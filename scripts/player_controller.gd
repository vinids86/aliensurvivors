class_name PlayerController extends CharacterBody2D

## Controlador principal da entidade Jogador.
## Refatorado: Física extraída para MovementController. Fix timing do recuo no ataque.

# --- SINAIS ---
signal on_attack_triggered(context_data: Dictionary)
# Mantidos para compatibilidade
signal on_hit_received(source: Node, damage: float) 
signal on_level_up(current_level: int)
signal on_xp_collected(amount: float)
signal on_dash_used(cooldown_time: float)
signal on_death()

# --- COMPONENTES (Unique Names) ---
@onready var health_component: HealthComponent = %HealthComponent
@onready var experience_component: ExperienceComponent = %ExperienceComponent
@onready var movement_controller: MovementController = %MovementController

@export var stats: StatsConfig

@export_group("Combat Arsenal")
@export var basic_attack_card: AttackBehaviorCard
@export var special_attack_card: AttackBehaviorCard
@export var current_attack_behavior: AttackBehaviorCard # Legacy

# --- CONFIGURAÇÃO FÍSICA ---
@export_group("Physics Params")
@export var self_knockback_force: float = 500.0 # Usado no recoil do ataque
@export var self_knockback_duration: float = 0.15 
@export var magnet_area_shape: CollisionShape2D 

# --- AUDIO E VISUAL ---
@export_group("Visuals")
@export var sprite_ref: Sprite2D 
@export var body_shader: Shader 
@export var color_head: Color = Color("4fffa0")
@export var color_damage: Color = Color("ff2a2a")
@export var color_dash: Color = Color(0.2, 1.0, 1.0)

@export_group("Audio")
@export var audio_player: AudioStreamPlayer2D 
@export var sfx_hurt: AudioStream
@export var sfx_dash: AudioStream

# --- ESTADO INTERNO ---
enum State { NORMAL, ATTACKING, KNOCKED_BACK, DASHING }
var _state: State = State.NORMAL

# Cooldowns de Ataque (Dash foi movido)
var _attack_timers = {
	"basic": 0.0,
	"special": 0.0
}

# Controle Visual
var _visual_rotation: float = 0.0
var _time_alive: float = 0.0 
var _visual_pivot: Node2D 
var _shader_material: ShaderMaterial
var _tween_body: Tween 
var _shader_time_accum: float = 0.0
var _current_agitation: float = 1.0

# Getters de Compatibilidade
var _current_health: float: 
	get: return health_component.current_health if health_component else 0.0
var _current_xp: float: 
	get: return experience_component.current_xp if experience_component else 0.0
var _xp_to_next_level: float: 
	get: return experience_component.xp_required if experience_component else 100.0
var _current_level: int: 
	get: return experience_component.current_level if experience_component else 1

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	if not movement_controller: push_error("Player: %MovementController não encontrado!")
	
	_initialize_components()
	_initialize_visuals()
	_update_magnet_radius() 

func _physics_process(delta: float) -> void:
	_time_alive += delta
	_process_attack_timers(delta)
	
	_sync_state_with_physics()
	
	match _state:
		State.NORMAL:       _state_logic_normal(delta)
		State.ATTACKING:    _state_logic_attacking(delta)
		State.DASHING:      pass 
		State.KNOCKED_BACK: pass
			
	_process_visual_rotation(delta)
	_update_visual_effects(delta)

# ==============================================================================
# STATE MANAGEMENT
# ==============================================================================

func _sync_state_with_physics() -> void:
	# O MovementController é a autoridade sobre estados físicos
	if movement_controller.is_knocked_back:
		_state = State.KNOCKED_BACK
	elif movement_controller.is_dashing:
		_state = State.DASHING
	elif _state == State.KNOCKED_BACK or _state == State.DASHING:
		# Se o componente diz que acabou e não estamos atacando, volta ao normal
		_state = State.NORMAL

func _state_logic_normal(_delta: float) -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	movement_controller.move_with_input(input_dir)
	
	if _check_dash_input(input_dir): return
	if _check_combat_input(): return

func _state_logic_attacking(_delta: float) -> void:
	# Permite cancelar windup com Dash
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if _check_dash_input(input_dir): return
	
	movement_controller.stop_movement()

# ==============================================================================
# ACTIONS
# ==============================================================================

func _check_dash_input(input_dir: Vector2) -> bool:
	if Input.is_action_just_pressed("ui_focus_next") or Input.is_action_just_pressed("dash"):
		if movement_controller.attempt_dash(input_dir, _visual_rotation):
			_play_sfx(sfx_dash)
			_visual_dash_start()
			on_dash_used.emit(movement_controller.dash_cooldown)
			return true
	return false

func _check_combat_input() -> bool:
	if _attack_timers.basic <= 0:
		if Input.is_action_pressed("attack_basic") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var card = basic_attack_card if basic_attack_card else current_attack_behavior
			if card:
				_start_attack_sequence(card, "basic")
				return true

	if _attack_timers.special <= 0:
		if Input.is_action_pressed("attack_special") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			if special_attack_card:
				_start_attack_sequence(special_attack_card, "special")
				return true
	return false

