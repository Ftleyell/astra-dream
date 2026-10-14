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
	var target_layer_pos: Vector2 = world_position * scroll_scale

	for cell: Vector2i in active_systems.keys():
		var sys: CosmosSolarSystem2D = active_systems[cell]
		if not is_instance_valid(sys) or sys.star_body == null:
			continue

		var star_layer_pos: Vector2 = sys.position + (sys.star_body.position if sys.star_body != null else Vector2.ZERO)
		if search_radius > 0.0 and star_layer_pos.distance_to(target_layer_pos) > search_radius:
			continue

		var slot: CosmosOrbitSlot = create_star_orbit_slot(sys, cell, scroll_scale)
		results.append(slot)

	# Si active_systems no tiene ningún sistema cargado en frustum, derivar slot analítico determinista desde el macro-grid
	if results.is_empty() and streamer.get_macro_grid() != null:
		var grid: CosmosMacroGrid = streamer.get_macro_grid()
		var center_cell: Vector2i = grid.world_to_grid_coords(target_layer_pos)
		var effective_spawn_chance: float = streamer.system_profile.spawn_chance if streamer.system_profile != null else 0.75

		for ox: int in range(-1, 2):
			for oy: int in range(-1, 2):
				var cell: Vector2i = center_cell + Vector2i(ox, oy)
				var has_override: bool = streamer.poi_registry != null and streamer.poi_registry.has_poi(cell)
				if not has_override and grid.get_cell_pseudorandom_float(cell, 9091) > effective_spawn_chance:
					continue

				var sys_pos: Vector2 = streamer.get_system_position_for_cell(cell)
				if search_radius <= 0.0 or sys_pos.distance_to(target_layer_pos) <= search_radius:
					var cell_seed: int = streamer.run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 888)
					var slot_radius: float = 1450.0
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

	if results.size() > 1:
		results.sort_custom(func(a: CosmosOrbitSlot, b: CosmosOrbitSlot) -> bool:
			return a.center_layer_position.distance_squared_to(target_layer_pos) < b.center_layer_position.distance_squared_to(target_layer_pos)
		)

	return results

