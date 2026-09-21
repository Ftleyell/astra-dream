class_name Planet
extends Node2D

## Planet.gd
## Macro-entidad planetaria destructible (~5 veces el tamaño del jugador, radio ~80 px).
## Compuesto por un Núcleo central protegido por un Manto de 6 segmentos y una Corteza de 8 segmentos.
## Actúa además como nido defensor desplegando drones cuando el jugador se acerca.

@export var planet_data: PlanetData
@export var core_radius: float = 30.0
@export var mantle_radius: float = 55.0
@export var crust_radius: float = 80.0
@export var mantle_segments_count: int = 6
@export var crust_segments_count: int = 8

@export var defender_spawn_interval: float = 7.0
@export var max_defenders: int = 3
@export var nest_trigger_radius: float = 750.0

var segment_scene: PackedScene = preload("res://scenes/combat/environment/planet_segment.tscn")
var drone_scene: PackedScene = preload("res://scenes/combat/enemies/enemy_drone.tscn")

var player: Player = null
var defender_timer: float = 2.0 # Primer spawn a los 2 segundos si el jugador está cerca
var active_defenders: Array[Node2D] = []

@onready var planet_core: PlanetCore = get_node_or_null("PlanetCore")
@onready var mantle_container: Node2D = get_node_or_null("MantleContainer")
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

	# 1. Configurar Núcleo
	if planet_core:
		planet_core.setup_core(core_radius, planet_data.core_color, planet_data.core_type)

	# 2. Generar Capa de Manto (6 gajos)
	_build_layer(
		mantle_container,
		core_radius,
		mantle_radius,
		mantle_segments_count,
		planet_data.mantle_color,
		planet_data.mantle_color.lightened(0.25),
		planet_data.mantle_health,
		planet_data.biomass_per_mantle
	)

	# 3. Generar Capa de Corteza Exterior (8 gajos)
	_build_layer(
		crust_container,
		mantle_radius,
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

	# Limpiar hijos previos si los hubiese
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
	# Rotación orbital lenta e inercial de la corteza y el manto
	if crust_container:
		crust_container.rotation += delta * 0.04
	if mantle_container:
		mantle_container.rotation -= delta * 0.02

	_handle_defender_nest(delta)


func _handle_defender_nest(delta: float) -> void:
	if not drone_scene or not is_inside_tree():
		return

	# Limpiar referencias de drones muertos
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
	var spawn_pos := global_position + Vector2(cos(ang), sin(ang)) * (crust_radius + 45.0)
	drone.global_position = spawn_pos

	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(drone)
		active_defenders.append(drone)
