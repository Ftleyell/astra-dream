class_name PilotIdleAnimConfig
extends Resource
## Configuración data-driven de animación Idle Zero-G multicapa (Valentina v2 8-Dir).
## Separa Capa 1 (Esqueleto 2D + Gyro-Lock cabeza), Capa 2 (Respiración 2.5D) y Capa 3 (Micro-flotación secundaria).

const BasePoseConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_base_pose_config.gd")

enum CadenceMode {
	FLUID_60 = 0,
	HYBRID_FLOAT60_POSE15 = 1,
	STEPPED_24 = 2,
	STEPPED_15 = 3,
}

const FAMILY_ORDER: Array[String] = ["s", "se", "e", "ne", "n"]
const MUL_KEYS: Array[String] = ["float_scale", "arms_scale", "legs_scale", "persp_25d_scale", "secondary_scale"]

@export var anim_id: String = "idle_zero_g_tactical"
@export var display_name: String = "Idle Zero-G — Suspensión Táctica Viva"

# Toggles de Capas y Cadencia
@export var enable_skeleton_layer: bool = true
@export var enable_25d_layer: bool = true
@export var enable_secondary_layer: bool = true
@export var cadence_mode: int = CadenceMode.FLUID_60
@export var master_intensity: float = 1.0

# A. Ritmo, Figura-8 y Gyro-Lock de Cabeza (Capa 1 Raíz)
@export var cycle_speed_rad: float = 1.55
@export var harmonic_asymmetry: float = 0.16
@export var float_amp_y_px: float = 3.8
@export var float_fig8_x_px: float = 1.65
@export var pelvis_sway_rot: float = 0.014
@export var head_gyro_lag_px: float = 0.85
@export var head_gyro_rot_rad: float = 0.016
@export var head_phase_lag: float = 0.55

# B. Respiración y Onda Articular Desfasada (Capa 1 Follow-Through)
@export var waist_sway_rot: float = 0.014
@export var chest_breath_rot: float = 0.018
@export var neck_counter_rot: float = 0.015
@export var shoulder_wave_rot: float = 0.022
@export var elbow_wave_rot: float = 0.028
@export var wrist_wave_rot: float = 0.032
@export var arm_chain_phase_lag: float = 0.48
@export var arm_lr_phase_offset: float = 0.65
@export var thigh_wave_rot: float = 0.018
@export var knee_wave_rot: float = 0.026
@export var ankle_wave_rot: float = 0.024
@export var leg_chain_phase_lag: float = 0.50
@export var leg_scissor_phase_offset: float = 1.85

# C. Respiración de Escorzo 2.5D (Capa 2 Shader)
@export var torso_trap_breath: float = 0.014
@export var torso_yaw_sway: float = 0.012
@export var arm_phi1_wave: float = 0.028
@export var arm_phi2_wave: float = 0.042
@export var leg_phi_thigh_wave: float = 0.032
@export var leg_phi_shin_wave: float = 0.048
@export var leg_distal_wave: float = 0.024
@export var leg_depth_phase_wave: float = 0.030

# D. Micro-Flotación Secundaria: Cabello y Torso (Capa 3 Máscaras Jiggle)
@export var hair_float_amp_px: float = 1.65
@export var hair_phase_lag: float = 0.75
@export var torso_secondary_amp_px: float = 1.05
@export var torso_secondary_phase_lag: float = 0.50

# E. Multiplicadores por Familia
@export var family_multipliers: Dictionary = {}


func _init() -> void:
	ensure_initialized()


