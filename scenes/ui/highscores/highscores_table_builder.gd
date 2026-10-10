class_name HighscoresTableBuilder
extends RefCounted

## Responsable de la construcción programática y renderizado de las vistas de datos:
## - Panel y filas de estadísticas de carrera espacial.
## - Filas y tabla de récords del Salón de la Fama (Top 10).

static func populate_career_view(career_container: ScrollContainer) -> void:
	if not career_container:
		return
	for child in career_container.get_children():
		child.queue_free()

	var career_data: Dictionary = SaveManager.get_career_stats()
	var total_time_sec: float = float(career_data.get("total_time_survived", 0.0))
	var hours: int = int(total_time_sec) / 3600
	var minutes: int = (int(total_time_sec) % 3600) / 60
	var seconds: int = int(total_time_sec) % 60
	var time_fmt: String = "%02dh %02dm %02ds" % [hours, minutes, seconds]

	var total_bosses: int = int(career_data.get("total_bosses_killed", 0))

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 16)

	# Rejilla de Estadísticas de Carrera
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

static func populate_table(list_container: VBoxContainer) -> void:
	if not list_container:
		return
	for child in list_container.get_children():
		child.queue_free()

	var records: Array = SaveManager.get_top_highscores()
	if records.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No hay récords registrados todavía.\n¡Completa una partida para ingresar al Salón de la Fama!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.modulate = Color(0.6, 0.7, 0.8, 0.8)
		list_container.add_child(empty_lbl)
		return

	for idx: int in range(records.size()):
		var entry: Dictionary = records[idx]
		var row: PanelContainer = create_record_row(idx + 1, entry)
		list_container.add_child(row)

static func create_record_row(rank: int, entry: Dictionary) -> PanelContainer:
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

static func _add_stat_row(grid: GridContainer, label_text: String, value_text: String, val_color: Color) -> void:
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
