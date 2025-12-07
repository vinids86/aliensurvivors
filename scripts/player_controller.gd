class_name PlayerController extends CharacterBody2D

## Controlador principal da entidade Jogador.
## Gerencia Input, Combate, XP, Coleta (Magnet) e agora Movimento Avançado (Dash).

# --- ARQUITETURA ---
@export_group("Architecture")
@export var stats: StatsConfig

@export_group("Combat Arsenal")
@export var basic_attack_card: AttackBehaviorCard   # Ataque 1 (Idyllic)
@export var special_attack_card: AttackBehaviorCard # Ataque 2 (Sonic Boom)
# Mantido para compatibilidade, mas o código priorizará os de cima se existirem
@export var current_attack_behavior: AttackBehaviorCard

# Sinais
signal on_attack_triggered(context_data: Dictionary)
signal on_hit_received(source, damage)
signal on_level_up(current_level)
signal on_xp_collected(amount)
# Sinal emitido quando o dash é usado (para câmera e UI)
signal on_dash_used(cooldown_time)

# --- VISUAL ---
@export_group("Visuals")
@export var sprite_ref: Sprite2D 
@export var body_shader: Shader 
@export var color_head: Color = Color("4fffa0")
@export var color_damage: Color = Color("ff2a2a")

# --- ÁUDIO ---
@export_group("Audio")
@export var audio_player: AudioStreamPlayer2D 
@export var sfx_hurt: AudioStream
@export var sfx_dash: AudioStream # Som do Dash

# --- PROGRESSÃO (XP) ---
@export_group("Progression")
@export var xp_growth_multiplier: float = 1.1 # +10% por nível (Curva suave)
@export var xp_flat_increase: float = 25.0    # +25 XP fixo por nível (Base sólida)

# --- COMBATE E COLETA ---
@export_group("Combat & Movement")
@export var self_knockback_force: float = 500.0 
@export var self_knockback_duration: float = 0.15 
@export var magnet_area_shape: CollisionShape2D 

# --- DASH ABILITY (NOVO) ---
@export_group("Dash Ability")
@export var dash_speed: float = 800.0          # Velocidade explosiva
@export var dash_duration: float = 0.3         # Duração um pouco maior para suavizar
@export var dash_cooldown: float = 1.5         # Tempo de recarga
@export var dash_invulnerability: bool = true  # Se o player fica imune durante o dash

# --- ANIMAÇÃO (TIMING) ---
@export_group("Animation Timings")
@export var anim_prep_time: float = 0.15     
@export var anim_strike_time: float = 0.1    
@export var anim_recovery_time: float = 0.3  

# Estado Interno
enum State { NORMAL, ATTACKING, KNOCKED_BACK, DASHING }
var _state: State = State.NORMAL

# Cooldowns individuais
var _basic_timer: float = 0.0
var _special_timer: float = 0.0
var _attack_timer: float = 0.0 # Legado

var _current_health: float
var _current_xp: float = 0.0
var _current_level: int = 1
var _xp_to_next_level: float = 100.0

var _time_alive: float = 0.0 
var _visual_rotation: float = 0.0
var _visual_pivot: Node2D 
var _shader_material: ShaderMaterial
var _tween_body: Tween 
var _shader_time_accum: float = 0.0
var _current_agitation: float = 1.0
var _knockback_velocity: Vector2 = Vector2.ZERO

# Variáveis de Controle do Dash
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_timer: float = 0.0

func _ready() -> void:
	if not stats: stats = StatsConfig.new()
	_current_health = stats.get_stat("max_health")
	_time_alive = 0.0
	
	_setup_visuals()
	_update_magnet_radius() 
	
	# Fallback: Se não configurou os slots novos, usa o antigo
	if not basic_attack_card and current_attack_behavior:
		basic_attack_card = current_attack_behavior
	
	if not audio_player:
		push_warning("PlayerController: 'Audio Player' não atribuído!")

