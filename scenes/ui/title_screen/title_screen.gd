class_name TitleScreen
extends Control

## TitleScreen.gd — Boot Preloader de Stela Galactica.
## Dispara la carga en segundo plano de MainGame (EntryMode.TITLE) envuelta en la
## Transición Singularidad para entrar directamente al Cosmos Engine vivo sin congelamientos.

const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")

@export var auto_boot_on_ready: bool = true

var _boot_triggered: bool = false


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
	RunLaunchRequestScript.transition_to_title(get_tree())


func is_boot_triggered() -> bool:
	return _boot_triggered
