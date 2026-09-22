class_name CharacterStatsOverlay
extends CanvasLayer

## CharacterStatsOverlay.gd
## Cuadro de Mando Táctico y Estadísticas en tiempo real [C].
## Pausa el juego para inspeccionar los atributos completos de la heroína en combate,
## bonos del árbol de habilidades e ítems adquiridos, con estética Psycho-Pop / Cockpit
## adaptada al color insignia del piloto y formato "ESTADISTICA = VALOR".

@export var player: Player = null

@onready var backdrop: ColorRect = $Backdrop
@onready var main_container: PanelContainer = $CenterContainer/MainPanel
@onready var close_button: Button = $CenterContainer/MainPanel/Margin/VBox/TopBar/CloseButton

# Cabecera y Lado Izquierdo
@onready var cockpit_title: Label = $CenterContainer/MainPanel/Margin/VBox/TopBar/CockpitTitle
@onready var portrait_panel: PanelContainer = $CenterContainer/MainPanel/Margin/VBox/ContentHBox/LeftColumn/PortraitContainer/PortraitPanel
@onready var portrait_texture: TextureRect = $CenterContainer/MainPanel/Margin/VBox/ContentHBox/LeftColumn/PortraitContainer/PortraitPanel/PortraitTexture
@onready var portrait_emblem: Polygon2D = $CenterContainer/MainPanel/Margin/VBox/ContentHBox/LeftColumn/PortraitContainer/PortraitPanel/PortraitEmblem
@onready var pilot_name_label: Label = $CenterContainer/MainPanel/Margin/VBox/ContentHBox/LeftColumn/PilotNameLabel
@onready var pilot_title_label: Label = $CenterContainer/MainPanel/Margin/VBox/ContentHBox/LeftColumn/PilotTitleLabel
@onready var level_label: Label = $CenterContainer/MainPanel/Margin/VBox/ContentHBox/LeftColumn/InfoPanel/VBox/LevelLabel
@onready var biomass_label: Label = $CenterContainer/MainPanel/Margin/VBox/ContentHBox/LeftColumn/InfoPanel/VBox/BiomassLabel
@onready var perks_list: VBoxContainer = $CenterContainer/MainPanel/Margin/VBox/ContentHBox/LeftColumn/PerksScroll/PerksList

# Columna Derecha (Estadísticas Clasificadas)
@onready var stats_scroll_container: VBoxContainer = $CenterContainer/MainPanel/Margin/VBox/ContentHBox/RightColumn/Scroll/StatsVBox

var is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if close_button:
		close_button.pressed.connect(close_stats)


func _input(event: InputEvent) -> void:
	# Captura prioritaria de tecla C y acción show_stats
	var is_c_pressed := false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_C or key_event.physical_keycode == KEY_C:
				is_c_pressed = true

	if is_c_pressed or event.is_action_pressed("show_stats"):
		if is_open:
			close_stats()
		else:
			open_stats()
		get_viewport().set_input_as_handled()
		return

	if is_open:
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
				close_stats()
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("ui_cancel"):
			close_stats()
			get_viewport().set_input_as_handled()
			return


func open_stats() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(player) and get_parent():
		player = get_parent().get_node_or_null("Player") as Player
	if not is_instance_valid(player) or not is_inside_tree():
		return

	# Si el menú de pausa [ESC] ya está abierto, no sobreponer
	var pause_menu = get_tree().get_first_node_in_group("pause_menu")
	if pause_menu and pause_menu.visible:
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
	tw.tween_property(main_container, "scale", Vector2(0.94, 0.94), 0.12)
	tw.parallel().tween_property(main_container, "modulate:a", 0.0, 0.12)
	await tw.finished
	visible = false
	var parent_game = get_parent()
	if parent_game and parent_game.has_method("is_any_combat_modal_active") and parent_game.is_any_combat_modal_active():
		get_tree().paused = true
		if parent_game.has_method("restore_combat_modal_focus"):
			parent_game.restore_combat_modal_focus()
	else:
		get_tree().paused = false


func _animate_open() -> void:
	main_container.pivot_offset = main_container.size * 0.5
	main_container.scale = Vector2(0.94, 0.94)
	main_container.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(main_container, "scale", Vector2.ONE, 0.22)
	tw.tween_property(main_container, "modulate:a", 1.0, 0.18)


