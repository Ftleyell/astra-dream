class_name WeaponController
extends Node2D

signal laser_cooldown_updated(current: float, max_val: float)
signal laser_charge_updated(current: float, max_val: float, is_full: bool, is_memorized: bool)
signal laser_charge_ended()
signal weapons_updated(weapons: Array)
signal aim_mode_changed(is_manual: bool)

@export var weapon_data: WeaponData
@export var player: Player

const MAX_WEAPON_SLOTS: int = 6

var equipped_weapons: Array[WeaponInstanceData] = []

# Modo de apuntado de la capa pasiva (Auto-aimed en radio de recogida vs Manual al puntero)
var is_manual_aim: bool = false
var current_locked_target: Node2D = null

# Carga de la capa activa unificada

var is_charging: bool = false
var charge_timer: float = 0.0
var max_charge_time: float = 3.0
var is_fully_charged: bool = false

# Memoria de carga en pausa (Charge Memory)
var has_charge_memory: bool = false
var memory_charge_timer: float = 0.0
var memory_is_fully_charged: bool = false
var memory_grace_timer: float = 0.0
const MEMORY_GRACE_MAX: float = 6.0

# Precarga de escenas de proyectiles y efectos
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
var last_known_target_dir: Vector2 = Vector2.UP

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not player and get_parent() is Player:
		player = get_parent() as Player

	if weapon_data:
		add_weapon(weapon_data)

	elif equipped_weapons.is_empty():
		# Cargar arma default si no hay ninguna
		var default_w := WeaponData.new()
		default_w.weapon_id = &"rail_launcher"
		default_w.weapon_name = "Cañón Rail-Launcher Mk.I"
		default_w.base_damage = 40.0
		default_w.base_cooldown = 1.0
		default_w.passive_interval = 1.6
		default_w.passive_search_radius = 520.0
		add_weapon(default_w)

func clear_equipped_weapons() -> void:
	equipped_weapons.clear()
	weapons_updated.emit(equipped_weapons)

## ─── Nova Omega Spin API ────────────────────────────────────────────────────

## Retorna true si el láser tiene carga máxima activa (normal o en memoria).
func is_laser_fully_charged() -> bool:
	return is_fully_charged or memory_is_fully_charged

## Consume la carga del láser: resetea todo el estado de carga y emite laser_charge_ended.
## Llamar esto antes de disparar el Omega Spin para que no se duplique el tiro.
func consume_laser_charge() -> void:
	is_charging = false
	charge_timer = 0.0
	is_fully_charged = false
	has_charge_memory = false
	memory_charge_timer = 0.0
	memory_is_fully_charged = false
	memory_grace_timer = 0.0
	laser_charge_ended.emit()

## ────────────────────────────────────────────────────────────────────────────

func add_weapon(data: WeaponData) -> bool:
	if not data:
		return false

	# 1. Comprobar si ya existe para subir de nivel
	for inst in equipped_weapons:
		if inst.weapon_data.weapon_id == data.weapon_id:
			return upgrade_weapon(data.weapon_id)

	# 2. Si no existe y hay cupo libre (< 6)
	if equipped_weapons.size() < MAX_WEAPON_SLOTS:
		var new_inst := WeaponInstanceData.new(data, 1)
		equipped_weapons.append(new_inst)
		weapons_updated.emit(equipped_weapons)
		return true

	return false

func upgrade_weapon(weapon_id: StringName) -> bool:
	for inst in equipped_weapons:
		if inst.weapon_data.weapon_id == weapon_id:
			if inst.level < 5:
				inst.level += 1
				weapons_updated.emit(equipped_weapons)
				var audio_mgr := get_node_or_null("/root/AudioManager")
				if audio_mgr and audio_mgr.has_method("play_sfx"):
					audio_mgr.play_sfx("ui_click", 1.8, 4.0)
				return true
			return false
	return false

func get_weapon_instance(weapon_id: StringName) -> WeaponInstanceData:
	for inst in equipped_weapons:
		if inst.weapon_data.weapon_id == weapon_id:
			return inst
	return null

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		if is_charging and charge_timer > 0.05:
			has_charge_memory = true
			memory_charge_timer = charge_timer
			memory_is_fully_charged = is_fully_charged
			memory_grace_timer = MEMORY_GRACE_MAX

