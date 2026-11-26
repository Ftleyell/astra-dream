class_name HubEmbeddedViewportBridge
extends Node

## Puente de paridad ortográfica 1:1 entre GameCamera2D / Player 2D (MainGame)
## y el SubViewport transparente del Hub 3D (AstralStationHub).
## Se ejecuta con process_priority = 10 para sincronizarse estrictamente después de GameCamera2D.

const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_art_lab_config.gd")
const LayoutConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_floating_layout_config.gd")

var hub_origin_2d: Vector2 = Vector2(960.0, 540.0)
var config: ConfigScript = null
var layout_config: LayoutConfigScript = null
var camera_2d: GameCamera2D = null
var camera_3d: Camera3D = null
var subviewport: SubViewport = null
var display_sprite: Sprite2D = null

var _flash_layer: CanvasLayer = null
var _flash_rect: ColorRect = null
var _flash_timer: float = 0.0
var _flash_duration: float = 0.32


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10


func setup(
	p_hub_origin_2d: Vector2,
	p_config: ConfigScript,
	p_layout_config: LayoutConfigScript,
	p_camera_2d: GameCamera2D,
	p_camera_3d: Camera3D,
	p_subviewport: SubViewport,
	p_display_sprite: Sprite2D
) -> void:
	hub_origin_2d = p_hub_origin_2d
	config = p_config
	layout_config = p_layout_config
	camera_2d = p_camera_2d
	camera_3d = p_camera_3d
	subviewport = p_subviewport
	display_sprite = p_display_sprite
	_ensure_flash_overlay()
	sync_camera_and_sprite()


func _ensure_flash_overlay() -> void:
	if _flash_layer != null:
		return
	_flash_layer = CanvasLayer.new()
	_flash_layer.name = "HubCosmosRetuneFlashLayer"
	_flash_layer.layer = 35
	add_child(_flash_layer)

	_flash_rect = ColorRect.new()
	_flash_rect.name = "RetuneFlashOverlay"
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(0.45, 0.92, 1.0, 0.0)
	_flash_rect.visible = false
	_flash_layer.add_child(_flash_rect)


func get_px_per_meter_x() -> float:
	if layout_config != null:
		return maxf(layout_config.embedded_px_per_meter_x, 10.0)
	return 84.0


func get_px_per_meter_z() -> float:
	var pitch_deg: float = absf(config.free_roam_pitch_deg) if config != null else 46.0
	return get_px_per_meter_x() * maxf(sin(deg_to_rad(pitch_deg)), 0.15)


func world_2d_to_hub_xz(world_2d: Vector2) -> Vector2:
	return Vector2(
		(world_2d.x - hub_origin_2d.x) / get_px_per_meter_x(),
		(world_2d.y - hub_origin_2d.y) / get_px_per_meter_z()
	)


func hub_3d_to_world_2d(pos_3d: Vector3) -> Vector2:
	return Vector2(
		hub_origin_2d.x + pos_3d.x * get_px_per_meter_x(),
		hub_origin_2d.y + pos_3d.z * get_px_per_meter_z()
	)


func trigger_retune_flash(duration: float = 0.32) -> void:
	_flash_duration = maxf(duration, 0.05)
	_flash_timer = _flash_duration
	if _flash_rect != null:
		_flash_rect.visible = true
		_flash_rect.color.a = 0.28


func _process(delta: float) -> void:
	sync_camera_and_sprite()
	if _flash_timer > 0.0 and _flash_rect != null:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		var norm: float = _flash_timer / maxf(_flash_duration, 0.001)
		_flash_rect.color.a = norm * 0.28
		if _flash_timer <= 0.0:
			_flash_rect.visible = false


func sync_camera_and_sprite() -> void:
	if camera_2d == null or not is_instance_valid(camera_2d):
		return
	if camera_3d == null or not is_instance_valid(camera_3d):
		return
	if subviewport == null or not is_instance_valid(subviewport):
		return
	if display_sprite == null or not is_instance_valid(display_sprite):
		return

	var main_vp: Viewport = get_viewport()
	var win_px := Vector2i(1280, 720)
	var vis_rect := Vector2(1920.0, 1080.0)
	if main_vp != null:
		var raw_win: Vector2i = main_vp.size
		if raw_win.x > 0 and raw_win.y > 0:
			win_px = Vector2i(maxi(raw_win.x, 64), maxi(raw_win.y, 64))
		var raw_vis: Vector2 = main_vp.get_visible_rect().size
		if raw_vis.x > 1.0 and raw_vis.y > 1.0:
			vis_rect = raw_vis

	if subviewport.size != win_px:
		subviewport.size = win_px

	var cam_center: Vector2 = camera_2d.global_position + camera_2d.offset
	var zoom_x: float = maxf(camera_2d.zoom.x, 0.05)
	var zoom_y: float = maxf(camera_2d.zoom.y, 0.05)

	display_sprite.global_position = cam_center
	display_sprite.scale = Vector2(
		(vis_rect.x / zoom_x) / float(win_px.x),
		(vis_rect.y / zoom_y) / float(win_px.y)
	)

	var px_x: float = get_px_per_meter_x()
	var pitch_deg: float = config.free_roam_pitch_deg if config != null else -46.0
	var pitch_rad: float = deg_to_rad(absf(pitch_deg))
	var cam_dist: float = layout_config.embedded_camera_distance_m if layout_config != null else 30.0

	camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_3d.keep_aspect = Camera3D.KEEP_HEIGHT
	camera_3d.size = (vis_rect.y / zoom_y) / px_x
	camera_3d.near = 2.0
	camera_3d.far = 72.0
	camera_3d.rotation_degrees = Vector3(pitch_deg, 0.0, 0.0)

	var cam_xz: Vector2 = world_2d_to_hub_xz(cam_center)
	var cam_offset_3d := Vector3(0.0, sin(pitch_rad) * cam_dist, cos(pitch_rad) * cam_dist)
	var target_3d := Vector3(cam_xz.x, 0.0, cam_xz.y) + cam_offset_3d
	if camera_3d.is_inside_tree():
		camera_3d.global_position = target_3d
	else:
		camera_3d.position = target_3d
