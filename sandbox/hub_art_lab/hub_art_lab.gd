class_name HubArtLab
extends Node3D

## Escena Vertical Slice (Fase 1) del Rework Total del Hub 3D ("Estación Astral v2 — Opción A").
## Ensambla arquitectura en "U" abierta al Sur con mapas Ink SDF 2x, Ventanal Norte con CosmosRootNode vivo,
## Cápsula Central de sincronización (auto-alineación frontal "s" + zoom), Consolas de Antesala con
## estados CALIBRATING/NEWLY_UNLOCKED/ONLINE, Anillo de Ignición Norte y Valentina v2 en vuelo 8-dir.

const ConfigScript = preload("res://sandbox/hub_art_lab/resources/hub_art_lab_config.gd")
const DEFAULT_CONFIG: ConfigScript = preload("res://sandbox/hub_art_lab/data/default_hub_art_lab_config.tres")
const ArchBuilder = preload("res://sandbox/hub_art_lab/meshes/hub_architecture_mesh_builder.gd")
const CapsuleBuilder = preload("res://sandbox/hub_art_lab/meshes/hub_capsule_mesh_builder.gd")
const TextureLoader = preload("res://sandbox/hub_art_lab/components/hub_texture_loader.gd")
const CosmosWindowScript = preload("res://sandbox/hub_art_lab/components/hub_cosmos_window_controller.gd")
const CameraRigScript = preload("res://sandbox/hub_art_lab/components/hub_lab_camera_rig.gd")
const StationNodeScript = preload("res://sandbox/hub_art_lab/components/hub_lab_station_node.gd")
const PlayerScript = preload("res://sandbox/hub_art_lab/components/hub_art_lab_player.gd")
const HUDScript = preload("res://sandbox/hub_art_lab/hub_art_lab_hud.gd")
const AstralWings3DScript = preload("res://scenes/pilots/vfx/astral_wings_3d_controller.gd")

const SurfaceShader = preload("res://sandbox/hub_art_lab/shaders/hub_arcsys_surface_3d.gdshader")
const PropShader = preload("res://sandbox/hub_art_lab/shaders/hub_arcsys_prop_3d.gdshader")
const OutlineShader = preload("res://sandbox/hub_art_lab/shaders/hub_arcsys_outline_3d.gdshader")
const IgnitionRingShader = preload("res://sandbox/hub_art_lab/shaders/hub_ignition_ring_3d.gdshader")

const FLOOR_TEX_BASE: String = "res://sandbox/hub_art_lab/assets/surfaces/hub_floor_astral"
const WALL_TEX_BASE: String = "res://sandbox/hub_art_lab/assets/surfaces/hub_wall_astral"
const RING_TEX_PATH: String = "res://sandbox/hub_art_lab/assets/rings/hub_ignition_ring_packed.png"
const WORKBENCH_HUB_PATH: String = "res://sandbox/workbenches/workbench_hub.tscn"

@export var config: ConfigScript = DEFAULT_CONFIG

var camera: Camera3D = null
var player: PlayerScript = null
var cosmos_window: CosmosWindowScript = null
var camera_rig: CameraRigScript = CameraRigScript.new()
var left_station: StationNodeScript = null
var right_station: StationNodeScript = null
var left_far_station: StationNodeScript = null
var right_far_station: StationNodeScript = null
var hud: HUDScript = null

var _world_env: WorldEnvironment = null
var _dir_light: DirectionalLight3D = null
var _floor_mat: ShaderMaterial = null
var _wall_mats: Array[ShaderMaterial] = []
var _arch_prop_mats: Array[ShaderMaterial] = []
var _hero_prop_mats: Array[ShaderMaterial] = []
var _prop_outline_mat: ShaderMaterial = null
var _ring_mat: ShaderMaterial = null
var _capsule_halo_mesh: MeshInstance3D = null
var _capsule_area: Area3D = null
var _capsule_label: Label3D = null
var _ignition_area: Area3D = null
var _ignition_label: Label3D = null

var _is_capsule_focused: bool = false
var _is_ignition_previewing: bool = false
var _ignition_timer: float = 0.0
var _time_acc: float = 0.0


