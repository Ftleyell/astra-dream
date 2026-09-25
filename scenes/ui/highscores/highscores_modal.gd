class_name HighscoresModal
extends CanvasLayer

signal closed()

@onready var panel: Panel = $Panel
@onready var vbox_root: VBoxContainer = $Panel/VBoxContainer
@onready var title_label: Label = $Panel/VBoxContainer/HeaderHBox/TitleLabel
@onready var table_header: HBoxContainer = $Panel/VBoxContainer/TableHeader
@onready var scroll_container: ScrollContainer = $Panel/VBoxContainer/ScrollContainer
@onready var list_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ListContainer
@onready var close_button: Button = $Panel/VBoxContainer/BottomBar/CloseButton

var current_tab: int = 0 # 0 = Carrera, 1 = Salón de la Fama
var career_container: ScrollContainer = null
var tab_career_btn: Button = null
var tab_hof_btn: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	hide()
	_setup_tab_bar()
	_setup_career_container()
	if close_button:
		UIFocusHelper.apply_cyber_focus(close_button)
		close_button.pressed.connect(close_highscores)

func _setup_tab_bar() -> void:
	var tab_bar := HBoxContainer.new()
	tab_bar.name = "TabBarHBox"
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_bar.add_theme_constant_override("separation", 16)

	tab_career_btn = Button.new()
	tab_career_btn.text = "  [1] HOJA DE SERVICIO Y CARRERA  "
	tab_career_btn.custom_minimum_size = Vector2(280, 42)
	UIFocusHelper.apply_cyber_focus(tab_career_btn)
	tab_career_btn.pressed.connect(func(): _switch_tab(0))

	tab_hof_btn = Button.new()
	tab_hof_btn.text = "  [2] SALÓN DE LA FAMA (TOP 10)  "
	tab_hof_btn.custom_minimum_size = Vector2(280, 42)
	UIFocusHelper.apply_cyber_focus(tab_hof_btn)
	tab_hof_btn.pressed.connect(func(): _switch_tab(1))

	tab_bar.add_child(tab_career_btn)
	tab_bar.add_child(tab_hof_btn)

	# Insertar la barra de tabs justo debajo del HeaderHBox (índice 1)
	if vbox_root:
		vbox_root.add_child(tab_bar)
		vbox_root.move_child(tab_bar, 1)

func _setup_career_container() -> void:
	career_container = ScrollContainer.new()
	career_container.name = "CareerScrollContainer"
	career_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	career_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if vbox_root:
		vbox_root.add_child(career_container)
		# Posicionarlo en el mismo lugar que el scroll_container
		var target_idx := scroll_container.get_index() if scroll_container else 4
		vbox_root.move_child(career_container, target_idx)

func _switch_tab(tab_idx: int) -> void:
	current_tab = tab_idx
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")

	if tab_idx == 0:
		# Tab Carrera
		if title_label:
			title_label.text = "HOJA DE SERVICIO Y CARRERA ESPACIAL"
		if table_header:
			table_header.visible = false
		if scroll_container:
			scroll_container.visible = false
		if career_container:
			career_container.visible = true
		_populate_career_view()
		_style_tab_buttons(true)
	else:
		# Tab Salón de la Fama
		if title_label:
			title_label.text = "SALÓN DE LA FAMA — TOP 10 RÉCORDS"
		if career_container:
			career_container.visible = false
		if table_header:
			table_header.visible = true
		if scroll_container:
			scroll_container.visible = true
		_populate_table()
		_style_tab_buttons(false)

func _style_tab_buttons(is_career_active: bool) -> void:
	if tab_career_btn:
		tab_career_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_career_active else Color(0.65, 0.75, 0.85, 0.7)
	if tab_hof_btn:
		tab_hof_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if not is_career_active else Color(0.65, 0.75, 0.85, 0.7)

func open_highscores() -> void:
	_switch_tab(current_tab)
	show()
	if tab_career_btn and current_tab == 0:
		tab_career_btn.grab_focus()
	elif tab_hof_btn and current_tab == 1:
		tab_hof_btn.grab_focus()
	elif close_button:
		close_button.grab_focus()

func open_career() -> void:
	current_tab = 0
	open_highscores()

func close_highscores() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(0.4)
	hide()
	closed.emit()

