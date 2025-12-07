class_name GameCamera extends Camera2D

# --- CONFIGURAÇÕES ---
@export_group("Follow")
@export var target: Node2D
@export var smooth_speed: float = 5.0
@export var offset_position: Vector2 = Vector2.ZERO

@export_group("Trauma Shake")
@export var decay_rate: float = 0.8  # Quão rápido o tremor para (0.0 a 1.0)
@export var max_offset: Vector2 = Vector2(100, 75) # Deslocamento máximo em pixels
@export var max_roll: float = 0.1    # Rotação máxima em radianos
@export var noise_speed: float = 1.5 # Velocidade da troca de direção do tremor

@export_group("Visual FX Connection")
# Arraste o ColorRect com o shader de aberração cromática aqui
@export var post_process_rect: ColorRect 

# --- ESTADO INTERNO ---
var _trauma: float = 0.0 # Valor atual de 0.0 a 1.0
var _noise_y: float = 0.0
var _noise = FastNoiseLite.new() # Gerador de ruído para movimento orgânico
var _default_zoom: Vector2 = Vector2.ONE

func _ready() -> void:
	_default_zoom = zoom
	randomize()
	_noise.seed = randi()
	_noise.frequency = 0.5
	_noise.fractal_octaves = 2

func _process(delta: float) -> void:
	# 1. Decaimento do Trauma (Linear)
	if _trauma > 0:
		_trauma = max(_trauma - decay_rate * delta, 0.0)
		
	# 2. Aplica o Shake
	_apply_shake(delta)
	
	# 3. Atualiza o Shader (Glitch visual)
	if post_process_rect and post_process_rect.material:
		# Passa o trauma para o shader
		post_process_rect.material.set_shader_parameter("chaos_level", _trauma)

func _physics_process(delta: float) -> void:
	if not target: return
	
	# Segue o alvo suavemente (Lógica original mantida)
	var target_pos = target.global_position + offset_position
	global_position = global_position.lerp(target_pos, smooth_speed * delta)

# --- SISTEMA DE TRAUMA ---

func add_trauma(amount: float) -> void:
	# Adiciona trauma, limitando a 1.0. 
	# Usa max() para garantir que um impacto leve não reduza um impacto forte existente.
	_trauma = min(_trauma + amount, 1.0)

func _apply_shake(delta: float) -> void:
	# O "Pulo do Gato": O shake é o quadrado do trauma.
	# Trauma 0.5 = Shake 0.25 | Trauma 0.9 = Shake 0.81
	var shake_power = _trauma * _trauma
	
	# Avança no ruído
	_noise_y += noise_speed 
	
	# Calcula offset usando ruído perlin (muito mais suave que randf())
	var noise_x = _noise.get_noise_2d(_noise.seed, _noise_y)
	var noise_y = _noise.get_noise_2d(_noise.seed + 1, _noise_y)
	var noise_r = _noise.get_noise_2d(_noise.seed + 2, _noise_y)
	
	# Aplica offset na câmera (offset é propriedade nativa do Camera2D)
	offset.x = max_offset.x * shake_power * noise_x
	offset.y = max_offset.y * shake_power * noise_y
	
	# Aplica rotação leve
	rotation = max_roll * shake_power * noise_r

# --- ZOOM DINÂMICO ---

func zoom_kick(amount: Vector2 = Vector2(0.05, 0.05), duration: float = 0.2) -> void:
	# Cria um efeito de "soco" no zoom (Zoom In rápido -> Volta suave)
	var tw = create_tween()
	
	# Zoom In (Aumenta o valor de zoom, aproximando a câmera)
	tw.tween_property(self, "zoom", _default_zoom + amount, duration * 0.1)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		
	# Zoom Out (Volta ao normal)
	tw.tween_property(self, "zoom", _default_zoom, duration * 0.9)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
