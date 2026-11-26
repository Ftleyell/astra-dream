extends Node
## Herramienta de auditoría visual GPU para Astral Glide-Hop en HubLocomotionLab.
## Genera 3 hojas de contacto (N/S, NE/NW/SE/SW, E/W) recortadas alrededor de Valentina.

const LabScene: PackedScene = preload("res://sandbox/hub_art_lab/hub_locomotion_lab/hub_locomotion_lab.tscn")
const LabScript = preload("res://sandbox/hub_art_lab/hub_locomotion_lab/hub_locomotion_lab.gd")

var _out_dir: String = ""
var _lab: LabScript = null


func _ready() -> void:
	_parse_args()
	DirAccess.make_dir_recursive_absolute(_out_dir)

	_lab = LabScene.instantiate() as LabScript
	_lab.name = "HubLocomotionLab"
	add_child(_lab)

	await _wait_frames(8)
	if _lab.hud != null:
		_lab.hud.toggle_panel_visibility()
		var tb: Control = _lab.hud.get("_top_bar") as Control
		if tb != null:
			tb.visible = false
	_lab.set_motion_mode(LabScript.MotionMode.TREADMILL_SCRUB)
	_lab.recenter_player()
	_lab.set_scrub_enabled(true)
	await _wait_frames(3)

	await _capture_ns_sheet()
	await _capture_diagonals_sheet()
	await _capture_profile_ew_sheet()

	_lab.queue_free()
	get_tree().quit(0)


func _parse_args() -> void:
	for raw_arg: String in OS.get_cmdline_user_args():
		if raw_arg.begins_with("--out="):
			_out_dir = raw_arg.trim_prefix("--out=").strip_edges()
	if _out_dir.is_empty():
		_out_dir = ProjectSettings.globalize_path("res://sandbox/hub_art_lab/captures/loco_audit")
	elif _out_dir.begins_with("res://"):
		_out_dir = ProjectSettings.globalize_path(_out_dir)


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _grab_cropped_tile(cam_mode: int, zoom_mult: float, dir_idx: int, phase_deg: float, tile_size: Vector2i) -> Image:
	_lab.recenter_player()
	_lab.set_camera_mode(cam_mode)
	_lab.set("_cam_zoom_mult", zoom_mult)
	_lab.set("_treadmill_dir_idx", dir_idx)
	_lab._on_scrub_deg_changed(phase_deg)
	var t_dir: Vector2 = LabScript.DIR_8_VECTORS[clampi(dir_idx, 0, LabScript.DIR_8_VECTORS.size() - 1)]
	_lab.player.set_pose_override(t_dir, 1.0, t_dir, true)
	if _lab.player.rig_avatar != null:
		_lab.player.rig_avatar.set_grounded_manual_scrub(true, deg_to_rad(phase_deg), 1.0)
	_lab._apply_camera_state(true, 0.0)
	await _wait_frames(8)
	_lab._apply_camera_state(true, 0.0)
	await _wait_frames(2)
	await RenderingServer.frame_post_draw
	var full_img: Image = get_viewport().get_texture().get_image()
	if full_img == null or full_img.is_empty():
		return Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)

	var fw: int = full_img.get_width()
	var fh: int = full_img.get_height()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var scale_x: float = float(fw) / maxf(vp_size.x, 1.0)
	var scale_y: float = float(fh) / maxf(vp_size.y, 1.0)
	var target_screen: Vector2 = _lab.camera.unproject_position(_lab.player.global_position + Vector3(0.0, 1.32, 0.0))
	target_screen.x *= scale_x
	target_screen.y *= scale_y
	var cw: int = mini(tile_size.x, fw)
	var ch: int = mini(tile_size.y, fh)
	var cx: int = clampi(int(round(target_screen.x)) - cw / 2, 0, maxi(0, fw - cw))
	var cy: int = clampi(int(round(target_screen.y)) - ch / 2, 0, maxi(0, fh - ch))
	var crop := Image.create(cw, ch, false, full_img.get_format())
	crop.blit_rect(full_img, Rect2i(cx, cy, cw, ch), Vector2i.ZERO)
	if crop.get_format() != Image.FORMAT_RGBA8:
		crop.convert(Image.FORMAT_RGBA8)
	if cw != tile_size.x or ch != tile_size.y:
		crop.resize(tile_size.x, tile_size.y, Image.INTERPOLATE_BILINEAR)
	return crop


