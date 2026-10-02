class_name CosmicRealityTear
extends Node2D

## Ruptura Cósmica / Fractura de Realidad Espaciotemporal.
## Efecto procedural distintivo para la aparición cinematográfica de Jefes de Dominio y Astra Prime.
## Genera una fisura dimensional con arcos eléctricos fractales, núcleo de singularidad
## gravitacional, absorción de partículas cósmicas y onda expansiva de despeje sectorial.

signal tear_opened
signal shockwave_completed
signal tear_collapsed

enum TearState { OPENING, SHOCKWAVE, ACTIVE, COLLAPSING, FINISHED }

@export var fissure_length: float = 240.0
@export var fissure_width: float = 46.0
@export var clearance_radius: float = 750.0
@export var domain_color: Color = Color(0.75, 0.2, 1.0, 1.0)
@export var core_color: Color = Color(0.04, 0.02, 0.08, 1.0)
@export var rim_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var auto_collapse: bool = false

var current_state: TearState = TearState.OPENING
var state_timer: float = 0.0
var open_duration: float = 0.40
var shockwave_duration: float = 0.45
var active_duration: float = 1.00
var collapse_duration: float = 0.32

var current_open_ratio: float = 0.0
var pulse_timer: float = 0.0
var crackle_timer: float = 0.0

# Shockwave
var shockwave_current_radius: float = 0.0
var shockwave_alpha: float = 0.0
var shockwave_front_width: float = 8.0
var _shockwave_has_cleared: bool = false

# Geometría de la fisura fractal
var _spine_points: PackedVector2Array = PackedVector2Array()
var _left_lip_points: PackedVector2Array = PackedVector2Array()
var _right_lip_points: PackedVector2Array = PackedVector2Array()
var _lightning_arcs: Array[PackedVector2Array] = []

# Partículas de colapso/absorción gravitacional
var _gravity_particles: Array[Dictionary] = []
var _shockwave_particles: Array[Dictionary] = []


static func get_boss_domain_color(boss_id: String) -> Color:
	match boss_id:
		"boss_hermit_void":
			return Color(0.68, 0.15, 0.95, 1.0) # Violeta Abisal
		"boss_ash_clock":
			return Color(1.0, 0.58, 0.12, 1.0) # Ámbar Cronológico
		"boss_broken_mirror":
			return Color(0.25, 0.88, 1.0, 1.0) # Espejo Prismático Cian
		"boss_overflow_vortex":
			return Color(0.95, 0.18, 0.65, 1.0) # Vórtice Magenta Caótico
		"boss_mothership", "boss_aegis":
			return Color(0.12, 0.65, 1.0, 1.0) # Azul Eléctrico Aegis
		"boss_astra_prime":
			return Color(1.0, 0.86, 0.28, 1.0) # Oro Radiante Núcleo
		_:
			return Color(0.8, 0.3, 1.0, 1.0)


func setup(pos: Vector2, color: Color, p_len: float = 240.0, p_clearance: float = 750.0) -> void:
	global_position = pos
	domain_color = color
	fissure_length = p_len
	clearance_radius = p_clearance


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 5
	z_as_relative = false

	_generate_spine_geometry()
	_init_gravity_particles()

	# Sonido ominoso de ruptura espaciotemporal inicial
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("laser_heavy", -1.5, 0.65)

	queue_redraw()


func _generate_spine_geometry() -> void:
	_spine_points.clear()
	var seg_count: int = 12
	var half_len: float = fissure_length * 0.5
	for i in range(seg_count + 1):
		var t := float(i) / float(seg_count)
		var y := lerpf(-half_len, half_len, t)
		# Curvatura y desplazamiento jagged aleatorio determinista
		var lateral := sin(t * PI) * randf_range(-18.0, 18.0)
		_spine_points.append(Vector2(lateral, y))


func _init_gravity_particles() -> void:
	_gravity_particles.clear()
	var count: int = 22
	for i in range(count):
		var ang := randf() * TAU
		var dist := randf_range(50.0, fissure_length * 0.8)
		_gravity_particles.append({
			"pos": Vector2(cos(ang), sin(ang)) * dist,
			"speed": randf_range(110.0, 240.0),
			"size": randf_range(2.0, 4.5),
			"life": randf()
		})


