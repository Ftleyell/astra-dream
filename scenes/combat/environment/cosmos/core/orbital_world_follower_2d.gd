class_name OrbitalWorldFollower2D
extends Node

## OrbitalWorldFollower2D.gd
## Componente desacoplado de GameplayWorld que sincroniza la posición global de cualquier entidad
## (satélite, baliza, planeta destruible) con un slot analítico en una capa de Parallax de Cosmos Engine.
##
## Garantiza sincronía perfecta sin jitter respecto a la cámara, cero colisiones falsas y
## preservación total del sistema de colisiones y BulletServer.

const CosmosOrbitSlot = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbit_slot.gd")
const CosmosOrbitalSlotTracker = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbital_slot_tracker.gd")

var slot: CosmosOrbitSlot = null
@export var active: bool = true
@export var freeze_parallax_drag: bool = false:
	set(value):
		if freeze_parallax_drag != value:
			freeze_parallax_drag = value
			if freeze_parallax_drag:
				_was_frozen_parallax = true
				if _camera_ref != null and is_instance_valid(_camera_ref):
					_frozen_camera_pos = _camera_ref.global_position
				elif is_inside_tree() and get_viewport() != null and get_viewport().get_camera_2d() != null:
					_frozen_camera_pos = get_viewport().get_camera_2d().global_position
			else:
				_was_frozen_parallax = false

var _target_node: Node2D = null
var _camera_ref: Camera2D = null
var _cosmos_root: CosmosRootNode = null
var _internal_time: float = 0.0
var _last_cosmos_time: float = -1.0
var _was_frozen_parallax: bool = false
var _frozen_camera_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	if get_parent() is Node2D:
		_target_node = get_parent() as Node2D
	_find_references()

func _find_references() -> void:
	if not is_inside_tree():
		return

	if _camera_ref == null:
		_camera_ref = get_viewport().get_camera_2d()

	if _cosmos_root == null:
		var root_node: Node = get_tree().get_first_node_in_group("cosmos_root")
		if root_node is CosmosRootNode:
			_cosmos_root = root_node as CosmosRootNode
		else:
			# Buscar en SpaceBackground si existe
			var bg: Node = get_tree().root.find_child("SpaceBackground", true, false)
			if bg != null and bg.has_method("get_cosmos_root"):
				_cosmos_root = bg.call("get_cosmos_root") as CosmosRootNode

func setup_orbital_binding(p_slot: CosmosOrbitSlot, p_camera: Camera2D = null, p_cosmos_root: CosmosRootNode = null) -> void:
	if _target_node == null and get_parent() is Node2D:
		_target_node = get_parent() as Node2D
	slot = p_slot
	if p_camera != null:
		_camera_ref = p_camera
	if p_cosmos_root != null:
		_cosmos_root = p_cosmos_root
	active = (slot != null)
	_was_frozen_parallax = false
	_update_position(0.0)

func _process(delta: float) -> void:
	if not active or slot == null or not is_instance_valid(_target_node):
		return

	_update_position(delta)

func _update_position(delta: float) -> void:
	if _camera_ref == null or not is_instance_valid(_camera_ref):
		_camera_ref = get_viewport().get_camera_2d()

	var t_global: float = 0.0
	if _cosmos_root != null and is_instance_valid(_cosmos_root):
		var root_time: float = _cosmos_root.get_global_time()
		if not is_equal_approx(root_time, _last_cosmos_time):
			_internal_time = 0.0
			_last_cosmos_time = root_time
		else:
			_internal_time += delta
		t_global = root_time + _internal_time
	else:
		_internal_time += delta
		t_global = _internal_time

	var cam_pos: Vector2 = Vector2.ZERO
	if freeze_parallax_drag:
		if not _was_frozen_parallax:
			_was_frozen_parallax = true
			if _camera_ref != null and is_instance_valid(_camera_ref):
				_frozen_camera_pos = _camera_ref.global_position
			elif is_inside_tree() and get_viewport() != null and get_viewport().get_camera_2d() != null:
				_frozen_camera_pos = get_viewport().get_camera_2d().global_position
		cam_pos = _frozen_camera_pos
	else:
		if _was_frozen_parallax:
			_was_frozen_parallax = false
		if _camera_ref != null and is_instance_valid(_camera_ref):
			cam_pos = _camera_ref.global_position

	var layer_pos: Vector2 = slot.calculate_layer_position(t_global)
	var s_scale: Vector2 = slot.layer_scroll_scale
	var new_world_pos: Vector2 = (cam_pos * (Vector2.ONE - s_scale)) + layer_pos
	_target_node.global_position = new_world_pos
