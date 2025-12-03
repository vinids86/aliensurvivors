class_name GameManager extends Node

## Gerencia o ciclo de vida da cena principal, conectando a Câmera e validando referências críticas.
## Atua como o ponto central de inicialização do "World".

@onready var player: PlayerController = $World/Player
@onready var camera: GameCamera = $Camera2D

func _ready() -> void:
	_validate_dependencies()
	_initialize_camera()

func _process(_delta: float) -> void:
	# Reinicia a cena ao pressionar ESC (Debug)
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().reload_current_scene()

func _validate_dependencies() -> void:
	if not player:
		push_error("GameManager: Player não encontrado em $World/Player")
	
	if not camera:
		push_error("GameManager: Câmera não encontrada em $Camera2D")

func _initialize_camera() -> void:
	if camera and player:
		camera.target = player
		camera.global_position = player.global_position
