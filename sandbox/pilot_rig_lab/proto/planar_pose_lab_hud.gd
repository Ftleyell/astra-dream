class_name PlanarPoseLabHud
extends RefCounted
## Constructor modular del HUD lateral en 5 pestañas ([1. Pose], [2. Idle], [3. Vuelo], [4. Giros], [5. Jiggle]) para planar_anim_test.tscn.

const BasePoseConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_base_pose_config.gd")
const IdleAnimConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_idle_anim_config.gd")
const LocomotionAnimConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_locomotion_anim_config.gd")
const TurnAnimConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_turn_anim_config.gd")
const JigglePhysicsConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_jiggle_physics_config.gd")
const KitingAnimConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_kiting_anim_config.gd")

const SLIDER_SPECS: Array[Dictionary] = [
	{"sec": "torso", "key": "pelvis_rot", "label": "Pelvis Inclinación", "min": -0.18, "max": 0.18, "step": 0.002, "rad": true},
	{"sec": "torso", "key": "waist_rot", "label": "Waist Inclinación", "min": -0.22, "max": 0.22, "step": 0.002, "rad": true},
	{"sec": "torso", "key": "chest_rot", "label": "Chest Inclinación", "min": -0.22, "max": 0.22, "step": 0.002, "rad": true},
	{"sec": "torso", "key": "neck_rot", "label": "Neck Compensación", "min": -0.32, "max": 0.32, "step": 0.002, "rad": true},
	{"sec": "torso", "key": "torso_trap", "label": "2.5D Trapecio Torso", "min": -0.12, "max": 0.12, "step": 0.002, "rad": false},
	{"sec": "torso", "key": "torso_yaw", "label": "2.5D Torsión Yaw", "min": -0.12, "max": 0.12, "step": 0.002, "rad": false},

	{"sec": "arms", "key": "shoulder_lead_rot", "label": "Hombro Líder/Int.", "min": -0.80, "max": 0.50, "step": 0.005, "rad": true},
	{"sec": "arms", "key": "elbow_lead_rot", "label": "Codo Líder/Int.", "min": -0.90, "max": 0.50, "step": 0.005, "rad": true},
	{"sec": "arms", "key": "wrist_lead_rot", "label": "Muñeca Líder/Int.", "min": -0.40, "max": 0.40, "step": 0.005, "rad": true},
	{"sec": "arms", "key": "shoulder_trail_rot", "label": "Hombro Trasero/Cám.", "min": -0.80, "max": 0.50, "step": 0.005, "rad": true},
	{"sec": "arms", "key": "elbow_trail_rot", "label": "Codo Trasero/Cám.", "min": -0.90, "max": 0.50, "step": 0.005, "rad": true},
	{"sec": "arms", "key": "wrist_trail_rot", "label": "Muñeca Trasero/Cám.", "min": -0.40, "max": 0.40, "step": 0.005, "rad": true},
	{"sec": "arms", "key": "pauldron_follow_ratio", "label": "Hombrera Follow %", "min": 0.0, "max": 1.0, "step": 0.02, "rad": false, "pct": true},
	{"sec": "arms", "key": "arm_lead_phi2", "label": "2.5D Brazo Líder (Phi2)", "min": -0.45, "max": 0.45, "step": 0.005, "rad": true},
	{"sec": "arms", "key": "arm_trail_phi2", "label": "2.5D Brazo Trasero (Phi2)", "min": -0.45, "max": 0.45, "step": 0.005, "rad": true},

	{"sec": "legs", "key": "thigh_lead_rot", "label": "Muslo Líder/Int.", "min": -0.50, "max": 0.40, "step": 0.005, "rad": true},
	{"sec": "legs", "key": "knee_lead_rot", "label": "Rodilla Líder/Int.", "min": -0.25, "max": 0.75, "step": 0.005, "rad": true},
	{"sec": "legs", "key": "ankle_lead_rot", "label": "Tobillo/Empeine Líder", "min": -0.40, "max": 0.50, "step": 0.005, "rad": true},
	{"sec": "legs", "key": "thigh_trail_rot", "label": "Muslo Impulso/Cám.", "min": -0.50, "max": 0.40, "step": 0.005, "rad": true},
	{"sec": "legs", "key": "knee_trail_rot", "label": "Rodilla Impulso/Cám.", "min": -0.25, "max": 0.75, "step": 0.005, "rad": true},
	{"sec": "legs", "key": "ankle_trail_rot", "label": "Tobillo/Empeine Impulso", "min": -0.40, "max": 0.50, "step": 0.005, "rad": true},
	{"sec": "legs", "key": "leg_lead_phi_shin", "label": "2.5D Rodilla Líder (Phi Shin)", "min": -0.45, "max": 0.45, "step": 0.005, "rad": true},
	{"sec": "legs", "key": "leg_lead_distal_amp", "label": "2.5D Pie Líder (Distal)", "min": -0.35, "max": 0.35, "step": 0.005, "rad": false},
	{"sec": "legs", "key": "leg_trail_phi_shin", "label": "2.5D Rodilla Impulso (Phi Shin)", "min": -0.45, "max": 0.45, "step": 0.005, "rad": true},
	{"sec": "legs", "key": "leg_trail_distal_amp", "label": "2.5D Pie Impulso (Distal)", "min": -0.35, "max": 0.35, "step": 0.005, "rad": false},
]

const IDLE_SLIDER_SPECS: Array[Dictionary] = [
	{"sec": "idle_root", "key": "master_intensity", "label": "Intensidad Maestra", "min": 0.0, "max": 2.0, "step": 0.05, "rad": false},
	{"sec": "idle_root", "key": "cycle_speed_rad", "label": "Velocidad Ciclo (rad/s)", "min": 0.4, "max": 3.5, "step": 0.05, "rad": false},
	{"sec": "idle_root", "key": "harmonic_asymmetry", "label": "Asimetría Armónica", "min": 0.0, "max": 0.45, "step": 0.02, "rad": false},
	{"sec": "idle_root", "key": "float_amp_y_px", "label": "Flote Vertical Y (px)", "min": 0.0, "max": 10.0, "step": 0.1, "rad": false},
	{"sec": "idle_root", "key": "float_fig8_x_px", "label": "Deriva Figura-8 X (px)", "min": 0.0, "max": 6.0, "step": 0.05, "rad": false},
	{"sec": "idle_root", "key": "pelvis_sway_rot", "label": "Balanceo Pelvis", "min": 0.0, "max": 0.06, "step": 0.002, "rad": true},
	{"sec": "idle_root", "key": "head_gyro_lag_px", "label": "Gyro-Lock Cabeza (px)", "min": 0.0, "max": 3.0, "step": 0.05, "rad": false},
	{"sec": "idle_root", "key": "head_gyro_rot_rad", "label": "Gyro-Lock Rotación", "min": 0.0, "max": 0.06, "step": 0.002, "rad": true},
	{"sec": "idle_root", "key": "head_phase_lag", "label": "Retardo Fase Cabeza", "min": 0.0, "max": 1.5, "step": 0.05, "rad": false},

	{"sec": "idle_skel", "key": "waist_sway_rot", "label": "Waist Sway", "min": 0.0, "max": 0.06, "step": 0.002, "rad": true},
	{"sec": "idle_skel", "key": "chest_breath_rot", "label": "Chest Respiración", "min": 0.0, "max": 0.06, "step": 0.002, "rad": true},
	{"sec": "idle_skel", "key": "neck_counter_rot", "label": "Neck Compensación", "min": 0.0, "max": 0.06, "step": 0.002, "rad": true},
	{"sec": "idle_skel", "key": "shoulder_wave_rot", "label": "Onda Hombros", "min": 0.0, "max": 0.08, "step": 0.002, "rad": true},
	{"sec": "idle_skel", "key": "elbow_wave_rot", "label": "Onda Codos", "min": 0.0, "max": 0.10, "step": 0.002, "rad": true},
	{"sec": "idle_skel", "key": "wrist_wave_rot", "label": "Onda Muñecas", "min": 0.0, "max": 0.12, "step": 0.002, "rad": true},
	{"sec": "idle_skel", "key": "arm_chain_phase_lag", "label": "Retardo Cadena Brazo", "min": 0.0, "max": 1.2, "step": 0.04, "rad": false},
	{"sec": "idle_skel", "key": "arm_lr_phase_offset", "label": "Desfase Brazos L/R", "min": 0.0, "max": 3.14, "step": 0.05, "rad": false},
	{"sec": "idle_skel", "key": "thigh_wave_rot", "label": "Onda Muslos", "min": 0.0, "max": 0.08, "step": 0.002, "rad": true},
	{"sec": "idle_skel", "key": "knee_wave_rot", "label": "Onda Rodillas", "min": 0.0, "max": 0.10, "step": 0.002, "rad": true},
	{"sec": "idle_skel", "key": "ankle_wave_rot", "label": "Onda Tobillos/Empeine", "min": 0.0, "max": 0.10, "step": 0.002, "rad": true},
	{"sec": "idle_skel", "key": "leg_chain_phase_lag", "label": "Retardo Cadena Pierna", "min": 0.0, "max": 1.2, "step": 0.04, "rad": false},
	{"sec": "idle_skel", "key": "leg_scissor_phase_offset", "label": "Desfase Tijera Piernas", "min": 0.0, "max": 3.14, "step": 0.05, "rad": false},

	{"sec": "idle_25d", "key": "torso_trap_breath", "label": "2.5D Trapecio Torso", "min": 0.0, "max": 0.05, "step": 0.002, "rad": false},
	{"sec": "idle_25d", "key": "torso_yaw_sway", "label": "2.5D Torsión Yaw", "min": 0.0, "max": 0.05, "step": 0.002, "rad": false},
	{"sec": "idle_25d", "key": "arm_phi1_wave", "label": "2.5D Hombro (Phi1)", "min": 0.0, "max": 0.10, "step": 0.002, "rad": true},
	{"sec": "idle_25d", "key": "arm_phi2_wave", "label": "2.5D Antebrazo (Phi2)", "min": 0.0, "max": 0.14, "step": 0.002, "rad": true},
	{"sec": "idle_25d", "key": "leg_phi_thigh_wave", "label": "2.5D Muslo (Phi1)", "min": 0.0, "max": 0.12, "step": 0.002, "rad": true},
	{"sec": "idle_25d", "key": "leg_phi_shin_wave", "label": "2.5D Rodilla (Phi2)", "min": 0.0, "max": 0.16, "step": 0.002, "rad": true},
	{"sec": "idle_25d", "key": "leg_distal_wave", "label": "2.5D Empeine (Distal)", "min": 0.0, "max": 0.10, "step": 0.002, "rad": false},
	{"sec": "idle_25d", "key": "leg_depth_phase_wave", "label": "2.5D Pulso Profundidad", "min": 0.0, "max": 0.10, "step": 0.002, "rad": false},

	{"sec": "idle_sec", "key": "hair_float_amp_px", "label": "Flote Cabello (px)", "min": 0.0, "max": 4.5, "step": 0.05, "rad": false},
	{"sec": "idle_sec", "key": "hair_phase_lag", "label": "Retardo Cabello", "min": 0.0, "max": 1.6, "step": 0.05, "rad": false},
	{"sec": "idle_sec", "key": "torso_secondary_amp_px", "label": "Micro-Flote Torso (px)", "min": 0.0, "max": 3.5, "step": 0.05, "rad": false},
	{"sec": "idle_sec", "key": "torso_secondary_phase_lag", "label": "Retardo Torso Sec.", "min": 0.0, "max": 1.6, "step": 0.05, "rad": false},

	{"sec": "idle_fam", "key": "float_scale", "label": "Mult. Familia: Flote/Cabeza", "min": 0.0, "max": 2.0, "step": 0.05, "rad": false, "fam_mul": true},
	{"sec": "idle_fam", "key": "arms_scale", "label": "Mult. Familia: Brazos", "min": 0.0, "max": 2.0, "step": 0.05, "rad": false, "fam_mul": true},
	{"sec": "idle_fam", "key": "legs_scale", "label": "Mult. Familia: Piernas", "min": 0.0, "max": 2.0, "step": 0.05, "rad": false, "fam_mul": true},
	{"sec": "idle_fam", "key": "persp_25d_scale", "label": "Mult. Familia: Escorzo 2.5D", "min": 0.0, "max": 2.0, "step": 0.05, "rad": false, "fam_mul": true},
	{"sec": "idle_fam", "key": "secondary_scale", "label": "Mult. Familia: Cabello/Torso", "min": 0.0, "max": 2.0, "step": 0.05, "rad": false, "fam_mul": true},
]

