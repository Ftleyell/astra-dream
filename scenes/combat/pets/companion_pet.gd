class_name CompanionPet
extends Node2D

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const PetDataScript = preload("res://data/pets/pet_data.gd")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")

## Mascota acompañante espacial en burbuja 3D viva sin hitbox.
## En Combate usa movimiento híbrido (órbita 3D inclinada ↔ seguidor elástico al dashear)
## y luz dinámica del Cosmos; en Hub 3D acompaña pacíficamente sin habilidades ni daño.

enum State {
	ORBITING,
	FETCHING,
	ATTACKING,
}

@export var pet_data: PetData

var player: Player = null
var current_state: State = State.ORBITING
var is_hub_mode: bool = false

var _orbit_angle: float = 0.0
var _orbit_radius: float = 102.0
var _orbit_speed: float = 1.45
var _follow_blend: float = 0.0
var _prev_global_pos: Vector2 = Vector2.ZERO
var _was_player_dashing: bool = false

# Targets y temporizadores de habilidades
var _target_exp_blob: WeakRef = null
var _target_enemy: WeakRef = null
var _attack_cooldown_timer: float = 0.0
var _support_pulse_timer: float = 15.0
var _pip_steal_timer: float = 5.0
var _cosmo_laser_timer: float = 0.8

var _bubble_config: PetBubbleVisualConfig = null
var _cosmos_host: CosmosHostController = null
var _lighting_sample: CosmicLightingSample = CosmicLightingSampleScript.new() as CosmicLightingSample

@onready var bubble_rig: PetBubbleRig25D = get_node_or_null("PetBubbleRig25D") as PetBubbleRig25D
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var aura_particles: CPUParticles2D = get_node_or_null("AuraParticles") as CPUParticles2D
@onready var laser_beam: Line2D = get_node_or_null("LaserBeam") as Line2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 25
	if not pet_data:
		var pid: StringName = SaveManager.get_selected_pet()
		pet_data = PetDataScript.get_pet(pid)

	_apply_pet_visuals()
	_acquire_player()
	_prev_global_pos = global_position
	_apply_passive_buffs()


func setup(p_data: PetData, p_player: Player) -> void:
	pet_data = p_data
	player = p_player
	_apply_pet_visuals()
	_acquire_player()
	_prev_global_pos = global_position
	_apply_passive_buffs()


func set_hub_mode(active: bool) -> void:
	is_hub_mode = active
	if is_hub_mode:
		current_state = State.ORBITING
		_target_exp_blob = null
		_target_enemy = null
		if laser_beam != null:
			laser_beam.visible = false
	_apply_diameter_for_mode()
	_apply_passive_buffs()


func refresh_from_save() -> void:
	var pid: StringName = SaveManager.get_selected_pet()
	pet_data = PetDataScript.get_pet(pid)
	_apply_pet_visuals()
	_apply_passive_buffs()
	if bubble_rig != null:
		bubble_rig.trigger_emote(&"roll_360")


func _acquire_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if is_instance_valid(player):
		global_position = player.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * _orbit_radius


func _apply_diameter_for_mode() -> void:
	if bubble_rig == null:
		return
	var diam: float = 64.0
	if _bubble_config != null:
		diam = _bubble_config.hub_diameter_px if is_hub_mode else _bubble_config.combat_diameter_px
	bubble_rig.set_bubble_diameter_px(diam)


func _apply_pet_visuals() -> void:
	if not pet_data:
		return
	var pet_id_str: String = String(pet_data.pet_id).to_lower()
	var equipped_skin_id: String = SaveManager.get_equipped_skin("pet:" + pet_id_str)
	var stars: int = SaveManager.get_skin_stars(equipped_skin_id) if not equipped_skin_id.is_empty() else 1

	_bubble_config = PetBubbleRegistry.get_config(pet_data.pet_id)
	if bubble_rig == null:
		bubble_rig = get_node_or_null("PetBubbleRig25D") as PetBubbleRig25D
	if bubble_rig != null and _bubble_config != null:
		bubble_rig.apply_config(_bubble_config)
		bubble_rig.apply_skin_by_id(equipped_skin_id, stars, false)
		_orbit_radius = _bubble_config.combat_orbit_radius_x
		_orbit_speed = _bubble_config.orbit_speed
		_apply_diameter_for_mode()

	if sprite == null:
		sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.visible = false
		sprite.texture = pet_data.get_icon_texture()

	if aura_particles == null:
		aura_particles = get_node_or_null("AuraParticles") as CPUParticles2D
	if aura_particles != null:
		aura_particles.emitting = false


