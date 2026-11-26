class_name AstralStationHub
extends Node3D

## Estación Astral Flotante v4 (Producción) — Mandala Octagonal de 9 Islas sobre Cosmos Engine Vivo.
## Composición de Capas:
## - Layer -10 (HubCosmosBackdropController): CosmosRootNode 2D a pantalla completa.
## - Layer   0 (Hub3DSubViewport transparente MSAA 4x): Islas esculpidas + Trim-Sheet PBR/Normal/ORM/Ink SDF 2x,
##   Puentes de Luz cromáticos, Valentina v2 (caminata en isla ↔ vuelo con alas 3D sobre espacio),
##   Cámara Telefoto Fija 1:1 (FOV 26°, Pitch -46°, Yaw 0° bloqueado) y Despegue Radial 8-Dir Seamless.

const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_art_lab_config.gd")
const DEFAULT_CONFIG: ConfigScript = preload("res://data/hub/default_astral_station_config.tres")
const LayoutConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_floating_layout_config.gd")
const DEFAULT_LAYOUT: LayoutConfigScript = preload("res://data/hub/default_astral_floating_layout.tres")
const ProgressionConfigScript = preload("res://scenes/ui/hub/resources/hub_progression_config.gd")
const DEFAULT_PROGRESSION_CONFIG: ProgressionConfigScript = preload("res://data/hub/default_hub_progression_config.tres")
const ProgressionEvaluatorScript = preload("res://scenes/ui/hub/components/hub_progression_evaluator.gd")
const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")

const IslandsBuilder = preload("res://scenes/ui/hub/astral_station/meshes/hub_floating_islands_mesh_builder.gd")
const CapsuleBuilder = preload("res://scenes/ui/hub/astral_station/meshes/hub_capsule_mesh_builder.gd")
const TextureLoader = preload("res://scenes/ui/hub/astral_station/components/hub_texture_loader.gd")
const CosmosBackdropScript = preload("res://scenes/ui/hub/astral_station/components/hub_cosmos_backdrop_controller.gd")
const CameraRigScript = preload("res://scenes/ui/hub/astral_station/components/hub_lab_camera_rig.gd")
const StationNodeScript = preload("res://scenes/ui/hub/astral_station/components/hub_lab_station_node.gd")
const PlayerScript = preload("res://scenes/ui/hub/astral_station/components/hub_art_lab_player.gd")
const HUDScript = preload("res://scenes/ui/hub/astral_station/astral_station_hud.gd")
const EastWingScript = preload("res://scenes/ui/hub/astral_station/components/hub_east_wing_controller.gd")
const WestSanctuaryScript = preload("res://scenes/ui/hub/astral_station/components/hub_west_sanctuary_controller.gd")
const ModalCoordScript = preload("res://scenes/ui/hub/astral_station/components/hub_antesala_modal_coordinator.gd")
const DepartureCtrlScript = preload("res://scenes/ui/hub/astral_station/components/hub_radial_departure_controller.gd")
const AtmosphereCtrlScript = preload("res://scenes/ui/hub/astral_station/components/hub_atmosphere_controller.gd")
const CharacterDataScript = preload("res://data/characters/character_data.gd")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")

const PropShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_arcsys_prop_3d.gdshader")
const SurfaceShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_arcsys_surface_3d.gdshader")
const OctagonDeckShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_octagon_deck_3d.gdshader")
const CapsuleDaisShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_capsule_dais_3d.gdshader")
const OutlineShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_arcsys_outline_3d.gdshader")
const HardlightBridgeShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_hardlight_bridge_3d.gdshader")
const AstralGlassShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_astral_glass_3d.gdshader")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")
const CosmicLightingSamplerScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sampler.gd")

signal embedded_camera_focus_changed(mode: int, focus_world_3d: Vector3)
signal embedded_launch_request_changed(request: RunLaunchRequestScript, trigger_flash: bool)
signal embedded_movement_lock_changed(locked: bool)
signal embedded_player_reposition_requested(world_3d: Vector3, face_dir: Vector2, suppress_shadow: bool)
signal embedded_pilot_selected(char_id: StringName, accent_color: Color)
signal embedded_companions_updated()
signal embedded_gacha_skin_equipped(equip_res: Dictionary)
signal embedded_settings_toggled(is_open: bool)
signal embedded_tutorial_requested()
signal embedded_return_to_title_requested()
signal embedded_demat_finished()
signal embedded_materialization_finished()

const FLOOR_TEX_BASE: String = "res://assets/environments/astral_station/surfaces/hub_floor_astral"
const TRIM_TEX_BASE: String = "res://assets/environments/astral_station/trims/hub_arcsys_trim"
const SETTINGS_MODAL_SCENE: PackedScene = preload("res://scenes/ui/settings_modal/settings_modal.tscn")
const TITLE_SCREEN_PATH: String = "res://scenes/ui/title_screen/title_screen.tscn"

@export var config: ConfigScript = DEFAULT_CONFIG
@export var layout_config: LayoutConfigScript = DEFAULT_LAYOUT
@export var progression_config: ProgressionConfigScript = DEFAULT_PROGRESSION_CONFIG
@export var is_dev_lab_mode: bool = false
@export var embedded_mode: bool = false

var cosmos_backdrop: CosmosBackdropScript = null
var hub_3d_layer: CanvasLayer = null
var hub_3d_container: SubViewportContainer = null
var hub_3d_viewport: SubViewport = null
var _world_3d_root: Node3D = null

var camera: Camera3D = null
var player: PlayerScript = null
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
var departure_controller: DepartureCtrlScript = null
var atmosphere_controller: AtmosphereCtrlScript = null
var hud: HUDScript = null
var settings_modal: SettingsModal = null
var _settings_layer: CanvasLayer = null

var _world_env: WorldEnvironment = null
var _dir_light: DirectionalLight3D = null
var _arch_prop_mats: Array[ShaderMaterial] = []
var _hero_prop_mats: Array[ShaderMaterial] = []
var _gold_trim_mats: Array[ShaderMaterial] = []
var _deck_surface_mats: Array[ShaderMaterial] = []
var _capsule_dais_mat: ShaderMaterial = null
var _skins_spotlight: SpotLight3D = null
var _glass_mat: ShaderMaterial = null
var _prop_outline_mat: ShaderMaterial = null
var _bridge_mats: Array[ShaderMaterial] = []
var _all_demat_mats: Array[ShaderMaterial] = []
var _under_keel_ring: MeshInstance3D = null
var _capsule_halo_mesh: MeshInstance3D = null
var _capsule_area: Area3D = null
var _capsule_label: Label3D = null

var _trim_norm_tex: Texture2D = null
var _trim_orm_tex: Texture2D = null
var _trim_sdf_tex: Texture2D = null

var _is_capsule_focused: bool = false
var _active_progression_preset: StringName = &"live"
var _shake_strength: float = 0.0
var _time_acc: float = 0.0
var _warn_progress_cached: float = 0.0
var _warn_sector_cached: Dictionary = {}
var _station_lighting_sample: CosmicLightingSampleScript = CosmicLightingSampleScript.new()

var _embedded_player_proxy: Node3D = null
var _embedded_player_rig_v2: Node = null
var _embedded_cosmos_root: CosmosRootNode = null
var _embedded_cosmos_sample_pos_2d: Vector2 = Vector2.ZERO
var _embedded_cosmos_anchor_2d: Vector2 = Vector2.INF
var _embedded_is_flying: bool = false
var _embedded_is_dematerializing: bool = false
var _embedded_input_suppressed: bool = false


func set_embedded_input_suppressed(suppressed: bool) -> void:
	_embedded_input_suppressed = suppressed


func configure_embedded(
	p_initial_request: RunLaunchRequestScript,
	p_player_rig_v2: Node,
	p_cosmos_root: CosmosRootNode
) -> void:
	embedded_mode = true
	is_dev_lab_mode = false
	if p_initial_request != null:
		active_launch_request = p_initial_request.duplicate_request()
	_embedded_player_rig_v2 = p_player_rig_v2
	_embedded_cosmos_root = p_cosmos_root


func set_embedded_cosmos_root(p_cosmos_root: CosmosRootNode) -> void:
	_embedded_cosmos_root = p_cosmos_root


func set_embedded_cosmos_anchor_2d(pos_2d: Vector2) -> void:
	_embedded_cosmos_anchor_2d = pos_2d


func set_embedded_player_rig_v2(p_player_rig_v2: Node) -> void:
	_embedded_player_rig_v2 = p_player_rig_v2
	if modal_coordinator != null:
		modal_coordinator.set_player_rig_v2(p_player_rig_v2)


func get_world_3d_viewport() -> SubViewport:
	return hub_3d_viewport


func get_camera_3d() -> Camera3D:
	return camera


