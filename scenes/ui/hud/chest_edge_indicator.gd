class_name ChestEdgeIndicator
extends Control

## ChestEdgeIndicator.gd
## Muestra una flecha e icono en el borde de la pantalla apuntando al cofre espacial activo más cercano.

@export var player: Player

var active_chest: SpatialChest = null
var current_cost: int = 0
var has_target: bool = false

@onready var panel_container: PanelContainer = $PanelContainer
@onready var icon_rect: TextureRect = $PanelContainer/VBoxContainer/Icon
@onready var distance_label: Label = $PanelContainer/VBoxContainer/DistanceLabel
@onready var arrow_indicator: Polygon2D = $ArrowIndicator

const BOX_SIZE: Vector2 = Vector2(44, 44)
const PADDING: float = 12.0
var _pulse_timer: float = 0.0

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
		style.bg_color = Color(0.04, 0.07, 0.14, 0.88)
		style.border_color = Color(0.0, 0.85, 1.0, 0.9)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		panel_container.add_theme_stylebox_override("panel", style)

	if arrow_indicator:
		arrow_indicator.polygon = PackedVector2Array([
			Vector2(-7, -12),
			Vector2(7, -12),
			Vector2(0, 0)
		])
		arrow_indicator.color = Color(0.0, 0.85, 1.0, 0.95)

func set_player(p: Player) -> void:
	player = p

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		var p_nodes := get_tree().get_nodes_in_group("player")
		if not p_nodes.is_empty():
			player = p_nodes[0] as Player

	_find_nearest_active_chest()

	if not has_target or not is_instance_valid(active_chest) or active_chest.is_opened:
		hide()
		return

	_pulse_timer += delta * 4.0
	var cam: Camera2D = get_viewport().get_camera_2d()
	if not cam:
		hide()
		return

	var vp_size: Vector2 = get_viewport_rect().size
	var cam_pos: Vector2 = cam.global_position
	var chest_world_pos: Vector2 = active_chest.global_position
	var to_chest: Vector2 = chest_world_pos - cam_pos

	var half_w: float = vp_size.x * 0.5
	var half_h: float = vp_size.y * 0.5
	var margin: float = 40.0

	var is_on_screen: bool = (absf(to_chest.x) < (half_w - margin)) and (absf(to_chest.y) < (half_h - margin))

	if is_on_screen:
		# Si ya está visible en pantalla, ocultar el indicador del borde
		hide()
		return

	show()

	# Calcular posición proyectada en el perímetro de la pantalla
	var dir := to_chest.normalized()
	var border_x: float = half_w - PADDING - BOX_SIZE.x * 0.5
	var border_y: float = half_h - PADDING - BOX_SIZE.y * 0.5

	var scale_x: float = border_x / maxf(0.0001, absf(dir.x))
	var scale_y: float = border_y / maxf(0.0001, absf(dir.y))
	var scale_min: float = minf(scale_x, scale_y)

	var edge_offset := dir * scale_min
	var screen_pos: Vector2 = Vector2(half_w, half_h) + edge_offset

	global_position = screen_pos - BOX_SIZE * 0.5

	# Actualizar flecha
	if arrow_indicator:
		arrow_indicator.visible = true
		arrow_indicator.position = BOX_SIZE * 0.5
		arrow_indicator.rotation = dir.angle() + PI * 0.5

	# Actualizar distancia
	if distance_label:
		var dist_m := int(to_chest.length() / 20.0)
		distance_label.text = "%dm" % dist_m

	# Color según tipo de cofre
	_update_theme_by_chest_type()

func _find_nearest_active_chest() -> void:
	if not is_instance_valid(player):
		has_target = false
		return

	var chests := get_tree().get_nodes_in_group("spatial_chests")
	var nearest: SpatialChest = null
	var min_dist_sq: float = INF

	for c in chests:
		if c is SpatialChest and is_instance_valid(c) and not c.is_opened:
			var d_sq: float = player.global_position.distance_squared_to(c.global_position)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				nearest = c

	active_chest = nearest
	has_target = (nearest != null)

func _update_theme_by_chest_type() -> void:
	if not active_chest:
		return
	var col := Color(0.0, 0.85, 1.0, 0.95)
	if active_chest.chest_type == SpatialChest.ChestType.SALVAGE_CAPSULE:
		col = Color(0.85, 0.65, 0.35, 0.95)
	elif active_chest.chest_type == SpatialChest.ChestType.GOLDEN:
		col = Color(1.0, 0.85, 0.25, 1.0)

	if arrow_indicator:
		arrow_indicator.color = col
	if icon_rect:
		icon_rect.modulate = col
