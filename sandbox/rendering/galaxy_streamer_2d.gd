class_name GalaxyStreamer2D
extends Node2D

## Controlador de streaming determinista de macro-galaxias en capas de Parallax2D lentas.
## Garantiza analíticamente la exclusividad 1-a-1 en frustum y zero allocation en runtime.

@export var landmark_profile: GalaxyLandmarkProfile
@export var parallax_layer: Parallax2D
@export var camera: Camera2D
@export var run_seed: int = 8943719

var _macro_grid: CosmicMacroGrid
var _calculated_cell_size: float = 0.0
var _safe_min_distance: float = 0.0

var _active_galaxy_sprite: Sprite2D = null
var _active_cell: Vector2i = Vector2i(2147483647, 2147483647)
var _is_rendered: bool = false
var _target_alpha: float = 0.0
var _current_alpha: float = 0.0

var _cached_frustum_half_extents: Vector2 = Vector2.ZERO
var _cached_screen_center_layer: Vector2 = Vector2.ZERO

func _ready() -> void:
	if landmark_profile != null:
		_initialize_exclusivity_geometry()
	_initialize_node_pool()

func _initialize_exclusivity_geometry() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(1920.0, 1080.0)
	var worst_case_zoom: float = 0.25
	var frustum_diagonal: float = viewport_size.length() / worst_case_zoom
	
	_safe_min_distance = frustum_diagonal + (2.0 * landmark_profile.maximum_bounding_radius) + (2.0 * landmark_profile.safety_padding)
	_calculated_cell_size = 2.0 * _safe_min_distance
	_macro_grid = CosmicMacroGrid.new(_calculated_cell_size, run_seed)

const GALAXY_DEEP_SHADER: Shader = preload("res://scenes/combat/environment/galaxy_deep.gdshader")

func _initialize_node_pool() -> void:
	_active_galaxy_sprite = Sprite2D.new()
	_active_galaxy_sprite.centered = true
	_active_galaxy_sprite.visible = false
	_active_galaxy_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)

	if GALAXY_DEEP_SHADER != null:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = GALAXY_DEEP_SHADER
		mat.set_shader_parameter("spin_speed", 0.003)
		mat.set_shader_parameter("overall_brightness", 0.95)
		mat.set_shader_parameter("core_pulse_intensity", 0.25)
		mat.set_shader_parameter("radial_fade_start", 0.35)
		mat.set_shader_parameter("radial_fade_end", 0.49)
		_active_galaxy_sprite.material = mat

	add_child(_active_galaxy_sprite)

func _process(delta: float) -> void:
	_evaluate_frustum_and_stream(delta)

func _evaluate_frustum_and_stream(delta: float) -> void:
	if camera == null or parallax_layer == null or landmark_profile == null or _macro_grid == null:
		return

	var zoom: Vector2 = camera.zoom
	if zoom.x <= 0.0001 or zoom.y <= 0.0001:
		zoom = Vector2.ONE

	var viewport_rect: Rect2 = get_viewport_rect()
	var viewport_size: Vector2 = viewport_rect.size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(1920.0, 1080.0)

	var viewport_half: Vector2 = (viewport_size * 0.5) / zoom
	var cam_pos: Vector2 = camera.get_screen_center_position()
	if cam_pos == Vector2.ZERO and camera.global_position != Vector2.ZERO:
		cam_pos = camera.global_position
	
	_cached_screen_center_layer = (cam_pos * parallax_layer.scroll_scale) - parallax_layer.scroll_offset
	_cached_frustum_half_extents = viewport_half

	var current_cell: Vector2i = _macro_grid.world_to_grid_coords(_cached_screen_center_layer)
	
	var candidate_found: bool = false
	var candidate_pos: Vector2 = Vector2.ZERO
	var candidate_cell: Vector2i = Vector2i.ZERO

	for ox: int in range(-1, 2):
		for oy: int in range(-1, 2):
			var test_cell: Vector2i = current_cell + Vector2i(ox, oy)
			
			if _macro_grid.get_cell_pseudorandom_float(test_cell, 551) > 0.65:
				continue
				
			var cell_base_center: Vector2 = _macro_grid.grid_to_world_center(test_cell)
			var offset_norm: Vector2 = _macro_grid.get_cell_normalized_offset(test_cell, 883)
			var max_jitter: float = _calculated_cell_size - _safe_min_distance
			var jitter: Vector2 = (offset_norm - Vector2(0.5, 0.5)) * max_jitter
			var galaxy_layer_pos: Vector2 = cell_base_center + jitter
			
			if _intersects_frustum(galaxy_layer_pos, _cached_screen_center_layer, _cached_frustum_half_extents):
				candidate_found = true
				candidate_pos = galaxy_layer_pos
				candidate_cell = test_cell
				break
		if candidate_found:
			break

	if candidate_found:
		if not _is_rendered or _active_cell != candidate_cell:
			_configure_galaxy_instance(candidate_cell, candidate_pos)
		_target_alpha = 1.0
	else:
		_target_alpha = 0.0

	_update_fade_state(delta)

