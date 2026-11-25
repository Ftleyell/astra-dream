class_name HubRadialDepartureController
extends Node

## Controlador de Despegue Radial 360° (8 Direcciones Cardinales) y Desmaterialización Tecnológica Seamless.
## - Detecta al piloto alejándose más allá de warning_radius y orienta un arco diegético al sector cardinal activo.
## - Al cruzar launch_radius, despliega el Anillo Orbital de Armamento, barre demat_progress (0→1) en toda
##   la estación flotante, sincroniza CosmosBackdrop y lanza MainGame seamless (o modo Preview con rematerialización).

signal perimeter_warning_updated(progress: float, sector_info: Dictionary)
signal departure_started(sector_info: Dictionary, direction_2d: Vector2)
signal departure_completed(request: RunLaunchRequestScript, launched_combat: bool)
signal hub_rematerialized()

const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_art_lab_config.gd")
const LayoutConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_floating_layout_config.gd")
const PlayerScript = preload("res://scenes/ui/hub/astral_station/components/hub_art_lab_player.gd")
const CosmosBackdropScript = preload("res://scenes/ui/hub/astral_station/components/hub_cosmos_backdrop_controller.gd")
const IslandsBuilder = preload("res://scenes/ui/hub/astral_station/meshes/hub_floating_islands_mesh_builder.gd")
const PropShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_arcsys_prop_3d.gdshader")
const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")

const SPARK_COUNT: int = 48

@export var launch_real_combat: bool = false

var _config: ConfigScript = null
var _layout: LayoutConfigScript = null
var _player: PlayerScript = null
var _cosmos_backdrop: CosmosBackdropScript = null
var _demat_materials: Array[ShaderMaterial] = []
var _dissolve_hide_nodes: Array[Node3D] = []
var _world_3d_parent: Node3D = null

var _is_departing: bool = false
var _is_dissolved_preview: bool = false
var _is_rematerializing: bool = false
var _departure_timer: float = 0.0
var _demat_progress: float = 0.0
var _departure_dir_2d: Vector2 = Vector2.UP
var _departure_origin: Vector3 = Vector3.ZERO
var _active_sector: Dictionary = {}
var _pending_request: RunLaunchRequestScript = null
var _can_trigger_departure: bool = true

var _compass_arc_mesh: MeshInstance3D = null
var _compass_mats: Array[ShaderMaterial] = []
var _spark_root: Node3D = null
var _spark_nodes: Array[MeshInstance3D] = []
var _spark_mat: ShaderMaterial = null
var _spark_offsets: Array[Vector3] = []
var _spark_phases: PackedFloat32Array = PackedFloat32Array()
var _shockwave_ring: MeshInstance3D = null
var _shockwave_mat: ShaderMaterial = null


func setup(
	p_config: ConfigScript,
	p_layout: LayoutConfigScript,
	p_player: PlayerScript,
	p_cosmos: CosmosBackdropScript,
	p_world_3d_parent: Node3D
) -> void:
	_config = p_config
	_layout = p_layout
	_player = p_player
	_cosmos_backdrop = p_cosmos
	_world_3d_parent = p_world_3d_parent
	_ensure_visual_nodes()
	_apply_demat_to_materials(0.0, Vector3.ZERO)


func set_demat_materials(mats: Array[ShaderMaterial]) -> void:
	_demat_materials = mats.duplicate()
	_apply_demat_to_materials(_demat_progress, _departure_origin)


func set_dissolve_hide_nodes(nodes: Array[Node3D]) -> void:
	_dissolve_hide_nodes = nodes.duplicate()


func _set_hide_nodes_visible(vis: bool) -> void:
	for n: Node3D in _dissolve_hide_nodes:
		if n != null and is_instance_valid(n):
			n.visible = vis


func set_departure_enabled(enabled: bool) -> void:
	_can_trigger_departure = enabled


func set_pending_request(req: RunLaunchRequestScript) -> void:
	_pending_request = req.duplicate_request() if req != null else null


func is_departing() -> bool:
	return _is_departing


func is_dissolved_preview() -> bool:
	return _is_dissolved_preview


