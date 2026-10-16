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

@export var camera: Camera2D
@export var player_target: Node2D
@export var floating_origin_tracker: CosmosFloatingOriginTracker
@export var viewport_tracker: CosmosViewportCanvasTracker
@export var time_scale: float = 1.0
@export var is_frozen: bool = false:
	set(v):
		is_frozen = v
		_propagate_freeze_state(v)

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
@export var parallax_debris_belt: Parallax2D
@export var debris_streamer: CosmosDebrisStreamer2D

var poi_registry: CosmicPoiRegistry = CosmicPoiRegistry.new()
var _global_time: float = 0.0
var _origin_shift_count: int = 0
var _accumulated_shift: Vector2 = Vector2.ZERO
var _starfield_mat: ShaderMaterial = null

func _propagate_freeze_state(frozen: bool) -> void:
	if nebula_controller != null and is_instance_valid(nebula_controller):
		nebula_controller.is_frozen = frozen
	if solar_streamer != null and is_instance_valid(solar_streamer):
		solar_streamer.is_frozen = frozen
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

var _has_runtime_profile_copy: bool = false

func _ensure_runtime_environment_profile() -> void:
	if environment_profile != null and not _has_runtime_profile_copy:
		var was_connected: bool = environment_profile.changed.is_connected(apply_environment_profile)
		if was_connected:
			environment_profile.changed.disconnect(apply_environment_profile)
		environment_profile = environment_profile.duplicate() as CosmosEnvProfile
		_has_runtime_profile_copy = true
		if not environment_profile.changed.is_connected(apply_environment_profile):
			environment_profile.changed.connect(apply_environment_profile)

func _init_environment_profile() -> void:
	if environment_profile == null:
		var default_res: CosmosEnvProfile = load("res://scenes/combat/environment/cosmos/resources/data/default_cosmos_environment.tres") as CosmosEnvProfile
		if default_res != null:
			environment_profile = default_res.duplicate() as CosmosEnvProfile
			_has_runtime_profile_copy = true
	else:
		_ensure_runtime_environment_profile()
	if environment_profile != null and not environment_profile.changed.is_connected(apply_environment_profile):
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
			if parallax_debris_belt != null:
				layers.append(parallax_debris_belt)
			floating_origin_tracker.parallax_layers = layers

func bind_camera_to_streamers() -> void:
	if camera == null:
		return
	_sync_poi_registry()
	if galaxy_streamer != null and galaxy_streamer.camera == null:
		galaxy_streamer.camera = camera
	if solar_streamer != null and solar_streamer.camera == null:
		solar_streamer.camera = camera
		solar_streamer._update_streaming_and_orbits(_global_time)
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
	var show_starfield: bool = (quality_level >= 2)
	if parallax_starfield_8k != null and is_instance_valid(parallax_starfield_8k):
		parallax_starfield_8k.visible = show_starfield
		var parent_node: Node = parallax_starfield_8k.get_parent()
		if parent_node is CanvasLayer:
			(parent_node as CanvasLayer).visible = show_starfield

	var dispersion: float = 0.004 if quality_level >= 2 else 0.0
	if nebula_controller != null and is_instance_valid(nebula_controller) and nebula_controller.material is ShaderMaterial:
		var n_mat: ShaderMaterial = nebula_controller.material as ShaderMaterial
		n_mat.set_shader_parameter("chromatic_dispersion", dispersion)
		var sparkle: float = 0.85 if quality_level >= 1 else 0.0
		n_mat.set_shader_parameter("deep_stars_sparkle_intensity", sparkle)


func _on_viewport_updated(center_world_pos: Vector2, zoom: Vector2, _rotation_rad: float) -> void:
	if solar_streamer != null:
		solar_streamer.set_camera_override(center_world_pos, zoom)
	if galaxy_streamer != null:
		galaxy_streamer.set_camera_override(center_world_pos, zoom)
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

func _on_solar_system_streamed(system: CosmosSolarSystem2D, cell: Vector2i) -> void:
	solar_system_streamed.emit(system, cell)

