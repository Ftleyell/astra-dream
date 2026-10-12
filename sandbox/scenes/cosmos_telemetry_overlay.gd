class_name CosmosTelemetryOverlay
extends CanvasLayer

## Overlay de depuración e instrumentación técnica interactiva para Cosmos Engine.
## Proporciona:
## 1. Telemetría continua de alta precisión (coordenadas, FPS, shifts, zoom).
## 2. Panel de control en vivo colapsable (F1) con toggles de estratos 1-5,
##    sliders reactivos de paralaje, estrellas y nebulosa, y control de tiempo cósmico.
## 3. Acceso directo a Gizmos de Depuración 2D (F2).

@export var cosmos_root: CosmosRoot
@export var vessel: PlayerVessel
@export var camera: CosmosCamera2D
@export var debug_drawer: CosmosDebugDrawer2D

@onready var label_telemetry: Label = $PanelContainer/MarginContainer/LabelTelemetry

# Controles de Interfaz de Depuración
var _debug_panel: PanelContainer = null
var _toggle_hud_button: Button = null

var _check_layer_1: CheckBox = null
var _check_layer_2: CheckBox = null
var _check_layer_3: CheckBox = null
var _check_layer_4: CheckBox = null
var _check_layer_5: CheckBox = null
var _check_gizmos: CheckBox = null

var _slider_parallax: HSlider = null
var _label_parallax_val: Label = null
var _slider_star_parallax: HSlider = null
var _label_star_parallax_val: Label = null
var _slider_stars: HSlider = null
var _label_stars_val: Label = null
var _slider_nebula: HSlider = null
var _label_nebula_val: Label = null

var _check_shadows: CheckBox = null
var _slider_shadow_opacity: HSlider = null
var _label_shadow_opacity_val: Label = null
var _slider_shadow_penumbra: HSlider = null
var _label_shadow_penumbra_val: Label = null
var _slider_shadow_expansion: HSlider = null
var _label_shadow_expansion_val: Label = null
var _slider_shadow_fade: HSlider = null
var _label_shadow_fade_val: Label = null
var _slider_planet_exposure: HSlider = null
var _label_planet_exposure_val: Label = null
var _slider_star_core: HSlider = null
var _label_star_core_val: Label = null

func _ready() -> void:
	layer = 120
	_build_debug_ui()
	_sync_ui_state_from_engine()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_F1:
			toggle_debug_panel()
		KEY_F2:
			toggle_gizmos()
		KEY_1:
			_toggle_stratum(1)
		KEY_2:
			_toggle_stratum(2)
		KEY_3:
			_toggle_stratum(3)
		KEY_4:
			_toggle_stratum(4)
		KEY_5:
			_toggle_stratum(5)
		KEY_B:
			_cycle_biome_preset()

func _process(_delta: float) -> void:
	_update_telemetry_label()

