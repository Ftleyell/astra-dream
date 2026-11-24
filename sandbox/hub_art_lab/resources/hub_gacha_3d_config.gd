class_name HubGacha3DConfig
extends Resource

## Configuración data-driven del Invocador Giroscópico Astral 3D (Fase 2 — Hub Art Lab).
## Centraliza cámara, coreografía de 5 fases, cinemática giroscópica, bloom, paletas y sesión sandbox.

@export_group("Camera — Idle & Cinematic")
@export var idle_cam_pos: Vector3 = Vector3(0.0, 3.65, 7.65)
@export var idle_cam_look_at: Vector3 = Vector3(0.0, 1.85, 0.0)
@export var idle_cam_fov: float = 38.0
@export var cinematic_cam_pos: Vector3 = Vector3(0.0, 1.72, 5.05)
@export var cinematic_cam_look_at: Vector3 = Vector3(0.0, 2.20, 0.0)
@export var cinematic_cam_fov: float = 32.5
@export var burst_cam_pos: Vector3 = Vector3(0.0, 2.05, 5.75)
@export var burst_cam_fov: float = 36.0
@export var camera_smooth: float = 6.2
@export var shake_max_charge: float = 0.045
@export var shake_fakeout_impulse: float = 0.14
@export var shake_burst_impulse: float = 0.16
@export var shake_decay: float = 6.5

@export_group("Choreography — 5 Phases")
@export var phase_frame_duration: float = 0.15
@export var phase_charge_duration: float = 1.00
@export var phase_tension_duration: float = 0.40
@export var phase_bloom_duration: float = 0.40
@export var skip_unlock_delay: float = 0.20
@export var fakeout_probability: float = 0.28
@export var fakeout_break_ratio: float = 0.52
@export var multi_cascade_step_delay: float = 0.11
@export var multi_epic_heroic_pause: float = 0.42

@export_group("Gyroscope Kinematics & Bloom")
@export var gyro_center_y: float = 2.28
@export var outer_ring_idle_speed: float = 0.42
@export var mid_ring_idle_speed: float = -0.68
@export var inner_ring_idle_speed: float = 1.15
@export var outer_ring_charge_mult: float = 6.5
@export var mid_ring_charge_mult: float = 9.0
@export var inner_ring_charge_mult: float = 13.5
@export var core_idle_bob_amp: float = 0.075
@export var core_idle_bob_hz: float = 1.15
@export var core_split_distance: float = 0.54
@export var rings_bloom_open_scale: float = 1.24
@export var rings_bloom_tilt_deg: float = 22.0
@export var emissive_idle: float = 1.55
@export var emissive_charge_peak: float = 2.65
@export var emissive_burst_common: float = 2.40
@export var emissive_burst_epic: float = 3.55
@export var bloom_idle: float = 0.72
@export var bloom_burst_peak: float = 1.38
@export var crease_ink_strength: float = 0.58
@export var outline_width: float = 0.013
@export var outline_ref_distance: float = 9.5

@export_group("Palettes & Surface Slots")
@export var common_energy_color: Color = Color(0.08, 0.92, 1.0, 1.0)
@export var rare_energy_color: Color = Color(0.76, 0.34, 1.0, 1.0)
@export var epic_energy_color: Color = Color(1.0, 0.80, 0.18, 1.0)
@export var epic_secondary_color: Color = Color(1.0, 0.16, 0.42, 1.0)
@export var armor_color: Color = Color(0.48, 0.54, 0.68, 1.0)
@export var chassis_color: Color = Color(0.065, 0.075, 0.14, 1.0)
@export var floor_tex_base: String = "res://sandbox/hub_art_lab/assets/surfaces/hub_floor_astral"
@export var wall_tex_base: String = "res://sandbox/hub_art_lab/assets/surfaces/hub_wall_astral"
@export var ring_tex_path: String = "res://sandbox/hub_art_lab/assets/rings/hub_ignition_ring_packed.png"

@export_group("Sandbox Session")
@export var sandbox_initial_tokens: int = 30
@export var sandbox_refill_amount: int = 20
