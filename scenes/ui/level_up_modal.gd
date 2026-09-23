class_name LevelUpModal
extends CanvasLayer

signal card_chosen(card: StatCardData)

@export var stat_deck_manager: StatDeckManager
@export var player: Player

@onready var modal_panel: Panel = $Panel
@onready var cards_container: HBoxContainer = find_child("CardsContainer", true, false) as HBoxContainer
@onready var level_label: Label = $Panel/VBoxContainer/Title
@onready var stats_side_panel: PanelContainer = find_child("StatsSidePanel", true, false) as PanelContainer
@onready var stats_header_label: Label = find_child("StatsHeader", true, false) as Label
@onready var pilot_info_label: Label = find_child("PilotInfo", true, false) as Label
@onready var stats_list_container: VBoxContainer = find_child("StatsList", true, false) as VBoxContainer

var current_offered_cards: Array[StatCardData] = []
var select_buttons: Array[Button] = []
var card_panels: Array[PanelContainer] = []
var card_tier_colors: Array[Color] = []
var current_selected_idx: int = 0
var stat_card_ui_entries: Dictionary = {}

var pending_levels_queue: Array[int] = []
var is_presenting_level: bool = false
var current_level_shown: int = 1
var _mouse_lockout_active: bool = false

const STAT_ICON_MAP = {
	&"base_damage": "res://assets/icons/items/icon_sword.svg",
	&"attack_speed": "res://assets/icons/items/icon_gauntlet.svg",
	&"crit_chance": "res://assets/icons/items/icon_glasses.svg",
	&"crit_damage": "res://assets/icons/items/icon_lens.svg",
	&"max_health": "res://assets/icons/items/icon_heart.svg",
	&"move_speed": "res://assets/icons/items/icon_boots.svg",
	&"luck": "res://assets/icons/items/icon_clover.svg",
	&"projectile_count": "res://assets/icons/items/icon_quiver.svg",
	&"armor": "res://assets/icons/items/icon_shield.svg",
	&"health_regen": "res://assets/icons/items/icon_apple.svg",
	&"pickup_radius": "res://assets/icons/items/icon_magnet.svg",
}

const RUN_STATS_CONFIG: Array[Dictionary] = [
	{"name": "DAÑO", "key": &"base_damage", "fmt": "%.1f", "suffix": ""},
	{"name": "VEL. ATAQUE", "key": &"attack_speed", "fmt": "%.2f", "suffix": "x"},
	{"name": "PROB. CRÍTICA", "key": &"crit_chance", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "DAÑO CRÍTICO", "key": &"crit_damage", "fmt": "%.2f", "suffix": "x"},
	{"name": "PROYECTILES", "key": &"projectile_count", "fmt": "%.0f", "suffix": ""},
	{"name": "VEL. PROYECTIL", "key": &"projectile_speed", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "VEL. MOVIMIENTO", "key": &"move_speed", "fmt": "%.0f", "suffix": " px/s"},
	{"name": "ENFRIAMIENTO", "key": &"cooldown_reduction", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "VIDA MÁXIMA", "key": &"max_health", "fmt": "%.0f", "suffix": " HP"},
	{"name": "REGEN. VIDA", "key": &"health_regen", "fmt": "%.1f", "suffix": "/s"},
	{"name": "ARMADURA", "key": &"armor", "fmt": "%.0f", "suffix": ""},
	{"name": "RADIO RECOGIDA", "key": &"pickup_radius", "fmt": "%.0f", "suffix": " px"},
	{"name": "MULTIPLICADOR EXP", "key": &"exp_multiplier", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "SUERTE", "key": &"luck", "fmt": "%+.0f", "suffix": ""},
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	# Estilo translúcido de alta tecnología para el panel del modal
	var modal_style := StyleBoxFlat.new()
	modal_style.bg_color = Color(0.04, 0.06, 0.1, 0.96)
	modal_style.set_border_width_all(2)
	modal_style.border_color = Color(0.2, 0.6, 1.0, 0.7)
	modal_style.set_corner_radius_all(12)
	modal_style.set_content_margin_all(16.0)
	if modal_panel:
		modal_panel.add_theme_stylebox_override("panel", modal_style)

	if stats_side_panel:
		var side_style := StyleBoxFlat.new()
		side_style.bg_color = Color(0.03, 0.04, 0.07, 0.92)
		side_style.set_border_width_all(1)
		side_style.border_color = Color(0.2, 0.5, 0.8, 0.5)
		side_style.set_corner_radius_all(8)
		stats_side_panel.add_theme_stylebox_override("panel", side_style)

	if stat_deck_manager:
		stat_deck_manager.cards_offered.connect(_on_cards_offered)

func show_level_up(level: int) -> void:
	var parent_game = get_parent()
	var shop_active: bool = (parent_game and parent_game.has_method("is_satellite_shop_active") and parent_game.is_satellite_shop_active())
	var diag_active: bool = (parent_game and parent_game.has_method("is_dialogue_active") and parent_game.is_dialogue_active())

	if is_presenting_level or visible or shop_active or diag_active:
		if not pending_levels_queue.has(level) and level != current_level_shown:
			pending_levels_queue.append(level)
		_update_header_title()
		return

	_present_level(level)

func queue_level_up(level: int) -> void:
	if not pending_levels_queue.has(level) and level != current_level_shown:
		pending_levels_queue.append(level)
	_update_header_title()

func has_pending_levels() -> bool:
	return not pending_levels_queue.is_empty() or is_presenting_level

func show_next_level_up() -> void:
	if is_presenting_level and visible:
		return
	if not pending_levels_queue.is_empty():
		var next_level: int = pending_levels_queue.pop_front()
		_present_level(next_level)

func clear_pending_levels() -> void:
	pending_levels_queue.clear()
	is_presenting_level = false

func _update_header_title() -> void:
	if not level_label:
		return
	var pending_count := pending_levels_queue.size()
	if pending_count > 0:
		level_label.text = "¡SUBIDA DE NIVEL %d! (+%d PENDIENTES) - SELECCIONA UNA MEJORA" % [current_level_shown, pending_count]
	else:
		level_label.text = "¡SUBIDA DE NIVEL %d! SELECCIONA UNA MEJORA" % current_level_shown
	level_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))

