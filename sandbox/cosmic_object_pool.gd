class_name CosmicObjectPool
extends Node2D

## cosmic_object_pool.gd
## Node pooling zero-allocation para sprites de fondo cósmico:
## Planetas con shaders atmosféricos, estaciones con balizas luminosas,
## galaxias espirales, agujeros negros supermasivos y púlsares relativistas.

# Texturas pre-cargadas
const TEX_PLANETS: Array[Texture2D] = [
	preload("res://assets/environments/parallax_space/planet_0.png"),
	preload("res://assets/environments/parallax_space/planet_1.png"),
	preload("res://assets/environments/parallax_space/planet_2.png"),
	preload("res://assets/environments/parallax_space/planet_3.png"),
]

const TEX_STATIONS: Array[Texture2D] = [
	preload("res://assets/environments/parallax_space/space_station_0.png"),
	preload("res://assets/environments/parallax_space/space_station_1.png"),
	preload("res://assets/environments/parallax_space/space_station_2.png"),
]

const TEX_SUNS: Array[Texture2D] = [
	preload("res://assets/environments/parallax_space/Star.jpg"),
	preload("res://assets/environments/parallax_space/Star 0.jpg"),
	preload("res://assets/environments/parallax_space/Star 1.jpg"),
]

const TEX_GALAXY: Texture2D = preload("res://assets/environments/parallax_space/Galaxy.jpg")
const TEX_BLACK_HOLE: Texture2D = preload("res://assets/environments/parallax_space/Black Hole.jpg")
const TEX_PULSAR: Texture2D = preload("res://assets/environments/parallax_space/Pulsar.jpg")

# Shaders
const SHADER_PLANET: Shader = preload("res://scenes/combat/environment/planet_atmosphere.gdshader")
const SHADER_STATION: Shader = preload("res://scenes/combat/environment/space_station_beacon.gdshader")
const SHADER_SUN: Shader = preload("res://scenes/combat/environment/sun_corona.gdshader")
const SHADER_GALAXY: Shader = preload("res://scenes/combat/environment/galaxy_deep.gdshader")
const SHADER_BLACK_HOLE: Shader = preload("res://scenes/combat/environment/black_hole.gdshader")
const SHADER_PULSAR: Shader = preload("res://scenes/combat/environment/pulsar.gdshader")

# Configuraciones espectrales de estrellas / soles
const SUN_SPECTRAL_CONFIGS: Array[Dictionary] = [
	{
		"spectral_tint": Color(1.0, 0.95, 0.85, 1.0),
		"corona_color": Color(1.0, 0.74, 0.32, 1.0),
		"emission": 2.5,
		"core_radius": 0.35,
		"corona_thickness": 0.12,
		"spin": 0.004,
	},
	{
		"spectral_tint": Color(0.75, 0.90, 1.0, 1.0),
		"corona_color": Color(0.35, 0.68, 1.0, 1.0),
		"emission": 2.8,
		"core_radius": 0.34,
		"corona_thickness": 0.14,
		"spin": -0.005,
	},
	{
		"spectral_tint": Color(1.0, 0.62, 0.38, 1.0),
		"corona_color": Color(1.0, 0.38, 0.12, 1.0),
		"emission": 2.3,
		"core_radius": 0.38,
		"corona_thickness": 0.11,
		"spin": 0.003,
	},
]


