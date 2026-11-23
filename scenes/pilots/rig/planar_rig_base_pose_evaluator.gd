class_name PlanarRigBasePoseEvaluator
extends RefCounted
## Evaluador desacoplado de Pose Base estática Zero-G, Idle Multicapa y Locomoción/Freno Suave.
## Soporta modos A/B independientes, 4 cadencias temporales y simetría automática para las 8 vistas nativas de Valentina v2.

const MeshBuilderScript = preload("res://scenes/pilots/rig/planar_rig_mesh_builder.gd")
const CalibStoreScript = preload("res://scenes/pilots/rig/planar_rig_calibration_helpers.gd")
const PerspConfigScript = preload("res://scenes/pilots/rig/rig_perspective_config.gd")
const BasePoseConfigScript = preload("res://data/pilots/schemas/pilot_base_pose_config.gd")
const IdleAnimConfigScript = preload("res://data/pilots/schemas/pilot_idle_anim_config.gd")
const LocomotionAnimConfigScript = preload("res://data/pilots/schemas/pilot_locomotion_anim_config.gd")
const TurnAnimConfigScript = preload("res://data/pilots/schemas/pilot_turn_anim_config.gd")
const JigglePhysicsConfigScript = preload("res://data/pilots/schemas/pilot_jiggle_physics_config.gd")
const KitingAnimConfigScript = preload("res://data/pilots/schemas/pilot_kiting_anim_config.gd")
const KitingEvaluatorScript = preload("res://scenes/pilots/rig/planar_rig_kiting_evaluator.gd")
const PERSP_CONFIG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_perspective_config.tres"

enum PoseLayerMode {
	COMBINED_BONES_AND_25D = 0,
	BONES_ONLY = 1,
	SHADER_25D_ONLY = 2,
	DEFAULT_RIG_REST = 3,
}

const ALL_VIEWS: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]

var _zone_masks: Dictionary = {}
var _hip_shadows: Dictionary = {}
var _stocking_pinches: Dictionary = {}
var _persp_cfg: PerspConfigScript = null
var _default_idle_cfg: IdleAnimConfigScript = null
var _default_loco_cfg: LocomotionAnimConfigScript = null
var _default_turn_cfg: TurnAnimConfigScript = null
var _default_jiggle_cfg: JigglePhysicsConfigScript = null
var _assets_loaded: bool = false

var _live_fwd_w: float = 0.0
var _live_brk_w: float = 0.0
var _live_rev_w: float = 0.0
var _cruise_momentum: float = 0.0
var _prev_speed_norm: float = 0.0
var _last_was_rev: bool = false

var _bust_pos_l: Vector2 = Vector2.ZERO
var _bust_vel_l: Vector2 = Vector2.ZERO
var _bust_pos_r: Vector2 = Vector2.ZERO
var _bust_vel_r: Vector2 = Vector2.ZERO
var _glute_pos_l: Vector2 = Vector2.ZERO
var _glute_vel_l: Vector2 = Vector2.ZERO
var _glute_pos_r: Vector2 = Vector2.ZERO
var _glute_vel_r: Vector2 = Vector2.ZERO
var _prev_fwd_w: float = 0.0
var _prev_brk_w: float = 0.0
var _prev_rev_w: float = 0.0
var _prev_rbrk_w: float = 0.0
var _prev_lat_kiting: float = 0.0
var _prev_turn_active: bool = false
var _prev_body_swapped: bool = false
var _prev_head_active: bool = false


static func soft_clamp_vec2(v: Vector2, max_r: float) -> Vector2:
	if max_r <= 0.0001:
		return Vector2.ZERO
	var l: float = v.length()
	if l <= 0.0001:
		return v
	return v * (tanh(l / max_r) * max_r / l)


func reset_jiggle_physics_state() -> void:
	_bust_pos_l = Vector2.ZERO
	_bust_vel_l = Vector2.ZERO
	_bust_pos_r = Vector2.ZERO
	_bust_vel_r = Vector2.ZERO
	_glute_pos_l = Vector2.ZERO
	_glute_vel_l = Vector2.ZERO
	_glute_pos_r = Vector2.ZERO
	_glute_vel_r = Vector2.ZERO
	_prev_fwd_w = 0.0
	_prev_brk_w = 0.0
	_prev_rev_w = 0.0
	_prev_rbrk_w = 0.0
	_prev_lat_kiting = 0.0
	_prev_turn_active = false
	_prev_body_swapped = false
	_prev_head_active = false


func trigger_jiggle_impulse(
	bust_impulse_px_s: Vector2,
	glute_impulse_px_s: Vector2,
	lr_asymmetry_sign: float = 1.0
) -> void:
	var asym_l: float = 1.0 + 0.14 * lr_asymmetry_sign
	var asym_r: float = 1.0 - 0.14 * lr_asymmetry_sign
	_bust_vel_l += bust_impulse_px_s * asym_l + Vector2(lr_asymmetry_sign * 3.0, 0.0)
	_bust_vel_r += bust_impulse_px_s * asym_r - Vector2(lr_asymmetry_sign * 3.0, 0.0)
	_glute_vel_l += glute_impulse_px_s * asym_l + Vector2(lr_asymmetry_sign * 2.4, 0.0)
	_glute_vel_r += glute_impulse_px_s * asym_r - Vector2(lr_asymmetry_sign * 2.4, 0.0)


func step_live_jiggle_physics(
	delta: float,
	loco_weights: Dictionary,
	turn_state: Dictionary,
	jiggle_cfg: JigglePhysicsConfigScript = null,
	kiting_weights: Dictionary = {}
) -> Dictionary:
	ensure_assets_loaded()
	var cfg: JigglePhysicsConfigScript = jiggle_cfg if jiggle_cfg != null else _default_jiggle_cfg
	var dt: float = clampf(delta, 0.001, 0.08)

	var fwd_w: float = float(loco_weights.get("fwd", 0.0))
	var brk_w: float = float(loco_weights.get("brk", 0.0))
	var rev_w: float = float(loco_weights.get("rev", 0.0))
	var rbrk_w: float = float(kiting_weights.get("rbrk", 0.0))
	var lat_w: float = float(kiting_weights.get("lat_signed", 0.0))
	var d_fwd: float = clampf(fwd_w - _prev_fwd_w, -0.5, 0.5)
	var d_brk: float = clampf(brk_w - _prev_brk_w, -0.5, 0.5)
	var d_rev: float = clampf(rev_w - _prev_rev_w, -0.5, 0.5)
	var d_rbrk: float = clampf(rbrk_w - _prev_rbrk_w, -0.5, 0.5)
	var d_lat: float = clampf(lat_w - _prev_lat_kiting, -0.5, 0.5)
	_prev_fwd_w = fwd_w
	_prev_brk_w = brk_w
	_prev_rev_w = rev_w
	_prev_rbrk_w = rbrk_w
	_prev_lat_kiting = lat_w

	var b_gain: float = cfg.bust_inertia_gain if cfg.enable_bust_jiggle else 0.0
	var g_gain: float = cfg.glute_inertia_gain if cfg.enable_glute_jiggle else 0.0

	if d_brk > 0.002:
		var brk_b := Vector2(0.45, 1.0) * d_brk * 68.0 * b_gain
		var brk_g := Vector2(0.35, -0.85) * d_brk * 58.0 * g_gain
		_bust_vel_l += brk_b * (1.0 + 0.16 * cfg.bust_lr_asymmetry)
		_bust_vel_r += brk_b * (1.0 - 0.16 * cfg.bust_lr_asymmetry)
		_glute_vel_l += brk_g * (1.0 + 0.16 * cfg.glute_lr_asymmetry)
		_glute_vel_r += brk_g * (1.0 - 0.16 * cfg.glute_lr_asymmetry)

	if d_rbrk > 0.002:
		var rbrk_b := Vector2(-0.42, 0.85) * d_rbrk * 64.0 * b_gain
		var rbrk_g := Vector2(-0.35, -0.75) * d_rbrk * 54.0 * g_gain
		_bust_vel_l += rbrk_b * (1.0 + 0.15 * cfg.bust_lr_asymmetry)
		_bust_vel_r += rbrk_b * (1.0 - 0.15 * cfg.bust_lr_asymmetry)
		_glute_vel_l += rbrk_g * (1.0 + 0.15 * cfg.glute_lr_asymmetry)
		_glute_vel_r += rbrk_g * (1.0 - 0.15 * cfg.glute_lr_asymmetry)

	if absf(d_lat) > 0.002:
		var lat_b := Vector2(-d_lat * 28.0 * b_gain, absf(d_lat) * 8.0 * b_gain)
		var lat_g := Vector2(-d_lat * 24.0 * g_gain, -absf(d_lat) * 6.0 * g_gain)
		_bust_vel_l += lat_b * (1.0 + 0.12 * cfg.bust_lr_asymmetry)
		_bust_vel_r += lat_b * (1.0 - 0.12 * cfg.bust_lr_asymmetry)
		_glute_vel_l += lat_g * (1.0 + 0.12 * cfg.glute_lr_asymmetry)
		_glute_vel_r += lat_g * (1.0 - 0.12 * cfg.glute_lr_asymmetry)

	if d_fwd > 0.002:
		var fwd_b := Vector2(-0.35, -0.65) * d_fwd * 44.0 * b_gain
		var fwd_g := Vector2(-0.30, 0.55) * d_fwd * 38.0 * g_gain
		_bust_vel_l += fwd_b * (1.0 + 0.12 * cfg.bust_lr_asymmetry)
		_bust_vel_r += fwd_b * (1.0 - 0.12 * cfg.bust_lr_asymmetry)
		_glute_vel_l += fwd_g * (1.0 + 0.12 * cfg.glute_lr_asymmetry)
		_glute_vel_r += fwd_g * (1.0 - 0.12 * cfg.glute_lr_asymmetry)

	if d_rev > 0.002:
		var rev_b := Vector2(0.30, -0.45) * d_rev * 36.0 * b_gain
		_bust_vel_l += rev_b
		_bust_vel_r += rev_b * (1.0 - 0.12 * cfg.bust_lr_asymmetry)

	var body_turn_active: bool = bool(turn_state.get("body_active", false))
	var body_swapped: bool = bool(turn_state.get("body_swapped", false))
	if body_turn_active:
		var t_dir: float = float(turn_state.get("body_turn_dir", 1.0))
		var t_mag: float = float(turn_state.get("body_turn_mag", 1.0))
		if not _prev_turn_active:
			trigger_jiggle_impulse(
				Vector2(-t_dir * 52.0 * t_mag * b_gain, 15.0 * b_gain),
				Vector2(-t_dir * 44.0 * t_mag * g_gain, -12.0 * g_gain),
				t_dir
			)
		elif body_swapped and not _prev_body_swapped:
			trigger_jiggle_impulse(
				Vector2(-t_dir * 26.0 * t_mag * b_gain, 10.0 * b_gain),
				Vector2(-t_dir * 22.0 * t_mag * g_gain, -8.0 * g_gain),
				-t_dir
			)
		else:
			_bust_vel_l += Vector2(-t_dir * 72.0 * t_mag * b_gain, 18.0 * b_gain) * dt
			_bust_vel_r += Vector2(-t_dir * 72.0 * t_mag * b_gain, 18.0 * b_gain) * dt * (1.0 - 0.15 * cfg.bust_lr_asymmetry)
			_glute_vel_l += Vector2(-t_dir * 60.0 * t_mag * g_gain, -14.0 * g_gain) * dt
			_glute_vel_r += Vector2(-t_dir * 60.0 * t_mag * g_gain, -14.0 * g_gain) * dt * (1.0 - 0.15 * cfg.glute_lr_asymmetry)
	_prev_turn_active = body_turn_active
	_prev_body_swapped = body_swapped

	var head_turn_active: bool = bool(turn_state.get("head_active", false))
	if head_turn_active and not _prev_head_active:
		var h_dir: float = float(turn_state.get("head_turn_dir", 1.0))
		_bust_vel_l += Vector2(h_dir * 11.0 * b_gain, 7.0 * b_gain)
		_bust_vel_r += Vector2(h_dir * 9.2 * b_gain, 5.6 * b_gain)
	_prev_head_active = head_turn_active

	var b_freq_l: float = cfg.bust_freq_hz
	var b_freq_r: float = cfg.bust_freq_hz * (1.0 + 0.14 * cfg.bust_lr_asymmetry)
	var g_freq_l: float = cfg.glute_freq_hz
	var g_freq_r: float = cfg.glute_freq_hz * (1.0 + 0.16 * cfg.glute_lr_asymmetry)

	var st_bl: Array = _integrate_spring_2d(_bust_pos_l, _bust_vel_l, dt, b_freq_l, cfg.bust_damping_ratio)
	_bust_pos_l = st_bl[0] as Vector2
	_bust_vel_l = st_bl[1] as Vector2
	var st_br: Array = _integrate_spring_2d(_bust_pos_r, _bust_vel_r, dt, b_freq_r, cfg.bust_damping_ratio)
	_bust_pos_r = st_br[0] as Vector2
	_bust_vel_r = st_br[1] as Vector2

	var st_gl: Array = _integrate_spring_2d(_glute_pos_l, _glute_vel_l, dt, g_freq_l, cfg.glute_damping_ratio)
	_glute_pos_l = st_gl[0] as Vector2
	_glute_vel_l = st_gl[1] as Vector2
	var st_gr: Array = _integrate_spring_2d(_glute_pos_r, _glute_vel_r, dt, g_freq_r, cfg.glute_damping_ratio)
	_glute_pos_r = st_gr[0] as Vector2
	_glute_vel_r = st_gr[1] as Vector2

	return {
		"bust_l": _bust_pos_l,
		"bust_r": _bust_pos_r,
		"glute_l": _glute_pos_l,
		"glute_r": _glute_pos_r,
	}


