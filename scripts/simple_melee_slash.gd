class_name SimpleMeleeSlash extends Area2D

## Sistema de Ataque: Bubble Burst (FINAL - Posição Corrigida)
## Gera uma explosão de energia maleável usando desenho procedural direto.
## A explosão ocorre na posição exata fornecida pelo MeleeAttackCard, seguindo a mira do Player.

# --- CONFIGURAÇÃO ---
var damage: float = 10.0
var knockback_force: float = 600.0
var element_color: Color = Color("4fffa0") # Verde Neon

# Parâmetros Geométricos
var max_radius: float = 60.0       # Tamanho final da explosão
var burst_scale: float = 1.8       # Crescimento extra no estouro

# Variáveis de Animação (Controladas via Tween)
var _anim_radius_scale: float = 0.0 
var _anim_hole_size: float = 0.0    
var _anim_alpha: float = 1.0        

# Cache de Colisão
var _collision_poly: CollisionPolygon2D
var _last_poly_points: PackedVector2Array

func setup(dmg: float, duration: float, scale_mod: float, kb: float, col: Color) -> void:
	damage = dmg
	knockback_force = kb
	element_color = col
	
	scale = Vector2.ONE * scale_mod
	_start_bubble_animation(duration)

func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)
	
	# Cria Colisão (agora via código)
	_collision_poly = CollisionPolygon2D.new()
	_collision_poly.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	add_child(_collision_poly)
	
func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var current_r = max_radius * _anim_radius_scale
	if current_r <= 1.0: return

	# 1. Aura Externa (Brilho difuso)
	var color_aura = element_color
	color_aura.a = 0.2 * _anim_alpha
	draw_circle(Vector2.ZERO, current_r * 1.2, color_aura)
	
	# 2. Corpo Principal (Anel/Donut)
	var color_body = element_color
	color_body.a = 0.7 * _anim_alpha
	_draw_donut(current_r, _anim_hole_size, color_body)
	
	# 3. Highlight Borda (Corte mais nítido)
	if _anim_alpha > 0.05:
		var color_edge = Color.WHITE
		color_edge.a = 0.9 * _anim_alpha
		draw_arc(Vector2.ZERO, current_r, 0, TAU, 32, color_edge, 2.0)

	_update_collision(current_r, _anim_hole_size)

# Função para desenhar Círculo com Buraco (Donut)
func _draw_donut(outer_radius: float, hole_pct: float, color: Color) -> void:
	var segments = 32
	var inner_radius = outer_radius * hole_pct
	
	if inner_radius >= outer_radius - 1.0: return

	var points_out = PackedVector2Array()
	var points_in = PackedVector2Array()
	
	for i in range(segments + 1):
		var angle = (float(i) / segments) * TAU
		var dir = Vector2(cos(angle), sin(angle))
		
		points_out.append(dir * outer_radius)
		points_in.append(dir * inner_radius)
	
	var poly = points_out.duplicate()
	points_in.reverse()
	poly.append_array(points_in)
		
	draw_colored_polygon(poly, color)
	_last_poly_points = poly

func _update_collision(current_r: float, hole_pct: float) -> void:
	if _last_poly_points.is_empty(): return
	if _collision_poly:
		_collision_poly.polygon = _last_poly_points

func _start_bubble_animation(duration: float) -> void:
	monitoring = true
	
	_anim_radius_scale = 0.0
	_anim_hole_size = 0.0
	_anim_alpha = 1.0
	
	var tw = create_tween().set_parallel(true)
	
	# Tempo total é o tempo de explosão
	var forward_move = Vector2.RIGHT.rotated(rotation) * 20.0
	tw.tween_property(self, "position", position + forward_move, duration)
	# 1. Estouro Violento (Scale 0.0 -> Burst Scale)
	tw.tween_property(self, "_anim_radius_scale", burst_scale, duration)\
		.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		
	# 2. Abertura do Buraco (Com delay, começa um pouco depois)
	tw.tween_property(self, "_anim_hole_size", 1.0, duration * 0.75)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)\
		.set_delay(duration * 0.25)
		
	# 3. Sumir (Fade Out)
	tw.tween_property(self, "_anim_alpha", 0.0, duration * 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)\
		.set_delay(duration * 0.6) # Começa a sumir no final
	
	await tw.finished
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController or body.is_in_group("player"): return
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("apply_knockback"):
			var k_dir = (body.global_position - global_position).normalized()
			body.apply_knockback(k_dir * knockback_force)