## Obtiene slots en el centro exacto de estrellas activas (r = 0, omega = 0), ideal para Forja Cuántica
func get_star_center_slots(world_position: Vector2, search_radius: float = 8000.0) -> Array[CosmosOrbitSlot]:
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
		if not is_instance_valid(sys) or sys.star_body == null:
			continue

		var star_layer_pos: Vector2 = sys.position + sys.star_body.position
		if search_radius > 0.0 and star_layer_pos.distance_to(target_layer_pos) > search_radius:
			continue

		var slot: CosmosOrbitSlot = create_star_center_slot(sys, cell, scroll_scale)
		results.append(slot)

	# Si active_systems no tiene ningún sistema cargado en frustum, derivar slot analítico determinista desde el macro-grid
	if results.is_empty() and streamer.get_macro_grid() != null:
		var grid: CosmosMacroGrid = streamer.get_macro_grid()
		var center_cell: Vector2i = grid.world_to_grid_coords(target_layer_pos)
		var effective_spawn_chance: float = streamer.system_profile.spawn_chance if streamer.system_profile != null else 0.75

		for ox: int in range(-1, 2):
			for oy: int in range(-1, 2):
				var cell: Vector2i = center_cell + Vector2i(ox, oy)
				var has_override: bool = streamer.poi_registry != null and streamer.poi_registry.has_poi(cell)
				if not has_override and grid.get_cell_pseudorandom_float(cell, 9091) > effective_spawn_chance:
					continue

				var sys_pos: Vector2 = streamer.get_system_position_for_cell(cell)
				if search_radius <= 0.0 or sys_pos.distance_to(target_layer_pos) <= search_radius:
					var slot: CosmosOrbitSlot = CosmosOrbitSlot.new(
						CosmosOrbitSlot.SlotCenterType.STAR,
						cell,
						sys_pos,
						0.0,
						0.0,
						0.0,
						null,
						StringName("StarCenterSlot_%d_%d" % [cell.x, cell.y]),
						scroll_scale
					)
					results.append(slot)
					break
			if not results.is_empty():
				break

	if results.size() > 1:
		results.sort_custom(func(a: CosmosOrbitSlot, b: CosmosOrbitSlot) -> bool:
			return a.center_layer_position.distance_squared_to(target_layer_pos) < b.center_layer_position.distance_squared_to(target_layer_pos)
		)

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

		var p_slots: Array[CosmosOrbitSlot] = create_planet_orbit_slots(sys, cell, scroll_scale)
		for slot: CosmosOrbitSlot in p_slots:
			if search_radius > 0.0:
				var slot_layer_pos: Vector2 = slot.center_layer_position
				if slot_layer_pos.distance_to(target_layer_pos) > search_radius:
					continue
			results.append(slot)

	# Si active_systems no tiene ningún planeta en frustum, derivar slots analíticos deterministas desde el macro-grid
	if results.is_empty() and streamer.get_macro_grid() != null:
		var grid: CosmosMacroGrid = streamer.get_macro_grid()
		var center_cell: Vector2i = grid.world_to_grid_coords(target_layer_pos)
		var p_cfg: CosmosPlanetarySystemConfig = streamer.system_profile.get_effective_planetary_config() if streamer.system_profile != null else null
		var base_vel: float = streamer.system_profile.base_angular_velocity if streamer.system_profile != null else 0.05
		var eff_min_r: float = p_cfg.orbit_radius_min if p_cfg != null else 1200.0
		var eff_max_r: float = p_cfg.orbit_radius_max if p_cfg != null else 3500.0
		var eff_spacing: float = p_cfg.min_orbital_spacing if p_cfg != null else 400.0
		var effective_spawn_chance: float = streamer.system_profile.spawn_chance if streamer.system_profile != null else 0.75

		var nearest_cell: Vector2i = center_cell
		var nearest_dist_sq: float = INF
		var has_nearest: bool = false

		for ox: int in range(-2, 3):
			for oy: int in range(-2, 3):
				var cell: Vector2i = center_cell + Vector2i(ox, oy)
				var has_override: bool = streamer.poi_registry != null and streamer.poi_registry.has_poi(cell)
				if not has_override and grid.get_cell_pseudorandom_float(cell, 9091) > effective_spawn_chance:
					continue

				var sys_pos: Vector2 = streamer.get_system_position_for_cell(cell)
				var d: float = sys_pos.distance_to(target_layer_pos)
				if search_radius > 0.0 and d > search_radius:
					continue
				var d_sq: float = d * d
				if d_sq < nearest_dist_sq:
					nearest_dist_sq = d_sq
					nearest_cell = cell
					has_nearest = true

		if has_nearest:
			var cell: Vector2i = nearest_cell
			var sys_pos: Vector2 = streamer.get_system_position_for_cell(cell)
			var cell_seed: int = streamer.run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 777)
			var num_planets: int = p_cfg.min_planets if p_cfg != null else 3
			var planet_count_range: int = (p_cfg.max_planets - p_cfg.min_planets) if p_cfg != null else 2
			if planet_count_range > 0:
				var planet_rnd: float = CosmosHasher.hash_2d_float(cell_seed, 202, 22)
				num_planets += int(planet_rnd * float(planet_count_range + 1))
			num_planets = maxi(num_planets, 1)

			var base_sys_theta: float = CosmosHasher.hash_2d_float(cell_seed, 505, 55) * TAU
			var theta_step: float = TAU / float(num_planets)
			var prev_r: float = 0.0

			for p_idx: int in range(num_planets):
				var p_seed: int = cell_seed + ((p_idx + 1) * 733)
				var t_norm: float = float(p_idx) / float(maxi(num_planets - 1, 1))
				var exp_curve: float = pow(t_norm, 1.15)
				var ideal_r: float = lerpf(eff_min_r, eff_max_r, exp_curve)
				var r_jit: float = (CosmosHasher.hash_2d_float(p_seed, 303, 33) - 0.5) * (eff_spacing * 0.35)
				var actual_r: float = ideal_r + r_jit
				if p_idx > 0:
					actual_r = maxf(actual_r, prev_r + eff_spacing)
				prev_r = actual_r

				var dir_sign: float = 1.0 if CosmosHasher.hash_2d_float(p_seed, 404, 44) > 0.1 else -1.0
				var p_ang_vel: float = CosmosKeplerOrbitMath.calculate_keplerian_angular_velocity(base_vel, eff_min_r, actual_r, dir_sign)
				var p_init_theta: float = fposmod(base_sys_theta + (float(p_idx) * theta_step), TAU)

				# Posición instantánea inicial del planeta respecto al centro del sistema
				var rel_planet_pos: Vector2 = CosmosKeplerOrbitMath.calculate_orbit_position(actual_r, p_init_theta, p_ang_vel, 0.0)
				var planet_layer_pos: Vector2 = sys_pos + rel_planet_pos

				var vis_radius: float = 130.0
				var orbit_dist: float = vis_radius * 2.2
				var sat_ang_vel: float = base_vel * 3.5
				var sat_seed: int = streamer.run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 444 + p_idx)
				var init_sat_theta: float = CosmosHasher.hash_2d_float(sat_seed, 202, 22) * TAU

				var slot: CosmosOrbitSlot = CosmosOrbitSlot.new(
					CosmosOrbitSlot.SlotCenterType.PLANET,
					cell,
					sys_pos,
					orbit_dist,
					sat_ang_vel,
					init_sat_theta,
					null,
					StringName("PlanetOrbitSlot_%d_%d_%d" % [cell.x, cell.y, p_idx]),
					scroll_scale,
					actual_r,
					p_init_theta,
					p_ang_vel
				)
				results.append(slot)


	if results.size() > 1:
		results.sort_custom(func(a: CosmosOrbitSlot, b: CosmosOrbitSlot) -> bool:
			return a.center_layer_position.distance_squared_to(target_layer_pos) < b.center_layer_position.distance_squared_to(target_layer_pos)
		)

	return results

