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
	_music_player.bus = "Music" 
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS 
	
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
		
		# --- CONEXÃO DOS EFEITOS DE CÂMERA ---
		# 1. Quando o player ataca (Tiro ou Corte)
		player.on_attack_triggered.connect(_on_player_attack)
		
		# 2. Quando o player recebe dano
		player.on_hit_received.connect(_on_player_hit)
	
	if hud and player:
		hud.setup(player)
	
	if player:
		player.on_level_up.connect(_on_player_level_up)

# --- EFEITOS DE GAME FEEL ---

func _on_player_attack(_context: Dictionary) -> void:
	if not camera: return
	
	# Pequeno "coice" visual a cada ataque para dar peso
	# Trauma baixo (0.15) = tremor sutil
	# Zoom Kick pequeno (0.02) = pulsação rítmica
	camera.add_trauma(0.15)
	camera.zoom_kick(Vector2(0.02, 0.02), 0.1)

func _on_player_hit(_source, _damage) -> void:
	if not camera: return
	
	# Impacto massivo ao levar dano
	# Trauma alto (0.6) = tremor forte + aberração cromática visível
	# Zoom Kick negativo (-0.05) = câmera "se afasta" ou distorce com o susto
	camera.add_trauma(0.6)
	camera.zoom_kick(Vector2(-0.05, -0.05), 0.3)

func _on_player_level_up(_new_level: int) -> void:
	if level_up_screen:
		level_up_screen.setup_and_show(player)
