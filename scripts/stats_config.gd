class_name StatsConfig extends Resource

# Um dicionário simples é mais flexível que variáveis hardcoded para esse tipo de jogo
# Ex: stats["damage"], stats["area"], stats["projectile_count"]
@export var _base_values: Dictionary = {
	"move_speed": 220.0,
	"max_health": 100.0,
	"damage": 10.0,
	"cooldown": 1.0,
	"area": 1.0,           # Escala do ataque
	"projectile_speed": 400.0,
	"pickup_range": 100.0  # Raio de coleta de XP
}

# Modificadores temporários ou permanentes (multiplicadores)
var _modifiers: Dictionary = {}

func get_stat(stat_name: String, default_value: float = 0.0) -> float:
	if not _base_values.has(stat_name):
		return default_value
		
	var val = _base_values[stat_name]
	
	# Aplica modificadores se existirem (Ex: +10% de dano)
	if _modifiers.has(stat_name):
		# Aqui você pode implementar lógica complexa (Add vs Multiply)
		# Por enquanto, vamos assumir soma simples para facilitar
		val += _modifiers[stat_name]
		
	return val

func modify_stat(stat_name: String, value: float):
	if _base_values.has(stat_name):
		_base_values[stat_name] += value
	else:
		_base_values[stat_name] = value # Cria novo stat se não existir (flexibilidade)
