class_name PilotLocomotionAnimConfig
extends Resource
## Configuración data-driven de locomoción continua (Avance Aerodinámico, Reversa en Guardia)
## y Freno Suave por contra-inclinación para Valentina v2 (8-Dir).

const BasePoseConfigScript = preload("res://data/pilots/schemas/pilot_base_pose_config.gd")

enum PreviewMode {
	AUTO_CYCLE = 0,
	FORWARD_CRUISE = 1,
	BRAKE_COUNTER = 2,
	BACKPEDAL_REVERSE = 3,
}

const FAMILY_ORDER: Array[String] = ["s", "se", "e", "ne", "n"]
const PHASE_PREFIXES: Array[String] = ["fwd_", "brk_", "rev_"]
const PHASE_BASE_KEYS: Array[String] = [
	"pelvis_shift_x", "pelvis_shift_y", "pelvis_rot", "waist_rot", "chest_rot", "neck_rot",
	"head_lag_px", "head_rot",
	"shoulder_lead_rot", "elbow_lead_rot", "wrist_lead_rot",
	"shoulder_trail_rot", "elbow_trail_rot", "wrist_trail_rot",
	"thigh_lead_rot", "knee_lead_rot", "ankle_lead_rot",
	"thigh_trail_rot", "knee_trail_rot", "ankle_trail_rot",
	"torso_trap", "torso_yaw", "leg_lead_phi_shin", "leg_trail_phi_shin", "leg_trail_distal_amp",
	"hair_drag_x_px", "hair_drag_y_px", "torso_sec_drag_y_px",
]

@export var anim_id: String = "locomotion_cruise_brake_zero_g"
@export var display_name: String = "Vuelo Crucero & Freno Suave Zero-G"

@export var master_intensity: float = 1.0
@export var accel_blend_rate: float = 11.0
@export var brake_enter_rate: float = 16.0
@export var brake_decay_rate: float = 5.5
@export var brake_decel_sensitivity: float = 0.85
@export var flight_idle_float_atten: float = 0.35
@export var flight_wake_freq_mul: float = 1.35
@export var flight_wake_amp_mul: float = 1.15
@export var fwd_leg_sync_blend: float = 0.85
@export var auto_cycle_duration_sec: float = 4.4

@export var families: Dictionary = {}


func _init() -> void:
	ensure_initialized()


static func _empty_family_dict() -> Dictionary:
	var out: Dictionary = {}
	for pfx: String in PHASE_PREFIXES:
		for bk: String in PHASE_BASE_KEYS:
			out[pfx + bk] = 0.0
	return out


static func _with_overrides(overrides: Dictionary) -> Dictionary:
	var d: Dictionary = _empty_family_dict()
	for k: Variant in overrides.keys():
		d[str(k)] = float(overrides[k])
	return d


