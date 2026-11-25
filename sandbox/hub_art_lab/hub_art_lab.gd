class_name HubArtLab
extends Node3D

## Estación Astral v2 Completa (Fase 3.5 — Pulido Calidad Producción).
## Orquestador modular que ensambla las 5 zonas en el diorama ~24x22m:
## 1. Cápsula Central (auto-alineación frontal 's' + zoom HD + colisión trasera)
## 2. Antesala de Loadout (4 Consolas con HubProgressionEvaluator + modales reales + toast diegético)
## 3. Anillo de Ignición Norte + Ventanal Cosmos sincronizado con RunLaunchRequest + ritual 3 tiempos
## 4. Ala Este Psycho-Pop Neón (HubEastWingController: Gacha 3D modo limpio, Tótem Telemetría, Lounge Mascotas)
## 5. Ala Oeste Santuario Oscuro (HubWestSanctuaryController: 5 Reliquias Cristalinas con maestría)

const ConfigScript = preload("res://sandbox/hub_art_lab/resources/hub_art_lab_config.gd")
const DEFAULT_CONFIG: ConfigScript = preload("res://sandbox/hub_art_lab/data/default_hub_art_lab_config.tres")
const ProgressionConfigScript = preload("res://scenes/ui/hub/resources/hub_progression_config.gd")
const DEFAULT_PROGRESSION_CONFIG: ProgressionConfigScript = preload("res://data/hub/default_hub_progression_config.tres")
const ProgressionEvaluatorScript = preload("res://scenes/ui/hub/components/hub_progression_evaluator.gd")
const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")

const ArchBuilder = preload("res://sandbox/hub_art_lab/meshes/hub_architecture_mesh_builder.gd")
const CapsuleBuilder = preload("res://sandbox/hub_art_lab/meshes/hub_capsule_mesh_builder.gd")
const TextureLoader = preload("res://sandbox/hub_art_lab/components/hub_texture_loader.gd")
const CosmosWindowScript = preload("res://sandbox/hub_art_lab/components/hub_cosmos_window_controller.gd")
const CameraRigScript = preload("res://sandbox/hub_art_lab/components/hub_lab_camera_rig.gd")
const StationNodeScript = preload("res://sandbox/hub_art_lab/components/hub_lab_station_node.gd")
const PlayerScript = preload("res://sandbox/hub_art_lab/components/hub_art_lab_player.gd")
const HUDScript = preload("res://sandbox/hub_art_lab/hub_art_lab_hud.gd")
const EastWingScript = preload("res://sandbox/hub_art_lab/components/hub_east_wing_controller.gd")
const WestSanctuaryScript = preload("res://sandbox/hub_art_lab/components/hub_west_sanctuary_controller.gd")
const ModalCoordScript = preload("res://sandbox/hub_art_lab/components/hub_antesala_modal_coordinator.gd")
const IgnitionCtrlScript = preload("res://sandbox/hub_art_lab/components/hub_ignition_ritual_controller.gd")
const AtmosphereCtrlScript = preload("res://sandbox/hub_art_lab/components/hub_atmosphere_controller.gd")
const CharacterDataScript = preload("res://data/characters/character_data.gd")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")

const SurfaceShader = preload("res://sandbox/hub_art_lab/shaders/hub_arcsys_surface_3d.gdshader")
const PropShader = preload("res://sandbox/hub_art_lab/shaders/hub_arcsys_prop_3d.gdshader")
const OutlineShader = preload("res://sandbox/hub_art_lab/shaders/hub_arcsys_outline_3d.gdshader")
const IgnitionRingShader = preload("res://sandbox/hub_art_lab/shaders/hub_ignition_ring_3d.gdshader")
const StationSkyShader = preload("res://sandbox/hub_art_lab/shaders/hub_station_sky_3d.gdshader")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")

const FLOOR_TEX_BASE: String = "res://sandbox/hub_art_lab/assets/surfaces/hub_floor_astral"
const WALL_TEX_BASE: String = "res://sandbox/hub_art_lab/assets/surfaces/hub_wall_astral"
const RING_TEX_PATH: String = "res://sandbox/hub_art_lab/assets/rings/hub_ignition_ring_packed.png"
const WORKBENCH_HUB_PATH: String = "res://sandbox/workbenches/workbench_hub.tscn"

@export var config: ConfigScript = DEFAULT_CONFIG
@export var progression_config: ProgressionConfigScript = DEFAULT_PROGRESSION_CONFIG

var camera: Camera3D = null
var player: PlayerScript = null
var cosmos_window: CosmosWindowScript = null
var camera_rig: CameraRigScript = CameraRigScript.new()
var progression_evaluator: ProgressionEvaluatorScript = ProgressionEvaluatorScript.new()
var active_launch_request: RunLaunchRequestScript = null

var left_station: StationNodeScript = null
var right_station: StationNodeScript = null
var left_far_station: StationNodeScript = null
var right_far_station: StationNodeScript = null

var east_wing: EastWingScript = null
var west_sanctuary: WestSanctuaryScript = null
var modal_coordinator: ModalCoordScript = null
var ignition_controller: IgnitionCtrlScript = null
var atmosphere_controller: AtmosphereCtrlScript = null
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
var _active_progression_preset: StringName = &"live"
var _shake_strength: float = 0.0
var _time_acc: float = 0.0
var _station_lighting_sample: CosmicLightingSampleScript = CosmicLightingSampleScript.new()


