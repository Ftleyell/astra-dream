class_name CosmosHostController
extends Node2D

## CosmosHostController.gd
## Fachada unificada de alto nivel para Cosmos Engine en entornos de combate.
##
## Responsabilidades:
## 1. Conexión reactiva con PauseArbitrator: sincroniza el estado de pausa del árbol
##    y suspende el avance de tiempo cósmico cuando se adquieren tokens de pausa.
## 2. API de Freeze / Hit-Stop desacoplada: set_frozen(true) para congelar el avance
##    de tiempo cósmico durante micro-hit-stops balísticos sin afectar la cámara ni el árbol entero.
## 3. Control de regiones espaciales: change_region() con transiciones suaves vía CosmicBiomeBlender.
## 4. Inyección de POIs narrativos hacia CosmicPoiRegistry (relativos o absolutos).
## 5. Control de escala de tiempo cósmico (Time Warp).

const CosmosRootNode = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.gd")
const CosmosBiomeConfig = preload("res://scenes/combat/environment/cosmos/resources/cosmic_biome_config.gd")
const CosmicPoiConfig = preload("res://scenes/combat/environment/cosmos/resources/cosmic_poi_config.gd")
const CosmicBiomeBlender = preload("res://scenes/combat/environment/cosmos/core/cosmic_biome_blender.gd")
const CosmosOrbitSlot = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbit_slot.gd")
const CosmosOrbitalSlotTracker = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbital_slot_tracker.gd")

signal region_changed(region_id: StringName, biome_config: CosmosBiomeConfig)
signal freeze_state_changed(is_frozen: bool)
signal solar_system_streamed(system: CosmosSolarSystem2D, cell: Vector2i, star_slot: CosmosOrbitSlot, planet_slots: Array)
signal solar_system_unstreamed(system: CosmosSolarSystem2D, cell: Vector2i)

@export var cosmos_root: CosmosRootNode = null:
	set(val):
		cosmos_root = val
		_slot_tracker = CosmosOrbitalSlotTracker.new(cosmos_root)
		_connect_cosmos_root_signals()
@export var default_region_id: StringName = &"perseus_rift"
@export var auto_connect_pause_arbitrator: bool = true

var _biome_blender: CosmicBiomeBlender = null
var _slot_tracker: CosmosOrbitalSlotTracker = null
var _current_region_id: StringName = &""
var _is_frozen: bool = false
var _is_paused_by_arbitrator: bool = false

# Catálogo pre-cargado de regiones conocidas
const REGION_REGISTRY: Dictionary[StringName, String] = {
	&"perseus_rift": "res://scenes/combat/environment/cosmos/resources/data/biomes/biome_01_perseus_rift.tres",
	&"hyperion_forge": "res://scenes/combat/environment/cosmos/resources/data/biomes/biome_02_hyperion_forge.tres",
	&"carina_abyss": "res://scenes/combat/environment/cosmos/resources/data/biomes/biome_03_carina_abyss.tres",
	&"crimson_veil": "res://scenes/combat/environment/cosmos/resources/data/biomes/biome_04_crimson_veil.tres",
	&"silica_corona": "res://scenes/combat/environment/cosmos/resources/data/biomes/biome_05_silica_corona.tres",
	&"bootes_void": "res://scenes/combat/environment/cosmos/resources/data/biomes/biome_06_bootes_void.tres"
}

func _ready() -> void:
	# Permitir que este nodo reciba notificaciones de proceso incluso durante la pausa
	process_mode = Node.PROCESS_MODE_ALWAYS

	_find_or_validate_cosmos_root()
	_initialize_blender()

	if auto_connect_pause_arbitrator:
		_connect_to_pause_arbitrator()

	if default_region_id != &"":
		change_region(default_region_id, 0.0)

func _find_or_validate_cosmos_root() -> void:
	if cosmos_root == null:
		cosmos_root = get_node_or_null("CosmosRoot") as CosmosRootNode
	if cosmos_root == null:
		cosmos_root = get_parent() as CosmosRootNode if get_parent() is CosmosRootNode else null
	_slot_tracker = CosmosOrbitalSlotTracker.new(cosmos_root)
	_connect_cosmos_root_signals()

func _connect_cosmos_root_signals() -> void:
	if cosmos_root == null:
		return
	if not cosmos_root.solar_system_streamed.is_connected(_on_solar_system_streamed):
		cosmos_root.solar_system_streamed.connect(_on_solar_system_streamed)
	if not cosmos_root.solar_system_unstreamed.is_connected(_on_solar_system_unstreamed):
		cosmos_root.solar_system_unstreamed.connect(_on_solar_system_unstreamed)

func _on_solar_system_streamed(system: CosmosSolarSystem2D, cell: Vector2i) -> void:
	var tracker := get_slot_tracker()
	var slots_dict: Dictionary = tracker.get_slots_for_system(system, cell)
	var star_slot: CosmosOrbitSlot = slots_dict.get("star_slot") as CosmosOrbitSlot
	var planet_slots: Array = slots_dict.get("planet_slots", [])
	solar_system_streamed.emit(system, cell, star_slot, planet_slots)

func _on_solar_system_unstreamed(system: CosmosSolarSystem2D, cell: Vector2i) -> void:
	solar_system_unstreamed.emit(system, cell)

func get_active_solar_systems() -> Dictionary:
	if cosmos_root != null and cosmos_root.solar_streamer != null:
		return cosmos_root.solar_streamer.get_active_systems()
	return {}

func _initialize_blender() -> void:
	if cosmos_root != null:
		_biome_blender = CosmicBiomeBlender.new(cosmos_root.nebula_controller, cosmos_root.environment_profile)
	else:
		_biome_blender = CosmicBiomeBlender.new(null, null)