# Configuraciones de balizas para las estaciones (index 0, 1, 2)
const STATION_BEACON_CONFIGS: Array[Dictionary] = [
	{
		"b1_pos": Vector2(0.486, 0.192), "b1_col": Color(1.0, 0.15, 0.15, 1.0), "b1_per": 1.2, "b1_ph": 0.0, "b1_rad": 0.018,
		"b2_pos": Vector2(0.055, 0.504), "b2_col": Color(1.0, 1.0, 1.0, 1.0), "b2_per": 0.8, "b2_ph": 0.2, "b2_rad": 0.016,
		"b3_pos": Vector2(0.954, 0.508), "b3_col": Color(0.2, 1.0, 0.4, 1.0), "b3_per": 1.4, "b3_ph": 0.5, "b3_rad": 0.016,
		"b4_pos": Vector2(0.204, 0.813), "b4_col": Color(1.0, 0.15, 0.15, 1.0), "b4_per": 1.2, "b4_ph": 0.6, "b4_rad": 0.018,
	},
	{
		"b1_pos": Vector2(0.855, 0.107), "b1_col": Color(1.0, 0.15, 0.15, 1.0), "b1_per": 1.1, "b1_ph": 0.0, "b1_rad": 0.016,
		"b2_pos": Vector2(0.061, 0.497), "b2_col": Color(1.0, 1.0, 1.0, 1.0), "b2_per": 0.75, "b2_ph": 0.15, "b2_rad": 0.016,
		"b3_pos": Vector2(0.941, 0.493), "b3_col": Color(0.2, 0.85, 1.0, 1.0), "b3_per": 1.3, "b3_ph": 0.4, "b3_rad": 0.016,
		"b4_pos": Vector2(0.688, 0.862), "b4_col": Color(1.0, 0.15, 0.15, 1.0), "b4_per": 1.1, "b4_ph": 0.55, "b4_rad": 0.016,
	},
	{
		"b1_pos": Vector2(0.484, 0.229), "b1_col": Color(1.0, 1.0, 1.0, 1.0), "b1_per": 0.85, "b1_ph": 0.0, "b1_rad": 0.018,
		"b2_pos": Vector2(0.068, 0.255), "b2_col": Color(1.0, 0.15, 0.15, 1.0), "b2_per": 1.25, "b2_ph": 0.3, "b2_rad": 0.016,
		"b3_pos": Vector2(0.952, 0.474), "b3_col": Color(0.2, 1.0, 0.4, 1.0), "b3_per": 1.25, "b3_ph": 0.3, "b3_rad": 0.016,
		"b4_pos": Vector2(0.515, 0.761), "b4_col": Color(1.0, 0.45, 0.1, 1.0), "b4_per": 1.5, "b4_ph": 0.7, "b4_rad": 0.018,
	}
]

# Atmósferas base de planetas
const PLANET_ATMOSPHERE_CONFIGS: Array[Dictionary] = [
	{"color": Color(1.0, 0.58, 0.22, 1.0), "intensity": 1.6, "fresnel": 3.5, "radius": 0.40, "spin": 0.006},
	{"color": Color(0.22, 0.78, 1.0, 1.0), "intensity": 1.7, "fresnel": 3.2, "radius": 0.35, "spin": -0.005},
	{"color": Color(0.45, 0.72, 0.95, 1.0), "intensity": 1.4, "fresnel": 3.8, "radius": 0.28, "spin": 0.002},
	{"color": Color(1.0, 0.38, 0.18, 1.0), "intensity": 1.5, "fresnel": 3.5, "radius": 0.40, "spin": 0.008},
]

# Estructura del pool interno
var _pool_items: Array[Sprite2D] = []
var _available_indices: Array[int] = []
var _active_items: Array[Dictionary] = []

const SpaceEnvironmentConfigScript = preload("res://core/resources/space_environment_config.gd")
@export var env_config: Resource = preload("res://data/environment/default_space_environment_config.tres")
@export var pool_capacity: int = 128

func _ready() -> void:
	_initialize_pool()

func _initialize_pool() -> void:
	_pool_items.clear()
	_available_indices.clear()
	_active_items.clear()

	for i: int in range(pool_capacity):
		var sprite := Sprite2D.new()
		sprite.name = "CosmicItem_%d" % i
		sprite.visible = false
		sprite.centered = true
		add_child(sprite)
		_pool_items.append(sprite)
		_available_indices.append(i)

func get_active_count() -> int:
	return _active_items.size()