func _ready() -> void:
	if config == null:
		config = DEFAULT_CONFIG
	if get_viewport() != null:
		get_viewport().msaa_2d = Viewport.MSAA_DISABLED
	_build_environment()
	_build_architecture()
	_build_cosmos_window()
	_build_central_capsule()
	_build_antesala_stations()
	_build_ignition_ring()
	_build_player_and_camera()
	_build_hud()
	apply_config_visuals()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.018, 0.042, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.11, 0.14, 0.24, 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.12
	env.glow_intensity = config.bloom_intensity
	env.glow_bloom = config.glow_bloom

	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnvironment"
	_world_env.environment = env
	add_child(_world_env)

	_dir_light = DirectionalLight3D.new()
	_dir_light.name = "DirectionalLight3D"
	_dir_light.rotation_degrees = Vector3(-48.0, -24.0, 0.0)
	_dir_light.light_color = Color(1.0, 0.98, 0.95, 1.0)
	_dir_light.light_energy = 0.92
	_dir_light.shadow_enabled = true
	_dir_light.shadow_bias = 0.04
	_dir_light.shadow_normal_bias = 1.2
	_dir_light.shadow_blur = 0.6
	_dir_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_dir_light.directional_shadow_max_distance = 45.0
	add_child(_dir_light)

	# 3 luces ambientales controladas: Oeste Santuario, Este Psycho-Pop y rebote del Ventanal Norte
	var west_light := OmniLight3D.new()
	west_light.name = "WestAccentLight"
	west_light.position = Vector3(-9.8, 2.7, 0.8)
	west_light.light_color = Color(0.62, 0.30, 1.0, 1.0)
	west_light.light_energy = 0.95
	west_light.omni_range = 13.5
	add_child(west_light)

	var east_light := OmniLight3D.new()
	east_light.name = "EastAccentLight"
	east_light.position = Vector3(9.8, 2.7, 0.8)
	east_light.light_color = Color(1.0, 0.18, 0.62, 1.0)
	east_light.light_energy = 0.95
	east_light.omni_range = 13.5
	add_child(east_light)

	var cosmos_bounce_light := OmniLight3D.new()
	cosmos_bounce_light.name = "NorthCosmosBounceLight"
	cosmos_bounce_light.position = Vector3(0.0, 3.4, -8.5)
	cosmos_bounce_light.light_color = Color(0.28, 0.86, 0.96, 1.0)
	cosmos_bounce_light.light_energy = 0.72
	cosmos_bounce_light.omni_range = 14.0
	add_child(cosmos_bounce_light)


