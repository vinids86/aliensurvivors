class_name BasicEnemy extends CharacterBody2D

## Inimigo "Kamikaze" Básico.
## Comportamento: Persegue o player cegamente.
## Arquitetura: Usa CharacterBody2D para física (ser empurrado) e Area2D (filha) para causar dano.

# --- CONFIGURAÇÃO ---
@export var max_health: float = 30.0
@export var damage: float = 5.0
@export var move_speed: float = 120.0
@export var xp_value: float = 10.0

# --- REFERÊNCIAS ---
@export var visual_sprite: Sprite2D # Arraste o Sprite aqui no Inspector
@onready var hitbox: Area2D = $HitboxArea # Certifique-se de criar este nó na cena!

# Estado Interno
var _current_health: float
var _player_ref: PlayerController
var _knockback_velocity: Vector2 = Vector2.ZERO

# Juice
var _material_ref: ShaderMaterial
var _original_color: Color

func _ready() -> void:
	_current_health = max_health
	
	# Busca o player no grupo (Desacoplado)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = players[0] as PlayerController
	
	# Configuração do Shader (Flash)
	if visual_sprite and visual_sprite.material:
		# Duplica o material para que o flash de um não afete todos (Unique)
		_material_ref = visual_sprite.material.duplicate()
		visual_sprite.material = _material_ref
		# Salva a cor original configurada no inspector do shader
		_original_color = _material_ref.get_shader_parameter("base_color")
	
	# Conecta o Hitbox de Dano (Se existir)
	if hitbox:
		# Usamos o sinal body_entered da Area2D para detectar o player
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	# 1. Movimento de Perseguição
	if _player_ref:
		var direction = (_player_ref.global_position - global_position).normalized()
		
		# Se estiver sob knockback forte, o controle de movimento é reduzido
		var control_factor = 1.0
		if _knockback_velocity.length() > 50.0:
			control_factor = 0.2 # Perde controle enquanto voa
			
		velocity = (direction * move_speed * control_factor) + _knockback_velocity
	else:
		velocity = _knockback_velocity
	
	move_and_slide()
	
	# 2. Decaimento do Knockback (Atrito)
	if _knockback_velocity.length_squared() > 10.0:
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 8.0 * delta)
	else:
		_knockback_velocity = Vector2.ZERO
		
	# 3. Orientação Visual (Squash simples na direção do movimento)
	if visual_sprite and velocity.length() > 10.0:
		var look_angle = velocity.angle()
		visual_sprite.rotation = lerp_angle(visual_sprite.rotation, look_angle, 10.0 * delta)

# --- INTERFACE DE DANO (Chamada pelo Player) ---

func take_damage(amount: float) -> void:
	_current_health -= amount
	_flash_hit()
	
	# Som de impacto simples (opcional por enquanto)
	
	if _current_health <= 0:
		die()

func apply_knockback(force: Vector2) -> void:
	_knockback_velocity = force

# --- SISTEMAS INTERNOS ---

func _flash_hit() -> void:
	if _material_ref:
		_material_ref.set_shader_parameter("base_color", Color.WHITE)
		var tw = create_tween()
		tw.tween_interval(0.1)
		tw.tween_callback(func(): 
			if _material_ref: _material_ref.set_shader_parameter("base_color", _original_color)
		)

func die() -> void:
	# Aqui futuramente spawnaremos XP e particulas de explosão
	# Por enquanto, apenas some.
	
	# Exemplo de chamada de evento global (se tivesse GameManager):
	# GameManager.on_enemy_killed.emit(xp_value)
	
	# Se o player tiver lógica de XP direta:
	if _player_ref:
		_player_ref.add_xp(xp_value)
		
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	# A Hitbox do inimigo tocou em algo. É o player?
	if body is PlayerController:
		body.take_damage(damage)
