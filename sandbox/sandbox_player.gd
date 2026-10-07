extends Node2D

const SHADER_TAPE = preload("res://sandbox/tape_marquee.gdshader")
const SHADER_WIPE = preload("res://sandbox/trail_wipe.gdshader")
const SHADER_SOLID_TINT = preload("res://sandbox/pilot_solid_tint.gdshader")
const SHADER_BRUSH = preload("res://sandbox/brush_trail.gdshader")
const SHIPS_DIR = "res://assets/characters/ships/"

const ORBITAL_TERMINAL_SCENE = preload("res://scenes/ui/components/orbital_terminal/orbital_ignition_terminal.tscn")
const ORBITAL_ENV = preload("res://scenes/ui/components/orbital_terminal/orbital_environment.tres")

# Configuración de las 7 pilotos (Nova en índice 3 como punta de la V)
const PILOT_CONFIG = [
	{"name": "echo",      "color": Color(0.12, 0.85, 0.95)}, # Cian
	{"name": "kira",      "color": Color(0.95, 0.78, 0.12)}, # Amarillo
	{"name": "nyx",       "color": Color(0.60, 0.20, 0.88)}, # Violeta
	{"name": "nova",      "color": Color(1.00, 0.40, 0.05)}, # Naranja (Centro)
	{"name": "roxy",      "color": Color(0.90, 0.14, 0.22)}, # Rojo
	{"name": "selene",    "color": Color(0.35, 0.25, 0.75)}, # Índigo
	{"name": "valentina", "color": Color(0.18, 0.45, 0.90)}  # Azul cobalto
]

var button_container: Control
var tape_rect: ColorRect
var tape_mat: ShaderMaterial

var orbital_terminal: OrbitalIgnitionTerminal = null
var hints_label: Label = null

# Estados y colores del botón de cinta
const COLOR_WAITING = Color(0.92, 0.12, 0.12, 1.0) # Rojo reposo
const COLOR_LAUNCH  = Color(0.08, 0.90, 0.35, 1.0) # Verde táctico

var current_color: Color = COLOR_WAITING
var target_color: Color = COLOR_WAITING
var target_scale_y: float = 1.0

var tex_waiting: Texture2D
var tex_launch: Texture2D
var repetitions_waiting: float = 1.0
var repetitions_launch: float = 1.0

const TAPE_WIDTH: float = 2400.0
const TAPE_HEIGHT: float = 90.0

# Nodos de la transición de bandas en V (Trail Buffer con SubViewport)
var transition_layer: CanvasLayer
var transition_root: Control
var solid_bands_root: Control
var front_bands_root: Control
var trail_viewport: SubViewport
var trail_display: TextureRect
var wipe_mat: ShaderMaterial
var pilot_sprites: Array[Dictionary] = []
var is_transitioning: bool = false

