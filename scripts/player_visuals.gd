class_name PlayerVisuals extends Node

## Gerencia Feedback Visual (Tweens, Shaders, Partículas) e Sonoro.
## Deve ser filho do PlayerController.

# --- DEPENDÊNCIAS ---
@export var sprite_ref: Sprite2D 
@export var audio_player: AudioStreamPlayer2D 

# --- CONFIGURAÇÃO VISUAL ---
@export_group("Colors")
@export var body_shader: Shader 
@export var color_head: Color = Color("4fffa0")
@export var color_damage: Color = Color("ff2a2a")
@export var color_dash: Color = Color(0.2, 1.0, 1.0)

@export_group("Audio Streams")
@export var sfx_hurt: AudioStream
@export var sfx_dash: AudioStream

# --- ESTADO INTERNO ---
var _shader_material: ShaderMaterial
var _tween_body: Tween 
var _shader_time_accum: float = 0.0
var _visual_pivot: Node2D 

# Usado para animação de "respiração" (Idle/Move)
var _time_alive: float = 0.0

func _ready() -> void:
	if sprite_ref:
		_visual_pivot = sprite_ref.get_parent()
		_setup_material()

func _process(delta: float) -> void:
	_time_alive += delta
	_update_shader_time(delta)

# --- INTERFACE PÚBLICA (Chamada pelo Player) ---

func update_idle_move_animation(delta: float, velocity_len: float) -> void:
	# Só executa animação de idle/move se não houver um Tween prioritário (Ataque/Dash) rodando
	if _tween_body and _tween_body.is_running(): return
	
	if not sprite_ref: return
	
	var target = Vector2(0.6, 0.6) # Escala base
	if velocity_len > 10.0:
		# Wobble ao andar
		target.x += sin(_time_alive * 15.0) * 0.05
	else:
		# Respiração parado
		target += Vector2(1, 1) * sin(_time_alive * 2.0) * 0.03
		
	sprite_ref.scale = sprite_ref.scale.lerp(target, 10.0 * delta)

func update_rotation(target_angle: float, delta: float) -> void:
	if _visual_pivot:
		_visual_pivot.rotation = lerp_angle(_visual_pivot.rotation, target_angle, 15 * delta)

func set_rotation_instant(angle: float) -> void:
	if _visual_pivot:
		_visual_pivot.rotation = angle

# --- EFEITOS ESPECÍFICOS ---

func play_hit_effect() -> void:
	_flash_color(color_damage, 0.2)
	_play_sfx(sfx_hurt)

func play_dash_start(duration: float) -> void:
	_play_sfx(sfx_dash)
	_tween_scale(Vector2(1.1, 0.4), 0.15)
	if _shader_material:
		_shader_material.set_shader_parameter("base_color", color_dash)

func play_attack_windup(duration: float) -> void:
	# Squash (Preparação)
	_tween_scale(Vector2(0.4, 0.8), duration)

func play_attack_execution() -> void:
	# Stretch (Disparo) + Flash
	_flash_color(Color.WHITE, 0.05)
	_tween_scale(Vector2(1.2, 0.4), 0.1)
	
	# Retorno automático ao normal
	await get_tree().create_timer(0.1).timeout
	_tween_scale(Vector2(0.6, 0.6), 0.2)

func reset_colors() -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("base_color", color_head)

# --- HELPERS INTERNOS ---

func _setup_material() -> void:
	if sprite_ref.material:
		_shader_material = sprite_ref.material.duplicate()
	elif body_shader:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = body_shader
	
	if _shader_material:
		_shader_material.set_shader_parameter("base_color", color_head)
		sprite_ref.material = _shader_material

func _tween_scale(target: Vector2, duration: float) -> void:
	if not sprite_ref: return
	if _tween_body: _tween_body.kill()
	
	_tween_body = create_tween()
	_tween_body.tween_property(sprite_ref, "scale", target, duration)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _flash_color(color: Color, duration: float) -> void:
	if not _shader_material: return
	_shader_material.set_shader_parameter("base_color", color)
	
	var tw = create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(reset_colors)

func _update_shader_time(delta: float) -> void:
	if _shader_material:
		# Acelera efeito se estiver "agitado" (ex: atacando), mas simplificamos aqui para constante por enquanto
		_shader_time_accum += delta
		_shader_material.set_shader_parameter("custom_time", _shader_time_accum)

func _play_sfx(stream: AudioStream) -> void:
	if audio_player and stream:
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.stream = stream
		audio_player.play()
