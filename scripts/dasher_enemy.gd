extends CharacterBody2D

# --- DEFINIÇÕES ---
enum State { CHASE, PREPARE, DASH, RECOVERY }

# --- REFERÊNCIAS ÚNICAS ---
@onready var health_component: HealthComponent = %HealthComponent
@onready var movement_controller: MovementController = %MovementController
@onready var hitbox_component: HitboxComponent = %HitboxComponent
@onready var loot_component: LootComponent = %LootComponent
@onready var visuals: EnemyVisuals = %EnemyVisuals # Novo Componente

# --- CONFIGURAÇÃO (Lógica de Jogo apenas) ---
@export_group("Stats")
@export var hp: int = 30
@export var normal_speed: float = 90.0
@export var dash_speed: float = 600.0

@export_group("Combat")
@export var attack_range: float = 200.0
@export var prepare_time: float = 0.8
@export var dash_duration: float = 0.25
@export var recovery_time: float = 1.0

# --- ESTADO INTERNO ---
var _player_ref: Node2D
var _current_state: State = State.CHASE
var _state_timer: float = 0.0
var _dash_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	_player_ref = get_tree().get_first_node_in_group("player")
	
	# Inicialização de Componentes
	health_component.initialize(hp)
	
	# Conexões Limpas: Lógica -> Visual
	health_component.on_death.connect(_on_death)
	health_component.on_damage_taken.connect(func(_a, _s): visuals.play_hit_feedback())
	
	hitbox_component.monitoring = false 
	hitbox_component.on_hit_target.connect(_on_hit_player)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player_ref): return
	
	match _current_state:
		State.CHASE: _state_logic_chase()
		State.PREPARE: _state_logic_prepare(delta)
		State.DASH: _state_logic_dash(delta)
		State.RECOVERY: _state_logic_recovery(delta)

# --- MÁQUINA DE ESTADOS ---

func change_state(new_state: State) -> void:
	if _current_state == new_state: return
	_exit_state(_current_state)
	_current_state = new_state
	_enter_state(_current_state)

func _enter_state(state: State) -> void:
	match state:
		State.PREPARE:
			_state_timer = prepare_time
			movement_controller.stop_movement()
			# Visual
			visuals.play_charge_buildup(prepare_time)
			
		State.DASH:
			_state_timer = dash_duration
			# Lógica
			_dash_vector = visuals.get_facing_direction() # Pede a direção para o visual
			movement_controller.stop_movement()
			movement_controller.is_knocked_back = false
			movement_controller.is_dashing = false
			hitbox_component.set_deferred("monitoring", true)
			# Visual
			visuals.play_dash_start(dash_duration)
			
		State.RECOVERY:
			_state_timer = recovery_time
			movement_controller.stop_movement()
			# Visual
			visuals.play_recovery()

func _exit_state(state: State) -> void:
	match state:
		State.DASH:
			hitbox_component.set_deferred("monitoring", false)

# --- LÓGICA DE CADA ESTADO ---

func _state_logic_chase() -> void:
	var dist = global_position.distance_to(_player_ref.global_position)
	
	if dist <= attack_range:
		change_state(State.PREPARE)
	else:
		var dir = global_position.direction_to(_player_ref.global_position)
		movement_controller.move_with_input(dir, normal_speed)
		visuals.rotate_towards(_player_ref.global_position, 0.1)

func _state_logic_prepare(delta: float) -> void:
	_state_timer -= delta
	visuals.rotate_towards(_player_ref.global_position, 5.0 * delta)
	
	if _state_timer <= 0:
		change_state(State.DASH)

func _state_logic_dash(delta: float) -> void:
	movement_controller.move_with_input(_dash_vector, dash_speed)
	
	_state_timer -= delta
	if _state_timer <= 0:
		change_state(State.RECOVERY)

func _state_logic_recovery(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0:
		change_state(State.CHASE)

# --- EVENTOS ---

func take_damage(amount: float, source: Node = null, push_force: float = 0.0) -> void:
	health_component.take_damage(amount, source)
	
	# Só aceita knockback se NÃO estiver dando Dash
	if _current_state != State.DASH and movement_controller:
		if source and push_force > 0:
			var dir = (global_position - source.global_position).normalized()
			movement_controller.apply_knockback(dir * push_force)

func _on_hit_player(_target: Node, _dmg: float) -> void:
	change_state(State.RECOVERY)
	
	if movement_controller:
		var recoil_dir = -_dash_vector 
		movement_controller.apply_knockback(recoil_dir * 600.0)

func _on_death() -> void:
	visuals.play_death()
	loot_component.drop_loot(global_position)
	queue_free()
