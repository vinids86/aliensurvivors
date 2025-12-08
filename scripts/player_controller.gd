class_name PlayerController extends CharacterBody2D

## Controlador principal da entidade Jogador.
## Arquitetura: Composição (Health, XP, Movement, Weapon, Visuals, Collector).
## Responsabilidade: Orquestrar inputs e conectar sinais entre componentes.

# --- SINAIS PÚBLICOS ---
signal on_attack_triggered(context_data: Dictionary) 
signal on_hit_received(source: Node, damage: float) 
signal on_level_up(current_level: int)
signal on_xp_collected(amount: float)
signal on_dash_used(cooldown_time: float)
signal on_death()

# --- COMPONENTES (Unique Names) ---
# Usamos % para acesso rápido na cena. Garanta que os nós tenham "Access as Unique Name".
@onready var health_component: HealthComponent = %HealthComponent
@onready var experience_component: ExperienceComponent = %ExperienceComponent
@onready var movement_controller: MovementController = %MovementController
@onready var weapon_manager: WeaponManager = %WeaponManager
@onready var player_visuals: PlayerVisuals = %PlayerVisuals
@onready var collector_component: CollectorComponent = %CollectorComponent

# Configuração Global de Stats (Velocidade, Dano, HP Max, etc)
@export var stats: StatsConfig

# --- CONFIGURAÇÃO FÍSICA ESPECÍFICA DO PLAYER ---
@export_group("Physics Params")
@export var self_knockback_force: float = 500.0
@export var self_knockback_duration: float = 0.15 

# --- ESTADO INTERNO ---
enum State { NORMAL, ATTACKING, KNOCKED_BACK, DASHING }
var _state: State = State.NORMAL

# Controle de Mira (Lógica de Jogo)
var _aim_rotation: float = 0.0

# --- GETTERS DE COMPATIBILIDADE ---
# Mantidos para que sistemas externos (HUD, Managers) possam ler dados sem saber dos componentes.

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
	_validate_dependencies()
	_initialize_components()

func _physics_process(delta: float) -> void:
	_sync_state_with_components()
	
	match _state:
		State.NORMAL:       _state_logic_normal(delta)
		State.ATTACKING:    _state_logic_attacking(delta)
		State.DASHING:      pass # Gerido pelo MovementController
		State.KNOCKED_BACK: pass # Gerido pelo MovementController
	
	_process_visual_updates(delta)

# ==============================================================================
# STATE MANAGEMENT
# ==============================================================================

func _sync_state_with_components() -> void:
	# Define a prioridade dos estados. Físico > Ação > Normal.
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
	# Permite cancelar o ataque com Dash
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if _check_dash_input(input_dir): 
		weapon_manager.cancel_attack()
		return
	
	# Durante ataque, aplicamos "fricção" para parar o personagem
	movement_controller.stop_movement()

# ==============================================================================
# INPUT HANDLING
# ==============================================================================

func _check_dash_input(input_dir: Vector2) -> bool:
	if Input.is_action_just_pressed("ui_focus_next") or Input.is_action_just_pressed("dash"):
		# Tenta executar o Dash no componente de movimento
		if movement_controller.attempt_dash(input_dir, _aim_rotation):
			on_dash_used.emit(movement_controller.dash_cooldown)
			
			# Feedback Visual
			if player_visuals: 
				player_visuals.play_dash_start(movement_controller.dash_duration)
			return true
	return false

func _check_combat_input() -> void:
	var type = ""
	if Input.is_action_pressed("attack_basic") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		type = "basic"
	elif Input.is_action_pressed("attack_special") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		type = "special"
	
	if type != "":
		# Atualiza a mira para a direção do input antes de disparar
		_update_aim_to_input()
		var aim_dir = Vector2.RIGHT.rotated(_aim_rotation)
		weapon_manager.attempt_attack(type, aim_dir)

# ==============================================================================
# EVENT HANDLERS (Sinais dos Componentes)
# ==============================================================================

func _on_weapon_windup(duration: float) -> void:
	if player_visuals:
		player_visuals.play_attack_windup(duration)

func _on_weapon_executed(recoil_dir: Vector2) -> void:
	# 1. Aplica Recuo Físico
	movement_controller.apply_knockback(recoil_dir * self_knockback_force, self_knockback_duration)
	
	# 2. Feedback Visual
	if player_visuals:
		player_visuals.play_attack_execution()

