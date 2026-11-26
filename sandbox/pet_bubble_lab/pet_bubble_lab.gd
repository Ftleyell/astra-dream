class_name PetBubbleLab
extends Node2D

## Laboratorio interactivo para probar las 5 mascotas en burbuja 3D,
## su órbita elíptica inclinada alrededor del piloto, iluminación normal-mapped
## y modos de inspección.

const PET_IDS: Array[StringName] = [&"mochi", &"kuro", &"luna", &"pip", &"cosmo"]
const CONFIG_DIR: String = "res://data/pets/bubble_v2"

@onready var space_bg: ColorRect = $BgLayer/SpaceBg
@onready var world_root: Node2D = $WorldRoot
@onready var pilot_anchor: Node2D = $WorldRoot/PilotAnchor
@onready var fetch_gem: Node2D = $WorldRoot/FetchGem
@onready var orbit_controller: PetOrbit3DController = $WorldRoot/PetOrbit3DController
@onready var hud: PetBubbleLabHUD = $HudLayer/PetBubbleLabHUD

var _configs: Dictionary = {}
var _active_selection: StringName = &"mochi"
var _auto_sun: bool = true
var _sun_angle_deg: float = 35.0
var _sun_time: float = 0.0
var _dragging_pilot: bool = false
var _pilot_home: Vector2 = Vector2(460.0, 360.0)


func _ready() -> void:
	_load_all_configs()
	_center_world()
	_connect_hud()
	_select_pet(&"mochi")
	_apply_mode(PetOrbit3DController.LabMode.ORBIT_3D)


func _load_all_configs() -> void:
	for pid: StringName in PET_IDS:
		var path: String = "%s/%s.tres" % [CONFIG_DIR, String(pid)]
		var cfg: PetBubbleVisualConfig = ResourceLoader.load(path) as PetBubbleVisualConfig
		if cfg != null:
			_configs[pid] = cfg


func _center_world() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 100.0:
		vp_size = Vector2(1280.0, 720.0)
	_pilot_home = Vector2((vp_size.x - 340.0) * 0.5, vp_size.y * 0.5)
	if pilot_anchor != null:
		pilot_anchor.position = _pilot_home
		pilot_anchor.z_index = 10
	if fetch_gem != null:
		fetch_gem.position = _pilot_home + Vector2(210.0, -90.0)
		fetch_gem.visible = false
	_redraw_markers()


func _connect_hud() -> void:
	if hud == null:
		return
	hud.pet_selected.connect(_select_pet)
	hud.mode_selected.connect(_on_mode_selected)
	hud.emote_triggered.connect(_on_emote_triggered)
	hud.overrides_changed.connect(_on_overrides_changed)
	hud.sun_changed.connect(_on_sun_changed)
	hud.orbit_params_changed.connect(_on_orbit_params_changed)
	hud.layers_changed.connect(_on_layers_changed)
	hud.debug_mode_changed.connect(_on_debug_mode_changed)
	hud.auto_gestures_changed.connect(_on_auto_gestures_changed)


func _select_pet(selection_id: StringName) -> void:
	_active_selection = selection_id
	var list: Array[PetBubbleVisualConfig] = []
	if selection_id == &"all":
		for pid: StringName in PET_IDS:
			if _configs.has(pid):
				list.append(_configs[pid] as PetBubbleVisualConfig)
	elif _configs.has(selection_id):
		list.append(_configs[selection_id] as PetBubbleVisualConfig)

	if orbit_controller != null:
		orbit_controller.set_pets(list)
	_update_status()


func _on_mode_selected(mode_idx: int) -> void:
	_apply_mode(mode_idx as PetOrbit3DController.LabMode)


func _apply_mode(mode: PetOrbit3DController.LabMode) -> void:
	if orbit_controller != null:
		orbit_controller.set_mode(mode)
	if fetch_gem != null:
		fetch_gem.visible = (mode == PetOrbit3DController.LabMode.FETCH_DEMO)
	if pilot_anchor != null:
		pilot_anchor.visible = (mode != PetOrbit3DController.LabMode.CLOSEUP_HERO)
	_update_status()


func _on_emote_triggered(kind: StringName) -> void:
	if orbit_controller != null:
		orbit_controller.trigger_emote_all(kind)


func _on_overrides_changed(
	opacity_mult: float,
	spin_mult: float,
	fresnel_mult: float,
	normal_strength: float,
	edge_tex_opacity: float,
	bubble_bump: float
) -> void:
	if orbit_controller != null:
		orbit_controller.set_runtime_overrides(
			opacity_mult,
			spin_mult,
			fresnel_mult,
			normal_strength,
			edge_tex_opacity,
			bubble_bump
		)


func _on_sun_changed(angle_deg: float, auto_sun: bool) -> void:
	_sun_angle_deg = angle_deg
	_auto_sun = auto_sun
	if not _auto_sun:
		_apply_sun_angle(_sun_angle_deg)


func _on_orbit_params_changed(tilt_deg: float, scale_mult: float, show_guide: bool) -> void:
	if orbit_controller != null:
		orbit_controller.set_orbit_tilt_deg(tilt_deg)
		orbit_controller.set_scale_multiplier(scale_mult)
		orbit_controller.show_orbit_guide = show_guide


func _on_layers_changed(show_back: bool, show_pet: bool, show_front: bool, show_particles: bool) -> void:
	if orbit_controller != null:
		orbit_controller.set_layer_visibility(show_back, show_pet, show_front, show_particles)


