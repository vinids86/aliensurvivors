class_name HealthComponent extends Node

## Componente reutilizável para gerenciar Vida (HP), Dano e Cura.
## Pode ser usado no Player, Inimigos ou objetos destrutíveis.

signal on_health_changed(current: float, max_value: float)
signal on_damage_taken(amount: float, source: Node)
signal on_death

var current_health: float
var max_health: float

func initialize(max_value: float) -> void:
	max_health = max_value
	current_health = max_value
	# Emite inicialização para atualizar UI
	on_health_changed.emit(current_health, max_health)

func take_damage(amount: float, source: Node = null) -> void:
	if current_health <= 0: return # Já morreu
	
	current_health -= amount
	on_damage_taken.emit(amount, source)
	on_health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		current_health = 0
		on_death.emit()

func heal(amount: float) -> void:
	if current_health <= 0: return # Não cura mortos (por enquanto)
	
	current_health = min(current_health + amount, max_health)
	on_health_changed.emit(current_health, max_health)

func heal_percent(percent: float) -> void:
	var amount = max_health * percent
	heal(amount)

# Permite aumentar a vida máxima dinamicamente (ex: Upgrades)
func increase_max_health(amount_added: float, heal_amount: bool = true) -> void:
	max_health += amount_added
	if heal_amount:
		heal(amount_added)
	else:
		on_health_changed.emit(current_health, max_health)
