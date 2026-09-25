class_name DeploymentSpaceBackground
extends Control

## deployment_space_background.gd
## Fondo espacial animado con Parallax cósmico idéntico al de la pantalla de inicio
## y naves que cruzan la pantalla a velocidades y trayectorias aleatorias (máximo 1 de cada).

const SpaceBackgroundScene := preload("res://scenes/combat/environment/space_background.tscn")

const SHIPS: Array[Dictionary] = [
	{
		"id": &"nova",
		"name": "Nova",
		"tex_path": "res://assets/characters/ships/ship_nova.png",
		"glow": Color(1.0, 0.5, 0.15, 0.9)
	},
	{
		"id": &"valentina",
		"name": "Valentina",
		"tex_path": "res://assets/characters/ships/ship_valentina.png",
		"glow": Color(0.2, 0.85, 1.0, 0.9)
	},
	{
		"id": &"kira",
		"name": "Kira",
		"tex_path": "res://assets/characters/ships/ship_kira.png",
		"glow": Color(0.3, 1.0, 0.55, 0.9)
	},
	{
		"id": &"selene",
		"name": "Selene",
		"tex_path": "res://assets/characters/ships/ship_selene.png",
		"glow": Color(0.85, 0.35, 1.0, 0.9)
	},
	{
		"id": &"roxy",
		"name": "Roxanne",
		"tex_path": "res://assets/characters/ships/ship_roxy.png",
		"glow": Color(1.0, 0.85, 0.25, 0.9)
	},
	{
		"id": &"echo",
		"name": "Echo",
		"tex_path": "res://assets/characters/ships/ship_echo.png",
		"glow": Color(0.15, 0.95, 0.95, 0.9)
	},
	{
		"id": &"nyx",
		"name": "Nyx",
		"tex_path": "res://assets/characters/ships/ship_nyx.png",
		"glow": Color(0.9, 0.25, 1.0, 0.9)
	}
]

enum TrajectoryType {
	STRAIGHT,
	CURVE_QUAD,
	CURVE_SINE
}

@onready var ships_container: Node2D = $ShipsContainer
@onready var dark_vignette: ColorRect = $DarkVignette

var _active_ships: Dictionary = {} # ship_id -> Node2D
var _spawn_timer: float = 0.0
var _next_spawn_delay: float = 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not has_node("SpaceBackground"):
		var bg := SpaceBackgroundScene.instantiate()
		bg.name = "SpaceBackground"
		add_child(bg)
		move_child(bg, 0)
	
	if not ships_container:
		ships_container = Node2D.new()
		ships_container.name = "ShipsContainer"
		add_child(ships_container)
		move_child(ships_container, 1)

	if not dark_vignette:
		dark_vignette = ColorRect.new()
		dark_vignette.name = "DarkVignette"
		dark_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		dark_vignette.color = Color(0.015, 0.02, 0.035, 0.65)
		dark_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dark_vignette)
		move_child(dark_vignette, 2)

	_next_spawn_delay = randf_range(0.8, 1.8)

