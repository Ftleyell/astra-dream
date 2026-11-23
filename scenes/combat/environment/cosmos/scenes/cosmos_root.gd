class_name CosmosRootNode
extends Node2D

const CosmicPoiConfig = preload("res://scenes/combat/environment/cosmos/resources/cosmic_poi_config.gd")
const CosmicPoiRegistry = preload("res://scenes/combat/environment/cosmos/core/cosmic_poi_registry.gd")
const CosmosViewportCanvasTracker = preload("res://scenes/combat/environment/cosmos/core/viewport_canvas_tracker.gd")

## Escena Raíz y Orquestador de Cosmos Engine.
## Unifica los 6 estratos cósmicos analíticos y Parallax2D en Godot 4:
## 1. ParallaxNebulaDeep: Shader universe_nebula.gdshader en CanvasLayer de fondo o Parallax ultralento.
## 2. ParallaxMacroGalaxies: CosmosGalaxyStreamer2D en capa de muy bajo factor (0.02).
## 3. ParallaxStarfield8K: Textura estelar 8K anti-tiling / espacio profundo en Parallax intermedio-bajo (0.05).
## 4. ParallaxSolarSystems: CosmosSolarSystemStreamer en estrato astronómico medio (0.20).
## 5. ParallaxDebrisBelt: CosmosDebrisStreamer2D con MultiMesh en GPU (0.50).
## 6. GameplayWorld: Entidades de combate/exploración interactiva (1.00).
##
## Administra el tiempo global cósmico (global_time) y sincroniza prioridades
## de proceso con CosmosFloatingOriginTracker para garantizar cero micro-saltos.

signal origin_shifted(shift_vector: Vector2)
signal solar_system_streamed(system: CosmosSolarSystem2D, cell: Vector2i)
signal solar_system_unstreamed(system: CosmosSolarSystem2D, cell: Vector2i)
signal non_stellar_sector_streamed(sector: CosmosDeepSpaceSector2D, cell: Vector2i)
signal non_stellar_sector_unstreamed(sector: CosmosDeepSpaceSector2D, cell: Vector2i)

@export var camera: Camera2D
@export var player_target: Node2D
@export var floating_origin_tracker: CosmosFloatingOriginTracker
@export var viewport_tracker: CosmosViewportCanvasTracker
@export var time_scale: float = 1.0:
	set(v):
		time_scale = v
		if solar_streamer != null and is_instance_valid(solar_streamer):
			solar_streamer.time_scale = v
		if non_stellar_streamer != null and is_instance_valid(non_stellar_streamer):
			non_stellar_streamer.time_scale = v
		if corridor_controller != null and is_instance_valid(corridor_controller):
			corridor_controller.time_scale = v
@export var is_frozen: bool = false:
	set(v):
		is_frozen = v
		_propagate_freeze_state(v)

var _orbit_guides_visible: bool = false

@export_group("Perfil de Entorno Data-Driven")
@export var environment_profile: CosmosEnvProfile:
	set(v):
		if environment_profile != null and environment_profile.changed.is_connected(apply_environment_profile):
			environment_profile.changed.disconnect(apply_environment_profile)
		environment_profile = v
		if environment_profile != null:
			if not environment_profile.changed.is_connected(apply_environment_profile):
				environment_profile.changed.connect(apply_environment_profile)
			apply_environment_profile()

# Referencias a Estratos Cósmicos
@export_group("Estratos Cósmicos")
@export var nebula_controller: CosmosNebulaBackdropController
@export var parallax_macro_galaxies: Parallax2D
@export var galaxy_streamer: CosmosGalaxyStreamer2D
@export var parallax_starfield_8k: CanvasItem
@export var parallax_solar_systems: Parallax2D
@export var solar_streamer: CosmosSolarSystemStreamer
@export var non_stellar_streamer: CosmosNonStellarStreamer2D
@export var corridor_controller: CosmosInterstellarCorridorController2D
@export var parallax_debris_far: Parallax2D
@export var debris_far_streamer: CosmosDebrisStreamer2D
@export var parallax_debris_belt: Parallax2D
@export var debris_streamer: CosmosDebrisStreamer2D
@export var atmosphere_layers: CosmosAtmosphereLayersController

var poi_registry: CosmicPoiRegistry = CosmicPoiRegistry.new()
var _global_time: float = 0.0
var _origin_shift_count: int = 0
var _accumulated_shift: Vector2 = Vector2.ZERO
var _starfield_mat: ShaderMaterial = null
var _quality_level: int = 2
var _screen_planet_occluders: Array[Vector4] = []
var _prev_player_world_pos: Vector2 = Vector2.ZERO
var _has_prev_player_pos: bool = false
var _smoothed_player_vel: Vector2 = Vector2.ZERO
var _prev_inside_domain: bool = false
var _domain_entry_pulse: float = 0.0

var _player_aura_color: Color = Color(0.98, 0.16, 0.34, 1.0)
var _player_aura_world_offset: Vector2 = Vector2(0.0, -20.0)
var _player_aura_world_radius: float = 220.0
var _player_aura_energy: float = 1.0
var _player_aura_wing_axis: Vector2 = Vector2(1.0, 0.0)

var _nearest_star_dists: PackedFloat32Array = PackedFloat32Array([INF, INF, INF, INF])
var _nearest_star_pos: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _nearest_star_col: PackedColorArray = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
var _nearest_star_rad: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
var _out_star_pos: PackedVector2Array = PackedVector2Array()
var _out_star_col: PackedColorArray = PackedColorArray()
var _out_star_rad: PackedFloat32Array = PackedFloat32Array()

var _has_smoothed_dom_star: bool = false
var _smooth_dom_star_screen: Vector2 = Vector2.ZERO
var _smooth_dom_star_uv: Vector2 = Vector2(0.5, 0.5)
var _smooth_dom_star_color: Color = Color.WHITE
var _smooth_dom_star_inf: float = 0.0
var _smooth_dom_light_dir: Vector2 = Vector2(0.85, -0.52)
var _smooth_dom_heliopause_uv_r: float = 1.2

## Configura la luz local que emiten las alas/skin de la piloto sobre polvo y sombras sin acoplar a escenas externas.
func set_player_aura_light(
	p_color: Color,
	p_world_offset: Vector2 = Vector2(0.0, -20.0),
	p_world_radius: float = 220.0,
	p_energy: float = 1.0,
	p_wing_axis: Vector2 = Vector2(1.0, 0.0)
) -> void:
	_player_aura_color = p_color
	_player_aura_world_offset = p_world_offset
	_player_aura_world_radius = maxf(p_world_radius, 40.0)
	_player_aura_energy = clampf(p_energy, 0.0, 2.5)
	_player_aura_wing_axis = p_wing_axis.normalized() if p_wing_axis.length_squared() > 0.0001 else Vector2(1.0, 0.0)

