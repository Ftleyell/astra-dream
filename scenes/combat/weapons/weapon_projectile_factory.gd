class_name WeaponProjectileFactory
extends RefCounted

## WeaponProjectileFactory.gd
## Fábrica y despachador balístico modular de proyectiles, lásers, vórtices y drones para WeaponController.
## Desacopla la instanciación de escenas de combate y sus parámetros de contexto balístico.

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

	var count := wdata.active_burst_count
	if wdata.scales_with_projectile_count and wdata.active_scales_with_projectiles and player and "stats" in player:
		count += maxi(0, int(player.stats.get_stat(&"projectile_count")) - 1)
	count += maxi(0, inst.level - 1)

	match wdata.active_behavior_type:
		&"laser":
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

		&"projectile":
			for i in range(count):
				var offset_rad := deg_to_rad((float(i) - float(count - 1) / 2.0) * wdata.active_spread_deg)
				var p_dir := aim_dir.rotated(offset_rad)
				var proj: KineticProjectile = kinetic_scene.instantiate() as KineticProjectile
				proj.speed = 1100.0 if wdata.weapon_id == &"sniper_rifle" else 850.0
				proj.pierces_max = 3 if wdata.weapon_id == &"sniper_rifle" else 1
				proj.setup(origin, p_dir, ctx, player, proj_speed, size_stat)
				spawn_parent.add_child(proj)

		&"shotgun":
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

		&"singularity":
			var vortex: SingularityVortex = vortex_scene.instantiate() as SingularityVortex
			vortex.setup(mouse_pos, ctx, size_stat)
			spawn_parent.add_child(vortex)

		&"chain":
			var chain: ChainLightningEffect = chain_scene.instantiate() as ChainLightningEffect
			chain.setup(origin, mouse_pos, ctx, 4 + count)
			spawn_parent.add_child(chain)

		&"cluster":
			var cluster: ClusterGrenade = cluster_scene.instantiate() as ClusterGrenade
			cluster.setup(origin, mouse_pos, ctx, player)
			spawn_parent.add_child(cluster)

		&"solar":
			var solar: SolarBeam = solar_scene.instantiate() as SolarBeam
			solar.setup(origin, aim_dir, ctx, size_stat)
			spawn_parent.add_child(solar)

		&"boomerang":
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

		&"crescent_cyclone":
			var cyclone = crescent_cyclone_scene.instantiate()
			spawn_parent.add_child(cyclone)
			cyclone.setup(origin, ctx, size_stat * 1.2, player)

		_:
			var laser: ScreenLaserBeam = laser_scene.instantiate() as ScreenLaserBeam
			laser.setup(origin, aim_dir, ctx)
			spawn_parent.add_child(laser)

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

	var count := 1
	if wdata.scales_with_projectile_count and wdata.passive_scales_with_projectiles and player and "stats" in player:
		count = maxi(1, int(player.stats.get_stat(&"projectile_count"))) + maxi(0, inst.level - 1)
	else:
		count += maxi(0, inst.level - 1)

	match wdata.passive_behavior_type:
		&"missile":
			fire_homing_missiles(ctx, count, aim_info, origin, spawn_parent)

		&"orbital":
			maintain_orbital_drones(ctx, count, weapon_node, spawn_parent)

		&"shockwave":
			var shock: ShockwaveArea = shockwave_scene.instantiate() as ShockwaveArea
			shock.setup(origin, ctx, size_stat)
			spawn_parent.add_child(shock)

		&"mortar":
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

		&"chain_pulse":
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

		&"boomerang":
			var p_dir := Vector2.from_angle(randf() * TAU)
			var proj: KineticProjectile = kinetic_scene.instantiate() as KineticProjectile
			proj.is_boomerang = true
			proj.speed = 650.0
			proj.pierces_max = 999
			proj.lifetime = 1.2
			proj.setup(origin, p_dir, ctx, player, 1.0, size_stat)
			spawn_parent.add_child(proj)

		&"crescent_slash":
			var slash_dir: Vector2 = aim_info.get("direction", Vector2.UP)
			if is_manual_aim:
				slash_dir = (mouse_pos - origin).normalized()
			var slash = crescent_slash_scene.instantiate()
			spawn_parent.add_child(slash)
			slash.setup(origin, slash_dir, ctx, count, size_stat)

		_:
			fire_homing_missiles(ctx, count, aim_info, origin, spawn_parent)


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