func _on_health_dmg(amount: float, source: Node) -> void:
	# Feedback Visual
	if player_visuals:
		player_visuals.play_hit_effect()
	
	# Notifica lógica do jogo (GameManager, UI)
	on_hit_received.emit(source, amount)

func _on_lvl_up(lvl: int) -> void:
	on_level_up.emit(lvl)
	# Regra de Jogo: Cura 20% ao subir de nível
	if health_component: 
		health_component.heal_percent(0.2)

# ==============================================================================
# VISUAL UPDATE LOOP
# ==============================================================================

func _process_visual_updates(delta: float) -> void:
	if not player_visuals: return
	
	# 1. Atualiza Rotação (Olhar)
	# Travamos a rotação durante ataques ou knockback para manter a mira/impacto
	if _state != State.ATTACKING and _state != State.KNOCKED_BACK:
		if velocity.length() > 0:
			_aim_rotation = lerp_angle(_aim_rotation, velocity.angle(), 15 * delta)
		
		player_visuals.update_rotation(_aim_rotation, delta)
	
	# 2. Animação de "Respiração/Wobble" (Apenas em estado normal)
	if _state == State.NORMAL:
		player_visuals.update_idle_move_animation(delta, velocity.length())

func _update_aim_to_input() -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		_aim_rotation = input_dir.angle()
	
	# Força o visual a rotacionar instantaneamente para a nova mira
	if player_visuals:
		player_visuals.set_rotation_instant(_aim_rotation)

# ==============================================================================
# SETUP & VALIDATION
# ==============================================================================

func _validate_dependencies() -> void:
	# Erros críticos que impedem o funcionamento
	if not movement_controller: push_error("Player: %MovementController ausente!")
	if not health_component: push_error("Player: %HealthComponent ausente!")
	if not weapon_manager: push_error("Player: %WeaponManager ausente!")
	
	# Avisos não-críticos (o jogo roda, mas sem feedback)
	if not player_visuals: push_warning("Player: %PlayerVisuals ausente! Feedback visual desativado.")
	if not collector_component: push_warning("Player: %CollectorComponent ausente! Coleta desativada.")

func _initialize_components() -> void:
	# Garante que Stats existe
	if not stats: stats = StatsConfig.new()
	
	# Inicializa Weapon Manager
	if weapon_manager:
		if not weapon_manager.on_attack_windup.is_connected(_on_weapon_windup):
			weapon_manager.on_attack_windup.connect(_on_weapon_windup)
		if not weapon_manager.on_attack_executed.is_connected(_on_weapon_executed):
			weapon_manager.on_attack_executed.connect(_on_weapon_executed)
	
	# Inicializa Health Component
	if health_component:
		if not health_component.on_damage_taken.is_connected(_on_health_dmg):
			health_component.on_damage_taken.connect(_on_health_dmg)
		if not health_component.on_death.is_connected(func(): on_death.emit()):
			health_component.on_death.connect(func(): on_death.emit())
		health_component.initialize(stats.get_stat("max_health", 100.0))

	# Inicializa XP Component
	if experience_component:
		if not experience_component.on_xp_collected.is_connected(func(a): on_xp_collected.emit(a)):
			experience_component.on_xp_collected.connect(func(a): on_xp_collected.emit(a))
		if not experience_component.on_level_up.is_connected(_on_lvl_up):
			experience_component.on_level_up.connect(_on_lvl_up)

	# Inicializa Collector Component
	if collector_component:
		collector_component.update_radius(stats.get_stat("pickup_range", 100.0))

# ==============================================================================
# PROXY METHODS (API Pública para outros objetos)
# ==============================================================================

func take_damage(amount: float, source: Node2D = null, force: float = 0.0) -> void:
	# Verifica invulnerabilidade (Dash)
	if movement_controller.is_dashing and movement_controller.dash_invulnerability: return
	
	# Aplica Knockback se houver fonte e força
	if source and force > 0:
		var dir = (global_position - source.global_position).normalized()
		movement_controller.apply_knockback(dir * force, 0.2)
	
	# Aplica Dano
	if health_component: health_component.take_damage(amount, source)

func add_xp(amount: float) -> void:
	if experience_component: experience_component.add_xp(amount)