func _ensure_screen_occluder_buf() -> void:
	if _screen_planet_occluders.size() == 6:
		return
	_screen_planet_occluders.resize(6)
	for i: int in range(6):
		_screen_planet_occluders[i] = Vector4.ZERO

func _propagate_freeze_state(frozen: bool) -> void:
	if nebula_controller != null and is_instance_valid(nebula_controller):
		nebula_controller.is_frozen = frozen
	if solar_streamer != null and is_instance_valid(solar_streamer):
		solar_streamer.is_frozen = frozen
	if non_stellar_streamer != null and is_instance_valid(non_stellar_streamer):
		non_stellar_streamer.is_frozen = frozen
	if corridor_controller != null and is_instance_valid(corridor_controller):
		corridor_controller.is_frozen = frozen
	if debris_far_streamer != null and is_instance_valid(debris_far_streamer):
		debris_far_streamer.is_frozen = frozen or (_quality_level < 1)
	if debris_streamer != null and is_instance_valid(debris_streamer):
		debris_streamer.is_frozen = frozen
	if galaxy_streamer != null and is_instance_valid(galaxy_streamer):
		galaxy_streamer.is_frozen = frozen
	if parallax_starfield_8k != null and is_instance_valid(parallax_starfield_8k):
		if parallax_starfield_8k is CosmosStarfieldBackdropController:
			(parallax_starfield_8k as CosmosStarfieldBackdropController).is_frozen = frozen

func _ready() -> void:
	# Prioridad de proceso: CosmosRootNode orquesta el tiempo y el tracker se procesa antes del render
	process_priority = -100
	add_to_group(&"cosmos_root")
	_propagate_freeze_state(is_frozen)
	_setup_viewport_tracker()
	_setup_floating_origin()
	_sync_poi_registry()
	bind_camera_to_streamers()
	_setup_solar_streamer_signals()
	_cache_starfield_material()
	if atmosphere_layers == null:
		atmosphere_layers = get_node_or_null("CosmosAtmosphereLayersController") as CosmosAtmosphereLayersController
	_init_environment_profile()
	_setup_settings_listener()


func _setup_viewport_tracker() -> void:
	if viewport_tracker == null:
		viewport_tracker = get_node_or_null("CosmosViewportCanvasTracker") as CosmosViewportCanvasTracker
	if viewport_tracker == null:
		# Instanciar dinámicamente si no existe en el árbol de escena
		viewport_tracker = CosmosViewportCanvasTracker.new()
		viewport_tracker.name = "CosmosViewportCanvasTracker"
		add_child(viewport_tracker)
	if not viewport_tracker.viewport_updated.is_connected(_on_viewport_updated):
		viewport_tracker.viewport_updated.connect(_on_viewport_updated)

func _init_environment_profile() -> void:
	if environment_profile == null:
		var default_res: CosmosEnvProfile = load("res://scenes/combat/environment/cosmos/resources/data/default_cosmos_environment.tres") as CosmosEnvProfile
		if default_res != null:
			environment_profile = default_res
	elif not environment_profile.changed.is_connected(apply_environment_profile):
		environment_profile.changed.connect(apply_environment_profile)
	
	if environment_profile != null:
		apply_environment_profile()

## Propaga reactivamente todos los parámetros del perfil a los estratos de Parallax y Shaders
func apply_environment_profile() -> void:
	if environment_profile == null:
		return

	var mult: float = environment_profile.parallax_multiplier

	# 1. Estratos de Paralaje
	if nebula_controller != null and is_instance_valid(nebula_controller):
		nebula_controller.parallax_factor = environment_profile.nebula_parallax_factor * mult
		if environment_profile.biome_a_profile != null:
			nebula_controller.biome_a = environment_profile.biome_a_profile
		if environment_profile.biome_b_profile != null:
			nebula_controller.biome_b = environment_profile.biome_b_profile
		nebula_controller.biome_blend_factor = environment_profile.biome_blend_factor
		nebula_controller.apply_biome_configurations()

		var n_mat: ShaderMaterial = nebula_controller.material as ShaderMaterial
		if n_mat != null:
			n_mat.set_shader_parameter("deep_stars_intensity", environment_profile.nebula_deep_stars_intensity)
			n_mat.set_shader_parameter("deep_stars_scale", environment_profile.nebula_deep_stars_scale)
			n_mat.set_shader_parameter("deep_stars_parallax", environment_profile.nebula_deep_stars_parallax)
			n_mat.set_shader_parameter("deep_stars_twinkle_speed", environment_profile.nebula_deep_stars_twinkle_speed)
			n_mat.set_shader_parameter("deep_stars_sparkle_intensity", environment_profile.nebula_deep_stars_sparkle_intensity)
			n_mat.set_shader_parameter("deep_stars_halo_radius", environment_profile.nebula_deep_stars_halo_radius)
			n_mat.set_shader_parameter("deep_stars_gas_interaction", environment_profile.nebula_deep_stars_gas_interaction)
			n_mat.set_shader_parameter("mid_stars_intensity", environment_profile.nebula_mid_stars_intensity)
			n_mat.set_shader_parameter("mid_stars_scale", environment_profile.nebula_mid_stars_scale)
			n_mat.set_shader_parameter("mid_stars_parallax", environment_profile.nebula_mid_stars_parallax)
			n_mat.set_shader_parameter("mid_stars_twinkle_speed", environment_profile.nebula_mid_stars_twinkle_speed)
			n_mat.set_shader_parameter("mid_stars_sparkle_intensity", environment_profile.nebula_mid_stars_sparkle_intensity)
			n_mat.set_shader_parameter("mid_stars_halo_radius", environment_profile.nebula_mid_stars_halo_radius)
			n_mat.set_shader_parameter("mid_stars_gas_interaction", environment_profile.nebula_mid_stars_gas_interaction)
			n_mat.set_shader_parameter("nebula_tile_mix", environment_profile.nebula_tile_mix)
			n_mat.set_shader_parameter("nebula_tile_scale", environment_profile.nebula_tile_scale)

	if parallax_macro_galaxies != null and is_instance_valid(parallax_macro_galaxies):
		parallax_macro_galaxies.scroll_scale = environment_profile.galaxy_scroll_scale * mult
	if galaxy_streamer != null and is_instance_valid(galaxy_streamer) and environment_profile.galaxy_profile != null:
		galaxy_streamer.landmark_profile = environment_profile.galaxy_profile

	if parallax_starfield_8k != null and is_instance_valid(parallax_starfield_8k):
		parallax_starfield_8k.scroll_scale = environment_profile.starfield_scroll_scale * mult

	if _starfield_mat != null:
		var biome_energy: float = environment_profile.biome_a_profile.starfield_energy if environment_profile.biome_a_profile != null else 1.0
		_starfield_mat.set_shader_parameter("star_intensity", environment_profile.star_intensity * biome_energy)
		_starfield_mat.set_shader_parameter("threshold_cutoff", environment_profile.star_threshold_cutoff)
		_starfield_mat.set_shader_parameter("window_scale", environment_profile.star_window_scale)
		_starfield_mat.set_shader_parameter("twinkle_amount", environment_profile.star_twinkle_amount)
		_starfield_mat.set_shader_parameter("twinkle_speed", environment_profile.star_twinkle_speed)
		_starfield_mat.set_shader_parameter("lens_flare_intensity", environment_profile.star_lens_flare_intensity)
		_starfield_mat.set_shader_parameter("lens_flare_length", environment_profile.star_lens_flare_length)

	if parallax_solar_systems != null and is_instance_valid(parallax_solar_systems):
		parallax_solar_systems.scroll_scale = environment_profile.solar_scroll_scale * mult
	if solar_streamer != null and is_instance_valid(solar_streamer) and environment_profile.solar_profile != null:
		solar_streamer.system_profile = environment_profile.solar_profile
	if non_stellar_streamer != null and is_instance_valid(non_stellar_streamer):
		if environment_profile.solar_profile != null:
			non_stellar_streamer.system_profile = environment_profile.solar_profile
		if environment_profile.debris_profile != null:
			non_stellar_streamer.debris_profile = environment_profile.debris_profile
		if environment_profile.living_universe_profile != null:
			non_stellar_streamer.living_config = environment_profile.living_universe_profile
		if solar_streamer != null and non_stellar_streamer.solar_streamer == null:
			non_stellar_streamer.solar_streamer = solar_streamer
	if corridor_controller != null and is_instance_valid(corridor_controller):
		if environment_profile.solar_profile != null:
			corridor_controller.system_profile = environment_profile.solar_profile
		if environment_profile.living_universe_profile != null:
			corridor_controller.living_config = environment_profile.living_universe_profile
		if solar_streamer != null and corridor_controller.solar_streamer == null:
			corridor_controller.solar_streamer = solar_streamer
		if non_stellar_streamer != null and corridor_controller.non_stellar_streamer == null:
			corridor_controller.non_stellar_streamer = non_stellar_streamer

	if parallax_debris_far != null and is_instance_valid(parallax_debris_far):
		parallax_debris_far.scroll_scale = Vector2(0.18, 0.18) * mult
	if parallax_debris_belt != null and is_instance_valid(parallax_debris_belt):
		parallax_debris_belt.scroll_scale = environment_profile.debris_scroll_scale * mult
	if debris_streamer != null and is_instance_valid(debris_streamer):
		if environment_profile.debris_profile != null:
			debris_streamer.profile = environment_profile.debris_profile
		if environment_profile.solar_profile != null:
			debris_streamer.celestial_profile = environment_profile.solar_profile