func _update_telemetry_label() -> void:
	if label_telemetry == null:
		return

	var fps: float = Engine.get_frames_per_second()
	var local_pos: Vector2 = vessel.global_position if vessel != null else Vector2.ZERO
	var abs_pos: Vector2 = cosmos_root.get_absolute_position(local_pos) if cosmos_root != null else local_pos
	var speed: float = vessel.get_current_speed() if vessel != null else 0.0
	var shift_count: int = cosmos_root.get_origin_shift_count() if cosmos_root != null else 0
	var zoom_lvl: Vector2 = camera.zoom if camera != null else Vector2.ONE
	var time_val: float = cosmos_root.get_global_time() if cosmos_root != null else 0.0
	var gizmos_state: String = "ON" if (debug_drawer != null and debug_drawer.enabled) else "OFF"

	# Celda galáctica de referencia (usando grid tamaño 60000)
	var cell_x: int = int(floor(abs_pos.x / 60000.0))
	var cell_y: int = int(floor(abs_pos.y / 60000.0))

	var biome_name: String = "Desconocido"
	if cosmos_root != null and cosmos_root.environment_profile != null and cosmos_root.environment_profile.biome_a_profile != null:
		biome_name = cosmos_root.environment_profile.biome_a_profile.display_name

	var text: String = "=== COSMOS ENGINE TELEMETRY ===\n"
	text += "Pilot: %s\n" % (vessel.get_character_display_name() if vessel != null and vessel.has_method("get_character_display_name") else "Vanguard")
	text += "Active Biome [B]: %s\n" % biome_name
	text += "FPS: %.1f\n" % fps
	text += "Global Cosmic Time: %.2f s (Warp: %.1fx)\n" % [time_val, cosmos_root.time_scale if cosmos_root != null else 1.0]
	text += "Local Pos: (%.1f, %.1f)\n" % [local_pos.x, local_pos.y]
	text += "Absolute World Pos: (%.1f, %.1f)\n" % [abs_pos.x, abs_pos.y]
	text += "Speed: %.1f px/s\n" % speed
	text += "Galactic Macro Cell: [%d, %d]\n" % [cell_x, cell_y]
	text += "Origin Shifts: %d\n" % shift_count
	text += "Camera Zoom: %.2fx | Gizmos [F2]: %s\n" % [zoom_lvl.x, gizmos_state]
	text += "Controls: WASD (Thrust), SHIFT (Boost), Wheel (+/- Zoom)\n"
	text += "Biomes: B (Cycle 6 Biomes) | Heroes: TAB/E/Q | HUD: F1"

	label_telemetry.text = text

