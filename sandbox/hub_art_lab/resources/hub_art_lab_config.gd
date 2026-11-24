class_name HubArtLabConfig
extends Resource

## Configuración data-driven del Vertical Slice Hub Art Lab (Estación Astral v2).
## Centraliza cámara Diorama + presets de foco, calibración ArcSys 3D, calidad del Ventanal Cosmos y coordenadas.

@export_group("Camera — Free Roam Diorama")
@export var free_roam_fov: float = 38.0
@export var free_roam_pitch_deg: float = -42.0
@export var free_roam_offset: Vector3 = Vector3(0.0, 8.4, 7.6)
@export var camera_clamp_min: Vector3 = Vector3(-5.8, 7.5, -2.5)
@export var camera_clamp_max: Vector3 = Vector3(5.8, 11.0, 17.5)
@export var camera_transition_smooth: float = 6.5

@export_group("Camera — Focus Presets")
@export var capsule_focus_offset: Vector3 = Vector3(0.75, 2.05, 5.35)
@export var capsule_focus_pitch_deg: float = -6.5
@export var capsule_focus_fov: float = 32.0
@export var station_focus_offset: Vector3 = Vector3(0.0, 2.45, 4.4)
@export var station_focus_pitch_deg: float = -15.0
@export var station_focus_fov: float = 33.0
@export var ignition_launch_offset: Vector3 = Vector3(0.0, 2.45, 6.4)
@export var ignition_launch_pitch_deg: float = -7.0
@export var ignition_launch_fov: float = 34.0

@export_group("Shaders & Visual Calibration")
@export var pilot_accent_color: Color = Color(0.95, 0.16, 0.34, 1.0)
@export var calibrating_tint: Color = Color(0.32, 0.36, 0.48, 1.0)
@export var ink_strength: float = 0.88
@export var ink_expand: float = 0.22
@export var crease_ink_strength: float = 0.58
@export var outline_width: float = 0.014
@export var outline_ref_distance: float = 13.8
@export var emissive_boost: float = 1.65
@export var bloom_intensity: float = 0.72
@export var glow_bloom: float = 0.18
@export var floor_uv_scale: Vector2 = Vector2(1.0, 1.0)
@export var wall_uv_scale: Vector2 = Vector2(1.0, 1.0)

@export_group("North Cosmos Window")
@export var cosmos_viewport_resolutions: Array[Vector2i] = [
	Vector2i(640, 320),
	Vector2i(960, 480),
	Vector2i(1280, 640),
]
@export var cosmos_camera_zoom: float = 0.62
@export var cosmos_drift_amp: Vector2 = Vector2(140.0, 65.0)
@export var cosmos_drift_hz: float = 0.035
@export var cosmos_retune_duration: float = 0.32
@export var default_preview_seed: int = 428175

@export_group("Deck Layout & Timing")
@export var capsule_pos: Vector3 = Vector3(0.0, 0.0, 1.6)
@export var console_left_pos: Vector3 = Vector3(-4.2, 0.0, -2.6)
@export var console_right_pos: Vector3 = Vector3(4.2, 0.0, -2.6)
@export var console_left_far_pos: Vector3 = Vector3(-6.2, 0.0, -5.8)
@export var console_right_far_pos: Vector3 = Vector3(6.2, 0.0, -5.8)
@export var ignition_ring_pos: Vector3 = Vector3(0.0, 0.065, -8.2)
@export var ignition_ring_size: Vector2 = Vector2(4.2, 4.2)
@export var north_window_pos: Vector3 = Vector3(0.0, 3.9, -10.55)
@export var north_window_size: Vector2 = Vector2(19.2, 7.4)
@export var player_spawn_pos: Vector3 = Vector3(0.0, 0.05, 4.35)
@export var player_move_speed: float = 7.2
@export var ignition_preview_duration: float = 1.15
