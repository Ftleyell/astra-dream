class_name CosmosGalaxyStreamer2D
extends Node2D

const CosmicPoiConfig = preload("res://scenes/combat/environment/cosmos/resources/cosmic_poi_config.gd")
const CosmicPoiRegistry = preload("res://scenes/combat/environment/cosmos/core/cosmic_poi_registry.gd")

## Controlador de streaming determinista de macro-galaxias en capas de Parallax2D.
## Implementa la Arquitectura A (Macro-Sectores 3x3):
## - Cada macro-sector 3x3 de sistemas solares alberga aproximadamente en su centro una galaxia de fondo.
## - Utiliza un Object Pool pre-asignado (zero allocations) para renderizar múltiples galaxias
##   simultáneas en pantalla de forma coherente con cualquier nivel de zoom.

const GALAXY_DEEP_SHADER: Shader = preload("res://scenes/combat/environment/galaxy_deep.gdshader")

@export var landmark_profile: CosmosGalaxyLandmarkProfile
@export var parallax_layer: Parallax2D
@export var camera: Camera2D
var poi_registry: CosmicPoiRegistry = null
@export var run_seed: int = 8943719
@export var solar_cell_size: float = 7500.0
@export var pool_size: int = 6

var _macro_grid: CosmosMacroGrid
var _calculated_cell_size: float = 0.0
var _safe_min_distance: float = 0.0

var _pool: Array[Sprite2D] = []
var _active_galaxies: Dictionary = {} # Vector2i -> Sprite2D

var _cached_frustum_half_extents: Vector2 = Vector2.ZERO
var _cached_screen_center_layer: Vector2 = Vector2.ZERO

var _has_camera_override: bool = false
var _override_cam_pos: Vector2 = Vector2.ZERO
var _override_zoom: Vector2 = Vector2.ONE

func set_camera_override(cam_pos: Vector2, zoom: Vector2) -> void:
	_has_camera_override = true
	_override_cam_pos = cam_pos
	_override_zoom = zoom

func clear_camera_override() -> void:
	_has_camera_override = false

func _ready() -> void:
	if landmark_profile != null:
		_initialize_macro_grid_geometry()
	_initialize_node_pool()

func _initialize_macro_grid_geometry() -> void:
	if landmark_profile != null and landmark_profile.cell_size > 0.0:
		_calculated_cell_size = landmark_profile.cell_size
	else:
		var span: int = landmark_profile.solar_cells_span if landmark_profile != null and landmark_profile.solar_cells_span > 0 else 3
		var gal_scroll: float = parallax_layer.scroll_scale.x if (parallax_layer != null and parallax_layer.scroll_scale.x > 0.0) else 0.10
		var solar_scroll: float = 0.25
		var eff_solar_cell: float = solar_cell_size

		var root: CosmosRootNode = get_parent().get_parent() as CosmosRootNode if (get_parent() != null and get_parent().get_parent() is CosmosRootNode) else null
		if root != null:
			if root.parallax_solar_systems != null and root.parallax_solar_systems.scroll_scale.x > 0.0:
				solar_scroll = root.parallax_solar_systems.scroll_scale.x
			if root.solar_streamer != null and root.solar_streamer.cell_size > 0.0:
				eff_solar_cell = root.solar_streamer.cell_size

		# Relación analítica exacta: span * (eff_solar_cell / solar_scroll) * gal_scroll
		_calculated_cell_size = float(span) * (eff_solar_cell / solar_scroll) * gal_scroll

	if _calculated_cell_size <= 0.0:
		_calculated_cell_size = 9000.0

	_safe_min_distance = _calculated_cell_size * 0.40
	_macro_grid = CosmosMacroGrid.new(_calculated_cell_size, run_seed)

func _initialize_node_pool() -> void:
	var count: int = landmark_profile.pool_size if (landmark_profile != null and landmark_profile.pool_size > 0) else pool_size
	for i: int in range(count):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "PooledGalaxySprite_" + str(i)
		sprite.centered = true
		sprite.visible = false
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)

		if GALAXY_DEEP_SHADER != null:
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = GALAXY_DEEP_SHADER
			var spin_spd: float = landmark_profile.shader_spin_speed if landmark_profile != null else 0.015
			var brightness: float = landmark_profile.overall_brightness if landmark_profile != null else 1.45
			var pulse_int: float = landmark_profile.core_pulse_intensity if landmark_profile != null else 0.35
			mat.set_shader_parameter("spin_speed", spin_spd)
			mat.set_shader_parameter("overall_brightness", brightness)
			mat.set_shader_parameter("core_pulse_intensity", pulse_int)
			mat.set_shader_parameter("radial_fade_start", 0.38)
			mat.set_shader_parameter("radial_fade_end", 0.49)
			sprite.material = mat

		add_child(sprite)
		_pool.append(sprite)

