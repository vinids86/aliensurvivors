class_name CollectorComponent extends Node

## Gerencia a área de imã para coletar itens (XP, Moedas, etc).
## Deve ser configurado com uma Area2D e um CollisionShape2D.

# --- DEPENDÊNCIAS ---
@export var collection_area: Area2D
@export var collision_shape: CollisionShape2D

func _ready() -> void:
	if collection_area:
		if not collection_area.area_entered.is_connected(_on_area_entered):
			collection_area.area_entered.connect(_on_area_entered)
	else:
		push_warning("CollectorComponent: Area2D não atribuída!")

# Chamado pelo Player para configurar o alcance inicial ou atualizações de stats
func update_radius(radius: float) -> void:
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = radius

func _on_area_entered(area: Area2D) -> void:
	# O protocolo é: o item deve ter um método 'attract(target)'
	if area.has_method("attract"):
		# Passamos o PAI deste componente (o PlayerBody) como alvo da atração
		var target = get_parent()
		area.attract(target)
