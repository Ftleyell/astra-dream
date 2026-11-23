class_name CosmosInterstellarCorridorController2D
extends Node2D

## Orquestador modular de Corredores Interestelares (Cosmos Engine v3.2c).
## Renderiza 3 capas conectivas entre parcelas del macro-grid con zero-allocation en _process():
## 1. Rutas Hiperespaciales (balizas en cascada + micro-convoyes MultiMesh en curvas Bézier).
## 2. Lluvias sutiles de micro-meteoros / estrellas fugaces locales.
## 3. Cometas interestelares errantes + Frentes de choque magnético (Bow-Shocks) entre soles cercanos.

const SOLAR_BOW_SHOCK_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/solar_bow_shock.gdshader")
const CORRIDOR_PARTICLE_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/hyperspace_corridor_particle.gdshader")
const COMET_TAIL_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/comet_tail.gdshader")

const MAX_PARTICLES: int = 1024
const MAX_BOW_SHOCKS: int = 8
const MAX_INTERSTELLAR_COMETS: int = 4


class _SlipstreamThreadDrawer extends Node2D:
	var _ctrl: CosmosInterstellarCorridorController2D = null
	var _pts_32: PackedVector2Array = PackedVector2Array()
	var _cols_outer: PackedColorArray = PackedColorArray()
	var _cols_inner: PackedColorArray = PackedColorArray()

	func _init() -> void:
		name = "SlipstreamThreadDrawer"
		z_index = -1
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
		_pts_32.resize(33)
		_cols_outer.resize(33)
		_cols_inner.resize(33)

	func setup(p_ctrl: CosmosInterstellarCorridorController2D) -> void:
		_ctrl = p_ctrl
		queue_redraw()

	func _draw() -> void:
		if not visible or _ctrl == null or not is_instance_valid(_ctrl) or _ctrl._lanes.is_empty():
			return
		var cfg: CosmosLivingUniverseConfig = _ctrl.living_config
		var base_col: Color = cfg.hyperspace_lane_color if cfg != null else Color(0.28, 0.86, 1.0, 1.0)
		var slip_a: float = cfg.hyperspace_slipstream_alpha if cfg != null else 0.04
		if slip_a <= 0.001:
			return
		var biome_laced: Color = base_col.lerp(_ctrl._biome_tint, 0.18)
		var draw_outer: bool = _ctrl._graphics_quality >= 1
		var inner_col: Color = Color(biome_laced.r, biome_laced.g, biome_laced.b, 1.0).lerp(Color.WHITE, 0.25)

		for lane: Dictionary in _ctrl._lanes:
			var p0: Vector2 = lane["p0"] as Vector2
			var p1: Vector2 = lane["p1"] as Vector2
			var p2: Vector2 = lane["p2"] as Vector2
			for i: int in range(33):
				var u: float = float(i) / 32.0
				_pts_32[i] = _ctrl._eval_bezier(p0, p1, p2, u)
				var end_fade: float = smoothstep(0.0, 0.10, u) * (1.0 - smoothstep(0.90, 1.0, u))
				_cols_inner[i] = Color(inner_col.r, inner_col.g, inner_col.b, slip_a * end_fade)
				if draw_outer:
					_cols_outer[i] = Color(biome_laced.r, biome_laced.g, biome_laced.b, slip_a * 0.16 * end_fade)
			if draw_outer:
				draw_polyline_colors(_pts_32, _cols_outer, 8.0, true)
			draw_polyline_colors(_pts_32, _cols_inner, 1.3, true)


class _CorridorGuidesDrawer extends Node2D:
	var _ctrl: CosmosInterstellarCorridorController2D = null
	var _pts_24: PackedVector2Array = PackedVector2Array()

	func _init() -> void:
		name = "CorridorGuidesDrawer"
		visible = false
		z_as_relative = false
		z_index = 1
		_pts_24.resize(25)

	func setup(p_ctrl: CosmosInterstellarCorridorController2D) -> void:
		_ctrl = p_ctrl
		if visible:
			queue_redraw()

	func _draw() -> void:
		if not visible or _ctrl == null or not is_instance_valid(_ctrl):
			return
		var inv_zoom: float = 1.0
		if is_inside_tree() and get_viewport() != null:
			var cam: Camera2D = get_viewport().get_camera_2d()
			if cam != null and cam.zoom.x > 0.001:
				inv_zoom = clampf(1.0 / cam.zoom.x, 0.75, 5.5)

		var lane_col: Color = Color(0.28, 0.88, 1.0, 0.34)
		var bow_col: Color = Color(1.0, 0.74, 0.32, 0.48)
		var comet_col: Color = Color(0.42, 1.0, 0.78, 0.38)
		var w_line: float = 1.6 * inv_zoom

		for lane: Dictionary in _ctrl._lanes:
			var p0: Vector2 = lane["p0"] as Vector2
			var p1: Vector2 = lane["p1"] as Vector2
			var p2: Vector2 = lane["p2"] as Vector2
			for i: int in range(25):
				var u: float = float(i) / 24.0
				_pts_24[i] = _ctrl._eval_bezier(p0, p1, p2, u)
			draw_polyline(_pts_24, lane_col, w_line, true)

		for bs: Dictionary in _ctrl._active_bow_shocks:
			var pos: Vector2 = bs["pos"] as Vector2
			var nrm: Vector2 = Vector2(-sin(float(bs["rot"])), cos(float(bs["rot"])))
			draw_line(pos - nrm * 450.0, pos + nrm * 450.0, bow_col, w_line * 1.15)

		for c_entry: Dictionary in _ctrl._active_comets_meta:
			var p0: Vector2 = c_entry["p0"] as Vector2
			var p1: Vector2 = c_entry["p1"] as Vector2
			var p2: Vector2 = c_entry["p2"] as Vector2
			for i: int in range(25):
				var u: float = float(i) / 24.0
				_pts_24[i] = _ctrl._eval_bezier(p0, p1, p2, u)
			draw_polyline(_pts_24, comet_col, w_line * 0.85, true)