func _connect_to_pause_arbitrator() -> void:
	if not Engine.has_singleton("PauseArbitrator") and not is_instance_valid(PauseArbitrator):
		return
	
	if PauseArbitrator != null:
		if not PauseArbitrator.pause_state_changed.is_connected(_on_pause_state_changed):
			PauseArbitrator.pause_state_changed.connect(_on_pause_state_changed)
		_is_paused_by_arbitrator = PauseArbitrator.is_paused()
		_update_effective_freeze()

func _on_pause_state_changed(is_paused: bool, _reasons: Array[StringName]) -> void:
	_is_paused_by_arbitrator = is_paused
	_update_effective_freeze()

## Sincroniza el congelamiento efectivo considerando tanto hit-stops locales como pausas globales
func _update_effective_freeze() -> void:
	var should_freeze: bool = _is_frozen or _is_paused_by_arbitrator
	if cosmos_root != null and is_instance_valid(cosmos_root):
		cosmos_root.is_frozen = should_freeze
	freeze_state_changed.emit(should_freeze)

## Establece el congelamiento local (hit-stop de combate, freeze balístico).
func set_frozen(p_frozen: bool) -> void:
	_is_frozen = p_frozen
	_update_effective_freeze()

func is_frozen() -> bool:
	return _is_frozen or _is_paused_by_arbitrator

## Cambia la región cósmica activa cargando el bioma correspondiente y efectuando una transición suave.
func change_region(region_id: StringName, blend_duration: float = 2.0) -> bool:
	if not REGION_REGISTRY.has(region_id):
		push_warning("CosmosHostController: Region '%s' no encontrada en REGION_REGISTRY." % region_id)
		return false

	var path: String = REGION_REGISTRY[region_id]
	var biome_res: CosmosBiomeConfig = load(path) as CosmosBiomeConfig
	if biome_res == null:
		push_error("CosmosHostController: No se pudo cargar el bioma para '%s' en %s" % [region_id, path])
		return false

	return apply_biome(biome_res, blend_duration, region_id)

## Aplica directamente un CosmosBiomeConfig arbitrario con transición suave.
func apply_biome(biome_config: CosmosBiomeConfig, blend_duration: float = 2.0, region_id: StringName = &"") -> bool:
	if biome_config == null:
		return false

	_current_region_id = region_id if region_id != &"" else biome_config.biome_id

	if _biome_blender != null:
		if cosmos_root != null and _biome_blender.nebula_controller == null:
			_biome_blender.nebula_controller = cosmos_root.nebula_controller
			_biome_blender.environment_profile = cosmos_root.environment_profile
		_biome_blender.blend_to_biome(biome_config, blend_duration, self)

	region_changed.emit(_current_region_id, biome_config)
	return true

func get_current_region_id() -> StringName:
	return _current_region_id

## Inyecta un Punto de Interés astronómico narrativo en coordenadas relativas a la posición del jugador
func inject_poi_relative_to_player(offset_cells: Vector2i, config: CosmicPoiConfig) -> Vector2i:
	if cosmos_root == null:
		return Vector2i.ZERO
	
	var origin_cell: Vector2i = Vector2i.ZERO
	if cosmos_root.solar_streamer != null:
		var current_layer_pos: Vector2 = cosmos_root.get_absolute_position(
			cosmos_root.player_target.global_position if is_instance_valid(cosmos_root.player_target) else Vector2.ZERO
		)
		origin_cell = cosmos_root.solar_streamer.get_macro_grid().world_to_grid_coords(current_layer_pos)

	return cosmos_root.register_relative_poi(offset_cells, config, origin_cell)

## Inyecta un Punto de Interés astronómico narrativo en coordenadas absolutas del macro-grid
func inject_poi_at_virtual_coords(grid_coords: Vector2i, config: CosmicPoiConfig) -> void:
	if cosmos_root != null:
		cosmos_root.register_poi(grid_coords, config)

## Limpia todos los POIs inyectados devolviendo la generación procedural pura
func clear_poi_overrides() -> void:
	if cosmos_root != null:
		cosmos_root.clear_poi_overrides()

## Controla la escala de tiempo cósmica (Time Warp)
func set_time_scale(scale_val: float) -> void:
	if cosmos_root != null:
		cosmos_root.time_scale = maxf(scale_val, 0.0)

func get_time_scale() -> float:
	return cosmos_root.time_scale if cosmos_root != null else 1.0

func get_biome_blender() -> CosmicBiomeBlender:
	return _biome_blender

## Devuelve la instancia del tracker de slots orbitales
func get_slot_tracker() -> CosmosOrbitalSlotTracker:
	if _slot_tracker == null:
		_slot_tracker = CosmosOrbitalSlotTracker.new(cosmos_root)
	elif _slot_tracker.cosmos_root == null and cosmos_root != null:
		_slot_tracker.cosmos_root = cosmos_root
	return _slot_tracker

## Obtiene slots de órbita alrededor de soles/estrellas de fondo
func get_star_orbit_slots(world_position: Vector2, search_radius: float = 8000.0) -> Array[CosmosOrbitSlot]:
	return get_slot_tracker().get_star_orbit_slots(world_position, search_radius)

## Obtiene slots de órbita alrededor de planetas de fondo
func get_planet_orbit_slots(world_position: Vector2, search_radius: float = 6000.0) -> Array[CosmosOrbitSlot]:
	return get_slot_tracker().get_planet_orbit_slots(world_position, search_radius)

## Proyecta un slot analítico a coordenadas del mundo de GameplayWorld sincronizadas con la cámara
func project_slot_to_world(slot: CosmosOrbitSlot, global_time: float, camera: Camera2D) -> Vector2:
	return CosmosOrbitalSlotTracker.project_slot_to_world(slot, global_time, camera)
