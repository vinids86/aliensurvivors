class_name UpgradeCard extends Resource

@export var title: String = "New Upgrade"
@export_multiline var description: String = "Description here"
@export var icon: Texture2D

# Função virtual que será sobrescrita por cada carta específica
func apply(player: Node2D) -> void:
	push_warning("UpgradeCard.apply() não foi implementado em: " + resource_path)
