class_name HubCosmosBackdropController
extends CanvasLayer

## Controlador del Cosmos Engine vivo a pantalla completa detrás del SubViewport 3D transparente del Hub.
## Aloja un CosmosRootNode 2D aislado, sincroniza parallax suave con el vuelo de Valentina,
## expone CosmicLightingSampler en tiempo real y prepara la transición 1:1 hacia MainGame.

const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_art_lab_config.gd")
const CosmosRootScene: PackedScene = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.tscn")
const CosmicLightingSamplerScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sampler.gd")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")

const HUB_BASE_ZOOM: float = 0.78
const COMBAT_TARGET_ZOOM: float = 1.0
const WORLD_TO_COSMOS_PX: float = 28.0

var _config: ConfigScript = null
var _container: SubViewportContainer = null
var _subviewport: SubViewport = null
var _camera_2d: Camera2D = null
var _anchor_2d: Node2D = null
var _cosmos_root: CosmosRootNode = null
var _flash_rect: ColorRect = null

var _preview_seed: int = 428175
var _seed_applied: bool = false
var _quality_tier: int = 2
var _time_acc: float = 0.0
var _flash_timer: float = 0.0
var _player_world_xz: Vector2 = Vector2.ZERO
var _departure_zoom_blend: float = 0.0


func setup(p_config: ConfigScript, p_initial_seed: int = -1) -> void:
	_config = p_config
	layer = -10
	if p_initial_seed > 0:
		_preview_seed = maxi(1, p_initial_seed & 0x7FFFFFFF)
	elif _config != null:
		_preview_seed = _config.default_preview_seed

	_quality_tier = _read_settings_quality()
	_ensure_backdrop_nodes()
	apply_quality_tier(_quality_tier)
	set_preview_seed(_preview_seed, false)


func _read_settings_quality() -> int:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and tree.root.has_node("SettingsManager"):
		var sm: Node = tree.root.get_node("SettingsManager")
		if sm != null and "space_background_quality" in sm:
			return clampi(int(sm.space_background_quality), 0, 2)
	return 2


func _ensure_backdrop_nodes() -> void:
	if _subviewport != null:
		return

	_container = SubViewportContainer.new()
	_container.name = "CosmosBackdropContainer"
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)

	_subviewport = SubViewport.new()
	_subviewport.name = "CosmosBackdropSubViewport"
	_subviewport.disable_3d = true
	_subviewport.transparent_bg = false
	_subviewport.use_hdr_2d = true
	_subviewport.msaa_2d = Viewport.MSAA_DISABLED
	_subviewport.handle_input_locally = false
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(_subviewport)

	_anchor_2d = Node2D.new()
	_anchor_2d.name = "CosmosBackdropAnchor"
	_anchor_2d.position = Vector2.ZERO
	_subviewport.add_child(_anchor_2d)

	_camera_2d = Camera2D.new()
	_camera_2d.name = "CosmosBackdropCamera2D"
	_camera_2d.enabled = true
	_camera_2d.zoom = Vector2(HUB_BASE_ZOOM, HUB_BASE_ZOOM)
	_subviewport.add_child(_camera_2d)

	_cosmos_root = CosmosRootScene.instantiate() as CosmosRootNode
	if _cosmos_root != null:
		_cosmos_root.name = "CosmosBackdropRoot"
		_cosmos_root.camera = _camera_2d
		_cosmos_root.player_target = _anchor_2d
		_subviewport.add_child(_cosmos_root)
		if _cosmos_root.floating_origin_tracker != null:
			_cosmos_root.floating_origin_tracker.is_enabled = false
			_cosmos_root.floating_origin_tracker.set_physics_process(false)
			_cosmos_root.floating_origin_tracker.set_process(false)
		_cosmos_root.bind_camera_to_streamers()

	_flash_rect = ColorRect.new()
	_flash_rect.name = "RetuneFlashOverlay"
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(0.45, 0.92, 1.0, 0.0)
	_flash_rect.visible = false
	add_child(_flash_rect)


func apply_quality_tier(tier: int) -> void:
	_quality_tier = clampi(tier, 0, 2)
	if _container != null:
		_container.stretch_shrink = 2 if _quality_tier == 0 else 1
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
		if _flash_rect != null:
			_flash_rect.visible = true
			_flash_rect.color.a = 0.28


func get_preview_seed() -> int:
	return _preview_seed


func get_cosmos_root() -> CosmosRootNode:
	return _cosmos_root


func get_subviewport() -> SubViewport:
	return _subviewport


func sync_with_player_world_xz(world_xz: Vector2, _delta: float) -> void:
	_player_world_xz = world_xz


func blend_camera_zoom_to_combat(t: float) -> void:
	_departure_zoom_blend = clampf(t, 0.0, 1.0)
	if _camera_2d != null:
		var z: float = lerpf(HUB_BASE_ZOOM, COMBAT_TARGET_ZOOM, _departure_zoom_blend)
		_camera_2d.zoom = Vector2(z, z)


func sample_cosmic_lighting(out_sample: CosmicLightingSampleScript = null) -> CosmicLightingSampleScript:
	var pos_2d: Vector2 = _camera_2d.position if _camera_2d != null else Vector2.ZERO
	return CosmicLightingSamplerScript.sample_at(_cosmos_root, pos_2d, null, out_sample)


func get_cosmos_sync_state() -> Dictionary:
	return {
		"cosmos_seed": _preview_seed,
		"cosmos_sync_time": _cosmos_root.get_global_time() if (_cosmos_root != null and is_instance_valid(_cosmos_root)) else _time_acc,
		"cosmos_sync_pos": _camera_2d.position if _camera_2d != null else Vector2.ZERO,
	}


func _process(delta: float) -> void:
	if _subviewport == null:
		return
	var vis_now: bool = visible
	var target_mode: SubViewport.UpdateMode = SubViewport.UPDATE_ALWAYS if vis_now else SubViewport.UPDATE_DISABLED
	if _subviewport.render_target_update_mode != target_mode:
		_subviewport.render_target_update_mode = target_mode
	if not vis_now:
		return

	_time_acc += delta
	if _camera_2d != null and _config != null:
		var phase: float = _time_acc * TAU * _config.cosmos_drift_hz
		var drift := Vector2(sin(phase) * _config.cosmos_drift_amp.x, cos(phase * 0.7) * _config.cosmos_drift_amp.y)
		var target_pos: Vector2 = drift + _player_world_xz * WORLD_TO_COSMOS_PX
		_camera_2d.position = _camera_2d.position.lerp(target_pos, clampf(delta * 5.0, 0.0, 1.0))
		if _anchor_2d != null:
			_anchor_2d.position = _camera_2d.position

	if _flash_timer > 0.0 and _config != null:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		var norm: float = _flash_timer / maxf(_config.cosmos_retune_duration, 0.001)
		if _flash_rect != null:
			_flash_rect.color.a = norm * 0.28
			if _flash_timer <= 0.0:
				_flash_rect.visible = false