const LOCO_SLIDER_SPECS: Array[Dictionary] = [
	{"sec": "loco_dyn", "key": "master_intensity", "label": "Intensidad Maestra", "min": 0.0, "max": 2.0, "step": 0.05, "rad": false, "global": true},
	{"sec": "loco_dyn", "key": "accel_blend_rate", "label": "Tasa Entrada Vuelo", "min": 3.0, "max": 25.0, "step": 0.5, "rad": false, "global": true},
	{"sec": "loco_dyn", "key": "brake_enter_rate", "label": "Tasa Entrada Freno", "min": 4.0, "max": 30.0, "step": 0.5, "rad": false, "global": true},
	{"sec": "loco_dyn", "key": "brake_decay_rate", "label": "Amortiguación Freno", "min": 1.5, "max": 15.0, "step": 0.25, "rad": false, "global": true},
	{"sec": "loco_dyn", "key": "brake_decel_sensitivity", "label": "Sensibilidad Freno", "min": 0.2, "max": 2.0, "step": 0.05, "rad": false, "global": true},
	{"sec": "loco_dyn", "key": "flight_idle_float_atten", "label": "Atenuación Figura-8", "min": 0.0, "max": 1.0, "step": 0.05, "rad": false, "global": true},
	{"sec": "loco_dyn", "key": "flight_wake_freq_mul", "label": "Frec. Estela Distal", "min": 0.8, "max": 2.2, "step": 0.05, "rad": false, "global": true},
	{"sec": "loco_dyn", "key": "flight_wake_amp_mul", "label": "Amp. Estela Distal", "min": 0.5, "max": 2.0, "step": 0.05, "rad": false, "global": true},
	{"sec": "loco_dyn", "key": "auto_cycle_duration_sec", "label": "Duración Ciclo Demo (s)", "min": 2.0, "max": 8.0, "step": 0.2, "rad": false, "global": true},

	{"sec": "loco_fwd", "key": "fwd_pelvis_shift_x", "label": "Pelvis Shift X", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},
	{"sec": "loco_fwd", "key": "fwd_pelvis_shift_y", "label": "Pelvis Shift Y", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},
	{"sec": "loco_fwd", "key": "fwd_waist_rot", "label": "Waist Inclinación", "min": -0.15, "max": 0.15, "step": 0.002, "rad": true},
	{"sec": "loco_fwd", "key": "fwd_chest_rot", "label": "Chest Inclinación", "min": -0.15, "max": 0.15, "step": 0.002, "rad": true},
	{"sec": "loco_fwd", "key": "fwd_neck_rot", "label": "Neck Compensación", "min": -0.25, "max": 0.25, "step": 0.002, "rad": true},
	{"sec": "loco_fwd", "key": "fwd_shoulder_lead_rot", "label": "Hombro Líder", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_fwd", "key": "fwd_elbow_lead_rot", "label": "Codo Líder", "min": -0.30, "max": 0.30, "step": 0.005, "rad": true},
	{"sec": "loco_fwd", "key": "fwd_shoulder_trail_rot", "label": "Hombro Trasero", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_fwd", "key": "fwd_elbow_trail_rot", "label": "Codo Trasero", "min": -0.30, "max": 0.30, "step": 0.005, "rad": true},
	{"sec": "loco_fwd", "key": "fwd_thigh_lead_rot", "label": "Muslo Líder", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_fwd", "key": "fwd_knee_lead_rot", "label": "Rodilla Líder", "min": -0.25, "max": 0.30, "step": 0.005, "rad": true},
	{"sec": "loco_fwd", "key": "fwd_thigh_trail_rot", "label": "Muslo Impulso", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_fwd", "key": "fwd_knee_trail_rot", "label": "Rodilla Impulso", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_fwd", "key": "fwd_ankle_trail_rot", "label": "Tobillo Impulso", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_fwd", "key": "fwd_torso_trap", "label": "2.5D Trapecio", "min": -0.08, "max": 0.08, "step": 0.002, "rad": false},
	{"sec": "loco_fwd", "key": "fwd_leg_trail_phi_shin", "label": "2.5D Rodilla Impulso", "min": -0.22, "max": 0.22, "step": 0.005, "rad": true},
	{"sec": "loco_fwd", "key": "fwd_hair_drag_x_px", "label": "Arrastre Pelo X (px)", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},
	{"sec": "loco_fwd", "key": "fwd_hair_drag_y_px", "label": "Arrastre Pelo Y (px)", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},

	{"sec": "loco_brk", "key": "brk_pelvis_shift_x", "label": "Pelvis Shift X", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},
	{"sec": "loco_brk", "key": "brk_pelvis_shift_y", "label": "Pelvis Shift Y", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},
	{"sec": "loco_brk", "key": "brk_waist_rot", "label": "Waist Contra-Pitch", "min": -0.18, "max": 0.18, "step": 0.002, "rad": true},
	{"sec": "loco_brk", "key": "brk_chest_rot", "label": "Chest Contra-Pitch", "min": -0.18, "max": 0.18, "step": 0.002, "rad": true},
	{"sec": "loco_brk", "key": "brk_neck_rot", "label": "Neck Compensación", "min": -0.25, "max": 0.25, "step": 0.002, "rad": true},
	{"sec": "loco_brk", "key": "brk_head_rot", "label": "Cabeza Inercia", "min": -0.10, "max": 0.10, "step": 0.002, "rad": true},
	{"sec": "loco_brk", "key": "brk_shoulder_lead_rot", "label": "Hombro Líder", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_brk", "key": "brk_elbow_lead_rot", "label": "Codo Líder", "min": -0.30, "max": 0.30, "step": 0.005, "rad": true},
	{"sec": "loco_brk", "key": "brk_shoulder_trail_rot", "label": "Hombro Trasero", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_brk", "key": "brk_elbow_trail_rot", "label": "Codo Trasero", "min": -0.30, "max": 0.30, "step": 0.005, "rad": true},
	{"sec": "loco_brk", "key": "brk_thigh_lead_rot", "label": "Muslo Líder", "min": -0.28, "max": 0.28, "step": 0.005, "rad": true},
	{"sec": "loco_brk", "key": "brk_knee_lead_rot", "label": "Rodilla Líder", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_brk", "key": "brk_ankle_lead_rot", "label": "Tobillo Líder", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_brk", "key": "brk_thigh_trail_rot", "label": "Muslo Impulso", "min": -0.28, "max": 0.28, "step": 0.005, "rad": true},
	{"sec": "loco_brk", "key": "brk_knee_trail_rot", "label": "Rodilla Impulso", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_brk", "key": "brk_ankle_trail_rot", "label": "Tobillo Impulso", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_brk", "key": "brk_torso_trap", "label": "2.5D Trapecio", "min": -0.08, "max": 0.08, "step": 0.002, "rad": false},
	{"sec": "loco_brk", "key": "brk_leg_trail_phi_shin", "label": "2.5D Rodilla Impulso", "min": -0.22, "max": 0.22, "step": 0.005, "rad": true},
	{"sec": "loco_brk", "key": "brk_hair_drag_x_px", "label": "Inercia Pelo X (px)", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},
	{"sec": "loco_brk", "key": "brk_hair_drag_y_px", "label": "Inercia Pelo Y (px)", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},

	{"sec": "loco_rev", "key": "rev_pelvis_shift_x", "label": "Pelvis Shift X", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},
	{"sec": "loco_rev", "key": "rev_pelvis_shift_y", "label": "Pelvis Shift Y", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},
	{"sec": "loco_rev", "key": "rev_waist_rot", "label": "Waist Retracción", "min": -0.15, "max": 0.15, "step": 0.002, "rad": true},
	{"sec": "loco_rev", "key": "rev_chest_rot", "label": "Chest Retracción", "min": -0.15, "max": 0.15, "step": 0.002, "rad": true},
	{"sec": "loco_rev", "key": "rev_neck_rot", "label": "Neck Compensación", "min": -0.25, "max": 0.25, "step": 0.002, "rad": true},
	{"sec": "loco_rev", "key": "rev_shoulder_lead_rot", "label": "Hombro Líder", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_rev", "key": "rev_shoulder_trail_rot", "label": "Hombro Trasero", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_rev", "key": "rev_thigh_lead_rot", "label": "Muslo Líder", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_rev", "key": "rev_thigh_trail_rot", "label": "Muslo Impulso", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_rev", "key": "rev_knee_lead_rot", "label": "Rodilla Líder", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_rev", "key": "rev_ankle_lead_rot", "label": "Tobillo Líder", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "loco_rev", "key": "rev_torso_trap", "label": "2.5D Trapecio", "min": -0.08, "max": 0.08, "step": 0.002, "rad": false},
	{"sec": "loco_rev", "key": "rev_hair_drag_x_px", "label": "Arrastre Pelo X (px)", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},
	{"sec": "loco_rev", "key": "rev_hair_drag_y_px", "label": "Arrastre Pelo Y (px)", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},
]

const TURN_SLIDER_SPECS: Array[Dictionary] = [
	{"sec": "turn_timing", "key": "master_intensity", "label": "Intensidad Maestra", "min": 0.0, "max": 2.0, "step": 0.05, "rad": false},
	{"sec": "turn_timing", "key": "body_turn_duration_sec", "label": "Duración Giro Cuerpo (s)", "min": 0.06, "max": 0.30, "step": 0.005, "rad": false},
	{"sec": "turn_timing", "key": "body_swap_point", "label": "Punto de Corte (Pre/Post)", "min": 0.15, "max": 0.60, "step": 0.02, "rad": false},
	{"sec": "turn_timing", "key": "head_turn_duration_sec", "label": "Duración Whip Cabeza (s)", "min": 0.04, "max": 0.20, "step": 0.005, "rad": false},

	{"sec": "turn_bridge", "key": "pre_yaw_25d", "label": "Pre-Giro 2.5D Saliente", "min": 0.0, "max": 0.40, "step": 0.01, "rad": false},
	{"sec": "turn_bridge", "key": "post_catchup_yaw_25d", "label": "Catch-Up 2.5D Entrante", "min": 0.0, "max": 0.45, "step": 0.01, "rad": false},
	{"sec": "turn_bridge", "key": "pelvis_whip_shift_x_px", "label": "Impulso Lateral Pelvis (px)", "min": 0.0, "max": 6.0, "step": 0.1, "rad": false},
	{"sec": "turn_bridge", "key": "spine_overshoot_rot", "label": "Overshoot Columna (Torso)", "min": 0.0, "max": 0.22, "step": 0.005, "rad": true},

	{"sec": "turn_cascade", "key": "limb_lag_phase", "label": "Desfase Cascada Extrem.", "min": 0.05, "max": 0.55, "step": 0.02, "rad": false},
	{"sec": "turn_cascade", "key": "arm_whip_rot", "label": "Latigazo Brazos (Whip)", "min": 0.0, "max": 0.35, "step": 0.005, "rad": true},
	{"sec": "turn_cascade", "key": "leg_whip_rot", "label": "Latigazo Piernas (Whip)", "min": 0.0, "max": 0.30, "step": 0.005, "rad": true},
	{"sec": "turn_cascade", "key": "body_turn_hair_whip_px", "label": "Inercia Cabello Giro (px)", "min": 0.0, "max": 7.0, "step": 0.1, "rad": false},

	{"sec": "turn_head", "key": "head_lead_rot", "label": "Anticipación Cabeza (Lead)", "min": 0.0, "max": 0.18, "step": 0.005, "rad": true},
	{"sec": "turn_head", "key": "head_whip_overshoot_rot", "label": "Overshoot Whip Cabeza", "min": 0.0, "max": 0.22, "step": 0.005, "rad": true},
	{"sec": "turn_head", "key": "head_neck_kick_rot", "label": "Patada Cervical (Neck)", "min": 0.0, "max": 0.16, "step": 0.005, "rad": true},
	{"sec": "turn_head", "key": "head_sympathetic_chest_rot", "label": "Reacción Simpática Pecho", "min": 0.0, "max": 0.10, "step": 0.002, "rad": true},
	{"sec": "turn_head", "key": "head_whip_hair_px", "label": "Latigazo Cabello Whip (px)", "min": 0.0, "max": 6.0, "step": 0.1, "rad": false},

	{"sec": "turn_fam", "key": "turn_scale", "label": "Mult. Familia: Intensidad Giro", "min": 0.0, "max": 2.0, "step": 0.05, "rad": false, "fam_mul": true},
]

const JIGGLE_SLIDER_SPECS: Array[Dictionary] = [
	{"sec": "jiggle_global", "key": "master_intensity", "label": "Intensidad Maestra", "min": 0.0, "max": 2.0, "step": 0.05, "rad": false},
	{"sec": "jiggle_global", "key": "normal_light_strength", "label": "Micro-Luz 2.5D (Normal)", "min": 0.0, "max": 0.25, "step": 0.005, "rad": false},
	{"sec": "jiggle_global", "key": "preview_pulse_interval_sec", "label": "Intervalo Pulso Demo (s)", "min": 0.4, "max": 3.0, "step": 0.05, "rad": false},

	{"sec": "jiggle_bust", "key": "bust_idle_amp_px", "label": "Sway Busto Idle (px)", "min": 0.0, "max": 5.0, "step": 0.05, "rad": false},
	{"sec": "jiggle_bust", "key": "bust_freq_hz", "label": "Frecuencia Busto (Hz)", "min": 1.0, "max": 4.5, "step": 0.05, "rad": false},
	{"sec": "jiggle_bust", "key": "bust_damping_ratio", "label": "Amortiguación Busto", "min": 0.10, "max": 0.85, "step": 0.02, "rad": false},
	{"sec": "jiggle_bust", "key": "bust_inertia_gain", "label": "Inercia Busto (Impulso)", "min": 0.0, "max": 3.5, "step": 0.05, "rad": false},
	{"sec": "jiggle_bust", "key": "bust_max_clamp_px", "label": "Tope Elástico Busto (px)", "min": 1.5, "max": 14.0, "step": 0.25, "rad": false},

	{"sec": "jiggle_glute", "key": "glute_idle_amp_px", "label": "Sway Glúteos Idle (px)", "min": 0.0, "max": 4.5, "step": 0.05, "rad": false},
	{"sec": "jiggle_glute", "key": "glute_freq_hz", "label": "Frecuencia Glúteos (Hz)", "min": 1.2, "max": 5.0, "step": 0.05, "rad": false},
	{"sec": "jiggle_glute", "key": "glute_damping_ratio", "label": "Amortiguación Glúteos", "min": 0.12, "max": 0.90, "step": 0.02, "rad": false},
	{"sec": "jiggle_glute", "key": "glute_thigh_coupling", "label": "Acoplamiento Cadera/Muslo", "min": 0.0, "max": 3.0, "step": 0.05, "rad": false},
	{"sec": "jiggle_glute", "key": "glute_max_clamp_px", "label": "Tope Elástico Glúteos (px)", "min": 1.5, "max": 12.0, "step": 0.25, "rad": false},

	{"sec": "jiggle_fam", "key": "bust_scale", "label": "Mult. Familia: Busto", "min": 0.0, "max": 2.0, "step": 0.05, "rad": false, "fam_mul": true},
	{"sec": "jiggle_fam", "key": "glute_scale", "label": "Mult. Familia: Glúteos", "min": 0.0, "max": 2.0, "step": 0.05, "rad": false, "fam_mul": true},
]

const KITING_GLOBAL_SPECS: Array[Dictionary] = [
	{"sec": "kiting_global", "key": "master_intensity", "label": "Intensidad Maestra Kiting", "min": 0.0, "max": 2.0, "step": 0.05, "rad": false, "global": true},
	{"sec": "kiting_global", "key": "blend_rate", "label": "Tasa Blend Strafe/Rev", "min": 3.0, "max": 24.0, "step": 0.5, "rad": false, "global": true},
	{"sec": "kiting_global", "key": "rev_brake_sensitivity", "label": "Sensibilidad Freno Reversa", "min": 0.2, "max": 2.0, "step": 0.05, "rad": false, "global": true},
	{"sec": "kiting_global", "key": "strafe_enter_dot_max", "label": "Umbral Dot Entrada Strafe", "min": 0.35, "max": 0.95, "step": 0.02, "rad": false, "global": true},
	{"sec": "kiting_global", "key": "reverse_enter_dot_max", "label": "Umbral Dot Reversa 180°", "min": -0.40, "max": 0.50, "step": 0.02, "rad": false, "global": true},
	{"sec": "kiting_global", "key": "hover_slide_micro_amp", "label": "Equilibrio Hover-Slide Amp", "min": 0.0, "max": 0.50, "step": 0.02, "rad": false, "global": true},
	{"sec": "kiting_global", "key": "hover_slide_micro_hz", "label": "Equilibrio Hover-Slide (Hz)", "min": 0.5, "max": 4.0, "step": 0.05, "rad": false, "global": true},
	{"sec": "kiting_global", "key": "auto_cycle_duration_sec", "label": "Ciclo Demo 360° (s)", "min": 2.5, "max": 12.0, "step": 0.2, "rad": false, "global": true},
]

const KITING_PHASE_SPECS: Array[Dictionary] = [
	{"sec": "kiting_phase", "key": "pelvis_shift_x", "label": "Pelvis Shift X (px)", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},
	{"sec": "kiting_phase", "key": "pelvis_shift_y", "label": "Pelvis Shift Y (px)", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},
	{"sec": "kiting_phase", "key": "pelvis_rot", "label": "Pelvis Inclinación", "min": -0.15, "max": 0.15, "step": 0.002, "rad": true},
	{"sec": "kiting_phase", "key": "waist_rot", "label": "Waist Inclinación", "min": -0.18, "max": 0.18, "step": 0.002, "rad": true},
	{"sec": "kiting_phase", "key": "chest_rot", "label": "Chest Inclinación", "min": -0.18, "max": 0.18, "step": 0.002, "rad": true},
	{"sec": "kiting_phase", "key": "neck_rot", "label": "Neck Compensación", "min": -0.25, "max": 0.25, "step": 0.002, "rad": true},
	{"sec": "kiting_phase", "key": "head_lag_px", "label": "Retardo Cabeza (px)", "min": -4.0, "max": 4.0, "step": 0.1, "rad": false},
	{"sec": "kiting_phase", "key": "head_rot", "label": "Inclinación Cabeza", "min": -0.10, "max": 0.10, "step": 0.002, "rad": true},
	{"sec": "kiting_phase", "key": "shoulder_lead_rot", "label": "Hombro Líder", "min": -0.35, "max": 0.35, "step": 0.005, "rad": true},
	{"sec": "kiting_phase", "key": "elbow_lead_rot", "label": "Codo Líder", "min": -0.40, "max": 0.40, "step": 0.005, "rad": true},
	{"sec": "kiting_phase", "key": "shoulder_trail_rot", "label": "Hombro Trasero", "min": -0.35, "max": 0.35, "step": 0.005, "rad": true},
	{"sec": "kiting_phase", "key": "elbow_trail_rot", "label": "Codo Trasero", "min": -0.40, "max": 0.40, "step": 0.005, "rad": true},
	{"sec": "kiting_phase", "key": "thigh_lead_rot", "label": "Muslo Líder", "min": -0.30, "max": 0.30, "step": 0.005, "rad": true},
	{"sec": "kiting_phase", "key": "knee_lead_rot", "label": "Rodilla Líder", "min": -0.20, "max": 0.45, "step": 0.005, "rad": true},
	{"sec": "kiting_phase", "key": "ankle_lead_rot", "label": "Tobillo Líder", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "kiting_phase", "key": "thigh_trail_rot", "label": "Muslo Impulso", "min": -0.35, "max": 0.30, "step": 0.005, "rad": true},
	{"sec": "kiting_phase", "key": "knee_trail_rot", "label": "Rodilla Impulso", "min": -0.25, "max": 0.35, "step": 0.005, "rad": true},
	{"sec": "kiting_phase", "key": "ankle_trail_rot", "label": "Tobillo Impulso", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "kiting_phase", "key": "torso_trap", "label": "2.5D Trapecio Torso", "min": -0.10, "max": 0.10, "step": 0.002, "rad": false},
	{"sec": "kiting_phase", "key": "torso_yaw", "label": "2.5D Torsión Yaw", "min": -0.10, "max": 0.10, "step": 0.002, "rad": false},
	{"sec": "kiting_phase", "key": "leg_lead_phi_shin", "label": "2.5D Rodilla Líder", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "kiting_phase", "key": "leg_trail_phi_shin", "label": "2.5D Rodilla Impulso", "min": -0.25, "max": 0.25, "step": 0.005, "rad": true},
	{"sec": "kiting_phase", "key": "hair_drag_x_px", "label": "Arrastre Pelo X (px)", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},
	{"sec": "kiting_phase", "key": "hair_drag_y_px", "label": "Arrastre Pelo Y (px)", "min": -5.0, "max": 5.0, "step": 0.1, "rad": false},
	{"sec": "kiting_phase", "key": "torso_sec_drag_y_px", "label": "Inercia Busto Y (px)", "min": -2.5, "max": 2.5, "step": 0.05, "rad": false},
]

const SECTION_TITLES: Dictionary = {
	"torso": "1. TORSO Y CUELLO",
	"arms": "2. GUARDIA DE BRAZOS",
	"legs": "3. TIJERA DE PIERNAS ZERO-G",
	"idle_root": "A. RITMO, FIGURA-8 Y GYRO-LOCK",
	"idle_skel": "B. ONDA ARTICULAR DESFASADA (CAPA 1)",
	"idle_25d": "C. RESPIRACIÓN ESCORZO 2.5D (CAPA 2)",
	"idle_sec": "D. MICRO-FLOTACIÓN CABELLO/TORSO (CAPA 3)",
	"idle_fam": "E. MULTIPLICADORES DE FAMILIA ACTIVA",
	"loco_dyn": "A. DINÁMICA DE TRANSICIÓN Y ESTELA",
	"loco_fwd": "B. AVANCE AERODINÁMICO (FAMILIA ACTIVA)",
	"loco_brk": "C. FRENO SUAVE CONTRA-PITCH (FAMILIA)",
	"loco_rev": "D. REVERSA / BACKPEDAL (FAMILIA)",
	"turn_timing": "A. TIEMPOS DE CORTE Y VELOCIDAD",
	"turn_bridge": "B. PUENTE 2.5D Y OVERSHOOT DE TORSO",
	"turn_cascade": "C. CASCADA EXTREMIDADES Y CABELLO",
	"turn_head": "D. WHIP CERVICAL CABEZA DESACOPLADA",
	"turn_fam": "E. MULTIPLICADOR DE FAMILIA ACTIVA",
	"jiggle_global": "A. CONTROL MAESTRO Y LUZ 2.5D",
	"jiggle_bust": "B. FÍSICA DE BUSTO (SEDA / DESFASE L-R)",
	"jiggle_glute": "C. FÍSICA DE GLÚTEOS (FIRME / CADERA)",
	"jiggle_fam": "D. MULTIPLICADORES DE FAMILIA ACTIVA",
	"kiting_global": "A. DINÁMICA DE KITING 360° & HOVER-SLIDE",
	"kiting_phase": "B. POSTURA DE FASE ACTIVA (FAMILIA)",
}

var _tab_buttons: Array[Button] = []
var _active_tab: int = 5
var _pose_tab_box: VBoxContainer = null
var _idle_tab_box: VBoxContainer = null
var _loco_tab_box: VBoxContainer = null
var _turn_tab_box: VBoxContainer = null
var _jiggle_tab_box: VBoxContainer = null
var _kiting_tab_box: VBoxContainer = null
var _on_tab_changed_cb: Callable = Callable()

var _ab_btn: Button = null
var _hover_btn: Button = null
var _mode_opt: OptionButton = null
var _scale_slider: HSlider = null
var _scale_val_lbl: Label = null
var _head_cycle_chk: CheckBox = null
var _face_live_chk: CheckBox = null
var _slowmo_opt: OptionButton = null
var _fam_buttons: Dictionary = {}
var _fam_subtitle_lbl: Label = null

var _pose_slider_rows: Dictionary = {}
var _idle_slider_rows: Dictionary = {}
var _loco_slider_rows: Dictionary = {}
var _turn_slider_rows: Dictionary = {}
var _jiggle_slider_rows: Dictionary = {}
var _kiting_slider_rows: Dictionary = {}
var _idle_skel_chk: CheckBox = null
var _idle_25d_chk: CheckBox = null
var _idle_sec_chk: CheckBox = null
var _idle_cadence_opt: OptionButton = null
var _loco_preview_chk: CheckBox = null
var _loco_mode_opt: OptionButton = null
var _turn_preview_chk: CheckBox = null
var _turn_mode_opt: OptionButton = null
var _jiggle_preview_chk: CheckBox = null
var _jiggle_mode_opt: OptionButton = null
var _jiggle_bust_chk: CheckBox = null
var _jiggle_glute_chk: CheckBox = null
var _kiting_preview_chk: CheckBox = null
var _kiting_mode_opt: OptionButton = null
var _kiting_phase_opt: OptionButton = null
var _feedback_lbl: Label = null


func build(
	host: Node,
	pose_cfg: BasePoseConfigScript,
	idle_cfg: IdleAnimConfigScript,
	loco_cfg: LocomotionAnimConfigScript,
	turn_cfg: TurnAnimConfigScript,
	jiggle_cfg: JigglePhysicsConfigScript,
	initial_family: String,
	initial_hover_on: bool,
	callbacks: Dictionary,
	kiting_cfg: KitingAnimConfigScript = null
) -> CanvasLayer:
	_on_tab_changed_cb = callbacks.get("on_tab_changed", Callable()) as Callable
	var layer := CanvasLayer.new()
	layer.name = "PoseLabHudLayer"
	layer.layer = 10
	host.add_child(layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 12.0
	panel.offset_right = 382.0
	panel.offset_top = 12.0
	panel.offset_bottom = -12.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "RIG LAB — POSE BASE & IDLE ZERO-G"
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	var tab_row := GridContainer.new()
	tab_row.columns = 3
	tab_row.add_theme_constant_override("h_separation", 4)
	tab_row.add_theme_constant_override("v_separation", 4)
	vbox.add_child(tab_row)
	_tab_buttons.clear()
	var tab_labels: Array[String] = ["1. Pose", "2. Idle", "3. Vuelo", "4. Giros", "5. Jiggle", "6. Kiting"]
	for t_idx: int in range(tab_labels.size()):
		var tb := Button.new()
		tb.text = tab_labels[t_idx]
		tb.add_theme_font_size_override("font_size", 11)
		tb.toggle_mode = true
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(func() -> void: set_active_tab(t_idx))
		tab_row.add_child(tb)
		_tab_buttons.append(tb)

	_hover_btn = Button.new()
	_hover_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_toggle_hover", Callable())
		if cb.is_valid():
			cb.call()
	)
	vbox.add_child(_hover_btn)

	_ab_btn = Button.new()
	_ab_btn.text = "⚡ A/B: Guardia Zero-G [ACTIVA] (Tab)"
	_ab_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_toggle_ab", Callable())
		if cb.is_valid():
			cb.call()
	)
	vbox.add_child(_ab_btn)

	_mode_opt = OptionButton.new()
	_mode_opt.add_item("0: Huesos 2D + Escorzo 2.5D (Híbrido)", 0)
	_mode_opt.add_item("1: Solo Huesos 2D (Skeleton2D)", 1)
	_mode_opt.add_item("2: Solo Escorzo 2.5D (Shader)", 2)
	_mode_opt.add_item("3: Pose Default Rig (Rest)", 3)
	_mode_opt.item_selected.connect(func(idx: int) -> void:
		var cb: Callable = callbacks.get("on_mode_changed", Callable())
		if cb.is_valid():
			cb.call(idx)
	)
	vbox.add_child(_mode_opt)

	var scale_row := HBoxContainer.new()
	vbox.add_child(scale_row)
	var scale_lbl := Label.new()
	scale_lbl.text = "Escala Pose:"
	scale_lbl.add_theme_font_size_override("font_size", 11)
	scale_row.add_child(scale_lbl)

	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.0
	_scale_slider.max_value = 1.5
	_scale_slider.step = 0.05
	_scale_slider.value = 1.0
	_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_slider.value_changed.connect(func(val: float) -> void:
		if _scale_val_lbl != null:
			_scale_val_lbl.text = "%.2fx" % val
		var cb: Callable = callbacks.get("on_scale_changed", Callable())
		if cb.is_valid():
			cb.call(val)
	)
	scale_row.add_child(_scale_slider)

	_scale_val_lbl = Label.new()
	_scale_val_lbl.text = "1.00x"
	_scale_val_lbl.custom_minimum_size = Vector2(44.0, 0.0)
	_scale_val_lbl.add_theme_font_size_override("font_size", 11)
	scale_row.add_child(_scale_val_lbl)

	var util_row := HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 6)
	vbox.add_child(util_row)

	_head_cycle_chk = CheckBox.new()
	_head_cycle_chk.text = "Rotar cabezas"
	_head_cycle_chk.button_pressed = false
	_head_cycle_chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head_cycle_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_head_cycle_toggled", Callable())
		if cb.is_valid():
			cb.call(v)
	)
	util_row.add_child(_head_cycle_chk)

	var reset_cam_btn := Button.new()
	reset_cam_btn.text = "Centrar (R)"
	reset_cam_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_reset_camera", Callable())
		if cb.is_valid():
			cb.call()
	)
	util_row.add_child(reset_cam_btn)

	_face_live_chk = CheckBox.new()
	_face_live_chk.text = "Rig Facial Vivo & Personalidad (.tres)"
	_face_live_chk.button_pressed = true
	_face_live_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_face_live_toggled", Callable())
		if cb.is_valid():
			cb.call(v)
	)
	vbox.add_child(_face_live_chk)

	var slowmo_row := HBoxContainer.new()
	slowmo_row.add_theme_constant_override("separation", 6)
	vbox.add_child(slowmo_row)
	var slowmo_lbl := Label.new()
	slowmo_lbl.text = "Velocidad (M):"
	slowmo_lbl.add_theme_font_size_override("font_size", 11)
	slowmo_row.add_child(slowmo_lbl)

	_slowmo_opt = OptionButton.new()
	_slowmo_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slowmo_opt.add_item("1.00x (Normal)", 0)
	_slowmo_opt.add_item("0.50x (Slow-Mo)", 1)
	_slowmo_opt.add_item("0.25x (Ultra Slow)", 2)
	_slowmo_opt.add_item("0.12x (Frame-by-Frame)", 3)
	_slowmo_opt.item_selected.connect(func(idx: int) -> void:
		var cb: Callable = callbacks.get("on_slowmo_changed", Callable())
		if cb.is_valid():
			cb.call(idx)
	)
	slowmo_row.add_child(_slowmo_opt)

	_add_section_header(vbox, "FAMILIA DE VISTA (ESPEJO AUTOMÁTICO)")
	var fam_row := HBoxContainer.new()
	fam_row.add_theme_constant_override("separation", 4)
	vbox.add_child(fam_row)
	var fam_btn_labels: Dictionary = {"s": "S", "se": "SE/SW", "e": "E/W", "ne": "NE/NW", "n": "N"}
	for fam_key: String in BasePoseConfigScript.FAMILY_ORDER:
		var fb := Button.new()
		fb.text = str(fam_btn_labels.get(fam_key, fam_key.to_upper()))
		fb.toggle_mode = true
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.pressed.connect(func() -> void:
			var cb: Callable = callbacks.get("on_family_selected", Callable())
			if cb.is_valid():
				cb.call(fam_key)
		)
		fam_row.add_child(fb)
		_fam_buttons[fam_key] = fb

	_fam_subtitle_lbl = Label.new()
	_fam_subtitle_lbl.add_theme_font_size_override("font_size", 11)
	_fam_subtitle_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0, 0.9))
	vbox.add_child(_fam_subtitle_lbl)

	_pose_tab_box = _build_pose_tab(vbox, callbacks)
	_idle_tab_box = _build_idle_tab(vbox, callbacks)
	_loco_tab_box = _build_loco_tab(vbox, callbacks)
	_turn_tab_box = _build_turn_tab(vbox, callbacks)
	_jiggle_tab_box = _build_jiggle_tab(vbox, callbacks)
	_kiting_tab_box = _build_kiting_tab(vbox, callbacks)

	_feedback_lbl = Label.new()
	_feedback_lbl.text = ""
	_feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_feedback_lbl)

	var readout_lbl := Label.new()
	readout_lbl.text = "Rueda: Zoom | Arrastrar: Mover | Espacio: Idle | M: Slow-Mo | Tab: A/B"
	readout_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readout_lbl.add_theme_font_size_override("font_size", 10)
	readout_lbl.add_theme_color_override("font_color", Color(0.68, 0.74, 0.86, 0.85))
	vbox.add_child(readout_lbl)

	set_active_tab(5)
	sync_from_config(pose_cfg, initial_family, 0, initial_hover_on, idle_cfg, loco_cfg, false, 0, turn_cfg, false, 0, jiggle_cfg, false, 0, kiting_cfg, true, 0, "rev_")
	return layer


