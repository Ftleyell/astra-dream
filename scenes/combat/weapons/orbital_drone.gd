class_name OrbitalDrone
extends Node2D

@export var orbit_radius: float = 85.0
@export var orbit_speed: float = 3.2
@export var fire_rate: float = 0.4
@export var drone_damage: float = 14.0

var player: Node2D = null
var current_angle: float = 0.0
var fire_timer: float = 0.0
var hit_context: HitContext

@onready var drone_body: Polygon2D = $DroneBody
@onready var beam_line: Line2D = $BeamLine

func setup(p_player: Node2D, p_starting_angle: float, p_ctx: HitContext) -> void:
	player = p_player
	current_angle = p_starting_angle
	hit_context = p_ctx
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return

	current_angle += orbit_speed * delta
	var offset := Vector2(cos(current_angle), sin(current_angle)) * orbit_radius
	global_position = player.global_position + offset
	rotation = current_angle + PI * 0.5

	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = fire_rate
		_try_fire_micro_beam()

func _try_fire_micro_beam() -> void:
	var tree := get_tree()
	if not tree:
		return

	var enemies: Array[Node] = tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("destructibles")
	var best_target: Node2D = null
	var best_d_sq: float = 280.0 * 280.0

	for node in enemies:
		if is_instance_valid(node) and node is Node2D:
			var d_sq := global_position.distance_squared_to(node.global_position)
			if d_sq <= best_d_sq:
				best_d_sq = d_sq
				best_target = node as Node2D

	if best_target and beam_line:
		var target_pos := best_target.global_position
		beam_line.points = PackedVector2Array([Vector2.ZERO, to_local(target_pos)])
		beam_line.visible = true

		if best_target.has_method("take_damage"):
			var c := HitContext.new()
			c.attacker = player
			c.raw_damage = drone_damage
			c.final_damage = drone_damage
			c.proc_coefficient = 0.25
			c.hit_position = target_pos
			best_target.take_damage(c)

		var tw := create_tween()
		tw.tween_property(beam_line, "modulate:a", 0.0, 0.08)
		tw.tween_callback(func(): beam_line.visible = false; beam_line.modulate.a = 1.0)
