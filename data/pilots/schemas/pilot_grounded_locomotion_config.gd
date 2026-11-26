class_name PilotGroundedLocomotionConfig
extends Resource
## Configuración data-driven de locomoción grounded AAA para el Hub 3D (Valentina v2 8-Dir).
## Define la pose de pie relajada (Idle Grounded), ciclo de marcha en 4 fases con Stride-Lock,
## física de pivote/arranque/frenado, escorzo 2.5D y parámetros del motor 3D compartido.

enum PreviewMode {
	AUTO_DEMO_CYCLE = 0,
	GROUNDED_IDLE = 1,
	WALK_STEADY = 2,
	START_STOP_CYCLE = 3,
	PIVOT_TURN = 4,
}

enum GaitStyle {
	WALK_STRIDE = 0,
	MOON_HOP = 1,
	ASTRAL_GLIDE_HOP = 2,
}

const FAMILY_ORDER: Array[String] = ["s", "se", "e", "ne", "n"]
const MUL_KEYS: Array[String] = [
	"bone_stride_scale",
	"persp_25d_scale",
	"arm_swing_scale",
	"pelvis_bounce_scale",
	"torso_twist_scale",
]

@export var anim_id: String = "hub_grounded_walk_aaa"
@export var display_name: String = "Hub 3D Caminata / Trote Grounded AAA"

@export_group("Ritmo y Stride-Lock")
@export var master_intensity: float = 1.0
@export var stride_length_m: float = 4.6
@export var min_walk_speed_norm: float = 0.06
@export var walk_blend_in_rate: float = 7.0
@export var walk_blend_out_rate: float = 6.0
@export var start_lean_duration_sec: float = 0.34
@export var stop_plant_duration_sec: float = 0.36
@export var pivot_duration_sec: float = 0.30
@export var idle_breath_hz: float = 0.34
@export var idle_weight_shift_hz: float = 0.17
@export var auto_demo_cycle_sec: float = 5.2

@export_group("Pelvis, Torso y Cabeza")
@export var pelvis_bounce_down_px: float = 2.6
@export var pelvis_bounce_up_px: float = -2.0
@export var pelvis_sway_x_px: float = 1.4
@export var pelvis_roll_rad: float = 0.022
@export var waist_counter_rad: float = -0.018
@export var chest_counter_rad: float = -0.016
@export var forward_lean_waist_rad: float = 0.030
@export var forward_lean_chest_rad: float = 0.036
@export var neck_stabilize_ratio: float = 0.88
@export var head_bob_lag_px: float = 0.9
@export var head_counter_rot_rad: float = 0.010
@export var torso_yaw_stride: float = 0.028
@export var torso_trap_lean: float = -0.018

@export_group("Ciclo de Piernas (4 Fases)")
@export var thigh_swing_fwd_rad: float = 0.25
@export var thigh_swing_back_rad: float = 0.21
@export var knee_pass_bend_rad: float = 0.38
@export var knee_contact_bend_rad: float = 0.06
@export var knee_down_absorb_rad: float = 0.14
@export var ankle_strike_rad: float = -0.08
@export var ankle_push_rad: float = 0.14

@export_group("Contrabalanceo de Brazos")
@export var arm_shoulder_fwd_rad: float = 0.18
@export var arm_shoulder_back_rad: float = 0.15
@export var arm_elbow_base_rad: float = -0.20
@export var arm_elbow_swing_rad: float = 0.14
@export var arm_wrist_lag_rad: float = 0.08

@export_group("Escorzo 2.5D y Reacción Secundaria")
@export var leg_25d_phi_thigh_amp: float = 0.20
@export var leg_25d_phi_shin_amp: float = 0.24
@export var leg_25d_distal_amp: float = 0.12
@export var leg_25d_depth_amp: float = 0.16
@export var arm_25d_phi1_amp: float = 0.14
@export var arm_25d_phi2_amp: float = 0.16
@export var step_jiggle_bust_impulse: float = 16.0
@export var step_jiggle_glute_impulse: float = 12.0
@export var step_hair_bounce_px: float = 1.4

