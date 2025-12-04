class_name UpgradeCardUI extends Button

## Controla a visualização de uma única carta no menu.
## Deve ser a raiz de uma cena contendo Labels e TextureRect.

signal card_selected(card_data: UpgradeCard)

@export var title_label: Label
@export var description_label: Label
@export var icon_rect: TextureRect

var _card_data: UpgradeCard

func setup(card: UpgradeCard) -> void:
	_card_data = card
	
	if title_label: title_label.text = card.title
	if description_label: description_label.text = card.description
	if icon_rect and card.icon: icon_rect.texture = card.icon
	
	# Conecta o clique do próprio botão (self)
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	# Emite o sinal para cima (para a LevelUpScreen) passando os dados
	card_selected.emit(_card_data)