func _populate_career_view() -> void:
	if not career_container:
		return
	for child in career_container.get_children():
		child.queue_free()

	var career_data := SaveManager.get_career_stats()
	var total_time_sec: float = float(career_data.get("total_time_survived", 0.0))
	var hours := int(total_time_sec) / 3600
	var minutes := (int(total_time_sec) % 3600) / 60
	var seconds := int(total_time_sec) % 60
	var time_fmt := "%02dh %02dm %02ds" % [hours, minutes, seconds]

	var total_bosses: int = int(career_data.get("total_bosses_killed", 0))
	var is_nyx_unlocked: bool = SaveManager.is_character_unlocked(&"nyx") or total_bosses >= 10

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 16)

	# 1. Panel de Desbloqueo de Nyx (Prioridad de progresión)
	var nyx_card := PanelContainer.new()
	nyx_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nyx_style := StyleBoxFlat.new()
	nyx_style.bg_color = Color(0.08, 0.02, 0.14, 0.92)
	nyx_style.border_color = Color(0.9, 0.3, 1.0, 1.0) if is_nyx_unlocked else Color(0.6, 0.2, 0.8, 0.8)
	nyx_style.set_border_width_all(2)
	nyx_style.set_corner_radius_all(8)
	nyx_style.set_content_margin_all(14.0)
	nyx_style.shadow_color = Color(0.8, 0.2, 1.0, 0.35)
	nyx_style.shadow_size = 8
	nyx_card.add_theme_stylebox_override("panel", nyx_style)

	var nyx_vbox := VBoxContainer.new()
	nyx_vbox.add_theme_constant_override("separation", 8)

	var nyx_header := HBoxContainer.new()
	var nyx_title := Label.new()
	nyx_title.text = "PROYECTO NYX — ESPADACHINA DIMENSIONAL [MELEE]"
	nyx_title.add_theme_font_size_override("font_size", 16)
	nyx_title.add_theme_color_override("font_color", Color(0.95, 0.4, 1.0))
	nyx_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nyx_header.add_child(nyx_title)

	var nyx_status := Label.new()
	if is_nyx_unlocked:
		nyx_status.text = "✓ DESBLOQUEADA"
		nyx_status.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	else:
		nyx_status.text = "🔒 BLOQUEADA (%d/10)" % mini(total_bosses, 10)
		nyx_status.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	nyx_status.add_theme_font_size_override("font_size", 15)
	nyx_header.add_child(nyx_status)
	nyx_vbox.add_child(nyx_header)

	var nyx_desc := Label.new()
	nyx_desc.text = "Guerrera cuerpo a cuerpo armada con espada en medialuna (ráfagas escalables con Proyectiles), corte ciclónico 360° que desintegra balas enemigas y dash teleport con línea de corte letal."
	nyx_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nyx_desc.add_theme_font_size_override("font_size", 13)
	nyx_desc.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 0.85))
	nyx_vbox.add_child(nyx_desc)

	# Barra de progreso de Jefes
	var bar_hbox := HBoxContainer.new()
	bar_hbox.add_theme_constant_override("separation", 12)

	var pbar := ProgressBar.new()
	pbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pbar.custom_minimum_size = Vector2(0, 18)
	pbar.min_value = 0.0
	pbar.max_value = 10.0
	pbar.value = float(mini(total_bosses, 10))
	pbar.show_percentage = false
	bar_hbox.add_child(pbar)

	var pbar_lbl := Label.new()
	pbar_lbl.text = "%d / 10 Jefes Derrotados" % mini(total_bosses, 10)
	pbar_lbl.add_theme_font_size_override("font_size", 13)
	pbar_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	bar_hbox.add_child(pbar_lbl)
	nyx_vbox.add_child(bar_hbox)

	nyx_card.add_child(nyx_vbox)
	root_vbox.add_child(nyx_card)

	# 2. Rejilla de Estadísticas de Carrera
	var stats_panel := PanelContainer.new()
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stats_style := StyleBoxFlat.new()
	stats_style.bg_color = Color(0.03, 0.05, 0.09, 0.88)
	stats_style.border_color = Color(0.1, 0.4, 0.7, 0.6)
	stats_style.set_border_width_all(1)
	stats_style.set_corner_radius_all(6)
	stats_style.set_content_margin_all(16.0)
	stats_panel.add_theme_stylebox_override("panel", stats_style)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 12)

	_add_stat_row(grid, "Tiempo Total Sobrevivido:", time_fmt, Color(0.4, 0.9, 1.0))
	_add_stat_row(grid, "Jefes Titanes Derrotados:", str(total_bosses), Color(1.0, 0.4, 0.3))
	_add_stat_row(grid, "Partidas Jugadas:", str(int(career_data.get("total_runs_played", 0))), Color(0.85, 0.9, 1.0))
	_add_stat_row(grid, "Partidas Ganadas (Victorias):", str(int(career_data.get("total_runs_cleared", 0))), Color(0.2, 1.0, 0.5))
	_add_stat_row(grid, "Enemigos Totales Neutralizados:", str(int(career_data.get("total_enemies_killed", 0))), Color(1.0, 0.6, 0.2))
	_add_stat_row(grid, "Créditos Recolectados:", "%d C" % int(career_data.get("total_credits_collected", 0)), Color(1.0, 0.85, 0.2))
	_add_stat_row(grid, "Biomasa Acumulada:", str(int(career_data.get("total_biomass_collected", 0))), Color(0.3, 0.9, 0.7))
	_add_stat_row(grid, "Satélites de Enlace Activados:", str(int(career_data.get("total_satellites_activated", 0))), Color(0.0, 0.9, 1.0))

	stats_panel.add_child(grid)
	root_vbox.add_child(stats_panel)

	career_container.add_child(root_vbox)

func _add_stat_row(grid: GridContainer, label_text: String, value_text: String, val_color: Color) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.9))
	grid.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 15)
	val.add_theme_color_override("font_color", val_color)
	grid.add_child(val)

func _populate_table() -> void:
	if not list_container:
		return
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
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_switch_tab(0)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_2:
			_switch_tab(1)
			get_viewport().set_input_as_handled()
