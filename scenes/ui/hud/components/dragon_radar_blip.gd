class_name DragonRadarBlip
extends RefCounted

## DragonRadarBlip.gd
## Estructura de datos fuertemente tipada para un 'ping' o eco en el radar.

var world_target_id: int = 0
var radar_pos: Vector2 = Vector2.ZERO
var color: Color = Color.GREEN
var size: float = 3.0
var life: float = 1.0 # 1.0 a 0.0 (fade out)
var max_life: float = 1.6
var is_satellite: bool = false
var is_edge_clamped: bool = false
var heading_angle: float = 0.0

func _init(p_target_id: int, p_pos: Vector2, p_color: Color, p_size: float, p_max_life: float = 1.6) -> void:
	world_target_id = p_target_id
	radar_pos = p_pos
	color = p_color
	size = p_size
	max_life = p_max_life
	life = 1.0
