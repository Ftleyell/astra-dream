class_name PhaseThrusterEffect
extends ItemEffect

@export var base_damage: float = 40.0
var _shock_scene: PackedScene = preload("res://scenes/combat/weapons/shockwave_area.tscn")

func _init() -> void:
	trigger = Enums.TriggerType.ON_DASH
	base_chance = 1.0
	proc_coefficient = 0.4

func execute(context: HitContext, stack_count: int, source_entity: Node) -> void:
	if not source_entity or not is_instance_valid(source_entity):
		return
	var tree := source_entity.get_tree()
	if not tree:
		return

	var spawn_pos: Vector2 = (source_entity as Node2D).global_position if source_entity is Node2D else context.hit_position
	var child_ctx := context.fork_child_hit(base_damage * float(stack_count), 0.0, &"phase_thruster")
	var shock := _shock_scene.instantiate() as ShockwaveArea
	shock.setup(spawn_pos, child_ctx, 0.85 + 0.1 * float(stack_count - 1))
	var spawn_parent: Node = tree.current_scene if tree.current_scene else tree.root
	spawn_parent.add_child(shock)
