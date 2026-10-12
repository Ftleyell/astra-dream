class_name CosmosShadowSystemConfig
extends Resource

## Configuración data-driven para proyección, penumbra y oclusión de sombras planetarias.

@export var enable_planetary_shadows: bool = true
@export_range(0.0, 1.0, 0.05) var shadow_intensity: float = 0.75
@export_range(0.05, 0.90, 0.05) var shadow_penumbra_ratio: float = 0.45
@export_range(1.0, 3.5, 0.05) var shadow_expansion_factor: float = 1.85
@export_range(0.02, 0.50, 0.01) var shadow_heliopause_fade: float = 0.22
@export var shadow_tint: Color = Color(0.18, 0.18, 0.24, 1.0)
@export var shadow_base_width_scale: float = 1.0
@export var shadow_tip_curvature: float = 0.40
