class_name PlayerController extends CharacterBody2D

## Controlador principal da entidade Jogador.
## Otimizado: Usa Unique Names (%) para acessar componentes automaticamente.

# --- SINAIS ---
signal on_attack_triggered(context_data: Dictionary)
# Mantidos para compatibilidade externa
signal on_hit_received(source: Node, damage: float) 
signal on_level_up(current_level: int)
signal on_xp_collected(amount: float)
signal on_dash_used(cooldown_time: float)
signal on_death()

# --- ARQUITETURA E COMPONENTES ---
# Usamos @onready com % para buscar automaticamente os nós marcados como Unique na cena.
# Isso elimina a necessidade de arrastar manualmente no Inspector.
@onready var health_component: HealthComponent = %HealthComponent
@onready var experience_component: ExperienceComponent = %ExperienceComponent

@export var stats: StatsConfig

@export_group("Combat Arsenal")
@export var basic_attack_card: AttackBehaviorCard
@export var special_attack_card: AttackBehaviorCard
@export var current_attack_behavior: AttackBehaviorCard # Legacy

# --- CONFIGURAÇÃO FÍSICA ---
@export_group("Movement & Physics")
@export var self_knockback_force: float = 500.0 
@export var self_knockback_duration: float = 0.15 
@export var magnet_area_shape: CollisionShape2D 

@export_group("Dash Ability")
@export var dash_speed: float = 800.0          
@export var dash_duration: float = 0.3         
@export var dash_cooldown: float = 1.5         
@export var dash_invulnerability: bool = true  

# --- AUDIO E VISUAL ---
@export_group("Visuals")
@export var sprite_ref: Sprite2D 
@export var body_shader: Shader 
@export var color_head: Color = Color("4fffa0")
@export var color_damage: Color = Color("ff2a2a")
@export var color_dash: Color = Color(0.2, 1.0, 1.0)

@export_group("Animation Timings")
@export var anim_prep_time: float = 0.15     
@export var anim_strike_time: float = 0.1    
@export var anim_recovery_time: float = 0.3  

@export_group("Audio")
@export var audio_player: AudioStreamPlayer2D 
@export var sfx_hurt: AudioStream
@export var sfx_dash: AudioStream

# --- ESTADO INTERNO ---
enum State { NORMAL, ATTACKING, KNOCKED_BACK, DASHING }
var _state: State = State.NORMAL

var _timers = {
	"basic_attack": 0.0,
	"special_attack": 0.0,
	"dash_cooldown": 0.0,
	"dash_duration": 0.0
}

# Variaveis de Controle Físico/Visual
var _knockback_velocity: Vector2 = Vector2.ZERO
var _dash_direction: Vector2 = Vector2.ZERO
var _visual_rotation: float = 0.0
var _time_alive: float = 0.0 
var _visual_pivot: Node2D 
var _shader_material: ShaderMaterial
var _tween_body: Tween 
var _shader_time_accum: float = 0.0
var _current_agitation: float = 1.0

# Acessores de Compatibilidade (Getters Seguros)
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
	# Validação crítica: Se esqueceu de marcar como Unique (%) na cena, avisa.
	if not health_component: push_error("Player: Nó %HealthComponent não encontrado! Marque-o como Unique Name na cena.")
	if not experience_component: push_error("Player: Nó %ExperienceComponent não encontrado! Marque-o como Unique Name na cena.")
	
	_validate_dependencies()
	_initialize_components()
	_initialize_visuals()
	_update_magnet_radius() 

func _physics_process(delta: float) -> void:
	_time_alive += delta
	_process_timers(delta)
	
	match _state:
		State.NORMAL:       _state_logic_normal(delta)
		State.ATTACKING:    _state_logic_attacking(delta)
		State.KNOCKED_BACK: _state_logic_knocked_back(delta)
		State.DASHING:      _state_logic_dashing(delta)
			
	_process_visual_rotation(delta)
	_update_visual_effects(delta)

# ==============================================================================
# INITIALIZATION & COMPONENTS
# ==============================================================================

