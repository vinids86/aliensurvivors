class_name ExperienceComponent extends Node

## Componente para gerenciar XP, Níveis e Curva de Progressão.

signal on_xp_collected(amount: float)
signal on_level_up(new_level: int)

# --- CONFIGURAÇÃO ---
@export_group("Progression Settings")
@export var initial_xp_required: float = 100.0
@export var xp_growth_multiplier: float = 1.1  # +10% a cada nível
@export var xp_flat_increase: float = 25.0     # +25 XP fixo a cada nível

# --- ESTADO ---
var current_level: int = 1
var current_xp: float = 0.0
var xp_required: float

func _ready() -> void:
	xp_required = initial_xp_required

func add_xp(amount: float) -> void:
	current_xp += amount
	on_xp_collected.emit(amount)
	
	# Loop while caso ganhe XP suficiente para subir múltiplos níveis de uma vez
	while current_xp >= xp_required:
		_level_up()

func _level_up() -> void:
	current_xp -= xp_required
	current_level += 1
	
	# Fórmula de crescimento: (Anterior * 1.1) + 25
	xp_required = (xp_required * xp_growth_multiplier) + xp_flat_increase
	
	on_level_up.emit(current_level)
	print("LEVEL UP! Nível: %d | Próximo XP: %.0f" % [current_level, xp_required])

# Função auxiliar para pegar o progresso (0.0 a 1.0) para a barra de XP
func get_progress_ratio() -> float:
	if xp_required == 0: return 0.0
	return current_xp / xp_required