static func build_default_families() -> Dictionary:
	return {
		"e": _with_overrides({
			"fwd_pelvis_shift_x": 2.2, "fwd_pelvis_shift_y": -1.0,
			"fwd_pelvis_rot": 0.045, "fwd_waist_rot": 0.065, "fwd_chest_rot": 0.075, "fwd_neck_rot": -0.135,
			"fwd_head_lag_px": -1.2, "fwd_head_rot": -0.025,
			"fwd_shoulder_lead_rot": -0.08, "fwd_elbow_lead_rot": -0.14, "fwd_wrist_lead_rot": -0.05,
			"fwd_shoulder_trail_rot": 0.11, "fwd_elbow_trail_rot": -0.12, "fwd_wrist_trail_rot": -0.04,
			"fwd_thigh_lead_rot": 0.355, "fwd_knee_lead_rot": -0.235, "fwd_ankle_lead_rot": 0.095,
			"fwd_thigh_trail_rot": 0.140, "fwd_knee_trail_rot": -0.195, "fwd_ankle_trail_rot": 0.095,
			"fwd_torso_trap": -0.018, "fwd_torso_yaw": 0.015,
			"fwd_leg_lead_phi_shin": -0.045, "fwd_leg_trail_phi_shin": -0.055, "fwd_leg_trail_distal_amp": -0.035,
			"fwd_hair_drag_x_px": -2.4, "fwd_hair_drag_y_px": 0.8, "fwd_torso_sec_drag_y_px": 0.75,

			"brk_pelvis_shift_x": 1.6, "brk_pelvis_shift_y": 1.8,
			"brk_pelvis_rot": -0.055, "brk_waist_rot": -0.065, "brk_chest_rot": -0.070, "brk_neck_rot": 0.115,
			"brk_head_lag_px": 1.1, "brk_head_rot": 0.035,
			"brk_shoulder_lead_rot": -0.14, "brk_elbow_lead_rot": 0.08, "brk_wrist_lead_rot": 0.06,
			"brk_shoulder_trail_rot": -0.12, "brk_elbow_trail_rot": 0.07, "brk_wrist_trail_rot": 0.05,
			"brk_thigh_lead_rot": -0.135, "brk_knee_lead_rot": -0.065, "brk_ankle_lead_rot": -0.140,
			"brk_thigh_trail_rot": -0.195, "brk_knee_trail_rot": 0.085, "brk_ankle_trail_rot": -0.155,
			"brk_torso_trap": 0.022, "brk_torso_yaw": -0.015,
			"brk_leg_lead_phi_shin": 0.055, "brk_leg_trail_phi_shin": 0.065, "brk_leg_trail_distal_amp": 0.045,
			"brk_hair_drag_x_px": 2.2, "brk_hair_drag_y_px": -0.6, "brk_torso_sec_drag_y_px": -0.65,

			"rev_pelvis_shift_x": -1.8, "rev_pelvis_shift_y": 0.8,
			"rev_pelvis_rot": -0.038, "rev_waist_rot": -0.048, "rev_chest_rot": -0.052, "rev_neck_rot": 0.088,
			"rev_head_lag_px": 0.8, "rev_head_rot": 0.022,
			"rev_shoulder_lead_rot": 0.08, "rev_elbow_lead_rot": -0.10, "rev_wrist_lead_rot": -0.04,
			"rev_shoulder_trail_rot": -0.12, "rev_elbow_trail_rot": -0.14, "rev_wrist_trail_rot": -0.05,
			"rev_thigh_lead_rot": -0.085, "rev_knee_lead_rot": -0.045, "rev_ankle_lead_rot": -0.095,
			"rev_thigh_trail_rot": -0.145, "rev_knee_trail_rot": 0.075, "rev_ankle_trail_rot": -0.110,
			"rev_torso_trap": 0.016, "rev_torso_yaw": -0.012,
			"rev_leg_lead_phi_shin": 0.040, "rev_leg_trail_phi_shin": 0.050, "rev_leg_trail_distal_amp": 0.030,
			"rev_hair_drag_x_px": 1.9, "rev_hair_drag_y_px": 0.5, "rev_torso_sec_drag_y_px": 0.45,
		}),
		"se": _with_overrides({
			"fwd_pelvis_shift_x": 1.5, "fwd_pelvis_shift_y": 1.4,
			"fwd_waist_rot": 0.038, "fwd_chest_rot": 0.045, "fwd_neck_rot": -0.078,
			"fwd_shoulder_lead_rot": -0.032, "fwd_elbow_lead_rot": -0.035,
			"fwd_shoulder_trail_rot": 0.035, "fwd_elbow_trail_rot": -0.030,
			"fwd_thigh_lead_rot": 0.260, "fwd_knee_lead_rot": -0.065, "fwd_ankle_lead_rot": 0.075,
			"fwd_thigh_trail_rot": 0.015, "fwd_knee_trail_rot": -0.145, "fwd_ankle_trail_rot": 0.105,
			"fwd_torso_trap": -0.024, "fwd_torso_yaw": 0.018,
			"fwd_leg_lead_phi_shin": -0.095, "fwd_leg_trail_phi_shin": -0.110, "fwd_leg_trail_distal_amp": -0.055,
			"fwd_hair_drag_x_px": -1.7, "fwd_hair_drag_y_px": -1.4, "fwd_torso_sec_drag_y_px": -0.85,

			"brk_pelvis_shift_x": -1.0, "brk_pelvis_shift_y": 1.6,
			"brk_waist_rot": -0.042, "brk_chest_rot": -0.048, "brk_neck_rot": 0.082, "brk_head_rot": 0.026,
			"brk_shoulder_lead_rot": -0.025, "brk_elbow_lead_rot": 0.045,
			"brk_shoulder_trail_rot": -0.040, "brk_elbow_trail_rot": 0.045,
			"brk_thigh_lead_rot": -0.005, "brk_knee_lead_rot": -0.075, "brk_ankle_lead_rot": -0.110,
			"brk_thigh_trail_rot": -0.020, "brk_knee_trail_rot": -0.035, "brk_ankle_trail_rot": -0.095,
			"brk_torso_trap": 0.028,
			"brk_leg_lead_phi_shin": 0.085, "brk_leg_trail_phi_shin": 0.095, "brk_leg_trail_distal_amp": 0.055,
			"brk_hair_drag_x_px": 1.6, "brk_hair_drag_y_px": 1.5, "brk_torso_sec_drag_y_px": 0.90,

			"rev_pelvis_shift_x": -1.2, "rev_pelvis_shift_y": -1.0,
			"rev_waist_rot": -0.030, "rev_chest_rot": -0.035, "rev_neck_rot": 0.060,
			"rev_knee_lead_rot": -0.050, "rev_ankle_lead_rot": -0.070,
			"rev_torso_trap": 0.020,
			"rev_leg_lead_phi_shin": 0.060, "rev_leg_trail_phi_shin": 0.070,
			"rev_hair_drag_x_px": 1.4, "rev_hair_drag_y_px": 1.2,
		}),
		"s": _with_overrides({
			"fwd_pelvis_shift_y": 2.0,
			"fwd_chest_rot": 0.010, "fwd_neck_rot": -0.012, "fwd_head_lag_px": -1.4,
			"fwd_shoulder_lead_rot": 0.032, "fwd_elbow_lead_rot": -0.025,
			"fwd_shoulder_trail_rot": -0.032, "fwd_elbow_trail_rot": 0.025,
			"fwd_thigh_lead_rot": -0.115, "fwd_knee_lead_rot": -0.118, "fwd_ankle_lead_rot": 0.075,
			"fwd_thigh_trail_rot": 0.125, "fwd_knee_trail_rot": 0.098, "fwd_ankle_trail_rot": -0.065,
			"fwd_torso_trap": -0.028,
			"fwd_leg_lead_phi_shin": -0.115, "fwd_leg_trail_phi_shin": -0.125, "fwd_leg_trail_distal_amp": -0.070,
			"fwd_hair_drag_y_px": -2.2, "fwd_torso_sec_drag_y_px": -1.1,

			"brk_pelvis_shift_y": 1.5, "brk_head_lag_px": 1.4,
			"brk_shoulder_lead_rot": 0.055, "brk_elbow_lead_rot": 0.040,
			"brk_shoulder_trail_rot": -0.055, "brk_elbow_trail_rot": -0.040,
			"brk_ankle_lead_rot": -0.085, "brk_ankle_trail_rot": 0.075,
			"brk_torso_trap": 0.032,
			"brk_leg_lead_phi_shin": 0.095, "brk_leg_trail_phi_shin": 0.110, "brk_leg_trail_distal_amp": 0.065,
			"brk_hair_drag_y_px": 2.1, "brk_torso_sec_drag_y_px": 1.05,

			"rev_pelvis_shift_y": -1.6, "rev_head_lag_px": 1.1,
			"rev_shoulder_lead_rot": -0.015, "rev_shoulder_trail_rot": 0.015,
			"rev_torso_trap": 0.024,
			"rev_leg_lead_phi_shin": 0.070, "rev_leg_trail_phi_shin": 0.080,
			"rev_hair_drag_y_px": 1.8, "rev_torso_sec_drag_y_px": 0.85,
		}),
		"ne": _with_overrides({
			"fwd_pelvis_shift_x": 1.5, "fwd_pelvis_shift_y": -1.4,
			"fwd_waist_rot": 0.036, "fwd_chest_rot": 0.042, "fwd_neck_rot": -0.072,
			"fwd_shoulder_lead_rot": 0.075, "fwd_elbow_lead_rot": 0.085,
			"fwd_shoulder_trail_rot": -0.085, "fwd_elbow_trail_rot": -0.110,
			"fwd_thigh_lead_rot": 0.040, "fwd_knee_lead_rot": -0.120, "fwd_ankle_lead_rot": 0.095,
			"fwd_thigh_trail_rot": 0.220, "fwd_knee_trail_rot": -0.020, "fwd_ankle_trail_rot": 0.050,
			"fwd_torso_trap": 0.022, "fwd_torso_yaw": -0.016,
			"fwd_leg_lead_phi_shin": 0.115, "fwd_leg_trail_phi_shin": 0.110, "fwd_leg_trail_distal_amp": 0.055,
			"fwd_hair_drag_x_px": -1.7, "fwd_hair_drag_y_px": 1.4, "fwd_torso_sec_drag_y_px": 0.80,

			"brk_pelvis_shift_x": -1.0, "brk_pelvis_shift_y": 1.4,
			"brk_waist_rot": -0.040, "brk_chest_rot": -0.045, "brk_neck_rot": 0.078,
			"brk_shoulder_lead_rot": -0.055, "brk_elbow_lead_rot": -0.045,
			"brk_shoulder_trail_rot": 0.065, "brk_elbow_trail_rot": 0.065,
			"brk_thigh_lead_rot": -0.025, "brk_knee_lead_rot": -0.045, "brk_ankle_lead_rot": -0.055,
			"brk_thigh_trail_rot": -0.055, "brk_knee_trail_rot": -0.045, "brk_ankle_trail_rot": -0.090,
			"brk_torso_trap": -0.025,
			"brk_leg_lead_phi_shin": -0.080, "brk_leg_trail_phi_shin": -0.090, "brk_leg_trail_distal_amp": -0.050,
			"brk_hair_drag_x_px": 1.6, "brk_hair_drag_y_px": -1.4, "brk_torso_sec_drag_y_px": -0.80,

			"rev_pelvis_shift_x": -1.2, "rev_pelvis_shift_y": 1.1,
			"rev_waist_rot": -0.028, "rev_chest_rot": -0.032, "rev_neck_rot": 0.055,
			"rev_knee_lead_rot": -0.032,
			"rev_torso_trap": -0.018,
			"rev_leg_lead_phi_shin": -0.055, "rev_leg_trail_phi_shin": -0.065,
			"rev_hair_drag_x_px": 1.4, "rev_hair_drag_y_px": -1.1,
		}),
		"n": _with_overrides({
			"fwd_pelvis_shift_y": -2.0, "fwd_head_lag_px": 1.3,
			"fwd_shoulder_lead_rot": -0.032, "fwd_elbow_lead_rot": -0.025,
			"fwd_shoulder_trail_rot": 0.032, "fwd_elbow_trail_rot": 0.025,
			"fwd_thigh_lead_rot": 0.138, "fwd_knee_lead_rot": 0.150, "fwd_ankle_lead_rot": 0.065,
			"fwd_thigh_trail_rot": -0.134, "fwd_knee_trail_rot": -0.134, "fwd_ankle_trail_rot": -0.055,
			"fwd_torso_trap": 0.026,
			"fwd_leg_lead_phi_shin": 0.110, "fwd_leg_trail_phi_shin": 0.120, "fwd_leg_trail_distal_amp": 0.065,
			"fwd_hair_drag_y_px": 2.2, "fwd_torso_sec_drag_y_px": 1.0,

			"brk_pelvis_shift_y": 1.5, "brk_head_lag_px": -1.3,
			"brk_shoulder_lead_rot": -0.055, "brk_elbow_lead_rot": 0.035,
			"brk_shoulder_trail_rot": 0.055, "brk_elbow_trail_rot": -0.035,
			"brk_ankle_lead_rot": -0.080, "brk_ankle_trail_rot": 0.070,
			"brk_torso_trap": -0.030,
			"brk_leg_lead_phi_shin": -0.090, "brk_leg_trail_phi_shin": -0.105, "brk_leg_trail_distal_amp": -0.060,
			"brk_hair_drag_y_px": -2.0, "brk_torso_sec_drag_y_px": -0.95,

			"rev_pelvis_shift_y": 1.6, "rev_head_lag_px": -1.0,
			"rev_torso_trap": -0.022,
			"rev_leg_lead_phi_shin": -0.065, "rev_leg_trail_phi_shin": -0.075,
			"rev_hair_drag_y_px": -1.7, "rev_torso_sec_drag_y_px": -0.80,
		}),
	}


