class_name BasicEnemy extends CharacterBody2D

## Inimigo Básico Refatorado (Composition)
## Comportamento: IA Simples que persegue o jogador.

# --- COMPONENTES ---
# Arraste os nós da cena para cá no Inspector
@export var health_component: HealthComponent
@export var movement_controller: MovementController
@export var hitbox_component: HitboxComponent
@export var loot_component: LootComponent
@export var visual_sprite: Sprite2D 

# --- CONFIG ---
@export var max_health: float = 10.0
@export var speed: float = 120.0
@export var recoil_on_hit: float = 200.0 # Força que ele se empurra para trás ao acertar
@export var sfx_death: AudioStream 

var _player_ref: Node2D
var _material_ref: ShaderMaterial
var _original_color: Color

func _ready() -> void:
	_setup_visuals()
	_setup_components()
	
	if health_component:
		health_component.initialize(max_health)
	
	if hitbox_component:
		hitbox_component.on_hit_target.connect(_on_attack_landed)
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = players[0]

func _setup_components() -> void:
	# Conecta morte
	if health_component:
		health_component.on_death.connect(_on_death)
		health_component.on_damage_taken.connect(_on_damage_taken)
	
	# Conecta ataque bem sucedido (para recuo)
	if hitbox_component:
		hitbox_component.on_hit_target.connect(_on_attack_landed)

func _physics_process(_delta: float) -> void:
	if not _player_ref or not movement_controller: return
	
	# IA: Calcula direção
	var direction = (_player_ref.global_position - global_position).normalized()
	
	# Manda o MovementController mover (ele lida com velocidade e move_and_slide)
	movement_controller.move_with_input(direction, speed)
	
	# Rotação visual
	if velocity.length() > 10.0:
		if visual_sprite:
			visual_sprite.rotation = lerp_angle(visual_sprite.rotation, velocity.angle(), 0.1)

# --- CALLBACKS ---

func _on_attack_landed(target: Node, _dmg: float) -> void:
	# Aplica recuo em SI MESMO quando acerta o player
	if movement_controller and recoil_on_hit > 0:
		var recoil_dir = (global_position - target.global_position).normalized()
		movement_controller.apply_knockback(recoil_dir * recoil_on_hit, 0.2)

func _on_damage_taken(_amount: float, source: Node) -> void:
	_flash_hit()
	# O Knockback agora é aplicado externamente. 
	# Quem causou o dano (Arma) deve chamar movement_controller.apply_knockback() neste objeto.
	# OU você pode calcular aqui se a fonte do dano não aplicar knockback automaticamente.

func _on_death() -> void:
	if sfx_death and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_2d(sfx_death, global_position)
	
	if loot_component:
		loot_component.drop_loot(global_position)
	
	queue_free()

# --- VISUAIS ---
func _setup_visuals() -> void:
	# Pop-in
	scale = Vector2.ZERO
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
	if visual_sprite and visual_sprite.material:
		_material_ref = visual_sprite.material.duplicate()
		visual_sprite.material = _material_ref
		_original_color = _material_ref.get_shader_parameter("base_color")

func _flash_hit() -> void:
	if _material_ref:
		_material_ref.set_shader_parameter("base_color", Color.WHITE)
		var tw = create_tween()
		tw.tween_interval(0.1)
		tw.tween_callback(func(): 
			if _material_ref: _material_ref.set_shader_parameter("base_color", _original_color)
		)

# Wrapper para compatibilidade se outros scripts chamarem take_damage direto no corpo
func take_damage(amount: float, source: Node = null, knockback_force: float = 0.0) -> void:
	if health_component:
		health_component.take_damage(amount, source)
	if movement_controller and source and knockback_force > 0:
		var dir = (global_position - source.global_position).normalized()
		movement_controller.apply_knockback(dir * knockback_force)
