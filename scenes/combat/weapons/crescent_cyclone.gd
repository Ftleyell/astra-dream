class_name CrescentCyclone
extends Node2D

@export var max_radius: float = 220.0
@export var duration: float = 0.36

var hit_context: HitContext
var current_time: float = 0.0
var damaged_nodes: Array[Node2D] = []

var player: Player = null
var start_angle: float = 0.0
var last_lead_angle: float = 0.0

@onready var vortex_core: Polygon2D = get_node_or_null("VortexCore") as Polygon2D
@onready var blade_poly1: Polygon2D = get_node_or_null("BladePoly1") as Polygon2D
@onready var blade_core_poly1: Polygon2D = get_node_or_null("BladeCorePoly1") as Polygon2D
@onready var blade_edge1: Line2D = get_node_or_null("BladeEdge1") as Line2D

@onready var blade_poly2: Polygon2D = get_node_or_null("BladePoly2") as Polygon2D
@onready var blade_core_poly2: Polygon2D = get_node_or_null("BladeCorePoly2") as Polygon2D
@onready var blade_edge2: Line2D = get_node_or_null("BladeEdge2") as Line2D

@onready var expansion_shockwave: Line2D = get_node_or_null("ExpansionShockwave") as Line2D
@onready var blade_ring: Line2D = get_node_or_null("BladeRing") as Line2D
@onready var blade_core: Line2D = get_node_or_null("BladeCore") as Line2D

var impact_vfx_scene: PackedScene = preload("res://scenes/combat/weapons/dimensional_slash_impact_vfx.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_init_edge_curves()

func _init_edge_curves() -> void:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.05)) # Cola afilada
	curve.add_point(Vector2(0.65, 1.0))  # Vientre de corte
	curve.add_point(Vector2(1.0, 0.15))  # Punta incisiva líder

	if blade_edge1:
		blade_edge1.width_curve = curve
		blade_edge1.width = 5.0
	if blade_edge2:
		blade_edge2.width_curve = curve
		blade_edge2.width = 5.0

func setup(p_origin: Vector2, p_ctx: HitContext, p_size_mult: float = 1.0, p_player: Player = null) -> void:
	global_position = p_origin
	hit_context = p_ctx
	max_radius *= p_size_mult

	if p_player:
		player = p_player
	elif p_ctx and p_ctx.attacker is Player:
		player = p_ctx.attacker as Player
	elif is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player

	if is_instance_valid(player):
		player.is_omega_spinning = true
		var mouse_pos := player.get_global_mouse_position()
		start_angle = (mouse_pos - player.global_position).angle()
		last_lead_angle = start_angle
		player.update_omega_spin_rotation(start_angle)
	else:
		start_angle = 0.0
		last_lead_angle = 0.0

	if is_inside_tree():
		_start_cyclone()
	else:
		ready.connect(_start_cyclone, CONNECT_ONE_SHOT)

func _start_cyclone() -> void:
	if is_inside_tree():
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("dash", 1.8, 3.0)
			audio_mgr.play_sfx("laser", 1.6, 0.0)
	_clear_bullets()

func _process(delta: float) -> void:
	current_time += delta
	var t := clampf(current_time / duration, 0.0, 1.0)

	# Mantener fijado al centro de la nave si se mueve
	if is_instance_valid(player):
		global_position = player.global_position

	var current_sweep := t * (TAU + 0.45)
	var lead_angle := start_angle + current_sweep

	# Giro visual de 360° de la nave sobre sí misma siguiendo el filo
	if is_instance_valid(player):
		player.update_omega_spin_rotation(lead_angle)

	_clear_bullets()
	_update_twin_spiral_blades(t, lead_angle)
	_check_hits(last_lead_angle, lead_angle)
	last_lead_angle = lead_angle

	if t >= 1.0:
		_finish_and_free()

func _finish_and_free() -> void:
	if is_instance_valid(player) and "is_omega_spinning" in player:
		player.is_omega_spinning = false
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(player) and "is_omega_spinning" in player:
		player.is_omega_spinning = false

