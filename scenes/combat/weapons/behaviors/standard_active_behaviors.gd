class_name StandardActiveBehaviors
extends RefCounted

## Catálogo de estrategias de comportamiento de disparo activo estándar.

const ProjectileBehaviorClass = preload("res://scenes/combat/weapons/behaviors/projectile_behavior.gd")

class LaserBehavior extends ProjectileBehaviorClass:
	var laser_scene: PackedScene
	func _init(scene: PackedScene) -> void: laser_scene = scene

	func execute(wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, aim_dir: Vector2, is_focused: bool, charge_ratio: float, max_charge_time: float, _player: CharacterBody2D, origin: Vector2, _mouse_pos: Vector2, spawn_parent: Node, count: int, _proj_speed: float, _size_stat: float) -> void:
		var dmg_mult := 2.2 if is_focused else lerpf(1.0, 1.6, clampf(charge_ratio / max_charge_time, 0.0, 1.0))
		ctx.raw_damage *= dmg_mult
		ctx.final_damage *= dmg_mult
		for i in range(count):
			var offset_rad := 0.0
			if not is_focused and count > 1:
				offset_rad = deg_to_rad((float(i) - float(count - 1) / 2.0) * wdata.active_spread_deg)
			var l_dir := aim_dir.rotated(offset_rad)
			var laser: ScreenLaserBeam = laser_scene.instantiate() as ScreenLaserBeam
			laser.setup(origin, l_dir, ctx)
			spawn_parent.add_child(laser)

class KineticBehavior extends ProjectileBehaviorClass:
	var kinetic_scene: PackedScene
	func _init(scene: PackedScene) -> void: kinetic_scene = scene

	func execute(wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, aim_dir: Vector2, _is_focused: bool, _charge_ratio: float, _max_charge_time: float, player: CharacterBody2D, origin: Vector2, _mouse_pos: Vector2, spawn_parent: Node, count: int, proj_speed: float, size_stat: float) -> void:
		for i in range(count):
			var offset_rad := deg_to_rad((float(i) - float(count - 1) / 2.0) * wdata.active_spread_deg)
			var p_dir := aim_dir.rotated(offset_rad)
			var proj: KineticProjectile = kinetic_scene.instantiate() as KineticProjectile
			proj.speed = 1100.0 if wdata.weapon_id == &"sniper_rifle" else 850.0
			proj.pierces_max = 3 if wdata.weapon_id == &"sniper_rifle" else 1
			proj.setup(origin, p_dir, ctx, player, proj_speed, size_stat)
			spawn_parent.add_child(proj)

class ShotgunBehavior extends ProjectileBehaviorClass:
	var kinetic_scene: PackedScene
	func _init(scene: PackedScene) -> void: kinetic_scene = scene

	func execute(wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, aim_dir: Vector2, _is_focused: bool, _charge_ratio: float, _max_charge_time: float, player: CharacterBody2D, origin: Vector2, _mouse_pos: Vector2, spawn_parent: Node, count: int, proj_speed: float, size_stat: float) -> void:
		var pellets := count * 4
		for i in range(pellets):
			var offset_rad := deg_to_rad(randf_range(-wdata.active_spread_deg, wdata.active_spread_deg))
			var p_dir := aim_dir.rotated(offset_rad)
			var proj: KineticProjectile = kinetic_scene.instantiate() as KineticProjectile
			proj.speed = randf_range(700.0, 950.0)
			proj.lifetime = 0.45
			proj.setup(origin, p_dir, ctx, player, proj_speed, size_stat * 1.2)
			spawn_parent.add_child(proj)
		if player and "velocity" in player:
			player.velocity -= aim_dir * 180.0

class SingularityBehavior extends ProjectileBehaviorClass:
	var vortex_scene: PackedScene
	func _init(scene: PackedScene) -> void: vortex_scene = scene

	func execute(_wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, _aim_dir: Vector2, _is_focused: bool, _charge_ratio: float, _max_charge_time: float, _player: CharacterBody2D, _origin: Vector2, mouse_pos: Vector2, spawn_parent: Node, _count: int, _proj_speed: float, size_stat: float) -> void:
		var vortex: SingularityVortex = vortex_scene.instantiate() as SingularityVortex
		vortex.setup(mouse_pos, ctx, size_stat)
		spawn_parent.add_child(vortex)

