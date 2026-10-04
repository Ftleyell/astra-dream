class_name CombatStatsDock
extends PanelContainer

## CombatStatsDock.gd
## Panel lateral izquierdo de estadísticas de combate en tiempo real.
## Proporciona un visor unificado y consistente de los atributos del piloto:
## - Accesible en combate mediante la tecla [TAB].
## - Reutilizado automáticamente como dock lateral al abrir la Tienda de Satélites y Cofres Espaciales.
## - Visualiza las 15 estadísticas principales con resaltado de mejoras (verde) y maldición (rojo).

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
	{"name": "MALDICIÓN", "key": &"curse", "fmt": "%.0f", "suffix": ""},
]

var _title_label: Label
var _stats_container: VBoxContainer
var _stat_ui_entries: Dictionary = {}
var _external_requesters: Dictionary = {}

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(235, 410)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_build_ui()

func _build_ui() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.06, 0.98)
	sb.border_color = Color(0.2, 0.7, 1.0, 0.9)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	sb.shadow_size = 8
	add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "📊 ATRIBUTOS [TAB]"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	vbox.add_child(_title_label)

	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 2)
	vbox.add_child(_stats_container)

func refresh_stats(player: Player) -> void:
	if not is_instance_valid(player) or not _stats_container:
		return

	for child: Node in _stats_container.get_children():
		child.queue_free()
	_stat_ui_entries.clear()

	var data: CharacterData = player.character_data
	var stats: CharacterStats = player.character_stats if player.character_stats else (player.get("stats") as CharacterStats)
	if not stats:
		return

	var theme_col: Color = data.color if data else Color("#00F0FF")

	for cfg: Dictionary in RUN_STATS_CONFIG:
		var key: StringName = cfg["key"]
		var current_val: float = stats.get_stat(key)
		var base_val: float = stats.get_base_stat(key) if stats.has_method("get_base_stat") else (data.get(key) if (data and key in data) else current_val)
		var mult: float = cfg.get("mult", 1.0)
		var fmt: String = cfg["fmt"]
		var suffix: String = cfg["suffix"]

		var is_curse: bool = (key == &"curse")
		var is_buffed: bool = (current_val > base_val + 0.001) and not is_curse
		var is_cursed: bool = is_curse and current_val > 0.0

		var item_panel := PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(0, 22)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.06, 0.10, 0.85)
		sb.border_color = (Color("#FF4466") if is_cursed else (Color("#00FF9D") if is_buffed else theme_col.darkened(0.5)))
		sb.set_border_width_all(1)
		sb.border_width_left = 3
		sb.set_corner_radius_all(3)
		item_panel.add_theme_stylebox_override("panel", sb)

		var p_margin := MarginContainer.new()
		p_margin.add_theme_constant_override("margin_left", 6)
		p_margin.add_theme_constant_override("margin_right", 6)
		p_margin.add_theme_constant_override("margin_top", 1)
		p_margin.add_theme_constant_override("margin_bottom", 1)
		item_panel.add_child(p_margin)

		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		p_margin.add_child(hbox)

		var lbl_name := Label.new()
		lbl_name.text = cfg["name"]
		lbl_name.add_theme_font_size_override("font_size", 10)
		lbl_name.add_theme_color_override("font_color", Color("#FF4466") if is_cursed else Color(0.8, 0.85, 0.9))
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl_name)

		var displayed_val: String = (fmt % (current_val * mult)) + suffix
		var lbl_val := Label.new()
		lbl_val.text = displayed_val
		lbl_val.add_theme_font_size_override("font_size", 10)
		lbl_val.add_theme_color_override("font_color", Color("#FF4466") if is_cursed else (Color("#00FF9D") if is_buffed else Color.WHITE))
		hbox.add_child(lbl_val)

		_stats_container.add_child(item_panel)
		_stat_ui_entries[key] = {
			"panel": item_panel,
			"lbl_val": lbl_val,
			"displayed_val": displayed_val,
			"is_buffed": is_buffed,
			"base_style": sb,
			"current_val": current_val,
			"mult": mult,
			"fmt": fmt,
			"suffix": suffix
		}

const COLOR_HIGHLIGHT_BORDER := Color("#FFE600")
const COLOR_BOON_GREEN := Color("#00FF9D")
const COLOR_CURSE_RED := Color("#FF4466")

func preview_stat_delta(target_stat: StringName, card: StatCardData = null) -> void:
	for stat_key in _stat_ui_entries.keys():
		var entry: Dictionary = _stat_ui_entries[stat_key]
		var p: PanelContainer = entry.get("panel")
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

