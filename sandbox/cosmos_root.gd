class_name CosmosRoot
extends Node2D

## Escena Raíz y Orquestador de Cosmos Engine.
## Unifica los 6 estratos cósmicos analíticos y Parallax2D en Godot 4:
## 1. ParallaxNebulaDeep: Shader universe_nebula.gdshader en CanvasLayer de fondo o Parallax ultralento.
## 2. ParallaxMacroGalaxies: GalaxyStreamer2D en capa de muy bajo factor (0.02).
## 3. ParallaxStarfield8K: Textura estelar 8K anti-tiling / espacio profundo en Parallax intermedio-bajo (0.05).
## 4. ParallaxSolarSystems: SolarSystemStreamer en estrato astronómico medio (0.20).
## 5. ParallaxDebrisBelt: DebrisStreamer2D con MultiMesh en GPU (0.50).
## 6. GameplayWorld: Entidades de combate/exploración interactiva (1.00).
##
## Administra el tiempo global cósmico (global_time) y sincroniza prioridades
## de proceso con FloatingOriginTracker para garantizar cero micro-saltos.

signal origin_shifted(shift_vector: Vector2)

@export var camera: Camera2D
@export var player_target: Node2D
@export var floating_origin_tracker: FloatingOriginTracker
@export var time_scale: float = 1.0

@export_group("Perfil de Entorno Data-Driven")
@export var environment_profile: CosmosEnvironmentProfile:
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
@export var nebula_controller: NebulaBackdropController
@export var parallax_macro_galaxies: Parallax2D
@export var galaxy_streamer: GalaxyStreamer2D
@export var parallax_starfield_8k: Parallax2D
@export var parallax_solar_systems: Parallax2D
@export var solar_streamer: SolarSystemStreamer
@export var parallax_debris_belt: Parallax2D
@export var debris_streamer: DebrisStreamer2D
@export var gameplay_world: Node2D

var _global_time: float = 0.0
var _origin_shift_count: int = 0
var _accumulated_shift: Vector2 = Vector2.ZERO
var _starfield_mat: ShaderMaterial = null

func _ready() -> void:
	# Prioridad de proceso: CosmosRoot orquesta el tiempo y el tracker se procesa antes del render
	process_priority = -100
	_setup_floating_origin()
	_bind_camera_to_streamers()
	_cache_starfield_material()
	_init_environment_profile()

func _init_environment_profile() -> void:
	if environment_profile == null:
		var default_res: CosmosEnvironmentProfile = load("res://sandbox/resources/data/default_cosmos_environment.tres") as CosmosEnvironmentProfile
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

	if parallax_solar_systems != null and is_instance_valid(parallax_solar_systems):
		parallax_solar_systems.scroll_scale = environment_profile.solar_scroll_scale * mult
	if solar_streamer != null and is_instance_valid(solar_streamer) and environment_profile.solar_profile != null:
		solar_streamer.system_profile = environment_profile.solar_profile

	if parallax_debris_belt != null and is_instance_valid(parallax_debris_belt):
		parallax_debris_belt.scroll_scale = environment_profile.debris_scroll_scale * mult
	if debris_streamer != null and is_instance_valid(debris_streamer) and environment_profile.debris_profile != null:
		debris_streamer.profile = environment_profile.debris_profile

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
			return parallax_starfield_8k.visible if parallax_starfield_8k != null and is_instance_valid(parallax_starfield_8k) else false
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
		var sprite: Sprite2D = parallax_starfield_8k.get_node_or_null("StarfieldSprite") as Sprite2D
		if sprite != null and sprite.material is ShaderMaterial:
			_starfield_mat = sprite.material as ShaderMaterial

func _setup_floating_origin() -> void:
	if floating_origin_tracker == null:
		floating_origin_tracker = get_node_or_null("FloatingOriginTracker") as FloatingOriginTracker
	
	if floating_origin_tracker != null:
		# Establecer prioridad de proceso del tracker previa a los renders
		floating_origin_tracker.process_priority = -50
		if not floating_origin_tracker.origin_shifted.is_connected(_on_floating_origin_shifted):
			floating_origin_tracker.origin_shifted.connect(_on_floating_origin_shifted)
		
		# Registrar capas de paralaje si no están asignadas
		if floating_origin_tracker.parallax_layers.is_empty():
			var layers: Array[Parallax2D] = []
			if parallax_macro_galaxies != null:
				layers.append(parallax_macro_galaxies)
			if parallax_starfield_8k != null:
				layers.append(parallax_starfield_8k)
			if parallax_solar_systems != null:
				layers.append(parallax_solar_systems)
			if parallax_debris_belt != null:
				layers.append(parallax_debris_belt)
			floating_origin_tracker.parallax_layers = layers

