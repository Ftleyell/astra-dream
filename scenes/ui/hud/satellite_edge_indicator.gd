class_name SatelliteEdgeIndicator
extends Control

@export var player: Player

var active_satellite_pos: Vector2 = Vector2.ZERO
var has_satellite: bool = false
var satellite_index: int = 1

@onready var panel_container: PanelContainer = $PanelContainer
@onready var icon_rect: TextureRect = $PanelContainer/VBoxContainer/Icon
@onready var distance_label: Label = $PanelContainer/VBoxContainer/DistanceLabel
@onready var arrow_indicator: Polygon2D = $ArrowIndicator

const BOX_SIZE: Vector2 = Vector2(50, 50)
const PADDING: float = 8.0

var _pulse_timer: float = 0.0
var ping_timer: float = 0.0
const PING_INTERVAL: float = 10.0
var _ping_ring_radius: float = 0.0
var _ping_ring_alpha: float = 0.0
var _ping_tween: Tween = null

func _draw() -> void:
	if _ping_ring_alpha > 0.01:
		draw_arc(BOX_SIZE * 0.5, _ping_ring_radius, 0.0, TAU, 36, Color(0.0, 0.95, 1.0, _ping_ring_alpha), 2.5)

func _ready() -> void:
	custom_minimum_size = BOX_SIZE
	size = BOX_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

	# Configuración visual de estilo ciberpunk translúcido
	if panel_container:
		panel_container.custom_minimum_size = BOX_SIZE
		panel_container.size = BOX_SIZE
		panel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.08, 0.16, 0.88)
		style.border_color = Color(0.0, 0.92, 1.0, 0.95)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(2.0)
		style.shadow_color = Color(0.0, 0.8, 1.0, 0.3)
		style.shadow_size = 4
		panel_container.add_theme_stylebox_override("panel", style)

func set_target(pos: Vector2, index: int) -> void:
	active_satellite_pos = pos
	satellite_index = index
	has_satellite = true
	ping_timer = 0.0
	show()
	trigger_ping()

func trigger_ping() -> void:
	if not has_satellite:
		return
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.6)

	if panel_container:
		panel_container.pivot_offset = BOX_SIZE * 0.5
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel_container, "scale", Vector2(1.3, 1.3), 0.1)
		tw.tween_property(panel_container, "scale", Vector2(1.0, 1.0), 0.25)

	if _ping_tween and _ping_tween.is_valid():
		_ping_tween.kill()
	_ping_ring_radius = 22.0
	_ping_ring_alpha = 1.0
	_ping_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_ping_tween.tween_property(self, "_ping_ring_radius", 75.0, 0.85)
	_ping_tween.tween_property(self, "_ping_ring_alpha", 0.0, 0.85)
	_ping_tween.chain().tween_callback(queue_redraw)

func clear_target() -> void:
	has_satellite = false
	ping_timer = 0.0
	if _ping_tween and _ping_tween.is_valid():
		_ping_tween.kill()
	_ping_ring_alpha = 0.0
	queue_redraw()
	hide()

func set_player(p: Player) -> void:
	player = p

func _get_closest_satellite_pos() -> Vector2:
	return active_satellite_pos

func _get_main_game() -> MainGame:
	var mg := get_tree().get_first_node_in_group("main_game") as MainGame
	if mg:
		return mg
	var n: Node = self
	while n != null:
		if n is MainGame:
			return n as MainGame
		n = n.get_parent()
	return null

func _get_active_camera() -> Camera2D:
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam
	return get_tree().get_first_node_in_group("camera") as Camera2D

func world_to_screen(world_pos: Vector2) -> Vector2:
	var cam := _get_active_camera()
	var vp_size := get_viewport().get_visible_rect().size
	var screen_center := vp_size * 0.5
	if cam:
		var cam_center := cam.get_screen_center_position()
		return screen_center + (world_pos - cam_center) * cam.zoom
	elif is_instance_valid(player):
		return screen_center + (world_pos - player.global_position)
	return world_pos

