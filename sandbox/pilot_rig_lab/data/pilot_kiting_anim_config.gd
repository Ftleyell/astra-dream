class_name PilotKitingAnimConfig
extends Resource
## Configuración data-driven de Kiting 360° Zero-G ("Hover-Slide") para Valentina v2 (8-Dir).
## Cubre Reversa 180° (rev_), Freno de Reversa (rbrk_) y Strafe Lateral (str_near_ / str_far_)
## con descomposición en marco anatómico de orientación y simetría automática L ↔ R.

const BasePoseConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_base_pose_config.gd")

enum PreviewMode {
	AUTO_KITING_360 = 0,
	REVERSE_180 = 1,
	STRAFE_NEAR_R = 2,
	STRAFE_FAR_L = 3,
	REVERSE_BRAKE = 4,
}

const FAMILY_ORDER: Array[String] = ["s", "se", "e", "ne", "n"]
const PHASE_PREFIXES: Array[String] = ["rev_", "rbrk_", "str_near_", "str_far_"]
const PHASE_LABELS: Dictionary = {
	"rev_": "Reversa 180° (Hover-Slide)",
	"rbrk_": "Freno de Reversa",
	"str_near_": "Strafe + (Cámara / Der.)",
	"str_far_": "Strafe - (Fondo / Izq.)",
}
const PHASE_BASE_KEYS: Array[String] = [
	"pelvis_shift_x", "pelvis_shift_y", "pelvis_rot", "waist_rot", "chest_rot", "neck_rot",
	"head_lag_px", "head_rot",
	"shoulder_lead_rot", "elbow_lead_rot", "wrist_lead_rot",
	"shoulder_trail_rot", "elbow_trail_rot", "wrist_trail_rot",
	"thigh_lead_rot", "knee_lead_rot", "ankle_lead_rot",
	"thigh_trail_rot", "knee_trail_rot", "ankle_trail_rot",
	"torso_trap", "torso_yaw",
	"leg_lead_phi_shin", "leg_lead_distal_amp",
	"leg_trail_phi_shin", "leg_trail_distal_amp",
	"hair_drag_x_px", "hair_drag_y_px", "torso_sec_drag_y_px",
]

@export var anim_id: String = "kiting_hover_slide_zero_g"
@export var display_name: String = "Kiting 360° & Hover-Slide Zero-G"