func _start_attack_sequence(card: AttackBehaviorCard, timer_key: String) -> void:
	# 1. Garante rotação correta ANTES de começar (trava a mira no input atual)
	_update_rotation_to_input()
	_state = State.ATTACKING
	
	# Calcula direção baseada na rotação travada
	var attack_dir = Vector2.RIGHT.rotated(_visual_rotation)
	
	var cd = stats.get_stat("cooldown", 1.0)
	if card.base_cooldown_override > 0: cd = card.base_cooldown_override
	_attack_timers[timer_key] = cd
	
	# 2. Windup (Preparação Visual) - O Recuo NÃO deve acontecer aqui ainda
	var t_prep = max(cd * 0.35, 0.05)
	_visual_tween_scale(Vector2(0.4, 0.8), t_prep)
	
	# Espera a preparação
	await get_tree().create_timer(t_prep).timeout
	
	# Verifica se foi cancelado (por Dash, Stun ou Morte) durante a espera
	if _state != State.ATTACKING: return

	# 3. Execução (Tiro + Recuo Simultâneos)
	# Aplica Recoil agora (Empurra para trás)
	movement_controller.apply_knockback(-attack_dir * self_knockback_force, self_knockback_duration)
	
	card.execute(self, attack_dir)
	_visual_flash(Color.WHITE, 0.05)
	
	# Animação de recuperação
	await get_tree().create_timer(0.2).timeout
	
	# Volta ao normal se o recuo já tiver acabado e o player não tiver feito outra ação
	if _state == State.ATTACKING: 
		_state = State.NORMAL

# ==============================================================================
# VISUALS & UTILS
# ==============================================================================

func _process_visual_rotation(delta: float) -> void:
	# Não rotacionar se estiver sofrendo knockback ou atacando (trava mira)
	if _state == State.KNOCKED_BACK or _state == State.ATTACKING:
		return 
		
	if velocity.length() > 0:
		_visual_rotation = lerp_angle(_visual_rotation, velocity.angle(), 15 * delta)
	
	if _visual_pivot: _visual_pivot.rotation = _visual_rotation

func _update_rotation_to_input() -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		_visual_rotation = input_dir.angle()
	if _visual_pivot: _visual_pivot.rotation = _visual_rotation

# ... Resto do código (take_damage, setup, efeitos) mantido inalterado ...

func take_damage(amount: float, source_node: Node2D = null, knockback_force: float = 0.0) -> void:
	if movement_controller.is_dashing and movement_controller.dash_invulnerability: return
	
	if source_node and knockback_force > 0:
		var knock_dir = (global_position - source_node.global_position).normalized()
		movement_controller.apply_knockback(knock_dir * knockback_force, 0.2)
	
	if health_component:
		health_component.take_damage(amount, source_node)

func add_xp(amount: float) -> void:
	if experience_component: experience_component.add_xp(amount)

func _initialize_components() -> void:
	if not stats: stats = StatsConfig.new()
	if health_component:
		health_component.on_damage_taken.connect(func(amt, src): 
			_visual_flash(color_damage, 0.2)
			_play_sfx(sfx_hurt)
			on_hit_received.emit(src, amt)
		)
		health_component.on_death.connect(func(): on_death.emit())
		health_component.initialize(stats.get_stat("max_health", 100.0))
	if experience_component:
		experience_component.on_xp_collected.connect(func(amt): on_xp_collected.emit(amt))
		experience_component.on_level_up.connect(func(lvl):
			on_level_up.emit(lvl)
			if health_component: health_component.heal_percent(0.2)
		)
	if not basic_attack_card and current_attack_behavior:
		basic_attack_card = current_attack_behavior

func _process_attack_timers(delta: float) -> void:
	for k in _attack_timers:
		if _attack_timers[k] > 0: _attack_timers[k] -= delta

func _play_sfx(stream: AudioStream) -> void:
	if audio_player and stream:
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.stream = stream
		audio_player.play()

func _initialize_visuals() -> void:
	if not sprite_ref: return
	_visual_pivot = sprite_ref.get_parent()
	if sprite_ref.material: _shader_material = sprite_ref.material.duplicate()
	elif body_shader:
		_shader_material = ShaderMaterial.new(); _shader_material.shader = body_shader
	if _shader_material: 
		_shader_material.set_shader_parameter("base_color", color_head)
		sprite_ref.material = _shader_material

func _update_visual_effects(delta: float) -> void:
	if sprite_ref and (_state == State.NORMAL):
		if not _tween_body or not _tween_body.is_running():
			var target = Vector2(0.6, 0.6)
			if velocity.length() > 10.0:
				target.x += sin(_time_alive * 15.0) * 0.05
			else:
				target += Vector2(1,1) * sin(_time_alive * 2.0) * 0.03
			sprite_ref.scale = sprite_ref.scale.lerp(target, 10.0 * delta)
	if _shader_material:
		_shader_time_accum += delta * (2.0 if _state == State.ATTACKING else 1.0)
		_shader_material.set_shader_parameter("custom_time", _shader_time_accum)

func _visual_tween_scale(target: Vector2, duration: float) -> void:
	if not sprite_ref: return
	if _tween_body: _tween_body.kill()
	_tween_body = create_tween()
	_tween_body.tween_property(sprite_ref, "scale", target, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _visual_flash(color: Color, duration: float) -> void:
	if not _shader_material: return
	_shader_material.set_shader_parameter("base_color", color)
	var tw = create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(func(): 
		if _shader_material: _shader_material.set_shader_parameter("base_color", color_dash if _state == State.DASHING else color_head)
	)

func _visual_dash_start() -> void:
	_visual_tween_scale(Vector2(1.1, 0.4), 0.15)
	if _shader_material: _shader_material.set_shader_parameter("base_color", color_dash)

func _update_magnet_radius() -> void:
	if magnet_area_shape and magnet_area_shape.shape is CircleShape2D:
		magnet_area_shape.shape.radius = stats.get_stat("pickup_range", 100.0)

func _on_magnet_area_entered(area: Area2D) -> void:
	if area.has_method("attract"): area.attract(self)