func get_demat_progress() -> float:
	return _demat_progress


func get_active_sector() -> Dictionary:
	return _active_sector


func _ensure_visual_nodes() -> void:
	if _world_3d_parent == null:
		return
	if _compass_arc_mesh == null:
		_compass_arc_mesh = MeshInstance3D.new()
		_compass_arc_mesh.name = "PerimeterCompassArc"
		_compass_arc_mesh.mesh = IslandsBuilder.build_perimeter_compass_arc_mesh()
		_compass_arc_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_compass_arc_mesh.visible = false
		_compass_mats.clear()
		var cols: Array[Color] = [Color(0.32, 0.38, 0.56, 1.0), Color(0.08, 0.10, 0.18, 1.0), Color(0.14, 0.94, 1.0, 1.0)]
		for si: int in range(3):
			var m := ShaderMaterial.new()
			m.shader = PropShader
			m.set_shader_parameter("material_kind", si)
			m.set_shader_parameter("base_color", cols[si])
			m.set_shader_parameter("pilot_accent_color", cols[2])
			m.set_shader_parameter("emissive_boost", 2.2)
			_compass_mats.append(m)
			_compass_arc_mesh.set_surface_override_material(si, m)
		_world_3d_parent.add_child(_compass_arc_mesh)

	if _spark_root == null:
		_spark_root = Node3D.new()
		_spark_root.name = "DematDataSparks"
		_spark_root.visible = false
		_world_3d_parent.add_child(_spark_root)

		_spark_mat = ShaderMaterial.new()
		_spark_mat.shader = PropShader
		_spark_mat.set_shader_parameter("material_kind", 2)
		_spark_mat.set_shader_parameter("base_color", Color(0.15, 0.95, 1.0, 1.0))
		_spark_mat.set_shader_parameter("pilot_accent_color", Color(0.15, 0.95, 1.0, 1.0))
		_spark_mat.set_shader_parameter("emissive_boost", 2.6)

		var spark_mesh: ArrayMesh = IslandsBuilder.build_data_spark_mesh()
		_spark_nodes.clear()
		_spark_offsets.clear()
		_spark_phases.resize(SPARK_COUNT)
		for i: int in range(SPARK_COUNT):
			var ang: float = TAU * float(i) / float(SPARK_COUNT)
			var rad: float = 1.6 + float(i % 6) * 3.8
			var mi := MeshInstance3D.new()
			mi.name = "DematSpark_%d" % i
			mi.mesh = spark_mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.set_surface_override_material(0, _spark_mat)
			_spark_root.add_child(mi)
			_spark_nodes.append(mi)
			_spark_offsets.append(Vector3(cos(ang) * rad, 0.1, sin(ang) * rad))
			_spark_phases[i] = float(i) / float(SPARK_COUNT)

		_shockwave_mat = ShaderMaterial.new()
		_shockwave_mat.shader = PropShader
		_shockwave_mat.set_shader_parameter("material_kind", 2)
		_shockwave_mat.set_shader_parameter("base_color", Color(0.18, 0.94, 1.0, 1.0))
		_shockwave_mat.set_shader_parameter("pilot_accent_color", Color(0.95, 0.80, 0.34, 1.0))
		_shockwave_mat.set_shader_parameter("emissive_boost", 2.8)
		var torus := TorusMesh.new()
		torus.inner_radius = 0.965
		torus.outer_radius = 1.005
		torus.rings = 64
		torus.ring_segments = 10
		_shockwave_ring = MeshInstance3D.new()
		_shockwave_ring.name = "DematShockwaveRing"
		_shockwave_ring.mesh = torus
		_shockwave_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shockwave_ring.set_surface_override_material(0, _shockwave_mat)
		_spark_root.add_child(_shockwave_ring)