static var _quad_tex: ImageTexture = null
static var _unit_quad_mesh: QuadMesh = null

@export var system_profile: CosmosCelestialSystemProfile
@export var living_config: CosmosLivingUniverseConfig
@export var solar_streamer: CosmosSolarSystemStreamer = null
@export var non_stellar_streamer: CosmosNonStellarStreamer2D = null
@export var parallax_layer: Parallax2D
@export var camera: Camera2D

@export var is_frozen: bool = false
@export var time_scale: float = 1.0
@export var run_seed: int = 428175

var _macro_grid: CosmosMacroGrid = null
var _cell_size: float = 11200.0
var _cached_center_cell: Vector2i = Vector2i(2147483647, 2147483647)
var _cached_seed: int = -1

var _has_camera_override: bool = false
var _override_cam_pos: Vector2 = Vector2.ZERO
var _override_zoom: Vector2 = Vector2.ONE

var _global_time: float = 0.0
var _graphics_quality: int = 2
var _orbit_guides_visible: bool = false
var _biome_tint: Color = Color(0.18, 0.28, 0.55, 1.0)

var _particle_mmi: MultiMeshInstance2D = null
var _particle_mm: MultiMesh = null
var _particle_mat: ShaderMaterial = null
var _particle_origin: Vector2 = Vector2.ZERO
var _slipstream_drawer: _SlipstreamThreadDrawer = null
var _guides_drawer: _CorridorGuidesDrawer = null

var _bow_shock_sprites: Array[Sprite2D] = []
var _bow_shock_mats: Array[ShaderMaterial] = []
var _comet_sprites: Array[Sprite2D] = []
var _comet_mats: Array[ShaderMaterial] = []

var _lanes: Array[Dictionary] = []
var _convoys: Array[Dictionary] = []
var _convoy_positions: PackedVector2Array = PackedVector2Array()
var _convoy_rotations: PackedFloat32Array = PackedFloat32Array()
var _meteors: Array[Dictionary] = []
var _active_bow_shocks: Array[Dictionary] = []
var _active_comets_meta: Array[Dictionary] = []

var _beacon_count: int = 0
var _convoy_start_idx: int = 0
var _meteor_start_idx: int = 0
var _total_active_particles: int = 0


static func _get_quad_tex() -> ImageTexture:
	if _quad_tex == null:
		var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_quad_tex = ImageTexture.create_from_image(img)
	return _quad_tex


static func _get_unit_quad_mesh() -> QuadMesh:
	if _unit_quad_mesh == null:
		_unit_quad_mesh = QuadMesh.new()
		_unit_quad_mesh.size = Vector2.ONE
	return _unit_quad_mesh


func _ready() -> void:
	z_index = -3
	if system_profile != null and system_profile.cell_size > 0.0:
		_cell_size = system_profile.cell_size
	_initialize_macro_grid()
	_initialize_gpu_pools()


func _initialize_macro_grid() -> void:
	if system_profile != null and system_profile.cell_size > 0.0:
		_cell_size = system_profile.cell_size
	_macro_grid = CosmosMacroGrid.new(_cell_size, run_seed)