## Construye dinámicamente el panel de control de debug
func _build_debug_ui() -> void:
	# Botón de apertura / cierre en esquina superior derecha
	_toggle_hud_button = Button.new()
	_toggle_hud_button.text = "🎛️ Debug Panel (F1)"
	_toggle_hud_button.anchor_left = 1.0
	_toggle_hud_button.anchor_right = 1.0
	_toggle_hud_button.offset_left = -170.0
	_toggle_hud_button.offset_top = 20.0
	_toggle_hud_button.offset_right = -20.0
	_toggle_hud_button.offset_bottom = 54.0
	_toggle_hud_button.pressed.connect(toggle_debug_panel)
	add_child(_toggle_hud_button)

	# Contenedor principal del panel
	_debug_panel = PanelContainer.new()
	_debug_panel.name = "CosmosLiveDebugPanel"
	_debug_panel.anchor_left = 1.0
	_debug_panel.anchor_right = 1.0
	_debug_panel.offset_left = -390.0
	_debug_panel.offset_top = 65.0
	_debug_panel.offset_right = -20.0
	_debug_panel.offset_bottom = 760.0
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_debug_panel.visible = false
	add_child(_debug_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_debug_panel.add_child(margin)

	var vbox: VBoxContainer = _create_vbox()
	margin.add_child(vbox)

	# 1. Cabecera
	var lbl_title: Label = Label.new()
	lbl_title.text = "🎛️ COSMOS LIVE CONTROL [F1]"
	lbl_title.add_theme_font_size_override("font_size", 14)
	lbl_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	vbox.add_child(lbl_title)

	vbox.add_child(HSeparator.new())

	# 2. Toggles de Estratos Cósmicos
	var lbl_layers: Label = Label.new()
	lbl_layers.text = "VISIBILIDAD DE ESTRATOS (Teclas 1-5):"
	lbl_layers.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl_layers)

	_check_layer_1 = _create_checkbox("[1] L1: Nebulosa Profunda (FBM GPU)", true)
	_check_layer_1.toggled.connect(func(val: bool) -> void: _set_layer(1, val))
	vbox.add_child(_check_layer_1)

	_check_layer_2 = _create_checkbox("[2] L2: Buffer Óptico 8K (Starfield)", true)
	_check_layer_2.toggled.connect(func(val: bool) -> void: _set_layer(2, val))
	vbox.add_child(_check_layer_2)

	_check_layer_3 = _create_checkbox("[3] L3: Macro-Galaxias (Landmarks)", true)
	_check_layer_3.toggled.connect(func(val: bool) -> void: _set_layer(3, val))
	vbox.add_child(_check_layer_3)

	_check_layer_4 = _create_checkbox("[4] L4: Sistemas Solares Keplerianos", true)
	_check_layer_4.toggled.connect(func(val: bool) -> void: _set_layer(4, val))
	vbox.add_child(_check_layer_4)

	_check_layer_5 = _create_checkbox("[5] L5: Cinturón de Escombros GPU", true)
	_check_layer_5.toggled.connect(func(val: bool) -> void: _set_layer(5, val))
	vbox.add_child(_check_layer_5)

	vbox.add_child(HSeparator.new())

	# 3. Gizmos Visuales 2D
	_check_gizmos = _create_checkbox("[F2] Gizmos de Depuración 2D", false)
	_check_gizmos.toggled.connect(_on_gizmos_toggled)
	vbox.add_child(_check_gizmos)

	vbox.add_child(HSeparator.new())

	# 4. Sliders en Caliente
	var lbl_sliders: Label = Label.new()
	lbl_sliders.text = "AJUSTES VISUALES EN CALIENTE:"
	lbl_sliders.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl_sliders)

	# Multiplicador Paralaje
	_label_parallax_val = Label.new()
	_label_parallax_val.text = "Paralaje Global: 1.00x"
	_label_parallax_val.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_label_parallax_val)
	_slider_parallax = HSlider.new()
	_slider_parallax.min_value = 0.0
	_slider_parallax.max_value = 3.0
	_slider_parallax.step = 0.05
	_slider_parallax.value = 1.0
	_slider_parallax.value_changed.connect(_on_parallax_slider_changed)
	vbox.add_child(_slider_parallax)

	# Velocidad / Factor de Paralaje del Buffer Óptico 8K (Segunda Capa)
	_label_star_parallax_val = Label.new()
	_label_star_parallax_val.text = "Paralaje Buffer Óptico 8K: 0.00650"
	_label_star_parallax_val.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_label_star_parallax_val)
	_slider_star_parallax = HSlider.new()
	_slider_star_parallax.min_value = 0.00000
	_slider_star_parallax.max_value = 0.02000
	_slider_star_parallax.step = 0.00010
	_slider_star_parallax.value = 0.00650
	_slider_star_parallax.value_changed.connect(_on_star_parallax_slider_changed)
	vbox.add_child(_slider_star_parallax)

	# Intensidad Estelar
	_label_stars_val = Label.new()
	_label_stars_val.text = "Intensidad Estelar 8K: 2.40"
	_label_stars_val.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_label_stars_val)
	_slider_stars = HSlider.new()
	_slider_stars.min_value = 0.1
	_slider_stars.max_value = 5.0
	_slider_stars.step = 0.1
	_slider_stars.value = 2.4
	_slider_stars.value_changed.connect(_on_star_intensity_slider_changed)
	vbox.add_child(_slider_stars)

	# Densidad de Nebulosa
	_label_nebula_val = Label.new()
	_label_nebula_val.text = "Densidad de Gas Nebular: 2.00"
	_label_nebula_val.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_label_nebula_val)
	_slider_nebula = HSlider.new()
	_slider_nebula.min_value = 0.1
	_slider_nebula.max_value = 3.0
	_slider_nebula.step = 0.05
	_slider_nebula.value = 2.0
	_slider_nebula.value_changed.connect(_on_nebula_density_slider_changed)
	vbox.add_child(_slider_nebula)

	# 5. Sombras Planetarias y Fotometría Solar
	vbox.add_child(HSeparator.new())
	var lbl_sol: Label = Label.new()
	lbl_sol.text = "SOMBRAS Y FOTOMETRÍA SOLAR:"
	lbl_sol.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl_sol)

	_check_shadows = CheckBox.new()
	_check_shadows.text = "🌑 Sombras Planetarias Activas"
	_check_shadows.button_pressed = true
	_check_shadows.toggled.connect(_on_shadows_toggled)
	vbox.add_child(_check_shadows)

	_label_shadow_opacity_val = Label.new()
	_label_shadow_opacity_val.text = "Opacidad de Sombra: 0.75"
	_label_shadow_opacity_val.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_label_shadow_opacity_val)
	_slider_shadow_opacity = HSlider.new()
	_slider_shadow_opacity.min_value = 0.0
	_slider_shadow_opacity.max_value = 1.0
	_slider_shadow_opacity.step = 0.05
	_slider_shadow_opacity.value = 0.75
	_slider_shadow_opacity.value_changed.connect(_on_shadow_opacity_changed)
	vbox.add_child(_slider_shadow_opacity)

	_label_shadow_penumbra_val = Label.new()
	_label_shadow_penumbra_val.text = "Suavidad de Penumbra: 0.45"
	_label_shadow_penumbra_val.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_label_shadow_penumbra_val)
	_slider_shadow_penumbra = HSlider.new()
	_slider_shadow_penumbra.min_value = 0.05
	_slider_shadow_penumbra.max_value = 0.90
	_slider_shadow_penumbra.step = 0.05
	_slider_shadow_penumbra.value = 0.45
	_slider_shadow_penumbra.value_changed.connect(_on_shadow_penumbra_changed)
	vbox.add_child(_slider_shadow_penumbra)

	_label_shadow_expansion_val = Label.new()
	_label_shadow_expansion_val.text = "Expansión Cónica: 1.85x"
	_label_shadow_expansion_val.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_label_shadow_expansion_val)
	_slider_shadow_expansion = HSlider.new()
	_slider_shadow_expansion.min_value = 1.00
	_slider_shadow_expansion.max_value = 3.50
	_slider_shadow_expansion.step = 0.05
	_slider_shadow_expansion.value = 1.85
	_slider_shadow_expansion.value_changed.connect(_on_shadow_expansion_changed)
	vbox.add_child(_slider_shadow_expansion)

	_label_shadow_fade_val = Label.new()
	_label_shadow_fade_val.text = "Fade Heliopausa: 0.22"
	_label_shadow_fade_val.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_label_shadow_fade_val)
	_slider_shadow_fade = HSlider.new()
	_slider_shadow_fade.min_value = 0.02
	_slider_shadow_fade.max_value = 0.50
	_slider_shadow_fade.step = 0.01
	_slider_shadow_fade.value = 0.22
	_slider_shadow_fade.value_changed.connect(_on_shadow_fade_changed)
	vbox.add_child(_slider_shadow_fade)

	_label_planet_exposure_val = Label.new()
	_label_planet_exposure_val.text = "Exposición Diurna Planetas: 1.30"
	_label_planet_exposure_val.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_label_planet_exposure_val)
	_slider_planet_exposure = HSlider.new()
	_slider_planet_exposure.min_value = 0.8
	_slider_planet_exposure.max_value = 2.5
	_slider_planet_exposure.step = 0.05
	_slider_planet_exposure.value = 1.30
	_slider_planet_exposure.value_changed.connect(_on_planet_exposure_changed)
	vbox.add_child(_slider_planet_exposure)

	_label_star_core_val = Label.new()
	_label_star_core_val.text = "Brillo Núcleo Solar: 1.25"
	_label_star_core_val.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_label_star_core_val)
	_slider_star_core = HSlider.new()
	_slider_star_core.min_value = 0.8
	_slider_star_core.max_value = 2.5
	_slider_star_core.step = 0.05
	_slider_star_core.value = 1.25
	_slider_star_core.value_changed.connect(_on_star_core_changed)
	vbox.add_child(_slider_star_core)

	vbox.add_child(HSeparator.new())

	# 5. Escala de Tiempo Cósmico
	var lbl_time: Label = Label.new()
	lbl_time.text = "VELOCIDAD DEL TIEMPO CÓSMICO:"
	lbl_time.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl_time)

	var hbox_time: HBoxContainer = HBoxContainer.new()
	hbox_time.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox_time)

	var btn_0x: Button = _create_time_btn("0x", 0.0)
	var btn_1x: Button = _create_time_btn("1x", 1.0)
	var btn_5x: Button = _create_time_btn("5x", 5.0)
	var btn_10x: Button = _create_time_btn("10x", 10.0)
	hbox_time.add_child(btn_0x)
	hbox_time.add_child(btn_1x)
	hbox_time.add_child(btn_5x)
	hbox_time.add_child(btn_10x)

	vbox.add_child(HSeparator.new())

	# 6. Biomas Cósmicos
	var btn_biome: Button = Button.new()
	btn_biome.text = "🌌 Conmutar Bioma Cósmico (B)"
	btn_biome.focus_mode = Control.FOCUS_NONE
	btn_biome.pressed.connect(_cycle_biome_preset)
	vbox.add_child(btn_biome)

