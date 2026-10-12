class_name CosmosOrbitalSlotTracker
extends RefCounted

## CosmosOrbitalSlotTracker.gd
## Proveedor analítico de slots orbitales alrededor de estrellas y planetas de fondo en Cosmos Engine.
## Realiza la búsqueda de slots más cercanos en coordenadas de gameplay y resuelve la proyección
## matemática entre el estrato de Parallax2D cósmico y el mundo de GameplayWorld (1.0).

const CosmosOrbitSlot = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbit_slot.gd")

var cosmos_root: CosmosRootNode = null

func _init(p_root: CosmosRootNode = null) -> void:
	cosmos_root = p_root

## Obtiene slots de órbita exterior alrededor de estrellas activas en el estrato solar
func get_star_orbit_slots(world_position: Vector2, search_radius: float = 8000.0) -> Array[CosmosOrbitSlot]:
	var results: Array[CosmosOrbitSlot] = []
	if cosmos_root == null or cosmos_root.solar_streamer == null:
		return results

	var streamer: CosmosSolarSystemStreamer = cosmos_root.solar_streamer
	var parallax_layer: Parallax2D = streamer.parallax_layer
	var scroll_scale: Vector2 = parallax_layer.scroll_scale if parallax_layer != null else Vector2(0.20, 0.20)
	var active_systems: Dictionary = streamer.get_active_systems()

	for cell: Vector2i in active_systems.keys():
		var sys: CosmosSolarSystem2D = active_systems[cell]
		if not is_instance_valid(sys) or sys.star_body == null:
			continue

		var star_layer_pos: Vector2 = sys.position + sys.star_body.position
		var target_layer_pos: Vector2 = world_position * scroll_scale
		if star_layer_pos.distance_to(target_layer_pos) > (search_radius * scroll_scale.x):
			continue

		var bounding_r: float = sys.get_bounding_radius()
		var slot_radius: float = maxf(bounding_r * 1.15, 3200.0)
		var base_vel: float = streamer.system_profile.base_angular_velocity if streamer.system_profile != null else 0.05
		var kepler_ang_vel: float = CosmosKeplerOrbitMath.calculate_keplerian_angular_velocity(
			base_vel,
			1000.0,
			slot_radius,
			1.0
		)
		var cell_seed: int = streamer.run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 888)
		var initial_theta: float = CosmosHasher.hash_2d_float(cell_seed, 101, 11) * TAU

		var slot: CosmosOrbitSlot = CosmosOrbitSlot.new(
			CosmosOrbitSlot.SlotCenterType.STAR,
			cell,
			star_layer_pos,
			slot_radius,
			kepler_ang_vel,
			initial_theta,
			sys.star_body,
			StringName("StarOrbitSlot_%d_%d" % [cell.x, cell.y]),
			scroll_scale
		)
		results.append(slot)

	# Si active_systems no tiene ningún sistema cargado en frustum, derivar slot analítico determinista desde el macro-grid
	if results.is_empty() and streamer.get_macro_grid() != null:
		var grid: CosmosMacroGrid = streamer.get_macro_grid()
		var target_layer_pos: Vector2 = world_position * scroll_scale
		var center_cell: Vector2i = grid.world_to_grid_coords(target_layer_pos)
		for ox: int in range(-1, 2):
			for oy: int in range(-1, 2):
				var cell: Vector2i = center_cell + Vector2i(ox, oy)
				var sys_pos: Vector2 = streamer.get_system_position_for_cell(cell)
				if sys_pos.distance_to(target_layer_pos) <= (search_radius * scroll_scale.x):
					var cell_seed: int = streamer.run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 888)
					var slot_radius: float = 3800.0
					var base_vel: float = streamer.system_profile.base_angular_velocity if streamer.system_profile != null else 0.05
					var kepler_ang_vel: float = CosmosKeplerOrbitMath.calculate_keplerian_angular_velocity(base_vel, 1000.0, slot_radius, 1.0)
					var initial_theta: float = CosmosHasher.hash_2d_float(cell_seed, 101, 11) * TAU
					var slot: CosmosOrbitSlot = CosmosOrbitSlot.new(
						CosmosOrbitSlot.SlotCenterType.STAR,
						cell,
						sys_pos,
						slot_radius,
						kepler_ang_vel,
						initial_theta,
						null,
						StringName("StarOrbitSlot_%d_%d" % [cell.x, cell.y]),
						scroll_scale
					)
					results.append(slot)
					break
			if not results.is_empty():
				break

	return results

