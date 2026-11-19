class_name PlanarRigImpactController
extends RefCounted
## Controla hit-stop local, shake ortogonal de UnifiedCharacterGroup e Impact Frames de 2 fases.

var _hit_stop_timer: float = 0.0
var _hit_stop_duration: float = 0.055
var _hit_stop_shake_px: float = 6.0
var _impact_frame_phase: int = 0


func reset(canvas_group: CanvasGroup, materials: PlanarRigMaterialController) -> void:
	_hit_stop_timer = 0.0
	_impact_frame_phase = 0
	if canvas_group != null:
		canvas_group.position = Vector2.ZERO
	if materials != null:
		materials.set_pass2_impact_phase(0)


func trigger(duration_ms: float, shake_px: float, owner_node: Node2D, materials: PlanarRigMaterialController) -> void:
	_hit_stop_duration = clampf(duration_ms / 1000.0, 0.040, 0.065)
	_hit_stop_timer = _hit_stop_duration
	_hit_stop_shake_px = clampf(shake_px, 0.0, 24.0)
	_impact_frame_phase = 1
	update_center_uv(owner_node, materials)
	if materials != null:
		materials.set_pass2_impact_phase(1)


func step(delta: float, owner_node: Node2D, canvas_group: CanvasGroup, materials: PlanarRigMaterialController) -> bool:
	update_center_uv(owner_node, materials)
	if _hit_stop_timer <= 0.0:
		return false
	_hit_stop_timer = maxf(0.0, _hit_stop_timer - delta)
	if _hit_stop_timer <= 0.0:
		_impact_frame_phase = 0
		if canvas_group != null:
			canvas_group.position = Vector2.ZERO
	else:
		var elapsed: float = _hit_stop_duration - _hit_stop_timer
		_impact_frame_phase = 1 if elapsed < (_hit_stop_duration * 0.5) else 2
		if canvas_group != null:
			var shake_dir: Vector2 = Vector2(1.0, 0.0) if _impact_frame_phase == 1 else Vector2(0.0, -1.0)
			canvas_group.position = shake_dir * _hit_stop_shake_px * (_hit_stop_timer / maxf(_hit_stop_duration, 0.001))
	if materials != null:
		materials.set_pass2_impact_phase(_impact_frame_phase)
	return true


func update_center_uv(owner_node: Node2D, materials: PlanarRigMaterialController) -> void:
	if materials == null:
		return
	var center_uv: Vector2 = Vector2(0.5, 0.5)
	if owner_node != null and owner_node.is_inside_tree() and owner_node.get_viewport() != null:
		var vp_rect: Rect2 = owner_node.get_viewport_rect()
		if vp_rect.size.x > 1.0 and vp_rect.size.y > 1.0:
			var screen_pos: Vector2 = owner_node.get_viewport().get_canvas_transform() * owner_node.global_position
			center_uv = (screen_pos / vp_rect.size).clamp(Vector2.ZERO, Vector2.ONE)
	materials.set_pass2_impact_center_uv(center_uv)


func is_active() -> bool:
	return _hit_stop_timer > 0.0


func get_phase() -> int:
	return _impact_frame_phase
