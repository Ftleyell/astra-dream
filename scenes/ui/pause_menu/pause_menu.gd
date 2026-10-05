class_name PauseMenu
extends CanvasLayer

const HighscoresModalScript := preload("res://scenes/ui/highscores/highscores_modal.gd")

@export var player: Player

@onready var resume_button: Button = $Panel/VBoxContainer/BottomBar/ResumeButton
@onready var settings_button: Button = $Panel/VBoxContainer/BottomBar/SettingsButton
@onready var highscores_button: Button = $Panel/VBoxContainer/BottomBar/HighscoresButton
@onready var save_quit_button: Button = $Panel/VBoxContainer/BottomBar/SaveQuitButton
@onready var restart_button: Button = $Panel/VBoxContainer/BottomBar/RestartButton
@onready var hub_button: Button = get_node_or_null("Panel/VBoxContainer/BottomBar/HubButton")
@onready var menu_button: Button = $Panel/VBoxContainer/BottomBar/MenuButton

@onready var stats_container: VBoxContainer = $Panel/VBoxContainer/ContentHBox/StatsColumn/StatsScroll/StatsList
@onready var items_container: VBoxContainer = $Panel/VBoxContainer/ContentHBox/ItemsColumn/ItemsScroll/ItemsList
@onready var upgrades_container: VBoxContainer = $Panel/VBoxContainer/ContentHBox/UpgradesColumn/UpgradesScroll/UpgradesList
@onready var settings_modal: SettingsModal = $SettingsModal
@onready var highscores_modal: CanvasLayer = $HighscoresModal

const RUN_STATS_CONFIG: Array[Dictionary] = [
	{"name": "DAÑO", "key": &"base_damage", "fmt": "%.1f", "suffix": ""},
	{"name": "VEL. ATAQUE", "key": &"attack_speed", "fmt": "%.2f", "suffix": "x"},
	{"name": "PROB. CRÍTICA", "key": &"crit_chance", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "DAÑO CRÍTICO", "key": &"crit_damage", "fmt": "%.2f", "suffix": "x"},
	{"name": "PROYECTILES", "key": &"projectile_count", "fmt": "%.0f", "suffix": ""},
	{"name": "VEL. PROYECTIL", "key": &"projectile_speed", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "TAMAÑO DE ARMA", "key": &"weapon_size", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "VEL. MOVIMIENTO", "key": &"move_speed", "fmt": "%.0f", "suffix": " px/s"},
	{"name": "ENFRIAMIENTO", "key": &"cooldown_reduction", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "VIDA MÁXIMA", "key": &"max_health", "fmt": "%.0f", "suffix": " HP"},
	{"name": "REGEN. VIDA", "key": &"health_regen", "fmt": "%.1f", "suffix": "/s"},
	{"name": "ARMADURA", "key": &"armor", "fmt": "%.0f", "suffix": ""},
	{"name": "RADIO RECOGIDA", "key": &"pickup_radius", "fmt": "%.0f", "suffix": " px"},
	{"name": "MULTIPLICADOR EXP", "key": &"exp_multiplier", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "MULTIPLICADOR CRÉDITOS", "key": &"credits_multiplier", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "MULTIPLICADOR BIOMASA", "key": &"biomass_multiplier", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "SUERTE", "key": &"luck", "fmt": "%+.0f", "suffix": ""},
	{"name": "MALDICIÓN", "key": &"curse", "fmt": "%.0f", "suffix": ""},
]

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
			# Si la tienda de satélite, briefing, diálogos o cinemáticas están activos, consumen o bloquean ESC prioritariamente
			var dialogic = get_node_or_null("/root/Dialogic")
			var is_dialogic_running: bool = bool(dialogic and "current_timeline" in dialogic and dialogic.current_timeline != null)
			if is_dialogic_running:
				return

			var parent_game = get_parent()
			if parent_game:
				if parent_game.has_method("is_satellite_shop_active") and parent_game.is_satellite_shop_active():
					return
				if "is_briefing_active" in parent_game and parent_game.is_briefing_active:
					return
				if "is_cockpit_active" in parent_game and parent_game.is_cockpit_active:
					parent_game.is_cockpit_active = false
				if "is_rival_cinematic_active" in parent_game and parent_game.is_rival_cinematic_active:
					return
				if "is_boss_transmission_active" in parent_game and parent_game.is_boss_transmission_active:
					parent_game.is_boss_transmission_active = false
				if "is_victory_dialogue_active" in parent_game and parent_game.is_victory_dialogue_active:
					return
				if parent_game.has_method("is_any_cutscene_active") and parent_game.is_any_cutscene_active():
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
	PauseArbitrator.acquire_pause(&"pause_menu")
	var hud: Node = get_tree().get_first_node_in_group("hud") if get_tree() else null
	if hud and hud.has_method("set_stats_dock_requested"):
		hud.set_stats_dock_requested(&"pause_menu", true)
	_refresh_build_inspector()
	show()
	_setup_button_navigation()
	resume_button.grab_focus()

