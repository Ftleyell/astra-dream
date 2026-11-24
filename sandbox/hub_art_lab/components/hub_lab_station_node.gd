class_name HubLabStationNode
extends Node3D

## Consola modular de Antesala con soporte de estados de progresión:
## CALIBRATING (desaturado + pista de desbloqueo), NEWLY_UNLOCKED (pulso HDR) y ONLINE (activo + prisma).

enum StationState {
	CALIBRATING = 0,
	NEWLY_UNLOCKED = 1,
	ONLINE = 2,
}

signal station_interacted(station: Node3D)

const PropShader = preload("res://sandbox/hub_art_lab/shaders/hub_arcsys_prop_3d.gdshader")
const OutlineShader = preload("res://sandbox/hub_art_lab/shaders/hub_arcsys_outline_3d.gdshader")
const HoloScreenShader = preload("res://sandbox/hub_art_lab/shaders/hub_console_holo_screen.gdshader")
const ConsoleMeshBuilder = preload("res://sandbox/hub_art_lab/meshes/hub_console_mesh_builder.gd")

@export var station_id: StringName = &"console"
@export var display_title: String = "Estación"
@export var locked_hint_text: String = "En Calibración — Completa 1 incursión"

var _state: StationState = StationState.ONLINE
var _calibration_factor: float = 0.0
var _accent_color: Color = Color(0.95, 0.16, 0.34, 1.0)
var _calibrating_tint: Color = Color(0.32, 0.36, 0.48, 1.0)
var _is_highlighted: bool = false
var _prompt_suppressed: bool = false
var _time_acc: float = 0.0

var _body_mesh: MeshInstance3D = null
var _holo_mesh: MeshInstance3D = null
var _holo_screen_mesh: MeshInstance3D = null
var _holo_screen_mat: ShaderMaterial = null
var _label_3d: Label3D = null
var _interact_area: Area3D = null
var _body_materials: Array[ShaderMaterial] = []
var _outline_mat: ShaderMaterial = null


func setup(
	p_id: StringName,
	p_title: String,
	p_locked_hint: String,
	p_initial_state: StationState,
	p_accent_color: Color,
	p_calibrating_tint: Color
) -> void:
	station_id = p_id
	display_title = p_title
	locked_hint_text = p_locked_hint
	_accent_color = p_accent_color
	_calibrating_tint = p_calibrating_tint
	_ensure_nodes()
	set_station_state(p_initial_state)


func _ready() -> void:
	_ensure_nodes()


func _process(delta: float) -> void:
	_time_acc += delta
	if _holo_mesh != null and _holo_mesh.visible:
		_holo_mesh.rotation.y += delta * 1.35
		_holo_mesh.position.y = 1.82 + sin(_time_acc * 2.4) * 0.07

	if _state == StationState.NEWLY_UNLOCKED:
		var pulse: float = 0.35 + 0.35 * sin(_time_acc * 4.4)
		for mat: ShaderMaterial in _body_materials:
			mat.set_shader_parameter("newly_unlocked_pulse", pulse)
		if _holo_screen_mat != null:
			_holo_screen_mat.set_shader_parameter("pulse_boost", pulse)


func _ensure_nodes() -> void:
	if _body_mesh != null:
		return

	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = OutlineShader

	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "ConsoleBodyMesh"
	_body_mesh.mesh = ConsoleMeshBuilder.build_console_body_mesh()
	_body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_body_mesh)

	_body_materials.clear()
	var surface_colors: Array[Color] = [
		Color(0.46, 0.52, 0.66, 1.0),
		Color(0.07, 0.085, 0.15, 1.0),
		_accent_color,
	]
	for surf_idx: int in range(3):
		var mat := ShaderMaterial.new()
		mat.shader = PropShader
		mat.next_pass = _outline_mat
		mat.set_shader_parameter("material_kind", surf_idx)
		mat.set_shader_parameter("base_color", surface_colors[surf_idx])
		mat.set_shader_parameter("pilot_accent_color", _accent_color)
		mat.set_shader_parameter("calibrating_tint", _calibrating_tint)
		_body_mesh.set_surface_override_material(surf_idx, mat)
		_body_materials.append(mat)

	_holo_mesh = MeshInstance3D.new()
	_holo_mesh.name = "HoloPrismMesh"
	_holo_mesh.mesh = ConsoleMeshBuilder.build_console_holo_prism_mesh()
	_holo_mesh.position = Vector3(0.0, 1.88, -0.02)
	_holo_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for surf_idx: int in range(3):
		_holo_mesh.set_surface_override_material(surf_idx, _body_materials[surf_idx])
	add_child(_holo_mesh)

	_holo_screen_mat = ShaderMaterial.new()
	_holo_screen_mat.shader = HoloScreenShader
	_holo_screen_mat.set_shader_parameter("screen_color", _accent_color)
	_holo_screen_mat.set_shader_parameter("calibration_factor", _calibration_factor)
	_holo_screen_mat.set_shader_parameter("pulse_boost", 0.0)

	var screen_quad := QuadMesh.new()
	screen_quad.size = Vector2(0.86, 0.46)
	_holo_screen_mesh = MeshInstance3D.new()
	_holo_screen_mesh.name = "HoloScreenMesh"
	_holo_screen_mesh.mesh = screen_quad
	_holo_screen_mesh.position = Vector3(0.0, 1.56, 0.02)
	_holo_screen_mesh.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	_holo_screen_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holo_screen_mesh.material_override = _holo_screen_mat
	add_child(_holo_screen_mesh)

	var col_body := StaticBody3D.new()
	col_body.name = "ConsoleCollider"
	col_body.collision_layer = 1
	col_body.collision_mask = 0
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.25, 1.4, 0.85)
	col_shape.shape = box
	col_shape.position = Vector3(0.0, 0.7, 0.0)
	col_body.add_child(col_shape)
	add_child(col_body)

	_interact_area = Area3D.new()
	_interact_area.name = "InteractArea"
	_interact_area.collision_layer = 0
	_interact_area.collision_mask = 2
	var area_shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.05
	cyl.height = 2.0
	area_shape.shape = cyl
	area_shape.position = Vector3(0.0, 0.8, 0.25)
	_interact_area.add_child(area_shape)
	add_child(_interact_area)

	_label_3d = Label3D.new()
	_label_3d.name = "PromptLabel3D"
	_label_3d.position = Vector3(0.0, 2.35, 0.0)
	_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_3d.font_size = 30
	_label_3d.outline_size = 12
	_label_3d.outline_modulate = Color(0.03, 0.03, 0.08, 1.0)
	_label_3d.visible = false
	add_child(_label_3d)


