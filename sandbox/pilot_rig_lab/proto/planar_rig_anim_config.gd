class_name PlanarRigAnimConfig
extends Resource
## Configuración data-driven para la máquina de estados de animación procedural
## del rig planar de combate (Idle, Strafe, Ascend, Descend, Backpedal, Dash).

const PerspConfigScript = preload("res://sandbox/pilot_rig_lab/proto/rig_perspective_config.gd")

@export_group("Dinámica y Resortes")
@export var joint_stiffness: float = 18.0
@export var joint_damping: float = 0.68
@export var bank_stiffness: float = 13.0
@export var bank_damping: float = 0.70
@export var hover_stiffness: float = 14.0
@export var hover_damping: float = 0.74
@export var scale_stiffness: float = 16.0
@export var scale_damping: float = 0.64
@export var turn_kick_decay: float = 16.0
@export var dir_smooth_rate: float = 28.0
@export var aim_smooth_rate: float = 34.0
@export var speed_smooth_rate: float = 26.0

@export_group("Reloj y Pose Hold Selectivo")
@export var snap_pose_hold_sec: float = 0.022
@export var dash_pose_hold_sec: float = 0.028
@export var head_snap_lag_sec: float = 0.042
@export var enable_skeleton_pose_latch: bool = true
@export var head_pose_stagger_ticks: int = 1
@export var latch_turn_damp_mul: float = 1.25
@export var view_switch_damp_sec: float = 0.14

@export_group("Respiración y Overlapping Action")
@export var breath_asymmetry: float = 0.35
@export var phase_lag_arms: float = 0.45
@export var phase_lag_wrists: float = 0.95
@export var phase_lag_legs: float = 0.38
@export var phase_lag_ankles: float = 0.85
@export var phase_lag_head: float = 0.25

@export_group("Cabeza Viva (Neck + Micro-Resorte)")
@export var head_neck_rot_mul: float = 0.75
@export var head_counter_balance_mul: float = -0.30
@export var head_spring_stiffness: float = 260.0
@export var head_spring_damping: float = 14.0
@export var head_max_lag_px: float = 7.5
@export var head_rot_stiffness: float = 240.0
@export var head_rot_damping: float = 15.0

@export_group("Hover e Inclinación")
@export var max_bank_rad: float = 0.24
@export var profile_bank_scale: float = 0.58
@export var bank_lateral_inertia_px: float = 4.5
@export var hover_bob_idle_px: float = 3.6
@export var hover_bob_move_px: float = 2.8
@export var descend_drop_px: float = 5.0
@export var ascend_lift_px: float = 4.0

@export_group("Foreshortening 2.5D (Escala)")
@export var ascend_scale: Vector2 = Vector2(0.97, 1.035)
@export var descend_scale: Vector2 = Vector2(1.035, 0.955)
@export var dash_scale: Vector2 = Vector2(0.95, 1.05)

@export_group("Torso y Cuello (Radianes)")
@export var strafe_waist_lean: float = 0.14
@export var strafe_chest_lean: float = 0.12
@export var strafe_neck_counter: float = -0.10
@export var turn_kick_waist_mul: float = 0.30
@export var turn_kick_chest_mul: float = 0.35
@export var turn_kick_neck_mul: float = -0.25
@export var aim_twist_chest_mul: float = 0.34
@export var aim_twist_neck_mul: float = 0.55
@export var idle_pelvis_tilt_rad: float = 0.045
@export var idle_waist_counter_rad: float = -0.040
@export var idle_chest_counter_rad: float = 0.025
@export var n_view_chest_lean: float = 0.05

@export_group("Brazos (Radianes)")
@export var idle_shoulder_flare: float = 0.07
@export var idle_elbow_bend: float = 0.08
@export var idle_wrist_float: float = 0.05
@export var strafe_shoulder_sweep: float = 0.16
@export var descend_arm_flare: float = 0.22
@export var descend_elbow_bend: float = 0.14
@export var backpedal_arm_tuck: float = -0.05
@export var backpedal_elbow_bend: float = 0.22
@export var dash_arm_sweep: float = 0.26
@export var dash_elbow_bend: float = 0.18
@export var n_view_shoulder_open: float = 0.12
@export var n_view_elbow_open: float = -0.08
@export var aim_arm_track_strength: float = 0.16
@export var profile_arm_parallel_bias: float = 0.15
@export var profile_arm_swing_amp: float = 0.12
@export var profile_elbow_tuck_rad: float = 0.24
@export var diag_front_arm_lead: float = 0.14
@export var aim_arm_track_limits: Vector2 = Vector2(-0.50, 0.50)
@export var aim_arm_elbow_mul: float = 0.45
@export var aim_arm_rear_follow_mul: float = 0.42
@export var aim_arm_passive_track: float = 0.08

@export_group("Piernas (Radianes)")
@export var idle_thigh_asym: float = 0.06
@export var idle_knee_asym: float = 0.12
@export var idle_knee_asym_diff: float = 0.14
@export var idle_ankle_point: float = 0.08
@export var strafe_thigh_swing: float = 0.18
@export var strafe_knee_trail: float = 0.22
@export var ascend_thigh_trail: float = -0.09
@export var ascend_ankle_point: float = 0.14
@export var descend_thigh_tuck: float = 0.22
@export var descend_knee_tuck: float = 0.34
@export var descend_ankle_tuck: float = -0.12
@export var backpedal_knee_brace: float = 0.18
@export var dash_thigh_sweep: float = -0.14
@export var dash_knee_sweep: float = 0.16
@export var profile_leg_stride_sep: float = 0.22
@export var profile_rear_leg_trail_rad: float = 0.14
@export var profile_rear_knee_bend_rad: float = 0.26
@export var diag_leg_stride_sep: float = 0.15

