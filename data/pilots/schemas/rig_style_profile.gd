class_name RigStyleProfile
extends Resource
## Perfil de identidad visual unificado (ArcSys × Espacial Cinematográfico) para Valentina v2.

@export var id: String = "00_original"
@export var label: String = "00 — Original (Baseline Limpio)"
@export var stylize_enabled: bool = false

@export_group("Iluminación Cel 2.5D (Normal + ILM)")
@export var use_normal_depth: bool = false
@export var cel_strength: float = 0.0
@export var cel_threshold: float = 0.05
@export var cel_softness: float = 0.038
@export var cel_mid_band_strength: float = 0.42
@export var albedo_de_shade: float = 0.34
@export var ilm_shadow_bias_strength: float = 0.74
@export var ilm_ao_strength: float = 0.82
@export var face_shadow_protect: float = 0.88

@export_group("Paleta Cinematográfica y Color Grading")
@export var key_light_tint: Color = Color(1.05, 1.02, 0.96, 1.0)
@export var shadow_tint: Color = Color(0.180, 0.169, 0.361, 1.0)
@export var ao_tint: Color = Color(0.098, 0.078, 0.196, 1.0)
@export var skin_shadow_tint: Color = Color(0.68, 0.43, 0.50, 1.0)
@export var sss_skin_color: Color = Color(0.97, 0.37, 0.30, 1.0)
@export var sss_strength: float = 0.0
@export var color_contrast: float = 1.0
@export var color_saturation: float = 1.0
@export var key_light_boost: float = 1.0

@export_group("Materiales (ID + ILM)")
@export var armor_spec_strength: float = 0.0
@export var armor_spec_threshold: float = 0.65
@export var suit_satin_strength: float = 0.0
@export var nylon_sheen_strength: float = 0.0
@export var stocking_denier: float = 0.34
@export var hair_angel_ring_strength: float = 0.0
@export var emissive_glow_strength: float = 0.0
@export var hdr_cap: float = 1.0

@export_group("Lineart Coloreado Interno (Pasada 1)")
@export var albedo_lod_bias: float = 0.0
@export var ink_strength: float = 0.0
@export var ink_color_tint_mix: float = 0.0
@export var ink_skin_tint: Color = Color(0.24, 0.11, 0.12, 1.0)
@export var ink_cool_tint: Color = Color(0.055, 0.055, 0.130, 1.0)
@export var ink_sdf_bias_px: float = -0.05
@export var ink_sdf_softness: float = 0.55

@export_group("Rim-Light Híbrido (Pasada 1 + Pasada 2)")
@export var normal_rim_strength: float = 0.0
@export var silhouette_rim_strength: float = 0.0
@export var silhouette_rim_width_px: float = 1.45
@export var counter_rim_strength: float = 0.0
@export var rim_key_color: Color = Color(0.94, 0.97, 1.0, 1.0)
@export var counter_rim_use_skin_accent: bool = true
@export var counter_rim_override_color: Color = Color(0.86, 0.18, 0.32, 1.0)

@export_group("Silueta Caligráfica y Light-Wrap (Pasada 2)")
@export var enable_outer_outline: bool = false
@export var outer_outline_width_px: float = 0.78
@export var outline_min_px: float = 0.48
@export var outline_max_px: float = 1.15
@export var outer_outline_strength: float = 0.0
@export var outer_outline_tint_mix: float = 0.0
@export var outline_calligraphy_amount: float = 0.65
@export var outline_crispness: float = 0.42
@export var outline_inward_replace: float = 0.12
@export var ign_jitter_strength: float = 0.0
@export var outer_outline_color: Color = Color(0.045, 0.040, 0.095, 1.0)
@export var hdr_light_wrap_strength: float = 0.0
@export var hdr_threshold: float = 1.05
@export var cas_sharpen_strength: float = 0.0
