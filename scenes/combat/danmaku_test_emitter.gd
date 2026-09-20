class_name DanmakuTestEmitter
extends Node2D

@export var bullet_server: BulletServer
@export var player: Player

var tick: int = 0
var radial_timer: float = 0.0
var spiral_timer: float = 0.0
var current_health: float = 200.0

func _ready() -> void:
	add_to_group("emitters")
	add_to_group("enemies")

func _process(delta: float) -> void:
	if not bullet_server:
		return

	radial_timer += delta
	spiral_timer += delta

	# Disparo de espiral dorada continua (Fermat Spiral)
	if spiral_timer >= 0.035:
		spiral_timer = 0.0
		tick += 1
		bullet_server.fire_fermat_spiral_tick(global_position, tick, 180.0, 0.0, 1)

	# Disparo de anillo radial periódico
	if radial_timer >= 1.6:
		radial_timer = 0.0
		bullet_server.fire_radial_ring(global_position, 20, 140.0, float(tick) * 0.1, 0)
		if player:
			bullet_server.fire_aimed_spread(global_position, player.global_position, 5, 45.0, 220.0, 2)

func take_damage(ctx: HitContext) -> void:
	current_health -= ctx.final_damage
	# Hit-flash visual
	modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

	if current_health <= 0.0:
		var blob_scene: PackedScene = load("res://scenes/combat/pickups/exp_blob.tscn")
		if blob_scene:
			var blob := blob_scene.instantiate() as Node2D
			if blob.has_method("setup"):
				blob.setup(40.0, global_position)
			get_parent().add_child(blob)

		if player:
			player.add_credits(20)
		# Regenerar vida y reubicarse ligeramente
		current_health = 200.0
		global_position += Vector2(randf_range(-60, 60), randf_range(-60, 60))
