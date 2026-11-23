class_name PilotBasePoseConfig
extends Resource
## Configuración data-driven de pose base estática Zero-G por familia direccional (s, se, e, ne, n).
## Las vistas izquierdas (sw, w, nw) derivan por simetría geométrica de se, e y ne.

const FAMILY_ORDER: Array[String] = ["s", "se", "e", "ne", "n"]
const FAMILY_LABELS: Dictionary = {
	"s": "S (Frente)",
	"se": "SE / SW (Diag. Frontal)",
	"e": "E / W (Perfil)",
	"ne": "NE / NW (Diag. Trasera)",
	"n": "N (Espalda)",
}

@export var pose_id: String = "tactical_zero_g"
@export var display_name: String = "Guardia Táctica Zero-G"
@export var families: Dictionary = {}


func _init() -> void:
	ensure_initialized()


static func canonical_family_for_view(view_key: String) -> String:
	match view_key:
		"se", "sw":
			return "se"
		"e", "w":
			return "e"
		"ne", "nw":
			return "ne"
		"n":
			return "n"
		_:
			return "s"


static func build_default_tactical_zero_g_families() -> Dictionary:
	return {
		"s": {
			"pelvis_rot": -0.012,
			"waist_rot": 0.018,
			"chest_rot": 0.014,
			"neck_rot": -0.020,
			"torso_trap": -0.032,
			"torso_yaw": 0.015,
			"shoulder_lead_rot": 0.055,
			"elbow_lead_rot": -0.048,
			"wrist_lead_rot": -0.045,
			"shoulder_trail_rot": -0.068,
			"elbow_trail_rot": 0.052,
			"wrist_trail_rot": 0.040,
			"pauldron_follow_ratio": 0.48,
			"arm_lead_phi1": 0.065,
			"arm_lead_phi2": -0.115,
			"arm_trail_phi1": 0.045,
			"arm_trail_phi2": -0.085,
			"thigh_lead_rot": -0.038,
			"knee_lead_rot": 0.062,
			"ankle_lead_rot": 0.045,
			"thigh_trail_rot": 0.028,
			"knee_trail_rot": -0.042,
			"ankle_trail_rot": -0.035,
			"leg_lead_phi_thigh": 0.085,
			"leg_lead_phi_shin": -0.165,
			"leg_lead_distal_amp": -0.085,
			"leg_lead_depth_phase": 0.055,
			"leg_lead_pivot_v": 0.445,
			"leg_trail_phi_thigh": 0.052,
			"leg_trail_phi_shin": -0.110,
			"leg_trail_distal_amp": -0.060,
			"leg_trail_depth_phase": -0.045,
			"leg_trail_pivot_v": 0.445,
		},
		"se": {
			"pelvis_rot": 0.018,
			"waist_rot": 0.032,
			"chest_rot": 0.038,
			"neck_rot": -0.068,
			"torso_trap": -0.028,
			"torso_yaw": 0.024,
			"shoulder_lead_rot": -0.085,
			"elbow_lead_rot": -0.072,
			"wrist_lead_rot": -0.045,
			"shoulder_trail_rot": 0.082,
			"elbow_trail_rot": -0.065,
			"wrist_trail_rot": -0.040,
			"pauldron_follow_ratio": 0.48,
			"arm_lead_phi1": 0.070,
			"arm_lead_phi2": -0.120,
			"arm_trail_phi1": -0.045,
			"arm_trail_phi2": -0.095,
			"thigh_lead_rot": -0.022,
			"knee_lead_rot": 0.145,
			"ankle_lead_rot": 0.110,
			"thigh_trail_rot": 0.024,
			"knee_trail_rot": 0.085,
			"ankle_trail_rot": 0.075,
			"leg_lead_phi_thigh": 0.085,
			"leg_lead_phi_shin": -0.155,
			"leg_lead_distal_amp": -0.075,
			"leg_lead_depth_phase": 0.045,
			"leg_lead_pivot_v": 0.460,
			"leg_trail_phi_thigh": 0.045,
			"leg_trail_phi_shin": -0.115,
			"leg_trail_distal_amp": -0.065,
			"leg_trail_depth_phase": -0.055,
			"leg_trail_pivot_v": 0.433,
		},
		"e": {
			"pelvis_rot": 0.025,
			"waist_rot": 0.048,
			"chest_rot": 0.055,
			"neck_rot": -0.095,
			"torso_trap": -0.020,
			"torso_yaw": 0.015,
			"shoulder_lead_rot": -0.280,
			"elbow_lead_rot": -0.360,
			"wrist_lead_rot": -0.080,
			"shoulder_trail_rot": 0.140,
			"elbow_trail_rot": -0.420,
			"wrist_trail_rot": -0.065,
			"pauldron_follow_ratio": 0.46,
			"arm_lead_phi1": 0.045,
			"arm_lead_phi2": -0.075,
			"arm_trail_phi1": -0.035,
			"arm_trail_phi2": -0.065,
			"thigh_lead_rot": -0.185,
			"knee_lead_rot": 0.280,
			"ankle_lead_rot": 0.165,
			"thigh_trail_rot": 0.115,
			"knee_trail_rot": 0.190,
			"ankle_trail_rot": 0.185,
			"leg_lead_phi_thigh": 0.045,
			"leg_lead_phi_shin": -0.075,
			"leg_lead_distal_amp": -0.050,
			"leg_lead_depth_phase": -0.680,
			"leg_lead_pivot_v": 0.440,
			"leg_trail_phi_thigh": 0.030,
			"leg_trail_phi_shin": -0.055,
			"leg_trail_distal_amp": -0.040,
			"leg_trail_depth_phase": 0.650,
			"leg_trail_pivot_v": 0.440,
		},
		"ne": {
			"pelvis_rot": 0.016,
			"waist_rot": 0.028,
			"chest_rot": 0.034,
			"neck_rot": -0.060,
			"torso_trap": 0.024,
			"torso_yaw": -0.020,
			"shoulder_lead_rot": 0.120,
			"elbow_lead_rot": 0.145,
			"wrist_lead_rot": 0.050,
			"shoulder_trail_rot": -0.140,
			"elbow_trail_rot": -0.210,
			"wrist_trail_rot": -0.060,
			"pauldron_follow_ratio": 0.48,
			"arm_lead_phi1": -0.055,
			"arm_lead_phi2": 0.085,
			"arm_trail_phi1": 0.040,
			"arm_trail_phi2": 0.070,
			"thigh_lead_rot": -0.025,
			"knee_lead_rot": 0.055,
			"ankle_lead_rot": 0.045,
			"thigh_trail_rot": 0.038,
			"knee_trail_rot": 0.115,
			"ankle_trail_rot": 0.110,
			"leg_lead_phi_thigh": -0.065,
			"leg_lead_phi_shin": 0.155,
			"leg_lead_distal_amp": 0.070,
			"leg_lead_depth_phase": -0.050,
			"leg_lead_pivot_v": 0.460,
			"leg_trail_phi_thigh": -0.040,
			"leg_trail_phi_shin": 0.095,
			"leg_trail_distal_amp": 0.050,
			"leg_trail_depth_phase": 0.045,
			"leg_trail_pivot_v": 0.433,
		},
		"n": {
			"pelvis_rot": 0.012,
			"waist_rot": -0.016,
			"chest_rot": -0.014,
			"neck_rot": 0.018,
			"torso_trap": 0.030,
			"torso_yaw": -0.015,
			"shoulder_lead_rot": -0.062,
			"elbow_lead_rot": -0.055,
			"wrist_lead_rot": -0.040,
			"shoulder_trail_rot": 0.052,
			"elbow_trail_rot": 0.048,
			"wrist_trail_rot": 0.035,
			"pauldron_follow_ratio": 0.48,
			"arm_lead_phi1": -0.055,
			"arm_lead_phi2": 0.095,
			"arm_trail_phi1": -0.040,
			"arm_trail_phi2": 0.075,
			"thigh_lead_rot": -0.026,
			"knee_lead_rot": -0.058,
			"ankle_lead_rot": 0.048,
			"thigh_trail_rot": 0.022,
			"knee_trail_rot": 0.042,
			"ankle_trail_rot": -0.036,
			"leg_lead_phi_thigh": -0.065,
			"leg_lead_phi_shin": 0.145,
			"leg_lead_distal_amp": 0.075,
			"leg_lead_depth_phase": -0.050,
			"leg_lead_pivot_v": 0.445,
			"leg_trail_phi_thigh": -0.045,
			"leg_trail_phi_shin": 0.105,
			"leg_trail_distal_amp": 0.055,
			"leg_trail_depth_phase": 0.040,
			"leg_trail_pivot_v": 0.445,
		},
	}


func ensure_initialized() -> void:
	var defaults: Dictionary = build_default_tactical_zero_g_families()
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
	families = build_default_tactical_zero_g_families()


func reset_family_to_defaults(fam: String) -> void:
	var defaults: Dictionary = build_default_tactical_zero_g_families()
	var can_fam: String = canonical_family_for_view(fam)
	if defaults.has(can_fam):
		families[can_fam] = (defaults[can_fam] as Dictionary).duplicate(true)


func get_family_dict(fam: String) -> Dictionary:
	ensure_initialized()
	var can_fam: String = canonical_family_for_view(fam)
	return families.get(can_fam, {}) as Dictionary


func get_param(fam: String, key: String) -> float:
	var d: Dictionary = get_family_dict(fam)
	return float(d.get(key, 0.0))


func set_param(fam: String, key: String, val: float) -> void:
	ensure_initialized()
	var can_fam: String = canonical_family_for_view(fam)
	var d: Dictionary = families.get(can_fam, {}) as Dictionary
	d[key] = val
	families[can_fam] = d
