class_name PauseMenu
extends CanvasLayer

@export var player: Player

@onready var resume_button: Button = $Panel/VBoxContainer/BottomBar/ResumeButton
@onready var settings_button: Button = $Panel/VBoxContainer/BottomBar/SettingsButton
@onready var restart_button: Button = $Panel/VBoxContainer/BottomBar/RestartButton
@onready var menu_button: Button = $Panel/VBoxContainer/BottomBar/MenuButton

@onready var items_container: VBoxContainer = $Panel/VBoxContainer/ContentHBox/ItemsColumn/ItemsScroll/ItemsList
@onready var upgrades_container: VBoxContainer = $Panel/VBoxContainer/ContentHBox/UpgradesColumn/UpgradesScroll/UpgradesList
@onready var settings_modal: SettingsModal = $SettingsModal

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	resume_button.pressed.connect(resume_game)
	settings_button.pressed.connect(_on_settings_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			# Si el modal de opciones está abierto, cerrarlo primero
			if settings_modal and settings_modal.visible:
				settings_modal.hide()
			else:
				resume_game()
		else:
			open_pause_menu()
		get_viewport().set_input_as_handled()

func open_pause_menu() -> void:
	get_tree().paused = true
	_refresh_build_inspector()
	show()

func resume_game() -> void:
	hide()
	if settings_modal:
		settings_modal.hide()
	get_tree().paused = false

func _refresh_build_inspector() -> void:
	_populate_items()
	_populate_upgrades()

func _populate_items() -> void:
	for child in items_container.get_children():
		child.queue_free()

	if not player or not player.inventory:
		var empty_lbl := Label.new()
		empty_lbl.text = "No se detectó inventario del jugador."
		items_container.add_child(empty_lbl)
		return

	var all_items := player.inventory.get_all_items()
	if all_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Ningún ítem adquirido aún.\n(Encuentra satélites en el radar para comprar ítems)"
		empty_lbl.modulate = Color(0.6, 0.65, 0.75, 0.8)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		items_container.add_child(empty_lbl)
		return

	for entry in all_items:
		var item: ItemData = entry["data"]
		var count: int = entry["count"]

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 48)

		var hbox := HBoxContainer.new()
		hbox.theme_override_constants.set("separation", 10)

		var count_lbl := Label.new()
		count_lbl.text = " x%d " % count
		count_lbl.modulate = Color(1.0, 0.85, 0.2, 1.0)

		var name_lbl := Label.new()
		name_lbl.text = item.item_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var desc_lbl := Label.new()
		desc_lbl.text = item.description
		desc_lbl.modulate = Color(0.7, 0.8, 0.9, 0.8)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(name_lbl)
		vbox.add_child(desc_lbl)

		hbox.add_child(count_lbl)
		hbox.add_child(vbox)
		panel.add_child(hbox)
		items_container.add_child(panel)

func _populate_upgrades() -> void:
	for child in upgrades_container.get_children():
		child.queue_free()

	if not player or player.chosen_stat_cards.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Sin mejoras de nivel adquiridas aún.\n(Recoge orbes de EXP para subir de nivel)"
		empty_lbl.modulate = Color(0.6, 0.65, 0.75, 0.8)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		upgrades_container.add_child(empty_lbl)
		return

	for card: StatCardData in player.chosen_stat_cards:
		var panel := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.theme_override_constants.set("separation", 10)

		var tier_badge := Label.new()
		var tier_text := "[COMÚN]"
		var tier_col := Color(0.8, 0.8, 0.8)
		match card.tier:
			Enums.Tier.TIER_2:
				tier_text = "[RARO]"
				tier_col = Color(0.2, 0.8, 1.0)
			Enums.Tier.TIER_3:
				tier_text = "[ÉPICO]"
				tier_col = Color(0.85, 0.35, 1.0)
			Enums.Tier.TIER_4:
				tier_text = "[LEGENDARIO]"
				tier_col = Color(1.0, 0.85, 0.2)

		tier_badge.text = tier_text
		tier_badge.modulate = tier_col

		var title_lbl := Label.new()
		title_lbl.text = card.title
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		hbox.add_child(tier_badge)
		hbox.add_child(title_lbl)
		panel.add_child(hbox)
		upgrades_container.add_child(panel)

func _on_settings_pressed() -> void:
	if settings_modal:
		settings_modal.open_settings()

func _on_restart_pressed() -> void:
	resume_game()
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	resume_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")