func _apply_passive_buffs() -> void:
	if not is_instance_valid(player) or not player.stats:
		return
	if player.stats.has_method("remove_modifier"):
		player.stats.remove_modifier(&"attack_speed", &"pet_pip_atk_spd")
		player.stats.remove_modifier(&"crit_chance", &"pet_pip_crit")
	if is_hub_mode or not pet_data:
		return
	# Pip: Bono pasivo constante de +15% cadencia y +8% crítico en combate
	if pet_data.pet_id == &"pip":
		player.stats.set_or_replace_modifier(&"attack_speed", CharacterStats.StatModifier.new(&"pet_pip_atk_spd", 0.15, true, self))
		player.stats.set_or_replace_modifier(&"crit_chance", CharacterStats.StatModifier.new(&"pet_pip_crit", 0.08, false, self))


func _exit_tree() -> void:
	if is_instance_valid(player) and player.stats:
		if player.stats.has_method("remove_modifier"):
			player.stats.remove_modifier(&"attack_speed", &"pet_pip_atk_spd")
			player.stats.remove_modifier(&"crit_chance", &"pet_pip_crit")


func _resolve_cosmos_host() -> void:
	if _cosmos_host != null and is_instance_valid(_cosmos_host):
		return
	if not is_inside_tree():
		return
	var env_host: Node = get_tree().get_first_node_in_group("space_environment_host")
	if env_host != null and env_host.has_method("get_cosmos_controller"):
		_cosmos_host = env_host.call("get_cosmos_controller") as CosmosHostController
		if _cosmos_host != null:
			return
	var cosmos_root: Node = get_tree().get_first_node_in_group("cosmos_root")
	if cosmos_root != null and cosmos_root.get_parent() is CosmosCombatEnvironment:
		_cosmos_host = (cosmos_root.get_parent() as CosmosCombatEnvironment).get_cosmos_controller()


func _update_cosmic_lighting() -> void:
	if bubble_rig == null:
		return
	_resolve_cosmos_host()
	if _cosmos_host != null and is_instance_valid(_cosmos_host):
		_cosmos_host.sample_lighting_at(global_position, _lighting_sample)
		bubble_rig.set_sun_direction(_lighting_sample.light_dir_3d)


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		_acquire_player()
		if not is_instance_valid(player):
			return

	_update_cosmic_lighting()

	if is_hub_mode:
		_process_hub_companion(delta)
	else:
		var pid: StringName = pet_data.pet_id if pet_data else &"mochi"
		match pid:
			&"mochi":
				_process_mochi(delta)
			&"kuro":
				_process_kuro(delta)
			&"luna":
				_process_luna(delta)
			&"pip":
				_process_pip(delta)
			&"cosmo":
				_process_cosmo(delta)

		match current_state:
			State.ORBITING:
				_process_orbiting(delta)
			State.FETCHING:
				_process_fetching(delta)
			State.ATTACKING:
				_process_attacking(delta)

	var vel: Vector2 = (global_position - _prev_global_pos) / maxf(delta, 0.001)
	_prev_global_pos = global_position
	if bubble_rig != null:
		bubble_rig.set_velocity_hint(vel)


