class_name RigPerspectiveConfig
extends Resource
## Configuración data-driven para Falsa Perspectiva 2.5D Post-Skinning (15 FPS Sakuga).
## Almacena constantes ópticas, piso Jacobiano, curvas Tick 0..8, tintes de profundidad
## y perfiles de coreografía por vista (8 direcciones) y estado de combate.

@export_group("Óptica y Límites Jacobianos")
@export var cam_tan_alpha: float = 0.1315
@export var jacobian_floor: float = 0.22
@export var k_conicity: float = 0.16
@export var k_volume: float = 0.14
@export var head_scale_ratio: float = 0.60
@export var max_pitch_rad: float = 1.309 # 75 grados

@export_group("Curvas Sakuga 15 FPS (Tick 0..8)")
@export var tick_distal_amps: PackedFloat32Array = PackedFloat32Array([0.0, -0.08, 0.24, 0.18, 0.18, 0.18, 0.12, 0.04, 0.0])
@export var tick_torso_trapezoids: PackedFloat32Array = PackedFloat32Array([0.0, -0.06, 0.16, 0.14, 0.14, 0.14, 0.08, 0.02, 0.0])
@export var tick_head_scale_offsets: PackedFloat32Array = PackedFloat32Array([0.0, -0.036, 0.096, 0.084, 0.084, 0.084, 0.048, 0.012, 0.0])
@export var tick_coil_phi_offset_rad: float = -0.2618 # -15 grados en Tick 1 Coil

@export_group("Profundidad, Vista N y Ruptura de Gemelo E/W")
@export var depth_near_tint: Color = Color(1.08, 1.06, 1.02, 1.0)
@export var depth_far_tint: Color = Color(0.76, 0.80, 0.92, 1.0)
@export var rim_occlusion_color: Color = Color(0.35, 0.75, 1.0, 1.0)
@export var n_knee_external_rot_rad: float = 0.1396 # 8 grados ("tangente rota")
@export var n_rim_z_threshold: float = 0.35
@export var ew_front_depth_weight: float = 0.65
@export var ew_back_depth_weight: float = -0.75
@export var pauldron_trapezoid_span_px: float = 14.0

@export_group("Turnaround 3-Tick (WHIP_SNAP_AFTERIMAGE)")
@export var whip_pre_yaw_twist: float = -0.14
@export var whip_swap_yaw_twist: float = 0.18
@export var whip_settle_yaw_twist: float = -0.08
@export var whip_pre_rim_sweep: float = -0.60
@export var whip_swap_rim_sweep: float = 1.00
@export var whip_settle_rim_sweep: float = -0.35
@export var whip_lead_arm_phi: float = 0.6109 # 35 grados
@export var whip_pauldron_shift_px: float = 4.5
@export var whip_head_settle_bounce: float = 1.04
@export var whip_swap_t_end: float = 0.72

