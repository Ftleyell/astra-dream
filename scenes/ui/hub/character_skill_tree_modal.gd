class_name CharacterSkillTreeModal
extends Control

const SkillTreeHexNodeClass = preload("res://scenes/ui/hub/skill_tree_hex_node.gd")

## CharacterSkillTreeModal.gd
## Modal de Árbol de Habilidades en Constelación Radial Hexagonal.
## Presenta un nodo central (Núcleo) del que se desprenden 4 ramas cardinales
## (Velocidad, Daño, Supervivencia, Utilidad) con un total de 12 nodos + Core.
## Los colores, líneas de circuito, paneles y brillos se adaptan al color del piloto.

signal modal_closed()
signal skill_unlocked(char_id: StringName, node_id: StringName)

const NODE_COST: int = 25

const NODE_DEFINITIONS: Array[Dictionary] = [
	# Núcleo Central
	{
		"id": &"core",
		"branch": "NÚCLEO",
		"title": "NÚCLEO DE PILOTO",
		"desc": "Matriz neural primaria del piloto. Punto de origen de todas las rutas de hiper-conducción.",
		"glyph": "⚛",
		"pos": Vector2(0, 0),
		"cost": 0,
		"req": &""
	},
	# Rama Norte (Velocidad)
	{
		"id": &"speed_1",
		"branch": "VELOCIDAD",
		"title": "IMPULSO VECTORIAL I",
		"desc": "+20% Velocidad de movimiento permanente en combate.",
		"glyph": "⚡",
		"pos": Vector2(0, -115),
		"cost": 25,
		"req": &"core"
	},
	{
		"id": &"speed_2",
		"branch": "VELOCIDAD",
		"title": "IMPULSO VECTORIAL II",
		"desc": "+20% Velocidad de movimiento permanente (+40% acumulado).",
		"glyph": "⚡",
		"pos": Vector2(0, -225),
		"cost": 25,
		"req": &"speed_1"
	},
	{
		"id": &"speed_3",
		"branch": "VELOCIDAD",
		"title": "SOBRECARGA DE POSTQUEMADOR",
		"desc": "+20% Velocidad de movimiento permanente (+60% acumulado).",
		"glyph": "⚡",
		"pos": Vector2(0, -335),
		"cost": 25,
		"req": &"speed_2"
	},
	# Rama Este (Daño)
	{
		"id": &"damage_1",
		"branch": "DAÑO",
		"title": "SOBREALIMENTACIÓN TÉRMICA I",
		"desc": "+15% Daño general infligido permanente en combate.",
		"glyph": "⚔",
		"pos": Vector2(150, 0),
		"cost": 25,
		"req": &"core"
	},
	{
		"id": &"damage_2",
		"branch": "DAÑO",
		"title": "SOBREALIMENTACIÓN TÉRMICA II",
		"desc": "+15% Daño general permanente (+30% acumulado).",
		"glyph": "⚔",
		"pos": Vector2(280, 0),
		"cost": 25,
		"req": &"damage_1"
	},
	{
		"id": &"damage_3",
		"branch": "DAÑO",
		"title": "FUSIÓN DE CAÑÓN CUÁNTICO",
		"desc": "+15% Daño general permanente (+45% acumulado).",
		"glyph": "⚔",
		"pos": Vector2(410, 0),
		"cost": 25,
		"req": &"damage_2"
	},
	# Rama Sur (Supervivencia)
	{
		"id": &"hp_1",
		"branch": "SUPERVIVENCIA",
		"title": "NANO-BLINDAJE REGENERATIVO I",
		"desc": "+25 Puntos de Salud Máxima permanente en combate.",
		"glyph": "🛡",
		"pos": Vector2(0, 115),
		"cost": 25,
		"req": &"core"
	},
	{
		"id": &"hp_2",
		"branch": "SUPERVIVENCIA",
		"title": "NANO-BLINDAJE REGENERATIVO II",
		"desc": "+25 Puntos de Salud Máxima permanente (+50 HP acumulado).",
		"glyph": "🛡",
		"pos": Vector2(0, 225),
		"cost": 25,
		"req": &"hp_1"
	},
	{
		"id": &"hp_3",
		"branch": "SUPERVIVENCIA",
		"title": "MATRIZ DE CASCO TITÁN",
		"desc": "+25 Puntos de Salud Máxima permanente (+75 HP acumulado).",
		"glyph": "🛡",
		"pos": Vector2(0, 335),
		"cost": 25,
		"req": &"hp_2"
	},
	# Rama Oeste (Utilidad / Crítico & Cadencia)
	{
		"id": &"crit_1",
		"branch": "UTILIDAD",
		"title": "TELEMETRÍA DE PRECISIÓN I",
		"desc": "+5% Probabilidad Crítica y +5% Cadencia de ataque permanente.",
		"glyph": "✦",
		"pos": Vector2(-150, 0),
		"cost": 25,
		"req": &"core"
	},
	{
		"id": &"crit_2",
		"branch": "UTILIDAD",
		"title": "TELEMETRÍA DE PRECISIÓN II",
		"desc": "+5% Probabilidad Crítica y +5% Cadencia (+10% acumulado).",
		"glyph": "✦",
		"pos": Vector2(-280, 0),
		"cost": 25,
		"req": &"crit_1"
	},
	{
		"id": &"crit_3",
		"branch": "UTILIDAD",
		"title": "SINCRONIZADOR HIPER-ÓPTICO",
		"desc": "+5% Probabilidad Crítica y +5% Cadencia (+15% acumulado).",
		"glyph": "✦",
		"pos": Vector2(-410, 0),
		"cost": 25,
		"req": &"crit_2"
	}
]