func restore_focus() -> void:
	if visible and resume_button and is_instance_valid(resume_button):
		resume_button.grab_focus()

func resume_game() -> void:
	if is_instance_valid(player) and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(0.4)
	hide()
	var hud: Node = get_tree().get_first_node_in_group("hud") if get_tree() else null
	if hud and hud.has_method("set_stats_dock_requested"):
		hud.set_stats_dock_requested(&"pause_menu", false)
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
	PauseArbitrator.release_pause(&"pause_menu")
	if parent_game and parent_game.has_method("restore_combat_modal_focus") and parent_game.has_method("is_any_combat_modal_active") and parent_game.is_any_combat_modal_active():
		parent_game.restore_combat_modal_focus()

func _refresh_build_inspector() -> void:
	_populate_stats()
	_populate_items()
	_populate_upgrades()

func _populate_stats() -> void:
	if not stats_container:
		return
	for child in stats_container.get_children():
		child.queue_free()

	if not is_instance_valid(player) or not player.stats:
		var empty_lbl := Label.new()
		empty_lbl.text = "Sin datos de estadísticas."
		stats_container.add_child(empty_lbl)
		return

	var data: CharacterData = player.character_data
	var stats: CharacterStats = player.stats
	var theme_col: Color = data.color if data else Color("#00F0FF")

	for cfg: Dictionary in RUN_STATS_CONFIG:
		var key: StringName = cfg["key"]
		var current_val: float = stats.get_stat(key)
		var base_val: float = data.get(key) if (data and key in data) else current_val
		var mult: float = cfg.get("mult", 1.0)
		var fmt: String = cfg["fmt"]
		var suffix: String = cfg["suffix"]

		var displayed_val: String = (fmt % (current_val * mult)) + suffix
		var is_curse: bool = (key == &"curse")
		var is_buffed: bool = (current_val > base_val + 0.001) and not is_curse
		var is_cursed: bool = is_curse and current_val > 0.0

		var item_panel := PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(260, 22)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.06, 0.10, 0.85)
		sb.border_color = (Color("#FF4466") if is_cursed else (Color("#00FF9D") if is_buffed else theme_col.darkened(0.4)))
		sb.set_border_width_all(1)
		sb.border_width_left = 3
		sb.set_corner_radius_all(3)
		item_panel.add_theme_stylebox_override("panel", sb)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 1)
		margin.add_theme_constant_override("margin_bottom", 1)
		item_panel.add_child(margin)

		var hbox := HBoxContainer.new()
		margin.add_child(hbox)

		var lbl_name := Label.new()
		lbl_name.text = cfg["name"]
		lbl_name.add_theme_font_size_override("font_size", 10)
		lbl_name.add_theme_color_override("font_color", Color("#FF4466") if is_cursed else Color(0.8, 0.85, 0.9))
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl_name)

		var lbl_val := Label.new()
		lbl_val.text = displayed_val
		lbl_val.add_theme_font_size_override("font_size", 10)
		lbl_val.add_theme_color_override("font_color", Color("#FF4466") if is_cursed else (Color("#00FF9D") if is_buffed else Color.WHITE))
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_val.custom_minimum_size = Vector2(85, 0)
		hbox.add_child(lbl_val)

		stats_container.add_child(item_panel)

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
		empty_lbl.text = "Ningún ítem adquirido aún.\n(Encuentra cofres y satélites para equipar ítems)"
		empty_lbl.modulate = Color(0.6, 0.65, 0.75, 0.8)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		items_container.add_child(empty_lbl)
		return

	# Agrupar ítems por origen de procedencia
	var origin_order: Array[String] = [
		"COFRE ESPACIAL",
		"TIENDA DE SATÉLITE",
		"FORJA CUÁNTICA",
		"BOTÍN DE RIVAL",
		"CONSUMIBLE / CAMPO"
	]

	var items_by_origin: Dictionary = {}
	for orig in origin_order:
		items_by_origin[orig] = []
	items_by_origin["OTROS"] = []

	for entry in all_items:
		var orig: String = entry.get("origin", "DESCONOCIDO")
		if items_by_origin.has(orig):
			items_by_origin[orig].append(entry)
		else:
			items_by_origin["OTROS"].append(entry)

	for orig in origin_order + ["OTROS"]:
		var group: Array = items_by_origin[orig]
		if group.is_empty():
			continue

		var header_panel := PanelContainer.new()
		var h_sb := StyleBoxFlat.new()
		h_sb.bg_color = Color(0.08, 0.12, 0.18, 0.8)
		h_sb.set_border_width_all(1)
		h_sb.border_color = Color(0.3, 0.7, 1.0, 0.5)
		h_sb.set_corner_radius_all(3)
		header_panel.add_theme_stylebox_override("panel", h_sb)

		var h_margin := MarginContainer.new()
		h_margin.add_theme_constant_override("margin_left", 8)
		h_margin.add_theme_constant_override("margin_top", 3)
		h_margin.add_theme_constant_override("margin_bottom", 3)
		header_panel.add_child(h_margin)

		var orig_lbl := Label.new()
		orig_lbl.text = "◆ %s (%d)" % [orig, group.size()]
		orig_lbl.add_theme_font_size_override("font_size", 12)
		orig_lbl.modulate = Color(0.4, 0.9, 1.0)
		h_margin.add_child(orig_lbl)
		items_container.add_child(header_panel)

		for entry in group:
			var item: ItemData = entry["data"]
			var count: int = entry["count"]

			var panel := PanelContainer.new()
			panel.custom_minimum_size = Vector2(0, 44)
			var p_sb := StyleBoxFlat.new()
			p_sb.bg_color = Color(0.04, 0.06, 0.10, 0.75)
			p_sb.set_border_width_all(1)
			p_sb.border_color = Color(0.2, 0.35, 0.5, 0.4)
			p_sb.set_corner_radius_all(4)
			panel.add_theme_stylebox_override("panel", p_sb)

			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 8)

			var icon_rect := TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if item.icon:
				icon_rect.texture = item.icon
			hbox.add_child(icon_rect)

			var count_lbl := Label.new()
			count_lbl.text = "x%d" % count
			count_lbl.modulate = Color(1.0, 0.85, 0.2, 1.0)
			count_lbl.add_theme_font_size_override("font_size", 12)
			hbox.add_child(count_lbl)

			var vbox := VBoxContainer.new()
			vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var name_lbl := Label.new()
			name_lbl.text = item.item_name
			name_lbl.add_theme_font_size_override("font_size", 13)

			var desc_lbl := Label.new()
			desc_lbl.text = item.description
			desc_lbl.modulate = Color(0.7, 0.8, 0.9, 0.8)
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			desc_lbl.add_theme_font_size_override("font_size", 10)

			vbox.add_child(name_lbl)
			vbox.add_child(desc_lbl)
			hbox.add_child(vbox)

			var item_m := MarginContainer.new()
			item_m.add_theme_constant_override("margin_left", 6)
			item_m.add_theme_constant_override("margin_right", 6)
			item_m.add_theme_constant_override("margin_top", 4)
			item_m.add_theme_constant_override("margin_bottom", 4)
			item_m.add_child(hbox)
			panel.add_child(item_m)

			items_container.add_child(panel)