func get_active_items() -> Array[Dictionary]:
	return _active_items

func get_available_count() -> int:
	return _available_indices.size()


func acquire_item(descriptor: Dictionary) -> int:
	if _available_indices.is_empty():
		push_warning("CosmicObjectPool: Capacidad agotada (%d items). Incrementando capacidad." % pool_capacity)
		var new_idx: int = _pool_items.size()
		var new_sprite := Sprite2D.new()
		new_sprite.name = "CosmicItem_%d" % new_idx
		new_sprite.visible = false
		new_sprite.centered = true
		add_child(new_sprite)
		_pool_items.append(new_sprite)
		_available_indices.append(new_idx)
		pool_capacity = _pool_items.size()

	var idx: int = _available_indices.pop_back()
	var sprite: Sprite2D = _pool_items[idx]
	_configure_sprite(sprite, descriptor)
	sprite.visible = true

	var item_record: Dictionary = {
		"pool_index": idx,
		"sprite": sprite,
		"world_pos": descriptor.get("world_pos", Vector2.ZERO),
		"scroll_scale": descriptor.get("scroll_scale", 0.05),
		"rotation_speed": descriptor.get("rotation_speed", 0.0),
		"base_rotation": descriptor.get("base_rotation", 0.0),
		"type": descriptor.get("type", "planet"),
		"type_variant": descriptor.get("type_variant", 0),
		"cell_coord": descriptor.get("cell_coord", Vector2i.ZERO),
		"socket_id": descriptor.get("socket_id", -1),
		"light_direction": descriptor.get("light_direction", Vector2(-0.707106, -0.707106)),
	}
	_active_items.append(item_record)
	return idx

func release_item(pool_index: int) -> void:
	for i: int in range(_active_items.size() - 1, -1, -1):
		if _active_items[i]["pool_index"] == pool_index:
			var sprite: Sprite2D = _active_items[i]["sprite"]
			sprite.visible = false
			_active_items.remove_at(i)
			_available_indices.append(pool_index)
			return

func release_cell_items(cell_coord: Vector2i) -> void:
	for i: int in range(_active_items.size() - 1, -1, -1):
		if _active_items[i]["cell_coord"] == cell_coord:
			var pool_index: int = _active_items[i]["pool_index"]
			var sprite: Sprite2D = _active_items[i]["sprite"]
			sprite.visible = false
			_active_items.remove_at(i)
			_available_indices.append(pool_index)

func release_socket_items(socket_id: int) -> void:
	for i: int in range(_active_items.size() - 1, -1, -1):
		if _active_items[i].get("socket_id", -1) == socket_id:
			var pool_index: int = _active_items[i]["pool_index"]
			var sprite: Sprite2D = _active_items[i]["sprite"]
			sprite.visible = false
			_active_items.remove_at(i)
			_available_indices.append(pool_index)

func update_item_light_direction(pool_index: int, light_dir: Vector2) -> void:
	for item: Dictionary in _active_items:
		if item["pool_index"] == pool_index:
			item["light_direction"] = light_dir
			var sprite: Sprite2D = item["sprite"]
			if is_instance_valid(sprite) and sprite.material is ShaderMaterial:
				(sprite.material as ShaderMaterial).set_shader_parameter("light_direction", light_dir)
			return

func update_item_world_pos(pool_index: int, new_world_pos: Vector2) -> void:
	for item: Dictionary in _active_items:
		if item["pool_index"] == pool_index:
			item["world_pos"] = new_world_pos
			return

func release_all() -> void:
	for item: Dictionary in _active_items:
		var sprite: Sprite2D = item["sprite"]
		sprite.visible = false
		_available_indices.append(item["pool_index"])
	_active_items.clear()

