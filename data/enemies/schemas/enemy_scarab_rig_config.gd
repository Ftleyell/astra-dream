class_name EnemyScarabRigConfig
extends Resource

## Data-driven calibration & animation config for the 7-piece articulated Void Scarab 2.5D rig.

@export var enemy_id: StringName = &"void_scarab"
@export var asset_dir: String = "res://assets/enemies/void_scarab"
@export_range(0.08, 1.2) var display_scale: float = 0.28

@export_group("Elytron Shells")
@export_range(0.4, 1.8) var elytron_scale: float = 1.0
@export var elytron_offset: Vector2 = Vector2(18.0, -47.5)
@export var elytron_hinge_uv: Vector2 = Vector2(0.4505, 0.3359)
@export_range(-30.0, 30.0) var elytron_closed_deg: float = -1.5
@export_range(5.0, 85.0) var elytron_open_deg: float = 48.0
@export_range(0.0, 40.0) var elytron_lift_px: float = 14.0
@export_range(0.0, 1.0) var elytron_open_pitch: float = 0.45
@export_range(0.0, 75.0) var elytron_open_pitch_deg: float = 28.0
@export_range(-45.0, 145.0) var elytron_open_roll_deg: float = 104.0
@export_range(0.0, 50.0) var elytron_dome_height_px: float = 30.0
@export_range(1.0, 14.0) var elytron_rim_thickness_px: float = 4.5

@export_group("Inner Bio-Wings")
@export_range(0.4, 1.8) var wing_scale: float = 1.0
@export var wing_offset: Vector2 = Vector2(11.0, -27.5)
@export var wing_hinge_uv: Vector2 = Vector2(0.3438, 0.3516)
@export_range(-45.0, 45.0) var wing_closed_deg: float = -18.0
@export_range(5.0, 85.0) var wing_open_deg: float = 28.0
@export_range(0.0, 28.0) var wing_buzz_amp: float = 14.0
@export_range(10.0, 80.0) var wing_buzz_freq: float = 46.0
@export_range(2.0, 40.0) var wing_flap_freq: float = 16.0
@export_range(0.0, 25.0) var wing_flap_sweep_deg: float = 9.0
@export_range(0.0, 16.0) var wing_flex_amp: float = 4.5
@export_range(0.0, 0.8) var wing_ghost_alpha: float = 0.20
@export_range(0.0, 38.0) var wing_blur_max_deg: float = 20.0
@export_range(8.0, 65.0) var wing_shutter_speed: float = 36.0
@export_range(4.0, 32.0) var wing_strobe_extreme_deg: float = 16.0
@export_range(0.0, 0.65) var wing_strobe_alpha: float = 0.34
@export_range(0.0, 1.5) var wing_wind_arcs_strength: float = 0.78

@export_group("Scissor Mandibles")
@export_range(0.6, 1.5) var mandible_scale: float = 1.0
@export var mandible_offset: Vector2 = Vector2(30.0, -73.0)
@export var mandible_hinge_uv: Vector2 = Vector2(0.4766, 0.6914)
@export_range(-20.0, 20.0) var mandible_rest_deg: float = 0.0
@export_range(-45.0, -5.0) var mandible_open_deg: float = -26.0
@export_range(10.0, 55.0) var mandible_bite_deg: float = 34.0

@export_group("Living Organic Motion & 3D Flight")
@export_range(0.0, 12.0) var breath_amp: float = 3.5
@export_range(0.0, 14.0) var leg_paddle_amp: float = 6.0
@export_range(1.0, 30.0) var leg_paddle_freq: float = 8.5
@export_range(0.0, 0.6) var idle_sway_amp: float = 0.24
@export_range(0.0, 32.0) var layer_parallax_px: float = 14.0

@export_group("Combat Dynamics")
@export_range(0.0, 1.0) var bank_max: float = 0.85
@export_range(0.1, 2.0) var telegraph_duration: float = 0.65
@export_range(0.2, 2.0) var shatter_duration: float = 0.58
@export_range(50.0, 600.0) var shatter_impulse: float = 240.0