func _process_hub_companion(delta: float) -> void:
	var is_dashing_now: bool = bool(player.get("is_dashing"))
	if is_dashing_now and not _was_player_dashing and bubble_rig != null:
		bubble_rig.trigger_emote(&"hop")
	_was_player_dashing = is_dashing_now

	var spd: float = player.velocity.length()
	var is_fast: bool = is_dashing_now or spd > 220.0
	_follow_blend = move_toward(_follow_blend, 1.0 if is_fast else 0.0, delta * 3.5)

	var orbit_spd: float = (_bubble_config.orbit_speed if _bubble_config != null else 1.4) * 0.72
	_orbit_angle = wrapf(_orbit_angle + orbit_spd * delta, 0.0, TAU)

	var rx: float = 52.0
	var ry: float = 22.0
	var orbit_pos: Vector2 = player.global_position + Vector2(cos(_orbit_angle) * rx, sin(_orbit_angle) * ry - 18.0)

	var move_dir: Vector2 = player.velocity.normalized() if spd > 12.0 else Vector2.RIGHT
	var shoulder_pos: Vector2 = player.global_position + Vector2(-move_dir.x * 46.0, -20.0 - move_dir.y * 16.0)
	var target_pos: Vector2 = orbit_pos.lerp(shoulder_pos, _follow_blend)

	global_position = global_position.lerp(target_pos, minf(1.0, delta * 8.5))

	var depth_val: float = lerpf(sin(_orbit_angle), 0.75, _follow_blend)
	var p_z: int = player.z_index
	z_index = (p_z + 3) if depth_val >= 0.0 else (p_z - 1)
	if bubble_rig != null:
		var back_s: float = _bubble_config.back_scale if _bubble_config != null else 0.82
		var front_s: float = _bubble_config.front_scale if _bubble_config != null else 1.12
		var s: float = lerpf(back_s, front_s, (depth_val + 1.0) * 0.5)
		bubble_rig.scale = Vector2(s, s)
		bubble_rig.set_orbit_depth(depth_val)


func _process_orbiting(delta: float) -> void:
	var spd: float = player.velocity.length()
	var is_dashing_now: bool = bool(player.get("is_dashing"))
	var follow_thresh: float = _bubble_config.combat_follow_speed_threshold if _bubble_config != null else 310.0
	var wants_follow: bool = is_dashing_now or spd > follow_thresh

	if is_dashing_now and not _was_player_dashing and bubble_rig != null:
		bubble_rig.trigger_emote(&"dash")
	_was_player_dashing = is_dashing_now

	_follow_blend = move_toward(_follow_blend, 1.0 if wants_follow else 0.0, delta * 4.5)

	var orbit_spd: float = _bubble_config.orbit_speed if _bubble_config != null else _orbit_speed
	_orbit_angle = wrapf(_orbit_angle + orbit_spd * delta, 0.0, TAU)

	var rx: float = _bubble_config.combat_orbit_radius_x if _bubble_config != null else _orbit_radius
	var ry: float = _bubble_config.combat_orbit_radius_y if _bubble_config != null else 42.0
	var tilt_rad: float = deg_to_rad(_bubble_config.orbit_tilt_deg if _bubble_config != null else 22.0)
	var px: float = cos(_orbit_angle) * rx
	var py: float = sin(_orbit_angle) * ry * cos(tilt_rad) + px * sin(tilt_rad) * 0.25
	var orbit_pos: Vector2 = player.global_position + Vector2(px, py)

	var follow_off: Vector2 = _bubble_config.combat_follow_offset_px if _bubble_config != null else Vector2(-58.0, 28.0)
	var move_dir: Vector2 = player.velocity.normalized() if spd > 10.0 else Vector2.RIGHT
	var oriented_off := Vector2(-move_dir.x * absf(follow_off.x), -move_dir.y * absf(follow_off.x) * 0.45 + follow_off.y * 0.35)
	var follow_pos: Vector2 = player.global_position + oriented_off

	var target_pos: Vector2 = orbit_pos.lerp(follow_pos, _follow_blend)
	var stiff: float = _bubble_config.combat_follow_stiffness if _bubble_config != null else 9.5
	global_position = global_position.lerp(target_pos, minf(1.0, delta * stiff))

	var depth_val: float = lerpf(sin(_orbit_angle), 0.85, _follow_blend)
	var p_z: int = player.z_index
	z_index = (p_z + 3) if depth_val >= 0.0 else (p_z - 2)
	if bubble_rig != null:
		var back_s: float = _bubble_config.back_scale if _bubble_config != null else 0.82
		var front_s: float = _bubble_config.front_scale if _bubble_config != null else 1.12
		var s: float = lerpf(back_s, front_s, (depth_val + 1.0) * 0.5)
		bubble_rig.scale = Vector2(s, s)
		bubble_rig.set_orbit_depth(depth_val)


