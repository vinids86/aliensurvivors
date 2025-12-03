class_name SimpleMeleeSlash extends Area2D

# Configurações de Gameplay
var damage: float = 10.0
var knockback_force: float = 0.0

# Visual & Geometria
var slash_color: Color = Color.WHITE
var width_scale: float = 1.0
var length_scale: float = 1.0
var base_arc_angle: float = 130.0 # Graus base (Cartas podem alterar isso no futuro)
var distance_from_player: float = 25.0

# Cache de geometria para não recalcular duas vezes (Draw e Physics) no mesmo frame
var _current_poly_points: PackedVector2Array = []

# Referência ao Colisor Dinâmico
var _collision_poly: CollisionPolygon2D

func setup(dmg: float, duration: float, scale_mod: float, kb: float, col: Color):
	damage = dmg
	knockback_force = kb
	slash_color = col
	
	scale = Vector2.ONE * scale_mod
	rotation = rotation + randf_range(-0.05, 0.05)
	
	_animate_slash(duration)

func _ready():
	monitoring = false
	body_entered.connect(_on_body_entered)
	
	# Cria o colisor dinâmico via código para garantir que ele exista
	_collision_poly = CollisionPolygon2D.new()
	# Otimização: Builds de colisão podem ser pesados, use 'Segments' se der lag, 
	# mas 'Solids' é mais preciso para áreas.
	_collision_poly.build_mode = CollisionPolygon2D.BUILD_SOLIDS 
	add_child(_collision_poly)

func _process(_delta):
	# Não usamos _process, a animação é controlada pelo Tween
	pass

# A MÁGICA ACONTECE AQUI: Uma função gera os pontos para AMBOS os sistemas
func _update_geometry():
	var radius = distance_from_player
	var arc_height = 35.0 * width_scale
	var span_angle = deg_to_rad(base_arc_angle) * length_scale
	
	var points_outer = PackedVector2Array()
	var points_inner = PackedVector2Array()
	
	var resolution = 16 # Resolução reduzida levemente para performance física
	
	for i in range(resolution + 1):
		var t = float(i) / resolution
		var angle = lerp(-span_angle / 2.0, span_angle / 2.0, t)
		var dir = Vector2(cos(angle), sin(angle))
		
		# Perfil da lâmina
		var thickness_profile = 1.0 - pow(2.0 * t - 1.0, 2)
		var current_width = thickness_profile * arc_height
		
		points_outer.append(dir * (radius + current_width))
		points_inner.append(dir * radius)
	
	# Monta o polígono final fechado
	var poly = points_outer.duplicate()
	var reversed_inner = points_inner.duplicate()
	reversed_inner.reverse()
	poly.append_array(reversed_inner)
	
	# 1. Atualiza cache para o desenho
	_current_poly_points = poly
	
	# 2. Atualiza a Colisão FÍSICA instantaneamente
	if _collision_poly:
		_collision_poly.polygon = poly

func _draw():
	if _current_poly_points.is_empty(): return
	
	# Usa os pontos calculados no _update_geometry
	var body_color = slash_color
	body_color.a = 0.8
	draw_colored_polygon(_current_poly_points, body_color)
	
	# Desenha o fio de corte (apenas a metade externa dos pontos)
	# Como o array é [outer... , inner...], a metade inicial é o outer
	var half_count = _current_poly_points.size() / 2
	var outer_line = _current_poly_points.slice(0, half_count)
	draw_polyline(outer_line, slash_color, 2.5)

func _animate_slash(duration: float):
	monitoring = true
	
	# Estado inicial
	width_scale = 0.1
	length_scale = 0.4
	modulate.a = 1.0
	
	# Gera a geometria inicial antes do primeiro frame
	_update_geometry()
	queue_redraw()
	
	var tw = create_tween().set_parallel(true)
	
	# Animações de Parâmetros
	tw.tween_property(self, "length_scale", 1.1, duration * 0.35)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	var width_tw = create_tween()
	width_tw.tween_property(self, "width_scale", 1.4, duration * 0.2)\
		.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	width_tw.tween_property(self, "width_scale", 0.0, duration * 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Avanço físico
	var forward_move = Vector2.RIGHT.rotated(rotation) * 20.0
	tw.tween_property(self, "position", position + forward_move, duration)
	
	# LOOP DE SINCRONIA:
	# A cada frame da animação, recalculamos a geometria.
	# Isso garante que a colisão cresça junto com o desenho.
	tw.tween_method(func(_v): 
		_update_geometry()
		queue_redraw(), 
		0.0, 1.0, duration)
	
	# Fade out
	tw.tween_property(self, "modulate:a", 0.0, duration * 0.3).set_delay(duration * 0.7)
	
	await tw.finished
	queue_free()

func _on_body_entered(body):
	if body == get_parent(): return
	
	if body.has_method("take_damage"):
		var knock_dir = (body.global_position - global_position).normalized()
		body.call("take_damage", damage)
		if body.has_method("apply_knockback"):
			body.call("apply_knockback", knock_dir * knockback_force)
