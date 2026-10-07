class_name SceneTransitionClass
extends CanvasLayer

## SceneTransition.gd
## Autoload global para transiciones de pantalla con barrido cinemático en V de 7 pilotos.
## Implementa buffer de estela continuo (SubViewport a 60 FPS), perfil anatómico LUT 1D,
## y cobertura total para intercambio asíncrono de escenas sin saltos ni cortes.

signal transition_started
signal screen_covered
signal transition_finished

const SHADER_WIPE: Shader = preload("res://shaders/ui/trail_wipe.gdshader")
const SHADER_SOLID_TINT: Shader = preload("res://shaders/ui/pilot_solid_tint.gdshader")
const SHADER_BRUSH: Shader = preload("res://shaders/ui/brush_trail.gdshader")
const SHIPS_DIR: String = "res://assets/characters/ships/"

# Configuración cromática de las 7 heroínas (Nova en índice 3 como punta de flecha en V)
const PILOT_CONFIG: Array[Dictionary] = [
	{"name": "echo",      "color": Color(0.12, 0.85, 0.95)}, # Cian
	{"name": "kira",      "color": Color(0.95, 0.78, 0.12)}, # Amarillo
	{"name": "nyx",       "color": Color(0.60, 0.20, 0.88)}, # Violeta
	{"name": "nova",      "color": Color(1.00, 0.40, 0.05)}, # Naranja (Punta de V)
	{"name": "roxy",      "color": Color(0.90, 0.14, 0.22)}, # Rojo
	{"name": "selene",    "color": Color(0.35, 0.25, 0.75)}, # Índigo
	{"name": "valentina", "color": Color(0.18, 0.45, 0.90)}  # Azul cobalto
]

var is_transitioning: bool = false

var _transition_root: Control = null
var _solid_bands_root: Control = null
var _front_bands_root: Control = null
var _trail_viewport: SubViewport = null
var _trail_display: TextureRect = null
var _wipe_mat: ShaderMaterial = null

var _pilot_lanes: Array[Dictionary] = []
var _lut_cache: Dictionary = {}
var _cached_screen_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_build_hierarchy()
	_precalculate_luts()
	_setup_lanes()


func _build_hierarchy() -> void:
	_transition_root = Control.new()
	_transition_root.name = "TransitionRoot"
	_transition_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_root.visible = false
	add_child(_transition_root)

	_solid_bands_root = Control.new()
	_solid_bands_root.name = "SolidBandsRoot"
	_solid_bands_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_solid_bands_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_solid_bands_root.visible = false
	_transition_root.add_child(_solid_bands_root)

	_trail_viewport = SubViewport.new()
	_trail_viewport.name = "TrailViewport"
	_trail_viewport.transparent_bg = true
	_trail_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_trail_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_trail_viewport)

	_wipe_mat = ShaderMaterial.new()
	_wipe_mat.shader = SHADER_WIPE
	_wipe_mat.set_shader_parameter("fade_progress", -0.5)
	_wipe_mat.set_shader_parameter("fade_feather", 0.38)

	_trail_display = TextureRect.new()
	_trail_display.name = "TrailDisplay"
	_trail_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trail_display.texture = _trail_viewport.get_texture()
	_trail_display.material = _wipe_mat
	_trail_display.visible = false
	_transition_root.add_child(_trail_display)

	_front_bands_root = Control.new()
	_front_bands_root.name = "FrontBandsRoot"
	_front_bands_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front_bands_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_front_bands_root.visible = false
	_transition_root.add_child(_front_bands_root)


func _precalculate_luts() -> void:
	for cfg in PILOT_CONFIG:
		var pilot_name: String = cfg.name
		var ship_path: String = SHIPS_DIR + "ship_%s.png" % pilot_name
		if ResourceLoader.exists(ship_path):
			_lut_cache[pilot_name] = _generate_ship_lut(ship_path)