func _on_solar_system_unstreamed(system: CosmosSolarSystem2D, cell: Vector2i) -> void:
	solar_system_unstreamed.emit(system, cell)

func _sync_poi_registry() -> void:
	if poi_registry == null:
		poi_registry = CosmicPoiRegistry.new()
	if solar_streamer != null and solar_streamer.poi_registry != poi_registry:
		solar_streamer.poi_registry = poi_registry
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
	if galaxy_streamer != null and is_instance_valid(galaxy_streamer):
		galaxy_streamer.set_run_seed(p_seed)
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

	if _starfield_mat != null:
		_starfield_mat.set_shader_parameter("global_time", _global_time)

## Transmite las posiciones cósmicas absolutas, colores y alcance de iluminación de los soles activos a la nebulosa de fondo
## Además, interpola suavemente el bioma de la nebulosa al entrar/salir de la órbita del sol más cercano
func _sync_active_star_lights_to_nebula(delta: float) -> void:
	if solar_streamer == null or nebula_controller == null:
		return
	var active_systems: Dictionary = solar_streamer.get_active_systems()
	if active_systems.is_empty():
		nebula_controller.update_star_lights(PackedVector2Array(), PackedColorArray(), PackedFloat32Array())
		nebula_controller.set_blend_factor(move_toward(nebula_controller.biome_blend_factor, 0.0, delta * 1.5))
		return

	var positions: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var radii: PackedFloat32Array = PackedFloat32Array()

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

	var target_influence: float = 0.0
	var closest_biome: CosmosBiomeConfig = null

	for cell_coords: Vector2i in active_systems.keys():
		var sys: CosmosSolarSystem2D = active_systems[cell_coords] as CosmosSolarSystem2D
		if sys == null or not sys.visible:
			continue

		var arch: CosmosStarArchetype = sys.active_archetype
		var star_col: Color = arch.star_color if arch != null else (sys.system_profile.star_emission_color if sys.system_profile != null else Color.WHITE)
		var orbit_max: float = arch.orbit_radius_max if arch != null else 2400.0
		var light_rad: float = orbit_max * 1.5

		# Posición exacta del centro del sol en pantalla (viewport space 1:1) y radio aparente
		var star_item: CanvasItem = sys.star_body if (sys.star_body != null and is_instance_valid(sys.star_body)) else sys
		var sun_screen_pos: Vector2 = star_item.get_global_transform_with_canvas().origin
		var sun_screen_radius: float = light_rad * zoom_val

		if positions.size() < 4:
			positions.append(sun_screen_pos)
			colors.append(star_col)
			radii.append(sun_screen_radius)

		# Evaluar proximidad real de la nave al sol en coordenadas de juego:
		# La transición comienza en 1.10 * orbit_max y alcanza 1.0 (saturación total) en 0.85 * orbit_max
		var dist_to_sun: float = player_world_pos.distance_to(star_item.global_position)
		var transition_outer: float = orbit_max * 1.10
		var transition_inner: float = orbit_max * 0.85
		if dist_to_sun < transition_outer:
			var influence: float = clampf((transition_outer - dist_to_sun) / (transition_outer - transition_inner), 0.0, 1.0)
			if influence > target_influence:
				target_influence = influence
				if arch != null and arch.biome_config != null:
					closest_biome = arch.biome_config

	nebula_controller.update_star_lights(positions, colors, radii)

	# Interpolar ágilmente hacia el bioma estelar o hacia el vacío espacial (~0.4s)
	if closest_biome != null:
		nebula_controller.set_biome_b(closest_biome)
	
	var current_blend: float = nebula_controller.biome_blend_factor
	var new_blend: float = lerpf(current_blend, target_influence, clampf(delta * 5.0, 0.0, 1.0))
	nebula_controller.set_blend_factor(new_blend)


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
		_ensure_runtime_environment_profile()
		environment_profile.biome_a_profile = biome_res
		environment_profile.biome_blend_factor = 0.0
	return biome_res

## Devuelve el índice del bioma activo actual (0..5)
func get_active_biome_index() -> int:
	return _active_biome_index
