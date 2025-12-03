class_name SimpleProjectile extends Area2D

# Configurações recebidas na criação
var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var max_range: float = 1000.0
var traveled_distance: float = 0.0

# Visual
var color: Color = Color.WHITE
var size: float = 1.0

func setup(pos: Vector2, dir: Vector2, speed: float, dmg: float, scale_mod: float, col: Color):
	global_position = pos
	velocity = dir * speed
	damage = dmg
	size = scale_mod
	color = col
	
	rotation = dir.angle()
	scale = Vector2(size, size)

func _ready():
	# Configura colisão se não tiver sido feito no editor
	if not has_node("CollisionShape2D"):
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 8.0
		shape.shape = circle
		add_child(shape)
	
	# Conecta sinal de colisão
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	var step = velocity * delta
	global_position += step
	traveled_distance += step.length()
	
	if traveled_distance >= max_range:
		queue_free()
	
	# Redesenha para fazer rastro simples (opcional)
	queue_redraw()

func _draw():
	# Desenha um projétil geométrico (Losango alongado)
	var points = PackedVector2Array([
		Vector2(10, 0),   # Frente
		Vector2(-5, 5),   # Asa Esq
		Vector2(-2, 0),   # Traseira (Recuo)
		Vector2(-5, -5)   # Asa Dir
	])
	draw_colored_polygon(points, color)
	draw_polyline(points, Color.WHITE, 1.0) # Borda

func _on_body_entered(body):
	if body.has_method("take_damage"):
		# Empurrão na direção do tiro
		var knock_dir = velocity.normalized()
		# Chamamos take_damage(amount, knockback_source)
		# Se a assinatura for diferente no inimigo, ajuste aqui
		if body.has_method("take_damage"):
			# Tenta passar knockback se o inimigo suportar, senão só dano
			# Isso é um duck typing seguro
			body.call("take_damage", damage) 
			
	# Efeito de impacto simples
	queue_free()
