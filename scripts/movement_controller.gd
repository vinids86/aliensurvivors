class_name MovementController extends Node

## Componente responsável pela física de movimento, Dash e Knockback.
## Deve ser filho de um CharacterBody2D.

signal on_dash_started(duration: float)
signal on_dash_ended
signal on_dash_cooldown_changed(current_cooldown: float)

# --- DEPENDÊNCIAS ---
# O corpo que será movido (geralmente o pai)
@export var body: CharacterBody2D
# Para ler velocidade de movimento (opcional, pode ser passado via função)
@export var stats: StatsConfig

# --- CONFIGURAÇÃO ---
@export_group("Dash Settings")
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.3
@export var dash_cooldown: float = 1.5
@export var dash_invulnerability: bool = true

@export_group("Physics")
@export var knockback_decay: float = 8.0 # Quão rápido o knockback desacelera

# --- ESTADO INTERNO ---
var is_dashing: bool = false
var is_knocked_back: bool = false

var _dash_direction: Vector2 = Vector2.ZERO
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	if not body and get_parent() is CharacterBody2D:
		body = get_parent()

func _physics_process(delta: float) -> void:
	if not body: return
	
	_process_timers(delta)
	
	# Prioridade de Movimento: Knockback > Dash > Normal
	if is_knocked_back:
		_process_knockback(delta)
	elif is_dashing:
		_process_dash(delta)
	
	# Nota: O movimento normal é chamado explicitamente pelo Player
	# quando ele NÃO está em estados especiais, para dar controle total ao Input.

func _process_timers(delta: float) -> void:
	if _dash_timer > 0:
		_dash_timer -= delta
		if _dash_timer <= 0:
			_end_dash()

	if _dash_cooldown_timer > 0:
		_dash_cooldown_timer -= delta

# --- INTERFACE PÚBLICA ---

# Chamado pelo Player no _physics_process quando no estado NORMAL
func move_with_input(input_dir: Vector2, speed_override: float = -1.0) -> void:
	if is_dashing or is_knocked_back: return
	
	var final_speed = 200.0 # Valor padrão interno
	
	# Prioridade 1: Valor passado pelo Inimigo (Override)
	if speed_override > 0:
		final_speed = speed_override
	# Prioridade 2: Sistema de Stats (usado pelo Player)
	elif stats:
		final_speed = stats.get_stat("move_speed", 200.0)
	
	body.velocity = input_dir * final_speed
	body.move_and_slide()

# Chamado pelo Player para tentar dar Dash
func attempt_dash(input_dir: Vector2, visual_rotation: float) -> bool:
	if _dash_cooldown_timer > 0 or is_dashing: return false
	
	# Direção do Dash
	var dir = input_dir
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(visual_rotation)
	_dash_direction = dir.normalized()
	
	# Inicia Estado
	is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	
	on_dash_started.emit(dash_duration)
	return true

# Chamado pelo Player ou Inimigos para empurrar esta entidade
func apply_knockback(force_vector: Vector2, duration: float = 0.2) -> void:
	if is_dashing and dash_invulnerability: return
	
	is_knocked_back = true
	_knockback_velocity = force_vector
	
	# Timeout de segurança para sair do estado de knockback
	get_tree().create_timer(duration).timeout.connect(func():
		is_knocked_back = false
		_knockback_velocity = Vector2.ZERO
	, CONNECT_ONE_SHOT)

# Força uma parada (ex: durante ataque)
func stop_movement() -> void:
	if body:
		body.velocity = Vector2.ZERO

# --- LÓGICA INTERNA ---

func _process_dash(_delta: float) -> void:
	body.velocity = _dash_direction * dash_speed
	body.move_and_slide()

func _end_dash() -> void:
	is_dashing = false
	# Inércia residual ao sair do dash
	if stats:
		body.velocity = _dash_direction * stats.get_stat("move_speed", 200.0)
	on_dash_ended.emit()

func _process_knockback(delta: float) -> void:
	body.velocity = _knockback_velocity
	body.move_and_slide()
	
	# Fricção
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, knockback_decay * delta)
	
	if _knockback_velocity.length_squared() < 50:
		is_knocked_back = false
		_knockback_velocity = Vector2.ZERO