func _present_level(level: int) -> void:
	is_presenting_level = true
	current_level_shown = level
	_mouse_lockout_active = true

	get_tree().paused = true
	_update_header_title()
	_refresh_player_stats_display(level)
	show()

	if stat_deck_manager and player:
		stat_deck_manager.offer_cards(player.stats, level, 4)

	# Período de gracia contra spam de clicks de mouse involuntarios al abrir o cambiar de nivel
	get_tree().create_timer(0.3, true, false, true).timeout.connect(func():
		_mouse_lockout_active = false
	)

func _refresh_player_stats_display(level_override: int = -1) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(player) and get_parent():
		player = get_parent().get_node_or_null("Player") as Player

	if not is_instance_valid(player) or not stats_list_container:
		return

	var data: CharacterData = player.character_data
	var stats: CharacterStats = player.stats
	var theme_col: Color = data.color if data else Color("#00F0FF")
	var display_lvl: int = level_override if level_override > 0 else (player.current_level if player else 1)

	if pilot_info_label:
		if data:
			pilot_info_label.text = "%s | NIVEL %d" % [data.display_name.to_upper(), display_lvl]
			pilot_info_label.add_theme_color_override("font_color", theme_col)
		else:
			pilot_info_label.text = "PILOTO | NIVEL %d" % display_lvl

	if stats_header_label:
		stats_header_label.add_theme_color_override("font_color", theme_col.lightened(0.2))

	for child in stats_list_container.get_children():
		child.queue_free()
	stat_card_ui_entries.clear()

	if not stats:
		return

	for cfg in RUN_STATS_CONFIG:
		var key: StringName = cfg["key"]
		var current_val: float = stats.get_stat(key)
		var base_val: float = data.get(key) if (data and key in data) else current_val
		var mult: float = cfg.get("mult", 1.0)
		var fmt: String = cfg["fmt"]
		var suffix: String = cfg["suffix"]

		var displayed_val := (fmt % (current_val * mult)) + suffix
		var is_buffed := (current_val > base_val + 0.001)

		var item_panel := PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(0, 26)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.07, 0.11, 0.85)
		sb.border_color = (Color("#00FF9D") if is_buffed else theme_col.darkened(0.5))
		sb.set_border_width_all(1)
		sb.border_width_left = 3
		sb.set_corner_radius_all(3)
		item_panel.add_theme_stylebox_override("panel", sb)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 3)
		margin.add_theme_constant_override("margin_bottom", 3)
		item_panel.add_child(margin)

		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		margin.add_child(hbox)

		var lbl_name := Label.new()
		lbl_name.text = cfg["name"]
		lbl_name.add_theme_font_size_override("font_size", 11)
		lbl_name.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl_name)

		var lbl_val := Label.new()
		lbl_val.text = displayed_val
		lbl_val.add_theme_font_size_override("font_size", 11)
		if is_buffed:
			lbl_val.add_theme_color_override("font_color", Color("#00FF9D"))
		else:
			lbl_val.add_theme_color_override("font_color", Color.WHITE)
		hbox.add_child(lbl_val)

		if is_buffed:
			var lbl_base := Label.new()
			var base_disp := (fmt % (base_val * mult)) + suffix
			lbl_base.text = " (%s)" % base_disp
			lbl_base.add_theme_font_size_override("font_size", 10)
			lbl_base.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.7))
			hbox.add_child(lbl_base)

		stats_list_container.add_child(item_panel)
		stat_card_ui_entries[key] = {
			"panel": item_panel,
			"is_buffed": is_buffed,
			"base_style": sb,
			"theme_col": theme_col,
			"current_val": current_val,
			"mult": mult,
			"fmt": fmt,
			"suffix": suffix,
			"displayed_val": displayed_val,
			"lbl_val": lbl_val
		}

