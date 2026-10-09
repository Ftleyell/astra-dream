class_name BuildStatsMatrixPresenter
extends RefCounted

## BuildStatsMatrixPresenter.gd
## Presentador visual de la matriz de estadísticas en el menú de pausa.
## Construye los paneles y etiquetas de estadísticas con formateo, sufijos y resaltado (buffed/cursed).

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

static func populate_stats(player: Player, stats_container: VBoxContainer) -> void:
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