func _initialize_gpu_pools() -> void:
	if _particle_mmi != null:
		return

	_particle_mmi = MultiMeshInstance2D.new()
	_particle_mmi.name = "CorridorParticlesMultiMesh"
	_particle_mmi.z_index = 0
	_particle_mmi.texture = _get_quad_tex()
	_particle_mm = MultiMesh.new()
	_particle_mm.transform_format = MultiMesh.TRANSFORM_2D
	_particle_mm.use_colors = true
	_particle_mm.use_custom_data = true
	_particle_mm.mesh = _get_unit_quad_mesh()
	_particle_mm.instance_count = MAX_PARTICLES
	_particle_mm.visible_instance_count = 0
	_particle_mm.custom_aabb = AABB(Vector3(-_cell_size * 2.5, -_cell_size * 2.5, -16.0), Vector3(_cell_size * 5.0, _cell_size * 5.0, 32.0))
	_particle_mmi.multimesh = _particle_mm

	_particle_mat = ShaderMaterial.new()
	_particle_mat.shader = CORRIDOR_PARTICLE_SHADER
	_particle_mat.set_shader_parameter("quality_level", _graphics_quality)
	_particle_mmi.material = _particle_mat
	add_child(_particle_mmi)

	_slipstream_drawer = _SlipstreamThreadDrawer.new()
	add_child(_slipstream_drawer)
	_slipstream_drawer.setup(self)

	for i: int in range(MAX_BOW_SHOCKS):
		var bs_spr := Sprite2D.new()
		bs_spr.name = "BowShock_%d" % i
		bs_spr.centered = true
		bs_spr.texture = _get_quad_tex()
		bs_spr.visible = false
		bs_spr.z_index = 0
		var bs_mat := ShaderMaterial.new()
		bs_mat.shader = SOLAR_BOW_SHOCK_SHADER
		bs_mat.set_shader_parameter("quality_level", _graphics_quality)
		bs_spr.material = bs_mat
		add_child(bs_spr)
		_bow_shock_sprites.append(bs_spr)
		_bow_shock_mats.append(bs_mat)

	for i: int in range(MAX_INTERSTELLAR_COMETS):
		var c_spr := Sprite2D.new()
		c_spr.name = "InterstellarComet_%d" % i
		c_spr.centered = false
		c_spr.offset = Vector2(-0.36, -1.0)
		c_spr.texture = _get_quad_tex()
		c_spr.visible = false
		c_spr.z_as_relative = false
		c_spr.z_index = -1
		var c_mat := ShaderMaterial.new()
		c_mat.shader = COMET_TAIL_SHADER
		c_mat.set_shader_parameter("ion_color", Color(0.44, 0.90, 1.0, 1.0))
		c_mat.set_shader_parameter("dust_color", Color(0.95, 0.82, 0.62, 1.0))
		c_mat.set_shader_parameter("solar_proximity", 0.72)
		c_spr.material = c_mat
		add_child(c_spr)
		_comet_sprites.append(c_spr)
		_comet_mats.append(c_mat)

	_guides_drawer = _CorridorGuidesDrawer.new()
	add_child(_guides_drawer)
	_guides_drawer.setup(self)
	_guides_drawer.visible = _orbit_guides_visible


func set_camera_override(cam_pos: Vector2, zoom: Vector2) -> void:
	_has_camera_override = true
	_override_cam_pos = cam_pos
	_override_zoom = zoom


func clear_camera_override() -> void:
	_has_camera_override = false


func set_run_seed(p_seed: int) -> void:
	if run_seed == p_seed and _macro_grid != null:
		return
	run_seed = p_seed
	_initialize_macro_grid()
	_cached_seed = -1


func apply_graphics_quality(quality_level: int) -> void:
	_graphics_quality = clampi(quality_level, 0, 2)
	if _particle_mat != null:
		_particle_mat.set_shader_parameter("quality_level", _graphics_quality)
	for mat: ShaderMaterial in _bow_shock_mats:
		mat.set_shader_parameter("quality_level", _graphics_quality)
	if _slipstream_drawer != null and is_instance_valid(_slipstream_drawer):
		_slipstream_drawer.queue_redraw()


func set_orbit_guides_visible(p_visible: bool) -> void:
	_orbit_guides_visible = p_visible
	if _guides_drawer != null and is_instance_valid(_guides_drawer):
		_guides_drawer.visible = p_visible
		if p_visible:
			_guides_drawer.queue_redraw()


func update_biome_harmony(b_primary: Color, b_secondary: Color) -> void:
	_biome_tint = b_primary.lerp(b_secondary, 0.45)
	for mat: ShaderMaterial in _bow_shock_mats:
		mat.set_shader_parameter("biome_tint_color", _biome_tint)
	if _slipstream_drawer != null and is_instance_valid(_slipstream_drawer):
		_slipstream_drawer.queue_redraw()


func _process(delta: float) -> void:
	if is_frozen:
		return
	_global_time += delta * time_scale
	update_corridors(_global_time)


func _resolve_focal_center() -> Vector2:
	if parallax_layer == null:
		return Vector2.ZERO
	var cam_pos: Vector2 = _override_cam_pos if _has_camera_override else (camera.get_screen_center_position() if camera != null else Vector2.ZERO)
	if not _has_camera_override and cam_pos == Vector2.ZERO and camera != null and camera.global_position != Vector2.ZERO:
		cam_pos = camera.global_position
	return (cam_pos * parallax_layer.scroll_scale) - parallax_layer.scroll_offset


