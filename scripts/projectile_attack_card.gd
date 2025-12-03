class_name ProjectileAttackCard extends AttackBehaviorCard

@export_group("Projectile Settings")
@export var projectile_scene: PackedScene # Arraste a cena do projétil aqui
@export var spread_degrees: float = 0.0   # 0 = Reto, 15 = Espalhado
@export var count_multiplier: int = 1     # Quantos projéteis por disparo base

func execute(target: Node2D, aim_direction: Vector2) -> void:
	var player = target as PlayerController
	if not player: 
		return # Segurança caso seja chamado por algo que não é o Player
	if not projectile_scene:
		push_warning("ProjectileAttackCard: Nenhuma cena de projétil atribuída!")
		return

	# 1. Busca estatísticas do Player (Data-Driven)
	var dmg = player.stats.get_stat("damage", 10.0)
	var spd = player.stats.get_stat("projectile_speed", 400.0)
	var area = player.stats.get_stat("area", 1.0)
	
	# Se tivermos um stat de "multishot", somamos com o da carta
	var total_count = count_multiplier + int(player.stats.get_stat("projectile_count", 0))
	
	# 2. Instancia os projéteis
	for i in range(total_count):
		var proj = projectile_scene.instantiate()
		
		# Calcula direção com spread (espalhamento)
		var final_dir = aim_direction
		if total_count > 1 or spread_degrees > 0:
			# Calcula ângulo de espalhamento centralizado
			var angle_offset = 0.0
			if total_count > 1:
				var spread_rad = deg_to_rad(spread_degrees)
				var step = spread_rad / (total_count - 1) if total_count > 1 else 0
				angle_offset = -spread_rad / 2.0 + (i * step)
			else:
				# Variação aleatória se for só 1 tiro com spread
				angle_offset = deg_to_rad(randf_range(-spread_degrees, spread_degrees))
			
			final_dir = aim_direction.rotated(angle_offset)
		
		# Adiciona à cena (Root) para não mover junto com o player
		player.get_tree().root.add_child(proj)
		
		# 3. Configura o projétil (Setup Pattern)
		# Passamos scale e cor baseados no player ou carta
		if proj.has_method("setup"):
			proj.setup(
				player.global_position,
				final_dir,
				spd,
				dmg,
				area,
				Color.WHITE
			)
			
		# 4. DISPARA SINAL (Crucial para a arquitetura)
		# Avisa que um objeto de ataque foi criado.
		# Cartas como "Rastro de Fogo" vão ouvir isso e pegar o 'proj' do dicionário.
		player.on_attack_triggered.emit({
			"source": player,
			"projectile": proj,
			"position": player.global_position,
			"direction": final_dir
		})