func _build_pose_tab(parent: VBoxContainer, callbacks: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	parent.add_child(box)

	var last_sec: String = ""
	for spec: Dictionary in SLIDER_SPECS:
		var sec_id: String = str(spec["sec"])
		if sec_id != last_sec:
			_add_section_header(box, str(SECTION_TITLES.get(sec_id, sec_id.to_upper())))
			last_sec = sec_id
		_build_param_row(box, spec, _pose_slider_rows, callbacks.get("on_param_changed", Callable()) as Callable)

	_add_section_header(box, "PERSISTENCIA POSE BASE (.TRES)")
	_add_io_buttons(
		box,
		"💾 Guardar Pose .tres",
		"↺ Recargar Pose .tres",
		"⚡ Reset Familia a Preset Táctico",
		callbacks.get("on_save_tres", Callable()) as Callable,
		callbacks.get("on_reload_tres", Callable()) as Callable,
		callbacks.get("on_reset_family", Callable()) as Callable
	)
	return box


func _build_idle_tab(parent: VBoxContainer, callbacks: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	parent.add_child(box)

	_add_section_header(box, "CAPAS CONMUTABLES & CADENCIA")
	var on_layer: Callable = callbacks.get("on_idle_layer_toggled", Callable()) as Callable
	_idle_skel_chk = CheckBox.new()
	_idle_skel_chk.text = "Capa 1: Esqueleto 2D + Gyro-Lock Cabeza"
	_idle_skel_chk.toggled.connect(func(v: bool) -> void:
		if on_layer.is_valid():
			on_layer.call("enable_skeleton_layer", v)
	)
	box.add_child(_idle_skel_chk)

	_idle_25d_chk = CheckBox.new()
	_idle_25d_chk.text = "Capa 2: Respiración Escorzo 2.5D"
	_idle_25d_chk.toggled.connect(func(v: bool) -> void:
		if on_layer.is_valid():
			on_layer.call("enable_25d_layer", v)
	)
	box.add_child(_idle_25d_chk)

	_idle_sec_chk = CheckBox.new()
	_idle_sec_chk.text = "Capa 3: Micro-Flotación Cabello/Torso"
	_idle_sec_chk.toggled.connect(func(v: bool) -> void:
		if on_layer.is_valid():
			on_layer.call("enable_secondary_layer", v)
	)
	box.add_child(_idle_sec_chk)

	_idle_cadence_opt = OptionButton.new()
	_idle_cadence_opt.add_item("Cadencia 0: 60 FPS Fluido Orgánico", 0)
	_idle_cadence_opt.add_item("Cadencia 1: Híbrido (Flote 60 + Pose 15 FPS)", 1)
	_idle_cadence_opt.add_item("Cadencia 2: Stepped 24 FPS Anime", 2)
	_idle_cadence_opt.add_item("Cadencia 3: Stepped 15 FPS Sakuga", 3)
	_idle_cadence_opt.item_selected.connect(func(idx: int) -> void:
		var cb: Callable = callbacks.get("on_idle_cadence_changed", Callable())
		if cb.is_valid():
			cb.call(idx)
	)
	box.add_child(_idle_cadence_opt)

	var on_idle_param: Callable = callbacks.get("on_idle_param_changed", Callable()) as Callable
	var on_idle_fam_mul: Callable = callbacks.get("on_idle_family_mul_changed", Callable()) as Callable
	var last_sec: String = ""
	for spec: Dictionary in IDLE_SLIDER_SPECS:
		var sec_id: String = str(spec["sec"])
		if sec_id != last_sec:
			_add_section_header(box, str(SECTION_TITLES.get(sec_id, sec_id.to_upper())))
			last_sec = sec_id
		var cb: Callable = on_idle_fam_mul if bool(spec.get("fam_mul", false)) else on_idle_param
		_build_param_row(box, spec, _idle_slider_rows, cb)

	_add_section_header(box, "PERSISTENCIA IDLE ZERO-G (.TRES)")
	_add_io_buttons(
		box,
		"💾 Guardar Idle .tres",
		"↺ Recargar Idle .tres",
		"⚡ Reset Idle a Preset Táctico",
		callbacks.get("on_save_idle_tres", Callable()) as Callable,
		callbacks.get("on_reload_idle_tres", Callable()) as Callable,
		callbacks.get("on_reset_idle", Callable()) as Callable
	)
	return box


func _build_loco_tab(parent: VBoxContainer, callbacks: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	parent.add_child(box)

	_add_section_header(box, "MODO DE PRUEBA EN BRÚJULA")
	_loco_preview_chk = CheckBox.new()
	_loco_preview_chk.text = "Activar Vuelo/Freno en Brújula"
	_loco_preview_chk.button_pressed = true
	_loco_preview_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_loco_preview_toggled", Callable())
		if cb.is_valid():
			cb.call(v)
	)
	box.add_child(_loco_preview_chk)

	_loco_mode_opt = OptionButton.new()
	_loco_mode_opt.add_item("0: Ciclo Demo (Idle → Vuelo → Freno → Idle)", 0)
	_loco_mode_opt.add_item("1: Fijo: Avance (Vuelo Crucero)", 1)
	_loco_mode_opt.add_item("2: Fijo: Freno Suave (Contra-Inclinación)", 2)
	_loco_mode_opt.add_item("3: Fijo: Reversa (Backpedal)", 3)
	_loco_mode_opt.item_selected.connect(func(idx: int) -> void:
		var cb: Callable = callbacks.get("on_loco_mode_changed", Callable())
		if cb.is_valid():
			cb.call(idx)
	)
	box.add_child(_loco_mode_opt)

	var on_loco_global: Callable = callbacks.get("on_loco_global_changed", Callable()) as Callable
	var on_loco_param: Callable = callbacks.get("on_loco_param_changed", Callable()) as Callable
	var last_sec: String = ""
	for spec: Dictionary in LOCO_SLIDER_SPECS:
		var sec_id: String = str(spec["sec"])
		if sec_id != last_sec:
			_add_section_header(box, str(SECTION_TITLES.get(sec_id, sec_id.to_upper())))
			last_sec = sec_id
		var cb: Callable = on_loco_global if bool(spec.get("global", false)) else on_loco_param
		_build_param_row(box, spec, _loco_slider_rows, cb)

	_add_section_header(box, "PERSISTENCIA VUELO & FRENO (.TRES)")
	_add_io_buttons(
		box,
		"💾 Guardar Vuelo .tres",
		"↺ Recargar Vuelo .tres",
		"⚡ Reset Familia Vuelo",
		callbacks.get("on_save_loco_tres", Callable()) as Callable,
		callbacks.get("on_reload_loco_tres", Callable()) as Callable,
		callbacks.get("on_reset_loco_family", Callable()) as Callable
	)
	return box


func _build_turn_tab(parent: VBoxContainer, callbacks: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	parent.add_child(box)

	_add_section_header(box, "PRUEBA DE GIROS EN BRÚJULA")
	_turn_preview_chk = CheckBox.new()
	_turn_preview_chk.text = "Activar Giros Snappy en Brújula"
	_turn_preview_chk.button_pressed = true
	_turn_preview_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_turn_preview_toggled", Callable())
		if cb.is_valid():
			cb.call(v)
	)
	box.add_child(_turn_preview_chk)

	_turn_mode_opt = OptionButton.new()
	_turn_mode_opt.add_item("0: Ciclo Completo (Cuerpo 45° + Cabeza Whip)", 0)
	_turn_mode_opt.add_item("1: Solo Cuerpo (Pasos 45°)", 1)
	_turn_mode_opt.add_item("2: Whip Cuerpo (Giros Bruscos 90°)", 2)
	_turn_mode_opt.add_item("3: Solo Cabeza (Whip Cervical)", 3)
	_turn_mode_opt.item_selected.connect(func(idx: int) -> void:
		var cb: Callable = callbacks.get("on_turn_mode_changed", Callable())
		if cb.is_valid():
			cb.call(idx)
	)
	box.add_child(_turn_mode_opt)

	var trigger_btn := Button.new()
	trigger_btn.text = "⚡ Disparar Giro Ahora"
	trigger_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_trigger_turn_now", Callable())
		if cb.is_valid():
			cb.call()
	)
	box.add_child(trigger_btn)

	var on_turn_param: Callable = callbacks.get("on_turn_param_changed", Callable()) as Callable
	var on_turn_fam_mul: Callable = callbacks.get("on_turn_family_mul_changed", Callable()) as Callable
	var last_sec: String = ""
	for spec: Dictionary in TURN_SLIDER_SPECS:
		var sec_id: String = str(spec["sec"])
		if sec_id != last_sec:
			_add_section_header(box, str(SECTION_TITLES.get(sec_id, sec_id.to_upper())))
			last_sec = sec_id
		var cb: Callable = on_turn_fam_mul if bool(spec.get("fam_mul", false)) else on_turn_param
		_build_param_row(box, spec, _turn_slider_rows, cb)

	_add_section_header(box, "PERSISTENCIA GIROS SNAPPY (.TRES)")
	_add_io_buttons(
		box,
		"💾 Guardar Giros .tres",
		"↺ Recargar Giros .tres",
		"⚡ Reset Giros a Preset Táctico",
		callbacks.get("on_save_turn_tres", Callable()) as Callable,
		callbacks.get("on_reload_turn_tres", Callable()) as Callable,
		callbacks.get("on_reset_turn_defaults", Callable()) as Callable
	)
	return box


func _build_jiggle_tab(parent: VBoxContainer, callbacks: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	parent.add_child(box)

	_add_section_header(box, "PRUEBA JIGGLE EN BRÚJULA")
	_jiggle_preview_chk = CheckBox.new()
	_jiggle_preview_chk.text = "Activar Jiggle Busto & Glúteos"
	_jiggle_preview_chk.button_pressed = true
	_jiggle_preview_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_jiggle_preview_toggled", Callable())
		if cb.is_valid():
			cb.call(v)
	)
	box.add_child(_jiggle_preview_chk)

	_jiggle_mode_opt = OptionButton.new()
	_jiggle_mode_opt.add_item("0: Giros Snappy 8-Dir + Vuelo/Freno + Jiggle", 0)
	_jiggle_mode_opt.add_item("1: Solo Giros Snappy 45°/90° + Jiggle", 1)
	_jiggle_mode_opt.add_item("2: Solo Ciclo Vuelo y Freno + Jiggle", 2)
	_jiggle_mode_opt.add_item("3: Pose Fija + Impulso Manual", 3)
	_jiggle_mode_opt.item_selected.connect(func(idx: int) -> void:
		var cb: Callable = callbacks.get("on_jiggle_mode_changed", Callable())
		if cb.is_valid():
			cb.call(idx)
	)
	box.add_child(_jiggle_mode_opt)

	var pulse_btn := Button.new()
	pulse_btn.text = "⚡ Disparar Impulso Jiggle Ahora"
	pulse_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_trigger_jiggle_now", Callable())
		if cb.is_valid():
			cb.call()
	)
	box.add_child(pulse_btn)

	var toggle_row := HBoxContainer.new()
	toggle_row.add_theme_constant_override("separation", 6)
	box.add_child(toggle_row)
	var on_jig_toggle: Callable = callbacks.get("on_jiggle_part_toggled", Callable()) as Callable

	_jiggle_bust_chk = CheckBox.new()
	_jiggle_bust_chk.text = "Busto"
	_jiggle_bust_chk.button_pressed = true
	_jiggle_bust_chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jiggle_bust_chk.toggled.connect(func(v: bool) -> void:
		if on_jig_toggle.is_valid():
			on_jig_toggle.call("enable_bust_jiggle", v)
	)
	toggle_row.add_child(_jiggle_bust_chk)

	_jiggle_glute_chk = CheckBox.new()
	_jiggle_glute_chk.text = "Glúteos"
	_jiggle_glute_chk.button_pressed = true
	_jiggle_glute_chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jiggle_glute_chk.toggled.connect(func(v: bool) -> void:
		if on_jig_toggle.is_valid():
			on_jig_toggle.call("enable_glute_jiggle", v)
	)
	toggle_row.add_child(_jiggle_glute_chk)

	var on_jig_param: Callable = callbacks.get("on_jiggle_param_changed", Callable()) as Callable
	var on_jig_fam_mul: Callable = callbacks.get("on_jiggle_family_mul_changed", Callable()) as Callable
	var last_sec: String = ""
	for spec: Dictionary in JIGGLE_SLIDER_SPECS:
		var sec_id: String = str(spec["sec"])
		if sec_id != last_sec:
			_add_section_header(box, str(SECTION_TITLES.get(sec_id, sec_id.to_upper())))
			last_sec = sec_id
		var cb: Callable = on_jig_fam_mul if bool(spec.get("fam_mul", false)) else on_jig_param
		_build_param_row(box, spec, _jiggle_slider_rows, cb)

	_add_section_header(box, "PERSISTENCIA JIGGLE PHYSICS (.TRES)")
	_add_io_buttons(
		box,
		"💾 Guardar Jiggle .tres",
		"↺ Recargar Jiggle .tres",
		"⚡ Reset Jiggle a Preset Táctico",
		callbacks.get("on_save_jiggle_tres", Callable()) as Callable,
		callbacks.get("on_reload_jiggle_tres", Callable()) as Callable,
		callbacks.get("on_reset_jiggle_defaults", Callable()) as Callable
	)
	return box