func _highlight_target_stat(target_stat: StringName, card: StatCardData = null) -> void:
	for stat_key in stat_card_ui_entries.keys():
		var entry: Dictionary = stat_card_ui_entries[stat_key]
		var p: PanelContainer = entry["panel"]
		if not is_instance_valid(p):
			continue
		var lbl_val: Label = entry.get("lbl_val")
		var displayed_val: String = entry.get("displayed_val", "")
		var is_buffed: bool = entry.get("is_buffed", false)

		if stat_key == target_stat:
			var high_style := StyleBoxFlat.new()
			high_style.bg_color = Color(0.12, 0.16, 0.24, 0.98)
			high_style.border_color = Color("#FFE600")
			high_style.set_border_width_all(2)
			high_style.border_width_left = 5
			high_style.set_corner_radius_all(4)
			high_style.shadow_color = Color(1.0, 0.9, 0.0, 0.3)
			high_style.shadow_size = 4
			p.add_theme_stylebox_override("panel", high_style)

			# Previsualización numérica de antes y después
			if card and is_instance_valid(lbl_val):
				var cur_v: float = entry.get("current_val", 0.0)
				var mult: float = entry.get("mult", 1.0)
				var fmt: String = entry.get("fmt", "%.1f")
				var suffix: String = entry.get("suffix", "")
				var projected_v := cur_v * (1.0 + card.modifier_value) if card.is_percentage else (cur_v + card.modifier_value)
				var proj_str := (fmt % (projected_v * mult)) + suffix
				lbl_val.text = "%s → %s" % [displayed_val, proj_str]
				lbl_val.add_theme_color_override("font_color", Color("#00FF9D") if card.modifier_value >= 0 else Color("#FF4466"))
		else:
			p.add_theme_stylebox_override("panel", entry["base_style"])
			if is_instance_valid(lbl_val):
				lbl_val.text = displayed_val
				if is_buffed:
					lbl_val.add_theme_color_override("font_color", Color("#00FF9D"))
				else:
					lbl_val.add_theme_color_override("font_color", Color.WHITE)