func update_parallax_positions(camera_world_pos: Vector2, delta: float, haze_color: Color) -> void:
	for item: Dictionary in _active_items:
		var sprite: Sprite2D = item["sprite"]
		var world_pos: Vector2 = item["world_pos"]
		var scroll: float = item["scroll_scale"]
		var rot_speed: float = item["rotation_speed"]

		# Ecuación continua de paralaje:
		# P_render = P_world + P_camera * (P_scroll - 1.0)
		sprite.position = world_pos + camera_world_pos * (scroll - 1.0)

		if rot_speed != 0.0:
			sprite.rotation += rot_speed * delta

		# Inyectar color de neblina al material de shader con dispersión Rayleigh según profundidad Z
		if sprite.material is ShaderMaterial:
			var sm := sprite.material as ShaderMaterial
			var itype: String = item["type"]
			match itype:
				"planet":
					sm.set_shader_parameter("biome_tint_color", haze_color)
					sm.set_shader_parameter("light_direction", item.get("light_direction", Vector2(-0.707106, -0.707106)))
				"sun":
					sm.set_shader_parameter("biome_tint_color", haze_color)
				"station":
					sm.set_shader_parameter("ambient_haze_color", haze_color)
				"galaxy":
					var target_tint: Color = Color(0.92, 0.90, 1.0, 0.95).lerp(haze_color, 0.35)
					sm.set_shader_parameter("tint_color", target_tint)
				_:
					sm.set_shader_parameter("biome_tint_color", haze_color)