@export_group("Motor Hub 3D & Contact Juice")
@export var hub_avatar_floor_y: float = 0.008
@export var hub_step_lift_3d_m: float = 0.012
@export var hub_shadow_contact_scale_amp: float = 0.05
@export var hub_move_speed: float = 6.2
@export var hub_accel: float = 18.0
@export var hub_friction: float = 16.0
@export var hub_pivot_brake_mul: float = 2.35
@export var hub_pivot_angle_deg: float = 110.0
@export var footstep_sfx_volume_db: float = -14.0
@export var footstep_vfx_enabled: bool = true

@export_group("Moon Hop (Microgravedad Estilizada)")
@export var gait_style: int = GaitStyle.ASTRAL_GLIDE_HOP
@export var hop_arc_height_rig_px: float = 82.0
@export var hop_crouch_dip_rig_px: float = 6.0
@export var hop_contact_duty: float = 0.28
@export var hop_squash_amount: float = 0.055
@export var hop_stretch_amount: float = 0.032
@export var hop_leg_tuck_thigh_rad: float = 0.24
@export var hop_leg_tuck_knee_rad: float = 0.42
@export var hop_leg_crouch_knee_rad: float = 0.26
@export var hop_leg_asym_ratio: float = 0.32
@export var hop_ankle_point_rad: float = 0.26
@export var hop_arm_float_rad: float = 0.22
@export var hop_forward_lean_rad: float = 0.065
@export var hop_hair_float_px: float = 5.5
@export var hop_shadow_shrink_ratio: float = 0.46
@export var hop_shadow_alpha_fade: float = 0.52
@export var hop_visual_sole_offset_y_px: float = 76.0
@export var hop_landing_ripple_enabled: bool = true
@export var hop_landing_ripple_radius_px: float = 26.0
@export var hop_landing_ripple_duration_sec: float = 0.34

@export_group("Astral Glide-Hop (Jeté Grácil)")
@export var glide_stride_length_m: float = 12.0
@export var glide_contact_duty: float = 0.09
@export var glide_arc_height_rig_px: float = 90.0
@export var glide_arc_hang_power: float = 0.72
@export var glide_arc_peak_shift: float = 0.44
@export var glide_crouch_dip_rig_px: float = 5.0
@export var glide_squash_amount: float = 0.048
@export var glide_stretch_amount: float = 0.046
@export var glide_3d_lift_m: float = 0.60
@export var glide_lead_thigh_fwd_rad: float = 0.30
@export var glide_lead_knee_poise_rad: float = 0.34
@export var glide_trail_thigh_back_rad: float = 0.34
@export var glide_trail_knee_sweep_rad: float = 0.25
@export var glide_ankle_point_rad: float = 0.30
@export var glide_ankle_reach_rad: float = -0.10
@export var glide_rebound_knee_rad: float = 0.28
@export var glide_25d_leg_depth_amp: float = 0.28
@export var glide_forward_lean_rad: float = 0.085
@export var glide_torso_bank_rad: float = 0.032
@export var glide_arm_grace_rad: float = 0.20
@export var glide_arm_elbow_soft_rad: float = 0.22
@export var glide_hair_trail_px: float = 6.2

@export_group("Ripple Astral de Rebote")
@export var ripple_enabled: bool = true
@export var ripple_outer_radius_m: float = 0.78
@export var ripple_inner_radius_m: float = 0.41
@export var ripple_duration_sec: float = 0.48
@export var ripple_intensity: float = 1.15
@export var ripple_use_skin_accent: bool = true
@export var ripple_fallback_color: Color = Color(0.55, 0.88, 1.0, 1.0)
@export var ripple_spark_count: int = 5

