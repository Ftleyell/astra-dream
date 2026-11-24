class_name PilotDialoguePortraitEntry
extends Resource
## Entrada individual de emoción/pose para retratos de diálogo vivos (Living Dialogue).
## Almacena las rutas albedo/máscaras y los parámetros emocionales de luz y movimiento.

enum EntryMotion {
	SMOOTH_FADE = 0,
	TACTICAL_SLIDE = 1,
	LOCKON_ZOOM = 2,
	ALERT_SHAKE = 3,
	CONFIDENT_TILT = 4,
}

@export_group("Identidad y Pose")
@export var emotion_id: StringName = &"neutral"
@export var display_label: String = "Neutral"
@export var pose_group: String = "pose_a_briefing"

@export_group("Texturas Shader-Ready")
@export var texture_path: String = ""
@export var normal_map_path: String = ""
@export var depth_map_path: String = ""
@export var id_mask_path: String = ""
@export var ilm_map_path: String = ""
@export var motion_mask_path: String = ""

@export_group("Iluminación Emocional Cósmica")
@export var rim_light_color: Color = Color(0.56, 0.72, 1.0, 1.0)
@export_range(0.0, 1.5, 0.01) var rim_light_strength: float = 0.56
@export_range(-180.0, 180.0, 1.0) var rim_light_angle_deg: float = -38.0
@export_range(0.0, 1.0, 0.01) var cel_strength: float = 0.48
@export var cel_shadow_tint: Color = Color(0.145, 0.145, 0.335, 1.0)
@export_range(0.0, 1.5, 0.01) var specular_strength: float = 0.72
@export_range(0.0, 1.0, 0.01) var ilm_ao_strength: float = 0.58
@export_range(0.0, 1.0, 0.01) var face_shadow_protect: float = 0.92

@export_group("Movimiento Orgánico Zero-G")
@export_range(0.0, 20.0, 0.1) var breath_amp_px: float = 4.5
@export_range(0.1, 6.0, 0.05) var breath_speed: float = 1.45
@export_range(0.0, 5.0, 0.05) var sway_deg: float = 0.55
@export_range(0.0, 14.0, 0.1) var hair_sway_amp_px: float = 3.2
@export_range(0.0, 1.5, 0.01) var eye_shimmer_strength: float = 0.32
@export_enum("Smooth Fade:0", "Tactical Slide:1", "Lock-On Zoom:2", "Alert Shake:3", "Confident Tilt:4") var entry_motion: int = EntryMotion.SMOOTH_FADE
@export_range(0.75, 1.25, 0.01) var scale_bias: float = 1.0
@export var offset_px: Vector2 = Vector2.ZERO
