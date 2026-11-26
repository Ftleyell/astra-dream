class_name PilotSkillConfig
extends Resource
## Configuración data-driven para la Habilidad Activa (Skill [R]) de un piloto v2.
## Parametriza economía, selección de blanco, Cut-In táctico (3 formatos),
## Impact Frame rápido, disparo Sniper Rail-Lance y marca de Vulnerabilidad Óptica.

enum SkillCutInStyle {
	DIAGONAL_STRIP = 0,
	HORIZONTAL_VISOR = 1,
	TACTICAL_HUD_WINDOW = 2,
}

@export_group("Economía y Selección de Blanco")
@export var cooldown_sec: float = 8.0
@export var search_radius_px: float = 1100.0
@export var cursor_snap_radius_px: float = 240.0
@export var prioritize_boss_and_elite: bool = true

@export_group("Cut-In Táctico y Time-Stop (~0.78s)")
@export var cutin_art_path: String = "res://assets/pilots/valentina_v2/abilities/valentina_v2_skill_cutin.jpg"
@export var use_custom_cutin_art: bool = true
@export var cutin_style: SkillCutInStyle = SkillCutInStyle.DIAGONAL_STRIP
@export var time_stop_sec: float = 0.78
@export var impact_frame_sec: float = 0.14
@export var hold_aim_time_scale: float = 0.22
@export var strip_angle_deg: float = -16.0
@export var strip_height_ratio: float = 0.30
@export var strip_y_ratio: float = 0.44
@export var eye_zoom_scale: float = 1.18
@export var eye_uv_offset: Vector2 = Vector2(0.0, 0.0)
@export var callout_text: String = "OPTIC MATRIX // WEAK POINT"
@export var camera_zoom_punch: float = 0.10
@export var camera_shake_px: float = 7.5
@export var accent_hdr_boost: float = 1.75
@export var bw_luma_threshold: float = 0.28

@export_group("Disparo Sniper Rail-Lance y Vulnerabilidad")
@export var damage_multiplier: float = 4.8
@export var guaranteed_crit: bool = true
@export var bonus_crit_damage: float = 0.65
@export var proc_coefficient: float = 1.0
@export var beam_width_px: float = 44.0
@export var beam_max_length_px: float = 2200.0
@export var beam_duration_sec: float = 0.30
@export var reticle_lead_sec: float = 0.14
@export var pierce_all_in_line: bool = false
@export var clear_corridor_bullets: bool = true
@export var bullet_clear_half_width_px: float = 72.0
@export var apply_vulnerability: bool = true
@export var vulnerability_duration_sec: float = 5.0
@export var vulnerability_crit_taken_mult: float = 1.25


func ensure_defaults() -> void:
	cooldown_sec = clampf(cooldown_sec, 0.5, 60.0)
	search_radius_px = clampf(search_radius_px, 200.0, 3000.0)
	cursor_snap_radius_px = clampf(cursor_snap_radius_px, 40.0, 800.0)
	time_stop_sec = clampf(time_stop_sec, 0.10, 1.50)
	impact_frame_sec = clampf(impact_frame_sec, 0.0, time_stop_sec * 0.6)
	strip_angle_deg = clampf(strip_angle_deg, -45.0, 45.0)
	strip_height_ratio = clampf(strip_height_ratio, 0.10, 0.55)
	strip_y_ratio = clampf(strip_y_ratio, 0.15, 0.85)
	eye_zoom_scale = clampf(eye_zoom_scale, 0.8, 5.0)
	camera_zoom_punch = clampf(camera_zoom_punch, 0.0, 0.45)
	camera_shake_px = clampf(camera_shake_px, 0.0, 32.0)
	accent_hdr_boost = clampf(accent_hdr_boost, 0.5, 3.5)
	bw_luma_threshold = clampf(bw_luma_threshold, 0.05, 0.85)
	damage_multiplier = clampf(damage_multiplier, 0.5, 25.0)
	bonus_crit_damage = clampf(bonus_crit_damage, 0.0, 5.0)
	proc_coefficient = clampf(proc_coefficient, 0.0, 3.0)
	beam_width_px = clampf(beam_width_px, 8.0, 180.0)
	beam_max_length_px = clampf(beam_max_length_px, 400.0, 4000.0)
	beam_duration_sec = clampf(beam_duration_sec, 0.08, 1.50)
	reticle_lead_sec = clampf(reticle_lead_sec, 0.02, 0.60)
	bullet_clear_half_width_px = clampf(bullet_clear_half_width_px, 12.0, 240.0)
	vulnerability_duration_sec = clampf(vulnerability_duration_sec, 0.5, 20.0)
	vulnerability_crit_taken_mult = clampf(vulnerability_crit_taken_mult, 1.0, 3.0)
