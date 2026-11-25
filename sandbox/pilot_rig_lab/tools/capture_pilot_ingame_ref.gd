extends Node2D
## Herramienta de captura en ventana GPU para extraer referencia fiel del modelo in-game
## con shaders activos (PlanarCombatRig + 02_valentina_razor_sharp + Pass2 + FaceLive).
## Uso:
##   Godot --path . --windowed --resolution 1280x1024 res://sandbox/pilot_rig_lab/tools/capture_pilot_ingame_ref.tscn
##   [-- --profile=res://... --out=<abs_o_res> --style=res://...]

const PlanarRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const ViewRouterScript = preload("res://scenes/pilots/rig/planar_rig_view_router.gd")

const DEFAULT_PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const DEFAULT_STYLE_PATH: String = "res://data/pilots/styles/02_valentina_razor_sharp.tres"
const DEFAULT_OUT_DIR: String = "res://sandbox/pilot_rig_lab/source_refs/valentina_v2_dialogue/00_ingame_ref"
const CAPTURE_SIZE := Vector2i(1280, 1024)
const DUAL_ZOOM: float = 6.2
const SINGLE_ZOOM: float = 9.0


var _profile_path: String = DEFAULT_PROFILE_PATH
var _style_path: String = DEFAULT_STYLE_PATH
var _out_path: String = ""
var _bust_out_path: String = ""

var _vp: SubViewport = null
var _camera: Camera2D = null
var _rig_left: PlanarCombatRig = null
var _rig_right: PlanarCombatRig = null


func _ready() -> void:
	_parse_cli_args()
	_ensure_output_dirs()
	_build_capture_stage()
	await _capture_sequence()


func _parse_cli_args() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for raw_arg: String in user_args:
		if raw_arg.begins_with("--profile="):
			_profile_path = raw_arg.trim_prefix("--profile=").strip_edges()
		elif raw_arg.begins_with("--style="):
			_style_path = raw_arg.trim_prefix("--style=").strip_edges()
		elif raw_arg.begins_with("--out="):
			_out_path = raw_arg.trim_prefix("--out=").strip_edges()

	var pilot_slug: String = "valentina_v2"
	var prof_res: Resource = ResourceLoader.load(_profile_path)
	var profile: PilotRigProfile = prof_res as PilotRigProfile
	if profile != null and not profile.pilot_id.is_empty():
		pilot_slug = profile.pilot_id

	if _out_path.is_empty():
		var out_dir_abs: String = ProjectSettings.globalize_path(DEFAULT_OUT_DIR)
		_out_path = out_dir_abs.path_join("%s_ingame_shaded_ref.png" % pilot_slug)
	elif _out_path.begins_with("res://"):
		_out_path = ProjectSettings.globalize_path(_out_path)

	var parent_dir: String = _out_path.get_base_dir()
	_bust_out_path = parent_dir.path_join("%s_ingame_bust_se.png" % pilot_slug)


func _ensure_output_dirs() -> void:
	var dir_abs: String = _out_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_abs):
		DirAccess.make_dir_recursive_absolute(dir_abs)


func _build_capture_stage() -> void:
	var profile: PilotRigProfile = ResourceLoader.load(_profile_path) as PilotRigProfile
	var style: RigStyleProfile = ResourceLoader.load(_style_path) as RigStyleProfile
	var skin: PilotSkinPreset = null
	var hair: PilotHairPreset = null
	if profile != null:
		if not profile.skins.is_empty():
			skin = profile.skins[0]
		if not profile.hair_presets.is_empty():
			hair = profile.hair_presets[0]
		if style == null and not profile.style_profiles.is_empty():
			style = profile.style_profiles[profile.style_profiles.size() - 1]

	_vp = SubViewport.new()
	_vp.name = "CaptureSubViewport"
	_vp.size = CAPTURE_SIZE
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.use_hdr_2d = true
	_vp.msaa_2d = Viewport.MSAA_2X
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	var bg := ColorRect.new()
	bg.name = "NeutralDarkBg"
	bg.color = Color(0.18, 0.21, 0.29, 1.0)
	bg.position = Vector2(-1200.0, -1200.0)
	bg.size = Vector2(2400.0, 2400.0)
	_vp.add_child(bg)

	_camera = Camera2D.new()
	_camera.name = "CaptureCamera"
	_camera.position = Vector2(0.0, -14.0)
	_camera.zoom = Vector2(DUAL_ZOOM, DUAL_ZOOM)
	_camera.enabled = true
	_vp.add_child(_camera)

	_rig_left = _spawn_rig("RigFrontS", Vector2(-50.0, 0.0), profile, style, skin, hair, "s", "head_front")
	_rig_right = _spawn_rig("RigThreeQuarterSE", Vector2(50.0, 0.0), profile, style, skin, hair, "se", "head_front_r")

	var preview_rect := TextureRect.new()
	preview_rect.texture = _vp.get_texture()
	preview_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.add_child(preview_rect)
	add_child(layer)


func _spawn_rig(
	node_name: String,
	pos: Vector2,
	profile: PilotRigProfile,
	style: RigStyleProfile,
	skin: PilotSkinPreset,
	hair: PilotHairPreset,
	view_key: String,
	head_key: String
) -> PlanarCombatRig:
	var rig: PlanarCombatRig = PlanarRigScript.new()
	rig.name = node_name
	rig.position = pos
	rig.pilot_profile = profile
	if profile != null:
		rig.display_scale = profile.display_scale
	rig.calibration_manual_pose = true
	rig.enable_live_animations = false
	rig.enable_face_live = true
	rig.enable_3d_wings = false
	rig.enable_base_propulsion_wings = false
	rig.enable_procedural_wings = false
	_vp.add_child(rig)

	rig.set_static_inspection(true, view_key, head_key, true)
	if style != null:
		rig.apply_style_profile(style)
	if skin != null:
		rig.apply_skin_preset(skin, 1)
	if hair != null:
		var skin_hair: Color = skin.hair_color if skin != null else Color(0.86, 0.89, 0.96, 1.0)
		rig.apply_hair_preset(hair, skin_hair)
	rig.set_shader_param_all("enable_inward_outline", false)
	var light_dir := Vector2(cos(deg_to_rad(234.0)), sin(deg_to_rad(234.0))).normalized()
	rig.set_normal_depth_options(true, light_dir, 0.88, 1.78)
	rig.set_zoom_scale(DUAL_ZOOM)
	rig.set_q_time(0.0)
	return rig


func _capture_sequence() -> void:
	for _i: int in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var dual_img: Image = _vp.get_texture().get_image()
	if dual_img != null and not dual_img.is_empty():
		var err_dual: Error = dual_img.save_png(_out_path)
		print("CAPTURED_DUAL=", _out_path, " err=", err_dual)
	else:
		push_error("Capture image empty for dual shot")

	# Segunda captura centrada de busto SE en alta densidad
	if is_instance_valid(_rig_left):
		_rig_left.visible = false
	if is_instance_valid(_rig_right):
		_rig_right.position = Vector2(0.0, 0.0)
		_rig_right.set_zoom_scale(SINGLE_ZOOM)
	if is_instance_valid(_camera):
		_camera.position = Vector2(0.0, -24.0)
		_camera.zoom = Vector2(SINGLE_ZOOM, SINGLE_ZOOM)

	for _j: int in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var bust_img: Image = _vp.get_texture().get_image()
	if bust_img != null and not bust_img.is_empty():
		var err_bust: Error = bust_img.save_png(_bust_out_path)
		print("CAPTURED_BUST=", _bust_out_path, " err=", err_bust)

	get_tree().quit(0)
