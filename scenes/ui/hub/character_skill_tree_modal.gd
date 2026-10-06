class_name CharacterSkillTreeModal
extends Control

const SkillTreeConfigClass = preload("res://core/types/skill_tree_config.gd")
const ConstellationRendererClass = preload("res://scenes/ui/hub/components/skill_tree_constellation_renderer.gd")
const SkillTreeHexNodeClass = preload("res://scenes/ui/hub/skill_tree_hex_node.gd")

## CharacterSkillTreeModal.gd
## Modal de Árbol de Habilidades en Constelación Radial Hexagonal.
## Orquestador desacoplado: delega datos en SkillTreeConfig y renderizado en SkillTreeConstellationRenderer.

signal modal_closed()
signal closed()
signal skill_unlocked(char_id: StringName, node_id: StringName)

const NODE_COST: int = 25

var current_character_id: StringName = &"nova"
var character_data_ref: CharacterData = null
var current_theme_color: Color = Color("#00F0FF")
var selected_node_id: StringName = &"core"

var active_config: Resource = null
var _renderer: RefCounted = null

var hex_nodes: Dictionary:
	get:
		if _renderer:
			return _renderer.hex_nodes
		return {}

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
	_renderer = ConstellationRendererClass.new()

	if close_button:
		close_button.focus_mode = Control.FOCUS_NONE
		close_button.pressed.connect(close_modal)
	if btn_activate_node:
		btn_activate_node.focus_mode = Control.FOCUS_NONE
		btn_activate_node.pressed.connect(_on_activate_pressed)
	if btn_add_biomass:
		btn_add_biomass.focus_mode = Control.FOCUS_NONE
		btn_add_biomass.pressed.connect(_on_add_biomass_pressed)
	if btn_refund_skills:
		btn_refund_skills.focus_mode = Control.FOCUS_NONE
		btn_refund_skills.pressed.connect(_on_refund_pressed)

	_setup_canvas()

func get_node_definitions() -> Array[Dictionary]:
	if not active_config:
		active_config = SkillTreeConfigClass.get_config_for_character(current_character_id)
	if active_config and active_config.has_method("get_node_definitions"):
		return active_config.get_node_definitions()
	return []

func open_for_character(char_id: StringName) -> void:
	current_character_id = char_id
	var roster := CharacterData.load_roster()
	character_data_ref = roster.get(char_id, null)
	active_config = SkillTreeConfigClass.get_config_for_character(current_character_id)

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

func open_tree_for_character(char_id: StringName) -> void:
	open_for_character(char_id)

func _setup_canvas() -> void:
	if constellation_canvas:
		constellation_canvas.draw.connect(_on_constellation_draw)
	if canvas_viewport:
		canvas_viewport.gui_input.connect(_on_canvas_viewport_gui_input)

func _on_constellation_draw() -> void:
	if _renderer and constellation_canvas:
		var unlocked_ids := SaveManager.get_character_unlocked_nodes(current_character_id)
		_renderer.draw_circuit_lines(constellation_canvas, get_node_definitions(), unlocked_ids, current_theme_color)

func _on_canvas_viewport_gui_input(event: InputEvent) -> void:
	if _renderer and canvas_viewport and constellation_canvas:
		_renderer.handle_gui_input(event, canvas_viewport, constellation_canvas)

func _center_canvas() -> void:
	if _renderer and canvas_viewport and constellation_canvas:
		_renderer.center_canvas(canvas_viewport, constellation_canvas)

func _build_or_update_hex_nodes() -> void:
	if not _renderer or not constellation_canvas:
		return
	_renderer.build_hex_nodes(get_node_definitions(), constellation_canvas, _on_hex_node_selected)
	_refresh_nodes_state()

func _refresh_nodes_state() -> void:
	if not _renderer:
		return
	var unlocked_ids := SaveManager.get_character_unlocked_nodes(current_character_id)
	_renderer.refresh_nodes_state(get_node_definitions(), unlocked_ids, selected_node_id, current_theme_color)

	if constellation_canvas:
		constellation_canvas.queue_redraw()

	_update_detail_panel()
	_update_hud_display()

func _on_hex_node_selected(hex_node: Control) -> void:
	_select_node(hex_node.get("node_id"))

func _select_node(nid: StringName) -> void:
	selected_node_id = nid
	_refresh_nodes_state()

