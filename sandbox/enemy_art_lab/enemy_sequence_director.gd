extends Node2D

## Modular sequence director for EnemyArtLab inside the real Cosmic Engine.
## Drives realistic outer-space flight, hunting strikes, 6-unit swarms,
## solar/planetary eclipse passes, and hit/shatter combat beats without clutter.

const VoidScarabRigScript = preload("res://scenes/combat/enemies/rig/void_scarab_rig_25d.gd")
const CosmosHostControllerScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_host_controller.gd")

enum SequenceId {
	PATROL_CRUISE = 0,
	PREDATOR_STRIKE = 1,
	SWARM_INTERCEPT = 2,
	SOLAR_ECLIPSE = 3,
	HIT_SHATTER = 4,
}

const SEQUENCE_LABELS: Array[String] = [
	"1 Patrulla",
	"2 Acecho+Mordida",
	"3 Enjambre 6x",
	"4 Solar/Eclipse",
	"5 Daño/Muerte",
]

const SEQUENCE_DURATIONS: Array[float] = [8.5, 9.0, 9.5, 10.0, 7.5]

var auto_reel: bool = true
var active_sequence: int = SequenceId.PATROL_CRUISE

var _seq_elapsed: float = 0.0
var _anchor_pos: Vector2 = Vector2.ZERO
var _beacon_pos: Vector2 = Vector2.ZERO
var _show_beacon: bool = false
var _vel: Vector2 = Vector2(360.0, 0.0)
var _strike_cycle_t: float = 0.0
var _strike_did_lunge: bool = false
var _hit_stage: int = 0
var _eclipse_star_pos: Vector2 = Vector2.ZERO
var _eclipse_planet_pos: Vector2 = Vector2(420.0, 0.0)
var _eclipse_planet_radius: float = 135.0
var _has_solar_target: bool = false

var _swarm_vels: Array[Vector2] = []


func start_sequence(seq_id: int, anchor_pos: Vector2, host_controller: CosmosHostControllerScript) -> void:
	active_sequence = clampi(seq_id, 0, SEQUENCE_LABELS.size() - 1)
	_seq_elapsed = 0.0
	_anchor_pos = anchor_pos
	_strike_cycle_t = 0.0
	_strike_did_lunge = false
	_hit_stage = 0
	_show_beacon = (active_sequence == SequenceId.PREDATOR_STRIKE or active_sequence == SequenceId.SWARM_INTERCEPT)
	_beacon_pos = anchor_pos + Vector2(240.0, -40.0)
	_resolve_solar_eclipse_target(host_controller)
	queue_redraw()


func set_auto_reel(enabled: bool) -> void:
	auto_reel = enabled


func set_beacon_visible(vis: bool) -> void:
	if not vis and _show_beacon:
		_show_beacon = false
		queue_redraw()


func is_swarm_needed() -> bool:
	return active_sequence == SequenceId.SWARM_INTERCEPT


func get_recommended_zoom() -> float:
	match active_sequence:
		SequenceId.PATROL_CRUISE:
			return 1.12
		SequenceId.PREDATOR_STRIKE:
			return 1.22
		SequenceId.SWARM_INTERCEPT:
			return 0.88
		SequenceId.SOLAR_ECLIPSE:
			return 1.15
		SequenceId.HIT_SHATTER:
			return 1.30
	return 1.15


func get_status_label() -> String:
	var dur: float = SEQUENCE_DURATIONS[active_sequence]
	var lbl: String = SEQUENCE_LABELS[active_sequence]
	if auto_reel:
		return "Reel: %s (%.1fs/%.0fs)" % [lbl, _seq_elapsed, dur]
	return "Seq: %s (%.1fs)" % [lbl, _seq_elapsed]