func _cycle_biome_preset() -> void:
	if cosmos_root == null:
		return
	var new_biome: CosmicBiomeConfig = cosmos_root.cycle_biome(true)
	if new_biome != null:
		_sync_ui_state_from_engine()

func _create_vbox() -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	return v

func _create_checkbox(title: String, initial: bool) -> CheckBox:
	var cb: CheckBox = CheckBox.new()
	cb.text = title
	cb.button_pressed = initial
	cb.focus_mode = Control.FOCUS_NONE
	return cb

func _create_time_btn(title: String, scale_val: float) -> Button:
	var b: Button = Button.new()
	b.text = title
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		if cosmos_root != null:
			cosmos_root.time_scale = scale_val
	)
	return b

func toggle_debug_panel() -> void:
	if _debug_panel != null:
		_debug_panel.visible = not _debug_panel.visible

func toggle_gizmos() -> void:
	if debug_drawer != null:
		var new_st: bool = debug_drawer.toggle_debug_draw()
		if _check_gizmos != null:
			_check_gizmos.set_pressed_no_signal(new_st)

func _on_gizmos_toggled(val: bool) -> void:
	if debug_drawer != null:
		debug_drawer.set_debug_enabled(val)

func _toggle_stratum(idx: int) -> void:
	if cosmos_root != null:
		var new_vis: bool = cosmos_root.toggle_layer_visibility(idx)
		_sync_checkbox_stratum(idx, new_vis)