func _process(delta: float) -> void:
	if not has_satellite:
		hide()
		return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if not is_instance_valid(player):
			hide()
			return

	# Ocultar si hay menús de combate sobrepuestos (pausa, level-up, tienda)
	var parent_game := _get_main_game()
	if parent_game and parent_game.has_method("is_any_combat_modal_active") and parent_game.is_any_combat_modal_active():
		hide()
		return

	if _ping_ring_alpha > 0.01:
		queue_redraw()

	ping_timer += delta
	if ping_timer >= PING_INTERVAL:
		ping_timer = 0.0
		trigger_ping()

	var target_pos := _get_closest_satellite_pos()
	var dist := player.global_position.distance_to(target_pos)

	# Actualización del texto y estilo de distancia
	if dist <= 180.0:
		distance_label.text = "CERCA"
		distance_label.add_theme_color_override("font_color", Color("#00FF9D"))
	else:
		distance_label.text = "%dm" % int(dist)
		distance_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))

	# Coordenadas exactas en pantalla de jugador y satélite basadas en la cámara 2D activa
	var player_screen := world_to_screen(player.global_position)
	var sat_screen := world_to_screen(target_pos)

	var vp_rect := get_viewport().get_visible_rect()
	var vp_size := vp_rect.size

	var half_w := BOX_SIZE.x * 0.5
	var half_h := BOX_SIZE.y * 0.5
	var pad := PADDING

	var min_x := half_w + pad
	var max_x := vp_size.x - half_w - pad
	var min_y := half_h + pad
	var max_y := vp_size.y - half_h - pad

	# Comprobación de si el satélite está dentro del área visible de la pantalla
	var is_on_screen: bool = (sat_screen.x >= min_x and sat_screen.x <= max_x and sat_screen.y >= min_y and sat_screen.y <= max_y)

	if is_on_screen:
		# Al aparecer el satélite en pantalla: soltarse del borde y quedar DEAD CENTER sobre el mismo
		global_position = sat_screen - BOX_SIZE * 0.5
		if arrow_indicator:
			arrow_indicator.visible = false
	else:
		# Fuera de pantalla: desplazarse por el borde en el punto de contacto entre jugador y satélite
		var origin := player_screen.clamp(Vector2(min_x, min_y), Vector2(max_x, max_y))
		var dir := sat_screen - player_screen
		if dir.length_squared() < 0.001:
			dir = Vector2.UP

		# Intersección matemática entre el rayo jugador->satélite y los 4 bordes de la pantalla
		var t: float = 1e9
		if dir.x > 0.0001:
			var tx := (max_x - origin.x) / dir.x
			if tx > 0.0: t = minf(t, tx)
		elif dir.x < -0.0001:
			var tx := (min_x - origin.x) / dir.x
			if tx > 0.0: t = minf(t, tx)

		if dir.y > 0.0001:
			var ty := (max_y - origin.y) / dir.y
			if ty > 0.0: t = minf(t, ty)
		elif dir.y < -0.0001:
			var ty := (min_y - origin.y) / dir.y
			if ty > 0.0: t = minf(t, ty)

		if t >= 1e8:
			t = 0.0

		var border_pos := origin + dir * t
		border_pos.x = clampf(border_pos.x, min_x, max_x)
		border_pos.y = clampf(border_pos.y, min_y, max_y)

		# El cuadradito se posiciona centrado en el punto de contacto con el borde
		global_position = border_pos - BOX_SIZE * 0.5

		# Actualización del puntero direccional apuntando hacia el satélite
		if arrow_indicator:
			arrow_indicator.visible = true
			var angle := dir.angle()
			arrow_indicator.rotation = angle
			arrow_indicator.position = BOX_SIZE * 0.5 + Vector2(cos(angle), sin(angle)) * (half_w + 3.0)

	# Pulso suave en la frontera cuando el jugador está en camino
	_pulse_timer += delta * (6.0 if dist <= 300.0 else 3.0)
	var pulse := (sin(_pulse_timer) + 1.0) * 0.5
	if dist <= 180.0:
		modulate = Color(1.0, 1.0, 1.0, 0.9 + 0.1 * pulse)
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.85 + 0.15 * pulse)

	show()