func step_sequence(
	delta: float,
	scarab: VoidScarabRigScript,
	swarm: Array[VoidScarabRigScript],
	host_controller: CosmosHostControllerScript
) -> Dictionary:
	if scarab == null:
		return {"velocity": Vector2.ZERO, "swarm_active": false}

	_seq_elapsed += delta
	if auto_reel and _seq_elapsed >= SEQUENCE_DURATIONS[active_sequence]:
		var next_seq: int = (active_sequence + 1) % SEQUENCE_LABELS.size()
		if scarab.get_anim_state() == VoidScarabRigScript.AnimState.DEATH_SHATTER:
			scarab.respawn()
		start_sequence(next_seq, scarab.position, host_controller)

	var swarm_needed: bool = is_swarm_needed()
	_show_beacon = (active_sequence == SequenceId.PREDATOR_STRIKE or active_sequence == SequenceId.SWARM_INTERCEPT)

	match active_sequence:
		SequenceId.PATROL_CRUISE:
			_step_patrol(delta, scarab)
		SequenceId.PREDATOR_STRIKE:
			_step_predator_strike(delta, scarab)
		SequenceId.SWARM_INTERCEPT:
			_step_swarm_intercept(delta, scarab, swarm)
		SequenceId.SOLAR_ECLIPSE:
			_step_solar_eclipse(delta, scarab, host_controller)
		SequenceId.HIT_SHATTER:
			_step_hit_shatter(delta, scarab)

	if _show_beacon:
		queue_redraw()

	return {
		"velocity": _vel,
		"swarm_active": swarm_needed,
		"active_sequence": active_sequence,
	}


func _step_patrol(delta: float, scarab: VoidScarabRigScript) -> void:
	if scarab.get_anim_state() != VoidScarabRigScript.AnimState.CRUISE_BANK:
		scarab.set_anim_state(VoidScarabRigScript.AnimState.CRUISE_BANK)
	var t: float = _seq_elapsed * 0.85
	var target_pt := _anchor_pos + Vector2(sin(t) * 440.0, sin(t * 2.0) * 210.0)
	_steer_unit(scarab, delta, target_pt, 420.0, 950.0, 7.5, false)


func _step_predator_strike(delta: float, scarab: VoidScarabRigScript) -> void:
	_beacon_pos = _anchor_pos + Vector2(cos(_seq_elapsed * 0.9) * 190.0, sin(_seq_elapsed * 1.3) * 120.0)
	_strike_cycle_t += delta
	if _strike_cycle_t >= 2.9:
		_strike_cycle_t = 0.0
		_strike_did_lunge = false

	if _strike_cycle_t < 1.35:
		if scarab.get_anim_state() != VoidScarabRigScript.AnimState.CRUISE_BANK:
			scarab.set_anim_state(VoidScarabRigScript.AnimState.CRUISE_BANK)
		var flank_ang: float = _seq_elapsed * 1.85 + 0.9
		var flank_pt: Vector2 = _beacon_pos + Vector2(cos(flank_ang) * 235.0, sin(flank_ang) * 165.0)
		_steer_unit(scarab, delta, flank_pt, 400.0, 1050.0, 8.5, false)
	elif _strike_cycle_t < 2.25:
		if scarab.get_anim_state() != VoidScarabRigScript.AnimState.CHARGE_TELEGRAPH:
			scarab.set_anim_state(VoidScarabRigScript.AnimState.CHARGE_TELEGRAPH)
		var to_b: Vector2 = _beacon_pos - scarab.position
		var desired_r: float = to_b.angle() if to_b.length_squared() > 4.0 else scarab.rotation
		var prev_r: float = scarab.rotation
		scarab.rotation = lerp_angle(prev_r, desired_r, clampf(delta * 10.0, 0.0, 1.0))
		var ang_v: float = wrapf(scarab.rotation - prev_r, -PI, PI) / maxf(delta, 0.001)
		var prev_spd: float = _vel.length()
		_vel = _vel.move_toward(Vector2.RIGHT.rotated(scarab.rotation) * 90.0, 920.0 * delta)
		scarab.position += _vel * delta
		var acc_n: float = clampf(((_vel.length() - prev_spd) / maxf(delta, 0.001)) / 920.0, -1.0, 1.0)
		scarab.set_tilt_25d(0.0, 0.0)
		scarab.step(delta, ang_v, clampf(_vel.length() / 420.0, 0.0, 1.2), acc_n)
	else:
		if not _strike_did_lunge:
			_strike_did_lunge = true
			scarab.set_anim_state(VoidScarabRigScript.AnimState.ATTACK_LUNGE)
			scarab.trigger_bite_snap()
			var dash_dir: Vector2 = (_beacon_pos - scarab.position).normalized()
			if dash_dir.length_squared() < 0.01:
				dash_dir = Vector2.RIGHT.rotated(scarab.rotation)
			_vel = dash_dir * 660.0
		_steer_unit(scarab, delta, _beacon_pos + Vector2.RIGHT.rotated(scarab.rotation) * 180.0, 620.0, 1450.0, 9.5, true)