class ChainBehavior extends ProjectileBehaviorClass:
	var chain_scene: PackedScene
	func _init(scene: PackedScene) -> void: chain_scene = scene

	func execute(_wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, _aim_dir: Vector2, _is_focused: bool, _charge_ratio: float, _max_charge_time: float, _player: CharacterBody2D, origin: Vector2, mouse_pos: Vector2, spawn_parent: Node, count: int, _proj_speed: float, _size_stat: float) -> void:
		var chain: ChainLightningEffect = chain_scene.instantiate() as ChainLightningEffect
		chain.setup(origin, mouse_pos, ctx, 4 + count)
		spawn_parent.add_child(chain)

class ClusterBehavior extends ProjectileBehaviorClass:
	var cluster_scene: PackedScene
	func _init(scene: PackedScene) -> void: cluster_scene = scene

	func execute(_wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, _aim_dir: Vector2, _is_focused: bool, _charge_ratio: float, _max_charge_time: float, player: CharacterBody2D, origin: Vector2, mouse_pos: Vector2, spawn_parent: Node, _count: int, _proj_speed: float, _size_stat: float) -> void:
		var cluster: ClusterGrenade = cluster_scene.instantiate() as ClusterGrenade
		cluster.setup(origin, mouse_pos, ctx, player)
		spawn_parent.add_child(cluster)

class SolarBehavior extends ProjectileBehaviorClass:
	var solar_scene: PackedScene
	func _init(scene: PackedScene) -> void: solar_scene = scene

	func execute(_wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, aim_dir: Vector2, _is_focused: bool, _charge_ratio: float, _max_charge_time: float, _player: CharacterBody2D, origin: Vector2, _mouse_pos: Vector2, spawn_parent: Node, _count: int, _proj_speed: float, size_stat: float) -> void:
		var solar: SolarBeam = solar_scene.instantiate() as SolarBeam
		solar.setup(origin, aim_dir, ctx, size_stat)
		spawn_parent.add_child(solar)

class BoomerangActiveBehavior extends ProjectileBehaviorClass:
	var kinetic_scene: PackedScene
	func _init(scene: PackedScene) -> void: kinetic_scene = scene

	func execute(_wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, aim_dir: Vector2, _is_focused: bool, _charge_ratio: float, _max_charge_time: float, player: CharacterBody2D, origin: Vector2, _mouse_pos: Vector2, spawn_parent: Node, count: int, proj_speed: float, size_stat: float) -> void:
		for i in range(count):
			var offset_rad := deg_to_rad((float(i) - float(count - 1) / 2.0) * 15.0)
			var b_dir := aim_dir.rotated(offset_rad)
			var proj: KineticProjectile = kinetic_scene.instantiate() as KineticProjectile
			proj.is_boomerang = true
			proj.speed = 780.0
			proj.pierces_max = 999
			proj.lifetime = 1.4
			proj.setup(origin, b_dir, ctx, player, proj_speed, size_stat * 1.3)
			spawn_parent.add_child(proj)

class CrescentCycloneBehavior extends ProjectileBehaviorClass:
	var crescent_cyclone_scene: PackedScene
	func _init(scene: PackedScene) -> void: crescent_cyclone_scene = scene

	func execute(_wdata: WeaponData, _inst: WeaponInstanceData, ctx: HitContext, _aim_dir: Vector2, _is_focused: bool, _charge_ratio: float, _max_charge_time: float, player: CharacterBody2D, origin: Vector2, _mouse_pos: Vector2, spawn_parent: Node, _count: int, _proj_speed: float, size_stat: float) -> void:
		var cyclone = crescent_cyclone_scene.instantiate()
		spawn_parent.add_child(cyclone)
		cyclone.setup(origin, ctx, size_stat * 1.2, player)
