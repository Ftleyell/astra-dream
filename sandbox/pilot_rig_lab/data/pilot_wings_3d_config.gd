class_name PilotWings3DConfig
extends Resource
## Configuración data-driven para las Alas Psíquicas 3D Cel-Shaded (3D Lab — Valentina v2).
## Controla geometría 3D en abanico, animación por cuchilla, sombreado ArcSys,
## estelas HDR ancladas por proyección 3D→2D y polvo estelar.

@export_group("Geometría y Encuadre 3D")
@export var wing_scale: float = 1.0
@export var anchor_offset_px: Vector2 = Vector2(0.0, -24.0)
@export var root_spread_x: float = 0.66
@export var root_height_y: float = 0.24
@export var root_depth_back_z: float = -0.36
@export var fan_upper_angle_deg: float = 44.0
@export var fan_lower_angle_deg: float = -48.0
@export var blade_sweep_back_deg: float = 20.0
@export var blade_length_scale: float = 1.0
@export var blade_thickness_scale: float = 1.0
@export var camera_elev_deg: float = 10.0

@export_group("Animación Dinámica")
@export var idle_breath_amp: float = 0.085
@export var idle_breath_hz: float = 0.65
@export var wave_amp_deg: float = 9.5
@export var wave_speed_hz: float = 0.85
@export var wave_phase_step: float = 0.55
@export var blade_twist_amp_deg: float = 14.0
@export var thrust_sweep_deg: float = 26.0
@export var aegis_radius: float = 1.45
@export var aegis_spin_speed: float = 1.15
@export var vortex_radius: float = 1.95
@export var vortex_spin_speed: float = 2.4
@export var full_burst_fire_interval: float = 0.14
@export var recoil_kick_units: float = 0.36
@export var recoil_recover_rate: float = 12.0

@export_group("Sombreado ArcSys 3D y HDR")
@export var outline_width: float = 0.018
@export var outline_calligraphy_amount: float = 0.65
@export var outline_color: Color = Color(0.045, 0.040, 0.095, 1.0)
@export var outline_lit_color: Color = Color(0.11, 0.035, 0.07, 1.0)
@export var crease_ink_strength: float = 0.68
@export var crease_ink_threshold: float = 0.28
@export var rim_strength: float = 0.68
@export var rim_color: Color = Color(0.88, 0.96, 1.0, 1.0)
@export var specular_sweep_strength: float = 0.52
@export var depth_back_dim: float = 0.22
@export var depth_back_tint: Color = Color(0.32, 0.36, 0.62, 1.0)
@export var fire_glow_color: Color = Color(0.98, 0.16, 0.34, 1.0)
@export var emissive_idle_boost: float = 1.25
@export var emissive_active_boost: float = 2.05
@export var channel_glow_strength: float = 1.45
@export var energy_flow_speed: float = 2.6
@export var energy_flow_amp: float = 0.38
@export var crimson_bounce_strength: float = 0.36
@export var follow_skin_palette: bool = true

@export_group("Post-Pass 2D Unificado (Estilo Valentina)")
@export var enable_post_pass: bool = true
@export var cas_sharpen_strength: float = 0.52
@export var post_outline_strength: float = 0.88
@export var post_outline_width_px: float = 1.35
@export var post_rim_strength: float = 0.48

@export_group("Estelas HDR y Polvo Estelar (3D→2D)")
@export var enable_trails: bool = true
@export var trail_max_points: int = 16
@export var trail_width_px: float = 3.6
@export var trail_alpha: float = 0.72
@export var enable_stardust: bool = true
@export var stardust_spawn_rate: float = 26.0
@export var stardust_size_px: float = 4.2


func ensure_defaults() -> void:
	wing_scale = clampf(wing_scale, 0.35, 2.2)
	root_spread_x = clampf(root_spread_x, 0.25, 1.8)
	blade_length_scale = clampf(blade_length_scale, 0.5, 1.8)
	blade_thickness_scale = clampf(blade_thickness_scale, 0.5, 2.0)
	outline_width = clampf(outline_width, 0.005, 0.08)
	trail_max_points = clampi(trail_max_points, 4, 32)
	full_burst_fire_interval = clampf(full_burst_fire_interval, 0.05, 1.0)