func _process(delta: float) -> void:
	_evaluate_frustum_and_stream(delta)

func _evaluate_frustum_and_stream(delta: float) -> void:
	if (camera == null and not _has_camera_override) or parallax_layer == null or landmark_profile == null or _macro_grid == null:
		return

	var zoom: Vector2 = _override_zoom if _has_camera_override else (camera.zoom if camera != null else Vector2.ONE)
	if zoom.x <= 0.0001 or zoom.y <= 0.0001:
		zoom = Vector2.ONE

	var viewport_rect: Rect2 = get_viewport_rect()
	var viewport_size: Vector2 = viewport_rect.size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(1920.0, 1080.0)

	var viewport_half: Vector2 = (viewport_size * 0.5) / zoom
	var cam_pos: Vector2 = _override_cam_pos if _has_camera_override else (camera.get_screen_center_position() if camera != null else Vector2.ZERO)
	if not _has_camera_override and cam_pos == Vector2.ZERO and camera != null and camera.global_position != Vector2.ZERO:
		cam_pos = camera.global_position

	_cached_screen_center_layer = (cam_pos * parallax_layer.scroll_scale) - parallax_layer.scroll_offset
	_cached_frustum_half_extents = viewport_half

	var bound_margin: float = landmark_profile.maximum_bounding_radius + landmark_profile.safety_padding
	var min_cx: int = int(floor((_cached_screen_center_layer.x - _cached_frustum_half_extents.x - bound_margin) / _calculated_cell_size))
	var max_cx: int = int(floor((_cached_screen_center_layer.x + _cached_frustum_half_extents.x + bound_margin) / _calculated_cell_size))
	var min_cy: int = int(floor((_cached_screen_center_layer.y - _cached_frustum_half_extents.y - bound_margin) / _calculated_cell_size))
	var max_cy: int = int(floor((_cached_screen_center_layer.y + _cached_frustum_half_extents.y + bound_margin) / _calculated_cell_size))

	var req_cells: Array[Vector2i] = []
	var spawn_chance: float = landmark_profile.spawn_chance

	for cx: int in range(min_cx, max_cx + 1):
		for cy: int in range(min_cy, max_cy + 1):
			var cell: Vector2i = Vector2i(cx, cy)
			var has_override: bool = poi_registry != null and poi_registry.has_poi(cell)
			var should_spawn: bool = false
			if has_override:
				var poi: CosmicPoiConfig = poi_registry.get_poi(cell)
				should_spawn = (poi != null and poi.poi_type == CosmicPoiConfig.PoiType.GALAXY)
			else:
				should_spawn = (_macro_grid.get_cell_pseudorandom_float(cell, 551) <= spawn_chance)

			if should_spawn:
				var g_pos: Vector2 = evaluate_galaxy_layer_position(cell)
				if _intersects_frustum(g_pos, _cached_screen_center_layer, _cached_frustum_half_extents):
					req_cells.append(cell)

	# 1. Liberar celdas que ya no intersectan el frustum
	var cells_to_release: Array[Vector2i] = []
	for active_cell: Vector2i in _active_galaxies.keys():
		if not req_cells.has(active_cell):
			cells_to_release.append(active_cell)

	for c: Vector2i in cells_to_release:
		var sprite: Sprite2D = _active_galaxies[c] as Sprite2D
		sprite.visible = false
		sprite.modulate.a = 0.0
		_active_galaxies.erase(c)
		_pool.append(sprite)

	# 2. Asignar sprites del pool para las celdas requeridas nuevas
	for req_cell: Vector2i in req_cells:
		if not _active_galaxies.has(req_cell):
			if not _pool.is_empty():
				var sprite: Sprite2D = _pool.pop_back() as Sprite2D
				var g_pos: Vector2 = evaluate_galaxy_layer_position(req_cell)
				_configure_galaxy_instance(req_cell, g_pos, sprite)
				_active_galaxies[req_cell] = sprite

	# 3. Animar rotación y fade-in de las galaxias activas
	for sprite: Sprite2D in _active_galaxies.values():
		sprite.rotation += landmark_profile.max_drift_rotation_speed * delta
		if sprite.modulate.a < 1.0:
			sprite.modulate.a = move_toward(sprite.modulate.a, 1.0, delta * 1.5)

