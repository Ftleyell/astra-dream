extends Node

## Árbitro Central de Pausa del Juego — Astra Dream
## Gestiona el estado global de get_tree().paused mediante una pila de tokens identificados (StringName).
## Garantiza que ningún modal, diálogo o cinemática reanude el juego prematuramente si otro sistema aún lo requiere.

signal pause_state_changed(is_paused: bool, active_reasons: Array[StringName])
signal pause_acquired(reason: StringName)
signal pause_released(reason: StringName)
signal all_pauses_cleared()

static var instance: Node = null

var _active_tokens: Dictionary[StringName, int] = {}

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

func acquire_pause(reason: StringName) -> void:
	if reason == &"":
		reason = &"generic"
	var current_count: int = _active_tokens.get(reason, 0)
	_active_tokens[reason] = current_count + 1

	var tree := get_tree()
	if tree and not tree.paused:
		tree.paused = true

	pause_acquired.emit(reason)
	pause_state_changed.emit(true, get_active_reasons())

func release_pause(reason: StringName) -> void:
	if reason == &"":
		reason = &"generic"
	if not _active_tokens.has(reason):
		return

	var current_count: int = _active_tokens.get(reason, 1)
	if current_count <= 1:
		_active_tokens.erase(reason)
	else:
		_active_tokens[reason] = current_count - 1

	pause_released.emit(reason)

	if _active_tokens.is_empty():
		var tree := get_tree()
		if tree and tree.paused:
			tree.paused = false
		pause_state_changed.emit(false, [])
		all_pauses_cleared.emit()
	else:
		pause_state_changed.emit(true, get_active_reasons())

func force_unpause_all() -> void:
	_active_tokens.clear()
	var tree := get_tree()
	if tree and tree.paused:
		tree.paused = false
	pause_state_changed.emit(false, [])
	all_pauses_cleared.emit()

func is_paused() -> bool:
	return not _active_tokens.is_empty()

func is_reason_active(reason: StringName) -> bool:
	return _active_tokens.has(reason)

func get_active_reasons() -> Array[StringName]:
	var result: Array[StringName] = []
	for k in _active_tokens.keys():
		result.append(k as StringName)
	return result

# ==============================================================================
# FACADE ESTÁTICA PARA USO CONVENIENTE Y DESACOPLADO
# ==============================================================================

static func acquire(reason: StringName) -> void:
	if instance:
		instance.acquire_pause(reason)
	else:
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			tree.paused = true

static func release(reason: StringName) -> void:
	if instance:
		instance.release_pause(reason)
	else:
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			tree.paused = false

static func force_clear() -> void:
	if instance:
		instance.force_unpause_all()
	else:
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			tree.paused = false

static func has_token(reason: StringName) -> bool:
	if instance:
		return instance.is_reason_active(reason)
	return false

static func is_system_paused() -> bool:
	if instance:
		return instance.is_paused()
	var tree := Engine.get_main_loop() as SceneTree
	return tree.paused if tree else false