func _build_kiting_tab(parent: VBoxContainer, callbacks: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	parent.add_child(box)

	_add_section_header(box, "PREVIEW KITING 360° / HOVER-SLIDE")
	_kiting_preview_chk = CheckBox.new()
	_kiting_preview_chk.text = "Activar Kiting / Reversa en Brújula"
	_kiting_preview_chk.button_pressed = true
	_kiting_preview_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_kiting_preview_toggled", Callable())
		if cb.is_valid():
			cb.call(v)
	)
	box.add_child(_kiting_preview_chk)

	_kiting_mode_opt = OptionButton.new()
	_kiting_mode_opt.add_item("0: Ciclo Kiting 360° (Rev → Freno → Strafe +/-)", 0)
	_kiting_mode_opt.add_item("1: Fijo: Reversa 180° (Hover-Slide)", 1)
	_kiting_mode_opt.add_item("2: Fijo: Strafe + (Hacia Cámara / Der.)", 2)
	_kiting_mode_opt.add_item("3: Fijo: Strafe - (Hacia Fondo / Izq.)", 3)
	_kiting_mode_opt.add_item("4: Fijo: Freno de Reversa", 4)
	_kiting_mode_opt.item_selected.connect(func(idx: int) -> void:
		var cb: Callable = callbacks.get("on_kiting_mode_changed", Callable())
		if cb.is_valid():
			cb.call(idx)
	)
	box.add_child(_kiting_mode_opt)

	var phase_row := HBoxContainer.new()
	phase_row.add_theme_constant_override("separation", 6)
	box.add_child(phase_row)
	var phase_lbl := Label.new()
	phase_lbl.text = "Fase Editada:"
	phase_lbl.add_theme_font_size_override("font_size", 11)
	phase_row.add_child(phase_lbl)

	_kiting_phase_opt = OptionButton.new()
	_kiting_phase_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kiting_phase_opt.add_item("Reversa 180° (rev_)", 0)
	_kiting_phase_opt.add_item("Freno Reversa (rbrk_)", 1)
	_kiting_phase_opt.add_item("Strafe + (str_near_)", 2)
	_kiting_phase_opt.add_item("Strafe - (str_far_)", 3)
	_kiting_phase_opt.item_selected.connect(func(idx: int) -> void:
		var cb: Callable = callbacks.get("on_kiting_edit_phase_changed", Callable())
		if cb.is_valid():
			cb.call(idx)
	)
	phase_row.add_child(_kiting_phase_opt)

	var on_k_global: Callable = callbacks.get("on_kiting_global_changed", Callable()) as Callable
	var on_k_param: Callable = callbacks.get("on_kiting_param_changed", Callable()) as Callable
	_add_section_header(box, str(SECTION_TITLES.get("kiting_global", "A. DINÁMICA DE KITING")))
	for spec: Dictionary in KITING_GLOBAL_SPECS:
		_build_param_row(box, spec, _kiting_slider_rows, on_k_global)

	_add_section_header(box, str(SECTION_TITLES.get("kiting_phase", "B. POSTURA DE FASE")))
	for spec: Dictionary in KITING_PHASE_SPECS:
		_build_param_row(box, spec, _kiting_slider_rows, on_k_param)

	_add_section_header(box, "PERSISTENCIA KITING 360° (.TRES)")
	_add_io_buttons(
		box,
		"💾 Guardar Kiting .tres",
		"↺ Recargar Kiting .tres",
		"⚡ Reset Familia Kiting",
		callbacks.get("on_save_kiting_tres", Callable()) as Callable,
		callbacks.get("on_reload_kiting_tres", Callable()) as Callable,
		callbacks.get("on_reset_kiting_family", Callable()) as Callable
	)
	return box


