class_name PassiveProjectileBehavior
extends RefCounted

## Interfaz base para estrategias de disparo pasivo de armas (WeaponProjectileFactory).
## Permite añadir nuevos comportamientos pasivos de forma modular y mod-friendly.

func execute(
	wdata: WeaponData,
	inst: WeaponInstanceData,
	ctx: HitContext,
	aim_info: Dictionary,
	is_manual_aim: bool,
	mouse_pos: Vector2,
	autoaim_range: float,
	player: CharacterBody2D,
	origin: Vector2,
	weapon_node: Node2D,
	spawn_parent: Node,
	count: int,
	size_stat: float,
	factory: WeaponProjectileFactory
) -> void:
	pass