## Construye el slot de órbita estelar para un sistema solar instanciado
func create_star_orbit_slot(sys: CosmosSolarSystem2D, cell: Vector2i, scroll_scale: Vector2) -> CosmosOrbitSlot:
	var streamer: CosmosSolarSystemStreamer = cosmos_root.solar_streamer if cosmos_root != null else null
	var star_layer_pos: Vector2 = sys.position + (sys.star_body.position if sys.star_body != null else Vector2.ZERO)
	var slot_radius: float = 1450.0
	var base_vel: float = streamer.system_profile.base_angular_velocity if (streamer != null and streamer.system_profile != null) else 0.05
	var kepler_ang_vel: float = CosmosKeplerOrbitMath.calculate_keplerian_angular_velocity(
		base_vel,
		1000.0,
		slot_radius,
		1.0
	)
	var run_seed: int = streamer.run_seed if streamer != null else 428175
	var cell_seed: int = run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 888)
	var initial_theta: float = CosmosHasher.hash_2d_float(cell_seed, 101, 11) * TAU

	return CosmosOrbitSlot.new(
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

## Construye el slot anclado al centro solar exacto (r = 0.0, omega = 0.0) para un sistema solar
func create_star_center_slot(sys: CosmosSolarSystem2D, cell: Vector2i, scroll_scale: Vector2) -> CosmosOrbitSlot:
	var star_layer_pos: Vector2 = sys.position + (sys.star_body.position if (is_instance_valid(sys) and sys.star_body != null) else Vector2.ZERO)
	return CosmosOrbitSlot.new(
		CosmosOrbitSlot.SlotCenterType.STAR,
		cell,
		star_layer_pos,
		0.0,
		0.0,
		0.0,
		sys.star_body if is_instance_valid(sys) else null,
		StringName("StarCenterSlot_%d_%d" % [cell.x, cell.y]),
		scroll_scale
	)

## Construye todos los slots de órbita planetaria para los planetas de fondo de un sistema solar
func create_planet_orbit_slots(sys: CosmosSolarSystem2D, cell: Vector2i, scroll_scale: Vector2) -> Array[CosmosOrbitSlot]:
	var results: Array[CosmosOrbitSlot] = []
	var streamer: CosmosSolarSystemStreamer = cosmos_root.solar_streamer if cosmos_root != null else null
	var base_vel: float = streamer.system_profile.base_angular_velocity if (streamer != null and streamer.system_profile != null) else 0.05
	var run_seed: int = streamer.run_seed if streamer != null else 428175

	for p_idx in range(sys.planets.size()):
		var planet_body: CosmosOrbitalBody2D = sys.planets[p_idx]
		if not is_instance_valid(planet_body):
			continue

		var star_pos: Vector2 = sys.star_body.position if sys.star_body != null else Vector2.ZERO
		var star_layer_pos: Vector2 = sys.position + star_pos
		var vis_radius: float = float(planet_body.get_meta(&"visual_radius", 130.0))
		var orbit_dist: float = vis_radius * 2.2
		var sat_ang_vel: float = base_vel * 3.5
		var p_seed: int = run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 444 + p_idx)
		var init_theta: float = CosmosHasher.hash_2d_float(p_seed, 202, 22) * TAU

		var slot: CosmosOrbitSlot = CosmosOrbitSlot.new(
			CosmosOrbitSlot.SlotCenterType.PLANET,
			cell,
			star_layer_pos,
			orbit_dist,
			sat_ang_vel,
			init_theta,
			planet_body,
			StringName("PlanetOrbitSlot_%d_%d_%d" % [cell.x, cell.y, p_idx]),
			scroll_scale,
			planet_body.orbit_radius,
			planet_body.initial_theta,
			planet_body.angular_velocity
		)
		results.append(slot)


	return results

