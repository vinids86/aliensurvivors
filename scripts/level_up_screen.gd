class_name LevelUpScreen extends CanvasLayer

@export_group("References")
@export var card_ui_scene: PackedScene 
@export var cards_container: HBoxContainer

@export_group("Data")
@export var all_upgrades: Array[UpgradeCard] 

var _player_ref: PlayerController

func _ready() -> void:
	# Garante que processa durante o pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Começa escondida
	visible = false

func setup_and_show(player: PlayerController) -> void:
	_player_ref = player
	
	if not card_ui_scene or all_upgrades.is_empty():
		push_warning("LevelUpScreen: Configuração incompleta.")
		return

	# 1. Limpa cartas antigas (do level up anterior)
	for child in cards_container.get_children():
		child.queue_free()
	
	# 2. Sorteia novas cartas
	var options = _pick_random_options(3)
	
	# 3. Cria os visuais
	for card_data in options:
		var card_instance = card_ui_scene.instantiate() as UpgradeCardUI
		cards_container.add_child(card_instance)
		
		card_instance.setup(card_data)
		card_instance.card_selected.connect(_on_card_selected)
	
	# 4. Exibe e Pausa
	visible = true
	get_tree().paused = true

func _on_card_selected(card: UpgradeCard) -> void:
	if _player_ref:
		card.apply(_player_ref)
	
	_close()

func _close() -> void:
	visible = false
	get_tree().paused = false

func _pick_random_options(count: int) -> Array[UpgradeCard]:
	var pool = all_upgrades.duplicate()
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))
