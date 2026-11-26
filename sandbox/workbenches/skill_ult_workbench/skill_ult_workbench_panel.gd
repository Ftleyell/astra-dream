class_name SkillUltWorkbenchPanel
extends RefCounted
## Constructor del panel lateral oficial (WorkbenchUIKit) para SkillUltWorkbench.

const UIKitScript = preload("res://sandbox/workbenches/shared/workbench_ui_kit.gd")


static func build(parent: Node, wb: Node) -> Dictionary:
	var ui: Dictionary = UIKitScript.create_panel_layer(
		parent,
		"SKILL & ULT WORKBENCH",
		"Mantener [R]: Apuntar Sniper · [Q]: Ultimate · [P]: Congelar · [G]: Guías · [H]: Panel",
		340.0,
		true,
		80
	)
	var vbox: VBoxContainer = ui["vbox"] as VBoxContainer
	var skill_cfg: PilotSkillConfig = wb.get_skill_config()
	var ult_cfg: PilotUltimateConfig = wb.get_ultimate_config()

	UIKitScript.add_section(vbox, "Escenario & Navegación")
	UIKitScript.add_button_row(vbox, [
		{"text": "Guías [G]", "cb": Callable(wb, "toggle_guides")},
		{"text": "Fondo Cosmos", "cb": Callable(wb, "toggle_cosmos_background")},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "GameHUD Real", "cb": Callable(wb, "toggle_real_game_hud")},
		{"text": "← Hub", "cb": Callable(wb, "return_to_hub")},
	])
	UIKitScript.add_button(vbox, "Abrir Skill & Ult Studio (Lab I+D)", Callable(wb, "open_skill_ult_studio"))
	UIKitScript.add_option(
		vbox,
		"Resolución",
		["1920x1080", "1280x720", "1600x900", "2560x1080"],
		func(_idx: int, label_str: String) -> void:
			wb.apply_window_preset(label_str)
	)

	UIKitScript.add_section(vbox, "Ejecución & Transporte")
	UIKitScript.add_button_row(vbox, [
		{"text": "[R] Skill Sniper", "cb": Callable(wb, "trigger_skill_demo")},
		{"text": "[Q] Ultimate 12 Alas", "cb": Callable(wb, "trigger_ultimate_demo")},
	])
	UIKitScript.add_button_row(vbox, [
		{"text": "Congelar [P]", "cb": Callable(wb, "toggle_freeze")},
		{"text": "Energía 100%", "cb": Callable(wb, "refill_energy")},
	])
	UIKitScript.add_option(
		vbox,
		"Velocidad",
		["1.0x (Real)", "0.5x (Slow-Mo)", "0.2x (Frame Inspect)"],
		func(idx: int, _lbl: String) -> void:
			var spd: float = 1.0 if idx == 0 else (0.5 if idx == 1 else 0.2)
			wb.set_playback_speed(spd)
	)
	UIKitScript.add_option(
		vbox,
		"Dummies",
		["Enjambre (12)", "Escuadrón Élites (4)", "Jefe Único (1)"],
		func(idx: int, _lbl: String) -> void:
			wb.spawn_scenario(idx)
	)
	var scrub_dict: Dictionary = UIKitScript.add_slider(vbox, "Timeline", 0.0, 1.0, 0.005, 0.0, Callable(wb, "scrub_timeline"))
	ui["scrubber"] = scrub_dict.get("slider")
	UIKitScript.add_check(vbox, "Usar PauseArbitrator real (Time-Stop)", true, Callable(wb, "set_use_pause_arbitrator"))

	UIKitScript.add_section(vbox, "Skill [R] — Sniper de Punto Débil")
	UIKitScript.add_check(vbox, "Usar Arte Dedicado Skill", skill_cfg.use_custom_cutin_art, func(b: bool) -> void:
		skill_cfg.use_custom_cutin_art = b
		wb.notify_config_changed()
	)
	var opt_sk_style: OptionButton = UIKitScript.add_option(
		vbox,
		"Formato [R]",
		["Diagonal 35° (ZZZ)", "Visor Horizontal (HSR)", "Ventana HUD (WuWa)"],
		func(idx: int, _lbl: String) -> void:
			skill_cfg.cutin_style = idx as PilotSkillConfig.SkillCutInStyle
			wb.notify_config_changed()
	)
	opt_sk_style.select(int(skill_cfg.cutin_style))
	UIKitScript.add_slider(vbox, "Pausa [R] (s)", 0.15, 1.60, 0.02, skill_cfg.time_stop_sec, func(v: float) -> void:
		skill_cfg.time_stop_sec = v
		wb.notify_config_changed()
	)
	UIKitScript.add_slider(vbox, "Ancho Haz", 12.0, 120.0, 2.0, skill_cfg.beam_width_px, func(v: float) -> void:
		skill_cfg.beam_width_px = v
		wb.notify_config_changed()
	)

	UIKitScript.add_section(vbox, "Ultimate [Q] — 4 Actos (3D + Sandevistan)")
	UIKitScript.add_slider(vbox, "Vuelta Sandevistan (s)", 0.12, 1.20, 0.02, ult_cfg.sandevistan_sweep_sec, func(v: float) -> void:
		ult_cfg.sandevistan_sweep_sec = v
		ult_cfg.ensure_defaults()
		wb.notify_config_changed()
	)
	UIKitScript.add_slider(vbox, "Radio Órbita (px)", 60.0, 420.0, 5.0, ult_cfg.sandevistan_orbit_radius_px, func(v: float) -> void:
		ult_cfg.sandevistan_orbit_radius_px = v
		wb.notify_config_changed()
	)
	UIKitScript.add_check(vbox, "Escenario 3D Cel-Shaded ON/OFF", ult_cfg.enable_3d_stage, func(b: bool) -> void:
		ult_cfg.enable_3d_stage = b
		wb.notify_config_changed()
	)
	UIKitScript.add_slider(vbox, "FOV Punch 3D (°)", 36.0, 96.0, 1.0, ult_cfg.stage_3d_fov_peak, func(v: float) -> void:
		ult_cfg.stage_3d_fov_peak = v
		wb.notify_config_changed()
	)
	UIKitScript.add_slider(vbox, "Fusión Fondo Arte", 0.04, 0.45, 0.01, ult_cfg.art_bg_key_threshold, func(v: float) -> void:
		ult_cfg.art_bg_key_threshold = v
		wb.notify_config_changed()
	)
	UIKitScript.add_slider(vbox, "Recolor Skin Arte", 0.0, 1.0, 0.02, ult_cfg.art_recolor_strength, func(v: float) -> void:
		ult_cfg.art_recolor_strength = v
		wb.notify_config_changed()
	)
	UIKitScript.add_slider(vbox, "Bonus Single-Target", 0.0, 0.60, 0.02, ult_cfg.single_target_consecutive_bonus, func(v: float) -> void:
		ult_cfg.single_target_consecutive_bonus = v
		wb.notify_config_changed()
	)
	var opt_ult_mode: OptionButton = UIKitScript.add_option(
		vbox,
		"Motor [Q]",
		["ARTE NUEVO (Wallpaper)", "LIVE_BANNER_25D (HD)", "RIG_BATTLE_POSE (18h)"],
		func(idx: int, _lbl: String) -> void:
			ult_cfg.render_mode = idx as PilotUltimateConfig.CutInRenderMode
			wb.notify_config_changed()
	)
	opt_ult_mode.select(int(ult_cfg.render_mode))
	var opt_comp: OptionButton = UIKitScript.add_option(
		vbox,
		"Marco [Q]",
		["Fullscreen Bleed", "Slash Asimétrico (ZZZ)", "Letterbox Widescreen"],
		func(idx: int, _lbl: String) -> void:
			ult_cfg.frame_composition = idx as PilotUltimateConfig.FrameComposition
			wb.notify_config_changed()
	)
	opt_comp.select(int(ult_cfg.frame_composition))
	UIKitScript.add_slider(vbox, "Cut-In (s)", 0.20, 2.00, 0.02, ult_cfg.cutin_phase_sec, func(v: float) -> void:
		ult_cfg.cutin_phase_sec = v
		ult_cfg.ensure_defaults()
		wb.notify_config_changed()
	)
	UIKitScript.add_slider(vbox, "Sakuga B/N (s)", 0.04, 0.50, 0.01, ult_cfg.impact_bw_phase_sec, func(v: float) -> void:
		ult_cfg.impact_bw_phase_sec = v
		ult_cfg.ensure_defaults()
		wb.notify_config_changed()
	)
	UIKitScript.add_slider(vbox, "Fractura (s)", 0.04, 0.50, 0.01, ult_cfg.impact_shatter_phase_sec, func(v: float) -> void:
		ult_cfg.impact_shatter_phase_sec = v
		ult_cfg.ensure_defaults()
		wb.notify_config_changed()
	)
	UIKitScript.add_slider(vbox, "Umbral B/N", 0.08, 0.72, 0.02, ult_cfg.bw_luma_threshold, func(v: float) -> void:
		ult_cfg.bw_luma_threshold = v
		wb.notify_config_changed()
	)
	UIKitScript.add_slider(vbox, "Celdas Voronoi", 6.0, 32.0, 1.0, ult_cfg.shatter_cell_density, func(v: float) -> void:
		ult_cfg.shatter_cell_density = v
		wb.notify_config_changed()
	)
	UIKitScript.add_slider(vbox, "Curva 12 Alas", 0.0, 280.0, 10.0, ult_cfg.blade_arc_curvature_px, func(v: float) -> void:
		ult_cfg.blade_arc_curvature_px = v
		wb.notify_config_changed()
	)

	UIKitScript.add_section(vbox, "HUD Preview & Skins Shader")
	var opt_hud: OptionButton = UIKitScript.add_option(
		vbox,
		"Estilo HUD",
		["Idea 1: WuWa/Genshin Circular", "Idea 2: ZZZ Hex + Decibel", "Idea 3: Cockpit Central"],
		func(idx: int, _lbl: String) -> void:
			wb.set_hud_preview_style(idx)
	)
	opt_hud.select(0)

	var skin_labels: Array[String] = wb.get_skin_labels()
	if not skin_labels.is_empty():
		UIKitScript.add_option(
			vbox,
			"Skin Piloto",
			skin_labels,
			func(idx: int, _lbl: String) -> void:
				wb.apply_skin_by_index(idx)
		)

	UIKitScript.add_section(vbox, "Persistencia .tres (Single Source)")
	UIKitScript.add_button_row(vbox, [
		{"text": "Guardar .tres", "cb": Callable(wb, "save_configs_to_disk")},
		{"text": "Recargar .tres", "cb": Callable(wb, "reload_configs_from_disk")},
	])

	UIKitScript.add_section(vbox, "Telemetría en Vivo")
	var metrics_lbl: Label = UIKitScript.add_readout(vbox, "Fase: IDLE | PauseArbitrator: FREE")
	ui["metrics_label"] = metrics_lbl

	return ui
