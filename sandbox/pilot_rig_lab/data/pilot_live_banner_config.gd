class_name PilotLiveBannerConfig
extends Resource
## Configuración data-driven para el Live Banner 2.5D de Selección de Personaje
## (Banner Lab — Valentina v2). Soporta 1 ilustración maestra + 2 máscaras RGB + depth map.

@export_group("Texturas y Máscaras")
@export var base_texture_path: String = "res://assets/characters/selection/selection_valentina.png"
@export var free_arm_texture_path: String = ""
@export var motion_mask_path: String = "res://assets/characters/selection/selection_valentina_mask.png"
@export var fx_mask_path: String = "res://assets/characters/selection/selection_valentina_mask.png"
@export var depth_map_path: String = ""
@export var normal_map_path: String = ""
@export var ilm_map_path: String = ""
@export var ink_sdf_path: String = ""
@export var eye_iris_texture_path: String = "res://sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/heads/head_front_eye_iris.png"
@export var eye_closed_texture_path: String = "res://sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/heads/head_front_eye_closed.png"

@export_group("Estilo Combate 2.5D (Cel-Shading + ILM + Ink SDF)")
@export var cel_shading_enabled: bool = true
@export var cel_strength: float = 0.72
@export var cel_light_angle_deg: float = -40.0
@export var cel_shadow_tint: Color = Color(0.145, 0.145, 0.335, 1.0)
@export var cel_specular_strength: float = 0.95
@export var ilm_ao_strength: float = 0.78
@export var albedo_de_shade: float = 0.28
@export var ink_sdf_enabled: bool = true
@export var ink_strength: float = 0.86
@export var ink_width_bias: float = -0.025
@export var ink_color_tint_mix: float = 0.82
@export var ink_color: Color = Color(0.055, 0.055, 0.13, 1.0)

@export_group("Respiración y Busto (Canal R)")
@export var chest_center_uv: Vector2 = Vector2(0.47, 0.41)
@export var breath_speed: float = 1.65
@export var breath_expand_amp: float = 0.018
@export var breath_lift_px: float = 4.2
@export var hover_jiggle_amp: float = 0.016
@export var jiggle_stiffness: float = 38.0
@export var jiggle_damping: float = 4.8

@export_group("Cabello Zero-G (Canal G)")
@export var hair_sway_speed: float = 2.15
@export var hair_sway_amp_px: float = 7.5
@export var hair_wave_freq: float = 11.0

@export_group("Brazo Libre 2.5D (Canal B de Motion Mask)")
@export var right_shoulder_uv: Vector2 = Vector2(0.4069, 0.2200)
@export var arm_sway_speed: float = 1.65
@export var arm_sway_phase_offset: float = -0.85
@export var arm_persp_scale_amp: float = 0.042
@export var arm_sway_x_px: float = 5.5
@export var arm_sway_y_px: float = 4.0
@export var arm_depth_shade_amp: float = 0.14

@export_group("Secuencia Elegir Piloto (Cascada Alas + Lock-In Overdrive)")
@export var wings_assets_dir: String = "res://sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/wings"
@export var wings_anchor_offset: Vector2 = Vector2(0.0, -145.0)
@export var wings_spread_x: float = 42.0
@export var wings_scale: float = 0.44
@export var wings_deploy_duration_sec: float = 0.34
@export var wings_cascade_duration_sec: float = 0.28
@export var wing_blade_open_sec: float = 0.095
@export var impact_frame_1_sec: float = 0.055
@export var impact_frame_2_sec: float = 0.055
@export var lock_zoom_punch: float = 0.075
@export var lock_camera_shake_px: float = 9.0
@export var lock_arm_flare_deg: float = 11.0
@export var wing_scanner_speed: float = 4.8
@export var wing_scanner_freq: float = 3.2
@export var wing_scanner_glow_intensity: float = 1.35

@export_group("Flotación y Balanceo Corporal")
@export var body_sway_speed: float = 0.85
@export var body_sway_amp_px: float = 3.2
@export var float_bob_speed: float = 1.15
@export var float_bob_amp_px: float = 5.5

@export_group("Ojos Live2D y Parpadeo (Canal B)")
@export var eye_center_uv: Vector2 = Vector2(0.4647, 0.1275)
@export var eye_almond_bounds_uv: Vector4 = Vector4(0.4421, 0.1152, 0.4810, 0.1322)
@export var eye_iris_size_uv: Vector2 = Vector2(0.0250, 0.0180)
@export var blink_enabled: bool = true
@export var blink_interval_min_sec: float = 2.8
@export var blink_interval_max_sec: float = 5.2
@export var blink_duration_sec: float = 0.16
@export var eye_glow_boost: float = 0.45
@export var eye_track_amp_px: float = 2.2

@export_group("Parallax 2.5D y Rim Light")
@export var mouse_parallax_strength: float = 0.022
@export var mouse_tilt_deg: float = 2.4
@export var mouse_smooth_rate: float = 7.5
@export var rim_light_strength: float = 0.62
@export var rim_light_color: Color = Color(0.96, 0.28, 0.46, 1.0)
@export var emissive_pulse_speed: float = 2.4
@export var emissive_boost: float = 0.55

@export_group("Atmósfera del Escaparate")
@export var show_orbital_ring_bg: bool = true
@export var show_stardust: bool = true
@export var ring_color: Color = Color(0.24, 0.86, 1.0, 0.42)
@export var backlight_color: Color = Color(0.88, 0.20, 0.36, 0.34)


func ensure_defaults() -> void:
	breath_speed = clampf(breath_speed, 0.1, 6.0)
	breath_expand_amp = clampf(breath_expand_amp, 0.0, 0.06)
	hair_sway_amp_px = clampf(hair_sway_amp_px, 0.0, 24.0)
	mouse_parallax_strength = clampf(mouse_parallax_strength, 0.0, 0.08)
	blink_interval_min_sec = clampf(blink_interval_min_sec, 0.5, 10.0)
	blink_interval_max_sec = maxf(blink_interval_min_sec + 0.2, clampf(blink_interval_max_sec, 1.0, 14.0))
	blink_duration_sec = clampf(blink_duration_sec, 0.06, 0.5)
	rim_light_strength = clampf(rim_light_strength, 0.0, 1.5)
	emissive_boost = clampf(emissive_boost, 0.0, 2.0)