func _intersects_frustum(pos: Vector2, center: Vector2, half_extents: Vector2) -> bool:
	var delta_pos: Vector2 = (pos - center).abs()
	var boundary: Vector2 = half_extents + Vector2.ONE * (landmark_profile.maximum_bounding_radius + landmark_profile.safety_padding)
	return delta_pos.x <= boundary.x and delta_pos.y <= boundary.y

func _configure_galaxy_instance(cell: Vector2i, layer_pos: Vector2, sprite: Sprite2D) -> void:
	sprite.position = layer_pos

	if not landmark_profile.galaxy_textures.is_empty():
		var tex_idx: int = int(_macro_grid.get_cell_pseudorandom_float(cell, 11) * float(landmark_profile.galaxy_textures.size()))
		tex_idx = clampi(tex_idx, 0, landmark_profile.galaxy_textures.size() - 1)
		sprite.texture = landmark_profile.galaxy_textures[tex_idx]

	var scale_factor: float = lerpf(
		landmark_profile.base_scale_range.x,
		landmark_profile.base_scale_range.y,
		_macro_grid.get_cell_pseudorandom_float(cell, 22)
	)
	sprite.scale = Vector2.ONE * scale_factor
	sprite.rotation = _macro_grid.get_cell_pseudorandom_float(cell, 33) * TAU

	var color_count: int = landmark_profile.modulate_colors.size()
	var chosen_color: Color = Color.WHITE
	if color_count > 0:
		var color_idx: int = int(_macro_grid.get_cell_pseudorandom_float(cell, 44) * float(color_count))
		color_idx = clampi(color_idx, 0, color_count - 1)
		chosen_color = landmark_profile.modulate_colors[color_idx]

	sprite.modulate = chosen_color
	if sprite.material is ShaderMaterial:
		var smat: ShaderMaterial = sprite.material as ShaderMaterial
		smat.set_shader_parameter("tint_color", chosen_color)
		if landmark_profile != null:
			smat.set_shader_parameter("spin_speed", landmark_profile.shader_spin_speed)
			smat.set_shader_parameter("overall_brightness", landmark_profile.overall_brightness)
			smat.set_shader_parameter("core_pulse_intensity", landmark_profile.core_pulse_intensity)

	sprite.modulate.a = 0.0
	sprite.visible = true

## Evalúa la posición analítica determinista de una galaxia en su macro-sector
func evaluate_galaxy_layer_position(cell: Vector2i) -> Vector2:
	var cell_base_center: Vector2 = _macro_grid.grid_to_world_center(cell)
	var jitter_pct: float = landmark_profile.jitter_factor if landmark_profile != null else 0.20
	var max_jitter: float = _calculated_cell_size * jitter_pct
	var offset_norm: Vector2 = _macro_grid.get_cell_normalized_offset(cell, 883)
	var jitter: Vector2 = (offset_norm - Vector2(0.5, 0.5)) * max_jitter
	return cell_base_center + jitter

## Métodos públicos de consulta para introspección, gizmos y testing
func get_active_galaxies() -> Dictionary:
	return _active_galaxies

func get_active_galaxies_count() -> int:
	return _active_galaxies.size()

func get_target_alpha() -> float:
	return 1.0 if is_galaxy_rendered() else 0.0

func get_current_alpha() -> float:
	var spr: Sprite2D = get_active_sprite()
	return spr.modulate.a if spr != null else 0.0

func get_active_cell() -> Vector2i:
	if _active_galaxies.is_empty():
		return Vector2i(2147483647, 2147483647)
	return _active_galaxies.keys()[0] as Vector2i

func is_galaxy_rendered() -> bool:
	return not _active_galaxies.is_empty()

func get_active_sprite() -> Sprite2D:
	if not _active_galaxies.is_empty():
		return _active_galaxies.values()[0] as Sprite2D
	if not _pool.is_empty():
		return _pool[0]
	return null

func get_calculated_cell_size() -> float:
	return _calculated_cell_size

func get_safe_min_distance() -> float:
	return _safe_min_distance

func get_macro_grid() -> CosmosMacroGrid:
	return _macro_grid

func get_pool_available_count() -> int:
	return _pool.size()