func _build_architecture() -> void:
	var arch_root := Node3D.new()
	arch_root.name = "StationArchitecture"
	add_child(arch_root)

	# 1. Piso principal (24 x 22 m, escala monumental 5.5 m/tile) con zonificación Night Hull
	_floor_mat = _create_surface_material(
		FLOOR_TEX_BASE,
		config.floor_uv_scale,
		Vector2(1024.0, 1024.0),
		Color(0.20, 0.25, 0.38, 1.0),
		Color(0.055, 0.068, 0.12, 1.0)
	)
	_floor_mat.set_shader_parameter("enable_deck_zoning", true)
	_floor_mat.set_shader_parameter("tile_emissive_mult", 0.16)
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "DeckFloorMesh"
	floor_mi.mesh = ArchBuilder.build_floor_mesh(24.0, 22.0, 6.0)
	floor_mi.position = Vector3(0.0, 0.0, 0.5)
	floor_mi.material_override = _floor_mat
	arch_root.add_child(floor_mi)

	_add_static_box(arch_root, "FloorCollider", Vector3(0.0, -0.25, 0.5), Vector3(24.4, 0.5, 22.4))
	_add_static_box(arch_root, "WestBoundary", Vector3(-12.4, 2.0, 0.5), Vector3(0.8, 4.0, 23.0))
	_add_static_box(arch_root, "EastBoundary", Vector3(12.4, 2.0, 0.5), Vector3(0.8, 4.0, 23.0))
	_add_static_box(arch_root, "NorthBoundary", Vector3(0.0, 2.0, -10.8), Vector3(25.0, 4.0, 0.8))
	_add_static_box(arch_root, "SouthBoundary", Vector3(0.0, 2.0, 11.6), Vector3(25.0, 4.0, 0.8))

	# 2. Muros laterales en "U" (Oeste Santuario y Este Psycho-Pop) con winding interior verificado
	var wall_mesh: ArrayMesh = ArchBuilder.build_side_wall_mesh(22.0, 3.8, 4.0)
	var west_mat: ShaderMaterial = _create_surface_material(
		WALL_TEX_BASE,
		config.wall_uv_scale,
		Vector2(1024.0, 572.0),
		Color(0.30, 0.32, 0.48, 1.0),
		Color(0.07, 0.08, 0.15, 1.0)
	)
	west_mat.set_shader_parameter("pilot_accent_color", Color(0.74, 0.36, 1.0, 1.0))
	west_mat.set_shader_parameter("ambient_fill", 0.42)
	west_mat.set_shader_parameter("tile_emissive_mult", 0.78)
	_wall_mats.append(west_mat)

	var west_wall := MeshInstance3D.new()
	west_wall.name = "WestSanctuaryWall"
	west_wall.mesh = wall_mesh
	west_wall.position = Vector3(-12.0, 0.0, 0.5)
	west_wall.material_override = west_mat
	arch_root.add_child(west_wall)

	var east_mat: ShaderMaterial = _create_surface_material(
		WALL_TEX_BASE,
		config.wall_uv_scale,
		Vector2(1024.0, 572.0),
		Color(0.28, 0.34, 0.50, 1.0),
		Color(0.07, 0.08, 0.15, 1.0)
	)
	east_mat.set_shader_parameter("pilot_accent_color", Color(1.0, 0.16, 0.62, 1.0))
	east_mat.set_shader_parameter("ambient_fill", 0.42)
	east_mat.set_shader_parameter("tile_emissive_mult", 0.85)
	_wall_mats.append(east_mat)

	var east_wall := MeshInstance3D.new()
	east_wall.name = "EastPsychoPopWall"
	east_wall.mesh = wall_mesh
	east_wall.position = Vector3(12.0, 0.0, 0.5)
	east_wall.rotation = Vector3(0.0, PI, 0.0)
	east_wall.material_override = east_mat
	arch_root.add_child(east_wall)

	# 3. Materiales separados: Arquitectura oscura (fondo) vs Hero Props (primer plano)
	_prop_outline_mat = ShaderMaterial.new()
	_prop_outline_mat.shader = OutlineShader
	_arch_prop_mats = _create_prop_surface_materials(Color(0.28, 0.33, 0.46, 1.0), Color(0.06, 0.075, 0.14, 1.0), 0.20)
	_hero_prop_mats = _create_prop_surface_materials(Color(0.46, 0.52, 0.66, 1.0), Color(0.07, 0.085, 0.15, 1.0), 0.24)

	var ign_socket_pos := Vector3(config.ignition_ring_pos.x, 0.0, config.ignition_ring_pos.z)
	for piece_spec: Dictionary in [
		{"name": "StructuralRibs", "mesh": ArchBuilder.build_structural_ribs_mesh(), "shadow": true, "pos": Vector3.ZERO},
		{"name": "NorthWindowFrame", "mesh": ArchBuilder.build_north_window_frame_mesh(), "shadow": true, "pos": Vector3.ZERO},
		{"name": "SouthLowRailing", "mesh": ArchBuilder.build_south_railing_mesh(), "shadow": false, "pos": Vector3.ZERO},
		{"name": "IgnitionPadSocket", "mesh": ArchBuilder.build_ignition_pad_socket_mesh(), "shadow": false, "pos": ign_socket_pos},
		{"name": "WingAlcovePads", "mesh": ArchBuilder.build_wing_alcove_pads_mesh(), "shadow": false, "pos": Vector3.ZERO},
	]:
		var mi := MeshInstance3D.new()
		mi.name = str(piece_spec["name"])
		mi.mesh = piece_spec["mesh"] as ArrayMesh
		mi.position = piece_spec["pos"] as Vector3
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(piece_spec["shadow"]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surf_idx: int in range(3):
			mi.set_surface_override_material(surf_idx, _arch_prop_mats[surf_idx])
		arch_root.add_child(mi)


func _build_cosmos_window() -> void:
	var window_mesh := MeshInstance3D.new()
	window_mesh.name = "NorthCosmosWindowMesh"
	var quad := QuadMesh.new()
	quad.size = config.north_window_size
	window_mesh.mesh = quad
	window_mesh.position = config.north_window_pos
	window_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(window_mesh)

	cosmos_window = CosmosWindowScript.new() as CosmosWindowScript
	cosmos_window.name = "HubCosmosWindowController"
	add_child(cosmos_window)
	cosmos_window.setup(config, window_mesh)


func _build_central_capsule() -> void:
	var cap_root := Node3D.new()
	cap_root.name = "CentralPilotCapsule"
	cap_root.position = config.capsule_pos
	add_child(cap_root)

	var base_mi := MeshInstance3D.new()
	base_mi.name = "CapsuleBaseMesh"
	base_mi.mesh = CapsuleBuilder.build_capsule_base_mesh()
	base_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for surf_idx: int in range(3):
		base_mi.set_surface_override_material(surf_idx, _hero_prop_mats[surf_idx])
	cap_root.add_child(base_mi)

	_capsule_halo_mesh = MeshInstance3D.new()
	_capsule_halo_mesh.name = "CapsuleHaloMesh"
	_capsule_halo_mesh.mesh = CapsuleBuilder.build_capsule_halo_mesh()
	_capsule_halo_mesh.position = Vector3(0.0, 1.82, -1.34)
	_capsule_halo_mesh.rotation_degrees = Vector3.ZERO
	_capsule_halo_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for surf_idx: int in range(3):
		_capsule_halo_mesh.set_surface_override_material(surf_idx, _hero_prop_mats[surf_idx])
	cap_root.add_child(_capsule_halo_mesh)

	# Colisión transitable escalonada sobre el suelo
	_add_static_cyl(cap_root, "CapsuleStepCollider", Vector3(0.0, 0.08, 0.0), 1.82, 0.16)

	_capsule_area = _create_trigger_area("CapsuleInteractArea", Vector3(0.0, 0.9, 0.0), 1.85)
	cap_root.add_child(_capsule_area)

	_capsule_label = _create_prompt_label("CapsulePromptLabel", Vector3(0.0, 2.35, 0.0), "[E] CÁPSULA DE PILOTO")
	cap_root.add_child(_capsule_label)


func _build_antesala_stations() -> void:
	left_station = _spawn_station(
		"LeftSkinsConsole",
		config.console_left_pos,
		24.0,
		&"skins_mirror",
		"Espejo de Skins",
		"Consigue tu primera skin en el Invocador Gacha",
		StationNodeScript.StationState.ONLINE
	)
	right_station = _spawn_station(
		"RightTacticalConsole",
		config.console_right_pos,
		-24.0,
		&"tactical_console",
		"Consola Táctica",
		"Completa 1 incursión para calibrar",
		StationNodeScript.StationState.CALIBRATING
	)
	left_far_station = _spawn_station(
		"LeftTalentsConsole",
		config.console_left_far_pos,
		20.0,
		&"talents_nexus",
		"Nexo de Talentos",
		"Completa tu primer sector para calibrar",
		StationNodeScript.StationState.CALIBRATING
	)
	right_far_station = _spawn_station(
		"RightCompanionsConsole",
		config.console_right_far_pos,
		-20.0,
		&"companions_projector",
		"Proyector de Compañeros",
		"Desbloquea un Pet o Navegante para calibrar",
		StationNodeScript.StationState.CALIBRATING
	)


func _spawn_station(
	node_name: String,
	pos: Vector3,
	yaw_deg: float,
	station_id: StringName,
	title: String,
	hint: String,
	init_state: StationNodeScript.StationState
) -> StationNodeScript:
	var st := StationNodeScript.new() as StationNodeScript
	st.name = node_name
	st.position = pos
	st.rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	add_child(st)
	st.setup(station_id, title, hint, init_state, config.pilot_accent_color, config.calibrating_tint)
	st.station_interacted.connect(_on_station_interacted)
	return st


func _all_stations() -> Array[StationNodeScript]:
	var list: Array[StationNodeScript] = []
	for st: StationNodeScript in [left_station, right_station, left_far_station, right_far_station]:
		if st != null:
			list.append(st)
	return list


func _build_ignition_ring() -> void:
	var ring_root := Node3D.new()
	ring_root.name = "NorthIgnitionRing"
	ring_root.position = Vector3(config.ignition_ring_pos.x, 0.0, config.ignition_ring_pos.z)
	add_child(ring_root)

	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = IgnitionRingShader
	var ring_tex: Texture2D = TextureLoader.load_texture_2d(RING_TEX_PATH, true)
	if ring_tex != null:
		_ring_mat.set_shader_parameter("ring_packed_tex", ring_tex)
	_ring_mat.set_shader_parameter("ring_accent_color", config.pilot_accent_color)

	var plane := PlaneMesh.new()
	plane.size = config.ignition_ring_size
	var ring_mi := MeshInstance3D.new()
	ring_mi.name = "IgnitionRingMesh"
	ring_mi.mesh = plane
	ring_mi.position = Vector3(0.0, 0.065, 0.0)
	ring_mi.material_override = _ring_mat
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_root.add_child(ring_mi)

	_ignition_area = _create_trigger_area("IgnitionInteractArea", Vector3(0.0, 0.8, 0.0), 2.15)
	ring_root.add_child(_ignition_area)

	_ignition_label = _create_prompt_label("IgnitionPromptLabel", Vector3(0.0, 2.35, 0.0), "[E] SALTAR AL COSMOS")
	ring_root.add_child(_ignition_label)


func _build_player_and_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	add_child(camera)

	player = PlayerScript.new() as PlayerScript
	player.name = "HubArtLabPlayer"
	player.position = config.player_spawn_pos
	add_child(player)
	player.setup(config.player_move_speed, _dir_light)

	camera_rig.configure(camera, config)
	camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
	camera_rig.update(camera, player.global_position, 0.0, config, true)


func _build_hud() -> void:
	hud = HUDScript.new() as HUDScript
	hud.name = "HubArtLabHUD"
	add_child(hud)
	hud.setup(config)
	hud.camera_mode_requested.connect(_on_hud_camera_mode_requested)
	hud.accent_color_selected.connect(set_pilot_accent_color)
	hud.station_state_cycled.connect(cycle_right_station_state)
	hud.seed_apply_requested.connect(func(s: int) -> void:
		if cosmos_window != null:
			cosmos_window.set_preview_seed(s, true)
		_refresh_hud_status()
	)
	hud.seed_random_requested.connect(func() -> void:
		if cosmos_window != null:
			cosmos_window.set_preview_seed(maxi(1, int(randi()) & 0x7FFFFFFF), true)
		_refresh_hud_status()
	)
	hud.quality_tier_selected.connect(func(q: int) -> void:
		if cosmos_window != null:
			cosmos_window.apply_quality_tier(q)
	)
	hud.shader_params_changed.connect(apply_config_visuals)
	hud.save_config_requested.connect(_save_config_resource)
	hud.back_to_workbench_requested.connect(_return_to_workbench)
	_refresh_hud_status()


func _process(delta: float) -> void:
	_time_acc += delta
	if _capsule_halo_mesh != null:
		_capsule_halo_mesh.rotate_object_local(Vector3.FORWARD, delta * 0.42)

	if _is_ignition_previewing:
		_ignition_timer += delta
		var t: float = clampf(_ignition_timer / maxf(config.ignition_preview_duration, 0.1), 0.0, 1.0)
		if _ring_mat != null:
			_ring_mat.set_shader_parameter("ignition_charge", t)
		if t >= 1.0:
			_finish_ignition_preview()

	if player != null and camera != null:
		camera_rig.update(camera, player.global_position, delta, config, false)
	_update_proximity_prompts()


func _unhandled_input(event: InputEvent) -> void:
	var key_ev := event as InputEventKey
	if key_ev == null or not key_ev.pressed or key_ev.echo:
		return
	match key_ev.keycode:
		KEY_H:
			if hud != null:
				hud.toggle_visible()
		KEY_E:
			_handle_interact_press()
		KEY_ESCAPE:
			if _is_capsule_focused:
				exit_capsule_focus()
			elif camera_rig.get_mode() != CameraRigScript.Mode.FREE_ROAM and not _is_ignition_previewing:
				_set_camera_mode(CameraRigScript.Mode.FREE_ROAM)
		KEY_1:
			_set_camera_mode(CameraRigScript.Mode.FREE_ROAM)
		KEY_2:
			trigger_capsule_focus()
		KEY_3:
			if left_station != null:
				_set_camera_mode(CameraRigScript.Mode.STATION_FOCUS, left_station.global_position)
		KEY_4:
			trigger_ignition_preview()


func _handle_interact_press() -> void:
	if _is_ignition_previewing:
		return
	if _is_capsule_focused:
		exit_capsule_focus()
		return
	if player != null and _capsule_area != null and _capsule_area.overlaps_body(player):
		trigger_capsule_focus()
		return
	if player != null and _ignition_area != null and _ignition_area.overlaps_body(player):
		trigger_ignition_preview()
		return
	for st: StationNodeScript in _all_stations():
		if st.is_player_inside(player):
			st.trigger_interaction()
			return


func trigger_capsule_focus() -> void:
	if _is_ignition_previewing or player == null:
		return
	_is_capsule_focused = true
	player.is_movement_locked = true
	player.global_position = config.capsule_pos + Vector3(0.0, 0.16, 0.0)
	player.face_front_idle(true)
	camera_rig.set_mode(CameraRigScript.Mode.CAPSULE_PILOT_FOCUS, config.capsule_pos)
	_refresh_hud_status()


func exit_capsule_focus() -> void:
	_is_capsule_focused = false
	if player != null:
		player.is_movement_locked = false
	camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
	_refresh_hud_status()


func trigger_ignition_preview() -> void:
	if _is_ignition_previewing or player == null:
		return
	_is_capsule_focused = false
	_is_ignition_previewing = true
	_ignition_timer = 0.0
	player.is_movement_locked = true
	player.global_position = Vector3(config.ignition_ring_pos.x, 0.065, config.ignition_ring_pos.z)
	player.face_front_idle(true)
	if player.rig_avatar != null:
		var rig: PlanarCombatRig = player.rig_avatar.get_rig()
		if rig != null:
			rig.set_3d_wings_enabled(true)
			rig.set_3d_wings_anim_state(AstralWings3DScript.AnimState.SERAPH_BLOOM, false)
			rig.trigger_3d_wings_pulse()
	camera_rig.set_mode(CameraRigScript.Mode.IGNITION_LAUNCH, config.ignition_ring_pos)
	_refresh_hud_status()


func _finish_ignition_preview() -> void:
	_is_ignition_previewing = false
	if _ring_mat != null:
		_ring_mat.set_shader_parameter("ignition_charge", 0.0)
	if player != null:
		player.is_movement_locked = false
		if player.rig_avatar != null:
			var rig: PlanarCombatRig = player.rig_avatar.get_rig()
			if rig != null:
				rig.set_3d_wings_enabled(false)
	camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
	_refresh_hud_status()


func _on_station_interacted(station_node: Node3D) -> void:
	var station: StationNodeScript = station_node as StationNodeScript
	if station == null:
		return
	if station.get_station_state() == StationNodeScript.StationState.CALIBRATING:
		return
	if camera_rig.get_mode() == CameraRigScript.Mode.STATION_FOCUS:
		_set_camera_mode(CameraRigScript.Mode.FREE_ROAM)
		if player != null:
			player.is_movement_locked = false
	else:
		if player != null:
			player.is_movement_locked = true
		_set_camera_mode(CameraRigScript.Mode.STATION_FOCUS, station.global_position)


func _on_hud_camera_mode_requested(mode_idx: int) -> void:
	match mode_idx:
		CameraRigScript.Mode.CAPSULE_PILOT_FOCUS:
			trigger_capsule_focus()
		CameraRigScript.Mode.STATION_FOCUS:
			if left_station != null:
				_set_camera_mode(CameraRigScript.Mode.STATION_FOCUS, left_station.global_position)
		CameraRigScript.Mode.IGNITION_LAUNCH:
			trigger_ignition_preview()
		_:
			exit_capsule_focus()


func _set_camera_mode(mode: CameraRigScript.Mode, focus_pos: Vector3 = Vector3.ZERO) -> void:
	_is_capsule_focused = (mode == CameraRigScript.Mode.CAPSULE_PILOT_FOCUS)
	if player != null and mode == CameraRigScript.Mode.FREE_ROAM:
		player.is_movement_locked = false
	camera_rig.set_mode(mode, focus_pos)
	_refresh_hud_status()


func cycle_right_station_state() -> void:
	if right_station == null:
		return
	var next_s: int = (int(right_station.get_station_state()) + 1) % 3
	right_station.set_station_state(next_s as StationNodeScript.StationState)
	_refresh_hud_status()


func set_pilot_accent_color(col: Color) -> void:
	config.pilot_accent_color = col
	apply_config_visuals()


func apply_config_visuals() -> void:
	if _world_env != null and _world_env.environment != null:
		_world_env.environment.glow_intensity = config.bloom_intensity
		_world_env.environment.glow_bloom = config.glow_bloom

	if _floor_mat != null:
		_floor_mat.set_shader_parameter("pilot_accent_color", config.pilot_accent_color)
		_floor_mat.set_shader_parameter("ink_strength", config.ink_strength)
		_floor_mat.set_shader_parameter("ink_expand", config.ink_expand)
		_floor_mat.set_shader_parameter("emissive_boost", config.emissive_boost)

	for wm: ShaderMaterial in _wall_mats:
		wm.set_shader_parameter("ink_strength", config.ink_strength)
		wm.set_shader_parameter("ink_expand", config.ink_expand)
		wm.set_shader_parameter("emissive_boost", config.emissive_boost)

	for pm: ShaderMaterial in _arch_prop_mats:
		pm.set_shader_parameter("pilot_accent_color", config.pilot_accent_color)
		pm.set_shader_parameter("crease_ink_strength", config.crease_ink_strength)
		pm.set_shader_parameter("emissive_boost", config.emissive_boost)
	for pm: ShaderMaterial in _hero_prop_mats:
		pm.set_shader_parameter("pilot_accent_color", config.pilot_accent_color)
		pm.set_shader_parameter("crease_ink_strength", config.crease_ink_strength)
		pm.set_shader_parameter("emissive_boost", config.emissive_boost)
	if _prop_outline_mat != null:
		_prop_outline_mat.set_shader_parameter("outline_width", config.outline_width)
		_prop_outline_mat.set_shader_parameter("reference_distance", config.outline_ref_distance)

	if _ring_mat != null:
		_ring_mat.set_shader_parameter("ring_accent_color", config.pilot_accent_color)
		_ring_mat.set_shader_parameter("energy_hdr_boost", maxf(config.emissive_boost, 1.85))

	for st: StationNodeScript in _all_stations():
		st.set_pilot_accent_color(config.pilot_accent_color)
		st.apply_shader_calibration(config.crease_ink_strength, config.outline_width, config.outline_ref_distance, config.emissive_boost)

	if hud != null:
		hud.sync_from_config(config)


func _save_config_resource() -> void:
	if config != null and not config.resource_path.is_empty():
		ResourceSaver.save(config, config.resource_path)


func _return_to_workbench() -> void:
	if ResourceLoader.exists(WORKBENCH_HUB_PATH) and get_tree() != null:
		get_tree().change_scene_to_file(WORKBENCH_HUB_PATH)


func _update_proximity_prompts() -> void:
	if player == null:
		return
	var is_free_roam: bool = (camera_rig.get_mode() == CameraRigScript.Mode.FREE_ROAM and not _is_ignition_previewing)
	var in_capsule: bool = _capsule_area != null and _capsule_area.overlaps_body(player)
	if _capsule_label != null:
		_capsule_label.visible = (in_capsule and is_free_roam)
		_capsule_label.modulate = Color(0.96, 0.84, 0.48, 1.0)
	var in_ign: bool = _ignition_area != null and _ignition_area.overlaps_body(player)
	if _ignition_label != null:
		_ignition_label.visible = (in_ign and is_free_roam)
		_ignition_label.modulate = Color(0.38, 0.96, 1.0, 1.0)
	for st: StationNodeScript in _all_stations():
		st.set_highlighted(st.is_player_inside(player))
		st.set_prompt_suppressed(not is_free_roam)


func _refresh_hud_status() -> void:
	if hud == null:
		return
	var mode_names: Array[String] = ["FREE_ROAM", "CAPSULE_FOCUS", "STATION_FOCUS", "IGNITION_LAUNCH"]
	var m_txt: String = mode_names[clampi(int(camera_rig.get_mode()), 0, mode_names.size() - 1)]
	var st_names: Array[String] = ["CALIBRATING", "NEWLY_UNLOCKED", "ONLINE"]
	var st_txt: String = st_names[clampi(int(right_station.get_station_state()), 0, 2)] if right_station != null else "N/A"
	var seed_v: int = cosmos_window.get_preview_seed() if cosmos_window != null else config.default_preview_seed
	hud.update_status(m_txt, st_txt, seed_v)


func _create_surface_material(
	base_path: String,
	uv_sc: Vector2,
	native_sz: Vector2,
	plate_tint: Color,
	chassis_tint: Color
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SurfaceShader
	var tex_alb: Texture2D = TextureLoader.load_texture_2d(base_path + ".png", true)
	var tex_id: Texture2D = TextureLoader.load_texture_2d(base_path + "_id_mask.png", false)
	var tex_ilm: Texture2D = TextureLoader.load_texture_2d(base_path + "_ilm_mask.png", true)
	var tex_sdf: Texture2D = TextureLoader.load_texture_2d(base_path + "_ink_sdf.png", false)

	var has_all: bool = (tex_alb != null and tex_id != null and tex_ilm != null and tex_sdf != null)
	mat.set_shader_parameter("has_maps", has_all)
	if has_all:
		mat.set_shader_parameter("albedo_tex", tex_alb)
		mat.set_shader_parameter("id_mask_tex", tex_id)
		mat.set_shader_parameter("ilm_mask_tex", tex_ilm)
		mat.set_shader_parameter("ink_sdf_tex", tex_sdf)
	mat.set_shader_parameter("uv_scale", uv_sc)
	mat.set_shader_parameter("tex_native_size", native_sz)
	mat.set_shader_parameter("wing_plate_tint", plate_tint)
	mat.set_shader_parameter("wing_chassis_tint", chassis_tint)
	mat.set_shader_parameter("pilot_accent_color", config.pilot_accent_color)
	return mat


func _create_prop_surface_materials(
	armor_col: Color = Color(0.46, 0.52, 0.66, 1.0),
	chassis_col: Color = Color(0.07, 0.085, 0.15, 1.0),
	ambient_f: float = 0.24
) -> Array[ShaderMaterial]:
	var mats: Array[ShaderMaterial] = []
	var base_colors: Array[Color] = [
		armor_col,
		chassis_col,
		config.pilot_accent_color,
	]
	for surf_idx: int in range(3):
		var mat := ShaderMaterial.new()
		mat.shader = PropShader
		mat.next_pass = _prop_outline_mat
		mat.set_shader_parameter("material_kind", surf_idx)
		mat.set_shader_parameter("base_color", base_colors[surf_idx])
		mat.set_shader_parameter("pilot_accent_color", config.pilot_accent_color)
		mat.set_shader_parameter("ambient_fill", ambient_f)
		mats.append(mat)
	return mats


func _add_static_box(parent: Node3D, node_name: String, pos: Vector3, size_v: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size_v
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)


func _add_static_cyl(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	body.add_child(cs)
	parent.add_child(body)


func _create_trigger_area(node_name: String, pos: Vector3, radius: float) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 2.0
	cs.shape = cyl
	area.add_child(cs)
	return area


func _create_prompt_label(node_name: String, pos: Vector3, text: String) -> Label3D:
	var lbl := Label3D.new()
	lbl.name = node_name
	lbl.position = pos
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 32
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0.03, 0.03, 0.08, 1.0)
	lbl.visible = false
	return lbl