func _add_io_buttons(
	box: VBoxContainer,
	save_txt: String,
	reload_txt: String,
	reset_txt: String,
	on_save: Callable,
	on_reload: Callable,
	on_reset: Callable
) -> void:
	var io_row := HBoxContainer.new()
	io_row.add_theme_constant_override("separation", 6)
	box.add_child(io_row)

	var save_btn := Button.new()
	save_btn.text = save_txt
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(func() -> void:
		if on_save.is_valid():
			on_save.call()
	)
	io_row.add_child(save_btn)

	var reload_btn := Button.new()
	reload_btn.text = reload_txt
	reload_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reload_btn.pressed.connect(func() -> void:
		if on_reload.is_valid():
			on_reload.call()
	)
	io_row.add_child(reload_btn)

	var reset_btn := Button.new()
	reset_btn.text = reset_txt
	reset_btn.pressed.connect(func() -> void:
		if on_reset.is_valid():
			on_reset.call()
	)
	box.add_child(reset_btn)


func set_active_tab(tab_idx: int) -> void:
	_active_tab = clampi(tab_idx, 0, 5)
	for i: int in range(_tab_buttons.size()):
		_tab_buttons[i].set_pressed_no_signal(i == _active_tab)
	if _pose_tab_box != null:
		_pose_tab_box.visible = (_active_tab == 0)
	if _idle_tab_box != null:
		_idle_tab_box.visible = (_active_tab == 1)
	if _loco_tab_box != null:
		_loco_tab_box.visible = (_active_tab == 2)
	if _turn_tab_box != null:
		_turn_tab_box.visible = (_active_tab == 3)
	if _jiggle_tab_box != null:
		_jiggle_tab_box.visible = (_active_tab == 4)
	if _kiting_tab_box != null:
		_kiting_tab_box.visible = (_active_tab == 5)
	if _on_tab_changed_cb.is_valid():
		_on_tab_changed_cb.call(_active_tab)


