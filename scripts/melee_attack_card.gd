class_name MeleeAttackCard extends AttackBehaviorCard

@export_group("Melee Settings")
@export var slash_scene: PackedScene # Cena com o script SimpleMeleeSlash
@export var offset_distance: float = 20.0 # Distância à frente do player
@export var attack_duration: float = 0.25
@export var knockback_power: float = 400.0

func execute(target: Node2D, aim_direction: Vector2) -> void:
	var player = target as PlayerController
	if not player: 
		return 

	if not slash_scene:
		push_warning("MeleeAttackCard: Nenhuma cena de Slash atribuída!")
		return

	# 1. Busca estatísticas dinâmicas do Player
	var dmg = player.stats.get_stat("damage", 10.0)
	var area = player.stats.get_stat("area", 1.0)
	
	# 2. Instancia o Slash
	var slash = slash_scene.instantiate()
	
	# 3. Adiciona à raiz da cena (Root)
	# O ataque é adicionado à raiz da árvore para ser independente do transform do Player.
	# Isso permite que o efeito permaneça no local do golpe mesmo se o player se mover.
	player.get_tree().root.add_child(slash)
	
	# 4. Posicionamento Global
	# Calcula a posição de spawn no mundo baseada na posição atual do player + offset.
	var spawn_position = player.global_position + (aim_direction * offset_distance)
	
	slash.global_position = spawn_position
	slash.rotation = aim_direction.angle()
	
	# 5. Configura parâmetros de combate (Dano, Tamanho, Knockback)
	if slash.has_method("setup"):
		slash.setup(
			dmg,
			attack_duration,
			area,
			knockback_power,
			Color.WHITE 
		)
			
	# 6. Notifica o sistema de eventos
	player.on_attack_triggered.emit({
		"source": player,
		"slash_object": slash,
		"position": slash.global_position,
		"direction": aim_direction
	})
