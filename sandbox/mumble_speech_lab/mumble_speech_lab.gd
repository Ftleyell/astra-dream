extends Control

## Laboratorio interactivo de Mumble Speech (enfoque híbrido data-driven).
## Permite probar perfiles .tres de pilotos/mascotas, ajustar parámetros en vivo,
## alternar el filtro de radio y guardar cambios en los .tres.

const VoiceProfileDataScript = preload("res://data/voices/voice_profile_data.gd")
const VoiceProfileRegistryScript = preload("res://data/voices/voice_profile_registry.gd")
const MumbleSpeechControllerScript = preload("res://core/audio/mumble_speech_controller.gd")

var _profile_paths: Array[String] = []

const SAMPLE_LINES: Array[Dictionary] = [
	{
		"label": "Afirmación",
		"text": "Motores estables. Entrando en el corredor orbital, mantengan formación."
	},
	{
		"label": "Pregunta (?)",
		"text": "¿Seguro que ese satélite es aliado? Sus escudos están cargando demasiado rápido..."
	},
	{
		"label": "Exclamación (!)",
		"text": "¡Cuidado a estribor! ¡Lluvia de micro-meteoros a doce grados!"
	},
	{
		"label": "Radio Rival",
		"text": "Aquí espectro-cero. No deberían haber cruzado este sector, pilotos."
	},
	{
		"label": "Mascota Feliz",
		"text": "¡Mochi detecta polvo estelar brillante! ¿Podemos ir a recogerlo ahora?"
	},
]

var _controller: MumbleSpeechControllerScript = null
var _profiles: Array[VoiceProfileDataScript] = []
var _active_profile_index: int = 0
var _active_profile: VoiceProfileDataScript = null

var _is_typing: bool = false
var _full_text: String = ""
var _revealed_count: int = 0
var _char_accumulator: float = 0.0
var _chars_per_sec: float = 38.0

# UI refs
var _profile_option: OptionButton = null
var _preset_option: OptionButton = null
var _text_edit: TextEdit = null
var _speaker_label: Label = null
var _dialogue_label: RichTextLabel = null
var _telemetry_label: Label = null
var _status_label: Label = null
var _radio_check: CheckButton = null
var _speed_slider: HSlider = null
var _speed_value_label: Label = null
var _sliders: Dictionary = {}
var _slider_labels: Dictionary = {}
var _syncing_ui: bool = false


func _ready() -> void:
	_controller = MumbleSpeechControllerScript.new()
	_controller.name = "MumbleSpeechController"
	add_child(_controller)
	_controller.blip_played.connect(_on_blip_played)

	_load_profiles()
	_build_ui()

	if not _profiles.is_empty():
		_select_profile(0)
	_select_sample_line(0)


func _process(delta: float) -> void:
	if not _is_typing:
		return
	if _revealed_count >= _full_text.length():
		_is_typing = false
		return

	_char_accumulator += delta * _chars_per_sec
	while _char_accumulator >= 1.0 and _revealed_count < _full_text.length():
		_char_accumulator -= 1.0
		var ch: String = _full_text.substr(_revealed_count, 1)
		_controller.on_character_revealed(ch, _revealed_count)
		_revealed_count += 1
		if _dialogue_label != null:
			_dialogue_label.visible_characters = _revealed_count

	if _revealed_count >= _full_text.length():
		_is_typing = false


