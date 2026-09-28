class_name GachaDomeWidget
extends Control

## GachaDomeWidget.gd
## Cúpula de cristal procedural con físicas de cápsulas rebotantes,
## reflejos neón especulares y animación de remolino al tirar de la palanca.

signal shake_finished()

var capsule_count: int = 14
var capsules: Array[Dictionary] = [] # { pos: Vector2, vel: Vector2, radius: float, col1: Color, col2: Color, angle: float, rot_speed: float }

var dome_radius: float = 110.0
var dome_center: Vector2 = Vector2.ZERO

var is_spinning: bool = false
var spin_energy: float = 0.0

const CAPSULE_PALETTES: Array[Array] = [
	[Color(0.0, 0.94, 1.0), Color(0.1, 0.2, 0.5)], # Cyan / Deep Blue
	[Color(1.0, 0.2, 0.6), Color(0.3, 0.05, 0.2)], # Magenta / Plum
	[Color(1.0, 0.85, 0.2), Color(0.5, 0.3, 0.0)], # Gold / Amber
	[Color(0.4, 1.0, 0.5), Color(0.05, 0.3, 0.15)], # Mint / Forest
	[Color(0.7, 0.4, 1.0), Color(0.2, 0.05, 0.4)], # Violet / Dark Purple
	[Color(1.0, 0.4, 0.2), Color(0.4, 0.1, 0.0)]  # Neon Orange / Russet
]

func _ready() -> void:
	custom_minimum_size = Vector2(300, 300)
	dome_radius = 120.0
	_init_capsules()

func _init_capsules() -> void:
	capsules.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	# Distribuir las cápsulas en la mitad inferior de la cúpula para que formen un montoncito natural
	for i in range(capsule_count):
		var ang := rng.randf_range(PI * 0.15, PI * 0.85)
		var dist := rng.randf_range(30.0, dome_radius - 28.0)
		var pal_pair: Array = CAPSULE_PALETTES[i % CAPSULE_PALETTES.size()]
		var r: float = rng.randf_range(16.0, 20.0)
		
		capsules.append({
			"pos": Vector2(cos(ang), sin(ang)) * dist,
			"vel": Vector2.ZERO,
			"radius": r,
			"col1": pal_pair[0] as Color,
			"col2": pal_pair[1] as Color,
			"angle": rng.randf_range(0.0, TAU),
			"rot_speed": rng.randf_range(-1.0, 1.0)
		})

func trigger_spin_and_shake(duration: float = 1.2) -> void:
	is_spinning = true
	spin_energy = 1.0
	
	var tw := create_tween()
	tw.tween_property(self, "spin_energy", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		is_spinning = false
		shake_finished.emit()
	)
	
	# Impulso explosivo inicial hacia arriba y remolino
	for cap in capsules:
		var burst_angle := randf_range(-PI * 0.9, -PI * 0.1) # Hacia arriba
		var speed := randf_range(350.0, 600.0)
		cap["vel"] = Vector2(cos(burst_angle), sin(burst_angle)) * speed
		cap["rot_speed"] = randf_range(-15.0, 15.0)

func _process(delta: float) -> void:
	dome_center = size * 0.5
	
	var gravity := Vector2(0, 180.0)
	var current_friction := 0.94
	if is_spinning:
		gravity = Vector2.ZERO
		current_friction = 0.98

	for i in range(capsules.size()):
		var cap: Dictionary = capsules[i]
		var pos: Vector2 = cap["pos"]
		var vel: Vector2 = cap["vel"]
		var r: float = cap["radius"]
		
		if is_spinning:
			# Efecto de vórtice magnético centrífugo
			var to_center := -pos
			var tangent := Vector2(-to_center.y, to_center.x).normalized()
			vel += tangent * (spin_energy * 650.0 * delta)
			vel += Vector2(randf_range(-100.0, 100.0), randf_range(-100.0, 100.0)) * spin_energy
			
		vel += gravity * delta
		vel *= current_friction
		pos += vel * delta
		
		# Limitar al borde circular del domo de cristal
		var dist := pos.length()
		var max_dist := dome_radius - r - 4.0
		if dist > max_dist:
			var normal := pos.normalized()
			pos = normal * max_dist
			vel = vel.bounce(normal) * 0.65
			
		cap["pos"] = pos
		cap["vel"] = vel
		cap["angle"] += float(cap["rot_speed"]) * delta

	# Repulsión y colisión entre cápsulas para evitar que se amontonen en un solo punto
	for i in range(capsules.size()):
		for j in range(i + 1, capsules.size()):
			var c1: Dictionary = capsules[i]
			var c2: Dictionary = capsules[j]
			var diff: Vector2 = c2["pos"] - c1["pos"]
			var d := diff.length()
			var min_dist: float = c1["radius"] + c2["radius"]
			if d < min_dist and d > 0.001:
				var overlap: float = (min_dist - d) * 0.5
				var dir := diff.normalized()
				c1["pos"] -= dir * overlap
				c2["pos"] += dir * overlap
				var rel_vel: Vector2 = c2["vel"] - c1["vel"]
				var sep_impulse: Vector2 = dir * (rel_vel.dot(dir) * 0.5)
				c1["vel"] += sep_impulse
				c2["vel"] -= sep_impulse

	queue_redraw()

