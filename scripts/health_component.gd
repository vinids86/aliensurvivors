class_name HealthComponent extends Node

## Componente genérico para gerir Vida, Dano e Cura.
## Pode ser usado pelo Jogador, Inimigos e objetos destrutíveis.

# --- SINAIS ---
# Emitido sempre que a vida muda (útil para atualizar barras de vida na UI)
signal on_health_changed(current: float, max_value: float)
# Emitido quando recebe dano (útil para piscar sprite, tocar som, floating text)
signal on_damage_taken(amount: float, source: Node)
# Emitido quando a vida chega a zero
signal on_death

# --- DADOS ---
var current_health: float
var max_health: float

# Deve ser chamado pelo dono (Player/Inimigo) no _ready()
func initialize(max_value: float) -> void:
	max_health = max_value
	current_health = max_value
	# Emite o estado inicial para garantir que a UI comece sincronizada
	on_health_changed.emit(current_health, max_health)

# Função principal de receber dano
func take_damage(amount: float, source: Node = null) -> void:
	if current_health <= 0: return # Já está morto, ignora
	
	current_health -= amount
	
	on_damage_taken.emit(amount, source)
	on_health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		current_health = 0
		on_death.emit()

# Função para curar
func heal(amount: float) -> void:
	if current_health <= 0: return # Opcional: não curar se já morreu
	
	current_health = min(current_health + amount, max_health)
	on_health_changed.emit(current_health, max_health)

# Cura baseada em porcentagem (útil para poções ou level up)
func heal_percent(percent: float) -> void:
	var amount = max_health * percent
	heal(amount)

# Permite aumentar a vida máxima (ex: upgrade passivo)
func increase_max_health(amount_added: float, heal_amount: bool = true) -> void:
	max_health += amount_added
	if heal_amount:
		heal(amount_added)
	else:
		on_health_changed.emit(current_health, max_health)