func _intersects_frustum(pos: Vector2, center: Vector2, half_extents: Vector2) -> bool:
	var delta_pos: Vector2 = (pos - center).abs()
	var boundary: Vector2 = half_extents + Vector2.ONE * (landmark_profile.maximum_bounding_radius + landmark_profile.safety_padding)
	return delta_pos.x <= boundary.x and delta_pos.y <= boundary.y

func _configure_galaxy_instance(cell: Vector2i, layer_pos: Vector2) -> void:
	_active_cell = cell
	_is_rendered = true
	_active_galaxy_sprite.position = layer_pos
	
	if not landmark_profile.galaxy_textures.is_empty():
		var tex_idx: int = int(_macro_grid.get_cell_pseudorandom_float(cell, 11) * float(landmark_profile.galaxy_textures.size()))
		tex_idx = clampi(tex_idx, 0, landmark_profile.galaxy_textures.size() - 1)
		_active_galaxy_sprite.texture = landmark_profile.galaxy_textures[tex_idx]
	
	var scale_factor: float = lerpf(
		landmark_profile.base_scale_range.x,
		landmark_profile.base_scale_range.y,
		_macro_grid.get_cell_pseudorandom_float(cell, 22)
	)
	_active_galaxy_sprite.scale = Vector2.ONE * scale_factor
	_active_galaxy_sprite.rotation = _macro_grid.get_cell_pseudorandom_float(cell, 33) * TAU
	
	var color_count: int = landmark_profile.modulate_colors.size()
	var chosen_color: Color = Color.WHITE
	if color_count > 0:
		var color_idx: int = int(_macro_grid.get_cell_pseudorandom_float(cell, 44) * float(color_count))
		color_idx = clampi(color_idx, 0, color_count - 1)
		chosen_color = landmark_profile.modulate_colors[color_idx]

	_active_galaxy_sprite.modulate = chosen_color
	if _active_galaxy_sprite.material is ShaderMaterial:
		(_active_galaxy_sprite.material as ShaderMaterial).set_shader_parameter("tint_color", chosen_color)

	_active_galaxy_sprite.modulate.a = 0.0
	_current_alpha = 0.0
	_active_galaxy_sprite.visible = true

func _update_fade_state(delta: float) -> void:
	if not _is_rendered:
		return
		
	_current_alpha = move_toward(_current_alpha, _target_alpha, delta * 0.75)
	_active_galaxy_sprite.modulate.a = _current_alpha
	_active_galaxy_sprite.rotation += landmark_profile.max_drift_rotation_speed * delta
	
	if _current_alpha <= 0.0 and _target_alpha == 0.0:
		_active_galaxy_sprite.visible = false
		_is_rendered = false
		_active_cell = Vector2i(2147483647, 2147483647)

## Métodos públicos de consulta para introspección y testing analítico
func get_active_cell() -> Vector2i:
	return _active_cell

func is_galaxy_rendered() -> bool:
	return _is_rendered

func get_current_alpha() -> float:
	return _current_alpha

func get_target_alpha() -> float:
	return _target_alpha

func get_active_sprite() -> Sprite2D:
	return _active_galaxy_sprite

func get_calculated_cell_size() -> float:
	return _calculated_cell_size

func get_safe_min_distance() -> float:
	return _safe_min_distance

func get_macro_grid() -> CosmicMacroGrid:
	return _macro_grid

func evaluate_galaxy_layer_position(cell: Vector2i) -> Vector2:
	var cell_base_center: Vector2 = _macro_grid.grid_to_world_center(cell)
	var offset_norm: Vector2 = _macro_grid.get_cell_normalized_offset(cell, 883)
	var max_jitter: float = _calculated_cell_size - _safe_min_distance
	var jitter: Vector2 = (offset_norm - Vector2(0.5, 0.5)) * max_jitter
	return cell_base_center + jitter
