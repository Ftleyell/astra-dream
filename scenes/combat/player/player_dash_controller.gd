class_name PlayerDashController
extends Node

## Componente modular encargado de la gestión de cargas, tiempos de recarga,
## marcos de invulnerabilidad y habilidades únicas de evasión (Dash) de cada heroína.

signal dash_updated(charges: int, max_charges: int, progress: float, is_focus: bool)
signal dash_executed(dash_dir: Vector2, character_id: StringName)

@export var fire_trail_scene: PackedScene = preload("res://scenes/combat/player/dash_effects/fire_trail_hazard.tscn")
@export var decoy_mine_scene: PackedScene = preload("res://scenes/combat/player/dash_effects/decoy_drone_mine.tscn")
@export var vacuum_pulse_scene: PackedScene = preload("res://scenes/combat/player/dash_effects/vacuum_phase_pulse.tscn")
@export var chain_scene: PackedScene = preload("res://scenes/combat/weapons/chain_lightning_effect.tscn")
@export var nova_spin_scene: PackedScene = preload("res://scenes/combat/player/dash_effects/nova_spin_360_laser.tscn")
@export var cut_line_scene: PackedScene = preload("res://scenes/combat/player/dash_effects/dimensional_cut_line.tscn")

var player: CharacterBody2D = null
var character_id: StringName = &"nova"

var max_dash_charges: int = 1
var dash_charges: int = 1
var dash_recharge_timer: float = 0.0
var dash_recharge_max: float = 1.6
var dash_internal_cd: float = 0.2
var _internal_cd_timer: float = 0.0

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT

var is_focus_active: bool = false
var focus_timer: float = 0.0
var has_guaranteed_crit: bool = false

var is_omega_spinning: bool = false
var omega_spin_angle: float = 0.0

# Roxy: Registro de enemigos golpeados durante la embestida
var roxy_ram_hit_enemies: Array[Node2D] = []

func setup_for_character(p_player: CharacterBody2D, cid: StringName) -> void:
	player = p_player
	character_id = cid

	match String(cid):
		"nova":
			max_dash_charges = 2
			dash_charges = 2
			dash_recharge_max = 1.0
			dash_internal_cd = 0.15
		"valentina":
			max_dash_charges = 1
			dash_charges = 1
			dash_recharge_max = 1.8
			dash_internal_cd = 0.25
		"kira":
			max_dash_charges = 1
			dash_charges = 1
			dash_recharge_max = 1.4
			dash_internal_cd = 0.2
		"selene":
			max_dash_charges = 1
			dash_charges = 1
			dash_recharge_max = 1.6
			dash_internal_cd = 0.2
		"roxy":
			max_dash_charges = 1
			dash_charges = 1
			dash_recharge_max = 1.8
			dash_internal_cd = 0.25
		"echo":
			max_dash_charges = 1
			dash_charges = 1
			dash_recharge_max = 1.2
			dash_internal_cd = 0.2
		"nyx":
			max_dash_charges = 2
			dash_charges = 2
			dash_recharge_max = 1.3
			dash_internal_cd = 0.15
		_:
			max_dash_charges = 1
			dash_charges = 1
			dash_recharge_max = 1.6
			dash_internal_cd = 0.2

	dash_recharge_timer = 0.0
	is_dashing = false
	is_focus_active = false
	has_guaranteed_crit = false
	is_omega_spinning = false
	roxy_ram_hit_enemies.clear()

func handle_dash_process(delta: float) -> void:
	var unscaled_delta: float = delta / maxf(0.1, Engine.time_scale)

	# 1. Temporizador de enfriamiento interno entre cargas consecutivas
	if _internal_cd_timer > 0.0:
		_internal_cd_timer -= unscaled_delta

	# 2. Recarga pasiva de cargas de dash
	if dash_charges < max_dash_charges:
		dash_recharge_timer += unscaled_delta
		if dash_recharge_timer >= dash_recharge_max:
			dash_recharge_timer = 0.0
			dash_charges = mini(max_dash_charges, dash_charges + 1)
			dash_updated.emit(dash_charges, max_dash_charges, 1.0, is_focus_active)
		else:
			dash_updated.emit(dash_charges, max_dash_charges, dash_recharge_timer / dash_recharge_max, is_focus_active)
	else:
		dash_recharge_timer = 0.0

	# 3. Temporizador de Sobre-Enfoque (Valentina)
	if is_focus_active:
		focus_timer -= unscaled_delta
		if focus_timer <= 0.0:
			is_focus_active = false
			Engine.time_scale = SaveManager.get_game_speed() if SaveManager else 1.0
			dash_updated.emit(dash_charges, max_dash_charges, 1.0 if dash_charges >= max_dash_charges else (dash_recharge_timer / dash_recharge_max), false)

	# 4. Estado activo de Dash e invulnerabilidad
	if is_dashing:
		dash_timer -= delta
		if character_id == &"roxy":
			_process_roxy_ram_collision()

		if dash_timer <= 0.0:
			is_dashing = false
			is_omega_spinning = false

	# 5. Entrada del jugador para ejecutar Dash
	if Input.is_action_just_pressed("dash") and not is_dashing and _internal_cd_timer <= 0.0 and dash_charges > 0:
		dash_charges -= 1
		_internal_cd_timer = dash_internal_cd
		execute_character_dash()
		dash_updated.emit(dash_charges, max_dash_charges, dash_recharge_timer / dash_recharge_max, is_focus_active)