func _initialize_components() -> void:
	# Configura Stats Iniciais
	if not stats: stats = StatsConfig.new()
	
	# Inicializa HealthComponent existente (agora pego via %UniqueName)
	if health_component:
		if not health_component.on_damage_taken.is_connected(_on_health_damage_taken):
			health_component.on_damage_taken.connect(_on_health_damage_taken)
		if not health_component.on_death.is_connected(_on_health_died):
			health_component.on_death.connect(_on_health_died)
		
		# Sincroniza com StatsConfig
		health_component.initialize(stats.get_stat("max_health", 100.0))
	
	# Inicializa ExperienceComponent existente (agora pego via %UniqueName)
	if experience_component:
		# Conexão segura para evitar duplicidade se o _ready rodar de novo
		if not experience_component.on_xp_collected.is_connected(func(amount): on_xp_collected.emit(amount)):
			experience_component.on_xp_collected.connect(func(amount): on_xp_collected.emit(amount))
		if not experience_component.on_level_up.is_connected(_on_comp_level_up):
			experience_component.on_level_up.connect(_on_comp_level_up)
	
	# Fallback para attack card antigo
	if not basic_attack_card and current_attack_behavior:
		basic_attack_card = current_attack_behavior

func _validate_dependencies() -> void:
	if not audio_player: push_warning("Player: AudioPlayer não atribuído.")
	# Removidos os push_error de componentes pois o @onready já lida (e o check no _ready complementa)

# ==============================================================================
# HEALTH HANDLERS
# ==============================================================================

func take_damage(amount: float, source_node: Node2D = null, knockback_force: float = 0.0) -> void:
	if _state == State.DASHING and dash_invulnerability: return 
	
	if source_node and knockback_force > 0:
		var knock_dir = (global_position - source_node.global_position).normalized()
		apply_impulse(knock_dir, knockback_force, 0.2)
	
	if health_component:
		health_component.take_damage(amount, source_node)

func heal(amount: float) -> void:
	if health_component:
		health_component.heal(amount)

func _on_health_damage_taken(amount: float, source: Node) -> void:
	_visual_flash(color_damage, 0.2)
	_play_sfx(sfx_hurt)
	on_hit_received.emit(source, amount)

func _on_health_died() -> void:
	on_death.emit()
	set_physics_process(false)

# ==============================================================================
# PROGRESSION HANDLERS
# ==============================================================================

func add_xp(amount: float) -> void:
	if experience_component:
		experience_component.add_xp(amount)

func _on_comp_level_up(new_level: int) -> void:
	# Retransmite sinal
	on_level_up.emit(new_level)
	# Cura 20% ao subir de nível
	if health_component:
		health_component.heal_percent(0.2)

func _update_magnet_radius() -> void:
	if magnet_area_shape and magnet_area_shape.shape is CircleShape2D:
		var range_val = stats.get_stat("pickup_range", 100.0)
		magnet_area_shape.shape.radius = range_val

func _on_magnet_area_entered(area: Area2D) -> void:
	if area.has_method("attract"):
		area.attract(self)

# ==============================================================================
# STATE MACHINE LOGIC
# ==============================================================================

func _state_logic_normal(_delta: float) -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move_speed = stats.get_stat("move_speed", 200.0)
	
	velocity = input_dir * move_speed
	move_and_slide()
	
	if _check_dash_input(): return
	if _check_combat_input(): return

func _state_logic_attacking(_delta: float) -> void:
	move_and_slide()
	if _check_dash_input(): return

func _state_logic_knocked_back(delta: float) -> void:
	velocity = _knockback_velocity
	move_and_slide()
	
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 8.0 * delta)
	if _knockback_velocity.length_squared() < 50:
		_state = State.NORMAL
		_knockback_velocity = Vector2.ZERO

func _state_logic_dashing(_delta: float) -> void:
	velocity = _dash_direction * dash_speed
	move_and_slide()
	
	if _timers.dash_duration <= 0:
		_finish_dash()

# ==============================================================================
# COMBAT SYSTEM
# ==============================================================================

func _check_combat_input() -> bool:
	if _timers.basic_attack <= 0:
		if Input.is_action_pressed("attack_basic") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var card = basic_attack_card if basic_attack_card else current_attack_behavior
			if card:
				_start_attack_sequence(card, "basic_attack")
				return true

	if _timers.special_attack <= 0:
		if Input.is_action_pressed("attack_special") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			if special_attack_card:
				_start_attack_sequence(special_attack_card, "special_attack")
				return true
	return false