func _physics_process(delta: float) -> void:
	_time_alive += delta
	
	# Gerencia Cooldowns
	if _dash_cooldown_timer > 0: _dash_cooldown_timer -= delta
	if _basic_timer > 0: _basic_timer -= delta
	if _special_timer > 0: _special_timer -= delta
	
	match _state:
		State.NORMAL:
			_handle_normal_movement(delta)
			_handle_dash_input() # Verifica se apertou botão de dash
		State.ATTACKING:
			move_and_slide()
			# Permite cancelar o ataque com Dash (Animation Cancel - Juice!)
			_handle_dash_input() 
		State.KNOCKED_BACK:
			_handle_knockback_movement(delta)
		State.DASHING:
			_handle_dashing_movement(delta)
			
	if _state != State.KNOCKED_BACK and velocity.length() > 0:
		_visual_rotation = lerp_angle(_visual_rotation, velocity.angle(), 15 * delta)
	
	_update_visuals(delta)
	_handle_combat(delta)

# --- MAGNET & XP ---

func _update_magnet_radius() -> void:
	if magnet_area_shape and magnet_area_shape.shape is CircleShape2D:
		var range_val = stats.get_stat("pickup_range", 100.0)
		magnet_area_shape.shape.radius = range_val

func _on_magnet_area_entered(area: Area2D) -> void:
	if area.has_method("attract"):
		area.attract(self)

func add_xp(amount: float) -> void:
	_current_xp += amount
	on_xp_collected.emit(amount)
	
	if _current_xp >= _xp_to_next_level:
		_level_up()

func _level_up() -> void:
	_current_xp -= _xp_to_next_level
	_current_level += 1
	_xp_to_next_level = (_xp_to_next_level * xp_growth_multiplier) + xp_flat_increase
	
	on_level_up.emit(_current_level)
	heal(stats.get_stat("max_health") * 0.2)
	print("LEVEL UP! Nível: %d | Próximo XP: %.0f" % [_current_level, _xp_to_next_level])

# --- DASH SYSTEM (CORE) ---

func _handle_dash_input() -> void:
	if _dash_cooldown_timer <= 0:
		# Use "dash" se você criou a ação no Input Map, ou "ui_focus_next" (Tab/R1) como fallback
		if Input.is_action_just_pressed("ui_focus_next") or Input.is_action_just_pressed("dash"):
			_start_dash()

func _start_dash() -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Se não estiver movendo, dash na direção que está olhando (Frente)
	if input_dir == Vector2.ZERO:
		input_dir = Vector2.RIGHT.rotated(_visual_rotation)
	
	_dash_direction = input_dir.normalized()
	_state = State.DASHING
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	
	# Som do Dash
	if audio_player and sfx_dash:
		audio_player.pitch_scale = randf_range(0.9, 1.1)
		audio_player.stream = sfx_dash
		audio_player.play()
	
	# Efeitos Visuais - SEQUÊNCIA DE DASH (Mais Suave)
	if sprite_ref:
		if _tween_body: _tween_body.kill()
		_tween_body = create_tween()
		
		# 1. Preparação (Anticipation) - Um pouco mais lenta e suave
		_tween_body.tween_property(sprite_ref, "scale", Vector2(0.5, 0.7), 0.08)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			
		# 2. Dash (Action) - Estica progressivamente
		_tween_body.tween_property(sprite_ref, "scale", Vector2(1.1, 0.4), 0.15)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Flash de cor (Ciano/Azul para indicar velocidade)
	if _shader_material:
		_shader_material.set_shader_parameter("base_color", Color(0.2, 1.0, 1.0)) 
	
	# Emite sinal para a Câmera fazer o Zoom Out
	on_dash_used.emit(dash_cooldown)

func _handle_dashing_movement(delta: float) -> void:
	velocity = _dash_direction * dash_speed
	move_and_slide()
	
	_dash_timer -= delta
	if _dash_timer <= 0:
		_finish_dash()

