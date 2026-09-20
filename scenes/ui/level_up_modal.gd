class_name LevelUpModal
extends CanvasLayer

signal card_chosen(card: StatCardData)

@export var stat_deck_manager: StatDeckManager
@export var player: Player

@onready var modal_panel: Panel = $Panel
@onready var cards_container: HBoxContainer = $Panel/VBoxContainer/CardsContainer
@onready var level_label: Label = $Panel/VBoxContainer/Title

func _ready() -> void:
	hide()
	if stat_deck_manager:
		stat_deck_manager.cards_offered.connect(_on_cards_offered)

func show_level_up(level: int) -> void:
	level_label.text = "¡SUBIDA DE NIVEL %d! SELECCIONA UNA MEJORA" % level
	get_tree().paused = true
	show()
	if stat_deck_manager and player:
		stat_deck_manager.offer_cards(player.stats, level, 4)

func _on_cards_offered(cards: Array[StatCardData], _cost: int) -> void:
	for child in cards_container.get_children():
		child.queue_free()

	for card in cards:
		_create_stat_card_ui(card)

func _create_stat_card_ui(card: StatCardData) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(190, 240)

	var vbox := VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 10)
	vbox.layout_mode = 1
	vbox.anchors_preset = Control.PRESET_FULL_RECT

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

	vbox.add_child(tier_lbl)
	vbox.add_child(title_lbl)
	btn.add_child(vbox)

	btn.pressed.connect(func():
		if stat_deck_manager and player:
			stat_deck_manager.apply_card_to_stats(card, player.stats)
			player.chosen_stat_cards.append(card)
		hide()
		get_tree().paused = false
		card_chosen.emit(card)
	)

	cards_container.add_child(btn)
