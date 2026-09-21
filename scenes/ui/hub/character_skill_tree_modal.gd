class_name CharacterSkillTreeModal
extends Control

## CharacterSkillTreeModal.gd
## Modal de Árbol de Habilidades cibernético en estilo Psycho-Pop.
## Ofrece 5 nodos secuenciales conectados por líneas de circuitos.
## Cada nodo cuesta 25 BioMasa y otorga +20% de velocidad de movimiento a la piloto seleccionada.

signal modal_closed()
signal skill_unlocked(char_id: StringName, node_index: int)

const NODE_COST: int = 25
const NODE_COUNT: int = 5

const NODE_TITLES: Array[String] = [
	"NODO 1: INICIADOR CINÉTICO",
	"NODO 2: CONECTOR DE FLUJO",
	"NODO 3: INYECTOR DE IMPULSO",
	"NODO 4: MATRIZ HIPER-CONDUCCIÓN",
	"NODO 5: SOBRECARGA SUPREMA"
]

const COLOR_HOT_PINK := Color("#FF1493")
const COLOR_DEEP_BLACK := Color("#0A0A0E")
const COLOR_PURE_WHITE := Color("#FFFFFF")
const COLOR_CYAN := Color("#00F0FF")
const COLOR_NEON_GREEN := Color("#00FF9D")
const COLOR_DIM_GRAY := Color("#252530")

var current_character_id: StringName = &"nova"
var character_data_ref: CharacterData = null
var node_cards: Array[PanelContainer] = []
var circuit_lines: Array[ColorRect] = []

@onready var backdrop: ColorRect = $Backdrop
@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var title_label: Label = $CenterContainer/MainPanel/Margin/VBox/Header/TitleLabel
@onready var pilot_label: Label = $CenterContainer/MainPanel/Margin/VBox/Header/PilotLabel
@onready var biomass_label: Label = $CenterContainer/MainPanel/Margin/VBox/Header/BiomassLabel
@onready var nodes_container: HBoxContainer = $CenterContainer/MainPanel/Margin/VBox/NodesHBox
@onready var total_bonus_label: Label = $CenterContainer/MainPanel/Margin/VBox/Footer/TotalBonusLabel
@onready var close_button: Button = $CenterContainer/MainPanel/Margin/VBox/Footer/CloseButton


func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(close_modal)


func open_for_character(char_id: StringName) -> void:
	current_character_id = char_id
	var roster := CharacterData.load_roster()
	character_data_ref = roster.get(char_id, null)

	visible = true
	_apply_styling()
	_rebuild_skill_tree()
	_animate_open()


func _apply_styling() -> void:
	if not main_panel:
		return

	var char_col: Color = character_data_ref.color if character_data_ref else COLOR_HOT_PINK

	# Panel principal Psycho-Pop: fondo negro puro con borde Hot Pink
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_DEEP_BLACK
	sb.border_color = COLOR_HOT_PINK
	sb.set_border_width_all(3)
	sb.border_width_top = 10
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	main_panel.add_theme_stylebox_override("panel", sb)

	if pilot_label:
		var dname: String = character_data_ref.display_name if character_data_ref else String(current_character_id).capitalize()
		var title: String = character_data_ref.title if character_data_ref else ""
		pilot_label.text = "PILOTO: %s — %s" % [dname.to_upper(), title.to_upper()]
		pilot_label.add_theme_color_override("font_color", char_col)

	if close_button:
		var sb_btn := StyleBoxFlat.new()
		sb_btn.bg_color = COLOR_HOT_PINK
		sb_btn.set_border_width_all(2)
		sb_btn.border_color = COLOR_PURE_WHITE
		sb_btn.corner_radius_top_left = 0
		sb_btn.corner_radius_top_right = 0
		sb_btn.corner_radius_bottom_left = 0
		sb_btn.corner_radius_bottom_right = 0
		close_button.add_theme_stylebox_override("normal", sb_btn)
		close_button.add_theme_color_override("font_color", COLOR_DEEP_BLACK)


func _rebuild_skill_tree() -> void:
	var unlocked_indices := SaveManager.get_character_unlocked_nodes(current_character_id)
	var bio := SaveManager.get_biomass()

	if biomass_label:
		biomass_label.text = "BIOMASA DISPONIBLE: %d u." % bio

	var total_pct: int = unlocked_indices.size() * 20
	if total_bonus_label:
		total_bonus_label.text = "BONO TOTAL DE VELOCIDAD: +%d%%" % total_pct
		total_bonus_label.add_theme_color_override("font_color", COLOR_NEON_GREEN if total_pct > 0 else COLOR_PURE_WHITE)

	for c in nodes_container.get_children():
		c.queue_free()
	node_cards.clear()

	for i in range(NODE_COUNT):
		var is_unlocked: bool = unlocked_indices.has(i)
		var is_available: bool = (i == 0 and not is_unlocked) or (i > 0 and unlocked_indices.has(i - 1) and not is_unlocked)
		var is_locked: bool = not is_unlocked and not is_available

		# Separador visual con traza de circuito entre nodos
		if i > 0:
			var trace := ColorRect.new()
			trace.custom_minimum_size = Vector2(24, 6)
			trace.size_flags_vertical = SIZE_SHRINK_CENTER
			trace.color = COLOR_NEON_GREEN if is_unlocked else (COLOR_HOT_PINK if is_available else COLOR_DIM_GRAY)
			nodes_container.add_child(trace)

		var card := _create_node_card(i, is_unlocked, is_available, is_locked, bio)
		nodes_container.add_child(card)
		node_cards.append(card)