## Control de visibilidad por estrato cósmico (1: Nebulosa, 2: Starfield, 3: Galaxias, 4: Solar, 5: Debris)
func set_layer_visibility(layer_index: int, is_visible: bool) -> void:
	match layer_index:
		1:
			if nebula_controller != null and is_instance_valid(nebula_controller):
				var parent_node: CanvasLayer = nebula_controller.get_parent() as CanvasLayer
				if parent_node != null:
					parent_node.visible = is_visible
				else:
					nebula_controller.visible = is_visible
		2:
			if parallax_starfield_8k != null and is_instance_valid(parallax_starfield_8k):
				var parent_node: CanvasLayer = parallax_starfield_8k.get_parent() as CanvasLayer
				if parent_node != null:
					parent_node.visible = is_visible
				else:
					parallax_starfield_8k.visible = is_visible
		3:
			if parallax_macro_galaxies != null and is_instance_valid(parallax_macro_galaxies):
				parallax_macro_galaxies.visible = is_visible
		4:
			if parallax_solar_systems != null and is_instance_valid(parallax_solar_systems):
				parallax_solar_systems.visible = is_visible
		5:
			if parallax_debris_belt != null and is_instance_valid(parallax_debris_belt):
				parallax_debris_belt.visible = is_visible
			if parallax_debris_far != null and is_instance_valid(parallax_debris_far):
				parallax_debris_far.visible = is_visible and (_quality_level >= 1)

func get_layer_visibility(layer_index: int) -> bool:
	match layer_index:
		1:
			if nebula_controller != null and is_instance_valid(nebula_controller):
				var parent_node: CanvasLayer = nebula_controller.get_parent() as CanvasLayer
				return parent_node.visible if parent_node != null else nebula_controller.visible
			return false
		2:
			if parallax_starfield_8k != null and is_instance_valid(parallax_starfield_8k):
				var parent_node: CanvasLayer = parallax_starfield_8k.get_parent() as CanvasLayer
				return parent_node.visible if parent_node != null else parallax_starfield_8k.visible
			return false
		3:
			return parallax_macro_galaxies.visible if parallax_macro_galaxies != null and is_instance_valid(parallax_macro_galaxies) else false
		4:
			return parallax_solar_systems.visible if parallax_solar_systems != null and is_instance_valid(parallax_solar_systems) else false
		5:
			return parallax_debris_belt.visible if parallax_debris_belt != null and is_instance_valid(parallax_debris_belt) else false
	return false

func toggle_layer_visibility(layer_index: int) -> bool:
	var current: bool = get_layer_visibility(layer_index)
	set_layer_visibility(layer_index, not current)
	return not current

func _cache_starfield_material() -> void:
	if parallax_starfield_8k != null:
		if parallax_starfield_8k is ColorRect:
			_starfield_mat = (parallax_starfield_8k as ColorRect).material as ShaderMaterial
		else:
			var sprite: Sprite2D = parallax_starfield_8k.get_node_or_null("StarfieldSprite") as Sprite2D
			if sprite != null and sprite.material is ShaderMaterial:
				_starfield_mat = sprite.material as ShaderMaterial

func _setup_floating_origin() -> void:
	if floating_origin_tracker == null:
		floating_origin_tracker = get_node_or_null("CosmosFloatingOriginTracker") as CosmosFloatingOriginTracker

	if floating_origin_tracker != null:
		var tree := get_tree()
		var is_combat: bool = (tree.get_first_node_in_group("bullet_server") != null or tree.get_first_node_in_group("main_game") != null) if tree else false
		if is_combat:
			push_warning("CosmosRootNode: FloatingOriginTracker deshabilitado en combate para proteger la memoria física contigua de BulletServer.")
			floating_origin_tracker.is_enabled = false
			floating_origin_tracker.set_physics_process(false)
			floating_origin_tracker.set_process(false)
			floating_origin_tracker = null
			return

		if floating_origin_tracker.viewport_tracker == null and viewport_tracker != null:
			floating_origin_tracker.viewport_tracker = viewport_tracker
		# Establecer prioridad de proceso del tracker previa a los renders
		floating_origin_tracker.process_priority = -50
		if not floating_origin_tracker.origin_shifted.is_connected(_on_floating_origin_shifted):
			floating_origin_tracker.origin_shifted.connect(_on_floating_origin_shifted)

		# Registrar capas de paralaje si no están asignadas
		if floating_origin_tracker.parallax_layers.is_empty():
			var layers: Array[Parallax2D] = []
			if parallax_macro_galaxies != null:
				layers.append(parallax_macro_galaxies)
			if parallax_starfield_8k is Parallax2D:
				layers.append(parallax_starfield_8k as Parallax2D)
			if parallax_solar_systems != null:
				layers.append(parallax_solar_systems)
			if parallax_debris_far != null:
				layers.append(parallax_debris_far)
			if parallax_debris_belt != null:
				layers.append(parallax_debris_belt)
			floating_origin_tracker.parallax_layers = layers