func _set_layer(idx: int, val: bool) -> void:
	if cosmos_root != null:
		cosmos_root.set_layer_visibility(idx, val)

func _sync_checkbox_stratum(idx: int, val: bool) -> void:
	match idx:
		1: if _check_layer_1 != null: _check_layer_1.set_pressed_no_signal(val)
		2: if _check_layer_2 != null: _check_layer_2.set_pressed_no_signal(val)
		3: if _check_layer_3 != null: _check_layer_3.set_pressed_no_signal(val)
		4: if _check_layer_4 != null: _check_layer_4.set_pressed_no_signal(val)
		5: if _check_layer_5 != null: _check_layer_5.set_pressed_no_signal(val)

func _on_parallax_slider_changed(val: float) -> void:
	if _label_parallax_val != null:
		_label_parallax_val.text = "Paralaje Global: %.2fx" % val
	if cosmos_root != null and cosmos_root.environment_profile != null:
		cosmos_root.environment_profile.parallax_multiplier = val

func _on_star_parallax_slider_changed(val: float) -> void:
	if _label_star_parallax_val != null:
		_label_star_parallax_val.text = "Paralaje Buffer Óptico 8K: %.5f" % val
	if cosmos_root != null:
		if cosmos_root.environment_profile != null:
			cosmos_root.environment_profile.starfield_scroll_scale = Vector2(val, val)
		elif cosmos_root.parallax_starfield_8k != null:
			cosmos_root.parallax_starfield_8k.scroll_scale = Vector2(val, val)

func _on_star_intensity_slider_changed(val: float) -> void:
	if _label_stars_val != null:
		_label_stars_val.text = "Intensidad Estelar 8K: %.2f" % val
	if cosmos_root != null and cosmos_root.environment_profile != null:
		cosmos_root.environment_profile.star_intensity = val

