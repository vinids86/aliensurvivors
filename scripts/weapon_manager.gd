class_name WeaponManager extends Node

## Gerencia ataques, cooldowns e a sequência de disparo.
## Deve ser filho de um PlayerController.

# Sinais para o Player reagir visualmente/fisicamente
signal on_attack_windup(duration: float)     # Início da animação (Squash)
signal on_attack_executed(recoil_vector: Vector2) # Momento do tiro (Recuo)
signal on_attack_finished                    # Fim da sequência

@export var body: CharacterBody2D
@export var stats: StatsConfig

@export_group("Arsenal")
@export var basic_attack_card: AttackBehaviorCard
@export var special_attack_card: AttackBehaviorCard

# Estado interno
var _timers = { "basic": 0.0, "special": 0.0 }
var is_busy: bool = false # Se está no meio de uma sequência de ataque

func _ready() -> void:
	if not body and get_parent() is CharacterBody2D:
		body = get_parent()

func _physics_process(delta: float) -> void:
	# Atualiza cooldowns
	for k in _timers:
		if _timers[k] > 0: _timers[k] -= delta

# Tenta iniciar uma sequência de ataque
func attempt_attack(type: String, aim_direction: Vector2) -> bool:
	if is_busy: return false # Não ataca se já estiver atacando
	if _timers.has(type) and _timers[type] > 0: return false
	
	var card = basic_attack_card if type == "basic" else special_attack_card
	if not card: return false
	
	_start_sequence(card, type, aim_direction)
	return true

# Corrotina da sequência de ataque
func _start_sequence(card: AttackBehaviorCard, type: String, dir: Vector2) -> void:
	is_busy = true
	
	# 1. Calcular tempos
	var base_cd = stats.get_stat("cooldown", 1.0) if stats else 1.0
	if card.base_cooldown_override > 0: base_cd = card.base_cooldown_override
	
	_timers[type] = base_cd
	
	var t_windup = max(base_cd * 0.35, 0.05)
	
	# 2. Notificar Player para iniciar animação (Windup)
	on_attack_windup.emit(t_windup)
	
	# Espera o tempo de preparação
	await get_tree().create_timer(t_windup).timeout
	
	# Verifica se o ataque ainda é válido (ex: Player não morreu ou stunou)
	if not is_instance_valid(body): return
	
	# 3. Execução (Tiro + Recuo)
	card.execute(body, dir)
	
	# O recuo é sempre oposto ao tiro
	on_attack_executed.emit(-dir)
	
	# Pequeno delay pós-disparo antes de liberar para outra ação
	await get_tree().create_timer(0.15).timeout
	
	is_busy = false
	on_attack_finished.emit()

# Força cancelamento (ex: ao dar Dash)
func cancel_attack() -> void:
	is_busy = false
