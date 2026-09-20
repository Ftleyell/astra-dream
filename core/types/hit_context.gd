class_name HitContext
extends RefCounted

var attacker: Node = null
var victim: Node = null
var raw_damage: float = 0.0
var final_damage: float = 0.0
var is_crit: bool = false
var proc_coefficient: float = 1.0
var depth: int = 0
var hit_position: Vector2 = Vector2.ZERO
var proc_chain: Array[StringName] = []

const MAX_DEPTH: int = 4

func fork_child_hit(new_damage: float, new_proc_coeff: float, triggered_by: StringName) -> HitContext:
	var child := HitContext.new()
	child.attacker = attacker
	child.victim = null
	child.raw_damage = new_damage
	child.final_damage = new_damage
	child.is_crit = false
	child.proc_coefficient = new_proc_coeff
	child.depth = depth + 1
	child.proc_chain = proc_chain.duplicate()
	if not child.proc_chain.has(triggered_by):
		child.proc_chain.append(triggered_by)
	return child

func can_proc(item_id: StringName) -> bool:
	if depth >= MAX_DEPTH:
		return false
	if proc_coefficient <= 0.0:
		return false
	if proc_chain.has(item_id):
		return false
	return true