func _step_swarm_intercept(delta: float, scarab: VoidScarabRigScript, swarm: Array[VoidScarabRigScript]) -> void:
	_beacon_pos = _anchor_pos + Vector2(cos(_seq_elapsed * 0.75) * 260.0, sin(_seq_elapsed * 1.15) * 165.0)
	_strike_cycle_t += delta
	if _strike_cycle_t >= 3.0:
		_strike_cycle_t = 0.0
		_strike_did_lunge = false

	# Leader sweeps around beacon and snaps a lunge halfway through cycle
	if _strike_cycle_t > 1.3 and _strike_cycle_t < 2.0:
		if scarab.get_anim_state() != VoidScarabRigScript.AnimState.CHARGE_TELEGRAPH:
			scarab.set_anim_state(VoidScarabRigScript.AnimState.CHARGE_TELEGRAPH)
	elif _strike_cycle_t >= 2.0 and not _strike_did_lunge:
		_strike_did_lunge = true
		scarab.set_anim_state(VoidScarabRigScript.AnimState.ATTACK_LUNGE)
		scarab.trigger_bite_snap()
		_vel = (_beacon_pos - scarab.position).normalized() * 640.0
	elif _strike_cycle_t < 1.3 and scarab.get_anim_state() != VoidScarabRigScript.AnimState.CRUISE_BANK:
		scarab.set_anim_state(VoidScarabRigScript.AnimState.CRUISE_BANK)

	var lead_pt: Vector2 = _beacon_pos + Vector2(cos(_seq_elapsed * 1.5) * 195.0, sin(_seq_elapsed * 1.5) * 145.0)
	_steer_unit(scarab, delta, lead_pt, 410.0, 1050.0, 8.0, true)

	if _swarm_vels.size() != swarm.size():
		_swarm_vels.resize(swarm.size())
		for j: int in range(swarm.size()):
			_swarm_vels[j] = Vector2(320.0, 0.0)

	for i: int in range(swarm.size()):
		var sw: VoidScarabRigScript = swarm[i]
		if sw == null:
			continue
		if not sw.visible:
			sw.visible = true
			sw.position = _beacon_pos + Vector2.RIGHT.rotated((TAU / 6.0) * float(i)) * 310.0
		var phase_off: float = fmod(_seq_elapsed + float(i) * 0.45, 2.7)
		if phase_off < 1.6:
			if sw.get_anim_state() != VoidScarabRigScript.AnimState.CRUISE_BANK:
				sw.set_anim_state(VoidScarabRigScript.AnimState.CRUISE_BANK)
		elif phase_off < 2.25:
			if sw.get_anim_state() != VoidScarabRigScript.AnimState.CHARGE_TELEGRAPH:
				sw.set_anim_state(VoidScarabRigScript.AnimState.CHARGE_TELEGRAPH)
		else:
			if sw.get_anim_state() != VoidScarabRigScript.AnimState.ATTACK_LUNGE:
				sw.set_anim_state(VoidScarabRigScript.AnimState.ATTACK_LUNGE)
				sw.trigger_bite_snap()

		var orbit_a: float = _seq_elapsed * 1.35 + (TAU / 6.0) * float(i)
		var ring_r: float = 250.0 + 48.0 * sin(_seq_elapsed * 2.1 + float(i))
		var target_sw: Vector2 = _beacon_pos + Vector2(cos(orbit_a) * ring_r, sin(orbit_a) * ring_r * 0.78)
		var sw_res: Vector2 = _steer_unit_with_vel(sw, _swarm_vels[i], delta, target_sw, 390.0, 980.0, 7.5)
		_swarm_vels[i] = sw_res


