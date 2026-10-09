class_name PlayerLocomotionController
extends RefCounted

## PlayerLocomotionController.gd
## Controlador especializado para la locomoción, cinemática de vuelo 360°,
## inclinación dinámica (bank tilt), enfoque táctico y visibilidad reactiva del HitboxCore.

const ROTATION_SMOOTH_SPEED: float = 14.0
const BANK_SMOOTH_SPEED: float = 8.0
const TACTICAL_FOCUS_SPEED: float = 280.0

var current_facing_angle: float = -PI / 2.0
var last_facing_direction: Vector2 = Vector2.UP
var current_bank_tilt: float = 0.0
var idle_bob_timer: float = 0.0
var is_tactical_focus_active: bool = false
var is_movement_suppressed: bool = false

var _threat_check_timer: float = 0.0
var _is_threat_nearby: bool = false


func update_hitbox_core_visibility(player: CharacterBody2D, hitbox_core: Node2D, delta: float) -> void:
	if not hitbox_core or not is_instance_valid(player):
		return
	_threat_check_timer -= delta
	if _threat_check_timer <= 0.0:
		_threat_check_timer = 0.12
		_is_threat_nearby = _check_hostile_threat(player)

	var settings_mgr: Node = player.get_node_or_null("/root/SettingsManager")
	var always_on: bool = settings_mgr.is_core_hitbox_always_visible() if settings_mgr and settings_mgr.has_method("is_core_hitbox_always_visible") else false

	var target_alpha: float = 1.0 if (always_on or is_tactical_focus_active or _is_threat_nearby) else 0.0
	hitbox_core.modulate.a = move_toward(hitbox_core.modulate.a, target_alpha, delta / 0.1)


func _check_hostile_threat(player: CharacterBody2D) -> bool:
	var tree := player.get_tree()
	if not tree:
		return false
	if not tree.get_nodes_in_group("bosses").is_empty() or not tree.get_nodes_in_group("rivals").is_empty():
		return true
	var chargers := tree.get_nodes_in_group("chargers")
	for c in chargers:
		if is_instance_valid(c) and c.get("is_preparing_charge") == true:
			return true
	var enemies := tree.get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e is Node2D and (e as Node2D).global_position.distance_squared_to(player.global_position) < 14400.0:
			return true
	return false


func handle_movement(player: CharacterBody2D, stats: CharacterStats, is_dashing: bool, dash_direction: Vector2, delta: float) -> void:
	if not is_instance_valid(player):
		return

	if is_movement_suppressed:
		player.velocity = Vector2.ZERO
		player.move_and_slide()
		return

	if is_dashing:
		var speed_mult: float = stats.get_stat(&"move_speed") * 2.5 if stats else 500.0
		player.velocity = dash_direction * speed_mult
		player.move_and_slide()
		return

	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	is_tactical_focus_active = Input.is_key_pressed(KEY_CTRL) or (InputMap.has_action(&"tactical_focus") and Input.is_action_pressed(&"tactical_focus"))

	var speed: float = stats.get_stat(&"move_speed") if stats else 200.0
	if is_tactical_focus_active:
		speed = minf(speed, TACTICAL_FOCUS_SPEED)

	player.velocity = player.velocity.move_toward(input_vector * speed, speed * 8.0 * delta)
	player.move_and_slide()


func update_flight_kinematics(player: CharacterBody2D, is_omega_spinning: bool, is_dashing: bool, delta: float) -> void:
	if not is_instance_valid(player):
		return

	idle_bob_timer += delta
	var is_moving: bool = player.velocity.length_squared() > 10.0
	var target_bank: float = 0.0

	if not is_omega_spinning:
		if is_moving:
			var move_angle := player.velocity.angle()
			last_facing_direction = player.velocity.normalized()
			var angle_diff := wrapf(move_angle - current_facing_angle, -PI, PI)
			current_facing_angle = lerp_angle(current_facing_angle, move_angle, ROTATION_SMOOTH_SPEED * delta)
			target_bank = clampf(angle_diff * 1.8, -1.0, 1.0)
		else:
			target_bank = 0.0

		current_bank_tilt = move_toward(current_bank_tilt, target_bank, BANK_SMOOTH_SPEED * delta)

		var visual_rotation := current_facing_angle + PI / 2.0
		var ship_spr := player.get_node_or_null("ShipSprite") as Sprite2D
		if ship_spr and ship_spr.visible:
			ship_spr.rotation = visual_rotation
			if not is_moving and not is_dashing:
				ship_spr.position.y = sin(idle_bob_timer * 3.5) * 1.5
			else:
				ship_spr.position.y = move_toward(ship_spr.position.y, 0.0, 8.0 * delta)

		var exo_spr := player.get_node_or_null("ExoArmorSprite") as Sprite2D
		if exo_spr:
			exo_spr.rotation = visual_rotation

		var placeholder := player.get_node_or_null("VisualPlaceholder") as Polygon2D
		if placeholder and placeholder.visible:
			placeholder.rotation = current_facing_angle


func set_cinematic_duel_facing(player: CharacterBody2D) -> void:
	if not is_instance_valid(player):
		return
	is_movement_suppressed = true
	player.velocity = Vector2.ZERO
	current_facing_angle = 0.0
	var ship_spr := player.get_node_or_null("ShipSprite") as Sprite2D
	if ship_spr:
		ship_spr.rotation = PI / 2.0
	var exo_spr := player.get_node_or_null("ExoArmorSprite") as Sprite2D
	if exo_spr:
		exo_spr.rotation = PI / 2.0
	var placeholder := player.get_node_or_null("VisualPlaceholder") as Polygon2D
	if placeholder:
		placeholder.rotation = 0.0


func resume_movement_control() -> void:
	is_movement_suppressed = false
