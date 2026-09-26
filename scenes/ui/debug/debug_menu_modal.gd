class_name DebugMenuModal
extends CanvasLayer

## Modal de Depuración y Trampas para el Menú de Despliegue.
## Totalmente navegable con WASD y flechas.
## En los campos de entrada numéricos, [ESPACIO] confirma y fija el valor emulando [ENTER].

signal closed()

@onready var modal_panel: PanelContainer = $CenterContainer/MainPanel
@onready var infinite_hp_check: CheckBox = $CenterContainer/MainPanel/Margin/VBox/CheatsBox/HpCheck
@onready var infinite_credits_check: CheckBox = $CenterContainer/MainPanel/Margin/VBox/CheatsBox/CreditsCheck
@onready var infinite_consumables_check: CheckBox = $CenterContainer/MainPanel/Margin/VBox/CheatsBox/ConsumablesCheck

@onready var subtitle_label: Label = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/TitleBox/SubtitleLabel")
@onready var reset_career_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CareerDebugRow/ResetCareerButton")
@onready var set_bosses_9_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CareerDebugRow/SetBosses9Button")
@onready var simulate_10m_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/PetsDebugRow/Simulate10mButton")
@onready var lock_cosmo_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/PetsDebugRow/LockCosmoButton")
@onready var unlock_iris_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/NavigatorsDebugRow/UnlockIrisButton")
@onready var lock_iris_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/NavigatorsDebugRow/LockIrisButton")
@onready var jump_pacifist_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/NarrativeDebugRow/JumpPacifistButton")
@onready var jump_slayer_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/NarrativeDebugRow/JumpSlayerButton")
@onready var jump_neutral_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/NarrativeDebugRow/JumpNeutralButton")
@onready var spawn_rival_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/NarrativeDebugRow/SpawnRivalButton")

@onready var stats_container: VBoxContainer = $CenterContainer/MainPanel/Margin/VBox/StatsScroll/StatsList
@onready var reset_button: Button = $CenterContainer/MainPanel/Margin/VBox/ActionsRow/ResetButton
@onready var close_button: Button = $CenterContainer/MainPanel/Margin/VBox/ActionsRow/CloseButton

var current_pilot_data: CharacterData = null
var _stat_controls: Dictionary = {} # stat_name -> { "slider": HSlider, "input": LineEdit, "config": Dictionary }
var is_open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	hide()

	if infinite_hp_check:
		infinite_hp_check.toggled.connect(_on_infinite_hp_toggled)
		UIFocusHelper.apply_cyber_focus(infinite_hp_check)

	if infinite_credits_check:
		infinite_credits_check.toggled.connect(_on_infinite_credits_toggled)
		UIFocusHelper.apply_cyber_focus(infinite_credits_check)

	if infinite_consumables_check:
		infinite_consumables_check.toggled.connect(_on_infinite_consumables_toggled)
		UIFocusHelper.apply_cyber_focus(infinite_consumables_check)

	if reset_career_btn:
		reset_career_btn.pressed.connect(_on_reset_career_pressed)
		UIFocusHelper.apply_cyber_focus(reset_career_btn)

	if set_bosses_9_btn:
		set_bosses_9_btn.pressed.connect(_on_set_bosses_9_pressed)
		UIFocusHelper.apply_cyber_focus(set_bosses_9_btn)

	if simulate_10m_btn:
		simulate_10m_btn.pressed.connect(_on_simulate_10m_pressed)
		UIFocusHelper.apply_cyber_focus(simulate_10m_btn)

	if lock_cosmo_btn:
		lock_cosmo_btn.pressed.connect(_on_lock_cosmo_pressed)
		UIFocusHelper.apply_cyber_focus(lock_cosmo_btn)

	if unlock_iris_btn:
		unlock_iris_btn.pressed.connect(_on_unlock_iris_pressed)
		UIFocusHelper.apply_cyber_focus(unlock_iris_btn)

	if lock_iris_btn:
		lock_iris_btn.pressed.connect(_on_lock_iris_pressed)
		UIFocusHelper.apply_cyber_focus(lock_iris_btn)

	if jump_pacifist_btn:
		jump_pacifist_btn.pressed.connect(_on_jump_pacifist_pressed)
		UIFocusHelper.apply_cyber_focus(jump_pacifist_btn)

	if jump_slayer_btn:
		jump_slayer_btn.pressed.connect(_on_jump_slayer_pressed)
		UIFocusHelper.apply_cyber_focus(jump_slayer_btn)

	if jump_neutral_btn:
		jump_neutral_btn.pressed.connect(_on_jump_neutral_pressed)
		UIFocusHelper.apply_cyber_focus(jump_neutral_btn)

	if spawn_rival_btn:
		spawn_rival_btn.pressed.connect(_on_spawn_rival_pressed)
		UIFocusHelper.apply_cyber_focus(spawn_rival_btn)

	if reset_button:
		reset_button.pressed.connect(reset_to_defaults)
		UIFocusHelper.apply_cyber_focus(reset_button)

	if close_button:
		close_button.pressed.connect(close_menu)
		UIFocusHelper.apply_cyber_focus(close_button)

	_build_stats_ui()
	_setup_focus_chain()