func get_active_tab() -> int:
	return _active_tab


func sync_from_config(
	pose_cfg: BasePoseConfigScript,
	active_family: String,
	layer_mode: int,
	is_hover_on: bool = false,
	idle_cfg: IdleAnimConfigScript = null,
	loco_cfg: LocomotionAnimConfigScript = null,
	loco_preview_on: bool = false,
	loco_preview_mode: int = 0,
	turn_cfg: TurnAnimConfigScript = null,
	turn_preview_on: bool = false,
	turn_preview_mode: int = 0,
	jiggle_cfg: JigglePhysicsConfigScript = null,
	jiggle_preview_on: bool = false,
	jiggle_preview_mode: int = 0,
	kiting_cfg: KitingAnimConfigScript = null,
	kiting_preview_on: bool = true,
	kiting_preview_mode: int = 0,
	kiting_edit_phase: String = "rev_"
) -> void:
	var fam: String = BasePoseConfigScript.canonical_family_for_view(active_family)
	for fk: Variant in _fam_buttons.keys():
		var btn: Button = _fam_buttons[fk] as Button
		if btn != null:
			btn.set_pressed_no_signal(str(fk) == fam)
	if _fam_subtitle_lbl != null:
		_fam_subtitle_lbl.text = "Editando: %s" % str(BasePoseConfigScript.FAMILY_LABELS.get(fam, fam))

	if _mode_opt != null:
		_mode_opt.select(clampi(layer_mode, 0, _mode_opt.item_count - 1))
	sync_ab_state(layer_mode)
	sync_hover_button(is_hover_on)

	if pose_cfg != null:
		for spec: Dictionary in SLIDER_SPECS:
			var key: String = str(spec["key"])
			_sync_slider_row(_pose_slider_rows, key, pose_cfg.get_param(fam, key), spec)

	if idle_cfg != null:
		if _idle_skel_chk != null:
			_idle_skel_chk.set_pressed_no_signal(idle_cfg.enable_skeleton_layer)
		if _idle_25d_chk != null:
			_idle_25d_chk.set_pressed_no_signal(idle_cfg.enable_25d_layer)
		if _idle_sec_chk != null:
			_idle_sec_chk.set_pressed_no_signal(idle_cfg.enable_secondary_layer)
		if _idle_cadence_opt != null:
			_idle_cadence_opt.select(clampi(idle_cfg.cadence_mode, 0, _idle_cadence_opt.item_count - 1))
		for spec: Dictionary in IDLE_SLIDER_SPECS:
			var key: String = str(spec["key"])
			var v: float = idle_cfg.get_family_mul(fam, key) if bool(spec.get("fam_mul", false)) else idle_cfg.get_global_param(key)
			_sync_slider_row(_idle_slider_rows, key, v, spec)

	if _loco_preview_chk != null:
		_loco_preview_chk.set_pressed_no_signal(loco_preview_on)
	if _loco_mode_opt != null:
		_loco_mode_opt.select(clampi(loco_preview_mode, 0, _loco_mode_opt.item_count - 1))
	if loco_cfg != null:
		for spec: Dictionary in LOCO_SLIDER_SPECS:
			var key: String = str(spec["key"])
			var lv: float = loco_cfg.get_global_param(key) if bool(spec.get("global", false)) else loco_cfg.get_family_param(fam, key)
			_sync_slider_row(_loco_slider_rows, key, lv, spec)

	if _turn_preview_chk != null:
		_turn_preview_chk.set_pressed_no_signal(turn_preview_on)
	if _turn_mode_opt != null:
		_turn_mode_opt.select(clampi(turn_preview_mode, 0, _turn_mode_opt.item_count - 1))
	if turn_cfg != null:
		for spec: Dictionary in TURN_SLIDER_SPECS:
			var key: String = str(spec["key"])
			var tv: float = turn_cfg.get_family_mul(fam, key) if bool(spec.get("fam_mul", false)) else turn_cfg.get_global_param(key)
			_sync_slider_row(_turn_slider_rows, key, tv, spec)

	if _jiggle_preview_chk != null:
		_jiggle_preview_chk.set_pressed_no_signal(jiggle_preview_on)
	if _jiggle_mode_opt != null:
		_jiggle_mode_opt.select(clampi(jiggle_preview_mode, 0, _jiggle_mode_opt.item_count - 1))
	if jiggle_cfg != null:
		if _jiggle_bust_chk != null:
			_jiggle_bust_chk.set_pressed_no_signal(jiggle_cfg.enable_bust_jiggle)
		if _jiggle_glute_chk != null:
			_jiggle_glute_chk.set_pressed_no_signal(jiggle_cfg.enable_glute_jiggle)
		for spec: Dictionary in JIGGLE_SLIDER_SPECS:
			var key: String = str(spec["key"])
			var jv: float = jiggle_cfg.get_family_mul(fam, key) if bool(spec.get("fam_mul", false)) else jiggle_cfg.get_global_param(key)
			_sync_slider_row(_jiggle_slider_rows, key, jv, spec)

	if _kiting_preview_chk != null:
		_kiting_preview_chk.set_pressed_no_signal(kiting_preview_on)
	if _kiting_mode_opt != null:
		_kiting_mode_opt.select(clampi(kiting_preview_mode, 0, _kiting_mode_opt.item_count - 1))
	if _kiting_phase_opt != null:
		var phase_idx: int = KitingAnimConfigScript.PHASE_PREFIXES.find(kiting_edit_phase)
		_kiting_phase_opt.select(clampi(phase_idx if phase_idx >= 0 else 0, 0, _kiting_phase_opt.item_count - 1))
	if kiting_cfg != null:
		for spec: Dictionary in KITING_GLOBAL_SPECS:
			var g_key: String = str(spec["key"])
			_sync_slider_row(_kiting_slider_rows, g_key, kiting_cfg.get_global_param(g_key), spec)
		for spec: Dictionary in KITING_PHASE_SPECS:
			var p_key: String = str(spec["key"])
			_sync_slider_row(_kiting_slider_rows, p_key, kiting_cfg.get_family_param(fam, kiting_edit_phase + p_key), spec)