func ensure_initialized() -> void:
	var defaults: Dictionary = build_default_families()
	for fam: String in FAMILY_ORDER:
		var def_fam: Dictionary = defaults[fam] as Dictionary
		if not families.has(fam) or not (families[fam] is Dictionary):
			families[fam] = def_fam.duplicate(true)
			continue
		var cur_fam: Dictionary = families[fam] as Dictionary
		for k: Variant in def_fam.keys():
			var ks: String = str(k)
			if not cur_fam.has(ks):
				cur_fam[ks] = float(def_fam[ks])


func reset_to_defaults() -> void:
	master_intensity = 1.0
	accel_blend_rate = 11.0
	brake_enter_rate = 16.0
	brake_decay_rate = 5.5
	brake_decel_sensitivity = 0.85
	flight_idle_float_atten = 0.35
	flight_wake_freq_mul = 1.35
	flight_wake_amp_mul = 1.15
	fwd_leg_sync_blend = 0.85
	auto_cycle_duration_sec = 4.4
	families = build_default_families()


func reset_family_to_defaults(fam: String) -> void:
	var defaults: Dictionary = build_default_families()
	var can_fam: String = BasePoseConfigScript.canonical_family_for_view(fam)
	if defaults.has(can_fam):
		families[can_fam] = (defaults[can_fam] as Dictionary).duplicate(true)


func get_global_param(key: String) -> float:
	if key in self:
		return float(get(key))
	return 0.0


func set_global_param(key: String, val: float) -> void:
	if key in self:
		set(key, val)


func get_family_dict(fam: String) -> Dictionary:
	ensure_initialized()
	var can_fam: String = BasePoseConfigScript.canonical_family_for_view(fam)
	return families.get(can_fam, {}) as Dictionary


func get_family_param(fam: String, key: String) -> float:
	var d: Dictionary = get_family_dict(fam)
	return float(d.get(key, 0.0))


func set_family_param(fam: String, key: String, val: float) -> void:
	ensure_initialized()
	var can_fam: String = BasePoseConfigScript.canonical_family_for_view(fam)
	var d: Dictionary = families.get(can_fam, {}) as Dictionary
	d[key] = val
	families[can_fam] = d
