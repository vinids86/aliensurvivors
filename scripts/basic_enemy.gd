class_name BasicEnemy extends CharacterBody2D

# --- COMPONENTES (Composition) ---
@onready var health_component: HealthComponent = %HealthComponent
@onready var movement_controller: MovementController = %MovementController
@onready var hitbox_component: HitboxComponent = %HitboxComponent
@onready var loot_component: LootComponent = %LootComponent
@onready var visuals: EnemyVisuals = %EnemyVisuals

# --- CONFIGURAÇÃO ---
@export var max_health: float = 30.0
@export var speed: float = 120.0
@export var recoil_on_hit: float = 200.0 

var _player_ref: Node2D

func _ready() -> void:
	_player_ref = get_tree().get_first_node_in_group("player")
	
	health_component.initialize(max_health)
	health_component.on_death.connect(_on_death)
	health_component.on_damage_taken.connect(func(_a, _s): visuals.play_hit_feedback())
	
	# Garante que a hitbox esteja ativa para causar dano e gerar recuo
	hitbox_component.monitoring = true
	hitbox_component.on_hit_target.connect(_on_attack_landed)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player_ref): return
	
	# Persegue
	var direction = (_player_ref.global_position - global_position).normalized()
	movement_controller.move_with_input(direction, speed)
	
	# Rotaciona visual
	if velocity.length() > 10.0:
		visuals.rotate_towards(global_position + velocity, 0.1)

# Wrapper de dano para compatibilidade com armas
func take_damage(amount: float, source: Node = null, push_force: float = 0.0) -> void:
	health_component.take_damage(amount, source)
	if source and push_force > 0:
		var dir = (global_position - source.global_position).normalized()
		movement_controller.apply_knockback(dir * push_force)

# Recuo (Recoil) quando acerta o player
func _on_attack_landed(target: Node, _dmg: float) -> void:
	if recoil_on_hit > 0:
		var recoil_dir = (global_position - target.global_position).normalized()
		movement_controller.apply_knockback(recoil_dir * recoil_on_hit, 0.2)

func _on_death() -> void:
	visuals.play_death()
	loot_component.drop_loot(global_position)
	queue_free()