## Evalúa topología (solo si cambia la celda central) y actualiza animación GPU zero-alloc en current_time.
func update_corridors(current_time: float) -> void:
	if _macro_grid == null:
		_initialize_macro_grid()
	if _particle_mmi == null:
		_initialize_gpu_pools()

	var cfg: CosmosLivingUniverseConfig = living_config if living_config != null else CosmosLivingUniverseConfig.new()
	if not cfg.enable_interstellar_corridors:
		if _particle_mm != null:
			_particle_mm.visible_instance_count = 0
		if _slipstream_drawer != null and is_instance_valid(_slipstream_drawer):
			_slipstream_drawer.visible = false
		for bs_spr: Sprite2D in _bow_shock_sprites:
			bs_spr.visible = false
		for c_spr: Sprite2D in _comet_sprites:
			c_spr.visible = false
		return

	if _slipstream_drawer != null and is_instance_valid(_slipstream_drawer) and not _slipstream_drawer.visible:
		_slipstream_drawer.visible = true
		_slipstream_drawer.queue_redraw()

	var center_pos: Vector2 = _resolve_focal_center()
	var center_cell: Vector2i = _macro_grid.world_to_grid_coords(center_pos)
	if center_cell != _cached_center_cell or run_seed != _cached_seed:
		_rebuild_topology(center_cell, cfg)

	_animate_runtime_state(current_time)


func _get_cell_endpoint(cell: Vector2i, cfg: CosmosLivingUniverseConfig) -> Dictionary:
	var spawn_chance: float = system_profile.spawn_chance if system_profile != null else 0.65
	var poi_reg: CosmicPoiRegistry = solar_streamer.poi_registry if solar_streamer != null else null
	var is_solar: bool = CosmosSolarSystemStreamer.is_cell_solar(cell, _macro_grid, spawn_chance, poi_reg)

	if is_solar:
		var pos: Vector2 = solar_streamer.get_system_position_for_cell(cell) if solar_streamer != null else _macro_grid.grid_to_world_center(cell)
		var cell_seed: int = run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 777)
		var arch: CosmosStarArchetype = system_profile.get_archetype_for_seed(cell_seed) if system_profile != null else null
		var col: Color = arch.star_color if arch != null else Color(1.0, 0.88, 0.55, 1.0)
		return {"eligible": true, "is_solar": true, "pos": pos, "color": col, "trim": 680.0}

	if poi_reg != null and poi_reg.has_poi(cell):
		return {"eligible": false, "is_solar": false, "pos": Vector2.ZERO, "color": Color.WHITE, "trim": 0.0}

	var sec_seed: int = non_stellar_streamer.get_sector_seed_for_cell(cell) if non_stellar_streamer != null else (run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 793))
	var sec_arch: int = cfg.pick_sector_archetype(sec_seed)
	if sec_arch == CosmosDeepSpaceSector2D.SectorArchetype.WARP_RELAY:
		var pos: Vector2 = non_stellar_streamer.get_sector_position_for_cell(cell) if non_stellar_streamer != null else _macro_grid.grid_to_world_center(cell)
		return {"eligible": true, "is_solar": false, "pos": pos, "color": cfg.relay_primary_color, "trim": 540.0}

	return {"eligible": false, "is_solar": false, "pos": Vector2.ZERO, "color": Color.WHITE, "trim": 0.0}


static func _canonical_edge_key(a: Vector2i, b: Vector2i) -> String:
	var first_a: bool = (a.x < b.x) or (a.x == b.x and a.y < b.y)
	var c0: Vector2i = a if first_a else b
	var c1: Vector2i = b if first_a else a
	return "%d,%d->%d,%d" % [c0.x, c0.y, c1.x, c1.y]


static func _canonical_edge_seed(a: Vector2i, b: Vector2i, p_seed: int) -> int:
	var first_a: bool = (a.x < b.x) or (a.x == b.x and a.y < b.y)
	var c0: Vector2i = a if first_a else b
	var c1: Vector2i = b if first_a else a
	return (c0.x * 73856093) ^ (c0.y * 19349663) ^ (c1.x * 83492791) ^ (c1.y * 297121507) ^ p_seed


func _eval_bezier(p0: Vector2, p1: Vector2, p2: Vector2, u: float) -> Vector2:
	var omt: float = 1.0 - u
	return (omt * omt) * p0 + (2.0 * omt * u) * p1 + (u * u) * p2


func _eval_bezier_tangent(p0: Vector2, p1: Vector2, p2: Vector2, u: float) -> Vector2:
	return 2.0 * (1.0 - u) * (p1 - p0) + 2.0 * u * (p2 - p1)


