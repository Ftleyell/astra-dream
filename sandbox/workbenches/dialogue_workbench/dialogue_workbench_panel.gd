class_name DialogueWorkbenchPanel
extends RefCounted
## Constructor del panel lateral de control para DialogueWorkbench.

const UIKitScript = preload("res://sandbox/workbenches/shared/workbench_ui_kit.gd")


static func build(parent: Node, wb: Node) -> Dictionary:
	var ui: Dictionary = UIKitScript.create_panel_layer(
		parent,
		"DIALOGUE WORKBENCH",
		"G: Guías · H: Ocultar panel · Espacio: Skip",
		330.0,
		true,
		80
	)
	var vbox: VBoxContainer = ui["vbox"] as VBoxContainer

	UIKitScript.add_section(vbox, "Vista & Control")
	UIKitScript.add_button_row(vbox, [
		{"text": "Guías [G]", "cb": Callable(wb, "toggle_guides")},
		{"text": "Fondo Cosmos", "cb": Callable(wb, "toggle_cosmos_background")},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "Stop / Skip", "cb": Callable(wb, "stop_active_dialogue")},
		{"text": "← Hub", "cb": Callable(wb, "return_to_hub")},
	])

	UIKitScript.add_section(vbox, "Participantes")
	var pilot_opt: OptionButton = UIKitScript.add_option(
		vbox,
		"Piloto",
		["valentina", "nova", "kira", "selene", "roxy", "echo", "nyx"],
		func(_idx: int, txt: String) -> void:
			wb.set_selected_pilot(txt)
	)
	UIKitScript.add_option(
		vbox,
		"Mascota",
		["mochi", "kuro", "luna", "pip", "cosmo"],
		func(_idx: int, txt: String) -> void:
			wb.set_selected_pet(txt)
	)
	UIKitScript.add_option(
		vbox,
		"Rival",
		["nova", "valentina", "kira", "selene", "roxy", "echo", "nyx"],
		func(_idx: int, txt: String) -> void:
			wb.set_selected_rival(txt)
	)
	UIKitScript.add_option(
		vbox,
		"Navegante",
		["lyra", "caelia", "iris", "vespera", "zephyr"],
		func(_idx: int, txt: String) -> void:
			wb.set_selected_navigator(txt)
	)

	UIKitScript.add_section(vbox, "Inspector de Retratos (.dch)")
	var portrait_opt: OptionButton = UIKitScript.add_option(
		vbox,
		"Retrato",
		["Normal"],
		func(_idx: int, txt: String) -> void:
			wb.set_selected_portrait(txt)
	)
	var portrait_info: Label = UIKitScript.add_readout(vbox, "Texture: -")
	UIKitScript.add_button_row(vbox, [
		{"text": "Izquierda", "cb": func() -> void: wb.preview_selected_portrait("left")},
		{"text": "Derecha", "cb": func() -> void: wb.preview_selected_portrait("right")},
		{"text": "Ambos", "cb": func() -> void: wb.preview_selected_portrait("both")},
	])

	UIKitScript.add_section(vbox, "Escenarios Reales (Producción)")
	UIKitScript.add_button_row(vbox, [
		{"text": "Prólogo Táctico", "cb": func() -> void: wb.trigger_scenario("prologue")},
		{"text": "Salto Rival", "cb": func() -> void: wb.trigger_scenario("rival_jump")},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "Cara a Cara Rival", "cb": func() -> void: wb.trigger_scenario("rival_face")},
		{"text": "Alerta Jefe", "cb": func() -> void: wb.trigger_scenario("boss_alert")},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "Clímax Pacifista", "cb": func() -> void: wb.trigger_scenario("climax_pacifist")},
		{"text": "Clímax Genocida", "cb": func() -> void: wb.trigger_scenario("climax_slayer")},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "Victoria Post-Jefe", "cb": func() -> void: wb.trigger_scenario("victory_pacifist")},
		{"text": "Radio Navegante", "cb": func() -> void: wb.trigger_scenario("navigator_radio")},
	])

	ui["pilot_option"] = pilot_opt
	ui["portrait_option"] = portrait_opt
	ui["portrait_info"] = portrait_info
	return ui
