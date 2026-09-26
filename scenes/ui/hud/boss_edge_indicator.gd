class_name BossEdgeIndicator
extends Control

## Indicador perimetral de pantalla para Jefes y Rivales fuera de visión.
## Se oculta automáticamente cuando el jefe/rival entra dentro del viewport de la cámara.

@export var player: Node2D

var tracked_target: Node2D = null
var active_target_pos: Vector2 = Vector2.ZERO
var has_target: bool = false
var target_title: String = "JEFE"

@onready var panel_container: PanelContainer = $PanelContainer
@onready var icon_rect: Control = $PanelContainer/VBoxContainer/Icon
@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var distance_label: Label = $PanelContainer/VBoxContainer/DistanceLabel
@onready var arrow_indicator: Polygon2D = $ArrowIndicator

const BOX_SIZE: Vector2 = Vector2(75, 75)
const PADDING: float = 12.0

var _pulse_timer: float = 0.0
var ping_timer: float = 0.0
const PING_INTERVAL: float = 6.0
var _ping_ring_radius: float = 0.0
var _ping_ring_alpha: float = 0.0
var _ping_tween: Tween = null

func _draw() -> void:
	if _ping_ring_alpha > 0.01:
		draw_arc(BOX_SIZE * 0.5, _ping_ring_radius, 0.0, TAU, 36, Color(1.0, 0.05, 0.25, _ping_ring_alpha), 3.0)

	# Dibujar retículo y calavera táctica procedural en el centro del indicador
	var center := Vector2(BOX_SIZE.x * 0.5, 34.0)
	var sc := Color(1.0, 0.1, 0.32, 0.95)
	var glow := Color(1.0, 0.05, 0.25, 0.35)

	# Anillo y retículo
	draw_arc(center, 13.0, 0.0, TAU, 24, glow, 2.5)
	draw_arc(center, 13.0, 0.0, TAU, 24, sc, 1.2)
	draw_line(center + Vector2(0, -16), center + Vector2(0, -11), sc, 1.5)
	draw_line(center + Vector2(0, 11), center + Vector2(0, 16), sc, 1.5)
	draw_line(center + Vector2(-16, 0), center + Vector2(-11, 0), sc, 1.5)
	draw_line(center + Vector2(11, 0), center + Vector2(16, 0), sc, 1.5)

	# Cabeza calavera
	draw_circle(center + Vector2(0, -2), 7.0, Color(0.2, 0.03, 0.07, 0.9))
	draw_arc(center + Vector2(0, -2), 7.0, 0.0, TAU, 16, sc, 1.8)

	# Mandíbula
	var jaw := Rect2(center.x - 3.5, center.y + 3.0, 7.0, 4.5)
	draw_rect(jaw, Color(0.2, 0.03, 0.07, 0.9), true)
	draw_rect(jaw, sc, false, 1.5)

	# Cuencas de ojos
	draw_circle(center + Vector2(-2.5, -3.0), 1.6, Color(1.0, 0.15, 0.35, 1.0))
	draw_circle(center + Vector2(2.5, -3.0), 1.6, Color(1.0, 0.15, 0.35, 1.0))

	# Dientes
	draw_line(center + Vector2(-1.5, 4.0), center + Vector2(-1.5, 7.0), sc, 1.0)
	draw_line(center + Vector2(1.5, 4.0), center + Vector2(1.5, 7.0), sc, 1.0)

func _ready() -> void:
	custom_minimum_size = BOX_SIZE
	size = BOX_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

	if panel_container:
		panel_container.custom_minimum_size = BOX_SIZE
		panel_container.size = BOX_SIZE
		panel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.02, 0.04, 0.92)
		style.border_color = Color(1.0, 0.08, 0.25, 0.98)
		style.set_border_width_all(3)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(2.0)
		style.shadow_color = Color(1.0, 0.0, 0.2, 0.45)
		style.shadow_size = 6
		panel_container.add_theme_stylebox_override("panel", style)