@export var master_intensity: float = 1.0
@export var blend_rate: float = 12.0
@export var rev_brake_enter_rate: float = 17.0
@export var rev_brake_decay_rate: float = 5.2
@export var rev_brake_sensitivity: float = 0.90
@export var strafe_enter_dot_max: float = 0.78
@export var reverse_enter_dot_max: float = 0.10
@export var hover_slide_micro_amp: float = 0.16
@export var hover_slide_micro_hz: float = 1.85
@export var auto_cycle_duration_sec: float = 6.4

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
			# Reversa 180° Hover-Slide: cuerpo reclinado hacia atrás, rodilla líder recogida en guardia, pierna trasera extendida.
			"rev_pelvis_shift_x": -3.2, "rev_pelvis_shift_y": 1.2,
			"rev_pelvis_rot": -0.068, "rev_waist_rot": -0.085, "rev_chest_rot": -0.095, "rev_neck_rot": 0.165,
			"rev_head_lag_px": 1.6, "rev_head_rot": 0.042,
			"rev_shoulder_lead_rot": -0.18, "rev_elbow_lead_rot": -0.20, "rev_wrist_lead_rot": -0.08,
			"rev_shoulder_trail_rot": 0.09, "rev_elbow_trail_rot": -0.18, "rev_wrist_trail_rot": -0.10,
			"rev_thigh_lead_rot": -0.175, "rev_knee_lead_rot": 0.30, "rev_ankle_lead_rot": 0.16,
			"rev_thigh_trail_rot": -0.24, "rev_knee_trail_rot": -0.11, "rev_ankle_trail_rot": -0.16,
			"rev_torso_trap": 0.036, "rev_torso_yaw": -0.028,
			"rev_leg_lead_phi_shin": 0.095, "rev_leg_lead_distal_amp": 0.060,
			"rev_leg_trail_phi_shin": 0.115, "rev_leg_trail_distal_amp": 0.075,
			"rev_hair_drag_x_px": 3.4, "rev_hair_drag_y_px": 0.9, "rev_torso_sec_drag_y_px": 0.85,

			# Freno de Reversa: latigazo compensatorio hacia adelante al cortar retroceso.
			"rbrk_pelvis_shift_x": 2.6, "rbrk_pelvis_shift_y": 1.6,
			"rbrk_pelvis_rot": 0.062, "rbrk_waist_rot": 0.078, "rbrk_chest_rot": 0.082, "rbrk_neck_rot": -0.145,
			"rbrk_head_lag_px": -1.5, "rbrk_head_rot": -0.038,
			"rbrk_shoulder_lead_rot": -0.12, "rbrk_elbow_lead_rot": -0.16, "rbrk_wrist_lead_rot": -0.04,
			"rbrk_shoulder_trail_rot": 0.10, "rbrk_elbow_trail_rot": -0.12, "rbrk_wrist_trail_rot": 0.06,
			"rbrk_thigh_lead_rot": 0.12, "rbrk_knee_lead_rot": 0.22, "rbrk_ankle_lead_rot": 0.10,
			"rbrk_thigh_trail_rot": 0.11, "rbrk_knee_trail_rot": 0.18, "rbrk_ankle_trail_rot": 0.12,
			"rbrk_torso_trap": -0.028, "rbrk_torso_yaw": 0.020,
			"rbrk_leg_lead_phi_shin": -0.065, "rbrk_leg_lead_distal_amp": -0.035,
			"rbrk_leg_trail_phi_shin": -0.080, "rbrk_leg_trail_distal_amp": -0.050,
			"rbrk_hair_drag_x_px": -3.2, "rbrk_hair_drag_y_px": -0.7, "rbrk_torso_sec_drag_y_px": -0.95,

			# Strafe Lateral (+Y hacia cámara en e; espejo automático en w).
			"str_near_pelvis_shift_x": -1.2, "str_near_pelvis_shift_y": 2.6,
			"str_near_pelvis_rot": -0.032, "str_near_waist_rot": -0.040, "str_near_chest_rot": -0.048, "str_near_neck_rot": 0.078,
			"str_near_head_lag_px": 0.9, "str_near_head_rot": 0.024,
			"str_near_shoulder_lead_rot": -0.14, "str_near_elbow_lead_rot": -0.16, "str_near_wrist_lead_rot": -0.05,
			"str_near_shoulder_trail_rot": -0.08, "str_near_elbow_trail_rot": -0.10, "str_near_wrist_trail_rot": -0.04,
			"str_near_thigh_lead_rot": -0.12, "str_near_knee_lead_rot": 0.18, "str_near_ankle_lead_rot": 0.12,
			"str_near_thigh_trail_rot": -0.16, "str_near_knee_trail_rot": 0.08, "str_near_ankle_trail_rot": -0.12,
			"str_near_torso_trap": 0.044, "str_near_torso_yaw": -0.052,
			"str_near_leg_lead_phi_shin": -0.065, "str_near_leg_lead_distal_amp": -0.035,
			"str_near_leg_trail_phi_shin": 0.145, "str_near_leg_trail_distal_amp": 0.085,
			"str_near_hair_drag_x_px": 1.0, "str_near_hair_drag_y_px": -2.8, "str_near_torso_sec_drag_y_px": -0.75,

			# Strafe Lateral (-Y hacia el fondo en e; espejo automático en w).
			"str_far_pelvis_shift_x": -0.9, "str_far_pelvis_shift_y": -2.4,
			"str_far_pelvis_rot": 0.028, "str_far_waist_rot": 0.036, "str_far_chest_rot": 0.042, "str_far_neck_rot": -0.068,
			"str_far_head_lag_px": -0.8, "str_far_head_rot": -0.022,
			"str_far_shoulder_lead_rot": 0.10, "str_far_elbow_lead_rot": -0.14, "str_far_wrist_lead_rot": 0.05,
			"str_far_shoulder_trail_rot": 0.10, "str_far_elbow_trail_rot": -0.16, "str_far_wrist_trail_rot": 0.06,
			"str_far_thigh_lead_rot": -0.06, "str_far_knee_lead_rot": 0.14, "str_far_ankle_lead_rot": -0.08,
			"str_far_thigh_trail_rot": 0.11, "str_far_knee_trail_rot": 0.16, "str_far_ankle_trail_rot": 0.12,
			"str_far_torso_trap": -0.042, "str_far_torso_yaw": 0.052,
			"str_far_leg_lead_phi_shin": -0.125, "str_far_leg_lead_distal_amp": -0.070,
			"str_far_leg_trail_phi_shin": -0.095, "str_far_leg_trail_distal_amp": -0.065,
			"str_far_hair_drag_x_px": 0.9, "str_far_hair_drag_y_px": 2.8, "str_far_torso_sec_drag_y_px": 0.75,
		}),
		"se": _with_overrides({
			"rev_pelvis_shift_x": -2.2, "rev_pelvis_shift_y": -2.0,
			"rev_pelvis_rot": -0.045, "rev_waist_rot": -0.058, "rev_chest_rot": -0.064, "rev_neck_rot": 0.115,
			"rev_head_lag_px": 1.4, "rev_head_rot": 0.034,
			"rev_shoulder_lead_rot": -0.032, "rev_elbow_lead_rot": -0.028, "rev_wrist_lead_rot": -0.04,
			"rev_shoulder_trail_rot": 0.036, "rev_elbow_trail_rot": -0.015, "rev_wrist_trail_rot": -0.04,
			"rev_thigh_lead_rot": -0.005, "rev_knee_lead_rot": 0.090, "rev_ankle_lead_rot": 0.095,
			"rev_thigh_trail_rot": -0.032, "rev_knee_trail_rot": -0.115, "rev_ankle_trail_rot": -0.120,
			"rev_torso_trap": 0.042, "rev_torso_yaw": -0.032,
			"rev_leg_lead_phi_shin": 0.135, "rev_leg_lead_distal_amp": 0.075,
			"rev_leg_trail_phi_shin": 0.115, "rev_leg_trail_distal_amp": 0.065,
			"rev_hair_drag_x_px": 2.4, "rev_hair_drag_y_px": 2.1, "rev_torso_sec_drag_y_px": 1.15,

			"rbrk_pelvis_shift_x": 1.8, "rbrk_pelvis_shift_y": 2.0,
			"rbrk_pelvis_rot": 0.042, "rbrk_waist_rot": 0.052, "rbrk_chest_rot": 0.056, "rbrk_neck_rot": -0.098,
			"rbrk_head_lag_px": -1.3, "rbrk_head_rot": -0.030,
			"rbrk_shoulder_lead_rot": 0.045, "rbrk_elbow_lead_rot": 0.045, "rbrk_wrist_lead_rot": 0.04,
			"rbrk_shoulder_trail_rot": -0.045, "rbrk_elbow_trail_rot": 0.045, "rbrk_wrist_trail_rot": 0.04,
			"rbrk_thigh_lead_rot": 0.025, "rbrk_knee_lead_rot": -0.065, "rbrk_ankle_lead_rot": -0.095,
			"rbrk_thigh_trail_rot": -0.015, "rbrk_knee_trail_rot": -0.045, "rbrk_ankle_trail_rot": -0.085,
			"rbrk_torso_trap": -0.036, "rbrk_torso_yaw": 0.024,
			"rbrk_leg_lead_phi_shin": -0.095, "rbrk_leg_lead_distal_amp": -0.055,
			"rbrk_leg_trail_phi_shin": -0.105, "rbrk_leg_trail_distal_amp": -0.060,
			"rbrk_hair_drag_x_px": -2.2, "rbrk_hair_drag_y_px": -2.0, "rbrk_torso_sec_drag_y_px": -1.05,

			"str_near_pelvis_shift_x": -2.4, "str_near_pelvis_shift_y": 1.8,
			"str_near_pelvis_rot": -0.048, "str_near_waist_rot": -0.058, "str_near_chest_rot": -0.062, "str_near_neck_rot": 0.108,
			"str_near_head_lag_px": 1.3, "str_near_head_rot": 0.032,
			"str_near_shoulder_lead_rot": -0.030, "str_near_elbow_lead_rot": -0.025, "str_near_wrist_lead_rot": -0.04,
			"str_near_shoulder_trail_rot": 0.032, "str_near_elbow_trail_rot": 0.045, "str_near_wrist_trail_rot": 0.04,
			"str_near_thigh_lead_rot": -0.005, "str_near_knee_lead_rot": 0.065, "str_near_ankle_lead_rot": -0.085,
			"str_near_thigh_trail_rot": -0.024, "str_near_knee_trail_rot": -0.035, "str_near_ankle_trail_rot": -0.095,
			"str_near_torso_trap": 0.030, "str_near_torso_yaw": -0.052,
			"str_near_leg_lead_phi_shin": 0.065, "str_near_leg_lead_distal_amp": 0.035,
			"str_near_leg_trail_phi_shin": 0.125, "str_near_leg_trail_distal_amp": 0.070,
			"str_near_hair_drag_x_px": 2.6, "str_near_hair_drag_y_px": -1.8, "str_near_torso_sec_drag_y_px": -0.65,

			"str_far_pelvis_shift_x": 2.2, "str_far_pelvis_shift_y": -1.8,
			"str_far_pelvis_rot": 0.044, "str_far_waist_rot": 0.054, "str_far_chest_rot": 0.058, "str_far_neck_rot": -0.100,
			"str_far_head_lag_px": -1.2, "str_far_head_rot": -0.028,
			"str_far_shoulder_lead_rot": 0.038, "str_far_elbow_lead_rot": -0.020, "str_far_wrist_lead_rot": 0.04,
			"str_far_shoulder_trail_rot": -0.036, "str_far_elbow_trail_rot": -0.015, "str_far_wrist_trail_rot": -0.04,
			"str_far_thigh_lead_rot": 0.024, "str_far_knee_lead_rot": 0.055, "str_far_ankle_lead_rot": 0.085,
			"str_far_thigh_trail_rot": 0.003, "str_far_knee_trail_rot": 0.085, "str_far_ankle_trail_rot": 0.095,
			"str_far_torso_trap": -0.032, "str_far_torso_yaw": 0.052,
			"str_far_leg_lead_phi_shin": -0.115, "str_far_leg_lead_distal_amp": -0.060,
			"str_far_leg_trail_phi_shin": -0.085, "str_far_leg_trail_distal_amp": -0.055,
			"str_far_hair_drag_x_px": -2.4, "str_far_hair_drag_y_px": 1.8, "str_far_torso_sec_drag_y_px": 0.65,
		}),
		"s": _with_overrides({
			"rev_pelvis_shift_y": -3.2, "rev_chest_rot": -0.016, "rev_neck_rot": 0.022, "rev_head_lag_px": 2.2,
			"rev_shoulder_lead_rot": 0.048, "rev_elbow_lead_rot": -0.038, "rev_wrist_lead_rot": -0.04,
			"rev_shoulder_trail_rot": -0.048, "rev_elbow_trail_rot": 0.038, "rev_wrist_trail_rot": 0.04,
			"rev_thigh_lead_rot": -0.006, "rev_knee_lead_rot": 0.032, "rev_ankle_lead_rot": 0.115,
			"rev_thigh_trail_rot": -0.035, "rev_knee_trail_rot": -0.036, "rev_ankle_trail_rot": -0.095,
			"rev_torso_trap": 0.052, "rev_torso_yaw": 0.022,
			"rev_leg_lead_phi_shin": 0.165, "rev_leg_lead_distal_amp": 0.085,
			"rev_leg_trail_phi_shin": 0.115, "rev_leg_trail_distal_amp": 0.065,
			"rev_hair_drag_y_px": 3.4, "rev_torso_sec_drag_y_px": 1.45,

			"rbrk_pelvis_shift_y": 2.8, "rbrk_chest_rot": 0.012, "rbrk_neck_rot": -0.016, "rbrk_head_lag_px": -2.0,
			"rbrk_shoulder_lead_rot": -0.045, "rbrk_elbow_lead_rot": 0.035,
			"rbrk_shoulder_trail_rot": 0.045, "rbrk_elbow_trail_rot": -0.035,
			"rbrk_ankle_lead_rot": -0.105, "rbrk_ankle_trail_rot": 0.095,
			"rbrk_torso_trap": -0.044,
			"rbrk_leg_lead_phi_shin": -0.125, "rbrk_leg_lead_distal_amp": -0.065,
			"rbrk_leg_trail_phi_shin": -0.115, "rbrk_leg_trail_distal_amp": -0.065,
			"rbrk_hair_drag_y_px": -3.2, "rbrk_torso_sec_drag_y_px": -1.35,

			# En s (frente): str_near_ corresponde a movimiento a la derecha anatómica (pantalla -X); str_far_ espejo opuesto (+X).
			"str_near_pelvis_shift_x": -3.2, "str_near_pelvis_shift_y": 0.6,
			"str_near_pelvis_rot": -0.055, "str_near_waist_rot": -0.068, "str_near_chest_rot": -0.072, "str_near_neck_rot": 0.135,
			"str_near_head_lag_px": 1.6, "str_near_head_rot": 0.036,
			"str_near_shoulder_lead_rot": 0.055, "str_near_elbow_lead_rot": -0.035,
			"str_near_shoulder_trail_rot": -0.055, "str_near_elbow_trail_rot": -0.030,
			"str_near_thigh_lead_rot": -0.006, "str_near_knee_lead_rot": 0.030, "str_near_ankle_lead_rot": -0.115,
			"str_near_thigh_trail_rot": -0.038, "str_near_knee_trail_rot": 0.048, "str_near_ankle_trail_rot": -0.105,
			"str_near_torso_trap": 0.018, "str_near_torso_yaw": -0.058,
			"str_near_leg_lead_phi_shin": 0.085, "str_near_leg_lead_distal_amp": 0.045,
			"str_near_leg_trail_phi_shin": -0.075, "str_near_leg_trail_distal_amp": -0.045,
			"str_near_hair_drag_x_px": 3.2, "str_near_hair_drag_y_px": 0.4, "str_near_torso_sec_drag_y_px": 0.35,

			"str_far_pelvis_shift_x": 3.2, "str_far_pelvis_shift_y": 0.6,
			"str_far_pelvis_rot": 0.055, "str_far_waist_rot": 0.068, "str_far_chest_rot": 0.072, "str_far_neck_rot": -0.135,
			"str_far_head_lag_px": -1.6, "str_far_head_rot": -0.036,
			"str_far_shoulder_lead_rot": 0.055, "str_far_elbow_lead_rot": 0.030,
			"str_far_shoulder_trail_rot": -0.055, "str_far_elbow_trail_rot": 0.035,
			"str_far_thigh_lead_rot": 0.038, "str_far_knee_lead_rot": -0.048, "str_far_ankle_lead_rot": 0.105,
			"str_far_thigh_trail_rot": 0.006, "str_far_knee_trail_rot": -0.030, "str_far_ankle_trail_rot": 0.115,
			"str_far_torso_trap": 0.018, "str_far_torso_yaw": 0.058,
			"str_far_leg_lead_phi_shin": -0.075, "str_far_leg_lead_distal_amp": -0.045,
			"str_far_leg_trail_phi_shin": 0.085, "str_far_leg_trail_distal_amp": 0.045,
			"str_far_hair_drag_x_px": -3.2, "str_far_hair_drag_y_px": 0.4, "str_far_torso_sec_drag_y_px": 0.35,
		}),
		"ne": _with_overrides({
			"rev_pelvis_shift_x": -2.2, "rev_pelvis_shift_y": 2.0,
			"rev_pelvis_rot": -0.045, "rev_waist_rot": -0.056, "rev_chest_rot": -0.062, "rev_neck_rot": 0.110,
			"rev_head_lag_px": 1.4, "rev_head_rot": 0.032,
			"rev_shoulder_lead_rot": -0.095, "rev_elbow_lead_rot": -0.085, "rev_wrist_lead_rot": -0.04,
			"rev_shoulder_trail_rot": 0.095, "rev_elbow_trail_rot": 0.080, "rev_wrist_trail_rot": 0.04,
			"rev_thigh_lead_rot": -0.055, "rev_knee_lead_rot": 0.125, "rev_ankle_lead_rot": -0.085,
			"rev_thigh_trail_rot": -0.065, "rev_knee_trail_rot": -0.085, "rev_ankle_trail_rot": -0.115,
			"rev_torso_trap": -0.040, "rev_torso_yaw": 0.032,
			"rev_leg_lead_phi_shin": -0.125, "rev_leg_lead_distal_amp": -0.065,
			"rev_leg_trail_phi_shin": -0.115, "rev_leg_trail_distal_amp": -0.060,
			"rev_hair_drag_x_px": 2.4, "rev_hair_drag_y_px": -2.0, "rev_torso_sec_drag_y_px": -1.10,

			"rbrk_pelvis_shift_x": 1.8, "rbrk_pelvis_shift_y": -1.8,
			"rbrk_pelvis_rot": 0.042, "rbrk_waist_rot": 0.050, "rbrk_chest_rot": 0.056, "rbrk_neck_rot": -0.096,
			"rbrk_head_lag_px": -1.3, "rbrk_head_rot": -0.028,
			"rbrk_shoulder_lead_rot": 0.075, "rbrk_elbow_lead_rot": 0.075,
			"rbrk_shoulder_trail_rot": -0.075, "rbrk_elbow_trail_rot": -0.075,
			"rbrk_thigh_lead_rot": 0.045, "rbrk_knee_lead_rot": 0.065, "rbrk_ankle_lead_rot": 0.075,
			"rbrk_thigh_trail_rot": 0.035, "rbrk_knee_trail_rot": 0.085, "rbrk_ankle_trail_rot": 0.095,
			"rbrk_torso_trap": 0.036, "rbrk_torso_yaw": -0.024,
			"rbrk_leg_lead_phi_shin": 0.105, "rbrk_leg_lead_distal_amp": 0.055,
			"rbrk_leg_trail_phi_shin": 0.095, "rbrk_leg_trail_distal_amp": 0.055,
			"rbrk_hair_drag_x_px": -2.2, "rbrk_hair_drag_y_px": 1.9, "rbrk_torso_sec_drag_y_px": 1.00,

			"str_near_pelvis_shift_x": 2.2, "str_near_pelvis_shift_y": 1.8,
			"str_near_pelvis_rot": 0.044, "str_near_waist_rot": 0.054, "str_near_chest_rot": 0.058, "str_near_neck_rot": -0.100,
			"str_near_head_lag_px": -1.2, "str_near_head_rot": -0.028,
			"str_near_shoulder_lead_rot": -0.075, "str_near_elbow_lead_rot": -0.065,
			"str_near_shoulder_trail_rot": 0.085, "str_near_elbow_trail_rot": 0.075,
			"str_near_thigh_lead_rot": 0.042, "str_near_knee_lead_rot": 0.095, "str_near_ankle_lead_rot": 0.085,
			"str_near_thigh_trail_rot": 0.042, "str_near_knee_trail_rot": 0.110, "str_near_ankle_trail_rot": 0.095,
			"str_near_torso_trap": -0.032, "str_near_torso_yaw": -0.052,
			"str_near_leg_lead_phi_shin": -0.065, "str_near_leg_lead_distal_amp": -0.035,
			"str_near_leg_trail_phi_shin": -0.125, "str_near_leg_trail_distal_amp": -0.065,
			"str_near_hair_drag_x_px": -2.4, "str_near_hair_drag_y_px": -1.8, "str_near_torso_sec_drag_y_px": -0.65,

			"str_far_pelvis_shift_x": -2.2, "str_far_pelvis_shift_y": -1.8,
			"str_far_pelvis_rot": -0.044, "str_far_waist_rot": -0.054, "str_far_chest_rot": -0.058, "str_far_neck_rot": 0.100,
			"str_far_head_lag_px": 1.2, "str_far_head_rot": 0.028,
			"str_far_shoulder_lead_rot": 0.085, "str_far_elbow_lead_rot": 0.075,
			"str_far_shoulder_trail_rot": -0.075, "str_far_elbow_trail_rot": -0.065,
			"str_far_thigh_lead_rot": -0.048, "str_far_knee_lead_rot": 0.075, "str_far_ankle_lead_rot": -0.085,
			"str_far_thigh_trail_rot": -0.042, "str_far_knee_trail_rot": -0.045, "str_far_ankle_trail_rot": -0.095,
			"str_far_torso_trap": 0.032, "str_far_torso_yaw": 0.052,
			"str_far_leg_lead_phi_shin": 0.115, "str_far_leg_lead_distal_amp": 0.060,
			"str_far_leg_trail_phi_shin": 0.085, "str_far_leg_trail_distal_amp": 0.055,
			"str_far_hair_drag_x_px": 2.4, "str_far_hair_drag_y_px": 1.8, "str_far_torso_sec_drag_y_px": 0.65,
		}),
		"n": _with_overrides({
			"rev_pelvis_shift_y": 3.0, "rev_chest_rot": 0.016, "rev_neck_rot": -0.022, "rev_head_lag_px": -2.0,
			"rev_shoulder_lead_rot": -0.048, "rev_elbow_lead_rot": -0.035,
			"rev_shoulder_trail_rot": 0.048, "rev_elbow_trail_rot": 0.035,
			"rev_thigh_lead_rot": 0.022, "rev_knee_lead_rot": -0.038, "rev_ankle_lead_rot": 0.110,
			"rev_thigh_trail_rot": -0.030, "rev_knee_trail_rot": 0.035, "rev_ankle_trail_rot": -0.090,
			"rev_torso_trap": -0.050, "rev_torso_yaw": -0.022,
			"rev_leg_lead_phi_shin": -0.160, "rev_leg_lead_distal_amp": -0.080,
			"rev_leg_trail_phi_shin": -0.115, "rev_leg_trail_distal_amp": -0.065,
			"rev_hair_drag_y_px": -3.4, "rev_torso_sec_drag_y_px": -1.35,

			"rbrk_pelvis_shift_y": -2.6, "rbrk_chest_rot": -0.012, "rbrk_neck_rot": 0.016, "rbrk_head_lag_px": 1.9,
			"rbrk_shoulder_lead_rot": 0.045, "rbrk_elbow_lead_rot": 0.035,
			"rbrk_shoulder_trail_rot": -0.045, "rbrk_elbow_trail_rot": -0.035,
			"rbrk_ankle_lead_rot": -0.100, "rbrk_ankle_trail_rot": 0.090,
			"rbrk_torso_trap": 0.044,
			"rbrk_leg_lead_phi_shin": 0.120, "rbrk_leg_lead_distal_amp": 0.065,
			"rbrk_leg_trail_phi_shin": 0.110, "rbrk_leg_trail_distal_amp": 0.060,
			"rbrk_hair_drag_y_px": 3.1, "rbrk_torso_sec_drag_y_px": 1.25,

			# En n (espalda): derecha anatómica = pantalla +X (str_near_); izquierda anatómica = pantalla -X (str_far_).
			"str_near_pelvis_shift_x": 3.2, "str_near_pelvis_shift_y": 0.6,
			"str_near_pelvis_rot": 0.055, "str_near_waist_rot": 0.068, "str_near_chest_rot": 0.072, "str_near_neck_rot": -0.135,
			"str_near_head_lag_px": -1.6, "str_near_head_rot": -0.036,
			"str_near_shoulder_lead_rot": -0.055, "str_near_elbow_lead_rot": -0.035,
			"str_near_shoulder_trail_rot": 0.055, "str_near_elbow_trail_rot": -0.030,
			"str_near_thigh_lead_rot": 0.026, "str_near_knee_lead_rot": -0.038, "str_near_ankle_lead_rot": 0.110,
			"str_near_thigh_trail_rot": 0.018, "str_near_knee_trail_rot": -0.038, "str_near_ankle_trail_rot": 0.100,
			"str_near_torso_trap": -0.018, "str_near_torso_yaw": 0.058,
			"str_near_leg_lead_phi_shin": -0.085, "str_near_leg_lead_distal_amp": -0.045,
			"str_near_leg_trail_phi_shin": 0.075, "str_near_leg_trail_distal_amp": 0.045,
			"str_near_hair_drag_x_px": -3.2, "str_near_hair_drag_y_px": -0.4, "str_near_torso_sec_drag_y_px": -0.35,

			"str_far_pelvis_shift_x": -3.2, "str_far_pelvis_shift_y": 0.6,
			"str_far_pelvis_rot": -0.055, "str_far_waist_rot": -0.068, "str_far_chest_rot": -0.072, "str_far_neck_rot": 0.135,
			"str_far_head_lag_px": 1.6, "str_far_head_rot": 0.036,
			"str_far_shoulder_lead_rot": -0.055, "str_far_elbow_lead_rot": 0.030,
			"str_far_shoulder_trail_rot": 0.055, "str_far_elbow_trail_rot": 0.035,
			"str_far_thigh_lead_rot": -0.018, "str_far_knee_lead_rot": 0.038, "str_far_ankle_lead_rot": -0.100,
			"str_far_thigh_trail_rot": -0.026, "str_far_knee_trail_rot": 0.038, "str_far_ankle_trail_rot": -0.110,
			"str_far_torso_trap": -0.018, "str_far_torso_yaw": -0.058,
			"str_far_leg_lead_phi_shin": 0.075, "str_far_leg_lead_distal_amp": 0.045,
			"str_far_leg_trail_phi_shin": -0.085, "str_far_leg_trail_distal_amp": -0.045,
			"str_far_hair_drag_x_px": 3.2, "str_far_hair_drag_y_px": -0.4, "str_far_torso_sec_drag_y_px": -0.35,
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
	blend_rate = 12.0
	rev_brake_enter_rate = 17.0
	rev_brake_decay_rate = 5.2
	rev_brake_sensitivity = 0.90
	strafe_enter_dot_max = 0.78
	reverse_enter_dot_max = 0.10
	hover_slide_micro_amp = 0.16
	hover_slide_micro_hz = 1.85
	auto_cycle_duration_sec = 6.4
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