func _process(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer >= _next_spawn_delay:
		_spawn_timer = 0.0
		_next_spawn_delay = randf_range(1.6, 3.4)
		_attempt_spawn_ship()

func _attempt_spawn_ship() -> void:
	var available: Array[Dictionary] = []
	for ship_cfg in SHIPS:
		if ship_cfg["id"] == &"nyx" and not SaveManager.is_character_unlocked(&"nyx"):
			continue
		if not _active_ships.has(ship_cfg["id"]):
			available.append(ship_cfg)

	if available.is_empty():
		return

	var chosen: Dictionary = available[randi() % available.size()]
	_spawn_ship(chosen)

func _spawn_ship(cfg: Dictionary) -> void:
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(1920, 1080)

	var margin: float = 120.0
	
	# Elegir borde de entrada (0: Izq, 1: Arriba, 2: Der, 3: Abajo)
	var start_edge: int = randi() % 4
	var start_pos := Vector2.ZERO
	match start_edge:
		0: # Izquierda
			start_pos = Vector2(-margin, randf_range(60.0, vp_size.y - 60.0))
		1: # Arriba
			start_pos = Vector2(randf_range(60.0, vp_size.x - 60.0), -margin)
		2: # Derecha
			start_pos = Vector2(vp_size.x + margin, randf_range(60.0, vp_size.y - 60.0))
		3: # Abajo
			start_pos = Vector2(randf_range(60.0, vp_size.x - 60.0), vp_size.y + margin)

	# Elegir borde de salida distinto al de entrada
	var end_edge: int = (start_edge + 1 + (randi() % 3)) % 4
	var end_pos := Vector2.ZERO
	match end_edge:
		0:
			end_pos = Vector2(-margin, randf_range(60.0, vp_size.y - 60.0))
		1:
			end_pos = Vector2(randf_range(60.0, vp_size.x - 60.0), -margin)
		2:
			end_pos = Vector2(vp_size.x + margin, randf_range(60.0, vp_size.y - 60.0))
		3:
			end_pos = Vector2(randf_range(60.0, vp_size.x - 60.0), vp_size.y + margin)

	var distance: float = start_pos.distance_to(end_pos)
	if distance < 400.0:
		distance = 400.0

	# Velocidad aleatoria entre 280 y 500 px/s para que nunca se queden demasiado
	var speed: float = randf_range(280.0, 500.0)
	var duration: float = clampf(distance / speed, 3.2, 6.2)

	# Tipo de trayectoria aleatoria
	var traj_type: TrajectoryType = randi() % 3 as TrajectoryType
	var mid_point: Vector2 = start_pos.lerp(end_pos, 0.5)
	var dir: Vector2 = (end_pos - start_pos).normalized()
	var normal: Vector2 = Vector2(-dir.y, dir.x)
	var curve_offset: float = randf_range(-380.0, 380.0)
	var control_point: Vector2 = mid_point + normal * curve_offset
	var sine_frequency: float = randf_range(1.5, 3.5)
	var sine_amplitude: float = randf_range(40.0, 110.0)

	# Crear nodo de la nave
	var ship_node := Node2D.new()
	ship_node.name = "FlybyShip_" + String(cfg["id"])
	ship_node.position = start_pos

	# Estela de propulsor (Trail)
	var trail := Line2D.new()
	trail.name = "ThrusterTrail"
	trail.width = 6.0
	trail.default_color = cfg["glow"]
	trail.top_level = false
	trail.z_index = -1
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	trail.width_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 0.95))
	grad.set_color(1, Color(cfg["glow"].r, cfg["glow"].g, cfg["glow"].b, 0.0))
	trail.gradient = grad
	ships_container.add_child(trail)

	# Sprite
	var tex := _get_ship_texture(cfg)
	if not tex:
		trail.queue_free()
		ship_node.queue_free()
		return

	var sprite := Sprite2D.new()
	sprite.texture = tex
	var ship_scale: float = randf_range(0.36, 0.54)
	sprite.scale = Vector2(ship_scale, ship_scale)
	sprite.modulate = Color(0.9, 0.95, 1.0, randf_range(0.75, 0.92))
	ship_node.add_child(sprite)

	ships_container.add_child(ship_node)
	_active_ships[cfg["id"]] = ship_node

	# Script / Runner de movimiento
	var runner_dict := {
		"node": ship_node,
		"trail": trail,
		"id": cfg["id"],
		"start": start_pos,
		"end": end_pos,
		"control": control_point,
		"normal": normal,
		"traj": traj_type,
		"sine_freq": sine_frequency,
		"sine_amp": sine_amplitude,
		"duration": duration,
		"elapsed": 0.0,
		"trail_points": []
	}

	_animate_ship(runner_dict)

func _animate_ship(data: Dictionary) -> void:
	var node: Node2D = data["node"]
	var trail: Line2D = data["trail"]
	var id: StringName = data["id"]
	var duration: float = data["duration"]

	var tw := create_tween()
	tw.tween_method(func(val: float):
		if not is_instance_valid(node):
			return
		data["elapsed"] = val * duration
		var t: float = clampf(val, 0.0, 1.0)
		var current_pos := _eval_trajectory(data, t)
		var next_t := minf(t + 0.015, 1.0)
		var next_pos := _eval_trajectory(data, next_t)

		node.global_position = current_pos
		var forward := next_pos - current_pos
		if forward.length_squared() > 0.001:
			node.rotation = forward.angle() + PI * 0.5

		# Actualizar estela (en coordenadas locales de ships_container para quedar detrás de la UI y del piloto)
		if is_instance_valid(trail):
			var engine_pos: Vector2 = current_pos - forward.normalized() * 16.0
			var local_engine_pos: Vector2 = ships_container.to_local(engine_pos)
			var pts: Array = data["trail_points"]
			pts.push_front(local_engine_pos)
			if pts.size() > 18:
				pts.pop_back()
			var packed_pts := PackedVector2Array()
			for p in pts:
				packed_pts.append(p)
			trail.points = packed_pts
	, 0.0, 1.0, duration)

	tw.tween_callback(func():
		_cleanup_ship(id, node, trail)
	)

func _eval_trajectory(data: Dictionary, t: float) -> Vector2:
	var traj: TrajectoryType = data["traj"]
	var p0: Vector2 = data["start"]
	var p2: Vector2 = data["end"]

	match traj:
		TrajectoryType.STRAIGHT:
			return p0.lerp(p2, t)
		TrajectoryType.CURVE_QUAD:
			var p1: Vector2 = data["control"]
			var u := 1.0 - t
			return u * u * p0 + 2.0 * u * t * p1 + t * t * p2
		TrajectoryType.CURVE_SINE:
			var base_pos := p0.lerp(p2, t)
			var offset: Vector2 = data["normal"] * (sin(t * PI * float(data["sine_freq"])) * float(data["sine_amp"]))
			return base_pos + offset
		_:
			return p0.lerp(p2, t)

func _cleanup_ship(id: StringName, node: Node2D, trail: Line2D) -> void:
	if _active_ships.has(id):
		_active_ships.erase(id)
	if is_instance_valid(trail):
		trail.queue_free()
	if is_instance_valid(node):
		node.queue_free()

func _get_ship_texture(cfg: Dictionary) -> Texture2D:
	if cfg.has("tex") and cfg["tex"] is Texture2D:
		return cfg["tex"]
	var p: String = cfg.get("tex_path", "")
	if not p.is_empty() and ResourceLoader.exists(p):
		var res = load(p)
		if res is Texture2D:
			cfg["tex"] = res
			return res
	return null
