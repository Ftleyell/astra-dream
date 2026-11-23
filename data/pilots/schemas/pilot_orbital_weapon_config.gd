class_name PilotOrbitalWeaponConfig
extends Resource
## Configuración data-driven para el sistema de Anillo Orbital 2.5D y Armamento
## en PilotRigLab (Guns Lab — Valentina v2).

@export_group("Anillo Orbital 3D")
@export var ring_center_offset: Vector2 = Vector2(0.0, 10.0)
@export var ring_radius_x: float = 128.0
@export var ring_radius_y: float = 72.0
@export var ring_tilt_deg: float = 0.0
@export var ring_thickness_px: float = 2.6
@export var ring_secondary_scale: float = 0.90
@export var ring_tick_count: int = 36
@export var ring_color_primary: Color = Color(0.22, 0.86, 1.0, 0.78)
@export var ring_color_accent: Color = Color(0.95, 0.22, 0.38, 0.92)
@export var ring_back_alpha_mult: float = 0.42
@export var ring_front_alpha_mult: float = 0.95
@export var ring_anchor_glow_radius: float = 16.0
@export var ring_follow_skin: bool = true
@export var ring_inner_arc_count: int = 3
@export var ring_inner_arc_speed: float = -0.45
@export var ring_inner_arc_span_rad: float = 1.15
@export var ring_diamond_size_px: float = 9.0
@export var ring_stardust_count: int = 10
@export var ring_use_texture: bool = true
@export var ring_outer_rot_speed: float = 0.18
@export var ring_texture_scale_mult: float = 1.0

@export_group("Proyección y Escala del Arma")
@export var weapon_base_scale: float = 0.135
@export var weapon_pivot_u: float = 0.355
@export var weapon_muzzle_u: float = 0.966
@export var weapon_radial_offset_px: float = 0.0
@export var weapon_vertical_bob_px: float = 2.5
@export var weapon_bob_speed: float = 2.4
@export var perspective_scale_amp: float = 0.24
@export var foreshorten_min_x: float = 0.46
@export var foreshorten_strength: float = 0.85
@export var aim_pitch_compression: float = 0.58

@export_group("Deformación 2.5D y Volumen (Shader)")
@export var trapezoid_strength: float = 0.42
@export var extrude_depth_px: float = 5.5
@export var extrude_tint: Color = Color(0.10, 0.16, 0.28, 0.92)
@export var depth_back_dim: float = 0.28
@export var depth_back_tint: Color = Color(0.32, 0.36, 0.62, 1.0)
@export var rim_strength: float = 0.55
@export var specular_sweep_strength: float = 0.42
@export var ink_sdf_strength: float = 0.92

@export_group("Órbita y Animación de Disparo")
@export var orbit_speed_rad: float = 1.35
@export var mouse_follow_rate: float = 11.0
@export var weapon_count: int = 1
@export var recoil_kick_px: float = 18.0
@export var recoil_recover_rate: float = 14.0
@export var recoil_pitch_kick_deg: float = 6.5
@export var fire_glow_boost: float = 1.45
@export var auto_fire_interval_sec: float = 0.42
@export var tracer_speed_px: float = 1250.0
@export var tracer_length_px: float = 72.0


func ensure_defaults() -> void:
	ring_radius_x = clampf(ring_radius_x, 40.0, 280.0)
	ring_radius_y = clampf(ring_radius_y, 12.0, 200.0)
	ring_tilt_deg = clampf(ring_tilt_deg, -45.0, 45.0)
	weapon_base_scale = clampf(weapon_base_scale, 0.04, 0.45)
	weapon_count = clampi(weapon_count, 1, 4)
	perspective_scale_amp = clampf(perspective_scale_amp, 0.0, 0.50)
	foreshorten_min_x = clampf(foreshorten_min_x, 0.20, 1.0)
	trapezoid_strength = clampf(trapezoid_strength, 0.0, 0.90)
	extrude_depth_px = clampf(extrude_depth_px, 0.0, 14.0)
	auto_fire_interval_sec = clampf(auto_fire_interval_sec, 0.10, 2.0)
	ring_inner_arc_count = clampi(ring_inner_arc_count, 1, 6)
	ring_inner_arc_speed = clampf(ring_inner_arc_speed, -3.0, 3.0)
	ring_inner_arc_span_rad = clampf(ring_inner_arc_span_rad, 0.25, 2.2)
	ring_diamond_size_px = clampf(ring_diamond_size_px, 4.0, 20.0)
	ring_stardust_count = clampi(ring_stardust_count, 0, 24)
	ink_sdf_strength = clampf(ink_sdf_strength, 0.0, 1.0)
	ring_outer_rot_speed = clampf(ring_outer_rot_speed, -3.0, 3.0)
	ring_texture_scale_mult = clampf(ring_texture_scale_mult, 0.6, 1.6)
