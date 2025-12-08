class_name HitboxComponent extends Area2D

# Configurações de Dano
@export var damage: float = 10.0
@export var knockback_force: float = 300.0 # Força aplicada no ALVO
@export var hit_interval: float = 0.5 # Tempo entre hits (se contínuo)

# Sinal útil para o dono saber que acertou alguém (ex: para aplicar recuo em si mesmo)
signal on_hit_target(target: Node, damage_dealt: float)

var _cooldown_timer: float = 0.0

func _ready() -> void:
	# Configuração automática de colisão se esquecer no editor
	# Collision Layer 0 (não colide física), Mask 2 (Player - ajuste conforme suas camadas)
	monitorable = false # Hitbox bate, não apanha
	monitoring = true

func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0:
		_cooldown_timer -= delta
		return
		
	if has_overlapping_bodies():
		for body in get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				_attack(body)
				break # Ataca um por vez ou remova para multi-hit

func _attack(target: Node) -> void:
	# Aplica dano
	target.take_damage(damage, get_parent(), knockback_force)
	
	
	
	on_hit_target.emit(target, damage)
	_cooldown_timer = hit_interval