func _rebuild_topology(center_cell: Vector2i, cfg: CosmosLivingUniverseConfig) -> void:
	_cached_center_cell = center_cell
	_cached_seed = run_seed

	_particle_origin = _macro_grid.grid_to_world_center(center_cell)
	if _particle_mmi != null:
		_particle_mmi.position = _particle_origin
	if _particle_mm != null:
		_particle_mm.custom_aabb = AABB(Vector3(-_cell_size * 2.5, -_cell_size * 2.5, -16.0), Vector3(_cell_size * 5.0, _cell_size * 5.0, 32.0))

	_lanes.clear()
	_convoys.clear()
	_meteors.clear()
	_active_bow_shocks.clear()
	_active_comets_meta.clear()

	# 1. Cachear endpoints del vecindario 5x5 para evaluar aristas 3x3 sin duplicados
	var info_map: Dictionary = {}
	for ox: int in range(-2, 3):
		for oy: int in range(-2, 3):
			var c: Vector2i = center_cell + Vector2i(ox, oy)
			info_map[c] = _get_cell_endpoint(c, cfg)

	var seen_edges: Dictionary = {}
	var max_lane_dist: float = _cell_size * cfg.corridor_max_link_distance_mult
	var max_bow_dist: float = _cell_size * cfg.bow_shock_max_distance_mult
	var p_idx: int = 0

	# 2. Balizas + rutas hiperespaciales + frentes bow-shock sobre aristas simétricas únicas
	for ax: int in range(-1, 2):
		for ay: int in range(-1, 2):
			var ca: Vector2i = center_cell + Vector2i(ax, ay)
			var ia: Dictionary = info_map[ca] as Dictionary
			if not bool(ia["eligible"]):
				continue

			for dx: int in range(-1, 2):
				for dy: int in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var cb: Vector2i = ca + Vector2i(dx, dy)
					if not info_map.has(cb):
						continue
					var e_key: String = _canonical_edge_key(ca, cb)
					if seen_edges.has(e_key):
						continue
					seen_edges[e_key] = true

					var ib: Dictionary = info_map[cb] as Dictionary
					if not bool(ib["eligible"]):
						continue

					var pos_a: Vector2 = ia["pos"] as Vector2
					var pos_b: Vector2 = ib["pos"] as Vector2
					var ab_vec: Vector2 = pos_b - pos_a
					var dist: float = ab_vec.length()
					if dist <= 1200.0:
						continue

					var edge_seed: int = _canonical_edge_seed(ca, cb, run_seed)
					var axis_dir: Vector2 = ab_vec / dist
					var perp_dir: Vector2 = Vector2(-axis_dir.y, axis_dir.x)

					# 2a. Bow-shock entre dos heliopausas solares cercanas
					if bool(ia["is_solar"]) and bool(ib["is_solar"]) and dist <= max_bow_dist:
						if _active_bow_shocks.size() < MAX_BOW_SHOCKS:
							_active_bow_shocks.append({
								"pos": pos_a.lerp(pos_b, 0.5),
								"rot": axis_dir.angle(),
								"scale": clampf(dist * 0.42, 2200.0, 4800.0),
								"col_a": ia["color"] as Color,
								"col_b": ib["color"] as Color,
								"phase": CosmosHasher.hash_2d_float(edge_seed, 19, 31) * TAU,
								"curve_sign": 1.0 if CosmosHasher.hash_2d_float(edge_seed, 23, 37) > 0.5 else -1.0,
							})

					# 2b. Ruta hiperespacial
					if dist <= max_lane_dist and _lanes.size() < 16:
						var roll: float = CosmosHasher.hash_2d_float(edge_seed, 511, 73)
						if roll <= cfg.hyperspace_lane_probability:
							var trim_a: float = float(ia["trim"])
							var trim_b: float = float(ib["trim"])
							if dist > trim_a + trim_b + 600.0:
								var p0: Vector2 = pos_a + axis_dir * trim_a
								var p2: Vector2 = pos_b - axis_dir * trim_b
								var bend: float = (CosmosHasher.hash_2d_float(edge_seed, 523, 89) - 0.5) * 0.36 * dist
								var p1: Vector2 = pos_a.lerp(pos_b, 0.5) + perp_dir * bend
								var lane_idx: int = _lanes.size()
								_lanes.append({"p0": p0, "p1": p1, "p2": p2, "len": dist, "seed": edge_seed})

								# Colocar balizas estáticas en buffer MultiMesh
								var n_b: int = cfg.hyperspace_beacons_per_lane
								for bi: int in range(n_b):
									if p_idx >= MAX_PARTICLES - 320:
										break
									var u_b: float = (float(bi) + 0.5) / float(maxi(n_b, 1))
									var b_pos: Vector2 = _eval_bezier(p0, p1, p2, u_b)
									var b_sz: float = lerpf(64.0, 92.0, sin(u_b * PI))
									_particle_mm.set_instance_transform_2d(p_idx, Transform2D(Vector2(b_sz, 0.0), Vector2(0.0, b_sz), b_pos - _particle_origin))
									_particle_mm.set_instance_color(p_idx, Color(cfg.hyperspace_lane_color.r, cfg.hyperspace_lane_color.g, cfg.hyperspace_lane_color.b, 0.62))
									_particle_mm.set_instance_custom_data(p_idx, Color(0.0, float(bi) * 0.72 + float(lane_idx) * 0.35, 1.0, 0.0))
									p_idx += 1

	_beacon_count = p_idx
	_convoy_start_idx = p_idx

	# 3. Registrar micro-convoyes dinámicos sobre las rutas activas
	for l_idx: int in range(_lanes.size()):
		var lane: Dictionary = _lanes[l_idx]
		var l_seed: int = int(lane["seed"])
		var l_len: float = maxf(float(lane["len"]), 1000.0)
		for ci: int in range(cfg.hyperspace_convoys_per_lane):
			if p_idx >= MAX_PARTICLES - 180:
				break
			var cv_seed: int = l_seed + (ci + 1) * 911
			var dir_sign: float = 1.0 if (ci % 2 == 0) else -1.0
			var spd_u: float = (cfg.hyperspace_convoy_speed * lerpf(0.82, 1.24, CosmosHasher.hash_2d_float(cv_seed, 11, 13)) / l_len) * dir_sign
			var u0: float = CosmosHasher.hash_2d_float(cv_seed, 17, 19)
			var use_cyan: bool = CosmosHasher.hash_2d_float(cv_seed, 29, 31) > 0.55
			var col: Color = cfg.hyperspace_lane_color if use_cyan else cfg.hyperspace_convoy_color
			_convoys.append({
				"lane_idx": l_idx,
				"u0": u0,
				"spd_u": spd_u,
				"col": col,
				"phase": CosmosHasher.hash_2d_float(cv_seed, 37, 41) * TAU,
				"scale": Vector2(lerpf(104.0, 152.0, CosmosHasher.hash_2d_float(cv_seed, 43, 47)), lerpf(20.0, 28.0, CosmosHasher.hash_2d_float(cv_seed, 53, 59))),
			})
			p_idx += 1

	_meteor_start_idx = p_idx

	# 4. Registrar lluvias sutiles de micro-meteoros locales en el vecindario 3x3
	var m_per_cell: int = cfg.meteor_shower_count_per_cell
	for cx: int in range(-1, 2):
		for cy: int in range(-1, 2):
			var c: Vector2i = center_cell + Vector2i(cx, cy)
			var c_center: Vector2 = _macro_grid.grid_to_world_center(c)
			for mi: int in range(m_per_cell):
				if p_idx >= MAX_PARTICLES:
					break
				var ms: int = run_seed ^ CosmosHasher.hash_2d(c.x * 13 + mi, c.y * 17 - mi, 6619)
				var off_x: float = (CosmosHasher.hash_2d_float(ms, 11, 12) - 0.5) * _cell_size * 0.92
				var off_y: float = (CosmosHasher.hash_2d_float(ms, 21, 22) - 0.5) * _cell_size * 0.92
				var ang: float = CosmosHasher.hash_2d_float(ms, 31, 32) * TAU
				_meteors.append({
					"start": c_center + Vector2(off_x, off_y),
					"dir": Vector2(cos(ang), sin(ang)),
					"travel": lerpf(580.0, 1150.0, CosmosHasher.hash_2d_float(ms, 41, 42)),
					"period": lerpf(2.6, 5.2, CosmosHasher.hash_2d_float(ms, 51, 52)),
					"duration": lerpf(0.62, 1.05, CosmosHasher.hash_2d_float(ms, 61, 62)),
					"phase": CosmosHasher.hash_2d_float(ms, 71, 72) * 5.2,
					"col": Color(0.76, 0.92, 1.0, 0.78) if (mi % 2 == 0) else Color(1.0, 0.88, 0.68, 0.74),
					"scale": Vector2(lerpf(140.0, 225.0, CosmosHasher.hash_2d_float(ms, 81, 82)), 18.0),
				})
				p_idx += 1

	_convoy_positions.resize(_convoys.size())
	_convoy_rotations.resize(_convoys.size())
	_total_active_particles = p_idx
	_particle_mm.visible_instance_count = _total_active_particles
	if _particle_mmi != null:
		_particle_mmi.queue_redraw()

	# 5. Actualizar Bow-Shocks físicos en pool
	for bs_i: int in range(MAX_BOW_SHOCKS):
		var bs_spr: Sprite2D = _bow_shock_sprites[bs_i]
		if bs_i < _active_bow_shocks.size():
			var bs: Dictionary = _active_bow_shocks[bs_i]
			var bs_mat: ShaderMaterial = _bow_shock_mats[bs_i]
			bs_spr.position = bs["pos"] as Vector2
			bs_spr.rotation = float(bs["rot"])
			bs_spr.scale = Vector2.ONE * float(bs["scale"])
			bs_mat.set_shader_parameter("color_a", bs["col_a"] as Color)
			bs_mat.set_shader_parameter("color_b", bs["col_b"] as Color)
			bs_mat.set_shader_parameter("seed_phase", float(bs["phase"]))
			bs_mat.set_shader_parameter("curve_sign", float(bs["curve_sign"]))
			bs_mat.set_shader_parameter("intensity", cfg.bow_shock_intensity)
			bs_spr.visible = true
		else:
			bs_spr.visible = false

	# 6. Construir cometas interestelares errantes que cruzan entre parcelas
	var max_comets: int = mini(_lanes.size(), MAX_INTERSTELLAR_COMETS)
	if max_comets == 0:
		# Si no hay rutas en vecindario, aún generar hasta 2 cometas cruzando la celda actual
		max_comets = clampi(2, 0, MAX_INTERSTELLAR_COMETS)
		for k: int in range(max_comets):
			var cs: int = run_seed ^ CosmosHasher.hash_2d(center_cell.x + k * 5, center_cell.y - k * 7, 7717)
			if CosmosHasher.hash_2d_float(cs, 19, 29) > cfg.interstellar_comet_probability:
				continue
			var cc: Vector2 = _macro_grid.grid_to_world_center(center_cell)
			var ang: float = CosmosHasher.hash_2d_float(cs, 31, 41) * TAU
			var d_v: Vector2 = Vector2(cos(ang), sin(ang))
			var n_v: Vector2 = Vector2(-d_v.y, d_v.x)
			var p0: Vector2 = cc - d_v * (_cell_size * 0.55)
			var p2: Vector2 = cc + d_v * (_cell_size * 0.55)
			var p1: Vector2 = cc + n_v * ((CosmosHasher.hash_2d_float(cs, 51, 61) - 0.5) * _cell_size * 0.5)
			_active_comets_meta.append({
				"p0": p0, "p1": p1, "p2": p2,
				"u0": CosmosHasher.hash_2d_float(cs, 71, 81),
				"rate": 1.0 / lerpf(42.0, 68.0, CosmosHasher.hash_2d_float(cs, 83, 89)),
				"sx": lerpf(165.0, 240.0, CosmosHasher.hash_2d_float(cs, 91, 97)),
			})
	else:
		for k: int in range(max_comets):
			var l_dict: Dictionary = _lanes[k]
			var cs: int = int(l_dict["seed"]) ^ 0x51A7
			if CosmosHasher.hash_2d_float(cs, 19, 29) > cfg.interstellar_comet_probability:
				continue
			var lp0: Vector2 = l_dict["p0"] as Vector2
			var lp2: Vector2 = l_dict["p2"] as Vector2
			var mid: Vector2 = lp0.lerp(lp2, 0.5)
			var dir_l: Vector2 = (lp2 - lp0).normalized()
			var perp_l: Vector2 = Vector2(-dir_l.y, dir_l.x)
			var lat_shift: float = (CosmosHasher.hash_2d_float(cs, 33, 44) - 0.5) * _cell_size * 0.42
			var p0: Vector2 = lp0 + perp_l * lat_shift
			var p2: Vector2 = lp2 - perp_l * lat_shift
			var p1: Vector2 = mid + perp_l * ((CosmosHasher.hash_2d_float(cs, 55, 66) - 0.5) * _cell_size * 0.55)
			_active_comets_meta.append({
				"p0": p0, "p1": p1, "p2": p2,
				"u0": CosmosHasher.hash_2d_float(cs, 77, 88),
				"rate": 1.0 / lerpf(44.0, 72.0, CosmosHasher.hash_2d_float(cs, 91, 99)),
				"sx": lerpf(170.0, 245.0, CosmosHasher.hash_2d_float(cs, 101, 103)),
			})

	for ci: int in range(MAX_INTERSTELLAR_COMETS):
		_comet_sprites[ci].visible = (ci < _active_comets_meta.size())

	if _slipstream_drawer != null and is_instance_valid(_slipstream_drawer):
		_slipstream_drawer.queue_redraw()
	if _guides_drawer != null and _guides_drawer.visible:
		_guides_drawer.queue_redraw()


