class_name HUDManager extends Control

# --- REFERÊNCIAS ---
@export var health_bar: ProgressBar
@export var xp_bar: ProgressBar
@export var level_label: Label

# Referência privada para ler dados (Max Health, XP necessaria)
var _player_ref: PlayerController

func setup(player: PlayerController) -> void:
	_player_ref = player
	
	# 1. Conecta aos sinais do Player
	player.on_hit_received.connect(_on_player_hit)
	player.on_xp_collected.connect(_on_xp_collected)
	player.on_level_up.connect(_on_level_up)
	
	# 2. Inicializa os valores visuais (Estado inicial)
	_update_health_bar()
	_update_xp_bar()
	level_label.text = "LVL " + str(player._current_level)

# --- ATUALIZAÇÕES ---

func _on_player_hit(_source, _damage) -> void:
	_update_health_bar()

func _on_xp_collected(_amount) -> void:
	_update_xp_bar()

func _on_level_up(new_level: int) -> void:
	level_label.text = "LVL " + str(new_level)
	_update_xp_bar() # Reseta a barra para o novo nível

# --- LÓGICA DE EXIBIÇÃO ---

func _update_health_bar() -> void:
	# Acessa variáveis internas do player (permitido em GDScript entre classes amigas)
	var max_hp = _player_ref.stats.get_stat("max_health")
	var current_hp = _player_ref._current_health
	
	health_bar.max_value = max_hp
	health_bar.value = current_hp

func _update_xp_bar() -> void:
	var xp_needed = _player_ref._xp_to_next_level
	var current_xp = _player_ref._current_xp
	
	xp_bar.max_value = xp_needed
	xp_bar.value = current_xp
