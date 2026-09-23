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
	show()

func clear_target() -> void:
	has_satellite = false
	hide()

func set_player(p: Player) -> void:
	player = p

func _get_closest_satellite_pos() -> Vector2:
	var satellites := get_tree().get_nodes_in_group("satellite_beacon")
	if satellites.is_empty():
		return active_satellite_pos

	if not is_instance_valid(player):
		return active_satellite_pos

	var closest_pos := active_satellite_pos
	var min_d := INF
	for sat in satellites:
		if is_instance_valid(sat) and sat is Node2D:
			var d := player.global_position.distance_to(sat.global_position)
			if d < min_d:
				min_d = d
				closest_pos = sat.global_position
	return closest_pos

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

	var target_pos := _get_closest_satellite_pos()
	var dist := player.global_position.distance_to(target_pos)

	# Actualización del texto y estilo de distancia
	if dist <= 180.0:
		distance_label.text = "CERCA"
		distance_label.add_theme_color_override("font_color", Color("#00FF9D"))
	else:
		distance_label.text = "%dm" % int(dist)
		distance_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))

	# Coordenadas de pantalla del jugador y del satélite
	var canvas_xform: Transform2D = get_viewport().get_canvas_transform()
	var player_screen: Vector2 = canvas_xform * player.global_position
	var sat_screen: Vector2 = canvas_xform * target_pos

	var vp_rect := get_viewport().get_visible_rect()
	var vp_size := vp_rect.size

	var half_w := BOX_SIZE.x * 0.5
	var half_h := BOX_SIZE.y * 0.5
	var pad := PADDING

	var min_x := half_w + pad
	var max_x := vp_size.x - half_w - pad
	var min_y := half_h + pad
	var max_y := vp_size.y - half_h - pad

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
