class_name ArcanaSelectionModal
extends CanvasLayer


## ArcanaSelectionModal.gd
## Modal de selección táctica de Arcanas (Pactos de Alto Riesgo / Recompensa).
## Se activa al recolectar un ArcanaOrb liberado por el Monolito Arcano.
## Pausa la partida, ofrece 3 cartas estilizadas Psycho-Pop, visualiza las alteraciones
## exactas en las estadísticas en tiempo real y aplica las modificaciones al jugador.

signal arcana_chosen(arcana: ArcanaData)
signal modal_closed()

const COLOR_HOT_PINK := Color("#FF1493")
const COLOR_DEEP_BLACK := Color("#0A0A0E")
const COLOR_PURE_WHITE := Color("#FFFFFF")
const COLOR_NEON_CYAN := Color("#00F0FF")
const COLOR_BOON_GREEN := Color("#44FF88")
const COLOR_CURSE_RED := Color("#FF3366")

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

@export var player: Player = null

@onready var backdrop: ColorRect = $Backdrop
@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var cards_container: HBoxContainer = find_child("CardsContainer", true, false) as HBoxContainer
@onready var header_title: Label = find_child("HeaderTitle", true, false) as Label
@onready var header_subtitle: Label = find_child("HeaderSubtitle", true, false) as Label
@onready var stats_side_panel: PanelContainer = find_child("StatsSidePanel", true, false) as PanelContainer
@onready var stats_list_container: VBoxContainer = find_child("StatsList", true, false) as VBoxContainer
@onready var stats_header_label: Label = find_child("StatsHeader", true, false) as Label
@onready var pilot_info_label: Label = find_child("PilotInfo", true, false) as Label
@onready var controls_hint_label: Label = find_child("ControlsHint", true, false) as Label