@export_group("Límites Asimétricos por Vista (S vs N)")
@export var s_shoulder_r_limits: Vector2 = Vector2(-0.34, 0.38)
@export var s_shoulder_l_limits: Vector2 = Vector2(-0.38, 0.34)
@export var s_elbow_r_limits: Vector2 = Vector2(-0.32, 0.42)
@export var s_elbow_l_limits: Vector2 = Vector2(-0.42, 0.32)
@export var s_wrist_r_limits: Vector2 = Vector2(-0.26, 0.26)
@export var s_wrist_l_limits: Vector2 = Vector2(-0.26, 0.26)
@export var s_thigh_limits: Vector2 = Vector2(-0.38, 0.38)
@export var s_knee_limits: Vector2 = Vector2(-0.14, 0.52)
@export var s_ankle_limits: Vector2 = Vector2(-0.32, 0.36)

@export var n_shoulder_r_limits: Vector2 = Vector2(-0.32, 0.36)
@export var n_shoulder_l_limits: Vector2 = Vector2(-0.12, 0.36)
@export var n_elbow_r_limits: Vector2 = Vector2(-0.30, 0.38)
@export var n_elbow_l_limits: Vector2 = Vector2(-0.16, 0.34)
@export var n_wrist_r_limits: Vector2 = Vector2(-0.26, 0.26)
@export var n_wrist_l_limits: Vector2 = Vector2(-0.24, 0.24)
@export var n_thigh_limits: Vector2 = Vector2(-0.38, 0.38)
@export var n_knee_limits: Vector2 = Vector2(-0.14, 0.52)
@export var n_ankle_limits: Vector2 = Vector2(-0.32, 0.36)

@export_group("Límites por Familia Angular (SE, E, NE)")
@export var se_shoulder_r_limits: Vector2 = Vector2(-0.34, 0.32)
@export var se_shoulder_l_limits: Vector2 = Vector2(-0.46, 0.22)
@export var se_elbow_r_limits: Vector2 = Vector2(-0.36, 0.26)
@export var se_elbow_l_limits: Vector2 = Vector2(-0.46, 0.16)
@export var se_wrist_r_limits: Vector2 = Vector2(-0.22, 0.24)
@export var se_wrist_l_limits: Vector2 = Vector2(-0.24, 0.18)
@export var se_thigh_limits: Vector2 = Vector2(-0.22, 0.22)
@export var se_knee_limits: Vector2 = Vector2(-0.12, 0.54)
@export var se_ankle_limits: Vector2 = Vector2(-0.28, 0.32)
@export var e_shoulder_r_limits: Vector2 = Vector2(-0.56, 0.26)
@export var e_shoulder_l_limits: Vector2 = Vector2(-0.48, 0.28)
@export var e_elbow_r_limits: Vector2 = Vector2(-0.54, 0.12)
@export var e_elbow_l_limits: Vector2 = Vector2(-0.48, 0.12)
@export var e_wrist_r_limits: Vector2 = Vector2(-0.26, 0.22)
@export var e_wrist_l_limits: Vector2 = Vector2(-0.24, 0.22)
@export var e_thigh_limits: Vector2 = Vector2(-0.34, 0.34)
@export var e_knee_limits: Vector2 = Vector2(-0.08, 0.56)
@export var e_ankle_limits: Vector2 = Vector2(-0.28, 0.32)
@export var ne_shoulder_r_limits: Vector2 = Vector2(-0.48, 0.26)
@export var ne_shoulder_l_limits: Vector2 = Vector2(-0.26, 0.34)
@export var ne_elbow_r_limits: Vector2 = Vector2(-0.46, 0.18)
@export var ne_elbow_l_limits: Vector2 = Vector2(-0.22, 0.34)
@export var ne_wrist_r_limits: Vector2 = Vector2(-0.24, 0.22)
@export var ne_wrist_l_limits: Vector2 = Vector2(-0.22, 0.24)
@export var ne_thigh_limits: Vector2 = Vector2(-0.24, 0.24)
@export var ne_knee_limits: Vector2 = Vector2(-0.12, 0.52)
@export var ne_ankle_limits: Vector2 = Vector2(-0.28, 0.32)

@export_group("Capas Aditivas (Combate y Locomoción)")
@export var launch_duration_sec: float = 0.18
@export var launch_lean_rad: float = 0.22
@export var launch_scale: Vector2 = Vector2(0.92, 1.09)
@export var air_brake_duration_sec: float = 0.24
@export var air_brake_lean_rad: float = -0.26
@export var air_brake_arm_flare: float = 0.28
@export var air_brake_knee_brace: float = 0.30
@export var air_brake_scale: Vector2 = Vector2(1.08, 0.93)
@export var dash_burst_duration_sec: float = 0.22
@export var dash_burst_scale: Vector2 = Vector2(0.88, 1.14)
@export var dash_burst_arm_sweep: float = 0.34
@export var attack_recoil_duration_sec: float = 0.16
@export var attack_recoil_chest_rad: float = -0.20
@export var attack_recoil_arm_kick: float = 0.32
@export var attack_recoil_scale: Vector2 = Vector2(1.06, 0.95)
@export var hit_react_duration_sec: float = 0.24
@export var hit_react_crunch_rad: float = 0.28
@export var hit_react_arm_flinch: float = 0.30
@export var hit_react_scale: Vector2 = Vector2(1.11, 0.89)
@export var whiplash_duration_sec: float = 0.165
@export var secondary_jiggle_stiffness: float = 210.0
@export var secondary_jiggle_damping: float = 12.5
@export var secondary_jiggle_max_px: float = 10.0

@export_group("Perspectiva 2.5D (Fase 3)")
@export var perspective_config: PerspConfigScript = null
