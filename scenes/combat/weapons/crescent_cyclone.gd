class_name CrescentCyclone
extends Node2D

@export var max_radius: float = 210.0
@export var duration: float = 0.32

var hit_context: HitContext
var current_time: float = 0.0
var damaged_nodes: Array[Node2D] = []

var player: Player = null
var start_angle: float = 0.0
var last_lead_angle: float = 0.0

@onready var blade_ring: Line2D = $BladeRing
@onready var blade_core: Line2D = get_node_or_null("BladeCore") as Line2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not blade_ring:
		blade_ring = get_node_or_null("BladeRing") as Line2D
	if not blade_core:
		blade_core = get_node_or_null("BladeCore") as Line2D

	if blade_ring:
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.02)) # Cola afilada que se pierde
		curve.add_point(Vector2(0.60, 1.0))  # Cuerpo ancho del tajo
		curve.add_point(Vector2(0.92, 0.85))
		curve.add_point(Vector2(1.0, 0.25))  # Punta incisiva del filo
		blade_ring.width_curve = curve
		blade_ring.width = 20.0

	if blade_core:
		var core_curve := Curve.new()
		core_curve.add_point(Vector2(0.0, 0.05))
		core_curve.add_point(Vector2(0.75, 1.0))
		core_curve.add_point(Vector2(1.0, 0.4))
		blade_core.width_curve = core_curve
		blade_core.width = 8.0

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
			audio_mgr.play_sfx("laser", 1.5, 0.0)
	_clear_bullets()

func _process(delta: float) -> void:
	current_time += delta
	var t := clampf(current_time / duration, 0.0, 1.0)

	# Mantener el centro fijado a la nave si el jugador se desplaza
	if is_instance_valid(player):
		global_position = player.global_position

	var current_sweep := t * (TAU + 0.35)
	var lead_angle := start_angle + current_sweep

	# Giro visual de 360° de la nave sobre sí misma siguiendo el filo
	if is_instance_valid(player):
		player.update_omega_spin_rotation(lead_angle)

	_clear_bullets()
	_update_slash_visual(t, current_sweep, lead_angle)
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
		bs.clear_bullets_in_radius(global_position, max_radius + 25.0)

func _update_slash_visual(t: float, current_sweep: float, lead_angle: float) -> void:
	if not blade_ring:
		blade_ring = get_node_or_null("BladeRing") as Line2D
	if not blade_ring:
		return

	# El tajo se dibuja progresivamente: arco de estela de hasta 160° detrás de la punta del filo
	var arc_span := minf(current_sweep, deg_to_rad(165.0))
	var tail_angle := lead_angle - arc_span

	var segs := maxi(6, int(arc_span / deg_to_rad(4.5)))
	var pts := PackedVector2Array()
	for i in range(segs + 1):
		var frac := float(i) / float(segs)
		var a := lerpf(tail_angle, lead_angle, frac)
		# Forma de filo de katana energética con curvatura dinámica
		var r := max_radius * (0.93 + 0.07 * sin(frac * PI))
		pts.append(Vector2(cos(a), sin(a)) * r)

	blade_ring.points = pts

	# Desvanecimiento al completar el giro
	var alpha := 1.0 if t < 0.70 else (1.0 - (t - 0.70) / 0.30)
	blade_ring.default_color = Color(0.95, 0.28, 1.0, alpha)

	# Filo central resplandeciente blanco-rosado de alta energía
	if blade_core:
		var core_pts := PackedVector2Array()
		var core_segs := maxi(4, int(segs * 0.50))
		var core_tail := lead_angle - arc_span * 0.50
		for i in range(core_segs + 1):
			var frac := float(i) / float(core_segs)
			var a := lerpf(core_tail, lead_angle, frac)
			var r := max_radius * (0.93 + 0.07 * sin((0.5 + frac * 0.5) * PI))
			core_pts.append(Vector2(cos(a), sin(a)) * r)
		blade_core.points = core_pts
		blade_core.default_color = Color(1.0, 0.92, 1.0, alpha * 0.95)

func _check_hits(from_angle: float, to_angle: float) -> void:
	var tree := get_tree()
	if not tree:
		return

	var r_sq := (max_radius + 15.0) * (max_radius + 15.0)
	var targets: Array[Node] = tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("destructibles")
	for node in targets:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var target := node as Node2D
		if damaged_nodes.has(target):
			continue

		var diff := target.global_position - global_position
		if diff.length_squared() <= r_sq:
			# Si el objetivo está muy cerca (< 65px), cortarlo siempre
			if diff.length_squared() <= 65.0 * 65.0:
				_damage_target(target)
				continue

			# Verificar si el objetivo cae dentro del arco recorrido en este intervalo
			var ang := diff.angle()
			var d_from := fposmod(ang - from_angle, TAU)
			var d_span := fposmod(to_angle - from_angle, TAU)
			if d_span < 0.001:
				d_span = TAU
			# Margen angular de tolerancia para no perder impactos
			if d_from <= d_span + 0.35:
				_damage_target(target)

func _damage_target(target: Node2D) -> void:
	damaged_nodes.append(target)
	if target.has_method("take_damage"):
		var c := hit_context
		if not c:
			c = HitContext.new()
			c.final_damage = 55.0
		target.take_damage(c)
		if c.attacker and "inventory" in c.attacker and c.attacker.inventory:
			c.attacker.inventory.process_hit_procs(c, c.attacker)