func _clear_bullets() -> void:
	var tree := get_tree()
	if not tree:
		return
	var bs = tree.get_first_node_in_group("bullet_server")
	if bs and bs.has_method("clear_bullets_in_radius"):
		bs.clear_bullets_in_radius(global_position, max_radius + 30.0)

func _update_twin_spiral_blades(t: float, lead_angle: float) -> void:
	# 1. Radio dinámico centrífugo (espiral expansiva)
	var spiral_factor := ease(t, 0.65)
	var cur_radius := lerpf(max_radius * 0.55, max_radius * 1.05, spiral_factor)

	# Desvanecimiento en el último 25% del giro
	var alpha := 1.0 if t < 0.75 else (1.0 - (t - 0.75) / 0.25)

	# 2. Vórtice central oscuro / dimensional
	_update_vortex_core(t, cur_radius * 0.45, alpha)

	# 3. Dos hojas opuestas a 180°
	var arc_span := deg_to_rad(115.0) # arco que barre cada cuchilla
	_build_blade_mesh(blade_poly1, blade_core_poly1, blade_edge1, lead_angle, arc_span, cur_radius, alpha)
	_build_blade_mesh(blade_poly2, blade_core_poly2, blade_edge2, lead_angle + PI, arc_span, cur_radius, alpha)

	# 4. Onda expansiva final cortante en los últimos compases
	_update_final_shockwave(t, alpha)

func _build_blade_mesh(
	poly: Polygon2D,
	core_poly: Polygon2D,
	edge_line: Line2D,
	angle_lead: float,
	arc_span: float,
	cur_r: float,
	alpha: float
) -> void:
	var segs := 24
	var tail_angle := angle_lead - arc_span

	var outer_pts: PackedVector2Array = []
	var inner_pts: PackedVector2Array = []
	var core_outer: PackedVector2Array = []
	var core_inner: PackedVector2Array = []

	var outer_uvs: PackedVector2Array = []
	var inner_uvs: PackedVector2Array = []
	var core_outer_uvs: PackedVector2Array = []
	var core_inner_uvs: PackedVector2Array = []

	var belly_max := cur_r * 0.28 # Espesor de la panza

	for i in range(segs + 1):
		var frac := float(i) / float(segs) # 0.0 (cola) a 1.0 (punta)
		var a := lerpf(tail_angle, angle_lead, frac)

		# Filo exterior: radio que crece suavemente hacia la punta
		var r_out := cur_r * (0.84 + 0.16 * frac)

		# Vientre (panza) con pico curvado en el centro del tajo
		var belly := sin(frac * PI)
		var r_in := r_out - belly_max * belly

		var dir := Vector2(cos(a), sin(a))
		outer_pts.append(dir * r_out)
		inner_pts.append(dir * r_in)

		outer_uvs.append(Vector2(frac, 1.0))
		inner_uvs.append(Vector2(frac, 0.0))

		# Núcleo interior brillante
		var r_core_in := r_out - (belly_max * 0.42) * belly
		core_outer.append(dir * r_out)
		core_inner.append(dir * r_core_in)
		core_outer_uvs.append(Vector2(frac, 1.0))
		core_inner_uvs.append(Vector2(frac, 0.0))

	# Crear polígonos cerrados
	var blade_pts: PackedVector2Array = []
	var blade_uvs: PackedVector2Array = []
	blade_pts.append_array(outer_pts)
	blade_uvs.append_array(outer_uvs)
	for j in range(inner_pts.size() - 1, -1, -1):
		blade_pts.append(inner_pts[j])
		blade_uvs.append(inner_uvs[j])

	var blade_core_pts: PackedVector2Array = []
	var blade_core_uvs: PackedVector2Array = []
	blade_core_pts.append_array(core_outer)
	blade_core_uvs.append_array(core_outer_uvs)
	for j in range(core_inner.size() - 1, -1, -1):
		blade_core_pts.append(core_inner[j])
		blade_core_uvs.append(core_inner_uvs[j])

	if poly:
		poly.polygon = blade_pts
		poly.uv = blade_uvs
		if not poly.material:
			var blade_shader := load("res://core/shaders/dimensional_slash_blade.gdshader") as Shader
			if blade_shader:
				var mat := ShaderMaterial.new()
				mat.shader = blade_shader
				poly.material = mat

	if core_poly:
		core_poly.polygon = blade_core_pts
		core_poly.uv = blade_core_uvs
		core_poly.color = Color(1.0, 0.94, 1.0, alpha * 0.95)

	if edge_line:
		edge_line.points = outer_pts
		edge_line.default_color = Color(1.0, 0.96, 1.0, alpha)

