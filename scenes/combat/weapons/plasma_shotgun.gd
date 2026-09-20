class_name PlasmaShotgun
extends Node2D

signal cooldown_updated(current: float, max_val: float)

@export var weapon_data: WeaponData
@export var player: Player

@export var pellet_scene: PackedScene = preload("res://scenes/combat/weapons/plasma_pellet.tscn")
@export var satellite_scene: PackedScene = preload("res://scenes/combat/weapons/orbital_satellite.tscn")

var active_cooldown: float = 0.0
var active_satellites: Array[OrbitalSatellite] = []
const REQUIRED_SATELLITES: int = 2

@onready var muzzle_point: Marker2D = get_node_or_null("MuzzlePoint")
@onready var weapon_mesh: Polygon2D = get_node_or_null("WeaponMesh")
@onready var muzzle_flash: Polygon2D = get_node_or_null("MuzzleFlash")

func _ready() -> void:
	if not player and is_inside_tree():
		var parent_node := get_parent()
		if parent_node is Player:
			player = parent_node
		else:
			player = get_tree().get_first_node_in_group("player") as Player

	if not weapon_data:
		weapon_data = preload("res://data/weapons/plasma_shotgun.tres") if ResourceLoader.exists("res://data/weapons/plasma_shotgun.tres") else WeaponData.new()
		if weapon_data.weapon_id == &"weapon_default":
			weapon_data.weapon_id = &"plasma_shotgun"
			weapon_data.weapon_name = "Escopeta de Plasma Astra-V"
			weapon_data.base_damage = 18.0
			weapon_data.base_cooldown = 0.75
			weapon_data.proc_coefficient = 0.6
			weapon_data.active_burst_count = 5
			weapon_data.active_spread_deg = 36.0

	if muzzle_flash:
		muzzle_flash.visible = false

	# Inicializar la capa pasiva: Satélites orbitales
	call_deferred("_ensure_orbital_satellites")

func _process(delta: float) -> void:
	_handle_aim()
	_handle_active_fire(delta)
	_ensure_orbital_satellites()

func _handle_aim() -> void:
	var mouse_pos := get_global_mouse_position()
	look_at(mouse_pos)

func _handle_active_fire(delta: float) -> void:
	if active_cooldown > 0.0:
		active_cooldown -= delta

	var atk_speed: float = player.stats.get_stat(&"attack_speed") if (player and player.stats) else 1.0
	var max_cd: float = weapon_data.base_cooldown / maxf(0.1, atk_speed)
	cooldown_updated.emit(maxf(0.0, active_cooldown), max_cd)

	if Input.is_action_pressed("fire_active") and active_cooldown <= 0.0:
		active_cooldown = max_cd
		fire_active()

func fire_active() -> void:
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT

	var base_dmg: float = weapon_data.base_damage + (player.stats.get_stat(&"base_damage") if (player and player.stats) else 0.0)
	var crit_chance: float = player.stats.get_stat(&"crit_chance") if (player and player.stats) else 0.05
	var is_crit := randf() <= crit_chance
	var crit_mult: float = player.stats.get_stat(&"crit_damage") if (player and player.stats) else 1.5
	var final_dmg := base_dmg * (crit_mult if is_crit else 1.0)

	var spawn_pos: Vector2 = muzzle_point.global_position if muzzle_point else global_position
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
		ctx.hit_position = spawn_pos

		var pellet: PlasmaPellet = pellet_scene.instantiate() as PlasmaPellet
		pellet.setup(spawn_pos, pellet_dir, ctx)
		if root_scene:
			root_scene.add_child(pellet)

	_trigger_fire_feedback()

func _ensure_orbital_satellites() -> void:
	if not is_inside_tree() or not is_instance_valid(player):
		return

	# Limpiar referencias muertas
	var valid_satellites: Array[OrbitalSatellite] = []
	for sat in active_satellites:
		if is_instance_valid(sat) and sat.is_inside_tree():
			valid_satellites.append(sat)
	active_satellites = valid_satellites

	# Si falta alguno de los 2 satélites protectores, reponerlo
	if active_satellites.size() < REQUIRED_SATELLITES:
		var root_scene := get_tree().current_scene
		if not root_scene:
			return

		for i in range(REQUIRED_SATELLITES):
			var has_slot := false
			for sat in active_satellites:
				if sat.orbit_index == i:
					has_slot = true
					break

			if not has_slot:
				var new_sat: OrbitalSatellite = satellite_scene.instantiate() as OrbitalSatellite
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

func _trigger_fire_feedback() -> void:
	# Destello del cañón
	if muzzle_flash:
		muzzle_flash.visible = true
		muzzle_flash.scale = Vector2(1.4, 1.4)
		var flash_tween := muzzle_flash.create_tween()
		flash_tween.tween_property(muzzle_flash, "scale", Vector2(0.5, 0.5), 0.07)
		flash_tween.tween_callback(func(): muzzle_flash.visible = false)

	# Retroceso visual en la malla del arma
	if weapon_mesh:
		var original_pos := weapon_mesh.position
		weapon_mesh.position.x = original_pos.x - 7.0
		var recoil_tween := weapon_mesh.create_tween()
		recoil_tween.tween_property(weapon_mesh, "position:x", original_pos.x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func cleanup_satellites() -> void:
	for sat in active_satellites:
		if is_instance_valid(sat):
			sat.queue_free()
	active_satellites.clear()

func _exit_tree() -> void:
	cleanup_satellites()
