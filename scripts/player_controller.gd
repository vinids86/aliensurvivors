class_name PlayerController extends CharacterBody2D

# --- ARQUITETURA ---
@export_group("Architecture")
@export var stats: StatsConfig
@export var current_attack_behavior: AttackBehaviorCard

# Sinais
signal on_attack_triggered(context_data: Dictionary)
signal on_hit_received(source, damage)
signal on_level_up(current_level)
signal on_xp_collected(amount)

# --- VISUAL ---
@export_group("Visuals")
@export var sprite_ref: Sprite2D 
@export var body_shader: Shader 
@export var color_head: Color = Color("4fffa0")
@export var color_damage: Color = Color("ff2a2a")

# --- ANIMAÇÃO (TIMING) ---
@export_group("Animation Timings")
@export var anim_prep_time: float = 0.15     
@export var anim_strike_time: float = 0.1    
@export var anim_recovery_time: float = 0.3  

# Variáveis internas
var _attack_timer: float = 0.0
var _current_health: float
var _visual_rotation: float = 0.0
var _visual_pivot: Node2D 
var _shader_material: ShaderMaterial
var _time_alive: float = 0.0 
var _tween_body: Tween 

# Controle manual do tempo do shader para evitar glitches
var _shader_time_accum: float = 0.0
var _current_agitation: float = 1.0

# MÁQUINA DE ESTADOS SIMPLES
enum State { NORMAL, ATTACKING }
var _state: State = State.NORMAL

func _ready():
	if not stats: stats = StatsConfig.new()
	_current_health = stats.get_stat("max_health")
	
	_time_alive = 0.0
	_setup_visuals()

func _physics_process(delta):
	if _time_alive == null: _time_alive = 0.0
	_time_alive += delta
	
	# 1. Movimento
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move_speed = stats.get_stat("move_speed")
	
	velocity = input_dir * move_speed
	move_and_slide()
	
	# 2. Rotação Visual
	if _state == State.NORMAL:
		if velocity.length() > 0:
			_visual_rotation = lerp_angle(_visual_rotation, velocity.angle(), 10 * delta)
	
	_update_visuals(delta)
	
	# 3. Combate
	_handle_combat(delta)

func _handle_combat(delta):
	if _attack_timer > 0:
		_attack_timer -= delta

	if _state == State.NORMAL and _attack_timer <= 0:
		if Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if current_attack_behavior:
				var attack_dir = Vector2.RIGHT.rotated(_visual_rotation)
				_start_attack_sequence(attack_dir)

func _start_attack_sequence(fixed_aim_direction: Vector2):
	_state = State.ATTACKING
	
	var cd_total = stats.get_stat("cooldown")
	if current_attack_behavior.base_cooldown_override > 0:
		cd_total = current_attack_behavior.base_cooldown_override
	
	_attack_timer = cd_total 
	
	var t_prep = max(cd_total * 0.35, 0.05)   
	var t_strike = max(cd_total * 0.15, 0.03) 
	var t_recover = max(cd_total * 0.4, 0.05) 
	
	# --- FASE 1: PREPARAÇÃO ---
	if sprite_ref:
		if _tween_body: _tween_body.kill()
		_tween_body = create_tween()
		_tween_body.tween_property(sprite_ref, "scale", Vector2(0.4, 0.8), t_prep)\
			.set_trans(Tween.TRANS_SINE)
	
	await get_tree().create_timer(t_prep).timeout
	
	# --- FASE 2: EXECUÇÃO ---
	current_attack_behavior.execute(self, fixed_aim_direction)
	_trigger_flash()
	
	if sprite_ref:
		if _tween_body: _tween_body.kill()
		_tween_body = create_tween()
		_tween_body.tween_property(sprite_ref, "scale", Vector2(1.2, 0.4), t_strike)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_tween_body.tween_property(sprite_ref, "scale", Vector2(0.6, 0.6), t_recover)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(t_strike + t_recover).timeout
	
	_state = State.NORMAL

# --- API ---
func take_damage(amount: float):
	_current_health -= amount
	on_hit_received.emit(null, amount)
	
	if _shader_material:
		_shader_material.set_shader_parameter("base_color", color_damage)
		var tw = create_tween()
		tw.tween_interval(0.1)
		tw.tween_callback(func(): _shader_material.set_shader_parameter("base_color", color_head))
	
	if _current_health <= 0: die()

func add_xp(amount: float):
	on_xp_collected.emit(amount)

func heal(amount: float):
	_current_health = min(_current_health + amount, stats.get_stat("max_health"))

func die():
	print("Player Morreu")

# --- VISUAL SYSTEM ---
func _setup_visuals():
	if not sprite_ref:
		push_warning("PlayerController: Sprite Ref não atribuído! O visual falhará.")
		return
		
	_visual_pivot = sprite_ref.get_parent()

	if body_shader:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = body_shader
		_shader_material.set_shader_parameter("base_color", color_head)
		# Não definimos mais 'agitation' aqui, controlamos via custom_time
		sprite_ref.material = _shader_material

func _update_visuals(delta):
	if _visual_pivot:
		_visual_pivot.rotation = _visual_rotation
	
	# --- ANIMAÇÃO PROCEDURAL ---
	if sprite_ref and _state == State.NORMAL:
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

	# --- CONTROLE DO SHADER (TEMPO MANUAL) ---
	if _shader_material:
		# Define a velocidade alvo: Rápida no ataque (2.0), Normal (1.0)
		var target_speed = 2.0 if _state == State.ATTACKING else 1.0
		
		# Interpola a velocidade para não dar trancos
		_current_agitation = lerp(_current_agitation, target_speed, 5.0 * delta)
		
		# Acumula o tempo sempre para frente
		_shader_time_accum += delta * _current_agitation
		
		# Passa o tempo calculado para o shader
		_shader_material.set_shader_parameter("custom_time", _shader_time_accum)

func _trigger_flash():
	if _shader_material:
		var prev_color = color_head
		_shader_material.set_shader_parameter("base_color", Color.WHITE)
		var tw = create_tween()
		tw.tween_interval(0.05)
		tw.tween_callback(func(): _shader_material.set_shader_parameter("base_color", prev_color))