func _setup_lanes() -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = Vector2(1920.0, 1080.0)
	_cached_screen_size = screen_size
	
	_trail_viewport.size = Vector2i(int(screen_size.x), int(screen_size.y))
	_trail_display.size = screen_size

	for child in _solid_bands_root.get_children():
		child.queue_free()
	for child in _front_bands_root.get_children():
		child.queue_free()
	for child in _trail_viewport.get_children():
		child.queue_free()
	_pilot_lanes.clear()

	var band_height: float = ceil(screen_size.y / float(PILOT_CONFIG.size()))

	for i in range(PILOT_CONFIG.size()):
		var cfg: Dictionary = PILOT_CONFIG[i]
		var pilot_name: String = cfg.name
		var lut_data: Dictionary = _lut_cache.get(pilot_name, {})
		if lut_data.is_empty():
			continue

		var tex: Texture2D = lut_data.texture
		var lut_tex: ImageTexture = lut_data.lut
		var span_x: int = lut_data.span_x
		var span_y: int = lut_data.span_y

		var scale_factor: float = band_height / float(maxi(1, span_x))
		var ship_pixel_length: float = float(span_y) * scale_factor
		var ship_length_norm: float = ship_pixel_length / screen_size.x

		# Sprite en viewport para after-images
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
		_trail_viewport.add_child(spr)

		# 1. Banda continua de fondo con perfil anatómico
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
		_solid_bands_root.add_child(band_back)

		# 2. Banda frontal rezagada 1 piloto con perfil anatómico
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
		_front_bands_root.add_child(band_front)

		_pilot_lanes.append({
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


func _generate_ship_lut(ship_path: String) -> Dictionary:
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
				if first_y == -1:
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


func _process(delta: float) -> void:
	if not is_transitioning:
		return

	var screen_w: float = _cached_screen_size.x
	for p in _pilot_lanes:
		var spr: Sprite2D = p.sprite
		var mat: ShaderMaterial = p.material
		var base_c: Color = p.base_color

		var lum_shift: float = sin(spr.position.x * 0.035) * 0.08
		mat.set_shader_parameter("tint_color", base_c + Color(lum_shift, lum_shift, lum_shift, 0.0))

		var norm_x: float = spr.position.x / screen_w
		p.mat_back.set_shader_parameter("progress", norm_x + (p.ship_length_norm * 0.5))
		p.mat_front.set_shader_parameter("progress", norm_x - (p.ship_length_norm * 0.5))


## Cambia de escena asíncronamente ejecutando la cinemática de barrido en V
func change_scene_to_file(target_scene_path: String) -> void:
	if is_transitioning:
		return

	await play_wipe(func() -> void:
		get_tree().change_scene_to_file(target_scene_path)
	)


## Ejecuta el barrido de transición y llama a on_covered_callback en cobertura máxima
func play_wipe(on_covered_callback: Callable = Callable()) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	transition_started.emit()

	var current_screen_size: Vector2 = get_viewport().get_visible_rect().size
	if current_screen_size != _cached_screen_size:
		_setup_lanes()

	_transition_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_transition_root.visible = true
	_solid_bands_root.visible = true
	_front_bands_root.visible = true
	_trail_display.visible = true
	_wipe_mat.set_shader_parameter("fade_progress", -0.5)

	# Limpiar buffer de after-images previo
	_trail_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	_trail_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER

	var screen_w: float = _cached_screen_size.x
	var duration: float = 0.90
	var delay_step: float = 0.09
	var max_delay: float = 3.0 * delay_step

	var tween := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	for p in _pilot_lanes:
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

	# Esperar a que la última piloto cubra completamente la pantalla
	var total_sweep_time: float = max_delay + duration
	await get_tree().create_timer(total_sweep_time, true, false, true).timeout

	screen_covered.emit()

	if on_covered_callback.is_valid():
		on_covered_callback.call()
		# Pausa de estabilidad para inicialización de la nueva escena
		await get_tree().process_frame
		await get_tree().process_frame

	var hold_time: float = 0.10
	await get_tree().create_timer(hold_time, true, false, true).timeout

	# Fase 2: Fade-out sutil de izquierda a derecha
	var fade_duration: float = 0.40
	var fade_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_tween.tween_method(
		func(val: float) -> void:
			_wipe_mat.set_shader_parameter("fade_progress", val)
			for p in _pilot_lanes:
				p.mat_back.set_shader_parameter("fade_progress", val)
				p.mat_front.set_shader_parameter("fade_progress", val),
		-0.1, 1.45, fade_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await fade_tween.finished

	# Limpieza y restauración de estado
	for p in _pilot_lanes:
		p.sprite.visible = false
		p.sprite.position = Vector2(-p.ship_pixel_length * 2.0, p.lane_y)
		p.band_back.visible = false
		p.band_front.visible = false
		p.mat_back.set_shader_parameter("progress", -0.5)
		p.mat_front.set_shader_parameter("progress", -0.5)

	_trail_display.visible = false
	_solid_bands_root.visible = false
	_front_bands_root.visible = false
	_transition_root.visible = false
	_transition_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe_mat.set_shader_parameter("fade_progress", -0.5)

	is_transitioning = false
	transition_finished.emit()