func bind_camera_to_streamers() -> void:
	if camera == null:
		return
	_sync_poi_registry()
	if galaxy_streamer != null and galaxy_streamer.camera == null:
		galaxy_streamer.camera = camera
	if solar_streamer != null:
		solar_streamer.time_scale = time_scale
		solar_streamer.set_orbit_guides_visible(_orbit_guides_visible)
		if solar_streamer.camera == null:
			solar_streamer.camera = camera
			solar_streamer._update_streaming_and_orbits(_global_time)
	if non_stellar_streamer != null:
		non_stellar_streamer.time_scale = time_scale
		non_stellar_streamer.set_orbit_guides_visible(_orbit_guides_visible)
		if solar_streamer != null and non_stellar_streamer.solar_streamer == null:
			non_stellar_streamer.solar_streamer = solar_streamer
		if non_stellar_streamer.camera == null:
			non_stellar_streamer.camera = camera
			non_stellar_streamer._update_streaming_and_sectors(_global_time)
	if corridor_controller != null:
		corridor_controller.time_scale = time_scale
		corridor_controller.set_orbit_guides_visible(_orbit_guides_visible)
		if solar_streamer != null and corridor_controller.solar_streamer == null:
			corridor_controller.solar_streamer = solar_streamer
		if non_stellar_streamer != null and corridor_controller.non_stellar_streamer == null:
			corridor_controller.non_stellar_streamer = non_stellar_streamer
		if corridor_controller.camera == null:
			corridor_controller.camera = camera
			corridor_controller.update_corridors(_global_time)
	if debris_far_streamer != null and debris_far_streamer.camera == null:
		debris_far_streamer.camera = camera
	if debris_streamer != null:
		if debris_streamer.camera == null:
			debris_streamer.camera = camera
		if solar_streamer != null and debris_streamer.solar_streamer == null:
			debris_streamer.solar_streamer = solar_streamer
	if nebula_controller != null and nebula_controller.camera == null:
		nebula_controller.camera = camera
	if parallax_starfield_8k != null and parallax_starfield_8k is CosmosStarfieldBackdropController:
		var star_ctrl: CosmosStarfieldBackdropController = parallax_starfield_8k as CosmosStarfieldBackdropController
		if star_ctrl.camera == null:
			star_ctrl.camera = camera

func set_orbit_guides_visible(p_visible: bool) -> void:
	_orbit_guides_visible = p_visible
	if solar_streamer != null and is_instance_valid(solar_streamer):
		solar_streamer.set_orbit_guides_visible(p_visible)
	if non_stellar_streamer != null and is_instance_valid(non_stellar_streamer):
		non_stellar_streamer.set_orbit_guides_visible(p_visible)
	if corridor_controller != null and is_instance_valid(corridor_controller):
		corridor_controller.set_orbit_guides_visible(p_visible)

func is_orbit_guides_visible() -> bool:
	return _orbit_guides_visible

func _bind_camera_to_streamers() -> void:
	bind_camera_to_streamers()

func _setup_settings_listener() -> void:
	var tree := get_tree()
	if tree != null and tree.root != null and tree.root.has_node("SettingsManager"):
		var sm: Node = tree.root.get_node("SettingsManager")
		if sm != null:
			if sm.has_signal("settings_changed") and not sm.settings_changed.is_connected(_on_settings_manager_changed):
				sm.settings_changed.connect(_on_settings_manager_changed)
			if "space_background_quality" in sm:
				apply_graphics_quality(int(sm.space_background_quality))

func _on_settings_manager_changed() -> void:
	var tree := get_tree()
	if tree != null and tree.root != null and tree.root.has_node("SettingsManager"):
		var sm: Node = tree.root.get_node("SettingsManager")
		if sm != null and "space_background_quality" in sm:
			apply_graphics_quality(int(sm.space_background_quality))

func apply_graphics_quality(quality_level: int) -> void:
	_quality_level = clampi(quality_level, 0, 2)
	var show_starfield: bool = (_quality_level >= 2)
	if parallax_starfield_8k != null and is_instance_valid(parallax_starfield_8k):
		parallax_starfield_8k.visible = show_starfield
		var parent_node: Node = parallax_starfield_8k.get_parent()
		if parent_node is CanvasLayer:
			(parent_node as CanvasLayer).visible = show_starfield
	if _starfield_mat != null:
		_starfield_mat.set_shader_parameter("hero_sparkle_intensity", 0.85 if _quality_level >= 2 else 0.0)

	if parallax_debris_far != null and is_instance_valid(parallax_debris_far):
		parallax_debris_far.visible = (_quality_level >= 1)
	if debris_far_streamer != null and is_instance_valid(debris_far_streamer):
		debris_far_streamer.is_frozen = is_frozen or (_quality_level < 1)

	var dispersion: float = 0.004 if _quality_level >= 2 else 0.0
	if nebula_controller != null and is_instance_valid(nebula_controller) and nebula_controller.material is ShaderMaterial:
		var n_mat: ShaderMaterial = nebula_controller.material as ShaderMaterial
		n_mat.set_shader_parameter("chromatic_dispersion", dispersion)
		var sparkle: float = 0.85 if _quality_level >= 1 else 0.0
		n_mat.set_shader_parameter("deep_stars_sparkle_intensity", sparkle)

	if atmosphere_layers != null and is_instance_valid(atmosphere_layers):
		atmosphere_layers.apply_graphics_quality(_quality_level)
	if solar_streamer != null and is_instance_valid(solar_streamer):
		solar_streamer.apply_graphics_quality(_quality_level)
	if non_stellar_streamer != null and is_instance_valid(non_stellar_streamer):
		non_stellar_streamer.apply_graphics_quality(_quality_level)
	if corridor_controller != null and is_instance_valid(corridor_controller):
		corridor_controller.apply_graphics_quality(_quality_level)


