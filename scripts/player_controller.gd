class_name PlayerController extends CharacterBody2D

## Controlador principal da entidade Jogador.
## Refatorado: Ataque movido para WeaponManager. Física no MovementController.

# --- SINAIS ---
# Restaurado para compatibilidade com os AttackCards (Melee/Projectile)
signal on_attack_triggered(context_data: Dictionary) 

signal on_hit_received(source: Node, damage: float) 
signal on_level_up(current_level: int)
signal on_xp_collected(amount: float)
signal on_dash_used(cooldown_time: float)
signal on_death()

# --- COMPONENTES (Unique Names) ---
@onready var health_component: HealthComponent = %HealthComponent
@onready var experience_component: ExperienceComponent = %ExperienceComponent
@onready var movement_controller: MovementController = %MovementController
@onready var weapon_manager: WeaponManager = %WeaponManager

@export var stats: StatsConfig

# --- CONFIGURAÇÃO FÍSICA ---
@export_group("Physics Params")
@export var self_knockback_force: float = 500.0
@export var self_knockback_duration: float = 0.15 
@export var magnet_area_shape: CollisionShape2D 

# --- VISUAL E AUDIO ---
@export_group("Visuals")
@export var sprite_ref: Sprite2D 
@export var body_shader: Shader 
@export var color_head: Color = Color("4fffa0")
@export var color_damage: Color = Color("ff2a2a")
@export var color_dash: Color = Color(0.2, 1.0, 1.0)
@export var audio_player: AudioStreamPlayer2D 
@export var sfx_hurt: AudioStream
@export var sfx_dash: AudioStream

# --- ESTADO INTERNO ---
enum State { NORMAL, ATTACKING, KNOCKED_BACK, DASHING }
var _state: State = State.NORMAL

# Controle Visual
var _visual_rotation: float = 0.0
var _time_alive: float = 0.0 
var _visual_pivot: Node2D 
var _shader_material: ShaderMaterial
var _tween_body: Tween 
var _shader_time_accum: float = 0.0

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
	if not weapon_manager: push_error("Player: %WeaponManager não encontrado!")
	
	_initialize_components()
	_initialize_visuals()
	_update_magnet_radius() 

func _physics_process(delta: float) -> void:
	_time_alive += delta
	_sync_state_with_components()
	
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

func _sync_state_with_components() -> void:
	# Prioridade de Estados: Knockback > Dash > Attack > Normal
	if movement_controller.is_knocked_back:
		_state = State.KNOCKED_BACK
	elif movement_controller.is_dashing:
		_state = State.DASHING
	elif weapon_manager.is_busy:
		_state = State.ATTACKING
	else:
		_state = State.NORMAL

func _state_logic_normal(_delta: float) -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	movement_controller.move_with_input(input_dir)
	
	if _check_dash_input(input_dir): return
	_check_combat_input()

func _state_logic_attacking(_delta: float) -> void:
	# Permite cancelar ataque com Dash
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if _check_dash_input(input_dir): 
		weapon_manager.cancel_attack()
		return
	
	# Durante ataque, o personagem para (exceto se empurrado pelo recuo)
	movement_controller.stop_movement()

# ==============================================================================
# ACTIONS (Delegation)
# ==============================================================================

func _check_dash_input(input_dir: Vector2) -> bool:
	if Input.is_action_just_pressed("ui_focus_next") or Input.is_action_just_pressed("dash"):
		if movement_controller.attempt_dash(input_dir, _visual_rotation):
			_play_sfx(sfx_dash)
			_visual_dash_start()
			on_dash_used.emit(movement_controller.dash_cooldown)
			return true
	return false

func _check_combat_input() -> void:
	var type = ""
	if Input.is_action_pressed("attack_basic") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		type = "basic"
	elif Input.is_action_pressed("attack_special") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		type = "special"
	
	if type != "":
		# Atualiza rotação antes de tentar atacar para mirar corretamente
		_update_rotation_to_input()
		var aim_dir = Vector2.RIGHT.rotated(_visual_rotation)
		weapon_manager.attempt_attack(type, aim_dir)

# ==============================================================================
# COMPONENT HANDLERS (Signals)
# ==============================================================================

func _on_weapon_windup(duration: float) -> void:
	# Efeito visual de "carregar" o ataque (Squash)
	_visual_tween_scale(Vector2(0.4, 0.8), duration)

