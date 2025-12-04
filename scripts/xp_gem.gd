class_name XPGem extends Area2D

## Representa uma unidade de XP no mundo.
## Comportamento: Idle (Orbital/Pulsante) -> Magnet (Squash) -> Coleta.

@export var xp_amount: float = 10.0
@export var speed: float = 600.0
@export var steer_force: float = 18.0

# --- REFERÊNCIAS VISUAIS/SONORAS ---
@export var sprite_ref: Sprite2D
@export var particles_ref: CPUParticles2D
@export var audio_ref: AudioStreamPlayer2D

# Estado
var _target: Node2D = null
var _velocity: Vector2 = Vector2.ZERO
var _wobble_time: float = 0.0
var _is_collected: bool = false
var _random_rotation_speed: float = 0.0 # Cada gema gira numa velocidade única

func _ready() -> void:
	# Juice: Randomiza para que as gemas não pulsem todas sincronizadas (efeito robótico)
	_wobble_time = randf() * 10.0
	_random_rotation_speed = randf_range(-2.0, 2.0) # Algumas giram pra esq, outras pra dir
	
	body_entered.connect(_on_body_entered)
	
	if not sprite_ref or not particles_ref or not audio_ref:
		push_warning("XPGem: Faltam referências no Inspector.")

func _physics_process(delta: float) -> void:
	if _is_collected: return 
	
	if _target:
		_handle_magnet_movement(delta)
	else:
		_handle_idle_animation(delta)

func attract(target_node: Node2D) -> void:
	if _is_collected: return
	_target = target_node
	
	# Efeito de "acordar" (Pop)
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _handle_magnet_movement(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = null
		return

	var desired_velocity = (_target.global_position - global_position).normalized() * speed
	var steering = (desired_velocity - _velocity) * steer_force * delta
	
	_velocity += steering
	position += _velocity * delta
	
	# Durante o voo, a gema aponta para onde vai e estica (efeito de velocidade)
	rotation = _velocity.angle()
	scale = Vector2(1.3, 0.7) # Alongada

func _handle_idle_animation(delta: float) -> void:
	_wobble_time += delta
	
	# 1. Rotação Constante (Energia contida)
	rotation += _random_rotation_speed * delta
	
	# 2. Pulso de Respiração (Senoide)
	var pulse = sin(_wobble_time * 4.0) * 0.1
	scale = Vector2.ONE * (0.9 + pulse) # Oscila entre 0.8 e 1.0

func _on_body_entered(body: Node2D) -> void:
	if _is_collected: return
	
	if body.has_method("add_xp"):
		_is_collected = true
		body.add_xp(xp_amount)
		_play_collection_effects()

func _play_collection_effects() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	if sprite_ref: sprite_ref.visible = false
	
	if audio_ref and audio_ref.stream:
		audio_ref.pitch_scale = randf_range(0.9, 1.1)
		audio_ref.play()
	
	if particles_ref:
		particles_ref.emitting = true
	
	var wait_time = 0.5 
	if particles_ref: wait_time = max(wait_time, particles_ref.lifetime)
	if audio_ref and audio_ref.stream: wait_time = max(wait_time, audio_ref.stream.get_length())
	
	await get_tree().create_timer(wait_time).timeout
	queue_free()
