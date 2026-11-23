class_name HubDioramaConfig
extends Resource
## Configuración data-driven para la cámara 2.5D Diorama del Hub 3D,
## el encuadre del SubViewport HDR de HubRigAvatar3D y el bloqueo visual de pedestales.

@export_group("Diorama Camera")
@export var camera_fov: float = 38.0
@export var camera_pitch_deg: float = -42.0
@export var camera_offset: Vector3 = Vector3(0.0, 9.2, 10.2)
@export var camera_follow_smooth: float = 7.5
@export var camera_clamp_min: Vector3 = Vector3(-9.5, 8.0, 0.5)
@export var camera_clamp_max: Vector3 = Vector3(9.5, 11.5, 54.0)

@export_group("Avatar SubViewport & Framing")
@export var viewport_size: int = 512
@export var rig_camera_zoom: float = 2.4
@export var rig_camera_center_offset: Vector2 = Vector2(0.0, 12.0)
@export var avatar_pixel_size: float = 0.0055
@export var avatar_feet_offset_px: float = 206.0
@export var avatar_hover_height: float = 0.22
@export var avatar_tilt_deg: float = -22.0
@export var avatar_aspect_y_comp: float = 1.064
@export var avatar_idle_bob_amp: float = 0.032
@export var avatar_idle_bob_hz: float = 1.55

@export_group("Rig Visuals")
@export var default_profile_path: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
@export var default_style_path: String = "res://data/pilots/styles/02_valentina_razor_sharp.tres"
@export var hub_light_dir_2d: Vector2 = Vector2(0.45, -0.89)

@export_group("Pedestal Rework Lockout")
@export var rework_rim_color: Color = Color(0.28, 0.30, 0.36, 1.0)
@export var rework_rim_emission: float = 0.12
@export var rework_badge_color: Color = Color(0.72, 0.76, 0.84, 0.85)
@export var rework_badge_y: float = 1.50