static func _integrate_spring_2d(pos: Vector2, vel: Vector2, dt: float, freq_hz: float, damp_ratio: float) -> Array:
	var sub_steps: int = maxi(1, int(ceil(dt / 0.008)))
	var h: float = dt / float(sub_steps)
	var omega: float = TAU * maxf(freq_hz, 0.25)
	var k_stiff: float = omega * omega
	var c_damp: float = 2.0 * maxf(damp_ratio, 0.05) * omega
	var p: Vector2 = pos
	var v: Vector2 = vel
	for _s: int in range(sub_steps):
		var acc: Vector2 = -k_stiff * p - c_damp * v
		v += acc * h
		p += v * h
	return [p, v]


static func sample_harmonic_wave(phase: float, asym: float) -> float:
	return sin(phase) + asym * sin(phase * 2.0 - 0.35)


static func compute_preview_locomotion_weights(preview_mode: int, anim_time: float, cycle_dur: float = 4.4) -> Dictionary:
	match preview_mode:
		LocomotionAnimConfigScript.PreviewMode.FORWARD_CRUISE:
			return {"fwd": 1.0, "brk": 0.0, "rev": 0.0}
		LocomotionAnimConfigScript.PreviewMode.BRAKE_COUNTER:
			return {"fwd": 0.0, "brk": 1.0, "rev": 0.0}
		LocomotionAnimConfigScript.PreviewMode.BACKPEDAL_REVERSE:
			return {"fwd": 0.0, "brk": 0.0, "rev": 1.0}
		_:
			var dur: float = maxf(cycle_dur, 1.0)
			var u: float = fposmod(anim_time, dur) / dur
			var fwd: float = smoothstep(0.18, 0.30, u) * (1.0 - smoothstep(0.46, 0.56, u))
			var brk: float = smoothstep(0.48, 0.56, u) * (1.0 - smoothstep(0.64, 0.78, u))
			return {"fwd": fwd, "brk": brk, "rev": 0.0}


func reset_live_locomotion_state() -> void:
	_live_fwd_w = 0.0
	_live_brk_w = 0.0
	_live_rev_w = 0.0
	_cruise_momentum = 0.0
	_prev_speed_norm = 0.0
	_last_was_rev = false


func step_live_locomotion_weights(
	delta: float,
	speed_norm: float,
	is_backpedal: bool,
	loco_cfg: LocomotionAnimConfigScript = null
) -> Dictionary:
	ensure_assets_loaded()
	var cfg: LocomotionAnimConfigScript = loco_cfg if loco_cfg != null else _default_loco_cfg
	var dt: float = maxf(delta, 0.004)
	var decel_rate: float = maxf(0.0, (_prev_speed_norm - speed_norm) / dt)
	_prev_speed_norm = speed_norm

	var accel_blend: float = 1.0 - exp(-cfg.accel_blend_rate * dt)
	var enter_blend: float = 1.0 - exp(-cfg.brake_enter_rate * dt)
	var decay_blend: float = 1.0 - exp(-cfg.brake_decay_rate * dt)

	if speed_norm > 0.08:
		_last_was_rev = is_backpedal
		if decel_rate > 0.35 and not is_backpedal:
			_live_fwd_w = lerpf(_live_fwd_w, 0.0, enter_blend)
			_live_rev_w = lerpf(_live_rev_w, 0.0, enter_blend)
			var brk_target: float = clampf(maxf(_cruise_momentum, _live_fwd_w) * cfg.brake_decel_sensitivity, 0.0, 1.0)
			_live_brk_w = clampf(maxf(lerpf(_live_brk_w, brk_target, enter_blend), _live_brk_w + decel_rate * cfg.brake_decel_sensitivity * dt), 0.0, 1.0)
		else:
			var target_fwd: float = clampf(speed_norm, 0.0, 1.25) if not is_backpedal else 0.0
			var target_rev: float = clampf(speed_norm, 0.0, 1.25) if is_backpedal else 0.0
			_live_fwd_w = lerpf(_live_fwd_w, target_fwd, accel_blend)
			_live_rev_w = lerpf(_live_rev_w, target_rev, accel_blend)
			_cruise_momentum = maxf(_cruise_momentum * (1.0 - decay_blend * 0.5), _live_fwd_w)
			_live_brk_w = lerpf(_live_brk_w, 0.0, enter_blend if speed_norm > 0.35 else decay_blend)
	else:
		var rem_fwd: float = maxf(_live_fwd_w, _cruise_momentum)
		if rem_fwd > 0.10 and not _last_was_rev:
			_live_brk_w = clampf(maxf(_live_brk_w, rem_fwd * cfg.brake_decel_sensitivity), 0.0, 1.0)
		_cruise_momentum = 0.0
		_live_fwd_w = lerpf(_live_fwd_w, 0.0, enter_blend)
		_live_rev_w = lerpf(_live_rev_w, 0.0, enter_blend)
		_live_brk_w = lerpf(_live_brk_w, 0.0, decay_blend)

	return {"fwd": _live_fwd_w, "brk": _live_brk_w, "rev": _live_rev_w}


func ensure_assets_loaded() -> void:
	if _assets_loaded:
		return
	_assets_loaded = true
	if ResourceLoader.exists(PERSP_CONFIG_PATH):
		_persp_cfg = ResourceLoader.load(PERSP_CONFIG_PATH) as PerspConfigScript
	if _persp_cfg == null:
		_persp_cfg = PerspConfigScript.new()
	if _default_idle_cfg == null:
		_default_idle_cfg = IdleAnimConfigScript.new()
		_default_idle_cfg.ensure_initialized()
	if _default_loco_cfg == null:
		_default_loco_cfg = LocomotionAnimConfigScript.new()
		_default_loco_cfg.ensure_initialized()
	if _default_turn_cfg == null:
		_default_turn_cfg = TurnAnimConfigScript.new()
		_default_turn_cfg.ensure_initialized()
	if _default_jiggle_cfg == null:
		_default_jiggle_cfg = JigglePhysicsConfigScript.new()
		_default_jiggle_cfg.ensure_initialized()

	for v_key: String in ALL_VIEWS:
		_zone_masks["%s_r" % v_key] = _load_png_tex("res://assets/pilots/shared/persp_masks/leg_r_%s_persp_mask.png" % v_key)
		_zone_masks["%s_l" % v_key] = _load_png_tex("res://assets/pilots/shared/persp_masks/leg_l_%s_persp_mask.png" % v_key)
		var meta_path: String = "%s/%s/parts_5/parts_5_meta.json" % [MeshBuilderScript.ASSETS_ROOT, v_key]
		var meta_d: Dictionary = MeshBuilderScript.load_json_dict(meta_path)
		_hip_shadows[v_key] = CalibStoreScript.parse_hip_cast_shadow_from_meta(meta_d, v_key)
		_stocking_pinches[v_key] = CalibStoreScript.parse_stocking_pinch_from_meta(meta_d)


