class_name WeaponController
extends Node2D

signal laser_cooldown_updated(current: float, max_val: float)

@export var weapon_data: WeaponData
@export var player: Player
@export var equip_plasma_on_start: bool = true

var active_cooldown: float = 0.0
var passive_timer: float = 0.1 # Inicia disparando inmediatamente al spawnear

# Escenas por defecto (Rail-Launcher)
var laser_scene: PackedScene = preload("res://scenes/combat/weapons/screen_laser_beam.tscn")
var missile_scene: PackedScene = preload("res://scenes/combat/weapons/homing_missile.tscn")

# Escenas de Plasma Shotgun
var plasma_pellet_scene: PackedScene = preload("res://scenes/combat/weapons/plasma_pellet.tscn")
var orbital_satellite_scene: PackedScene = preload("res://scenes/combat/weapons/orbital_satellite.tscn")
var plasma_shotgun_res: WeaponData = preload("res://data/weapons/plasma_shotgun.tres")

# Satélites orbitales activos
var active_satellites: Array[OrbitalSatellite] = []
const REQUIRED_SATELLITES: int = 2

@onready var weapon_visual: Polygon2D = get_node_or_null("WeaponVisual")

func _ready() -> void:
	if not player and is_inside_tree():
		var p := get_parent()
		if p is Player:
			player = p

	if equip_plasma_on_start and plasma_shotgun_res:
		equip_weapon(plasma_shotgun_res)
	elif not weapon_data:
		_setup_default_railgun()

	passive_timer = 0.1

func _unhandled_input(event: InputEvent) -> void:
	# Teclas de desarrollo para alternar armas durante el gameplay sin modificar main_game.tscn
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_setup_default_railgun()
		elif event.keycode == KEY_2 and plasma_shotgun_res:
			equip_weapon(plasma_shotgun_res)

func _setup_default_railgun() -> void:
	_cleanup_satellites()
	weapon_data = WeaponData.new()
	weapon_data.weapon_id = &"weapon_default"
	weapon_data.weapon_name = "Cañón Rail-Launcher Mk.I"
	weapon_data.base_damage = 40.0
	weapon_data.base_cooldown = 1.0 # Cooldown del láser
	weapon_data.passive_interval = 1.6 # Intervalo del misil auto-aim
	weapon_data.proc_coefficient = 1.0

	if weapon_visual:
		weapon_visual.color = Color(1.0, 0.8, 0.2, 1.0) # Dorado/Ámbar

func equip_weapon(new_data: WeaponData) -> void:
	_cleanup_satellites()
	weapon_data = new_data
	active_cooldown = 0.0

	if weapon_data.weapon_id == &"plasma_shotgun":
		if weapon_visual:
			weapon_visual.color = Color(0.2, 0.85, 1.0, 1.0) # Azul Plasma
		call_deferred("_ensure_satellites")

func _process(delta: float) -> void:
	_handle_aim()
	_handle_active_fire(delta)
	_handle_passive_fire(delta)

	if weapon_data and weapon_data.weapon_id == &"plasma_shotgun":
		_ensure_satellites()

func _handle_aim() -> void:
	var mouse_pos := get_global_mouse_position()
	look_at(mouse_pos)

func _handle_active_fire(delta: float) -> void:
	if active_cooldown > 0.0:
		active_cooldown -= delta

	var atk_speed: float = player.stats.get_stat(&"attack_speed") if (player and player.stats) else 1.0
	var max_cd: float = weapon_data.base_cooldown / maxf(0.1, atk_speed)
	laser_cooldown_updated.emit(maxf(0.0, active_cooldown), max_cd)

	if Input.is_action_pressed("fire_active") and active_cooldown <= 0.0:
		active_cooldown = max_cd
		if weapon_data.weapon_id == &"plasma_shotgun":
			_fire_active_plasma_shotgun()
		else:
			_fire_active_laser()

func _fire_active_plasma_shotgun() -> void:
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT

	var base_dmg: float = weapon_data.base_damage + (player.stats.get_stat(&"base_damage") if (player and player.stats) else 0.0)
	var crit_chance: float = player.stats.get_stat(&"crit_chance") if (player and player.stats) else 0.05
	var is_crit := randf() <= crit_chance
	var crit_mult: float = player.stats.get_stat(&"crit_damage") if (player and player.stats) else 1.5
	var final_dmg := base_dmg * (crit_mult if is_crit else 1.0)

	var burst_count: int = max(1, weapon_data.active_burst_count)
	var spread_deg: float = weapon_data.active_spread_deg
	var spread_rad: float = deg_to_rad(spread_deg)
	var start_angle: float = aim_dir.angle() - (spread_rad * 0.5)
	var step: float = spread_rad / float(burst_count - 1) if burst_count > 1 else 0.0

	var root_scene := get_tree().current_scene if is_inside_tree() else null

	for i in range(burst_count):
		var pellet_angle: float = start_angle + float(i) * step
		var pellet_dir := Vector2.from_angle(pellet_angle)

		var ctx := HitContext.new()
		ctx.attacker = player
		ctx.raw_damage = base_dmg
		ctx.final_damage = final_dmg
		ctx.is_crit = is_crit
		ctx.proc_coefficient = weapon_data.proc_coefficient
		ctx.hit_position = global_position

		var pellet: PlasmaPellet = plasma_pellet_scene.instantiate() as PlasmaPellet
		pellet.setup(global_position, pellet_dir, ctx)
		if root_scene:
			root_scene.add_child(pellet)

	_trigger_weapon_recoil()