## Obtiene slots de órbita alrededor de planetas de fondo activos (ideal para satélites/balizas)
func get_planet_orbit_slots(world_position: Vector2, search_radius: float = 6000.0) -> Array[CosmosOrbitSlot]:
	var results: Array[CosmosOrbitSlot] = []
	if cosmos_root == null or cosmos_root.solar_streamer == null:
		return results

	var streamer: CosmosSolarSystemStreamer = cosmos_root.solar_streamer
	var parallax_layer: Parallax2D = streamer.parallax_layer
	var scroll_scale: Vector2 = parallax_layer.scroll_scale if parallax_layer != null else Vector2(0.20, 0.20)
	var active_systems: Dictionary = streamer.get_active_systems()

	var target_layer_pos: Vector2 = world_position * scroll_scale

	for cell: Vector2i in active_systems.keys():
		var sys: CosmosSolarSystem2D = active_systems[cell]
		if not is_instance_valid(sys):
			continue

		for p_idx in range(sys.planets.size()):
			var planet_body: CosmosOrbitalBody2D = sys.planets[p_idx]
			if not is_instance_valid(planet_body):
				continue

			var planet_layer_pos: Vector2 = sys.position + planet_body.position
			if planet_layer_pos.distance_to(target_layer_pos) > (search_radius * scroll_scale.x):
				continue

			var vis_radius: float = float(planet_body.get_meta(&"visual_radius", 130.0))
			# Órbita del satélite en espacio de capa cósmica
			var orbit_dist: float = vis_radius * 2.2
			var base_vel: float = streamer.system_profile.base_angular_velocity if streamer.system_profile != null else 0.05
			var sat_ang_vel: float = base_vel * 3.5
			var p_seed: int = streamer.run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 444 + p_idx)
			var init_theta: float = CosmosHasher.hash_2d_float(p_seed, 202, 22) * TAU

			var slot: CosmosOrbitSlot = CosmosOrbitSlot.new(
				CosmosOrbitSlot.SlotCenterType.PLANET,
				cell,
				planet_layer_pos,
				orbit_dist,
				sat_ang_vel,
				init_theta,
				planet_body,
				StringName("PlanetOrbitSlot_%d_%d_%d" % [cell.x, cell.y, p_idx]),
				scroll_scale
			)
			results.append(slot)

	return results

## Proyecta un slot analítico a coordenadas del mundo de GameplayWorld considerando la cámara actual.
## En Godot Parallax2D:
## Posición en pantalla del nodo en la capa = PosCapa - (PosCamara * ScrollScale) + ScrollOffset
## Para que un nodo en GameplayWorld (ScrollScale = 1.0) aparezca visualmente alineado en pantalla con el nodo de la capa:
## PosPantalla_Gameplay = PosMundo - PosCamara
## Igualando ambas:
## PosMundo - PosCamara = PosCapa - (PosCamara * ScrollScale) + ScrollOffset
## => PosMundo = PosCamara * (1.0 - ScrollScale) + PosCapa + ScrollOffset
static func project_slot_to_world(slot: CosmosOrbitSlot, global_time: float, camera: Camera2D) -> Vector2:
	if slot == null:
		return Vector2.ZERO

	var layer_pos: Vector2 = slot.calculate_layer_position(global_time)
	var cam_pos: Vector2 = Vector2.ZERO
	if camera != null and is_instance_valid(camera):
		cam_pos = camera.global_position

	var s_scale: Vector2 = slot.layer_scroll_scale
	var world_pos: Vector2 = (cam_pos * (Vector2.ONE - s_scale)) + layer_pos
	return world_pos
