class_name GameManager extends Node

## Gerencia o ciclo de vida da cena principal, conectando a Câmera, HUD e Player.

@onready var player: PlayerController = $World/Player
@onready var camera: GameCamera = $Camera2D
@onready var hud: HUDManager = $HUD/Control # Referência ao novo script

func _ready() -> void:
	_validate_dependencies()
	_initialize_game()

func _process(_delta: float) -> void:
	# Reinicia a cena ao pressionar ESC (Debug)
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().reload_current_scene()

func _validate_dependencies() -> void:
	if not player: push_error("GameManager: Player não encontrado!")
	if not camera: push_error("GameManager: Câmera não encontrada!")
	if not hud: push_error("GameManager: HUD (Control) não encontrado ou sem script!")

func _initialize_game() -> void:
	# 1. Configura Câmera
	if camera and player:
		camera.target = player
		camera.global_position = player.global_position
	
	# 2. Configura HUD
	if hud and player:
		hud.setup(player)
