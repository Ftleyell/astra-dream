class_name PlanarRigAnimationRuntime
extends RefCounted
## Controlador runtime unificado de las 6 capas de animación del Animation Rig
## (Pose Base Zero-G, Idle, Locomoción/Freno/Reversa, Giros 8-Dir, Jiggle Physics y Face Live)
## más reacciones aditivas de combate (Dash, Recoil, Hit-React y Air-Brake).

const BasePoseConfigScript = preload("res://data/pilots/schemas/pilot_base_pose_config.gd")
const IdleAnimConfigScript = preload("res://data/pilots/schemas/pilot_idle_anim_config.gd")
const LocomotionAnimConfigScript = preload("res://data/pilots/schemas/pilot_locomotion_anim_config.gd")
const GroundedConfigScript = preload("res://data/pilots/schemas/pilot_grounded_locomotion_config.gd")
const KitingAnimConfigScript = preload("res://data/pilots/schemas/pilot_kiting_anim_config.gd")
const TurnAnimConfigScript = preload("res://data/pilots/schemas/pilot_turn_anim_config.gd")
const JigglePhysicsConfigScript = preload("res://data/pilots/schemas/pilot_jiggle_physics_config.gd")
const FaceAnimConfigScript = preload("res://data/pilots/schemas/pilot_face_anim_config.gd")
const BasePoseEvaluatorScript = preload("res://scenes/pilots/rig/planar_rig_base_pose_evaluator.gd")
const GroundedEvaluatorScript = preload("res://scenes/pilots/rig/planar_rig_grounded_evaluator.gd")
const KitingEvaluatorScript = preload("res://scenes/pilots/rig/planar_rig_kiting_evaluator.gd")

const DEFAULT_BASE_POSE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_base_pose.tres"
const DEFAULT_IDLE_ANIM_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_idle_anim.tres"
const DEFAULT_LOCO_ANIM_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_locomotion_anim.tres"
const DEFAULT_GROUNDED_LOCO_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_grounded_locomotion.tres"
const DEFAULT_KITING_ANIM_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_kiting_anim.tres"
const DEFAULT_TURN_ANIM_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_turn_anim.tres"
const DEFAULT_JIGGLE_PHYSICS_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_jiggle_physics.tres"
const DEFAULT_FACE_ANIM_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_face_anim.tres"

enum LocomotionMode {
	ZERO_G_FLIGHT = 0,
	GROUNDED_HUB = 1,
}

const DASH_DURATION_SEC: float = 0.24
const RECOIL_DURATION_SEC: float = 0.16
const HIT_DURATION_SEC: float = 0.22
const AIR_BRAKE_DURATION_SEC: float = 0.28

var evaluator: BasePoseEvaluatorScript = null
var grounded_evaluator: GroundedEvaluatorScript = null
var kiting_evaluator: KitingEvaluatorScript = null
var base_pose_cfg: BasePoseConfigScript = null
var idle_anim_cfg: IdleAnimConfigScript = null
var loco_anim_cfg: LocomotionAnimConfigScript = null
var grounded_loco_cfg: GroundedConfigScript = null
var kiting_anim_cfg: KitingAnimConfigScript = null
var turn_anim_cfg: TurnAnimConfigScript = null
var jiggle_anim_cfg: JigglePhysicsConfigScript = null
var face_anim_cfg: FaceAnimConfigScript = null

var locomotion_mode: int = LocomotionMode.ZERO_G_FLIGHT
var pending_world_displacement_m: float = -1.0
var pose_layer_mode: int = BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D
var idle_enabled: bool = true
var loco_enabled: bool = true
var kiting_enabled: bool = true
var turn_enabled: bool = true
var jiggle_enabled: bool = true
var face_enabled: bool = true

var idle_time: float = 0.0
var live_loco_weights: Dictionary = {}
var live_kiting_weights: Dictionary = {}

var _dash_timer: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _recoil_timer: float = 0.0
var _recoil_strength: float = 0.0
var _recoil_dir: Vector2 = Vector2.RIGHT
var _hit_timer: float = 0.0
var _hit_strength: float = 0.0
var _hit_dir: Vector2 = Vector2.LEFT
var _air_brake_timer: float = 0.0
var _air_brake_strength: float = 0.0


