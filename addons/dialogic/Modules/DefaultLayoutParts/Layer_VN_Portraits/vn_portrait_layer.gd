@tool
extends DialogicLayoutLayer

## A layer that allows showing 5 portraits, like in a visual novel.
## Automatically docks left and right portraits to screen edges in ultrawide resolutions.

## The canvas layer that the portraits are on.
@export var portrait_size_mode: DialogicNode_PortraitContainer.SizeModes = DialogicNode_PortraitContainer.SizeModes.FIT_SCALE_HEIGHT


func _ready() -> void:
	if not Engine.is_editor_hint():
		var portraits: Control = get_node_or_null("%Portraits")
		if is_instance_valid(portraits):
			if not portraits.resized.is_connected(_update_portrait_anchors):
				portraits.resized.connect(_update_portrait_anchors)
			_update_portrait_anchors()


func _apply_export_overrides() -> void:
	# apply portrait size
	var portraits: Control = get_node_or_null("%Portraits")
	if is_instance_valid(portraits):
		for child in portraits.get_children():
			if child is DialogicNode_PortraitContainer:
				child.size_mode = portrait_size_mode
	_update_portrait_anchors()


func _update_portrait_anchors() -> void:
	var portraits: Control = get_node_or_null("%Portraits")
	if not is_instance_valid(portraits):
		return
	var viewport_size: Vector2 = portraits.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var half_width: float = viewport_size.y * 0.5
	var total_width: float = viewport_size.x

	var left_frac: float = clampf(half_width / total_width, 0.0, 0.5)
	var right_frac: float = clampf((total_width - half_width) / total_width, 0.5, 1.0)

	for child in portraits.get_children():
		if not child is DialogicNode_PortraitContainer:
			continue

		if child.is_container("center") or child.is_container("middle") or child.is_container("2"):
			_apply_container_position(child, 0.5)
		elif child.is_container("left") or child.is_container("1") or child.is_container("leftmost") or child.is_container("0"):
			_apply_container_position(child, left_frac)
		elif child.is_container("right") or child.is_container("3") or child.is_container("rightmost") or child.is_container("4"):
			_apply_container_position(child, right_frac)
		elif child.mode == DialogicNode_PortraitContainer.PositionModes._CHARACTER:
			var ref_id: String = ""
			if child.current_settings and not child.current_settings.reference_position_id.is_empty():
				ref_id = child.current_settings.reference_position_id
			elif child.container_ids and child.container_ids.size() > 0:
				ref_id = _find_character_target_position(child)
			if ref_id in ["left", "1", "leftmost", "0"]:
				_apply_container_position(child, left_frac)
			elif ref_id in ["right", "3", "rightmost", "4"]:
				_apply_container_position(child, right_frac)
			elif ref_id in ["center", "middle", "2"]:
				_apply_container_position(child, 0.5)


func _find_character_target_position(char_container: DialogicNode_PortraitContainer) -> String:
	var d_autoload = DialogicUtil.autoload()
	if not d_autoload or not d_autoload.has_subsystem("Portraits"):
		return ""
	for char_id in d_autoload.Portraits.portraits:
		var info: Dictionary = d_autoload.Portraits.portraits[char_id]
		var char_node: Node = d_autoload.Portraits.character_nodes.get(char_id)
		if char_node and char_node.get_parent() == char_container:
			return info.get("position_id", "")
	return ""


func _apply_container_position(container: DialogicNode_PortraitContainer, x_frac: float) -> void:
	container.container_position.x_percent = true
	container.container_position.x_value = x_frac
	container.container_position.y_percent = true
	container.container_position.y_value = 1.0
	if container.current_settings:
		container.current_settings.position = container.container_position.copy()
	container.update_transform_from_properties()
	var origin_pos: Vector2 = container.current_settings._get_origin_position() if container.current_settings else Vector2.ZERO
	for child in container.get_children():
		if child is Node2D:
			child.position = origin_pos