@export_group("Familias Direccionales (8-Dir)")
@export var standing_families: Dictionary = {}
@export var family_multipliers: Dictionary = {}


func _init() -> void:
	ensure_initialized()


static func build_default_standing_families() -> Dictionary:
	return {
		"s": {
			"pelvis_rot": -0.014,
			"waist_rot": 0.018,
			"chest_rot": 0.012,
			"neck_rot": -0.016,
			"torso_trap": -0.016,
			"torso_yaw": 0.010,
			"shoulder_lead_rot": 0.045,
			"elbow_lead_rot": -0.065,
			"wrist_lead_rot": -0.030,
			"shoulder_trail_rot": -0.055,
			"elbow_trail_rot": 0.060,
			"wrist_trail_rot": 0.025,
			"pauldron_follow_ratio": 0.48,
			"arm_lead_phi1": 0.025,
			"arm_lead_phi2": -0.045,
			"arm_trail_phi1": 0.020,
			"arm_trail_phi2": -0.040,
			"thigh_lead_rot": -0.146,
			"knee_lead_rot": -0.058,
			"ankle_lead_rot": 0.085,
			"thigh_trail_rot": 0.146,
			"knee_trail_rot": 0.058,
			"ankle_trail_rot": -0.085,
			"leg_lead_phi_thigh": 0.020,
			"leg_lead_phi_shin": -0.030,
			"leg_lead_distal_amp": -0.010,
			"leg_lead_depth_phase": 0.030,
			"leg_lead_pivot_v": 0.445,
			"leg_trail_phi_thigh": 0.010,
			"leg_trail_phi_shin": -0.020,
			"leg_trail_distal_amp": -0.008,
			"leg_trail_depth_phase": -0.025,
			"leg_trail_pivot_v": 0.445,
		},
		"se": {
			"pelvis_rot": 0.010,
			"waist_rot": 0.016,
			"chest_rot": 0.020,
			"neck_rot": -0.036,
			"torso_trap": -0.014,
			"torso_yaw": 0.014,
			"shoulder_lead_rot": -0.045,
			"elbow_lead_rot": -0.085,
			"wrist_lead_rot": -0.025,
			"shoulder_trail_rot": 0.045,
			"elbow_trail_rot": -0.075,
			"wrist_trail_rot": -0.025,
			"pauldron_follow_ratio": 0.48,
			"arm_lead_phi1": 0.025,
			"arm_lead_phi2": -0.050,
			"arm_trail_phi1": -0.020,
			"arm_trail_phi2": -0.040,
			"thigh_lead_rot": 0.108,
			"knee_lead_rot": 0.058,
			"ankle_lead_rot": -0.065,
			"thigh_trail_rot": -0.120,
			"knee_trail_rot": -0.082,
			"ankle_trail_rot": 0.075,
			"leg_lead_phi_thigh": 0.022,
			"leg_lead_phi_shin": -0.035,
			"leg_lead_distal_amp": -0.012,
			"leg_lead_depth_phase": 0.035,
			"leg_lead_pivot_v": 0.460,
			"leg_trail_phi_thigh": 0.012,
			"leg_trail_phi_shin": -0.025,
			"leg_trail_distal_amp": -0.010,
			"leg_trail_depth_phase": -0.035,
			"leg_trail_pivot_v": 0.433,
		},
		"e": {
			"pelvis_rot": 0.010,
			"waist_rot": 0.018,
			"chest_rot": 0.022,
			"neck_rot": -0.035,
			"torso_trap": -0.010,
			"torso_yaw": 0.010,
			"shoulder_lead_rot": -0.060,
			"elbow_lead_rot": -0.120,
			"wrist_lead_rot": -0.020,
			"shoulder_trail_rot": 0.050,
			"elbow_trail_rot": -0.140,
			"wrist_trail_rot": -0.020,
			"pauldron_follow_ratio": 0.46,
			"arm_lead_phi1": 0.020,
			"arm_lead_phi2": -0.035,
			"arm_trail_phi1": -0.015,
			"arm_trail_phi2": -0.030,
			"thigh_lead_rot": -0.045,
			"knee_lead_rot": 0.055,
			"ankle_lead_rot": 0.000,
			"thigh_trail_rot": 0.035,
			"knee_trail_rot": 0.030,
			"ankle_trail_rot": 0.000,
			"leg_lead_phi_thigh": 0.018,
			"leg_lead_phi_shin": -0.025,
			"leg_lead_distal_amp": -0.010,
			"leg_lead_depth_phase": -0.680,
			"leg_lead_pivot_v": 0.440,
			"leg_trail_phi_thigh": 0.012,
			"leg_trail_phi_shin": -0.020,
			"leg_trail_distal_amp": -0.008,
			"leg_trail_depth_phase": 0.650,
			"leg_trail_pivot_v": 0.440,
		},
		"ne": {
			"pelvis_rot": 0.008,
			"waist_rot": 0.014,
			"chest_rot": 0.018,
			"neck_rot": -0.030,
			"torso_trap": 0.014,
			"torso_yaw": -0.012,
			"shoulder_lead_rot": 0.055,
			"elbow_lead_rot": 0.065,
			"wrist_lead_rot": 0.025,
			"shoulder_trail_rot": -0.065,
			"elbow_trail_rot": -0.095,
			"wrist_trail_rot": -0.025,
			"pauldron_follow_ratio": 0.48,
			"arm_lead_phi1": -0.025,
			"arm_lead_phi2": 0.040,
			"arm_trail_phi1": 0.020,
			"arm_trail_phi2": 0.035,
			"thigh_lead_rot": -0.122,
			"knee_lead_rot": -0.088,
			"ankle_lead_rot": 0.075,
			"thigh_trail_rot": 0.094,
			"knee_trail_rot": 0.070,
			"ankle_trail_rot": -0.060,
			"leg_lead_phi_thigh": -0.020,
			"leg_lead_phi_shin": 0.035,
			"leg_lead_distal_amp": 0.012,
			"leg_lead_depth_phase": -0.035,
			"leg_lead_pivot_v": 0.460,
			"leg_trail_phi_thigh": -0.012,
			"leg_trail_phi_shin": 0.025,
			"leg_trail_distal_amp": 0.010,
			"leg_trail_depth_phase": 0.035,
			"leg_trail_pivot_v": 0.433,
		},
		"n": {
			"pelvis_rot": 0.010,
			"waist_rot": -0.012,
			"chest_rot": -0.010,
			"neck_rot": 0.014,
			"torso_trap": 0.016,
			"torso_yaw": -0.010,
			"shoulder_lead_rot": -0.045,
			"elbow_lead_rot": -0.055,
			"wrist_lead_rot": -0.025,
			"shoulder_trail_rot": 0.045,
			"elbow_trail_rot": 0.045,
			"wrist_trail_rot": 0.020,
			"pauldron_follow_ratio": 0.48,
			"arm_lead_phi1": -0.025,
			"arm_lead_phi2": 0.045,
			"arm_trail_phi1": -0.020,
			"arm_trail_phi2": 0.035,
			"thigh_lead_rot": 0.104,
			"knee_lead_rot": 0.094,
			"ankle_lead_rot": -0.070,
			"thigh_trail_rot": -0.104,
			"knee_trail_rot": -0.094,
			"ankle_trail_rot": 0.070,
			"leg_lead_phi_thigh": -0.020,
			"leg_lead_phi_shin": 0.035,
			"leg_lead_distal_amp": 0.012,
			"leg_lead_depth_phase": -0.035,
			"leg_lead_pivot_v": 0.445,
			"leg_trail_phi_thigh": -0.012,
			"leg_trail_phi_shin": 0.025,
			"leg_trail_distal_amp": 0.010,
			"leg_trail_depth_phase": 0.030,
			"leg_trail_pivot_v": 0.445,
		},
	}