func trigger_radial_departure(override_dir: Vector2 = Vector2.ZERO) -> void:
	if _is_departing or _is_dissolved_preview or _layout == null or _player == null:
		return

	var pos_xz := Vector2(_player.global_position.x, _player.global_position.z)
	var dir: Vector2 = override_dir.normalized() if override_dir.length_squared() > 0.001 else (pos_xz.normalized() if pos_xz.length_squared() > 0.001 else Vector2.UP)
	_departure_dir_2d = dir
	_departure_origin = _player.global_position
	_active_sector = _layout.quantize_departure_sector(dir)

	_is_departing = true
	_is_rematerializing = false
	_departure_timer = 0.0

	if _compass_arc_mesh != null:
		_compass_arc_mesh.visible = false
	if _spark_root != null:
		_spark_root.visible = true

	_player.set_forced_space_flight(true)
	_player.is_movement_locked = true
	_player.is_pose_override_active = true
	_player.set_pose_override(dir, 1.25, dir, false)
	if _player.rig_avatar != null:
		_player.rig_avatar.set_orbital_weapon_deployed(true)

	departure_started.emit(_active_sector, dir)


func rematerialize_hub(snap_player_to_center: bool = true) -> void:
	if _is_departing:
		return
	_is_dissolved_preview = false
	_is_rematerializing = true
	_departure_timer = 0.0
	if _player != null:
		_player.is_movement_locked = false
		_player.is_pose_override_active = false
		_player.set_forced_space_flight(false)
		if snap_player_to_center:
			_player.global_position = _config.player_spawn_pos if _config != null else Vector3(0.0, 0.02, 4.2)
			_player.face_front_idle(true)
			_player.evaluate_platform_traversal(0.0, true)
		if _player.rig_avatar != null:
			_player.rig_avatar.set_orbital_weapon_deployed(false)
	_set_hide_nodes_visible(true)
	if _cosmos_backdrop != null:
		_cosmos_backdrop.blend_camera_zoom_to_combat(0.0)
	if _spark_root != null:
		_spark_root.visible = false


func _process(delta: float) -> void:
	if _layout == null or _player == null:
		return

	if _is_departing:
		_step_departure(delta)
		return

	if _is_rematerializing:
		_step_rematerialize(delta)
		return

	if _is_dissolved_preview or not _can_trigger_departure:
		if _compass_arc_mesh != null:
			_compass_arc_mesh.visible = false
		return

	var xz := Vector2(_player.global_position.x, _player.global_position.z)
	var dist: float = xz.length()
	if dist >= _layout.launch_radius:
		trigger_radial_departure(xz.normalized())
		return

	if dist >= _layout.warning_radius:
		var prog: float = clampf((dist - _layout.warning_radius) / maxf(_layout.launch_radius - _layout.warning_radius, 0.1), 0.0, 1.0)
		var dir: Vector2 = xz.normalized()
		_active_sector = _layout.quantize_departure_sector(dir)
		_update_compass_arc(dir, prog)
		perimeter_warning_updated.emit(prog, _active_sector)
	else:
		if _compass_arc_mesh != null and _compass_arc_mesh.visible:
			_compass_arc_mesh.visible = false
		perimeter_warning_updated.emit(0.0, {})


func _update_compass_arc(dir_xz: Vector2, prog: float) -> void:
	if _compass_arc_mesh == null or _player == null:
		return
	_compass_arc_mesh.visible = true
	_compass_arc_mesh.position = Vector3(_player.global_position.x, 0.08, _player.global_position.z)
	_compass_arc_mesh.rotation = Vector3(0.0, atan2(-dir_xz.x, -dir_xz.y), 0.0)
	var sc: float = lerpf(0.95, 1.18, prog)
	_compass_arc_mesh.scale = Vector3(sc, 1.0, sc)
	var sec_col: Color = _active_sector.get("color", Color(0.14, 0.94, 1.0, 1.0)) as Color
	if _compass_mats.size() >= 3:
		_compass_mats[2].set_shader_parameter("base_color", sec_col)
		_compass_mats[2].set_shader_parameter("pilot_accent_color", sec_col)
		_compass_mats[2].set_shader_parameter("emissive_boost", lerpf(1.6, 3.4, prog))