func _on_viewport_updated(center_world_pos: Vector2, zoom: Vector2, _rotation_rad: float) -> void:
	if solar_streamer != null:
		solar_streamer.set_camera_override(center_world_pos, zoom)
	if non_stellar_streamer != null:
		non_stellar_streamer.set_camera_override(center_world_pos, zoom)
	if corridor_controller != null:
		corridor_controller.set_camera_override(center_world_pos, zoom)
	if galaxy_streamer != null:
		galaxy_streamer.set_camera_override(center_world_pos, zoom)
	if debris_far_streamer != null:
		debris_far_streamer.set_camera_override(center_world_pos, zoom)
	if debris_streamer != null:
		debris_streamer.set_camera_override(center_world_pos, zoom)
	if nebula_controller != null:
		nebula_controller.set_world_view_position(center_world_pos)
	if parallax_starfield_8k != null and parallax_starfield_8k.has_method("set_world_view_position"):
		parallax_starfield_8k.call("set_world_view_position", center_world_pos)

func _setup_solar_streamer_signals() -> void:
	if solar_streamer != null:
		if not solar_streamer.system_streamed.is_connected(_on_solar_system_streamed):
			solar_streamer.system_streamed.connect(_on_solar_system_streamed)
		if not solar_streamer.system_unstreamed.is_connected(_on_solar_system_unstreamed):
			solar_streamer.system_unstreamed.connect(_on_solar_system_unstreamed)
	if non_stellar_streamer != null:
		if not non_stellar_streamer.sector_streamed.is_connected(_on_non_stellar_sector_streamed):
			non_stellar_streamer.sector_streamed.connect(_on_non_stellar_sector_streamed)
		if not non_stellar_streamer.sector_unstreamed.is_connected(_on_non_stellar_sector_unstreamed):
			non_stellar_streamer.sector_unstreamed.connect(_on_non_stellar_sector_unstreamed)

func _on_solar_system_streamed(system: CosmosSolarSystem2D, cell: Vector2i) -> void:
	solar_system_streamed.emit(system, cell)

func _on_solar_system_unstreamed(system: CosmosSolarSystem2D, cell: Vector2i) -> void:
	solar_system_unstreamed.emit(system, cell)

func _on_non_stellar_sector_streamed(sector: CosmosDeepSpaceSector2D, cell: Vector2i) -> void:
	non_stellar_sector_streamed.emit(sector, cell)

func _on_non_stellar_sector_unstreamed(sector: CosmosDeepSpaceSector2D, cell: Vector2i) -> void:
	non_stellar_sector_unstreamed.emit(sector, cell)

func _sync_poi_registry() -> void:
	if poi_registry == null:
		poi_registry = CosmicPoiRegistry.new()
	if solar_streamer != null and solar_streamer.poi_registry != poi_registry:
		solar_streamer.poi_registry = poi_registry
	if non_stellar_streamer != null and non_stellar_streamer.poi_registry != poi_registry:
		non_stellar_streamer.poi_registry = poi_registry
	if galaxy_streamer != null and galaxy_streamer.poi_registry != poi_registry:
		galaxy_streamer.poi_registry = poi_registry

## Registra un POI narrativo en coordenadas absolutas del macro-grid.
func register_poi(coord: Vector2i, config: CosmicPoiConfig) -> void:
	_sync_poi_registry()
	poi_registry.register_poi(coord, config)

## Registra un POI narrativo en coordenadas relativas a un origen de celda dado.
func register_relative_poi(offset: Vector2i, config: CosmicPoiConfig, current_origin: Vector2i) -> Vector2i:
	_sync_poi_registry()
	return poi_registry.register_relative_poi(offset, config, current_origin)

## Configura la semilla aleatoria/determinista en todos los streamers cósmicos hijos
func set_run_seed(p_seed: int) -> void:
	if solar_streamer != null and is_instance_valid(solar_streamer):
		solar_streamer.set_run_seed(p_seed)
	if non_stellar_streamer != null and is_instance_valid(non_stellar_streamer):
		non_stellar_streamer.set_run_seed(p_seed)
	if corridor_controller != null and is_instance_valid(corridor_controller):
		corridor_controller.set_run_seed(p_seed)
	if galaxy_streamer != null and is_instance_valid(galaxy_streamer):
		galaxy_streamer.set_run_seed(p_seed)
	if debris_far_streamer != null and is_instance_valid(debris_far_streamer):
		debris_far_streamer.set_run_seed(p_seed ^ 0x4F2A)
	if debris_streamer != null and is_instance_valid(debris_streamer):
		debris_streamer.set_run_seed(p_seed)

## Limpia todos los POIs registrados devolviendo el streaming al comportamiento 100% procedural.
func clear_poi_overrides() -> void:
	if poi_registry != null:
		poi_registry.clear_overrides()

func has_poi(coord: Vector2i) -> bool:
	return poi_registry.has_poi(coord) if poi_registry != null else false

func get_poi(coord: Vector2i) -> CosmicPoiConfig:
	return poi_registry.get_poi(coord) if poi_registry != null else null

var _prev_dom_system_id: int = 0
var _empty_v2: PackedVector2Array = PackedVector2Array()
var _empty_col: PackedColorArray = PackedColorArray()
var _empty_f32: PackedFloat32Array = PackedFloat32Array()

func _process(delta: float) -> void:
	if is_frozen:
		return
	var delta_time: float = delta * time_scale
	_global_time += delta_time

	# Actualizar tiempo en controladores que dependen de tiempo global continuo
	if nebula_controller != null and is_instance_valid(nebula_controller):
		var mat: ShaderMaterial = nebula_controller.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("global_time", _global_time)
		_sync_active_star_lights_to_nebula(delta_time)

	if galaxy_streamer != null and is_instance_valid(galaxy_streamer):
		galaxy_streamer.update_global_time(_global_time)

	if _starfield_mat != null:
		_starfield_mat.set_shader_parameter("global_time", _global_time)

