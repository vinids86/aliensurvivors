class_name LootComponent extends Node

@export var drop_scene: PackedScene
@export var xp_value: float = 10.0
@export var drop_chance: float = 1.0 # 1.0 = 100%

func drop_loot(global_pos: Vector2) -> void:
	if drop_scene and randf() <= drop_chance:
		var item = drop_scene.instantiate()
		item.global_position = global_pos
		
		# Passagem segura de parâmetros
		if "xp_amount" in item:
			item.xp_amount = xp_value
		elif "amount" in item:
			item.amount = xp_value
			
		# Adiciona na raiz para não ser deletado com o inimigo
		get_tree().root.call_deferred("add_child", item)
