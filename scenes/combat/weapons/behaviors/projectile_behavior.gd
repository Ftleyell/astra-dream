class_name ProjectileBehavior
extends RefCounted

## Interfaz base para estrategias de disparo activo de armas (WeaponProjectileFactory).
## Permite añadir nuevos comportamientos balísticos de forma modular y mod-friendly.

func execute(
	wdata: WeaponData,
	inst: WeaponInstanceData,
	ctx: HitContext,
	aim_dir: Vector2,
	is_focused: bool,
	charge_ratio: float,
	max_charge_time: float,
	player: CharacterBody2D,
	origin: Vector2,
	mouse_pos: Vector2,
	spawn_parent: Node,
	count: int,
	proj_speed: float,
	size_stat: float
) -> void:
	pass