func restore_focus() -> void:
	if current_selected_idx >= 0 and current_selected_idx < select_buttons.size():
		var btn = select_buttons[current_selected_idx]
		if is_instance_valid(btn):
			btn.grab_focus()
	elif not select_buttons.is_empty() and is_instance_valid(select_buttons[0]):
		select_buttons[0].grab_focus()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Si el Menú de Pausa está abierto por encima, ignorar cualquier entrada para no competir con el foco ni desviar WASD
	var parent_game = get_parent()
	if parent_game and parent_game.has_method("is_pause_menu_active") and parent_game.is_pause_menu_active():
		return
	var root_pm = get_tree().root.find_child("PauseMenu", true, false)
	if root_pm and root_pm.visible:
		return

	# Si el período de gracia contra spam de clicks está activo, bloquear clicks del ratón
	if event is InputEventMouseButton and event.is_pressed() and _mouse_lockout_active:
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			# Atajos numéricos directos (1, 2, 3, 4)
			KEY_1, KEY_KP_1:
				_select_card_by_index(0)
				get_viewport().set_input_as_handled()
				return
			KEY_2, KEY_KP_2:
				_select_card_by_index(1)
				get_viewport().set_input_as_handled()
				return
			KEY_3, KEY_KP_3:
				_select_card_by_index(2)
				get_viewport().set_input_as_handled()
				return
			KEY_4, KEY_KP_4:
				_select_card_by_index(3)
				get_viewport().set_input_as_handled()
				return

			# Navegación con ASDW y Flechas Direccionales
			KEY_A, KEY_LEFT, KEY_W, KEY_UP:
				_change_selection(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_D, KEY_RIGHT, KEY_S, KEY_DOWN:
				_change_selection(1)
				get_viewport().set_input_as_handled()
				return

			# Confirmación con Barra Espaciadora o Enter
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_confirm_current_selection()
				get_viewport().set_input_as_handled()
				return

func _change_selection(direction: int) -> void:
	if card_panels.is_empty():
		return
	var new_idx := (current_selected_idx + direction) % card_panels.size()
	if new_idx < 0:
		new_idx += card_panels.size()
	if new_idx != current_selected_idx:
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("ui_click")
	_update_card_selection(new_idx)

func _update_card_selection(idx: int) -> void:
	if idx < 0 or idx >= card_panels.size():
		return
	current_selected_idx = idx

	for i in range(card_panels.size()):
		var panel_node := card_panels[i]
		var color := card_tier_colors[i]
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.set_content_margin_all(10.0)

		if i == current_selected_idx:
			style.bg_color = Color(0.10, 0.14, 0.22, 0.98)
			style.set_border_width_all(3)
			style.border_color = color.lightened(0.3)
			style.shadow_color = color * Color(1.0, 1.0, 1.0, 0.45)
			style.shadow_size = 8
			if i < select_buttons.size() and is_instance_valid(select_buttons[i]):
				select_buttons[i].grab_focus()
		else:
			style.bg_color = Color(0.06, 0.08, 0.13, 0.92)
			style.set_border_width_all(2)
			style.border_color = color * Color(1.0, 1.0, 1.0, 0.5)
			style.shadow_size = 0

		panel_node.add_theme_stylebox_override("panel", style)

	if idx < current_offered_cards.size():
		_highlight_target_stat(current_offered_cards[idx].target_stat, current_offered_cards[idx])

func _confirm_current_selection() -> void:
	_select_card_by_index(current_selected_idx)

func _select_card_by_index(idx: int) -> void:
	if idx >= 0 and idx < current_offered_cards.size():
		_select_card(current_offered_cards[idx])

func _on_cards_offered(cards: Array[StatCardData], _cost: int) -> void:
	current_offered_cards = cards
	select_buttons.clear()
	card_panels.clear()
	card_tier_colors.clear()
	current_selected_idx = 0

	if cards_container:
		for child in cards_container.get_children():
			child.queue_free()

		for i in range(cards.size()):
			_create_stat_card_ui(cards[i], i)

	call_deferred("_update_card_selection", 0)

func _create_stat_card_ui(card: StatCardData, index: int) -> void:
	# Respaldo automático de icono según la estadística afectada si viene nulo
	if not card.icon:
		var stat_key: StringName = card.target_stat
		if STAT_ICON_MAP.has(stat_key) and ResourceLoader.exists(STAT_ICON_MAP[stat_key]):
			card.icon = load(STAT_ICON_MAP[stat_key]) as Texture2D

	var tier_info := _get_tier_info(card.tier)
	var tier_color: Color = tier_info["color"]

	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(210, 310)
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.08, 0.13, 0.92)
	card_style.set_border_width_all(2)
	card_style.border_color = tier_color * Color(1.0, 1.0, 1.0, 0.5)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(10.0)
	card_panel.add_theme_stylebox_override("panel", card_style)

	# Foco visual al pasar el cursor sobre la carta
	card_panel.mouse_entered.connect(func():
		_update_card_selection(index)
	)

	card_panels.append(card_panel)
	card_tier_colors.append(tier_color)

	var vbox := VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 8)

	# Indicador de atajo de teclado
	var hotkey_lbl := Label.new()
	hotkey_lbl.text = "[ TECLA %d ]" % (index + 1)
	hotkey_lbl.modulate = Color(1.0, 0.9, 0.35, 0.95)
	hotkey_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkey_lbl.add_theme_font_size_override("font_size", 12)

	# Etiqueta de Tier con color indicador
	var tier_lbl := Label.new()
	tier_lbl.text = tier_info["name"]
	tier_lbl.modulate = tier_color
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_font_size_override("font_size", 12)

	# Título de la carta
	var title_lbl := Label.new()
	title_lbl.text = card.title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_lbl.add_theme_color_override("font_color", tier_color)
	title_lbl.add_theme_font_size_override("font_size", 15)

	# Marco contenedor del icono de 64x64 px centrado
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(64, 64)
	icon_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.03, 0.04, 0.07, 0.95)
	icon_style.set_border_width_all(2)
	icon_style.border_color = tier_color
	icon_style.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", icon_style)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(50, 50)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if card.icon:
		icon_rect.texture = card.icon
		icon_rect.modulate = tier_color
	icon_panel.add_child(icon_rect)

	# Descripción de mejora con valor exacto y nombre de estadística
	var stat_name_display: String = str(card.target_stat)
	for cfg in RUN_STATS_CONFIG:
		if cfg["key"] == card.target_stat:
			stat_name_display = cfg["name"]
			break

	var mod_sign := "+" if card.modifier_value > 0 else ""
	var mod_text := ""
	if card.is_percentage:
		mod_text = "%s%.0f%%" % [mod_sign, card.modifier_value * 100.0]
	else:
		mod_text = "%s%.0f" % [mod_sign, card.modifier_value]

	var desc_lbl := Label.new()
	desc_lbl.text = "%s %s" % [mod_text, stat_name_display]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color("#00FF9D") if card.modifier_value >= 0 else Color("#FF4466"))

	# Botón de selección interactivo compacto (evita miss-clicks involuntarios por spam de disparo)
	var select_btn := Button.new()
	select_btn.text = "Elegir [%d]" % (index + 1)
	select_btn.custom_minimum_size = Vector2(110, 30)
	select_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	select_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	select_btn.add_theme_font_size_override("font_size", 12)
	select_btn.add_theme_color_override("font_color", tier_color.lightened(0.2))

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.08, 0.12, 0.20, 0.95)
	btn_normal.border_color = tier_color
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(5)
	btn_normal.set_content_margin_all(4.0)
	select_btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.12, 0.20, 0.32, 0.98)
	btn_hover.border_color = tier_color.lightened(0.3)
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(5)
	btn_hover.set_content_margin_all(4.0)
	select_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_focus := StyleBoxFlat.new()
	btn_focus.bg_color = Color(0.15, 0.24, 0.38, 0.98)
	btn_focus.border_color = Color.WHITE
	btn_focus.set_border_width_all(2)
	btn_focus.set_corner_radius_all(5)
	btn_focus.set_content_margin_all(4.0)
	select_btn.add_theme_stylebox_override("focus", btn_focus)

	select_btn.pressed.connect(func():
		if _mouse_lockout_active:
			return
		_select_card(card)
	)
	select_btn.focus_entered.connect(func():
		if current_selected_idx != index:
			_update_card_selection(index)
	)

	vbox.add_child(hotkey_lbl)
	vbox.add_child(tier_lbl)
	vbox.add_child(title_lbl)
	vbox.add_child(icon_panel)
	vbox.add_child(desc_lbl)
	vbox.add_child(select_btn)
	card_panel.add_child(vbox)

	if cards_container:
		cards_container.add_child(card_panel)
	select_buttons.append(select_btn)