func _process(delta: float) -> void:
	state_timer += delta
	pulse_timer += delta * 10.0
	crackle_timer += delta

	# Actualizar arcos eléctricos espaciotemporales cada 0.06s
	if crackle_timer >= 0.06:
		crackle_timer = 0.0
		_regenerate_lightning_arcs()

	# Actualizar partículas que convergen hacia la fractura
	for i in range(_gravity_particles.size()):
		var p: Dictionary = _gravity_particles[i]
		var dir: Vector2 = -p["pos"].normalized()
		p["pos"] += dir * float(p["speed"]) * delta
		p["life"] += delta
		if p["pos"].length() <= 8.0 or p["life"] >= 1.0:
			var ang := randf() * TAU
			var dist := randf_range(60.0, fissure_length * 0.75)
			p["pos"] = Vector2(cos(ang), sin(ang)) * dist
			p["life"] = 0.0

	match current_state:
		TearState.OPENING:
			var t := clampf(state_timer / open_duration, 0.0, 1.0)
			current_open_ratio = Tween.interpolate_value(0.0, 1.0, t, 1.0, Tween.TRANS_EXPO, Tween.EASE_OUT)
			_update_lip_geometry(current_open_ratio)
			if state_timer >= open_duration:
				current_state = TearState.SHOCKWAVE
				state_timer = 0.0
				tear_opened.emit()
				_detonate_clearance_shockwave()

		TearState.SHOCKWAVE:
			var t := clampf(state_timer / shockwave_duration, 0.0, 1.0)
			current_open_ratio = 1.0 + sin(pulse_timer) * 0.08
			_update_lip_geometry(current_open_ratio)
			shockwave_current_radius = lerpf(fissure_width, clearance_radius, Tween.interpolate_value(0.0, 1.0, t, 1.0, Tween.TRANS_QUAD, Tween.EASE_OUT))
			shockwave_alpha = (1.0 - t) * 0.95
			shockwave_front_width = lerpf(10.0, 2.5, t)

			if state_timer >= shockwave_duration:
				current_state = TearState.ACTIVE
				state_timer = 0.0
				shockwave_alpha = 0.0
				shockwave_completed.emit()

		TearState.ACTIVE:
			current_open_ratio = 1.0 + sin(pulse_timer) * 0.06
			_update_lip_geometry(current_open_ratio)
			if auto_collapse and state_timer >= active_duration:
				start_collapse()

		TearState.COLLAPSING:
			var t := clampf(state_timer / collapse_duration, 0.0, 1.0)
			current_open_ratio = 1.0 - Tween.interpolate_value(0.0, 1.0, t, 1.0, Tween.TRANS_BACK, Tween.EASE_IN)
			_update_lip_geometry(maxf(0.0, current_open_ratio))
			shockwave_current_radius = fissure_length * 0.6 * (1.0 + t * 1.2)
			shockwave_alpha = (1.0 - t) * 0.9
			if state_timer >= collapse_duration:
				current_state = TearState.FINISHED
				tear_collapsed.emit()
				queue_free()
				return

	queue_redraw()


func _update_lip_geometry(ratio: float) -> void:
	_left_lip_points.clear()
	_right_lip_points.clear()
	var count := _spine_points.size()
	if count < 2:
		return

	var max_w := (fissure_width * 0.5) * ratio
	for i in range(count):
		var pt := _spine_points[i]
		var t := float(i) / float(count - 1)
		var w := sin(t * PI) * max_w
		_left_lip_points.append(pt + Vector2(-w, 0.0))
		_right_lip_points.append(pt + Vector2(w, 0.0))


func _regenerate_lightning_arcs() -> void:
	_lightning_arcs.clear()
	if current_open_ratio <= 0.15:
		return

	var count := _left_lip_points.size()
	if count < 4:
		return

	# Generar 3-5 arcos transversales entre los labios de la ruptura
	var arc_count := randi_range(3, 5)
	for a in range(arc_count):
		var idx := randi_range(1, count - 2)
		var p_start := _left_lip_points[idx]
		var p_end := _right_lip_points[idx]
		var mid := (p_start + p_end) * 0.5 + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		var arc := PackedVector2Array([p_start, mid, p_end])
		_lightning_arcs.append(arc)