func apply_pose_to_rig_all_views(
	rig: PlanarCombatRig,
	pose_cfg: BasePoseConfigScript,
	layer_mode: int,
	pose_scale: float = 1.0,
	micro_hover_enabled: bool = false,
	anim_time: float = 0.0,
	idle_cfg: IdleAnimConfigScript = null,
	loco_cfg: LocomotionAnimConfigScript = null,
	loco_weights: Dictionary = {},
	turn_cfg: TurnAnimConfigScript = null,
	turn_state: Dictionary = {},
	jiggle_cfg: JigglePhysicsConfigScript = null,
	kiting_cfg: KitingAnimConfigScript = null,
	kiting_weights: Dictionary = {}
) -> void:
	if rig == null:
		return
	var views: Dictionary = rig.get_views()
	for v_key: String in views.keys():
		apply_pose_to_rig_view(rig, v_key, pose_cfg, layer_mode, pose_scale, micro_hover_enabled, anim_time, idle_cfg, loco_cfg, loco_weights, turn_cfg, turn_state, jiggle_cfg, kiting_cfg, kiting_weights)


func apply_pose_to_rig_view(
	rig: PlanarCombatRig,
	view_key: String,
	pose_cfg: BasePoseConfigScript,
	layer_mode: int,
	pose_scale: float = 1.0,
	micro_hover_enabled: bool = false,
	anim_time: float = 0.0,
	idle_cfg: IdleAnimConfigScript = null,
	loco_cfg: LocomotionAnimConfigScript = null,
	loco_weights: Dictionary = {},
	turn_cfg: TurnAnimConfigScript = null,
	turn_state: Dictionary = {},
	jiggle_cfg: JigglePhysicsConfigScript = null,
	kiting_cfg: KitingAnimConfigScript = null,
	kiting_weights: Dictionary = {}
) -> void:
	if rig == null:
		return
	var views: Dictionary = rig.get_views()
	if not views.has(view_key):
		return
	ensure_assets_loaded()

	var vd: Dictionary = views[view_key] as Dictionary
	var bones: Dictionary = vd.get("bones", {}) as Dictionary
	var rest_rots: Dictionary = vd.get("rest_rots", {}) as Dictionary
	var rest_pos: Dictionary = vd.get("rest_pos", {}) as Dictionary
	var polys: Dictionary = vd.get("polys", {}) as Dictionary

	var use_bones: bool = layer_mode == PoseLayerMode.COMBINED_BONES_AND_25D or layer_mode == PoseLayerMode.BONES_ONLY
	var use_25d: bool = layer_mode == PoseLayerMode.COMBINED_BONES_AND_25D or layer_mode == PoseLayerMode.SHADER_25D_ONLY
	var not_rest: bool = layer_mode != PoseLayerMode.DEFAULT_RIG_REST
	var idle_active: bool = micro_hover_enabled and not_rest
	var loco_active: bool = not_rest and loco_cfg != null and not loco_weights.is_empty()
	var kiting_active: bool = not_rest and kiting_cfg != null and not kiting_weights.is_empty()
	var turn_active: bool = not_rest and turn_cfg != null and (bool(turn_state.get("body_active", false)) or bool(turn_state.get("head_active", false)))
	var jiggle_active: bool = not_rest and jiggle_cfg != null

	var fam: String = BasePoseConfigScript.canonical_family_for_view(view_key)
	var fam_dict: Dictionary = pose_cfg.get_family_dict(fam) if pose_cfg != null else {}
	var is_mirrored_left: bool = view_key in ["sw", "w", "nw"]
	var mirror_sign: float = -1.0 if is_mirrored_left else 1.0
	var sides: Dictionary = _resolve_lead_trail_sides(view_key)
	var lead_sfx: String = str(sides["lead"])
	var trail_sfx: String = str(sides["trail"])

	var motion: Dictionary = _compute_idle_motion(
		view_key,
		fam,
		mirror_sign,
		pose_scale,
		idle_active,
		anim_time,
		idle_cfg,
		loco_cfg if loco_active else null,
		loco_weights if loco_active else {},
		kiting_weights if kiting_active else {}
	)
	if loco_active:
		_merge_locomotion_into_motion(
			motion,
			fam,
			mirror_sign,
			pose_scale,
			idle_cfg,
			loco_cfg,
			loco_weights,
			kiting_active
		)
	if kiting_active:
		KitingEvaluatorScript.merge_kiting_into_motion(
			motion,
			view_key,
			fam,
			mirror_sign,
			pose_scale,
			idle_cfg,
			kiting_cfg,
			kiting_weights,
			anim_time
		)
	if turn_active:
		_merge_turn_into_motion(
			motion,
			fam,
			pose_scale,
			idle_cfg,
			turn_cfg,
			turn_state
		)
	if jiggle_active:
		_merge_jiggle_physics_into_motion(
			motion,
			view_key,
			fam,
			mirror_sign,
			pose_scale,
			idle_active,
			anim_time,
			idle_cfg,
			jiggle_cfg
		)

	_apply_bones_layer(
		bones,
		rest_rots,
		rest_pos,
		fam_dict,
		lead_sfx,
		trail_sfx,
		mirror_sign,
		use_bones,
		pose_scale,
		motion
	)

	if view_key == rig.get_active_view_key():
		rig.sync_head_to_active_neck(
			(motion.get("head_offset", Vector2.ZERO) as Vector2) if use_bones else Vector2.ZERO,
			float(motion.get("head_rot", 0.0)) if use_bones else 0.0
		)

	_apply_shader_25d_layer(
		view_key,
		bones,
		rest_pos,
		polys,
		fam_dict,
		lead_sfx,
		trail_sfx,
		mirror_sign,
		use_25d,
		pose_scale,
		motion
	)

	_apply_secondary_jiggle_layer(rig, view_key, vd, motion)


func _resolve_lead_trail_sides(view_key: String) -> Dictionary:
	if view_key == "s" or view_key == "n":
		return {"lead": "R", "trail": "L"}
	if view_key in ["sw", "w", "nw"]:
		return {"lead": "R", "trail": "L"}
	return {"lead": "L", "trail": "R"}


func _resolve_cadence_times(anim_time: float, cadence_mode: int) -> Vector2:
	match cadence_mode:
		IdleAnimConfigScript.CadenceMode.HYBRID_FLOAT60_POSE15:
			return Vector2(anim_time, floorf(anim_time * 15.0) / 15.0)
		IdleAnimConfigScript.CadenceMode.STEPPED_24:
			var q24: float = floorf(anim_time * 24.0) / 24.0
			return Vector2(q24, q24)
		IdleAnimConfigScript.CadenceMode.STEPPED_15:
			var q15: float = floorf(anim_time * 15.0) / 15.0
			return Vector2(q15, q15)
		_:
			return Vector2(anim_time, anim_time)


