class_name PilotHairPreset
extends Resource
## Preset de color de cabello para el shader del rig de piloto.

@export var id: String = "original"
@export var label: String = "Color Pelo 0: Original"
@export var override_color: bool = false
@export var follow_skin_hair: bool = false
@export var hair_color: Color = Color(0.86, 0.88, 0.94, 1.0)
@export var hair_secondary_color: Color = Color(0.86, 0.18, 0.32, 1.0)
