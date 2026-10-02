class_name PyroclasticBatteryEffect
extends ItemEffect

@export var shard_damage: float = 25.0
@export var shard_count: int = 3
var _kinetic_scene: PackedScene = preload("res://scenes/combat/weapons/kinetic_projectile.tscn")

func _init() -> void:
	trigger = Enums.TriggerType.ON_KILL
	base_chance = 1.0
	proc_coefficient = 0.5

func execute(context: HitContext, stack_count: int, source_entity: Node) -> void:
	if not source_entity or not is_instance_valid(source_entity):
		return
	var tree := source_entity.get_tree()
	if not tree:
		return

	var origin: Vector2 = context.hit_position
	if origin == Vector2.ZERO and source_entity is Node2D:
		origin = (source_entity as Node2D).global_position

	var enemies := tree.get_nodes_in_group("enemies")
	var spawn_parent: Node = tree.current_scene if tree.current_scene else tree.root
	var total_shards: int = shard_count + (stack_count - 1) * 2

	for i in range(total_shards):
		var target_enemy: Node2D = null
		if not enemies.is_empty():
			var rand_idx: int = randi() % enemies.size()
			if is_instance_valid(enemies[rand_idx]) and enemies[rand_idx] is Node2D:
				target_enemy = enemies[rand_idx] as Node2D

		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		if target_enemy:
			dir = origin.direction_to(target_enemy.global_position).rotated(randf_range(-0.3, 0.3))

		var proj: KineticProjectile = _kinetic_scene.instantiate() as KineticProjectile
		var child_ctx := context.fork_child_hit(shard_damage, 0.5, &"pyroclastic_battery")
		proj.setup(origin, dir, child_ctx, source_entity as Node2D, 0.65, 0.8)
		proj.modulate = Color(1.8, 0.6, 0.1, 1.0)
		spawn_parent.add_child(proj)