func _init() -> void:
	evaluator = BasePoseEvaluatorScript.new()
	grounded_evaluator = GroundedEvaluatorScript.new()
	kiting_evaluator = KitingEvaluatorScript.new()


func setup(profile: PilotRigProfile, rig: Node2D, apply_all_views: bool = true) -> void:
	if evaluator == null:
		evaluator = BasePoseEvaluatorScript.new()
	if grounded_evaluator == null:
		grounded_evaluator = GroundedEvaluatorScript.new()
	if kiting_evaluator == null:
		kiting_evaluator = KitingEvaluatorScript.new()
	evaluator.ensure_assets_loaded()
	_load_configs(profile, false)
	sync_turn_timings(rig)
	if rig != null:
		rig.call("set_face_live_enabled", face_enabled, face_anim_cfg)
		if apply_all_views:
			apply_to_rig(rig, true)


func reload_from_disk(profile: PilotRigProfile, rig: Node2D) -> void:
	if evaluator == null:
		evaluator = BasePoseEvaluatorScript.new()
	if grounded_evaluator == null:
		grounded_evaluator = GroundedEvaluatorScript.new()
	if kiting_evaluator == null:
		kiting_evaluator = KitingEvaluatorScript.new()
	evaluator.ensure_assets_loaded()
	_load_configs(profile, true)
	sync_turn_timings(rig)
	if rig != null:
		rig.call("set_face_live_enabled", face_enabled, face_anim_cfg)
		apply_to_rig(rig, true)


func _load_configs(profile: PilotRigProfile, ignore_cache: bool) -> void:
	base_pose_cfg = _resolve_cfg(profile.base_pose_config if profile != null else null, DEFAULT_BASE_POSE_PATH, BasePoseConfigScript, ignore_cache) as BasePoseConfigScript
	if base_pose_cfg == null:
		base_pose_cfg = BasePoseConfigScript.new()
	base_pose_cfg.ensure_initialized()

	idle_anim_cfg = _resolve_cfg(profile.idle_anim_config if profile != null else null, DEFAULT_IDLE_ANIM_PATH, IdleAnimConfigScript, ignore_cache) as IdleAnimConfigScript
	if idle_anim_cfg == null:
		idle_anim_cfg = IdleAnimConfigScript.new()
	idle_anim_cfg.ensure_initialized()

	loco_anim_cfg = _resolve_cfg(profile.locomotion_anim_config if profile != null else null, DEFAULT_LOCO_ANIM_PATH, LocomotionAnimConfigScript, ignore_cache) as LocomotionAnimConfigScript
	if loco_anim_cfg == null:
		loco_anim_cfg = LocomotionAnimConfigScript.new()
	loco_anim_cfg.ensure_initialized()

	grounded_loco_cfg = _resolve_cfg(profile.grounded_locomotion_config if profile != null else null, DEFAULT_GROUNDED_LOCO_PATH, GroundedConfigScript, ignore_cache) as GroundedConfigScript
	if grounded_loco_cfg == null:
		grounded_loco_cfg = GroundedConfigScript.new()
	grounded_loco_cfg.ensure_initialized()

	kiting_anim_cfg = _resolve_cfg(profile.kiting_anim_config if profile != null else null, DEFAULT_KITING_ANIM_PATH, KitingAnimConfigScript, ignore_cache) as KitingAnimConfigScript
	if kiting_anim_cfg == null:
		kiting_anim_cfg = KitingAnimConfigScript.new()
	kiting_anim_cfg.ensure_initialized()

	turn_anim_cfg = _resolve_cfg(profile.turn_anim_config if profile != null else null, DEFAULT_TURN_ANIM_PATH, TurnAnimConfigScript, ignore_cache) as TurnAnimConfigScript
	if turn_anim_cfg == null:
		turn_anim_cfg = TurnAnimConfigScript.new()
	turn_anim_cfg.ensure_initialized()

	jiggle_anim_cfg = _resolve_cfg(profile.jiggle_physics_config if profile != null else null, DEFAULT_JIGGLE_PHYSICS_PATH, JigglePhysicsConfigScript, ignore_cache) as JigglePhysicsConfigScript
	if jiggle_anim_cfg == null:
		jiggle_anim_cfg = JigglePhysicsConfigScript.new()
	jiggle_anim_cfg.ensure_initialized()

	face_anim_cfg = _resolve_cfg(profile.face_anim_config if profile != null else null, DEFAULT_FACE_ANIM_PATH, FaceAnimConfigScript, ignore_cache) as FaceAnimConfigScript
	if face_anim_cfg == null:
		face_anim_cfg = FaceAnimConfigScript.new()