var offered_arcanas: Array[ArcanaData] = []
var card_panels: Array[PanelContainer] = []
var card_buttons: Array[Button] = []
var stat_card_ui_entries: Dictionary = {}
var current_selected_idx: int = 0
var is_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_apply_modal_styles()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active or not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if not offered_arcanas.is_empty():
					_on_card_chosen(offered_arcanas[0])
				else:
					close_modal()
				get_viewport().set_input_as_handled()
				return
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
			KEY_LEFT, KEY_A:
				_cycle_selection(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_RIGHT, KEY_D:
				_cycle_selection(1)
				get_viewport().set_input_as_handled()
				return
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_choose_focused_card()
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("ui_left"):
		_cycle_selection(-1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_right"):
		_cycle_selection(1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_accept"):
		_choose_focused_card()
		get_viewport().set_input_as_handled()
		return


func _cycle_selection(delta_dir: int) -> void:
	if card_buttons.is_empty():
		return
	var next_idx := (current_selected_idx + delta_dir) % card_buttons.size()
	if next_idx < 0:
		next_idx += card_buttons.size()
	_update_card_selection(next_idx)


func _select_card_by_index(idx: int) -> void:
	if idx >= 0 and idx < offered_arcanas.size():
		_on_card_chosen(offered_arcanas[idx])


func _choose_focused_card() -> void:
	if current_selected_idx >= 0 and current_selected_idx < offered_arcanas.size():
		_on_card_chosen(offered_arcanas[current_selected_idx])
	elif not offered_arcanas.is_empty():
		_on_card_chosen(offered_arcanas[0])


func show_arcana_selection(p_player: Player = null) -> void:
	if p_player:
		player = p_player
	elif not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player

	# Pausar la simulación de juego
	get_tree().paused = true
	is_active = true
	visible = true

	var excluded_ids: Array = []
	if is_instance_valid(player) and player.has_method("get_arcana_ids"):
		excluded_ids = player.get_arcana_ids()

	offered_arcanas = ArcanaData.get_random_selection(3, excluded_ids)

	# Manejo seguro si el catálogo está agotado (24 arcanas adquiridas)
	if offered_arcanas.is_empty():
		var overload_arc := ArcanaData.new()
		overload_arc.id = "quantum_overload_mastery"
		overload_arc.name = "Sobrecarga del Vacío"
		overload_arc.description_boon = "Todas las 24 Arcanas asimiladas. +500 Créditos y +15 Materia Oscura inmediata."
		overload_arc.description_curse = "Sobrecarga canalizada. Sin penalizaciones adicionales."
		overload_arc.quadrant = "greed"
		overload_arc.color_accent = Color(0.85, 0.2, 1.0)
		overload_arc.stat_modifiers = {}
		offered_arcanas.append(overload_arc)

	_refresh_player_stats_display()
	_build_cards_ui()

	# Audio místico de apertura
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("level_up", 1.1)

	# Foco inicial en la primera carta
	call_deferred("_update_card_selection", 0)


func close_modal() -> void:
	is_active = false
	visible = false
	get_tree().paused = false

	# Notificar cierre a MainGame y Player para suprimir disparador de bomba accidental
	var main_node = get_parent()
	if main_node and main_node.has_method("notify_menu_closed"):
		main_node.notify_menu_closed(0.35)
	elif is_instance_valid(player) and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(0.35)

	modal_closed.emit()


func restore_focus() -> void:
	if is_active and current_selected_idx >= 0 and current_selected_idx < card_buttons.size():
		var btn = card_buttons[current_selected_idx]
		if is_instance_valid(btn):
			btn.grab_focus()
	elif is_active and not card_buttons.is_empty() and is_instance_valid(card_buttons[0]):
		card_buttons[0].grab_focus()


func _build_cards_ui() -> void:
	if not cards_container:
		return

	# Limpiar cartas anteriores
	for child in cards_container.get_children():
		child.queue_free()
	card_buttons.clear()
	card_panels.clear()

	for i in range(offered_arcanas.size()):
		var arc: ArcanaData = offered_arcanas[i]
		var card := _create_cyber_card(arc, i)
		cards_container.add_child(card)

	# Enlace horizontal cíclico de foco para teclado / gamepad
	var n := card_buttons.size()
	for i in range(n):
		var prev_btn := card_buttons[(i - 1 + n) % n]
		var next_btn := card_buttons[(i + 1) % n]
		card_buttons[i].focus_neighbor_left = prev_btn.get_path()
		card_buttons[i].focus_neighbor_right = next_btn.get_path()


func _create_cyber_card(arc: ArcanaData, index: int) -> Control:
	var accent: Color = arc.color_accent if arc.color_accent != Color.BLACK else COLOR_NEON_CYAN

	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(310, 490)
	card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Estilo Psycho-Pop: fondo negro con bordes rectos (corner_radius = 0)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.04, 0.05, 0.08, 0.96)
	card_sb.border_color = accent
	card_sb.set_border_width_all(2)
	card_sb.border_width_top = 6
	card_sb.set_corner_radius_all(0)
	card_sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.25)
	card_sb.shadow_size = 10
	card_panel.add_theme_stylebox_override("panel", card_sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# 1. Indicador de Atajo de Teclado
	var hotkey_lbl := Label.new()
	hotkey_lbl.text = "[ TECLA %d ]" % (index + 1)
	hotkey_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkey_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35, 0.95))
	hotkey_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hotkey_lbl)

	# 2. Badge del Cuadrante
	var quad_badge := Label.new()
	quad_badge.text = "[ %s ]" % arc.get_quadrant_title().to_upper()
	quad_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quad_badge.add_theme_color_override("font_color", accent.lightened(0.2))
	quad_badge.add_theme_font_size_override("font_size", 10)
	vbox.add_child(quad_badge)

	# 3. Nombre de la Arcana
	var name_label := Label.new()
	name_label.text = arc.name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.add_theme_color_override("font_color", COLOR_PURE_WHITE)
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# 4. Separador decorativo neón
	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = accent
	sep_style.thickness = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# 5. Icono o Glifo Central
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if arc.icon:
		icon_rect.texture = arc.icon
	icon_rect.modulate = accent
	vbox.add_child(icon_rect)

	# 6. PANEL DE ALTERACIONES EXACTAS DE ESTADÍSTICAS (STAT DELTAS BADGES)
	var stat_deltas_box := VBoxContainer.new()
	stat_deltas_box.add_theme_constant_override("separation", 3)

	if arc.stat_modifiers.is_empty():
		var neutral_badge := Label.new()
		neutral_badge.text = "◈ PACTO SIN ALTERACIONES DIRECTAS ◈"
		neutral_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		neutral_badge.add_theme_font_size_override("font_size", 10)
		neutral_badge.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		stat_deltas_box.add_child(neutral_badge)
	else:
		for mod_key in arc.stat_modifiers.keys():
			var s_key := String(mod_key)
			var target_stat := StringName(s_key.trim_suffix("_pct"))
			var is_pct := s_key.ends_with("_pct")
			var mod_val := float(arc.stat_modifiers[mod_key])

			var stat_display_name: String = str(target_stat)
			for cfg in RUN_STATS_CONFIG:
				if cfg["key"] == target_stat:
					stat_display_name = cfg["name"]
					break

			var sign_str := "+" if mod_val > 0 else ""
			var val_str := ("%s%.0f%%" % [sign_str, mod_val * 100.0]) if is_pct else ("%s%.0f" % [sign_str, mod_val])
			var arrow_str := "▲" if mod_val >= 0 else "▼"
			var col_badge: Color = COLOR_BOON_GREEN if mod_val >= 0 else COLOR_CURSE_RED

			var badge_panel := PanelContainer.new()
			var badge_sb := StyleBoxFlat.new()
			badge_sb.bg_color = Color(col_badge.r, col_badge.g, col_badge.b, 0.12)
			badge_sb.border_color = col_badge
			badge_sb.border_width_left = 3
			badge_sb.set_border_width_all(1)
			badge_sb.set_corner_radius_all(2)
			badge_panel.add_theme_stylebox_override("panel", badge_sb)

			var badge_margin := MarginContainer.new()
			badge_margin.add_theme_constant_override("margin_left", 6)
			badge_margin.add_theme_constant_override("margin_right", 6)
			badge_margin.add_theme_constant_override("margin_top", 2)
			badge_margin.add_theme_constant_override("margin_bottom", 2)
			badge_panel.add_child(badge_margin)

			var badge_lbl := Label.new()
			badge_lbl.text = "%s %s  %s" % [arrow_str, val_str, stat_display_name]
			badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge_lbl.add_theme_font_size_override("font_size", 11)
			badge_lbl.add_theme_color_override("font_color", col_badge)
			badge_margin.add_child(badge_lbl)

			stat_deltas_box.add_child(badge_panel)

	vbox.add_child(stat_deltas_box)

	# 7. Sección de Bendición (Boon)
	var boon_panel := PanelContainer.new()
	boon_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var boon_sb := StyleBoxFlat.new()
	boon_sb.bg_color = Color(0.05, 0.15, 0.08, 0.75)
	boon_sb.border_color = COLOR_BOON_GREEN
	boon_sb.border_width_left = 3
	boon_sb.set_corner_radius_all(0)
	boon_panel.add_theme_stylebox_override("panel", boon_sb)

	var boon_margin := MarginContainer.new()
	boon_margin.add_theme_constant_override("margin_left", 8)
	boon_margin.add_theme_constant_override("margin_right", 8)
	boon_margin.add_theme_constant_override("margin_top", 6)
	boon_margin.add_theme_constant_override("margin_bottom", 6)
	boon_panel.add_child(boon_margin)

	var boon_vbox := VBoxContainer.new()
	boon_vbox.add_theme_constant_override("separation", 2)
	boon_margin.add_child(boon_vbox)

	var boon_header := Label.new()
	boon_header.text = "▲ BENDICIÓN TÁCTICA"
	boon_header.add_theme_color_override("font_color", COLOR_BOON_GREEN)
	boon_header.add_theme_font_size_override("font_size", 11)
	boon_vbox.add_child(boon_header)

	var boon_desc := Label.new()
	boon_desc.text = arc.description_boon
	boon_desc.add_theme_color_override("font_color", COLOR_PURE_WHITE)
	boon_desc.add_theme_font_size_override("font_size", 11)
	boon_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boon_vbox.add_child(boon_desc)

	vbox.add_child(boon_panel)

	# 8. Sección de Maldición / Tributo (Curse)
	var curse_panel := PanelContainer.new()
	curse_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var curse_sb := StyleBoxFlat.new()
	curse_sb.bg_color = Color(0.2, 0.04, 0.06, 0.75)
	curse_sb.border_color = COLOR_CURSE_RED
	curse_sb.border_width_left = 3
	curse_sb.set_corner_radius_all(0)
	curse_panel.add_theme_stylebox_override("panel", curse_sb)

	var curse_margin := MarginContainer.new()
	curse_margin.add_theme_constant_override("margin_left", 8)
	curse_margin.add_theme_constant_override("margin_right", 8)
	curse_margin.add_theme_constant_override("margin_top", 6)
	curse_margin.add_theme_constant_override("margin_bottom", 6)
	curse_panel.add_child(curse_margin)

	var curse_vbox := VBoxContainer.new()
	curse_vbox.add_theme_constant_override("separation", 2)
	curse_margin.add_child(curse_vbox)

	var curse_header := Label.new()
	curse_header.text = "▼ TRIBUTO / MALDICIÓN"
	curse_header.add_theme_color_override("font_color", COLOR_CURSE_RED)
	curse_header.add_theme_font_size_override("font_size", 11)
	curse_vbox.add_child(curse_header)

	var curse_desc := Label.new()
	curse_desc.text = arc.description_curse
	curse_desc.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	curse_desc.add_theme_font_size_override("font_size", 11)
	curse_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	curse_vbox.add_child(curse_desc)

	vbox.add_child(curse_panel)

	# 9. Botón de Selección con UIFocusHelper
	var btn := Button.new()
	btn.text = "PACTAR CON ARCANA [%d]" % (index + 1)
	btn.custom_minimum_size = Vector2(0, 36)
	btn.focus_mode = Control.FOCUS_ALL

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = COLOR_DEEP_BLACK
	btn_normal.border_color = accent
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = accent
	btn_hover.border_color = COLOR_PURE_WHITE
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_color_override("font_hover_color", COLOR_DEEP_BLACK)

	UIFocusHelper.apply_cyber_focus(btn)
	btn.pressed.connect(_on_card_chosen.bind(arc))
	btn.focus_entered.connect(func():
		_update_card_selection(index)
	)

	card_panel.mouse_entered.connect(func():
		_update_card_selection(index)
	)

	vbox.add_child(btn)
	card_buttons.append(btn)
	card_panels.append(card_panel)

	return card_panel