func _detonate_clearance_shockwave() -> void:
	if _shockwave_has_cleared:
		return
	_shockwave_has_cleared = true

	# Sonido de implosión y choque sónico dimensional
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("bomb_explode", 0.0, 1.2)

	# Partículas radiales de choque fractal
	_shockwave_particles.clear()
	var part_count: int = 30
	for i in range(part_count):
		var ang := randf() * TAU
		var p_dir := Vector2(cos(ang), sin(ang))
		var p_dist := randf_range(clearance_radius * 0.45, clearance_radius)
		var p_sz := randf_range(3.0, 6.0)
		_shockwave_particles.append({
			"dir": p_dir,
			"dist": p_dist,
			"size": p_sz
		})

	# Vaporizar macro-obstáculos en el radio del coloso
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
					n2d.disintegrate(domain_color)
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
		lerpf(domain_color.r, 2.5, 0.7),
		lerpf(domain_color.g, 2.5, 0.7),
		lerpf(domain_color.b, 3.5, 0.7),
		0.0
	)
	tw.tween_property(n2d, "modulate", flash_col, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n2d, "scale", n2d.scale * 1.2, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(n2d.queue_free)



func start_collapse() -> void:
	if current_state == TearState.COLLAPSING or current_state == TearState.FINISHED:
		return
	current_state = TearState.COLLAPSING
	state_timer = 0.0

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("bomb_explode", -2.5, 0.8)


func _draw() -> void:
	if current_state == TearState.FINISHED:
		return

	# 1. Shockwave expansiva poligonal y fragmentada
	if shockwave_alpha > 0.01 and shockwave_current_radius > 0.0:
		var wave_col := domain_color
		wave_col.a = shockwave_alpha * 0.75
		var wave_rim := rim_color
		wave_rim.a = shockwave_alpha

		# Anillo de choque exterior
		draw_arc(Vector2.ZERO, shockwave_current_radius, 0.0, TAU, 36, wave_rim, shockwave_front_width)
		draw_arc(Vector2.ZERO, shockwave_current_radius * 0.88, 0.0, TAU, 28, wave_col, shockwave_front_width * 0.5)

		# Rayos de fractura tangenciales
		var ray_count := 8
		for r in range(ray_count):
			var r_ang := (TAU / float(ray_count)) * float(r) + pulse_timer * 0.2
			var r_start := Vector2(cos(r_ang), sin(r_ang)) * (shockwave_current_radius * 0.7)
			var r_end := Vector2(cos(r_ang), sin(r_ang)) * shockwave_current_radius
			draw_line(r_start, r_end, wave_rim, 2.5)

		# Partículas expansivas
		for sp in _shockwave_particles:
			var p_pos: Vector2 = sp["dir"] * (shockwave_current_radius * (sp["dist"] / clearance_radius))
			var p_col := domain_color
			p_col.a = shockwave_alpha * 0.85
			draw_circle(p_pos, float(sp["size"]), p_col)

	# 2. Partículas gravitacionales convergentes al núcleo
	for gp in _gravity_particles:
		var p_pos: Vector2 = gp["pos"]
		var p_col := domain_color
		p_col.a = (1.0 - float(gp["life"])) * 0.85
		draw_circle(p_pos, float(gp["size"]), p_col)

	# 3. Núcleo Abisal de la Fractura (Polígono cerrado entre labios izquierdo y derecho)
	if _left_lip_points.size() >= 3 and _right_lip_points.size() >= 3 and current_open_ratio > 0.02:
		var poly_pts: PackedVector2Array = PackedVector2Array()
		# Labio izquierdo descendente
		for pt in _left_lip_points:
			poly_pts.append(pt)
		# Labio derecho ascendente (en reverso para cerrar el lazo poligonal)
		for j in range(_right_lip_points.size() - 1, -1, -1):
			poly_pts.append(_right_lip_points[j])

		# Relleno del vacío oscuro dimensional
		var dark_abyss := core_color
		dark_abyss.a = clampf(current_open_ratio, 0.0, 0.96)
		draw_polygon(poly_pts, PackedColorArray([dark_abyss]))

		# Halo resplandeciente exterior
		var glow_col := domain_color
		glow_col.a = clampf(0.55 * current_open_ratio, 0.0, 1.0)
		draw_polyline(_left_lip_points, glow_col, 8.0)
		draw_polyline(_right_lip_points, glow_col, 8.0)

		# Borde afilado del tejido roto
		var lip_col := rim_color
		lip_col.a = clampf(0.9 * current_open_ratio, 0.0, 1.0)
		draw_polyline(_left_lip_points, lip_col, 3.0)
		draw_polyline(_right_lip_points, lip_col, 3.0)

		# Arcos eléctricos que chisporrotean dentro de la fractura
		var arc_col := domain_color.lerp(rim_color, 0.5)
		arc_col.a = 0.95
		for arc in _lightning_arcs:
			if arc.size() >= 2:
				draw_polyline(arc, arc_col, 2.2)

		# Resplandor central en la espina
		draw_circle(Vector2.ZERO, fissure_width * 0.45 * current_open_ratio, domain_color.lerp(Color.WHITE, 0.3))
		draw_circle(Vector2.ZERO, fissure_width * 0.22 * current_open_ratio, Color.WHITE)
