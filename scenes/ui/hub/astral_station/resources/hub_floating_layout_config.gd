class_name HubFloatingLayoutConfig
extends Resource

## Configuración 100% data-driven de la Mandala Octagonal de 9 Islas, 8 Puentes Perpendiculares,
## Física de Travesía (Plataforma ↔ Espacio) y Salida Radial en 8 Direcciones Cardinales.

@export_group("Octagonal Archipelago Geometry (XZ Plane)")
@export var central_island_pos: Vector2 = Vector2(0.0, 0.0)
@export var central_island_radius: float = 7.60
@export var north_island_pos: Vector2 = Vector2(0.0, -15.42)
@export var north_island_radius: float = 4.113
@export var south_island_pos: Vector2 = Vector2(0.0, 15.82)
@export var south_island_radius: float = 4.546
@export var west_island_pos: Vector2 = Vector2(-15.42, 0.0)
@export var east_island_pos: Vector2 = Vector2(15.42, 0.0)
@export var bastion_dock_x: float = 3.80
@export var bastion_arc_radius: float = 5.35
@export var loadout_pod_positions: Array[Vector2] = [
	Vector2(-10.20, -10.20),
	Vector2(10.20, -10.20),
	Vector2(-10.20, 10.20),
	Vector2(10.20, 10.20),
]
@export var loadout_pod_radius: float = 3.15

# Alias heredado para tests/compatibilidad con nodos que consulten north_prow_pos
@export var north_prow_pos: Vector2 = Vector2(0.0, -15.42)
@export var north_prow_radius: float = 4.113

@export_group("8 Perpendicular Flush-Docked Bridges")
@export var bridges: Array[Dictionary] = [
	{"name": "Bridge_North", "from": Vector2(0.0, -7.02), "to": Vector2(0.0, -11.62), "half_width": 1.05},
	{"name": "Bridge_South", "from": Vector2(0.0, 7.02), "to": Vector2(0.0, 11.62), "half_width": 1.05},
	{"name": "Bridge_West", "from": Vector2(-7.02, 0.0), "to": Vector2(-11.62, 0.0), "half_width": 1.05},
	{"name": "Bridge_East", "from": Vector2(7.02, 0.0), "to": Vector2(11.62, 0.0), "half_width": 1.05},
	{"name": "Bridge_NW", "from": Vector2(-4.965, -4.965), "to": Vector2(-8.145, -8.145), "half_width": 0.90},
	{"name": "Bridge_NE", "from": Vector2(4.965, -4.965), "to": Vector2(8.145, -8.145), "half_width": 0.90},
	{"name": "Bridge_SW", "from": Vector2(-4.965, 4.965), "to": Vector2(-8.145, 8.145), "half_width": 0.90},
	{"name": "Bridge_SE", "from": Vector2(4.965, 4.965), "to": Vector2(8.145, 8.145), "half_width": 0.90},
]

@export_group("Traversal Tuning (Walk vs Flight)")
@export var platform_walk_speed: float = 6.2
@export var space_flight_speed: float = 11.5
@export var departure_boost_speed: float = 18.5
@export var platform_hover_y: float = 0.02
@export var capsule_pad_xz: Vector2 = Vector2(0.0, 0.0)
@export var capsule_pad_radius: float = 2.05
@export var capsule_pad_hover_y: float = 0.112
@export var flight_hover_y: float = 0.44
@export var traversal_hysteresis_sec: float = 0.10