func _compute_idle_motion(
	view_key: String,
	fam: String,
	mirror_sign: float,
	pose_scale: float,
	idle_active: bool,
	anim_time: float,
	idle_cfg: IdleAnimConfigScript,
	loco_cfg: LocomotionAnimConfigScript = null,
	loco_weights: Dictionary = {},
	kiting_weights: Dictionary = {}
) -> Dictionary:
	var out: Dictionary = {
		"skel_active": false,
		"persp_active": false,
		"sec_active": false,
		"pelvis_offset": Vector2.ZERO,
		"pelvis_rot": 0.0,
		"waist_rot": 0.0,
		"chest_rot": 0.0,
		"neck_rot": 0.0,
		"head_offset": Vector2.ZERO,
		"head_rot": 0.0,
		"arm_lead": {"sh": 0.0, "el": 0.0, "wr": 0.0, "phi1": 0.0, "phi2": 0.0},
		"arm_trail": {"sh": 0.0, "el": 0.0, "wr": 0.0, "phi1": 0.0, "phi2": 0.0},
		"leg_lead": {"th": 0.0, "kn": 0.0, "an": 0.0, "phi_t": 0.0, "phi_s": 0.0, "dist": 0.0, "depth": 0.0},
		"leg_trail": {"th": 0.0, "kn": 0.0, "an": 0.0, "phi_t": 0.0, "phi_s": 0.0, "dist": 0.0, "depth": 0.0},
		"torso_trap": 0.0,
		"torso_yaw": 0.0,
		"torso_jiggle_l": Vector2.ZERO,
		"torso_jiggle_r": Vector2.ZERO,
		"_idle_torso_jiggle_l": Vector2.ZERO,
		"_idle_torso_jiggle_r": Vector2.ZERO,
		"sec_normal_strength": 0.0,
		"hair_jiggle_l": Vector2.ZERO,
		"hair_jiggle_r": Vector2.ZERO,
	}
	if not idle_active:
		return out

	var cfg: IdleAnimConfigScript = idle_cfg if idle_cfg != null else _default_idle_cfg
	cfg.ensure_initialized()

	var loco_blend: float = 0.0
	var float_atten: float = 1.0
	var wake_freq: float = 1.0
	var wake_amp: float = 1.0
	var kite_blend: float = float(kiting_weights.get("kiting_total", 0.0)) if not kiting_weights.is_empty() else 0.0
	if (loco_cfg != null and not loco_weights.is_empty()) or kite_blend > 0.001:
		var loco_sum: float = float(loco_weights.get("fwd", 0.0)) + float(loco_weights.get("brk", 0.0)) + float(loco_weights.get("rev", 0.0))
		loco_blend = clampf(loco_sum + kite_blend, 0.0, 1.0)
		var atten_cfg: float = loco_cfg.flight_idle_float_atten if loco_cfg != null else 0.35
		var wf_cfg: float = loco_cfg.flight_wake_freq_mul if loco_cfg != null else 1.35
		var wa_cfg: float = loco_cfg.flight_wake_amp_mul if loco_cfg != null else 1.15
		float_atten = lerpf(1.0, atten_cfg, loco_blend)
		wake_freq = wf_cfg
		wake_amp = lerpf(1.0, wa_cfg, loco_blend)
	var fwd_w: float = float(loco_weights.get("fwd", 0.0)) if (loco_cfg != null and not loco_weights.is_empty()) else 0.0
	var leg_sync: float = clampf(fwd_w * (loco_cfg.fwd_leg_sync_blend if loco_cfg != null else 0.85), 0.0, 1.0)
	var leg_fwd_damp: float = lerpf(1.0, 0.25, leg_sync)

	var times: Vector2 = _resolve_cadence_times(anim_time, cfg.cadence_mode)
	var t_float: float = times.x
	var t_pose: float = times.y
	var w: float = cfg.cycle_speed_rad
	var ph_float: float = t_float * w
	var ph_pose: float = t_pose * w
	var ph_wake: float = ph_pose * wake_freq
	var asym: float = cfg.harmonic_asymmetry

	var m_int: float = cfg.master_intensity * pose_scale
	var m_float: float = m_int * cfg.get_family_mul(fam, "float_scale") * float_atten
	var m_arms: float = m_int * cfg.get_family_mul(fam, "arms_scale")
	var m_legs: float = m_int * cfg.get_family_mul(fam, "legs_scale")
	var m_25d: float = m_int * cfg.get_family_mul(fam, "persp_25d_scale") * float_atten
	var m_sec: float = m_int * cfg.get_family_mul(fam, "secondary_scale") * wake_amp
	var back_sign: float = -1.0 if view_key == "n" else 1.0
	var z_sign: float = -1.0 if view_key in ["n", "ne", "nw"] else 1.0

	if cfg.enable_skeleton_layer:
		out["skel_active"] = true
		var float_y: float = sample_harmonic_wave(ph_float, asym) * cfg.float_amp_y_px * m_float
		var float_x: float = sin(ph_float * 0.5) * cfg.float_fig8_x_px * mirror_sign * m_float
		out["pelvis_offset"] = Vector2(float_x, float_y)
		out["pelvis_rot"] = sin(ph_pose * 0.5 - 0.25) * cfg.pelvis_sway_rot * mirror_sign * m_float
		out["waist_rot"] = sin(ph_pose * 0.5 - 0.10) * cfg.waist_sway_rot * mirror_sign * m_float
		var chest_w: float = sample_harmonic_wave(ph_pose - 0.20, asym)
		out["chest_rot"] = chest_w * cfg.chest_breath_rot * m_float
		out["neck_rot"] = -chest_w * cfg.neck_counter_rot * m_float

		var head_breath: float = sample_harmonic_wave(ph_float - cfg.head_phase_lag, asym)
		var head_sway: float = sin((ph_float - cfg.head_phase_lag) * 0.5)
		out["head_offset"] = Vector2(-head_sway * 0.35 * mirror_sign, -head_breath * cfg.head_gyro_lag_px) * m_float
		out["head_rot"] = head_sway * cfg.head_gyro_rot_rad * mirror_sign * m_float

		for role_pair: Array in [["arm_lead", 1.0, 0.0], ["arm_trail", -1.0, cfg.arm_lr_phase_offset]]:
			var rk: String = str(role_pair[0])
			var s_sign: float = float(role_pair[1]) * mirror_sign * back_sign
			var ph_off: float = float(role_pair[2])
			var d_arm: Dictionary = out[rk] as Dictionary
			d_arm["sh"] = sample_harmonic_wave(ph_pose - 0.25 + ph_off, asym) * cfg.shoulder_wave_rot * s_sign * m_arms * float_atten
			d_arm["el"] = sample_harmonic_wave(ph_pose - 0.25 - cfg.arm_chain_phase_lag + ph_off, asym) * cfg.elbow_wave_rot * s_sign * m_arms * float_atten
			var wr_base: float = sample_harmonic_wave(ph_pose - 0.25 - cfg.arm_chain_phase_lag * 2.0 + ph_off, asym)
			var wr_wake: float = sample_harmonic_wave(ph_wake - 0.25 - cfg.arm_chain_phase_lag * 2.0 + ph_off, asym)
			d_arm["wr"] = lerpf(wr_base, wr_wake, loco_blend) * cfg.wrist_wave_rot * s_sign * m_arms * wake_amp

		for leg_pair: Array in [["leg_lead", 1.0, 0.0], ["leg_trail", -1.0, cfg.leg_scissor_phase_offset]]:
			var lk: String = str(leg_pair[0])
			var ls_sign: float = float(leg_pair[1]) * mirror_sign * back_sign
			var l_ph: float = float(leg_pair[2])
			var d_leg: Dictionary = out[lk] as Dictionary
			d_leg["th"] = sample_harmonic_wave(ph_pose - 0.15 + l_ph, asym) * cfg.thigh_wave_rot * ls_sign * m_legs * float_atten * leg_fwd_damp
			d_leg["kn"] = -sample_harmonic_wave(ph_pose - 0.15 - cfg.leg_chain_phase_lag + l_ph, asym) * cfg.knee_wave_rot * ls_sign * m_legs * float_atten * leg_fwd_damp
			var an_base: float = sample_harmonic_wave(ph_pose - 0.15 - cfg.leg_chain_phase_lag * 2.0 + l_ph, asym)
			var an_wake: float = sample_harmonic_wave(ph_wake - 0.15 - cfg.leg_chain_phase_lag * 2.0 + l_ph, asym)
			d_leg["an"] = lerpf(an_base, an_wake, loco_blend) * cfg.ankle_wave_rot * ls_sign * m_legs * wake_amp
		if leg_sync > 0.001:
			var d_lead_sync: Dictionary = out["leg_lead"] as Dictionary
			var d_trail_sync: Dictionary = out["leg_trail"] as Dictionary
			d_trail_sync["th"] = lerpf(float(d_trail_sync["th"]), float(d_lead_sync["th"]), leg_sync)
			d_trail_sync["kn"] = lerpf(float(d_trail_sync["kn"]), float(d_lead_sync["kn"]), leg_sync)
			d_trail_sync["an"] = lerpf(float(d_trail_sync["an"]), float(d_lead_sync["an"]), leg_sync)

	if cfg.enable_25d_layer:
		out["persp_active"] = true
		out["torso_trap"] = sample_harmonic_wave(ph_pose - 0.15, asym) * cfg.torso_trap_breath * m_25d
		out["torso_yaw"] = sin(ph_pose * 0.5) * cfg.torso_yaw_sway * mirror_sign * m_25d

		for role_pair: Array in [["arm_lead", 0.0], ["arm_trail", cfg.arm_lr_phase_offset]]:
			var rk: String = str(role_pair[0])
			var ph_off: float = float(role_pair[1])
			var d_arm: Dictionary = out[rk] as Dictionary
			d_arm["phi1"] = sample_harmonic_wave(ph_pose - 0.25 + ph_off, asym) * cfg.arm_phi1_wave * z_sign * m_25d
			d_arm["phi2"] = -sample_harmonic_wave(ph_pose - 0.25 - cfg.arm_chain_phase_lag + ph_off, asym) * cfg.arm_phi2_wave * z_sign * m_25d

		for leg_pair: Array in [["leg_lead", 0.0], ["leg_trail", cfg.leg_scissor_phase_offset]]:
			var lk: String = str(leg_pair[0])
			var l_ph: float = lerpf(float(leg_pair[1]), 0.0, leg_sync) if lk == "leg_trail" else float(leg_pair[1])
			var d_leg: Dictionary = out[lk] as Dictionary
			var w_th: float = sample_harmonic_wave(ph_pose - 0.15 + l_ph, asym)
			var w_sh: float = sample_harmonic_wave(ph_pose - 0.15 - cfg.leg_chain_phase_lag + l_ph, asym)
			var w_ft: float = sample_harmonic_wave(ph_pose - 0.15 - cfg.leg_chain_phase_lag * 2.0 + l_ph, asym)
			d_leg["phi_t"] = w_th * cfg.leg_phi_thigh_wave * z_sign * m_25d
			d_leg["phi_s"] = -w_sh * cfg.leg_phi_shin_wave * z_sign * m_25d
			d_leg["dist"] = w_ft * cfg.leg_distal_wave * z_sign * m_25d
			d_leg["depth"] = w_th * cfg.leg_depth_phase_wave * z_sign * m_25d

	if cfg.enable_secondary_layer:
		out["sec_active"] = true
		var sec_t_l: float = lerpf(sample_harmonic_wave(ph_pose - cfg.torso_secondary_phase_lag, asym), sample_harmonic_wave(ph_wake - cfg.torso_secondary_phase_lag, asym), loco_blend)
		var sec_t_r: float = lerpf(sample_harmonic_wave(ph_pose - cfg.torso_secondary_phase_lag - 0.25, asym), sample_harmonic_wave(ph_wake - cfg.torso_secondary_phase_lag - 0.25, asym), loco_blend)
		var sec_t_x: float = sin(ph_pose * 0.5 - cfg.torso_secondary_phase_lag) * 0.45 * mirror_sign
		out["torso_jiggle_l"] = Vector2(sec_t_x, -sec_t_l) * cfg.torso_secondary_amp_px * m_sec
		out["torso_jiggle_r"] = Vector2(sec_t_x, -sec_t_r) * cfg.torso_secondary_amp_px * m_sec
		out["_idle_torso_jiggle_l"] = out["torso_jiggle_l"]
		out["_idle_torso_jiggle_r"] = out["torso_jiggle_r"]

		var sec_h_l: float = lerpf(sample_harmonic_wave(ph_pose - cfg.hair_phase_lag, asym), sample_harmonic_wave(ph_wake - cfg.hair_phase_lag, asym), loco_blend)
		var sec_h_r: float = lerpf(sample_harmonic_wave(ph_pose - cfg.hair_phase_lag - 0.35, asym), sample_harmonic_wave(ph_wake - cfg.hair_phase_lag - 0.35, asym), loco_blend)
		var sec_h_x: float = sin(ph_pose * 0.5 - cfg.hair_phase_lag) * 0.55 * mirror_sign
		out["hair_jiggle_l"] = Vector2(sec_h_x, -sec_h_l) * cfg.hair_float_amp_px * m_sec
		out["hair_jiggle_r"] = Vector2(-sec_h_x * 0.7, -sec_h_r) * cfg.hair_float_amp_px * m_sec

	return out


