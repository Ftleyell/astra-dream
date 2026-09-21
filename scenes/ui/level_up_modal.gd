class_name LevelUpModal
extends CanvasLayer

signal card_chosen(card: StatCardData)

@export var stat_deck_manager: StatDeckManager
@export var player: Player

@onready var modal_panel: Panel = $Panel
@onready var cards_container: HBoxContainer = $Panel/VBoxContainer/CardsContainer
@onready var level_label: Label = $Panel/VBoxContainer/Title

var current_offered_cards: Array[StatCardData] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	if stat_deck_manager:
		stat_deck_manager.cards_offered.connect(_on_cards_offered)

func show_level_up(level: int) -> void:
	level_label.text = "¡SUBIDA DE NIVEL %d! SELECCIONA UNA MEJORA" % level
	get_tree().paused = true
	show()
	if stat_deck_manager and player:
		stat_deck_manager.offer_cards(player.stats, level, 4)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var idx := -1
		match event.keycode:
			KEY_1, KEY_KP_1:
				idx = 0
			KEY_2, KEY_KP_2:
				idx = 1
			KEY_3, KEY_KP_3:
				idx = 2
			KEY_4, KEY_KP_4:
				idx = 3

		if idx >= 0 and idx < current_offered_cards.size():
			_select_card(current_offered_cards[idx])
			get_viewport().set_input_as_handled()

func _on_cards_offered(cards: Array[StatCardData], _cost: int) -> void:
	current_offered_cards = cards
	for child in cards_container.get_children():
		child.queue_free()

	for i in range(cards.size()):
		_create_stat_card_ui(cards[i], i)

func _create_stat_card_ui(card: StatCardData, index: int) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(190, 240)

	var vbox := VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 8)
	vbox.layout_mode = 1
	vbox.anchors_preset = Control.PRESET_FULL_RECT

	# Indicador de atajo de teclado
	var hotkey_lbl := Label.new()
	hotkey_lbl.text = "[ TECLA %d ]" % (index + 1)
	hotkey_lbl.modulate = Color(1.0, 0.9, 0.3, 0.95)
	hotkey_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkey_lbl.add_theme_font_size_override("font_size", 12)

	var tier_name := "TIER 1 (Común)"
	var tier_color := Color(0.8, 0.8, 0.8)
	match card.tier:
		Enums.Tier.TIER_2:
			tier_name = "TIER 2 (Raro)"
			tier_color = Color(0.2, 0.7, 1.0)
		Enums.Tier.TIER_3:
			tier_name = "TIER 3 (Épico)"
			tier_color = Color(0.8, 0.3, 1.0)
		Enums.Tier.TIER_4:
			tier_name = "TIER 4 (Legendario)"
			tier_color = Color(1.0, 0.8, 0.2)

	var tier_lbl := Label.new()
	tier_lbl.text = tier_name
	tier_lbl.modulate = tier_color
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var title_lbl := Label.new()
	title_lbl.text = card.title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL

	vbox.add_child(hotkey_lbl)
	vbox.add_child(tier_lbl)
	vbox.add_child(title_lbl)
	btn.add_child(vbox)

	btn.pressed.connect(func():
		_select_card(card)
	)

	cards_container.add_child(btn)

func _select_card(card: StatCardData) -> void:
	if stat_deck_manager and player:
		stat_deck_manager.apply_card_to_stats(card, player.stats)
		player.chosen_stat_cards.append(card)
	hide()
	get_tree().paused = false
	card_chosen.emit(card)
