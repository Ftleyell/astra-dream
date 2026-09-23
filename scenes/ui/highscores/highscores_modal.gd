class_name HighscoresModal
extends CanvasLayer

signal closed()

@onready var panel: Panel = $Panel
@onready var list_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ListContainer
@onready var close_button: Button = $Panel/VBoxContainer/BottomBar/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	hide()
	if close_button:
		UIFocusHelper.apply_cyber_focus(close_button)
		close_button.pressed.connect(close_highscores)

func open_highscores() -> void:
	_populate_table()
	show()
	if close_button:
		close_button.grab_focus()

func close_highscores() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(0.4)
	hide()
	closed.emit()

func _populate_table() -> void:
	for child in list_container.get_children():
		child.queue_free()

	var records := SaveManager.get_top_highscores()
	if records.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No hay récords registrados todavía.\n¡Completa una partida para ingresar al Salón de la Fama!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.modulate = Color(0.6, 0.7, 0.8, 0.8)
		list_container.add_child(empty_lbl)
		return

	for idx in range(records.size()):
		var entry: Dictionary = records[idx]
		var row := _create_record_row(idx + 1, entry)
		list_container.add_child(row)

func _create_record_row(rank: int, entry: Dictionary) -> PanelContainer:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 48)

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.04, 0.06, 0.1, 0.85) if rank % 2 == 1 else Color(0.06, 0.08, 0.14, 0.85)
	row_style.set_corner_radius_all(4)
	row_style.set_content_margin_all(8.0)
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	# Rank
	var rank_lbl := Label.new()
	rank_lbl.custom_minimum_size = Vector2(50, 0)
	rank_lbl.text = "#%d" % rank
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match rank:
		1: rank_lbl.modulate = Color(1.0, 0.85, 0.2, 1.0) # Gold
		2: rank_lbl.modulate = Color(0.85, 0.9, 0.95, 1.0) # Silver
		3: rank_lbl.modulate = Color(0.9, 0.6, 0.3, 1.0) # Bronze
		_: rank_lbl.modulate = Color(0.4, 0.75, 1.0, 0.85)
	hbox.add_child(rank_lbl)

	# Piloto
	var pilot_lbl := Label.new()
	pilot_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pilot_lbl.text = str(entry.get("pilot_name", "Nova"))
	pilot_lbl.modulate = Color(0.95, 0.98, 1.0)
	hbox.add_child(pilot_lbl)

	# Oleada
	var wave_lbl := Label.new()
	wave_lbl.custom_minimum_size = Vector2(90, 0)
	wave_lbl.text = "Oleada %d" % int(entry.get("wave_reached", 1))
	wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_lbl.modulate = Color(0.3, 0.9, 1.0)
	hbox.add_child(wave_lbl)

	# Tiempo
	var time_lbl := Label.new()
	time_lbl.custom_minimum_size = Vector2(90, 0)
	time_lbl.text = str(entry.get("time_survived_formatted", "00:00"))
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.modulate = Color(0.8, 0.85, 0.9)
	hbox.add_child(time_lbl)

	# Bajas
	var kills_lbl := Label.new()
	kills_lbl.custom_minimum_size = Vector2(90, 0)
	kills_lbl.text = "%d Bajas" % int(entry.get("enemies_killed", 0))
	kills_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kills_lbl.modulate = Color(1.0, 0.45, 0.3)
	hbox.add_child(kills_lbl)

	# Créditos
	var credits_lbl := Label.new()
	credits_lbl.custom_minimum_size = Vector2(90, 0)
	credits_lbl.text = "%d C" % int(entry.get("credits_earned", 0))
	credits_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_lbl.modulate = Color(1.0, 0.85, 0.2)
	hbox.add_child(credits_lbl)

	# Estado
	var is_victory: bool = bool(entry.get("victory", false))
	var status_lbl := Label.new()
	status_lbl.custom_minimum_size = Vector2(110, 0)
	status_lbl.text = "VICTORIA" if is_victory else "DERROTA"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.modulate = Color(0.2, 1.0, 0.5) if is_victory else Color(0.7, 0.7, 0.8, 0.7)
	hbox.add_child(status_lbl)

	# Fecha
	var date_lbl := Label.new()
	date_lbl.custom_minimum_size = Vector2(130, 0)
	date_lbl.text = str(entry.get("date", "")).substr(0, 16)
	date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date_lbl.modulate = Color(0.5, 0.55, 0.65, 0.7)
	hbox.add_child(date_lbl)

	row_panel.add_child(hbox)
	return row_panel

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		close_highscores()
		get_viewport().set_input_as_handled()
