class_name ArcanaStatsInspector
extends RefCounted

## ArcanaStatsInspector.gd
## Controlador del panel lateral de estadísticas del jugador para ArcanaSelectionModal.
## Gestiona la visualización de atributos actuales, mejoras activas y la previsualización
## proyectada en tiempo real de las modificaciones numéricas de cada pacto arcano.

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
	{"name": "VEL. MOVIMIENTO", "key": &"move_speed", "fmt": "%.0f", "suffix": " px/s"},
	{"name": "ENFRIAMIENTO", "key": &"cooldown_reduction", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "VIDA MÁXIMA", "key": &"max_health", "fmt": "%.0f", "suffix": " HP"},
	{"name": "REGEN. VIDA", "key": &"health_regen", "fmt": "%.1f", "suffix": "/s"},
	{"name": "ARMADURA", "key": &"armor", "fmt": "%.0f", "suffix": ""},
	{"name": "RADIO RECOGIDA", "key": &"pickup_radius", "fmt": "%.0f", "suffix": " px"},
	{"name": "MULTIPLICADOR EXP", "key": &"exp_multiplier", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "SUERTE", "key": &"luck", "fmt": "%+.0f", "suffix": ""},
]

var stats_list_container: VBoxContainer = null
var stats_header_label: Label = null
var pilot_info_label: Label = null
var stat_card_ui_entries: Dictionary = {}


func setup(p_stats_list: VBoxContainer, p_header: Label, p_pilot_info: Label) -> void:
	stats_list_container = p_stats_list
	stats_header_label = p_header
	pilot_info_label = p_pilot_info


static func get_stat_display_name(key: StringName) -> String:
	for cfg in RUN_STATS_CONFIG:
		if cfg["key"] == key:
			return cfg["name"]
	return String(key)


func refresh_player_stats(player: Player) -> void:
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

	if pilot_info_label:
		if data:
			pilot_info_label.text = "%s | PACTOS CUÁNTICOS" % data.display_name.to_upper()
			pilot_info_label.add_theme_color_override("font_color", theme_col)
		else:
			pilot_info_label.text = "PILOTO | PACTOS"

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
		var is_buffed: bool = (current_val > base_val + 0.001)

		var item_panel := PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(0, 24)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.07, 0.11, 0.85)
		sb.border_color = (COLOR_BOON_GREEN if is_buffed else theme_col.darkened(0.5))
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
		lbl_val.add_theme_color_override("font_color", COLOR_BOON_GREEN if is_buffed else Color.WHITE)
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


func highlight_arcana_stats(arc: ArcanaData) -> void:
	if not arc:
		return

	# Pre-parsear modificadores de la arcana
	var active_mods: Dictionary = {}
	for mod_key in arc.stat_modifiers.keys():
		var s_key := String(mod_key)
		var stat_name := StringName(s_key.trim_suffix("_pct"))
		var is_pct: bool = s_key.ends_with("_pct")
		var val: float = float(arc.stat_modifiers[mod_key])
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
			high_style.border_color = COLOR_HIGHLIGHT_BORDER
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
				var projected_v: float = cur_v * (1.0 + mod_val) if is_pct else (cur_v + mod_val)
				var proj_str: String = (fmt % (projected_v * mult)) + suffix
				lbl_val.text = "%s → %s" % [displayed_val, proj_str]
				lbl_val.add_theme_color_override("font_color", COLOR_BOON_GREEN if mod_val >= 0 else COLOR_CURSE_RED)
		else:
			p.add_theme_stylebox_override("panel", entry["base_style"])
			if is_instance_valid(lbl_val):
				lbl_val.text = displayed_val
				if is_buffed:
					lbl_val.add_theme_color_override("font_color", COLOR_BOON_GREEN)
				else:
					lbl_val.add_theme_color_override("font_color", Color.WHITE)