func _step_solar_eclipse(delta: float, scarab: VoidScarabRigScript, host_controller: CosmosHostControllerScript) -> void:
	if scarab.get_anim_state() != VoidScarabRigScript.AnimState.CRUISE_BANK:
		scarab.set_anim_state(VoidScarabRigScript.AnimState.CRUISE_BANK)
	if not _has_solar_target:
		_resolve_solar_eclipse_target(host_controller)

	if _has_solar_target:
		# Sweep across the anti-solar umbra cone behind the planet, then into full starlight
		var sun_dir: Vector2 = (_eclipse_planet_pos - _eclipse_star_pos).normalized()
		if sun_dir.length_squared() < 0.01:
			sun_dir = Vector2.RIGHT
		var perp := Vector2(-sun_dir.y, sun_dir.x)
		var arc_prog: float = clampf(_seq_elapsed / SEQUENCE_DURATIONS[SequenceId.SOLAR_ECLIPSE], 0.0, 1.0)
		var cross_u: float = lerpf(-1.3, 1.3, arc_prog)
		var stand_off: float = _eclipse_planet_radius + 110.0
		var target_pt: Vector2 = _eclipse_planet_pos + sun_dir * stand_off + perp * (cross_u * 290.0)
		_steer_unit(scarab, delta, target_pt, 320.0, 860.0, 6.5, false)
	else:
		var ang: float = _seq_elapsed * 1.05
		var target_pt := _anchor_pos + Vector2(cos(ang) * 340.0, sin(ang) * 210.0)
		_steer_unit(scarab, delta, target_pt, 350.0, 880.0, 6.8, false)


func _step_hit_shatter(delta: float, scarab: VoidScarabRigScript) -> void:
	if _hit_stage == 0 and _seq_elapsed >= 1.55:
		_hit_stage = 1
		scarab.trigger_hit_flash()
		_vel += Vector2(-210.0, -90.0)
	elif _hit_stage == 1 and _seq_elapsed >= 2.25:
		_hit_stage = 2
		scarab.trigger_hit_flash()
		_vel += Vector2(190.0, 110.0)
	elif _hit_stage == 2 and _seq_elapsed >= 2.85:
		_hit_stage = 3
		scarab.trigger_hit_flash()
		_vel += Vector2(-170.0, 140.0)
	elif _hit_stage == 3 and _seq_elapsed >= 3.45:
		_hit_stage = 4
		scarab.set_anim_state(VoidScarabRigScript.AnimState.DEATH_SHATTER)
		_vel = Vector2.ZERO
	elif _hit_stage == 4 and _seq_elapsed >= 6.10:
		_hit_stage = 5
		scarab.respawn()
		scarab.set_anim_state(VoidScarabRigScript.AnimState.CRUISE_BANK)
		_vel = Vector2.RIGHT.rotated(scarab.rotation) * 280.0

	if scarab.get_anim_state() == VoidScarabRigScript.AnimState.DEATH_SHATTER:
		scarab.set_tilt_25d(0.0, 0.0)
		scarab.step(delta, 0.0, 0.0, 0.0)
		return

	if scarab.get_anim_state() != VoidScarabRigScript.AnimState.CRUISE_BANK:
		scarab.set_anim_state(VoidScarabRigScript.AnimState.CRUISE_BANK)
	var patrol_pt := _anchor_pos + Vector2(cos(_seq_elapsed * 1.1) * 220.0, sin(_seq_elapsed * 1.6) * 130.0)
	_steer_unit(scarab, delta, patrol_pt, 310.0, 840.0, 7.0, false)


