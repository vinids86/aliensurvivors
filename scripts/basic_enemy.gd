class_name BasicEnemy extends CharacterBody2D

## Inimigo "Kamikaze" Básico.
## Comportamento: Persegue -> Ataca (Recoil) -> Morre e Dropa Loot.

# --- CONFIGURAÇÃO ---
@export_group("Stats")
@export var max_health: float = 30.0
@export var damage: float = 5.0
@export var move_speed: float = 120.0
@export var xp_value: float = 10.0

@export_group("Combat")
@export var attack_cooldown: float = 1.0
@export var push_force_on_player: float = 400.0
@export var recoil_force: float = 300.0

@export_group("Loot")
@export var xp_gem_scene: PackedScene # Arraste a cena xp_gem.tscn aqui

# --- REFERÊNCIAS ---
@export_group("References")
@export var visual_sprite: Sprite2D 
@onready var hitbox: Area2D = $HitboxArea 

# Estado Interno
var _current_health: float
var _player_ref: PlayerController
var _knockback_velocity: Vector2 = Vector2.ZERO
var _current_attack_cooldown: float = 0.0 

# Juice
var _material_ref: ShaderMaterial
var _original_color: Color

func _ready() -> void:
	_current_health = max_health
	
	# Pop-in Effect
	scale = Vector2.ZERO
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = players[0] as PlayerController
	
	if visual_sprite and visual_sprite.material:
		_material_ref = visual_sprite.material.duplicate()
		visual_sprite.material = _material_ref
		_original_color = _material_ref.get_shader_parameter("base_color")

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_attack_logic(delta)

func _handle_movement(delta: float) -> void:
	if _player_ref:
		var direction = (_player_ref.global_position - global_position).normalized()
		
		# Perde controle sob knockback forte
		var control_factor = 1.0
		if _knockback_velocity.length() > 50.0:
			control_factor = 0.1
			
		velocity = (direction * move_speed * control_factor) + _knockback_velocity
	else:
		velocity = _knockback_velocity
	
	move_and_slide()
	
	if _knockback_velocity.length_squared() > 10.0:
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 8.0 * delta)
	
	if visual_sprite and velocity.length() > 10.0:
		visual_sprite.rotation = lerp_angle(visual_sprite.rotation, velocity.angle(), 10.0 * delta)

func _handle_attack_logic(delta: float) -> void:
	if _current_attack_cooldown > 0:
		_current_attack_cooldown -= delta
		return

	if hitbox:
		var overlapping_bodies = hitbox.get_overlapping_bodies()
		for body in overlapping_bodies:
			if body is PlayerController:
				_execute_attack(body)
				break 

func _execute_attack(target: PlayerController) -> void:
	target.take_damage(damage, self, push_force_on_player)
	
	# Recuo
	var recoil_dir = (global_position - target.global_position).normalized()
	apply_knockback(recoil_dir * recoil_force)
	
	_current_attack_cooldown = attack_cooldown

# --- INTERFACE PÚBLICA ---

func take_damage(amount: float) -> void:
	_current_health -= amount
	_flash_hit()
	if _current_health <= 0:
		die()

func apply_knockback(force: Vector2) -> void:
	_knockback_velocity = force

func _flash_hit() -> void:
	if _material_ref:
		_material_ref.set_shader_parameter("base_color", Color.WHITE)
		var tw = create_tween()
		tw.tween_interval(0.1)
		tw.tween_callback(func(): 
			if _material_ref: _material_ref.set_shader_parameter("base_color", _original_color)
		)

func die() -> void:
	# DROP DE LOOT
	if xp_gem_scene:
		var gem = xp_gem_scene.instantiate()
		gem.global_position = global_position
		gem.xp_amount = xp_value # Passa o valor do inimigo para a gema
		
		# Adiciona à raiz para não ser deletado junto com o inimigo
		# Usamos call_deferred para evitar travamentos de física durante a troca de frame
		get_tree().root.call_deferred("add_child", gem)
	
	queue_free()
