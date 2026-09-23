class_name ArcanaEdgeIndicator
extends Control

## ArcanaEdgeIndicator.gd
## Indicador direccional de borde de pantalla para rastrear Monolitos Arcanos activos en el espacio.
## Estilizado con la paleta mística Psycho-Pop (magenta brillante #FF1493 y cian neón #00F0FF).
## Se ancla al borde cuando el Monolito está fuera de pantalla y se oculta automáticamente cuando entra en visión.

@export var player: CharacterBody2D

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

	# Configuración visual de estilo Psycho-Pop místico translúcido con borde recto
	if panel_container:
		panel_container.custom_minimum_size = BOX_SIZE
		panel_container.size = BOX_SIZE
		panel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.02, 0.16, 0.90)
		style.border_color = Color("#FF1493")
		style.set_border_width_all(2)
		style.set_corner_radius_all(0) # Borde recto
		style.set_content_margin_all(2.0)
		style.shadow_color = Color(1.0, 0.08, 0.58, 0.35)
		style.shadow_size = 4
		panel_container.add_theme_stylebox_override("panel", style)


func set_player(p: Node2D) -> void:
	player = p as CharacterBody2D


func get_closest_monolith() -> Node2D:
	if not is_inside_tree():
		return null
	var monoliths := get_tree().get_nodes_in_group("monoliths")
	if monoliths.is_empty():
		return null

	var valid_monoliths: Array[Node2D] = []
	for m in monoliths:
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			if not bool(m.get("is_dying")):
				valid_monoliths.append(m as Node2D)

	if valid_monoliths.is_empty():
		return null

	var p_pos := player.global_position if is_instance_valid(player) else Vector2.ZERO
	var closest: Node2D = valid_monoliths[0]
	var min_dist := p_pos.distance_squared_to(closest.global_position)
	for i in range(1, valid_monoliths.size()):
		var d := p_pos.distance_squared_to(valid_monoliths[i].global_position)
		if d < min_dist:
			min_dist = d
			closest = valid_monoliths[i]
	return closest


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
	if not is_inside_tree():
		hide()
		return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D
		if not is_instance_valid(player):
			hide()
			return

	# Ocultar si hay modales de combate sobrepuestos
	var parent_game := _get_main_game()
	if parent_game and parent_game.has_method("is_any_combat_modal_active") and parent_game.is_any_combat_modal_active():
		hide()
		return

	var target_monolith := get_closest_monolith()
	if not is_instance_valid(target_monolith):
		hide()
		return

	var target_pos := target_monolith.global_position
	var dist := player.global_position.distance_to(target_pos)

	# Actualización del texto y estilo de distancia
	if dist <= 200.0:
		distance_label.text = "CERCA"
		distance_label.add_theme_color_override("font_color", Color("#00F0FF"))
	else:
		distance_label.text = "%dm" % int(dist)
		distance_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))

	var player_screen := world_to_screen(player.global_position)
	var mon_screen := world_to_screen(target_pos)

	var vp_rect := get_viewport().get_visible_rect()
	var vp_size := vp_rect.size

	var half_w := BOX_SIZE.x * 0.5
	var half_h := BOX_SIZE.y * 0.5
	var pad := PADDING

	var min_x := half_w + pad
	var max_x := vp_size.x - half_w - pad
	var min_y := half_h + pad
	var max_y := vp_size.y - half_h - pad

	# Si el monolito está dentro de pantalla, se oculta limpiamente
	var is_on_screen: bool = (mon_screen.x >= 0.0 and mon_screen.x <= vp_size.x and mon_screen.y >= 0.0 and mon_screen.y <= vp_size.y)
	if is_on_screen:
		hide()
		return

	# Si está fuera de pantalla: se ancla en el borde proyectando la trayectoria hacia el monolito
	var origin := player_screen.clamp(Vector2(min_x, min_y), Vector2(max_x, max_y))
	var dir := mon_screen - player_screen
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
		arrow_indicator.position = BOX_SIZE * 0.5 + Vector2(cos(angle), sin(angle)) * (half_w + 3.0)

	# Pulso místico Psycho-Pop
	_pulse_timer += delta * (5.0 if dist <= 350.0 else 2.5)
	var pulse := (sin(_pulse_timer) + 1.0) * 0.5
	modulate = Color(1.0, 1.0, 1.0, 0.85 + 0.15 * pulse)

	show()