func _get_active_player_node() -> Node3D:
	return _embedded_player_proxy if embedded_mode else player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree() != null:
		get_tree().paused = false
	Engine.time_scale = 1.0
	SaveManagerScript.set_game_speed(1.0)

	if config == null:
		config = DEFAULT_CONFIG
	if layout_config == null:
		layout_config = DEFAULT_LAYOUT
	if progression_config == null:
		progression_config = DEFAULT_PROGRESSION_CONFIG

	progression_evaluator.setup(progression_config)
	if active_launch_request == null:
		if is_dev_lab_mode:
			active_launch_request = RunLaunchRequestScript.create(config.default_preview_seed, RunLaunchRequestScript.SeedMode.AUTO)
		else:
			active_launch_request = RunLaunchRequestScript.create_random_auto()

	_load_trim_sheet_textures()
	_build_viewport_stack()
	_build_environment()
	_build_architecture()
	_build_central_capsule()
	_build_antesala_stations()
	_build_player_and_camera()
	_build_phase3_wings_and_controllers()
	if departure_controller != null:
		departure_controller.launch_real_combat = (not is_dev_lab_mode) and (not embedded_mode)
	_build_hud()
	if not is_dev_lab_mode:
		_build_production_settings_modal()
	_register_all_demat_and_trim_materials()

	apply_progression_preset(&"live")
	apply_config_visuals()
	apply_launch_request(active_launch_request, false)

	if not embedded_mode:
		var audio_mgr: Node = get_node_or_null("/root/AudioManager")
		if audio_mgr != null and audio_mgr.has_method("play_music"):
			audio_mgr.play_music("menu")


func _load_trim_sheet_textures() -> void:
	_trim_norm_tex = TextureLoader.load_texture_2d(TRIM_TEX_BASE + "_normal.png", true)
	_trim_orm_tex = TextureLoader.load_texture_2d(TRIM_TEX_BASE + "_pbr_orm.png", true)
	# Estrictamente SIN mipmaps para mantener nitidez vectorial en LOD 0
	_trim_sdf_tex = TextureLoader.load_texture_2d(TRIM_TEX_BASE + "_ink_sdf.png", false)


func _build_viewport_stack() -> void:
	if embedded_mode:
		hub_3d_viewport = SubViewport.new()
		hub_3d_viewport.name = "Hub3DSubViewport"
		hub_3d_viewport.own_world_3d = true
		hub_3d_viewport.transparent_bg = true
		hub_3d_viewport.handle_input_locally = false
		hub_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if DisplayServer.get_name() != "headless":
			hub_3d_viewport.msaa_3d = Viewport.MSAA_4X
		add_child(hub_3d_viewport)

		_world_3d_root = Node3D.new()
		_world_3d_root.name = "HubFloatingWorld3D"
		hub_3d_viewport.add_child(_world_3d_root)
		return

	cosmos_backdrop = CosmosBackdropScript.new() as CosmosBackdropScript
	cosmos_backdrop.name = "CosmosBackdropLayer"
	add_child(cosmos_backdrop)
	cosmos_backdrop.setup(config, active_launch_request.cosmos_seed if active_launch_request != null else -1)

	hub_3d_layer = CanvasLayer.new()
	hub_3d_layer.name = "Hub3DViewportLayer"
	hub_3d_layer.layer = 0
	add_child(hub_3d_layer)

	hub_3d_container = SubViewportContainer.new()
	hub_3d_container.name = "Hub3DSubViewportContainer"
	hub_3d_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	hub_3d_container.stretch = true
	hub_3d_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hub_3d_layer.add_child(hub_3d_container)

	hub_3d_viewport = SubViewport.new()
	hub_3d_viewport.name = "Hub3DSubViewport"
	hub_3d_viewport.own_world_3d = true
	hub_3d_viewport.transparent_bg = true
	hub_3d_viewport.handle_input_locally = false
	hub_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if DisplayServer.get_name() != "headless":
		hub_3d_viewport.msaa_3d = Viewport.MSAA_4X
	hub_3d_container.add_child(hub_3d_viewport)

	_world_3d_root = Node3D.new()
	_world_3d_root.name = "HubFloatingWorld3D"
	hub_3d_viewport.add_child(_world_3d_root)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.22, 0.36, 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.22
	env.glow_intensity = config.bloom_intensity
	env.glow_bloom = config.glow_bloom
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.06

	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnvironment"
	_world_env.environment = env
	_world_3d_root.add_child(_world_env)

	_dir_light = DirectionalLight3D.new()
	_dir_light.name = "DirectionalLight3D"
	_dir_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	_dir_light.light_color = Color(1.0, 0.97, 0.94, 1.0)
	_dir_light.light_energy = 1.12
	_dir_light.shadow_enabled = true
	_dir_light.shadow_bias = 0.045
	_dir_light.shadow_normal_bias = 1.45
	_dir_light.shadow_blur = 2.0
	_dir_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_dir_light.directional_shadow_max_distance = 52.0
	_dir_light.directional_shadow_pancake_size = 0.0
	_world_3d_root.add_child(_dir_light)

	var cap_spot := SpotLight3D.new()
	cap_spot.name = "CapsuleHeroSpotLight"
	cap_spot.position = Vector3(0.0, 6.2, 2.5)
	cap_spot.light_color = Color(1.0, 0.93, 0.84, 1.0)
	cap_spot.light_energy = 1.35
	cap_spot.spot_range = 12.0
	cap_spot.spot_angle = 38.0
	cap_spot.look_at_from_position(cap_spot.position, Vector3(0.0, 0.5, 0.8), Vector3.UP)
	_world_3d_root.add_child(cap_spot)

	atmosphere_controller = AtmosphereCtrlScript.new() as AtmosphereCtrlScript
	atmosphere_controller.name = "HubAtmosphereController"
	_world_3d_root.add_child(atmosphere_controller)
	atmosphere_controller.setup(config.capsule_pos, false)

	for light_spec: Dictionary in [
		{"name": "WestAccentLight", "pos": Vector3(-18.5, 3.0, 0.0), "col": Color(0.74, 0.40, 1.0, 1.0), "energy": 1.25, "range": 15.0},
		{"name": "EastAccentLight", "pos": Vector3(18.5, 3.0, 0.0), "col": Color(1.0, 0.18, 0.62, 1.0), "energy": 1.10, "range": 15.0},
		{"name": "SouthTalentsLight", "pos": Vector3(0.0, 2.8, 15.82), "col": Color(0.14, 0.92, 1.0, 1.0), "energy": 1.05, "range": 12.0},
	]:
		var ol := OmniLight3D.new()
		ol.name = str(light_spec["name"])
		ol.position = light_spec["pos"] as Vector3
		ol.light_color = light_spec["col"] as Color
		ol.light_energy = float(light_spec["energy"])
		ol.omni_range = float(light_spec["range"])
		_world_3d_root.add_child(ol)

	_skins_spotlight = SpotLight3D.new()
	_skins_spotlight.name = "SkinsSpotlightLight"
	_skins_spotlight.position = Vector3(0.0, 5.2, -13.9)
	_skins_spotlight.light_color = Color(1.0, 0.96, 0.98, 1.0)
	_skins_spotlight.light_energy = 0.65
	_skins_spotlight.spot_range = 14.0
	_skins_spotlight.spot_angle = 32.0
	_skins_spotlight.look_at_from_position(_skins_spotlight.position, Vector3(0.0, 0.7, -15.42), Vector3.UP)
	_world_3d_root.add_child(_skins_spotlight)


