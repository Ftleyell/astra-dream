class_name EntropyCatalystEffect
extends ItemEffect

@export var base_damage: float = 25.0
var _vortex_scene: PackedScene = preload("res://scenes/combat/weapons/singularity_vortex.tscn")
var _last_proc_msec: int = 0

func _init() -> void:
	trigger = Enums.TriggerType.ON_CRIT
	base_chance = 0.5
	proc_coefficient = 0.3

func execute(context: HitContext, stack_count: int, source_entity: Node) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_proc_msec < 1000:
		return
	_last_proc_msec = now

	if not source_entity or not is_instance_valid(source_entity):
		return
	var tree := source_entity.get_tree()
	if not tree:
		return

	var spawn_pos: Vector2 = context.hit_position
	if spawn_pos == Vector2.ZERO and source_entity is Node2D:
		spawn_pos = (source_entity as Node2D).global_position

	var child_ctx := context.fork_child_hit(base_damage * float(stack_count), 0.3, &"entropy_catalyst")
	var vortex := _vortex_scene.instantiate() as SingularityVortex
	vortex.setup(spawn_pos, child_ctx, 0.75 + 0.15 * float(stack_count - 1))
	var spawn_parent: Node = tree.current_scene if tree.current_scene else tree.root
	spawn_parent.add_child(vortex)
