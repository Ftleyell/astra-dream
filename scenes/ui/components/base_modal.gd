class_name BaseModal
extends CanvasLayer

## BaseModal.gd — Astra Dream
## Clase base estándar para todos los modales de decisión y menús interactivos del juego.
## Unifica el ciclo de vida, la integración transparente con PauseArbitrator y la sincronización con el CombatStatsDock del HUD.

signal opened()
signal closed()

@export var modal_token: StringName = &"generic_modal"
@export var auto_pause: bool = true
@export var sync_hud_stats: bool = true
@export var mouse_grace_period: float = 0.25

var _mouse_lockout_active: bool = false
var _is_modal_open: bool = false

func _enter_tree() -> void:
	# Los modales deben responder siempre a entradas de usuario incluso con el juego pausado
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if not _is_modal_open:
		hide()

func _on_visibility_changed() -> void:
	if not visible and _is_modal_open:
		close_modal()

func open_modal() -> void:
	if _is_modal_open and visible:
		return
	_is_modal_open = true
	_mouse_lockout_active = true

	if auto_pause:
		PauseArbitrator.acquire_pause(modal_token)

	if sync_hud_stats:
		_notify_hud_stats_dock(true)

	show()
	opened.emit()

	if mouse_grace_period > 0.0:
		get_tree().create_timer(mouse_grace_period, true, false, true).timeout.connect(func():
			_mouse_lockout_active = false
		)
	else:
		_mouse_lockout_active = false

func close_modal() -> void:
	if not _is_modal_open and not visible:
		return
	_is_modal_open = false

	if auto_pause:
		PauseArbitrator.release_pause(modal_token)

	if sync_hud_stats:
		_notify_hud_stats_dock(false)

	hide()
	closed.emit()

func is_modal_open() -> bool:
	return _is_modal_open or visible

func is_mouse_locked() -> bool:
	return _mouse_lockout_active

func _notify_hud_stats_dock(active: bool) -> void:
	var hud_node: Node = get_tree().get_first_node_in_group("hud") if get_tree() else null
	if not hud_node:
		var parent_node = get_parent()
		if parent_node and "hud" in parent_node and is_instance_valid(parent_node.hud):
			hud_node = parent_node.hud
	if hud_node and hud_node.has_method("set_stats_dock_requested"):
		hud_node.set_stats_dock_requested(modal_token, active)

func _get_hud_stats_dock() -> Node:
	var hud_node: Node = get_tree().get_first_node_in_group("hud") if get_tree() else null
	if not hud_node:
		var parent_node = get_parent()
		if parent_node and "hud" in parent_node and is_instance_valid(parent_node.hud):
			hud_node = parent_node.hud
	if hud_node and "combat_stats_dock" in hud_node and is_instance_valid(hud_node.combat_stats_dock):
		return hud_node.combat_stats_dock
	return null
