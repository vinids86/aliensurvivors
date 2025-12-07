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
		if player.has_signal("on_attack_triggered"):
			player.on_attack_triggered.connect(_on_player_attack)
		
		if player.has_signal("on_hit_received"):
			player.on_hit_received.connect(_on_player_hit)
			
		# NOVO: Conecta o sinal do Dash
		if player.has_signal("on_dash_used"):
			player.on_dash_used.connect(_on_player_dash)
	
	if hud and player:
		hud.setup(player)
	
	if player:
		player.on_level_up.connect(_on_player_level_up)

# --- EFEITOS DE GAME FEEL ---

func _on_player_attack(_context: Dictionary) -> void:
	if not camera: return
	camera.add_trauma(0.15)
	camera.zoom_kick(Vector2(0.02, 0.02), 0.1)

func _on_player_hit(_source, _damage) -> void:
	if not camera: return
	camera.add_trauma(0.6)
	camera.zoom_kick(Vector2(-0.05, -0.05), 0.3)

# NOVO: Reação da câmera ao Dash
func _on_player_dash(_cooldown) -> void:
	if not camera: return
	# Zoom out leve e rápido para dar sensação de velocidade
	camera.zoom_kick(Vector2(0.05, 0.05), 0.15) 
	# Trauma leve para sentir o impacto da arrancada
	camera.add_trauma(0.2)

func _on_player_level_up(_new_level: int) -> void:
	if level_up_screen:
		level_up_screen.setup_and_show(player)