func open_menu(pilot_data: CharacterData = null) -> void:
	current_pilot_data = pilot_data
	is_open = true
	show()

	# Cargar estado actual de DebugManager
	if infinite_hp_check:
		infinite_hp_check.set_pressed_no_signal(DebugManager.infinite_hp)
	if infinite_credits_check:
		infinite_credits_check.set_pressed_no_signal(DebugManager.infinite_credits)
	if infinite_consumables_check:
		infinite_consumables_check.set_pressed_no_signal(DebugManager.infinite_consumables)

	_refresh_stats_display()

	if infinite_hp_check:
		infinite_hp_check.grab_focus()

func close_menu() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_menu()
		return
	get_viewport().set_input_as_handled()

func _build_stats_ui() -> void:
	if not stats_container:
		return

	for child in stats_container.get_children():
		child.queue_free()
	_stat_controls.clear()

	for stat_name in DebugManager.STAT_CONFIGS.keys():
		var cfg: Dictionary = DebugManager.STAT_CONFIGS[stat_name]
		var row := HBoxContainer.new()
		row.name = "Row_" + String(stat_name)
		row.custom_minimum_size = Vector2(0, 36)
		row.add_theme_constant_override("separation", 16)

		# 1. Etiqueta con nombre amigable
		var lbl := Label.new()
		lbl.text = cfg.name
		lbl.custom_minimum_size = Vector2(240, 32)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.95))
		row.add_child(lbl)

		# 2. Slider horizontal
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(360, 32)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = cfg.min
		slider.max_value = cfg.max
		slider.step = cfg.step
		slider.value = cfg.default
		UIFocusHelper.apply_cyber_focus(slider)
		row.add_child(slider)

		# 3. Input numérico LineEdit
		var line_edit := LineEdit.new()
		line_edit.custom_minimum_size = Vector2(120, 32)
		line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_edit.text = cfg.format % cfg.default
		UIFocusHelper.apply_cyber_focus(line_edit)
		row.add_child(line_edit)

		# Sincronización Slider -> Input & DebugManager
		slider.value_changed.connect(func(val: float):
			line_edit.text = cfg.format % val
			DebugManager.set_stat_override(stat_name, val)
		)

		# Sincronización Input -> Slider & DebugManager (Enter y Barra Espaciadora)
		line_edit.text_submitted.connect(func(txt: String):
			_commit_input_value(stat_name, line_edit, slider, cfg)
		)

		# Capturar la Barra Espaciadora en el LineEdit para fijar el valor como si fuera Enter
		line_edit.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventKey and ev.pressed and not ev.echo:
				if ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
					_commit_input_value(stat_name, line_edit, slider, cfg)
					get_viewport().set_input_as_handled()
		)

		stats_container.add_child(row)
		_stat_controls[stat_name] = {
			"slider": slider,
			"input": line_edit,
			"config": cfg
		}

func _commit_input_value(stat_name: StringName, line_edit: LineEdit, slider: HSlider, cfg: Dictionary) -> void:
	var clean_text := line_edit.text.strip_edges()
	var val: float = clean_text.to_float()
	val = clampf(val, cfg.min, cfg.max)

	slider.set_value_no_signal(val)
	line_edit.text = cfg.format % val
	DebugManager.set_stat_override(stat_name, val)

	# Feedback sonoro sutil
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.5, 1.4)

	# Destello visual en el LineEdit para confirmar la fijación del valor
	var tw := create_tween()
	tw.tween_property(line_edit, "modulate", Color(0.2, 1.0, 0.4, 1.0), 0.08)
	tw.tween_property(line_edit, "modulate", Color.WHITE, 0.15)

func _refresh_stats_display() -> void:
	for stat_name in _stat_controls.keys():
		var ctrl: Dictionary = _stat_controls[stat_name]
		var slider: HSlider = ctrl.slider
		var input: LineEdit = ctrl.input
		var cfg: Dictionary = ctrl.config

		var default_val: float = cfg.default
		if current_pilot_data and stat_name in current_pilot_data:
			default_val = float(current_pilot_data.get(stat_name))

		var current_val: float = DebugManager.get_stat_override(stat_name, default_val)
		slider.set_value_no_signal(current_val)
		input.text = cfg.format % current_val

