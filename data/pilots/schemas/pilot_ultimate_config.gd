class_name PilotUltimateConfig
extends Resource
## Configuración data-driven para la Habilidad Definitiva (Ultimate [Q]) de un piloto v2.
## Parametriza Energía 0-100%, Cut-In estilo Wallpaper Engine (LiveBanner 2.5D o CombatRig Pose),
## Impact Frame Híbrido Full-Screen (B/N Carmesí HDR + Fractura de Cristal Obsidiana)
## y descarga global de las 12 cuchillas de alas.

enum CutInRenderMode {
	CUSTOM_CUTIN_ART = 0,
	LIVE_BANNER_25D = 1,
	RIG_BATTLE_POSE = 2,
}

enum FrameComposition {
	FULLSCREEN_BLEED = 0,
	ASYMMETRIC_SLASH = 1,
	CINEMATIC_LETTERBOX = 2,
}

@export_group("Energía Definitiva (0-100%) y Cooldown")
@export var max_energy: float = 100.0
@export var min_cooldown_sec: float = 10.0
@export var energy_per_hit: float = 1.2
@export var energy_crit_bonus: float = 2.2
@export var energy_per_kill: float = 4.5
@export var energy_on_skill_cast: float = 14.0
@export var energy_per_graze: float = 1.8
@export var passive_regen_per_sec: float = 0.5

@export_group("Marco Animado Wallpaper Engine (Cut-In)")
@export var cutin_art_path: String = "res://assets/pilots/valentina_v2/abilities/valentina_v2_ultimate_cutin.jpg"
@export var render_mode: CutInRenderMode = CutInRenderMode.CUSTOM_CUTIN_ART
@export var frame_composition: FrameComposition = FrameComposition.CINEMATIC_LETTERBOX
@export var total_timestop_sec: float = 1.55
@export var cutin_phase_sec: float = 1.05
@export var impact_bw_phase_sec: float = 0.24
@export var impact_shatter_phase_sec: float = 0.18
@export var release_flash_sec: float = 0.08
@export var face_closeup_zoom: float = 1.12
@export var face_focus_offset_px: Vector2 = Vector2(0.0, 0.0)
@export var dutch_tilt_deg: float = -5.0
@export var camera_drift_px: Vector2 = Vector2(26.0, -12.0)
@export var hair_wind_boost: float = 2.2
@export var breath_speed_mult: float = 1.75
@export var eye_flare_boost: float = 1.45
@export var iris_contract_scale: float = 0.82
@export var callout_title: String = "ZERO HORIZON // EXECUTE"

@export_group("Pose de Batalla (Modo RIG_BATTLE_POSE)")
@export var rig_view_direction: Vector2 = Vector2(0.7, 0.7)
@export var rig_torso_lean_deg: float = -7.5
@export var rig_head_tilt_deg: float = 5.5
@export var rig_lead_arm_rot_deg: float = -38.0
@export var rig_trail_arm_rot_deg: float = 24.0
@export var rig_closeup_zoom: float = 2.55
@export var rig_wings_bloom: bool = true

@export_group("Shader Full-Screen: Impact Frame B/N + Fractura Obsidiana")
@export var bw_luma_threshold: float = 0.28
@export var accent_hdr_boost: float = 1.90
@export var secondary_crack_color: Color = Color(0.545, 0.361, 0.965, 1.0)
@export var shatter_cell_density: float = 16.0
@export var shatter_crack_width_px: float = 2.6
@export var shatter_refraction_px: float = 14.0
@export var radial_speedlines_strength: float = 0.62
@export var chromatic_aberration_px: float = 9.5

@export_group("Descarga de las 12 Alas y Sobrecarga Serafín")
@export var blade_count: int = 12
@export var blade_launch_stagger_sec: float = 0.020
@export var blade_flight_sec: float = 0.24
@export var blade_apex_hold_sec: float = 0.12
@export var blade_return_sec: float = 0.28
@export var blade_arc_curvature_px: float = 130.0
@export var blade_scale: float = 0.46
@export var slash_trail_linger_sec: float = 0.40
@export var blade_damage_mult: float = 1.85
@export var shatter_finisher_mult: float = 3.20
@export var guaranteed_crit: bool = true
@export var proc_coefficient_per_blade: float = 0.25
@export var purge_all_bullets: bool = true
@export var overdrive_duration_sec: float = 4.0
@export var overdrive_attack_speed_bonus: float = 0.30


func ensure_defaults() -> void:
	max_energy = clampf(max_energy, 10.0, 500.0)
	min_cooldown_sec = clampf(min_cooldown_sec, 0.0, 120.0)
	cutin_phase_sec = clampf(cutin_phase_sec, 0.15, 3.0)
	impact_bw_phase_sec = clampf(impact_bw_phase_sec, 0.02, 0.60)
	impact_shatter_phase_sec = clampf(impact_shatter_phase_sec, 0.02, 0.80)
	release_flash_sec = clampf(release_flash_sec, 0.02, 0.50)
	total_timestop_sec = maxf(0.25, cutin_phase_sec + impact_bw_phase_sec + impact_shatter_phase_sec + release_flash_sec)
	face_closeup_zoom = clampf(face_closeup_zoom, 0.7, 4.0)
	dutch_tilt_deg = clampf(dutch_tilt_deg, -25.0, 25.0)
	hair_wind_boost = clampf(hair_wind_boost, 0.0, 5.0)
	breath_speed_mult = clampf(breath_speed_mult, 0.2, 4.0)
	eye_flare_boost = clampf(eye_flare_boost, 0.0, 3.0)
	iris_contract_scale = clampf(iris_contract_scale, 0.5, 1.3)
	rig_closeup_zoom = clampf(rig_closeup_zoom, 0.8, 5.0)
	bw_luma_threshold = clampf(bw_luma_threshold, 0.05, 0.85)
	accent_hdr_boost = clampf(accent_hdr_boost, 0.5, 3.5)
	shatter_cell_density = clampf(shatter_cell_density, 4.0, 40.0)
	shatter_crack_width_px = clampf(shatter_crack_width_px, 0.5, 10.0)
	shatter_refraction_px = clampf(shatter_refraction_px, 0.0, 48.0)
	radial_speedlines_strength = clampf(radial_speedlines_strength, 0.0, 1.5)
	chromatic_aberration_px = clampf(chromatic_aberration_px, 0.0, 30.0)
	blade_count = clampi(blade_count, 2, 12)
	blade_launch_stagger_sec = clampf(blade_launch_stagger_sec, 0.0, 0.12)
	blade_flight_sec = clampf(blade_flight_sec, 0.08, 1.0)
	blade_arc_curvature_px = clampf(blade_arc_curvature_px, 0.0, 360.0)
	blade_scale = clampf(blade_scale, 0.15, 1.4)
	slash_trail_linger_sec = clampf(slash_trail_linger_sec, 0.08, 1.5)
	blade_damage_mult = clampf(blade_damage_mult, 0.2, 15.0)
	shatter_finisher_mult = clampf(shatter_finisher_mult, 0.5, 25.0)
	proc_coefficient_per_blade = clampf(proc_coefficient_per_blade, 0.0, 2.0)
	overdrive_duration_sec = clampf(overdrive_duration_sec, 0.0, 15.0)
	overdrive_attack_speed_bonus = clampf(overdrive_attack_speed_bonus, 0.0, 1.5)
