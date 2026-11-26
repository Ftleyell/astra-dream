class_name SingularityTransitionPresenter
extends CanvasLayer

## Transición cinemática Singularidad en 3 fases:
## 1) Big Crunch: contracción gravitacional del viewport a un punto blanco.
## 2) Singularity Hold: punto blanco incandescente vivo + partículas radiales (sin texto ni barras)
##    mientras corre una carga asíncrona (ResourceLoader.load_threaded_request) o callback.
## 3) Big Bang: onda expansiva refractiva que revela la nueva escena/Cosmos desde el centro.

signal crunch_completed()
signal big_bang_started()
signal transition_finished()

const SHADER_SINGULARITY: Shader = preload("res://shaders/ui/singularity_transition.gdshader")
const ConfigScript = preload("res://data/ui/singularity_transition_config.gd")
const DEFAULT_CONFIG: ConfigScript = preload("res://data/ui/default_singularity_transition_config.tres")

enum Phase {
	CRUNCH = 0,
	HOLD = 1,
	BIG_BANG = 2,
}

@export var config: ConfigScript = DEFAULT_CONFIG

var _overlay: ColorRect = null
var _mat: ShaderMaterial = null
var _is_running: bool = false
var _fallback_tex: ImageTexture = null


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	if config == null:
		config = DEFAULT_CONFIG
	_ensure_overlay()


func _ensure_overlay() -> void:
	if _overlay != null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER_SINGULARITY
	_apply_config_uniforms()

	_overlay = ColorRect.new()
	_overlay.name = "SingularityOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.material = _mat
	_overlay.visible = false
	add_child(_overlay)


func apply_config(p_cfg: ConfigScript) -> void:
	if p_cfg != null:
		config = p_cfg
	_apply_config_uniforms()


func _apply_config_uniforms() -> void:
	if _mat == null or config == null:
		return
	_mat.set_shader_parameter("swirl_strength", config.swirl_strength)
	_mat.set_shader_parameter("chromatic_aberration", config.chromatic_aberration)
	_mat.set_shader_parameter("singularity_core_radius", config.singularity_core_radius)
	_mat.set_shader_parameter("anamorphic_flare_intensity", config.anamorphic_flare_intensity)
	_mat.set_shader_parameter("shockwave_refraction", config.shockwave_refraction)
	_mat.set_shader_parameter("particle_density", config.particle_density)
	_mat.set_shader_parameter("core_tint", config.core_tint)
	_mat.set_shader_parameter("shockwave_tint", config.shockwave_tint)


func is_transition_active() -> bool:
	return _is_running


func _capture_viewport_snapshot() -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return _get_fallback_texture()
	var vp: Viewport = get_viewport()
	if vp == null:
		return _get_fallback_texture()
	var vp_tex: Texture2D = vp.get_texture()
	if vp_tex == null:
		return _get_fallback_texture()
	var img: Image = vp_tex.get_image()
	if img == null or img.is_empty():
		return _get_fallback_texture()
	return ImageTexture.create_from_image(img)


func _get_fallback_texture() -> ImageTexture:
	if _fallback_tex != null:
		return _fallback_tex
	var img: Image = Image.create(64, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.04, 0.05, 0.12, 1.0))
	_fallback_tex = ImageTexture.create_from_image(img)
	return _fallback_tex


func _update_aspect_ratio() -> void:
	if _mat == null:
		return
	var sz: Vector2 = get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1920.0, 1080.0)
	var aspect: float = sz.x / maxf(sz.y, 1.0)
	_mat.set_shader_parameter("aspect_ratio", aspect)


func play_custom_transition(on_collapsed_callback: Callable = Callable(), min_hold_override: float = -1.0) -> void:
	if _is_running:
		return
	_is_running = true
	if config == null:
		config = DEFAULT_CONFIG
	_ensure_overlay()
	_apply_config_uniforms()
	_update_aspect_ratio()

	var snap: Texture2D = _capture_viewport_snapshot()
	_mat.set_shader_parameter("snapshot_tex", snap)
	_mat.set_shader_parameter("has_snapshot", snap != null)
	_mat.set_shader_parameter("phase", Phase.CRUNCH)
	_mat.set_shader_parameter("progress", 0.0)

	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = true

	# Fase 0: Big Crunch
	var crunch_dur: float = maxf(config.crunch_duration_sec, 0.05)
	var tw_crunch: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_crunch.tween_method(
		func(v: float) -> void:
			if _mat != null:
				_mat.set_shader_parameter("progress", v),
		0.0,
		1.0,
		crunch_dur
	)
	await tw_crunch.finished

	if not is_inside_tree():
		_finish_cleanup()
		return

	# Fase 1: Singularity Hold
	_mat.set_shader_parameter("phase", Phase.HOLD)
	_mat.set_shader_parameter("progress", 0.0)
	crunch_completed.emit()

	var start_msec: int = Time.get_ticks_msec()
	var min_hold: float = min_hold_override if min_hold_override >= 0.0 else config.min_singularity_hold_sec

	if on_collapsed_callback.is_valid():
		await on_collapsed_callback.call()

	var elapsed_sec: float = float(Time.get_ticks_msec() - start_msec) / 1000.0
	var remaining: float = maxf(0.0, min_hold - elapsed_sec)
	if remaining > 0.005 and is_inside_tree():
		await get_tree().create_timer(remaining, true, false, true).timeout

	if not is_inside_tree():
		_finish_cleanup()
		return

	await get_tree().process_frame
	await get_tree().process_frame

	# Fase 2: Big Bang
	_mat.set_shader_parameter("phase", Phase.BIG_BANG)
	_mat.set_shader_parameter("progress", 0.0)
	big_bang_started.emit()

	var bang_dur: float = maxf(config.big_bang_duration_sec, 0.05)
	var tw_bang: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_bang.tween_method(
		func(v: float) -> void:
			if _mat != null:
				_mat.set_shader_parameter("progress", v),
		0.0,
		1.0,
		bang_dur
	)
	await tw_bang.finished

	_finish_cleanup()


func change_scene_threaded(target_scene_path: String) -> void:
	if _is_running or target_scene_path.is_empty():
		return
	await play_custom_transition(func() -> void:
		var req_err: Error = ResourceLoader.load_threaded_request(target_scene_path, "", false, ResourceLoader.CACHE_MODE_REUSE)
		if req_err != OK:
			get_tree().change_scene_to_file(target_scene_path)
			return
		while is_inside_tree():
			var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(target_scene_path)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				var packed: PackedScene = ResourceLoader.load_threaded_get(target_scene_path) as PackedScene
				if packed != null:
					get_tree().change_scene_to_packed(packed)
				else:
					get_tree().change_scene_to_file(target_scene_path)
				return
			elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				get_tree().change_scene_to_file(target_scene_path)
				return
			await get_tree().process_frame
	)


func _finish_cleanup() -> void:
	if _overlay != null:
		_overlay.visible = false
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_running = false
	transition_finished.emit()
