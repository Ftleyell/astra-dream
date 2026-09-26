class_name GameOverModal
extends CanvasLayer

## GameOverModal.gd
## Pantalla de Fin de Partida (Game Over / Misión Fallida).
## Muestra telemetría completa de la incursión:
## - Puntuación total calculada
## - Indicador destacado de Nuevo Récord / Posición en el Top 10
## - Oleadas sobrevividas, tiempo de juego, bajas y jefes derrotados
## - Materiales y recursos recolectados: Biomasa, Antimateria y Créditos
## - Pactos Astra activos, Ítems de inventario y Armas equipadas
## - Acciones rápidas: [R] Reiniciar Incursión / [H] Volver al HUB

signal restart_requested()
signal hub_requested()
signal closed()

@onready var panel: Panel = $Panel
@onready var backdrop: ColorRect = $Backdrop

# Header & Score
@onready var title_label: Label = $Panel/VBoxContainer/HeaderContainer/TitleLabel
@onready var pilot_label: Label = $Panel/VBoxContainer/HeaderContainer/PilotLabel
@onready var highscore_badge: PanelContainer = $Panel/VBoxContainer/HeaderContainer/HighscoreBadge
@onready var highscore_label: Label = $Panel/VBoxContainer/HeaderContainer/HighscoreBadge/HighscoreLabel
@onready var score_value_label: Label = $Panel/VBoxContainer/ScoreBanner/ScoreValueLabel

# Stats Labels
@onready var wave_val_label: Label = $Panel/VBoxContainer/MainContent/StatsPanel/StatsVBox/WaveRow/Val
@onready var time_val_label: Label = $Panel/VBoxContainer/MainContent/StatsPanel/StatsVBox/TimeRow/Val
@onready var bosses_val_label: Label = $Panel/VBoxContainer/MainContent/StatsPanel/StatsVBox/BossesRow/Val
@onready var kills_val_label: Label = $Panel/VBoxContainer/MainContent/StatsPanel/StatsVBox/KillsRow/Val

# Resource Labels
@onready var biomass_val_label: Label = $Panel/VBoxContainer/MainContent/StatsPanel/StatsVBox/BiomassRow/Val
@onready var dark_matter_val_label: Label = $Panel/VBoxContainer/MainContent/StatsPanel/StatsVBox/DarkMatterRow/Val
@onready var credits_val_label: Label = $Panel/VBoxContainer/MainContent/StatsPanel/StatsVBox/CreditsRow/Val

# Loadout Containers
@onready var arcanas_container: HFlowContainer = $Panel/VBoxContainer/MainContent/LoadoutPanel/LoadoutScroll/LoadoutVBox/ArcanasContainer
@onready var items_container: HFlowContainer = $Panel/VBoxContainer/MainContent/LoadoutPanel/LoadoutScroll/LoadoutVBox/ItemsContainer
@onready var weapons_container: HFlowContainer = $Panel/VBoxContainer/MainContent/LoadoutPanel/LoadoutScroll/LoadoutVBox/WeaponsContainer

# Action Buttons
@onready var restart_button: Button = $Panel/VBoxContainer/BottomBar/RestartButton
@onready var hub_button: Button = $Panel/VBoxContainer/BottomBar/HubButton

var is_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 70
	hide()

	if restart_button:
		UIFocusHelper.apply_cyber_focus(restart_button)
		restart_button.pressed.connect(_on_restart_pressed)
	if hub_button:
		UIFocusHelper.apply_cyber_focus(hub_button)
		hub_button.pressed.connect(_on_hub_pressed)

func show_game_over(data: Dictionary) -> void:
	is_active = true
	_populate_screen(data)
	show()

	# Sonido dramático de apertura
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("menu_open", 1.0, 1.0)

	if restart_button:
		restart_button.grab_focus()