func _build_architecture() -> void:
	var arch_root := Node3D.new()
	arch_root.name = "StationArchitecture"
	_world_3d_root.add_child(arch_root)

	_prop_outline_mat = ShaderMaterial.new()
	_prop_outline_mat.shader = OutlineShader
	_arch_prop_mats = _create_prop_surface_materials(Color(0.16, 0.21, 0.34, 1.0), Color(0.05, 0.062, 0.125, 1.0), 0.22)
	_hero_prop_mats = _create_prop_surface_materials(Color(0.46, 0.52, 0.66, 1.0), Color(0.07, 0.085, 0.15, 1.0), 0.26)
	_gold_trim_mats = _create_gold_trim_materials()

	_deck_surface_mats.clear()
	var main_deck_mat: ShaderMaterial = _create_octagon_deck_material(Color(0.16, 0.21, 0.34, 1.0), Color(0.055, 0.072, 0.145, 1.0), config.pilot_accent_color, 7.60, false, 1.0)
	var north_deck_mat: ShaderMaterial = _create_octagon_deck_material(Color(0.17, 0.21, 0.36, 1.0), Color(0.055, 0.070, 0.140, 1.0), Color(0.98, 0.36, 0.66, 1.0), 4.113, false, 1.0)
	var south_deck_mat: ShaderMaterial = _create_octagon_deck_material(Color(0.16, 0.22, 0.37, 1.0), Color(0.052, 0.068, 0.142, 1.0), Color(0.14, 0.92, 1.0, 1.0), 4.546, false, 1.0)
	var west_deck_mat: ShaderMaterial = _create_octagon_deck_material(Color(0.18, 0.20, 0.37, 1.0), Color(0.058, 0.064, 0.140, 1.0), Color(0.75, 0.35, 1.0, 1.0), 5.35, true, -1.0)
	var east_deck_mat: ShaderMaterial = _create_octagon_deck_material(Color(0.18, 0.20, 0.37, 1.0), Color(0.058, 0.064, 0.140, 1.0), Color(1.0, 0.16, 0.62, 1.0), 5.35, true, 1.0)
	var compact_deck_mat: ShaderMaterial = _create_octagon_deck_material(Color(0.16, 0.21, 0.34, 1.0), Color(0.055, 0.072, 0.145, 1.0), Color(0.24, 0.96, 0.72, 1.0), 3.15, false, 1.0)
	_deck_surface_mats = [main_deck_mat, north_deck_mat, south_deck_mat, west_deck_mat, east_deck_mat, compact_deck_mat]

	_glass_mat = ShaderMaterial.new()
	_glass_mat.shader = AstralGlassShader
	_glass_mat.set_shader_parameter("base_alpha", 0.08)

	# 1. Mandala Octagonal de 9 Islas (Central + 4 Cardinales + 4 Intermedias Compactas)
	var central_pos := Vector3(layout_config.central_island_pos.x, 0.0, layout_config.central_island_pos.y)
	var north_pos := Vector3(layout_config.north_island_pos.x, 0.0, layout_config.north_island_pos.y)
	var south_pos := Vector3(layout_config.south_island_pos.x, 0.0, layout_config.south_island_pos.y)
	var west_pos := Vector3(layout_config.west_island_pos.x, 0.0, layout_config.west_island_pos.y)
	var east_pos := Vector3(layout_config.east_island_pos.x, 0.0, layout_config.east_island_pos.y)

	var island_specs: Array[Dictionary] = [
		{
			"name": "CentralFlagshipIsland",
			"mesh": IslandsBuilder.build_central_flagship_island_mesh(),
			"deck_meshes": [IslandsBuilder.build_central_deck_surface_mesh()],
			"gold_mesh": IslandsBuilder.build_central_gold_collar_mesh(),
			"deck_mat": main_deck_mat,
			"pos": central_pos,
			"yaw_deg": 0.0,
		},
		{
			"name": "NorthObservatoryIsland",
			"mesh": IslandsBuilder.build_north_observatory_island_mesh(),
			"deck_meshes": [IslandsBuilder.build_north_observatory_deck_surface_mesh()],
			"gold_mesh": IslandsBuilder.build_north_observatory_gold_collar_mesh(),
			"deck_mat": north_deck_mat,
			"pos": north_pos,
			"yaw_deg": 0.0,
		},
		{
			"name": "SouthTalentsIsland",
			"mesh": IslandsBuilder.build_south_talents_island_mesh(),
			"deck_meshes": [IslandsBuilder.build_south_talents_deck_surface_mesh()],
			"gold_mesh": IslandsBuilder.build_south_talents_gold_collar_mesh(),
			"deck_mat": south_deck_mat,
			"pos": south_pos,
			"yaw_deg": 0.0,
		},
		{
			"name": "WestCrescentIsland",
			"mesh": IslandsBuilder.build_mirrored_bastion_island_mesh(-1.0),
			"deck_meshes": [IslandsBuilder.build_mirrored_bastion_deck_surface_mesh(-1.0)],
			"gold_mesh": IslandsBuilder.build_mirrored_bastion_gold_collar_mesh(-1.0),
			"deck_mat": west_deck_mat,
			"pos": west_pos,
			"yaw_deg": 0.0,
		},
		{
			"name": "EastSatelliteIsland",
			"mesh": IslandsBuilder.build_mirrored_bastion_island_mesh(1.0),
			"deck_meshes": [IslandsBuilder.build_mirrored_bastion_deck_surface_mesh(1.0)],
			"gold_mesh": IslandsBuilder.build_mirrored_bastion_gold_collar_mesh(1.0),
			"deck_mat": east_deck_mat,
			"pos": east_pos,
			"yaw_deg": 0.0,
		},
	]
	for pi: int in range(layout_config.loadout_pod_positions.size()):
		var p_xz: Vector2 = layout_config.loadout_pod_positions[pi]
		var to_center: Vector2 = (-p_xz).normalized()
		var dock_yaw_deg: float = rad_to_deg(atan2(-to_center.x, -to_center.y))
		island_specs.append({
			"name": "LoadoutPodIsland_%d" % pi,
			"mesh": IslandsBuilder.build_compact_octagon_island_mesh(),
			"deck_meshes": [IslandsBuilder.build_compact_octagon_deck_surface_mesh()],
			"gold_mesh": IslandsBuilder.build_compact_octagon_gold_collar_mesh(),
			"deck_mat": compact_deck_mat,
			"pos": Vector3(p_xz.x, 0.0, p_xz.y),
			"yaw_deg": dock_yaw_deg,
		})

	for spec: Dictionary in island_specs:
		var island_pos: Vector3 = spec["pos"] as Vector3
		var island_rot := Vector3(0.0, deg_to_rad(float(spec.get("yaw_deg", 0.0))), 0.0)
		var mi := MeshInstance3D.new()
		mi.name = str(spec["name"])
		mi.mesh = spec["mesh"] as ArrayMesh
		mi.position = island_pos
		mi.rotation = island_rot
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surf_idx: int in range(3):
			mi.set_surface_override_material(surf_idx, _arch_prop_mats[surf_idx])
		arch_root.add_child(mi)

		var d_meshes: Array = spec.get("deck_meshes", []) as Array
		var d_mat: ShaderMaterial = spec.get("deck_mat", main_deck_mat) as ShaderMaterial
		for di: int in range(d_meshes.size()):
			var dmi := MeshInstance3D.new()
			dmi.name = "%s_Deck_%d" % [str(spec["name"]), di]
			dmi.mesh = d_meshes[di] as ArrayMesh
			dmi.position = island_pos
			dmi.rotation = island_rot
			dmi.material_override = d_mat
			dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			arch_root.add_child(dmi)

		var g_mesh: ArrayMesh = spec.get("gold_mesh", null) as ArrayMesh
		if g_mesh != null:
			var gmi := MeshInstance3D.new()
			gmi.name = "%s_GoldCollar" % str(spec["name"])
			gmi.mesh = g_mesh
			gmi.position = island_pos
			gmi.rotation = island_rot
			gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for si: int in range(g_mesh.get_surface_count()):
				gmi.set_surface_override_material(si, _gold_trim_mats[si])
			arch_root.add_child(gmi)

	# Monolito Astral Sellado en Isla NW + Balizas de esquina y Aro Astrolabio bajo la quilla
	if not layout_config.loadout_pod_positions.is_empty():
		var nw_xz: Vector2 = layout_config.loadout_pod_positions[0]
		var nw_anchor := MeshInstance3D.new()
		nw_anchor.name = "NWFutureSlotAnchor"
		nw_anchor.mesh = IslandsBuilder.build_future_slot_anchor_mesh()
		nw_anchor.position = Vector3(nw_xz.x, 0.015, nw_xz.y)
		nw_anchor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for si: int in range(3):
			nw_anchor.set_surface_override_material(si, _gold_trim_mats[si] if si == 0 else _arch_prop_mats[si])
		arch_root.add_child(nw_anchor)

	var corners_mi := MeshInstance3D.new()
	corners_mi.name = "CentralCornerBeacons"
	corners_mi.mesh = IslandsBuilder.build_central_corner_beacons_mesh()
	corners_mi.position = central_pos
	corners_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for si: int in range(3):
		corners_mi.set_surface_override_material(si, _gold_trim_mats[si] if si == 0 else _arch_prop_mats[si])
	arch_root.add_child(corners_mi)

	_under_keel_ring = MeshInstance3D.new()
	_under_keel_ring.name = "CentralUnderKeelRing"
	_under_keel_ring.mesh = IslandsBuilder.build_central_under_keel_ring_mesh()
	_under_keel_ring.position = central_pos + Vector3(0.0, -1.55, 0.0)
	_under_keel_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for si: int in range(3):
		_under_keel_ring.set_surface_override_material(si, _gold_trim_mats[si] if si == 0 else _arch_prop_mats[si])
	arch_root.add_child(_under_keel_ring)

	var glass_mi := MeshInstance3D.new()
	glass_mi.name = "CentralGlassCutouts"
	glass_mi.mesh = IslandsBuilder.build_central_glass_cutouts_mesh()
	glass_mi.position = central_pos
	glass_mi.material_override = _glass_mat
	glass_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arch_root.add_child(glass_mi)

	# 2. 8 Puentes de Luz Perpendiculares con pulso cromático del ala destino (cero postes sueltos)
	var wing_bridge_colors: Dictionary = {
		"Bridge_North": Color(0.98, 0.36, 0.66, 1.0),
		"Bridge_South": Color(0.14, 0.94, 1.0, 1.0),
		"Bridge_West": Color(0.68, 0.36, 1.0, 1.0),
		"Bridge_East": Color(1.0, 0.18, 0.62, 1.0),
		"Bridge_SW": Color(0.24, 0.96, 0.72, 1.0),
		"Bridge_NE": Color(1.0, 0.76, 0.24, 1.0),
		"Bridge_SE": Color(0.28, 0.78, 1.0, 1.0),
		"Bridge_NW": Color(0.92, 0.78, 0.42, 1.0),
	}
	_bridge_mats.clear()
	for b_spec: Dictionary in layout_config.bridges:
		var b_name: String = str(b_spec.get("name", "HardlightBridge"))
		var p_a: Vector2 = b_spec.get("from", Vector2.ZERO) as Vector2
		var p_b: Vector2 = b_spec.get("to", Vector2.ZERO) as Vector2
		var hw: float = float(b_spec.get("half_width", 1.0))
		var delta_v: Vector2 = p_b - p_a
		var b_len: float = maxf(delta_v.length(), 0.25)
		var b_center: Vector2 = (p_a + p_b) * 0.5
		var b_yaw: float = atan2(-delta_v.x, -delta_v.y)

		var b_holder := Node3D.new()
		b_holder.name = b_name
		b_holder.position = Vector3(b_center.x, 0.0, b_center.y)
		b_holder.rotation = Vector3(0.0, b_yaw, 0.0)
		arch_root.add_child(b_holder)

		var b_mat := ShaderMaterial.new()
		b_mat.shader = HardlightBridgeShader
		b_mat.set_shader_parameter("bridge_color", wing_bridge_colors.get(b_name, Color(0.14, 0.92, 1.0, 1.0)) as Color)
		b_mat.set_shader_parameter("trim_gold_color", Color(0.95, 0.80, 0.34, 1.0))
		_bridge_mats.append(b_mat)

		var surf_mi := MeshInstance3D.new()
		surf_mi.name = b_name + "_Surface"
		surf_mi.mesh = IslandsBuilder.build_hardlight_bridge_surface_mesh(b_len, hw * 2.0)
		surf_mi.material_override = b_mat
		surf_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b_holder.add_child(surf_mi)