func _bind_camera_to_streamers() -> void:
	if camera == null:
		return
	if galaxy_streamer != null and galaxy_streamer.camera == null:
		galaxy_streamer.camera = camera
	if solar_streamer != null and solar_streamer.camera == null:
		solar_streamer.camera = camera
	if debris_streamer != null and debris_streamer.camera == null:
		debris_streamer.camera = camera
	if nebula_controller != null and nebula_controller.camera == null:
		nebula_controller.camera = camera

func _process(delta: float) -> void:
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

	var scroll_s: Vector2 = parallax_solar_systems.scroll_scale if parallax_solar_systems != null else Vector2.ONE
	var scroll_off: Vector2 = parallax_solar_systems.scroll_offset if parallax_solar_systems != null else Vector2.ZERO

	var vp_size: Vector2 = nebula_controller.get_viewport_rect().size
	if vp_size == Vector2.ZERO:
		vp_size = Vector2(1920.0, 1080.0)
	var vp_center: Vector2 = vp_size * 0.5

	var cam_pos: Vector2 = camera.get_screen_center_position() if camera != null else Vector2.ZERO
	if cam_pos == Vector2.ZERO and camera != null and camera.global_position != Vector2.ZERO:
		cam_pos = camera.global_position
	var zoom_val: float = camera.zoom.x if camera != null and camera.zoom.x > 0.0001 else 1.0

	var layer_center: Vector2 = (cam_pos * scroll_s) - scroll_off

	# Punto de referencia de la nave/cámara proyectado al plano del estrato del sistema solar
	var player_world_pos: Vector2 = camera.global_position if camera != null else Vector2.ZERO
	if player_target != null and is_instance_valid(player_target):
		player_world_pos = player_target.global_position
	var player_layer_pos: Vector2 = (player_world_pos * scroll_s) - scroll_off

	var target_influence: float = 0.0
	var closest_biome: CosmicBiomeConfig = null

	for cell_coords: Vector2i in active_systems.keys():
		var sys: SolarSystem2D = active_systems[cell_coords] as SolarSystem2D
		if sys == null or not sys.visible:
			continue

		var arch: StarArchetype = sys.active_archetype
		var star_col: Color = arch.star_color if arch != null else (sys.system_profile.star_emission_color if sys.system_profile != null else Color.WHITE)
		var orbit_max: float = arch.orbit_radius_max if arch != null else 2400.0
		var light_rad: float = orbit_max * 1.5

		# Posición exacta del sol en pantalla (viewport space) y radio aparente
		var sun_screen_pos: Vector2 = vp_center + (sys.position - layer_center) * zoom_val
		var sun_screen_radius: float = light_rad * zoom_val

		if positions.size() < 4:
			positions.append(sun_screen_pos)
			colors.append(star_col)
			radii.append(sun_screen_radius)

		# Evaluar proximidad real de la nave en el plano del sol:
		# La transición comienza en 1.10 * orbit_max y alcanza 1.0 (saturación total) en 0.85 * orbit_max
		var dist_to_sun: float = player_layer_pos.distance_to(sys.position)
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
	"res://sandbox/resources/data/biomes/biome_01_perseus_rift.tres",
	"res://sandbox/resources/data/biomes/biome_02_hyperion_forge.tres",
	"res://sandbox/resources/data/biomes/biome_03_carina_abyss.tres",
	"res://sandbox/resources/data/biomes/biome_04_crimson_veil.tres",
	"res://sandbox/resources/data/biomes/biome_05_silica_corona.tres",
	"res://sandbox/resources/data/biomes/biome_06_bootes_void.tres"
]
var _active_biome_index: int = 0

## Conmuta en caliente al siguiente bioma de la colección de 6 biomas
func cycle_biome(forward: bool = true) -> CosmicBiomeConfig:
	if BIOME_PRESETS.is_empty():
		return null
	if forward:
		_active_biome_index = (_active_biome_index + 1) % BIOME_PRESETS.size()
	else:
		_active_biome_index = (_active_biome_index - 1 + BIOME_PRESETS.size()) % BIOME_PRESETS.size()
	
	var path: String = BIOME_PRESETS[_active_biome_index]
	var biome_res: CosmicBiomeConfig = load(path) as CosmicBiomeConfig
	if biome_res != null and environment_profile != null:
		environment_profile.biome_a_profile = biome_res
		environment_profile.biome_blend_factor = 0.0
	return biome_res

## Devuelve el índice del bioma activo actual (0..5)
func get_active_biome_index() -> int:
	return _active_biome_index
