class_name HyperspacePortal
extends Node2D

## Vórtice Hiperespacial Procedural para la llegada cinematográfica de Pilotos Rivales.
## Renderiza anillos concéntricos giratorios, singularidad central luminosa,
## onda expansiva estelar de desintegración (shockwave) y partículas cósmicas.

signal portal_opened
signal shockwave_completed
signal portal_collapsed

enum PortalState { OPENING, SHOCKWAVE, ACTIVE, COLLAPSING, FINISHED }

@export var max_radius: float = 68.0
@export var clearance_radius: float = 680.0
@export var portal_color: Color = Color(0.0, 0.9, 1.0, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var auto_collapse: bool = false

var current_state: PortalState = PortalState.OPENING
var state_timer: float = 0.0
var open_duration: float = 0.35
var shockwave_duration: float = 0.38
var active_duration: float = 0.70
var collapse_duration: float = 0.25

var spin_angle: float = 0.0
var pulse_timer: float = 0.0
var current_scale: float = 0.0

# Shockwave visual properties
var shockwave_current_radius: float = 0.0
var shockwave_alpha: float = 0.0
var shockwave_front_width: float = 6.0
var _shockwave_has_cleared: bool = false

# Partículas de singularidad convergentes
var _particle_positions: PackedVector2Array = PackedVector2Array()
var _particle_speeds: PackedFloat32Array = PackedFloat32Array()
var _particle_radii: PackedFloat32Array = PackedFloat32Array()

# Partículas estelares expansivas de la shockwave
var _shockwave_particles: Array[Dictionary] = []


func setup(pos: Vector2, color: Color, p_radius: float = 68.0, p_clearance: float = 680.0) -> void:
	global_position = pos
	portal_color = color
	max_radius = p_radius
	clearance_radius = p_clearance


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 5
	z_as_relative = false

	# Inicializar 16 partículas orbitales convergentes hacia el centro
	var p_count: int = 16
	_particle_positions.resize(p_count)
	_particle_speeds.resize(p_count)
	_particle_radii.resize(p_count)
	for i in range(p_count):
		var ang: float = randf() * TAU
		var dist: float = randf_range(max_radius * 0.4, max_radius * 1.3)
		_particle_positions[i] = Vector2(cos(ang), sin(ang)) * dist
		_particle_speeds[i] = randf_range(90.0, 180.0)
		_particle_radii[i] = dist

	queue_redraw()


func _process(delta: float) -> void:
	state_timer += delta
	spin_angle += delta * 7.5
	pulse_timer += delta * 12.0

	# Actualizar partículas gravitacionales convergentes
	for i in range(_particle_positions.size()):
		var current_r: float = _particle_radii[i] - _particle_speeds[i] * delta
		if current_r <= 4.0:
			current_r = max_radius * randf_range(1.0, 1.4)
		_particle_radii[i] = current_r
		var ang: float = _particle_positions[i].angle() + delta * 4.0
		_particle_positions[i] = Vector2(cos(ang), sin(ang)) * current_r

	match current_state:
		PortalState.OPENING:
			var t: float = clampf(state_timer / open_duration, 0.0, 1.0)
			current_scale = Tween.interpolate_value(0.0, 1.0, t, 1.0, Tween.TRANS_BACK, Tween.EASE_OUT)
			if state_timer >= open_duration:
				current_state = PortalState.SHOCKWAVE
				state_timer = 0.0
				portal_opened.emit()
				_detonate_clearance_shockwave()

		PortalState.SHOCKWAVE:
			var t: float = clampf(state_timer / shockwave_duration, 0.0, 1.0)
			current_scale = 1.0 + sin(pulse_timer) * 0.05
			shockwave_current_radius = lerpf(max_radius * 0.8, clearance_radius, Tween.interpolate_value(0.0, 1.0, t, 1.0, Tween.TRANS_QUAD, Tween.EASE_OUT))
			shockwave_alpha = (1.0 - t) * 0.95
			shockwave_front_width = lerpf(8.0, 2.0, t)

			if state_timer >= shockwave_duration:
				current_state = PortalState.ACTIVE
				state_timer = 0.0
				shockwave_alpha = 0.0
				shockwave_completed.emit()

		PortalState.ACTIVE:
			current_scale = 1.0 + sin(pulse_timer) * 0.06
			if auto_collapse and state_timer >= active_duration:
				start_collapse()

		PortalState.COLLAPSING:
			var t: float = clampf(state_timer / collapse_duration, 0.0, 1.0)
			current_scale = 1.0 - t
			shockwave_current_radius = max_radius * (1.0 + t * 1.5)
			shockwave_alpha = (1.0 - t) * 0.85
			if state_timer >= collapse_duration:
				current_state = PortalState.FINISHED
				portal_collapsed.emit()
				queue_free()
				return

	queue_redraw()


func _detonate_clearance_shockwave() -> void:
	if _shockwave_has_cleared:
		return
	_shockwave_has_cleared = true

	# Sonido estelar de onda expansiva
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("bomb_explode", 0.0, 1.4)

	# Generar partículas expansivas radiales
	_shockwave_particles.clear()
	var part_count: int = 24
	for i in range(part_count):
		var ang: float = randf() * TAU
		var p_dir := Vector2(cos(ang), sin(ang))
		var p_dist: float = randf_range(clearance_radius * 0.5, clearance_radius)
		var p_sz: float = randf_range(2.5, 5.0)
		_shockwave_particles.append({
			"dir": p_dir,
			"dist": p_dist,
			"size": p_sz
		})

	# Eliminar y vaporizar obstáculos en el radio del duelo (planetas, asteroides, macro-estructuras)
	var candidate_groups: Array[String] = ["planets", "destructibles", "asteroids", "planet_sectors"]
	var cleared_nodes: Dictionary = {}

	for grp in candidate_groups:
		for node in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(node) or node in cleared_nodes:
				continue
			if not (node is Node2D):
				continue
			var n2d := node as Node2D
			var dist: float = global_position.distance_to(n2d.global_position)

			var obj_r: float = 40.0
			if "crust_radius" in n2d:
				obj_r = float(n2d.get("crust_radius"))
			elif "obstacle_radius" in n2d:
				obj_r = float(n2d.get("obstacle_radius"))

			if dist <= (clearance_radius + obj_r):
				cleared_nodes[node] = true
				if n2d.has_method("disintegrate"):
					n2d.disintegrate(portal_color)
				elif n2d.has_method("_die"):
					n2d._die()
				else:
					_disintegrate_generic_node(n2d)


func _disintegrate_generic_node(n2d: Node2D) -> void:
	for child in n2d.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
		elif child is Area2D:
			(child as Area2D).set_deferred("monitoring", false)
			(child as Area2D).set_deferred("monitorable", false)

	var tw := create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	var flash_col := Color(
		lerpf(portal_color.r, 2.5, 0.7),
		lerpf(portal_color.g, 2.5, 0.7),
		lerpf(portal_color.b, 3.5, 0.7),
		0.0
	)
	tw.tween_property(n2d, "modulate", flash_col, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n2d, "scale", n2d.scale * 1.2, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(n2d.queue_free)


func start_collapse() -> void:
	if current_state != PortalState.COLLAPSING and current_state != PortalState.FINISHED:
		current_state = PortalState.COLLAPSING
		state_timer = 0.0


func _draw() -> void:
	if current_scale <= 0.001:
		return

	var r: float = max_radius * current_scale

	# 1. Singularidad central (núcleo blanco brillante con halo del color de la piloto)
	var glow_color := Color(portal_color.r, portal_color.g, portal_color.b, 0.35)
	draw_circle(Vector2.ZERO, r * 0.75, glow_color)

	var core_draw_color := Color(
		lerpf(portal_color.r, core_color.r, 0.7),
		lerpf(portal_color.g, core_color.g, 0.7),
		lerpf(portal_color.b, core_color.b, 0.7),
		0.9
	)
	draw_circle(Vector2.ZERO, r * 0.32, core_draw_color)
	draw_circle(Vector2.ZERO, r * 0.16, Color(1.0, 1.0, 1.0, 1.0))

	# 2. Anillos concéntricos giratorios con radios diferenciados
	var ring_color_outer := Color(portal_color.r, portal_color.g, portal_color.b, 0.85)
	var ring_color_mid := Color(portal_color.r, portal_color.g, portal_color.b, 0.65)
	var ring_color_inner := Color(1.0, 1.0, 1.0, 0.8)

	draw_arc(Vector2.ZERO, r, spin_angle, spin_angle + TAU * 0.85, 32, ring_color_outer, 3.0)
	draw_arc(Vector2.ZERO, r * 0.72, -spin_angle * 1.3, -spin_angle * 1.3 + TAU * 0.8, 28, ring_color_mid, 2.4)
	draw_arc(Vector2.ZERO, r * 0.45, spin_angle * 1.8, spin_angle * 1.8 + TAU * 0.75, 24, ring_color_inner, 2.0)

	# 3. Rayos de distorsión vórtice (8 espigas espirales)
	var spoke_count: int = 8
	var spoke_step: float = TAU / float(spoke_count)
	for s in range(spoke_count):
		var a1: float = spin_angle + float(s) * spoke_step
		var a2: float = a1 + 0.45
		var p1 := Vector2(cos(a1), sin(a1)) * (r * 0.3)
		var p2 := Vector2(cos(a2), sin(a2)) * (r * 0.95)
		draw_line(p1, p2, Color(portal_color.r, portal_color.g, portal_color.b, 0.55), 1.6)

	# 4. Partículas gravitacionales estelares
	if current_state != PortalState.COLLAPSING:
		for i in range(_particle_positions.size()):
			var p_pos := _particle_positions[i] * current_scale
			var p_alpha := clampf(_particle_radii[i] / max_radius, 0.2, 0.95)
			var p_col := Color(portal_color.r, portal_color.g, portal_color.b, p_alpha)
			draw_circle(p_pos, 2.0, p_col)

	# 5. Onda de choque expansiva de desintegración (Shockwave)
	if current_state == PortalState.SHOCKWAVE and shockwave_alpha > 0.02:
		var sw_col := Color(portal_color.r, portal_color.g, portal_color.b, shockwave_alpha)
		var sw_core := Color(1.0, 1.0, 1.0, shockwave_alpha * 0.85)
		draw_arc(Vector2.ZERO, shockwave_current_radius, 0.0, TAU, 64, sw_col, shockwave_front_width)
		draw_arc(Vector2.ZERO, maxf(1.0, shockwave_current_radius - 4.0), 0.0, TAU, 56, sw_core, shockwave_front_width * 0.5)

		# Dibujar partículas estelares disparadas radialmente
		var t_part: float = clampf(state_timer / shockwave_duration, 0.0, 1.0)
		for p in _shockwave_particles:
			var p_pos: Vector2 = p["dir"] * (float(p["dist"]) * t_part)
			var p_c := Color(portal_color.r, portal_color.g, portal_color.b, (1.0 - t_part) * 0.85)
			draw_circle(p_pos, float(p["size"]) * (1.0 - t_part * 0.4), p_c)

	# 6. Onda de choque de colapso
	if current_state == PortalState.COLLAPSING and shockwave_alpha > 0.01:
		var sw_col := Color(portal_color.r, portal_color.g, portal_color.b, shockwave_alpha)
		draw_arc(Vector2.ZERO, shockwave_current_radius, 0.0, TAU, 36, sw_col, 2.5)