func _update_card_selection(idx: int) -> void:
	if idx < 0 or idx >= offered_arcanas.size():
		return
	current_selected_idx = idx

	for i in range(card_panels.size()):
		var p := card_panels[i]
		var arc := offered_arcanas[i]
		var accent: Color = arc.color_accent if arc.color_accent != Color.BLACK else COLOR_NEON_CYAN
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(0)

		if i == current_selected_idx:
			sb.bg_color = Color(0.08, 0.10, 0.16, 0.98)
			sb.border_color = COLOR_PURE_WHITE
			sb.set_border_width_all(3)
			sb.border_width_top = 8
			sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.5)
			sb.shadow_size = 14
			if i < card_buttons.size() and is_instance_valid(card_buttons[i]):
				card_buttons[i].grab_focus()
		else:
			sb.bg_color = Color(0.04, 0.05, 0.08, 0.96)
			sb.border_color = accent * Color(1.0, 1.0, 1.0, 0.7)
			sb.set_border_width_all(2)
			sb.border_width_top = 5
			sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.2)
			sb.shadow_size = 6

		p.add_theme_stylebox_override("panel", sb)

	_highlight_arcana_stats(offered_arcanas[idx])


func _refresh_player_stats_display() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(player) and get_parent():
		player = get_parent().get_node_or_null("Player") as Player

	if not is_instance_valid(player) or not stats_list_container:
		return

	var data: CharacterData = player.character_data
	var stats: CharacterStats = player.stats
	var theme_col: Color = data.color if data else COLOR_NEON_CYAN

	if pilot_info_label:
		if data:
			pilot_info_label.text = "%s | PACTOS CUÁNTICOS" % data.display_name.to_upper()
			pilot_info_label.add_theme_color_override("font_color", theme_col)
		else:
			pilot_info_label.text = "PILOTO | PACTOS"

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
		item_panel.custom_minimum_size = Vector2(0, 24)

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
		margin.add_theme_constant_override("margin_top", 2)
		margin.add_theme_constant_override("margin_bottom", 2)
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
		lbl_val.add_theme_color_override("font_color", Color("#00FF9D") if is_buffed else Color.WHITE)
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