func _update_vortex_core(t: float, r: float, alpha: float) -> void:
	if not vortex_core:
		return
	var segs := 24
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in range(segs):
		var a := float(i) / float(segs) * TAU
		var p := Vector2(cos(a), sin(a))
		pts.append(p * r)
		uvs.append(p * 0.5 + Vector2(0.5, 0.5))
	vortex_core.polygon = pts
	vortex_core.uv = uvs
	if not vortex_core.material:
		var vortex_shader := load("res://core/shaders/dimensional_vortex_core.gdshader") as Shader
		if vortex_shader:
			var mat := ShaderMaterial.new()
			mat.shader = vortex_shader
			vortex_core.material = mat

func _update_final_shockwave(t: float, alpha: float) -> void:
	if not expansion_shockwave:
		return
	if t >= 0.78:
		expansion_shockwave.visible = true
		var wave_t := (t - 0.78) / 0.22
		var wave_r := lerpf(max_radius * 0.85, max_radius * 1.35, wave_t)
		var wave_alpha := (1.0 - wave_t) * alpha

		var segs := 32
		var pts := PackedVector2Array()
		for i in range(segs + 1):
			var a := float(i) / float(segs) * TAU
			pts.append(Vector2(cos(a), sin(a)) * wave_r)
		expansion_shockwave.points = pts
		expansion_shockwave.width = lerpf(8.0, 1.5, wave_t)
		expansion_shockwave.default_color = Color(1.0, 0.35, 0.95, wave_alpha)
	else:
		expansion_shockwave.visible = false

func _check_hits(from_angle: float, to_angle: float) -> void:
	var tree := get_tree()
	if not tree:
		return

	var r_sq := (max_radius + 20.0) * (max_radius + 20.0)
	var targets: Array[Node] = tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("destructibles")
	for node in targets:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var target := node as Node2D
		if damaged_nodes.has(target):
			continue

		var diff := target.global_position - global_position
		if diff.length_squared() <= r_sq:
			# Si el objetivo está en radio interior (< 80px), golpe directo
			if diff.length_squared() <= 80.0 * 80.0:
				_damage_target(target, diff.angle())
				continue

			# Verificar si alguna de las dos cuchillas opuestas barre sobre el objetivo
			var ang := diff.angle()
			var d_from1 := fposmod(ang - from_angle, TAU)
			var d_from2 := fposmod(ang - (from_angle + PI), TAU)
			var d_span := fposmod(to_angle - from_angle, TAU)
			if d_span < 0.001:
				d_span = TAU

			if d_from1 <= d_span + 0.40 or d_from2 <= d_span + 0.40:
				_damage_target(target, ang)

func _damage_target(target: Node2D, hit_angle: float) -> void:
	damaged_nodes.append(target)
	if target.has_method("take_damage"):
		var c := hit_context
		if not c:
			c = HitContext.new()
			c.final_damage = 55.0
		target.take_damage(c)
		if c.attacker and "inventory" in c.attacker and c.attacker.inventory:
			c.attacker.inventory.process_hit_procs(c, c.attacker)

		# Generar Hit VFX de incisión dimensional
		_spawn_hit_impact_vfx(target.global_position, hit_angle)

func _spawn_hit_impact_vfx(hit_pos: Vector2, angle: float) -> void:
	if not impact_vfx_scene:
		return
	var vfx := impact_vfx_scene.instantiate() as Node2D
	if not vfx:
		return
	var spawn_parent: Node = get_parent()
	if not spawn_parent or not spawn_parent.is_inside_tree():
		spawn_parent = get_tree().current_scene
	if spawn_parent:
		spawn_parent.add_child(vfx)
		if vfx.has_method("setup"):
			vfx.setup(hit_pos, angle + deg_to_rad(90.0), Color(1.0, 0.25, 0.95, 1.0), 54.0)
