class_name TeslaCoilEffect
extends ItemEffect

@export var chain_radius: float = 320.0
@export var damage_factor: float = 0.45
var _chain_scene: PackedScene = preload("res://scenes/combat/weapons/chain_lightning_effect.tscn")

func _init() -> void:
	trigger = Enums.TriggerType.ON_CRIT
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
	var target_enemy: Node2D = null
	var min_dist_sq: float = chain_radius * chain_radius
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if enemy == context.victim:
			continue
		var dist_sq: float = origin.distance_squared_to((enemy as Node2D).global_position)
		if dist_sq <= min_dist_sq:
			min_dist_sq = dist_sq
			target_enemy = enemy as Node2D

	if target_enemy:
		var dmg: float = maxf(15.0, context.final_damage * damage_factor * float(stack_count))
		var child_ctx := context.fork_child_hit(dmg, 0.5, &"tesla_coil")
		var chain := _chain_scene.instantiate() as ChainLightningEffect
		chain.setup(origin, target_enemy.global_position, child_ctx, mini(4 + stack_count, 8))
		var spawn_parent: Node = tree.current_scene if tree.current_scene else tree.root
		spawn_parent.add_child(chain)