static func build_default_family_multipliers() -> Dictionary:
	return {
		"s": {"float_scale": 1.0, "arms_scale": 1.0, "legs_scale": 0.65, "persp_25d_scale": 1.0, "secondary_scale": 1.0},
		"se": {"float_scale": 1.0, "arms_scale": 1.0, "legs_scale": 1.0, "persp_25d_scale": 1.0, "secondary_scale": 1.0},
		"e": {"float_scale": 1.0, "arms_scale": 0.85, "legs_scale": 1.0, "persp_25d_scale": 1.0, "secondary_scale": 1.0},
		"ne": {"float_scale": 1.0, "arms_scale": 1.0, "legs_scale": 1.0, "persp_25d_scale": 1.0, "secondary_scale": 1.0},
		"n": {"float_scale": 1.0, "arms_scale": 1.0, "legs_scale": 0.65, "persp_25d_scale": 1.0, "secondary_scale": 1.0},
	}


func ensure_initialized() -> void:
	var defaults: Dictionary = build_default_family_multipliers()
	for fam: String in FAMILY_ORDER:
		var def_fam: Dictionary = defaults[fam] as Dictionary
		if not family_multipliers.has(fam) or not (family_multipliers[fam] is Dictionary):
			family_multipliers[fam] = def_fam.duplicate(true)
			continue
		var cur_fam: Dictionary = family_multipliers[fam] as Dictionary
		for k: String in MUL_KEYS:
			if not cur_fam.has(k):
				cur_fam[k] = float(def_fam[k])


func reset_to_defaults() -> void:
	enable_skeleton_layer = true
	enable_25d_layer = true
	enable_secondary_layer = true
	cadence_mode = CadenceMode.FLUID_60
	master_intensity = 1.0
	cycle_speed_rad = 1.55
	harmonic_asymmetry = 0.16
	float_amp_y_px = 3.8
	float_fig8_x_px = 1.65
	pelvis_sway_rot = 0.014
	head_gyro_lag_px = 0.85
	head_gyro_rot_rad = 0.016
	head_phase_lag = 0.55
	waist_sway_rot = 0.014
	chest_breath_rot = 0.018
	neck_counter_rot = 0.015
	shoulder_wave_rot = 0.022
	elbow_wave_rot = 0.028
	wrist_wave_rot = 0.032
	arm_chain_phase_lag = 0.48
	arm_lr_phase_offset = 0.65
	thigh_wave_rot = 0.018
	knee_wave_rot = 0.026
	ankle_wave_rot = 0.024
	leg_chain_phase_lag = 0.50
	leg_scissor_phase_offset = 1.85
	torso_trap_breath = 0.014
	torso_yaw_sway = 0.012
	arm_phi1_wave = 0.028
	arm_phi2_wave = 0.042
	leg_phi_thigh_wave = 0.032
	leg_phi_shin_wave = 0.048
	leg_distal_wave = 0.024
	leg_depth_phase_wave = 0.030
	hair_float_amp_px = 1.65
	hair_phase_lag = 0.75
	torso_secondary_amp_px = 1.05
	torso_secondary_phase_lag = 0.50
	family_multipliers = build_default_family_multipliers()


func reset_family_multipliers(fam: String) -> void:
	var defaults: Dictionary = build_default_family_multipliers()
	var can_fam: String = BasePoseConfigScript.canonical_family_for_view(fam)
	if defaults.has(can_fam):
		family_multipliers[can_fam] = (defaults[can_fam] as Dictionary).duplicate(true)


func get_global_param(key: String) -> float:
	if key in self:
		return float(get(key))
	return 0.0


func set_global_param(key: String, val: float) -> void:
	if key in self:
		set(key, val)


func get_family_mul(fam: String, key: String) -> float:
	ensure_initialized()
	var can_fam: String = BasePoseConfigScript.canonical_family_for_view(fam)
	var d: Dictionary = family_multipliers.get(can_fam, {}) as Dictionary
	return float(d.get(key, 1.0))


func set_family_mul(fam: String, key: String, val: float) -> void:
	ensure_initialized()
	var can_fam: String = BasePoseConfigScript.canonical_family_for_view(fam)
	var d: Dictionary = family_multipliers.get(can_fam, {}) as Dictionary
	d[key] = val
	family_multipliers[can_fam] = d