func _animate_runtime_state(global_time: float) -> void:
	if _particle_mat != null:
		_particle_mat.set_shader_parameter("global_time", global_time)
	for mat: ShaderMaterial in _bow_shock_mats:
		mat.set_shader_parameter("global_time", global_time)

	# 1. Micro-convoyes sobre rutas hiperespaciales (zero-alloc)
	for i: int in range(_convoys.size()):
		var cv: Dictionary = _convoys[i]
		var lane: Dictionary = _lanes[int(cv["lane_idx"])]
		var p0: Vector2 = lane["p0"] as Vector2
		var p1: Vector2 = lane["p1"] as Vector2
		var p2: Vector2 = lane["p2"] as Vector2
		var u: float = fposmod(float(cv["u0"]) + float(cv["spd_u"]) * global_time, 1.0)
		var pos: Vector2 = _eval_bezier(p0, p1, p2, u)
		var tang: Vector2 = _eval_bezier_tangent(p0, p1, p2, u) * (1.0 if float(cv["spd_u"]) >= 0.0 else -1.0)
		var rot: float = tang.angle() if tang.length_squared() > 0.001 else 0.0
		_convoy_positions[i] = pos
		_convoy_rotations[i] = rot
		var end_fade: float = smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.92, 1.0, u))
		var sc: Vector2 = cv["scale"] as Vector2
		var col: Color = cv["col"] as Color
		var idx: int = _convoy_start_idx + i
		var c_cos: float = cos(rot)
		var c_sin: float = sin(rot)
		_particle_mm.set_instance_transform_2d(idx, Transform2D(Vector2(c_cos, c_sin) * sc.x, Vector2(-c_sin, c_cos) * sc.y, pos - _particle_origin))
		_particle_mm.set_instance_color(idx, Color(col.r, col.g, col.b, end_fade * 0.95))
		_particle_mm.set_instance_custom_data(idx, Color(1.0, float(cv["phase"]), end_fade, 0.0))

	# 2. Micro-meteoros locales deterministas
	for i: int in range(_meteors.size()):
		var mt: Dictionary = _meteors[i]
		var period: float = maxf(float(mt["period"]), 0.5)
		var duration: float = clampf(float(mt["duration"]), 0.1, period)
		var cyc: float = fposmod(global_time + float(mt["phase"]), period)
		var idx: int = _meteor_start_idx + i
		if cyc >= duration:
			_particle_mm.set_instance_transform_2d(idx, Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO))
			_particle_mm.set_instance_custom_data(idx, Color(2.0, 0.0, 0.0, 0.0))
			continue
		var prog: float = cyc / duration
		var fade: float = sin(prog * PI)
		var dir: Vector2 = mt["dir"] as Vector2
		var pos: Vector2 = (mt["start"] as Vector2) + dir * (prog * float(mt["travel"]))
		var col: Color = mt["col"] as Color
		var m_sc: Vector2 = mt["scale"] as Vector2
		_particle_mm.set_instance_transform_2d(idx, Transform2D(dir * m_sc.x, Vector2(-dir.y, dir.x) * m_sc.y, pos - _particle_origin))
		_particle_mm.set_instance_color(idx, col)
		_particle_mm.set_instance_custom_data(idx, Color(2.0, float(mt["phase"]), fade, 0.0))

	# 3. Cometas interestelares errantes estrictamente alineados a -vel.normalized()
	for ci: int in range(_active_comets_meta.size()):
		var cm: Dictionary = _active_comets_meta[ci]
		var u: float = fposmod(float(cm["u0"]) + float(cm["rate"]) * global_time, 1.0)
		var p0: Vector2 = cm["p0"] as Vector2
		var p1: Vector2 = cm["p1"] as Vector2
		var p2: Vector2 = cm["p2"] as Vector2
		var pos: Vector2 = _eval_bezier(p0, p1, p2, u)
		var vel: Vector2 = _eval_bezier_tangent(p0, p1, p2, u)
		var c_spr: Sprite2D = _comet_sprites[ci]
		var c_mat: ShaderMaterial = _comet_mats[ci]
		c_spr.position = pos
		if vel.length_squared() > 0.001:
			c_spr.rotation = (-vel).angle()
		var sx: float = float(cm["sx"])
		c_spr.scale = Vector2(sx, sx * 0.44)
		var env: float = smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.88, 1.0, u))
		c_spr.modulate.a = env * 0.92
		c_mat.set_shader_parameter("global_time", global_time)
		c_mat.set_shader_parameter("dust_curve_angle", 0.08)


func get_active_lane_count() -> int:
	return _lanes.size()


func get_active_bow_shock_count() -> int:
	return _active_bow_shocks.size()


func get_active_interstellar_comet_count() -> int:
	return _active_comets_meta.size()


func get_convoy_world_position(index: int) -> Vector2:
	if index < 0 or index >= _convoy_positions.size():
		return Vector2.ZERO
	return _convoy_positions[index]


func get_convoy_rotation(index: int) -> float:
	if index < 0 or index >= _convoy_rotations.size():
		return 0.0
	return _convoy_rotations[index]
