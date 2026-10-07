class_name OrbitalIgnitionTerminal
extends BaseButton

signal ignition_committed

enum TerminalState { IDLE, HOVERED, FOCUSED, COMMITTED }
enum InputScheme { KEYBOARD, GAMEPAD_XBOX, GAMEPAD_SONY }

const BASE_TELEMETRY: String = "/// ENLACE NEURAL ESTABLECIDO // PROTOCOLO DE SALTO: AUTORIZADO // VECTOR ORBITAL SINCRONIZADO // CONFIRMAR DESPLIEGUE >>> CARGANDO SISTEMAS TÁCTICOS // IGNICIÓN EN ESPERA /// "
const LOCKED_TELEMETRY: String = "[ TARGET LOCKED // LISTO PARA DESPLIEGUE ] >>> ENLACE ORBITAL ESTABLECIDO // AUTORIZAR IGNICIÓN >>> "
const COMMIT_TELEMETRY: String = ">>> IGNICIÓN DE HIPERESPACIO: COMPROMETIDA <<<"

@export_group("Tipografía y Telemetría")
@export var terminal_font: Font
@export var font_size: int = 13
@export var base_speed: float = 38.0
@export var hover_speed: float = 85.0
@export var focus_speed: float = 55.0

@export_group("Paleta Cromática y HDR")
@export var color_idle: Color = Color(0.20, 0.45, 0.55, 0.85)
@export var color_hover: Color = Color(0.60, 1.80, 2.20, 1.00)
@export var color_focus: Color = Color(0.80, 2.40, 3.20, 1.00)
@export var color_flash: Color = Color(5.00, 5.00, 5.00, 1.00)
@export var color_laser: Color = Color(1.20, 3.00, 4.00, 1.00)

@onready var glass_bg: ColorRect = $GlassBackground
@onready var marquee_zone: Control = $MarqueeZone
@onready var marquee_display: CanvasGroup = $MarqueeZone/MarqueeDisplay
@onready var label_a: Label = $MarqueeZone/MarqueeDisplay/MarqueeLabelA
@onready var label_b: Label = $MarqueeZone/MarqueeDisplay/MarqueeLabelB
@onready var chassis_sep: ColorRect = $ChassisSeparator
@onready var anchor_action_label: Label = $ConfirmationAnchor/AnchorActionLabel
@onready var prompt_glyph: Control = $ConfirmationAnchor/PromptGlyph
@onready var vector_overlay: Control = $VectorOverlay

var current_state: TerminalState = TerminalState.IDLE
var current_input_scheme: InputScheme = InputScheme.KEYBOARD

var marquee_offset: float = 0.0
var marquee_string_width: float = 0.0
var current_speed: float = 38.0
var active_telemetry_text: String = BASE_TELEMETRY

var bracket_inset: float = 0.0
var corner_reticle_alpha: float = 0.0
var laser_progress: float = 0.0
var led_time_accumulator: float = 0.0
var is_flashing: bool = false
var current_chassis_color: Color = Color(0.20, 0.45, 0.55, 0.85)

var active_tween: Tween = null

func _ready() -> void:
	custom_minimum_size = Vector2(720, 36)
	focus_mode = FOCUS_ALL
	
	_configure_label(label_a)
	_configure_label(label_b)
	_update_telemetry_metrics()
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	pressed.connect(_on_pressed)
	
	if vector_overlay:
		vector_overlay.draw.connect(_on_vector_overlay_draw)
	if prompt_glyph:
		prompt_glyph.draw.connect(_on_prompt_glyph_draw)
	
	_update_input_prompt_label()

func _input(event: InputEvent) -> void:
	var prev_scheme: InputScheme = current_input_scheme
	
	if event is InputEventKey or event is InputEventMouseButton:
		current_input_scheme = InputScheme.KEYBOARD
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs((event as InputEventJoypadMotion).axis_value) > 0.3):
		var joy_name: String = Input.get_joy_name(event.device).to_lower()
		if "sony" in joy_name or "ps" in joy_name or "playstation" in joy_name:
			current_input_scheme = InputScheme.GAMEPAD_SONY
		else:
			current_input_scheme = InputScheme.GAMEPAD_XBOX
			
	if prev_scheme != current_input_scheme:
		_update_input_prompt_label()
		if is_instance_valid(prompt_glyph):
			prompt_glyph.queue_redraw()