@export_group("Radial 8-Dir Seamless Departure")
@export var warning_radius: float = 24.5
@export var launch_radius: float = 30.0
@export var demat_duration_sec: float = 1.35
@export var sectors_8dir: Array[Dictionary] = [
	{"id": &"E", "label": "SECTOR ESTE · E", "color": Color(1.0, 0.24, 0.62, 1.0), "angle_deg": 0.0},
	{"id": &"SE", "label": "SECTOR SURESTE · SE", "color": Color(1.0, 0.62, 0.22, 1.0), "angle_deg": 45.0},
	{"id": &"S", "label": "SECTOR SUR · S", "color": Color(0.95, 0.80, 0.34, 1.0), "angle_deg": 90.0},
	{"id": &"SW", "label": "SECTOR SUROESTE · SW", "color": Color(0.75, 0.35, 1.0, 1.0), "angle_deg": 135.0},
	{"id": &"W", "label": "SECTOR OESTE · W", "color": Color(0.58, 0.28, 1.0, 1.0), "angle_deg": 180.0},
	{"id": &"NW", "label": "SECTOR NOROESTE · NW", "color": Color(0.32, 0.72, 1.0, 1.0), "angle_deg": 225.0},
	{"id": &"N", "label": "SECTOR NORTE · N", "color": Color(0.14, 0.94, 1.0, 1.0), "angle_deg": 270.0},
	{"id": &"NE", "label": "SECTOR NORESTE · NE", "color": Color(0.24, 1.0, 0.68, 1.0), "angle_deg": 315.0},
]


func is_point_on_platform(xz: Vector2) -> bool:
	# 1. Octágono Central Flagship
	if _in_octagon_approx(xz, central_island_pos, central_island_radius):
		return true

	# 2. Isla Norte (Spotlight Skins) e Isla Sur (Ceremonial Talentos)
	if _in_octagon_approx(xz, north_island_pos, north_island_radius):
		return true
	if _in_octagon_approx(xz, south_island_pos, south_island_radius):
		return true

	# 3. Par Espejado Bastión Oeste / Este
	if _in_mirrored_bastion(xz, west_island_pos, -1.0):
		return true
	if _in_mirrored_bastion(xz, east_island_pos, 1.0):
		return true

	# 4. 4 Octágonos Intermedios Compactos (NW, NE, SW, SE)
	for pod_pos: Vector2 in loadout_pod_positions:
		if _in_octagon_approx(xz, pod_pos, loadout_pod_radius):
			return true

	# 5. 8 Puentes Perpendiculares
	for b: Dictionary in bridges:
		var p_a: Vector2 = b.get("from", Vector2.ZERO) as Vector2
		var p_b: Vector2 = b.get("to", Vector2.ZERO) as Vector2
		var hw: float = float(b.get("half_width", 1.0))
		if _point_in_capsule_segment(xz, p_a, p_b, hw):
			return true

	return false


func quantize_departure_sector(dir_xz: Vector2) -> Dictionary:
	var n: Vector2 = dir_xz.normalized() if dir_xz.length_squared() > 0.0001 else Vector2(0.0, -1.0)
	var ang_deg: float = rad_to_deg(atan2(n.y, n.x))
	if ang_deg < 0.0:
		ang_deg += 360.0
	var idx: int = int(floor((ang_deg + 22.5) / 45.0)) % 8
	if idx >= 0 and idx < sectors_8dir.size():
		return sectors_8dir[idx]
	return {"id": &"N", "label": "SECTOR NORTE · N", "color": Color(0.14, 0.94, 1.0, 1.0), "angle_deg": 270.0}


static func _in_octagon_approx(xz: Vector2, center: Vector2, radius: float) -> bool:
	var apothem: float = radius * 0.9238795
	var d: Vector2 = (xz - center).abs()
	if d.x > apothem or d.y > apothem:
		return false
	return (d.x + d.y) * 0.7071068 <= apothem


func _in_mirrored_bastion(xz: Vector2, center: Vector2, mirror_sign_x: float) -> bool:
	var local := Vector2((xz.x - center.x) * mirror_sign_x, xz.y - center.y)
	if local.x < -bastion_dock_x:
		return false
	if local.x <= 0.0:
		var max_z: float = lerpf(2.75, bastion_arc_radius, clampf((local.x + bastion_dock_x) / bastion_dock_x, 0.0, 1.0))
		return absf(local.y) <= max_z
	return local.length_squared() <= bastion_arc_radius * bastion_arc_radius


static func _point_in_capsule_segment(p: Vector2, a: Vector2, b: Vector2, half_w: float) -> bool:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq < 0.0001:
		return p.distance_squared_to(a) <= half_w * half_w
	var t: float = clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return p.distance_squared_to(proj) <= half_w * half_w