func _setup_focus_chain() -> void:
	# Enlace de navegación WASD completo entre Toggles, Sliders, Inputs y Botones
	if infinite_hp_check and infinite_credits_check and infinite_consumables_check:
		infinite_hp_check.focus_neighbor_right = infinite_credits_check.get_path()
		infinite_credits_check.focus_neighbor_left = infinite_hp_check.get_path()
		infinite_credits_check.focus_neighbor_right = infinite_consumables_check.get_path()
		infinite_consumables_check.focus_neighbor_left = infinite_credits_check.get_path()

	var stat_keys := _stat_controls.keys()
	if stat_keys.is_empty():
		return

	var first_stat: StringName = stat_keys[0]
	var last_stat: StringName = stat_keys[-1]
	var first_ctrl: Dictionary = _stat_controls[first_stat]
	var last_ctrl: Dictionary = _stat_controls[last_stat]

	if infinite_hp_check:
		infinite_hp_check.focus_neighbor_bottom = first_ctrl.slider.get_path()
	if infinite_credits_check:
		infinite_credits_check.focus_neighbor_bottom = first_ctrl.slider.get_path()
	if infinite_consumables_check:
		infinite_consumables_check.focus_neighbor_bottom = first_ctrl.input.get_path()

	for i in range(stat_keys.size()):
		var s_name: StringName = stat_keys[i]
		var ctrl: Dictionary = _stat_controls[s_name]
		var slider: HSlider = ctrl.slider
		var input: LineEdit = ctrl.input

		# Izquierda / Derecha dentro de la fila
		slider.focus_neighbor_right = input.get_path()
		input.focus_neighbor_left = slider.get_path()

		# Arriba
		if i > 0:
			var prev_ctrl: Dictionary = _stat_controls[stat_keys[i - 1]]
			slider.focus_neighbor_top = prev_ctrl.slider.get_path()
			input.focus_neighbor_top = prev_ctrl.input.get_path()
		else:
			slider.focus_neighbor_top = infinite_hp_check.get_path()
			input.focus_neighbor_top = infinite_consumables_check.get_path()

		# Abajo
		if i < stat_keys.size() - 1:
			var next_ctrl: Dictionary = _stat_controls[stat_keys[i + 1]]
			slider.focus_neighbor_bottom = next_ctrl.slider.get_path()
			input.focus_neighbor_bottom = next_ctrl.input.get_path()
		else:
			if reset_career_btn:
				slider.focus_neighbor_bottom = reset_career_btn.get_path()
			else:
				slider.focus_neighbor_bottom = reset_button.get_path()
			if set_bosses_9_btn:
				input.focus_neighbor_bottom = set_bosses_9_btn.get_path()
			else:
				input.focus_neighbor_bottom = close_button.get_path()

	if reset_career_btn and set_bosses_9_btn:
		reset_career_btn.focus_neighbor_top = last_ctrl.slider.get_path()
		reset_career_btn.focus_neighbor_right = set_bosses_9_btn.get_path()
		reset_career_btn.focus_neighbor_bottom = simulate_10m_btn.get_path() if simulate_10m_btn else reset_button.get_path()
		set_bosses_9_btn.focus_neighbor_top = last_ctrl.input.get_path()
		set_bosses_9_btn.focus_neighbor_left = reset_career_btn.get_path()
		set_bosses_9_btn.focus_neighbor_bottom = lock_cosmo_btn.get_path() if lock_cosmo_btn else close_button.get_path()

	if simulate_10m_btn and lock_cosmo_btn:
		simulate_10m_btn.focus_neighbor_top = reset_career_btn.get_path() if reset_career_btn else last_ctrl.slider.get_path()
		simulate_10m_btn.focus_neighbor_right = lock_cosmo_btn.get_path()
		simulate_10m_btn.focus_neighbor_bottom = reset_button.get_path()
		lock_cosmo_btn.focus_neighbor_top = set_bosses_9_btn.get_path() if set_bosses_9_btn else last_ctrl.input.get_path()
		lock_cosmo_btn.focus_neighbor_left = simulate_10m_btn.get_path()
		lock_cosmo_btn.focus_neighbor_bottom = close_button.get_path()

	if reset_button and close_button:
		if simulate_10m_btn:
			reset_button.focus_neighbor_top = simulate_10m_btn.get_path()
		elif reset_career_btn:
			reset_button.focus_neighbor_top = reset_career_btn.get_path()
		else:
			reset_button.focus_neighbor_top = last_ctrl.slider.get_path()
		reset_button.focus_neighbor_right = close_button.get_path()

		if lock_cosmo_btn:
			close_button.focus_neighbor_top = lock_cosmo_btn.get_path()
		elif set_bosses_9_btn:
			close_button.focus_neighbor_top = set_bosses_9_btn.get_path()
		else:
			close_button.focus_neighbor_top = last_ctrl.input.get_path()
		close_button.focus_neighbor_left = reset_button.get_path()

