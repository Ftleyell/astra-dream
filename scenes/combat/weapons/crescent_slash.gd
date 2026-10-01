class_name CrescentSlash
extends Node2D

@export var base_reach: float = 165.0
@export var arc_angle_deg: float = 140.0
@export var belly_thickness_ratio: float = 0.30

var hit_context: HitContext
var flurry_count: int = 1
var current_flurry: int = 0
var flurry_interval: float = 0.08
var flurry_timer: float = 0.0
var base_origin: Vector2 = Vector2.ZERO
var base_direction: Vector2 = Vector2.RIGHT
var current_slash_dir: Vector2 = Vector2.RIGHT
var reach: float = 165.0

@onready var slash_blade_poly: Polygon2D = get_node_or_null("SlashBladePoly") as Polygon2D
@onready var slash_blade_core: Polygon2D = get_node_or_null("SlashBladeCorePoly") as Polygon2D
@onready var slash_edge_line: Line2D = get_node_or_null("SlashEdgeLine") as Line2D
@onready var slash_line: Line2D = get_node_or_null("SlashLine") as Line2D

const BLADE_SHADER: Shader = preload("res://core/shaders/dimensional_slash_blade.gdshader")
var impact_vfx_scene: PackedScene = preload("res://scenes/combat/weapons/dimensional_slash_impact_vfx.tscn")

func setup(p_origin: Vector2, p_dir: Vector2, p_ctx: HitContext, p_count: int = 1, p_size_mult: float = 1.0) -> void:
	base_origin = p_origin
	global_position = p_origin
	base_direction = p_dir.normalized()
	if base_direction.length_squared() < 0.001:
		base_direction = Vector2.RIGHT
	current_slash_dir = base_direction
	hit_context = p_ctx
	flurry_count = maxi(1, p_count)
	reach = base_reach * p_size_mult
	rotation = base_direction.angle()
	if is_inside_tree():
		_execute_single_slash()
	else:
		ready.connect(_execute_single_slash, CONNECT_ONE_SHOT)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not slash_blade_poly:
		slash_blade_poly = get_node_or_null("SlashBladePoly") as Polygon2D
	if slash_blade_poly and not slash_blade_poly.material:
		var mat := ShaderMaterial.new()
		mat.shader = BLADE_SHADER
		slash_blade_poly.material = mat

func _process(delta: float) -> void:
	if current_flurry < flurry_count:
		flurry_timer += delta
		if flurry_timer >= flurry_interval:
			flurry_timer = 0.0
			_execute_single_slash()
	else:
		# Tras completar la ráfaga, espera a que el último tajo se disuelva
		flurry_timer += delta
		if flurry_timer >= 0.18:
			queue_free()

func _execute_single_slash() -> void:
	current_flurry += 1

	# Variación angular y avance frontal en cascada según el número de corte
	var angle_tilt := 0.0
	match (current_flurry - 1) % 4:
		0:
			angle_tilt = deg_to_rad(24.0)   # Corte diagonal descendente
		1:
			angle_tilt = deg_to_rad(-24.0)  # Corte diagonal ascendente cruzado en X
		2:
			angle_tilt = deg_to_rad(0.0)    # Estocada/corte central directo
		3:
			angle_tilt = deg_to_rad(32.0)   # Tajo de apertura amplia

	var forward_step := float(current_flurry - 1) * 14.0
	global_position = base_origin + base_direction * forward_step
	current_slash_dir = base_direction.rotated(angle_tilt)
	rotation = current_slash_dir.angle()

	# Audio de corte dimensional con pitch incremental
	if is_inside_tree():
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("dash", 1.5 + float(current_flurry) * 0.12, 1.0)

	_build_crescent_blade_geometry()
	_animate_slash_fade()
	_check_slash_hits()

