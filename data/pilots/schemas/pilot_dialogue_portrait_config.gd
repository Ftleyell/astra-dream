class_name PilotDialoguePortraitConfig
extends Resource
## Configuración data-driven multi-piloto para close-ups de diálogo con shaders,
## máscaras y animación orgánica Zero-G (Living Dialogue Portraits).

const EntryScript = preload("res://data/pilots/schemas/pilot_dialogue_portrait_entry.gd")

@export_group("Identidad")
@export var pilot_id: String = "valentina_v2"
@export var display_name: String = "Valentina"
@export var default_emotion: StringName = &"neutral"

@export_group("Presentación y Transiciones")
@export_range(240.0, 1280.0, 4.0) var base_display_height_px: float = 860.0
@export var left_slot_pos: Vector2 = Vector2(442.0, 1080.0)
@export var right_slot_pos: Vector2 = Vector2(1478.0, 1080.0)
@export_range(0.50, 0.99, 0.01) var bottom_fade_start: float = 0.86
@export_range(0.50, 4.0, 0.05) var bottom_fade_power: float = 1.8
@export_range(0.04, 0.60, 0.01) var transition_duration_sec: float = 0.16
@export_range(0.0, 20.0, 0.5) var speaking_bounce_px: float = 0.0
@export_range(0.0, 0.10, 0.002) var speaking_scale_punch: float = 0.0

@export_group("Dinámica de Turno y Cámara")
@export_range(0.20, 1.0, 0.01) var listening_dim_brightness: float = 0.58
@export_range(0.0, 0.80, 0.01) var listening_desaturate: float = 0.25
@export_range(0.85, 1.0, 0.005) var listening_scale_mult: float = 0.95
@export_range(1.0, 1.15, 0.005) var active_focus_scale: float = 1.04
@export var follow_mouse: bool = false
@export_range(0.0, 30.0, 0.5) var mouse_parallax_px: float = 0.0
@export_range(0.0, 5.0, 0.1) var mouse_tilt_deg: float = 0.0

@export_group("Atmósfera y Comms")
@export var show_cosmic_particles: bool = true
@export var comms_tint_color: Color = Color(0.42, 0.90, 1.0, 1.0)

@export_group("Catálogo de Emociones")
@export var entries: Array[EntryScript] = []


func get_entry(emotion_id: StringName) -> EntryScript:
	var target: StringName = emotion_id
	for entry: EntryScript in entries:
		if entry != null and entry.emotion_id == target:
			return entry
	for entry: EntryScript in entries:
		if entry != null and entry.emotion_id == default_emotion:
			return entry
	for entry: EntryScript in entries:
		if entry != null:
			return entry
	return null


func get_emotion_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: EntryScript in entries:
		if entry != null and not entry.emotion_id.is_empty():
			out.append(entry.emotion_id)
	return out


func ensure_defaults() -> void:
	base_display_height_px = clampf(base_display_height_px, 240.0, 1280.0)
	bottom_fade_start = clampf(bottom_fade_start, 0.50, 0.99)
	bottom_fade_power = clampf(bottom_fade_power, 0.50, 4.0)
	transition_duration_sec = clampf(transition_duration_sec, 0.04, 0.60)
	listening_dim_brightness = clampf(listening_dim_brightness, 0.20, 1.0)
	listening_desaturate = clampf(listening_desaturate, 0.0, 0.80)
	listening_scale_mult = clampf(listening_scale_mult, 0.85, 1.0)
	active_focus_scale = clampf(active_focus_scale, 1.0, 1.15)
	if entries.is_empty():
		var fallback := EntryScript.new()
		fallback.emotion_id = default_emotion if not default_emotion.is_empty() else &"neutral"
		fallback.display_label = "Neutral"
		entries.append(fallback)
