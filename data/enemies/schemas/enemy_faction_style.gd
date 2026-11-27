class_name EnemyFactionStyle
extends Resource

## Data-driven ArcSys x Cosmos visual style preset for 2.5D enemies.

@export var style_id: StringName = &"biomech_void"
@export var label: String = "Biomech Void (ArcSys)"

@export_group("2.5D Relief, Shell Extrusion, Reactor Light & Cast Shadows")
@export_range(0.0, 60.0) var relief_depth_px: float = 26.0
@export_range(0.0, 0.08) var parallax_strength: float = 0.032
@export_range(0.0, 28.0) var shell_thickness_px: float = 13.0
@export_range(0.0, 3.5) var core_light_strength: float = 1.65
@export var core_light_color: Color = Color(0.22, 1.0, 0.56, 1.0)
@export_range(0.0, 2.5) var green_bounce_strength: float = 0.62
@export_range(0.0, 1.0) var cast_shadow_opacity: float = 0.38
@export_range(0.0, 48.0) var cast_shadow_offset_px: float = 18.0

@export_group("Studio Exposure, Cel Shading & AO")
@export_range(0.5, 2.8) var studio_exposure: float = 1.12
@export_range(0.0, 1.2) var ambient_fill_strength: float = 0.36
@export_range(0.0, 1.0) var cel_strength: float = 0.88
@export_range(-0.6, 0.6) var cel_threshold: float = -0.04
@export_range(0.005, 0.25) var cel_softness: float = 0.022
@export_range(0.0, 1.0) var cel_mid_band_strength: float = 0.45
@export_range(0.0, 1.0) var albedo_de_shade: float = 0.32
@export_range(0.0, 1.0) var ao_strength: float = 0.52
@export_range(0.7, 1.6) var color_contrast: float = 1.05
@export_range(0.5, 1.8) var color_saturation: float = 1.10

@export_group("Material Specular, Iridescence, SSS & Rim")
@export_range(0.0, 2.5) var specular_strength: float = 1.15
@export_range(0.20, 0.95) var specular_threshold: float = 0.38
@export_range(0.0, 2.0) var iridescence_strength: float = 0.65
@export var iridescence_color_a: Color = Color(0.56, 0.28, 1.0, 1.0)
@export var iridescence_color_b: Color = Color(0.18, 0.96, 0.78, 1.0)
@export var sss_color: Color = Color(0.22, 0.98, 0.55, 1.0)
@export_range(0.0, 2.0) var sss_strength: float = 0.72
@export_range(0.0, 2.5) var normal_rim_strength: float = 0.95
@export_range(0.0, 1.5) var counter_rim_strength: float = 0.42
@export var counter_rim_color: Color = Color(0.68, 0.24, 0.96, 1.0)

@export_group("Ink SDF 2x & Outer Calligraphic Outline")
@export_range(0.0, 1.0) var ink_strength: float = 0.90
@export var ink_color: Color = Color(0.045, 0.040, 0.095, 1.0)
@export_range(-1.0, 1.0) var ink_sdf_bias_px: float = -0.14
@export_range(0.15, 2.0) var ink_sdf_softness: float = 0.40
@export_range(0.0, 6.0) var outer_outline_width_px: float = 0.95
@export_range(0.0, 1.0) var outer_outline_strength: float = 0.85
@export var outer_outline_color: Color = Color(0.045, 0.040, 0.095, 1.0)
@export var outer_alert_color: Color = Color(1.0, 0.22, 0.36, 1.0)
@export_range(1.0, 4.0) var hdr_cap: float = 1.85

@export_group("Emissives & Variants")
@export_range(0.0, 4.0) var primary_emissive_strength: float = 1.35
@export_range(0.0, 12.0) var plasma_flow_speed: float = 4.8
@export var primary_emissive_tint: Color = Color(0.28, 1.0, 0.56, 1.0)
@export var secondary_emissive_tint: Color = Color(0.35, 1.0, 0.72, 1.0)
@export var dissolve_edge_color: Color = Color(0.35, 1.0, 0.62, 1.0)
@export var variant_tints: Array[Color] = [
	Color(0.92, 0.38, 1.0, 1.0),
	Color(1.0, 0.24, 0.38, 1.0),
	Color(0.32, 0.92, 1.0, 1.0),
	Color(1.0, 0.82, 0.24, 1.0),
]
@export var variant_armor_tints: Array[Color] = [
	Color(0.30, 0.16, 0.46, 1.0),
	Color(0.42, 0.14, 0.20, 1.0),
	Color(0.14, 0.26, 0.46, 1.0),
	Color(0.40, 0.26, 0.14, 1.0),
]
@export var variant_energy_tints: Array[Color] = [
	Color(0.86, 0.32, 1.0, 1.0),
	Color(1.0, 0.26, 0.42, 1.0),
	Color(0.24, 0.94, 1.0, 1.0),
	Color(1.0, 0.78, 0.20, 1.0),
]