func _on_debug_mode_changed(mode_idx: int) -> void:
	if orbit_controller != null:
		orbit_controller.set_pet_debug_mode(mode_idx)


func _on_auto_gestures_changed(enabled: bool) -> void:
	if orbit_controller != null:
		orbit_controller.set_auto_gestures_enabled(enabled)


func _apply_sun_angle(deg: float) -> void:
	var rad: float = deg_to_rad(deg)
	var sun_dir := Vector3(cos(rad), sin(rad), 0.62).normalized()
	if orbit_controller != null:
		orbit_controller.set_sun_direction(sun_dir)


func _update_status() -> void:
	if hud == null or orbit_controller == null:
		return
	var mode_names: Array[String] = ["Órbita 3D", "Closeup Hero", "Fetch Dash", "In-Game 64px"]
	var m_idx: int = clampi(int(orbit_controller.get_mode()), 0, mode_names.size() - 1)
	var pet_label: String = "TODAS (5)" if _active_selection == &"all" else String(_active_selection).capitalize()
	hud.set_status_text("Pet: %s · Modo: %s" % [pet_label, mode_names[m_idx]])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and mb.position.x < get_viewport_rect().size.x - 340.0:
				_dragging_pilot = true
			elif not mb.pressed:
				_dragging_pilot = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and fetch_gem != null and fetch_gem.visible:
			fetch_gem.global_position = mb.position
	elif event is InputEventMouseMotion and _dragging_pilot and pilot_anchor != null:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		pilot_anchor.position = mm.position
	elif event is InputEventKey and event.pressed and not event.echo:
		var ke: InputEventKey = event as InputEventKey
		match ke.keycode:
			KEY_1:
				_select_pet(&"mochi")
			KEY_2:
				_select_pet(&"kuro")
			KEY_3:
				_select_pet(&"luna")
			KEY_4:
				_select_pet(&"pip")
			KEY_5:
				_select_pet(&"cosmo")
			KEY_6:
				_select_pet(&"all")
			KEY_SPACE:
				_on_emote_triggered(&"hop")
			KEY_R:
				_on_emote_triggered(&"roll_360")
			KEY_E:
				_on_emote_triggered(&"wiggle")
			KEY_Q:
				_on_emote_triggered(&"curious_tilt")
			KEY_F:
				_on_emote_triggered(&"flip")
			KEY_TAB:
				var next_mode: int = (int(orbit_controller.get_mode()) + 1) % 4
				_apply_mode(next_mode as PetOrbit3DController.LabMode)


func _process(delta: float) -> void:
	_sun_time += delta
	if _auto_sun:
		_apply_sun_angle(_sun_angle_deg + _sun_time * 32.0)

	if pilot_anchor != null and pilot_anchor.visible:
		var move_dir := Vector2.ZERO
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move_dir.x += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move_dir.x -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move_dir.y += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move_dir.y -= 1.0
		if move_dir.length_squared() > 0.0:
			pilot_anchor.position += move_dir.normalized() * 340.0 * delta

	if space_bg != null and space_bg.material is ShaderMaterial:
		var bg_mat: ShaderMaterial = space_bg.material as ShaderMaterial
		bg_mat.set_shader_parameter("time_sec", _sun_time)
		if pilot_anchor != null:
			bg_mat.set_shader_parameter("camera_offset", pilot_anchor.position - _pilot_home)


func _redraw_markers() -> void:
	if pilot_anchor != null and not pilot_anchor.draw.is_connected(_draw_pilot_anchor):
		pilot_anchor.draw.connect(_draw_pilot_anchor)
	if pilot_anchor != null:
		pilot_anchor.queue_redraw()
	if fetch_gem != null and not fetch_gem.draw.is_connected(_draw_fetch_gem):
		fetch_gem.draw.connect(_draw_fetch_gem)
	if fetch_gem != null:
		fetch_gem.queue_redraw()


func _draw_pilot_anchor() -> void:
	if pilot_anchor == null:
		return
	pilot_anchor.draw_circle(Vector2.ZERO, 28.0, Color(0.14, 0.22, 0.42, 0.55))
	pilot_anchor.draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 40, Color(0.55, 0.85, 1.0, 0.85), 2.2, true)
	var pts := PackedVector2Array([
		Vector2(0.0, -18.0),
		Vector2(14.0, 12.0),
		Vector2(0.0, 6.0),
		Vector2(-14.0, 12.0),
	])
	pilot_anchor.draw_colored_polygon(pts, Color(0.85, 0.94, 1.0, 0.92))


func _draw_fetch_gem() -> void:
	if fetch_gem == null:
		return
	var pts := PackedVector2Array([
		Vector2(0.0, -14.0),
		Vector2(10.0, 0.0),
		Vector2(0.0, 14.0),
		Vector2(-10.0, 0.0),
	])
	fetch_gem.draw_colored_polygon(pts, Color(0.35, 0.96, 1.0, 0.95))
	fetch_gem.draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 24, Color(0.65, 1.0, 1.0, 0.55), 1.5, true)


func get_loaded_configs() -> Dictionary:
	return _configs


func get_orbit_controller() -> PetOrbit3DController:
	return orbit_controller


func select_pet_for_test(selection_id: StringName) -> void:
	_select_pet(selection_id)


func set_mode_for_test(mode: PetOrbit3DController.LabMode) -> void:
	_apply_mode(mode)
