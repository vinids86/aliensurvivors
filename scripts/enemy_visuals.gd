class_name EnemyVisuals extends Node

## Componente responsável por Feedback Visual e Sonoro (VFX/SFX).
## Deve ser adicionado como filho do Inimigo.

# --- DEPENDÊNCIAS (OBRIGATÓRIO: Arraste os nós da cena para cá no Inspector) ---
@export var visual_body: CanvasItem # OBRIGATÓRIO: O nó ColorRect ou Sprite
@export var trail_particles: GPUParticles2D # OBRIGATÓRIO: O nó de partículas

# --- CONFIGURAÇÃO DE ÁUDIO ---
@export_group("Audio")
@export var sfx_charge: AudioStream
@export var sfx_dash: AudioStream
@export var sfx_hit: AudioStream
@export var sfx_death: AudioStream

# --- VARIAVEIS INTERNAS ---
var _shader_mat: ShaderMaterial
var _original_scale: Vector2 = Vector2.ONE
var _parent: Node2D 

# Tweens Controlados
var _scale_tween: Tween

func _ready() -> void:
	if get_parent() is Node2D:
		_parent = get_parent()
		
	if visual_body:
		_original_scale = visual_body.scale
		
		# Configuração do Shader (Apenas para deformação de charge/shake)
		if visual_body.material is ShaderMaterial:
			visual_body.material = visual_body.material.duplicate()
			_shader_mat = visual_body.material as ShaderMaterial

# --- INTERFACE PÚBLICA (Comandos) ---

func play_hit_feedback() -> void:
	# 1. Som
	_play_sfx(sfx_hit)
	
	# 2. Squash (Amassar) - Feedback Físico
	_start_scale_tween()
	# Amassa: Escala X aumenta, Y diminui (efeito de impacto)
	_scale_tween.tween_property(visual_body, "scale", _original_scale * Vector2(1.4, 0.6), 0.05)
	# Volta ao normal com efeito elástico
	_scale_tween.tween_property(visual_body, "scale", _original_scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func play_charge_buildup(duration: float) -> void:
	_play_sfx(sfx_charge)
	
	# Animação de "Inchar" e Tremer
	_start_scale_tween()
	_scale_tween.set_parallel(true)
	_scale_tween.tween_property(visual_body, "scale", _original_scale * Vector2(0.5, 1.5), duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	if _shader_mat:
		var st = create_tween().set_parallel(true)
		st.tween_property(_shader_mat, "shader_parameter/charge_level", 1.0, duration)
		st.tween_property(_shader_mat, "shader_parameter/shake_power", 30.0, duration)

func play_dash_start(duration: float) -> void:
	_play_sfx(sfx_dash)
	
	if trail_particles:
		trail_particles.emitting = true
	
	# Estica no sentido do movimento
	_start_scale_tween()
	_scale_tween.tween_property(visual_body, "scale", _original_scale * Vector2(2.5, 0.4), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func play_recovery() -> void:
	if trail_particles:
		trail_particles.emitting = false
		
	# Volta ao normal
	_start_scale_tween()
	_scale_tween.set_parallel(true)
	_scale_tween.tween_property(visual_body, "scale", _original_scale, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	if _shader_mat:
		var st = create_tween().set_parallel(true)
		st.tween_property(_shader_mat, "shader_parameter/charge_level", 0.0, 0.2)
		st.tween_property(_shader_mat, "shader_parameter/shake_power", 0.0, 0.2)

func play_death() -> void:
	_play_sfx(sfx_death)
	_spawn_death_particles()

func rotate_towards(target_pos: Vector2, speed: float) -> void:
	var current_pos = visual_body.global_position if "global_position" in visual_body else _parent.global_position
	var angle = current_pos.angle_to_point(target_pos)
	visual_body.rotation = lerp_angle(visual_body.rotation, angle, speed)

func get_facing_direction() -> Vector2:
	return Vector2.RIGHT.rotated(visual_body.rotation)

# --- AUXILIARES ---

func _start_scale_tween() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()

func _play_sfx(stream: AudioStream) -> void:
	if stream and has_node("/root/AudioManager") and _parent:
		get_node("/root/AudioManager").play_sfx_2d(stream, _parent.global_position)

func _spawn_death_particles() -> void:
	if not _parent: return
	
	var explosion = GPUParticles2D.new()
	explosion.emitting = false
	explosion.amount = 25
	explosion.lifetime = 0.6
	explosion.one_shot = true
	explosion.explosiveness = 1.0
	explosion.global_position = _parent.global_position
	explosion.z_index = 10
	
	var mat = ParticleProcessMaterial.new()
	mat.gravity = Vector3.ZERO
	mat.spread = 180.0
	mat.initial_velocity_min = 150.0
	mat.initial_velocity_max = 300.0
	mat.damping_min = 100.0 
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	
	# Gradiente Original (Laranja -> Vermelho Transparente)
	var grad = Gradient.new()
	grad.colors = [Color(1.0, 0.4, 0.1, 1.0), Color(1.0, 0.1, 0.0, 0.0)]
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	
	explosion.process_material = mat
	
	# Textura Original (Bolinha suave gerada via código)
	var tex = GradientTexture2D.new()
	tex.width = 16
	tex.height = 16
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var tgrad = Gradient.new()
	tgrad.set_color(0, Color.WHITE)
	tgrad.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = tgrad
	explosion.texture = tex
	
	get_tree().root.call_deferred("add_child", explosion)
	explosion.finished.connect(explosion.queue_free)
	explosion.call_deferred("set_emitting", true)
