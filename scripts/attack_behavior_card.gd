class_name AttackBehaviorCard extends UpgradeCard

# Define o tempo base entre ataques (pode ser modificado pelos stats do player)
@export var base_cooldown_override: float = -1.0 

# A lógica do ataque. O Player chama isso, mas não sabe o que acontece aqui dentro.
func execute(player: Node2D, direction: Vector2) -> void:
	push_warning("AttackBehaviorCard.execute() não foi implementado.")

# Atalho para aplicar: define este card como o ataque atual do player
func apply(player: Node2D) -> void:
	if "current_attack_behavior" in player:
		player.current_attack_behavior = self
		print("Ataque alterado para: " + title)
