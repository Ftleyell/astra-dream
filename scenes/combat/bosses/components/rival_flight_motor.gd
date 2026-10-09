class_name RivalFlightMotor
extends RefCounted

## RivalFlightMotor.gd
## Manejador cinemático 2D desacoplado para naves rivales:
## Navegación orbital en modo pacífico, persecución/evasión dogfight 1v1, micro-dashes
## y parámetros de shader de inclinación dinámica (bank tilt) y empuje de propulsores.

var dash_timer: float = 0.0
var is_dashing: bool = false
var dash_velocity: Vector2 = Vector2.ZERO
var previous_rotation: float = 0.0
var current_bank_tilt: float = 0.0

func process_peaceful_flight(boss: CharacterBody2D, player: Node2D, delta: float, elapsed_time: float) -> void:
	if not is_instance_valid(boss) or not is_instance_valid(player):
		return

	# Rotar mirando al jugador con cautela
	var dir: Vector2 = (player.global_position - boss.global_position).normalized()
	boss.rotation = lerp_angle(boss.rotation, dir.angle() + PI / 2.0, 5.0 * delta)

	# Suave flotación orbital
	boss.velocity = Vector2(-dir.y, dir.x) * sin(elapsed_time * 1.5) * 45.0
	boss.move_and_slide()

func process_dogfight_flight(boss: CharacterBody2D, player: Node2D, delta: float, dist: float) -> void:
	if not is_instance_valid(boss) or not is_instance_valid(player):
		return

	var to_player: Vector2 = (player.global_position - boss.global_position).normalized()
	boss.rotation = lerp_angle(boss.rotation, to_player.angle() + PI / 2.0, 8.0 * delta)

	# IA de movimiento: maniobra en espiral / órbita táctica a ~400 px
	var ideal_dist: float = 400.0
	var radial_speed: float = (dist - ideal_dist) * 1.5
	var orbit_dir: Vector2 = Vector2(-to_player.y, to_player.x)
	var target_vel: Vector2 = (to_player * radial_speed) + (orbit_dir * 310.0)

	# Micro-dash evasivo
	dash_timer -= delta
	if dash_timer <= 0.0:
		dash_timer = randf_range(2.5, 4.0)
		is_dashing = true
		dash_velocity = orbit_dir * (randf_range(500.0, 650.0) * (1.0 if randf() > 0.5 else -1.0))
		boss.create_tween().tween_callback(func() -> void: is_dashing = false).set_delay(0.35)

	if is_dashing:
		boss.velocity = dash_velocity
	else:
		boss.velocity = boss.velocity.move_toward(target_vel, 700.0 * delta)
	boss.move_and_slide()

func update_flight_shader(boss: CharacterBody2D, ship_sprite: Sprite2D, is_dogfight: bool, delta: float, elapsed_time: float) -> void:
	if not ship_sprite or not (ship_sprite.material is ShaderMaterial):
		return
	var mat: ShaderMaterial = ship_sprite.material as ShaderMaterial

	var rot_diff: float = wrapf(boss.rotation - previous_rotation, -PI, PI)
	previous_rotation = boss.rotation
	var angular_rate: float = rot_diff / maxf(0.001, delta)
	var target_bank: float = clampf(angular_rate * 0.12, -1.0, 1.0)
	current_bank_tilt = move_toward(current_bank_tilt, target_bank, 8.0 * delta)

	mat.set_shader_parameter("bank_tilt", current_bank_tilt)
	var leg_bend_val: float = clampf(-current_bank_tilt * 0.22, -0.22, 0.22)
	mat.set_shader_parameter("leg_bend", leg_bend_val)

	var spd: float = boss.velocity.length()
	var spd_ratio: float = clampf(spd / 600.0, 0.0, 1.0)
	mat.set_shader_parameter("speed_ratio", spd_ratio)

	if is_dashing:
		mat.set_shader_parameter("thrust_intensity", 2.2)
		mat.set_shader_parameter("thruster_length", 0.75)
		mat.set_shader_parameter("thruster_speed", 90.0)
		mat.set_shader_parameter("thruster_width", 0.075)
	elif is_dogfight:
		mat.set_shader_parameter("thrust_intensity", lerpf(0.7, 1.4, spd_ratio))
		mat.set_shader_parameter("thruster_length", lerpf(0.42, 0.58, spd_ratio))
		mat.set_shader_parameter("thruster_speed", lerpf(50.0, 75.0, spd_ratio))
		mat.set_shader_parameter("thruster_width", lerpf(0.045, 0.06, spd_ratio))
	else:
		mat.set_shader_parameter("thrust_intensity", 0.45)
		mat.set_shader_parameter("thruster_length", 0.35 + 0.04 * sin(elapsed_time * 4.0))
		mat.set_shader_parameter("thruster_speed", 40.0)
		mat.set_shader_parameter("thruster_width", 0.04)