func _process(delta: float) -> void:
	_handle_toggle_input()
	_update_locked_target()
	_handle_aim()
	_handle_active_fire(delta)
	_handle_passive_fire(delta)

func _handle_toggle_input() -> void:
	if Input.is_action_just_pressed("toggle_aim_mode"):
		if player and player.has_method("is_any_menu_or_modal_active") and player.is_any_menu_or_modal_active():
			return
		toggle_aim_mode()

## Alterna entre modo Automático (objetivo en radio de recogida) y Manual (orientado al cursor)
func toggle_aim_mode() -> void:
	is_manual_aim = not is_manual_aim
	aim_mode_changed.emit(is_manual_aim)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 1.6 if is_manual_aim else 1.2, 0.0)

func _update_locked_target() -> void:
	if is_manual_aim:
		current_locked_target = null
	else:
		current_locked_target = _find_closest_enemy_in_pickup_radius()

## Rango de búsqueda para auto-apuntado:
## Base de pantalla completa (850px), escalando con el radio de atracción/imán.
func get_autoaim_range() -> float:
	var base_range: float = 850.0
	var pickup_bonus: float = 0.0
	if player and player.stats:
		var current_pickup: float = player.stats.get_stat(&"pickup_radius")
		var base_pickup: float = player.character_data.pickup_radius if (player.character_data and player.character_data.pickup_radius > 0.0) else 100.0
		pickup_bonus = maxf(0.0, current_pickup - base_pickup)
	return base_range + pickup_bonus * 1.5

func _find_closest_enemy_in_pickup_radius() -> Node2D:
	var search_rad: float = get_autoaim_range()
	var rad_sq := search_rad * search_rad
	var tree := get_tree()
	if not tree:
		return null

	var nearest: Node2D = null
	var min_dist_sq := rad_sq

	var candidates: Array[Node] = []
	candidates.append_array(tree.get_nodes_in_group("enemies"))
	candidates.append_array(tree.get_nodes_in_group("emitters"))

	for node in candidates:
		if node is Node2D and is_instance_valid(node) and not node.is_queued_for_deletion() and not node.get("is_dying"):
			var d_sq := global_position.distance_squared_to((node as Node2D).global_position)
			if d_sq <= min_dist_sq:
				min_dist_sq = d_sq
				nearest = node as Node2D

	return nearest


func _get_passive_aim_info() -> Dictionary:
	if is_manual_aim:
		var dir := (get_global_mouse_position() - global_position).normalized()
		if dir.length_squared() < 0.001:
			dir = Vector2.UP
		return { "direction": dir, "target": null }

	# Modo Automático: enemigo más cercano dentro del radio de pantalla
	var target := current_locked_target if is_instance_valid(current_locked_target) else _find_closest_enemy_in_pickup_radius()
	if target and is_instance_valid(target):
		var dir := (target.global_position - global_position).normalized()
		if dir.length_squared() < 0.001:
			dir = Vector2.UP
		last_known_target_dir = dir
		return { "direction": dir, "target": target }

	# Fallback cuando no hay enemigos en pantalla:
	# Mantener la última dirección válida de hostiles en vez de disparar hacia la velocidad de huida
	if last_known_target_dir.length_squared() > 0.001:
		return { "direction": last_known_target_dir, "target": null }

	var fallback_dir := Vector2.UP
	if player and "last_facing_direction" in player and player.last_facing_direction.length_squared() > 0.001:
		fallback_dir = player.last_facing_direction.normalized()
	elif rotation != 0.0:
		fallback_dir = Vector2.from_angle(rotation)

	return { "direction": fallback_dir, "target": null }

func _handle_aim() -> void:
	if player and player.is_omega_spinning:
		return
	if is_manual_aim:
		look_at(get_global_mouse_position())
	else:
		if current_locked_target and is_instance_valid(current_locked_target):
			look_at(current_locked_target.global_position)
		elif Input.is_action_pressed("fire_active"):
			look_at(get_global_mouse_position())
		else:
			var info := _get_passive_aim_info()
			look_at(global_position + info.direction * 100.0)