## Transmite las posiciones cósmicas absolutas, colores y alcance de iluminación de los soles activos a la nebulosa de fondo
## Además, interpola suavemente el bioma de la nebulosa al entrar/salir de la órbita del sol más cercano
func _sync_active_star_lights_to_nebula(delta: float) -> void:
	if solar_streamer == null or nebula_controller == null:
		return
	var active_systems: Dictionary = solar_streamer.get_active_systems()
	if active_systems.is_empty():
		nebula_controller.update_star_lights(_empty_v2, _empty_col, _empty_f32)
		nebula_controller.set_blend_factor(move_toward(nebula_controller.biome_blend_factor, 0.0, delta * 1.5))
		_has_smoothed_dom_star = false
		_prev_dom_system_id = 0
		_update_atmosphere_layers(Vector2.ZERO, Color.WHITE, 0.0)
		return

	var zoom_val: float = 1.0
	if viewport_tracker != null:
		zoom_val = viewport_tracker.current_zoom.x
	elif camera != null and camera.zoom.x > 0.0001:
		zoom_val = camera.zoom.x

	# Punto de referencia de la nave/cámara/viewport en espacio de coordenadas globales
	var player_world_pos: Vector2 = Vector2.ZERO
	if player_target != null and is_instance_valid(player_target):
		player_world_pos = player_target.global_position
	elif viewport_tracker != null:
		player_world_pos = viewport_tracker.current_center
	elif camera != null:
		player_world_pos = camera.global_position

	for k: int in range(4):
		_nearest_star_dists[k] = INF
	var nearest_count: int = 0

	var target_influence: float = 0.0
	var closest_biome: CosmosBiomeConfig = null
	var dominant_star_screen := Vector2.ZERO
	var dominant_star_world_pos: Vector2 = player_world_pos + Vector2(850.0, -520.0)
	var dominant_star_color := Color.WHITE
	var dominant_system: CosmosSolarSystem2D = null
	var dominant_is_black_hole: bool = false
	var dominant_light_rad: float = 2400.0
	var max_star_inf: float = 0.0

	for cell_coords: Vector2i in active_systems.keys():
		var sys: CosmosSolarSystem2D = active_systems[cell_coords] as CosmosSolarSystem2D
		if sys == null or not sys.visible:
			continue

		var arch: CosmosStarArchetype = sys.active_archetype
		var star_col: Color = arch.star_color if arch != null else (sys.system_profile.star_emission_color if sys.system_profile != null else Color.WHITE)
		var orbit_max: float = arch.orbit_radius_max if arch != null else 2400.0
		var light_rad: float = maxf(sys.get_light_field_radius() * 1.12, orbit_max * 1.15)

		# Posición exacta del centro del sol en pantalla (viewport space 1:1) y radio aparente
		var star_item: CanvasItem = sys.star_body if (sys.star_body != null and is_instance_valid(sys.star_body)) else sys
		var sun_screen_pos: Vector2 = star_item.get_global_transform_with_canvas().origin
		var sun_screen_radius: float = light_rad * zoom_val

		var dist_to_sun: float = player_world_pos.distance_to(star_item.global_position)
		if dist_to_sun < _nearest_star_dists[3]:
			var ins_idx: int = mini(nearest_count, 3)
			while ins_idx > 0 and dist_to_sun < _nearest_star_dists[ins_idx - 1]:
				_nearest_star_dists[ins_idx] = _nearest_star_dists[ins_idx - 1]
				_nearest_star_pos[ins_idx] = _nearest_star_pos[ins_idx - 1]
				_nearest_star_col[ins_idx] = _nearest_star_col[ins_idx - 1]
				_nearest_star_rad[ins_idx] = _nearest_star_rad[ins_idx - 1]
				ins_idx -= 1
			_nearest_star_dists[ins_idx] = dist_to_sun
			_nearest_star_pos[ins_idx] = sun_screen_pos
			_nearest_star_col[ins_idx] = star_col
			_nearest_star_rad[ins_idx] = sun_screen_radius
			if nearest_count < 4:
				nearest_count += 1

		var star_prox: float = clampf(1.0 - dist_to_sun / maxf(light_rad, 1.0), 0.0, 1.0)
		if star_prox > max_star_inf:
			max_star_inf = star_prox
			dominant_star_screen = sun_screen_pos
			dominant_star_world_pos = star_item.global_position
			dominant_star_color = star_col
			dominant_system = sys
			dominant_light_rad = light_rad
			dominant_is_black_hole = (arch != null and arch.get_effective_visual_config().star_signature_mode == 3)
		var transition_outer: float = orbit_max * 1.10
		var transition_inner: float = orbit_max * 0.85
		if dist_to_sun < transition_outer:
			var influence: float = clampf((transition_outer - dist_to_sun) / (transition_outer - transition_inner), 0.0, 1.0)
			if influence > target_influence:
				target_influence = influence
				if arch != null and arch.biome_config != null:
					closest_biome = arch.biome_config

	if _out_star_pos.size() != nearest_count:
		_out_star_pos.resize(nearest_count)
		_out_star_col.resize(nearest_count)
		_out_star_rad.resize(nearest_count)
	for k: int in range(nearest_count):
		_out_star_pos[k] = _nearest_star_pos[k]
		_out_star_col[k] = _nearest_star_col[k]
		_out_star_rad[k] = _nearest_star_rad[k]
	nebula_controller.update_star_lights(_out_star_pos, _out_star_col, _out_star_rad)

	# Interpolar ágilmente hacia el bioma estelar o hacia el vacío espacial (~0.4s)
	if closest_biome != null:
		nebula_controller.set_biome_b(closest_biome)
	
	var current_blend: float = nebula_controller.biome_blend_factor
	var new_blend: float = lerpf(current_blend, target_influence, clampf(delta * 5.0, 0.0, 1.0))
	nebula_controller.set_blend_factor(new_blend)
	var dominant_light_dir: Vector2 = (dominant_star_world_pos - player_world_pos).normalized()

	_ensure_screen_occluder_buf()
	var vp_size: Vector2 = get_viewport_rect().size if get_viewport() != null else Vector2(1920.0, 1080.0)
	if vp_size.x < 1.0 or vp_size.y < 1.0:
		vp_size = Vector2(1920.0, 1080.0)
	var star_screen_uv: Vector2 = Vector2(dominant_star_screen.x / vp_size.x, dominant_star_screen.y / vp_size.y)
	var dom_heliopause_uv_r: float = clampf((dominant_light_rad * zoom_val) / vp_size.y, 0.25, 4.5)

	var dom_sys_id: int = dominant_system.get_instance_id() if (dominant_system != null and is_instance_valid(dominant_system)) else 0
	var is_teleport_jump: bool = _has_prev_player_pos and _prev_player_world_pos.distance_squared_to(player_world_pos) > 810000.0
	if not _has_smoothed_dom_star or is_teleport_jump or dom_sys_id == 0:
		_smooth_dom_star_screen = dominant_star_screen
		_smooth_dom_star_uv = star_screen_uv
		_smooth_dom_star_color = dominant_star_color
		_smooth_dom_star_inf = max_star_inf
		_smooth_dom_light_dir = dominant_light_dir
		_smooth_dom_heliopause_uv_r = dom_heliopause_uv_r
		_has_smoothed_dom_star = (dom_sys_id != 0)
	elif dom_sys_id == _prev_dom_system_id:
		# Mismo sol dominante: posición exacta sin lag de cámara + atenuación suave en colores
		var t_soft: float = clampf(delta * 8.0, 0.0, 1.0)
		_smooth_dom_star_screen = dominant_star_screen
		_smooth_dom_star_uv = star_screen_uv
		_smooth_dom_star_color = _smooth_dom_star_color.lerp(dominant_star_color, t_soft)
		_smooth_dom_star_inf = lerpf(_smooth_dom_star_inf, max_star_inf, t_soft)
		_smooth_dom_light_dir = dominant_light_dir
		_smooth_dom_heliopause_uv_r = dom_heliopause_uv_r
	else:
		# Cruce entre dos sistemas: crossfade suave sin latigazo visual
		var t_cross: float = clampf(delta * 7.5, 0.0, 1.0)
		_smooth_dom_star_screen = _smooth_dom_star_screen.lerp(dominant_star_screen, t_cross)
		_smooth_dom_star_uv = _smooth_dom_star_uv.lerp(star_screen_uv, t_cross)
		_smooth_dom_star_color = _smooth_dom_star_color.lerp(dominant_star_color, t_cross)
		_smooth_dom_star_inf = lerpf(_smooth_dom_star_inf, max_star_inf, t_cross)
		_smooth_dom_light_dir = _smooth_dom_light_dir.lerp(dominant_light_dir, t_cross).normalized()
		_smooth_dom_heliopause_uv_r = lerpf(_smooth_dom_heliopause_uv_r, dom_heliopause_uv_r, t_cross)
	_prev_dom_system_id = dom_sys_id

	var edge_dx: float = absf(_smooth_dom_star_uv.x - 0.5)
	var edge_dy: float = absf(_smooth_dom_star_uv.y - 0.5)
	var screen_bounds_vis: float = 1.0 - clampf((maxf(edge_dx, edge_dy) - 0.62) / 0.38, 0.0, 1.0)
	var occ_count: int = 0
	var eclipse_occl: float = 0.0
	var player_eclipse: float = 0.0
	if dominant_system != null and is_instance_valid(dominant_system):
		var shadow_exp: float = dominant_system.shadow_projector.shadow_expansion_factor if dominant_system.shadow_projector != null else 1.85
		var dom_orbit_max: float = dominant_system.active_archetype.orbit_radius_max if dominant_system.active_archetype != null else 3800.0
		for p_body: CosmosOrbitalBody2D in dominant_system.planets:
			if not is_instance_valid(p_body):
				continue
			var p_scr: Vector2 = p_body.get_global_transform_with_canvas().origin
			var p_vis_r: float = float(p_body.get_meta(&"visual_radius", 130.0))
			var p_scr_r: float = p_vis_r * zoom_val
			if p_scr_r > 2.0:
				var d_sun_p: float = p_scr.distance_to(_smooth_dom_star_screen)
				if d_sun_p < p_scr_r * 1.15:
					eclipse_occl = maxf(eclipse_occl, 1.0 - clampf(d_sun_p / (p_scr_r * 1.15), 0.0, 1.0))
			if occ_count < 6:
				_screen_planet_occluders[occ_count] = Vector4(
					p_scr.x / vp_size.x,
					p_scr.y / vp_size.y,
					p_scr_r / vp_size.y,
					shadow_exp
				)
				occ_count += 1
			var p_world: Vector2 = p_body.global_position
			var to_p: Vector2 = p_world - dominant_star_world_pos
			var d_sun_p_world: float = to_p.length()
			if d_sun_p_world > 1.0 and p_vis_r > 2.0:
				var p_out: Vector2 = to_p / d_sun_p_world
				var rel_pl: Vector2 = player_world_pos - p_world
				var proj_behind: float = rel_pl.dot(p_out)
				if proj_behind > 0.0:
					var cone_len_est: float = maxf(dom_orbit_max * 1.5 - d_sun_p_world, 600.0)
					if proj_behind < cone_len_est:
						var perp_d: float = (rel_pl - p_out * proj_behind).length()
						var prog_w: float = clampf(proj_behind / cone_len_est, 0.0, 1.0)
						var cone_w: float = p_vis_r * lerpf(1.03, shadow_exp, pow(prog_w, 0.88))
						var attach_w: float = clampf(proj_behind / maxf(p_vis_r * 0.45, 1.0), 0.0, 1.0)
						var ecl_w: float = (1.0 - clampf((perp_d - cone_w * 0.55) / maxf(cone_w * 0.55, 1.0), 0.0, 1.0)) * attach_w
						player_eclipse = maxf(player_eclipse, ecl_w)
	for k: int in range(occ_count, 6):
		_screen_planet_occluders[k] = Vector4.ZERO
	var star_vis: float = clampf(screen_bounds_vis * (1.0 - eclipse_occl * 0.85), 0.0, 1.0) if dominant_system != null else 0.0

	var inst_vel: Vector2 = Vector2.ZERO
	if player_target != null and is_instance_valid(player_target) and player_target is CharacterBody2D:
		inst_vel = (player_target as CharacterBody2D).velocity
	if inst_vel.length_squared() < 4.0 and _has_prev_player_pos and delta > 0.0001:
		var delta_p: Vector2 = player_world_pos - _prev_player_world_pos
		if delta_p.length_squared() < 810000.0:
			inst_vel = delta_p / delta
	var target_vel_norm: Vector2 = inst_vel / 550.0
	var v_len: float = target_vel_norm.length()
	if v_len > 1.4:
		target_vel_norm = target_vel_norm * (1.4 / v_len)
	_smoothed_player_vel = _smoothed_player_vel.lerp(target_vel_norm, clampf(delta * 10.0, 0.0, 1.0))

	var inside_domain: bool = (target_influence > 0.12)
	if inside_domain and not _prev_inside_domain and _has_prev_player_pos:
		_domain_entry_pulse = 1.0
	else:
		_domain_entry_pulse = move_toward(_domain_entry_pulse, 0.0, delta * 1.55)
	_prev_inside_domain = inside_domain
	_prev_player_world_pos = player_world_pos
	_has_prev_player_pos = true

	var player_screen_uv: Vector2 = Vector2(0.5, 0.5)
	if player_target != null and is_instance_valid(player_target):
		var p_scr_pos: Vector2 = player_target.get_global_transform_with_canvas().origin + _player_aura_world_offset * zoom_val
		player_screen_uv = Vector2(clampf(p_scr_pos.x / vp_size.x, -0.2, 1.2), clampf(p_scr_pos.y / vp_size.y, -0.2, 1.2))
	var player_aura_rad_v: float = clampf((_player_aura_world_radius * zoom_val) / vp_size.y, 0.045, 0.42)

	_update_atmosphere_layers(
		_smooth_dom_star_screen,
		_smooth_dom_star_color,
		_smooth_dom_star_inf,
		_smooth_dom_light_dir,
		zoom_val,
		_smooth_dom_star_uv,
		star_vis,
		dominant_is_black_hole,
		occ_count,
		player_screen_uv,
		player_eclipse,
		_smoothed_player_vel,
		_domain_entry_pulse,
		player_aura_rad_v,
		_smooth_dom_heliopause_uv_r
	)