static func build_default_family_multipliers() -> Dictionary:
	return {
		"s": {"bone_stride_scale": 0.00, "persp_25d_scale": 1.25, "arm_swing_scale": 0.25, "pelvis_bounce_scale": 1.00, "torso_twist_scale": 1.15},
		"se": {"bone_stride_scale": 0.30, "persp_25d_scale": 1.00, "arm_swing_scale": 0.65, "pelvis_bounce_scale": 1.00, "torso_twist_scale": 0.95},
		"e": {"bone_stride_scale": 0.95, "persp_25d_scale": 0.22, "arm_swing_scale": 0.95, "pelvis_bounce_scale": 1.05, "torso_twist_scale": 0.55},
		"ne": {"bone_stride_scale": 0.30, "persp_25d_scale": 1.00, "arm_swing_scale": 0.65, "pelvis_bounce_scale": 1.00, "torso_twist_scale": 0.95},
		"n": {"bone_stride_scale": 0.00, "persp_25d_scale": 1.25, "arm_swing_scale": 0.25, "pelvis_bounce_scale": 1.00, "torso_twist_scale": 1.15},
	}


func ensure_initialized() -> void:
	var def_stand: Dictionary = build_default_standing_families()
	for fam: String in FAMILY_ORDER:
		var def_f: Dictionary = def_stand[fam] as Dictionary
		if not standing_families.has(fam) or not (standing_families[fam] is Dictionary):
			standing_families[fam] = def_f.duplicate(true)
		else:
			var cur_f: Dictionary = standing_families[fam] as Dictionary
			for k_v: Variant in def_f.keys():
				var k: String = str(k_v)
				if not cur_f.has(k):
					cur_f[k] = def_f[k]

	var def_muls: Dictionary = build_default_family_multipliers()
	for fam: String in FAMILY_ORDER:
		var def_m: Dictionary = def_muls[fam] as Dictionary
		if not family_multipliers.has(fam) or not (family_multipliers[fam] is Dictionary):
			family_multipliers[fam] = def_m.duplicate(true)
		else:
			var cur_m: Dictionary = family_multipliers[fam] as Dictionary
			for mk: String in MUL_KEYS:
				if not cur_m.has(mk):
					cur_m[mk] = float(def_m[mk])