func _merge_locomotion_into_motion(
	motion: Dictionary,
	fam: String,
	mirror_sign: float,
	pose_scale: float,
	idle_cfg: IdleAnimConfigScript,
	loco_cfg: LocomotionAnimConfigScript,
	loco_weights: Dictionary,
	suppress_rev: bool = false
) -> void:
	loco_cfg.ensure_initialized()
	var loco_fam: Dictionary = loco_cfg.get_family_dict(fam)
	if loco_fam.is_empty():
		return

	var base_scale: float = loco_cfg.master_intensity * pose_scale
	var w_fwd: float = float(loco_weights.get("fwd", 0.0)) * base_scale
	var w_brk: float = float(loco_weights.get("brk", 0.0)) * base_scale
	var w_rev: float = 0.0 if suppress_rev else float(loco_weights.get("rev", 0.0)) * base_scale
	if w_fwd + w_brk + w_rev <= 0.0001:
		return

	var allow_skel: bool = idle_cfg == null or idle_cfg.enable_skeleton_layer
	var allow_25d: bool = idle_cfg == null or idle_cfg.enable_25d_layer
	var allow_sec: bool = idle_cfg == null or idle_cfg.enable_secondary_layer
	var is_front_back: bool = (fam == "s" or fam == "n")

	if allow_skel:
		motion["skel_active"] = true
	if allow_25d:
		motion["persp_active"] = true
	if allow_sec:
		motion["sec_active"] = true

	for phase_cfg: Array in [["fwd_", w_fwd], ["brk_", w_brk], ["rev_", w_rev]]:
		var pfx: String = str(phase_cfg[0])
		var w: float = float(phase_cfg[1])
		if w <= 0.0001:
			continue

		if allow_skel:
			var p_off := Vector2(float(loco_fam.get(pfx + "pelvis_shift_x", 0.0)) * mirror_sign, float(loco_fam.get(pfx + "pelvis_shift_y", 0.0))) * w
			motion["pelvis_offset"] = (motion["pelvis_offset"] as Vector2) + p_off
			motion["pelvis_rot"] = float(motion["pelvis_rot"]) + float(loco_fam.get(pfx + "pelvis_rot", 0.0)) * mirror_sign * w
			motion["waist_rot"] = float(motion["waist_rot"]) + float(loco_fam.get(pfx + "waist_rot", 0.0)) * mirror_sign * w
			motion["chest_rot"] = float(motion["chest_rot"]) + float(loco_fam.get(pfx + "chest_rot", 0.0)) * mirror_sign * w
			motion["neck_rot"] = float(motion["neck_rot"]) + float(loco_fam.get(pfx + "neck_rot", 0.0)) * mirror_sign * w

			var h_lag_val: float = float(loco_fam.get(pfx + "head_lag_px", 0.0))
			var h_lag_vec: Vector2 = Vector2(0.0, h_lag_val) if is_front_back else Vector2(h_lag_val * mirror_sign, 0.0)
			motion["head_offset"] = (motion["head_offset"] as Vector2) + h_lag_vec * w
			motion["head_rot"] = float(motion["head_rot"]) + float(loco_fam.get(pfx + "head_rot", 0.0)) * mirror_sign * w

			for role: String in ["lead", "trail"]:
				var d_arm: Dictionary = motion["arm_" + role] as Dictionary
				d_arm["sh"] = float(d_arm["sh"]) + float(loco_fam.get("%sshoulder_%s_rot" % [pfx, role], 0.0)) * mirror_sign * w
				d_arm["el"] = float(d_arm["el"]) + float(loco_fam.get("%selbow_%s_rot" % [pfx, role], 0.0)) * mirror_sign * w
				d_arm["wr"] = float(d_arm["wr"]) + float(loco_fam.get("%swrist_%s_rot" % [pfx, role], 0.0)) * mirror_sign * w

				var d_leg: Dictionary = motion["leg_" + role] as Dictionary
				d_leg["th"] = float(d_leg["th"]) + float(loco_fam.get("%sthigh_%s_rot" % [pfx, role], 0.0)) * mirror_sign * w
				d_leg["kn"] = float(d_leg["kn"]) + float(loco_fam.get("%sknee_%s_rot" % [pfx, role], 0.0)) * mirror_sign * w
				d_leg["an"] = float(d_leg["an"]) + float(loco_fam.get("%sankle_%s_rot" % [pfx, role], 0.0)) * mirror_sign * w

		if allow_25d:
			motion["torso_trap"] = float(motion["torso_trap"]) + float(loco_fam.get(pfx + "torso_trap", 0.0)) * w
			motion["torso_yaw"] = float(motion["torso_yaw"]) + float(loco_fam.get(pfx + "torso_yaw", 0.0)) * mirror_sign * w
			var d_lead: Dictionary = motion["leg_lead"] as Dictionary
			var d_trail: Dictionary = motion["leg_trail"] as Dictionary
			d_lead["phi_s"] = float(d_lead["phi_s"]) + float(loco_fam.get(pfx + "leg_lead_phi_shin", 0.0)) * w
			d_trail["phi_s"] = float(d_trail["phi_s"]) + float(loco_fam.get(pfx + "leg_trail_phi_shin", 0.0)) * w
			d_trail["dist"] = float(d_trail["dist"]) + float(loco_fam.get(pfx + "leg_trail_distal_amp", 0.0)) * w

		if allow_sec:
			var h_dx: float = float(loco_fam.get(pfx + "hair_drag_x_px", 0.0)) * mirror_sign
			var h_dy: float = float(loco_fam.get(pfx + "hair_drag_y_px", 0.0))
			var h_drag := Vector2(h_dx, h_dy) * w
			motion["hair_jiggle_l"] = (motion["hair_jiggle_l"] as Vector2) + h_drag
			motion["hair_jiggle_r"] = (motion["hair_jiggle_r"] as Vector2) + h_drag

			var t_drag := Vector2(h_dx * 0.25, float(loco_fam.get(pfx + "torso_sec_drag_y_px", 0.0))) * w
			motion["torso_jiggle_l"] = (motion["torso_jiggle_l"] as Vector2) + t_drag
			motion["torso_jiggle_r"] = (motion["torso_jiggle_r"] as Vector2) + t_drag


func _merge_turn_into_motion(
	motion: Dictionary,
	fam: String,
	pose_scale: float,
	idle_cfg: IdleAnimConfigScript,
	turn_cfg: TurnAnimConfigScript,
	turn_state: Dictionary
) -> void:
	if turn_cfg == null or turn_state.is_empty():
		return
	var allow_skel: bool = idle_cfg == null or idle_cfg.enable_skeleton_layer
	var allow_25d: bool = idle_cfg == null or idle_cfg.enable_25d_layer
	var allow_sec: bool = idle_cfg == null or idle_cfg.enable_secondary_layer
	if allow_skel:
		motion["skel_active"] = true
	if allow_25d:
		motion["persp_active"] = true
	if allow_sec:
		motion["sec_active"] = true

	var m_turn: float = turn_cfg.master_intensity * pose_scale * turn_cfg.get_family_mul(fam, "turn_scale")
	if m_turn <= 0.0001:
		return

	if bool(turn_state.get("body_active", false)):
		_apply_body_turn_motion(motion, turn_cfg, turn_state, m_turn, allow_skel, allow_25d, allow_sec)
	if bool(turn_state.get("head_active", false)):
		_apply_head_turn_motion(motion, turn_cfg, turn_state, m_turn, allow_skel, allow_sec)


