class_name HUDWorkbenchPanel
extends RefCounted
## Constructor del panel lateral de control para HUDWorkbench.

const UIKitScript = preload("res://sandbox/workbenches/shared/workbench_ui_kit.gd")


static func build(parent: Node, wb: Node) -> Dictionary:
	var ui: Dictionary = UIKitScript.create_panel_layer(
		parent,
		"HUD WORKBENCH",
		"G: Guías/Equidistancia · H: Ocultar panel",
		330.0,
		true,
		80
	)
	var vbox: VBoxContainer = ui["vbox"] as VBoxContainer

	UIKitScript.add_section(vbox, "Vista & Guías")
	UIKitScript.add_button_row(vbox, [
		{"text": "Guías [G]", "cb": Callable(wb, "toggle_guides")},
		{"text": "Fondo Cosmos", "cb": Callable(wb, "toggle_cosmos_background")},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "Recargar HUD", "cb": Callable(wb, "reload_hud")},
		{"text": "← Hub", "cb": Callable(wb, "return_to_hub")},
	])
	UIKitScript.add_option(
		vbox,
		"Resolución",
		["1920x1080", "1280x720", "1600x900", "2560x1080"],
		func(_idx: int, label_str: String) -> void:
			wb.apply_window_preset(label_str)
	)

	UIKitScript.add_section(vbox, "Armas (0–4 Slots)")
	UIKitScript.add_button_row(vbox, [
		{"text": "0", "cb": func() -> void: wb.set_weapon_count(0)},
		{"text": "1", "cb": func() -> void: wb.set_weapon_count(1)},
		{"text": "2", "cb": func() -> void: wb.set_weapon_count(2)},
		{"text": "3", "cb": func() -> void: wb.set_weapon_count(3)},
		{"text": "4", "cb": func() -> void: wb.set_weapon_count(4)},
	])
	UIKitScript.add_button(vbox, "Rotar Armas del Catálogo", Callable(wb, "rotate_weapon_catalog"))
	UIKitScript.add_check(vbox, "Simular Cooldowns en Vivo", false, Callable(wb, "set_simulate_cooldowns"))

	UIKitScript.add_section(vbox, "Salud, Escudo & Nivel")
	UIKitScript.add_slider(vbox, "HP %", 0.0, 100.0, 1.0, 100.0, Callable(wb, "set_health_percent"))
	UIKitScript.add_slider(vbox, "Escudo", 0.0, 100.0, 1.0, 25.0, Callable(wb, "set_shield_amount"))
	UIKitScript.add_slider(vbox, "EXP %", 0.0, 100.0, 1.0, 40.0, Callable(wb, "set_exp_percent"))
	UIKitScript.add_button_row(vbox, [
		{"text": "Flash OSP", "cb": Callable(wb, "trigger_osp_preview")},
		{"text": "Nivel +1", "cb": Callable(wb, "increment_level")},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "Bomba -1", "cb": func() -> void: wb.step_bombs(-1)},
		{"text": "Bombas Full", "cb": func() -> void: wb.step_bombs(5)},
		{"text": "Laser 50%", "cb": func() -> void: wb.set_laser_cd_preview(0.5)},
		{"text": "Laser 0%", "cb": func() -> void: wb.set_laser_cd_preview(0.0)},
	])

	UIKitScript.add_section(vbox, "Economía & Encuentros")
	UIKitScript.add_button_row(vbox, [
		{"text": "+250 Créd", "cb": func() -> void: wb.add_credits_preview(250)},
		{"text": "+50 Bio", "cb": func() -> void: wb.add_biomass_preview(50)},
		{"text": "+1 Llave", "cb": func() -> void: wb.add_key_preview(1)},
	])
	var boss_toggle_ref: Array[bool] = [false]
	var toggle_boss_cb: Callable = func() -> void:
		boss_toggle_ref[0] = not boss_toggle_ref[0]
		wb.set_boss_bar_visible(boss_toggle_ref[0], 0.72)
	UIKitScript.add_button_row(vbox, [
		{"text": "Toggle Boss Bar", "cb": toggle_boss_cb},
		{"text": "Alerta Táctica", "cb": Callable(wb, "trigger_tactical_alert_preview")},
	])
	UIKitScript.add_slider(vbox, "Boss HP %", 0.0, 100.0, 1.0, 72.0, func(v: float) -> void:
		wb.set_boss_bar_visible(true, v / 100.0)
	)
	UIKitScript.add_button(vbox, "Banner Satélite", Callable(wb, "trigger_satellite_banner_preview"))

	UIKitScript.add_section(vbox, "Telemetría de Layout")
	var metrics_label: Label = UIKitScript.add_readout(vbox, "Calculando bounds...")
	ui["metrics_label"] = metrics_label
	return ui