func _resolve_cfg(profile_res: Resource, fallback_path: String, expected_script: Variant, ignore_cache: bool) -> Resource:
	var res_path: String = ""
	if profile_res != null and not profile_res.resource_path.is_empty():
		res_path = profile_res.resource_path
	elif not fallback_path.is_empty():
		res_path = fallback_path

	if ignore_cache and not res_path.is_empty() and ResourceLoader.exists(res_path):
		var reloaded: Resource = ResourceLoader.load(res_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if reloaded != null and is_instance_of(reloaded, expected_script):
			return reloaded.duplicate(true)

	if profile_res != null and is_instance_of(profile_res, expected_script):
		return profile_res.duplicate(true)

	if not fallback_path.is_empty() and ResourceLoader.exists(fallback_path):
		var loaded: Resource = ResourceLoader.load(fallback_path)
		if loaded != null and is_instance_of(loaded, expected_script):
			return loaded.duplicate(true)
	return null


func sync_turn_timings(rig: Node2D) -> void:
	if rig == null:
		return
	if turn_enabled and turn_anim_cfg != null:
		rig.call("configure_turn_timings", turn_anim_cfg.body_turn_duration_sec, turn_anim_cfg.body_swap_point, turn_anim_cfg.head_turn_duration_sec)
	else:
		rig.call("configure_turn_timings", 0.0, 0.0, 0.0)


func set_pose_layer_mode(mode: int, rig: Node2D) -> void:
	pose_layer_mode = clampi(mode, 0, 3)
	apply_to_rig(rig, true)


func set_idle_enabled(enabled: bool, rig: Node2D) -> void:
	idle_enabled = enabled
	if not enabled:
		idle_time = 0.0
	apply_to_rig(rig, true)


func set_loco_enabled(enabled: bool, rig: Node2D) -> void:
	loco_enabled = enabled
	if not enabled:
		live_loco_weights.clear()
		if evaluator != null:
			evaluator.reset_live_locomotion_state()
	apply_to_rig(rig, true)


func set_kiting_enabled(enabled: bool, rig: Node2D) -> void:
	kiting_enabled = enabled
	if not enabled:
		live_kiting_weights.clear()
		if kiting_evaluator != null:
			kiting_evaluator.reset_state()
	apply_to_rig(rig, true)


func set_turn_enabled(enabled: bool, rig: Node2D) -> void:
	turn_enabled = enabled
	sync_turn_timings(rig)
	apply_to_rig(rig, true)


func set_jiggle_enabled(enabled: bool, rig: Node2D) -> void:
	jiggle_enabled = enabled
	if not enabled and evaluator != null:
		evaluator.reset_jiggle_physics_state()
	apply_to_rig(rig, true)


func set_face_enabled(enabled: bool, rig: Node2D) -> void:
	face_enabled = enabled
	if rig != null:
		rig.call("set_face_live_enabled", enabled, face_anim_cfg)


func set_face_personality_profile(profile_id: int, rig: Node2D) -> void:
	if face_anim_cfg != null:
		face_anim_cfg.personality_profile = profile_id
	if rig != null:
		rig.call("set_face_personality_profile", profile_id)


func reset_combat_impulses() -> void:
	_dash_timer = 0.0
	_recoil_timer = 0.0
	_recoil_strength = 0.0
	_hit_timer = 0.0
	_hit_strength = 0.0
	_air_brake_timer = 0.0
	_air_brake_strength = 0.0


func reset_to_rest(rig: Node2D) -> void:
	idle_time = 0.0
	pending_world_displacement_m = -1.0
	live_loco_weights.clear()
	live_kiting_weights.clear()
	reset_combat_impulses()
	if evaluator != null:
		evaluator.reset_live_locomotion_state()
		evaluator.reset_jiggle_physics_state()
	if grounded_evaluator != null:
		grounded_evaluator.reset_state()
	if kiting_evaluator != null:
		kiting_evaluator.reset_state()
	if rig != null:
		rig.call("configure_turn_timings", 0.0, 0.0, 0.0)
		rig.call("set_face_live_enabled", false, null)
		if evaluator != null:
			evaluator.apply_pose_to_rig_all_views(rig, base_pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.DEFAULT_RIG_REST, 1.0, false, 0.0, null, null, {}, null, {}, null)


func set_locomotion_mode(mode: int, rig: Node2D = null) -> void:
	var target: int = LocomotionMode.GROUNDED_HUB if mode == LocomotionMode.GROUNDED_HUB else LocomotionMode.ZERO_G_FLIGHT
	if locomotion_mode == target:
		return
	locomotion_mode = target
	pending_world_displacement_m = -1.0
	if grounded_evaluator != null:
		grounded_evaluator.reset_state()
	if rig != null:
		apply_to_rig(rig, true)


func get_locomotion_mode() -> int:
	return locomotion_mode


func feed_world_displacement(dist_m: float) -> void:
	if dist_m >= 0.0:
		if pending_world_displacement_m < 0.0:
			pending_world_displacement_m = dist_m
		else:
			pending_world_displacement_m += dist_m


func trigger_grounded_pivot(turn_sign: float = 1.0) -> void:
	if grounded_evaluator != null:
		grounded_evaluator.trigger_pivot(turn_sign)


func consume_grounded_step_event() -> Dictionary:
	return grounded_evaluator.consume_step_event() if grounded_evaluator != null else {}


func get_grounded_pelvis_lift_norm() -> float:
	return grounded_evaluator.pelvis_lift_norm if grounded_evaluator != null else 0.0


func get_grounded_gait_phase() -> float:
	return grounded_evaluator.gait_phase if grounded_evaluator != null else 0.0


func trigger_dash_burst(dir: Vector2) -> void:
	_dash_timer = DASH_DURATION_SEC
	_dash_dir = dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT
	if jiggle_enabled and evaluator != null:
		var side: float = 1.0 if _dash_dir.x >= 0.0 else -1.0
		evaluator.trigger_jiggle_impulse(Vector2(-_dash_dir.x * 26.0, 18.0), Vector2(-_dash_dir.x * 22.0, 14.0), side)


func trigger_attack_recoil(aim_dir: Vector2, strength: float = 1.0) -> void:
	_recoil_timer = RECOIL_DURATION_SEC
	_recoil_strength = clampf(strength, 0.25, 1.8)
	_recoil_dir = aim_dir.normalized() if aim_dir.length_squared() > 0.01 else Vector2.RIGHT
	if jiggle_enabled and evaluator != null:
		var kick: Vector2 = -_recoil_dir * (18.0 * _recoil_strength)
		var side: float = 1.0 if _recoil_dir.x >= 0.0 else -1.0
		evaluator.trigger_jiggle_impulse(kick + Vector2(0.0, 10.0 * _recoil_strength), kick * 0.65, side)


func trigger_hit_react(hit_dir: Vector2, strength: float = 1.0, rig: Node2D = null) -> void:
	_hit_timer = HIT_DURATION_SEC
	_hit_strength = clampf(strength, 0.25, 1.8)
	_hit_dir = hit_dir.normalized() if hit_dir.length_squared() > 0.01 else Vector2.LEFT
	if jiggle_enabled and evaluator != null:
		var shock: Vector2 = _hit_dir * (30.0 * _hit_strength)
		var side: float = 1.0 if _hit_dir.x >= 0.0 else -1.0
		evaluator.trigger_jiggle_impulse(shock + Vector2(0.0, -20.0 * _hit_strength), shock * 0.85 + Vector2(0.0, 14.0 * _hit_strength), -side)
	if rig != null:
		rig.call("trigger_hit_flash", 0.62 * _hit_strength)


func trigger_air_brake(strength: float = 1.0) -> void:
	_air_brake_timer = AIR_BRAKE_DURATION_SEC
	_air_brake_strength = clampf(strength, 0.3, 1.6)
	if jiggle_enabled and evaluator != null:
		evaluator.trigger_jiggle_impulse(Vector2(0.0, -24.0 * _air_brake_strength), Vector2(0.0, 18.0 * _air_brake_strength), 1.0)


func step(
	delta: float,
	rig: Node2D,
	speed_norm: float,
	move_dir: Vector2,
	aim_dir: Vector2,
	is_backpedaling: bool,
	is_turbo: bool
) -> void:
	if rig == null or evaluator == null:
		return
	var dt: float = clampf(delta, 0.0, 0.08)
	if idle_enabled:
		idle_time += dt

	_dash_timer = maxf(0.0, _dash_timer - dt)
	_recoil_timer = maxf(0.0, _recoil_timer - dt)
	_hit_timer = maxf(0.0, _hit_timer - dt)
	_air_brake_timer = maxf(0.0, _air_brake_timer - dt)

	var eff_speed: float = clampf(speed_norm * (1.28 if is_turbo else 1.0), 0.0, 1.45)
	if _dash_timer > 0.0:
		eff_speed = maxf(eff_speed, 1.35)

	if locomotion_mode == LocomotionMode.GROUNDED_HUB:
		_step_grounded_hub(dt, rig, eff_speed, move_dir, aim_dir, is_backpedaling, is_turbo)
		return

	if loco_enabled:
		live_loco_weights = evaluator.step_live_locomotion_weights(dt, eff_speed, is_backpedaling, loco_anim_cfg)
		if _dash_timer > 0.0:
			var dash_u: float = _dash_timer / DASH_DURATION_SEC
			live_loco_weights["fwd"] = maxf(float(live_loco_weights.get("fwd", 0.0)), clampf(dash_u * 1.15, 0.0, 1.25))
		if _air_brake_timer > 0.0:
			var brk_u: float = (_air_brake_timer / AIR_BRAKE_DURATION_SEC) * _air_brake_strength
			live_loco_weights["brk"] = maxf(float(live_loco_weights.get("brk", 0.0)), clampf(brk_u * 1.15, 0.0, 1.25))

	if kiting_enabled:
		if kiting_evaluator == null:
			kiting_evaluator = KitingEvaluatorScript.new()
		var active_vk: String = str(rig.call("get_active_view_key"))
		live_kiting_weights = kiting_evaluator.step_live_weights(dt, eff_speed, move_dir, aim_dir, active_vk, is_backpedaling, kiting_anim_cfg)

	if jiggle_enabled:
		var j_loco: Dictionary = live_loco_weights if loco_enabled else {}
		var j_kiting: Dictionary = live_kiting_weights if kiting_enabled else {}
		var j_turn: Dictionary = rig.call("get_turn_anim_state") as Dictionary if turn_enabled else {}
		evaluator.step_live_jiggle_physics(dt, j_loco, j_turn, jiggle_anim_cfg, j_kiting)

	apply_to_rig(rig, false)
	_apply_combat_additive_to_pivot(rig)

	if face_enabled:
		var vel_norm: Vector2 = move_dir.normalized() * eff_speed if move_dir.length_squared() > 0.001 else Vector2.ZERO
		var face_loco: Dictionary = live_loco_weights.duplicate() if loco_enabled else {}
		if kiting_enabled and not live_kiting_weights.is_empty():
			face_loco["brk"] = maxf(float(face_loco.get("brk", 0.0)), float(live_kiting_weights.get("rbrk", 0.0)))
		rig.call("step_face_live", dt, {
			"head_key": rig.call("get_active_head_key"),
			"aim_dir": aim_dir,
			"vel_norm": vel_norm,
			"speed_norm": eff_speed,
			"is_turbo": is_turbo or (_dash_timer > 0.0),
			"is_backpedaling": is_backpedaling,
			"loco_weights": face_loco,
			"turn_state": rig.call("get_turn_anim_state") as Dictionary if turn_enabled else {},
			"head_rot_rad": float(rig.call("get_manual_head_rot")),
			"head_offset_du": rig.call("get_manual_head_offset") as Vector2,
			"sync_q_time": false,
		})


func _step_grounded_hub(
	dt: float,
	rig: Node2D,
	eff_speed: float,
	move_dir: Vector2,
	aim_dir: Vector2,
	is_backpedaling: bool,
	is_turbo: bool
) -> void:
	if grounded_evaluator == null:
		grounded_evaluator = GroundedEvaluatorScript.new()
	if grounded_loco_cfg == null:
		grounded_loco_cfg = GroundedConfigScript.new()
		grounded_loco_cfg.ensure_initialized()

	var disp_m: float = pending_world_displacement_m
	pending_world_displacement_m = -1.0
	var step_info: Dictionary = grounded_evaluator.step_gait(dt, eff_speed, disp_m, grounded_loco_cfg)

	var step_foot: StringName = step_info.get("step_foot", &"") as StringName
	if jiggle_enabled and not step_foot.is_empty():
		var foot_sign: float = 1.0 if step_foot == &"left" else -1.0
		var s_str: float = float(step_info.get("step_strength", 0.7))
		evaluator.trigger_jiggle_impulse(
			Vector2(foot_sign * 6.0, grounded_loco_cfg.step_jiggle_bust_impulse * s_str),
			Vector2(foot_sign * 4.5, -grounded_loco_cfg.step_jiggle_glute_impulse * s_str),
			foot_sign
		)

	if jiggle_enabled:
		var j_turn: Dictionary = rig.call("get_turn_anim_state") as Dictionary if turn_enabled else {}
		evaluator.step_live_jiggle_physics(dt, {}, j_turn, jiggle_anim_cfg, {})

	apply_to_rig(rig, false)
	_apply_combat_additive_to_pivot(rig)

	if face_enabled:
		var vel_norm: Vector2 = move_dir.normalized() * eff_speed if move_dir.length_squared() > 0.001 else Vector2.ZERO
		rig.call("step_face_live", dt, {
			"head_key": rig.call("get_active_head_key"),
			"aim_dir": aim_dir,
			"vel_norm": vel_norm,
			"speed_norm": eff_speed,
			"is_turbo": is_turbo or (_dash_timer > 0.0),
			"is_backpedaling": is_backpedaling,
			"loco_weights": {"fwd": grounded_evaluator.walk_blend, "brk": grounded_evaluator.stop_weight},
			"turn_state": rig.call("get_turn_anim_state") as Dictionary if turn_enabled else {},
			"head_rot_rad": float(rig.call("get_manual_head_rot")),
			"head_offset_du": rig.call("get_manual_head_offset") as Vector2,
			"sync_q_time": false,
		})


func apply_to_rig(rig: Node2D, all_views: bool) -> void:
	if rig == null or evaluator == null:
		return
	var turn_cfg_eff: TurnAnimConfigScript = turn_anim_cfg if turn_enabled else null
	var turn_st_eff: Dictionary = rig.call("get_turn_anim_state") as Dictionary if turn_enabled else {}
	var jiggle_cfg_eff: JigglePhysicsConfigScript = jiggle_anim_cfg if jiggle_enabled else null
	if locomotion_mode == LocomotionMode.GROUNDED_HUB and grounded_evaluator != null:
		grounded_evaluator.apply_to_rig(rig, evaluator, grounded_loco_cfg, pose_layer_mode, 1.0, all_views, turn_cfg_eff, turn_st_eff, jiggle_cfg_eff)
		return
	var loco_cfg_eff: LocomotionAnimConfigScript = loco_anim_cfg if loco_enabled else null
	var loco_w_eff: Dictionary = live_loco_weights if loco_enabled else {}
	var kiting_cfg_eff: KitingAnimConfigScript = kiting_anim_cfg if kiting_enabled else null
	var kiting_w_eff: Dictionary = live_kiting_weights if kiting_enabled else {}
	if all_views:
		evaluator.apply_pose_to_rig_all_views(rig, base_pose_cfg, pose_layer_mode, 1.0, idle_enabled, idle_time, idle_anim_cfg, loco_cfg_eff, loco_w_eff, turn_cfg_eff, turn_st_eff, jiggle_cfg_eff, kiting_cfg_eff, kiting_w_eff)
	else:
		var active_vk: String = str(rig.call("get_active_view_key"))
		evaluator.apply_pose_to_rig_view(rig, active_vk, base_pose_cfg, pose_layer_mode, 1.0, idle_enabled, idle_time, idle_anim_cfg, loco_cfg_eff, loco_w_eff, turn_cfg_eff, turn_st_eff, jiggle_cfg_eff, kiting_cfg_eff, kiting_w_eff)


func _apply_combat_additive_to_pivot(rig: Node2D) -> void:
	var bp: Node2D = rig.call("get_body_pivot") as Node2D
	if bp == null:
		return
	var add_pos := Vector2.ZERO
	var add_rot: float = 0.0

	if _dash_timer > 0.0:
		var u: float = sin((_dash_timer / DASH_DURATION_SEC) * PI)
		add_pos += _dash_dir * (8.5 * u)
		add_rot += clampf(_dash_dir.x, -1.0, 1.0) * 0.095 * u
	if _recoil_timer > 0.0:
		var u_r: float = pow(_recoil_timer / RECOIL_DURATION_SEC, 1.4) * _recoil_strength
		add_pos += -_recoil_dir * (7.5 * u_r)
		add_rot += -clampf(_recoil_dir.x, -1.0, 1.0) * 0.075 * u_r
	if _hit_timer > 0.0:
		var u_h: float = (_hit_timer / HIT_DURATION_SEC) * _hit_strength
		var shake: float = sin(_hit_timer * 68.0) * u_h
		add_pos += _hit_dir * (9.0 * u_h) + Vector2(shake * 5.0, -3.5 * u_h)
		add_rot += (-clampf(_hit_dir.x, -1.0, 1.0) * 0.11 + shake * 0.04) * u_h
	if _air_brake_timer > 0.0:
		var u_b: float = sin((_air_brake_timer / AIR_BRAKE_DURATION_SEC) * PI) * _air_brake_strength
		add_pos += Vector2(0.0, -5.5 * u_b)
		add_rot += -0.055 * u_b

	bp.position = add_pos
	bp.rotation = add_rot


func is_dash_burst_active() -> bool:
	return _dash_timer > 0.0


func is_attack_recoil_active() -> bool:
	return _recoil_timer > 0.0


func is_hit_react_active() -> bool:
	return _hit_timer > 0.0


func is_air_brake_active() -> bool:
	return _air_brake_timer > 0.0


func get_active_additive_summary() -> String:
	var tags: Array[String] = []
	if _dash_timer > 0.0:
		tags.append("DASH")
	if _recoil_timer > 0.0:
		tags.append("RECOIL")
	if _hit_timer > 0.0:
		tags.append("HIT")
	if _air_brake_timer > 0.0:
		tags.append("AIR_BRAKE")
	return "+".join(tags) if not tags.is_empty() else "NONE"


func format_loco_state_tag() -> String:
	if not loco_enabled and not kiting_enabled:
		return "LOCO OFF"
	var w_fwd: float = float(live_loco_weights.get("fwd", 0.0)) if loco_enabled else 0.0
	var w_brk: float = float(live_loco_weights.get("brk", 0.0)) if loco_enabled else 0.0
	var w_rev: float = float(live_loco_weights.get("rev", 0.0)) if loco_enabled else 0.0
	if kiting_enabled and not live_kiting_weights.is_empty():
		var w_rbrk: float = float(live_kiting_weights.get("rbrk", 0.0))
		var w_krev: float = float(live_kiting_weights.get("rev", 0.0))
		var w_near: float = float(live_kiting_weights.get("str_near", 0.0))
		var w_far: float = float(live_kiting_weights.get("str_far", 0.0))
		var k_dom: float = maxf(w_rbrk, maxf(w_krev, maxf(w_near, w_far)))
		if k_dom > 0.18 and (k_dom >= maxf(w_fwd, w_brk) or w_rbrk > 0.22):
			var k_tag: String = KitingEvaluatorScript.format_state_tag(live_kiting_weights)
			if not k_tag.is_empty():
				return k_tag
	if w_brk >= maxf(w_fwd, w_rev) and w_brk > 0.18:
		return "FRENO %.2f" % w_brk
	if w_fwd >= w_rev and w_fwd > 0.18:
		return "VUELO %.2f" % w_fwd
	if w_rev > 0.18:
		return "REVERSA %.2f" % w_rev
	return "IDLE"