func _finish_dash() -> void:
	_state = State.NORMAL
	# Mantém um pouco de inércia na direção do movimento
	velocity = _dash_direction * stats.get_stat("move_speed")
	
	# Efeito: Frenagem (Follow Through) - Mais natural
	if sprite_ref:
		if _tween_body: _tween_body.kill()
		_tween_body = create_tween()
		
		# 3. Frenagem (Impacto da parada)
		_tween_body.tween_property(sprite_ref, "scale", Vector2(0.55, 0.65), 0.12)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			
		# 4. Estabiliza no tamanho original (0.6, 0.6) suavemente
		_tween_body.tween_property(sprite_ref, "scale", Vector2(0.6, 0.6), 0.25)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Volta a cor original
	if _shader_material:
		_shader_material.set_shader_parameter("base_color", color_head)

# --- MOVIMENTO E COMBATE ---

func _handle_normal_movement(_delta: float) -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move_speed = stats.get_stat("move_speed")
	velocity = input_dir * move_speed
	move_and_slide()

func _handle_knockback_movement(delta: float) -> void:
	velocity = _knockback_velocity
	move_and_slide()
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 8.0 * delta)
	if _knockback_velocity.length_squared() < 50:
		_state = State.NORMAL
		_knockback_velocity = Vector2.ZERO

func apply_movement_knockback(direction: Vector2, force: float, duration: float) -> void:
	# Não aplica knockback se estiver no meio de um dash (imparável)
	if _state == State.DASHING: return
	
	_knockback_velocity = direction * force
	_state = State.KNOCKED_BACK
	var tw = create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(func(): 
		if _state == State.KNOCKED_BACK:
			_state = State.NORMAL
			_knockback_velocity = Vector2.ZERO
	)

func take_damage(amount: float, source_node: Node2D = null, knockback_force: float = 0.0) -> void:
	# INVULNERABILIDADE (I-FRAME) durante o Dash
	if _state == State.DASHING and dash_invulnerability:
		return 
		
	_current_health -= amount
	on_hit_received.emit(source_node, amount)
	
	if source_node and knockback_force > 0:
		var knock_dir = (global_position - source_node.global_position).normalized()
		apply_movement_knockback(knock_dir, knockback_force, 0.2)
	
	if _shader_material:
		_shader_material.set_shader_parameter("base_color", color_damage)
		var tw = create_tween()
		tw.tween_interval(0.1)
		tw.tween_callback(func(): 
			# Só reseta a cor se não estiver no meio de um dash (que usa azul)
			if _state != State.DASHING and _shader_material:
				_shader_material.set_shader_parameter("base_color", color_head)
		)
	
	if audio_player and sfx_hurt:
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.stream = sfx_hurt
		audio_player.play()
	
	if _current_health <= 0:
		_die()

func heal(amount: float) -> void:
	_current_health = min(_current_health + amount, stats.get_stat("max_health"))

func _setup_visuals() -> void:
	if not sprite_ref: return
	_visual_pivot = sprite_ref.get_parent()
	if body_shader:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = body_shader
		_shader_material.set_shader_parameter("base_color", color_head)
		sprite_ref.material = _shader_material

func _die() -> void:
	set_physics_process(false)
	# Aqui você pode adicionar lógica de Game Over depois

func _handle_combat(delta: float) -> void:
	# Lógica para 2 Ataques:
	# 1. Checa BÁSICO (Botão Esquerdo / attack_basic)
	if _state == State.NORMAL and _basic_timer <= 0:
		if Input.is_action_pressed("attack_basic") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): # 'attack' como fallback
			if basic_attack_card:
				var dir = Vector2.RIGHT.rotated(_visual_rotation)
				_start_attack_sequence(basic_attack_card, dir, "basic")
				return

	# 2. Checa ESPECIAL (Botão Direito / attack_special)
	if _state == State.NORMAL and _special_timer <= 0:
		if Input.is_action_pressed("attack_special") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			if special_attack_card:
				var dir = Vector2.RIGHT.rotated(_visual_rotation)
				_start_attack_sequence(special_attack_card, dir, "special")
				return