func _build_central_capsule() -> void:
	var cap_root := Node3D.new()
	cap_root.name = "CentralPilotCapsule"
	cap_root.position = config.capsule_pos
	_world_3d_root.add_child(cap_root)

	var base_mi := MeshInstance3D.new()
	base_mi.name = "CapsuleBaseMesh"
	base_mi.mesh = CapsuleBuilder.build_capsule_base_mesh()
	base_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for surf_idx: int in range(base_mi.mesh.get_surface_count()):
		base_mi.set_surface_override_material(surf_idx, _hero_prop_mats[surf_idx])
	cap_root.add_child(base_mi)

	var gold_trim_mi := MeshInstance3D.new()
	gold_trim_mi.name = "CapsuleGoldTrimMesh"
	gold_trim_mi.mesh = CapsuleBuilder.build_capsule_gold_trim_mesh()
	gold_trim_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for surf_idx: int in range(gold_trim_mi.mesh.get_surface_count()):
		gold_trim_mi.set_surface_override_material(surf_idx, _gold_trim_mats[surf_idx])
	cap_root.add_child(gold_trim_mi)

	_capsule_dais_mat = ShaderMaterial.new()
	_capsule_dais_mat.shader = CapsuleDaisShader
	_capsule_dais_mat.set_shader_parameter("pilot_accent_color", config.pilot_accent_color)
	if cosmos_backdrop != null and cosmos_backdrop.get_subviewport() != null:
		_capsule_dais_mat.set_shader_parameter("cosmos_reflection_tex", cosmos_backdrop.get_subviewport().get_texture())
		_capsule_dais_mat.set_shader_parameter("has_cosmos_reflection", true)

	var dais_mi := MeshInstance3D.new()
	dais_mi.name = "CapsuleDaisSurfaceMesh"
	dais_mi.mesh = CapsuleBuilder.build_capsule_dais_surface_mesh()
	dais_mi.material_override = _capsule_dais_mat
	dais_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cap_root.add_child(dais_mi)

	_capsule_halo_mesh = MeshInstance3D.new()
	_capsule_halo_mesh.name = "CapsuleHaloMesh"
	_capsule_halo_mesh.mesh = CapsuleBuilder.build_capsule_halo_mesh()
	_capsule_halo_mesh.position = Vector3(0.0, 1.88, -1.44)
	_capsule_halo_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for surf_idx: int in range(_capsule_halo_mesh.mesh.get_surface_count()):
		_capsule_halo_mesh.set_surface_override_material(surf_idx, _gold_trim_mats[surf_idx] if surf_idx == 0 else _hero_prop_mats[surf_idx])
	cap_root.add_child(_capsule_halo_mesh)

	_add_static_box(cap_root, "CapsuleRearArchCollider", Vector3(0.0, 0.9, -1.16), Vector3(3.35, 1.8, 0.48))
	_capsule_area = _create_trigger_area("CapsuleInteractArea", Vector3(0.0, 0.9, 0.0), 2.05)
	cap_root.add_child(_capsule_area)

	_capsule_label = _create_prompt_label("CapsulePromptLabel", Vector3(0.0, 2.72, 0.0), "[E] CÁPSULA DE PILOTO")
	cap_root.add_child(_capsule_label)