func _on_nebula_density_slider_changed(val: float) -> void:
	if _label_nebula_val != null:
		_label_nebula_val.text = "Densidad de Gas Nebular: %.2f" % val
	if cosmos_root != null and cosmos_root.environment_profile != null:
		if cosmos_root.environment_profile.biome_a_profile != null:
			cosmos_root.environment_profile.biome_a_profile.gas_density = val
		cosmos_root.apply_environment_profile()

func _on_shadows_toggled(toggled_on: bool) -> void:
	if cosmos_root != null and cosmos_root.solar_streamer != null:
		var prof: CelestialSystemProfile = cosmos_root.solar_streamer.system_profile
		if prof != null:
			prof.enable_planetary_shadows = toggled_on
			if prof.shadow_config != null:
				prof.shadow_config.enable_planetary_shadows = toggled_on
		cosmos_root.solar_streamer.set_shadows_enabled(toggled_on)

func _on_shadow_opacity_changed(val: float) -> void:
	if _label_shadow_opacity_val != null:
		_label_shadow_opacity_val.text = "Opacidad de Sombra: %.2f" % val
	if cosmos_root != null and cosmos_root.solar_streamer != null:
		var prof: CelestialSystemProfile = cosmos_root.solar_streamer.system_profile
		if prof != null:
			prof.shadow_intensity = val
			if prof.shadow_config != null:
				prof.shadow_config.shadow_intensity = val
		cosmos_root.solar_streamer.set_shadow_opacity(val)

func _on_shadow_penumbra_changed(val: float) -> void:
	if _label_shadow_penumbra_val != null:
		_label_shadow_penumbra_val.text = "Suavidad de Penumbra: %.2f" % val
	if cosmos_root != null and cosmos_root.solar_streamer != null:
		var prof: CelestialSystemProfile = cosmos_root.solar_streamer.system_profile
		if prof != null:
			prof.shadow_penumbra_ratio = val
			if prof.shadow_config != null:
				prof.shadow_config.shadow_penumbra_ratio = val
		cosmos_root.solar_streamer.set_shadow_penumbra_ratio(val)

func _on_shadow_expansion_changed(val: float) -> void:
	if _label_shadow_expansion_val != null:
		_label_shadow_expansion_val.text = "Expansión Cónica: %.2fx" % val
	if cosmos_root != null and cosmos_root.solar_streamer != null:
		var prof: CelestialSystemProfile = cosmos_root.solar_streamer.system_profile
		if prof != null:
			prof.shadow_expansion_factor = val
			if prof.shadow_config != null:
				prof.shadow_config.shadow_expansion_factor = val
		cosmos_root.solar_streamer.set_shadow_expansion_factor(val)

func _on_shadow_fade_changed(val: float) -> void:
	if _label_shadow_fade_val != null:
		_label_shadow_fade_val.text = "Fade Heliopausa: %.2f" % val
	if cosmos_root != null and cosmos_root.solar_streamer != null:
		var prof: CelestialSystemProfile = cosmos_root.solar_streamer.system_profile
		if prof != null:
			prof.shadow_heliopause_fade = val
			if prof.shadow_config != null:
				prof.shadow_config.shadow_heliopause_fade = val
		cosmos_root.solar_streamer.set_shadow_heliopause_fade(val)

func _on_planet_exposure_changed(val: float) -> void:
	if _label_planet_exposure_val != null:
		_label_planet_exposure_val.text = "Exposición Diurna Planetas: %.2f" % val
	if cosmos_root != null and cosmos_root.solar_streamer != null:
		var prof: CelestialSystemProfile = cosmos_root.solar_streamer.system_profile
		if prof != null:
			prof.planet_day_exposure = val
			if prof.planetary_config != null:
				prof.planetary_config.planet_day_exposure = val
		cosmos_root.solar_streamer.set_planet_day_exposure(val)

