class_name LevelUpScreen extends CanvasLayer

@export_group("References")
@export var card_ui_scene: PackedScene 
@export var cards_container: HBoxContainer

@export_group("Data")
@export var all_upgrades: Array[UpgradeCard] 

@export_group("Audio Feedback")
@export var sfx_hover: AudioStream   
@export var sfx_confirm: AudioStream 

@onready var _audio_player: AudioStreamPlayer = AudioStreamPlayer.new()

var _player_ref: PlayerController

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	add_child(_audio_player)
	_audio_player.bus = "SFX" 

func _input(event: InputEvent) -> void:
	if not visible: return

	if event.is_action_pressed("ui_accept") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.pressed):
		var focused_node = get_viewport().gui_get_focus_owner()
		if focused_node and focused_node in cards_container.get_children():
			focused_node.pressed.emit() 
			get_viewport().set_input_as_handled() 

func setup_and_show(player: PlayerController) -> void:
	_player_ref = player
	
	if not card_ui_scene or all_upgrades.is_empty():
		push_warning("LevelUpScreen: Configuração incompleta.")
		return

	# 1. LIMPEZA ROBUSTA
	# Usamos remove_child para tirar da árvore IMEDIATAMENTE.
	# queue_free() sozinho deixa o nó lá até o final do frame, atrapalhando o índice 0.
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()
	
	var options = _pick_random_options(3)
	
	# Variável para guardar explicitamente a primeira carta nova
	var first_new_card: Control = null
	
	# 2. Cria e Configura
	for i in range(options.size()):
		var card_data = options[i]
		var card_instance = card_ui_scene.instantiate() as UpgradeCardUI
		cards_container.add_child(card_instance)
		
		# Guarda referência se for a primeira
		if i == 0:
			first_new_card = card_instance
		
		card_instance.setup(card_data)
		card_instance.card_selected.connect(_on_card_selected)
		
		card_instance.focus_entered.connect(_play_hover_sound)
		card_instance.mouse_entered.connect(_play_hover_sound)
	
	visible = true
	get_tree().paused = true
	
	# 3. AUTO-SELECT (Corrigido)
	# Foca diretamente na instância que acabamos de criar, sem depender de get_child(0)
	if first_new_card:
		# call_deferred é necessário para esperar a visibilidade se propagar
		first_new_card.grab_focus.call_deferred()

func _on_card_selected(card: UpgradeCard) -> void:
	if sfx_confirm:
		_audio_player.stream = sfx_confirm
		_audio_player.play()
	
	if _player_ref:
		card.apply(_player_ref)
	
	_close()

func _play_hover_sound() -> void:
	# Verificação extra para não tocar som na inicialização automática
	if visible: 
		_audio_player.pitch_scale = randf_range(0.95, 1.05)
		_audio_player.stream = sfx_hover
		_audio_player.play()

func _close() -> void:
	visible = false
	get_tree().paused = false

func _pick_random_options(count: int) -> Array[UpgradeCard]:
	var pool = all_upgrades.duplicate()
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))
