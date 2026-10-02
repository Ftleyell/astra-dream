class_name PhaseInverterEffect
extends ItemEffect

var _vfx_scene: PackedScene = preload("res://scenes/combat/weapons/kinetic_impact_vfx.tscn")
var _last_proc_msec: int = 0

func _init() -> void:
	trigger = Enums.TriggerType.ON_HIT
	base_chance = 0.20
	proc_coefficient = 0.4

func execute(context: HitContext, _stack_count: int, source_entity: Node) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_proc_msec < 2500:
		return
	_last_proc_msec = now

	if source_entity is Player:
		var p := source_entity as Player
		p.set_meta("phase_inverter_shield", true)
		var tw := p.create_tween()
		if tw:
			tw.tween_property(p, "modulate", Color(0.3, 1.5, 2.0, 1.0), 0.1)
			tw.tween_property(p, "modulate", Color.WHITE, 0.25)

	if source_entity and is_instance_valid(source_entity):
		var tree := source_entity.get_tree()
		if tree:
			var spawn_pos: Vector2 = context.hit_position
			if spawn_pos == Vector2.ZERO and source_entity is Node2D:
				spawn_pos = (source_entity as Node2D).global_position
			var vfx = _vfx_scene.instantiate()
			if vfx.has_method("setup"):
				vfx.setup(spawn_pos)
			elif vfx is Node2D:
				(vfx as Node2D).global_position = spawn_pos
			var spawn_parent: Node = tree.current_scene if tree.current_scene else tree.root
			spawn_parent.add_child(vfx)