func _build_crescent_blade_geometry() -> void:
	if not slash_blade_poly:
		slash_blade_poly = get_node_or_null("SlashBladePoly") as Polygon2D
	if not slash_blade_core:
		slash_blade_core = get_node_or_null("SlashBladeCorePoly") as Polygon2D
	if not slash_edge_line:
		slash_edge_line = get_node_or_null("SlashEdgeLine") as Line2D

	var half_arc := deg_to_rad(arc_angle_deg * 0.5)
	var segs := 32

	var outer_pts: PackedVector2Array = []
	var inner_pts: PackedVector2Array = []
	var core_outer_pts: PackedVector2Array = []
	var core_inner_pts: PackedVector2Array = []

	var outer_uvs: PackedVector2Array = []
	var inner_uvs: PackedVector2Array = []
	var core_outer_uvs: PackedVector2Array = []
	var core_inner_uvs: PackedVector2Array = []

	for i in range(segs + 1):
		var u := -1.0 + (float(i) / float(segs)) * 2.0 # de -1.0 a +1.0
		var u_norm := float(i) / float(segs)          # de 0.0 a 1.0 a lo largo del arco
		var ang := u * half_arc

		# Perfil de cuchilla con panza: R_outer tiene curvatura convexa
		var r_outer := reach * (1.0 - 0.24 * u * u)
		# R_inner tiene curvatura cóncava más pronunciada, convergiendo a R_outer en u = ±1
		var belly_factor := (1.0 - u * u)
		var r_inner := reach * (1.0 - belly_thickness_ratio * belly_factor - 0.24 * u * u)

		var dir_vec := Vector2(cos(ang), sin(ang))
		outer_pts.append(dir_vec * r_outer)
		inner_pts.append(dir_vec * r_inner)

		outer_uvs.append(Vector2(u_norm, 1.0))
		inner_uvs.append(Vector2(u_norm, 0.0))

		# Núcleo interior brillante caliente (más estrecho)
		var r_core_out := reach * (1.0 - 0.24 * u * u)
		var r_core_in := reach * (1.0 - (belly_thickness_ratio * 0.40) * belly_factor - 0.24 * u * u)
		core_outer_pts.append(dir_vec * r_core_out)
		core_inner_pts.append(dir_vec * r_core_in)
		core_outer_uvs.append(Vector2(u_norm, 1.0))
		core_inner_uvs.append(Vector2(u_norm, 0.0))

	# El polígono cerrado va por el filo exterior y regresa por el interior
	var full_poly_pts: PackedVector2Array = []
	var full_poly_uvs: PackedVector2Array = []
	full_poly_pts.append_array(outer_pts)
	full_poly_uvs.append_array(outer_uvs)
	for j in range(inner_pts.size() - 1, -1, -1):
		full_poly_pts.append(inner_pts[j])
		full_poly_uvs.append(inner_uvs[j])

	var full_core_pts: PackedVector2Array = []
	var full_core_uvs: PackedVector2Array = []
	full_core_pts.append_array(core_outer_pts)
	full_core_uvs.append_array(core_outer_uvs)
	for j in range(core_inner_pts.size() - 1, -1, -1):
		full_core_pts.append(core_inner_pts[j])
		full_core_uvs.append(core_inner_uvs[j])

	if slash_blade_poly:
		slash_blade_poly.polygon = full_poly_pts
		slash_blade_poly.uv = full_poly_uvs

	if slash_blade_core:
		slash_blade_core.polygon = full_core_pts
		slash_blade_core.uv = full_core_uvs
		slash_blade_core.color = Color(1.0, 0.94, 1.0, 0.9)

	if slash_edge_line:
		slash_edge_line.points = outer_pts
		slash_edge_line.width = 5.0
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.05)) # Punta superior afilada
		curve.add_point(Vector2(0.5, 1.0))  # Filo central máximo
		curve.add_point(Vector2(1.0, 0.05)) # Punta inferior afilada
		slash_edge_line.width_curve = curve
		slash_edge_line.default_color = Color(1.0, 0.95, 1.0, 1.0)

func _animate_slash_fade() -> void:
	scale = Vector2(0.92, 0.92)
	modulate.a = 1.0

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _check_slash_hits() -> void:
	var tree := get_tree()
	if not tree:
		return

	var half_arc := deg_to_rad(arc_angle_deg * 0.5)
	var reach_sq := reach * reach

	var targets: Array[Node] = tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("destructibles")
	for node in targets:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var target := node as Node2D
		var to_target := target.global_position - global_position
		var dist_sq := to_target.length_squared()
		if dist_sq > reach_sq:
			continue

		var angle_to := current_slash_dir.angle_to(to_target)
		if abs(angle_to) <= half_arc:
			if target.has_method("take_damage"):
				var ctx_to_use: HitContext = hit_context
				if not ctx_to_use:
					ctx_to_use = HitContext.new()
					ctx_to_use.final_damage = 48.0
					ctx_to_use.is_crit = false
				target.take_damage(ctx_to_use)

				# Generar Hit VFX de incisión dimensional sobre la entidad impactada
				_spawn_hit_impact_vfx(target.global_position)

func _spawn_hit_impact_vfx(hit_pos: Vector2) -> void:
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
			vfx.setup(hit_pos, current_slash_dir.angle(), Color(1.0, 0.25, 0.95, 1.0), 48.0)
