class_name MeleeAttackCard extends AttackBehaviorCard

@export_group("Melee Settings")
@export var slash_scene: PackedScene 
@export var offset_distance: float = 20.0 
@export var attack_duration: float = 0.25 # Valor Base
@export var knockback_power: float = 400.0

func execute(target: Node2D, aim_direction: Vector2) -> void:
	var player = target as PlayerController
	if not player: return 
	if not slash_scene: return

	# 1. Busca estatísticas (MODIFICADO)
	var dmg = player.stats.get_stat("damage", 10.0)
	var area_mod = player.stats.get_stat("area", 1.0) # Multiplicador de tamanho
	
	# NOVO: Busca bônus de duração. Default 0.0, pois queremos somar ao base.
	var duration_bonus = player.stats.get_stat("duration", 0.0)
	var final_duration = attack_duration + duration_bonus
	
	# 2. Instancia
	var slash = slash_scene.instantiate()
	player.get_tree().root.add_child(slash)
	
	# 3. Posicionamento
	var spawn_position = player.global_position + (aim_direction * offset_distance)
	slash.global_position = spawn_position
	slash.rotation = aim_direction.angle()
	
	# 4. Configura (MODIFICADO)
	if slash.has_method("setup"):
		slash.setup(
			dmg,
			final_duration, # Passamos o valor calculado
			area_mod,
			knockback_power,
			Color.WHITE
		)
			
	player.on_attack_triggered.emit({
		"source": player,
		"slash_object": slash,
		"position": slash.global_position,
		"direction": aim_direction
	})