func execute_character_dash() -> void:
	if not is_instance_valid(player):
		return

	if "inventory" in player and player.inventory:
		player.inventory.process_dash_procs(player)

	var aim_dir := (player.get_global_mouse_position() - player.global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT

	dash_direction = aim_dir

	match String(character_id):
		"nova":
			_execute_nova_dash()
		"valentina":
			_execute_valentina_dash()
		"kira":
			_execute_kira_dash()
		"selene":
			_execute_selene_dash()
		"roxy":
			_execute_roxy_dash()
		"echo":
			_execute_echo_dash()
		"nyx":
			_execute_nyx_dash()
		_:
			_execute_nova_dash()

	dash_executed.emit(dash_direction, character_id)

func _execute_nova_dash() -> void:
	var wc := player.get_node_or_null("WeaponController") as WeaponController
	if wc and wc.is_laser_fully_charged():
		_execute_nova_omega_spin(wc)
		return

	is_dashing = true
	dash_timer = 0.28
	is_omega_spinning = true
	omega_spin_angle = dash_direction.angle()
	if player.has_method("update_omega_spin_rotation"):
		player.update_omega_spin_rotation(omega_spin_angle)

	var audio_mgr := player.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("dash", 1.25, 0.0)

func _execute_nova_omega_spin(wc: WeaponController) -> void:
	is_dashing = true
	dash_timer = 0.35
	is_omega_spinning = true
	omega_spin_angle = dash_direction.angle()
	if player.has_method("update_omega_spin_rotation"):
		player.update_omega_spin_rotation(omega_spin_angle)

	wc.consume_laser_charge()

	var base_dmg: float = player.stats.get_stat(&"base_damage") if ("stats" in player and player.stats) else 20.0
	var crit_chance: float = player.stats.get_stat(&"crit_chance") if ("stats" in player and player.stats) else 0.05
	var is_crit: bool = randf() <= crit_chance
	var crit_mult: float = player.stats.get_stat(&"crit_damage") if ("stats" in player and player.stats) else 1.5
	var final_dmg: float = base_dmg * (crit_mult if is_crit else 1.0)

	var ctx := HitContext.new()
	ctx.attacker = player
	ctx.raw_damage = base_dmg
	ctx.final_damage = final_dmg
	ctx.is_crit = is_crit
	ctx.proc_coefficient = 0.35
	ctx.hit_position = player.global_position

	var spawn_parent: Node = player.get_tree().current_scene if player.get_tree() and player.get_tree().current_scene else player.get_parent()
	if spawn_parent and nova_spin_scene:
		var spin: Node2D = nova_spin_scene.instantiate() as Node2D
		if spin:
			spawn_parent.add_child(spin)
			if spin.has_method("setup"):
				spin.call("setup", player, ctx, dash_direction.angle())

	var audio_mgr := player.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("laser", 1.6, 2.0)
		audio_mgr.play_sfx("dash", 1.4, 3.0)

func _execute_valentina_dash() -> void:
	var aim_dir := (player.get_global_mouse_position() - player.global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT
	dash_direction = -aim_dir
	is_dashing = true
	dash_timer = 0.22
	is_focus_active = true
	focus_timer = 1.5
	has_guaranteed_crit = true
	var base_spd: float = SaveManager.get_game_speed() if SaveManager else 1.0
	Engine.time_scale = base_spd * 0.55

	var audio_mgr := player.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.6, 2.0)

func _execute_kira_dash() -> void:
	is_dashing = true
	dash_timer = 0.25
	if decoy_mine_scene:
		var mine := decoy_mine_scene.instantiate()
		if mine and mine.has_method("setup"):
			mine.setup(player.global_position, player)
			var spawn_parent: Node = player.get_tree().current_scene if player.get_tree() and player.get_tree().current_scene else player.get_parent()
			if spawn_parent:
				spawn_parent.add_child(mine)
	var audio_mgr := player.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("dash", 1.4, -2.0)

func _execute_selene_dash() -> void:
	is_dashing = true
	dash_timer = 0.15
	var teleport_dist := 240.0
	player.global_position += dash_direction * teleport_dist

	if vacuum_pulse_scene:
		var pulse := vacuum_pulse_scene.instantiate()
		if pulse and pulse.has_method("setup"):
			pulse.setup(player.global_position, player)
			var spawn_parent: Node = player.get_tree().current_scene if player.get_tree() and player.get_tree().current_scene else player.get_parent()
			if spawn_parent:
				spawn_parent.add_child(pulse)
	var audio_mgr := player.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("laser", 0.7, 1.0)

func _execute_roxy_dash() -> void:
	is_dashing = true
	dash_timer = 0.32
	roxy_ram_hit_enemies.clear()

	if "bullet_server" in player and player.bullet_server and player.bullet_server.has_method("clear_bullets_in_arc"):
		player.bullet_server.clear_bullets_in_arc(player.global_position, dash_direction, 120.0, 180.0)

	var audio_mgr := player.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("explosion", 1.6, 2.0)

func _process_roxy_ram_collision() -> void:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	var tree := player.get_tree()
	if not tree:
		return
	var ram_radius_sq := 48.0 * 48.0
	for enemy in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy is Node2D and not roxy_ram_hit_enemies.has(enemy):
			if player.global_position.distance_squared_to(enemy.global_position) <= ram_radius_sq:
				roxy_ram_hit_enemies.append(enemy)
				if enemy.has_method("take_damage"):
					var ctx := HitContext.new()
					ctx.attacker = player
					ctx.raw_damage = 35.0
					ctx.final_damage = 35.0
					ctx.hit_position = player.global_position
					enemy.take_damage(ctx)
				if "velocity" in enemy:
					enemy.velocity += dash_direction * 300.0

func _execute_echo_dash() -> void:
	is_dashing = true
	dash_timer = 0.15
	var teleport_dist := 200.0
	player.global_position += dash_direction * teleport_dist

	var nearest_enemy: Node2D = null
	var min_d_sq := 400.0 * 400.0
	var tree := player.get_tree()
	if tree:
		for enemy in tree.get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy is Node2D:
				var d_sq := player.global_position.distance_squared_to(enemy.global_position)
				if d_sq < min_d_sq:
					min_d_sq = d_sq
					nearest_enemy = enemy

	if nearest_enemy and chain_scene:
		var chain := chain_scene.instantiate()
		if chain and chain.has_method("setup"):
			var ctx := HitContext.new()
			ctx.attacker = player
			ctx.raw_damage = 40.0
			ctx.final_damage = 40.0
			ctx.hit_position = player.global_position
			chain.setup(player.global_position, nearest_enemy.global_position, ctx, 5)
			var spawn_parent: Node = player.get_tree().current_scene if player.get_tree() and player.get_tree().current_scene else player.get_parent()
			if spawn_parent:
				spawn_parent.add_child(chain)

	var audio_mgr := player.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("dash", 1.8, 1.0)

func _execute_nyx_dash() -> void:
	is_dashing = true
	dash_timer = 0.18
	var start_pos := player.global_position
	var teleport_dist := 260.0
	var target_pos := start_pos + dash_direction * teleport_dist
	player.global_position = target_pos

	var base_dmg: float = player.stats.get_stat(&"base_damage") if ("stats" in player and player.stats) else 48.0
	var crit_chance: float = player.stats.get_stat(&"crit_chance") if ("stats" in player and player.stats) else 0.15
	var is_crit: bool = (randf() <= crit_chance) or consume_guaranteed_crit()
	var crit_mult: float = player.stats.get_stat(&"crit_damage") if ("stats" in player and player.stats) else 1.8
	var final_dmg: float = base_dmg * 1.5 * (crit_mult if is_crit else 1.0)

	var ctx := HitContext.new()
	ctx.attacker = player
	ctx.raw_damage = base_dmg * 1.5
	ctx.final_damage = final_dmg
	ctx.is_crit = is_crit
	ctx.proc_coefficient = 1.0
	ctx.hit_position = (start_pos + target_pos) * 0.5

	if cut_line_scene:
		var cut: Node2D = cut_line_scene.instantiate() as Node2D
		if cut and cut.has_method("setup"):
			var spawn_parent: Node = player.get_tree().current_scene if player.get_tree() and player.get_tree().current_scene else player.get_parent()
			if spawn_parent:
				spawn_parent.add_child(cut)
			cut.setup(start_pos, target_pos, player, ctx)

	var audio_mgr := player.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("dash", 1.8, 1.5)

func consume_guaranteed_crit() -> bool:
	if has_guaranteed_crit:
		has_guaranteed_crit = false
		return true
	return false
