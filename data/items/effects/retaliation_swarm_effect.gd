class_name RetaliationSwarmEffect
extends ItemEffect

@export var base_damage: float = 35.0
var _missile_scene: PackedScene = preload("res://scenes/combat/weapons/homing_missile.tscn")
var _last_proc_msec: int = 0

func _init() -> void:
	trigger = Enums.TriggerType.ON_TAKE_DAMAGE
	base_chance = 1.0
	proc_coefficient = 0.5

func execute(context: HitContext, stack_count: int, source_entity: Node) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_proc_msec < 600:
		return
	_last_proc_msec = now

	if not source_entity or not is_instance_valid(source_entity):
		return
	var tree := source_entity.get_tree()
	if not tree:
		return

	var spawn_pos: Vector2 = (source_entity as Node2D).global_position if source_entity is Node2D else context.hit_position
	var child_ctx := context.fork_child_hit(base_damage * float(stack_count), 0.0, &"retaliation_swarm")
	var spawn_parent: Node = tree.current_scene if tree.current_scene else tree.root

	var missile_count: int = mini(2 + stack_count, 6)
	for i in range(missile_count):
		var angle := float(i) * TAU / float(missile_count) + randf_range(-0.2, 0.2)
		var m_dir := Vector2.from_angle(angle)
		var missile := _missile_scene.instantiate() as HomingMissile
		missile.setup(spawn_pos, m_dir, child_ctx, null)
		spawn_parent.add_child(missile)