func _on_star_core_changed(val: float) -> void:
	if _label_star_core_val != null:
		_label_star_core_val.text = "Brillo Núcleo Solar: %.2f" % val
	if cosmos_root != null and cosmos_root.solar_streamer != null:
		var prof: CelestialSystemProfile = cosmos_root.solar_streamer.system_profile
		if prof != null:
			if prof.star_visual_config != null:
				prof.star_visual_config.core_brightness = val
			for arch: StarArchetype in prof.star_archetypes:
				if arch != null:
					arch.core_brightness = val
					if arch.visual_config != null:
						arch.visual_config.core_brightness = val
		cosmos_root.solar_streamer.set_star_core_brightness(val)

func _sync_ui_state_from_engine() -> void:
	if cosmos_root != null:
		_sync_checkbox_stratum(1, cosmos_root.get_layer_visibility(1))
		_sync_checkbox_stratum(2, cosmos_root.get_layer_visibility(2))
		_sync_checkbox_stratum(3, cosmos_root.get_layer_visibility(3))
		_sync_checkbox_stratum(4, cosmos_root.get_layer_visibility(4))
		_sync_checkbox_stratum(5, cosmos_root.get_layer_visibility(5))
		if cosmos_root.environment_profile != null:
			var prof: CosmosEnvironmentProfile = cosmos_root.environment_profile
			if _slider_parallax != null:
				_slider_parallax.set_value_no_signal(prof.parallax_multiplier)
				_label_parallax_val.text = "Paralaje Global: %.2fx" % prof.parallax_multiplier
			if _slider_star_parallax != null:
				var star_px: float = prof.starfield_scroll_scale.x
				_slider_star_parallax.set_value_no_signal(star_px)
				_label_star_parallax_val.text = "Paralaje Buffer Óptico 8K: %.5f" % star_px
			if _slider_stars != null:
				_slider_stars.set_value_no_signal(prof.star_intensity)
				_label_stars_val.text = "Intensidad Estelar 8K: %.2f" % prof.star_intensity
			if _slider_nebula != null and prof.biome_a_profile != null:
				_slider_nebula.set_value_no_signal(prof.biome_a_profile.gas_density)
				_label_nebula_val.text = "Densidad de Gas Nebular: %.2f" % prof.biome_a_profile.gas_density

		if cosmos_root.solar_streamer != null and cosmos_root.solar_streamer.system_profile != null:
			var s_prof: CelestialSystemProfile = cosmos_root.solar_streamer.system_profile
			var sh_cfg: ShadowSystemConfig = s_prof.get_effective_shadow_config()
			var pl_cfg: PlanetarySystemConfig = s_prof.get_effective_planetary_config()
			if _check_shadows != null:
				_check_shadows.set_pressed_no_signal(sh_cfg.enable_planetary_shadows)
			if _slider_shadow_opacity != null:
				_slider_shadow_opacity.set_value_no_signal(sh_cfg.shadow_intensity)
				_label_shadow_opacity_val.text = "Opacidad de Sombra: %.2f" % sh_cfg.shadow_intensity
			if _slider_shadow_penumbra != null:
				_slider_shadow_penumbra.set_value_no_signal(sh_cfg.shadow_penumbra_ratio)
				_label_shadow_penumbra_val.text = "Suavidad de Penumbra: %.2f" % sh_cfg.shadow_penumbra_ratio
			if _slider_shadow_expansion != null:
				_slider_shadow_expansion.set_value_no_signal(sh_cfg.shadow_expansion_factor)
				_label_shadow_expansion_val.text = "Expansión Cónica: %.2fx" % sh_cfg.shadow_expansion_factor
			if _slider_shadow_fade != null:
				_slider_shadow_fade.set_value_no_signal(sh_cfg.shadow_heliopause_fade)
				_label_shadow_fade_val.text = "Fade Heliopausa: %.2f" % sh_cfg.shadow_heliopause_fade
			if _slider_planet_exposure != null:
				_slider_planet_exposure.set_value_no_signal(pl_cfg.planet_day_exposure)
				_label_planet_exposure_val.text = "Exposición Diurna Planetas: %.2f" % pl_cfg.planet_day_exposure

	if debug_drawer != null and _check_gizmos != null:
		_check_gizmos.set_pressed_no_signal(debug_drawer.enabled)