func _ready() -> void:
	if config == null:
		config = DEFAULT_CONFIG
	if progression_config == null:
		progression_config = DEFAULT_PROGRESSION_CONFIG
	if get_viewport() != null and DisplayServer.get_name() != "headless":
		get_viewport().msaa_2d = Viewport.MSAA_DISABLED
		get_viewport().msaa_3d = Viewport.MSAA_4X

	progression_evaluator.setup(progression_config)
	active_launch_request = RunLaunchRequestScript.create(config.default_preview_seed, RunLaunchRequestScript.SeedMode.AUTO)

	_build_environment()
	_build_architecture()
	_build_cosmos_window()
	_build_central_capsule()
	_build_antesala_stations()
	_build_ignition_ring()
	_build_player_and_camera()
	_build_phase3_wings_and_controllers()
	_build_hud()

	apply_progression_preset(&"live")
	apply_config_visuals()
	apply_launch_request(active_launch_request, false)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.028, 0.068, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.14, 0.17, 0.30, 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.22
	env.glow_intensity = config.bloom_intensity
	env.glow_bloom = config.glow_bloom
	env.fog_enabled = true
	env.fog_light_color = Color(0.055, 0.042, 0.115, 1.0)
	env.fog_density = 0.0050
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 1.08
	if DisplayServer.get_name() != "headless":
		env.ssao_enabled = true
		env.ssao_radius = 0.90
		env.ssao_intensity = 1.28
		env.ssil_enabled = true
		env.ssil_radius = 2.6
		env.ssil_intensity = 0.85
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.011
		env.volumetric_fog_albedo = Color(0.28, 0.24, 0.48, 1.0)
		env.volumetric_fog_emission = Color(0.075, 0.048, 0.145, 1.0)
		env.volumetric_fog_anisotropy = 0.55

	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnvironment"
	_world_env.environment = env
	add_child(_world_env)

	# Domo espacial 3D real rodeando toda la estación (cielo estrellado y nebulosa visibles hacia Sur/Este/Oeste)
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 95.0
	dome_mesh.height = 190.0
	dome_mesh.radial_segments = 32
	dome_mesh.rings = 16
	dome_mesh.flip_faces = true
	var dome_mat := ShaderMaterial.new()
	dome_mat.shader = StationSkyShader
	var dome_mi := MeshInstance3D.new()
	dome_mi.name = "StationCosmosDome"
	dome_mi.mesh = dome_mesh
	dome_mi.material_override = dome_mat
	dome_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome_mi)

	_dir_light = DirectionalLight3D.new()
	_dir_light.name = "DirectionalLight3D"
	_dir_light.rotation_degrees = Vector3(-46.0, -26.0, 0.0)
	_dir_light.light_color = Color(1.0, 0.97, 0.94, 1.0)
	_dir_light.light_energy = 1.04
	_dir_light.shadow_enabled = true
	_dir_light.shadow_bias = 0.03
	_dir_light.shadow_normal_bias = 1.10
	_dir_light.shadow_blur = 1.65
	_dir_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_dir_light.directional_shadow_max_distance = 52.0
	add_child(_dir_light)

	# Spotlight Hero sobre la Cápsula Central + Luz de Rebote del Cosmos Norte (con sombras y niebla volumétrica)
	var cap_spot := SpotLight3D.new()
	cap_spot.name = "CapsuleHeroSpotLight"
	cap_spot.position = Vector3(0.0, 5.4, 2.55)
	cap_spot.light_color = Color(1.0, 0.93, 0.84, 1.0)
	cap_spot.light_energy = 1.55
	cap_spot.light_volumetric_fog_energy = 2.6
	cap_spot.shadow_enabled = true
	cap_spot.shadow_bias = 0.04
	cap_spot.shadow_blur = 1.4
	cap_spot.spot_range = 10.5
	cap_spot.spot_angle = 36.0
	cap_spot.spot_attenuation = 1.2
	cap_spot.look_at_from_position(cap_spot.position, Vector3(0.0, 0.75, 1.6), Vector3.UP)
	add_child(cap_spot)

	var north_rim := SpotLight3D.new()
	north_rim.name = "NorthCosmosRimSpot"
	north_rim.position = Vector3(0.0, 4.4, -9.8)
	north_rim.light_color = Color(1.0, 0.36, 0.54, 1.0)
	north_rim.light_energy = 1.45
	north_rim.light_volumetric_fog_energy = 3.2
	north_rim.spot_range = 16.5
	north_rim.spot_angle = 54.0
	north_rim.look_at_from_position(north_rim.position, Vector3(0.0, 0.4, -2.0), Vector3.UP)
	add_child(north_rim)

	atmosphere_controller = AtmosphereCtrlScript.new() as AtmosphereCtrlScript
	atmosphere_controller.name = "HubAtmosphereController"
	add_child(atmosphere_controller)
	atmosphere_controller.setup(config.capsule_pos)

	for light_spec: Dictionary in [
		{"name": "WestAccentLight", "pos": Vector3(-15.8, 2.9, 0.8), "col": Color(0.74, 0.40, 1.0, 1.0), "energy": 1.35, "range": 14.5},
		{"name": "WestChamberFillLight", "pos": Vector3(-14.2, 2.6, 0.8), "col": Color(0.84, 0.78, 1.0, 1.0), "energy": 0.95, "range": 11.0},
		{"name": "EastAccentLight", "pos": Vector3(9.8, 2.7, 0.8), "col": Color(1.0, 0.18, 0.62, 1.0), "energy": 0.66, "range": 11.5},
		{"name": "NorthCosmosBounceLight", "pos": Vector3(0.0, 3.4, -8.5), "col": Color(0.28, 0.86, 0.96, 1.0), "energy": 0.58, "range": 13.5},
	]:
		var ol := OmniLight3D.new()
		ol.name = str(light_spec["name"])
		ol.position = light_spec["pos"] as Vector3
		ol.light_color = light_spec["col"] as Color
		ol.light_energy = float(light_spec["energy"])
		ol.omni_range = float(light_spec["range"])
		add_child(ol)