func _populate_upgrades() -> void:
	for child in upgrades_container.get_children():
		child.queue_free()

	# 1. Sección de Arcanas Activas
	if player and not player.active_arcanas.is_empty():
		var arc_header := PanelContainer.new()
		var a_sb := StyleBoxFlat.new()
		a_sb.bg_color = Color(0.15, 0.04, 0.12, 0.85)
		a_sb.border_color = Color("#FF1493")
		a_sb.set_border_width_all(1)
		a_sb.set_corner_radius_all(3)
		arc_header.add_theme_stylebox_override("panel", a_sb)

		var a_margin := MarginContainer.new()
		a_margin.add_theme_constant_override("margin_left", 8)
		a_margin.add_theme_constant_override("margin_top", 3)
		a_margin.add_theme_constant_override("margin_bottom", 3)
		arc_header.add_child(a_margin)

		var arc_title := Label.new()
		arc_title.text = "◈ PACTOS DE ARCANA (%d)" % player.active_arcanas.size()
		arc_title.add_theme_font_size_override("font_size", 12)
		arc_title.modulate = Color("#FF1493")
		a_margin.add_child(arc_title)
		upgrades_container.add_child(arc_header)

		for arc: ArcanaData in player.active_arcanas:
			var arc_panel := PanelContainer.new()
			var p_sb := StyleBoxFlat.new()
			p_sb.bg_color = Color(0.06, 0.03, 0.08, 0.8)
			p_sb.border_color = arc.color_accent if arc.color_accent != Color.BLACK else Color("#FF1493")
			p_sb.set_border_width_all(1)
			p_sb.border_width_left = 3
			p_sb.set_corner_radius_all(4)
			arc_panel.add_theme_stylebox_override("panel", p_sb)

			var m := MarginContainer.new()
			m.add_theme_constant_override("margin_left", 6)
			m.add_theme_constant_override("margin_right", 6)
			m.add_theme_constant_override("margin_top", 4)
			m.add_theme_constant_override("margin_bottom", 4)
			arc_panel.add_child(m)

			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 2)

			var t_lbl := Label.new()
			t_lbl.text = "✦ %s [%s]" % [arc.name, arc.get_quadrant_title().to_upper()]
			t_lbl.add_theme_font_size_override("font_size", 12)
			t_lbl.modulate = Color(1.0, 0.9, 0.4)
			v.add_child(t_lbl)

			var b_lbl := Label.new()
			b_lbl.text = "▲ %s" % arc.description_boon
			b_lbl.add_theme_font_size_override("font_size", 10)
			b_lbl.modulate = Color(0.4, 1.0, 0.6)
			b_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			v.add_child(b_lbl)

			if not arc.description_curse.is_empty():
				var c_lbl := Label.new()
				c_lbl.text = "▼ %s" % arc.description_curse
				c_lbl.add_theme_font_size_override("font_size", 10)
				c_lbl.modulate = Color(1.0, 0.4, 0.5)
				c_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				v.add_child(c_lbl)

			m.add_child(v)
			upgrades_container.add_child(arc_panel)

	# 2. Sección de Mejoras de Nivel (Stat Cards)
	var lvl_header := PanelContainer.new()
	var l_sb := StyleBoxFlat.new()
	l_sb.bg_color = Color(0.08, 0.12, 0.18, 0.8)
	l_sb.border_color = Color(1.0, 0.85, 0.2, 0.5)
	l_sb.set_border_width_all(1)
	l_sb.set_corner_radius_all(3)
	lvl_header.add_theme_stylebox_override("panel", l_sb)

	var l_margin := MarginContainer.new()
	l_margin.add_theme_constant_override("margin_left", 8)
	l_margin.add_theme_constant_override("margin_top", 3)
	l_margin.add_theme_constant_override("margin_bottom", 3)
	lvl_header.add_child(l_margin)

	var num_upgrades: int = player.chosen_stat_cards.size() if player else 0
	var lvl_title := Label.new()
	lvl_title.text = "★ MEJORAS DE NIVEL (%d)" % num_upgrades
	lvl_title.add_theme_font_size_override("font_size", 12)
	lvl_title.modulate = Color(1.0, 0.85, 0.2)
	l_margin.add_child(lvl_title)
	upgrades_container.add_child(lvl_header)

	if not player or player.chosen_stat_cards.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Sin mejoras de nivel adquiridas aún."
		empty_lbl.modulate = Color(0.6, 0.65, 0.75, 0.8)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		upgrades_container.add_child(empty_lbl)
		return

	# Agrupar mejoras de nivel por target_stat
	var cards_by_stat: Dictionary = {} # StringName -> Array[StatCardData]
	var stat_order: Array[StringName] = []

	for card: StatCardData in player.chosen_stat_cards:
		var stat_key: StringName = card.target_stat
		if not cards_by_stat.has(stat_key):
			cards_by_stat[stat_key] = []
			stat_order.append(stat_key)
		cards_by_stat[stat_key].append(card)

	for stat_key: StringName in stat_order:
		var cards_group: Array = cards_by_stat[stat_key]
		var count: int = cards_group.size()
		var first_card: StatCardData = cards_group[0]

		# Calcular acumulado numérico total de las mejoras de este stat
		var total_mod: float = 0.0
		var is_pct: bool = first_card.is_percentage
		for c: StatCardData in cards_group:
			total_mod += c.modifier_value

		# Obtener nombre bonito del stat desde RUN_STATS_CONFIG
		var stat_name: String = String(stat_key).to_upper()
		for cfg: Dictionary in RUN_STATS_CONFIG:
			if cfg["key"] == stat_key:
				stat_name = cfg["name"]
				break

		var value_text: String = LevelUpStatsInspector.format_stat_modifier(stat_key, total_mod, is_pct, true)

		var panel := PanelContainer.new()
		var p_sb := StyleBoxFlat.new()
		p_sb.bg_color = Color(0.04, 0.06, 0.10, 0.75)
		p_sb.border_color = Color(1.0, 0.85, 0.2, 0.4)
		p_sb.set_border_width_all(1)
		p_sb.border_width_left = 3
		p_sb.set_corner_radius_all(3)
		panel.add_theme_stylebox_override("panel", p_sb)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		var count_badge := Label.new()
		count_badge.text = "x%d" % count
		count_badge.modulate = Color(1.0, 0.85, 0.2)
		count_badge.add_theme_font_size_override("font_size", 11)

		var name_lbl := Label.new()
		name_lbl.text = stat_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))

		var val_lbl := Label.new()
		val_lbl.text = value_text
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.add_theme_color_override("font_color", Color("#00FF9D"))

		hbox.add_child(count_badge)
		hbox.add_child(name_lbl)
		hbox.add_child(val_lbl)

		var cm := MarginContainer.new()
		cm.add_theme_constant_override("margin_left", 6)
		cm.add_theme_constant_override("margin_right", 8)
		cm.add_theme_constant_override("margin_top", 3)
		cm.add_theme_constant_override("margin_bottom", 3)
		cm.add_child(hbox)
		panel.add_child(cm)

		upgrades_container.add_child(panel)