func _determine_theme_color() -> void:
	if character_data_ref and character_data_ref.color != Color.WHITE:
		current_theme_color = character_data_ref.color
	else:
		match current_character_id:
			&"nova": current_theme_color = Color("#00F0FF")
			&"valentina": current_theme_color = Color("#FF3366")
			&"kira": current_theme_color = Color("#FFCC00")
			&"selene": current_theme_color = Color("#BF40BF")
			&"roxy": current_theme_color = Color("#00FF9D")
			&"echo": current_theme_color = Color("#66CCFF")
			&"nyx": current_theme_color = Color(0.9, 0.25, 1.0, 1.0)
			_: current_theme_color = Color("#00F0FF")

func _apply_pilot_theming() -> void:
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

	_refresh_nodes_state()

func _update_detail_panel() -> void:
	var def: Dictionary = {}
	for d in get_node_definitions():
		if d.get("id", &"") == selected_node_id:
			def = d
			break
	if def.is_empty():
		return

	var unlocked_ids := SaveManager.get_character_unlocked_nodes(current_character_id)
	var is_unlocked := unlocked_ids.has(selected_node_id)
	var req_id: StringName = def.get("req", &"")
	var is_req_met: bool = (req_id == &"" or unlocked_ids.has(req_id))
	var bio := SaveManager.get_biomass()
	var cost: int = int(def.get("cost", 25))

	if node_category_label:
		node_category_label.text = "CATEGORÍA: " + str(def.get("branch", "")).to_upper()
		node_category_label.add_theme_color_override("font_color", current_theme_color)
	if node_title_label:
		node_title_label.text = str(def.get("title", "")).to_upper()
	if node_desc_label:
		node_desc_label.text = str(def.get("desc", ""))

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
			btn_activate_node.text = "⚡ ACTIVAR [ESPACIO] (%d BioMasa)" % cost
			btn_activate_node.disabled = false
			sb_act.bg_color = current_theme_color
			sb_act.border_color = Color.WHITE
			btn_activate_node.add_theme_color_override("font_color", Color("#0A0A0E"))

		btn_activate_node.add_theme_stylebox_override("normal", sb_act)
		btn_activate_node.add_theme_stylebox_override("disabled", sb_act)

func _on_activate_pressed() -> void:
	var def: Dictionary = {}
	for d in get_node_definitions():
		if d.get("id", &"") == selected_node_id:
			def = d
			break
	if def.is_empty():
		return

	var cost: int = int(def.get("cost", 25))
	var req_id: StringName = def.get("req", &"")

	var success := SaveManager.unlock_character_skill_node(current_character_id, selected_node_id, cost, req_id)
	if not success:
		return

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")

	if _renderer and get_tree():
		_renderer.animate_hex_pulse(selected_node_id, Vector2(1.28, 1.28), get_tree())

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
	modal_closed.emit()
	closed.emit()
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(0.92, 0.92), 0.12)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.12)
	await tw.finished
	visible = false

func _navigate_direction(move_dir: Vector2) -> void:
	if not _renderer:
		return
	var best_nid: StringName = _renderer.find_best_direction_node(selected_node_id, get_node_definitions(), move_dir)
	if best_nid != &"":
		_select_node(best_nid)
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("ui_click")
		if get_tree():
			_renderer.animate_hex_pulse(best_nid, Vector2(1.2, 1.2), get_tree())

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action("ui_focus_next") or event.is_action("ui_focus_prev"):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action("ui_focus_next") or event.is_action("ui_focus_prev"):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		close_modal()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W, KEY_UP:
				_navigate_direction(Vector2.UP)
				get_viewport().set_input_as_handled()
				return
			KEY_S, KEY_DOWN:
				_navigate_direction(Vector2.DOWN)
				get_viewport().set_input_as_handled()
				return
			KEY_A, KEY_LEFT:
				_navigate_direction(Vector2.LEFT)
				get_viewport().set_input_as_handled()
				return
			KEY_D, KEY_RIGHT:
				_navigate_direction(Vector2.RIGHT)
				get_viewport().set_input_as_handled()
				return
			KEY_SPACE, KEY_ENTER:
				_on_activate_pressed()
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		_navigate_direction(Vector2.UP)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		_navigate_direction(Vector2.DOWN)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_navigate_direction(Vector2.LEFT)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_navigate_direction(Vector2.RIGHT)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_accept"):
		_on_activate_pressed()
		get_viewport().set_input_as_handled()
		return
