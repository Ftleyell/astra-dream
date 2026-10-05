class_name BaseTestSuite
extends Node

## BaseTestSuite — Astra Dream
## Proporciona un entorno determinista para pruebas automatizadas en Godot Headless.
## Garantiza inmunidad ante pausas del SceneTree, watchdog automático y terminación limpia de procesos.

@export var timeout_seconds: float = 6.0

var _watchdog_timer: SceneTreeTimer = null
var _is_finished: bool = false

func _enter_tree() -> void:
	# Asegurar que este nodo se ejecute incluso si el juego o un modal activa get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_start_watchdog()

func _start_watchdog() -> void:
	if timeout_seconds <= 0.0:
		return
	# create_timer(time_sec, process_always=true, process_in_physics=false, ignore_time_scale=true)
	_watchdog_timer = get_tree().create_timer(timeout_seconds, true, false, true)
	_watchdog_timer.timeout.connect(_on_watchdog_timeout)

func _on_watchdog_timeout() -> void:
	if _is_finished:
		return
	_is_finished = true
	printerr("[TEST WATCHDOG TIMEOUT] La suite '%s' no finalizó tras %.1f segundos. Abortando con error..." % [name, timeout_seconds])
	_cleanup_and_quit(1)

func assert_true(condition: bool, failure_message: String = "Assertion failed") -> void:
	if not condition:
		_is_finished = true
		printerr("[ASSERTION FAILURE] %s" % failure_message)
		_cleanup_and_quit(1)

func pass_suite(summary_message: String = "") -> void:
	if _is_finished:
		return
	_is_finished = true
	if not summary_message.is_empty():
		print("[PASS] %s" % summary_message)
	_cleanup_and_quit(0)

func fail_suite(failure_message: String = "") -> void:
	if _is_finished:
		return
	_is_finished = true
	if not failure_message.is_empty():
		printerr("[FAIL] %s" % failure_message)
	_cleanup_and_quit(1)

func _cleanup_and_quit(exit_code: int) -> void:
	var pa = get_node_or_null("/root/PauseArbitrator")
	if pa and pa.has_method("force_unpause_all"):
		pa.force_unpause_all()
	elif "instance" in PauseArbitrator and PauseArbitrator.instance:
		PauseArbitrator.instance.force_unpause_all()
	var tree := get_tree()
	if tree:
		tree.paused = false
		await tree.process_frame
		await tree.process_frame
		tree.quit(exit_code)