func _update_atmosphere_layers(
	star_screen_pos: Vector2,
	star_color: Color,
	star_influence: float,
	light_dir: Vector2 = Vector2(0.85, -0.52),
	camera_zoom: float = 1.0,
	star_screen_uv: Vector2 = Vector2(0.5, 0.5),
	star_vis: float = 0.0,
	is_black_hole: bool = false,
	occ_count: int = 0,
	player_screen_uv: Vector2 = Vector2(0.5, 0.5),
	player_eclipse: float = 0.0,
	player_vel_norm: Vector2 = Vector2.ZERO,
	domain_entry_pulse: float = 0.0,
	player_aura_rad_v: float = 0.20,
	star_heliopause_uv_r: float = 1.2
) -> void:
	_ensure_screen_occluder_buf()
	var b_primary: Color = Color(0.28, 0.06, 0.52, 1.0)
	var b_secondary: Color = Color(0.03, 0.38, 0.62, 1.0)
	if nebula_controller != null and nebula_controller.biome_a != null:
		b_primary = nebula_controller.biome_a.color_gas_primary
		b_secondary = nebula_controller.biome_a.color_gas_secondary
		if nebula_controller.biome_b != null and nebula_controller.biome_blend_factor > 0.001:
			var bf: float = nebula_controller.biome_blend_factor
			b_primary = b_primary.lerp(nebula_controller.biome_b.color_gas_primary, bf)
			b_secondary = b_secondary.lerp(nebula_controller.biome_b.color_gas_secondary, bf)

	var vp_size: Vector2 = get_viewport_rect().size if get_viewport() != null else Vector2(1920.0, 1080.0)
	if vp_size.x < 1.0 or vp_size.y < 1.0:
		vp_size = Vector2(1920.0, 1080.0)
	var vp_aspect: float = vp_size.x / maxf(vp_size.y, 1.0)
	var near_occ_count: int = occ_count if _quality_level >= 1 else 0

	var b_haze_near: Color = b_primary.lerp(b_secondary, 0.35).lerp(Color(0.05, 0.08, 0.20, 1.0), 0.38)
	var b_haze_far: Color = b_primary.lerp(b_secondary, 0.55).lerp(Color(0.04, 0.06, 0.16, 1.0), 0.28)
	if debris_streamer != null and is_instance_valid(debris_streamer):
		debris_streamer.update_atmospheric_lighting(
			light_dir, star_color, star_influence, b_haze_near, 0.0,
			star_screen_uv, vp_aspect, _screen_planet_occluders, near_occ_count
		)
	if debris_far_streamer != null and is_instance_valid(debris_far_streamer) and (parallax_debris_far == null or parallax_debris_far.visible):
		debris_far_streamer.update_atmospheric_lighting(
			light_dir, star_color, star_influence * 0.72, b_haze_far, 0.0,
			star_screen_uv, vp_aspect, _screen_planet_occluders, 0
		)
	if galaxy_streamer != null and is_instance_valid(galaxy_streamer):
		galaxy_streamer.update_biome_harmony(b_primary.lerp(b_secondary, 0.45), 0.44)
	if non_stellar_streamer != null and is_instance_valid(non_stellar_streamer):
		non_stellar_streamer.update_biome_harmony(b_primary, b_secondary)
	if corridor_controller != null and is_instance_valid(corridor_controller):
		corridor_controller.update_biome_harmony(b_primary, b_secondary)

	if atmosphere_layers == null or not is_instance_valid(atmosphere_layers):
		return

	var cam_center: Vector2 = Vector2.ZERO
	if viewport_tracker != null:
		cam_center = viewport_tracker.current_center
	elif camera != null and is_instance_valid(camera):
		cam_center = camera.global_position
	atmosphere_layers.update_view_and_lighting(
		cam_center,
		_global_time,
		b_primary,
		b_secondary,
		star_screen_pos,
		star_color,
		star_influence,
		vp_size,
		camera_zoom,
		star_screen_uv,
		star_vis,
		is_black_hole,
		_screen_planet_occluders,
		occ_count,
		player_screen_uv,
		player_eclipse,
		player_vel_norm,
		domain_entry_pulse,
		_player_aura_color,
		player_aura_rad_v,
		_player_aura_energy,
		_player_aura_wing_axis,
		star_heliopause_uv_r
	)


