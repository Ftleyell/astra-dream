class_name SatelliteBeacon
extends Node2D

@export var satellite_index: int = 1
@export var activation_radius: float = 180.0
@export var core_bump_radius: float = 60.0
@export var plant_duration: float = 6.0

var is_planted: bool = false
var is_ready: bool = false
var current_charge: float = 0.0
var player_inside: bool = false
var _cached_player: Node2D = null
var _is_tearing_down: bool = false
var _bump_cooldown: float = 0.0
var ping_timer: float = 0.0
const PING_INTERVAL: float = 10.0
var _ping_line: Line2D = null
var _charge_arc: Line2D = null
var _charge_expanding_circle: Line2D = null
var _status_label: Label = null

signal planted(index: int, pos: Vector2)
signal exited_perimeter(index: int)

@onready var area: Area2D = $PerimeterArea
@onready var visual_core: CanvasItem = $VisualCore
@onready var radius_visual: Line2D = $RadiusVisual

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("satellite_beacon")
	scale = Vector2(2.0, 2.0)
	check_orbital_relay()
	_draw_radius_circle()
	_setup_ping_line()
	_setup_charge_arc()
	_setup_charge_expanding_circle()
	_setup_status_label()
	trigger_beacon_ping()
	if is_instance_valid(area):
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

func check_orbital_relay(player_override: Node = null) -> void:
	var target_player: Node = player_override if player_override else (get_tree().get_first_node_in_group("player") if get_tree() else null)
	if target_player and "inventory" in target_player and target_player.inventory:
		if target_player.inventory.has_method("get_item_count") and target_player.inventory.get_item_count(&"orbital_relay") > 0:
			plant_duration = 4.0
		else:
			plant_duration = 6.0

func _setup_ping_line() -> void:
	_ping_line = Line2D.new()
	_ping_line.width = 3.0
	_ping_line.default_color = Color(0.0, 0.95, 1.0, 0.0)
	add_child(_ping_line)

func _setup_charge_arc() -> void:
	_charge_arc = Line2D.new()
	_charge_arc.width = 4.0
	_charge_arc.default_color = Color(0.0, 0.95, 1.0, 0.9)
	add_child(_charge_arc)

func _setup_charge_expanding_circle() -> void:
	_charge_expanding_circle = Line2D.new()
	_charge_expanding_circle.width = 3.5
	_charge_expanding_circle.default_color = Color(0.1, 0.9, 1.0, 0.75)
	add_child(_charge_expanding_circle)

func _setup_status_label() -> void:
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.position = Vector2(-75.0, -activation_radius - 22.0)
	_status_label.size = Vector2(150.0, 20.0)
	_status_label.modulate = Color(0.3, 0.9, 1.0, 0.9)
	_status_label.text = "[SATÉLITE EN ESPERA]"
	add_child(_status_label)

func trigger_beacon_ping() -> void:
	if is_planted or _is_tearing_down or not _ping_line:
		return
	_ping_line.clear_points()
	var points: int = 36
	for i in range(points + 1):
		var angle := float(i) * TAU / float(points)
		_ping_line.add_point(Vector2(cos(angle), sin(angle)) * 20.0)
	_ping_line.default_color = Color(0.0, 0.95, 1.0, 0.9)
	_ping_line.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_property(_ping_line, "scale", Vector2(activation_radius / 20.0, activation_radius / 20.0), 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_ping_line, "default_color:a", 0.0, 1.2)

func _process(delta: float) -> void:
	if _is_tearing_down:
		return

	if get_tree() and get_tree().paused:
		return

	var tree := get_tree()
	if tree:
		var mg := tree.get_first_node_in_group("main_game")
		if mg and mg.has_method("is_any_combat_modal_active") and mg.is_any_combat_modal_active():
			return

	if _bump_cooldown > 0.0:
		_bump_cooldown -= delta

	# Ping radial periódico mientras no esté listo
	if not is_ready:
		ping_timer += delta
		if ping_timer >= PING_INTERVAL:
			ping_timer = 0.0
			trigger_beacon_ping()

	# Proceso de carga por permanencia en el perímetro
	if not is_ready:
		if player_inside:
			current_charge = minf(plant_duration, current_charge + delta)
			var progress := current_charge / maxf(0.1, plant_duration)
			_update_charge_arc(progress)
			if _status_label:
				_status_label.text = "[CARGANDO %d%%]" % int(progress * 100.0)
				_status_label.modulate = Color(0.0, 0.95, 1.0, 1.0)

			if current_charge >= plant_duration:
				_on_charge_completed()
		else:
			if current_charge > 0.0 and _status_label:
				var progress := current_charge / maxf(0.1, plant_duration)
				_status_label.text = "[PAUSA %d%%]" % int(progress * 100.0)
				_status_label.modulate = Color(1.0, 0.8, 0.2, 0.85)
	else:
		# Estado READY o TIENDA ABIERTA: Detección de bumpeo con el núcleo del jugador
		_check_core_bump()