func _get_tier_info(tier: Enums.Tier) -> Dictionary:
	match tier:
		Enums.Tier.TIER_1:
			return {
				"name": "TIER 1 (Común)",
				"color": Color(0.5, 0.8, 1.0, 0.95)
			}
		Enums.Tier.TIER_2:
			return {
				"name": "TIER 2 (Poco Común)",
				"color": Color(0.2, 0.95, 0.4, 0.95)
			}
		Enums.Tier.TIER_3:
			return {
				"name": "TIER 3 (Raro)",
				"color": Color(1.0, 0.8, 0.15, 1.0)
			}
		Enums.Tier.TIER_4:
			return {
				"name": "TIER 4 (Legendario)",
				"color": Color(0.9, 0.35, 1.0, 1.0)
			}
		_:
			return {
				"name": "TIER 1",
				"color": Color.WHITE
			}

func _select_card(card: StatCardData) -> void:
	if stat_deck_manager and player:
		stat_deck_manager.apply_card_to_stats(card, player.stats)
		player.chosen_stat_cards.append(card)
		_refresh_player_stats_display(current_level_shown)
	if player and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(0.4)

	card_chosen.emit(card)

	# Si quedan niveles acumulados en la cola, presentamos el siguiente sin despausar ni pisarse
	if not pending_levels_queue.is_empty():
		var next_level: int = pending_levels_queue.pop_front()
		_present_level(next_level)
		return

	is_presenting_level = false
	hide()
	var parent_game = get_parent()
	if parent_game and parent_game.has_method("notify_menu_closed"):
		parent_game.notify_menu_closed(0.4)
	if parent_game and parent_game.has_method("is_any_combat_modal_active") and parent_game.is_any_combat_modal_active():
		get_tree().paused = true
		if parent_game.has_method("restore_combat_modal_focus"):
			parent_game.restore_combat_modal_focus()
	else:
		get_tree().paused = false
