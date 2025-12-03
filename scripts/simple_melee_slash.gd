class_name SimpleMeleeSlash extends Area2D

## Visual: "Sonic Boom" (Impacto Geométrico Puro)
## Um círculo perfeito que expande violentamente.
## Foca em contraste (Branco -> Cor), velocidade e clareza da hitbox.

# --- CONFIGURAÇÃO ---
var damage: float = 10.0
var knockback_force: float = 500.0 # Aumentei um pouco para combinar com o impacto visual
var element_color: Color = Color("4fffa0") # Verde Neon

# Geometria
var max_radius: float = 55.0       
var initial_radius: float = 5.0    # Não começa do zero absoluto para ter "corpo" no frame 1

# Variáveis de Animação
var _current_radius: float = 0.0
var _anim_width: float = 0.0       # Espessura da onda de choque
var _anim_alpha: float = 1.0
var _core_flash: float = 1.0       # Intensidade do centro branco

# Cache de Colisão
var _collision_shape: CollisionShape2D
var _circle_shape: CircleShape2D

func setup(dmg: float, duration: float, scale_mod: float, kb: float, col: Color) -> void:
	damage = dmg
	knockback_force = kb
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

func _draw() -> void:
	if _current_radius <= 1.0: return

	# 1. Onda de Choque (Borda Grossa)
	# Desenhamos um arco grosso que representa a força do impacto
	var color_wave = element_color
	color_wave.a = 0.8 * _anim_alpha
	
	if _anim_width > 0.5:
		draw_arc(Vector2.ZERO, _current_radius, 0, TAU, 64, color_wave, _anim_width)
	
	# 2. Flash Central (Impacto Branco)
	# Nos primeiros frames, desenha um círculo sólido branco que desvanece rápido.
	# Isso dá a sensação de "energia concentrada" liberada.
	if _core_flash > 0.01:
		var color_core = Color.WHITE
		color_core.a = _core_flash * 0.9
		# O núcleo é um pouco menor que a onda principal
		draw_circle(Vector2.ZERO, _current_radius * 0.85, color_core)

	_update_collision(_current_radius)

func _update_collision(radius: float) -> void:
	if _circle_shape:
		_circle_shape.radius = radius

func _start_impact_animation(duration: float) -> void:
	monitoring = true
	_current_radius = initial_radius
	_anim_width = 20.0 # Começa bem grosso
	_core_flash = 1.0
	_anim_alpha = 1.0
	
	var tw = create_tween().set_parallel(true)
	
	# 1. Expansão Explosiva (Radius)
	# EASE_OUT_QUART é muito rápido no início e freia bruscamente -> Sensação de Impacto
	tw.tween_property(self, "_current_radius", max_radius, duration)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		
	# 2. Afinamento da Onda (Width)
	# A onda começa grossa e fica fina à medida que dissipa energia
	tw.tween_property(self, "_anim_width", 2.0, duration * 0.8)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 3. Flash Branco (Core)
	# Dura pouquíssimo tempo (apenas o "pop" inicial)
	tw.tween_property(self, "_core_flash", 0.0, duration * 0.3)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# 4. Fade Out Geral
	tw.tween_property(self, "_anim_alpha", 0.0, duration * 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)\
		.set_delay(duration * 0.6)
	
	await tw.finished
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController or body.is_in_group("player"): return
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("apply_knockback"):
			var k_dir = (body.global_position - global_position).normalized()
			body.apply_knockback(k_dir * knockback_force)