func _configure_label(lbl: Label) -> void:
	if not is_instance_valid(lbl):
		return
	if terminal_font:
		lbl.add_theme_font_override("font", terminal_font)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.95, 0.90))

func _update_telemetry_metrics() -> void:
	if is_instance_valid(label_a):
		label_a.text = active_telemetry_text
	if is_instance_valid(label_b):
		label_b.text = active_telemetry_text
	
	if terminal_font:
		marquee_string_width = terminal_font.get_string_size(
			active_telemetry_text, 
			HORIZONTAL_ALIGNMENT_LEFT, 
			-1.0, 
			font_size
		).x
	elif is_instance_valid(label_a):
		var def_font: Font = label_a.get_theme_default_font()
		if def_font:
			marquee_string_width = def_font.get_string_size(active_telemetry_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		else:
			marquee_string_width = float(active_telemetry_text.length()) * 8.0

func _process(delta: float) -> void:
	if current_state != TerminalState.COMMITTED and marquee_string_width > 0.0:
		marquee_offset = fmod(marquee_offset + current_speed * delta, marquee_string_width)
		if is_instance_valid(label_a):
			label_a.position.x = -marquee_offset
		if is_instance_valid(label_b):
			label_b.position.x = -marquee_offset + marquee_string_width
	
	if current_state == TerminalState.FOCUSED:
		var perimeter: float = 2.0 * (size.x + size.y)
		if perimeter > 0.0:
			laser_progress = fmod(laser_progress + (perimeter * 0.45 * delta), perimeter)
	
	led_time_accumulator += delta
	if is_instance_valid(vector_overlay):
		vector_overlay.queue_redraw()
	if is_instance_valid(prompt_glyph):
		prompt_glyph.queue_redraw()

func _on_mouse_entered() -> void:
	if current_state == TerminalState.COMMITTED:
		return
	if current_state != TerminalState.FOCUSED:
		current_state = TerminalState.HOVERED
		_transition_to_hover()

func _on_mouse_exited() -> void:
	if current_state == TerminalState.COMMITTED or has_focus():
		return
	current_state = TerminalState.IDLE
	_transition_to_idle()

func _on_focus_entered() -> void:
	if current_state == TerminalState.COMMITTED:
		return
	current_state = TerminalState.FOCUSED
	_transition_to_focused()

func _on_focus_exited() -> void:
	if current_state == TerminalState.COMMITTED:
		return
	if is_hovered():
		current_state = TerminalState.HOVERED
		_transition_to_hover()
	else:
		current_state = TerminalState.IDLE
		_transition_to_idle()

func _on_pressed() -> void:
	if current_state == TerminalState.COMMITTED:
		return
	current_state = TerminalState.COMMITTED
	_execute_commit_sequence()

func reset_terminal() -> void:
	current_state = TerminalState.IDLE
	is_flashing = false
	bracket_inset = 0.0
	corner_reticle_alpha = 0.0
	laser_progress = 0.0
	current_chassis_color = color_idle
	if is_instance_valid(label_a):
		label_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_transition_to_idle()

func _transition_to_idle() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween().set_parallel(true)
	
	active_tween.tween_property(self, "current_speed", base_speed, 0.35).set_trans(Tween.TRANS_SINE)
	active_tween.tween_property(self, "current_chassis_color", color_idle, 0.30)
	active_tween.tween_property(self, "bracket_inset", 0.0, 0.25).set_trans(Tween.TRANS_QUAD)
	active_tween.tween_property(self, "corner_reticle_alpha", 0.0, 0.20)
	
	_set_glass_tint(Color(0.015, 0.025, 0.04, 0.85))
	_set_shimmer_intensity(0.0)
	
	active_telemetry_text = BASE_TELEMETRY
	_update_telemetry_metrics()

func _transition_to_hover() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween().set_parallel(true)
	
	active_tween.tween_property(self, "current_speed", hover_speed, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "current_chassis_color", color_hover, 0.15)
	
	var mat := glass_bg.material as ShaderMaterial if is_instance_valid(glass_bg) else null
	if mat:
		mat.set_shader_parameter("shimmer_intensity", 1.8)
		mat.set_shader_parameter("shimmer_position", -0.3)
		active_tween.tween_property(mat, "shader_parameter/shimmer_position", 1.3, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _transition_to_focused() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween().set_parallel(true)
	
	active_tween.tween_property(self, "current_speed", focus_speed, 0.25)
	active_tween.tween_property(self, "current_chassis_color", color_focus, 0.10)
	active_tween.tween_property(self, "bracket_inset", 5.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	_set_glass_tint(Color(0.010, 0.018, 0.03, 0.92))
	
	var blink := create_tween()
	corner_reticle_alpha = 0.0
	blink.tween_property(self, "corner_reticle_alpha", 1.0, 0.04)
	blink.tween_property(self, "corner_reticle_alpha", 0.0, 0.04)
	blink.tween_property(self, "corner_reticle_alpha", 1.0, 0.04)
	blink.tween_property(self, "corner_reticle_alpha", 0.2, 0.04)
	blink.tween_property(self, "corner_reticle_alpha", 1.0, 0.06)
	
	active_telemetry_text = LOCKED_TELEMETRY + BASE_TELEMETRY
	_update_telemetry_metrics()

func _execute_commit_sequence() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	is_flashing = true
	current_chassis_color = color_flash
	_set_glass_tint(Color(1.0, 1.0, 1.0, 0.98))
	if is_instance_valid(vector_overlay):
		vector_overlay.queue_redraw()
	
	var commit := create_tween()
	commit.tween_callback(func() -> void:
		is_flashing = false
		_set_glass_tint(Color(0.01, 0.02, 0.03, 0.95))
		current_chassis_color = color_focus
	).set_delay(0.03)
	
	if is_instance_valid(marquee_display):
		commit.tween_property(marquee_display, "scale:x", 0.0, 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		commit.tween_callback(func() -> void:
			active_telemetry_text = COMMIT_TELEMETRY
			if is_instance_valid(label_a):
				label_a.text = active_telemetry_text
				label_a.position.x = 0.0
				label_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				if is_instance_valid(marquee_zone):
					label_a.size.x = marquee_zone.size.x
			if is_instance_valid(label_b):
				label_b.text = ""
		)
		commit.tween_property(marquee_display, "scale:x", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	commit.parallel().tween_property(self, "bracket_inset", -18.0, 0.20).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	commit.tween_interval(0.35)
	commit.tween_callback(func() -> void:
		ignition_committed.emit()
	)

func _set_glass_tint(tint: Color) -> void:
	if not is_instance_valid(glass_bg):
		return
	var mat := glass_bg.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("glass_tint", tint)

func _set_shimmer_intensity(val: float) -> void:
	if not is_instance_valid(glass_bg):
		return
	var mat := glass_bg.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("shimmer_intensity", val)

func _update_input_prompt_label() -> void:
	if not is_instance_valid(anchor_action_label):
		return
	match current_input_scheme:
		InputScheme.KEYBOARD:
			anchor_action_label.text = "[ EJECUTAR DESPLIEGUE "
		InputScheme.GAMEPAD_XBOX:
			anchor_action_label.text = "[ EJECUTAR DESPLIEGUE "
		InputScheme.GAMEPAD_SONY:
			anchor_action_label.text = "[ EJECUTAR DESPLIEGUE "

func _on_vector_overlay_draw() -> void:
	if not is_instance_valid(vector_overlay):
		return
	var r := Rect2(Vector2.ZERO, size)
	var col: Color = current_chassis_color
	
	if is_flashing:
		vector_overlay.draw_rect(r, Color(3.5, 3.5, 3.5, 0.95), true)
		return
	
	# Delimitación estructural de 1 píxel
	vector_overlay.draw_rect(r, col * 0.5, false, 1.0)
	
	# Hilo superior de carga pulsante
	var breath: float = 0.55 + 0.45 * sin(led_time_accumulator * 2.0)
	vector_overlay.draw_line(Vector2(0, 0), Vector2(size.x, 0), col * breath, 1.0)
	
	var h: float = size.y
	var cut: float = 7.0
	
	# Corchete Izquierdo [ //
	var lx: float = bracket_inset
	var left_bracket := PackedVector2Array([
		Vector2(lx + cut, 0),
		Vector2(lx, cut),
		Vector2(lx, h - cut),
		Vector2(lx + cut, h)
	])
	vector_overlay.draw_polyline(left_bracket, col, 1.2, true)
	vector_overlay.draw_line(Vector2(lx + 4, cut), Vector2(lx + 9, h - cut), col * 0.6, 1.0, true)
	vector_overlay.draw_line(Vector2(lx + 8, cut), Vector2(lx + 13, h - cut), col * 0.6, 1.0, true)
	
	# Corchete Derecho // ]
	var rx: float = size.x - bracket_inset
	var right_bracket := PackedVector2Array([
		Vector2(rx - cut, 0),
		Vector2(rx, cut),
		Vector2(rx, h - cut),
		Vector2(rx - cut, h)
	])
	vector_overlay.draw_polyline(right_bracket, col, 1.2, true)
	vector_overlay.draw_line(Vector2(rx - 9, cut), Vector2(rx - 4, h - cut), col * 0.6, 1.0, true)
	vector_overlay.draw_line(Vector2(rx - 13, cut), Vector2(rx - 8, h - cut), col * 0.6, 1.0, true)
	
	# Diodo LED de telemetría de vuelo
	var led_pos := Vector2(lx + 20.0, h * 0.5)
	var led_intensity: float
	var led_col := Color(0.40, 2.00, 2.60, 1.00)
	
	if current_state == TerminalState.FOCUSED:
		led_intensity = 1.0 if fmod(led_time_accumulator * 3.0, 1.0) > 0.45 else 0.1
	else:
		led_intensity = 0.4 + 0.6 * (0.5 + 0.5 * sin(led_time_accumulator * 2.5))
		
	vector_overlay.draw_circle(led_pos, 2.0, led_col * led_intensity)
	vector_overlay.draw_arc(led_pos, 3.8, 0, TAU, 12, led_col * (led_intensity * 0.35), 1.0, true)
	
	# Retículas HUD de Enclavamiento en las cuatro esquinas
	if corner_reticle_alpha > 0.01:
		var ret_col: Color = color_focus * corner_reticle_alpha
		var arm: float = 8.0
		vector_overlay.draw_line(Vector2(-3, -3), Vector2(-3 + arm, -3), ret_col, 1.2)
		vector_overlay.draw_line(Vector2(-3, -3), Vector2(-3, -3 + arm), ret_col, 1.2)
		vector_overlay.draw_line(Vector2(size.x + 3, -3), Vector2(size.x + 3 - arm, -3), ret_col, 1.2)
		vector_overlay.draw_line(Vector2(size.x + 3, -3), Vector2(size.x + 3, -3 + arm), ret_col, 1.2)
		vector_overlay.draw_line(Vector2(-3, size.y + 3), Vector2(-3 + arm, size.y + 3), ret_col, 1.2)
		vector_overlay.draw_line(Vector2(-3, size.y + 3), Vector2(-3, size.y + 3 - arm), ret_col, 1.2)
		vector_overlay.draw_line(Vector2(size.x + 3, size.y + 3), Vector2(size.x + 3 - arm, size.y + 3), ret_col, 1.2)
		vector_overlay.draw_line(Vector2(size.x + 3, size.y + 3), Vector2(size.x + 3, size.y + 3 - arm), ret_col, 1.2)
		
	# Trazador de láser horario perimetral
	if current_state == TerminalState.FOCUSED:
		_draw_laser_trail(r)

func _draw_laser_trail(bounds: Rect2) -> void:
	if not is_instance_valid(vector_overlay):
		return
	var total_p: float = 2.0 * (bounds.size.x + bounds.size.y)
	if total_p <= 0.0:
		return
	var trail_len: float = 48.0
	var steps: int = 8
	
	for i in range(steps):
		var factor: float = float(i) / float(steps)
		var dist: float = fmod(laser_progress - (factor * trail_len) + total_p, total_p)
		var pt: Vector2 = _sample_perimeter_point(bounds, dist)
		var next_dist: float = fmod(dist + (trail_len / float(steps)), total_p)
		var next_pt: Vector2 = _sample_perimeter_point(bounds, next_dist)
		
		if pt.distance_to(next_pt) < (trail_len * 1.5):
			var col: Color = color_laser * (1.0 - factor)
			vector_overlay.draw_line(pt, next_pt, col, 1.4, true)

func _sample_perimeter_point(b: Rect2, d: float) -> Vector2:
	var w: float = b.size.x
	var h: float = b.size.y
	
	if d < w:
		return Vector2(d, 0)
	d -= w
	if d < h:
		return Vector2(w, d)
	d -= w
	if d < w:
		return Vector2(w - d, h)
	d -= w
	return Vector2(0, h - d)

func _on_prompt_glyph_draw() -> void:
	if not is_instance_valid(prompt_glyph):
		return
	var center: Vector2 = prompt_glyph.size * 0.5
	var glyph_color: Color = color_hover
	
	match current_input_scheme:
		InputScheme.KEYBOARD:
			var box := Rect2(center - Vector2(7, 6), Vector2(14, 12))
			prompt_glyph.draw_rect(box, glyph_color * 0.45, false, 1.0)
			var pts := PackedVector2Array([
				Vector2(center.x + 3, center.y - 3),
				Vector2(center.x + 3, center.y + 1),
				Vector2(center.x - 3, center.y + 1)
			])
			prompt_glyph.draw_polyline(pts, glyph_color, 1.0)
			prompt_glyph.draw_line(Vector2(center.x - 3, center.y + 1), Vector2(center.x - 1, center.y - 1), glyph_color, 1.0)
			prompt_glyph.draw_line(Vector2(center.x - 3, center.y + 1), Vector2(center.x - 1, center.y + 3), glyph_color, 1.0)
			
		InputScheme.GAMEPAD_XBOX:
			prompt_glyph.draw_arc(center, 6.5, 0, TAU, 16, glyph_color, 1.0, true)
			var ring_scale: float = 8.0 + 1.4 * sin(led_time_accumulator * 4.0)
			prompt_glyph.draw_arc(center, ring_scale, 0, TAU, 16, glyph_color * 0.35, 1.0, true)
			var a_pts := PackedVector2Array([
				Vector2(center.x - 3, center.y + 3),
				Vector2(center.x, center.y - 3),
				Vector2(center.x + 3, center.y + 3)
			])
			prompt_glyph.draw_polyline(a_pts, glyph_color, 1.0)
			prompt_glyph.draw_line(Vector2(center.x - 2, center.y + 1), Vector2(center.x + 2, center.y + 1), glyph_color, 1.0)
			
		InputScheme.GAMEPAD_SONY:
			prompt_glyph.draw_arc(center, 6.5, 0, TAU, 16, glyph_color, 1.0, true)
			var ring_s: float = 8.0 + 1.4 * sin(led_time_accumulator * 4.0)
			prompt_glyph.draw_arc(center, ring_s, 0, TAU, 16, glyph_color * 0.35, 1.0, true)
			prompt_glyph.draw_line(Vector2(center.x - 2.5, center.y - 2.5), Vector2(center.x + 2.5, center.y + 2.5), glyph_color, 1.0)
			prompt_glyph.draw_line(Vector2(center.x + 2.5, center.y - 2.5), Vector2(center.x - 2.5, center.y + 2.5), glyph_color, 1.0)
