class_name IdyllicSlash extends Area2D

# --- CONFIGURAÇÃO ---
@export var damage: float = 5.0
@export var knockback_force: float = 100.0
@export var duration: float = 0.4 
@export var arc_angle: float = 130.0

# AJUSTE: Radius deve ser maior que o Width para criar o buraco
# Tente Radius = 200 e Width = 60
@export var radius: float = 200.0 
@export var width: float = 60.0 

@export_group("Audio")
@export var sfx_slash: AudioStream 

# Referências
@onready var visual_shape: ColorRect = $VisualRect
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D 

var _shader_mat: ShaderMaterial
var _tween: Tween
var _hit_enemies: Array[Node2D] = [] 

func setup(dmg: float, dur: float, scale_mod: float, kb: float, color_tint: Color) -> void:
	damage = dmg
	duration = max(dur, 0.3) 
	knockback_force = kb
	
	# Resetamos a escala para 1 para evitar confusão no raio.
	# O tamanho é controlado pelo 'radius' e tamanho do Rect.
	scale = Vector2.ONE 
	
	if visual_shape:
		# Garante que o Rect seja grande o suficiente para o raio definido
		# Se raio é 200, o Rect precisa ser pelo menos 400x400, colocamos 500 pra garantir
		var rect_dimension = (radius + width) * 2.2
		visual_shape.size = Vector2(rect_dimension, rect_dimension)
		# Centraliza
		visual_shape.position = -visual_shape.size / 2.0
		
		_shader_mat = visual_shape.material as ShaderMaterial
		if _shader_mat:
			_shader_mat = _shader_mat.duplicate()
			visual_shape.material = _shader_mat
			_shader_mat.set_shader_parameter("base_color", color_tint)
			_shader_mat.set_shader_parameter("arc_angle", arc_angle)

	_generate_collision_polygon()
	_start_animation()
	_play_sound()

func _ready() -> void:
	z_index = 10 
	monitorable = false
	monitoring = true
	body_entered.connect(_on_body_entered)

func _generate_collision_polygon() -> void:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.queue_free()
	
	var polygon = CollisionPolygon2D.new()
	var points = PackedVector2Array()
	
	var segments = 16 
	var half_angle_rad = deg_to_rad(arc_angle) / 2.0
	var start_angle = -half_angle_rad
	var end_angle = half_angle_rad
	var step = (end_angle - start_angle) / segments
	
	# IMPORTANTE: O raio do shader é relativo ao UV (0 a 1).
	# O shader desenha o anel em 0.7 do UV (raio 0.35 do rect total).
	# Vamos forçar a hitbox a seguir essa lógica se o raio não estiver batendo.
	# Mas o jeito mais fácil é ajustar o 'radius' manualmente no inspector até bater.
	
	var r_outer = radius + (width / 2.0)
	var r_inner = max(10.0, radius - (width / 2.0))
	
	# Borda Externa
	for i in range(segments + 1):
		var current_angle = start_angle + (step * i)
		var point = Vector2(cos(current_angle), sin(current_angle)) * r_outer
		points.append(point)
	
	# Borda Interna
	for i in range(segments, -1, -1):
		var current_angle = start_angle + (step * i)
		var point = Vector2(cos(current_angle), sin(current_angle)) * r_inner
		points.append(point)

	polygon.polygon = points
	add_child(polygon)

func _play_sound() -> void:
	if audio_player and sfx_slash:
		audio_player.stream = sfx_slash
		audio_player.pitch_scale = randf_range(0.9, 1.1)
		audio_player.play()

func _start_animation() -> void:
	if not _shader_mat and visual_shape:
		_shader_mat = visual_shape.material as ShaderMaterial
			
	if not _shader_mat:
		queue_free()
		return
		
	_tween = create_tween()
	
	_tween.tween_method(
		func(val): _shader_mat.set_shader_parameter("progress", val),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Hitbox ativa por 60% do tempo visual
	get_tree().create_timer(duration * 0.6).timeout.connect(func(): monitoring = false)
	
	var total_time = duration
	if sfx_slash: total_time = max(duration, sfx_slash.get_length())
	
	await get_tree().create_timer(total_time + 0.1).timeout
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController: return
	if body in _hit_enemies: return
	
	if body.has_method("take_damage"):
		_hit_enemies.append(body)
		var k_dir = (body.global_position - global_position).normalized()
		if body.has_method("apply_knockback"):
			body.apply_knockback(k_dir * knockback_force)
		body.take_damage(damage)