## Obtiene el slot orbital dedicado reservado para el planeta destructible en el sistema solar dado
func get_destructible_planet_slot(sys: CosmosSolarSystem2D, cell: Vector2i) -> CosmosOrbitSlot:
	if not is_instance_valid(sys) or sys.star_body == null:
		return null

	var streamer: CosmosSolarSystemStreamer = cosmos_root.solar_streamer if cosmos_root != null else null
	var parallax_layer: Parallax2D = streamer.parallax_layer if streamer != null else null
	var scroll_scale: Vector2 = parallax_layer.scroll_scale if parallax_layer != null else Vector2(0.20, 0.20)
	var star_layer_pos: Vector2 = sys.position + sys.star_body.position

	var slot_radius: float = sys.destructible_orbit_radius
	var ang_vel: float = sys.destructible_angular_velocity
	var init_theta: float = sys.destructible_initial_theta

	if slot_radius <= 0.0:
		var base_vel: float = streamer.system_profile.base_angular_velocity if (streamer != null and streamer.system_profile != null) else 0.05
		slot_radius = 1800.0
		ang_vel = CosmosKeplerOrbitMath.calculate_keplerian_angular_velocity(base_vel, 1000.0, slot_radius, 1.0)
		var run_seed: int = streamer.run_seed if streamer != null else 428175
		var cell_seed: int = run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 888)
		init_theta = CosmosHasher.hash_2d_float(cell_seed, 101, 11) * TAU

	return CosmosOrbitSlot.new(
		CosmosOrbitSlot.SlotCenterType.STAR,
		cell,
		star_layer_pos,
		slot_radius,
		ang_vel,
		init_theta,
		sys.star_body,
		StringName("DestructiblePlanetSlot_%d_%d" % [cell.x, cell.y]),
		scroll_scale
	)