func _on_weapon_executed(recoil_dir: Vector2) -> void:
	# 1. Aplica Knockback físico
	movement_controller.apply_knockback(recoil_dir * self_knockback_force, self_knockback_duration)
	
	# 2. Efeitos Visuais (Stretch + Flash)
	_visual_flash(Color.WHITE, 0.05)
	_visual_tween_scale(Vector2(1.2, 0.4), 0.1) # Stretch rápido
	
	# 3. Retorna escala ao normal após um breve momento
	await get_tree().create_timer(0.1).timeout
	if _state != State.DASHING:
		_visual_tween_scale(Vector2(0.6, 0.6), 0.2)

# ==============================================================================
# SETUP & INITIALIZATION
# ==============================================================================

func _initialize_components() -> void:
	if not stats: stats = StatsConfig.new()
	
	# Configura conexões do WeaponManager
	if weapon_manager:
		if not weapon_manager.on_attack_windup.is_connected(_on_weapon_windup):
			weapon_manager.on_attack_windup.connect(_on_weapon_windup)
		if not weapon_manager.on_attack_executed.is_connected(_on_weapon_executed):
			weapon_manager.on_attack_executed.connect(_on_weapon_executed)
		
		# Transferir referências antigas para o componente se necessário
		# (Isso assume que você vai configurar no Inspector do WeaponManager,
		# mas deixo aqui caso queira migrar via código)
	
	# Configura HealthComponent
	if health_component:
		if not health_component.on_damage_taken.is_connected(_on_health_dmg):
			health_component.on_damage_taken.connect(_on_health_dmg)
		if not health_component.on_death.is_connected(func(): on_death.emit()):
			health_component.on_death.connect(func(): on_death.emit())
		health_component.initialize(stats.get_stat("max_health", 100.0))

	# XP Component
	if experience_component:
		if not experience_component.on_xp_collected.is_connected(func(a): on_xp_collected.emit(a)):
			experience_component.on_xp_collected.connect(func(a): on_xp_collected.emit(a))
		if not experience_component.on_level_up.is_connected(_on_lvl_up):
			experience_component.on_level_up.connect(_on_lvl_up)

# ==============================================================================
# PROXIES & UTILS
# ==============================================================================

func take_damage(amount: float, source: Node2D = null, force: float = 0.0) -> void:
	if movement_controller.is_dashing and movement_controller.dash_invulnerability: return
	if source and force > 0:
		var dir = (global_position - source.global_position).normalized()
		movement_controller.apply_knockback(dir * force, 0.2)
	if health_component: health_component.take_damage(amount, source)

func add_xp(amount: float) -> void:
	if experience_component: experience_component.add_xp(amount)

func _on_health_dmg(amount: float, source: Node) -> void:
	_visual_flash(color_damage, 0.2)
	_play_sfx(sfx_hurt)
	on_hit_received.emit(source, amount)

func _on_lvl_up(lvl: int) -> void:
	on_level_up.emit(lvl)
	if health_component: health_component.heal_percent(0.2)

# ==============================================================================
# VISUALS
# ==============================================================================

func _process_visual_rotation(delta: float) -> void:
	# Trava rotação se estiver atacando ou em knockback
	if _state == State.ATTACKING or _state == State.KNOCKED_BACK: return
	if velocity.length() > 0:
		_visual_rotation = lerp_angle(_visual_rotation, velocity.angle(), 15 * delta)
	if _visual_pivot: _visual_pivot.rotation = _visual_rotation

func _update_rotation_to_input() -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		_visual_rotation = input_dir.angle()
	if _visual_pivot: _visual_pivot.rotation = _visual_rotation

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
		var spd = 2.0 if _state == State.ATTACKING else 1.0
		_shader_time_accum += delta * spd
		_shader_material.set_shader_parameter("custom_time", _shader_time_accum)

func _initialize_visuals() -> void:
	if not sprite_ref: return
	_visual_pivot = sprite_ref.get_parent()
	if sprite_ref.material: _shader_material = sprite_ref.material.duplicate()
	elif body_shader:
		_shader_material = ShaderMaterial.new(); _shader_material.shader = body_shader
	if _shader_material: 
		_shader_material.set_shader_parameter("base_color", color_head)
		sprite_ref.material = _shader_material

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
func _play_sfx(stream: AudioStream) -> void:
	if audio_player and stream:
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.stream = stream
		audio_player.play()
func _update_magnet_radius() -> void:
	if magnet_area_shape and magnet_area_shape.shape is CircleShape2D:
		magnet_area_shape.shape.radius = stats.get_stat("pickup_range", 100.0)
func _on_magnet_area_entered(area: Area2D) -> void:
	if area.has_method("attract"): area.attract(self)