func _handle_active_fire(delta: float) -> void:
	# Actualizar cooldowns individuales de todas las armas equipadas
	for inst in equipped_weapons:
		if inst.active_cooldown > 0.0:
			inst.active_cooldown -= delta

	# Comprobar si hay al menos un arma láser equipada
	var laser_inst: WeaponInstanceData = null
	for inst in equipped_weapons:
		if inst.weapon_data and inst.weapon_data.active_behavior_type == &"laser":
			laser_inst = inst
			break

	# Para el HUD emitimos el cooldown (del láser prioritariamente, o del arma primaria)
	if laser_inst:
		var max_cd := laser_inst.get_effective_cooldown(player.stats if player else null)
		laser_cooldown_updated.emit(maxf(0.0, laser_inst.active_cooldown), max_cd)
	elif not equipped_weapons.is_empty():
		var primary := equipped_weapons[0]
		var max_cd := primary.get_effective_cooldown(player.stats if player else null)
		laser_cooldown_updated.emit(maxf(0.0, primary.active_cooldown), max_cd)

	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT

	# 1. DISPARO INSTANTÁNEO / TAP PARA TODAS LAS ARMAS NO-LÁSER
	# Se disparan inmediatamente al presionar o mantener fire_active si su cooldown está listo
	if Input.is_action_pressed("fire_active"):
		for inst in equipped_weapons:
			if inst.weapon_data and inst.weapon_data.active_behavior_type != &"laser":
				if inst.active_cooldown <= 0.0:
					_dispatch_weapon_active_fire(inst, aim_dir, false, 0.0)
					inst.active_cooldown = inst.get_effective_cooldown(player.stats if player else null)

	# 2. MECÁNICA DE CARGA EXCLUSIVA PARA EL LÁSER
	if laser_inst:
		# Gestión de memoria de carga
		if has_charge_memory:
			memory_grace_timer -= delta
			if memory_grace_timer <= 0.0:
				has_charge_memory = false
				laser_charge_ended.emit()
			else:
				laser_charge_updated.emit(memory_charge_timer, max_charge_time, memory_is_fully_charged, true)

		# Mantenimiento del clic -> Cargar láser
		if Input.is_action_pressed("fire_active"):
			if laser_inst.active_cooldown <= 0.0:
				if not is_charging:
					is_charging = true
					charge_timer = 0.0
					is_fully_charged = false

				charge_timer += delta
				if charge_timer >= max_charge_time:
					charge_timer = max_charge_time
					if not is_fully_charged:
						is_fully_charged = true
						var audio_mgr := get_node_or_null("/root/AudioManager")
						if audio_mgr and audio_mgr.has_method("play_sfx"):
							audio_mgr.play_sfx("ui_click", 2.0, -2.0)

				laser_charge_updated.emit(charge_timer, max_charge_time, is_fully_charged, false)
			else:
				if is_charging:
					is_charging = false
					charge_timer = 0.0
					laser_charge_ended.emit()

		# Liberación del clic -> Fuego del láser
		elif Input.is_action_just_released("fire_active"):
			var ready_to_fire := false
			var charge_to_use := 0.0
			var full_to_use := false

			if is_charging:
				charge_to_use = charge_timer
				full_to_use = is_fully_charged
				ready_to_fire = true
			elif has_charge_memory:
				charge_to_use = memory_charge_timer
				full_to_use = memory_is_fully_charged
				ready_to_fire = true
			elif laser_inst.active_cooldown <= 0.0:
				ready_to_fire = true

			if ready_to_fire:
				for inst in equipped_weapons:
					if inst.weapon_data and inst.weapon_data.active_behavior_type == &"laser":
						if inst.active_cooldown <= 0.0:
							_dispatch_weapon_active_fire(inst, aim_dir, full_to_use, charge_to_use)
							inst.active_cooldown = inst.get_effective_cooldown(player.stats if player else null)

			is_charging = false
			charge_timer = 0.0
			is_fully_charged = false
			has_charge_memory = false
			laser_charge_ended.emit()

		# Sin presionar botón activo
		else:
			if is_charging:
				if charge_timer > 0.05:
					has_charge_memory = true
					memory_charge_timer = charge_timer
					memory_is_fully_charged = is_fully_charged
					memory_grace_timer = MEMORY_GRACE_MAX
				is_charging = false
				charge_timer = 0.0
				is_fully_charged = false
				if not has_charge_memory:
					laser_charge_ended.emit()
	else:
		# Si no hay láser equipado, apagar cualquier estado de carga residual
		if is_charging or has_charge_memory:
			is_charging = false
			charge_timer = 0.0
			is_fully_charged = false
			has_charge_memory = false
			laser_charge_ended.emit()

