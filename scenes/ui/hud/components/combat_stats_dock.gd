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
	sb.bg_color = Color(0.03, 0.05, 0.09, 0.94)
	sb.border_color = Color(0.2, 0.6, 1.0, 0.6)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(8)
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
		var base_val: float = data.get(key) if (data and key in data) else current_val
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

func set_dock_requested(requester_id: StringName, requested: bool, player: Player = null) -> void:
	if requested:
		_external_requesters[requester_id] = true
	else:
		_external_requesters.erase(requester_id)

	if requested and player:
		refresh_stats(player)

	visible = not _external_requesters.is_empty()

func toggle_tab_dock(player: Player) -> void:
	if _external_requesters.has(&"tab"):
		set_dock_requested(&"tab", false)
	else:
		set_dock_requested(&"tab", true, player)