func _on_settings_pressed() -> void:
	if settings_modal:
		settings_modal.open_settings()

func _on_highscores_pressed() -> void:
	if highscores_modal:
		highscores_modal.open_highscores()

func _release_hud_dock() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud") if get_tree() else null
	if hud and hud.has_method("set_stats_dock_requested"):
		hud.set_stats_dock_requested(&"pause_menu", false)

func _on_save_quit_pressed() -> void:
	# Guardar estado actual de la partida
	var main_game := get_parent() as MainGame
	if not main_game and get_tree():
		main_game = get_tree().current_scene as MainGame
	if main_game:
		main_game.set("is_exiting_run", true)
		if main_game.has_method("save_current_run_state"):
			main_game.save_current_run_state()

	hide()
	_release_hud_dock()
	PauseArbitrator.force_unpause_all()
	Engine.time_scale = 1.0
	SaveManager.set_game_speed(1.0)
	get_tree().change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")

func _on_restart_pressed() -> void:
	var main_game: Node = get_parent()
	if not main_game and get_tree():
		main_game = get_tree().current_scene
	if main_game:
		main_game.set("is_exiting_run", true)

	hide()
	_release_hud_dock()
	PauseArbitrator.force_unpause_all()
	get_tree().reload_current_scene()

func _on_hub_pressed() -> void:
	var main_game: Node = get_parent()
	if not main_game and get_tree():
		main_game = get_tree().current_scene
	if main_game:
		main_game.set("is_exiting_run", true)

	hide()
	_release_hud_dock()
	PauseArbitrator.force_unpause_all()
	Engine.time_scale = 1.0
	SaveManager.set_game_speed(1.0)
	get_tree().change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")

func _on_menu_pressed() -> void:
	var main_game: Node = get_parent()
	if not main_game and get_tree():
		main_game = get_tree().current_scene
	if main_game:
		main_game.set("is_exiting_run", true)

	hide()
	_release_hud_dock()
	PauseArbitrator.force_unpause_all()
	Engine.time_scale = 1.0
	SaveManager.set_game_speed(1.0)
	get_tree().change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")