func _update_charge_arc(progress: float) -> void:
	if _charge_arc:
		_charge_arc.clear_points()
		if progress > 0.01:
			var total_points: int = 40
			var points_to_draw: int = int(float(total_points) * progress)
			points_to_draw = clampi(points_to_draw, 2, total_points + 1)
			for i in range(points_to_draw):
				var angle: float = -PI / 2.0 + (float(i) / float(total_points)) * TAU
				_charge_arc.add_point(Vector2(cos(angle), sin(angle)) * activation_radius)

	# Círculo de neón que se abre y expande desde el centro hacia el perímetro
	if _charge_expanding_circle:
		_charge_expanding_circle.clear_points()
		if progress > 0.005:
			var cur_radius: float = activation_radius * clampf(progress, 0.0, 1.0)
			var circle_points: int = 36
			for i in range(circle_points + 1):
				var ang: float = float(i) * TAU / float(circle_points)
				_charge_expanding_circle.add_point(Vector2(cos(ang), sin(ang)) * cur_radius)
			_charge_expanding_circle.default_color = Color(0.1, 0.95, 1.0, lerpf(0.35, 0.95, progress))
			_charge_expanding_circle.width = lerpf(2.0, 4.5, progress)

func _on_charge_completed() -> void:
	is_ready = true
	_update_charge_arc(1.0)
	if _charge_arc:
		_charge_arc.default_color = Color(0.2, 1.0, 0.4, 0.95)
	if _charge_expanding_circle:
		_charge_expanding_circle.default_color = Color(0.2, 1.0, 0.4, 0.85)
		_charge_expanding_circle.width = 4.0
	if radius_visual:
		radius_visual.default_color = Color(0.2, 1.0, 0.4, 0.6)
	if visual_core:
		visual_core.modulate = Color(0.6, 1.3, 0.8, 1.0)
	if _status_label:
		_status_label.text = "[¡LISTO! - BUMPEAR]"
		_status_label.modulate = Color(0.2, 1.0, 0.4, 1.0)

	# Pulso visual de confirmación READY
	var tw := create_tween()
	tw.tween_property(visual_core, "scale", Vector2(0.32, 0.32), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual_core, "scale", Vector2(0.24, 0.24), 0.2)

func _check_core_bump() -> void:
	if not is_ready or _bump_cooldown > 0.0:
		return
	var player_node := _get_player_node()
	if not player_node or not is_instance_valid(player_node):
		return

	# Distancia euclidiana al núcleo (ajustada por escala de la escena)
	var effective_bump_dist: float = core_bump_radius * scale.x
	if global_position.distance_to(player_node.global_position) <= effective_bump_dist:
		_bump_cooldown = 0.8
		plant_satellite()

func _get_player_node() -> Node2D:
	if _cached_player and is_instance_valid(_cached_player) and not _cached_player.is_queued_for_deletion():
		return _cached_player
	if is_inside_tree():
		var p_nodes := get_tree().get_nodes_in_group("player")
		if not p_nodes.is_empty():
			_cached_player = p_nodes[0] as Node2D
			return _cached_player
	return null

func _exit_tree() -> void:
	_is_tearing_down = true
	if is_instance_valid(area):
		if area.body_entered.is_connected(_on_body_entered):
			area.body_entered.disconnect(_on_body_entered)
		if area.body_exited.is_connected(_on_body_exited):
			area.body_exited.disconnect(_on_body_exited)

func _draw_radius_circle() -> void:
	radius_visual.clear_points()
	var points: int = 36
	for i in range(points + 1):
		var angle := float(i) * TAU / float(points)
		radius_visual.add_point(Vector2(cos(angle), sin(angle)) * activation_radius)

func _on_body_entered(body: Node2D) -> void:
	if _is_tearing_down or not is_inside_tree() or is_queued_for_deletion():
		return
	if body != null and (not body.is_inside_tree() or body.is_queued_for_deletion()):
		return
	if body is Player or (body != null and body.is_in_group("player")):
		player_inside = true
		_cached_player = body
		check_orbital_relay(body)
		if is_ready and not is_planted:
			_check_core_bump()

func _on_body_exited(body: Node2D) -> void:
	if _is_tearing_down or not is_inside_tree() or is_queued_for_deletion():
		return
	if body != null and (not body.is_inside_tree() or body.is_queued_for_deletion()):
		return
	var tree := get_tree()
	if tree != null:
		var scene_root := tree.current_scene
		if scene_root != null and (not scene_root.is_inside_tree() or scene_root.is_queued_for_deletion()):
			return
	if body is Player or (body != null and body.is_in_group("player")):
		player_inside = false
		if _cached_player == body:
			_cached_player = null
		if is_planted:
			exited_perimeter.emit(satellite_index)

func plant_satellite() -> void:
	is_planted = true
	if _status_label:
		_status_label.text = "[TIENDA DISPONIBLE - BUMPEAR]"
		_status_label.modulate = Color(0.4, 1.2, 0.6, 1.0)
	visual_core.modulate = Color(0.4, 1.2, 0.6, 1.0)
	radius_visual.default_color = Color(0.2, 1.0, 0.4, 0.4)
	planted.emit(satellite_index, global_position)
