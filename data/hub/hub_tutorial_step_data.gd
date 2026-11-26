class_name HubTutorialStepData
extends Resource

## Paso individual data-driven del debrief/tutorial guiado por mascota en el Hub 3D.

@export var step_id: StringName = &""
@export var target_id: StringName = &""
@export var station_badge: String = ""
@export_multiline var dialogue_text: String = ""
@export var camera_zoom: float = 1.45
@export var focus_offset_2d: Vector2 = Vector2(0.0, 110.0)
@export var highlight_color: Color = Color(0.24, 0.94, 1.0, 1.0)
@export var pulse_speed_hz: float = 2.6
@export var pulse_intensity: float = 1.25
@export var spotlight_enabled: bool = true
@export var spotlight_radius: float = 0.17
