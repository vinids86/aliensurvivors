class_name StatUpgradeCard extends UpgradeCard

@export_group("Stat Settings")
@export var stat_name: String = "move_speed" # Deve bater com as chaves do StatsConfig
@export var value_to_add: float = 10.0

func apply(player: Node2D) -> void:
	# Verificação de segurança
	var player_controller = player as PlayerController
	if not player_controller:
		push_warning("StatUpgradeCard: Alvo não é PlayerController")
		return

	if not player_controller.stats:
		push_error("StatUpgradeCard: Player não possui StatsConfig")
		return

	# 1. Aplica o valor no "Backend" (StatsConfig)
	player_controller.stats.modify_stat(stat_name, value_to_add)

	# 2. Side Effects (Atualizações Visuais/Físicas Imediatas)
	# Alguns atributos precisam de uma atualização instantânea no PlayerController
	match stat_name:
		"max_health":
			# Se aumentou a vida máxima, cura o player nesse valor para não ficar com a barra "vazia" no final
			player_controller.heal(value_to_add)
			
		"pickup_range":
			# O PlayerController tem um método para redimensionar o colisor do imã
			if player_controller.has_method("_update_magnet_radius"):
				player_controller._update_magnet_radius()