func _highlight_arcana_stats(arc: ArcanaData) -> void:
	if not arc:
		return

	# Pre-parsear modificadores de la arcana
	var active_mods: Dictionary = {}
	for mod_key in arc.stat_modifiers.keys():
		var s_key := String(mod_key)
		var stat_name := StringName(s_key.trim_suffix("_pct"))
		var is_pct := s_key.ends_with("_pct")
		var val := float(arc.stat_modifiers[mod_key])
		active_mods[stat_name] = {"val": val, "is_pct": is_pct}

	for stat_key in stat_card_ui_entries.keys():
		var entry: Dictionary = stat_card_ui_entries[stat_key]
		var p: PanelContainer = entry["panel"]
		if not is_instance_valid(p):
			continue
		var lbl_val: Label = entry.get("lbl_val")
		var displayed_val: String = entry.get("displayed_val", "")
		var is_buffed: bool = entry.get("is_buffed", false)

		if active_mods.has(stat_key):
			var mod_info: Dictionary = active_mods[stat_key]
			var mod_val: float = mod_info["val"]
			var is_pct: bool = mod_info["is_pct"]

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
			if is_instance_valid(lbl_val):
				var cur_v: float = entry.get("current_val", 0.0)
				var mult: float = entry.get("mult", 1.0)
				var fmt: String = entry.get("fmt", "%.1f")
				var suffix: String = entry.get("suffix", "")
				var projected_v := cur_v * (1.0 + mod_val) if is_pct else (cur_v + mod_val)
				var proj_str := (fmt % (projected_v * mult)) + suffix
				lbl_val.text = "%s → %s" % [displayed_val, proj_str]
				lbl_val.add_theme_color_override("font_color", Color("#00FF9D") if mod_val >= 0 else Color("#FF4466"))
		else:
			p.add_theme_stylebox_override("panel", entry["base_style"])
			if is_instance_valid(lbl_val):
				lbl_val.text = displayed_val
				if is_buffed:
					lbl_val.add_theme_color_override("font_color", Color("#00FF9D"))
				else:
					lbl_val.add_theme_color_override("font_color", Color.WHITE)


