class_name CharacterSelectWorkbenchPanel
extends RefCounted
## Constructor del panel lateral de control para CharacterSelectWorkbench.

const UIKitScript = preload("res://sandbox/workbenches/shared/workbench_ui_kit.gd")


static func build(parent: Node, wb: Node) -> Dictionary:
	var ui: Dictionary = UIKitScript.create_panel_layer(
		parent,
		"CHAR SELECT WORKBENCH",
		"G: Guías/Bounds · H: Ocultar panel",
		320.0,
		true,
		150
	)
	var vbox: VBoxContainer = ui["vbox"] as VBoxContainer

	UIKitScript.add_section(vbox, "Vistas Rápidas")
	UIKitScript.add_button_row(vbox, [
		{"text": "Hero Picker", "cb": Callable(wb, "open_hero_picker")},
		{"text": "Loadout / Showcase", "cb": Callable(wb, "open_loadout_view")},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "Tab Loadout", "cb": func() -> void: wb.switch_tab_view(0)},
		{"text": "Tab Habilidades", "cb": func() -> void: wb.switch_tab_view(1)},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "Recargar Escena", "cb": Callable(wb, "reload_character_select")},
		{"text": "← Hub", "cb": Callable(wb, "return_to_hub")},
	])

	UIKitScript.add_section(vbox, "Skins Shader Valentina v2")
	var skin_options: Dictionary = wb.get_skin_display_lists()
	var pilot_labels: Array[String] = skin_options.get("pilot_labels", ["base"]) as Array[String]
	var wings_labels: Array[String] = skin_options.get("wings_labels", ["follow_pilot", "base"]) as Array[String]
	var weapon_labels: Array[String] = skin_options.get("weapon_labels", ["follow_pilot", "base"]) as Array[String]

	var pilot_opt: OptionButton = UIKitScript.add_option(
		vbox,
		"Piloto",
		pilot_labels,
		func(idx: int, _txt: String) -> void:
			wb.select_skin_by_index("pilot", idx)
	)
	var wings_opt: OptionButton = UIKitScript.add_option(
		vbox,
		"Alas",
		wings_labels,
		func(idx: int, _txt: String) -> void:
			wb.select_skin_by_index("wings", idx)
	)
	var weapon_opt: OptionButton = UIKitScript.add_option(
		vbox,
		"Arma",
		weapon_labels,
		func(idx: int, _txt: String) -> void:
			wb.select_skin_by_index("weapon", idx)
	)

	UIKitScript.add_section(vbox, "Presets de Save (Sandbox)")
	UIKitScript.add_button_row(vbox, [
		{"text": "Desbloq. Todas ★5", "cb": func() -> void: wb.apply_save_preset("unlock_all")},
		{"text": "Solo Base", "cb": func() -> void: wb.apply_save_preset("base_only")},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "Monedas 9999", "cb": func() -> void: wb.apply_save_preset("rich_wallet")},
		{"text": "Restaurar Snap", "cb": func() -> void: wb.apply_save_preset("restore")},
	])

	UIKitScript.add_section(vbox, "Guías & Bounds [G]")
	UIKitScript.add_button(vbox, "Toggle Guías [G]", Callable(wb, "toggle_guides"))
	var metrics_label: Label = UIKitScript.add_readout(vbox, "Calculando bounds...")

	ui["pilot_opt"] = pilot_opt
	ui["wings_opt"] = wings_opt
	ui["weapon_opt"] = weapon_opt
	ui["metrics_label"] = metrics_label
	return ui
