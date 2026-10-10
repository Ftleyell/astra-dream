class_name NebulaBackdropController
extends ColorRect

## Controlador de actualización de uniforms para el shader universe_nebula.gdshader.
## Actualiza cámara, resolución, tiempo cósmico y perfiles de biomas en runtime con zero allocations.

@export var camera: Camera2D
@export var biome_a: CosmicBiomeConfig
@export var biome_b: CosmicBiomeConfig
@export_range(0.0, 1.0, 0.01) var biome_blend_factor: float = 0.0
@export_range(0.0, 1.0, 0.005) var parallax_factor: float = 0.05
@export var auto_sync_viewport: bool = true

var _shader_mat: ShaderMaterial = null
var _accumulated_time: float = 0.0
var accumulated_origin_shift: Vector2 = Vector2.ZERO

func _ready() -> void:
	if material is ShaderMaterial:
		_shader_mat = material as ShaderMaterial
	else:
		var shader_res: Shader = load("res://sandbox/shaders/universe_nebula.gdshader") as Shader
		if shader_res != null:
			_shader_mat = ShaderMaterial.new()
			_shader_mat.shader = shader_res
			material = _shader_mat

	# Asegurar anclaje a pantalla completa
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_biome_configurations()

func _process(delta: float) -> void:
	_accumulated_time += delta
	_update_uniforms()

func _apply_biome_configurations() -> void:
	if _shader_mat == null:
		return

	if biome_a != null:
		_shader_mat.set_shader_parameter("biome_a_color_deep", biome_a.color_deep_space)
		_shader_mat.set_shader_parameter("biome_a_color_gas_primary", biome_a.color_gas_primary)
		_shader_mat.set_shader_parameter("biome_a_color_gas_secondary", biome_a.color_gas_secondary)
		_shader_mat.set_shader_parameter("biome_a_density", biome_a.gas_density)
		_shader_mat.set_shader_parameter("biome_a_frequency", biome_a.noise_frequency)

	if biome_b != null:
		_shader_mat.set_shader_parameter("biome_b_color_deep", biome_b.color_deep_space)
		_shader_mat.set_shader_parameter("biome_b_color_gas_primary", biome_b.color_gas_primary)
		_shader_mat.set_shader_parameter("biome_b_color_gas_secondary", biome_b.color_gas_secondary)
		_shader_mat.set_shader_parameter("biome_b_density", biome_b.gas_density)
		_shader_mat.set_shader_parameter("biome_b_frequency", biome_b.noise_frequency)

func _update_uniforms() -> void:
	if _shader_mat == null:
		return

	_shader_mat.set_shader_parameter("global_time", _accumulated_time)
	_shader_mat.set_shader_parameter("parallax_factor", parallax_factor)
	_shader_mat.set_shader_parameter("biome_blend_factor", biome_blend_factor)

	if auto_sync_viewport:
		var vp_rect: Rect2 = get_viewport_rect()
		var res: Vector2 = vp_rect.size if vp_rect.size != Vector2.ZERO else Vector2(1920.0, 1080.0)
		_shader_mat.set_shader_parameter("viewport_resolution", res)

	if camera != null:
		var cam_pos: Vector2 = camera.get_screen_center_position()
		if cam_pos == Vector2.ZERO and camera.global_position != Vector2.ZERO:
			cam_pos = camera.global_position
		var world_cam: Vector2 = cam_pos + accumulated_origin_shift
		_shader_mat.set_shader_parameter("camera_world_position", world_cam)

func set_blend_factor(blend: float) -> void:
	biome_blend_factor = clampf(blend, 0.0, 1.0)
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("biome_blend_factor", biome_blend_factor)