func _step_departure(delta: float) -> void:
	var dur: float = maxf(_layout.demat_duration_sec, 0.25)
	_departure_timer += delta
	var t: float = clampf(_departure_timer / dur, 0.0, 1.0)
	var ease_t: float = t * t * (3.0 - 2.0 * t)

	_demat_progress = ease_t
	_apply_demat_to_materials(_demat_progress, _departure_origin)

	# Impulso continuo en dirección de salida
	var boost_spd: float = _layout.departure_boost_speed * lerpf(0.75, 1.25, ease_t)
	_player.global_position.x += _departure_dir_2d.x * boost_spd * delta
	_player.global_position.z += _departure_dir_2d.y * boost_spd * delta
	_player.set_pose_override(_departure_dir_2d, 1.25, _departure_dir_2d, false)

	if _cosmos_backdrop != null:
		_cosmos_backdrop.blend_camera_zoom_to_combat(ease_t)

	_update_data_sparks(t)

	if t >= 1.0:
		_finish_departure()


func _step_rematerialize(delta: float) -> void:
	_departure_timer += delta
	var t: float = clampf(_departure_timer / 0.75, 0.0, 1.0)
	var ease_t: float = 1.0 - (t * t * (3.0 - 2.0 * t))
	_demat_progress = ease_t
	_apply_demat_to_materials(_demat_progress, Vector3.ZERO)
	if t >= 1.0:
		_is_rematerializing = false
		_demat_progress = 0.0
		_apply_demat_to_materials(0.0, Vector3.ZERO)
		hub_rematerialized.emit()


func _update_data_sparks(t_norm: float) -> void:
	if _spark_root == null:
		return
	if _shockwave_ring != null:
		var wave_r: float = maxf(0.4, lerpf(0.8, 34.0, t_norm))
		_shockwave_ring.position = Vector3(_departure_origin.x, 0.24, _departure_origin.z)
		_shockwave_ring.scale = Vector3(wave_r, 0.55, wave_r)
	for i: int in range(_spark_nodes.size()):
		var mi: MeshInstance3D = _spark_nodes[i]
		var ph: float = fmod(t_norm * 1.8 + _spark_phases[i], 1.0)
		var base_off: Vector3 = _spark_offsets[i]
		mi.position = Vector3(base_off.x, ph * 6.5, base_off.z)
		var s: float = sin(ph * PI) * 1.1
		mi.scale = Vector3(s, s * 1.6, s)


func _finish_departure() -> void:
	_is_departing = false
	_demat_progress = 1.0
	_apply_demat_to_materials(1.0, _departure_origin)
	if _spark_root != null:
		_spark_root.visible = false

	var req: RunLaunchRequestScript = _pending_request.duplicate_request() if _pending_request != null else RunLaunchRequestScript.create_random_auto()
	req.departure_sector = _active_sector.get("id", &"N") as StringName
	req.departure_direction = _departure_dir_2d
	req.seamless_entry = true
	if _cosmos_backdrop != null:
		var sync_state: Dictionary = _cosmos_backdrop.get_cosmos_sync_state()
		req.cosmos_seed = int(sync_state.get("cosmos_seed", req.cosmos_seed))
		req.cosmos_sync_time = float(sync_state.get("cosmos_sync_time", 0.0))
		req.cosmos_sync_pos = sync_state.get("cosmos_sync_pos", Vector2.ZERO) as Vector2

	RunLaunchRequestScript.set_pending(req)

	var launched_combat: bool = false
	if launch_real_combat and get_tree() != null:
		SaveManagerScript.is_resuming_run = false
		var err: Error = get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")
		launched_combat = (err == OK)

	if not launched_combat:
		_is_dissolved_preview = true
		_set_hide_nodes_visible(false)
		_player.is_movement_locked = false
		_player.is_pose_override_active = false

	departure_completed.emit(req, launched_combat)


func _apply_demat_to_materials(progress: float, origin: Vector3) -> void:
	for mat: ShaderMaterial in _demat_materials:
		if mat == null or not is_instance_valid(mat):
			continue
		mat.set_shader_parameter("demat_progress", progress)
		mat.set_shader_parameter("demat_origin", origin)
		mat.set_shader_parameter("demat_max_radius", 34.0)
