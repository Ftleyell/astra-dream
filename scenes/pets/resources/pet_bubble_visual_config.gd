class_name PetBubbleVisualConfig
extends Resource

## Configuración visual y física data-driven para una pet en burbuja 3D (Producción).

@export_group("Identity")
@export var pet_id: StringName = &"mochi"
@export var display_name: String = "Mochi"
@export var albedo_texture: Texture2D
@export var normal_texture: Texture2D
@export var bubble_texture: Texture2D

@export_group("BubbleGlass")
@export var theme_color: Color = Color(1.0, 0.72, 0.25, 1.0)
@export var rim_color: Color = Color(1.0, 0.90, 0.55, 1.0)
@export var inner_glow_color: Color = Color(1.0, 0.58, 0.18, 1.0)
@export var front_opacity: float = 0.34
@export var back_opacity: float = 0.30
@export var edge_texture_opacity: float = 0.78
@export var texture_strength: float = 0.88
@export var glass_refraction: float = 0.36
@export var bubble_bump_strength: float = 0.30
@export var caustic_strength: float = 0.95
@export var rim_bevel_darkness: float = 0.72
@export var fresnel_power: float = 2.6
@export var fresnel_strength: float = 1.05
@export var iridescence_strength: float = 0.26
@export var specular_strength: float = 1.15
@export var bubble_spin_speed: Vector3 = Vector3(0.22, 0.65, 0.12)

@export_group("PetInterior")
@export var pet_scale: float = 0.78
@export var pet_normal_strength: float = 1.0
@export var pet_shadow_tint: Color = Color(0.56, 0.58, 0.78, 1.0)
@export var pet_rim_strength: float = 0.55
@export var bob_amplitude: float = 4.5
@export var bob_speed: float = 3.2
@export var wobble_strength: float = 0.014
@export var lag_stiffness: float = 10.5
@export var max_lag_px: float = 10.0

@export_group("Orbit3D")
@export var orbit_radius_x: float = 155.0
@export var orbit_radius_y: float = 56.0
@export var orbit_tilt_deg: float = 22.0
@export var orbit_speed: float = 1.45
@export var back_scale: float = 0.82
@export var front_scale: float = 1.12

@export_group("CombatHybrid")
@export var combat_diameter_px: float = 64.0
@export var hub_diameter_px: float = 54.0
@export var combat_orbit_radius_x: float = 102.0
@export var combat_orbit_radius_y: float = 42.0
@export var combat_follow_speed_threshold: float = 310.0
@export var combat_follow_offset_px: Vector2 = Vector2(-58.0, 28.0)
@export var combat_follow_stiffness: float = 9.5

@export_group("CuteGestures")
@export var auto_gestures_enabled: bool = true
@export var gesture_interval_min: float = 2.6
@export var gesture_interval_max: float = 5.2
@export var planar_roll_bias: float = 0.45
@export var auto_flip_speed_threshold: float = 320.0
@export var auto_flip_cooldown: float = 2.8
@export var flip_duration: float = 0.22
@export var flip_flash_intensity: float = 1.15