func _set_front_action_presentation() -> void:
	z_index = player.z_index + 4 if is_instance_valid(player) else 25
	if bubble_rig != null:
		bubble_rig.scale = Vector2.ONE
		bubble_rig.set_orbit_depth(1.0)


# ── 1. MOCHI: IMÁN DE EXP DINÁMICO ──────────────────────────────────────────
func _process_mochi(_delta: float) -> void:
	if current_state == State.ORBITING:
		var p_radius: float = player.stats.get_stat(&"pickup_radius") if player.stats else 100.0
		var max_search_dist: float = p_radius * 3.5 + 280.0
		var best_blob: ExpBlob = null
		var best_dist: float = 999999.0

		for node: Node in get_tree().get_nodes_in_group("exp_blobs"):
			if is_instance_valid(node) and node is ExpBlob:
				var blob := node as ExpBlob
				if blob.is_collected or blob.is_being_absorbed:
					continue
				var d: float = global_position.distance_to(blob.global_position)
				var d_player: float = player.global_position.distance_to(blob.global_position)
				if d_player > p_radius * 1.3 and d < max_search_dist and d < best_dist:
					best_dist = d
					best_blob = blob

		if best_blob != null:
			_target_exp_blob = weakref(best_blob)
			current_state = State.FETCHING


func _process_fetching(delta: float) -> void:
	var blob: ExpBlob = _target_exp_blob.get_ref() as ExpBlob if _target_exp_blob != null else null
	if blob == null or not is_instance_valid(blob) or blob.is_collected or blob.is_being_absorbed:
		current_state = State.ORBITING
		return

	_set_front_action_presentation()
	var p_radius: float = player.stats.get_stat(&"pickup_radius") if (player and player.stats) else 100.0
	var fetch_speed: float = 440.0 + (p_radius * 1.6)
	var dir: Vector2 = (blob.global_position - global_position).normalized()
	global_position += dir * fetch_speed * delta

	if global_position.distance_to(blob.global_position) < 32.0:
		blob._collect()
		_play_happy_emote(&"hop")
		current_state = State.ORBITING


func _play_happy_emote(kind: StringName = &"roll_360") -> void:
	if bubble_rig != null:
		bubble_rig.trigger_emote(kind)


# ── 2. KURO: ZARPAZO A ENEMIGOS 1 A 1 ───────────────────────────────────────
func _process_kuro(delta: float) -> void:
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	if current_state == State.ORBITING and _attack_cooldown_timer <= 0.0:
		var nearest_enemy: Node2D = null
		var min_dist: float = 380.0
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(node) and node is Node2D:
				var d: float = player.global_position.distance_to((node as Node2D).global_position)
				if d < min_dist:
					min_dist = d
					nearest_enemy = node as Node2D
		if nearest_enemy != null:
			_target_enemy = weakref(nearest_enemy)
			current_state = State.ATTACKING


func _process_attacking(delta: float) -> void:
	var enemy: Node2D = _target_enemy.get_ref() as Node2D if _target_enemy != null else null
	if enemy == null or not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
		current_state = State.ORBITING
		_attack_cooldown_timer = 0.4
		return

	_set_front_action_presentation()
	var attack_speed: float = 650.0
	var dir: Vector2 = (enemy.global_position - global_position).normalized()
	global_position += dir * attack_speed * delta

	if global_position.distance_to(enemy.global_position) < 35.0:
		_apply_damage(enemy, 18.0)
		_spawn_claw_scratch_vfx(enemy.global_position)
		_play_happy_emote(&"dash")
		_attack_cooldown_timer = 1.2
		current_state = State.ORBITING