func get_standing_family(fam: String) -> Dictionary:
	ensure_initialized()
	if standing_families.has(fam):
		return standing_families[fam] as Dictionary
	return standing_families.get("s", {}) as Dictionary


func get_family_mul(fam: String, key: String) -> float:
	ensure_initialized()
	if family_multipliers.has(fam):
		var fm: Dictionary = family_multipliers[fam] as Dictionary
		if fm.has(key):
			return float(fm[key])
	return 1.0


func reset_defaults() -> void:
	master_intensity = 1.0
	stride_length_m = 4.6
	min_walk_speed_norm = 0.06
	walk_blend_in_rate = 7.0
	walk_blend_out_rate = 6.0
	start_lean_duration_sec = 0.34
	stop_plant_duration_sec = 0.36
	pivot_duration_sec = 0.30
	idle_breath_hz = 0.34
	idle_weight_shift_hz = 0.17
	auto_demo_cycle_sec = 5.2

	pelvis_bounce_down_px = 2.6
	pelvis_bounce_up_px = -2.0
	pelvis_sway_x_px = 1.4
	pelvis_roll_rad = 0.022
	waist_counter_rad = -0.018
	chest_counter_rad = -0.016
	forward_lean_waist_rad = 0.030
	forward_lean_chest_rad = 0.036
	neck_stabilize_ratio = 0.88
	head_bob_lag_px = 0.9
	head_counter_rot_rad = 0.010
	torso_yaw_stride = 0.028
	torso_trap_lean = -0.018

	thigh_swing_fwd_rad = 0.25
	thigh_swing_back_rad = 0.21
	knee_pass_bend_rad = 0.38
	knee_contact_bend_rad = 0.06
	knee_down_absorb_rad = 0.14
	ankle_strike_rad = -0.08
	ankle_push_rad = 0.14

	arm_shoulder_fwd_rad = 0.18
	arm_shoulder_back_rad = 0.15
	arm_elbow_base_rad = -0.20
	arm_elbow_swing_rad = 0.14
	arm_wrist_lag_rad = 0.08

	leg_25d_phi_thigh_amp = 0.20
	leg_25d_phi_shin_amp = 0.24
	leg_25d_distal_amp = 0.12
	leg_25d_depth_amp = 0.16
	arm_25d_phi1_amp = 0.14
	arm_25d_phi2_amp = 0.16
	step_jiggle_bust_impulse = 16.0
	step_jiggle_glute_impulse = 12.0
	step_hair_bounce_px = 1.4

	hub_avatar_floor_y = 0.008
	hub_step_lift_3d_m = 0.012
	hub_shadow_contact_scale_amp = 0.05
	hub_move_speed = 6.2
	hub_accel = 18.0
	hub_friction = 16.0
	hub_pivot_brake_mul = 2.35
	hub_pivot_angle_deg = 110.0
	footstep_sfx_volume_db = -14.0
	footstep_vfx_enabled = true

	gait_style = GaitStyle.ASTRAL_GLIDE_HOP
	hop_arc_height_rig_px = 82.0
	hop_crouch_dip_rig_px = 6.0
	hop_contact_duty = 0.28
	hop_squash_amount = 0.055
	hop_stretch_amount = 0.032
	hop_leg_tuck_thigh_rad = 0.24
	hop_leg_tuck_knee_rad = 0.42
	hop_leg_crouch_knee_rad = 0.26
	hop_leg_asym_ratio = 0.32
	hop_ankle_point_rad = 0.26
	hop_arm_float_rad = 0.22
	hop_forward_lean_rad = 0.065
	hop_hair_float_px = 5.5
	hop_shadow_shrink_ratio = 0.46
	hop_shadow_alpha_fade = 0.52
	hop_visual_sole_offset_y_px = 76.0
	hop_landing_ripple_enabled = true
	hop_landing_ripple_radius_px = 26.0
	hop_landing_ripple_duration_sec = 0.34

	glide_stride_length_m = 12.0
	glide_contact_duty = 0.09
	glide_arc_height_rig_px = 90.0
	glide_arc_hang_power = 0.72
	glide_arc_peak_shift = 0.44
	glide_crouch_dip_rig_px = 5.0
	glide_squash_amount = 0.048
	glide_stretch_amount = 0.046
	glide_3d_lift_m = 0.60
	glide_lead_thigh_fwd_rad = 0.30
	glide_lead_knee_poise_rad = 0.34
	glide_trail_thigh_back_rad = 0.34
	glide_trail_knee_sweep_rad = 0.25
	glide_ankle_point_rad = 0.30
	glide_ankle_reach_rad = -0.10
	glide_rebound_knee_rad = 0.28
	glide_25d_leg_depth_amp = 0.28
	glide_forward_lean_rad = 0.085
	glide_torso_bank_rad = 0.032
	glide_arm_grace_rad = 0.20
	glide_arm_elbow_soft_rad = 0.22
	glide_hair_trail_px = 6.2

	ripple_enabled = true
	ripple_outer_radius_m = 0.78
	ripple_inner_radius_m = 0.41
	ripple_duration_sec = 0.48
	ripple_intensity = 1.15
	ripple_use_skin_accent = true
	ripple_fallback_color = Color(0.55, 0.88, 1.0, 1.0)
	ripple_spark_count = 5

	standing_families = build_default_standing_families()
	family_multipliers = build_default_family_multipliers()