func _populate_screen(data: Dictionary) -> void:
	# 1. Puntuación & Récord
	var score: int = int(data.get("score", 0))
	if score_value_label:
		score_value_label.text = "%s PTS" % _format_number(score)

	var is_victory: bool = bool(data.get("victory", false))
	var ending_title: String = str(data.get("ending_title", ""))

	if title_label:
		if is_victory:
			title_label.text = "★ ¡VICTORIA ESTELAR - INCURSIÓN CUMPLIDA! ★"
			title_label.modulate = Color(0.2, 1.0, 0.65, 1.0)
		else:
			title_label.text = "SEÑAL DE NAVE PERDIDA (GAME OVER)"
			title_label.modulate = Color(1.0, 0.25, 0.25, 1.0)

	var is_new_record: bool = bool(data.get("is_new_highscore", false))
	var rank: int = int(data.get("rank", -1))

	if highscore_badge:
		if not ending_title.is_empty():
			highscore_badge.show()
			if highscore_label:
				highscore_label.text = "✦ %s ✦" % ending_title.to_upper()
				var e_type: String = str(data.get("ending_type", "neutral"))
				if e_type == "pacifist":
					highscore_label.modulate = Color(0.2, 0.95, 1.0, 1.0)
				elif e_type == "slayer":
					highscore_label.modulate = Color(1.0, 0.25, 0.35, 1.0)
				else:
					highscore_label.modulate = Color(1.0, 0.85, 0.2, 1.0)
		elif is_new_record:
			highscore_badge.show()
			if highscore_label:
				highscore_label.text = "★ ¡NUEVO RÉCORD HISTÓRICO - TOP #1! ★"
				highscore_label.modulate = Color(1.0, 0.85, 0.2, 1.0)
		elif rank > 0 and rank <= 10:
			highscore_badge.show()
			if highscore_label:
				highscore_label.text = "★ RÉCORD REGISTRADO EN EL TOP #%d ★" % rank
				highscore_label.modulate = Color(0.3, 0.9, 1.0, 1.0)
		else:
			highscore_badge.hide()

	# 2. Piloto
	var pilot_name: String = str(data.get("pilot_name", "Nova"))
	if pilot_label:
		var pilot_line := "PILOTO: %s" % pilot_name.to_upper()
		if not str(data.get("epilogue_text", "")).is_empty():
			pilot_line += " | %s" % str(data.get("epilogue_text", ""))
		pilot_label.text = pilot_line

	# 3. Estadísticas de Incursión
	if wave_val_label:
		wave_val_label.text = "Oleada %d" % int(data.get("waves_survived", 1))
	if time_val_label:
		time_val_label.text = str(data.get("time_formatted", "00:00"))
	if bosses_val_label:
		bosses_val_label.text = "%d Derrotados" % int(data.get("bosses_defeated", 0))
	if kills_val_label:
		kills_val_label.text = "%d Bajas" % int(data.get("enemies_killed", 0))

	# 4. Materiales & Economía
	if biomass_val_label:
		biomass_val_label.text = "+%d ☣" % int(data.get("biomass_collected", 0))
	if dark_matter_val_label:
		dark_matter_val_label.text = "+%d ✦" % int(data.get("dark_matter_collected", 0))
	if credits_val_label:
		credits_val_label.text = "+%d ⬡" % int(data.get("credits_collected", 0))

	# 5. Pactos Astra
	_populate_arcanas(data.get("arcanas", []))

	# 6. Ítems de Inventario
	_populate_items(data.get("items", []))

	# 7. Armas Equipadas
	_populate_weapons(data.get("weapons", []))

func _populate_arcanas(arcanas_list: Array) -> void:
	if not arcanas_container:
		return
	for c in arcanas_container.get_children():
		c.queue_free()

	if arcanas_list.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Ningún pacto astra sellado."
		empty_lbl.modulate = Color(0.6, 0.65, 0.75, 0.6)
		empty_lbl.add_theme_font_size_override("font_size", 12)
		arcanas_container.add_child(empty_lbl)
		return

	for arc in arcanas_list:
		if not (arc is ArcanaData):
			continue
		var arc_data := arc as ArcanaData
		var chip := _create_chip(arc_data.name, arc_data.color_accent, arc_data.icon)
		arcanas_container.add_child(chip)

func _populate_items(items_list: Array) -> void:
	if not items_container:
		return
	for c in items_container.get_children():
		c.queue_free()

	if items_list.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Ningún ítem recolectado."
		empty_lbl.modulate = Color(0.6, 0.65, 0.75, 0.6)
		empty_lbl.add_theme_font_size_override("font_size", 12)
		items_container.add_child(empty_lbl)
		return

	for item_entry in items_list:
		var item_res: ItemData = item_entry.get("data") if item_entry is Dictionary else null
		var count: int = int(item_entry.get("count", 1)) if item_entry is Dictionary else 1
		if not item_res:
			continue
		var chip_text := item_res.item_name
		if count > 1:
			chip_text += " x%d" % count
		var chip := _create_chip(chip_text, Color(0.2, 0.9, 0.6, 1.0), item_res.icon)
		items_container.add_child(chip)

func _populate_weapons(weapons_list: Array) -> void:
	if not weapons_container:
		return
	for c in weapons_container.get_children():
		c.queue_free()

	if weapons_list.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Arma básica estándar."
		empty_lbl.modulate = Color(0.6, 0.65, 0.75, 0.6)
		empty_lbl.add_theme_font_size_override("font_size", 12)
		weapons_container.add_child(empty_lbl)
		return

	for w_info in weapons_list:
		var w_name: String = ""
		var w_lvl: int = 1
		var w_icon: Texture2D = null
		if w_info is Dictionary:
			w_name = str(w_info.get("name", "Arma"))
			w_lvl = int(w_info.get("level", 1))
		elif "weapon_data" in w_info and w_info.weapon_data:
			w_name = w_info.weapon_data.name if "name" in w_info.weapon_data else str(w_info.weapon_data.weapon_id)
			w_lvl = int(w_info.level) if "level" in w_info else 1
			w_icon = w_info.weapon_data.icon if "icon" in w_info.weapon_data else null
		elif "weapon_id" in w_info:
			w_name = str(w_info.weapon_id)

		var chip_text := "%s (Nvl %d)" % [w_name, w_lvl]
		var chip := _create_chip(chip_text, Color(1.0, 0.75, 0.2, 1.0), w_icon)
		weapons_container.add_child(chip)

func _create_chip(text: String, accent_color: Color, icon_tex: Texture2D = null) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.12, 0.85)
	style.border_color = accent_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(5.0)
	chip.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	if icon_tex:
		var tr := TextureRect.new()
		tr.texture = icon_tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(16, 16)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(tr)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = Color(0.9, 0.95, 1.0, 1.0)
	hbox.add_child(lbl)

	chip.add_child(hbox)
	return chip

func _format_number(n: int) -> String:
	var s := str(n)
	var res := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res

func _on_restart_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 1.1, 1.0)
	restart_requested.emit()

func _on_hub_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 1.0, 1.0)
	hub_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_active:
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_R:
			_on_restart_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_H or event.keycode == KEY_ESCAPE:
			_on_hub_pressed()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			_on_hub_pressed()
			get_viewport().set_input_as_handled()
