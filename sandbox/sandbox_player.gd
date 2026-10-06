extends Node2D

const SHIPS_DIR = "res://assets/characters/ships/"
const PILOT_NAMES = ["echo", "kira", "nova", "nyx", "roxy", "selene", "valentina"]
const SHADER_PILOT = preload("res://sandbox/pilot_flight.gdshader")

class PilotInstance:
	var root: Node2D
	var sprite: Sprite2D
	var material: ShaderMaterial
	var time_offset: float = 0.0
	var center_offset: Vector2 = Vector2.ZERO
	var last_rot: float = 0.0
	var current_bend: float = 0.0

var pilots: Array[PilotInstance] = []
var global_timer: float = 0.0

@export var flight_speed: float = 1.3
@export var radius_x: float = 280.0
@export var radius_y: float = 140.0

func _ready() -> void:
	# Ajustamos la cámara para ver a todas cómodamente
	var cam = $Camera2D if has_node("Camera2D") else Camera2D.new()
	if not cam.is_inside_tree():
		add_child(cam)
	cam.zoom = Vector2(0.65, 0.65) # Zoom amplio

	# Limpiamos nodos previos si existían
	if has_node("PilotoTest"):
		$PilotoTest.queue_free()

	for i in range(PILOT_NAMES.size()):
		var ship_name = PILOT_NAMES[i]
		var tex_path = SHIPS_DIR + "ship_%s.png" % ship_name
		var mask_path = SHIPS_DIR + "ship_%s_mask.png" % ship_name

		if not ResourceLoader.exists(tex_path):
			continue

		var p = PilotInstance.new()
		p.root = Node2D.new()
		p.root.name = ship_name.capitalize()
		add_child(p.root)

		p.sprite = Sprite2D.new()
		p.sprite.texture = load(tex_path)
		p.root.add_child(p.sprite)

		p.material = ShaderMaterial.new()
		p.material.shader = SHADER_PILOT
		
		# Configuraciones específicas de ángulo de pelo por caso
		if ship_name == "valentina":
			p.material.set_shader_parameter("hair_dir", Vector2(0.2, 1.0))
			p.material.set_shader_parameter("wave_freq", 24.0)
		elif ship_name == "roxy":
			p.material.set_shader_parameter("hair_dir", Vector2(0.7, -0.7))
		else:
			p.material.set_shader_parameter("hair_dir", Vector2(1.0, 0.0))

		# Comprobamos si ya creaste su máscara
		if ResourceLoader.exists(mask_path):
			var mask_tex = load(mask_path)
			p.material.set_shader_parameter("mask_texture", mask_tex)
			p.material.set_shader_parameter("has_mask", true)
		else:
			p.material.set_shader_parameter("has_mask", false)

		p.sprite.material = p.material
		
		# Desfase temporal a lo largo del 8 para que vuelen en fila india/patrulla
		p.time_offset = (float(i) / float(PILOT_NAMES.size())) * (TAU * 2.0)
		
		# Separación leve de formación
		var col = (i % 4) - 1.5
		var row = floor(float(i) / 4.0) - 0.5
		p.center_offset = Vector2(col * 220.0, row * 240.0)

		pilots.append(p)

func _process(delta: float) -> void:
	global_timer += delta * flight_speed

	for p in pilots:
		var t = global_timer + p.time_offset
		
		# 1. Trayectoria Lemniscata alrededor de su cuadrante de formación
		var pos_x = p.center_offset.x + cos(t) * radius_x
		var pos_y = p.center_offset.y + sin(t) * cos(t) * radius_y
		p.root.position = Vector2(pos_x, pos_y)

		# 2. Dirección tangencial
		var vel_x = -sin(t) * radius_x
		var vel_y = (cos(t) * cos(t) - sin(t) * sin(t)) * radius_y
		var move_direction = Vector2(vel_x, vel_y)

		var target_rot = move_direction.angle() + (PI / 2.0)
		p.root.rotation = target_rot

		# 3. Inercia angular de piernas
		var turn_delta = angle_difference(p.last_rot, p.root.rotation)
		var turn_rate = turn_delta / delta
		p.last_rot = p.root.rotation

		var target_bend = clamp(turn_rate * 0.035, -0.16, 0.16)
		p.current_bend = lerp(p.current_bend, target_bend, 7.0 * delta)

		p.material.set_shader_parameter("leg_bend", p.current_bend)
