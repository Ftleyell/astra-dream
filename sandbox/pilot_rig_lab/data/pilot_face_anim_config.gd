class_name PilotFaceAnimConfig
extends Resource
## Configuración data-driven del rig facial vivo de Valentina v2 (Ojos, Expresiones, Soldadura Cervical, Parallax 2.5D, Cabello 3 Zonas y Monóculo).

enum ExpressionPreset {
	NEUTRAL_IDLE = 0,
	COMBAT_FOCUS = 1,
	CONFIDENT_SMIRK = 2,
	ALERT_SURPRISE = 3,
	HIT_WINCE = 4,
	COMMS_TALKING = 5,
}

enum GazeMode {
	FOLLOW_CURSOR = 0,
	AUTO_SACCADES = 1,
	CENTER_LOCK = 2,
}

enum LabViewMode {
	HERO_CLOSEUP = 0,
	GALLERY_8DIR = 1,
}

enum PersonalityProfile {
	STOIC_TACTICAL = 0,
	CONFIDENT_ACE = 1,
	EXPRESSIVE_ANIME = 2,
}

const PERSONALITY_LABELS: Array[String] = [
	"Táctica Fría (Estoica)",
	"Piloto Ace Confiada",
	"Anime Dinámico",
]

const COMBAT_MOOD_TABLES: Dictionary = {
	PersonalityProfile.STOIC_TACTICAL: {
		"IDLE": {"squint": 0.04, "brow_y": -0.15, "brow_tilt": -0.012, "mouth_open": 0.0, "mouth_smile": -0.02, "iris_scale": 1.00, "iris_glow": 0.28, "monocle_floor": 0.18},
		"FOCUS": {"squint": 0.12, "brow_y": -1.05, "brow_tilt": -0.052, "mouth_open": 0.0, "mouth_smile": -0.22, "iris_scale": 0.93, "iris_glow": 0.74, "monocle_floor": 0.68},
		"BACKPEDAL": {"squint": 0.14, "brow_y": -0.85, "brow_tilt": -0.044, "mouth_open": 0.0, "mouth_smile": -0.18, "iris_scale": 0.94, "iris_glow": 0.65, "monocle_floor": 0.60},
		"BRAKE_DASH": {"squint": 0.02, "brow_y": 0.75, "brow_tilt": -0.015, "mouth_open": 0.08, "mouth_smile": -0.16, "iris_scale": 0.90, "iris_glow": 0.95, "monocle_floor": 0.88},
		"FIRE": {"squint": 0.34, "brow_y": -1.20, "brow_tilt": -0.060, "mouth_open": 0.06, "mouth_smile": -0.28, "iris_scale": 0.89, "iris_glow": 1.08, "monocle_floor": 1.10},
		"HIT_WINCE": {"squint": 0.94, "brow_y": -1.65, "brow_tilt": -0.075, "mouth_open": 0.18, "mouth_smile": -0.58, "iris_scale": 0.80, "iris_glow": 0.45, "monocle_floor": 1.40},
		"COMMS": {"squint": 0.14, "brow_y": 0.15, "brow_tilt": -0.010, "mouth_open": 0.45, "mouth_smile": -0.04, "iris_scale": 0.98, "iris_glow": 0.62, "monocle_floor": 0.82},
	},
	PersonalityProfile.CONFIDENT_ACE: {
		"IDLE": {"squint": 0.03, "brow_y": 0.10, "brow_tilt": 0.008, "mouth_open": 0.0, "mouth_smile": 0.32, "iris_scale": 1.04, "iris_glow": 0.32, "monocle_floor": 0.22},
		"FOCUS": {"squint": 0.10, "brow_y": -0.85, "brow_tilt": -0.042, "mouth_open": 0.0, "mouth_smile": 0.08, "iris_scale": 0.96, "iris_glow": 0.78, "monocle_floor": 0.70},
		"BACKPEDAL": {"squint": 0.12, "brow_y": -0.60, "brow_tilt": -0.030, "mouth_open": 0.0, "mouth_smile": 0.12, "iris_scale": 0.97, "iris_glow": 0.68, "monocle_floor": 0.62},
		"BRAKE_DASH": {"squint": 0.06, "brow_y": 0.95, "brow_tilt": 0.018, "mouth_open": 0.12, "mouth_smile": 0.42, "iris_scale": 0.92, "iris_glow": 1.00, "monocle_floor": 0.92},
		"FIRE": {"squint": 0.30, "brow_y": -1.00, "brow_tilt": -0.048, "mouth_open": 0.10, "mouth_smile": -0.05, "iris_scale": 0.91, "iris_glow": 1.12, "monocle_floor": 1.15},
		"HIT_WINCE": {"squint": 0.90, "brow_y": -1.55, "brow_tilt": -0.068, "mouth_open": 0.26, "mouth_smile": -0.62, "iris_scale": 0.80, "iris_glow": 0.48, "monocle_floor": 1.42},
		"COMMS": {"squint": 0.10, "brow_y": 0.38, "brow_tilt": 0.012, "mouth_open": 0.52, "mouth_smile": 0.24, "iris_scale": 1.03, "iris_glow": 0.66, "monocle_floor": 0.85},
	},
	PersonalityProfile.EXPRESSIVE_ANIME: {
		"IDLE": {"squint": 0.00, "brow_y": 0.35, "brow_tilt": 0.018, "mouth_open": 0.04, "mouth_smile": 0.56, "iris_scale": 1.06, "iris_glow": 0.36, "monocle_floor": 0.26},
		"FOCUS": {"squint": 0.08, "brow_y": -0.95, "brow_tilt": -0.050, "mouth_open": 0.05, "mouth_smile": -0.10, "iris_scale": 0.95, "iris_glow": 0.82, "monocle_floor": 0.74},
		"BACKPEDAL": {"squint": 0.10, "brow_y": -0.55, "brow_tilt": -0.032, "mouth_open": 0.08, "mouth_smile": 0.05, "iris_scale": 0.96, "iris_glow": 0.72, "monocle_floor": 0.65},
		"BRAKE_DASH": {"squint": 0.00, "brow_y": 2.00, "brow_tilt": 0.032, "mouth_open": 0.34, "mouth_smile": 0.15, "iris_scale": 0.89, "iris_glow": 1.05, "monocle_floor": 0.96},
		"FIRE": {"squint": 0.32, "brow_y": -1.15, "brow_tilt": -0.055, "mouth_open": 0.26, "mouth_smile": -0.22, "iris_scale": 0.90, "iris_glow": 1.18, "monocle_floor": 1.22},
		"HIT_WINCE": {"squint": 0.92, "brow_y": -1.65, "brow_tilt": -0.072, "mouth_open": 0.36, "mouth_smile": -0.74, "iris_scale": 0.78, "iris_glow": 0.50, "monocle_floor": 1.48},
		"COMMS": {"squint": 0.08, "brow_y": 0.55, "brow_tilt": 0.018, "mouth_open": 0.62, "mouth_smile": 0.32, "iris_scale": 1.04, "iris_glow": 0.72, "monocle_floor": 0.90},
	},
}

