extends Node

## Herramienta de captura en ventana GPU real (Vulkan / Mobile + AgX + Bloom) para auditar Gacha 3D Lab.
## Uso:
##   Godot --path . --windowed --resolution 1280x720 res://sandbox/hub_art_lab/tools/capture_gacha_3d_lab_views.tscn [-- --out=<abs_dir>]

const LabScene: PackedScene = preload("res://sandbox/hub_art_lab/gacha_3d_lab.tscn")
const LabScript = preload("res://sandbox/hub_art_lab/gacha_3d_lab.gd")
const SessionScript = preload("res://scenes/ui/hub/astral_station/components/gacha_3d_session_controller.gd")

var _out_dir: String = ""
var _lab: LabScript = null


func _ready() -> void:
	_parse_args()
	DirAccess.make_dir_recursive_absolute(_out_dir)

	_lab = LabScene.instantiate() as LabScript
	_lab.name = "Gacha3DLab"
	add_child(_lab)

	await _wait_frames(12)
	await _capture_sequence()


func _parse_args() -> void:
	for raw_arg: String in OS.get_cmdline_user_args():
		if raw_arg.begins_with("--out="):
			_out_dir = raw_arg.trim_prefix("--out=").strip_edges()
	if _out_dir.is_empty():
		_out_dir = ProjectSettings.globalize_path("res://sandbox/hub_art_lab/captures_gacha")
	elif _out_dir.begins_with("res://"):
		_out_dir = ProjectSettings.globalize_path(_out_dir)


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _capture_file(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var full_path: String = _out_dir.path_join(filename)
	if img == null or img.is_empty():
		printerr("CAPTURE_EMPTY=", full_path)
		return
	var err: Error = img.save_png(full_path)
	if err != OK:
		printerr("CAPTURE_ERR=", full_path, " code=", err)
		return
	print("CAPTURED=", full_path)


func _capture_sequence() -> void:
	# 1. Reposo en banner General
	_lab.select_banner("general")
	await _wait_frames(4)
	await _capture_file("01_idle_general.png")

	# 2. Fase de carga & alineación ecuatorial (banner Pilots, tirada épica)
	_lab.select_banner("pilots")
	_lab.request_pull(1, SessionScript.PullOverride.FORCE_EPIC)
	_lab.summoner.step_sequence(0.85)
	_lab._update_camera(0.45)
	await _wait_frames(3)
	await _capture_file("02_charge_alignment.png")

	# 3. Estallido Epic Fake-Out + apertura en flor + núcleo separado
	_lab.close_reveal()
	_lab.select_banner("ships")
	_lab.request_pull(1, SessionScript.PullOverride.FORCE_FAKEOUT)
	_lab.summoner.step_sequence(1.66)
	_lab._update_camera(0.45)
	await _wait_frames(3)
	await _capture_file("03_epic_fakeout_burst.png")

	# 4. Reveal x1 con ShaderSkinLivePreview
	_lab.summoner.step_sequence(0.40)
	_lab._update_camera(0.45)
	await _wait_frames(8)
	await _capture_file("04_reveal_single_preview.png")

	# 5. Reveal Multi x10 con cascada completa y equipamiento en vivo
	_lab.close_reveal()
	_lab.select_banner("pilots")
	_lab.request_pull(10, SessionScript.PullOverride.FORCE_EPIC)
	_lab.summoner.step_sequence(0.25)
	_lab.request_skip()
	await _wait_frames(4)
	_lab.overlay.complete_cascade_instant()
	_lab.equip_selected_reward()
	await _wait_frames(8)
	await _capture_file("05_reveal_multi_10x.png")

	get_tree().quit(0)