func _load_profiles() -> void:
	_profiles.clear()
	_profile_paths.clear()
	var ids: Array[StringName] = VoiceProfileRegistryScript.get_all_profile_ids()
	for id: StringName in ids:
		var path: String = "%s%s.tres" % [VoiceProfileRegistryScript.PROFILES_DIR, String(id)]
		var res: Resource = load(path)
		if res is VoiceProfileDataScript:
			_profiles.append(res as VoiceProfileDataScript)
			_profile_paths.append(path)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.11, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	# Header
	var title: Label = Label.new()
	title.text = "MUMBLE SPEECH LAB — Enfoque Híbrido Data-Driven (Sandbox)"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.76, 0.88, 1.0))
	root_vbox.add_child(title)

	# Middle split
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 20)
	root_vbox.add_child(hbox)

	# Left column: Speaker, text, playback
	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 10)
	hbox.add_child(left_vbox)

	var speaker_row: HBoxContainer = HBoxContainer.new()
	left_vbox.add_child(speaker_row)
	var sp_lbl: Label = Label.new()
	sp_lbl.text = "Perfil de Voz (.tres): "
	speaker_row.add_child(sp_lbl)

	_profile_option = OptionButton.new()
	_profile_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for p: VoiceProfileDataScript in _profiles:
		_profile_option.add_item(p.display_name)
	_profile_option.item_selected.connect(_select_profile)
	speaker_row.add_child(_profile_option)

	var preset_row: HBoxContainer = HBoxContainer.new()
	left_vbox.add_child(preset_row)
	var pr_lbl: Label = Label.new()
	pr_lbl.text = "Frase de Prueba: "
	preset_row.add_child(pr_lbl)

	_preset_option = OptionButton.new()
	_preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: Dictionary in SAMPLE_LINES:
		_preset_option.add_item(String(item["label"]))
	_preset_option.item_selected.connect(_select_sample_line)
	preset_row.add_child(_preset_option)

	_text_edit = TextEdit.new()
	_text_edit.custom_minimum_size = Vector2(0, 120)
	_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	left_vbox.add_child(_text_edit)

	# Speed slider
	var speed_row: HBoxContainer = HBoxContainer.new()
	left_vbox.add_child(speed_row)
	var speed_lbl: Label = Label.new()
	speed_lbl.text = "Velocidad texto (chars/s): "
	speed_row.add_child(speed_lbl)
	_speed_slider = HSlider.new()
	_speed_slider.min_value = 12.0
	_speed_slider.max_value = 80.0
	_speed_slider.step = 1.0
	_speed_slider.value = _chars_per_sec
	_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed_slider.value_changed.connect(_on_speed_changed)
	speed_row.add_child(_speed_slider)
	_speed_value_label = Label.new()
	_speed_value_label.text = "%d" % int(_chars_per_sec)
	_speed_value_label.custom_minimum_size = Vector2(40, 0)
	speed_row.add_child(_speed_value_label)

	# Action buttons
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	left_vbox.add_child(btn_row)

	var play_btn: Button = Button.new()
	play_btn.text = "▶ Reproducir"
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_btn.pressed.connect(start_playback)
	btn_row.add_child(play_btn)

	var stop_btn: Button = Button.new()
	stop_btn.text = "■ Detener"
	stop_btn.pressed.connect(stop_playback)
	btn_row.add_child(stop_btn)

	var save_btn: Button = Button.new()
	save_btn.text = "💾 Guardar .tres"
	save_btn.pressed.connect(_save_active_profile)
	btn_row.add_child(save_btn)

	# Right column: Live Data-Driven Sliders
	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(420, 0)
	hbox.add_child(right_panel)

	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	var params_title: Label = Label.new()
	params_title.text = "Parámetros Data-Driven (En Vivo)"
	params_title.add_theme_font_size_override("font_size", 16)
	right_vbox.add_child(params_title)

	_add_param_slider(right_vbox, "base_pitch", "Base Pitch", 0.5, 2.2, 0.01)
	_add_param_slider(right_vbox, "pitch_variance", "Pitch Variance", 0.0, 0.35, 0.005)
	_add_param_slider(right_vbox, "formant_hz", "Formant Hz (Synth)", 160.0, 1200.0, 5.0)
	_add_param_slider(right_vbox, "syllable_duration_sec", "Duración Sílaba (s)", 0.03, 0.14, 0.005)
	_add_param_slider(right_vbox, "chars_per_blip", "Chars por Blip", 1.0, 5.0, 1.0)
	_add_param_slider(right_vbox, "min_interval_ms", "Min Interval (ms)", 20.0, 150.0, 5.0)
	_add_param_slider(right_vbox, "question_pitch_boost", "Boost Pregunta (?)", 0.0, 0.45, 0.01)
	_add_param_slider(right_vbox, "exclamation_vol_db", "Boost Exclamación (!)", 0.0, 6.0, 0.25)

	_radio_check = CheckButton.new()
	_radio_check.text = "Filtro Radio / Cockpit (BandPass + Overdrive)"
	_radio_check.toggled.connect(_on_radio_toggled)
	right_vbox.add_child(_radio_check)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(0.65, 0.9, 0.72))
	right_vbox.add_child(_status_label)

	# Bottom dialogue preview box
	var preview_panel: PanelContainer = PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(0, 150)
	root_vbox.add_child(preview_panel)

	var preview_vbox: VBoxContainer = VBoxContainer.new()
	preview_vbox.add_theme_constant_override("separation", 6)
	preview_panel.add_child(preview_vbox)

	var preview_header: HBoxContainer = HBoxContainer.new()
	preview_vbox.add_child(preview_header)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 18)
	_speaker_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	_speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_header.add_child(_speaker_label)

	_telemetry_label = Label.new()
	_telemetry_label.text = "Pitch: -- | Vol: -- dB | Bus: Master"
	_telemetry_label.add_theme_color_override("font_color", Color(0.65, 0.78, 0.95))
	preview_header.add_child(_telemetry_label)

	_dialogue_label = RichTextLabel.new()
	_dialogue_label.fit_content = false
	_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_label.add_theme_font_size_override("normal_font_size", 20)
	preview_vbox.add_child(_dialogue_label)