var current_character_id: StringName = &"nova"
var character_data_ref: CharacterData = null
var current_theme_color: Color = Color("#00F0FF")
var selected_node_id: StringName = &"core"

var hex_nodes: Dictionary = {} # StringName -> SkillTreeHexNode
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var canvas_base_pos: Vector2 = Vector2.ZERO

@onready var close_button: Button = $TopBar/CloseButton
@onready var header_title_label: Label = $TopBar/HeaderVBox/TitleLabel
@onready var header_pilot_label: Label = $TopBar/HeaderVBox/PilotLabel
@onready var hud_biomass_label: Label = $TopBar/HudRight/BiomassLabel
@onready var hud_points_label: Label = $TopBar/HudRight/PointsLabel

@onready var canvas_viewport: Control = $CanvasContainer
@onready var constellation_canvas: Control = $CanvasContainer/ConstellationCanvas

# Panel Lateral de Detalle
@onready var detail_panel: PanelContainer = $DetailPanel
@onready var node_category_label: Label = $DetailPanel/Margin/VBox/CategoryLabel
@onready var node_title_label: Label = $DetailPanel/Margin/VBox/TitleLabel
@onready var node_desc_label: Label = $DetailPanel/Margin/VBox/DescLabel
@onready var node_cost_label: Label = $DetailPanel/Margin/VBox/CostLabel
@onready var btn_activate_node: Button = $DetailPanel/Margin/VBox/ActivateButton
@onready var btn_add_biomass: Button = $DetailPanel/Margin/VBox/TestToolsHBox/AddBioButton
@onready var btn_refund_skills: Button = $DetailPanel/Margin/VBox/TestToolsHBox/RefundButton


func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(close_modal)
	if btn_activate_node:
		btn_activate_node.pressed.connect(_on_activate_pressed)
	if btn_add_biomass:
		btn_add_biomass.pressed.connect(_on_add_biomass_pressed)
	if btn_refund_skills:
		btn_refund_skills.pressed.connect(_on_refund_pressed)

	_setup_canvas_input()


func open_for_character(char_id: StringName) -> void:
	current_character_id = char_id
	var roster := CharacterData.load_roster()
	character_data_ref = roster.get(char_id, null)

	# Auto-desbloquear core inicial gratuito si no estaba registrado
	var unlocked := SaveManager.get_character_unlocked_nodes(current_character_id)
	if not unlocked.has(&"core"):
		SaveManager.unlock_character_skill_node(current_character_id, &"core", 0)

	_determine_theme_color()
	visible = true

	_build_or_update_hex_nodes()
	_apply_pilot_theming()
	_center_canvas()
	_select_node(&"core")
	_animate_open()