func _spawn_claw_scratch_vfx(pos: Vector2) -> void:
	var p: Node = get_parent() if is_inside_tree() else null
	if p == null:
		return
	var claw := Line2D.new()
	claw.width = 4.0
	claw.default_color = Color(1.0, 0.2, 0.35, 0.95)
	claw.points = PackedVector2Array([Vector2(-14, -14), Vector2(14, 14)])
	claw.global_position = pos
	p.add_child(claw)
	var tw: Tween = claw.create_tween()
	tw.tween_property(claw, "modulate:a", 0.0, 0.22)
	tw.tween_callback(claw.queue_free)

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr != null and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.8)


# ── 3. LUNA: PULSO PURPURINA (SANACIÓN + RALENTIZACIÓN) ─────────────────────
func _process_luna(delta: float) -> void:
	_support_pulse_timer -= delta
	if _support_pulse_timer <= 0.0:
		_support_pulse_timer = 15.0
		_trigger_luna_pulse()


func _trigger_luna_pulse() -> void:
	if not is_instance_valid(player):
		return
	var max_hp: float = player.stats.get_stat(&"max_health") if player.stats else 100.0
	player.current_health = minf(player.current_health + 8.0, max_hp)
	player.health_changed.emit(player.current_health, max_hp)

	var p_parent: Node = get_parent() if is_inside_tree() else null
	if p_parent != null:
		FloatingText.spawn(p_parent, player.global_position + Vector2(0, -38), "💖 +8 HP", Color(0.4, 1.0, 0.85))

	_play_happy_emote(&"roll_360")


# ── 4. PIP: ROBO DE CRÉDITOS Y PASIVOS ───────────────────────────────────────
func _process_pip(delta: float) -> void:
	_pip_steal_timer -= delta
	if _pip_steal_timer <= 0.0:
		_pip_steal_timer = 5.5
		var has_nearby: bool = false
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(node) and node is Node2D and global_position.distance_to((node as Node2D).global_position) < 320.0:
				has_nearby = true
				break
		if has_nearby and is_instance_valid(player):
			player.add_credits(3)
			_play_happy_emote(&"wiggle")
			var p_parent: Node = get_parent() if is_inside_tree() else null
			if p_parent != null:
				FloatingText.spawn(p_parent, global_position + Vector2(0, -25), "+3 💰", Color(1.0, 0.88, 0.2))


# ── 5. COSMO: HÍBRIDO ASTRAL (EXP GRAVITACIONAL + MICRO-LÁSER) ──────────────
func _process_cosmo(delta: float) -> void:
	for node: Node in get_tree().get_nodes_in_group("exp_blobs"):
		if is_instance_valid(node) and node is ExpBlob:
			var blob := node as ExpBlob
			if not blob.is_collected and not blob.is_being_absorbed:
				if global_position.distance_to(blob.global_position) < 220.0:
					blob.is_force_magnetized = true
					if global_position.distance_to(blob.global_position) < 28.0:
						blob._collect()

	_cosmo_laser_timer -= delta
	if _cosmo_laser_timer <= 0.0:
		_cosmo_laser_timer = 0.85
		_fire_cosmo_laser()


func _fire_cosmo_laser() -> void:
	var target: Node2D = null
	var min_d: float = 320.0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node is Node2D:
			var n2d := node as Node2D
			var d: float = global_position.distance_to(n2d.global_position)
			if d < min_d:
				min_d = d
				target = n2d

	if target != null and laser_beam != null:
		laser_beam.visible = true
		laser_beam.clear_points()
		laser_beam.add_point(Vector2.ZERO)
		laser_beam.add_point(to_local(target.global_position))
		_apply_damage(target, 12.0)
		_play_happy_emote(&"curious_tilt")
		var tw: Tween = laser_beam.create_tween()
		tw.tween_property(laser_beam, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func() -> void:
			laser_beam.visible = false
			laser_beam.modulate.a = 1.0
		)


func _apply_damage(target: Node, amount: float) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	var ctx := HitContext.new()
	ctx.attacker = player if is_instance_valid(player) else self
	ctx.victim = target
	ctx.raw_damage = amount
	ctx.final_damage = amount
	ctx.is_crit = false
	target.take_damage(ctx)