func _sync_slider_row(rows_dict: Dictionary, key: String, val: float, spec: Dictionary) -> void:
	var row_info: Dictionary = rows_dict.get(key, {}) as Dictionary
	if row_info.is_empty():
		return
	(row_info["slider"] as HSlider).set_value_no_signal(val)
	(row_info["val_lbl"] as Label).text = _format_param_value(val, spec)


func sync_hover_button(is_hover_on: bool) -> void:
	if _hover_btn == null:
		return
	_hover_btn.text = "⏸ Idle Zero-G: EN VIVO (Espacio)" if is_hover_on else "▶ Idle Zero-G: PAUSADO (Espacio)"


func sync_loco_preview_checkbox(enabled: bool) -> void:
	if _loco_preview_chk != null:
		_loco_preview_chk.set_pressed_no_signal(enabled)


func sync_turn_preview_checkbox(enabled: bool) -> void:
	if _turn_preview_chk != null:
		_turn_preview_chk.set_pressed_no_signal(enabled)


func sync_jiggle_preview_checkbox(enabled: bool) -> void:
	if _jiggle_preview_chk != null:
		_jiggle_preview_chk.set_pressed_no_signal(enabled)


func sync_kiting_preview_checkbox(enabled: bool) -> void:
	if _kiting_preview_chk != null:
		_kiting_preview_chk.set_pressed_no_signal(enabled)