func _determine_theme_color() -> void:
	if character_data_ref and character_data_ref.color != Color.WHITE:
		current_theme_color = character_data_ref.color
	else:
		match current_character_id:
			&"nova": current_theme_color = Color("#00F0FF") # Cyan
			&"valentina": current_theme_color = Color("#FF3366") # Crimson
			&"kira": current_theme_color = Color("#FFCC00") # Gold
			&"selene": current_theme_color = Color("#BF40BF") # Violet
			&"roxy": current_theme_color = Color("#00FF9D") # Emerald
			&"echo": current_theme_color = Color("#66CCFF") # Electric Sky
			_: current_theme_color = Color("#00F0FF")


func _apply_pilot_theming() -> void:
	# 1. Cabecera y HUD
	if header_title_label:
		header_title_label.add_theme_color_override("font_color", current_theme_color)
	if header_pilot_label:
		var dname: String = character_data_ref.display_name if character_data_ref else String(current_character_id).capitalize()
		var title: String = character_data_ref.title if character_data_ref else "PILOTO DE COMBATE"
		header_pilot_label.text = "PILOTO: %s // %s" % [dname.to_upper(), title.to_upper()]
		header_pilot_label.add_theme_color_override("font_color", Color.WHITE)

	if close_button:
		var sb_close := StyleBoxFlat.new()
		sb_close.bg_color = Color(0.04, 0.05, 0.07, 0.95)
		sb_close.border_color = current_theme_color
		sb_close.set_border_width_all(2)
		sb_close.set_corner_radius_all(0)
		close_button.add_theme_stylebox_override("normal", sb_close)
		close_button.add_theme_color_override("font_color", current_theme_color)

	# 2. Panel Lateral de Detalle con estilo Psycho-Pop / Radar cibernético
	if detail_panel:
		var sb_panel := StyleBoxFlat.new()
		sb_panel.bg_color = Color(0.04, 0.05, 0.07, 0.92)
		sb_panel.border_color = current_theme_color
		sb_panel.border_width_left = 6
		sb_panel.border_width_top = 2
		sb_panel.border_width_right = 2
		sb_panel.border_width_bottom = 2
		sb_panel.set_corner_radius_all(0)
		detail_panel.add_theme_stylebox_override("panel", sb_panel)

	# 3. Actualizar nodos
	for nid in hex_nodes.keys():
		var hex = hex_nodes[nid]
		if is_instance_valid(hex):
			hex.set_theme_color(current_theme_color)

	_update_hud_display()


func _build_or_update_hex_nodes() -> void:
	if not constellation_canvas:
		return

	# Si es la primera vez, crear los nodos hexagonales
	if hex_nodes.is_empty():
		for def in NODE_DEFINITIONS:
			var hex := SkillTreeHexNodeClass.new()
			hex.name = "Hex_" + String(def["id"]).capitalize()
			hex.node_id = def["id"]
			hex.branch_name = def["branch"]
			hex.title = def["title"]
			hex.stat_bonus_text = def["desc"]
			hex.glyph_icon = def["glyph"]
			hex.cost = def["cost"]
			hex.req_node_id = def["req"]
			hex.position = def["pos"] - (hex.size * 0.5)
			hex.selected.connect(_on_hex_node_selected)
			constellation_canvas.add_child(hex)
			hex_nodes[hex.node_id] = hex

	_refresh_nodes_state()


func _refresh_nodes_state() -> void:
	var unlocked_ids := SaveManager.get_character_unlocked_nodes(current_character_id)

	for def in NODE_DEFINITIONS:
		var nid: StringName = def["id"]
		var hex = hex_nodes.get(nid, null)
		if not hex:
			continue

		var is_unlocked := unlocked_ids.has(nid)
		var is_selected := (nid == selected_node_id)

		if is_unlocked:
			hex.set_node_state(SkillTreeHexNodeClass.State.UNLOCKED, is_selected)
		else:
			var req_id: StringName = def["req"]
			var is_req_met: bool = (req_id == &"" or unlocked_ids.has(req_id))
			if is_req_met:
				hex.set_node_state(SkillTreeHexNodeClass.State.AVAILABLE, is_selected)
			else:
				hex.set_node_state(SkillTreeHexNodeClass.State.LOCKED, is_selected)

	# Redibujar trazas de circuitos conectores
	if constellation_canvas:
		constellation_canvas.queue_redraw()

	_update_detail_panel()
	_update_hud_display()


