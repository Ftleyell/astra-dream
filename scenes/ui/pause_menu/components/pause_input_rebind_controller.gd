class_name PauseInputRebindController
extends RefCounted

## PauseInputRebindController — Astra Dream
## Controlador desacoplado de mapeo de controles y reasignación de teclas (InputRebind).
## Gestiona la captura de eventos, preservación de gamepad y persistencia en SettingsManager.

static var ACTIONS_TO_REBIND: Array[Dictionary] = [
	{ "action": &"move_up", "label": "Mover Arriba" },
	{ "action": &"move_down", "label": "Mover Abajo" },
	{ "action": &"move_left", "label": "Mover Izquierda" },
	{ "action": &"move_right", "label": "Mover Derecha" },
	{ "action": &"fire_active", "label": "Disparo Activo (Láser)" },
	{ "action": &"toggle_aim_mode", "label": "Alternar Apuntado Pasivo (Auto/Manual)" },
	{ "action": &"dash", "label": "Dash (Invulnerabilidad)" },
	{ "action": &"bomb", "label": "Bomba de Pantalla" },
	{ "action": &"dialogue_skip", "label": "Saltar Diálogo" }
]

static func get_action_key_text(act: StringName) -> String:
	var events := InputMap.action_get_events(act)
	for ev in events:
		if ev is InputEventKey:
			return ev.as_text_physical_keycode() if ev.physical_keycode != 0 else ev.as_text_keycode()
		elif ev is InputEventMouseButton:
			match ev.button_index:
				MOUSE_BUTTON_LEFT: return "Clic Izquierdo"
				MOUSE_BUTTON_RIGHT: return "Clic Derecho"
				MOUSE_BUTTON_MIDDLE: return "Clic Central"
				_: return "Ratón %d" % ev.button_index
	return "No asignado"

static func apply_rebind(rebind_action: StringName, new_event: InputEvent) -> void:
	if rebind_action == &"":
		return

	# Preservar eventos de mando existentes
	var old_events := InputMap.action_get_events(rebind_action)
	var preserved_events: Array[InputEvent] = []
	for ev in old_events:
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			preserved_events.append(ev)

	InputMap.action_erase_events(rebind_action)
	for ev in preserved_events:
		InputMap.action_add_event(rebind_action, ev)

	InputMap.action_add_event(rebind_action, new_event)

	var mgr = Engine.get_main_loop().root.get_node_or_null("/root/SettingsManager") if Engine.get_main_loop() else null
	if mgr and mgr.has_method("save_keybinding"):
		mgr.save_keybinding(rebind_action, new_event)