func _draw() -> void:
	var c := dome_center
	
	# Sombra exterior difusa de la máquina
	draw_circle(c + Vector2(0, 14), dome_radius + 4.0, Color(0.0, 0.0, 0.0, 0.45))
	
	# Fondo interior oscuro de la cúpula (cámara acrílica)
	draw_circle(c, dome_radius, Color(0.04, 0.03, 0.09, 0.95))
	
	# Anillo interior neón de sujeción
	draw_arc(c, dome_radius - 2.0, 0, TAU, 48, Color(0.0, 0.94, 1.0, 0.25), 2.0, true)
	
	# Dibujar cada una de las cápsulas bicolores dentro
	for cap in capsules:
		var p: Vector2 = c + cap["pos"]
		var r: float = cap["radius"]
		var ang: float = cap["angle"]
		var c1: Color = cap["col1"]
		var c2: Color = cap["col2"]
		
		# Sombra de la cápsula
		draw_circle(p + Vector2(0, 3), r, Color(0.0, 0.0, 0.0, 0.35))
		
		# Mitad 1 (color vibrante)
		draw_circle_arc_half(p, r, ang, ang + PI, c1)
		# Mitad 2 (color oscuro / acento)
		draw_circle_arc_half(p, r, ang + PI, ang + TAU, c2)
		
		# Borde ecuatorial metálico de unión
		var div_start := p + Vector2(cos(ang), sin(ang)) * r
		var div_end := p - Vector2(cos(ang), sin(ang)) * r
		draw_line(div_start, div_end, Color(0.9, 0.95, 1.0, 0.8), 2.0, true)
		
		# Brillo especular blanco en la cápsula
		var spec_offset := Vector2(cos(ang - 0.7), sin(ang - 0.7)) * (r * 0.45)
		draw_circle(p + spec_offset, r * 0.22, Color(1.0, 1.0, 1.0, 0.6))
	
	# --- CRISTAL Y REFLEJOS ESPECULARES DE LA CÚPULA ---
	# Resplandor cian perimetral del domo
	draw_arc(c, dome_radius, 0, TAU, 64, Color(0.0, 0.94, 1.0, 0.85), 3.0, true)
	
	# Arco de reflejo curvo superior izquierdo (efecto de cristal abombado)
	draw_arc(c - Vector2(10, 10), dome_radius * 0.75, PI * 1.05, PI * 1.55, 32, Color(1.0, 1.0, 1.0, 0.55), 4.5, true)
	draw_arc(c - Vector2(8, 8), dome_radius * 0.65, PI * 1.1, PI * 1.45, 24, Color(0.0, 0.94, 1.0, 0.35), 2.0, true)
	
	# Destello puntual en la cima del domo
	draw_circle(c + Vector2(-dome_radius * 0.45, -dome_radius * 0.55), 6.0, Color(1.0, 1.0, 1.0, 0.8))
	draw_circle(c + Vector2(-dome_radius * 0.45, -dome_radius * 0.55), 12.0, Color(0.0, 0.94, 1.0, 0.35))
	
	# Base metálica inferior de expulsión
	var base_rect := Rect2(c.x - dome_radius * 0.7, c.y + dome_radius * 0.75, dome_radius * 1.4, 28)
	draw_rect(base_rect, Color(0.08, 0.07, 0.15, 0.95), true)
	draw_rect(base_rect, Color(0.0, 0.94, 1.0, 0.7), false, 2.0)
	
	# Boquilla del dispensador
	var nozzle := Rect2(c.x - 28, c.y + dome_radius * 0.82, 56, 14)
	draw_rect(nozzle, Color(0.02, 0.01, 0.05, 1.0), true)
	draw_rect(nozzle, Color(1.0, 0.85, 0.2, 0.85), false, 1.5)

func draw_circle_arc_half(center: Vector2, radius: float, angle_from: float, angle_to: float, color: Color) -> void:
	var nb_points := 20
	var points_arc := PackedVector2Array()
	points_arc.push_back(center)
	
	for i in range(nb_points + 1):
		var angle_point: float = angle_from + i * (angle_to - angle_from) / nb_points
		points_arc.push_back(center + Vector2(cos(angle_point), sin(angle_point)) * radius)
	
	draw_colored_polygon(points_arc, color)