func _build_and_save_sheet(filename: String, cols: int, rows: int, tile_size: Vector2i, specs: Array[Dictionary]) -> void:
	var sheet := Image.create(cols * tile_size.x, rows * tile_size.y, false, Image.FORMAT_RGBA8)
	for i: int in range(specs.size()):
		var sp: Dictionary = specs[i]
		var tile: Image = await _grab_cropped_tile(
			int(sp["cam"]), float(sp["zoom"]), int(sp["dir"]), float(sp["deg"]), tile_size
		)
		var col_idx: int = i % cols
		var row_idx: int = i / cols
		sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, tile_size), Vector2i(col_idx * tile_size.x, row_idx * tile_size.y))
	var out_path: String = _out_dir.path_join(filename)
	var err: Error = sheet.save_png(out_path)
	if err == OK:
		print("CAPTURED=", out_path)
	else:
		printerr("CAPTURE_ERR=", out_path, " code=", err)


func _capture_ns_sheet() -> void:
	# Row 0: S (dir 2) at 18°, 95°, 275° | Row 1: N (dir 6) at 18°, 95°, 275°
	var specs: Array[Dictionary] = [
		{"cam": LabScript.CamMode.CLOSEUP_34, "zoom": 1.25, "dir": 2, "deg": 18.0},
		{"cam": LabScript.CamMode.CLOSEUP_34, "zoom": 1.25, "dir": 2, "deg": 95.0},
		{"cam": LabScript.CamMode.CLOSEUP_34, "zoom": 1.25, "dir": 2, "deg": 275.0},
		{"cam": LabScript.CamMode.CLOSEUP_34, "zoom": 1.25, "dir": 6, "deg": 18.0},
		{"cam": LabScript.CamMode.CLOSEUP_34, "zoom": 1.25, "dir": 6, "deg": 95.0},
		{"cam": LabScript.CamMode.CLOSEUP_34, "zoom": 1.25, "dir": 6, "deg": 275.0},
	]
	await _build_and_save_sheet("01_ns_mobility.png", 3, 2, Vector2i(360, 520), specs)


func _capture_diagonals_sheet() -> void:
	# Row 0: NE (7) 95°, 275°; NW (5) 95°, 275° | Row 1: SE (1) 95°, 275°; SW (3) 95°, 275°
	var specs: Array[Dictionary] = [
		{"cam": LabScript.CamMode.CLOSEUP_34, "zoom": 1.25, "dir": 7, "deg": 95.0},
		{"cam": LabScript.CamMode.CLOSEUP_34, "zoom": 1.25, "dir": 7, "deg": 275.0},
		{"cam": LabScript.CamMode.CLOSEUP_34, "zoom": 1.25, "dir": 5, "deg": 95.0},
		{"cam": LabScript.CamMode.CLOSEUP_34, "zoom": 1.25, "dir": 5, "deg": 275.0},
		{"cam": LabScript.CamMode.CLOSEUP_34, "zoom": 1.25, "dir": 1, "deg": 95.0},
		{"cam": LabScript.CamMode.CLOSEUP_34, "zoom": 1.25, "dir": 1, "deg": 275.0},
		{"cam": LabScript.CamMode.CLOSEUP_34, "zoom": 1.25, "dir": 3, "deg": 95.0},
		{"cam": LabScript.CamMode.CLOSEUP_34, "zoom": 1.25, "dir": 3, "deg": 275.0},
	]
	await _build_and_save_sheet("02_diagonals_ne_nw_se_sw.png", 4, 2, Vector2i(360, 520), specs)


func _capture_profile_ew_sheet() -> void:
	# Row 0: E (0) at 18°, 95°, 275° | Row 1: W (4) at 18°, 95°, 275°
	var specs: Array[Dictionary] = [
		{"cam": LabScript.CamMode.SIDE_PROFILE, "zoom": 1.28, "dir": 0, "deg": 18.0},
		{"cam": LabScript.CamMode.SIDE_PROFILE, "zoom": 1.28, "dir": 0, "deg": 95.0},
		{"cam": LabScript.CamMode.SIDE_PROFILE, "zoom": 1.28, "dir": 0, "deg": 275.0},
		{"cam": LabScript.CamMode.SIDE_PROFILE, "zoom": 1.28, "dir": 4, "deg": 18.0},
		{"cam": LabScript.CamMode.SIDE_PROFILE, "zoom": 1.28, "dir": 4, "deg": 95.0},
		{"cam": LabScript.CamMode.SIDE_PROFILE, "zoom": 1.28, "dir": 4, "deg": 275.0},
	]
	await _build_and_save_sheet("03_profile_ew_arms.png", 3, 2, Vector2i(360, 520), specs)
