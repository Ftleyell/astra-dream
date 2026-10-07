class_name SkillTreeConstellationRenderer
extends RefCounted

const SkillTreeHexNodeClass = preload("res://scenes/ui/hub/skill_tree_hex_node.gd")

## SkillTreeConstellationRenderer.gd
## Controlador y renderizador especializado para la constelación radial hexagonal del árbol de habilidades.
## Gestiona instanciación de nodos hexagonales, circuito conectores, paneo del viewport y navegación espacial.

var hex_nodes: Dictionary = {} # StringName -> SkillTreeHexNode
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var canvas_base_pos: Vector2 = Vector2.ZERO

func clear() -> void:
	hex_nodes.clear()
	is_dragging = false

func build_hex_nodes(defs: Array[Dictionary], canvas: Control, on_selected: Callable) -> void:
	if not canvas:
		return

	for child in canvas.get_children():
		child.queue_free()
	hex_nodes.clear()

	for def in defs:
		var hex := SkillTreeHexNodeClass.new()
		var nid: StringName = def.get("id", &"")
		hex.name = "Hex_" + String(nid).capitalize()
		hex.node_id = nid
		hex.branch_name = str(def.get("branch", ""))
		hex.title = str(def.get("title", ""))
		hex.stat_bonus_text = str(def.get("desc", ""))
		hex.glyph_icon = str(def.get("glyph", "⚛"))
		var raw_ico = def.get("icon", null)
		if raw_ico is Texture2D:
			hex.icon = raw_ico
		elif raw_ico is String and not str(raw_ico).is_empty() and ResourceLoader.exists(str(raw_ico)):
			hex.icon = ResourceLoader.load(str(raw_ico)) as Texture2D
		hex.cost = int(def.get("cost", 25))
		hex.req_node_id = def.get("req", &"")
		var pos_vec: Vector2 = def.get("pos", Vector2.ZERO)
		hex.position = pos_vec - (hex.size * 0.5)
		hex.selected.connect(on_selected)
		canvas.add_child(hex)
		hex_nodes[nid] = hex

func refresh_nodes_state(defs: Array[Dictionary], unlocked_ids: Array[StringName], selected_node_id: StringName, theme_color: Color) -> void:
	for def in defs:
		var nid: StringName = def.get("id", &"")
		var hex = hex_nodes.get(nid, null)
		if not hex or not is_instance_valid(hex):
			continue

		hex.set_theme_color(theme_color)
		var is_unlocked := unlocked_ids.has(nid)
		var is_selected := (nid == selected_node_id)

		if is_unlocked:
			hex.set_node_state(SkillTreeHexNodeClass.State.UNLOCKED, is_selected)
		else:
			var req_id: StringName = def.get("req", &"")
			var is_req_met: bool = (req_id == &"" or unlocked_ids.has(req_id))
			if is_req_met:
				hex.set_node_state(SkillTreeHexNodeClass.State.AVAILABLE, is_selected)
			else:
				hex.set_node_state(SkillTreeHexNodeClass.State.LOCKED, is_selected)

func draw_circuit_lines(canvas: Control, defs: Array[Dictionary], unlocked_ids: Array[StringName], theme_color: Color) -> void:
	if not canvas:
		return

	for def in defs:
		var req_id: StringName = def.get("req", &"")
		if req_id == &"":
			continue

		var parent_def: Dictionary = {}
		for d in defs:
			if d.get("id", &"") == req_id:
				parent_def = d
				break
		if parent_def.is_empty():
			continue

		var p_from: Vector2 = parent_def.get("pos", Vector2.ZERO)
		var p_to: Vector2 = def.get("pos", Vector2.ZERO)

		var child_id: StringName = def.get("id", &"")
		var is_child_unlocked := unlocked_ids.has(child_id)
		var is_parent_unlocked := unlocked_ids.has(req_id)

		if is_child_unlocked and is_parent_unlocked:
			# Conexión activa brillante
			canvas.draw_line(p_from, p_to, theme_color, 3.5, true)
			canvas.draw_line(p_from, p_to, Color.WHITE, 1.2, true)
		elif is_parent_unlocked:
			# Conexión disponible hacia el siguiente nodo
			var col := Color(theme_color.r, theme_color.g, theme_color.b, 0.5)
			canvas.draw_line(p_from, p_to, col, 2.0, true)
		else:
			# Conexión bloqueada atenuada
			var col := Color(0.2, 0.25, 0.3, 0.35)
			canvas.draw_line(p_from, p_to, col, 1.5, true)

func center_canvas(viewport: Control, canvas: Control) -> void:
	if not canvas:
		return
	var vp_size := Vector2(1280.0, 720.0)
	if viewport and viewport.size.x > 100.0:
		vp_size = viewport.size
	elif canvas.get_viewport():
		vp_size = canvas.get_viewport_rect().size
	var center := Vector2(vp_size.x * 0.42, vp_size.y * 0.5)
	canvas.position = center

func handle_gui_input(event: InputEvent, viewport: Control, canvas: Control) -> void:
	if not canvas or not viewport:
		return

	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				is_dragging = true
				drag_start_pos = event.position
				canvas_base_pos = canvas.position
			else:
				is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		var delta_drag: Vector2 = event.position - drag_start_pos
		var new_pos := canvas_base_pos + delta_drag
		new_pos.x = clampf(new_pos.x, viewport.size.x * 0.5 - 650.0, viewport.size.x * 0.5 + 650.0)
		new_pos.y = clampf(new_pos.y, viewport.size.y * 0.5 - 550.0, viewport.size.y * 0.5 + 550.0)
		canvas.position = new_pos

func find_best_direction_node(cur_nid: StringName, defs: Array[Dictionary], move_dir: Vector2) -> StringName:
	var cur_pos := Vector2.ZERO
	for d in defs:
		if d.get("id", &"") == cur_nid:
			cur_pos = d.get("pos", Vector2.ZERO)
			break

	var best_nid: StringName = &""
	var best_score: float = 999999.0

	for d in defs:
		var nid: StringName = d.get("id", &"")
		if nid == cur_nid:
			continue
		var target_pos: Vector2 = d.get("pos", Vector2.ZERO)
		var delta_pos: Vector2 = target_pos - cur_pos
		var dist: float = delta_pos.length()
		if dist < 1.0:
			continue
		var dir_norm := delta_pos.normalized()
		var dot: float = dir_norm.dot(move_dir)
		if dot > 0.35:
			var score: float = dist + (1.0 - dot) * 140.0
			if score < best_score:
				best_score = score
				best_nid = nid

	return best_nid

func animate_hex_pulse(nid: StringName, target_scale: Vector2 = Vector2(1.2, 1.2), tree_ref: SceneTree = null) -> void:
	var hex = hex_nodes.get(nid, null)
	if hex and is_instance_valid(hex) and tree_ref:
		var tw := tree_ref.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(hex, "scale", target_scale, 0.08)
		tw.tween_property(hex, "scale", Vector2.ONE, 0.12)