func _on_simulate_10m_pressed() -> void:
	var cur_scene = get_tree().current_scene
	if cur_scene and "run_time_elapsed" in cur_scene:
		cur_scene.run_time_elapsed = 599.0
	else:
		SaveManager.unlock_pet(&"cosmo")
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.8, 1.0)
	if subtitle_label:
		subtitle_label.text = "✓ 10 MINUTOS SIMULADOS. ¡PET SECRETO COSMO DESBLOQUEADO!"
		subtitle_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 1.0))

func _on_lock_cosmo_pressed() -> void:
	SaveManager.lock_pet(&"cosmo")
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.8, 1.0)
	if subtitle_label:
		subtitle_label.text = "✓ PET COSMO BLOQUEADO (REQUERIRÁ SOBREVIVIR 10 MIN EN COMBATE)."
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4, 1.0))

func _on_unlock_iris_pressed() -> void:
	SaveManager.unlock_navigator(&"iris")
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.8, 1.0)
	if subtitle_label:
		subtitle_label.text = "✓ ¡NAVEGANTE SECRETA IRIS DESBLOQUEADA!"
		subtitle_label.add_theme_color_override("font_color", Color(0.9, 0.75, 1.0, 1.0))

func _on_lock_iris_pressed() -> void:
	SaveManager.lock_navigator(&"iris")
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.8, 1.0)
	if subtitle_label:
		subtitle_label.text = "✓ NAVEGANTE IRIS BLOQUEADA (REQUIERE COMPLETAR UN FINAL)."
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4, 1.0))

func _on_reset_career_pressed() -> void:
	SaveManager.reset_career_stats()
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.8, 1.0)
	if subtitle_label:
		subtitle_label.text = "✓ DATOS DE CARRERA REINICIADOS. NYX BLOQUEADA (0 JEFES MATADOS)."
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.55, 1.0))

func _on_set_bosses_9_pressed() -> void:
	SaveManager.set_career_bosses_killed(9)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.8, 1.0)
	if subtitle_label:
		subtitle_label.text = "✓ JEFES MATADOS FIJADOS A 9. ¡EL PRÓXIMO JEFE DERROTADO DESBLOQUEARÁ A NYX!"
		subtitle_label.add_theme_color_override("font_color", Color(0.9, 0.45, 1.0, 1.0))

func reset_to_defaults() -> void:
	DebugManager.stat_overrides.clear()
	_refresh_stats_display()
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.8, 1.0)

func _on_infinite_hp_toggled(toggled_on: bool) -> void:
	DebugManager.infinite_hp = toggled_on
	if toggled_on:
		DebugManager.is_enabled = true

func _on_infinite_credits_toggled(toggled_on: bool) -> void:
	DebugManager.infinite_credits = toggled_on
	if toggled_on:
		DebugManager.is_enabled = true

func _on_infinite_consumables_toggled(toggled_on: bool) -> void:
	DebugManager.infinite_consumables = toggled_on
	if toggled_on:
		DebugManager.is_enabled = true

func _on_jump_pacifist_pressed() -> void:
	_trigger_route_jump("pacifist")

func _on_jump_slayer_pressed() -> void:
	_trigger_route_jump("slayer")

func _on_jump_neutral_pressed() -> void:
	_trigger_route_jump("neutral")

func _trigger_route_jump(route: String) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.8)

	var mg = get_tree().get_first_node_in_group("main_game")
	if mg and mg.has_method("jump_to_wave_11"):
		mg.jump_to_wave_11(route)
		close_menu()
	else:
		# Si se presiona fuera de combate (Menú Principal, Hangar, etc.), iniciar partida directamente en la última oleada (Wave 11)
		DebugManager.set_pending_debug_route(route)
		close_menu()
		get_tree().paused = false
		if not (get_tree().current_scene and "Test" in get_tree().current_scene.name):
			get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")

func _on_spawn_rival_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.8)

	var mg = get_tree().get_first_node_in_group("main_game")
	if mg and mg.has_method("spawn_next_rival_pilot"):
		mg.spawn_next_rival_pilot()
		close_menu()
	else:
		# Si se presiona fuera de combate, iniciar partida normal (la rival aparecerá en Oleada 1)
		close_menu()
		get_tree().paused = false
		if not (get_tree().current_scene and "Test" in get_tree().current_scene.name):
			get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")