func _create_node_card(idx: int, is_unlocked: bool, is_available: bool, is_locked: bool, bio: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(170, 260)
	card.pivot_offset = Vector2(85, 130)

	var sb := StyleBoxFlat.new()
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.set_border_width_all(2)

	if is_unlocked:
		sb.bg_color = Color("#0c1e14") # Verde oscuro profundo
		sb.border_color = COLOR_NEON_GREEN
		sb.border_width_top = 8
	elif is_available:
		sb.bg_color = Color("#220515") # Magenta oscuro profundo
		sb.border_color = COLOR_HOT_PINK
		sb.border_width_top = 8
	else:
		sb.bg_color = Color("#111116") # Gris apagado
		sb.border_color = COLOR_DIM_GRAY
		sb.border_width_top = 4

	card.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.theme_override_constants.set("separation", 10)
	margin.add_child(vbox)

	# Número y título del nodo
	var lbl_num := Label.new()
	lbl_num.text = "PASO 0%d" % (idx + 1)
	lbl_num.add_theme_font_size_override("font_size", 13)
	lbl_num.add_theme_color_override("font_color", COLOR_NEON_GREEN if is_unlocked else (COLOR_HOT_PINK if is_available else Color(0.5, 0.5, 0.5)))
	vbox.add_child(lbl_num)

	var lbl_title := Label.new()
	lbl_title.text = NODE_TITLES[idx]
	lbl_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_title.add_theme_font_size_override("font_size", 14)
	lbl_title.add_theme_color_override("font_color", COLOR_PURE_WHITE if (is_unlocked or is_available) else Color(0.45, 0.45, 0.45))
	vbox.add_child(lbl_title)

	# Icono o Glifo del circuito
	var lbl_icon := Label.new()
	lbl_icon.text = "⚡ +20%"
	lbl_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_icon.add_theme_font_size_override("font_size", 22)
	lbl_icon.add_theme_color_override("font_color", COLOR_NEON_GREEN if is_unlocked else (COLOR_CYAN if is_available else Color(0.3, 0.3, 0.3)))
	vbox.add_child(lbl_icon)

	var lbl_desc := Label.new()
	lbl_desc.text = "+20% Velocidad de Movimiento permanente en partida"
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_desc.add_theme_font_size_override("font_size", 11)
	lbl_desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	vbox.add_child(lbl_desc)

	vbox.add_spacer(false)

	# Botón de estado o compra
	if is_unlocked:
		var lbl_status := Label.new()
		lbl_status.text = "ACTIVO ✓"
		lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_status.add_theme_font_size_override("font_size", 14)
		lbl_status.add_theme_color_override("font_color", COLOR_NEON_GREEN)
		vbox.add_child(lbl_status)
	elif is_available:
		var can_afford := bio >= NODE_COST
		var btn_buy := Button.new()
		btn_buy.text = "ACTIVAR\n(25 BioMasa)"
		btn_buy.custom_minimum_size = Vector2(0, 48)
		btn_buy.add_theme_font_size_override("font_size", 13)

		var sb_buy := StyleBoxFlat.new()
		sb_buy.bg_color = COLOR_HOT_PINK if can_afford else Color(0.3, 0.15, 0.22)
		sb_buy.set_border_width_all(2)
		sb_buy.border_color = COLOR_PURE_WHITE if can_afford else Color(0.5, 0.3, 0.4)
		sb_buy.corner_radius_top_left = 0
		sb_buy.corner_radius_top_right = 0
		sb_buy.corner_radius_bottom_left = 0
		sb_buy.corner_radius_bottom_right = 0
		btn_buy.add_theme_stylebox_override("normal", sb_buy)
		btn_buy.add_theme_color_override("font_color", COLOR_PURE_WHITE)
		btn_buy.disabled = not can_afford

		var node_idx: int = idx
		btn_buy.pressed.connect(func(): _on_buy_node(node_idx, card))
		vbox.add_child(btn_buy)
	else:
		var lbl_lock := Label.new()
		lbl_lock.text = "BLOQUEADO 🔒\n(Requiere anterior)"
		lbl_lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_lock.add_theme_font_size_override("font_size", 11)
		lbl_lock.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		vbox.add_child(lbl_lock)

	return card


func _on_buy_node(idx: int, card: PanelContainer) -> void:
	var success := SaveManager.unlock_character_skill_node(current_character_id, idx, NODE_COST)
	if not success:
		return

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")

	# Animación elástica de activación
	var tw := card.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(1.15, 1.15), 0.15)
	tw.tween_property(card, "scale", Vector2.ONE, 0.2)
	await tw.finished

	skill_unlocked.emit(current_character_id, idx)
	_rebuild_skill_tree()


func _animate_open() -> void:
	if not main_panel:
		return
	main_panel.pivot_offset = main_panel.size * 0.5
	main_panel.scale = Vector2(0.85, 0.85)
	main_panel.modulate.a = 0.0

	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(main_panel, "scale", Vector2.ONE, 0.28)
	tw.tween_property(main_panel, "modulate:a", 1.0, 0.22)


func close_modal() -> void:
	if not visible:
		return
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(main_panel, "scale", Vector2(0.85, 0.85), 0.15)
	tw.parallel().tween_property(main_panel, "modulate:a", 0.0, 0.15)
	await tw.finished
	visible = false
	modal_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_modal()
			get_viewport().set_input_as_handled()
