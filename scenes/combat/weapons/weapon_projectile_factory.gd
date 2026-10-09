class_name WeaponProjectileFactory
extends RefCounted

## WeaponProjectileFactory.gd
## Fábrica y despachador balístico modular de proyectiles, lásers, vórtices y drones para WeaponController.
## Emplea un registro abierto de estrategias (ProjectileBehavior / PassiveProjectileBehavior)
## permitiendo extensión sin modificar código central (Open/Closed Principle para mods).

const ProjectileBehaviorClass = preload("res://scenes/combat/weapons/behaviors/projectile_behavior.gd")
const PassiveProjectileBehaviorClass = preload("res://scenes/combat/weapons/behaviors/passive_projectile_behavior.gd")
const StandardActiveBehaviorsClass = preload("res://scenes/combat/weapons/behaviors/standard_active_behaviors.gd")
const StandardPassiveBehaviorsClass = preload("res://scenes/combat/weapons/behaviors/standard_passive_behaviors.gd")

var laser_scene: PackedScene = preload("res://scenes/combat/weapons/screen_laser_beam.tscn")
var missile_scene: PackedScene = preload("res://scenes/combat/weapons/homing_missile.tscn")
var kinetic_scene: PackedScene = preload("res://scenes/combat/weapons/kinetic_projectile.tscn")
var vortex_scene: PackedScene = preload("res://scenes/combat/weapons/singularity_vortex.tscn")
var chain_scene: PackedScene = preload("res://scenes/combat/weapons/chain_lightning_effect.tscn")
var shockwave_scene: PackedScene = preload("res://scenes/combat/weapons/shockwave_area.tscn")
var drone_scene: PackedScene = preload("res://scenes/combat/weapons/orbital_drone.tscn")
var cluster_scene: PackedScene = preload("res://scenes/combat/weapons/cluster_grenade.tscn")
var solar_scene: PackedScene = preload("res://scenes/combat/weapons/solar_beam.tscn")
var crescent_slash_scene: PackedScene = preload("res://scenes/combat/weapons/crescent_slash.tscn")
var crescent_cyclone_scene: PackedScene = preload("res://scenes/combat/weapons/crescent_cyclone.tscn")

var active_drones: Array[Node2D] = []

var _active_behaviors: Dictionary = {}
var _passive_behaviors: Dictionary = {}

func _init() -> void:
	_register_default_behaviors()

func register_active_behavior(type_id: StringName, behavior: RefCounted) -> void:
	_active_behaviors[type_id] = behavior

func register_passive_behavior(type_id: StringName, behavior: RefCounted) -> void:
	_passive_behaviors[type_id] = behavior

func _register_default_behaviors() -> void:
	register_active_behavior(&"laser", StandardActiveBehaviorsClass.LaserBehavior.new(laser_scene))
	register_active_behavior(&"projectile", StandardActiveBehaviorsClass.KineticBehavior.new(kinetic_scene))
	register_active_behavior(&"shotgun", StandardActiveBehaviorsClass.ShotgunBehavior.new(kinetic_scene))
	register_active_behavior(&"singularity", StandardActiveBehaviorsClass.SingularityBehavior.new(vortex_scene))
	register_active_behavior(&"chain", StandardActiveBehaviorsClass.ChainBehavior.new(chain_scene))
	register_active_behavior(&"cluster", StandardActiveBehaviorsClass.ClusterBehavior.new(cluster_scene))
	register_active_behavior(&"solar", StandardActiveBehaviorsClass.SolarBehavior.new(solar_scene))
	register_active_behavior(&"boomerang", StandardActiveBehaviorsClass.BoomerangActiveBehavior.new(kinetic_scene))
	register_active_behavior(&"crescent_cyclone", StandardActiveBehaviorsClass.CrescentCycloneBehavior.new(crescent_cyclone_scene))

	register_passive_behavior(&"missile", StandardPassiveBehaviorsClass.MissilePassiveBehavior.new())
	register_passive_behavior(&"orbital", StandardPassiveBehaviorsClass.OrbitalPassiveBehavior.new())
	register_passive_behavior(&"shockwave", StandardPassiveBehaviorsClass.ShockwavePassiveBehavior.new(shockwave_scene))
	register_passive_behavior(&"mortar", StandardPassiveBehaviorsClass.MortarPassiveBehavior.new(shockwave_scene))
	register_passive_behavior(&"chain_pulse", StandardPassiveBehaviorsClass.ChainPulsePassiveBehavior.new(chain_scene))
	register_passive_behavior(&"boomerang", StandardPassiveBehaviorsClass.BoomerangPassiveBehavior.new(kinetic_scene))
	register_passive_behavior(&"crescent_slash", StandardPassiveBehaviorsClass.CrescentSlashPassiveBehavior.new(crescent_slash_scene))

