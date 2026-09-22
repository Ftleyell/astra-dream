extends Area2D

@export var lifetime: float = 2.0
@export var damage_per_tick: float = 15.0
@export var tick_interval: float = 0.25

var _tick_timer: float = 0.0
var _current_life: float = 0.0
var player_ref: Node2D = null

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_polygon: Polygon2D = get_node_or_null("VisualPolygon")

func _ready() -> void:
	monitoring = true
	monitorable = true
	add_to_group("player_hazards")
	if not visual_polygon:
		var poly := Polygon2D.new()
		poly.name = "VisualPolygon"
		poly.color = Color(1.0, 0.45, 0.1, 0.75)
		poly.polygon = PackedVector2Array([
			Vector2(-24, -12),
			Vector2(24, -12),
			Vector2(32, 0),
			Vector2(24, 12),
			Vector2(-24, 12),
			Vector2(-32, 0)
		])
		add_child(poly)
		visual_polygon = poly

func setup(pos: Vector2, dash_dir: Vector2, p_ref: Node2D = null) -> void:
	global_position = pos
	rotation = dash_dir.angle()
	player_ref = p_ref

func _process(delta: float) -> void:
	_current_life += delta
	if _current_life >= lifetime:
		queue_free()
		return

	# Desvanecimiento alfa progresivo
	var alpha_factor := 1.0 - (_current_life / lifetime)
	modulate.a = alpha_factor

	# Destruir balas hostiles menores que toquen el fuego
	var bullet_server := get_node_or_null("/root/BulletServer")
	if not bullet_server and is_instance_valid(player_ref) and "bullet_server" in player_ref:
		bullet_server = player_ref.bullet_server
	if bullet_server and bullet_server.has_method("clear_bullets_in_radius"):
		bullet_server.clear_bullets_in_radius(global_position, 28.0)

	# Ticks de daño a enemigos en el área
	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		_deal_tick_damage()

func _deal_tick_damage() -> void:
	var overlapping := get_overlapping_bodies()
	for body in overlapping:
		if is_instance_valid(body) and body.is_in_group("enemies"):
			if body.has_method("take_damage"):
				var ctx := HitContext.new()
				ctx.attacker = player_ref
				ctx.raw_damage = damage_per_tick
				ctx.final_damage = damage_per_tick
				ctx.hit_position = global_position
				body.take_damage(ctx)
