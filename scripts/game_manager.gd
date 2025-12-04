class_name GameManager extends Node

@onready var player: PlayerController = $World/Player
@onready var camera: GameCamera = $Camera2D
@onready var hud: HUDManager = $HUD/Control

# REFERÊNCIA DIRETA À UI
@export var level_up_screen: LevelUpScreen 

# MÚSICA DE FUNDO
@export_group("Audio")
@export var bgm_music: AudioStream
@onready var _music_player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready() -> void:
	# Configura e adiciona o player de música
	add_child(_music_player)
	_music_player.bus = "Music" # Importante: crie esse Bus no editor de áudio!
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS # Toca mesmo pausado (menu level up)
	
	if bgm_music:
		_music_player.stream = bgm_music
		_music_player.play()
	else:
		push_warning("GameManager: Nenhuma música de fundo atribuída.")

	_validate_dependencies()
	_initialize_game()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().reload_current_scene()

func _validate_dependencies() -> void:
	if not player: push_error("GameManager: Player não encontrado!")
	if not camera: push_error("GameManager: Câmera não encontrada!")
	if not hud: push_error("GameManager: HUD não encontrado!")
	
	if not level_up_screen: push_warning("GameManager: LevelUpScreen não atribuída!")

func _initialize_game() -> void:
	if camera and player:
		camera.target = player
		camera.global_position = player.global_position
	
	if hud and player:
		hud.setup(player)
	
	if player:
		player.on_level_up.connect(_on_player_level_up)

func _on_player_level_up(_new_level: int) -> void:
	if level_up_screen:
		level_up_screen.setup_and_show(player)