func _build_architecture() -> void:
	var arch_root := Node3D.new()
	arch_root.name = "StationArchitecture"
	add_child(arch_root)

	_floor_mat = _create_surface_material(
		FLOOR_TEX_BASE, config.floor_uv_scale, Vector2(1024.0, 1024.0),
		Color(0.20, 0.25, 0.38, 1.0), Color(0.11, 0.135, 0.22, 1.0)
	)
	_floor_mat.set_shader_parameter("enable_deck_zoning", true)
	_floor_mat.set_shader_parameter("tile_emissive_mult", 0.14)
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "DeckFloorMesh"
	floor_mi.mesh = ArchBuilder.build_floor_mesh(24.0, 22.0, 6.0)
	floor_mi.position = Vector3(0.0, 0.0, 0.5)
	floor_mi.material_override = _floor_mat
	arch_root.add_child(floor_mi)

	# Colisiones perimetrales + Portal abierto hacia Galería Oeste (-19.4 .. -12.0, Z = -2.4 .. +4.0)
	_add_static_box(arch_root, "FloorCollider", Vector3(0.0, -0.25, 0.5), Vector3(24.4, 0.5, 22.4))
	_add_static_box(arch_root, "WestNorthBoundary", Vector3(-11.65, 2.0, -6.45), Vector3(1.2, 4.0, 8.1))
	_add_static_box(arch_root, "WestSouthBoundary", Vector3(-11.65, 2.0, 7.75), Vector3(1.2, 4.0, 7.5))
	_add_static_box(arch_root, "WestChamberFloorCollider", Vector3(-15.9, -0.25, 0.8), Vector3(8.2, 0.5, 10.2))
	_add_static_box(arch_root, "WestChamberBackBoundary", Vector3(-19.6, 2.0, 0.8), Vector3(0.9, 4.0, 10.5))
	_add_static_box(arch_root, "WestChamberNorthBoundary", Vector3(-15.9, 2.0, -4.3), Vector3(8.2, 4.0, 0.8))
	_add_static_box(arch_root, "WestChamberSouthBoundary", Vector3(-15.9, 2.0, 5.9), Vector3(8.2, 4.0, 0.8))
	_add_static_box(arch_root, "EastBoundary", Vector3(11.65, 2.0, 0.5), Vector3(1.2, 4.0, 23.0))
	_add_static_box(arch_root, "NorthBoundary", Vector3(0.0, 2.0, -10.15), Vector3(25.0, 4.0, 1.2))
	_add_static_box(arch_root, "SouthBoundary", Vector3(0.0, 2.0, 11.25), Vector3(25.0, 4.0, 1.2))
	_add_static_box(arch_root, "NWCornerCollider", Vector3(-10.8, 2.0, -9.7), Vector3(1.6, 4.0, 1.4))
	_add_static_box(arch_root, "NECornerCollider", Vector3(10.8, 2.0, -9.7), Vector3(1.6, 4.0, 1.4))

	var wall_mesh: ArrayMesh = ArchBuilder.build_side_wall_mesh(22.0, 3.8, 4.0)
	var west_mat: ShaderMaterial = _create_surface_material(
		WALL_TEX_BASE, config.wall_uv_scale, Vector2(1024.0, 572.0),
		Color(0.28, 0.30, 0.46, 1.0), Color(0.08, 0.095, 0.17, 1.0)
	)
	west_mat.set_shader_parameter("pilot_accent_color", Color(0.74, 0.36, 1.0, 1.0))
	west_mat.set_shader_parameter("ambient_fill", 0.38)
	west_mat.set_shader_parameter("tile_emissive_mult", 0.72)
	_wall_mats.append(west_mat)

	var west_wall_n := MeshInstance3D.new()
	west_wall_n.name = "WestSanctuaryWallNorth"
	west_wall_n.mesh = ArchBuilder.build_side_wall_mesh(8.1, 3.8, 4.0)
	west_wall_n.position = Vector3(-12.0, 0.0, -6.45)
	west_wall_n.material_override = west_mat
	arch_root.add_child(west_wall_n)

	var west_wall_s := MeshInstance3D.new()
	west_wall_s.name = "WestSanctuaryWallSouth"
	west_wall_s.mesh = ArchBuilder.build_side_wall_mesh(7.5, 3.8, 4.0)
	west_wall_s.position = Vector3(-12.0, 0.0, 7.75)
	west_wall_s.material_override = west_mat
	arch_root.add_child(west_wall_s)

	var west_floor := MeshInstance3D.new()
	west_floor.name = "WestChamberFloorMesh"
	west_floor.mesh = ArchBuilder.build_west_chamber_floor_mesh()
	west_floor.material_override = _floor_mat
	arch_root.add_child(west_floor)

	var east_mat: ShaderMaterial = _create_surface_material(
		WALL_TEX_BASE, config.wall_uv_scale, Vector2(1024.0, 572.0),
		Color(0.26, 0.32, 0.48, 1.0), Color(0.08, 0.095, 0.17, 1.0)
	)
	east_mat.set_shader_parameter("pilot_accent_color", Color(1.0, 0.16, 0.62, 1.0))
	east_mat.set_shader_parameter("ambient_fill", 0.38)
	east_mat.set_shader_parameter("tile_emissive_mult", 0.76)
	_wall_mats.append(east_mat)

	var east_wall := MeshInstance3D.new()
	east_wall.name = "EastPsychoPopWall"
	east_wall.mesh = wall_mesh
	east_wall.position = Vector3(12.0, 0.0, 0.5)
	east_wall.rotation = Vector3(0.0, PI, 0.0)
	east_wall.material_override = east_mat
	arch_root.add_child(east_wall)

	_prop_outline_mat = ShaderMaterial.new()
	_prop_outline_mat.shader = OutlineShader
	_arch_prop_mats = _create_prop_surface_materials(Color(0.28, 0.33, 0.46, 1.0), Color(0.06, 0.075, 0.14, 1.0), 0.20)
	_hero_prop_mats = _create_prop_surface_materials(Color(0.46, 0.52, 0.66, 1.0), Color(0.07, 0.085, 0.15, 1.0), 0.24)

	var ign_socket_pos := Vector3(config.ignition_ring_pos.x, 0.0, config.ignition_ring_pos.z)
	for piece_spec: Dictionary in [
		{"name": "StructuralRibs", "mesh": ArchBuilder.build_structural_ribs_mesh(), "shadow": true, "pos": Vector3.ZERO},
		{"name": "NorthWindowFrame", "mesh": ArchBuilder.build_north_window_frame_mesh(), "shadow": true, "pos": Vector3.ZERO},
		{"name": "SouthLowRailing", "mesh": ArchBuilder.build_south_railing_mesh(), "shadow": false, "pos": Vector3.ZERO},
		{"name": "SouthSuperstructure", "mesh": ArchBuilder.build_south_superstructure_mesh(), "shadow": true, "pos": Vector3.ZERO},
		{"name": "WestSanctuaryChamber", "mesh": ArchBuilder.build_west_sanctuary_chamber_mesh(), "shadow": true, "pos": Vector3.ZERO},
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
	cosmos_window.setup(config, window_mesh, active_launch_request.cosmos_seed if active_launch_request != null else -1)
	if _floor_mat != null and cosmos_window.get_subviewport() != null:
		_floor_mat.set_shader_parameter("cosmos_reflection_tex", cosmos_window.get_subviewport().get_texture())
		_floor_mat.set_shader_parameter("has_cosmos_reflection", true)
		_floor_mat.set_shader_parameter("cosmos_reflection_strength", 0.42)


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
	_capsule_halo_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for surf_idx: int in range(3):
		_capsule_halo_mesh.set_surface_override_material(surf_idx, _hero_prop_mats[surf_idx])
	cap_root.add_child(_capsule_halo_mesh)

	_add_static_cyl(cap_root, "CapsuleStepCollider", Vector3(0.0, 0.08, 0.0), 1.92, 0.16)
	_add_static_box(cap_root, "CapsuleRearArchCollider", Vector3(0.0, 0.9, -1.16), Vector3(3.35, 1.8, 0.48))
	_capsule_area = _create_trigger_area("CapsuleInteractArea", Vector3(0.0, 0.9, 0.0), 1.95)
	cap_root.add_child(_capsule_area)

	_capsule_label = _create_prompt_label("CapsulePromptLabel", Vector3(0.0, 2.72, 0.0), "[E] CÁPSULA DE PILOTO")
	cap_root.add_child(_capsule_label)


func _build_antesala_stations() -> void:
	left_station = _spawn_station(
		"LeftSkinsConsole", config.console_left_pos, 24.0,
		&"skins_mirror", "Espejo de Skins", "Consigue tu primera skin en el Invocador Gacha",
		StationNodeScript.StationState.CALIBRATING,
		Color(0.98, 0.36, 0.66, 1.0)
	)
	left_far_station = _spawn_station(
		"LeftTalentsConsole", config.console_left_far_pos, 20.0,
		&"talents_nexus", "Nexo de Talentos", "Recolecta Biomasa o completa tu 1.ª incursión",
		StationNodeScript.StationState.CALIBRATING,
		Color(0.14, 0.92, 1.0, 1.0)
	)
	right_station = _spawn_station(
		"RightCompanionsConsole", config.console_right_pos, -24.0,
		&"companions_projector", "Proyector de Compañía", "Desbloquea una Mascota o Navegante",
		StationNodeScript.StationState.CALIBRATING,
		Color(0.24, 0.96, 0.72, 1.0)
	)
	right_far_station = _spawn_station(
		"RightTacticalConsole", config.console_right_far_pos, -20.0,
		&"tactical_console", "Consola Táctica", "Completa 1 incursión para calibrar Banlist",
		StationNodeScript.StationState.CALIBRATING,
		Color(1.0, 0.76, 0.24, 1.0)
	)


func _spawn_station(
	node_name: String, pos: Vector3, yaw_deg: float,
	station_id: StringName, title: String, hint: String, init_state: StationNodeScript.StationState,
	theme_accent: Color = Color(-1.0, 0.0, 0.0, 1.0)
) -> StationNodeScript:
	var st := StationNodeScript.new() as StationNodeScript
	st.name = node_name
	st.station_id = station_id
	st.display_title = title
	st.locked_hint_text = hint
	st.position = pos
	st.rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	add_child(st)
	var eff_accent: Color = theme_accent if theme_accent.r >= 0.0 else config.pilot_accent_color
	st.setup(station_id, title, hint, init_state, eff_accent, config.calibrating_tint)
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
	if player.rig_avatar != null:
		player.rig_avatar.set_camera_pitch_alignment(camera.rotation_degrees.x, true)


func _build_phase3_wings_and_controllers() -> void:
	east_wing = EastWingScript.new() as EastWingScript
	east_wing.name = "HubEastWingController"
	add_child(east_wing)
	east_wing.setup(config, player)
	east_wing.gacha_focus_requested.connect(_on_gacha_focus_requested)
	east_wing.gacha_focus_exited.connect(_on_gacha_focus_exited)
	east_wing.telemetry_requested.connect(_on_telemetry_requested)
	east_wing.camera_shake_requested.connect(func(amt: float) -> void: _shake_strength = maxf(_shake_strength, amt))
	east_wing.bloom_boost_requested.connect(_on_bloom_boost_requested)
	east_wing.skin_equipped_live.connect(_on_gacha_skin_equipped_live)

	west_sanctuary = WestSanctuaryScript.new() as WestSanctuaryScript
	west_sanctuary.name = "HubWestSanctuaryController"
	add_child(west_sanctuary)
	west_sanctuary.setup(config)
	west_sanctuary.relic_interacted.connect(_on_west_relic_interacted)

	modal_coordinator = ModalCoordScript.new() as ModalCoordScript
	modal_coordinator.name = "HubAntesalaModalCoordinator"
	add_child(modal_coordinator)
	modal_coordinator.setup(progression_evaluator, player.rig_avatar if player != null else null, active_launch_request)
	modal_coordinator.modal_opened.connect(_on_modal_opened)
	modal_coordinator.modal_closed.connect(_on_modal_closed)
	modal_coordinator.pilot_changed.connect(_on_pilot_changed)
	modal_coordinator.companions_updated.connect(_on_companions_updated)
	modal_coordinator.trophy_upgraded_live.connect(func(_tid: StringName, _lvl: int) -> void:
		if west_sanctuary != null:
			west_sanctuary.refresh_all_relics()
	)
	modal_coordinator.tactical_seed_changed.connect(func(req: RunLaunchRequestScript, flash: bool) -> void:
		apply_launch_request(req, flash)
	)

	ignition_controller = IgnitionCtrlScript.new() as IgnitionCtrlScript
	ignition_controller.name = "HubIgnitionRitualController"
	add_child(ignition_controller)
	ignition_controller.setup(config, player, _ring_mat)
	ignition_controller.ritual_started.connect(func(focus_pos: Vector3) -> void:
		_is_capsule_focused = false
		if hud != null:
			hud.set_clean_hud_visible(false)
		_set_camera_mode(CameraRigScript.Mode.IGNITION_LAUNCH, focus_pos)
	)
	ignition_controller.ritual_progress.connect(func(_charge: float, push_in_t: float) -> void:
		camera_rig.set_ignition_push_in(push_in_t)
	)
	ignition_controller.bloom_swell_requested.connect(_on_bloom_boost_requested)
	ignition_controller.camera_shake_requested.connect(func(amt: float) -> void: _shake_strength = maxf(_shake_strength, amt))
	ignition_controller.warp_retune_requested.connect(func() -> void:
		if cosmos_window != null and active_launch_request != null:
			cosmos_window.set_preview_seed(active_launch_request.cosmos_seed, true)
	)
	ignition_controller.ritual_completed.connect(func(_req: RunLaunchRequestScript, launched_combat: bool) -> void:
		if not launched_combat:
			if hud != null:
				hud.set_clean_hud_visible(true)
			_set_camera_mode(CameraRigScript.Mode.FREE_ROAM)
		_refresh_hud_status()
	)


func _build_hud() -> void:
	hud = HUDScript.new() as HUDScript
	hud.name = "HubArtLabHUD"
	add_child(hud)
	hud.setup(config)
	hud.camera_mode_requested.connect(_on_hud_camera_mode_requested)
	hud.accent_color_selected.connect(set_pilot_accent_color)
	hud.station_state_cycled.connect(cycle_right_station_state)
	hud.progression_preset_selected.connect(apply_progression_preset)
	hud.relic_mastery_override_selected.connect(set_west_mastery_override)
	hud.dry_run_toggled.connect(func(is_dry: bool) -> void:
		if ignition_controller != null:
			ignition_controller.dry_run_sandbox_launch = is_dry
	)
	hud.seed_apply_requested.connect(func(s: int) -> void:
		apply_launch_request(RunLaunchRequestScript.create(s, RunLaunchRequestScript.SeedMode.CUSTOM), true)
	)
	hud.seed_random_requested.connect(func() -> void:
		apply_launch_request(RunLaunchRequestScript.create_random_auto(), true)
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

	if _shake_strength > 0.001:
		_shake_strength = maxf(0.0, _shake_strength - delta * 2.4)
		camera_rig.set_shake_offset(Vector3(
			sin(_time_acc * 58.0) * _shake_strength,
			cos(_time_acc * 49.0) * _shake_strength * 0.7,
			0.0
		))
	else:
		camera_rig.set_shake_offset(Vector3.ZERO)

	if player != null and camera != null:
		camera_rig.update(camera, player.global_position, delta, config, false)
		var zoom_t: float = camera_rig.get_effective_zoom_t()
		var fp_fade: float = 1.0 - smoothstep(0.74, 0.88, zoom_t)
		player.set_visibility_fade(fp_fade)
		if player.rig_avatar != null:
			player.rig_avatar.set_camera_pitch_alignment(camera.rotation_degrees.x, false)
			player.rig_avatar.rotation_degrees.y = lerpf(player.rig_avatar.rotation_degrees.y, camera.rotation_degrees.y, clampf(10.0 * delta, 0.0, 1.0))
			_update_player_station_lighting(delta)
	_update_proximity_prompts()


func _update_player_station_lighting(delta: float) -> void:
	if player == null or player.rig_avatar == null or _station_lighting_sample == null:
		return
	var p: Vector3 = player.global_position
	var north_w: float = clampf((-p.z - 2.5) / 6.5, 0.0, 1.0)
	var east_w: float = clampf((p.x - 4.0) / 5.5, 0.0, 1.0)
	var west_w: float = clampf((-p.x - 5.0) / 7.5, 0.0, 1.0)
	var capsule_w: float = clampf(1.0 - Vector2(p.x, p.z - 1.6).length() / 3.4, 0.0, 1.0)

	var key_col: Color = Color(1.02, 0.99, 0.96, 1.0)
	key_col = key_col.lerp(Color(1.05, 0.72, 0.78, 1.0), north_w * 0.45)
	key_col = key_col.lerp(Color(0.84, 0.72, 1.08, 1.0), west_w * 0.55)
	key_col = key_col.lerp(Color(1.04, 0.78, 0.92, 1.0), east_w * 0.42)
	key_col = key_col.lerp(Color(1.08, 0.98, 0.84, 1.0), capsule_w * 0.40)

	var rim_col: Color = Color(0.58, 0.86, 1.0, 1.0)
	rim_col = rim_col.lerp(Color(1.0, 0.28, 0.52, 1.0), north_w * 0.70)
	rim_col = rim_col.lerp(Color(0.75, 0.22, 1.0, 1.0), west_w * 0.72)
	rim_col = rim_col.lerp(Color(1.0, 0.20, 0.68, 1.0), east_w * 0.65)
	rim_col = rim_col.lerp(Color(1.0, 0.86, 0.46, 1.0), capsule_w * 0.52)

	var shd_col: Color = Color(0.16, 0.17, 0.34, 1.0).lerp(Color(0.24, 0.12, 0.32, 1.0), maxf(north_w, west_w) * 0.55)

	_station_lighting_sample.light_dir_2d = Vector2(0.45, -0.89).normalized()
	_station_lighting_sample.light_dir_3d = Vector3(0.45, 0.89, 0.55).normalized()
	_station_lighting_sample.key_light_tint = key_col
	_station_lighting_sample.rim_key_color = rim_col
	_station_lighting_sample.shadow_tint = shd_col
	_station_lighting_sample.ao_tint = Color(0.08, 0.07, 0.18, 1.0)
	_station_lighting_sample.star_proximity = maxf(north_w, capsule_w * 0.6)
	_station_lighting_sample.star_tint_weight = 0.48
	_station_lighting_sample.rim_tint_weight = 0.58 + 0.28 * maxf(north_w, maxf(west_w, east_w))
	_station_lighting_sample.biome_shadow_weight = 0.36
	_station_lighting_sample.eclipse_factor = west_w * 0.18
	_station_lighting_sample.visibility_floor = 0.72
	_station_lighting_sample.emissive_boost_mult = 1.05 + north_w * 0.12
	player.rig_avatar.apply_station_lighting(_station_lighting_sample, delta)


func _unhandled_input(event: InputEvent) -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return

	var is_free_roam: bool = (
		camera_rig.get_mode() == CameraRigScript.Mode.FREE_ROAM
		and not _is_ritual_active()
		and (east_wing == null or not east_wing.is_gacha_open())
		and (modal_coordinator == null or not modal_coordinator.is_any_modal_open())
	)

	var mb_ev := event as InputEventMouseButton
	if mb_ev != null and mb_ev.pressed and is_free_roam:
		if mb_ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_rig.adjust_scroll_zoom(0.11)
			return
		if mb_ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_rig.adjust_scroll_zoom(-0.11)
			return

	var mm_ev := event as InputEventMouseMotion
	if mm_ev != null and is_free_roam and camera_rig.is_first_person() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_rig.apply_first_person_look(-mm_ev.relative.x * 0.16, -mm_ev.relative.y * 0.12)
		return

	if event.is_action_pressed("interact"):
		_handle_interact_press()
		return

	var key_ev := event as InputEventKey
	if key_ev == null or not key_ev.pressed or key_ev.echo:
		return
	match key_ev.keycode:
		KEY_H, KEY_F2:
			if hud != null:
				hud.toggle_visible()
		KEY_E, KEY_SPACE:
			_handle_interact_press()
		KEY_ESCAPE:
			if east_wing != null and east_wing.is_gacha_open():
				east_wing.close_gacha_station()
			elif ignition_controller != null and ignition_controller.is_active_run_prompt_open():
				ignition_controller.cancel_active_run_prompt()
			elif modal_coordinator != null and modal_coordinator.is_any_modal_open():
				modal_coordinator.close_active_modal()
			elif _is_capsule_focused:
				exit_capsule_focus()
			elif camera_rig.get_mode() != CameraRigScript.Mode.FREE_ROAM and not _is_ritual_active():
				_set_camera_mode(CameraRigScript.Mode.FREE_ROAM)
		KEY_1:
			_on_hud_camera_mode_requested(CameraRigScript.Mode.FREE_ROAM)
		KEY_2:
			_on_hud_camera_mode_requested(CameraRigScript.Mode.CAPSULE_PILOT_FOCUS)
		KEY_3:
			_on_hud_camera_mode_requested(CameraRigScript.Mode.SKINS_MIRROR_FOCUS)
		KEY_4:
			_on_hud_camera_mode_requested(CameraRigScript.Mode.STATION_FOCUS)
		KEY_5:
			_on_hud_camera_mode_requested(CameraRigScript.Mode.GACHA_SUMMON_CINEMATIC)
		KEY_6:
			_on_hud_camera_mode_requested(CameraRigScript.Mode.TROPHY_FOCUS)
		KEY_7:
			_on_hud_camera_mode_requested(CameraRigScript.Mode.IGNITION_LAUNCH)


func _is_ritual_active() -> bool:
	return ignition_controller != null and ignition_controller.is_ritual_active()


func _handle_interact_press() -> void:
	if _is_ritual_active():
		return
	if east_wing != null and east_wing.is_gacha_open():
		return
	if _is_capsule_focused:
		exit_capsule_focus()
		return
	if modal_coordinator != null and modal_coordinator.is_any_modal_open():
		return
	if player == null:
		return
	if _capsule_area != null and _capsule_area.overlaps_body(player):
		trigger_capsule_focus(true)
		return
	if _ignition_area != null and _ignition_area.overlaps_body(player):
		if ignition_controller != null:
			ignition_controller.request_ignition(active_launch_request, false)
		return
	for st: StationNodeScript in _all_stations():
		if st.is_player_inside(player):
			st.trigger_interaction()
			return
	if east_wing != null and east_wing.try_interact(player):
		return
	if west_sanctuary != null:
		west_sanctuary.try_interact(player)


func trigger_capsule_focus(open_pilot_panel: bool = false) -> void:
	if _is_ritual_active() or player == null:
		return
	_is_capsule_focused = true
	player.is_movement_locked = true
	player.is_pose_override_active = true
	player.global_position = config.capsule_pos + Vector3(0.0, 0.10, 0.0)
	player.face_front_idle(true)
	if hud != null:
		hud.set_clean_hud_visible(false)
	if open_pilot_panel and modal_coordinator != null:
		modal_coordinator.open_pilot_capsule(config.capsule_pos)
	else:
		camera_rig.set_mode(CameraRigScript.Mode.CAPSULE_PILOT_FOCUS, config.capsule_pos)
		_refresh_hud_status()


func exit_capsule_focus() -> void:
	_is_capsule_focused = false
	if modal_coordinator != null and modal_coordinator.is_any_modal_open():
		modal_coordinator.close_active_modal()
	if player != null:
		player.is_movement_locked = false
		player.is_pose_override_active = false
	if hud != null:
		hud.set_clean_hud_visible(true)
	camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
	_refresh_hud_status()


func trigger_ignition_preview() -> void:
	if ignition_controller != null:
		ignition_controller.request_ignition(active_launch_request, true)


func _finish_ignition_preview() -> void:
	if ignition_controller != null and ignition_controller.is_ritual_active():
		ignition_controller._complete_ritual()
	else:
		if _ring_mat != null:
			_ring_mat.set_shader_parameter("ignition_charge", 0.0)
		if player != null:
			player.is_movement_locked = false
			if player.rig_avatar != null:
				player.rig_avatar.set_showcase_lift_offset(0.0)
				player.rig_avatar.set_loadout_showcase_enabled(false, false)
		if hud != null:
			hud.set_clean_hud_visible(true)
		camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
		_refresh_hud_status()


func open_station_by_id(station_id: StringName) -> void:
	for st: StationNodeScript in _all_stations():
		if st.station_id == station_id:
			_on_station_interacted(st)
			return


func _on_station_interacted(station_node: Node3D) -> void:
	var station: StationNodeScript = station_node as StationNodeScript
	if station == null:
		return
	if station.get_station_state() == StationNodeScript.StationState.CALIBRATING:
		if hud != null:
			var hint_str: String = progression_evaluator.get_locked_hint(station.station_id)
			hud.show_toast("ESTACIÓN EN CALIBRACIÓN // %s" % station.display_title.to_upper(), hint_str, Color(0.95, 0.68, 0.22, 1.0))
		return

	if station.get_station_state() == StationNodeScript.StationState.NEWLY_UNLOCKED:
		if station.station_id == &"tactical_console":
			progression_evaluator.acknowledge_tactical_console()
		else:
			progression_evaluator.acknowledge_module(station.station_id)
		station.set_station_state(StationNodeScript.StationState.ONLINE)

	if player != null:
		player.is_movement_locked = true
		player.face_front_idle(true)

	if modal_coordinator == null:
		_set_camera_mode(CameraRigScript.Mode.STATION_FOCUS, station.global_position)
		return

	match station.station_id:
		&"skins_mirror":
			if player != null:
				player.is_pose_override_active = true
				player.global_position = station.global_position + Vector3(0.0, 0.05, 1.48)
				player.face_front_idle(true)
				modal_coordinator.open_skins_mirror(player.global_position)
			else:
				modal_coordinator.open_skins_mirror(station.global_position)
		&"talents_nexus":
			if player != null:
				player.is_pose_override_active = true
				var se_dir := Vector2(0.45, 0.89).normalized()
				player.set_pose_override(se_dir, 0.0, se_dir, true)
				modal_coordinator.open_talents_nexus(player.global_position + Vector3(0.0, 0.18, 0.0))
			else:
				modal_coordinator.open_talents_nexus(station.global_position)
		&"companions_projector":
			modal_coordinator.open_companions_projector(station.global_position)
		&"tactical_console":
			modal_coordinator.open_tactical_console(station.global_position)
		_:
			_set_camera_mode(CameraRigScript.Mode.STATION_FOCUS, station.global_position)


func _on_modal_opened(cam_mode: int, focus_pos: Vector3) -> void:
	if player != null:
		player.is_movement_locked = true
	if hud != null:
		hud.set_clean_hud_visible(false)
	_set_camera_mode(cam_mode as CameraRigScript.Mode, focus_pos)


func _on_modal_closed() -> void:
	_is_capsule_focused = false
	if player != null:
		player.is_movement_locked = false
		player.is_pose_override_active = false
	if hud != null:
		hud.set_clean_hud_visible(true)
	_set_camera_mode(CameraRigScript.Mode.FREE_ROAM)


func _on_pilot_changed(_char_id: StringName, accent_col: Color) -> void:
	set_pilot_accent_color(accent_col)
	_refresh_hud_status()


func _on_companions_updated() -> void:
	if east_wing != null:
		east_wing.refresh_pets(player)
	if modal_coordinator != null and right_station != null:
		modal_coordinator.refresh_navigator_hologram(right_station, right_station.get_station_state() != StationNodeScript.StationState.CALIBRATING)


func _on_gacha_focus_requested(focus_pos: Vector3) -> void:
	if player != null:
		player.is_movement_locked = true
	if hud != null:
		hud.set_clean_hud_visible(false)
	_set_camera_mode(CameraRigScript.Mode.GACHA_SUMMON_CINEMATIC, focus_pos)


func _on_gacha_focus_exited() -> void:
	if player != null:
		player.is_movement_locked = false
	if hud != null:
		hud.set_clean_hud_visible(true)
	_set_camera_mode(CameraRigScript.Mode.FREE_ROAM)


func _on_telemetry_requested(focus_pos: Vector3) -> void:
	if modal_coordinator != null:
		modal_coordinator.open_telemetry_totem(focus_pos)


func _on_west_relic_interacted(trophy_id: StringName, focus_pos: Vector3) -> void:
	if modal_coordinator != null:
		modal_coordinator.open_trophy_details(trophy_id, focus_pos)


func _on_gacha_skin_equipped_live(equip_res: Dictionary) -> void:
	if player == null or player.rig_avatar == null:
		return
	var preset: PilotSkinPreset = equip_res.get("preset", null) as PilotSkinPreset
	if preset == null:
		return
	var cat: String = str(equip_res.get("category", "pilot"))
	var stars: int = int(equip_res.get("star_level", 1))
	if cat == "wings" or cat == "ship":
		player.rig_avatar.apply_wings_skin_preset(preset, stars)
	elif cat == "weapon":
		player.rig_avatar.apply_weapon_skin_preset(preset, stars)
	else:
		player.rig_avatar.apply_skin_preset(preset, stars)


func _on_bloom_boost_requested(bloom_val: float) -> void:
	if _world_env != null and _world_env.environment != null:
		_world_env.environment.glow_intensity = bloom_val


func _on_hud_camera_mode_requested(mode_idx: int) -> void:
	match mode_idx:
		CameraRigScript.Mode.CAPSULE_PILOT_FOCUS:
			trigger_capsule_focus(false)
		CameraRigScript.Mode.SKINS_MIRROR_FOCUS:
			if left_station != null and player != null:
				player.global_position = left_station.global_position + Vector3(0.0, 0.05, 1.48)
				player.face_front_idle(true)
				_set_camera_mode(CameraRigScript.Mode.SKINS_MIRROR_FOCUS, player.global_position)
		CameraRigScript.Mode.STATION_FOCUS:
			if right_far_station != null:
				_set_camera_mode(CameraRigScript.Mode.STATION_FOCUS, right_far_station.global_position)
		CameraRigScript.Mode.GACHA_SUMMON_CINEMATIC:
			if east_wing != null and east_wing.summoner != null:
				_set_camera_mode(CameraRigScript.Mode.GACHA_SUMMON_CINEMATIC, east_wing.summoner.global_position)
		CameraRigScript.Mode.TROPHY_FOCUS:
			if west_sanctuary != null:
				_set_camera_mode(CameraRigScript.Mode.TROPHY_FOCUS, west_sanctuary.get_relic_world_pos(&"trophy_cryo_core"))
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


func apply_progression_preset(preset_id: StringName) -> void:
	_active_progression_preset = preset_id
	var snap: Dictionary = (
		ProgressionEvaluatorScript.build_live_snapshot(false)
		if preset_id == &"live"
		else ProgressionEvaluatorScript.build_preset_snapshot(preset_id)
	)
	progression_evaluator.evaluate_snapshot(snap)
	if preset_id == &"all_online" or preset_id == &"debug_unlock":
		progression_evaluator.acknowledge_all_unlocked()
	_sync_stations_from_evaluator()
	if modal_coordinator != null:
		modal_coordinator.set_evaluator(progression_evaluator)
		if right_station != null:
			modal_coordinator.refresh_navigator_hologram(right_station, right_station.get_station_state() != StationNodeScript.StationState.CALIBRATING)
	_refresh_hud_status()


func _sync_stations_from_evaluator() -> void:
	for st: StationNodeScript in _all_stations():
		var eval_state: int = (
			int(progression_evaluator.get_tactical_console_state())
			if st.station_id == &"tactical_console"
			else int(progression_evaluator.get_module_state(st.station_id))
		)
		st.set_station_state(eval_state as StationNodeScript.StationState)


func apply_launch_request(req: RunLaunchRequestScript, trigger_flash: bool = true) -> void:
	if req == null:
		return
	active_launch_request = req.duplicate_request()
	if cosmos_window != null:
		cosmos_window.set_preview_seed(active_launch_request.cosmos_seed, trigger_flash)
	if modal_coordinator != null:
		modal_coordinator.set_active_request(active_launch_request)
	_refresh_hud_status()


func set_west_mastery_override(level: int) -> void:
	if west_sanctuary != null:
		west_sanctuary.set_mastery_override(level)


func cycle_right_station_state() -> void:
	if right_station == null:
		return
	var next_s: int = (int(right_station.get_station_state()) + 1) % 3
	right_station.set_station_state(next_s as StationNodeScript.StationState)
	if modal_coordinator != null:
		modal_coordinator.refresh_navigator_hologram(right_station, right_station.get_station_state() != StationNodeScript.StationState.CALIBRATING)
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
		st.apply_shader_calibration(config.crease_ink_strength, config.outline_width, config.outline_ref_distance, config.emissive_boost)

	if east_wing != null:
		east_wing.apply_shader_calibration(config.crease_ink_strength, config.outline_width, config.outline_ref_distance, config.emissive_boost)
	if west_sanctuary != null:
		west_sanctuary.apply_shader_calibration(config.crease_ink_strength, config.outline_width, config.outline_ref_distance, config.emissive_boost)

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
	var is_free_roam: bool = (
		camera_rig.get_mode() == CameraRigScript.Mode.FREE_ROAM
		and not _is_ritual_active()
		and (east_wing == null or not east_wing.is_gacha_open())
		and (modal_coordinator == null or not modal_coordinator.is_any_modal_open())
	)

	var pill_text: String = ""
	var pill_col: Color = Color(0.95, 0.80, 0.34, 1.0)

	var in_capsule: bool = _capsule_area != null and _capsule_area.overlaps_body(player)
	if _capsule_label != null:
		_capsule_label.visible = (in_capsule and is_free_roam)
		_capsule_label.modulate = Color(0.96, 0.84, 0.48, 1.0)
	if in_capsule and is_free_roam:
		pill_text = "[E] Cápsula de Piloto (Cambiar Heroína)"
		pill_col = Color(0.96, 0.84, 0.48, 1.0)

	var in_ign: bool = _ignition_area != null and _ignition_area.overlaps_body(player)
	if _ignition_label != null:
		_ignition_label.visible = (in_ign and is_free_roam)
		_ignition_label.modulate = Color(0.38, 0.96, 1.0, 1.0)
	if in_ign and is_free_roam and pill_text.is_empty():
		pill_text = "[E] Anillo Norte — Saltar al Cosmos"
		pill_col = Color(0.38, 0.96, 1.0, 1.0)

	for st: StationNodeScript in _all_stations():
		var inside: bool = st.is_player_inside(player)
		st.set_highlighted(inside)
		st.set_prompt_suppressed(not is_free_roam)
		if inside and is_free_roam and pill_text.is_empty():
			if st.get_station_state() == StationNodeScript.StationState.CALIBRATING:
				pill_text = "🔒 %s — %s" % [st.display_title, st.locked_hint_text]
				pill_col = Color(0.95, 0.68, 0.24, 1.0)
			else:
				pill_text = "[E] Abrir %s" % st.display_title
				pill_col = Color(0.38, 1.0, 0.82, 1.0) if st.get_station_state() == StationNodeScript.StationState.NEWLY_UNLOCKED else Color(0.95, 0.80, 0.34, 1.0)

	if east_wing != null:
		east_wing.update_proximity(player, is_free_roam)
	if west_sanctuary != null:
		west_sanctuary.update_proximity(player, is_free_roam)
	if hud != null:
		hud.set_interaction_prompt(pill_text, pill_col, is_free_roam and not pill_text.is_empty())


func _refresh_hud_status() -> void:
	if hud == null:
		return
	var mode_names: Array[String] = ["FREE_ROAM", "CAPSULE", "STATION", "IGNITION", "SKINS", "GACHA", "RELIC"]
	var m_txt: String = mode_names[clampi(int(camera_rig.get_mode()), 0, mode_names.size() - 1)]
	var st_names: Array[String] = ["CALIBRATING", "NEWLY_UNLOCKED", "ONLINE"]
	var st_txt: String = st_names[clampi(int(right_station.get_station_state()), 0, 2)] if right_station != null else "N/A"
	var seed_v: int = cosmos_window.get_preview_seed() if cosmos_window != null else config.default_preview_seed
	var coord_code: String = active_launch_request.coordinate_code if active_launch_request != null else RunLaunchRequestScript.encode_coordinate_code(seed_v)
	var badge: String = active_launch_request.get_seed_badge_text() if active_launch_request != null else ""

	var cid: StringName = SaveManagerScript.get_selected_character()
	var roster: Dictionary = CharacterDataScript.load_roster()
	var cdata: CharacterData = roster.get(cid, null) as CharacterData
	var pilot_name: String = cdata.display_name if cdata != null else String(cid).capitalize()

	hud.update_status(m_txt, st_txt, seed_v, coord_code, badge, str(_active_progression_preset), pilot_name)


func _create_surface_material(
	base_path: String, uv_sc: Vector2, native_sz: Vector2, plate_tint: Color, chassis_tint: Color
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
	var tex_norm: Texture2D = TextureLoader.load_texture_2d(base_path + "_normal.png", true)
	var tex_orm: Texture2D = TextureLoader.load_texture_2d(base_path + "_pbr_orm.png", true)
	var has_pbr: bool = (tex_norm != null and tex_orm != null)
	mat.set_shader_parameter("has_pbr_maps", has_pbr)
	if has_pbr:
		mat.set_shader_parameter("normal_map_tex", tex_norm)
		mat.set_shader_parameter("pbr_orm_tex", tex_orm)
	mat.set_shader_parameter("uv_scale", uv_sc)
	mat.set_shader_parameter("tex_native_size", native_sz)
	mat.set_shader_parameter("wing_plate_tint", plate_tint)
	mat.set_shader_parameter("wing_chassis_tint", chassis_tint)
	mat.set_shader_parameter("pilot_accent_color", config.pilot_accent_color)
	return mat


func _create_prop_surface_materials(
	armor_col: Color = Color(0.46, 0.52, 0.66, 1.0), chassis_col: Color = Color(0.07, 0.085, 0.15, 1.0), ambient_f: float = 0.24
) -> Array[ShaderMaterial]:
	var mats: Array[ShaderMaterial] = []
	var base_colors: Array[Color] = [armor_col, chassis_col, config.pilot_accent_color]
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
