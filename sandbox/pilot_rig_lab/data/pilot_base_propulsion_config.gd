class_name PilotBasePropulsionConfig
extends Resource
## Configuración data-driven para la Propulsión Base Zero-G de Valentina v2 (Pulido v3):
## Capa 1: Alas Psíquicas Heroicas (6 cuchillas cohesivas por ala, flotación amplia sin diamante,
##         cero superposición al frenar, perspectiva 2.5D prolija en los 8 ángulos, luz roja HDR real).
## Capa 2: 12 Cintas Rojas sólidas semitransparentes (curvas suaves sin zigzag).
## Capa 3: Polvo Estelar (estrellas de 4 puntas plata/rubí, pool zero-allocation).

@export_group("Capa 1 — Alas Psíquicas (Escala Heroica y Flotación)")
@export var wings_enabled: bool = true
@export_range(0.6, 2.6, 0.05) var wing_scale: float = 1.60
@export_range(0.0, 30.0, 0.5) var idle_fold_angle_deg: float = 12.0
@export_range(-12.0, 12.0, 0.5) var flight_spread_angle_deg: float = -4.0
@export_range(0.65, 1.05, 0.02) var idle_scale_factor: float = 0.90
@export_range(0.85, 1.25, 0.02) var flight_scale_factor: float = 1.04
@export_range(2.0, 20.0, 0.5) var open_smooth_rate: float = 7.5
@export_range(0.45, 1.0, 0.02) var over_back_opacity: float = 0.92
@export var shoulder_anchor_offset_du: Vector2 = Vector2(0.0, -14.0)
@export_range(20.0, 120.0, 1.0) var wing_root_spread_x_du: float = 68.0
@export_range(0.0, 50.0, 1.0) var thrust_linear_slide_du: float = 22.0
@export_range(0.0, 50.0, 1.0) var brake_spread_extra_du: float = 28.0

@export_group("Capa 1B — Cohesión y Onda Psíquica por Cuchilla")
@export_range(0.1, 2.5, 0.05) var idle_breathe_hz: float = 0.62
@export_range(0.0, 10.0, 0.25) var blade_wave_amp_deg: float = 2.8
@export_range(0.0, 16.0, 0.5) var blade_wave_float_du: float = 4.5
@export_range(0.1, 1.2, 0.05) var blade_wave_phase_step: float = 0.52
@export_range(0.0, 20.0, 0.5) var blade_fan_spread_deg: float = 8.0
@export_range(0.0, 24.0, 0.5) var blade_radial_expand_du: float = 10.0
@export_range(0.0, 14.0, 0.5) var banking_tilt_deg: float = 5.5
@export_range(0.0, 14.0, 0.5) var kick_impulse_deg: float = 6.0

@export_group("Capa 1C — Empuje Newtoniano, Luz Roja HDR y Micro-Vibración")
@export_range(0.0, 1.0, 0.05) var effort_asymmetry_gain: float = 0.85
@export_range(2.0, 20.0, 0.5) var effort_smooth_rate: float = 8.0
@export_range(0.0, 12.0, 0.5) var effort_extra_open_deg: float = 5.5
@export_range(0.0, 4.0, 0.1) var effort_vibration_amp_du: float = 0.9
@export_range(8.0, 36.0, 1.0) var effort_vibration_hz: float = 20.0
@export_range(0.4, 2.5, 0.05) var idle_emissive_boost: float = 0.85
@export_range(1.0, 5.0, 0.1) var thrust_emissive_boost: float = 3.00
@export_range(0.0, 2.5, 0.05) var effort_rim_strength: float = 1.35
@export var effort_rim_color: Color = Color(1.0, 0.12, 0.28, 1.0)
@export_range(0.0, 1.0, 0.02) var red_glow_idle_intensity: float = 0.12
@export_range(0.2, 3.5, 0.05) var red_glow_thrust_intensity: float = 1.65
@export_range(0.5, 4.0, 0.05) var red_glow_brake_intensity: float = 2.35
@export var red_glow_color: Color = Color(1.0, 0.08, 0.22, 1.0)

@export_group("Capa 1D — Puente 2.5D de Giro (Squash-X)")
@export var turn_bridge_enabled: bool = true
@export_range(0.015, 0.12, 0.005) var turn_pre_cut_sec: float = 0.045
@export_range(0.03, 0.22, 0.005) var turn_post_cut_sec: float = 0.095
@export_range(0.08, 0.55, 0.02) var turn_flip_min_scale_x: float = 0.18
@export_range(0.35, 0.90, 0.02) var turn_adj_min_scale_x: float = 0.58
@export_range(1.0, 1.22, 0.01) var turn_overshoot_scale_x: float = 1.09
@export_range(1.0, 1.15, 0.01) var turn_squash_stretch_y: float = 1.05
@export var warp_streak_enabled: bool = true
@export_range(0.05, 0.30, 0.01) var warp_arc_lifetime_sec: float = 0.14
@export_range(2.0, 12.0, 0.5) var warp_arc_width_px: float = 6.5
@export_range(10.0, 90.0, 2.0) var warp_arc_curve_px: float = 42.0
@export var warp_arc_color: Color = Color(0.98, 0.08, 0.24, 0.88)
@export_range(0.03, 0.18, 0.01) var warp_ghost_lifetime_sec: float = 0.085
@export_range(0.10, 0.80, 0.02) var warp_ghost_opacity: float = 0.42
@export var warp_ghost_color: Color = Color(1.0, 0.14, 0.32, 1.0)

@export_group("Capa 2 — 12 Cintas Rojas Sólidas (Todas las Puntas)")
@export var ribbons_enabled: bool = true
@export_range(20.0, 220.0, 5.0) var ribbon_min_speed_px_s: float = 55.0
@export_range(8, 44, 1) var ribbon_max_points: int = 22
@export_range(0.1, 1.2, 0.02) var ribbon_lifetime_sec: float = 0.38
@export_range(1.5, 12.0, 0.2) var ribbon_width_px: float = 4.6
@export_range(0.2, 1.0, 0.02) var ribbon_secondary_scale: float = 0.48
@export_range(0.1, 1.0, 0.02) var ribbon_opacity: float = 0.66
@export_range(0.0, 1.0, 0.05) var ribbon_effort_boost: float = 0.30
@export var ribbon_primary_color: Color = Color(0.92, 0.05, 0.18, 1.0)

@export_group("Capa 3 — Polvo Estelar (Stardust Wake)")
@export var stardust_enabled: bool = true
@export_range(0.0, 20.0, 0.5) var stardust_idle_rate_hz: float = 2.8
@export_range(2.0, 60.0, 1.0) var stardust_flight_rate_hz: float = 18.0
@export_range(8, 96, 1) var stardust_max_particles: int = 44
@export_range(0.2, 2.0, 0.05) var stardust_lifetime_sec: float = 0.85
@export_range(1.5, 10.0, 0.2) var stardust_size_px: float = 4.2
@export var stardust_silver_color: Color = Color(0.92, 0.96, 1.0, 0.88)
@export var stardust_ruby_color: Color = Color(1.0, 0.16, 0.32, 0.94)