func set_target_node(target: Node2D, title: String = "JEFE") -> void:
	tracked_target = target
	target_title = title
	has_target = is_instance_valid(target)
	if has_target:
		active_target_pos = target.global_position
		trigger_ping()
	else:
		hide()

func set_target_pos(pos: Vector2, title: String = "JEFE") -> void:
	tracked_target = null
	active_target_pos = pos
	target_title = title
	has_target = true
	trigger_ping()

func clear_target() -> void:
	tracked_target = null
	has_target = false
	ping_timer = 0.0
	if _ping_tween and _ping_tween.is_valid():
		_ping_tween.kill()
	_ping_ring_alpha = 0.0
	queue_redraw()
	hide()

func get_tracked_node() -> Node2D:
	return tracked_target

func set_player(p: Node2D) -> void:
	player = p

func trigger_ping() -> void:
	if not has_target:
		return
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.2)

	if panel_container:
		panel_container.pivot_offset = BOX_SIZE * 0.5
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel_container, "scale", Vector2(1.35, 1.35), 0.12)
		tw.tween_property(panel_container, "scale", Vector2(1.0, 1.0), 0.28)

	if _ping_tween and _ping_tween.is_valid():
		_ping_tween.kill()
	_ping_ring_radius = 28.0
	_ping_ring_alpha = 1.0
	_ping_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_ping_tween.tween_property(self, "_ping_ring_radius", 95.0, 0.9)
	_ping_tween.tween_property(self, "_ping_ring_alpha", 0.0, 0.9)
	_ping_tween.chain().tween_callback(queue_redraw)

func _get_target_pos() -> Vector2:
	if is_instance_valid(tracked_target):
		active_target_pos = tracked_target.global_position
	return active_target_pos

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

func _process(delta: float) -> void:
	if not has_target:
		hide()
		return

	if tracked_target != null and not is_instance_valid(tracked_target):
		clear_target()
		return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		if not is_instance_valid(player):
			hide()
			return

	# Ocultar si hay menús modales
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

	var target_pos := _get_target_pos()
	var dist := player.global_position.distance_to(target_pos)

	if title_label:
		title_label.text = target_title

	if distance_label:
		if dist <= 250.0:
			distance_label.text = "PELIGRO"
			distance_label.add_theme_color_override("font_color", Color("#FF0033"))
		else:
			distance_label.text = "%dm" % int(dist)
			distance_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85, 0.95))

	var player_screen := world_to_screen(player.global_position)
	var target_screen := world_to_screen(target_pos)

	var vp_rect := get_viewport().get_visible_rect()
	var vp_size := vp_rect.size

	var half_w := BOX_SIZE.x * 0.5
	var half_h := BOX_SIZE.y * 0.5
	var pad := PADDING

	var min_x := half_w + pad
	var max_x := vp_size.x - half_w - pad
	var min_y := half_h + pad
	var max_y := vp_size.y - half_h - pad

	# Comprobación de si está dentro de la pantalla
	var is_on_screen: bool = (target_screen.x >= min_x and target_screen.x <= max_x and target_screen.y >= min_y and target_screen.y <= max_y)

	if is_on_screen:
		# REGLA: Si el jefe está dentro de pantalla, se oculta para no estorbar el combate
		hide()
		return

	# Fuera de pantalla: calcular punto de contacto con el borde
	var origin := player_screen.clamp(Vector2(min_x, min_y), Vector2(max_x, max_y))
	var dir := target_screen - player_screen
	if dir.length_squared() < 0.001:
		dir = Vector2.UP

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

	global_position = border_pos - BOX_SIZE * 0.5

	if arrow_indicator:
		arrow_indicator.visible = true
		var angle := dir.angle()
		arrow_indicator.rotation = angle
		arrow_indicator.position = BOX_SIZE * 0.5 + Vector2(cos(angle), sin(angle)) * (half_w + 4.0)

	_pulse_timer += delta * (8.0 if dist <= 400.0 else 4.0)
	var pulse := (sin(_pulse_timer) + 1.0) * 0.5
	modulate = Color(1.0, 1.0, 1.0, 0.85 + 0.15 * pulse)

	show()