func _on_hex_node_selected(hex_node: Control) -> void:
	_select_node(hex_node.get("node_id"))


func _select_node(nid: StringName) -> void:
	selected_node_id = nid
	_refresh_nodes_state()


func _update_detail_panel() -> void:
	var def: Dictionary = {}
	for d in NODE_DEFINITIONS:
		if d["id"] == selected_node_id:
			def = d
			break
	if def.is_empty():
		return

	var unlocked_ids := SaveManager.get_character_unlocked_nodes(current_character_id)
	var is_unlocked := unlocked_ids.has(selected_node_id)
	var req_id: StringName = def["req"]
	var is_req_met: bool = (req_id == &"" or unlocked_ids.has(req_id))
	var bio := SaveManager.get_biomass()
	var cost: int = def["cost"]

	if node_category_label:
		node_category_label.text = "CATEGORÍA: " + String(def["branch"]).to_upper()
		node_category_label.add_theme_color_override("font_color", current_theme_color)
	if node_title_label:
		node_title_label.text = String(def["title"]).to_upper()
	if node_desc_label:
		node_desc_label.text = def["desc"]

	if node_cost_label:
		if cost == 0:
			node_cost_label.text = "COSTE: NÚCLEO INICIAL (0 BioMasa)"
			node_cost_label.add_theme_color_override("font_color", Color("#00FF9D"))
		else:
			node_cost_label.text = "COSTE DE ACTIVACIÓN: %d BioMasa (Disponible: %d u.)" % [cost, bio]
			node_cost_label.add_theme_color_override("font_color", Color.WHITE if bio >= cost else Color("#FF3366"))

	if btn_activate_node:
		var sb_act := StyleBoxFlat.new()
		sb_act.set_corner_radius_all(0)
		sb_act.set_border_width_all(2)

		if is_unlocked:
			btn_activate_node.text = "NODO ACTIVO ✓"
			btn_activate_node.disabled = true
			sb_act.bg_color = Color(0.08, 0.22, 0.14, 0.8)
			sb_act.border_color = Color("#00FF9D")
			btn_activate_node.add_theme_color_override("font_color", Color("#00FF9D"))
		elif not is_req_met:
			btn_activate_node.text = "BLOQUEADO 🔒 (Requiere anterior)"
			btn_activate_node.disabled = true
			sb_act.bg_color = Color(0.08, 0.08, 0.12, 0.7)
			sb_act.border_color = Color(0.3, 0.35, 0.4)
			btn_activate_node.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		elif bio < cost:
			btn_activate_node.text = "BIOMASA INSUFICIENTE (Faltan %d u.)" % (cost - bio)
			btn_activate_node.disabled = true
			sb_act.bg_color = Color(0.2, 0.08, 0.12, 0.8)
			sb_act.border_color = Color("#FF3366")
			btn_activate_node.add_theme_color_override("font_color", Color("#FF3366"))
		else:
			btn_activate_node.text = "⚡ ACTIVAR NODO (25 BioMasa)"
			btn_activate_node.disabled = false
			sb_act.bg_color = current_theme_color
			sb_act.border_color = Color.WHITE
			btn_activate_node.add_theme_color_override("font_color", Color("#0A0A0E"))

		btn_activate_node.add_theme_stylebox_override("normal", sb_act)
		btn_activate_node.add_theme_stylebox_override("disabled", sb_act)


func _on_activate_pressed() -> void:
	var def: Dictionary = {}
	for d in NODE_DEFINITIONS:
		if d["id"] == selected_node_id:
			def = d
			break
	if def.is_empty():
		return

	var cost: int = def["cost"]
	var req_id: StringName = def["req"]

	var success := SaveManager.unlock_character_skill_node(current_character_id, selected_node_id, cost, req_id)
	if not success:
		return

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")

	# Animación elástica sobre el hexágono activado
	var hex = hex_nodes.get(selected_node_id, null)
	if hex:
		var tw: Tween = create_tween()
		tw.set_trans(Tween.TRANS_BACK)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(hex, "scale", Vector2(1.28, 1.28), 0.14)
		tw.tween_property(hex, "scale", Vector2.ONE, 0.2)

	skill_unlocked.emit(current_character_id, selected_node_id)
	_refresh_nodes_state()


