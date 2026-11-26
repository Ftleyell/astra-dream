class_name TitleScreen
extends Control

## TitleScreen.gd — Boot Preloader de Stela Galactica.
## Muestra una estrella semilla serena (GENESIS_IDLE, phase=3) mientras carga MainGame
## en segundo plano sin Big Crunch previo para enlazar directo al Big Bang de nacimiento.

const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")
const SHADER_SINGULARITY: Shader = preload("res://shaders/ui/singularity_transition.gdshader")
const SingularityConfigScript = preload("res://data/ui/singularity_transition_config.gd")
const DEFAULT_SING_CFG: SingularityConfigScript = preload("res://data/ui/default_singularity_transition_config.tres")

@export var auto_boot_on_ready: bool = true

var _boot_triggered: bool = false
var _is_loading_main: bool = false
var _painted_frames: int = 0
var _seed_mat: ShaderMaterial = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PauseArbitrator.force_unpause_all()
	Engine.time_scale = 1.0
	_setup_genesis_seed_backdrop()

	if auto_boot_on_ready and get_tree() != null and get_tree().current_scene == self:
		call_deferred("trigger_boot_to_title")


func _setup_genesis_seed_backdrop() -> void:
	var backdrop: ColorRect = get_node_or_null("VoidBackdrop") as ColorRect
	if backdrop == null:
		return
	_seed_mat = ShaderMaterial.new()
	_seed_mat.shader = SHADER_SINGULARITY
	_seed_mat.set_shader_parameter("phase", 3)
	_seed_mat.set_shader_parameter("progress", 0.0)
	_seed_mat.set_shader_parameter("has_snapshot", false)
	if DEFAULT_SING_CFG != null:
		_seed_mat.set_shader_parameter("singularity_core_radius", DEFAULT_SING_CFG.singularity_core_radius)
		_seed_mat.set_shader_parameter("anamorphic_flare_intensity", DEFAULT_SING_CFG.anamorphic_flare_intensity)
		_seed_mat.set_shader_parameter("core_tint", DEFAULT_SING_CFG.core_tint)
		_seed_mat.set_shader_parameter("shockwave_tint", DEFAULT_SING_CFG.shockwave_tint)
	var vp: Viewport = get_viewport()
	var sz: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(1920.0, 1080.0)
	_seed_mat.set_shader_parameter("aspect_ratio", sz.x / maxf(sz.y, 1.0))
	backdrop.material = _seed_mat


func trigger_boot_to_title() -> void:
	if _boot_triggered or get_tree() == null:
		return
	_boot_triggered = true
	_painted_frames = 0
	RunLaunchRequestScript.request_title_entry()

	var err: Error = ResourceLoader.load_threaded_request(
		RunLaunchRequestScript.MAIN_GAME_SCENE_PATH,
		"",
		false,
		ResourceLoader.CACHE_MODE_REUSE
	)
	if err != OK:
		get_tree().change_scene_to_file(RunLaunchRequestScript.MAIN_GAME_SCENE_PATH)
		return
	_is_loading_main = true


func _process(_delta: float) -> void:
	_painted_frames += 1
	if not _is_loading_main or get_tree() == null:
		return
	if DisplayServer.get_name() != "headless" and _painted_frames < 2:
		return
	var target_path: String = RunLaunchRequestScript.MAIN_GAME_SCENE_PATH
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(target_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_is_loading_main = false
		var packed: PackedScene = ResourceLoader.load_threaded_get(target_path) as PackedScene
		if packed != null:
			get_tree().change_scene_to_packed(packed)
		else:
			get_tree().change_scene_to_file(target_path)
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_is_loading_main = false
		get_tree().change_scene_to_file(target_path)


func is_boot_triggered() -> bool:
	return _boot_triggered