func _apply_body_turn_motion(
	motion: Dictionary,
	turn_cfg: TurnAnimConfigScript,
	turn_state: Dictionary,
	m_turn: float,
	allow_skel: bool,
	allow_25d: bool,
	allow_sec: bool
) -> void:
	var u: float = clampf(float(turn_state.get("body_t", 1.0)), 0.0, 1.0)
	var swap_pt: float = clampf(float(turn_state.get("body_swap_pt", turn_cfg.body_swap_point)), 0.15, 0.65)
	var t_dir: float = float(turn_state.get("body_turn_dir", 1.0))
	var t_mag: float = clampf(float(turn_state.get("body_turn_mag", 1.0)), 0.8, 1.5) * m_turn

	if u < swap_pt:
		var p_pre: float = clampf(u / maxf(swap_pt, 0.05), 0.0, 1.0)
		var w_pre: float = p_pre * p_pre
		if allow_25d:
			motion["torso_yaw"] = float(motion["torso_yaw"]) + t_dir * turn_cfg.pre_yaw_25d * w_pre * t_mag
			motion["torso_trap"] = float(motion["torso_trap"]) - turn_cfg.turn_torso_trap_pulse * w_pre * t_mag
		if allow_skel:
			motion["head_rot"] = float(motion["head_rot"]) + t_dir * turn_cfg.head_lead_rot * p_pre * t_mag
			motion["neck_rot"] = float(motion["neck_rot"]) + t_dir * turn_cfg.head_lead_rot * 0.6 * p_pre * t_mag
			motion["pelvis_offset"] = (motion["pelvis_offset"] as Vector2) + Vector2(t_dir * turn_cfg.pelvis_whip_shift_x_px * 0.35 * w_pre, turn_cfg.pelvis_bob_y_px * w_pre) * t_mag
			var pre_spine: float = t_dir * turn_cfg.spine_overshoot_rot * 0.45 * w_pre * t_mag
			motion["pelvis_rot"] = float(motion["pelvis_rot"]) + pre_spine * 0.7
			motion["waist_rot"] = float(motion["waist_rot"]) + pre_spine * 0.9
			motion["chest_rot"] = float(motion["chest_rot"]) + pre_spine
			for role: String in ["lead", "trail"]:
				var d_arm: Dictionary = motion["arm_" + role] as Dictionary
				d_arm["sh"] = float(d_arm["sh"]) - t_dir * turn_cfg.arm_whip_rot * 0.35 * w_pre * t_mag
				d_arm["el"] = float(d_arm["el"]) - t_dir * turn_cfg.arm_whip_rot * 0.35 * w_pre * t_mag
				d_arm["wr"] = float(d_arm["wr"]) - t_dir * turn_cfg.arm_whip_rot * 0.45 * w_pre * t_mag
				var d_leg: Dictionary = motion["leg_" + role] as Dictionary
				d_leg["th"] = float(d_leg["th"]) - t_dir * turn_cfg.leg_whip_rot * 0.35 * w_pre * t_mag
				d_leg["an"] = float(d_leg["an"]) - t_dir * turn_cfg.leg_whip_rot * 0.35 * w_pre * t_mag
		if allow_sec:
			var h_pre := Vector2(-t_dir * turn_cfg.body_turn_hair_whip_px * 0.55 * w_pre, 0.35 * w_pre) * t_mag
			motion["hair_jiggle_l"] = (motion["hair_jiggle_l"] as Vector2) + h_pre
			motion["hair_jiggle_r"] = (motion["hair_jiggle_r"] as Vector2) + h_pre
		return

	var p_post: float = clampf((u - swap_pt) / maxf(1.0 - swap_pt, 0.05), 0.0, 1.0)
	var env_post: float = pow(1.0 - p_post, 1.25)
	var catchup_wave: float = -cos(p_post * PI * 1.35) * pow(1.0 - p_post, 1.40)
	var core_whip: float = sin(p_post * PI * 1.25) * env_post
	var lag: float = clampf(turn_cfg.limb_lag_phase, 0.05, 0.60)
	var p_limb: float = clampf((p_post - lag * 0.45) / maxf(1.0 - lag * 0.45, 0.1), 0.0, 1.0)
	var limb_whip: float = -cos(p_limb * PI * 1.45) * pow(1.0 - p_post, 1.15)

	if allow_25d:
		motion["torso_yaw"] = float(motion["torso_yaw"]) + t_dir * turn_cfg.post_catchup_yaw_25d * catchup_wave * t_mag
		motion["torso_trap"] = float(motion["torso_trap"]) + turn_cfg.turn_torso_trap_pulse * sin(p_post * PI) * env_post * t_mag
		var d_lead_leg: Dictionary = motion["leg_lead"] as Dictionary
		var d_trail_leg: Dictionary = motion["leg_trail"] as Dictionary
		d_lead_leg["phi_s"] = float(d_lead_leg["phi_s"]) + turn_cfg.leg_shin_phi_pulse * limb_whip * t_mag
		d_trail_leg["phi_s"] = float(d_trail_leg["phi_s"]) - turn_cfg.leg_shin_phi_pulse * 0.8 * limb_whip * t_mag

	if allow_skel:
		motion["pelvis_offset"] = (motion["pelvis_offset"] as Vector2) + Vector2(t_dir * turn_cfg.pelvis_whip_shift_x_px * core_whip, turn_cfg.pelvis_bob_y_px * cos(p_post * PI * 1.5) * env_post) * t_mag
		var post_spine: float = t_dir * turn_cfg.spine_overshoot_rot * core_whip * t_mag
		motion["pelvis_rot"] = float(motion["pelvis_rot"]) + post_spine * 0.7
		motion["waist_rot"] = float(motion["waist_rot"]) + post_spine * 0.9
		motion["chest_rot"] = float(motion["chest_rot"]) + post_spine
		motion["neck_rot"] = float(motion["neck_rot"]) - post_spine * 0.45
		for role: String in ["lead", "trail"]:
			var d_arm: Dictionary = motion["arm_" + role] as Dictionary
			d_arm["sh"] = float(d_arm["sh"]) + t_dir * turn_cfg.arm_whip_rot * limb_whip * t_mag
			d_arm["el"] = float(d_arm["el"]) + t_dir * turn_cfg.arm_whip_rot * 1.15 * limb_whip * t_mag
			d_arm["wr"] = float(d_arm["wr"]) + t_dir * turn_cfg.arm_whip_rot * 1.30 * limb_whip * t_mag
			var d_leg: Dictionary = motion["leg_" + role] as Dictionary
			d_leg["th"] = float(d_leg["th"]) + t_dir * turn_cfg.leg_whip_rot * limb_whip * t_mag
			d_leg["kn"] = float(d_leg["kn"]) - t_dir * turn_cfg.leg_whip_rot * 0.85 * limb_whip * t_mag
			d_leg["an"] = float(d_leg["an"]) + t_dir * turn_cfg.leg_whip_rot * 1.10 * limb_whip * t_mag

	if allow_sec:
		var hair_vec := Vector2(t_dir * turn_cfg.body_turn_hair_whip_px * limb_whip, -absf(limb_whip) * 0.65) * t_mag
		motion["hair_jiggle_l"] = (motion["hair_jiggle_l"] as Vector2) + hair_vec
		motion["hair_jiggle_r"] = (motion["hair_jiggle_r"] as Vector2) + hair_vec
		var chest_vec := Vector2(t_dir * turn_cfg.body_turn_chest_jiggle_px * limb_whip, core_whip * 0.5) * t_mag
		motion["torso_jiggle_l"] = (motion["torso_jiggle_l"] as Vector2) + chest_vec
		motion["torso_jiggle_r"] = (motion["torso_jiggle_r"] as Vector2) + chest_vec


func _apply_head_turn_motion(
	motion: Dictionary,
	turn_cfg: TurnAnimConfigScript,
	turn_state: Dictionary,
	m_turn: float,
	allow_skel: bool,
	allow_sec: bool
) -> void:
	var uh: float = clampf(float(turn_state.get("head_t", 1.0)), 0.0, 1.0)
	var h_dir: float = float(turn_state.get("head_turn_dir", 1.0))
	var h_whip: float = sin(uh * PI * 1.40) * pow(1.0 - uh, 1.15) * m_turn
	var h_hair_wave: float = -cos(uh * PI * 1.55) * pow(1.0 - uh, 1.10) * m_turn

	if allow_skel:
		motion["head_rot"] = float(motion["head_rot"]) + h_dir * turn_cfg.head_whip_overshoot_rot * h_whip
		motion["head_offset"] = (motion["head_offset"] as Vector2) + Vector2(h_dir * turn_cfg.head_whip_offset_x_px * h_whip, -absf(h_whip) * 0.35)
		motion["neck_rot"] = float(motion["neck_rot"]) + h_dir * turn_cfg.head_neck_kick_rot * h_whip
		var symp: float = h_dir * turn_cfg.head_sympathetic_chest_rot * h_whip
		motion["chest_rot"] = float(motion["chest_rot"]) + symp
		(motion["arm_lead"] as Dictionary)["sh"] = float((motion["arm_lead"] as Dictionary)["sh"]) + symp * 0.65
		(motion["arm_trail"] as Dictionary)["sh"] = float((motion["arm_trail"] as Dictionary)["sh"]) + symp * 0.65

	if allow_sec:
		var h_whip_vec := Vector2(h_dir * turn_cfg.head_whip_hair_px * h_hair_wave, -absf(h_hair_wave) * 0.45)
		motion["hair_jiggle_l"] = (motion["hair_jiggle_l"] as Vector2) + h_whip_vec
		motion["hair_jiggle_r"] = (motion["hair_jiggle_r"] as Vector2) + h_whip_vec


func _merge_jiggle_physics_into_motion(
	motion: Dictionary,
	view_key: String,
	fam: String,
	mirror_sign: float,
	pose_scale: float,
	idle_active: bool,
	anim_time: float,
	idle_cfg: IdleAnimConfigScript,
	jiggle_cfg: JigglePhysicsConfigScript
) -> void:
	if jiggle_cfg == null:
		return
	var allow_sec: bool = idle_cfg == null or idle_cfg.enable_secondary_layer
	if not allow_sec:
		return

	var eff_idle_cfg: IdleAnimConfigScript = idle_cfg if idle_cfg != null else _default_idle_cfg
	var m_int: float = jiggle_cfg.master_intensity * pose_scale
	var m_bust: float = m_int * jiggle_cfg.get_family_mul(fam, "bust_scale")
	var m_glute: float = m_int * jiggle_cfg.get_family_mul(fam, "glute_scale")

	var ext_drag_l: Vector2 = (motion.get("torso_jiggle_l", Vector2.ZERO) as Vector2) - (motion.get("_idle_torso_jiggle_l", Vector2.ZERO) as Vector2)
	var ext_drag_r: Vector2 = (motion.get("torso_jiggle_r", Vector2.ZERO) as Vector2) - (motion.get("_idle_torso_jiggle_r", Vector2.ZERO) as Vector2)

	var b_wave_l := Vector2.ZERO
	var b_wave_r := Vector2.ZERO
	var g_wave_l := Vector2.ZERO
	var g_wave_r := Vector2.ZERO
	if idle_active and m_int > 0.0001:
		var ph: float = anim_time * eff_idle_cfg.cycle_speed_rad
		var asym: float = eff_idle_cfg.harmonic_asymmetry
		var b_amp: float = jiggle_cfg.bust_idle_amp_px
		var b_stag: float = 0.28 * jiggle_cfg.bust_lr_asymmetry
		b_wave_l = Vector2(sin(ph * 0.5 - 0.50) * 0.35 * mirror_sign, -sample_harmonic_wave(ph - 0.55, asym)) * b_amp
		b_wave_r = Vector2(sin(ph * 0.5 - 0.50 - b_stag) * 0.35 * mirror_sign, -sample_harmonic_wave(ph - 0.55 - b_stag, asym)) * b_amp

		var g_amp: float = jiggle_cfg.glute_idle_amp_px
		var g_stag: float = 0.32 * jiggle_cfg.glute_lr_asymmetry
		g_wave_l = Vector2(sin(ph * 0.5 - 0.35) * 0.25 * mirror_sign, -sample_harmonic_wave(ph - 0.40, asym)) * g_amp
		g_wave_r = Vector2(sin(ph * 0.5 - 0.35 - g_stag) * 0.25 * mirror_sign, -sample_harmonic_wave(ph - 0.40 - g_stag, asym)) * g_amp

	var d_leg_lead: Dictionary = motion.get("leg_lead", {}) as Dictionary
	var d_leg_trail: Dictionary = motion.get("leg_trail", {}) as Dictionary
	var th_l: float = float(d_leg_lead.get("th", 0.0))
	var th_t: float = float(d_leg_trail.get("th", 0.0))
	var g_coup: float = jiggle_cfg.glute_thigh_coupling * 9.5
	var g_thigh_l := Vector2(-th_l * 0.45 * mirror_sign, th_l) * g_coup
	var g_thigh_r := Vector2(-th_t * 0.45 * mirror_sign, th_t) * g_coup

	var tot_bust_l: Vector2 = soft_clamp_vec2((b_wave_l + _bust_pos_l + ext_drag_l * 0.55) * m_bust, jiggle_cfg.bust_max_clamp_px) if jiggle_cfg.enable_bust_jiggle else Vector2.ZERO
	var tot_bust_r: Vector2 = soft_clamp_vec2((b_wave_r + _bust_pos_r + ext_drag_r * 0.55) * m_bust, jiggle_cfg.bust_max_clamp_px) if jiggle_cfg.enable_bust_jiggle else Vector2.ZERO
	var tot_glute_l: Vector2 = soft_clamp_vec2((g_wave_l + _glute_pos_l + g_thigh_l + ext_drag_l * 0.35) * m_glute, jiggle_cfg.glute_max_clamp_px) if jiggle_cfg.enable_glute_jiggle else Vector2.ZERO
	var tot_glute_r: Vector2 = soft_clamp_vec2((g_wave_r + _glute_pos_r + g_thigh_r + ext_drag_r * 0.35) * m_glute, jiggle_cfg.glute_max_clamp_px) if jiggle_cfg.enable_glute_jiggle else Vector2.ZERO

	var out_l := Vector2.ZERO
	var out_r := Vector2.ZERO
	if view_key in ["s", "se", "sw"]:
		out_l = tot_bust_l
		out_r = tot_bust_r
	elif view_key in ["n", "ne", "nw"]:
		out_l = tot_glute_l
		out_r = tot_glute_r
	else:
		out_l = tot_bust_l
		out_r = tot_glute_r

	if out_l.length_squared() > 0.0001 or out_r.length_squared() > 0.0001:
		motion["sec_active"] = true
	motion["torso_jiggle_l"] = out_l
	motion["torso_jiggle_r"] = out_r
	motion["sec_normal_strength"] = jiggle_cfg.normal_light_strength * clampf(jiggle_cfg.master_intensity, 0.0, 2.0)