func _configure_sprite(sprite: Sprite2D, desc: Dictionary) -> void:
	var itype: String = desc.get("type", "planet")
	var variant: int = desc.get("type_variant", 0)
	var final_scale: float = desc.get("scale", 1.0)
	var base_rot: float = desc.get("base_rotation", 0.0)
	var alpha_val: float = desc.get("alpha", 1.0)

	sprite.rotation = base_rot
	sprite.scale = Vector2(final_scale, final_scale)
	sprite.modulate = Color(1.0, 1.0, 1.0, alpha_val)

	match itype:
		"sun":
			var clamped_v: int = clampi(variant, 0, TEX_SUNS.size() - 1)
			sprite.texture = TEX_SUNS[clamped_v]
			var sm := ShaderMaterial.new()
			sm.shader = SHADER_SUN
			var cfg: Dictionary = SUN_SPECTRAL_CONFIGS[clamped_v]
			sm.set_shader_parameter("spectral_tint", cfg["spectral_tint"])
			sm.set_shader_parameter("corona_color", cfg["corona_color"])
			sm.set_shader_parameter("emission_boost", cfg["emission"])
			sm.set_shader_parameter("core_radius", cfg["core_radius"])
			sm.set_shader_parameter("corona_thickness", cfg["corona_thickness"])
			sm.set_shader_parameter("axial_spin_speed", cfg["spin"])
			sm.set_shader_parameter("biome_tint_color", Color(0.12, 0.04, 0.22, 1.0))
			sm.set_shader_parameter("biome_tint_intensity", desc.get("haze_depth", 0.15))
			sm.set_shader_parameter("rayleigh_depth", 0.20)
			sprite.material = sm

		"planet":
			var clamped_v: int = clampi(variant, 0, TEX_PLANETS.size() - 1)
			sprite.texture = TEX_PLANETS[clamped_v]
			var sm := ShaderMaterial.new()
			sm.shader = SHADER_PLANET
			var cfg: Dictionary = PLANET_ATMOSPHERE_CONFIGS[clamped_v]
			sm.set_shader_parameter("atmosphere_color", cfg["color"])
			sm.set_shader_parameter("atmosphere_intensity", cfg["intensity"])
			sm.set_shader_parameter("fresnel_power", cfg["fresnel"])
			sm.set_shader_parameter("planet_center", Vector2(0.5, 0.5))
			sm.set_shader_parameter("planet_radius", cfg["radius"])
			sm.set_shader_parameter("rim_edge_feather", 0.006)
			sm.set_shader_parameter("edge_crop_margin", 0.018)
			sm.set_shader_parameter("biome_tint_color", Color(0.18, 0.05, 0.32, 1.0))
			sm.set_shader_parameter("biome_tint_intensity", desc.get("haze_depth", 0.32))
			sm.set_shader_parameter("light_direction", desc.get("light_direction", Vector2(-0.707106, -0.707106)))
			sm.set_shader_parameter("light_depth", 0.35)
			sm.set_shader_parameter("terminator_offset", 0.05)
			sm.set_shader_parameter("terminator_softness", 0.35)
			sm.set_shader_parameter("outer_atmosphere_thickness", 0.028)
			sm.set_shader_parameter("outer_atmosphere_intensity", 0.9)
			sm.set_shader_parameter("dark_side_occlusion", 1.0)
			sm.set_shader_parameter("axial_spin_speed", cfg["spin"])
			sprite.material = sm

		"station":
			var clamped_v: int = clampi(variant, 0, TEX_STATIONS.size() - 1)
			sprite.texture = TEX_STATIONS[clamped_v]
			var sm := ShaderMaterial.new()
			sm.shader = SHADER_STATION
			var cfg: Dictionary = STATION_BEACON_CONFIGS[clamped_v]
			sm.set_shader_parameter("beacon_1_pos", cfg["b1_pos"])
			sm.set_shader_parameter("beacon_1_color", cfg["b1_col"])
			sm.set_shader_parameter("beacon_1_period", cfg["b1_per"])
			sm.set_shader_parameter("beacon_1_phase_offset", cfg["b1_ph"])
			sm.set_shader_parameter("beacon_1_radius", cfg["b1_rad"])
			sm.set_shader_parameter("beacon_2_pos", cfg["b2_pos"])
			sm.set_shader_parameter("beacon_2_color", cfg["b2_col"])
			sm.set_shader_parameter("beacon_2_period", cfg["b2_per"])
			sm.set_shader_parameter("beacon_2_phase_offset", cfg["b2_ph"])
			sm.set_shader_parameter("beacon_2_radius", cfg["b2_rad"])
			sm.set_shader_parameter("beacon_3_pos", cfg["b3_pos"])
			sm.set_shader_parameter("beacon_3_color", cfg["b3_col"])
			sm.set_shader_parameter("beacon_3_period", cfg["b3_per"])
			sm.set_shader_parameter("beacon_3_phase_offset", cfg["b3_ph"])
			sm.set_shader_parameter("beacon_3_radius", cfg["b3_rad"])
			sm.set_shader_parameter("beacon_4_pos", cfg["b4_pos"])
			sm.set_shader_parameter("beacon_4_color", cfg["b4_col"])
			sm.set_shader_parameter("beacon_4_period", cfg["b4_per"])
			sm.set_shader_parameter("beacon_4_phase_offset", cfg["b4_ph"])
			sm.set_shader_parameter("beacon_4_radius", cfg["b4_rad"])
			sm.set_shader_parameter("beacon_intensity", 2.4)
			sm.set_shader_parameter("ambient_haze_color", Color(0.06, 0.09, 0.18, 1.0))
			sm.set_shader_parameter("ambient_haze_intensity", desc.get("haze_depth", 0.38))
			sm.set_shader_parameter("distance_desaturation", 0.25)
			sprite.material = sm

		"galaxy":
			sprite.texture = TEX_GALAXY
			var sm := ShaderMaterial.new()
			sm.shader = SHADER_GALAXY
			sm.set_shader_parameter("spin_speed", 0.003)
			sm.set_shader_parameter("galaxy_center", Vector2(0.5, 0.5))
			sm.set_shader_parameter("core_pulse_speed", 1.3)
			sm.set_shader_parameter("core_pulse_intensity", 0.28)
			var bright: float = env_config.galaxy_overall_brightness if is_instance_valid(env_config) else 0.88
			var fade_start: float = env_config.galaxy_radial_fade_start if is_instance_valid(env_config) else 0.38
			var fade_end: float = env_config.galaxy_radial_fade_end if is_instance_valid(env_config) else 0.50
			sm.set_shader_parameter("overall_brightness", bright)
			sm.set_shader_parameter("radial_fade_start", fade_start)
			sm.set_shader_parameter("radial_fade_end", fade_end)
			sm.set_shader_parameter("tint_color", Color(0.92, 0.88, 1.0, 0.95))
			sprite.material = sm

		"black_hole":
			sprite.texture = TEX_BLACK_HOLE
			var sm := ShaderMaterial.new()
			sm.shader = SHADER_BLACK_HOLE
			sm.set_shader_parameter("event_horizon_radius", 0.115)
			sm.set_shader_parameter("horizon_edge_softness", 0.016)
			sm.set_shader_parameter("screen_lensing_strength", 1.6)
			sm.set_shader_parameter("screen_lensing_radius", 0.35)
			sm.set_shader_parameter("redshift_color", Color(0.42, 0.08, 0.02, 1.0))
			sm.set_shader_parameter("biome_tint_color", Color(0.18, 0.05, 0.32, 1.0))
			sm.set_shader_parameter("biome_tint_intensity", 0.45)
			sm.set_shader_parameter("ambient_haze_depth", desc.get("haze_depth", 0.32))
			sm.set_shader_parameter("black_cutoff", 0.035)
			sm.set_shader_parameter("black_feather", 0.24)
			sm.set_shader_parameter("radial_fade_start", 0.34)
			sm.set_shader_parameter("radial_fade_end", 0.495)
			sm.set_shader_parameter("thermal_breath_speed", 0.5)
			sprite.material = sm

		"pulsar":
			sprite.texture = TEX_PULSAR
			var sm := ShaderMaterial.new()
			sm.shader = SHADER_PULSAR
			sm.set_shader_parameter("pulsar_center", Vector2(0.5, 0.5))
			sm.set_shader_parameter("screen_lensing_strength", 1.2)
			sm.set_shader_parameter("screen_lensing_radius", 0.32)
			sm.set_shader_parameter("core_shadow_radius", 0.075)
			sm.set_shader_parameter("core_shadow_softness", 0.01)
			sm.set_shader_parameter("cone_tip_width", 0.002)
			sm.set_shader_parameter("cone_spread_angle", 0.28)
			sm.set_shader_parameter("cone_length", 0.44)
			sm.set_shader_parameter("cone_tip_feather", 0.09)
			sm.set_shader_parameter("jet_flow_speed", 2.4)
			sm.set_shader_parameter("beam_spin_speed", 0.65)
			sm.set_shader_parameter("beam_precession_angle", 0.16)
			sm.set_shader_parameter("pulse_speed", 0.95)
			sm.set_shader_parameter("pulse_intensity", 0.45)
			sm.set_shader_parameter("jet_core_color", Color(0.55, 0.96, 1.0, 1.0))
			sm.set_shader_parameter("jet_outer_color", Color(0.72, 0.26, 0.98, 1.0))
			sm.set_shader_parameter("jet_focal_color", Color(1.0, 1.0, 1.0, 1.0))
			sm.set_shader_parameter("biome_tint_color", Color(0.18, 0.05, 0.32, 1.0))
			sm.set_shader_parameter("biome_tint_intensity", 0.5)
			sm.set_shader_parameter("ambient_haze_depth", desc.get("haze_depth", 0.35))
			sm.set_shader_parameter("dust_occlusion_strength", 0.72)
			sm.set_shader_parameter("emission_master_power", 1.05)
			sm.set_shader_parameter("black_cutoff", 0.035)
			sm.set_shader_parameter("black_feather", 0.16)
			sm.set_shader_parameter("radial_fade_start", 0.36)
			sm.set_shader_parameter("radial_fade_end", 0.49)
			sprite.material = sm

		_:
			sprite.texture = TEX_PLANETS[0]
			sprite.material = null