func _build_antesala_stations() -> void:
	left_station = _spawn_station(
		"LeftSkinsConsole", config.console_left_pos, 0.0,
		&"skins_mirror", "Espejo de Skins", "Consigue tu primera skin en el Invocador Gacha",
		StationNodeScript.StationState.CALIBRATING,
		Color(0.98, 0.36, 0.66, 1.0)
	)
	left_far_station = _spawn_station(
		"LeftTalentsConsole", config.console_left_far_pos, 0.0,
		&"talents_nexus", "Nexo de Talentos", "Recolecta Biomasa o completa tu 1.ª incursión",
		StationNodeScript.StationState.CALIBRATING,
		Color(0.14, 0.92, 1.0, 1.0)
	)
	right_station = _spawn_station(
		"RightCompanionsConsole", config.console_right_pos, 32.0,
		&"companions_projector", "Proyector de Compañía", "Desbloquea una Mascota o Navegante",
		StationNodeScript.StationState.CALIBRATING,
		Color(0.24, 0.96, 0.72, 1.0)
	)
	right_far_station = _spawn_station(
		"RightTacticalConsole", config.console_right_far_pos, -32.0,
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
	_world_3d_root.add_child(st)
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


func _build_player_and_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	_world_3d_root.add_child(camera)

	if embedded_mode:
		_embedded_player_proxy = Node3D.new()
		_embedded_player_proxy.name = "EmbeddedPlayerProxy3D"
		_embedded_player_proxy.position = config.player_spawn_pos
		_world_3d_root.add_child(_embedded_player_proxy)
		camera.current = true
		camera.top_level = true
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.rotation_degrees = Vector3(config.free_roam_pitch_deg, 0.0, 0.0)
		camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
		return

	player = PlayerScript.new() as PlayerScript
	player.name = "HubArtLabPlayer"
	player.position = config.player_spawn_pos
	_world_3d_root.add_child(player)
	player.setup(layout_config.platform_walk_speed, _dir_light, layout_config)
	player.traversal_state_changed.connect(func(_flying: bool) -> void:
		_refresh_hud_status()
	)

	camera_rig.configure(camera, config)
	camera_rig.set_mode(CameraRigScript.Mode.FREE_ROAM)
	camera_rig.update(camera, player.global_position, 0.0, config, true)
	if player.rig_avatar != null:
		player.rig_avatar.set_camera_pitch_alignment(camera.rotation_degrees.x, true)


func _build_phase3_wings_and_controllers() -> void:
	var active_p_node: Node3D = _get_active_player_node()
	east_wing = EastWingScript.new() as EastWingScript
	east_wing.name = "HubEastWingController"
	_world_3d_root.add_child(east_wing)
	east_wing.setup(config, active_p_node, embedded_mode)
	east_wing.gacha_focus_requested.connect(_on_gacha_focus_requested)
	east_wing.gacha_focus_exited.connect(_on_gacha_focus_exited)
	east_wing.telemetry_requested.connect(_on_telemetry_requested)
	east_wing.camera_shake_requested.connect(func(amt: float) -> void: _shake_strength = maxf(_shake_strength, amt))
	east_wing.bloom_boost_requested.connect(_on_bloom_boost_requested)
	east_wing.skin_equipped_live.connect(_on_gacha_skin_equipped_live)

	west_sanctuary = WestSanctuaryScript.new() as WestSanctuaryScript
	west_sanctuary.name = "HubWestSanctuaryController"
	_world_3d_root.add_child(west_sanctuary)
	west_sanctuary.setup(config)
	west_sanctuary.relic_interacted.connect(_on_west_relic_interacted)

	modal_coordinator = ModalCoordScript.new() as ModalCoordScript
	modal_coordinator.name = "HubAntesalaModalCoordinator"
	add_child(modal_coordinator)
	modal_coordinator.setup(progression_evaluator, player.rig_avatar if player != null else null, active_launch_request)
	if _embedded_player_rig_v2 != null:
		modal_coordinator.set_player_rig_v2(_embedded_player_rig_v2)
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

	departure_controller = DepartureCtrlScript.new() as DepartureCtrlScript
	departure_controller.name = "HubRadialDepartureController"
	add_child(departure_controller)
	departure_controller.setup(config, layout_config, player, cosmos_backdrop, _world_3d_root)
	departure_controller.set_pending_request(active_launch_request)
	if embedded_mode:
		departure_controller.embedded_dissolve_completed.connect(func() -> void:
			_embedded_is_dematerializing = false
			embedded_demat_finished.emit()
		)
		departure_controller.embedded_materialization_completed.connect(func() -> void:
			if hud != null:
				hud.set_clean_hud_visible(true)
			embedded_materialization_finished.emit()
		)
	else:
		departure_controller.perimeter_warning_updated.connect(func(prog: float, sector: Dictionary) -> void:
			_warn_progress_cached = prog
			_warn_sector_cached = sector
			if hud != null and player != null:
				hud.update_traversal_telemetry(player.is_flying_in_space, prog, sector, departure_controller.is_dissolved_preview())
		)
		departure_controller.departure_started.connect(func(sector: Dictionary, _dir: Vector2) -> void:
			_is_capsule_focused = false
			_warn_sector_cached = sector
			if hud != null:
				hud.set_clean_hud_visible(false)
			_set_camera_mode(CameraRigScript.Mode.SEAMLESS_DEPARTURE, player.global_position if player != null else Vector3.ZERO)
		)
		departure_controller.departure_completed.connect(func(_req: RunLaunchRequestScript, launched_combat: bool) -> void:
			if not launched_combat:
				if hud != null:
					hud.set_clean_hud_visible(true)
				_set_camera_mode(CameraRigScript.Mode.FREE_ROAM)
			_refresh_hud_status()
		)
		departure_controller.hub_rematerialized.connect(func() -> void:
			_warn_progress_cached = 0.0
			_warn_sector_cached = {}
			_set_camera_mode(CameraRigScript.Mode.FREE_ROAM)
			_refresh_hud_status()
		)


func _register_all_demat_and_trim_materials() -> void:
	_all_demat_mats.clear()
	var has_trim: bool = (_trim_norm_tex != null and _trim_orm_tex != null and _trim_sdf_tex != null)
	for mat: ShaderMaterial in _arch_prop_mats:
		mat.set_shader_parameter("has_trim_maps", has_trim)
		if has_trim:
			mat.set_shader_parameter("trim_normal_tex", _trim_norm_tex)
			mat.set_shader_parameter("trim_orm_tex", _trim_orm_tex)
			mat.set_shader_parameter("trim_ink_sdf_tex", _trim_sdf_tex)
		if not _all_demat_mats.has(mat):
			_all_demat_mats.append(mat)
	# Anodized metal & hero capsule arches stay crisp without UVs stretched trim seams
	for clean_mat: ShaderMaterial in _gold_trim_mats + _hero_prop_mats:
		clean_mat.set_shader_parameter("has_trim_maps", false)
		clean_mat.set_shader_parameter("trim_ink_strength", 0.0)
		if not _all_demat_mats.has(clean_mat):
			_all_demat_mats.append(clean_mat)

	for dmat: ShaderMaterial in _deck_surface_mats:
		if dmat != null and not _all_demat_mats.has(dmat):
			_all_demat_mats.append(dmat)
	if _capsule_dais_mat != null and not _all_demat_mats.has(_capsule_dais_mat):
		_all_demat_mats.append(_capsule_dais_mat)
	if _glass_mat != null and not _all_demat_mats.has(_glass_mat):
		_all_demat_mats.append(_glass_mat)

	if _prop_outline_mat != null and not _all_demat_mats.has(_prop_outline_mat):
		_all_demat_mats.append(_prop_outline_mat)
	for bmat: ShaderMaterial in _bridge_mats:
		if bmat != null and not _all_demat_mats.has(bmat):
			_all_demat_mats.append(bmat)

	for st: StationNodeScript in _all_stations():
		st.apply_trim_sheet_maps(_trim_norm_tex, _trim_orm_tex, _trim_sdf_tex)
		for m: ShaderMaterial in st.get_demat_materials():
			if not _all_demat_mats.has(m):
				_all_demat_mats.append(m)

	if east_wing != null:
		east_wing.apply_trim_sheet_maps(_trim_norm_tex, _trim_orm_tex, _trim_sdf_tex)
		for m: ShaderMaterial in east_wing.get_demat_materials():
			if not _all_demat_mats.has(m):
				_all_demat_mats.append(m)

	if west_sanctuary != null:
		west_sanctuary.apply_trim_sheet_maps(_trim_norm_tex, _trim_orm_tex, _trim_sdf_tex)
		for m: ShaderMaterial in west_sanctuary.get_demat_materials():
			if not _all_demat_mats.has(m):
				_all_demat_mats.append(m)

	if departure_controller != null:
		departure_controller.set_demat_materials(_all_demat_mats)
		var hide_nodes: Array[Node3D] = []
		for candidate_name: String in ["StationArchitecture", "CentralPilotCapsule", "HubAtmosphereController", "HubEastWingController", "HubWestSanctuaryController"]:
			var n: Node3D = _world_3d_root.get_node_or_null(candidate_name) as Node3D
			if n != null:
				hide_nodes.append(n)
		for st: StationNodeScript in _all_stations():
			hide_nodes.append(st)
		departure_controller.set_dissolve_hide_nodes(hide_nodes)


func _build_hud() -> void:
	hud = HUDScript.new() as HUDScript
	hud.name = "HubArtLabHUD"
	add_child(hud)
	hud.setup(config, is_dev_lab_mode)
	hud.camera_mode_requested.connect(_on_hud_camera_mode_requested)
	hud.accent_color_selected.connect(set_pilot_accent_color)
	hud.station_state_cycled.connect(cycle_right_station_state)
	hud.progression_preset_selected.connect(apply_progression_preset)
	hud.relic_mastery_override_selected.connect(set_west_mastery_override)
	hud.real_launch_toggled.connect(func(launch_real: bool) -> void:
		if departure_controller != null:
			departure_controller.launch_real_combat = launch_real
	)
	hud.rematerialize_requested.connect(func() -> void:
		if departure_controller != null:
			departure_controller.rematerialize_hub(true)
	)
	hud.seed_apply_requested.connect(func(s: int) -> void:
		apply_launch_request(RunLaunchRequestScript.create(s, RunLaunchRequestScript.SeedMode.CUSTOM), true)
	)
	hud.seed_random_requested.connect(func() -> void:
		apply_launch_request(RunLaunchRequestScript.create_random_auto(), true)
	)
	hud.quality_tier_selected.connect(func(q: int) -> void:
		if cosmos_backdrop != null:
			cosmos_backdrop.apply_quality_tier(q)
	)
	hud.shader_params_changed.connect(apply_config_visuals)
	hud.save_config_requested.connect(_save_config_resource)
	hud.back_to_workbench_requested.connect(_return_to_workbench)
	hud.settings_requested.connect(open_settings_modal)
	hud.tutorial_requested.connect(_on_hud_tutorial_requested)
	hud.return_to_title_requested.connect(return_to_title_screen)
	_refresh_hud_status()


func _build_production_settings_modal() -> void:
	if settings_modal != null or SETTINGS_MODAL_SCENE == null:
		return
	_settings_layer = CanvasLayer.new()
	_settings_layer.name = "SettingsModalLayer"
	_settings_layer.layer = 30
	add_child(_settings_layer)

	settings_modal = SETTINGS_MODAL_SCENE.instantiate() as SettingsModal
	if settings_modal != null:
		settings_modal.visible = false
		if settings_modal.has_signal("closed") and not settings_modal.closed.is_connected(_on_settings_modal_closed):
			settings_modal.closed.connect(_on_settings_modal_closed)
		_settings_layer.add_child(settings_modal)


func open_settings_modal() -> void:
	if settings_modal == null:
		_build_production_settings_modal()
	if settings_modal == null or _is_departure_active():
		return
	if player != null:
		player.is_movement_locked = true
	if embedded_mode:
		embedded_movement_lock_changed.emit(true)
		embedded_settings_toggled.emit(true)
	if settings_modal.has_method("open_settings"):
		settings_modal.open_settings()
	else:
		settings_modal.visible = true


func close_settings_modal() -> void:
	if settings_modal == null:
		return
	if settings_modal.has_method("close_settings"):
		settings_modal.close_settings()
	else:
		settings_modal.visible = false
		_on_settings_modal_closed()


func _on_settings_modal_closed() -> void:
	var unlocked: bool = not _is_capsule_focused and (modal_coordinator == null or not modal_coordinator.is_any_modal_open())
	if player != null and unlocked:
		player.is_movement_locked = false
	if embedded_mode:
		if unlocked:
			embedded_movement_lock_changed.emit(false)
		embedded_settings_toggled.emit(false)


func _on_hud_tutorial_requested() -> void:
	if _is_departure_active() or is_any_hub_modal_or_panel_open():
		return
	if embedded_mode:
		embedded_tutorial_requested.emit()


func return_to_title_screen() -> void:
	if _is_departure_active() or get_tree() == null:
		return
	if embedded_mode:
		embedded_return_to_title_requested.emit()
		return
	RunLaunchRequestScript.transition_to_title(get_tree())


func _process(delta: float) -> void:
	_time_acc += delta
	if _capsule_halo_mesh != null:
		_capsule_halo_mesh.rotate_object_local(Vector3.FORWARD, delta * 0.42)
	if _under_keel_ring != null:
		_under_keel_ring.rotate_y(delta * 0.14)

	if _shake_strength > 0.001:
		_shake_strength = maxf(0.0, _shake_strength - delta * 2.4)
		camera_rig.set_shake_offset(Vector3(
			sin(_time_acc * 58.0) * _shake_strength,
			cos(_time_acc * 49.0) * _shake_strength * 0.7,
			0.0
		))
	else:
		camera_rig.set_shake_offset(Vector3.ZERO)

	if embedded_mode:
		if _embedded_player_proxy != null:
			for bmat: ShaderMaterial in _bridge_mats:
				bmat.set_shader_parameter("player_world_pos", _embedded_player_proxy.global_position)
		_sync_live_cosmic_lighting(delta)
		if not _embedded_is_dematerializing:
			_update_proximity_prompts()
		return

	if player != null and camera != null:
		camera_rig.update(camera, player.global_position, delta, config, false)
		player.set_visibility_fade(1.0)
		for bmat: ShaderMaterial in _bridge_mats:
			bmat.set_shader_parameter("player_world_pos", player.global_position)
		if cosmos_backdrop != null:
			cosmos_backdrop.sync_with_player_world_xz(Vector2(player.global_position.x, player.global_position.z), delta)
		if player.rig_avatar != null:
			player.rig_avatar.set_camera_pitch_alignment(camera.rotation_degrees.x, false)
			player.rig_avatar.rotation_degrees.y = 0.0
			_sync_live_cosmic_lighting(delta)

	var allow_dep: bool = (
		not _is_capsule_focused
		and (east_wing == null or not east_wing.is_gacha_open())
		and (modal_coordinator == null or not modal_coordinator.is_any_modal_open())
	)
	if departure_controller != null:
		departure_controller.set_departure_enabled(allow_dep)
	_update_proximity_prompts()


func _sync_live_cosmic_lighting(delta: float) -> void:
	if _station_lighting_sample == null:
		return
	if cosmos_backdrop != null:
		cosmos_backdrop.sample_cosmic_lighting(_station_lighting_sample)
	elif embedded_mode and _embedded_cosmos_root != null and is_instance_valid(_embedded_cosmos_root):
		var sample_pos: Vector2 = _embedded_cosmos_anchor_2d if _embedded_cosmos_anchor_2d != Vector2.INF else _embedded_cosmos_sample_pos_2d
		CosmicLightingSamplerScript.sample_at(_embedded_cosmos_root, sample_pos, null, _station_lighting_sample)
	else:
		return

	if _dir_light != null and is_instance_valid(_dir_light):
		var target_col: Color = Color.WHITE.lerp(_station_lighting_sample.key_light_tint, clampf(_station_lighting_sample.star_tint_weight * 0.55, 0.0, 0.75))
		var col_w: float = clampf(1.0 - exp(-4.0 * maxf(delta, 0.016)), 0.0, 1.0)
		_dir_light.light_color = _dir_light.light_color.lerp(target_col, col_w)

	var key_t: Color = _station_lighting_sample.key_light_tint
	var shd_t: Color = _station_lighting_sample.shadow_tint
	var rim_c: Color = _station_lighting_sample.rim_key_color

	for mat: ShaderMaterial in _arch_prop_mats + _hero_prop_mats + _gold_trim_mats:
		mat.set_shader_parameter("cosmic_key_tint", key_t)
		mat.set_shader_parameter("cosmic_shadow_tint", shd_t)
		mat.set_shader_parameter("cosmic_rim_color", rim_c)
	for dmat: ShaderMaterial in _deck_surface_mats:
		dmat.set_shader_parameter("cosmic_shadow_tint", shd_t)
		dmat.set_shader_parameter("cosmic_rim_color", rim_c)
	if _capsule_dais_mat != null:
		_capsule_dais_mat.set_shader_parameter("cosmic_shadow_tint", shd_t)
		_capsule_dais_mat.set_shader_parameter("cosmic_rim_color", rim_c)
	for st: StationNodeScript in _all_stations():
		st.apply_cosmic_lighting_tints(key_t, shd_t, rim_c)
	if east_wing != null:
		east_wing.apply_cosmic_lighting_tints(key_t, shd_t, rim_c)
	if west_sanctuary != null:
		west_sanctuary.apply_cosmic_lighting_tints(key_t, shd_t, rim_c)

	if player != null and player.rig_avatar != null:
		player.rig_avatar.apply_cosmic_lighting_sample(_station_lighting_sample, delta)


func _unhandled_input(event: InputEvent) -> void:
	if embedded_mode and (_embedded_is_dematerializing or _embedded_input_suppressed):
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return

	var is_settings_open: bool = settings_modal != null and settings_modal.visible
	var is_free_roam: bool = (
		camera_rig.get_mode() == CameraRigScript.Mode.FREE_ROAM
		and not is_settings_open
		and not _is_departure_active()
		and (east_wing == null or not east_wing.is_gacha_open())
		and (modal_coordinator == null or not modal_coordinator.is_any_modal_open())
	)

	var mb_ev := event as InputEventMouseButton
	if mb_ev != null and mb_ev.pressed and is_free_roam and not embedded_mode:
		if mb_ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_rig.adjust_scroll_zoom(0.11)
			return
		if mb_ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_rig.adjust_scroll_zoom(-0.11)
			return

	if not is_settings_open and event.is_action_pressed("interact"):
		_handle_interact_press()
		return

	var key_ev := event as InputEventKey
	if key_ev == null or not key_ev.pressed or key_ev.echo:
		return
	match key_ev.keycode:
		KEY_F1:
			if embedded_mode and not is_dev_lab_mode and is_free_roam:
				get_viewport().set_input_as_handled()
				embedded_tutorial_requested.emit()
		KEY_H, KEY_F2:
			if is_dev_lab_mode and hud != null:
				hud.toggle_visible()
		KEY_R:
			if is_dev_lab_mode and departure_controller != null and departure_controller.is_dissolved_preview():
				departure_controller.rematerialize_hub(true)
		KEY_E, KEY_SPACE:
			if not is_settings_open:
				_handle_interact_press()
		KEY_ESCAPE:
			if is_settings_open:
				close_settings_modal()
			elif east_wing != null and east_wing.is_gacha_open():
				east_wing.close_gacha_station()
			elif modal_coordinator != null and modal_coordinator.is_any_modal_open():
				modal_coordinator.close_active_modal()
			elif _is_capsule_focused:
				exit_capsule_focus()
			elif camera_rig.get_mode() != CameraRigScript.Mode.FREE_ROAM and not _is_departure_active():
				_set_camera_mode(CameraRigScript.Mode.FREE_ROAM)
			elif not is_dev_lab_mode:
				open_settings_modal()
		KEY_1:
			if is_dev_lab_mode:
				_on_hud_camera_mode_requested(CameraRigScript.Mode.FREE_ROAM)
		KEY_2:
			if is_dev_lab_mode:
				_on_hud_camera_mode_requested(CameraRigScript.Mode.CAPSULE_PILOT_FOCUS)
		KEY_3:
			if is_dev_lab_mode:
				_on_hud_camera_mode_requested(CameraRigScript.Mode.SKINS_MIRROR_FOCUS)
		KEY_4:
			if is_dev_lab_mode:
				_on_hud_camera_mode_requested(CameraRigScript.Mode.STATION_FOCUS)
		KEY_5:
			if is_dev_lab_mode:
				_on_hud_camera_mode_requested(CameraRigScript.Mode.GACHA_SUMMON_CINEMATIC)
		KEY_6:
			if is_dev_lab_mode:
				_on_hud_camera_mode_requested(CameraRigScript.Mode.TROPHY_FOCUS)
		KEY_7:
			if is_dev_lab_mode:
				_on_hud_camera_mode_requested(CameraRigScript.Mode.SEAMLESS_DEPARTURE)


func _is_departure_active() -> bool:
	return _embedded_is_dematerializing or (departure_controller != null and departure_controller.is_departing())


func _is_body_near_capsule(body_3d: Node3D) -> bool:
	if body_3d == null or not is_instance_valid(body_3d):
		return false
	if _capsule_area != null and _capsule_area.overlaps_body(body_3d):
		return true
	var cap_pos: Vector3 = config.capsule_pos if config != null else Vector3.ZERO
	var dx: float = body_3d.global_position.x - cap_pos.x
	var dz: float = body_3d.global_position.z - cap_pos.z
	return (dx * dx + dz * dz) <= (2.05 * 2.05)


func _handle_interact_press() -> void:
	if _is_departure_active() or (departure_controller != null and departure_controller.is_dissolved_preview()):
		return
	if east_wing != null and east_wing.is_gacha_open():
		return
	if _is_capsule_focused:
		exit_capsule_focus()
		return
	if modal_coordinator != null and modal_coordinator.is_any_modal_open():
		return
	var active_p: Node3D = _get_active_player_node()
	if active_p == null:
		return
	if _is_body_near_capsule(active_p):
		trigger_capsule_focus(true)
		return
	for st: StationNodeScript in _all_stations():
		if st.is_player_inside(active_p):
			st.trigger_interaction()
			return
	if east_wing != null and east_wing.try_interact(active_p):
		return
	if west_sanctuary != null:
		west_sanctuary.try_interact(active_p)


func trigger_capsule_focus(open_pilot_panel: bool = false) -> void:
	var active_p: Node3D = _get_active_player_node()
	if _is_departure_active() or active_p == null:
		return
	_is_capsule_focused = true
	if embedded_mode:
		embedded_movement_lock_changed.emit(true)
		embedded_player_reposition_requested.emit(
			config.capsule_pos + Vector3(0.0, layout_config.capsule_pad_hover_y if layout_config != null else 0.112, 0.0),
			Vector2.DOWN,
			true
		)
	elif player != null:
		player.is_movement_locked = true
		player.is_pose_override_active = true
		player.set_closeup_shadow_suppressed(true)
		player.global_position = config.capsule_pos + Vector3(0.0, layout_config.capsule_pad_hover_y if layout_config != null else 0.112, 0.0)
		player.evaluate_platform_traversal(0.0, true)
		player.face_front_idle(true)
	if hud != null:
		hud.set_clean_hud_visible(false)
	if open_pilot_panel and modal_coordinator != null:
		modal_coordinator.open_pilot_capsule(config.capsule_pos)
	else:
		_set_camera_mode(CameraRigScript.Mode.CAPSULE_PILOT_FOCUS, config.capsule_pos)


func exit_capsule_focus() -> void:
	_is_capsule_focused = false
	if modal_coordinator != null and modal_coordinator.is_any_modal_open():
		modal_coordinator.close_active_modal()
	if embedded_mode:
		embedded_movement_lock_changed.emit(false)
	elif player != null:
		player.is_movement_locked = false
		player.is_pose_override_active = false
		player.set_closeup_shadow_suppressed(false)
	if hud != null:
		hud.set_clean_hud_visible(true)
	_set_camera_mode(CameraRigScript.Mode.FREE_ROAM)


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

	if embedded_mode:
		embedded_movement_lock_changed.emit(true)
	elif player != null:
		player.is_movement_locked = true
		player.face_front_idle(true)

	if modal_coordinator == null:
		_set_camera_mode(CameraRigScript.Mode.STATION_FOCUS, station.global_position)
		return

	match station.station_id:
		&"skins_mirror":
			if _skins_spotlight != null:
				_skins_spotlight.light_energy = 2.45
			var target_mirror_pos: Vector3 = station.global_position + Vector3(0.0, 0.098, 0.08)
			if embedded_mode:
				embedded_player_reposition_requested.emit(target_mirror_pos, Vector2.DOWN, true)
				modal_coordinator.open_skins_mirror(target_mirror_pos)
			elif player != null:
				player.is_pose_override_active = true
				player.set_closeup_shadow_suppressed(true)
				player.global_position = target_mirror_pos
				player.evaluate_platform_traversal(0.0, true)
				player.face_front_idle(true)
				modal_coordinator.open_skins_mirror(player.global_position)
			else:
				modal_coordinator.open_skins_mirror(station.global_position)
		&"talents_nexus":
			var target_nexus_pos: Vector3 = station.global_position + Vector3(0.0, 0.02, -2.35)
			if embedded_mode:
				embedded_player_reposition_requested.emit(target_nexus_pos, Vector2.DOWN, false)
				modal_coordinator.open_talents_nexus(station.global_position + Vector3(0.0, 0.35, 0.0))
			elif player != null:
				player.is_pose_override_active = true
				player.global_position = target_nexus_pos
				player.evaluate_platform_traversal(0.0, true)
				var se_dir := Vector2(0.0, 1.0)
				player.set_pose_override(se_dir, 0.0, se_dir, true)
				modal_coordinator.open_talents_nexus(station.global_position + Vector3(0.0, 0.35, 0.0))
			else:
				modal_coordinator.open_talents_nexus(station.global_position)
		&"companions_projector":
			modal_coordinator.open_companions_projector(station.global_position)
		&"tactical_console":
			modal_coordinator.open_tactical_console(station.global_position)
		_:
			_set_camera_mode(CameraRigScript.Mode.STATION_FOCUS, station.global_position)


func _on_modal_opened(cam_mode: int, focus_pos: Vector3) -> void:
	if embedded_mode:
		embedded_movement_lock_changed.emit(true)
	elif player != null:
		player.is_movement_locked = true
	if hud != null:
		hud.set_clean_hud_visible(false)
	_set_camera_mode(cam_mode as CameraRigScript.Mode, focus_pos)


func _on_modal_closed() -> void:
	_is_capsule_focused = false
	if _skins_spotlight != null:
		_skins_spotlight.light_energy = 0.65
	if embedded_mode:
		embedded_movement_lock_changed.emit(false)
	elif player != null:
		player.is_movement_locked = false
		player.is_pose_override_active = false
		player.set_closeup_shadow_suppressed(false)
	if hud != null:
		hud.set_clean_hud_visible(true)
	_set_camera_mode(CameraRigScript.Mode.FREE_ROAM)


func _on_pilot_changed(char_id: StringName, accent_col: Color) -> void:
	set_pilot_accent_color(accent_col)
	if embedded_mode:
		embedded_pilot_selected.emit(char_id, accent_col)
	_refresh_hud_status()


func _on_companions_updated() -> void:
	if east_wing != null:
		east_wing.refresh_pets(_get_active_player_node())
	if modal_coordinator != null and right_station != null:
		modal_coordinator.refresh_navigator_hologram(right_station, right_station.get_station_state() != StationNodeScript.StationState.CALIBRATING)
	if embedded_mode:
		embedded_companions_updated.emit()


func _on_gacha_focus_requested(focus_pos: Vector3) -> void:
	if embedded_mode:
		embedded_movement_lock_changed.emit(true)
	elif player != null:
		player.is_movement_locked = true
	if hud != null:
		hud.set_clean_hud_visible(false)
	_set_camera_mode(CameraRigScript.Mode.GACHA_SUMMON_CINEMATIC, focus_pos)


func _on_gacha_focus_exited() -> void:
	if embedded_mode:
		embedded_movement_lock_changed.emit(false)
	elif player != null:
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
	if embedded_mode:
		embedded_gacha_skin_equipped.emit(equip_res)
		return
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
				if _skins_spotlight != null:
					_skins_spotlight.light_energy = 2.45
				player.set_closeup_shadow_suppressed(true)
				player.global_position = left_station.global_position + Vector3(0.0, 0.098, 0.08)
				player.evaluate_platform_traversal(0.0, true)
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
		CameraRigScript.Mode.SEAMLESS_DEPARTURE, CameraRigScript.Mode.IGNITION_LAUNCH:
			if departure_controller != null:
				departure_controller.trigger_radial_departure(Vector2(0.7, -0.7).normalized())
		_:
			exit_capsule_focus()


func _set_camera_mode(mode: CameraRigScript.Mode, focus_pos: Vector3 = Vector3.ZERO) -> void:
	_is_capsule_focused = (mode == CameraRigScript.Mode.CAPSULE_PILOT_FOCUS)
	if player != null and mode == CameraRigScript.Mode.FREE_ROAM and not _is_departure_active():
		player.is_movement_locked = false
	camera_rig.set_mode(mode, focus_pos)
	if embedded_mode:
		embedded_camera_focus_changed.emit(int(mode), focus_pos)
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
	if cosmos_backdrop != null:
		cosmos_backdrop.set_preview_seed(active_launch_request.cosmos_seed, trigger_flash)
	if modal_coordinator != null:
		modal_coordinator.set_active_request(active_launch_request)
	if departure_controller != null:
		departure_controller.set_pending_request(active_launch_request)
	if embedded_mode:
		embedded_launch_request_changed.emit(active_launch_request, trigger_flash)
	_refresh_hud_status()


func sync_embedded_player_3d(pos_3d: Vector3, sample_pos_2d: Vector2, is_flying: bool) -> void:
	_embedded_cosmos_sample_pos_2d = sample_pos_2d
	if _embedded_player_proxy != null:
		_embedded_player_proxy.global_position = pos_3d
	if _embedded_is_flying != is_flying:
		_embedded_is_flying = is_flying
		_refresh_hud_status()


func update_embedded_perimeter_warning(world_3d: Vector3, dir_xz: Vector2, prog: float, sector: Dictionary) -> void:
	_warn_progress_cached = prog
	_warn_sector_cached = sector
	if departure_controller != null:
		departure_controller.update_embedded_compass(world_3d, dir_xz, prog, sector)
	if hud != null:
		hud.update_traversal_telemetry(_embedded_is_flying, prog, sector, _embedded_is_dematerializing)


func start_embedded_dematerialization(origin_3d: Vector3) -> void:
	if _embedded_is_dematerializing:
		return
	_embedded_is_dematerializing = true
	_is_capsule_focused = false
	if hud != null:
		hud.set_clean_hud_visible(false)
	if departure_controller != null:
		departure_controller.start_embedded_dissolve_only(origin_3d)
	else:
		_embedded_is_dematerializing = false
		embedded_demat_finished.emit()


func set_embedded_hidden_for_materialization() -> void:
	_embedded_is_dematerializing = false
	_is_capsule_focused = false
	if hud != null:
		hud.set_clean_hud_visible(false)
	if departure_controller != null:
		departure_controller.set_embedded_hidden_for_materialization()


func play_embedded_materialization(duration_sec: float = 1.25) -> void:
	_embedded_is_dematerializing = false
	if hud != null:
		hud.set_clean_hud_visible(false)
	if departure_controller != null:
		departure_controller.start_embedded_materialization(duration_sec)
	else:
		if hud != null:
			hud.set_clean_hud_visible(true)
		embedded_materialization_finished.emit()


func set_all_stations_state_override(new_state: StationNodeScript.StationState) -> void:
	for st: StationNodeScript in _all_stations():
		st.set_station_state(new_state)
	if modal_coordinator != null and right_station != null:
		modal_coordinator.refresh_navigator_hologram(right_station, new_state != StationNodeScript.StationState.CALIBRATING)
	_refresh_hud_status()


func get_station_materials_for_tutorial(target_id: StringName) -> Dictionary:
	match target_id:
		&"overview":
			return {"world_pos_3d": Vector3.ZERO}
		&"pilot_capsule":
			var p_mats: Array[ShaderMaterial] = []
			for m: ShaderMaterial in _hero_prop_mats + _gold_trim_mats:
				if m != null and not p_mats.has(m):
					p_mats.append(m)
			var o_mats: Array[ShaderMaterial] = []
			if _prop_outline_mat != null:
				o_mats.append(_prop_outline_mat)
			var d_mats: Array[ShaderMaterial] = []
			if _capsule_dais_mat != null:
				d_mats.append(_capsule_dais_mat)
			return {
				"prop_mats": p_mats,
				"outline_mats": o_mats,
				"dais_mats": d_mats,
				"world_pos_3d": config.capsule_pos if config != null else Vector3.ZERO,
			}
		&"skins_mirror", &"tactical_console", &"talents_nexus", &"companions_projector":
			for st: StationNodeScript in _all_stations():
				if st.station_id == target_id:
					var bundle: Dictionary = st.get_tutorial_highlight_materials()
					bundle["world_pos_3d"] = st.global_position if st.is_inside_tree() else st.position
					return bundle
			return {"world_pos_3d": Vector3.ZERO}
		&"gacha_summoner":
			if east_wing != null:
				return east_wing.get_gacha_highlight_bundle()
			return {"world_pos_3d": config.gacha_summoner_pos if config != null else Vector3(15.42, 0.0, 0.0)}
		&"telemetry_totem":
			if east_wing != null:
				return east_wing.get_telemetry_highlight_bundle()
			return {"world_pos_3d": config.telemetry_totem_pos if config != null else Vector3(10.2, 0.0, 10.2)}
		&"west_sanctuary":
			if west_sanctuary != null:
				return west_sanctuary.get_sanctuary_highlight_bundle()
			return {"world_pos_3d": Vector3(-20.4, 0.0, 0.0)}
		&"perimeter_takeoff":
			return {
				"bridge_mats": _bridge_mats.duplicate(),
				"world_pos_3d": Vector3.ZERO,
			}
		_:
			return {"world_pos_3d": Vector3.ZERO}


func is_any_hub_modal_or_panel_open() -> bool:
	if _is_capsule_focused:
		return true
	if settings_modal != null and settings_modal.visible:
		return true
	if east_wing != null and east_wing.is_gacha_open():
		return true
	if modal_coordinator != null and modal_coordinator.is_any_modal_open():
		return true
	return false


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

	for pm: ShaderMaterial in _arch_prop_mats + _hero_prop_mats:
		pm.set_shader_parameter("pilot_accent_color", config.pilot_accent_color)
		pm.set_shader_parameter("crease_ink_strength", config.crease_ink_strength)
		pm.set_shader_parameter("emissive_boost", config.emissive_boost)
	for gm: ShaderMaterial in _gold_trim_mats:
		gm.set_shader_parameter("crease_ink_strength", config.crease_ink_strength)
		gm.set_shader_parameter("emissive_boost", config.emissive_boost)
	for dm: ShaderMaterial in _deck_surface_mats:
		dm.set_shader_parameter("ink_strength", config.ink_strength)
		dm.set_shader_parameter("emissive_boost", config.emissive_boost)
	if _capsule_dais_mat != null:
		_capsule_dais_mat.set_shader_parameter("pilot_accent_color", config.pilot_accent_color)
		_capsule_dais_mat.set_shader_parameter("emissive_boost", config.emissive_boost)
	if _prop_outline_mat != null:
		_prop_outline_mat.set_shader_parameter("outline_width", config.outline_width)
		_prop_outline_mat.set_shader_parameter("reference_distance", config.outline_ref_distance)

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
	_on_dev_back_to_workbench()


func _on_dev_back_to_workbench() -> void:
	return_to_title_screen()


func _update_proximity_prompts() -> void:
	var active_p: Node3D = _get_active_player_node()
	if active_p == null:
		return
	if embedded_mode and _embedded_input_suppressed:
		if _capsule_label != null:
			_capsule_label.visible = false
		for st: StationNodeScript in _all_stations():
			st.set_highlighted(false)
			st.set_prompt_suppressed(true)
		if hud != null:
			hud.set_interaction_prompt("", Color.WHITE, false)
		return
	var is_dissolved: bool = _embedded_is_dematerializing or (departure_controller != null and departure_controller.is_dissolved_preview())
	var is_free_roam: bool = (
		camera_rig.get_mode() == CameraRigScript.Mode.FREE_ROAM
		and not _is_departure_active()
		and not is_dissolved
		and (east_wing == null or not east_wing.is_gacha_open())
		and (modal_coordinator == null or not modal_coordinator.is_any_modal_open())
	)

	var pill_text: String = ""
	var pill_col: Color = Color(0.95, 0.80, 0.34, 1.0)

	var in_capsule: bool = _is_body_near_capsule(active_p)
	if _capsule_label != null:
		_capsule_label.visible = (in_capsule and is_free_roam)
		_capsule_label.modulate = Color(0.96, 0.84, 0.48, 1.0)
	if in_capsule and is_free_roam:
		pill_text = "[E] Cápsula de Piloto (Cambiar Heroína)"
		pill_col = Color(0.96, 0.84, 0.48, 1.0)

	for st: StationNodeScript in _all_stations():
		var inside: bool = st.is_player_inside(active_p)
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
		east_wing.update_proximity(active_p, is_free_roam)
	if west_sanctuary != null:
		west_sanctuary.update_proximity(active_p, is_free_roam)
	if hud != null:
		hud.set_interaction_prompt(pill_text, pill_col, is_free_roam and not pill_text.is_empty())


func _refresh_hud_status() -> void:
	if hud == null:
		return
	var mode_names: Array[String] = ["FREE_ROAM", "CAPSULE", "STATION", "IGNITION", "SKINS", "GACHA", "RELIC", "DEPARTURE"]
	var m_txt: String = mode_names[clampi(int(camera_rig.get_mode()), 0, mode_names.size() - 1)]
	var st_names: Array[String] = ["CALIBRATING", "NEWLY_UNLOCKED", "ONLINE"]
	var st_txt: String = st_names[clampi(int(right_station.get_station_state()), 0, 2)] if right_station != null else "N/A"
	var seed_v: int = (
		active_launch_request.cosmos_seed if (embedded_mode and active_launch_request != null)
		else (cosmos_backdrop.get_preview_seed() if cosmos_backdrop != null else config.default_preview_seed)
	)
	var coord_code: String = active_launch_request.coordinate_code if active_launch_request != null else RunLaunchRequestScript.encode_coordinate_code(seed_v)
	var badge: String = active_launch_request.get_seed_badge_text() if active_launch_request != null else ""

	var cid: StringName = SaveManagerScript.get_selected_character()
	var roster: Dictionary = CharacterDataScript.load_roster()
	var cdata: CharacterData = roster.get(cid, null) as CharacterData
	var pilot_name: String = cdata.display_name if cdata != null else String(cid).capitalize()

	hud.update_status(m_txt, st_txt, seed_v, coord_code, badge, str(_active_progression_preset), pilot_name)
	var is_flying: bool = _embedded_is_flying if embedded_mode else (player != null and player.is_flying_in_space)
	var is_dissolved: bool = _embedded_is_dematerializing if embedded_mode else (departure_controller != null and departure_controller.is_dissolved_preview())
	hud.update_traversal_telemetry(is_flying, _warn_progress_cached, _warn_sector_cached, is_dissolved)


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


func _create_gold_trim_materials() -> Array[ShaderMaterial]:
	var mats: Array[ShaderMaterial] = []
	var cols: Array[Color] = [
		Color(0.92, 0.77, 0.42, 1.0),
		Color(0.14, 0.10, 0.08, 1.0),
		Color(0.24, 0.90, 1.0, 1.0),
	]
	for surf_idx: int in range(3):
		var mat := ShaderMaterial.new()
		mat.shader = PropShader
		mat.next_pass = _prop_outline_mat
		mat.set_shader_parameter("material_kind", surf_idx)
		mat.set_shader_parameter("base_color", cols[surf_idx])
		mat.set_shader_parameter("shadow_tint", Color(0.45, 0.30, 0.14, 1.0))
		mat.set_shader_parameter("rim_color", Color(1.0, 0.94, 0.72, 1.0))
		mat.set_shader_parameter("use_pilot_accent", false)
		mat.set_shader_parameter("pilot_accent_color", cols[2])
		mat.set_shader_parameter("rim_strength", 0.68)
		mat.set_shader_parameter("ambient_fill", 0.34)
		mats.append(mat)
	return mats


func _create_octagon_deck_material(
	plate_tint: Color,
	chassis_tint: Color,
	accent_col: Color,
	deck_r: float = 7.60,
	is_bastion: bool = false,
	bastion_sign: float = 1.0
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = OctagonDeckShader
	mat.set_shader_parameter("deck_radius", deck_r)
	mat.set_shader_parameter("is_bastion_mode", is_bastion)
	mat.set_shader_parameter("bastion_mirror_sign", bastion_sign)
	mat.set_shader_parameter("wing_plate_tint", plate_tint)
	mat.set_shader_parameter("wing_chassis_tint", chassis_tint)
	mat.set_shader_parameter("pilot_accent_color", accent_col)
	if cosmos_backdrop != null and cosmos_backdrop.get_subviewport() != null:
		mat.set_shader_parameter("cosmos_reflection_tex", cosmos_backdrop.get_subviewport().get_texture())
		mat.set_shader_parameter("has_cosmos_reflection", true)
		mat.set_shader_parameter("cosmos_reflection_strength", 0.34)
	return mat


func _create_hq_deck_material(plate_tint: Color, chassis_tint: Color, accent_col: Color) -> ShaderMaterial:
	return _create_octagon_deck_material(plate_tint, chassis_tint, accent_col, 7.60, false, 1.0)


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