func _on_add_biomass_pressed() -> void:
	SaveManager.add_test_biomass(100)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")
	_refresh_nodes_state()


func _on_refund_pressed() -> void:
	var refunded := SaveManager.refund_character_skills(current_character_id, NODE_COST)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")
	selected_node_id = &"core"
	_refresh_nodes_state()


func _update_hud_display() -> void:
	var bio := SaveManager.get_biomass()
	var unlocked_count := SaveManager.get_character_unlocked_nodes_count(current_character_id)

	if hud_biomass_label:
		hud_biomass_label.text = "BIOMASA: %d u." % bio
		hud_biomass_label.add_theme_color_override("font_color", Color("#00FF9D"))

	if hud_points_label:
		hud_points_label.text = "MEJORAS ACTIVAS: %d / 12" % unlocked_count
		hud_points_label.add_theme_color_override("font_color", current_theme_color)


# --- DIBUJADO DE CONEXIONES DE CIRCUITO EN EL LIENZO ---
func _draw_circuit_lines() -> void:
	if not constellation_canvas:
		return

	var unlocked_ids := SaveManager.get_character_unlocked_nodes(current_character_id)

	for def in NODE_DEFINITIONS:
		var req_id: StringName = def["req"]
		if req_id == &"":
			continue

		var parent_def: Dictionary = {}
		for d in NODE_DEFINITIONS:
			if d["id"] == req_id:
				parent_def = d
				break
		if parent_def.is_empty():
			continue

		var p_from: Vector2 = parent_def["pos"]
		var p_to: Vector2 = def["pos"]

		var is_child_unlocked := unlocked_ids.has(def["id"])
		var is_parent_unlocked := unlocked_ids.has(req_id)

		if is_child_unlocked and is_parent_unlocked:
			# Conexión activa brillante
			constellation_canvas.draw_line(p_from, p_to, current_theme_color, 3.5, true)
			constellation_canvas.draw_line(p_from, p_to, Color.WHITE, 1.2, true)
		elif is_parent_unlocked:
			# Conexión disponible hacia el siguiente nodo
			var col := Color(current_theme_color.r, current_theme_color.g, current_theme_color.b, 0.5)
			constellation_canvas.draw_line(p_from, p_to, col, 2.0, true)
		else:
			# Conexión bloqueada atenuada
			var col := Color(0.2, 0.25, 0.3, 0.35)
			constellation_canvas.draw_line(p_from, p_to, col, 1.5, true)


func _setup_canvas_input() -> void:
	if not constellation_canvas:
		return

	constellation_canvas.draw.connect(_draw_circuit_lines)

	if canvas_viewport:
		canvas_viewport.gui_input.connect(_on_canvas_viewport_gui_input)


func _on_canvas_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				is_dragging = true
				drag_start_pos = event.position
				canvas_base_pos = constellation_canvas.position
			else:
				is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		var delta_drag: Vector2 = event.position - drag_start_pos
		var new_pos := canvas_base_pos + delta_drag
		# Limitar rango de paneo
		new_pos.x = clampf(new_pos.x, canvas_viewport.size.x * 0.5 - 500, canvas_viewport.size.x * 0.5 + 500)
		new_pos.y = clampf(new_pos.y, canvas_viewport.size.y * 0.5 - 450, canvas_viewport.size.y * 0.5 + 450)
		constellation_canvas.position = new_pos


func _center_canvas() -> void:
	if canvas_viewport and constellation_canvas:
		# Centrar el Core (0, 0) con ligero sesgo hacia la izquierda para dar espacio al panel de detalles
		var center := Vector2(canvas_viewport.size.x * 0.42, canvas_viewport.size.y * 0.5)
		constellation_canvas.position = center


func _animate_open() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.92, 0.92)
	modulate.a = 0.0

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.25)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)


func close_modal() -> void:
	if not visible:
		return
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(0.92, 0.92), 0.14)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.14)
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