# Modificado para aceitar o Card e o Tipo
func _start_attack_sequence(card: AttackBehaviorCard, fixed_aim_direction: Vector2, attack_type: String) -> void:
	_state = State.ATTACKING
	
	# Define cooldown baseado na carta (ou global se a carta não tiver override)
	var cd = stats.get_stat("cooldown")
	if card.base_cooldown_override > 0:
		cd = card.base_cooldown_override
	
	# Aplica no timer correto
	if attack_type == "basic":
		_basic_timer = cd
	else:
		_special_timer = cd
	
	# Animações baseadas no tempo do ataque
	var t_prep = max(cd * 0.35, 0.05)   
	var t_strike = max(cd * 0.15, 0.03) 
	var t_recover = max(cd * 0.4, 0.05) 
	
	# Prep (Squash)
	_visual_squash_stretch(Vector2(0.4, 0.8), t_prep)
	
	await get_tree().create_timer(t_prep).timeout
	if _state != State.ATTACKING: return # Cancelou?
	
	# Executa
	var knockback_dir = -fixed_aim_direction
	apply_movement_knockback(knockback_dir, self_knockback_force, self_knockback_duration)
	
	# AQUI: O card instancia a cena (Idyllic ou Sonic Boom)
	card.execute(self, fixed_aim_direction)
	_trigger_flash()
	
	# Strike (Stretch)
	_visual_squash_stretch(Vector2(1.2, 0.4), t_strike)
	
	await get_tree().create_timer(t_strike).timeout
	
	# Recover
	_visual_squash_stretch(Vector2(0.6, 0.6), t_recover)
	
	await get_tree().create_timer(t_recover).timeout
	if _state == State.ATTACKING:
		_state = State.NORMAL

func _visual_squash_stretch(target_scale: Vector2, duration: float) -> void:
	if sprite_ref:
		if _tween_body: _tween_body.kill()
		_tween_body = create_tween()
		_tween_body.tween_property(sprite_ref, "scale", target_scale, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _update_visuals(delta: float) -> void:
	if _visual_pivot:
		_visual_pivot.rotation = _visual_rotation
	
	# Só anima o "respiração/wobble" se NÃO estiver em animação forçada (Tween rodando)
	if sprite_ref and (_state == State.NORMAL or _state == State.KNOCKED_BACK) and (not _tween_body or not _tween_body.is_running()):
		var base_scale = Vector2(0.6, 0.6)
		var target_scale = base_scale
		if velocity.length() > 10.0:
			var wobble_freq = 5.0
			var wobble_amp = 0.1
			var wave = sin(_time_alive * wobble_freq) * wobble_amp
			target_scale = Vector2(base_scale.x + 0.1 + wave, base_scale.y - 0.1 - wave)
		else:
			var breath_freq = 2.0
			var breath_amp = 0.03
			var wave = sin(_time_alive * breath_freq) * breath_amp
			target_scale = base_scale + Vector2(wave, wave)
		sprite_ref.scale = sprite_ref.scale.lerp(target_scale, 10.0 * delta)
		
	if _shader_material:
		var target_speed = 2.0 if _state == State.ATTACKING else 1.0
		_current_agitation = lerp(_current_agitation, target_speed, 5.0 * delta)
		_shader_time_accum += delta * _current_agitation
		_shader_material.set_shader_parameter("custom_time", _shader_time_accum)

func _trigger_flash() -> void:
	if _shader_material:
		var prev_color = color_head
		_shader_material.set_shader_parameter("base_color", Color.WHITE)
		var tw = create_tween()
		tw.tween_interval(0.05)
		tw.tween_callback(func(): _shader_material.set_shader_parameter("base_color", prev_color))