const PRESET_LABELS: Array[String] = [
	"0: Neutral / Idle",
	"1: Enfoque Combate",
	"2: Media Sonrisa",
	"3: Alerta / Sorpresa",
	"4: Impacto / Mueca",
	"5: Comms Hablando",
]

const GAZE_LABELS: Array[String] = [
	"Seguir Cursor",
	"Auto-Sacadas",
	"Mirada Fija Centro",
]

const FLOAT_DEFAULTS: Dictionary = {
	"eye_look_max_px": 3.2,
	"eye_saccade_speed": 2.4,
	"eye_smooth_rate": 16.0,
	"blink_interval_sec": 3.4,
	"blink_duration_sec": 0.16,
	"double_blink_chance": 0.25,
	"squint_amount": 0.0,
	"iris_scale_offset": 0.0,
	"eye_highlight_strength": 0.92,
	"eye_lid_shadow_strength": 0.72,
	"eye_far_clarity": 0.90,
	"eye_combat_glow_strength": 0.52,
	"expression_blend_rate": 10.0,
	"brow_lift_px": 0.0,
	"brow_furrow": 0.0,
	"mouth_open": 0.0,
	"mouth_smile": 0.0,
	"comms_talk_speed_hz": 6.5,
	"comms_talk_amp": 0.72,
	"neck_weld_strength": 0.92,
	"cursor_head_tilt_deg": 4.5,
	"neck_idle_nod_px": 1.6,
	"neck_idle_freq_rad": 1.65,
	"chin_shadow_strength": 0.48,
	"face_parallax_px": 4.2,
	"face_parallax_cursor_gain": 1.35,
	"face_parallax_pivot": 0.60,
	"hair_bangs_amp_px": 2.8,
	"hair_bangs_freq_hz": 2.35,
	"hair_bangs_damping": 0.30,
	"hair_sides_amp_px": 3.8,
	"hair_sides_freq_hz": 2.05,
	"hair_sides_damping": 0.28,
	"hair_back_amp_px": 4.5,
	"hair_back_freq_hz": 1.80,
	"hair_back_damping": 0.32,
	"hair_wind_strength": 0.45,
	"hair_normal_light_strength": 0.020,
	"hair_max_clamp_px": 7.5,
	"monocle_hud_strength": 0.75,
	"monocle_gaze_reactivity": 0.85,
	"combat_aim_lead_gain": 1.35,
	"combat_parallax_gain": 1.15,
	"combat_turn_blink_dur_sec": 0.115,
	"combat_turn_blink_cooldown_sec": 0.35,
	"combat_hair_vel_drag_px": 4.2,
	"combat_hair_brake_overshoot_px": 5.2,
	"combat_hair_turn_whip_impulse": 82.0,
	"combat_fire_flinch_sec": 0.18,
	"combat_dash_react_sec": 0.34,
	"combat_hit_wince_sec": 0.44,
	"combat_comms_default_sec": 2.6,
	"combat_focus_speed_thresh": 0.32,
	"combat_brake_thresh": 0.32,
}