func dispatch_active_fire(
	inst: WeaponInstanceData,
	aim_dir: Vector2,
	is_focused: bool,
	charge_ratio: float,
	max_charge_time: float,
	player: CharacterBody2D,
	origin: Vector2,
	mouse_pos: Vector2,
	spawn_parent: Node
) -> void:
	if not inst or not inst.weapon_data or not spawn_parent:
		return

	var wdata := inst.weapon_data
	var base_dmg := inst.get_effective_damage(player.stats if player and "stats" in player else null)
	var crit_chance: float = player.stats.get_stat(&"crit_chance") if player and "stats" in player else 0.05
	var is_crit: bool = (randf() <= crit_chance)
	if not is_crit and player != null and player.has_method("consume_guaranteed_crit"):
		is_crit = bool(player.consume_guaranteed_crit())
	var crit_mult: float = player.stats.get_stat(&"crit_damage") if player and "stats" in player else 1.5
	var final_dmg := base_dmg * (crit_mult if is_crit else 1.0)
	var size_stat: float = player.stats.get_stat(&"weapon_size") if player and "stats" in player else 1.0
	var proj_speed: float = player.stats.get_stat(&"projectile_speed") if player and "stats" in player else 1.0

	var ctx := HitContext.new()
	ctx.attacker = player
	ctx.raw_damage = base_dmg
	ctx.final_damage = final_dmg
	ctx.is_crit = is_crit
	ctx.proc_coefficient = wdata.proc_coefficient
	ctx.hit_position = origin
	ctx.source_weapon_id = wdata.weapon_id
	ctx.weapon_level = inst.level

	if wdata.base_cooldown > 1.1:
		check_and_trigger_point_blank_pulse(origin, base_dmg, player, spawn_parent)

	var count := wdata.active_burst_count
	if wdata.scales_with_projectile_count and wdata.active_scales_with_projectiles and player and "stats" in player:
		count += maxi(0, int(player.stats.get_stat(&"projectile_count")) - 1)
	count += maxi(0, inst.level - 1)

	var behavior: ProjectileBehaviorClass = _active_behaviors.get(wdata.active_behavior_type, null)
	if not behavior:
		behavior = _active_behaviors.get(&"laser", null)

	if behavior:
		behavior.execute(
			wdata, inst, ctx, aim_dir, is_focused, charge_ratio,
			max_charge_time, player, origin, mouse_pos, spawn_parent,
			count, proj_speed, size_stat
		)

	_play_fire_sfx(wdata.weapon_id)

	if player and "inventory" in player and player.inventory:
		player.inventory.process_hit_procs(ctx, player)

func dispatch_passive_fire(
	inst: WeaponInstanceData,
	aim_info: Dictionary,
	is_manual_aim: bool,
	mouse_pos: Vector2,
	autoaim_range: float,
	player: CharacterBody2D,
	origin: Vector2,
	weapon_node: Node2D,
	spawn_parent: Node
) -> void:
	if not inst or not inst.weapon_data or not spawn_parent:
		return

	var wdata := inst.weapon_data
	var base_dmg := inst.get_effective_damage(player.stats if player and "stats" in player else null) * 0.75
	var crit_chance: float = player.stats.get_stat(&"crit_chance") if player and "stats" in player else 0.05
	var is_crit := randf() <= crit_chance
	var crit_mult: float = player.stats.get_stat(&"crit_damage") if player and "stats" in player else 1.5
	var final_dmg := base_dmg * (crit_mult if is_crit else 1.0)
	var size_stat: float = player.stats.get_stat(&"weapon_size") if player and "stats" in player else 1.0

	var ctx := HitContext.new()
	ctx.attacker = player
	ctx.raw_damage = base_dmg
	ctx.final_damage = final_dmg
	ctx.is_crit = is_crit
	ctx.proc_coefficient = wdata.proc_coefficient * 0.6
	ctx.hit_position = origin
	ctx.source_weapon_id = wdata.weapon_id
	ctx.weapon_level = inst.level

	var count := 1
	if wdata.scales_with_projectile_count and wdata.passive_scales_with_projectiles and player and "stats" in player:
		count = maxi(1, int(player.stats.get_stat(&"projectile_count"))) + maxi(0, inst.level - 1)
	else:
		count += maxi(0, inst.level - 1)

	var p_behavior: PassiveProjectileBehaviorClass = _passive_behaviors.get(wdata.passive_behavior_type, null)
	if not p_behavior:
		p_behavior = _passive_behaviors.get(&"missile", null)

	if p_behavior:
		p_behavior.execute(
			wdata, inst, ctx, aim_info, is_manual_aim, mouse_pos,
			autoaim_range, player, origin, weapon_node, spawn_parent,
			count, size_stat, self
		)