func _ready() -> void:
	if has_node("Camera2D"):
		$Camera2D.position = Vector2.ZERO
	if has_node("Background"):
		($Background as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	_crear_entorno_hdr()
	_crear_fondo_prueba()
	_crear_boton_cinta()
	_crear_terminal_orbital()
	_crear_sistema_transicion_v()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_H:
			if is_instance_valid(button_container):
				button_container.visible = not button_container.visible
		elif event.keycode == KEY_R:
			if is_instance_valid(orbital_terminal):
				orbital_terminal.reset_terminal()
		elif event.keycode == KEY_TAB:
			if is_instance_valid(orbital_terminal):
				orbital_terminal.grab_focus()

func _process(delta: float) -> void:
	# Transición suave de color en la cinta
	current_color = current_color.lerp(target_color, 12.0 * delta)
	if tape_mat:
		tape_mat.set_shader_parameter("tape_color", current_color)

	# Expansión suave vertical del botón en hover
	if button_container:
		button_container.scale.y = lerp(button_container.scale.y, target_scale_y, 12.0 * delta)

	# Sincronización a la misma velocidad: la sólida por detrás y las afterimages cubriéndola por encima
	if is_transitioning:
		var screen_w: float = get_viewport_rect().size.x
		for p in pilot_sprites:
			var spr: Sprite2D = p.sprite
			var mat: ShaderMaterial = p.material
			var base_c: Color = p.base_color

			# Modulación cromática en el frente de afterimages
			var lum_shift: float = sin(spr.position.x * 0.035) * 0.08
			mat.set_shader_parameter("tint_color", base_c + Color(lum_shift, lum_shift, lum_shift, 0.0))

			var norm_x: float = spr.position.x / screen_w
			# 1. Banda sólida de fondo con relieve anatómico en la cabeza
			p.mat_back.set_shader_parameter("progress", norm_x + (p.ship_length_norm * 0.5))

			# 2. Banda sólida frontal con relieve anatómico rezagada exactamente 1 piloto
			p.mat_front.set_shader_parameter("progress", norm_x - (p.ship_length_norm * 0.5))

# ==============================================================================
# 1. BOTÓN DE CINTA DE RECORTE INFINITO
# ==============================================================================
func _crear_boton_cinta() -> void:
	# Generamos las dos texturas dinámicas en memoria
	var data_waiting = _crear_modulo_texto("WAITING")
	tex_waiting = data_waiting.texture
	repetitions_waiting = TAPE_WIDTH / data_waiting.width

	var data_launch = _crear_modulo_texto("LAUNCH")
	tex_launch = data_launch.texture
	repetitions_launch = TAPE_WIDTH / data_launch.width

	tape_mat = ShaderMaterial.new()
	tape_mat.shader = SHADER_TAPE
	tape_mat.set_shader_parameter("text_mask", tex_waiting)
	tape_mat.set_shader_parameter("repetitions_x", repetitions_waiting)
	tape_mat.set_shader_parameter("scroll_speed", 0.4)
	tape_mat.set_shader_parameter("tape_color", COLOR_WAITING)

	button_container = Control.new()
	button_container.name = "TapeButton"
	button_container.size = Vector2(TAPE_WIDTH, TAPE_HEIGHT)
	button_container.position = Vector2(-TAPE_WIDTH / 2.0, -TAPE_HEIGHT / 2.0)
	button_container.pivot_offset = Vector2(TAPE_WIDTH / 2.0, TAPE_HEIGHT / 2.0)
	add_child(button_container)

	tape_rect = ColorRect.new()
	tape_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tape_rect.size = button_container.size
	tape_rect.material = tape_mat
	button_container.add_child(tape_rect)

	# Área interactiva
	var btn = Button.new()
	btn.flat = true
	btn.size = button_container.size
	btn.mouse_entered.connect(_on_focus_entered)
	btn.mouse_exited.connect(_on_focus_exited)
	btn.focus_entered.connect(_on_focus_entered)
	btn.focus_exited.connect(_on_focus_exited)
	btn.pressed.connect(_on_tape_pressed)
	button_container.add_child(btn)

func _on_focus_entered() -> void:
	if is_transitioning:
		return
	target_color = COLOR_LAUNCH
	target_scale_y = 1.15
	tape_mat.set_shader_parameter("text_mask", tex_launch)
	tape_mat.set_shader_parameter("repetitions_x", repetitions_launch)
	tape_mat.set_shader_parameter("scroll_speed", 0.9)

func _on_focus_exited() -> void:
	if is_transitioning:
		return
	target_color = COLOR_WAITING
	target_scale_y = 1.0
	tape_mat.set_shader_parameter("text_mask", tex_waiting)
	tape_mat.set_shader_parameter("repetitions_x", repetitions_waiting)
	tape_mat.set_shader_parameter("scroll_speed", 0.4)

func _on_tape_pressed() -> void:
	if is_transitioning:
		return
	disparar_transicion_pilotos()

# ==============================================================================
# 2. TRANSICIÓN EN V POR VIEWPORT DE ACUMULACIÓN (TRAIL BUFFER 60 FPS)
# ==============================================================================
func _crear_sistema_transicion_v() -> void:
	transition_layer = CanvasLayer.new()
	transition_layer.layer = 120 # Por encima de la interfaz
	add_child(transition_layer)

	transition_root = Control.new()
	transition_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_layer.add_child(transition_root)

	var screen_size: Vector2 = get_viewport_rect().size
	var band_height: float = ceil(screen_size.y / 7.0)

	# 1. Capa de fondo: Líneas sólidas puras
	solid_bands_root = Control.new()
	solid_bands_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	solid_bands_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	solid_bands_root.visible = false
	transition_root.add_child(solid_bands_root)

	# 2. Viewport de acumulación continua para after-images (transparente)
	trail_viewport = SubViewport.new()
	trail_viewport.size = Vector2i(int(screen_size.x), int(screen_size.y))
	trail_viewport.transparent_bg = true
	trail_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	trail_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(trail_viewport)

	# 3. Lienzo que proyecta la textura del Viewport (Capa intermedia de after-images)
	wipe_mat = ShaderMaterial.new()
	wipe_mat.shader = SHADER_WIPE
	wipe_mat.set_shader_parameter("fade_progress", -0.5)
	wipe_mat.set_shader_parameter("fade_feather", 0.38)

	trail_display = TextureRect.new()
	trail_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail_display.texture = trail_viewport.get_texture()
	trail_display.size = screen_size
	trail_display.material = wipe_mat
	trail_display.visible = false
	transition_root.add_child(trail_display)

	# 4. Capa frontal de todo: Líneas sólidas rezagadas 1 piloto
	front_bands_root = Control.new()
	front_bands_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front_bands_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front_bands_root.visible = false
	transition_root.add_child(front_bands_root)

	# 5. Creación de los 7 sprites y sus bandas de fondo y frente con extrusión de silueta
	for i in range(PILOT_CONFIG.size()):
		var cfg: Dictionary = PILOT_CONFIG[i]
		var ship_path: String = SHIPS_DIR + "ship_%s.png" % cfg.name

		if not ResourceLoader.exists(ship_path):
			continue

		var lut_data: Dictionary = _generar_lut_perfil_piloto(ship_path)
		var tex: Texture2D = lut_data.texture
		var lut_tex: ImageTexture = lut_data.lut
		var span_x: int = lut_data.span_x
		var span_y: int = lut_data.span_y

		# Escala proporcional estricta 1:1 para cubrir la altura del carril
		var scale_factor: float = band_height / float(span_x)
		var ship_pixel_length: float = float(span_y) * scale_factor
		var ship_length_norm: float = ship_pixel_length / screen_size.x

		# Sprite para el buffer de after-images en el Viewport
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = true
		spr.rotation_degrees = 90.0
		spr.scale = Vector2(scale_factor, scale_factor)
		spr.position = Vector2(-ship_pixel_length * 2.0, (i + 0.5) * band_height)
		spr.z_index = abs(i - 3)

		var mat := ShaderMaterial.new()
		mat.shader = SHADER_SOLID_TINT
		mat.set_shader_parameter("tint_color", cfg.color)
		spr.material = mat
		spr.visible = false
		trail_viewport.add_child(spr)

		# 1. Banda continua de fondo (por debajo de las after-images) con perfil anatómico
		var band_back := ColorRect.new()
		band_back.position = Vector2(0.0, i * band_height)
		band_back.size = Vector2(screen_size.x, band_height + 1.0)
		var mat_back := ShaderMaterial.new()
		mat_back.shader = SHADER_BRUSH
		mat_back.set_shader_parameter("leading_edge_lut", lut_tex)
		mat_back.set_shader_parameter("tint_color", cfg.color)
		mat_back.set_shader_parameter("ship_length_norm", ship_length_norm)
		mat_back.set_shader_parameter("progress", -0.5)
		mat_back.set_shader_parameter("fade_progress", -0.5)
		band_back.material = mat_back
		band_back.visible = false
		solid_bands_root.add_child(band_back)

		# 2. Banda continua frontal (por encima de las after-images, rezagada 1 piloto) con perfil anatómico idéntico
		var band_front := ColorRect.new()
		band_front.position = Vector2(0.0, i * band_height)
		band_front.size = Vector2(screen_size.x, band_height + 1.0)
		var mat_front := ShaderMaterial.new()
		mat_front.shader = SHADER_BRUSH
		mat_front.set_shader_parameter("leading_edge_lut", lut_tex)
		mat_front.set_shader_parameter("tint_color", cfg.color)
		mat_front.set_shader_parameter("ship_length_norm", ship_length_norm)
		mat_front.set_shader_parameter("progress", -0.5)
		mat_front.set_shader_parameter("fade_progress", -0.5)
		band_front.material = mat_front
		band_front.visible = false
		front_bands_root.add_child(band_front)

		pilot_sprites.append({
			"sprite": spr,
			"material": mat,
			"band_back": band_back,
			"mat_back": mat_back,
			"band_front": band_front,
			"mat_front": mat_front,
			"base_color": cfg.color,
			"index": i,
			"ship_pixel_length": ship_pixel_length,
			"ship_length_norm": ship_length_norm,
			"lane_y": (i + 0.5) * band_height
		})

func _generar_lut_perfil_piloto(ship_path: String) -> Dictionary:
	var tex: Texture2D = load(ship_path)
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()

	var min_x: int = img.get_width()
	var max_x: int = -1
	var min_y: int = img.get_height()
	var max_y: int = -1

	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.12:
				if x < min_x: min_x = x
				if x > max_x: max_x = x
				if y < min_y: min_y = y
				if y > max_y: max_y = y

	var span_x: int = max(1, max_x - min_x + 1)
	var span_y: int = max(1, max_y - min_y + 1)

	var lut_img := Image.create(span_x, 1, false, Image.FORMAT_RF)

	for i in range(span_x):
		var x: int = min_x + i
		var first_y: int = -1
		for y in range(min_y, max_y + 1):
			if img.get_pixel(x, y).a > 0.12:
				first_y = y
				break

		var norm_offset: float = 1.0
		if first_y != -1:
			norm_offset = float(first_y - min_y) / float(span_y)

		lut_img.set_pixel(i, 0, Color(norm_offset, 0.0, 0.0, 1.0))

	var lut_tex := ImageTexture.create_from_image(lut_img)
	return {
		"texture": tex,
		"lut": lut_tex,
		"span_x": span_x,
		"span_y": span_y,
		"min_x": min_x,
		"max_x": max_x,
		"min_y": min_y,
		"max_y": max_y
	}

func disparar_transicion_pilotos() -> void:
	is_transitioning = true
	wipe_mat.set_shader_parameter("fade_progress", -0.5)
	solid_bands_root.visible = true
	front_bands_root.visible = true
	trail_display.visible = true

	# Limpiar lienzo previo
	trail_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	trail_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER

	var screen_w: float = get_viewport_rect().size.x
	var duration: float = 0.90
	var delay_step: float = 0.09
	var max_delay: float = 3.0 * delay_step

	var tween := create_tween().set_parallel(true)

	for p in pilot_sprites:
		var spr: Sprite2D = p.sprite
		var mat_back: ShaderMaterial = p.mat_back
		var mat_front: ShaderMaterial = p.mat_front
		var i: int = p.index
		var delay_start: float = abs(i - 3) * delay_step
		var start_x: float = -p.ship_pixel_length * 1.5
		var target_x: float = screen_w + p.ship_pixel_length * 2.0

		spr.position = Vector2(start_x, p.lane_y)
		spr.visible = true

		p.band_back.visible = true
		mat_back.set_shader_parameter("fade_progress", -0.5)
		mat_back.set_shader_parameter("progress", -0.5)

		p.band_front.visible = true
		mat_front.set_shader_parameter("fade_progress", -0.5)
		mat_front.set_shader_parameter("progress", -0.5)

		tween.tween_property(spr, "position:x", target_x, duration) \
			.set_delay(delay_start) \
			.set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)

	# Pausa con pantalla 100% cubierta y luego fade-out sutil de izquierda a derecha
	var total_sweep_time: float = max_delay + duration
	var hold_time: float = 0.40
	var fade_duration: float = 0.70

	var fade_tween := create_tween()
	fade_tween.tween_interval(total_sweep_time + hold_time)
	fade_tween.tween_method(
		func(val: float) -> void:
			wipe_mat.set_shader_parameter("fade_progress", val)
			for p in pilot_sprites:
				p.mat_back.set_shader_parameter("fade_progress", val)
				p.mat_front.set_shader_parameter("fade_progress", val),
		-0.1, 1.45, fade_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	fade_tween.tween_callback(func() -> void:
		for p in pilot_sprites:
			p.sprite.visible = false
			p.sprite.position = Vector2(-p.ship_pixel_length * 2.0, p.lane_y)
			p.band_back.visible = false
			p.band_front.visible = false
			p.mat_back.set_shader_parameter("progress", -0.5)
			p.mat_front.set_shader_parameter("progress", -0.5)
		trail_display.visible = false
		solid_bands_root.visible = false
		front_bands_root.visible = false
		wipe_mat.set_shader_parameter("fade_progress", -0.5)
		is_transitioning = false
		_on_focus_exited()
		if is_instance_valid(orbital_terminal):
			orbital_terminal.reset_terminal()
	)

# ==============================================================================
# 3. GENERADOR DE TEXTURAS EN MEMORIA Y FONDO
# ==============================================================================
func _crear_modulo_texto(palabra: String) -> Dictionary:
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Impact", "Arial Black", "Trebuchet MS", "sans-serif"])
	font.font_weight = 900
	font.font_stretch = 75

	var font_size = 58
	var text_size = font.get_string_size(palabra, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	var dash_width = 36.0
	var dash_height = 12.0
	var spacing = 20.0

	var total_w = int(ceil(text_size.x + spacing + dash_width + spacing))
	var total_h = int(TAPE_HEIGHT)

	var vp = SubViewport.new()
	vp.size = Vector2i(total_w, total_h)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var root = Control.new()
	root.size = Vector2(total_w, total_h)
	vp.add_child(root)

	# Texto
	var label = Label.new()
	label.text = palabra
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(0, (total_h - text_size.y) / 2.0 + 2.0)
	root.add_child(label)

	# Guion sólido y centrado
	var dash = ColorRect.new()
	dash.color = Color.WHITE
	dash.size = Vector2(dash_width, dash_height)
	dash.position = Vector2(text_size.x + spacing, (total_h - dash_height) / 2.0)
	root.add_child(dash)

	add_child(vp)

	return {
		"texture": vp.get_texture(),
		"width": float(total_w)
	}

func _crear_fondo_prueba() -> void:
	var bg = ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.size = Vector2(2500, 1400)
	bg.position = Vector2(-1250, -700)
	bg.color = Color(0.06, 0.07, 0.1, 1.0)
	bg.z_index = -10
	add_child(bg)

func _crear_entorno_hdr() -> void:
	if not has_node("WorldEnvironment"):
		var we := WorldEnvironment.new()
		we.name = "WorldEnvironment"
		we.environment = ORBITAL_ENV
		add_child(we)

func _crear_terminal_orbital() -> void:
	orbital_terminal = ORBITAL_TERMINAL_SCENE.instantiate() as OrbitalIgnitionTerminal
	orbital_terminal.name = "OrbitalIgnitionTerminal"
	# Centrado en el viewport (720x36) en la zona inferior
	orbital_terminal.position = Vector2(-360.0, 160.0)
	orbital_terminal.ignition_committed.connect(_on_orbital_ignition_committed)
	add_child(orbital_terminal)

	hints_label = Label.new()
	hints_label.name = "TerminalHintsLabel"
	hints_label.text = "[TERMINAL ORBITAL DIEGÉTICA] • Click / Hover / Tab (Enclavamiento) • [H] Ocultar/Mostrar Cinta Anterior • [R] Reiniciar"
	hints_label.add_theme_font_size_override("font_size", 12)
	hints_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.95, 0.75))
	hints_label.position = Vector2(-360.0, 210.0)
	add_child(hints_label)

func _on_orbital_ignition_committed() -> void:
	print("[ORBITAL TERMINAL] >>> IGNICIÓN CONFIRMADA EN EL PUENTE DE MANDO <<<")
	if not is_transitioning:
		disparar_transicion_pilotos()