func _apply_bones_layer(
	bones: Dictionary,
	rest_rots: Dictionary,
	rest_pos: Dictionary,
	fam: Dictionary,
	lead_sfx: String,
	trail_sfx: String,
	mirror_sign: float,
	use_bones: bool,
	pose_scale: float,
	idle_motion: Dictionary
) -> void:
	for b_val: Variant in bones.values():
		var b: Bone2D = b_val as Bone2D
		if b != null:
			b.scale = Vector2.ONE

	if not use_bones or fam.is_empty():
		for b_name: Variant in bones.keys():
			var b_key: String = str(b_name)
			var bone: Bone2D = bones[b_key] as Bone2D
			if bone == null:
				continue
			bone.rotation = float(rest_rots.get(b_key, 0.0))
			if rest_pos.has(b_key):
				bone.position = rest_pos[b_key] as Vector2
		return

	var skel_idle: bool = bool(idle_motion.get("skel_active", false))
	var pelvis_off: Vector2 = idle_motion.get("pelvis_offset", Vector2.ZERO) as Vector2
	if bones.has("Pelvis") and rest_pos.has("Pelvis"):
		(bones["Pelvis"] as Bone2D).position = (rest_pos["Pelvis"] as Vector2) + (pelvis_off if skel_idle else Vector2.ZERO)

	_set_bone_rot(bones, rest_rots, "Pelvis", float(fam.get("pelvis_rot", 0.0)) * mirror_sign * pose_scale + float(idle_motion.get("pelvis_rot", 0.0)))
	_set_bone_rot(bones, rest_rots, "Waist", float(fam.get("waist_rot", 0.0)) * mirror_sign * pose_scale + float(idle_motion.get("waist_rot", 0.0)))
	_set_bone_rot(bones, rest_rots, "Chest", float(fam.get("chest_rot", 0.0)) * mirror_sign * pose_scale + float(idle_motion.get("chest_rot", 0.0)))
	_set_bone_rot(bones, rest_rots, "Neck", float(fam.get("neck_rot", 0.0)) * mirror_sign * pose_scale + float(idle_motion.get("neck_rot", 0.0)))

	var follow_ratio: float = clampf(float(fam.get("pauldron_follow_ratio", 0.48)), 0.0, 1.0)
	var sh_deltas: Dictionary = {}
	for role_cfg: Array in [["lead", lead_sfx], ["trail", trail_sfx]]:
		var role: String = str(role_cfg[0])
		var sfx: String = str(role_cfg[1])
		var d_arm: Dictionary = idle_motion.get("arm_%s" % role, {}) as Dictionary
		var d_leg: Dictionary = idle_motion.get("leg_%s" % role, {}) as Dictionary

		var sh_delta: float = float(fam.get("shoulder_%s_rot" % role, 0.0)) * mirror_sign * pose_scale + float(d_arm.get("sh", 0.0))
		var el_delta: float = float(fam.get("elbow_%s_rot" % role, 0.0)) * mirror_sign * pose_scale + float(d_arm.get("el", 0.0))
		var wr_delta: float = float(fam.get("wrist_%s_rot" % role, 0.0)) * mirror_sign * pose_scale + float(d_arm.get("wr", 0.0))
		sh_deltas[sfx] = sh_delta
		_set_bone_rot(bones, rest_rots, "Shoulder_%s" % sfx, sh_delta)
		_set_bone_rot(bones, rest_rots, "Elbow_%s" % sfx, el_delta)
		_set_bone_rot(bones, rest_rots, "Wrist_%s" % sfx, wr_delta)

		var th_delta: float = float(fam.get("thigh_%s_rot" % role, 0.0)) * mirror_sign * pose_scale + float(d_leg.get("th", 0.0))
		var kn_delta: float = float(fam.get("knee_%s_rot" % role, 0.0)) * mirror_sign * pose_scale + float(d_leg.get("kn", 0.0))
		var an_delta: float = float(fam.get("ankle_%s_rot" % role, 0.0)) * mirror_sign * pose_scale + float(d_leg.get("an", 0.0))
		_set_bone_rot(bones, rest_rots, "Thigh_%s" % sfx, th_delta)
		_set_bone_rot(bones, rest_rots, "Knee_%s" % sfx, kn_delta)
		_set_bone_rot(bones, rest_rots, "Ankle_%s" % sfx, an_delta)

	for sfx: String in ["R", "L"]:
		var p_name: String = "Pauldron_%s" % sfx
		if bones.has(p_name) and rest_pos.has(p_name):
			(bones[p_name] as Bone2D).position = (rest_pos[p_name] as Vector2) + (Vector2(0.0, -pelvis_off.y * 0.2) if skel_idle else Vector2.ZERO)
		_set_bone_rot(bones, rest_rots, p_name, float(sh_deltas.get(sfx, 0.0)) * follow_ratio)


func _set_bone_rot(bones: Dictionary, rest_rots: Dictionary, b_name: String, delta_rot: float) -> void:
	if not bones.has(b_name):
		return
	var bone: Bone2D = bones[b_name] as Bone2D
	if bone != null:
		bone.rotation = float(rest_rots.get(b_name, 0.0)) + delta_rot


