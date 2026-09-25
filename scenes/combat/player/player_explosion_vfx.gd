class_name PlayerExplosionVFX
extends Node2D

## Visual Effect for Player Ship Destruction.
## Renders a dramatic multi-layered sci-fi explosion:
## 1. Blinding core energy flash
## 2. Fast-expanding dual shockwave rings
## 3. High-velocity hull debris fragments flying outward with angular spin
## 4. Radial energy spark embers with drag

@export var duration: float = 1.4
@export var blast_color: Color = Color(0.2, 0.85, 1.0, 1.0) # Cyber Cyan
@export var secondary_color: Color = Color(1.0, 0.2, 0.55, 1.0) # Psychopop Magenta
@export var core_color: Color = Color(1.0, 1.0, 1.0, 1.0)

var _timer: float = 0.0

# Debris shards
class Shard:
	var offset: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var rotation: float = 0.0
	var rot_speed: float = 0.0
	var points: PackedVector2Array = PackedVector2Array()
	var color: Color = Color.WHITE

var _shards: Array[Shard] = []

# Spark particles
class Spark:
	var offset: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var color: Color = Color.WHITE
	var size: float = 2.0

var _sparks: Array[Spark] = []

func setup(pos: Vector2, accent_color: Color = Color(0.2, 0.85, 1.0, 1.0)) -> void:
	global_position = pos
	blast_color = accent_color

func _ready() -> void:
	z_index = 50
	z_as_relative = false

	# Generar fragmentos de casco (shards)
	var num_shards := randi_range(9, 14)
	for i in range(num_shards):
		var s := Shard.new()
		var angle := randf() * TAU
		var speed := randf_range(120.0, 320.0)
		s.velocity = Vector2(cos(angle), sin(angle)) * speed
		s.rot_speed = randf_range(-12.0, 12.0)
		s.rotation = randf() * TAU

		# Forma triangular o trapezoidal del fragmento
		var sz := randf_range(4.0, 12.0)
		s.points = PackedVector2Array([
			Vector2(-sz * 0.7, -sz * 0.5),
			Vector2(sz * 0.8, -sz * 0.3),
			Vector2(sz * 0.4, sz * 0.6),
			Vector2(-sz * 0.5, sz * 0.4)
		])
		# Color del fragmento: mezcla de color primario y metal oscuro
		s.color = blast_color.lerp(Color(0.85, 0.9, 1.0), randf_range(0.2, 0.8)) if randf() > 0.4 else secondary_color
		_shards.append(s)

	# Generar chispas de energía radiales
	var num_sparks := randi_range(24, 36)
	for i in range(num_sparks):
		var sp := Spark.new()
		var sp_angle := (float(i) / float(num_sparks)) * TAU + randf_range(-0.15, 0.15)
		var sp_speed := randf_range(160.0, 420.0)
		sp.velocity = Vector2(cos(sp_angle), sin(sp_angle)) * sp_speed
		sp.size = randf_range(2.0, 4.5)
		sp.color = core_color if randf() > 0.5 else (blast_color if randf() > 0.5 else secondary_color)
		_sparks.append(sp)

	queue_redraw()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= duration:
		queue_free()
		return

	# Actualizar física de escombros y chispas
	for s in _shards:
		s.offset += s.velocity * delta
		s.velocity = s.velocity.move_toward(Vector2.ZERO, 140.0 * delta) # Fricción espacial
		s.rotation += s.rot_speed * delta

	for sp in _sparks:
		sp.offset += sp.velocity * delta
		sp.velocity = sp.velocity.move_toward(Vector2.ZERO, 200.0 * delta)

	queue_redraw()

func _draw() -> void:
	var t := clampf(_timer / duration, 0.0, 1.0)
	var alpha_global := 1.0 - t

	# 1. Destello inicial nuclear cegador (0.0s -> 0.3s)
	if t < 0.35:
		var flash_t := t / 0.35
		var flash_alpha := (1.0 - flash_t) * 0.95
		var flash_r := lerpf(15.0, 240.0, flash_t)
		# Halo exterior
		draw_circle(Vector2.ZERO, flash_r, Color(secondary_color.r, secondary_color.g, secondary_color.b, flash_alpha * 0.4))
		# Halo intermedio
		draw_circle(Vector2.ZERO, flash_r * 0.6, Color(blast_color.r, blast_color.g, blast_color.b, flash_alpha * 0.7))
		# Núcleo blanco
		draw_circle(Vector2.ZERO, flash_r * 0.3, Color(1.0, 1.0, 1.0, flash_alpha))

	# 2. Onda expansiva primaria (Shockwave ring)
	var shock_t := clampf(_timer / (duration * 0.8), 0.0, 1.0)
	var ease_shock := 1.0 - pow(1.0 - shock_t, 3.0)
	var shock_radius := ease_shock * 380.0
	var shock_alpha := (1.0 - shock_t) * 0.9

	if shock_radius > 6.0:
		# Anillo de plasma exterior
		draw_arc(Vector2.ZERO, shock_radius, 0.0, TAU, 48, Color(blast_color.r, blast_color.g, blast_color.b, shock_alpha * 0.7), 4.0, true)
		# Anillo fino interior super-brillante
		draw_arc(Vector2.ZERO, maxf(1.0, shock_radius - 6.0), 0.0, TAU, 48, Color(core_color.r, core_color.g, core_color.b, shock_alpha * 0.9), 2.0, true)

	# 3. Onda expansiva secundaria (Psychopop ring diferido)
	if t > 0.08:
		var sec_t := clampf((_timer - 0.08) / (duration * 0.7), 0.0, 1.0)
		var sec_ease := 1.0 - pow(1.0 - sec_t, 2.5)
		var sec_radius := sec_ease * 260.0
		var sec_alpha := (1.0 - sec_t) * 0.7
		if sec_radius > 4.0:
			draw_arc(Vector2.ZERO, sec_radius, 0.0, TAU, 36, Color(secondary_color.r, secondary_color.g, secondary_color.b, sec_alpha * 0.6), 3.0, true)

	# 4. Dibujar chispas de energía proyectadas
	for sp in _sparks:
		var sp_col := Color(sp.color.r, sp.color.g, sp.color.b, alpha_global * 0.9)
		draw_circle(sp.offset, sp.size * (1.0 - t * 0.5), sp_col)

	# 5. Dibujar escombros de casco girando
	for s in _shards:
		var shard_alpha := clampf(alpha_global * 1.2, 0.0, 1.0)
		var col := Color(s.color.r, s.color.g, s.color.b, shard_alpha)
		var transformed_pts := PackedVector2Array()
		for pt in s.points:
			transformed_pts.append(s.offset + pt.rotated(s.rotation))
		draw_colored_polygon(transformed_pts, col)
