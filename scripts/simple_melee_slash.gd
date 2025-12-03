class_name SimpleMeleeSlash extends Area2D

## Visual: "Sonic Boom" (Impacto Geométrico Puro)
## Um círculo perfeito que expande violentamente.
## Foca em contraste (Branco -> Cor), velocidade e clareza da hitbox.

# --- CONFIGURAÇÃO ---
var damage: float = 10.0
var knockback_force: float = 500.0 
var element_color: Color = Color("4fffa0") # Verde Neon Padrão

# Geometria
var max_radius: float = 55.0       
var initial_radius: float = 5.0    
var decay_radius: float = 0.5      

# Variáveis de Animação
var _current_radius: float = 0.0
var _anim_width: float = 20.0      
var _anim_alpha: float = 1.0
var _core_flash: float = 1.0       

# Cache de Colisão
var _collision_shape: CollisionShape2D
var _circle_shape: CircleShape2D

# Componente de Partículas (Lista de Emissores para Variação de Cor)
var _emitters: Array[CPUParticles2D] = []

func setup(dmg: float, duration: float, scale_mod: float, kb: float, col: Color) -> void:
	damage = dmg
	knockback_force = kb
	
	# Sobrescreve se for branco (padrão genérico)
	if col == Color.WHITE:
		element_color = Color("4fffa0") 
	else:
		element_color = col
	
	scale = Vector2.ONE * scale_mod
	_start_impact_animation(duration)

func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)
	
	_collision_shape = CollisionShape2D.new()
	_circle_shape = CircleShape2D.new()
	_collision_shape.shape = _circle_shape
	add_child(_collision_shape)

func _process(_delta: float) -> void:
	queue_redraw()
	
	# Atualiza o raio de TODOS os emissores
	for emitter in _emitters:
		if emitter and emitter.emitting:
			_update_particle_ring_radius(emitter, _current_radius)

func _draw() -> void:
	if _current_radius <= 1.0: return

	# 1. Onda de Choque
	var color_wave = element_color
	color_wave.a = 0.8 * _anim_alpha
	
	if _anim_width > 0.5:
		draw_arc(Vector2.ZERO, _current_radius, 0, TAU, 64, color_wave, _anim_width)
	
	# 2. Flash Central
	if _core_flash > 0.01:
		var color_core = Color.WHITE
		color_core.a = _core_flash * 0.9
		draw_circle(Vector2.ZERO, _current_radius * 0.85, color_core)

	_update_collision(_current_radius)

func _update_collision(radius: float) -> void:
	if _circle_shape:
		_circle_shape.radius = radius

# Cria as camadas de partículas com cores distintas
func _spawn_multi_layered_particles(base_color: Color) -> void:
	# Textura Compartilhada (Otimização)
	var particle_texture = _create_particle_texture()
	
	# Camada 1: Cor Base (Dominante - 500 partículas)
	_create_single_emitter(base_color, 200, particle_texture)
	
	# Camada 2: Variação Azulada/Fria (Hue Shift +0.08 - 250 partículas)
	var col_cool = base_color
	col_cool.h = wrapf(col_cool.h + 0.08, 0.0, 1.0)
	_create_single_emitter(col_cool, 50, particle_texture)
	
	# Camada 3: Variação Quente/Amarelada (Hue Shift -0.08 - 250 partículas)
	var col_warm = base_color
	col_warm.h = wrapf(col_warm.h - 0.08, 0.0, 1.0)
	_create_single_emitter(col_warm, 50, particle_texture)

# Função auxiliar para criar um único emissor
func _create_single_emitter(color: Color, count: int, texture: Texture2D) -> void:
	var emitter = CPUParticles2D.new()
	add_child(emitter)
	_emitters.append(emitter)
	
	emitter.texture = texture
	emitter.amount = count
	emitter.lifetime = 0.5 
	emitter.emitting = true
	emitter.one_shot = false 
	emitter.explosiveness = 0.0
	emitter.gravity = Vector2.ZERO
	emitter.local_coords = false 
	
	# Emissão (Anel)
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	_update_particle_ring_radius(emitter, initial_radius)
	
	# Tamanho
	emitter.scale_amount_min = 1.0
	emitter.scale_amount_max = 3.0
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	emitter.scale_amount_curve = scale_curve
	
	# Cor Sólida (Garantia de Variação)
	emitter.color = color
	
	# Gradiente de Fade Out (Apenas Alpha)
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	emitter.color_ramp = gradient
	
	# Movimento
	emitter.direction = Vector2.UP
	emitter.spread = 180.0
	emitter.initial_velocity_min = 40.0
	emitter.initial_velocity_max = 100.0

func _create_particle_texture() -> Texture2D:
	var tex = GradientTexture2D.new()
	tex.width = 12 
	tex.height = 12
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5) 
	tex.fill_to = Vector2(0.5, 0.0)   
	var g = Gradient.new()
	g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)]) 
	tex.gradient = g
	return tex

func _update_particle_ring_radius(emitter: CPUParticles2D, radius: float) -> void:
	var points_count = 120
	var ring_points = PackedVector2Array()
	
	for i in range(points_count):
		var angle = (float(i) / points_count) * TAU
		var point_pos = Vector2(cos(angle), sin(angle)) * radius
		ring_points.append(point_pos)
		
	emitter.emission_points = ring_points

func _start_impact_animation(duration: float) -> void:
	monitoring = true
	_current_radius = initial_radius
	_anim_width = 20.0 
	_core_flash = 1.0
	_anim_alpha = 1.0
	
	# Inicia o sistema de partículas multicamada
	_spawn_multi_layered_particles(element_color)
	
	var tw = create_tween().set_parallel(true)
	
	# Animações
	tw.tween_property(self, "_current_radius", max_radius, duration)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_anim_width", 2.0, duration * 0.8)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_core_flash", 0.0, duration * 0.3)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_anim_alpha", 0.0, duration * 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)\
		.set_delay(duration * 0.6)
	
	await tw.finished
	
	monitoring = false
	
	# Finalização de todos os emissores
	for emitter in _emitters:
		emitter.emitting = false
	
	# Espera o tempo de vida das partículas (0.5s) antes de morrer
	await get_tree().create_timer(0.6).timeout
	
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController or body.is_in_group("player"): return
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("apply_knockback"):
			var k_dir = (body.global_position - global_position).normalized()
			body.apply_knockback(k_dir * knockback_force)