func _apply_shader_25d_layer(
	view_key: String,
	bones: Dictionary,
	rest_pos: Dictionary,
	polys: Dictionary,
	fam: Dictionary,
	lead_sfx: String,
	trail_sfx: String,
	mirror_sign: float,
	use_25d: bool,
	pose_scale: float,
	idle_motion: Dictionary
) -> void:
	var bc_poly: Polygon2D = polys.get("body_core", null) as Polygon2D
	var bc_tex: Texture2D = bc_poly.texture if bc_poly != null else null
	var bc_rect: Variant = (bc_poly.material as ShaderMaterial).get_shader_parameter("part_rig_rect") if (bc_poly != null and bc_poly.material is ShaderMaterial) else Vector4(0.0, 0.0, 1.0, 1.0)
	var pelvis_bone: Bone2D = bones.get("Pelvis", null) as Bone2D
	var pelvis_delta: Vector2 = (pelvis_bone.position - (rest_pos.get("Pelvis", Vector2.ZERO) as Vector2)) if pelvis_bone != null else Vector2.ZERO

	var role_by_sfx: Dictionary = {
		lead_sfx: "lead",
		trail_sfx: "trail",
	}
	var cam_tan: float = _persp_cfg.cam_tan_alpha if _persp_cfg != null else 0.1315
	var jac_floor: float = _persp_cfg.jacobian_floor if _persp_cfg != null else 0.22
	var k_con: float = _persp_cfg.k_conicity if _persp_cfg != null else 0.16
	var k_vol: float = _persp_cfg.k_volume if _persp_cfg != null else 0.14
	var ew_front: float = _persp_cfg.ew_front_depth_weight if _persp_cfg != null else 0.65
	var ew_back: float = _persp_cfg.ew_back_depth_weight if _persp_cfg != null else -0.75
	var persp_idle: bool = bool(idle_motion.get("persp_active", false))

	for p_key: String in polys.keys():
		var poly: Polygon2D = polys[p_key] as Polygon2D
		if poly == null or not (poly.material is ShaderMaterial):
			continue
		poly.position = Vector2.ZERO
		var mat: ShaderMaterial = poly.material as ShaderMaterial
		var is_r: bool = p_key.begins_with("leg_r")
		var is_l: bool = p_key.begins_with("leg_l")

		if is_r or is_l:
			var sfx: String = "R" if is_r else "L"
			var role: String = str(role_by_sfx.get(sfx, "lead"))
			_apply_leg_common_overlays(view_key, p_key, poly, mat, bc_tex, bc_rect, pelvis_delta)

			if use_25d and not fam.is_empty():
				var mask_key: String = "%s_%s" % [view_key, "r" if is_r else "l"]
				var z_mask: Texture2D = _zone_masks.get(mask_key, null) as Texture2D
				var b_root: Bone2D = bones.get("Thigh_" + sfx, null) as Bone2D
				var b_mid: Bone2D = bones.get("Knee_" + sfx, null) as Bone2D
				var b_tip: Bone2D = bones.get("Ankle_" + sfx, null) as Bone2D
				if b_root != null and b_mid != null and b_tip != null:
					var p_root: Vector2 = poly.to_local(b_root.global_position)
					var p_mid: Vector2 = poly.to_local(b_mid.global_position)
					var p_tip: Vector2 = poly.to_local(b_tip.global_position)
					var d_leg: Dictionary = (idle_motion.get("leg_%s" % role, {}) as Dictionary) if persp_idle else {}
					var phi_thigh: float = float(fam.get("leg_%s_phi_thigh" % role, 0.0)) * pose_scale + float(d_leg.get("phi_t", 0.0))
					var phi_shin: float = float(fam.get("leg_%s_phi_shin" % role, 0.0)) * pose_scale + float(d_leg.get("phi_s", 0.0))
					var distal_amp: float = float(fam.get("leg_%s_distal_amp" % role, 0.0)) * pose_scale + float(d_leg.get("dist", 0.0))
					var depth_phase: float = float(fam.get("leg_%s_depth_phase" % role, 0.0)) * pose_scale + float(d_leg.get("depth", 0.0))
					var pivot_v: float = float(fam.get("leg_%s_pivot_v" % role, 0.445))
					mat.set_shader_parameter("persp_mode", 1)
					mat.set_shader_parameter("use_persp_zone_mask", z_mask != null)
					if z_mask != null:
						mat.set_shader_parameter("persp_zone_mask", z_mask)
					mat.set_shader_parameter("persp_anchors_root_mid", Vector4(p_root.x, p_root.y, p_mid.x, p_mid.y))
					mat.set_shader_parameter("persp_anchors_tip_piv", Vector4(p_tip.x, p_tip.y, pivot_v, phi_thigh))
					mat.set_shader_parameter("persp_params_a", Vector4(phi_shin, maxf(cam_tan, 0.16), jac_floor, k_con))
					mat.set_shader_parameter("persp_params_b", Vector4(0.02 * (k_vol / 0.14), distal_amp, -0.35, 0.0))
					mat.set_shader_parameter("bone_chain_angles", Vector2.ZERO)
					mat.set_shader_parameter("joint_flexion", 0.0)
					mat.set_shader_parameter("leg_depth_phase", depth_phase)
					continue

			var static_depth: float = 0.0
			if view_key == "e":
				static_depth = ew_front if is_r else ew_back
			elif view_key == "w":
				static_depth = ew_front if is_l else ew_back
			mat.set_shader_parameter("persp_mode", 0)
			mat.set_shader_parameter("use_persp_zone_mask", false)
			mat.set_shader_parameter("bone_chain_angles", Vector2.ZERO)
			mat.set_shader_parameter("joint_flexion", 0.0)
			mat.set_shader_parameter("leg_depth_phase", static_depth)
			continue

		if use_25d and not fam.is_empty() and (p_key == "arm_r" or p_key == "arm_l"):
			var a_sfx: String = "R" if p_key == "arm_r" else "L"
			var a_role: String = str(role_by_sfx.get(a_sfx, "lead"))
			var a_root: Bone2D = bones.get("Shoulder_" + a_sfx, null) as Bone2D
			var a_mid: Bone2D = bones.get("Elbow_" + a_sfx, null) as Bone2D
			var a_tip: Bone2D = bones.get("Wrist_" + a_sfx, null) as Bone2D
			if a_root != null and a_mid != null and a_tip != null:
				var pr_a: Vector2 = poly.to_local(a_root.global_position)
				var pm_a: Vector2 = poly.to_local(a_mid.global_position)
				var pt_a: Vector2 = poly.to_local(a_tip.global_position)
				var d_arm: Dictionary = (idle_motion.get("arm_%s" % a_role, {}) as Dictionary) if persp_idle else {}
				var phi1_a: float = float(fam.get("arm_%s_phi1" % a_role, 0.0)) * pose_scale + float(d_arm.get("phi1", 0.0))
				var phi2_a: float = float(fam.get("arm_%s_phi2" % a_role, 0.0)) * pose_scale + float(d_arm.get("phi2", 0.0))
				mat.set_shader_parameter("persp_mode", 1)
				mat.set_shader_parameter("use_persp_zone_mask", false)
				mat.set_shader_parameter("persp_anchors_root_mid", Vector4(pr_a.x, pr_a.y, pm_a.x, pm_a.y))
				mat.set_shader_parameter("persp_anchors_tip_piv", Vector4(pt_a.x, pt_a.y, 0.48, phi1_a))
				mat.set_shader_parameter("persp_params_a", Vector4(phi2_a, 0.15, jac_floor, 0.10))
				mat.set_shader_parameter("persp_params_b", Vector4(0.02, 0.0, 0.0, 0.0))
				mat.set_shader_parameter("bone_chain_angles", Vector2.ZERO)
				mat.set_shader_parameter("joint_flexion", 0.0)
				mat.set_shader_parameter("leg_depth_phase", 0.0)
				continue

		if use_25d and not fam.is_empty() and p_key == "body_core":
			var b_neck: Bone2D = bones.get("Neck", null) as Bone2D
			var b_pelvis: Bone2D = bones.get("Pelvis", null) as Bone2D
			if b_neck != null and b_pelvis != null:
				var pn: Vector2 = poly.to_local(b_neck.global_position)
				var pp: Vector2 = poly.to_local(b_pelvis.global_position)
				var trap: float = float(fam.get("torso_trap", 0.0)) * pose_scale + (float(idle_motion.get("torso_trap", 0.0)) if persp_idle else 0.0)
				var yaw: float = float(fam.get("torso_yaw", 0.0)) * mirror_sign * pose_scale + (float(idle_motion.get("torso_yaw", 0.0)) if persp_idle else 0.0)
				mat.set_shader_parameter("persp_mode", 2)
				mat.set_shader_parameter("use_persp_zone_mask", false)
				mat.set_shader_parameter("persp_anchors_root_mid", Vector4(pn.x, pn.y, pn.x, pn.y))
				mat.set_shader_parameter("persp_anchors_tip_piv", Vector4(pp.x, pp.y, 0.5, 0.03))
				mat.set_shader_parameter("persp_params_a", Vector4(0.0, 0.15, jac_floor, 0.0))
				mat.set_shader_parameter("persp_params_b", Vector4(0.0, 0.0, 0.0, trap))
				mat.set_shader_parameter("persp_params_c", Vector4(yaw, 0.0, 0.35, 0.0))
				mat.set_shader_parameter("bone_chain_angles", Vector2.ZERO)
				mat.set_shader_parameter("joint_flexion", 0.0)
				mat.set_shader_parameter("leg_depth_phase", 0.0)
				continue

		mat.set_shader_parameter("persp_mode", 0)
		mat.set_shader_parameter("use_persp_zone_mask", false)
		mat.set_shader_parameter("bone_chain_angles", Vector2.ZERO)
		mat.set_shader_parameter("joint_flexion", 0.0)
		mat.set_shader_parameter("leg_depth_phase", 0.0)


func _apply_secondary_jiggle_layer(
	rig: PlanarCombatRig,
	view_key: String,
	vd: Dictionary,
	idle_motion: Dictionary
) -> void:
	var sec_active: bool = bool(idle_motion.get("sec_active", false))
	var sec_norm_str: float = float(idle_motion.get("sec_normal_strength", 0.0)) if sec_active else 0.0
	var core_mat: ShaderMaterial = vd.get("body_core_mat", null) as ShaderMaterial
	if core_mat != null:
		if sec_active:
			core_mat.set_shader_parameter("enable_secondary_jiggle", true)
			core_mat.set_shader_parameter("secondary_jiggle_l_px", idle_motion.get("torso_jiggle_l", Vector2.ZERO) as Vector2)
			core_mat.set_shader_parameter("secondary_jiggle_r_px", idle_motion.get("torso_jiggle_r", Vector2.ZERO) as Vector2)
			core_mat.set_shader_parameter("secondary_jiggle_normal_strength", sec_norm_str)
		else:
			core_mat.set_shader_parameter("secondary_jiggle_l_px", Vector2.ZERO)
			core_mat.set_shader_parameter("secondary_jiggle_r_px", Vector2.ZERO)
			core_mat.set_shader_parameter("secondary_jiggle_normal_strength", 0.0)

	if view_key != rig.get_active_view_key():
		return
	if rig.is_face_live_enabled():
		return
	var h_l: Vector2 = (idle_motion.get("hair_jiggle_l", Vector2.ZERO) as Vector2) if sec_active else Vector2.ZERO
	var h_r: Vector2 = (idle_motion.get("hair_jiggle_r", Vector2.ZERO) as Vector2) if sec_active else Vector2.ZERO
	for h_dict: Dictionary in [rig.get_head_data(), rig.get_head_under_data()]:
		if h_dict.is_empty():
			continue
		for m_v: Variant in (h_dict.get("materials", []) as Array):
			var mat: ShaderMaterial = m_v as ShaderMaterial
			if mat == null:
				continue
			mat.set_shader_parameter("enable_secondary_jiggle", sec_active)
			mat.set_shader_parameter("secondary_jiggle_l_px", h_l)
			mat.set_shader_parameter("secondary_jiggle_r_px", h_r)


func _apply_leg_common_overlays(
	view_key: String,
	p_key: String,
	poly: Polygon2D,
	mat: ShaderMaterial,
	bc_tex: Texture2D,
	bc_rect: Variant,
	pelvis_delta: Vector2
) -> void:
	var sh_cfg: Dictionary = _hip_shadows.get(view_key, {}) as Dictionary
	var use_cast: bool = bool(sh_cfg.get("enabled", true)) and bc_tex != null
	mat.set_shader_parameter("enable_hip_cast_shadow", use_cast)
	if use_cast:
		mat.set_shader_parameter("hip_cast_body_tex", bc_tex)
		mat.set_shader_parameter("hip_cast_body_rect", bc_rect)
		mat.set_shader_parameter("hip_cast_pelvis_delta", Vector2.ZERO)
		mat.set_shader_parameter("hip_cast_shadow_offset_px", sh_cfg.get("offset", Vector2(0.8, 3.2)) as Vector2)
		mat.set_shader_parameter("hip_cast_shadow_color", sh_cfg.get("color", Color(0.82, 0.68, 0.74, 1.0)) as Color)

	var sp_cfg: Dictionary = _stocking_pinches.get(view_key, {}) as Dictionary
	var use_pinch: bool = bool(sp_cfg.get("enabled", true))
	mat.set_shader_parameter("enable_stocking_pinch", use_pinch)
	if use_pinch:
		var is_l: bool = p_key.begins_with("leg_l")
		var v_key_sp: String = "v_l" if is_l else "v_r"
		var tilt_key: String = "tilt_l" if is_l else "tilt_r"
		var v_val_sp: float = float(sp_cfg.get(v_key_sp, sp_cfg.get("v", 0.25)))
		mat.set_shader_parameter("stocking_pinch_v", v_val_sp)
		mat.set_shader_parameter("stocking_pinch_center_u", CalibStoreScript.compute_pinch_center_u(poly.texture, v_val_sp))
		mat.set_shader_parameter("stocking_pinch_tilt", float(sp_cfg.get(tilt_key, sp_cfg.get("tilt", 0.0))))
		mat.set_shader_parameter("stocking_pinch_strength", float(sp_cfg.get("strength", 0.045)))
		mat.set_shader_parameter("stocking_pinch_width", float(sp_cfg.get("width", 0.032)))
		mat.set_shader_parameter("stocking_pinch_shadow", float(sp_cfg.get("shadow", 0.20)))


func _load_png_tex(res_path: String) -> Texture2D:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img: Image = Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(res_path):
		return ResourceLoader.load(res_path) as Texture2D
	return null
