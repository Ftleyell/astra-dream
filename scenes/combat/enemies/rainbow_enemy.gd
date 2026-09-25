class_name RainbowEnemy
extends EnemyBase

var escape_timer: float = 14.0
var _trail_timer: float = 0.0
var _current_flight_dir: Vector2 = Vector2.ZERO
var is_escaping: bool = false

func _ready_custom() -> void:
	enemy_id = &"enemy_rainbow"
	max_health = 350.0
	current_health = max_health
	move_speed = 390.0
	contact_damage = 0.0
	credits_reward = 250
	exp_reward = 100.0

	_acquire_player()
	if is_instance_valid(player):
		_current_flight_dir = (global_position - player.global_position).normalized()
	if _current_flight_dir.length_squared() < 0.001:
		_current_flight_dir = Vector2.from_angle(randf() * TAU)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.7)

func _update_behavior(delta: float) -> void:
	if is_dying or is_escaping:
		return

	escape_timer -= delta
	if escape_timer <= 0.0:
		_warp_escape()
		return

	# Huir activamente del jugador
	if is_instance_valid(player):
		var flee_dir := (global_position - player.global_position).normalized()
		_current_flight_dir = _current_flight_dir.lerp(flee_dir, delta * 3.5).normalized()

	velocity = _current_flight_dir * move_speed
	rotation = _current_flight_dir.angle() + PI * 0.5
	move_and_slide()

	# Rastro cromático arcoíris
	_trail_timer += delta
	if _trail_timer >= 0.06:
		_trail_timer = 0.0
		_spawn_rainbow_trail_ghost()

func _spawn_rainbow_trail_ghost() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if not spr or not spr.texture:
		return
	var ghost := Sprite2D.new()
	ghost.texture = spr.texture
	ghost.material = spr.material
	ghost.global_position = spr.global_position
	ghost.rotation = spr.rotation
	ghost.scale = spr.scale
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.45)

	var p: Node = get_parent() if is_inside_tree() else null
	if p:
		p.add_child(ghost)
		var tw := ghost.create_tween()
		tw.tween_property(ghost, "modulate:a", 0.0, 0.35)
		tw.tween_property(ghost, "scale", spr.scale * 0.7, 0.35)
		tw.tween_callback(ghost.queue_free)

func _warp_escape() -> void:
	if is_escaping or is_dying:
		return
	is_escaping = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.01, 2.5), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)

func _on_die_extra() -> void:
	# Otorga 1 nivel completo instantáneo al jugador
	if is_instance_valid(player) and player.has_method("add_exp"):
		var exp_needed: float = maxf(1.0, player.exp_to_next - player.current_exp)
		player.add_exp(exp_needed)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.8)
