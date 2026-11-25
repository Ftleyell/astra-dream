class_name HubCosmosWindowController
extends Node3D

## Controlador del Ventanal Panorámico Norte que proyecta CosmosRootNode vivo en un SubViewport.
## Adapta automáticamente la resolución del SubViewport según SettingsManager.space_background_quality
## y sincroniza en caliente la semilla del sector inicial (next_run_seed) con pulso visual retune_flash.

const ConfigScript = preload("res://sandbox/hub_art_lab/resources/hub_art_lab_config.gd")
const CosmosRootScene: PackedScene = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.tscn")
const CosmosWindowShader = preload("res://sandbox/hub_art_lab/shaders/hub_cosmos_window_3d.gdshader")

var _config: ConfigScript = null
var _window_mesh: MeshInstance3D = null
var _window_mat: ShaderMaterial = null
var _subviewport: SubViewport = null
var _camera_2d: Camera2D = null
var _anchor_2d: Node2D = null
var _cosmos_root: CosmosRootNode = null

var _preview_seed: int = 428175
var _seed_applied: bool = false
var _quality_tier: int = 2
var _time_acc: float = 0.0
var _flash_timer: float = 0.0


func setup(p_config: ConfigScript, p_window_mesh: MeshInstance3D, p_initial_seed: int = -1) -> void:
	_config = p_config
	_window_mesh = p_window_mesh
	if p_initial_seed > 0:
		_preview_seed = maxi(1, p_initial_seed & 0x7FFFFFFF)
	elif _config != null:
		_preview_seed = _config.default_preview_seed

	_quality_tier = _read_settings_quality()
	_ensure_subviewport()
	_bind_window_material()
	apply_quality_tier(_quality_tier)
	set_preview_seed(_preview_seed, false)


func _read_settings_quality() -> int:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and tree.root.has_node("SettingsManager"):
		var sm: Node = tree.root.get_node("SettingsManager")
		if sm != null and "space_background_quality" in sm:
			return clampi(int(sm.space_background_quality), 0, 2)
	return 2


func _ensure_subviewport() -> void:
	if _subviewport != null:
		return

	_subviewport = SubViewport.new()
	_subviewport.name = "CosmosWindowSubViewport"
	_subviewport.disable_3d = true
	_subviewport.transparent_bg = false
	_subviewport.use_hdr_2d = true
	_subviewport.msaa_2d = Viewport.MSAA_DISABLED
	_subviewport.handle_input_locally = false
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_subviewport.size = _resolve_resolution_for_tier(_quality_tier)
	add_child(_subviewport)

	_anchor_2d = Node2D.new()
	_anchor_2d.name = "CosmosPreviewAnchor"
	_anchor_2d.position = Vector2.ZERO
	_subviewport.add_child(_anchor_2d)

	_camera_2d = Camera2D.new()
	_camera_2d.name = "CosmosPreviewCamera2D"
	_camera_2d.enabled = true
	var zoom_val: float = _config.cosmos_camera_zoom if _config != null else 0.62
	_camera_2d.zoom = Vector2(zoom_val, zoom_val)
	_subviewport.add_child(_camera_2d)

	_cosmos_root = CosmosRootScene.instantiate() as CosmosRootNode
	if _cosmos_root != null:
		_cosmos_root.name = "CosmosPreviewRoot"
		_cosmos_root.camera = _camera_2d
		_cosmos_root.player_target = _anchor_2d
		_subviewport.add_child(_cosmos_root)
		if _cosmos_root.floating_origin_tracker != null:
			_cosmos_root.floating_origin_tracker.is_enabled = false
			_cosmos_root.floating_origin_tracker.set_physics_process(false)
			_cosmos_root.floating_origin_tracker.set_process(false)
		_cosmos_root.bind_camera_to_streamers()


func _bind_window_material() -> void:
	if _window_mesh == null or _subviewport == null:
		return
	if _window_mat == null:
		_window_mat = ShaderMaterial.new()
		_window_mat.shader = CosmosWindowShader
	_window_mat.set_shader_parameter("cosmos_tex", _subviewport.get_texture())
	_window_mat.set_shader_parameter("retune_flash", 0.0)
	_window_mesh.material_override = _window_mat


func _resolve_resolution_for_tier(tier: int) -> Vector2i:
	var clamped: int = clampi(tier, 0, 2)
	if _config != null and _config.cosmos_viewport_resolutions.size() > clamped:
		return _config.cosmos_viewport_resolutions[clamped]
	match clamped:
		0:
			return Vector2i(640, 320)
		1:
			return Vector2i(960, 480)
		_:
			return Vector2i(1280, 640)


func apply_quality_tier(tier: int) -> void:
	_quality_tier = clampi(tier, 0, 2)
	if _subviewport != null:
		_subviewport.size = _resolve_resolution_for_tier(_quality_tier)
	if _cosmos_root != null and is_instance_valid(_cosmos_root):
		_cosmos_root.apply_graphics_quality(_quality_tier)


func get_quality_tier() -> int:
	return _quality_tier


func set_preview_seed(p_seed: int, trigger_flash: bool = true) -> void:
	var normalized: int = maxi(1, p_seed & 0x7FFFFFFF)
	if _seed_applied and _preview_seed == normalized and not trigger_flash:
		return
	_preview_seed = normalized
	_seed_applied = true
	if _cosmos_root != null and is_instance_valid(_cosmos_root):
		_cosmos_root.set_run_seed(_preview_seed)
		_cosmos_root.bind_camera_to_streamers()
	if trigger_flash and _config != null:
		_flash_timer = _config.cosmos_retune_duration
		if _window_mat != null:
			_window_mat.set_shader_parameter("retune_flash", 1.0)


func get_preview_seed() -> int:
	return _preview_seed


func get_subviewport() -> SubViewport:
	return _subviewport


func get_cosmos_root() -> CosmosRootNode:
	return _cosmos_root


func _process(delta: float) -> void:
	if _subviewport == null:
		return
	var vis_now: bool = is_visible_in_tree() and (_window_mesh == null or _window_mesh.visible)
	var target_mode: SubViewport.UpdateMode = SubViewport.UPDATE_ALWAYS if vis_now else SubViewport.UPDATE_DISABLED
	if _subviewport.render_target_update_mode != target_mode:
		_subviewport.render_target_update_mode = target_mode
	if not vis_now:
		return

	_time_acc += delta
	if _camera_2d != null and _config != null:
		var phase: float = _time_acc * TAU * _config.cosmos_drift_hz
		var drift_pos := Vector2(sin(phase) * _config.cosmos_drift_amp.x, cos(phase * 0.7) * _config.cosmos_drift_amp.y)
		_camera_2d.position = drift_pos
		if _anchor_2d != null:
			_anchor_2d.position = drift_pos

	if _flash_timer > 0.0 and _config != null:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		var norm: float = _flash_timer / maxf(_config.cosmos_retune_duration, 0.001)
		if _window_mat != null:
			_window_mat.set_shader_parameter("retune_flash", norm)