func _refresh_display() -> void:
	if not is_instance_valid(player):
		return

	var data: CharacterData = player.character_data
	var stats: CharacterStats = player.stats
	var theme_col: Color = data.color if data else Color("#00F0FF")

	# 1. Aplicar estilo dinámico con el color del personaje a los marcos
	_apply_theme_colors(theme_col)

	# 2. Información del Piloto y Retrato
	if pilot_name_label:
		pilot_name_label.text = (data.display_name if data else "PILOTO").to_upper()
		pilot_name_label.add_theme_color_override("font_color", theme_col)

	if pilot_title_label:
		pilot_title_label.text = (data.title if data else "VANGUARDIA").to_upper()

	if level_label:
		level_label.text = "NIVEL DE COMBATE: %d" % player.current_level

	if biomass_label:
		biomass_label.text = "BIOMASA TOTAL: %d u." % SaveManager.get_biomass()

	# Retrato y silueta
	if portrait_texture and data and data.portrait_icon:
		portrait_texture.texture = data.portrait_icon
		portrait_texture.visible = true
	elif portrait_texture:
		portrait_texture.visible = false

	if portrait_emblem and data:
		portrait_emblem.color = theme_col
		if data.pts.size() >= 3:
			portrait_emblem.polygon = data.pts
			portrait_emblem.scale = Vector2(0.9, 0.9)
			portrait_emblem.visible = (portrait_texture == null or not portrait_texture.visible)
		else:
			portrait_emblem.visible = false

	# 3. Lista de Protocolos de Constelación
	_populate_perks_list(data, theme_col)

	# 4. Estadísticas clasificadas con formato "ESTADISTICA = VALOR"
	_populate_stats_display(data, stats, theme_col)


func _apply_theme_colors(col: Color) -> void:
	if main_container:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.04, 0.07, 0.96)
		sb.border_color = col
		sb.set_border_width_all(2)
		sb.border_width_top = 4
		sb.set_corner_radius_all(0)
		sb.shadow_color = Color(col.r, col.g, col.b, 0.2)
		sb.shadow_size = 14
		main_container.add_theme_stylebox_override("panel", sb)

	if portrait_panel:
		var sb_port := StyleBoxFlat.new()
		sb_port.bg_color = Color(0.06, 0.08, 0.12, 0.9)
		sb_port.border_color = col
		sb_port.set_border_width_all(2)
		sb_port.set_corner_radius_all(0)
		portrait_panel.add_theme_stylebox_override("panel", sb_port)

	if cockpit_title:
		cockpit_title.add_theme_color_override("font_color", col.lightened(0.3))


func _populate_perks_list(data: CharacterData, col: Color) -> void:
	if not perks_list:
		return

	for child in perks_list.get_children():
		child.queue_free()

	if not data:
		return

	var unlocked := SaveManager.get_character_unlocked_nodes(data.character_id)
	var active_perks: Array[String] = []

	for nid in unlocked:
		var s := String(nid)
		if s == "core":
			active_perks.append("⚛ MATRIZ NEURAL: Núcleo Activo")
		elif s.begins_with("speed_"):
			active_perks.append("⚡ IMPULSO VECTORIAL (+20% Velocidad)")
		elif s.begins_with("damage_"):
			active_perks.append("⚔️ SOBREALIMENTACIÓN (+15% Daño)")
		elif s.begins_with("hp_") or s.begins_with("hull_"):
			active_perks.append("🛡️ NANO-BLINDAJE (+25 Max HP)")
		elif s.begins_with("crit_") or s.begins_with("overclock_") or s.begins_with("focus_"):
			active_perks.append("✦ SINCRONIZADOR ÓPTICO (+5% Crítico & Cadencia)")

	if active_perks.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Sin nodos activos en el Hub."
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		empty_lbl.add_theme_font_size_override("font_size", 11)
		perks_list.add_child(empty_lbl)
		return

	for perk_text in active_perks:
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.08, 0.12, 0.8)
		sb.border_color = col
		sb.border_width_left = 3
		sb.border_width_top = 0
		sb.border_width_right = 0
		sb.border_width_bottom = 0
		sb.set_corner_radius_all(0)
		p.add_theme_stylebox_override("panel", sb)

		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 8)
		m.add_theme_constant_override("margin_right", 8)
		m.add_theme_constant_override("margin_top", 4)
		m.add_theme_constant_override("margin_bottom", 4)
		p.add_child(m)

		var l := Label.new()
		l.text = perk_text
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		m.add_child(l)

		perks_list.add_child(p)


