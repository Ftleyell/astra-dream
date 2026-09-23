class_name PauseMenu
extends CanvasLayer

const UIFocusHelper := preload("res://core/utils/ui_focus_helper.gd")
const HighscoresModalScript := preload("res://scenes/ui/highscores/highscores_modal.gd")

@export var player: Player

@onready var resume_button: Button = $Panel/VBoxContainer/BottomBar/ResumeButton
@onready var settings_button: Button = $Panel/VBoxContainer/BottomBar/SettingsButton
@onready var highscores_button: Button = $Panel/VBoxContainer/BottomBar/HighscoresButton
@onready var save_quit_button: Button = $Panel/VBoxContainer/BottomBar/SaveQuitButton
@onready var restart_button: Button = $Panel/VBoxContainer/BottomBar/RestartButton
@onready var hub_button: Button = get_node_or_null("Panel/VBoxContainer/BottomBar/HubButton")
@onready var menu_button: Button = $Panel/VBoxContainer/BottomBar/MenuButton

@onready var items_container: VBoxContainer = $Panel/VBoxContainer/ContentHBox/ItemsColumn/ItemsScroll/ItemsList
@onready var upgrades_container: VBoxContainer = $Panel/VBoxContainer/ContentHBox/UpgradesColumn/UpgradesScroll/UpgradesList
@onready var settings_modal: SettingsModal = $SettingsModal
@onready var highscores_modal: CanvasLayer = $HighscoresModal

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	if settings_modal:
		settings_modal.closed.connect(func(): if visible and settings_button: settings_button.grab_focus())
	if highscores_modal:
		highscores_modal.closed.connect(func(): if visible and highscores_button: highscores_button.grab_focus())

	UIFocusHelper.apply_cyber_focus(resume_button)
	UIFocusHelper.apply_cyber_focus(settings_button)
	UIFocusHelper.apply_cyber_focus(highscores_button)
	UIFocusHelper.apply_cyber_focus(save_quit_button)
	UIFocusHelper.apply_cyber_focus(restart_button)
	if hub_button:
		UIFocusHelper.apply_cyber_focus(hub_button)
	UIFocusHelper.apply_cyber_focus(menu_button)

	resume_button.pressed.connect(resume_game)
	settings_button.pressed.connect(_on_settings_pressed)
	if highscores_button:
		highscores_button.pressed.connect(_on_highscores_pressed)
	if save_quit_button:
		save_quit_button.pressed.connect(_on_save_quit_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	if hub_button:
		hub_button.pressed.connect(_on_hub_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	_setup_button_navigation()

func _setup_button_navigation() -> void:
	var buttons: Array[Button] = [
		resume_button,
		settings_button,
		highscores_button,
		save_quit_button,
		restart_button,
		hub_button,
		menu_button
	]
	var active: Array[Button] = []
	for b in buttons:
		if is_instance_valid(b) and b.visible:
			active.append(b)

	var count := active.size()
	if count <= 1:
		return

	for i in range(count):
		var btn := active[i]
		var prev_btn := active[(i - 1 + count) % count]
		var next_btn := active[(i + 1) % count]
		btn.focus_neighbor_left = prev_btn.get_path()
		btn.focus_neighbor_right = next_btn.get_path()
		# Permitir que W y S también naveguen circularmente entre las opciones
		btn.focus_neighbor_top = prev_btn.get_path()
		btn.focus_neighbor_bottom = next_btn.get_path()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			if highscores_modal and highscores_modal.visible:
				highscores_modal.close_highscores()
			elif settings_modal and settings_modal.visible:
				settings_modal.close_settings()
			else:
				resume_game()
			get_viewport().set_input_as_handled()
		else:
			# Si la tienda de satélite o el briefing están activos, ellos consumen ESC prioritariamente
			var parent_game = get_parent()
			if parent_game and parent_game.has_method("is_satellite_shop_active") and parent_game.is_satellite_shop_active():
				return
			if parent_game and "is_briefing_active" in parent_game and parent_game.is_briefing_active:
				return
			open_pause_menu()
			get_viewport().set_input_as_handled()
		return

	if visible:
		# Si se pierde el foco por clic o cambio de ventana, recuperarlo con cualquier botón de dirección
		if not get_viewport().gui_get_focus_owner():
			if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
				resume_button.grab_focus()
				get_viewport().set_input_as_handled()
				return

func open_pause_menu() -> void:
	get_tree().paused = true
	_refresh_build_inspector()
	show()
	_setup_button_navigation()
	resume_button.grab_focus()

func resume_game() -> void:
	if is_instance_valid(player) and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(0.4)
	hide()
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	if settings_modal and settings_modal.visible:
		settings_modal.close_settings()
	if highscores_modal and highscores_modal.visible:
		highscores_modal.close_highscores()

	var parent_game = get_parent()
	if parent_game and parent_game.has_method("notify_menu_closed"):
		parent_game.notify_menu_closed(0.4)
	if parent_game and parent_game.has_method("is_any_combat_modal_active") and parent_game.is_any_combat_modal_active():
		# Mantener el árbol pausado porque hay otra ventana modal activa (Leveleo, Satélite, etc.)
		get_tree().paused = true
		if parent_game.has_method("restore_combat_modal_focus"):
			parent_game.restore_combat_modal_focus()
	else:
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
		hbox.add_theme_constant_override("separation", 10)

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
		hbox.add_theme_constant_override("separation", 10)

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

func _on_highscores_pressed() -> void:
	if highscores_modal:
		highscores_modal.open_highscores()

func _on_save_quit_pressed() -> void:
	# Guardar estado actual de la partida
	var main_game := get_parent() as MainGame
	if not main_game:
		main_game = get_tree().current_scene as MainGame
	if main_game and main_game.has_method("save_current_run_state"):
		main_game.save_current_run_state()

	hide()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")

func _on_restart_pressed() -> void:
	hide()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_hub_pressed() -> void:
	hide()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")

func _on_menu_pressed() -> void:
	hide()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")