func fire_homing_missiles(
	ctx: HitContext,
	count: int,
	aim_info: Dictionary,
	origin: Vector2,
	spawn_parent: Node
) -> void:
	var base_dir: Vector2 = aim_info.get("direction", Vector2.UP)
	var assigned_target: Node2D = aim_info.get("target", null)
	var spread_deg: float = 16.0

	for i in range(count):
		var offset_rad := deg_to_rad((float(i) - float(count - 1) / 2.0) * spread_deg)
		var m_dir := base_dir.rotated(offset_rad)
		var missile: HomingMissile = missile_scene.instantiate() as HomingMissile
		var missile_target: Node2D = assigned_target if count == 1 else null
		missile.setup(origin, m_dir, ctx, missile_target)
		spawn_parent.add_child(missile)

	var tree := Engine.get_main_loop() as SceneTree
	var audio_mgr: Node = tree.root.get_node_or_null("AudioManager") if tree and tree.root else null
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("missile")

func maintain_orbital_drones(ctx: HitContext, desired_count: int, weapon_node: Node2D, spawn_parent: Node) -> void:
	active_drones = active_drones.filter(func(d: Node2D) -> bool: return is_instance_valid(d))

	while active_drones.size() < desired_count:
		var drone: OrbitalDrone = drone_scene.instantiate() as OrbitalDrone
		var angle := float(active_drones.size()) * TAU / float(maxi(1, desired_count))
		drone.setup(weapon_node, angle, ctx)
		spawn_parent.add_child(drone)
		active_drones.append(drone)

func _play_fire_sfx(weapon_id: StringName) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var audio_mgr: Node = tree.root.get_node_or_null("AudioManager") if tree and tree.root else null
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		if weapon_id == &"titan_shotgun" or weapon_id == &"cluster_submunition":
			audio_mgr.play_sfx("explosion", 1.2, 0.0)
		elif weapon_id == &"tesla_arc" or weapon_id == &"hive_cannon":
			audio_mgr.play_sfx("dash", 1.5, -2.0)
		else:
			audio_mgr.play_sfx("laser", 1.0, 0.0)

func check_and_trigger_point_blank_pulse(origin: Vector2, base_dmg: float, player: CharacterBody2D, spawn_parent: Node) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		return false
	var enemies := tree.get_nodes_in_group("enemies")
	var nearby_enemies: Array[Node2D] = []
	for node in enemies:
		if is_instance_valid(node) and (node is Node2D):
			var enemy := node as Node2D
			if origin.distance_to(enemy.global_position) < 80.0:
				nearby_enemies.append(enemy)

	if nearby_enemies.is_empty():
		return false

	var pulse_ctx := HitContext.create_direct_hit(base_dmg * 0.30, false, 0.0)
	pulse_ctx.attacker = player
	pulse_ctx.hit_position = origin
	pulse_ctx.source_weapon_id = &"point_blank_pulse"

	for enemy in nearby_enemies:
		if enemy.has_method("take_damage"):
			var hit := HitContext.create_direct_hit(base_dmg * 0.30, false, 0.0)
			hit.attacker = player
			hit.hit_position = enemy.global_position
			hit.source_weapon_id = &"point_blank_pulse"
			enemy.take_damage(hit)

		var push_dir := (enemy.global_position - origin).normalized()
		if push_dir.length_squared() < 0.001:
			push_dir = Vector2.RIGHT
		if "velocity" in enemy:
			enemy.velocity += push_dir * 250.0
		else:
			enemy.global_position += push_dir * (250.0 * 0.1)

	var shock: ShockwaveArea = shockwave_scene.instantiate() as ShockwaveArea
	if shock:
		shock.setup(origin, pulse_ctx, 80.0 / 220.0)
		shock.push_force = 250.0
		for enemy in nearby_enemies:
			shock.damaged_nodes.append(enemy)
		spawn_parent.add_child(shock)

	return true