func _fire_all_active_weapons(is_focused: bool, charge_amount: float) -> void:
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT

	for inst in equipped_weapons:
		if inst.active_cooldown <= 0.0:
			_dispatch_weapon_active_fire(inst, aim_dir, is_focused, charge_amount)
			inst.active_cooldown = inst.get_effective_cooldown(player.stats if player else null)

func _dispatch_weapon_active_fire(inst: WeaponInstanceData, aim_dir: Vector2, is_focused: bool, charge_ratio: float) -> void:
	var wdata := inst.weapon_data
	var base_dmg := inst.get_effective_damage(player.stats if player else null)
	var crit_chance: float = player.stats.get_stat(&"crit_chance") if player else 0.05
	var is_crit := (randf() <= crit_chance) or (player != null and player.has_method("consume_guaranteed_crit") and player.consume_guaranteed_crit())
	var crit_mult: float = player.stats.get_stat(&"crit_damage") if player else 1.5
	var final_dmg := base_dmg * (crit_mult if is_crit else 1.0)
	var size_stat: float = player.stats.get_stat(&"weapon_size") if player else 1.0
	var proj_speed: float = player.stats.get_stat(&"projectile_speed") if player else 1.0

	var ctx := HitContext.new()
	ctx.attacker = player
	ctx.raw_damage = base_dmg
	ctx.final_damage = final_dmg
	ctx.is_crit = is_crit
	ctx.proc_coefficient = wdata.proc_coefficient
	ctx.hit_position = global_position

	var count := wdata.active_burst_count
	if wdata.scales_with_projectile_count and wdata.active_scales_with_projectiles and player:
		count += maxi(0, int(player.stats.get_stat(&"projectile_count")) - 1)

	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root

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
				laser.setup(global_position, l_dir, ctx)
				spawn_parent.add_child(laser)

		&"projectile": # Francotirador, agujas
			for i in range(count):
				var offset_rad := deg_to_rad((float(i) - float(count - 1) / 2.0) * wdata.active_spread_deg)
				var p_dir := aim_dir.rotated(offset_rad)
				var proj: KineticProjectile = kinetic_scene.instantiate() as KineticProjectile
				proj.speed = 1100.0 if wdata.weapon_id == &"sniper_rifle" else 850.0
				proj.pierces_max = 3 if wdata.weapon_id == &"sniper_rifle" else 1
				proj.setup(global_position, p_dir, ctx, player, proj_speed, size_stat)
				spawn_parent.add_child(proj)

		&"shotgun": # Roxanne escopeta sísmica
			var pellets := count * 4
			for i in range(pellets):
				var offset_rad := deg_to_rad(randf_range(-wdata.active_spread_deg, wdata.active_spread_deg))
				var p_dir := aim_dir.rotated(offset_rad)
				var proj: KineticProjectile = kinetic_scene.instantiate() as KineticProjectile
				proj.speed = randf_range(700.0, 950.0)
				proj.lifetime = 0.45
				proj.setup(global_position, p_dir, ctx, player, proj_speed, size_stat * 1.2)
				spawn_parent.add_child(proj)
			# Retroceso leve
			if player:
				player.velocity -= aim_dir * 180.0

		&"singularity": # Selene vórtice
			var mouse_pos := get_global_mouse_position()
			var vortex: SingularityVortex = vortex_scene.instantiate() as SingularityVortex
			vortex.setup(mouse_pos, ctx, size_stat)
			spawn_parent.add_child(vortex)

		&"chain": # Echo Arco Tesla
			var mouse_pos := get_global_mouse_position()
			var chain: ChainLightningEffect = chain_scene.instantiate() as ChainLightningEffect
			chain.setup(global_position, mouse_pos, ctx, 4 + count)
			spawn_parent.add_child(chain)

		&"cluster": # Lanzagranadas
			var mouse_pos := get_global_mouse_position()
			var cluster: ClusterGrenade = cluster_scene.instantiate() as ClusterGrenade
			cluster.setup(global_position, mouse_pos, ctx, player)
			spawn_parent.add_child(cluster)

		&"solar": # Rayo Solar continuo
			var solar: SolarBeam = solar_scene.instantiate() as SolarBeam
			solar.setup(global_position, aim_dir, ctx, size_stat)
			spawn_parent.add_child(solar)

		&"boomerang": # Cuchilla dimensional
			for i in range(count):
				var offset_rad := deg_to_rad((float(i) - float(count - 1) / 2.0) * 15.0)
				var b_dir := aim_dir.rotated(offset_rad)
				var proj: KineticProjectile = kinetic_scene.instantiate() as KineticProjectile
				proj.is_boomerang = true
				proj.speed = 780.0
				proj.pierces_max = 999
				proj.lifetime = 1.4
				proj.setup(global_position, b_dir, ctx, player, proj_speed, size_stat * 1.3)
				spawn_parent.add_child(proj)

		&"crescent_cyclone":
			var cyclone = crescent_cyclone_scene.instantiate()
			spawn_parent.add_child(cyclone)
			cyclone.setup(global_position, ctx, size_stat * 1.2)

		_:
			# Fallback a láser
			var laser: ScreenLaserBeam = laser_scene.instantiate() as ScreenLaserBeam
			laser.setup(global_position, aim_dir, ctx)
			spawn_parent.add_child(laser)

	# Sonido
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		if wdata.weapon_id == &"titan_shotgun" or wdata.weapon_id == &"cluster_submunition":
			audio_mgr.play_sfx("explosion", 1.2, 0.0)
		elif wdata.weapon_id == &"tesla_arc" or wdata.weapon_id == &"hive_cannon":
			audio_mgr.play_sfx("dash", 1.5, -2.0)
		else:
			audio_mgr.play_sfx("laser", 1.0, 0.0)

	if player and player.inventory:
		player.inventory.process_hit_procs(ctx, player)