func set_station_state(new_state: StationState) -> void:
	_state = new_state
	_calibration_factor = 1.0 if new_state == StationState.CALIBRATING else 0.0

	for mat: ShaderMaterial in _body_materials:
		mat.set_shader_parameter("calibration_factor", _calibration_factor)
		if new_state != StationState.NEWLY_UNLOCKED:
			mat.set_shader_parameter("newly_unlocked_pulse", 0.0)
	if _outline_mat != null:
		_outline_mat.set_shader_parameter("calibration_factor", _calibration_factor)

	if _holo_mesh != null:
		_holo_mesh.visible = (new_state != StationState.CALIBRATING)
	_refresh_holo_screen()

	_refresh_prompt_label()


func get_station_state() -> StationState:
	return _state


func get_calibration_factor() -> float:
	return _calibration_factor


func set_pilot_accent_color(col: Color) -> void:
	_accent_color = col
	for mat: ShaderMaterial in _body_materials:
		mat.set_shader_parameter("pilot_accent_color", col)
	_refresh_holo_screen()


func apply_shader_calibration(crease_strength: float, outline_w: float, ref_dist: float, emissive_b: float) -> void:
	for mat: ShaderMaterial in _body_materials:
		mat.set_shader_parameter("crease_ink_strength", crease_strength)
		mat.set_shader_parameter("emissive_boost", emissive_b)
	if _outline_mat != null:
		_outline_mat.set_shader_parameter("outline_width", outline_w)
		_outline_mat.set_shader_parameter("reference_distance", ref_dist)


func set_highlighted(active: bool) -> void:
	_is_highlighted = active
	_refresh_prompt_label()


func set_prompt_suppressed(suppressed: bool) -> void:
	_prompt_suppressed = suppressed
	_refresh_prompt_label()


func is_player_inside(body: Node3D) -> bool:
	if _interact_area == null or body == null:
		return false
	return _interact_area.overlaps_body(body)


func trigger_interaction() -> void:
	if _state == StationState.NEWLY_UNLOCKED:
		set_station_state(StationState.ONLINE)
	station_interacted.emit(self)


func _refresh_holo_screen() -> void:
	if _holo_screen_mat == null:
		return
	_holo_screen_mat.set_shader_parameter("calibration_factor", _calibration_factor)
	match _state:
		StationState.CALIBRATING:
			_holo_screen_mat.set_shader_parameter("screen_color", Color(0.95, 0.65, 0.18, 1.0))
			_holo_screen_mat.set_shader_parameter("pulse_boost", 0.0)
		StationState.NEWLY_UNLOCKED:
			var hi_col := _accent_color.lerp(Color(0.32, 1.0, 0.78, 1.0), 0.35)
			_holo_screen_mat.set_shader_parameter("screen_color", hi_col)
			_holo_screen_mat.set_shader_parameter("pulse_boost", 0.55)
		_:
			_holo_screen_mat.set_shader_parameter("screen_color", _accent_color)
			_holo_screen_mat.set_shader_parameter("pulse_boost", 0.0)


func _refresh_prompt_label() -> void:
	if _label_3d == null:
		return
	_label_3d.visible = (_is_highlighted and not _prompt_suppressed)
	if not _label_3d.visible:
		return
	match _state:
		StationState.CALIBRATING:
			_label_3d.text = "EN CALIBRACIÓN\n%s" % locked_hint_text
			_label_3d.modulate = Color(0.95, 0.72, 0.30, 1.0)
		StationState.NEWLY_UNLOCKED:
			_label_3d.text = "[E] %s (ONLINE · NUEVO)" % display_title
			_label_3d.modulate = Color(0.38, 1.0, 0.82, 1.0)
		_:
			_label_3d.text = "[E] %s" % display_title
			_label_3d.modulate = Color(0.96, 0.84, 0.48, 1.0)