func _resolve_solar_eclipse_target(host_controller: CosmosHostControllerScript) -> void:
	_has_solar_target = false
	if host_controller == null:
		return
	var systems: Dictionary = host_controller.get_active_solar_systems()
	var best_sys: CosmosSolarSystem2D = null
	var best_d: float = INF
	for sys_v: Variant in systems.values():
		var sys: CosmosSolarSystem2D = sys_v as CosmosSolarSystem2D
		if sys != null and is_instance_valid(sys) and sys.visible and sys.star_body != null and not sys.planets.is_empty():
			var d: float = _anchor_pos.distance_to(sys.star_body.global_position)
			if d < best_d:
				best_d = d
				best_sys = sys
	if best_sys != null:
		var planet: CosmosOrbitalBody2D = best_sys.planets[0]
		_eclipse_star_pos = best_sys.star_body.global_position
		_eclipse_planet_pos = best_sys.star_body.global_position + planet.position
		_eclipse_planet_radius = float(planet.get_meta(&"visual_radius", 130.0))
		_has_solar_target = true


func _steer_unit(
	unit: VoidScarabRigScript,
	delta: float,
	target_pt: Vector2,
	cruise_speed: float,
	accel_rate: float,
	turn_rate: float,
	keep_existing_vel_dir: bool
) -> void:
	_vel = _steer_unit_with_vel(unit, _vel, delta, target_pt, cruise_speed, accel_rate, turn_rate, keep_existing_vel_dir)


func _steer_unit_with_vel(
	unit: VoidScarabRigScript,
	cur_vel: Vector2,
	delta: float,
	target_pt: Vector2,
	cruise_speed: float,
	accel_rate: float,
	turn_rate: float,
	keep_existing_vel_dir: bool = false
) -> Vector2:
	var to_t: Vector2 = target_pt - unit.position
	var desired_dir: Vector2 = to_t.normalized() if to_t.length_squared() > 9.0 else Vector2.RIGHT.rotated(unit.rotation)
	var desired_vel: Vector2 = desired_dir * cruise_speed
	var prev_spd: float = cur_vel.length()
	var next_vel: Vector2 = cur_vel.lerp(desired_vel, clampf(delta * 4.2, 0.0, 1.0)) if keep_existing_vel_dir else cur_vel.move_toward(desired_vel, accel_rate * delta)
	unit.position += next_vel * delta

	var ang_vel: float = 0.0
	if next_vel.length_squared() > 25.0:
		var prev_r: float = unit.rotation
		unit.rotation = lerp_angle(prev_r, next_vel.angle(), clampf(delta * turn_rate, 0.0, 1.0))
		ang_vel = wrapf(unit.rotation - prev_r, -PI, PI) / maxf(delta, 0.001)

	var spd: float = next_vel.length()
	var fwd_norm: float = clampf(spd / 420.0, 0.0, 1.35)
	var acc_norm: float = clampf(((spd - prev_spd) / maxf(delta, 0.001)) / maxf(accel_rate, 100.0), -1.0, 1.0)
	unit.set_tilt_25d(0.0, 0.0)
	unit.step(delta, ang_vel, fwd_norm, acc_norm)
	return next_vel


func _draw() -> void:
	if not _show_beacon:
		return
	var outer_col := Color(0.28, 0.94, 1.0, 0.72)
	var inner_col := Color(1.0, 0.52, 0.25, 0.85)
	draw_arc(_beacon_pos, 26.0, 0.0, TAU, 32, outer_col, 1.6, true)
	draw_arc(_beacon_pos, 14.0, _seq_elapsed * 2.5, _seq_elapsed * 2.5 + PI * 1.4, 20, inner_col, 1.8, true)
	draw_line(_beacon_pos + Vector2(-9.0, 0.0), _beacon_pos + Vector2(9.0, 0.0), outer_col, 1.2, true)
	draw_line(_beacon_pos + Vector2(0.0, -9.0), _beacon_pos + Vector2(0.0, 9.0), outer_col, 1.2, true)