func _handle_passive_fire(delta: float) -> void:
	for inst in equipped_weapons:
		inst.passive_timer -= delta
		if inst.passive_timer <= 0.0:
			inst.passive_timer = inst.get_effective_passive_interval(player.stats if player else null)
			_dispatch_weapon_passive_fire(inst)

func _dispatch_weapon_passive_fire(inst: WeaponInstanceData) -> void:
	var wdata := inst.weapon_data
	var base_dmg := inst.get_effective_damage(player.stats if player else null) * 0.75
	var crit_chance: float = player.stats.get_stat(&"crit_chance") if player else 0.05
	var is_crit := randf() <= crit_chance
	var crit_mult: float = player.stats.get_stat(&"crit_damage") if player else 1.5
	var final_dmg := base_dmg * (crit_mult if is_crit else 1.0)
	var size_stat: float = player.stats.get_stat(&"weapon_size") if player else 1.0

	var ctx := HitContext.new()
	ctx.attacker = player
	ctx.raw_damage = base_dmg
	ctx.final_damage = final_dmg
	ctx.is_crit = is_crit
	ctx.proc_coefficient = wdata.proc_coefficient * 0.6
	ctx.hit_position = global_position

	var count := 1
	if wdata.scales_with_projectile_count and wdata.passive_scales_with_projectiles and player:
		count = maxi(1, int(player.stats.get_stat(&"projectile_count")))

	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root

	match wdata.passive_behavior_type:
		&"missile":
			_fire_homing_missiles(ctx, count, wdata.passive_search_radius)

		&"orbital": # Drones Kira
			_maintain_orbital_drones(ctx, count)

		&"shockwave": # Selene onda gravitacional
			var shock: ShockwaveArea = shockwave_scene.instantiate() as ShockwaveArea
			shock.setup(global_position, ctx, size_stat)
			spawn_parent.add_child(shock)

		&"mortar": # Roxanne mortero
			var aim_info := _get_passive_aim_info()
			var target_pos := Vector2.ZERO
			if is_manual_aim:
				target_pos = get_global_mouse_position()
			elif aim_info.target and is_instance_valid(aim_info.target):
				target_pos = aim_info.target.global_position
			else:
				var forward_dist: float = get_autoaim_range()
				target_pos = global_position + aim_info.direction * forward_dist

			var shock: ShockwaveArea = shockwave_scene.instantiate() as ShockwaveArea
			shock.setup(target_pos, ctx, size_stat * 1.3)
			spawn_parent.add_child(shock)

		&"chain_pulse": # Echo pulso tesla
			var aim_info := _get_passive_aim_info()
			var target_pos := Vector2.ZERO
			if is_manual_aim:
				target_pos = get_global_mouse_position()
			elif aim_info.target and is_instance_valid(aim_info.target):
				target_pos = aim_info.target.global_position
			else:
				var forward_dist: float = get_autoaim_range()
				target_pos = global_position + aim_info.direction * forward_dist


			var chain: ChainLightningEffect = chain_scene.instantiate() as ChainLightningEffect
			chain.setup(global_position, target_pos, ctx, 3)
			spawn_parent.add_child(chain)

		&"boomerang": # Cuchilla orbital
			var p_dir := Vector2.from_angle(randf() * TAU)
			var proj: KineticProjectile = kinetic_scene.instantiate() as KineticProjectile
			proj.is_boomerang = true
			proj.speed = 650.0
			proj.pierces_max = 999
			proj.lifetime = 1.2
			proj.setup(global_position, p_dir, ctx, player, 1.0, size_stat)
			spawn_parent.add_child(proj)

		&"crescent_slash":
			var aim_info := _get_passive_aim_info()
			var slash_dir: Vector2 = aim_info.direction
			if is_manual_aim:
				slash_dir = (get_global_mouse_position() - global_position).normalized()
			var slash = crescent_slash_scene.instantiate()
			spawn_parent.add_child(slash)
			slash.setup(global_position, slash_dir, ctx, count, size_stat)

		_:
			_fire_homing_missiles(ctx, count, wdata.passive_search_radius)