func _populate_stats_display(data: CharacterData, stats: CharacterStats, col: Color) -> void:
	if not stats_scroll_container:
		return

	for child in stats_scroll_container.get_children():
		child.queue_free()

	if not stats or not data:
		return

	# Definición clasificada de todas las 14 estadísticas con formato exacto
	var categories := [
		{
			"title": "⚔️ SISTEMAS OFENSIVOS",
			"stats": [
				{"name": "DAÑO", "key": &"base_damage", "base": data.base_damage, "fmt": "%.1f", "suffix": ""},
				{"name": "VELOCIDAD DE ATAQUE", "key": &"attack_speed", "base": data.attack_speed, "fmt": "%.2f", "suffix": "x"},
				{"name": "CANTIDAD DE PROYECTILES", "key": &"projectile_count", "base": data.projectile_count, "fmt": "%.0f", "suffix": ""},
				{"name": "VELOCIDAD DE PROYECTIL", "key": &"projectile_speed", "base": data.projectile_speed, "fmt": "%.0f", "suffix": "%", "mult": 100.0},
				{"name": "TAMAÑO DE ARMAS", "key": &"weapon_size", "base": data.weapon_size, "fmt": "%.0f", "suffix": "%", "mult": 100.0},
				{"name": "PROBABILIDAD CRÍTICA", "key": &"crit_chance", "base": data.crit_chance, "fmt": "%.0f", "suffix": "%", "mult": 100.0},
				{"name": "DAÑO CRÍTICO", "key": &"crit_damage", "base": data.crit_damage, "fmt": "%.2f", "suffix": "x"},
			]
		},
		{
			"title": "🚀 PROPULSIÓN Y MOVILIDAD",
			"stats": [
				{"name": "VELOCIDAD DE MOVIMIENTO", "key": &"move_speed", "base": data.move_speed, "fmt": "%.0f", "suffix": " px/s"},
				{"name": "RECUPERACIÓN DE ENFRIAMIENTO", "key": &"cooldown_reduction", "base": data.cooldown_reduction, "fmt": "%.0f", "suffix": "%", "mult": 100.0},
			]
		},
		{
			"title": "🧲 RECOLECCIÓN Y PROGRESIÓN",
			"stats": [
				{"name": "RANGO DE RECOLECCIÓN", "key": &"pickup_radius", "base": data.pickup_radius, "fmt": "%.0f", "suffix": " px"},
				{"name": "GANANCIA DE EXP", "key": &"exp_multiplier", "base": data.exp_multiplier, "fmt": "%.0f", "suffix": "%", "mult": 100.0},
				{"name": "SUERTE", "key": &"luck", "base": data.luck, "fmt": "%+.0f", "suffix": ""},
			]
		},
		{
			"title": "🛡️ DEFENSA Y BLINDAJE",
			"stats": [
				{"name": "VIDA MÁXIMA", "key": &"max_health", "base": data.max_health, "fmt": "%.0f", "suffix": " HP"},
				{"name": "REGENERACIÓN DE VIDA", "key": &"health_regen", "base": data.health_regen, "fmt": "%.1f", "suffix": "/s"},
				{"name": "ARMADURA", "key": &"armor", "base": data.armor, "fmt": "%.0f", "suffix": ""},
			]
		}
	]

	for cat in categories:
		# Cabecera de Categoría
		var cat_lbl := Label.new()
		cat_lbl.text = cat["title"]
		cat_lbl.add_theme_font_size_override("font_size", 14)
		cat_lbl.add_theme_color_override("font_color", col.lightened(0.2))
		stats_scroll_container.add_child(cat_lbl)

		# Rejilla de 2 columnas para las estadísticas de esta categoría
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 8)
		stats_scroll_container.add_child(grid)

		for entry in cat["stats"]:
			var key: StringName = entry["key"]
			var current_val: float = stats.get_stat(key)
			var base_val: float = entry["base"]
			var mult: float = entry.get("mult", 1.0)
			var fmt: String = entry["fmt"]
			var suffix: String = entry["suffix"]

			# Formato exacto solicitado: "ESTADISTICA = VALOR"
			var card := _create_stat_entry_card(entry["name"], current_val, base_val, fmt, suffix, mult, col)
			grid.add_child(card)

		# Espaciador entre categorías
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		stats_scroll_container.add_child(spacer)


func _create_stat_entry_card(stat_name: String, current: float, base: float, fmt: String, suffix: String, mult: float, theme_col: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 44)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.10, 0.9)
	sb.border_color = theme_col.darkened(0.4)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(hbox)

	var displayed_val := (fmt % (current * mult)) + suffix
	var is_buffed := (current > base + 0.001)

	# Formato canónico: "ESTADISTICA = NUMERO DE ESTADISTICA"
	var lbl_formula := Label.new()
	lbl_formula.text = "%s = %s" % [stat_name, displayed_val]
	lbl_formula.add_theme_font_size_override("font_size", 13)
	lbl_formula.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if is_buffed:
		lbl_formula.add_theme_color_override("font_color", Color("#00FF9D"))
	else:
		lbl_formula.add_theme_color_override("font_color", Color.WHITE)

	hbox.add_child(lbl_formula)

	# Si está potenciado, mostrar la comparativa base a la derecha
	if is_buffed:
		var lbl_base := Label.new()
		var base_display := (fmt % (base * mult)) + suffix
		lbl_base.text = "(Base: %s)" % base_display
		lbl_base.add_theme_font_size_override("font_size", 11)
		lbl_base.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.8))
		hbox.add_child(lbl_base)

	return panel
