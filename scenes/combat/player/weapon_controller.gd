class_name WeaponController
extends Node2D

signal laser_cooldown_updated(current: float, max_val: float)

@export var weapon_data: WeaponData
@export var player: Player

var active_cooldown: float = 0.0
var passive_timer: float = 0.1 # Inicia disparando inmediatamente al spawnear

var laser_scene: PackedScene = preload("res://scenes/combat/weapons/screen_laser_beam.tscn")
var missile_scene: PackedScene = preload("res://scenes/combat/weapons/homing_missile.tscn")

func _ready() -> void:
	if not weapon_data:
		weapon_data = WeaponData.new()
		weapon_data.weapon_name = "Cañón Rail-Launcher Mk.I"
		weapon_data.base_damage = 40.0
		weapon_data.base_cooldown = 1.0 # Cooldown del láser
		weapon_data.passive_interval = 1.6 # Intervalo del misil auto-aim

	# Disparo pasivo inicial inmediato
	passive_timer = 0.1

func _process(delta: float) -> void:
	_handle_aim()
	_handle_active_fire(delta)
	_handle_passive_fire(delta)

func _handle_aim() -> void:
	var mouse_pos := get_global_mouse_position()
	look_at(mouse_pos)

func _handle_active_fire(delta: float) -> void:
	if active_cooldown > 0.0:
		active_cooldown -= delta

	var max_cd: float = weapon_data.base_cooldown / maxf(0.1, player.stats.get_stat(&"attack_speed") if player else 1.0)
	laser_cooldown_updated.emit(maxf(0.0, active_cooldown), max_cd)

	if Input.is_action_pressed("fire_active") and active_cooldown <= 0.0:
		active_cooldown = max_cd
		_fire_active_laser()

func _fire_active_laser() -> void:
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT

	var count := 1
	if weapon_data.scales_with_projectile_count and weapon_data.active_scales_with_projectiles and player:
		count = maxi(1, int(player.stats.get_stat(&"projectile_count")))

	var base_dmg: float = weapon_data.base_damage + (player.stats.get_stat(&"base_damage") if player else 0.0)
	var crit_chance: float = player.stats.get_stat(&"crit_chance") if player else 0.05
	var is_crit := randf() <= crit_chance
	var crit_mult: float = player.stats.get_stat(&"crit_damage") if player else 1.5
	var final_dmg := base_dmg * (crit_mult if is_crit else 1.0)

	var ctx := HitContext.new()
	ctx.attacker = player
	ctx.raw_damage = base_dmg
	ctx.final_damage = final_dmg
	ctx.is_crit = is_crit
	ctx.proc_coefficient = weapon_data.proc_coefficient
	ctx.hit_position = global_position

	for i in range(count):
		var offset_rad := deg_to_rad((float(i) - float(count - 1) / 2.0) * weapon_data.active_spread_deg)
		var laser_dir := aim_dir.rotated(offset_rad)
		var laser: ScreenLaserBeam = laser_scene.instantiate() as ScreenLaserBeam
		laser.setup(global_position, laser_dir, ctx)
		get_tree().current_scene.add_child(laser)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("laser")

	if player and player.inventory:
		player.inventory.process_hit_procs(ctx, player)

func _handle_passive_fire(delta: float) -> void:
	passive_timer -= delta
	if passive_timer <= 0.0:
		var atk_speed: float = player.stats.get_stat(&"attack_speed") if player else 1.0
		passive_timer = weapon_data.passive_interval / maxf(0.1, atk_speed)
		_fire_passive_missile()

func _fire_passive_missile() -> void:
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.UP

	var count := 1
	if weapon_data.scales_with_projectile_count and weapon_data.passive_scales_with_projectiles and player:
		count = maxi(1, int(player.stats.get_stat(&"projectile_count")))

	var base_dmg: float = (weapon_data.base_damage * 0.75) + (player.stats.get_stat(&"base_damage") if player else 0.0)
	var crit_chance: float = player.stats.get_stat(&"crit_chance") if player else 0.05
	var is_crit := randf() <= crit_chance
	var crit_mult: float = player.stats.get_stat(&"crit_damage") if player else 1.5
	var final_dmg := base_dmg * (crit_mult if is_crit else 1.0)

	var ctx := HitContext.new()
	ctx.attacker = player
	ctx.raw_damage = base_dmg
	ctx.final_damage = final_dmg
	ctx.is_crit = is_crit
	ctx.proc_coefficient = weapon_data.proc_coefficient * 0.6
	ctx.hit_position = global_position

	var candidates: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("emitters"):
		if is_instance_valid(node) and node is Node2D and not node.get("is_dying"):
			candidates.append(node as Node2D)
	candidates.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))

	var spread_deg: float = 16.0
	for i in range(count):
		var offset_rad := deg_to_rad((float(i) - float(count - 1) / 2.0) * spread_deg)
		var m_dir := aim_dir.rotated(offset_rad)
		var assigned_target: Node2D = candidates[i % candidates.size()] if not candidates.is_empty() else null
		var missile: HomingMissile = missile_scene.instantiate() as HomingMissile
		missile.setup(global_position, m_dir, ctx, assigned_target)
		get_tree().current_scene.add_child(missile)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("missile")