## Obtiene los slots de planetas destructibles activos alrededor de estrellas cercanas en coordenadas de gameplay
func get_destructible_planet_slots(world_position: Vector2, search_radius: float = 8000.0) -> Array[CosmosOrbitSlot]:
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
		if not is_instance_valid(sys) or sys.star_body == null:
			continue

		var star_layer_pos: Vector2 = sys.position + sys.star_body.position
		if search_radius > 0.0 and star_layer_pos.distance_to(target_layer_pos) > search_radius:
			continue

		var slot: CosmosOrbitSlot = get_destructible_planet_slot(sys, cell)
		if slot != null:
			results.append(slot)

	# Si active_systems no tiene ningún sistema cargado en frustum, derivar slot analítico determinista desde el macro-grid
	if results.is_empty() and streamer.get_macro_grid() != null:
		var grid: CosmosMacroGrid = streamer.get_macro_grid()
		var center_cell: Vector2i = grid.world_to_grid_coords(target_layer_pos)
		var effective_spawn_chance: float = streamer.system_profile.spawn_chance if streamer.system_profile != null else 0.75

		for ox: int in range(-1, 2):
			for oy: int in range(-1, 2):
				var cell: Vector2i = center_cell + Vector2i(ox, oy)
				var has_override: bool = streamer.poi_registry != null and streamer.poi_registry.has_poi(cell)
				if not has_override and grid.get_cell_pseudorandom_float(cell, 9091) > effective_spawn_chance:
					continue

				var sys_pos: Vector2 = streamer.get_system_position_for_cell(cell)
				if search_radius <= 0.0 or sys_pos.distance_to(target_layer_pos) <= search_radius:
					var cell_seed: int = streamer.run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 888)
					var p_cfg: CosmosPlanetarySystemConfig = streamer.system_profile.get_effective_planetary_config() if streamer.system_profile != null else null
					var eff_min_r: float = p_cfg.orbit_radius_min if p_cfg != null else 1200.0
					var eff_max_r: float = p_cfg.orbit_radius_max if p_cfg != null else 3500.0
					var slot_radius: float = lerpf(eff_min_r, eff_max_r, 0.45)
					var base_vel: float = streamer.system_profile.base_angular_velocity if streamer.system_profile != null else 0.05
					var kepler_ang_vel: float = CosmosKeplerOrbitMath.calculate_keplerian_angular_velocity(base_vel, eff_min_r, slot_radius, 1.0)
					var initial_theta: float = CosmosHasher.hash_2d_float(cell_seed, 101, 11) * TAU
					var slot: CosmosOrbitSlot = CosmosOrbitSlot.new(
						CosmosOrbitSlot.SlotCenterType.STAR,
						cell,
						sys_pos,
						slot_radius,
						kepler_ang_vel,
						initial_theta,
						null,
						StringName("DestructiblePlanetSlot_%d_%d" % [cell.x, cell.y]),
						scroll_scale
					)
					results.append(slot)
					break
			if not results.is_empty():
				break

	if results.size() > 1:
		results.sort_custom(func(a: CosmosOrbitSlot, b: CosmosOrbitSlot) -> bool:
			return a.center_layer_position.distance_squared_to(target_layer_pos) < b.center_layer_position.distance_squared_to(target_layer_pos)
		)

	return results

## Obtiene de forma empaquetada todos los slots de un sistema solar activo
func get_slots_for_system(sys: CosmosSolarSystem2D, cell: Vector2i) -> Dictionary:
	var streamer: CosmosSolarSystemStreamer = cosmos_root.solar_streamer if cosmos_root != null else null
	var parallax_layer: Parallax2D = streamer.parallax_layer if streamer != null else null
	var scroll_scale: Vector2 = parallax_layer.scroll_scale if parallax_layer != null else Vector2(0.20, 0.20)

	return {
		"star_slot": create_star_orbit_slot(sys, cell, scroll_scale),
		"star_center_slot": create_star_center_slot(sys, cell, scroll_scale),
		"planet_slots": create_planet_orbit_slots(sys, cell, scroll_scale),
		"destructible_slot": get_destructible_planet_slot(sys, cell)
	}

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