@export_group("Perfiles por Estado y Vista")
@export var state_profiles: Dictionary = {
	"IDLE_HOVER": {
		"s": {
			"torso_trapezoid": 0.0, "distal_amp": 0.0, "toe_heel_bias": 0.0,
			"leg_r_phi1": 0.21, "leg_r_phi2": -0.06, "leg_r_depth": 0.18,
			"leg_l_phi1": -0.18, "leg_l_phi2": -0.10, "leg_l_depth": -0.10,
			"arm_r_phi1": 0.06, "arm_r_phi2": 0.08, "arm_l_phi1": -0.05, "arm_l_phi2": 0.04,
		},
		"se_sw": {
			"torso_trapezoid": 0.0, "distal_amp": 0.0, "toe_heel_bias": 0.0,
			"leg_r_phi1": 0.16, "leg_r_phi2": -0.05, "leg_r_depth": 0.15,
			"leg_l_phi1": -0.22, "leg_l_phi2": -0.15, "leg_l_depth": -0.22,
			"arm_r_phi1": 0.10, "arm_r_phi2": 0.12, "arm_l_phi1": -0.14, "arm_l_phi2": -0.06,
		},
		"e_w": {
			"torso_trapezoid": 0.0, "distal_amp": 0.0, "toe_heel_bias": 0.0,
			"leg_r_phi1": 0.14, "leg_r_phi2": -0.04, "leg_r_depth": 0.65,
			"leg_l_phi1": -0.18, "leg_l_phi2": -0.16, "leg_l_depth": -0.75,
			"arm_r_phi1": 0.12, "arm_r_phi2": 0.14, "arm_l_phi1": -0.18, "arm_l_phi2": -0.10,
		},
		"ne_nw": {
			"torso_trapezoid": 0.0, "distal_amp": 0.0, "toe_heel_bias": -0.10,
			"leg_r_phi1": 0.12, "leg_r_phi2": 0.10, "leg_r_depth": 0.12,
			"leg_l_phi1": -0.16, "leg_l_phi2": -0.08, "leg_l_depth": -0.18,
			"arm_r_phi1": 0.12, "arm_r_phi2": 0.06, "arm_l_phi1": -0.10, "arm_l_phi2": -0.04,
		},
		"n": {
			"torso_trapezoid": 0.0, "distal_amp": 0.04, "toe_heel_bias": -0.25,
			"leg_r_phi1": -0.12, "leg_r_phi2": 0.42, "leg_r_depth": 0.36,
			"leg_l_phi1": -0.08, "leg_l_phi2": -0.14, "leg_l_depth": -0.15,
			"arm_r_phi1": 0.08, "arm_r_phi2": 0.10, "arm_l_phi1": 0.08, "arm_l_phi2": 0.10,
		},
	},
	"DASH": {
		"s": {
			"torso_trapezoid": 0.16, "distal_amp": 0.18, "toe_heel_bias": 0.25,
			"leg_r_phi1": -0.35, "leg_r_phi2": -0.58, "leg_r_depth": -0.55,
			"leg_l_phi1": -0.40, "leg_l_phi2": -0.55, "leg_l_depth": -0.55,
			"arm_r_phi1": -0.28, "arm_r_phi2": -0.35, "arm_l_phi1": -0.28, "arm_l_phi2": -0.35,
		},
		"se_sw": {
			"torso_trapezoid": 0.14, "distal_amp": 0.18, "toe_heel_bias": 0.20,
			"leg_r_phi1": 0.35, "leg_r_phi2": -0.52, "leg_r_depth": 0.35,
			"leg_l_phi1": -0.32, "leg_l_phi2": -0.48, "leg_l_depth": -0.50,
			"arm_r_phi1": 0.24, "arm_r_phi2": 0.32, "arm_l_phi1": -0.30, "arm_l_phi2": -0.40,
		},
		"e_w": {
			"torso_trapezoid": 0.10, "distal_amp": 0.14, "toe_heel_bias": 0.15,
			"leg_r_phi1": 0.24, "leg_r_phi2": -0.36, "leg_r_depth": 0.65,
			"leg_l_phi1": -0.28, "leg_l_phi2": -0.44, "leg_l_depth": -0.75,
			"arm_r_phi1": -0.20, "arm_r_phi2": -0.30, "arm_l_phi1": -0.26, "arm_l_phi2": -0.35,
		},
		"ne_nw": {
			"torso_trapezoid": -0.16, "distal_amp": 0.24, "toe_heel_bias": -0.35,
			"leg_r_phi1": -0.22, "leg_r_phi2": 0.56, "leg_r_depth": 0.50,
			"leg_l_phi1": -0.26, "leg_l_phi2": 0.50, "leg_l_depth": 0.45,
			"arm_r_phi1": -0.24, "arm_r_phi2": -0.30, "arm_l_phi1": -0.24, "arm_l_phi2": -0.30,
		},
		"n": {
			"torso_trapezoid": -0.16, "distal_amp": 0.24, "toe_heel_bias": -0.40,
			"leg_r_phi1": -0.28, "leg_r_phi2": 0.68, "leg_r_depth": 0.58,
			"leg_l_phi1": -0.20, "leg_l_phi2": 0.56, "leg_l_depth": 0.48,
			"arm_r_phi1": -0.22, "arm_r_phi2": -0.28, "arm_l_phi1": -0.22, "arm_l_phi2": -0.28,
		},
	},
	"AIR_BRAKE": {
		"s": {
			"torso_trapezoid": -0.14, "distal_amp": 0.20, "toe_heel_bias": 0.30,
			"leg_r_phi1": 0.46, "leg_r_phi2": 0.26, "leg_r_depth": 0.45,
			"leg_l_phi1": 0.22, "leg_l_phi2": -0.12, "leg_l_depth": 0.15,
			"arm_r_phi1": 0.26, "arm_r_phi2": 0.34, "arm_l_phi1": 0.22, "arm_l_phi2": 0.28,
		},
		"se_sw": {
			"torso_trapezoid": -0.12, "distal_amp": 0.22, "toe_heel_bias": 0.25,
			"leg_r_phi1": 0.48, "leg_r_phi2": 0.30, "leg_r_depth": 0.50,
			"leg_l_phi1": -0.16, "leg_l_phi2": -0.24, "leg_l_depth": -0.28,
			"arm_r_phi1": 0.28, "arm_r_phi2": 0.36, "arm_l_phi1": -0.35, "arm_l_phi2": -0.45,
		},
		"e_w": {
			"torso_trapezoid": -0.10, "distal_amp": 0.16, "toe_heel_bias": 0.20,
			"leg_r_phi1": 0.34, "leg_r_phi2": 0.18, "leg_r_depth": 0.65,
			"leg_l_phi1": -0.20, "leg_l_phi2": -0.18, "leg_l_depth": -0.75,
			"arm_r_phi1": 0.30, "arm_r_phi2": 0.36, "arm_l_phi1": -0.22, "arm_l_phi2": -0.20,
		},
		"ne_nw": {
			"torso_trapezoid": 0.12, "distal_amp": 0.14, "toe_heel_bias": -0.20,
			"leg_r_phi1": -0.12, "leg_r_phi2": -0.24, "leg_r_depth": -0.20,
			"leg_l_phi1": 0.16, "leg_l_phi2": 0.22, "leg_l_depth": 0.24,
			"arm_r_phi1": 0.24, "arm_r_phi2": 0.30, "arm_l_phi1": 0.20, "arm_l_phi2": 0.24,
		},
		"n": {
			"torso_trapezoid": 0.14, "distal_amp": 0.12, "toe_heel_bias": -0.20,
			"leg_r_phi1": -0.18, "leg_r_phi2": -0.28, "leg_r_depth": -0.25,
			"leg_l_phi1": -0.14, "leg_l_phi2": -0.24, "leg_l_depth": -0.20,
			"arm_r_phi1": 0.24, "arm_r_phi2": 0.28, "arm_l_phi1": 0.24, "arm_l_phi2": 0.28,
		},
	},
	"ATTACK_RECOIL": {
		"s": {
			"torso_trapezoid": -0.15, "distal_amp": 0.20, "toe_heel_bias": 0.15,
			"leg_r_phi1": 0.22, "leg_r_phi2": -0.14, "leg_r_depth": 0.20,
			"leg_l_phi1": -0.16, "leg_l_phi2": -0.18, "leg_l_depth": -0.18,
			"arm_r_phi1": 0.38, "arm_r_phi2": 0.56, "arm_l_phi1": -0.18, "arm_l_phi2": -0.24,
		},
		"se_sw": {
			"torso_trapezoid": -0.14, "distal_amp": 0.20, "toe_heel_bias": 0.15,
			"leg_r_phi1": 0.20, "leg_r_phi2": -0.12, "leg_r_depth": 0.22,
			"leg_l_phi1": -0.20, "leg_l_phi2": -0.22, "leg_l_depth": -0.24,
			"arm_r_phi1": 0.42, "arm_r_phi2": 0.52, "arm_l_phi1": -0.22, "arm_l_phi2": -0.28,
		},
		"e_w": {
			"torso_trapezoid": -0.10, "distal_amp": 0.18, "toe_heel_bias": 0.10,
			"leg_r_phi1": 0.18, "leg_r_phi2": -0.10, "leg_r_depth": 0.65,
			"leg_l_phi1": -0.24, "leg_l_phi2": -0.22, "leg_l_depth": -0.75,
			"arm_r_phi1": 0.32, "arm_r_phi2": 0.46, "arm_l_phi1": -0.34, "arm_l_phi2": -0.38,
		},
		"ne_nw": {
			"torso_trapezoid": 0.12, "distal_amp": 0.16, "toe_heel_bias": -0.15,
			"leg_r_phi1": 0.14, "leg_r_phi2": 0.18, "leg_r_depth": 0.18,
			"leg_l_phi1": -0.18, "leg_l_phi2": -0.14, "leg_l_depth": -0.20,
			"arm_r_phi1": 0.30, "arm_r_phi2": 0.40, "arm_l_phi1": -0.22, "arm_l_phi2": -0.28,
		},
		"n": {
			"torso_trapezoid": 0.14, "distal_amp": 0.16, "toe_heel_bias": -0.25,
			"leg_r_phi1": -0.14, "leg_r_phi2": 0.44, "leg_r_depth": 0.38,
			"leg_l_phi1": -0.10, "leg_l_phi2": -0.16, "leg_l_depth": -0.18,
			"arm_r_phi1": 0.28, "arm_r_phi2": 0.38, "arm_l_phi1": 0.28, "arm_l_phi2": 0.38,
		},
	},
	"HIT": {
		"s": {
			"torso_trapezoid": 0.16, "distal_amp": 0.16, "toe_heel_bias": 0.10,
			"leg_r_phi1": 0.28, "leg_r_phi2": -0.24, "leg_r_depth": 0.24,
			"leg_l_phi1": 0.20, "leg_l_phi2": -0.28, "leg_l_depth": -0.18,
			"arm_r_phi1": 0.30, "arm_r_phi2": 0.42, "arm_l_phi1": 0.30, "arm_l_phi2": 0.42,
		},
		"se_sw": {
			"torso_trapezoid": 0.15, "distal_amp": 0.16, "toe_heel_bias": 0.10,
			"leg_r_phi1": 0.26, "leg_r_phi2": -0.22, "leg_r_depth": 0.25,
			"leg_l_phi1": -0.18, "leg_l_phi2": -0.30, "leg_l_depth": -0.25,
			"arm_r_phi1": 0.32, "arm_r_phi2": 0.40, "arm_l_phi1": -0.24, "arm_l_phi2": -0.32,
		},
		"e_w": {
			"torso_trapezoid": 0.12, "distal_amp": 0.14, "toe_heel_bias": 0.10,
			"leg_r_phi1": 0.22, "leg_r_phi2": -0.20, "leg_r_depth": 0.65,
			"leg_l_phi1": -0.22, "leg_l_phi2": -0.28, "leg_l_depth": -0.75,
			"arm_r_phi1": 0.28, "arm_r_phi2": 0.36, "arm_l_phi1": -0.28, "arm_l_phi2": -0.36,
		},
		"ne_nw": {
			"torso_trapezoid": -0.15, "distal_amp": 0.18, "toe_heel_bias": -0.20,
			"leg_r_phi1": -0.20, "leg_r_phi2": 0.38, "leg_r_depth": 0.36,
			"leg_l_phi1": -0.24, "leg_l_phi2": 0.30, "leg_l_depth": 0.28,
			"arm_r_phi1": -0.24, "arm_r_phi2": -0.30, "arm_l_phi1": -0.24, "arm_l_phi2": -0.30,
		},
		"n": {
			"torso_trapezoid": -0.16, "distal_amp": 0.20, "toe_heel_bias": -0.30,
			"leg_r_phi1": -0.24, "leg_r_phi2": 0.54, "leg_r_depth": 0.48,
			"leg_l_phi1": -0.20, "leg_l_phi2": 0.46, "leg_l_depth": 0.40,
			"arm_r_phi1": -0.26, "arm_r_phi2": -0.34, "arm_l_phi1": -0.26, "arm_l_phi2": -0.34,
		},
	},
	"FLIGHT_STRAFE": {
		"s": {
			"torso_trapezoid": 0.0, "distal_amp": 0.06, "toe_heel_bias": 0.08,
			"leg_r_phi1": 0.18, "leg_r_phi2": -0.16, "leg_r_depth": 0.22,
			"leg_l_phi1": -0.20, "leg_l_phi2": -0.22, "leg_l_depth": -0.18,
			"arm_r_phi1": 0.12, "arm_r_phi2": 0.16, "arm_l_phi1": -0.10, "arm_l_phi2": -0.08,
		},
		"se_sw": {
			"torso_trapezoid": 0.0, "distal_amp": 0.08, "toe_heel_bias": 0.10,
			"leg_r_phi1": 0.22, "leg_r_phi2": -0.24, "leg_r_depth": 0.24,
			"leg_l_phi1": -0.24, "leg_l_phi2": -0.28, "leg_l_depth": -0.28,
			"arm_r_phi1": 0.16, "arm_r_phi2": 0.20, "arm_l_phi1": -0.18, "arm_l_phi2": -0.16,
		},
		"e_w": {
			"torso_trapezoid": 0.0, "distal_amp": 0.06, "toe_heel_bias": 0.08,
			"leg_r_phi1": 0.18, "leg_r_phi2": -0.20, "leg_r_depth": 0.65,
			"leg_l_phi1": -0.22, "leg_l_phi2": -0.26, "leg_l_depth": -0.75,
			"arm_r_phi1": 0.14, "arm_r_phi2": 0.18, "arm_l_phi1": -0.20, "arm_l_phi2": -0.16,
		},
		"ne_nw": {
			"torso_trapezoid": 0.0, "distal_amp": 0.08, "toe_heel_bias": -0.15,
			"leg_r_phi1": -0.14, "leg_r_phi2": 0.26, "leg_r_depth": 0.24,
			"leg_l_phi1": -0.18, "leg_l_phi2": 0.20, "leg_l_depth": -0.18,
			"arm_r_phi1": -0.12, "arm_r_phi2": -0.14, "arm_l_phi1": -0.12, "arm_l_phi2": -0.14,
		},
		"n": {
			"torso_trapezoid": 0.0, "distal_amp": 0.08, "toe_heel_bias": -0.22,
			"leg_r_phi1": -0.16, "leg_r_phi2": 0.38, "leg_r_depth": 0.38,
			"leg_l_phi1": -0.12, "leg_l_phi2": 0.24, "leg_l_depth": -0.14,
			"arm_r_phi1": -0.10, "arm_r_phi2": -0.12, "arm_l_phi1": -0.10, "arm_l_phi2": -0.12,
		},
	},
	"ASCEND": {
		"s": {
			"torso_trapezoid": 0.0, "distal_amp": 0.08, "toe_heel_bias": -0.12,
			"leg_r_phi1": -0.20, "leg_r_phi2": -0.32, "leg_r_depth": -0.22,
			"leg_l_phi1": -0.24, "leg_l_phi2": -0.34, "leg_l_depth": -0.26,
			"arm_r_phi1": -0.14, "arm_r_phi2": -0.18, "arm_l_phi1": -0.14, "arm_l_phi2": -0.18,
		},
		"se_sw": {
			"torso_trapezoid": 0.0, "distal_amp": 0.08, "toe_heel_bias": -0.10,
			"leg_r_phi1": -0.16, "leg_r_phi2": -0.28, "leg_r_depth": 0.14,
			"leg_l_phi1": -0.24, "leg_l_phi2": -0.32, "leg_l_depth": -0.26,
			"arm_r_phi1": -0.12, "arm_r_phi2": -0.14, "arm_l_phi1": -0.18, "arm_l_phi2": -0.22,
		},
		"e_w": {
			"torso_trapezoid": 0.0, "distal_amp": 0.06, "toe_heel_bias": -0.08,
			"leg_r_phi1": -0.14, "leg_r_phi2": -0.24, "leg_r_depth": 0.65,
			"leg_l_phi1": -0.22, "leg_l_phi2": -0.30, "leg_l_depth": -0.75,
			"arm_r_phi1": -0.12, "arm_r_phi2": -0.16, "arm_l_phi1": -0.18, "arm_l_phi2": -0.22,
		},
		"ne_nw": {
			"torso_trapezoid": 0.0, "distal_amp": 0.12, "toe_heel_bias": -0.20,
			"leg_r_phi1": -0.16, "leg_r_phi2": 0.34, "leg_r_depth": 0.30,
			"leg_l_phi1": -0.20, "leg_l_phi2": 0.28, "leg_l_depth": 0.22,
			"arm_r_phi1": -0.14, "arm_r_phi2": -0.18, "arm_l_phi1": -0.14, "arm_l_phi2": -0.18,
		},
		"n": {
			"torso_trapezoid": 0.0, "distal_amp": 0.14, "toe_heel_bias": -0.28,
			"leg_r_phi1": -0.20, "leg_r_phi2": 0.48, "leg_r_depth": 0.42,
			"leg_l_phi1": -0.16, "leg_l_phi2": 0.36, "leg_l_depth": 0.30,
			"arm_r_phi1": -0.14, "arm_r_phi2": -0.18, "arm_l_phi1": -0.14, "arm_l_phi2": -0.18,
		},
	},
	"DESCEND": {
		"s": {
			"torso_trapezoid": 0.0, "distal_amp": 0.10, "toe_heel_bias": 0.16,
			"leg_r_phi1": 0.28, "leg_r_phi2": -0.18, "leg_r_depth": 0.28,
			"leg_l_phi1": 0.16, "leg_l_phi2": -0.22, "leg_l_depth": 0.12,
			"arm_r_phi1": 0.16, "arm_r_phi2": 0.22, "arm_l_phi1": 0.14, "arm_l_phi2": 0.18,
		},
		"se_sw": {
			"torso_trapezoid": 0.0, "distal_amp": 0.10, "toe_heel_bias": 0.14,
			"leg_r_phi1": 0.28, "leg_r_phi2": -0.18, "leg_r_depth": 0.28,
			"leg_l_phi1": -0.14, "leg_l_phi2": -0.24, "leg_l_depth": -0.20,
			"arm_r_phi1": 0.18, "arm_r_phi2": 0.24, "arm_l_phi1": -0.14, "arm_l_phi2": -0.18,
		},
		"e_w": {
			"torso_trapezoid": 0.0, "distal_amp": 0.08, "toe_heel_bias": 0.12,
			"leg_r_phi1": 0.24, "leg_r_phi2": -0.16, "leg_r_depth": 0.65,
			"leg_l_phi1": -0.16, "leg_l_phi2": -0.22, "leg_l_depth": -0.75,
			"arm_r_phi1": 0.18, "arm_r_phi2": 0.24, "arm_l_phi1": -0.16, "arm_l_phi2": -0.20,
		},
		"ne_nw": {
			"torso_trapezoid": 0.0, "distal_amp": 0.08, "toe_heel_bias": -0.12,
			"leg_r_phi1": -0.10, "leg_r_phi2": 0.20, "leg_r_depth": 0.16,
			"leg_l_phi1": 0.12, "leg_l_phi2": 0.16, "leg_l_depth": 0.18,
			"arm_r_phi1": 0.14, "arm_r_phi2": 0.18, "arm_l_phi1": 0.12, "arm_l_phi2": 0.16,
		},
		"n": {
			"torso_trapezoid": 0.0, "distal_amp": 0.08, "toe_heel_bias": -0.16,
			"leg_r_phi1": -0.12, "leg_r_phi2": 0.26, "leg_r_depth": 0.24,
			"leg_l_phi1": -0.10, "leg_l_phi2": 0.18, "leg_l_depth": 0.14,
			"arm_r_phi1": 0.14, "arm_r_phi2": 0.18, "arm_l_phi1": 0.14, "arm_l_phi2": 0.18,
		},
	},
}


func get_view_family_key(view_key: String) -> String:
	match view_key:
		"s":
			return "s"
		"se", "sw":
			return "se_sw"
		"e", "w":
			return "e_w"
		"ne", "nw":
			return "ne_nw"
		"n":
			return "n"
		_:
			return "s"


func get_state_profile(state_name: String, view_key: String) -> Dictionary:
	var fam: String = get_view_family_key(view_key)
	var st_dict: Dictionary = state_profiles.get(state_name, state_profiles.get("IDLE_HOVER", {})) as Dictionary
	return st_dict.get(fam, st_dict.get("s", {})) as Dictionary
