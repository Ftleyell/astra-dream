extends Node2D

@export var duration: float = 2.0
@export var explosion_damage: float = 65.0
@export var explosion_radius: float = 140.0

var _timer: float = 0.0
var _player_ref: Node2D = null

@onready var visual_poly: Polygon2D = get_node_or_null("VisualPolygon")

func _ready() -> void:
	add_to_group("decoy_targets")
	if not visual_poly:
		var poly := Polygon2D.new()
		poly.name = "VisualPolygon"
		poly.color = Color(0.1, 0.9, 0.6, 0.9)
		poly.polygon = PackedVector2Array([
			Vector2(0, -14),
			Vector2(12, -4),
			Vector2(8, 12),
			Vector2(-8, 12),
			Vector2(-12, -4)
		])
		add_child(poly)
		visual_poly = poly

func setup(pos: Vector2, p_ref: Node2D = null) -> void:
	global_position = pos
	_player_ref = p_ref

func _process(delta: float) -> void:
	_timer += delta
	rotation += delta * 6.0

	# Parpadeo de advertencia rápido antes de explotar
	if visual_poly:
		var blink_speed := 10.0 if _timer > duration * 0.6 else 4.0
		visual_poly.modulate = Color(1.0, 1.0, 1.0) if fmod(_timer * blink_speed, 1.0) > 0.5 else Color(0.2, 1.0, 0.7)

	if _timer >= duration:
		_detonate()

func _detonate() -> void:
	var tree := get_tree()
	if tree:
		var r_sq := explosion_radius * explosion_radius
		for enemy in tree.get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy is Node2D:
				var dist_sq := global_position.distance_squared_to(enemy.global_position)
				if dist_sq <= r_sq:
					if enemy.has_method("take_damage"):
						var ctx := HitContext.new()
						ctx.attacker = _player_ref
						ctx.raw_damage = explosion_damage
						ctx.final_damage = explosion_damage
						ctx.hit_position = global_position
						enemy.take_damage(ctx)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("explosion", 1.4, 0.0)

	var bullet_server := get_node_or_null("/root/BulletServer")
	if not bullet_server and is_instance_valid(_player_ref) and "bullet_server" in _player_ref:
		bullet_server = _player_ref.bullet_server
	if bullet_server and bullet_server.has_method("clear_bullets_in_radius"):
		bullet_server.clear_bullets_in_radius(global_position, explosion_radius)

	queue_free()