func _fire_active_laser() -> void:
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT

	var base_dmg: float = weapon_data.base_damage + (player.stats.get_stat(&"base_damage") if (player and player.stats) else 0.0)
	var crit_chance: float = player.stats.get_stat(&"crit_chance") if (player and player.stats) else 0.05
	var is_crit := randf() <= crit_chance
	var crit_mult: float = player.stats.get_stat(&"crit_damage") if (player and player.stats) else 1.5
	var final_dmg := base_dmg * (crit_mult if is_crit else 1.0)

	var ctx := HitContext.new()
	ctx.attacker = player
	ctx.raw_damage = base_dmg
	ctx.final_damage = final_dmg
	ctx.is_crit = is_crit
	ctx.proc_coefficient = weapon_data.proc_coefficient
	ctx.hit_position = global_position

	var laser: ScreenLaserBeam = laser_scene.instantiate() as ScreenLaserBeam
	laser.setup(global_position, aim_dir, ctx)
	get_tree().current_scene.add_child(laser)

	if player and player.inventory:
		player.inventory.process_hit_procs(ctx, player)

func _handle_passive_fire(delta: float) -> void:
	if weapon_data.weapon_id == &"plasma_shotgun":
		# En PlasmaShotgun la capa pasiva son los satélites autónomos persistentes
		return

	passive_timer -= delta
	if passive_timer <= 0.0:
		var atk_speed: float = player.stats.get_stat(&"attack_speed") if (player and player.stats) else 1.0
		passive_timer = weapon_data.passive_interval / maxf(0.1, atk_speed)
		_fire_passive_missile()

func _fire_passive_missile() -> void:
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.UP

	var base_dmg: float = (weapon_data.base_damage * 0.75) + (player.stats.get_stat(&"base_damage") if (player and player.stats) else 0.0)
	var crit_chance: float = player.stats.get_stat(&"crit_chance") if (player and player.stats) else 0.05
	var is_crit := randf() <= crit_chance
	var crit_mult: float = player.stats.get_stat(&"crit_damage") if (player and player.stats) else 1.5
	var final_dmg := base_dmg * (crit_mult if is_crit else 1.0)

	var ctx := HitContext.new()
	ctx.attacker = player
	ctx.raw_damage = base_dmg
	ctx.final_damage = final_dmg
	ctx.is_crit = is_crit
	ctx.proc_coefficient = weapon_data.proc_coefficient * 0.6
	ctx.hit_position = global_position

	var missile: HomingMissile = missile_scene.instantiate() as HomingMissile
	missile.setup(global_position, aim_dir, ctx)
	get_tree().current_scene.add_child(missile)

func _ensure_satellites() -> void:
	if not is_inside_tree() or not is_instance_valid(player):
		return

	var valid: Array[OrbitalSatellite] = []
	for sat in active_satellites:
		if is_instance_valid(sat) and sat.is_inside_tree():
			valid.append(sat)
	active_satellites = valid

	if active_satellites.size() < REQUIRED_SATELLITES:
		var root_scene := get_tree().current_scene
		if not root_scene:
			return

		for i in range(REQUIRED_SATELLITES):
			var exists := false
			for sat in active_satellites:
				if sat.orbit_index == i:
					exists = true
					break

			if not exists:
				var new_sat: OrbitalSatellite = orbital_satellite_scene.instantiate() as OrbitalSatellite
				root_scene.add_child(new_sat)

				var ctx := HitContext.new()
				ctx.attacker = player
				ctx.raw_damage = weapon_data.base_damage * 0.8
				ctx.final_damage = weapon_data.base_damage * 0.8
				ctx.proc_coefficient = 0.25

				new_sat.setup(player, i, REQUIRED_SATELLITES, ctx)
				if player and player.bullet_server:
					new_sat.bullet_server = player.bullet_server
				active_satellites.append(new_sat)

func _trigger_weapon_recoil() -> void:
	if weapon_visual:
		var original_x := 16.0
		weapon_visual.position.x = original_x - 6.0
		var tween := weapon_visual.create_tween()
		tween.tween_property(weapon_visual, "position:x", original_x, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _cleanup_satellites() -> void:
	for sat in active_satellites:
		if is_instance_valid(sat):
			sat.queue_free()
	active_satellites.clear()

func _exit_tree() -> void:
	_cleanup_satellites()
