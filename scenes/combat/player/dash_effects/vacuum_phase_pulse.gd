extends Node2D

@export var duration: float = 0.5
@export var vacuum_radius: float = 380.0
@export var damage_radius: float = 260.0
@export var bullet_clear_radius: float = 120.0
@export var pulse_damage: float = 20.0

var _timer: float = 0.0
var _player_ref: Node2D = null

func setup(pos: Vector2, p_ref: Node2D = null) -> void:
	global_position = pos
	_player_ref = p_ref

func _ready() -> void:
	# 1. Limpiar balas de inmediato en el epicentro del vacío
	var bullet_server := get_node_or_null("/root/BulletServer")
	if not bullet_server and is_instance_valid(_player_ref) and "bullet_server" in _player_ref:
		bullet_server = _player_ref.bullet_server
	if bullet_server and bullet_server.has_method("clear_bullets_in_radius"):
		bullet_server.clear_bullets_in_radius(global_position, bullet_clear_radius)

	# 2. Atraer todos los orbes de EXP en el área hacia la posición del pulso
	var tree := get_tree()
	if tree:
		var vac_r_sq := vacuum_radius * vacuum_radius
		for orb in tree.get_nodes_in_group("exp_orbs"):
			if is_instance_valid(orb) and orb is Node2D:
				if global_position.distance_squared_to(orb.global_position) <= vac_r_sq:
					if "target" in orb and is_instance_valid(_player_ref):
						orb.target = _player_ref
					if "is_attracted" in orb:
						orb.is_attracted = true

		# 3. Dañar y ralentizar enemigos dentro del radio de vacío
		var dmg_r_sq := damage_radius * damage_radius
		for enemy in tree.get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy is Node2D:
				var dist_sq := global_position.distance_squared_to(enemy.global_position)
				if dist_sq <= dmg_r_sq:
					if enemy.has_method("take_damage"):
						var ctx := HitContext.new()
						ctx.attacker = _player_ref
						ctx.raw_damage = pulse_damage
						ctx.final_damage = pulse_damage
						ctx.hit_position = global_position
						enemy.take_damage(ctx)
					# Ralentización gravitacional por 1.5 segundos
					if "speed_multiplier" in enemy:
						enemy.speed_multiplier = 0.5
						var t := tree.create_timer(1.5)
						t.timeout.connect(func():
							if is_instance_valid(enemy) and "speed_multiplier" in enemy:
								enemy.speed_multiplier = 1.0
						)

	queue_redraw()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := _timer / duration
	var current_rad := lerpf(40.0, damage_radius, progress)
	var alpha := 1.0 - progress
	draw_arc(Vector2.ZERO, current_rad, 0.0, TAU, 32, Color(0.7, 0.2, 1.0, alpha * 0.8), 3.0)
	draw_circle(Vector2.ZERO, lerpf(10.0, 50.0, progress), Color(0.4, 0.1, 0.8, alpha * 0.4))
