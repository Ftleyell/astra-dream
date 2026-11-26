class_name TitleScreen
extends Control

## TitleScreen.gd — Boot Preloader de Stela Galactica.
## Carga MainGame (EntryMode.TITLE) en segundo plano sin animación de Singularidad
## para entrar al Cosmos Engine vivo de forma directa y fluida.

const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")

@export var auto_boot_on_ready: bool = true

var _boot_triggered: bool = false
var _is_loading_main: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PauseArbitrator.force_unpause_all()
	Engine.time_scale = 1.0

	if auto_boot_on_ready and get_tree() != null and get_tree().current_scene == self:
		call_deferred("trigger_boot_to_title")


func trigger_boot_to_title() -> void:
	if _boot_triggered or get_tree() == null:
		return
	_boot_triggered = true
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
	if not _is_loading_main or get_tree() == null:
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
