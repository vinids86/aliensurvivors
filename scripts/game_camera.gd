class_name GameCamera extends Camera2D

@export var target: Node2D
@export var smooth_speed: float = 5.0
@export var offset_position: Vector2 = Vector2.ZERO

func _physics_process(delta):
	if not target:
		return
		
	# Interpolação suave para seguir o alvo
	var target_pos = target.global_position + offset_position
	global_position = global_position.lerp(target_pos, smooth_speed * delta)