func _fire_homing_missiles(ctx: HitContext, count: int, _search_radius: float = 0.0) -> void:
	var aim_info := _get_passive_aim_info()
	var base_dir: Vector2 = aim_info.direction
	var assigned_target: Node2D = aim_info.target
	var spread_deg: float = 16.0
	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root

	for i in range(count):
		var offset_rad := deg_to_rad((float(i) - float(count - 1) / 2.0) * spread_deg)
		var m_dir := base_dir.rotated(offset_rad)
		var missile: HomingMissile = missile_scene.instantiate() as HomingMissile
		# En línea recta (estilo Picayune):
		# Si hay 1 solo misil y hay target directo, se fija a él.
		# Si hay múltiples misiles, cada uno sale en abanico con su m_dir.
		var missile_target: Node2D = assigned_target if count == 1 else null
		missile.setup(global_position, m_dir, ctx, missile_target)
		spawn_parent.add_child(missile)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("missile")


func _maintain_orbital_drones(ctx: HitContext, desired_count: int) -> void:
	# Filtrar drones muertos
	active_drones = active_drones.filter(func(d): return is_instance_valid(d))
	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root

	while active_drones.size() < desired_count:
		var drone: OrbitalDrone = drone_scene.instantiate() as OrbitalDrone
		var angle := float(active_drones.size()) * TAU / float(maxi(1, desired_count))
		drone.setup(self, angle, ctx)
		spawn_parent.add_child(drone)
		active_drones.append(drone)

func _get_candidates_in_range(radius: float) -> Array[Node2D]:
	var r_sq := radius * radius
	var candidates: Array[Node2D] = []
	var tree := get_tree()
	if not tree:
		return candidates

	for node in tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("emitters"):
		if is_instance_valid(node) and node is Node2D and not node.get("is_dying"):
			if global_position.distance_squared_to(node.global_position) <= r_sq:
				candidates.append(node as Node2D)
	candidates.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	return candidates

func _find_target_by_mode(mode: Enums.TargetMode, radius: float) -> Node2D:
	var candidates := _get_candidates_in_range(radius)
	if candidates.is_empty():
		return null
	match mode:
		Enums.TargetMode.NEAREST:
			return candidates[0]
		Enums.TargetMode.RANDOM:
			return candidates.pick_random()
		_:
			return candidates[0]
