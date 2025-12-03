class_name DissolveShockwave extends Node2D

var _emitters: Array[CPUParticles2D] = []
var _current_radius: float = 0.0

# Chamado pelo SimpleMeleeSlash no início do ataque
func play_expansion(start_radius: float, end_radius: float, duration: float, color: Color) -> void:
	_spawn_multi_layered_particles(color)
	
	_current_radius = start_radius
	
	# Tween para expandir o raio das partículas junto com o ataque
	var tw = create_tween()
	tw.tween_property(self, "_current_radius", end_radius, duration)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Agenda o fim da emissão para quando o ataque "acabar" visualmente
	get_tree().create_timer(duration * 0.8).timeout.connect(_stop_emitting)
	
	# Auto-destruição segura (duração + tempo de vida das partículas)
	get_tree().create_timer(duration + 1.0).timeout.connect(queue_free)

func _process(_delta: float) -> void:
	# Atualiza o raio de emissão frame a frame
	if _emitters.size() > 0 and _emitters[0].emitting:
		for emitter in _emitters:
			_update_particle_ring_radius(emitter, _current_radius)

func _stop_emitting() -> void:
	for emitter in _emitters:
		emitter.emitting = false

# --- Configuração dos Emissores (Igual ao anterior, mas OneShot = False inicialmente) ---
func _spawn_multi_layered_particles(base_color: Color) -> void:
	var particle_texture = _create_particle_texture(base_color)
	
	# Camada Base
	_create_emitter(base_color, 150, particle_texture) # Reduzi um pouco para não travar (3 camadas x 400 = 1200)
	
	# Camadas de Variação
	var col_cool = base_color
	col_cool.h = wrapf(col_cool.h + 0.08, 0.0, 1.0)
	_create_emitter(col_cool, 70, particle_texture)
	
	var col_warm = base_color
	col_warm.h = wrapf(col_warm.h - 0.08, 0.0, 1.0)
	_create_emitter(col_warm, 70, particle_texture)

func _create_emitter(color: Color, count: int, texture: Texture2D) -> void:
	var emitter = CPUParticles2D.new()
	add_child(emitter)
	_emitters.append(emitter)
	
	emitter.texture = texture
	emitter.amount = count
	emitter.lifetime = 0.5
	emitter.emitting = true
	emitter.one_shot = false # IMPORTANTE: Contínuo durante a expansão
	emitter.explosiveness = 0.0 # Suave
	emitter.gravity = Vector2.ZERO
	emitter.local_coords = false # Fica no mundo
	
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	
	# Visual
	emitter.scale_amount_min = 1.0
	emitter.scale_amount_max = 3.0
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	emitter.scale_amount_curve = scale_curve
	
	emitter.color = color
	
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	emitter.color_ramp = gradient
	
	emitter.direction = Vector2.UP
	emitter.spread = 180.0
	emitter.initial_velocity_min = 40.0
	emitter.initial_velocity_max = 100.0

func _generate_ring_points(radius: float) -> PackedVector2Array:
	var points_count = 80
	var ring_points = PackedVector2Array()
	for i in range(points_count):
		var angle = (float(i) / points_count) * TAU
		var point_pos = Vector2(cos(angle), sin(angle)) * radius
		ring_points.append(point_pos)
	return ring_points

func _update_particle_ring_radius(emitter: CPUParticles2D, radius: float) -> void:
	emitter.emission_points = _generate_ring_points(radius)

func _create_particle_texture(target_color: Color) -> Texture2D:
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