func _on_floating_origin_shifted(shift: Vector2) -> void:
	_origin_shift_count += 1
	_accumulated_shift += shift
	if nebula_controller != null and is_instance_valid(nebula_controller):
		nebula_controller.accumulated_origin_shift = _accumulated_shift
	if parallax_starfield_8k != null and is_instance_valid(parallax_starfield_8k) and parallax_starfield_8k is CosmosStarfieldBackdropController:
		(parallax_starfield_8k as CosmosStarfieldBackdropController).accumulated_origin_shift = _accumulated_shift
	origin_shifted.emit(shift)

## Devuelve el tiempo cósmico universal transcurrido.
func get_global_time() -> float:
	return _global_time

## Devuelve el conteo de recentrados efectuados.
func get_origin_shift_count() -> int:
	return _origin_shift_count

## Devuelve la suma vectorial acumulada de los recentrados.
func get_accumulated_shift() -> Vector2:
	return _accumulated_shift

## Devuelve la posición absoluta no recentrada en el cosmos continuo.
func get_absolute_position(local_pos: Vector2) -> Vector2:
	return local_pos + _accumulated_shift

const BIOME_PRESETS: Array[String] = [
	"res://scenes/combat/environment/cosmos/resources/data/biomes/biome_01_perseus_rift.tres",
	"res://scenes/combat/environment/cosmos/resources/data/biomes/biome_02_hyperion_forge.tres",
	"res://scenes/combat/environment/cosmos/resources/data/biomes/biome_03_carina_abyss.tres",
	"res://scenes/combat/environment/cosmos/resources/data/biomes/biome_04_crimson_veil.tres",
	"res://scenes/combat/environment/cosmos/resources/data/biomes/biome_05_silica_corona.tres",
	"res://scenes/combat/environment/cosmos/resources/data/biomes/biome_06_bootes_void.tres"
]
var _active_biome_index: int = 0

## Conmuta en caliente al siguiente bioma de la colección de 6 biomas
func cycle_biome(forward: bool = true) -> CosmosBiomeConfig:
	if BIOME_PRESETS.is_empty():
		return null
	if forward:
		_active_biome_index = (_active_biome_index + 1) % BIOME_PRESETS.size()
	else:
		_active_biome_index = (_active_biome_index - 1 + BIOME_PRESETS.size()) % BIOME_PRESETS.size()
	
	var path: String = BIOME_PRESETS[_active_biome_index]
	var biome_res: CosmosBiomeConfig = load(path) as CosmosBiomeConfig
	if biome_res != null and environment_profile != null:
		environment_profile.biome_a_profile = biome_res
		environment_profile.biome_blend_factor = 0.0
	return biome_res

## Devuelve el índice del bioma activo actual (0..5)
func get_active_biome_index() -> int:
	return _active_biome_index
