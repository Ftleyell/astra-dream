class_name CombatGymPanel
extends RefCounted
## Constructor del panel lateral interactivo para CombatGym.

const UIKitScript = preload("res://sandbox/workbenches/shared/workbench_ui_kit.gd")


static func build(parent: Node, gym: Node) -> Dictionary:
	var ui: Dictionary = UIKitScript.create_panel_layer(
		parent,
		"COMBAT GYM",
		"WASD: Volar · Mouse: Apuntar · F9/H: Panel · G: Guías",
		335.0,
		true,
		80
	)
	var vbox: VBoxContainer = ui["vbox"] as VBoxContainer

	UIKitScript.add_section(vbox, "Armamento (1–4 Slots)")
	UIKitScript.add_button_row(vbox, [
		{"text": "1", "cb": func() -> void: gym.set_weapon_count(1)},
		{"text": "2", "cb": func() -> void: gym.set_weapon_count(2)},
		{"text": "3", "cb": func() -> void: gym.set_weapon_count(3)},
		{"text": "4", "cb": func() -> void: gym.set_weapon_count(4)},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "Rotar Catálogo", "cb": Callable(gym, "rotate_weapon_catalog")},
		{"text": "Aim Auto/Man", "cb": Callable(gym, "toggle_aim_mode")},
	])

	UIKitScript.add_section(vbox, "Equidistancia & Salud")
	UIKitScript.add_button_row(vbox, [
		{"text": "-20 HP", "cb": func() -> void: gym.apply_damage_test(20.0)},
		{"text": "Curar 100%", "cb": Callable(gym, "heal_full")},
		{"text": "Escudo +50", "cb": func() -> void: gym.add_shield_test(50.0)},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "Probar OSP", "cb": Callable(gym, "trigger_osp_test")},
		{"text": "Guías Radiales [G]", "cb": Callable(gym, "toggle_guides")},
	])
	UIKitScript.add_check(vbox, "Mostrar OverheadHealthBar", true, Callable(gym, "set_overhead_bar_visible"))
	var ring_metrics_label: Label = UIKitScript.add_readout(vbox, "Radios: calculando...")

	UIKitScript.add_section(vbox, "Skins Valentina v2 & VFX")
	var skin_lists: Dictionary = gym.get_skin_display_lists()
	UIKitScript.add_option(
		vbox,
		"Piloto",
		skin_lists.get("pilot_labels", ["Base (Original)"]) as Array[String],
		func(idx: int, _txt: String) -> void:
			gym.select_skin_by_index("pilot", idx)
	)
	UIKitScript.add_option(
		vbox,
		"Alas",
		skin_lists.get("wings_labels", ["Seguir Piloto", "Base (Original)"]) as Array[String],
		func(idx: int, _txt: String) -> void:
			gym.select_skin_by_index("wings", idx)
	)
	UIKitScript.add_option(
		vbox,
		"Arma",
		skin_lists.get("weapon_labels", ["Seguir Piloto", "Base (Original)"]) as Array[String],
		func(idx: int, _txt: String) -> void:
			gym.select_skin_by_index("weapon", idx)
	)
	UIKitScript.add_button_row(vbox, [
		{"text": "Recargar Dash", "cb": Callable(gym, "refill_dash_and_bombs")},
		{"text": "Overfocus Sim", "cb": Callable(gym, "toggle_simulated_overfocus")},
	])

	UIKitScript.add_section(vbox, "Escenario, Cámara & Tiempo")
	UIKitScript.add_button_row(vbox, [
		{"text": "Dummy x1", "cb": func() -> void: gym.spawn_dummies(1)},
		{"text": "Dummies x3", "cb": func() -> void: gym.spawn_dummies(3)},
		{"text": "Limpiar", "cb": Callable(gym, "clear_dummies")},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "1.0x", "cb": func() -> void: gym.set_camera_zoom(1.0)},
		{"text": "1.5x", "cb": func() -> void: gym.set_camera_zoom(1.5)},
		{"text": "2.2x", "cb": func() -> void: gym.set_camera_zoom(2.2)},
		{"text": "3.0x", "cb": func() -> void: gym.set_camera_zoom(3.0)},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "TS 1.0", "cb": func() -> void: gym.set_gym_time_scale(1.0)},
		{"text": "0.5", "cb": func() -> void: gym.set_gym_time_scale(0.5)},
		{"text": "0.25", "cb": func() -> void: gym.set_gym_time_scale(0.25)},
		{"text": "0.1", "cb": func() -> void: gym.set_gym_time_scale(0.1)},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "Toggle Pausa", "cb": Callable(gym, "toggle_gym_pause")},
		{"text": "Toggle HUD", "cb": Callable(gym, "toggle_hud_visible")},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "Diál. Prólogo", "cb": func() -> void: gym.trigger_dialogue_preview("prologue")},
		{"text": "Diál. Rival", "cb": func() -> void: gym.trigger_dialogue_preview("rival_face")},
		{"text": "Skip Diál.", "cb": Callable(gym, "stop_active_dialogue")},
	])
	UIKitScript.add_button(vbox, "← Volver al Workbench Hub", Callable(gym, "return_to_hub"))

	ui["ring_metrics_label"] = ring_metrics_label
	return ui
