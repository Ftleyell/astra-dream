class_name RivalWarpPresenter
extends RefCounted

## Presentador cinemático para la entrada y salida hiperespacial de las pilotos rivales.
## Desacopla la gestión de vórtices, portales, ondas de choque y tweens de deformación dimensional.

const HyperspacePortalScript = preload("res://scenes/combat/bosses/hyperspace_portal.gd")

static func prepare_warp_in(rival: CharacterBody2D, warp_target_pos: Vector2) -> Vector2:
	rival.rotation = -PI / 2.0
	var final_target: Vector2 = warp_target_pos
	if final_target != Vector2.ZERO:
		rival.global_position = final_target + Vector2(90.0, 0.0)
	else:
		final_target = rival.global_position
		rival.global_position = final_target + Vector2(90.0, 0.0)

	var sprite: Sprite2D = rival.get("ship_sprite") as Sprite2D
	if sprite:
		sprite.scale = Vector2(0.01, 0.01)
		sprite.modulate = Color(2.5, 2.5, 3.5, 0.0)

	var danger_ring: Sprite2D = rival.get("combat_danger_ring") as Sprite2D
	if danger_ring:
		danger_ring.modulate.a = 0.0

	var label: Label = rival.get("warning_label") as Label
	if label:
		label.modulate.a = 0.0

	rival.queue_redraw()
	return final_target

static func open_warp_portal(rival: CharacterBody2D, warp_target_pos: Vector2, theme_color: Color, on_shockwave_ready: Callable = Callable()) -> Node2D:
	rival.process_mode = Node.PROCESS_MODE_ALWAYS
	rival.rotation = -PI / 2.0

	var target: Vector2 = warp_target_pos if warp_target_pos != Vector2.ZERO else rival.global_position
	var portal_pos: Vector2 = target + Vector2(90.0, 0.0)

	var portal = HyperspacePortalScript.new()
	portal.setup(portal_pos, theme_color, 68.0, 680.0)
	portal.auto_collapse = false
	portal.process_mode = Node.PROCESS_MODE_ALWAYS

	var parent_node: Node = rival.get_parent()
	if parent_node:
		parent_node.add_child(portal)
	else:
		rival.add_child(portal)

	rival.global_position = portal_pos
	var sprite: Sprite2D = rival.get("ship_sprite") as Sprite2D
	if sprite:
		sprite.scale = Vector2(0.01, 0.01)
		sprite.modulate = Color(2.5, 2.5, 3.5, 0.0)

	var danger_ring: Sprite2D = rival.get("combat_danger_ring") as Sprite2D
	if danger_ring:
		danger_ring.modulate.a = 0.0

	var label: Label = rival.get("warning_label") as Label
	if label:
		label.modulate.a = 0.0

	if on_shockwave_ready.is_valid():
		var shockwave_dispatched: Array[bool] = [false]
		var safe_shockwave_cb: Callable = func() -> void:
			if not shockwave_dispatched[0]:
				shockwave_dispatched[0] = true
				if on_shockwave_ready.is_valid():
					on_shockwave_ready.call()
		portal.shockwave_completed.connect(safe_shockwave_cb, Object.CONNECT_ONE_SHOT)
		rival.get_tree().create_timer(1.2, true, false, true).timeout.connect(safe_shockwave_cb)

	return portal

static func emerge_from_portal(rival: CharacterBody2D, warp_portal: Node2D, target_pos: Vector2, callback: Callable = Callable()) -> void:
	rival.process_mode = Node.PROCESS_MODE_ALWAYS
	var sprite: Sprite2D = rival.get("ship_sprite") as Sprite2D
	if not sprite:
		if is_instance_valid(warp_portal) and warp_portal.has_method("start_collapse"):
			warp_portal.start_collapse()
		if callback.is_valid():
			callback.call()
		return

	if rival.has_method("_play_sfx"):
		rival.call("_play_sfx", "dash", 0.65)

	var tw := rival.create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tw.tween_property(rival, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var t_anim := tw.tween_property(sprite, "scale", Vector2(0.42, 0.42), 0.5)
	t_anim.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)

	var danger_ring: Sprite2D = rival.get("combat_danger_ring") as Sprite2D
	if danger_ring:
		tw.tween_property(danger_ring, "modulate:a", 0.65, 0.5)

	var emerge_done: Array[bool] = [false]
	var safe_emerge_cb: Callable = func() -> void:
		if not emerge_done[0]:
			emerge_done[0] = true
			if is_instance_valid(warp_portal) and warp_portal.has_method("start_collapse"):
				warp_portal.start_collapse()
			if callback.is_valid():
				callback.call()

	tw.chain().tween_callback(safe_emerge_cb)
	rival.get_tree().create_timer(0.9, true, false, true).timeout.connect(safe_emerge_cb)

static func warp_out_peacefully(rival: CharacterBody2D, pilot_id: StringName, pilot_name: String) -> void:
	var label: Label = rival.get("warning_label") as Label
	if label:
		label.text = "✓ %s: HIPERSALTO INICIADO. CONTACTO PACÍFICO." % pilot_name.to_upper()
		label.modulate = Color(0.2, 1.0, 0.6, 1.0)

	var danger_ring: Sprite2D = rival.get("combat_danger_ring") as Sprite2D
	if danger_ring and is_instance_valid(danger_ring):
		var tw_ring := rival.create_tween()
		tw_ring.tween_property(danger_ring, "modulate:a", 0.0, 0.4)
		tw_ring.chain().tween_callback(danger_ring.queue_free)
		rival.set("combat_danger_ring", null)

	rival.emit_signal("rival_spared", pilot_id)

	var forward: Vector2 = Vector2.UP.rotated(rival.rotation)
	var tw := rival.create_tween()
	tw.set_parallel(true)
	tw.tween_property(rival, "global_position", rival.global_position + forward * 900.0, 0.8).set_ease(Tween.EASE_IN)
	tw.tween_property(rival, "scale", Vector2(0.1, 2.5), 0.8)
	tw.tween_property(rival, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(rival.queue_free)
