class_name CharacterStatsOverlay
extends CanvasLayer

## CharacterStatsOverlay.gd
## Cuadro de Mando Táctico y Estadísticas en tiempo real [C].
## Pausa el juego para inspeccionar los atributos base, bonus de constelación,
## y mejoras de la heroína en combate con estética Psycho-Pop / Cockpit.

@export var player: Player = null

@onready var backdrop: ColorRect = $Backdrop
@onready var main_container: PanelContainer = $CenterContainer/MainPanel
@onready var close_button: Button = $CenterContainer/MainPanel/Margin/VBox/TopBar/CloseButton

# Cabecera
@onready var portrait_texture: TextureRect = $CenterContainer/MainPanel/Margin/VBox/TopBar/PilotHeader/PortraitFrame/PortraitTexture
@onready var portrait_emblem: Polygon2D = $CenterContainer/MainPanel/Margin/VBox/TopBar/PilotHeader/PortraitFrame/PortraitEmblem
@onready var pilot_name_label: Label = $CenterContainer/MainPanel/Margin/VBox/TopBar/PilotHeader/InfoVBox/PilotNameLabel
@onready var pilot_title_label: Label = $CenterContainer/MainPanel/Margin/VBox/TopBar/PilotHeader/InfoVBox/PilotTitleLabel
@onready var level_label: Label = $CenterContainer/MainPanel/Margin/VBox/TopBar/LevelContainer/LevelLabel
@onready var biomass_label: Label = $CenterContainer/MainPanel/Margin/VBox/TopBar/LevelContainer/BiomassLabel

# Columnas de Estadísticas
@onready var stats_grid: GridContainer = $CenterContainer/MainPanel/Margin/VBox/ContentHBox/StatsColumn/StatsGrid
@onready var skills_list: VBoxContainer = $CenterContainer/MainPanel/Margin/VBox/ContentHBox/SkillsColumn/Scroll/SkillsList

var is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if close_button:
		close_button.pressed.connect(close_stats)


func _unhandled_input(event: InputEvent) -> void:
	var triggered: bool = event.is_action_pressed("show_stats")
	if not triggered and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_C or event.keycode == KEY_C:
			triggered = true

	if triggered:
		if is_open:
			close_stats()
		else:
			open_stats()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		close_stats()
		get_viewport().set_input_as_handled()


func open_stats() -> void:
	if not player or not is_inside_tree():
		return
	# No abrir si ya hay otro menú de pausa o modal activo
	if get_tree().paused and not is_open:
		return

	is_open = true
	get_tree().paused = true
	visible = true

	_refresh_display()
	_animate_open()


func close_stats() -> void:
	if not is_open:
		return
	is_open = false
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(main_container, "scale", Vector2(0.92, 0.92), 0.12)
	tw.parallel().tween_property(main_container, "modulate:a", 0.0, 0.12)
	await tw.finished
	visible = false
	get_tree().paused = false


func _animate_open() -> void:
	main_container.pivot_offset = main_container.size * 0.5
	main_container.scale = Vector2(0.92, 0.92)
	main_container.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(main_container, "scale", Vector2.ONE, 0.22)
	tw.tween_property(main_container, "modulate:a", 1.0, 0.18)


func _refresh_display() -> void:
	var data: CharacterData = player.character_data
	var stats: CharacterStats = player.stats
	var theme_col: Color = data.color if data else Color("#00F0FF")

	# 1. Cabecera y Retrato
	if pilot_name_label:
		pilot_name_label.text = data.display_name.to_upper() if data else "PILOTO"
		pilot_name_label.add_theme_color_override("font_color", theme_col)
	if pilot_title_label:
		pilot_title_label.text = data.title.to_upper() if data else "VANGUARDIA"
	if level_label:
		level_label.text = "NIVEL DE COMBATE: %d" % player.current_level
	if biomass_label:
		biomass_label.text = "BIOMASA TOTAL: %d u." % SaveManager.get_biomass()

	var tex: Texture2D = data.portrait_icon if data else null
	if not tex and data:
		var ppath := "res://assets/portraits/portrait_%s.png" % str(data.character_id).to_lower()
		if ResourceLoader.exists(ppath):
			tex = load(ppath) as Texture2D

	if portrait_texture and tex:
		portrait_texture.texture = tex
		portrait_texture.visible = true
		if portrait_emblem:
			portrait_emblem.visible = false
	elif portrait_emblem and data:
		portrait_emblem.polygon = data.pts
		portrait_emblem.color = theme_col
		portrait_emblem.visible = true
		if portrait_texture:
			portrait_texture.visible = false

	# 2. Rejilla de Estadísticas en Tiempo Real
	_populate_stats_grid(data, stats, theme_col)

	# 3. Lista de Mejoras Activas de la Constelación
	_populate_skills_list(data, theme_col)


