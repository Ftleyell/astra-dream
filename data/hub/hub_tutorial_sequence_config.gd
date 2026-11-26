class_name HubTutorialSequenceConfig
extends Resource

## Secuencia data-driven completa del tour/debrief de la Estación Astral en el Hub 3D.

const StepDataScript = preload("res://data/hub/hub_tutorial_step_data.gd")

@export var typewriter_chars_per_sec: float = 48.0
@export var dialogue_panel_offset_y_px: float = 115.0
@export var dialogic_portrait_camera_offset_px: Vector2 = Vector2(150.0, 25.0)
@export_group("Spotlight Blur & Dim")
@export_range(0.0, 6.0, 0.05) var spotlight_blur_strength: float = 2.4
@export_range(0.0, 0.95, 0.01) var spotlight_dim_strength: float = 0.56
@export_range(0.02, 0.6, 0.01) var spotlight_softness: float = 0.16
@export var spotlight_dim_color: Color = Color(0.035, 0.045, 0.11, 1.0)
@export var spotlight_focus_lift_y_px: float = -24.0
@export_group("")
@export var steps: Array[StepDataScript] = []
