class_name Planet
extends Node2D

## Planet.gd
## Macro-entidad planetaria colosal (radio 300 px, diámetro 600 px, ~20x la nave).
## Consta de un Núcleo central accionable protegido por 3 capas concéntricas:
## - Manto profundo / Roca basal (50 - 120 px, 6 segmentos, 700 HP)
## - Manto intermedio (120 - 200 px, 8 segmentos, 350 HP)
## - Corteza exterior (200 - 300 px, 12 segmentos, 120 HP)
## Actúa además como nido defensor con radio de alerta de 950 px.

@export var planet_data: PlanetData
@export var core_radius: float = 50.0
@export var deep_mantle_radius: float = 120.0
@export var mid_mantle_radius: float = 200.0
@export var crust_radius: float = 300.0

@export var deep_mantle_segments_count: int = 6
@export var mid_mantle_segments_count: int = 8
@export var crust_segments_count: int = 12

@export var defender_spawn_interval: float = 6.0
@export var max_defenders: int = 4
@export var nest_trigger_radius: float = 950.0

var segment_scene: PackedScene = preload("res://scenes/combat/environment/planet_segment.tscn")
var drone_scene: PackedScene = preload("res://scenes/combat/enemies/enemy_drone.tscn")

var player: Player = null
var defender_timer: float = 2.0
var active_defenders: Array[Node2D] = []

@onready var planet_core: PlanetCore = get_node_or_null("PlanetCore")
@onready var deep_mantle_container: Node2D = get_node_or_null("DeepMantleContainer")
@onready var mid_mantle_container: Node2D = get_node_or_null("MidMantleContainer")
@onready var crust_container: Node2D = get_node_or_null("CrustContainer")


func _ready() -> void:
	if not planet_data:
		_pick_random_planet_data()

	_initialize_planet()


func _pick_random_planet_data() -> void:
	var presets := [
		"res://data/planets/verdant_planet.tres",
		"res://data/planets/volcanic_planet.tres",
		"res://data/planets/cryo_planet.tres"
	]
	var chosen_path: String = presets[randi() % presets.size()]
	if ResourceLoader.exists(chosen_path):
		planet_data = load(chosen_path) as PlanetData


func _initialize_planet() -> void:
	if not planet_data:
		return

	# 1. Configurar Núcleo central (radio 50 px, recompensa 20 BioMasa)
	if planet_core:
		planet_core.setup_core(core_radius, planet_data.core_color, planet_data.core_type, planet_data.core_biomass_reward)

	# 2. Generar Capa de Manto Profundo (50 - 120 px, 6 gajos, 700 HP)
	_build_layer(
		deep_mantle_container,
		core_radius,
		deep_mantle_radius,
		deep_mantle_segments_count,
		planet_data.deep_mantle_color,
		planet_data.deep_mantle_color.lightened(0.2),
		planet_data.deep_mantle_health,
		planet_data.biomass_per_deep_mantle
	)

	# 3. Generar Capa de Manto Intermedio (120 - 200 px, 8 gajos, 350 HP)
	_build_layer(
		mid_mantle_container,
		deep_mantle_radius,
		mid_mantle_radius,
		mid_mantle_segments_count,
		planet_data.mid_mantle_color,
		planet_data.mid_mantle_color.lightened(0.25),
		planet_data.mid_mantle_health,
		planet_data.biomass_per_mid_mantle
	)

	# 4. Generar Capa de Corteza Exterior (200 - 300 px, 12 gajos, 120 HP)
	_build_layer(
		crust_container,
		mid_mantle_radius,
		crust_radius,
		crust_segments_count,
		planet_data.crust_color,
		planet_data.crust_border_color,
		planet_data.crust_health,
		planet_data.biomass_per_crust
	)


func _build_layer(container: Node2D, r_in: float, r_out: float, count: int, col: Color, b_col: Color, hp: float, xp_biomass: int) -> void:
	if not container or not segment_scene:
		return

	for child in container.get_children():
		child.queue_free()

	var angle_step := TAU / float(count)
	for i in range(count):
		var a_start := angle_step * float(i)
		var a_end := angle_step * float(i + 1)

		var seg := segment_scene.instantiate() as PlanetSegment
		if not seg:
			continue

		container.add_child(seg)
		seg.setup_segment(r_in, r_out, a_start, a_end, col, b_col, hp, xp_biomass)


func _process(delta: float) -> void:
	# Rotación diferencial sutil de las capas
	if crust_container:
		crust_container.rotation += delta * 0.015
	if mid_mantle_container:
		mid_mantle_container.rotation -= delta * 0.01
	if deep_mantle_container:
		deep_mantle_container.rotation += delta * 0.005

	_handle_defender_nest(delta)


func _handle_defender_nest(delta: float) -> void:
	if not drone_scene or not is_inside_tree():
		return

	active_defenders = active_defenders.filter(func(d: Node2D) -> bool: return is_instance_valid(d))

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if not player:
			return

	var dist_sq := global_position.distance_squared_to(player.global_position)
	if dist_sq > nest_trigger_radius * nest_trigger_radius:
		return

	defender_timer -= delta
	if defender_timer <= 0.0:
		defender_timer = defender_spawn_interval
		if active_defenders.size() < max_defenders:
			_spawn_defender_drone()


func _spawn_defender_drone() -> void:
	var drone := drone_scene.instantiate() as Node2D
	if not drone:
		return

	var ang := randf() * TAU
	var spawn_pos := global_position + Vector2(cos(ang), sin(ang)) * (crust_radius + 60.0)
	drone.global_position = spawn_pos

	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(drone)
		active_defenders.append(drone)