func _on_card_chosen(arc: ArcanaData) -> void:
	if arc.id == "quantum_overload_mastery":
		if is_instance_valid(player):
			player.add_credits(500)
			if player.has_method("add_dark_matter"):
				player.add_dark_matter(15)
			else:
				SaveManager.add_dark_matter(15)
	else:
		# Aplicar bonos y maldiciones al jugador
		if is_instance_valid(player) and player.has_method("apply_arcana"):
			player.apply_arcana(arc)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 1.2)

	arcana_chosen.emit(arc)
	close_modal()


func _apply_modal_styles() -> void:
	if backdrop:
		backdrop.color = Color(0.02, 0.02, 0.04, 0.88)

	if main_panel:
		var sb := StyleBoxFlat.new()
		sb.bg_color = COLOR_DEEP_BLACK
		sb.border_color = COLOR_HOT_PINK
		sb.set_border_width_all(2)
		sb.border_width_top = 4
		sb.set_corner_radius_all(0)
		sb.shadow_color = Color(1.0, 0.08, 0.58, 0.25)
		sb.shadow_size = 18
		main_panel.add_theme_stylebox_override("panel", sb)

	if stats_side_panel:
		var side_sb := StyleBoxFlat.new()
		side_sb.bg_color = Color(0.03, 0.04, 0.07, 0.92)
		side_sb.set_border_width_all(1)
		side_sb.border_color = Color(0.2, 0.5, 0.8, 0.5)
		side_sb.set_corner_radius_all(6)
		stats_side_panel.add_theme_stylebox_override("panel", side_sb)

	if header_title:
		header_title.text = "◈ INVOCACIÓN DE ARCANA ◈"
		header_title.add_theme_color_override("font_color", COLOR_HOT_PINK)

	if header_subtitle:
		header_subtitle.text = "PACTOS DE ALTO RIESGO / RECOMPENSA - SELECCIONA UNA ALTERACIÓN CUÁNTICA"
		header_subtitle.add_theme_color_override("font_color", COLOR_NEON_CYAN)