func _add_param_slider(parent: Control, key: String, label_text: String, min_v: float, max_v: float, step_v: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(165, 0)
	row.add_child(lbl)

	var slider: HSlider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_param_changed.bind(key))
	row.add_child(slider)

	var val_lbl: Label = Label.new()
	val_lbl.custom_minimum_size = Vector2(58, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	_sliders[key] = slider
	_slider_labels[key] = val_lbl


func _select_profile(index: int) -> void:
	if index < 0 or index >= _profiles.size():
		return
	_active_profile_index = index
	_active_profile = _profiles[index]
	_controller.set_profile(_active_profile)
	_speaker_label.text = _active_profile.display_name
	_sync_ui_from_profile()


func _select_sample_line(index: int) -> void:
	if index < 0 or index >= SAMPLE_LINES.size():
		return
	_text_edit.text = String(SAMPLE_LINES[index]["text"])


func _sync_ui_from_profile() -> void:
	if _active_profile == null:
		return
	_syncing_ui = true
	for key: String in _sliders.keys():
		var val: float = float(_active_profile.get(key))
		var slider: HSlider = _sliders[key] as HSlider
		var val_lbl: Label = _slider_labels[key] as Label
		slider.value = val
		val_lbl.text = _format_param_value(key, val)
	_radio_check.button_pressed = _active_profile.radio_filter_enabled
	_syncing_ui = false


func _format_param_value(key: String, val: float) -> String:
	if key == "chars_per_blip" or key == "min_interval_ms" or key == "formant_hz":
		return "%d" % int(round(val))
	return "%.3f" % val if key == "syllable_duration_sec" else "%.2f" % val


func _on_param_changed(value: float, key: String) -> void:
	if _syncing_ui or _active_profile == null:
		return
	if key == "chars_per_blip" or key == "min_interval_ms":
		_active_profile.set(key, int(round(value)))
	else:
		_active_profile.set(key, value)

	var val_lbl: Label = _slider_labels[key] as Label
	val_lbl.text = _format_param_value(key, value)

	if key == "formant_hz" or key == "syllable_duration_sec":
		_controller.invalidate_procedural_cache()


func _on_radio_toggled(enabled: bool) -> void:
	if _syncing_ui or _active_profile == null:
		return
	_active_profile.radio_filter_enabled = enabled


func _on_speed_changed(value: float) -> void:
	_chars_per_sec = value
	_speed_value_label.text = "%d" % int(round(value))


func start_playback() -> void:
	if _active_profile == null:
		return
	_full_text = _text_edit.text
	_revealed_count = 0
	_char_accumulator = 0.0
	_dialogue_label.text = _full_text
	_dialogue_label.visible_characters = 0
	_controller.begin_utterance(_full_text)
	_is_typing = true
	_status_label.text = ""


func stop_playback() -> void:
	_is_typing = false
	_controller.stop()


func _save_active_profile() -> void:
	if _active_profile == null or _active_profile_index >= _profile_paths.size():
		return
	var save_path: String = _profile_paths[_active_profile_index]
	var err: Error = ResourceSaver.save(_active_profile, save_path)
	if err == OK:
		VoiceProfileRegistryScript.reload_all()
		_status_label.text = "Guardado en %s" % save_path.get_file()
	else:
		_status_label.text = "Error al guardar (%d)" % int(err)


func _on_blip_played(pitch_scale: float, volume_db: float, is_radio: bool) -> void:
	var bus_str: String = "MumbleRadio" if is_radio else "SFX/Master"
	_telemetry_label.text = "Pitch: %.2f | Vol: %.1f dB | Bus: %s" % [pitch_scale, volume_db, bus_str]