@export var anim_id: String = "valentina_v2_face_live"
@export var display_name: String = "Valentina v2 — Rig Facial Vivo"

# A. Ojos y Parpadeo
@export var enable_eyes_live: bool = true
@export var gaze_mode: int = GazeMode.FOLLOW_CURSOR
@export var eye_look_max_px: float = 3.2
@export var eye_saccade_speed: float = 2.4
@export var eye_smooth_rate: float = 16.0
@export var blink_interval_sec: float = 3.4
@export var blink_duration_sec: float = 0.16
@export var double_blink_chance: float = 0.25
@export var squint_amount: float = 0.0
@export var enable_pupil_dilation: bool = true
@export var iris_scale_offset: float = 0.0
@export var eye_highlight_strength: float = 0.92
@export var eye_lid_shadow_strength: float = 0.72
@export var eye_far_clarity: float = 0.90
@export var eye_combat_glow_strength: float = 0.52

# B. Expresiones, Cejas, Boca y Comms
@export var expression_preset: int = ExpressionPreset.NEUTRAL_IDLE
@export var expression_blend_rate: float = 10.0
@export var brow_lift_px: float = 0.0
@export var brow_furrow: float = 0.0
@export var mouth_open: float = 0.0
@export var mouth_smile: float = 0.0
@export var comms_talk_speed_hz: float = 6.5
@export var comms_talk_amp: float = 0.72

# C. Soldadura Cervical y Cabeceo
@export var enable_neck_weld: bool = true
@export var neck_weld_strength: float = 0.92
@export var cursor_head_tilt_deg: float = 4.5
@export var neck_idle_nod_px: float = 1.6
@export var neck_idle_freq_rad: float = 1.65
@export var chin_shadow_strength: float = 0.48

# D. Parallax Facial 2.5D (Live2D)
@export var enable_face_parallax: bool = true
@export var face_parallax_px: float = 4.2
@export var face_parallax_cursor_gain: float = 1.35
@export var face_parallax_pivot: float = 0.60

# E. Cabello 3 Zonas (R=Flequillo, G=Laterales, B=Puntas/Nuca)
@export var enable_hair_3zone: bool = true
@export var hair_bangs_amp_px: float = 2.8
@export var hair_bangs_freq_hz: float = 2.35
@export var hair_bangs_damping: float = 0.30
@export var hair_sides_amp_px: float = 3.8
@export var hair_sides_freq_hz: float = 2.05
@export var hair_sides_damping: float = 0.28
@export var hair_back_amp_px: float = 4.5
@export var hair_back_freq_hz: float = 1.80
@export var hair_back_damping: float = 0.32
@export var hair_wind_strength: float = 0.45
@export var hair_normal_light_strength: float = 0.020
@export var hair_max_clamp_px: float = 7.5

# F. Monóculo Táctico Vivo
@export var enable_monocle_hud: bool = true
@export var monocle_hud_strength: float = 0.75
@export var monocle_gaze_reactivity: float = 0.85