func _populate_stats_grid(data: CharacterData, stats: CharacterStats, col: Color) -> void:
	if not stats_grid:
		return

	for c in stats_grid.get_children():
		c.queue_free()

	var cur_hp := player.current_health
	var max_hp := stats.get_stat(&"max_health")
	var spd := stats.get_stat(&"move_speed")
	var dmg := stats.get_stat(&"base_damage")
	var crit := stats.get_stat(&"crit_chance") * 100.0
	var crit_mult := stats.get_stat(&"crit_damage")
	var atk_spd := stats.get_stat(&"attack_speed")
	var arm := stats.get_stat(&"armor")
	var lck := stats.get_stat(&"luck")
	var regen := stats.get_stat(&"health_regen")
	var magnet := stats.get_stat(&"pickup_radius")

	var stat_entries: Array[Dictionary] = [
		{"name": "SALUD", "val": "%.0f / %.0f" % [cur_hp, max_hp], "base": "Base: %.0f" % (data.max_health if data else 100.0), "icon": "❤️"},
		{"name": "VELOCIDAD", "val": "%.0f px/s" % spd, "base": "Base: %.0f" % (data.move_speed if data else 320.0), "icon": "⚡"},
		{"name": "DAÑO BASE", "val": "%.1f" % dmg, "base": "Base: %.0f" % (data.base_damage if data else 40.0), "icon": "⚔️"},
		{"name": "PROB. CRÍTICA", "val": "%.1f%%" % crit, "base": "Base: %.0f%%" % ((data.crit_chance if data else 0.05) * 100.0), "icon": "🎯"},
		{"name": "DAÑO CRÍTICO", "val": "%.1fx" % crit_mult, "base": "Multiplicador", "icon": "💥"},
		{"name": "CADENCIA", "val": "%.2fx" % atk_spd, "base": "Base: 1.0x", "icon": "⏱️"},
		{"name": "ARMADURA", "val": "%.0f" % arm, "base": "Defensa plana", "icon": "🛡️"},
		{"name": "SUERTE", "val": "+%.0f" % lck, "base": "Bono de botín", "icon": "🍀"},
		{"name": "REGENERACIÓN", "val": "%.1f HP/s" % regen, "base": "Recuperación", "icon": "🧪"},
		{"name": "RADIO IMÁN", "val": "%.0f px" % magnet, "base": "Aspiración EXP", "icon": "🧲"}
	]

	for entry in stat_entries:
		var card := _create_stat_card(entry["icon"], entry["name"], entry["val"], entry["base"], col)
		stats_grid.add_child(card)


func _create_stat_card(icon: String, stat_name: String, value_str: String, base_str: String, col: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(170, 72)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.10, 0.95)
	sb.border_color = col.darkened(0.2)
	sb.border_width_left = 4
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	var lbl_name := Label.new()
	lbl_name.text = "%s %s" % [icon, stat_name]
	lbl_name.add_theme_font_size_override("font_size", 11)
	lbl_name.add_theme_color_override("font_color", col.lightened(0.4))
	vbox.add_child(lbl_name)

	var lbl_val := Label.new()
	lbl_val.text = value_str
	lbl_val.add_theme_font_size_override("font_size", 16)
	lbl_val.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(lbl_val)

	var lbl_base := Label.new()
	lbl_base.text = base_str
	lbl_base.add_theme_font_size_override("font_size", 10)
	lbl_base.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	vbox.add_child(lbl_base)

	return panel


func _populate_skills_list(data: CharacterData, col: Color) -> void:
	if not skills_list:
		return

	for c in skills_list.get_children():
		c.queue_free()

	if not data:
		return

	var unlocked := SaveManager.get_character_unlocked_nodes(data.character_id)
	var active_nodes: Array[String] = []

	for nid in unlocked:
		var s := String(nid)
		if s == "core":
			active_nodes.append("⚛ NÚCLEO PRIMARIO: Matriz Neural Activa")
		elif s.begins_with("speed_"):
			active_nodes.append("⚡ IMPULSO VECTORIAL (+20% Velocidad de Movimiento)")
		elif s.begins_with("damage_"):
			active_nodes.append("⚔️ SOBREALIMENTACIÓN (+15% Daño de Disparo)")
		elif s.begins_with("hp_") or s.begins_with("hull_"):
			active_nodes.append("🛡️ NANO-BLINDAJE (+25 Puntos de Salud Máxima)")
		elif s.begins_with("crit_") or s.begins_with("overclock_") or s.begins_with("focus_"):
			active_nodes.append("✦ SINCRONIZADOR ÓPTICO (+5% Crítico & +5% Cadencia)")

	if active_nodes.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No hay mejoras activas en el Árbol de Habilidades.\nVisita el Hub para activar nodos."
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		empty_lbl.add_theme_font_size_override("font_size", 12)
		skills_list.add_child(empty_lbl)
		return

	for txt in active_nodes:
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.10, 0.14, 0.8)
		sb.border_color = col
		sb.border_width_left = 3
		sb.set_border_width_all(1)
		sb.border_width_left = 3
		sb.set_corner_radius_all(0)
		p.add_theme_stylebox_override("panel", sb)

		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 8)
		m.add_theme_constant_override("margin_right", 8)
		m.add_theme_constant_override("margin_top", 6)
		m.add_theme_constant_override("margin_bottom", 6)
		p.add_child(m)

		var l := Label.new()
		l.text = txt
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		m.add_child(l)

		skills_list.add_child(p)
