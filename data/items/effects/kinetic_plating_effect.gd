class_name KineticPlatingEffect
extends ItemEffect

@export var base_damage: float = 60.0
var _shock_scene: PackedScene = preload("res://scenes/combat/weapons/shockwave_area.tscn")
var _last_proc_msec: int = 0

func _init() -> void:
	trigger = Enums.TriggerType.ON_TAKE_DAMAGE
	base_chance = 1.0
	proc_coefficient = 0.3

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
	var child_ctx := context.fork_child_hit(base_damage * float(stack_count), 0.3, &"kinetic_plating")
	var shock := _shock_scene.instantiate() as ShockwaveArea
	shock.setup(spawn_pos, child_ctx, 1.0 + 0.15 * float(stack_count - 1))
	var spawn_parent: Node = tree.current_scene if tree.current_scene else tree.root
	spawn_parent.add_child(shock)