func sync_face_live_checkbox(enabled: bool) -> void:
	if _face_live_chk != null:
		_face_live_chk.set_pressed_no_signal(enabled)


func sync_slowmo_index(idx: int) -> void:
	if _slowmo_opt != null:
		_slowmo_opt.select(clampi(idx, 0, _slowmo_opt.item_count - 1))


func sync_ab_state(layer_mode: int) -> void:
	if _ab_btn == null:
		return
	if layer_mode == 3:
		_ab_btn.text = "⚡ A/B: Pose Default Rig [ACTIVA] (Tab)"
	else:
		_ab_btn.text = "⚡ A/B: Guardia Zero-G [ACTIVA] (Tab)"
	if _mode_opt != null and _mode_opt.selected != layer_mode:
		_mode_opt.select(clampi(layer_mode, 0, _mode_opt.item_count - 1))


func set_feedback(msg: String, is_ok: bool = true) -> void:
	if _feedback_lbl == null:
		return
	_feedback_lbl.text = msg
	_feedback_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65, 1.0) if is_ok else Color(1.0, 0.55, 0.55, 1.0))


func _build_param_row(parent: VBoxContainer, spec: Dictionary, rows_dict: Dictionary, on_change: Callable) -> void:
	var key: String = str(spec["key"])
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 1)
	parent.add_child(container)

	var top_row := HBoxContainer.new()
	container.add_child(top_row)

	var lbl := Label.new()
	lbl.text = str(spec["label"])
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 11)
	top_row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = "0.000"
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0, 0.95))
	top_row.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = float(spec["min"])
	slider.max_value = float(spec["max"])
	slider.step = float(spec["step"])
	slider.custom_minimum_size = Vector2(0.0, 18.0)
	slider.value_changed.connect(func(val: float) -> void:
		val_lbl.text = _format_param_value(val, spec)
		if on_change.is_valid():
			on_change.call(key, val)
	)
	container.add_child(slider)

	rows_dict[key] = {
		"slider": slider,
		"val_lbl": val_lbl,
		"spec": spec,
	}


func _format_param_value(val: float, spec: Dictionary) -> String:
	if bool(spec.get("pct", false)):
		return "%d%%" % int(round(val * 100.0))
	if bool(spec.get("rad", false)):
		return "%.3f (%.1f°)" % [val, rad_to_deg(val)]
	return "%.3f" % val


func _add_section_header(parent: VBoxContainer, title_text: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0, 1.0))
	parent.add_child(lbl)