func _start_attack_sequence(card: AttackBehaviorCard, timer_key: String) -> void:
	_state = State.ATTACKING
	
	var attack_dir = Vector2.RIGHT.rotated(_visual_rotation)
	var cd = stats.get_stat("cooldown", 1.0)
	if card.base_cooldown_override > 0: cd = card.base_cooldown_override
	_timers[timer_key] = cd
	
	var t_prep = max(cd * 0.35, 0.05)   
	var t_strike = max(cd * 0.15, 0.03) 
	var t_recover = max(cd * 0.4, 0.05) 
	
	_visual_tween_scale(Vector2(0.4, 0.8), t_prep) # Squash
	await get_tree().create_timer(t_prep).timeout
	
	if _state != State.ATTACKING: return 
	
	apply_impulse(-attack_dir, self_knockback_force, self_knockback_duration)
	card.execute(self, attack_dir)
	_visual_flash(Color.WHITE, 0.05)
	
	_visual_tween_scale(Vector2(1.2, 0.4), t_strike) # Stretch
	await get_tree().create_timer(t_strike).timeout
	
	_visual_tween_scale(Vector2(0.6, 0.6), t_recover) # Recover
	await get_tree().create_timer(t_recover).timeout
	
	if _state == State.ATTACKING: _state = State.NORMAL

func apply_impulse(direction: Vector2, force: float, duration: float) -> void:
	if _state == State.DASHING: return
	
	_knockback_velocity = direction * force
	_state = State.KNOCKED_BACK
	
	get_tree().create_timer(duration).timeout.connect(func():
		if _state == State.KNOCKED_BACK:
			_state = State.NORMAL
			_knockback_velocity = Vector2.ZERO
	, CONNECT_ONE_SHOT)

# ==============================================================================
# DASH SYSTEM
# ==============================================================================

func _check_dash_input() -> bool:
	if _timers.dash_cooldown > 0: return false
	
	if Input.is_action_just_pressed("ui_focus_next") or Input.is_action_just_pressed("dash"):
		_start_dash()
		return true
	return false

func _start_dash() -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir == Vector2.ZERO: input_dir = Vector2.RIGHT.rotated(_visual_rotation)
	
	_dash_direction = input_dir.normalized()
	_state = State.DASHING
	_timers.dash_duration = dash_duration
	_timers.dash_cooldown = dash_cooldown
	
	_play_sfx(sfx_dash)
	_visual_dash_start()
	on_dash_used.emit(dash_cooldown)

func _finish_dash() -> void:
	_state = State.NORMAL
	velocity = _dash_direction * stats.get_stat("move_speed", 200.0)
	_visual_dash_end()

# ==============================================================================
# VISUALS & UTILS
# ==============================================================================

func _process_timers(delta: float) -> void:
	for key in _timers.keys():
		if _timers[key] > 0: _timers[key] -= delta

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
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = body_shader
	
	if _shader_material:
		_shader_material.set_shader_parameter("base_color", color_head)
		sprite_ref.material = _shader_material

func _process_visual_rotation(delta: float) -> void:
	if _state != State.KNOCKED_BACK and velocity.length() > 0:
		_visual_rotation = lerp_angle(_visual_rotation, velocity.angle(), 15 * delta)
	if _visual_pivot: _visual_pivot.rotation = _visual_rotation

func _update_visual_effects(delta: float) -> void:
	if sprite_ref and (_state == State.NORMAL or _state == State.KNOCKED_BACK):
		if not _tween_body or not _tween_body.is_running():
			var base = Vector2(0.6, 0.6)
			var target = base
			if velocity.length() > 10.0:
				var wobble = sin(_time_alive * 15.0) * 0.05
				target = Vector2(base.x + wobble, base.y - wobble)
			else:
				var breath = sin(_time_alive * 2.0) * 0.03
				target = base + Vector2(breath, breath)
			sprite_ref.scale = sprite_ref.scale.lerp(target, 10.0 * delta)

	if _shader_material:
		var target_speed = 2.0 if _state == State.ATTACKING else 1.0
		_current_agitation = lerp(_current_agitation, target_speed, 5.0 * delta)
		_shader_time_accum += delta * _current_agitation
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
		var return_color = color_dash if _state == State.DASHING else color_head
		if _shader_material: _shader_material.set_shader_parameter("base_color", return_color)
	)

func _visual_dash_start() -> void:
	if not sprite_ref: return
	if _tween_body: _tween_body.kill()
	_tween_body = create_tween()
	_tween_body.tween_property(sprite_ref, "scale", Vector2(0.5, 0.7), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_body.tween_property(sprite_ref, "scale", Vector2(1.1, 0.4), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if _shader_material: _shader_material.set_shader_parameter("base_color", color_dash)

func _visual_dash_end() -> void:
	if not sprite_ref: return
	if _tween_body: _tween_body.kill()
	_tween_body = create_tween()
	_tween_body.tween_property(sprite_ref, "scale", Vector2(0.55, 0.65), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_body.tween_property(sprite_ref, "scale", Vector2(0.6, 0.6), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _shader_material: _shader_material.set_shader_parameter("base_color", color_head)
