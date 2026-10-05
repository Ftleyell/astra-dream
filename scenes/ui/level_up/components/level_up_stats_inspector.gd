class_name LevelUpStatsInspector
extends RefCounted

## LevelUpStatsInspector.gd
## Controlador del panel lateral de estadísticas del jugador para LevelUpModal.
## Gestiona la visualización de estadísticas base y mejoradas, así como la previsualización
## numérica proyectada de las mejoras de nivel seleccionadas.

const COLOR_NEON_CYAN := Color("#00F0FF")
const COLOR_BOON_GREEN := Color("#00FF9D")
const COLOR_CURSE_RED := Color("#FF4466")
const COLOR_HIGHLIGHT_BORDER := Color("#FFE600")

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

const PERCENTAGE_STAT_KEYS: Array[StringName] = [
	&"crit_chance",
	&"crit_damage",
	&"cooldown_reduction",
	&"projectile_speed",
	&"exp_multiplier",
	&"credits_multiplier",
	&"biomass_multiplier",
	&"weapon_size"
]

var stats_list_container: VBoxContainer = null
var stats_header_label: Label = null
var pilot_info_label: Label = null
var stat_card_ui_entries: Dictionary = {}


func setup(p_stats_list: VBoxContainer, p_header: Label, p_pilot_info: Label) -> void:
	stats_list_container = p_stats_list
	stats_header_label = p_header
	pilot_info_label = p_pilot_info


static func is_percentage_stat(key: StringName) -> bool:
	return PERCENTAGE_STAT_KEYS.has(key)


static func format_stat_modifier(key: StringName, value: float, is_percentage_flag: bool = false, with_sign: bool = true) -> String:
	var is_pct: bool = is_percentage_flag or is_percentage_stat(key)
	var sign_s: String = ("+" if value > 0.0 else "") if with_sign else ""
	if is_pct:
		return "%s%.0f%%" % [sign_s, value * 100.0]
	elif key == &"health_regen":
		return "%s%.1f/s" % [sign_s, value]
	elif is_equal_approx(value, roundf(value)):
		return "%s%.0f" % [sign_s, value]
	else:
		return "%s%.1f" % [sign_s, value]


static func get_stat_display_name(key: StringName) -> String:
	for cfg in RUN_STATS_CONFIG:
		if cfg["key"] == key:
			return cfg["name"]
	return String(key)


func refresh_player_stats(player: Player, level_override: int = -1) -> void:
	if not stats_list_container:
		return

	for child in stats_list_container.get_children():
		child.queue_free()
	stat_card_ui_entries.clear()

	if not is_instance_valid(player):
		return

	var data: CharacterData = player.character_data
	var stats: CharacterStats = player.stats
	var theme_col: Color = data.color if data else COLOR_NEON_CYAN
	var display_lvl: int = level_override if level_override > 0 else (player.current_level if player else 1)

	if pilot_info_label:
		if data:
			pilot_info_label.text = "%s | NIVEL %d" % [data.display_name.to_upper(), display_lvl]
			pilot_info_label.add_theme_color_override("font_color", theme_col)
		else:
			pilot_info_label.text = "PILOTO | NIVEL %d" % display_lvl

	if stats_header_label:
		stats_header_label.add_theme_color_override("font_color", theme_col.lightened(0.2))

	if not stats:
		return

	for cfg in RUN_STATS_CONFIG:
		var key: StringName = cfg["key"]
		var current_val: float = stats.get_stat(key)
		var base_val: float = data.get(key) if (data and key in data) else current_val
		var mult: float = cfg.get("mult", 1.0)
		var fmt: String = cfg["fmt"]
		var suffix: String = cfg["suffix"]

		var displayed_val: String = (fmt % (current_val * mult)) + suffix
		var is_cursed: bool = (key == &"curse" and current_val > 0.001)
		var is_buffed: bool = (key != &"curse" and current_val > base_val + 0.001)

		var item_panel := PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(0, 22)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.07, 0.11, 0.85)
		if is_cursed:
			sb.border_color = COLOR_CURSE_RED
		elif is_buffed:
			sb.border_color = COLOR_BOON_GREEN
		else:
			sb.border_color = theme_col.darkened(0.5)
		sb.set_border_width_all(1)
		sb.border_width_left = 3
		sb.set_corner_radius_all(3)
		item_panel.add_theme_stylebox_override("panel", sb)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_top", 1)
		margin.add_theme_constant_override("margin_bottom", 1)
		item_panel.add_child(margin)

		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		margin.add_child(hbox)

		var lbl_name := Label.new()
		lbl_name.text = cfg["name"]
		lbl_name.add_theme_font_size_override("font_size", 10)
		lbl_name.add_theme_color_override("font_color", COLOR_CURSE_RED if is_cursed else Color(0.8, 0.85, 0.9))
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl_name)

		var lbl_val := Label.new()
		lbl_val.text = displayed_val
		lbl_val.add_theme_font_size_override("font_size", 10)
		if is_cursed:
			lbl_val.add_theme_color_override("font_color", COLOR_CURSE_RED)
		elif is_buffed:
			lbl_val.add_theme_color_override("font_color", COLOR_BOON_GREEN)
		else:
			lbl_val.add_theme_color_override("font_color", Color.WHITE)
		hbox.add_child(lbl_val)

		if is_buffed:
			var lbl_base := Label.new()
			var base_disp: String = (fmt % (base_val * mult)) + suffix
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


func highlight_target_stat(target_stat: StringName, card: StatCardData = null) -> void:
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
			high_style.border_color = COLOR_HIGHLIGHT_BORDER
			high_style.set_border_width_all(2)
			high_style.border_width_left = 5
			high_style.set_corner_radius_all(4)
			high_style.shadow_color = Color(1.0, 0.9, 0.0, 0.3)
			high_style.shadow_size = 4
			p.add_theme_stylebox_override("panel", high_style)

			# Previsualización numérica proyectada
			if card and is_instance_valid(lbl_val):
				var cur_v: float = entry.get("current_val", 0.0)
				var mult: float = entry.get("mult", 1.0)
				var fmt: String = entry.get("fmt", "%.1f")
				var suffix: String = entry.get("suffix", "")
				var projected_v: float = cur_v * (1.0 + card.modifier_value) if card.is_percentage else (cur_v + card.modifier_value)
				var proj_str: String = (fmt % (projected_v * mult)) + suffix
				lbl_val.text = "%s → %s" % [displayed_val, proj_str]
				lbl_val.add_theme_color_override("font_color", COLOR_BOON_GREEN if card.modifier_value >= 0 else COLOR_CURSE_RED)
		else:
			p.add_theme_stylebox_override("panel", entry["base_style"])
			if is_instance_valid(lbl_val):
				lbl_val.text = displayed_val
				if is_buffed:
					lbl_val.add_theme_color_override("font_color", COLOR_BOON_GREEN)
				else:
					lbl_val.add_theme_color_override("font_color", Color.WHITE)