func preview_arcana_deltas(arc: ArcanaData) -> void:
	if not arc:
		clear_previews()
		return

	var active_mods: Dictionary = {}
	for mod_key in arc.stat_modifiers.keys():
		var s_key := String(mod_key)
		var stat_name := StringName(s_key.trim_suffix("_pct"))
		var is_pct: bool = s_key.ends_with("_pct")
		var val: float = float(arc.stat_modifiers[mod_key])
		active_mods[stat_name] = {"val": val, "is_pct": is_pct}

	for stat_key in _stat_ui_entries.keys():
		var entry: Dictionary = _stat_ui_entries[stat_key]
		var p: PanelContainer = entry.get("panel")
		if not is_instance_valid(p):
			continue
		var lbl_val: Label = entry.get("lbl_val")
		var displayed_val: String = entry.get("displayed_val", "")
		var is_buffed: bool = entry.get("is_buffed", false)

		if active_mods.has(stat_key):
			var mod_info: Dictionary = active_mods[stat_key]
			var val: float = mod_info["val"]
			var is_pct: bool = mod_info["is_pct"]
			var is_boon: bool = (val > 0.0)

			var high_style := StyleBoxFlat.new()
			high_style.bg_color = Color(0.14, 0.14, 0.22, 0.98)
			high_style.border_color = COLOR_HIGHLIGHT_BORDER
			high_style.set_border_width_all(2)
			high_style.border_width_left = 5
			high_style.set_corner_radius_all(4)
			high_style.shadow_color = Color(1.0, 0.9, 0.0, 0.35)
			high_style.shadow_size = 5
			p.add_theme_stylebox_override("panel", high_style)

			if is_instance_valid(lbl_val):
				var cur_v: float = entry.get("current_val", 0.0)
				var mult: float = entry.get("mult", 1.0)
				var fmt: String = entry.get("fmt", "%.1f")
				var suffix: String = entry.get("suffix", "")
				var projected_v: float = cur_v * (1.0 + val) if is_pct else (cur_v + val)
				var proj_str: String = (fmt % (projected_v * mult)) + suffix
				lbl_val.text = "%s → %s" % [displayed_val, proj_str]
				lbl_val.add_theme_color_override("font_color", COLOR_BOON_GREEN if is_boon else COLOR_CURSE_RED)
		else:
			p.add_theme_stylebox_override("panel", entry["base_style"])
			if is_instance_valid(lbl_val):
				lbl_val.text = displayed_val
				if is_buffed:
					lbl_val.add_theme_color_override("font_color", COLOR_BOON_GREEN)
				else:
					lbl_val.add_theme_color_override("font_color", Color.WHITE)

func preview_item_stat(item: ItemData) -> void:
	if not item or item.stat_name == &"":
		clear_previews()
		return

	var target_stat := item.stat_name
	for stat_key in _stat_ui_entries.keys():
		var entry: Dictionary = _stat_ui_entries[stat_key]
		var p: PanelContainer = entry.get("panel")
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

			if is_instance_valid(lbl_val):
				var cur_v: float = entry.get("current_val", 0.0)
				var mult: float = entry.get("mult", 1.0)
				var fmt: String = entry.get("fmt", "%.1f")
				var suffix: String = entry.get("suffix", "")
				var projected_v: float = cur_v * (1.0 + item.stat_value) if item.is_percentage else (cur_v + item.stat_value)
				var proj_str: String = (fmt % (projected_v * mult)) + suffix
				lbl_val.text = "%s → %s" % [displayed_val, proj_str]
				lbl_val.add_theme_color_override("font_color", COLOR_BOON_GREEN if item.stat_value >= 0 else COLOR_CURSE_RED)
		else:
			p.add_theme_stylebox_override("panel", entry["base_style"])
			if is_instance_valid(lbl_val):
				lbl_val.text = displayed_val
				if is_buffed:
					lbl_val.add_theme_color_override("font_color", COLOR_BOON_GREEN)
				else:
					lbl_val.add_theme_color_override("font_color", Color.WHITE)


func preview_raw_stat(target_stat: StringName, delta_val: float, is_pct: bool) -> void:
	if delta_val == 0.0 or target_stat == &"":
		clear_previews()
		return

	for stat_key in _stat_ui_entries.keys():
		var entry: Dictionary = _stat_ui_entries[stat_key]
		var p: PanelContainer = entry.get("panel")
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

			if is_instance_valid(lbl_val):
				var cur_v: float = entry.get("current_val", 0.0)
				var mult: float = entry.get("mult", 1.0)
				var fmt: String = entry.get("fmt", "%.1f")
				var suffix: String = entry.get("suffix", "")
				var projected_v: float = cur_v * (1.0 + delta_val) if is_pct else (cur_v + delta_val)
				var proj_str: String = (fmt % (projected_v * mult)) + suffix
				lbl_val.text = "%s → %s" % [displayed_val, proj_str]
				lbl_val.add_theme_color_override("font_color", COLOR_BOON_GREEN if delta_val >= 0 else COLOR_CURSE_RED)
		else:
			p.add_theme_stylebox_override("panel", entry["base_style"])
			if is_instance_valid(lbl_val):
				lbl_val.text = displayed_val
				if is_buffed:
					lbl_val.add_theme_color_override("font_color", COLOR_BOON_GREEN)
				else:
					lbl_val.add_theme_color_override("font_color", Color.WHITE)


func clear_previews() -> void:
	for stat_key in _stat_ui_entries.keys():
		var entry: Dictionary = _stat_ui_entries[stat_key]
		var p: PanelContainer = entry.get("panel")
		if is_instance_valid(p) and entry.has("base_style"):
			p.add_theme_stylebox_override("panel", entry["base_style"])
		var lbl_val: Label = entry.get("lbl_val")
		if is_instance_valid(lbl_val):
			lbl_val.text = entry.get("displayed_val", "")
			if entry.get("is_buffed", false):
				lbl_val.add_theme_color_override("font_color", COLOR_BOON_GREEN)
			else:
				lbl_val.add_theme_color_override("font_color", Color.WHITE)

func set_dock_requested(requester_id: StringName, requested: bool, player: Player = null) -> void:
	if requested:
		_external_requesters[requester_id] = true
	else:
		_external_requesters.erase(requester_id)

	if requested and player:
		refresh_stats(player)
	elif not requested:
		clear_previews()

	visible = not _external_requesters.is_empty()

func toggle_tab_dock(player: Player) -> void:
	if _external_requesters.has(&"tab"):
		set_dock_requested(&"tab", false)
	else:
		set_dock_requested(&"tab", true, player)
