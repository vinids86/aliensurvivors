class_name PlayerController extends CharacterBody2D

## Controlador principal da entidade Jogador.
## Gerencia Input, Combate, XP e Coleta (Magnet).

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

# --- ÁUDIO ---
@export_group("Audio")
@export var audio_player: AudioStreamPlayer2D 
@export var sfx_hurt: AudioStream

# --- COMBATE E COLETA ---
@export_group("Combat & Movement")
@export var self_knockback_force: float = 500.0 
@export var self_knockback_duration: float = 0.15 
# Referência à área de coleta para atualizar o tamanho dinamicamente
@export var magnet_area_shape: CollisionShape2D 

# --- ANIMAÇÃO (TIMING) ---
@export_group("Animation Timings")
@export var anim_prep_time: float = 0.15     
@export var anim_strike_time: float = 0.1    
@export var anim_recovery_time: float = 0.3  

# Estado Interno
enum State { NORMAL, ATTACKING, KNOCKED_BACK }
var _state: State = State.NORMAL

var _attack_timer: float = 0.0
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

func _ready() -> void:
	if not stats: stats = StatsConfig.new()
	_current_health = stats.get_stat("max_health")
	_time_alive = 0.0
	
	_setup_visuals()
	_update_magnet_radius() # Configura o tamanho inicial do imã
	
	if not audio_player:
		push_warning("PlayerController: 'Audio Player' não atribuído!")

func _physics_process(delta: float) -> void:
	_time_alive += delta
	
	match _state:
		State.NORMAL:
			_handle_normal_movement(delta)
		State.ATTACKING:
			move_and_slide() 
		State.KNOCKED_BACK:
			_handle_knockback_movement(delta)
			
	if _state != State.KNOCKED_BACK and velocity.length() > 0:
		_visual_rotation = lerp_angle(_visual_rotation, velocity.angle(), 15 * delta)
	
	_update_visuals(delta)
	_handle_combat(delta)

# --- MAGNET & XP ---

# Chamado sempre que ganhamos um upgrade de 'pickup_range'
func _update_magnet_radius() -> void:
	if magnet_area_shape and magnet_area_shape.shape is CircleShape2D:
		var range_val = stats.get_stat("pickup_range", 100.0)
		magnet_area_shape.shape.radius = range_val

# Chamado pelo sinal da MagnetArea (Conectaremos no Editor)
func _on_magnet_area_entered(area: Area2D) -> void:
	# Duck Typing: Se tem o método 'attract', é colecionável
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
	_xp_to_next_level *= 1.2 # Curva exponencial simples
	on_level_up.emit(_current_level)
	
	# Cura total ou parcial ao subir de nível (opcional, comum no gênero)
	heal(stats.get_stat("max_health") * 0.2)
	
	print("LEVEL UP! Nível: ", _current_level)

# --- MOVIMENTO E COMBATE ---

func _handle_normal_movement(delta: float) -> void:
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
	_current_health -= amount
	on_hit_received.emit(source_node, amount)
	
	if source_node and knockback_force > 0:
		var knock_dir = (global_position - source_node.global_position).normalized()
		apply_movement_knockback(knock_dir, knockback_force, 0.2)
	
	if _shader_material:
		_shader_material.set_shader_parameter("base_color", color_damage)
		var tw = create_tween()
		tw.tween_interval(0.1)
		tw.tween_callback(func(): _shader_material.set_shader_parameter("base_color", color_head))
	
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

func _handle_combat(delta: float) -> void:
	if _attack_timer > 0:
		_attack_timer -= delta
	if _state == State.NORMAL and _attack_timer <= 0:
		if Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("attack"):
			if current_attack_behavior:
				var attack_dir = Vector2.RIGHT.rotated(_visual_rotation)
				_start_attack_sequence(attack_dir)

func _start_attack_sequence(fixed_aim_direction: Vector2) -> void:
	_state = State.ATTACKING
	var cd_total = stats.get_stat("cooldown")
	if current_attack_behavior.base_cooldown_override > 0:
		cd_total = current_attack_behavior.base_cooldown_override
	_attack_timer = cd_total 
	var t_prep = max(cd_total * 0.35, 0.05)   
	var t_strike = max(cd_total * 0.15, 0.03) 
	var t_recover = max(cd_total * 0.4, 0.05) 
	
	if sprite_ref:
		if _tween_body: _tween_body.kill()
		_tween_body = create_tween()
		_tween_body.tween_property(sprite_ref, "scale", Vector2(0.4, 0.8), t_prep).set_trans(Tween.TRANS_SINE)
	
	await get_tree().create_timer(t_prep).timeout
	var knockback_dir = -fixed_aim_direction
	apply_movement_knockback(knockback_dir, self_knockback_force, self_knockback_duration)
	current_attack_behavior.execute(self, fixed_aim_direction)
	_trigger_flash()
	
	if sprite_ref:
		if _tween_body: _tween_body.kill()
		_tween_body = create_tween()
		_tween_body.tween_property(sprite_ref, "scale", Vector2(1.2, 0.4), t_strike).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_tween_body.tween_property(sprite_ref, "scale", Vector2(0.6, 0.6), t_recover).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(t_strike + t_recover).timeout
	if _state == State.ATTACKING:
		_state = State.NORMAL

func _update_visuals(delta: float) -> void:
	if _visual_pivot:
		_visual_pivot.rotation = _visual_rotation
	if sprite_ref and (_state == State.NORMAL or _state == State.KNOCKED_BACK):
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
