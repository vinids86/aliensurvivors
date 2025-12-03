class_name MeleeAttackCard extends AttackBehaviorCard

@export_group("Melee Settings")
@export var slash_scene: PackedScene # Cena com o script SimpleMeleeSlash
@export var offset_distance: float = 20.0 # Distância à frente do player
@export var attack_duration: float = 0.25
@export var knockback_power: float = 400.0

# CORREÇÃO: O tipo do argumento deve ser Node2D para bater com a classe pai.
# Renomeamos para 'target' para fazer o cast seguro logo abaixo.
func execute(target: Node2D, aim_direction: Vector2) -> void:
	var player = target as PlayerController
	if not player: 
		return # Segurança caso seja chamado por algo que não é o Player

	if not slash_scene:
		push_warning("MeleeAttackCard: Nenhuma cena de Slash atribuída!")
		return

	# 1. Busca estatísticas
	var dmg = player.stats.get_stat("damage", 10.0)
	var area = player.stats.get_stat("area", 1.0)
	
	# 2. Instancia o Slash
	var slash = slash_scene.instantiate()
	
	# IMPORTANTE: Adiciona como FILHO do Player para girar e andar junto com ele
	player.add_child(slash)
	
	# 3. Posiciona na frente
	# Como é filho, a posição (0,0) é o centro do player.
	# Movemos apenas no eixo X local (frente) se o Player já estiver rotacionado,
	# mas seu player rotaciona o _visual_pivot, não o nó raiz necessariamente.
	# Se o PlayerController raiz NÃO gira, usamos aim_direction para posicionar.
	
	slash.position = aim_direction * offset_distance
	slash.rotation = aim_direction.angle()
	
	# 4. Configura
	if slash.has_method("setup"):
		slash.setup(
			dmg,
			attack_duration,
			area,
			knockback_power,
			Color.WHITE # Usa a cor do player
		)
			
	# 5. Emite sinal (Para efeitos como Rastro de Fogo funcionarem aqui também)
	player.on_attack_triggered.emit({
		"source": player,
		"slash_object": slash,
		"position": slash.global_position,
		"direction": aim_direction
	})
