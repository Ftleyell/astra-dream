class_name HubInputDispatcher
extends RefCounted

## HubInputDispatcher.gd
## Manejador desacoplado de atajos y eventos de teclado no manejados para HubWorld:
## - Manejo de ESC para modales (terminales, sala de trofeos, árbol de talentos, settings).
## - Manejo de atajos directos (Q para salir/volver al menú principal).

static func handle_unhandled_input(
	event: InputEvent,
	hub: HubWorld
) -> bool:
	if not is_instance_valid(hub):
		return false

	if hub._is_modal_active():
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
			if hub.terminal_manager and hub.terminal_manager.handle_esc_input():
				hub.get_viewport().set_input_as_handled()
				return true
			if hub.trophy_manager and hub.trophy_manager.is_modal_active():
				hub.trophy_manager.close_modal()
				hub.get_viewport().set_input_as_handled()
				return true
			if hub.skill_tree_modal and hub.skill_tree_modal.visible:
				if hub.skill_tree_modal.has_method("close_modal"):
					hub.skill_tree_modal.close_modal()
				else:
					hub.skill_tree_modal.visible = false
					hub._on_skill_tree_closed()
				hub.get_viewport().set_input_as_handled()
				return true
		return false

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				hub._open_settings()
				hub.get_viewport().set_input_as_handled()
				return true
			KEY_Q:
				hub._quit_game()
				hub.get_viewport().set_input_as_handled()
				return true

	return false
