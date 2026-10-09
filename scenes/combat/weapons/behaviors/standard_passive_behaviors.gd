class_name StandardPassiveBehaviors
extends RefCounted

## Catálogo de estrategias de comportamiento de disparo pasivo estándar.

const PassiveProjectileBehaviorClass = preload("res://scenes/combat/weapons/behaviors/passive_projectile_behavior.gd")

class MissilePassiveBehavior extends PassiveProjectileBehaviorClass:
	func execute(_wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, aim_info: Dictionary, _is_manual_aim: bool, _mouse_pos: Vector2, _autoaim_range: float, _player: CharacterBody2D, origin: Vector2, _weapon_node: Node2D, spawn_parent: Node, count: int, _size_stat: float, factory: WeaponProjectileFactory) -> void:
		factory.fire_homing_missiles(ctx, count, aim_info, origin, spawn_parent)

class OrbitalPassiveBehavior extends PassiveProjectileBehaviorClass:
	func execute(_wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, _aim_info: Dictionary, _is_manual_aim: bool, _mouse_pos: Vector2, _autoaim_range: float, _player: CharacterBody2D, _origin: Vector2, weapon_node: Node2D, spawn_parent: Node, count: int, _size_stat: float, factory: WeaponProjectileFactory) -> void:
		factory.maintain_orbital_drones(ctx, count, weapon_node, spawn_parent)

class ShockwavePassiveBehavior extends PassiveProjectileBehaviorClass:
	var shockwave_scene: PackedScene
	func _init(scene: PackedScene) -> void: shockwave_scene = scene

	func execute(_wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, _aim_info: Dictionary, _is_manual_aim: bool, _mouse_pos: Vector2, _autoaim_range: float, _player: CharacterBody2D, origin: Vector2, _weapon_node: Node2D, spawn_parent: Node, _count: int, size_stat: float, _factory: WeaponProjectileFactory) -> void:
		var shock: ShockwaveArea = shockwave_scene.instantiate() as ShockwaveArea
		shock.setup(origin, ctx, size_stat)
		spawn_parent.add_child(shock)

class MortarPassiveBehavior extends PassiveProjectileBehaviorClass:
	var shockwave_scene: PackedScene
	func _init(scene: PackedScene) -> void: shockwave_scene = scene

	func execute(_wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, aim_info: Dictionary, is_manual_aim: bool, mouse_pos: Vector2, autoaim_range: float, _player: CharacterBody2D, origin: Vector2, _weapon_node: Node2D, spawn_parent: Node, _count: int, size_stat: float, _factory: WeaponProjectileFactory) -> void:
		var target_pos := Vector2.ZERO
		if is_manual_aim:
			target_pos = mouse_pos
		elif aim_info.get("target") and is_instance_valid(aim_info.target):
			target_pos = aim_info.target.global_position
		else:
			var dir: Vector2 = aim_info.get("direction", Vector2.UP)
			target_pos = origin + dir * autoaim_range

		var shock: ShockwaveArea = shockwave_scene.instantiate() as ShockwaveArea
		shock.setup(target_pos, ctx, size_stat * 1.3)
		spawn_parent.add_child(shock)

class ChainPulsePassiveBehavior extends PassiveProjectileBehaviorClass:
	var chain_scene: PackedScene
	func _init(scene: PackedScene) -> void: chain_scene = scene

	func execute(_wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, aim_info: Dictionary, is_manual_aim: bool, mouse_pos: Vector2, autoaim_range: float, _player: CharacterBody2D, origin: Vector2, _weapon_node: Node2D, spawn_parent: Node, _count: int, _size_stat: float, _factory: WeaponProjectileFactory) -> void:
		var target_pos := Vector2.ZERO
		if is_manual_aim:
			target_pos = mouse_pos
		elif aim_info.get("target") and is_instance_valid(aim_info.target):
			target_pos = aim_info.target.global_position
		else:
			var dir: Vector2 = aim_info.get("direction", Vector2.UP)
			target_pos = origin + dir * autoaim_range

		var chain: ChainLightningEffect = chain_scene.instantiate() as ChainLightningEffect
		chain.setup(origin, target_pos, ctx, 3)
		spawn_parent.add_child(chain)

class BoomerangPassiveBehavior extends PassiveProjectileBehaviorClass:
	var kinetic_scene: PackedScene
	func _init(scene: PackedScene) -> void: kinetic_scene = scene

	func execute(_wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, _aim_info: Dictionary, _is_manual_aim: bool, _mouse_pos: Vector2, _autoaim_range: float, player: CharacterBody2D, origin: Vector2, _weapon_node: Node2D, spawn_parent: Node, _count: int, size_stat: float, _factory: WeaponProjectileFactory) -> void:
		var p_dir := Vector2.from_angle(randf() * TAU)
		var proj: KineticProjectile = kinetic_scene.instantiate() as KineticProjectile
		proj.is_boomerang = true
		proj.speed = 650.0
		proj.pierces_max = 999
		proj.lifetime = 1.2
		proj.setup(origin, p_dir, ctx, player, 1.0, size_stat)
		spawn_parent.add_child(proj)

class CrescentSlashPassiveBehavior extends PassiveProjectileBehaviorClass:
	var crescent_slash_scene: PackedScene
	func _init(scene: PackedScene) -> void: crescent_slash_scene = scene

	func execute(_wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, aim_info: Dictionary, is_manual_aim: bool, mouse_pos: Vector2, _autoaim_range: float, _player: CharacterBody2D, origin: Vector2, _weapon_node: Node2D, spawn_parent: Node, count: int, size_stat: float, _factory: WeaponProjectileFactory) -> void:
		var slash_dir: Vector2 = aim_info.get("direction", Vector2.UP)
		if is_manual_aim:
			slash_dir = (mouse_pos - origin).normalized()
		var slash = crescent_slash_scene.instantiate()
		spawn_parent.add_child(slash)
		slash.setup(origin, slash_dir, ctx, count, size_stat)
