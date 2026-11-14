class_name RigStyleProfile
extends Resource
## Perfil de identidad visual y post-proceso para `pilot_rig_stylizer.gdshader`.

@export var id: String = "original"
@export var label: String = "Perfil 0: Original Upscayl 4x"
@export var pipeline_mode: int = 0

@export_group("Semitono / Trama")
@export var enable_halftone: bool = false
@export var halftone_pattern_type: int = 0
@export var halftone_zone_mode: int = 0
@export var halftone_scale: float = 165.0
@export var halftone_strength: float = 0.0
@export var halftone_angle_deg: float = 45.0
@export var halftone_threshold: float = 0.38

@export_group("Tinta, Cel-Shading y Rim-Light")
@export var ink_boost: float = 0.10
@export var cel_step_strength: float = 0.0
@export var noir_shadow_crush: float = 0.0
@export var noir_shadow_threshold: float = 0.24
@export var metal_sheen_strength: float = 0.0
@export var rim_light_strength: float = 0.12
@export var rim_width_px: float = 4.5
@export var dual_rim_strength: float = 0.0
@export var glow_intensity: float = 1.05
