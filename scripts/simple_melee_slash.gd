class_name SimpleMeleeSlash extends Area2D

## Visual: "Sonic Boom" (Impacto Geométrico Puro)
## Foca em contraste (Branco -> Cor), velocidade e clareza da hitbox.
## Delega o efeito de dissolução para uma cena externa.

# --- CONFIGURAÇÃO ---
var damage: float = 10.0
var knockback_force: float = 500.0 
var element_color: Color = Color("4fffa0") 

# Referências Externas (Visual e Áudio)
@export var dissolve_scene: PackedScene 
@export var attack_sound: AudioStream # Arraste seu AudioStreamRandomizer aqui no Inspector

# Geometria
var max_radius: float = 55.0       
var initial_radius: float = 5.0    
var decay_radius: float = 0.5      

# Variáveis de Animação
var _current_radius: float = 0.0
var _anim_width: float = 20.0      
var _anim_alpha: float = 1.0
var _core_flash: float = 1.0       

# Componentes Internos
var _collision_shape: CollisionShape2D
var _circle_shape: CircleShape2D

# --- ÁUDIO (REFATORADO) ---
# Em vez de criar via código, esperamos que exista um nó filho na cena.
# O nome do nó na cena deve ser "AudioStreamPlayer2D".
@onready var _audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func setup(dmg: float, duration: float, scale_mod: float, kb: float, col: Color) -> void:
	damage = dmg
	knockback_force = kb
	
	if col == Color.WHITE:
		element_color = Color("4fffa0") 
	else:
		element_color = col
	
	scale = Vector2.ONE * scale_mod
	_start_impact_animation(duration)

func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)
	
	# Colisão continua sendo criada via código pois é dinâmica/geométrica
	_collision_shape = CollisionShape2D.new()
	_circle_shape = CircleShape2D.new()
	_collision_shape.shape = _circle_shape
	add_child(_collision_shape)
	
	# REMOVIDO: A criação manual do AudioStreamPlayer2D.
	# Agora confiamos no @onready var _audio_player lá em cima.

func _process(_delta: float) -> void:
	queue_redraw()

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

func _start_impact_animation(duration: float) -> void:
	monitoring = true
	_current_radius = initial_radius
	_anim_width = 20.0 
	_core_flash = 1.0
	_anim_alpha = 1.0
	
	# --- ÁUDIO ---
	# Toca o som configurado no Inspector ou injetado pela carta
	if _audio_player:
		if attack_sound:
			_audio_player.stream = attack_sound
			_audio_player.play()
		elif _audio_player.stream:
			# Se nenhum som foi passado na variável, mas o nó AudioPlayer 
			# já tem um som configurado no Editor, toca ele.
			_audio_player.play()
	
	# --- VISUAL (PARTÍCULAS) ---
	if dissolve_scene:
		var effect = dissolve_scene.instantiate() as Node2D
		get_tree().root.add_child(effect)
		effect.global_position = global_position
		
		if effect.has_method("play_expansion"):
			effect.play_expansion(initial_radius, max_radius * scale.x, duration, element_color)
	
	# --- LÓGICA DO CÍRCULO (Hitbox) ---
	var tw = create_tween().set_parallel(true)
	
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
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController or body.is_in_group("player"): return
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("apply_knockback"):
			var k_dir = (body.global_position - global_position).normalized()
			body.apply_knockback(k_dir * knockback_force)