# G. Personalidad & Reactividad de Combate (PlanarRigFaceController)
@export var personality_profile: int = PersonalityProfile.STOIC_TACTICAL
@export var enable_blink_on_turn: bool = true
@export var enable_combat_hair_physics: bool = true
@export var enable_combat_aim_lead: bool = true
@export var combat_aim_lead_gain: float = 1.35
@export var combat_parallax_gain: float = 1.15
@export var combat_turn_blink_dur_sec: float = 0.115
@export var combat_turn_blink_cooldown_sec: float = 0.35
@export var combat_hair_vel_drag_px: float = 4.2
@export var combat_hair_brake_overshoot_px: float = 5.2
@export var combat_hair_turn_whip_impulse: float = 82.0
@export var combat_fire_flinch_sec: float = 0.18
@export var combat_dash_react_sec: float = 0.34
@export var combat_hit_wince_sec: float = 0.44
@export var combat_comms_default_sec: float = 2.6
@export var combat_focus_speed_thresh: float = 0.32
@export var combat_brake_thresh: float = 0.32


## Devuelve las metas emocionales de combate para el perfil de personalidad y mood solicitados.
static func get_combat_mood_targets(personality_id: int, mood_key: String) -> Dictionary:
	var profile_tbl: Dictionary = COMBAT_MOOD_TABLES.get(personality_id, COMBAT_MOOD_TABLES[PersonalityProfile.STOIC_TACTICAL]) as Dictionary
	return (profile_tbl.get(mood_key, profile_tbl["IDLE"]) as Dictionary).duplicate()


## Devuelve las metas base de expresión para el preset indicado.
static func get_preset_targets(preset_id: int) -> Dictionary:
	match preset_id:
		ExpressionPreset.COMBAT_FOCUS:
			return {"squint": 0.28, "brow_y": -1.1, "brow_tilt": -0.055, "mouth_open": 0.0, "mouth_smile": -0.25, "iris_scale": 0.91, "iris_glow": 0.76}
		ExpressionPreset.CONFIDENT_SMIRK:
			return {"squint": 0.22, "brow_y": 0.6, "brow_tilt": 0.030, "mouth_open": 0.05, "mouth_smile": 0.72, "iris_scale": 1.06, "iris_glow": 0.48}
		ExpressionPreset.ALERT_SURPRISE:
			return {"squint": 0.0, "brow_y": 2.4, "brow_tilt": 0.040, "mouth_open": 0.48, "mouth_smile": -0.10, "iris_scale": 0.83, "iris_glow": 0.92}
		ExpressionPreset.HIT_WINCE:
			return {"squint": 0.88, "brow_y": -1.6, "brow_tilt": -0.070, "mouth_open": 0.32, "mouth_smile": -0.75, "iris_scale": 0.80, "iris_glow": 0.42}
		ExpressionPreset.COMMS_TALKING:
			return {"squint": 0.08, "brow_y": 0.45, "brow_tilt": 0.015, "mouth_open": 0.55, "mouth_smile": 0.22, "iris_scale": 1.03, "iris_glow": 0.65}
		_:
			return {"squint": 0.0, "brow_y": 0.0, "brow_tilt": 0.0, "mouth_open": 0.0, "mouth_smile": 0.05, "iris_scale": 1.00, "iris_glow": 0.28}


## Restaura todos los parámetros exportados a sus valores calibrados por defecto.
func reset_to_defaults() -> void:
	enable_eyes_live = true
	enable_pupil_dilation = true
	gaze_mode = GazeMode.FOLLOW_CURSOR
	expression_preset = ExpressionPreset.NEUTRAL_IDLE
	enable_neck_weld = true
	enable_face_parallax = true
	enable_hair_3zone = true
	enable_monocle_hud = true
	personality_profile = PersonalityProfile.STOIC_TACTICAL
	enable_blink_on_turn = true
	enable_combat_hair_physics = true
	enable_combat_aim_lead = true
	for k: String in FLOAT_DEFAULTS.keys():
		if k in self:
			set(k, float(FLOAT_DEFAULTS[k]))


## Actualiza una propiedad numérica asegurando existencia en el recurso.
func set_param(param_key: String, value: float) -> void:
	if param_key in self:
		set(param_key, value)


## Guarda el recurso `.tres` en disco en la ruta indicada.
func save_to_path(path: String) -> Error:
	return ResourceSaver.save(self, path)
