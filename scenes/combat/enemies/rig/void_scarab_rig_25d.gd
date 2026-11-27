class_name VoidScarabRig25D
extends Node2D

## Articulated 7-piece AAA 2.5D Biomech "Void Scarab" rig (Sandbox Enemy Workbench).
## Parts: body_core + scissor mandible_l/r + inner_wing_l/r + elytron_l/r.
## Features 2.5D shell thickness extrusion, internal reactor crystal point light,
## constant 3D flight attitude & inter-layer parallax, scissor-bite snap + HDR crunch VFX,
## and world-space wingtip flight ribbons.

const EnemyShader = preload("res://scenes/combat/enemies/shaders/enemy_stylized_25d.gdshader")
const RigConfigScript = preload("res://data/enemies/schemas/enemy_scarab_rig_config.gd")
const FactionStyleScript = preload("res://data/enemies/schemas/enemy_faction_style.gd")
const DefaultStyleRes = preload("res://data/enemies/void_scarab/style_biomech_void.tres")
const DefaultConfigRes = preload("res://data/enemies/void_scarab/void_scarab_config.tres")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")

static var _texture_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}


static func get_cached_texture_count() -> int:
	return _texture_cache.size()


static func get_cached_mesh_count() -> int:
	return _mesh_cache.size()

enum AnimState {
	IDLE_HOVER = 0,
	CRUISE_BANK = 1,
	CHARGE_TELEGRAPH = 2,
	ATTACK_LUNGE = 3,
	DEATH_SHATTER = 4,
}

const STATE_LABELS: Array[String] = [
	"1 · Idle Alive",
	"2 · Cruise & Bank",
	"3 · Telegraph (Open-V)",
	"4 · Predator Lunge",
	"5 · Death Shatter",
]


class _BiteCrunchVFX extends Node2D:
	var age: float = 1.0
	var duration: float = 0.24
	var sparks: Array[Dictionary] = []

	func _ready() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
		visible = false

	func trigger() -> void:
		age = 0.0
		visible = true
		sparks.clear()
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i: int in range(12):
			var ang: float = rng.randf_range(-PI, PI)
			var spd: float = rng.randf_range(260.0, 620.0)
			sparks.append({
				"vel": Vector2(cos(ang), sin(ang)) * spd,
				"len": rng.randf_range(16.0, 38.0),
				"col": Color(0.75, 1.8, 0.95, 1.0) if (i % 3 == 0) else Color(0.28, 1.6, 0.62, 1.0),
			})
		queue_redraw()

	func is_active() -> bool:
		return age < duration

	func step_vfx(delta: float) -> void:
		if age >= duration:
			if visible:
				visible = false
			return
		age += delta
		if age >= duration:
			visible = false
			return
		queue_redraw()

	func _draw() -> void:
		if age >= duration:
			return
		var t: float = clampf(age / duration, 0.0, 1.0)
		var inv: float = 1.0 - t
		var rad: float = lerpf(16.0, 88.0, sqrt(t))
		# Twin scissor slash crescents
		draw_arc(Vector2(-10.0, 0.0), rad, -0.95, 0.95, 20, Color(0.42, 1.75, 0.72, inv * 0.95), 7.5 * inv + 1.5)
		draw_arc(Vector2(10.0, 0.0), rad, PI - 0.95, PI + 0.95, 20, Color(0.75, 1.9, 1.0, inv * 0.95), 7.5 * inv + 1.5)
		draw_circle(Vector2.ZERO, lerpf(28.0, 6.0, t), Color(0.85, 2.0, 1.0, inv * 0.65))
		for sp: Dictionary in sparks:
			var vel: Vector2 = sp["vel"] as Vector2
			var p1: Vector2 = vel * age * 0.62
			var dir: Vector2 = vel.normalized()
			var p0: Vector2 = p1 - dir * float(sp["len"]) * inv
			var col: Color = sp["col"] as Color
			col.a = inv
			draw_line(p0, p1, col, 3.0 * inv + 0.8)


class _WingBuzzArcsVFX extends Node2D:
	var _cur_alpha: float = 0.0
	var _strobe_phase: float = 0.0
	var _l_hinge: Vector2 = Vector2.ZERO
	var _r_hinge: Vector2 = Vector2.ZERO
	var _l_rot: float = 0.0
	var _r_rot: float = 0.0
	var _wing_scale: float = 1.0
	var _sweep_rad: float = 0.35

	func _ready() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
		visible = false

	func update_arcs(
		speed_ramp: float,
		strength: float,
		state_boost: float,
		strobe_phase: float,
		l_hinge: Vector2,
		r_hinge: Vector2,
		l_rot: float,
		r_rot: float,
		wing_scale_val: float,
		sweep_rad: float,
		active: bool
	) -> void:
		_cur_alpha = clampf((speed_ramp - 0.20) / 0.80, 0.0, 1.0) * strength * state_boost if active else 0.0
		if _cur_alpha <= 0.02:
			if visible:
				visible = false
			return
		visible = true
		_strobe_phase = strobe_phase
		_l_hinge = l_hinge
		_r_hinge = r_hinge
		_l_rot = l_rot
		_r_rot = r_rot
		_wing_scale = wing_scale_val
		_sweep_rad = maxf(sweep_rad, 0.14)
		queue_redraw()

	func is_arcs_visible() -> bool:
		return visible and _cur_alpha > 0.02

	func _draw() -> void:
		if _cur_alpha <= 0.02:
			return
		var r_base_ang: float = 0.765 + _r_rot
		var l_base_ang: float = (PI - 0.765) + _l_rot
		var radii: Array[float] = [182.0, 194.0, 206.0]
		var widths: Array[float] = [2.2, 1.6, 1.1]
		var spans: Array[float] = [0.27, 0.23, 0.18]
		for side: int in range(2):
			var center_pt: Vector2 = _r_hinge if side == 0 else _l_hinge
			var base_ang: float = r_base_ang if side == 0 else l_base_ang
			for i: int in range(3):
				var fi: float = float(i)
				var fside: float = float(side)
				var osc: float = sin(_strobe_phase * (1.30 + fi * 0.45) + fside * 2.1 + fi * 1.4)
				var flick: float = 0.42 + 0.58 * clampf(0.5 + 0.5 * sin(_strobe_phase * (1.85 + fi * 0.6) + fi * 2.3), 0.0, 1.0)
				var arc_a: float = clampf(_cur_alpha * flick * (0.48 - fi * 0.10), 0.0, 0.58)
				if arc_a <= 0.015:
					continue
				var ang_mid: float = base_ang + osc * (_sweep_rad * 0.85)
				var half_span: float = spans[i]
				var rad: float = radii[i] * _wing_scale
				var col: Color = Color(0.72, 1.30, 1.0, arc_a) if i == 0 else Color(0.38, 1.45, 0.82, arc_a * 0.78)
				draw_arc(center_pt, rad, ang_mid - half_span, ang_mid + half_span, 14, col, widths[i], true)


class _PivotGizmoOverlay extends Node2D:
	var _ely_l: Vector2 = Vector2.ZERO
	var _ely_r: Vector2 = Vector2.ZERO
	var _wing_l: Vector2 = Vector2.ZERO
	var _wing_r: Vector2 = Vector2.ZERO

	func _ready() -> void:
		visible = false

	func update_pivots(ely_l: Vector2, ely_r: Vector2, wing_l: Vector2, wing_r: Vector2, show_pivots: bool) -> void:
		visible = show_pivots
		if not show_pivots:
			return
		_ely_l = ely_l
		_ely_r = ely_r
		_wing_l = wing_l
		_wing_r = wing_r
		queue_redraw()

	func _draw() -> void:
		var mag := Color(1.0, 0.35, 0.95, 0.95)
		var cya := Color(0.25, 0.95, 1.0, 0.95)
		for pt: Vector2 in [_ely_l, _ely_r]:
			draw_line(pt + Vector2(-10.0, 0.0), pt + Vector2(10.0, 0.0), mag, 1.6, true)
			draw_line(pt + Vector2(0.0, -10.0), pt + Vector2(0.0, 10.0), mag, 1.6, true)
			draw_arc(pt, 4.0, 0.0, TAU, 16, mag, 1.4, true)
		for pt: Vector2 in [_wing_l, _wing_r]:
			draw_line(pt + Vector2(-8.0, 0.0), pt + Vector2(8.0, 0.0), cya, 1.5, true)
			draw_line(pt + Vector2(0.0, -8.0), pt + Vector2(0.0, 8.0), cya, 1.5, true)
			draw_arc(pt, 3.5, 0.0, TAU, 16, cya, 1.3, true)


@export var rig_config: RigConfigScript = null
@export var style_profile: FactionStyleScript = null
@export var combat_lite_mode: bool = false
@export var enable_combat_ribbons: bool = false

var _visual_root: Node2D = null
var _art_up_root: Node2D = null

var _under_shadow_mesh: MeshInstance2D = null
var _under_shadow_mat: ShaderMaterial = null

var _mandible_l_shadow_pivot: Node2D = null
var _mandible_r_shadow_pivot: Node2D = null
var _mandible_l_shadow_mesh: MeshInstance2D = null
var _mandible_r_shadow_mesh: MeshInstance2D = null
var _mandible_shadow_mats: Array[ShaderMaterial] = []

var _mandible_l_pivot: Node2D = null
var _mandible_r_pivot: Node2D = null
var _mandible_l_shatter: Node2D = null
var _mandible_r_shatter: Node2D = null
var _mandible_l_mesh: MeshInstance2D = null
var _mandible_r_mesh: MeshInstance2D = null

var _body_shatter: Node2D = null
var _body_shell_meshes: Array[MeshInstance2D] = []
var _body_shell_mats: Array[ShaderMaterial] = []
var _body_mesh: MeshInstance2D = null

var _wing_l_pivot: Node2D = null
var _wing_r_pivot: Node2D = null
var _wing_l_shatter: Node2D = null
var _wing_r_shatter: Node2D = null
var _wing_l_mesh: MeshInstance2D = null
var _wing_r_mesh: MeshInstance2D = null
var _wing_l_ghost_a_pivot: Node2D = null
var _wing_l_ghost_b_pivot: Node2D = null
var _wing_l_ghost_a: MeshInstance2D = null
var _wing_l_ghost_b: MeshInstance2D = null
var _wing_r_ghost_a_pivot: Node2D = null
var _wing_r_ghost_b_pivot: Node2D = null
var _wing_r_ghost_a: MeshInstance2D = null
var _wing_r_ghost_b: MeshInstance2D = null
var _wing_buzz_vfx: _WingBuzzArcsVFX = null

var _ely_l_shadow_pivot: Node2D = null
var _ely_r_shadow_pivot: Node2D = null
var _ely_l_shadow_mesh: MeshInstance2D = null
var _ely_r_shadow_mesh: MeshInstance2D = null
var _ely_shadow_mats: Array[ShaderMaterial] = []

var _elytron_l_pivot: Node2D = null
var _elytron_r_pivot: Node2D = null
var _elytron_l_shatter: Node2D = null
var _elytron_r_shatter: Node2D = null
var _elytron_l_shells: Array[MeshInstance2D] = []
var _elytron_r_shells: Array[MeshInstance2D] = []
var _elytron_shell_mats: Array[ShaderMaterial] = []
var _elytron_l_mesh: MeshInstance2D = null
var _elytron_r_mesh: MeshInstance2D = null
var _elytron_l_inner_mesh: MeshInstance2D = null
var _elytron_r_inner_mesh: MeshInstance2D = null
var _elytron_inner_mats: Array[ShaderMaterial] = []

var _thruster_particles: CPUParticles2D = null
var _core_glow_poly: Polygon2D = null
var _pivot_gizmo: _PivotGizmoOverlay = null
var _show_pivots: bool = false
var _bite_vfx: _BiteCrunchVFX = null
var _ribbon_l: Line2D = null
var _ribbon_r: Line2D = null
var _ribbon_l_tip: Marker2D = null
var _ribbon_r_tip: Marker2D = null
var _ribbon_pts_l: PackedVector2Array = PackedVector2Array()
var _ribbon_pts_r: PackedVector2Array = PackedVector2Array()

var _part_meshes: Array[MeshInstance2D] = []
var _part_mats: Array[ShaderMaterial] = []
var _shell_meshes: Array[MeshInstance2D] = []
var _shell_mats: Array[ShaderMaterial] = []
var _ghost_mats: Array[ShaderMaterial] = []
var _shatter_nodes: Array[Node2D] = []

var _state: int = AnimState.IDLE_HOVER
var _time: float = 0.0
var _idle_flare_timer: float = 2.4
var _idle_flare_pulse: float = 0.0

var _ely_open_blend: float = 0.0
var _ely_open_vel: float = 0.0
var _wing_open_blend: float = 0.0
var _wing_open_vel: float = 0.0
var _wing_vis_alpha: float = 0.0
var _wing_flap_phase: float = 0.0
var _wing_speed_ramp: float = 0.0
var _wing_strobe_phase: float = 0.0
var _wing_blur_arc_rad_cur: float = 0.0
var _ely_pitch_rad_cur: float = 0.0
var _ely_roll_rad_cur: float = 0.0
var _mandible_deg_cur: float = 0.0
var _mandible_deg_vel: float = 0.0

var _bite_phase: int = 0 # 0=none, 1=windup, 2=snap
var _bite_timer: float = 0.0
var _bite_hitstop: float = 0.0

var _tilt_input: Vector2 = Vector2.ZERO
var _tilt_smoothed: Vector2 = Vector2.ZERO
var _tail_whip_smoothed: float = 0.0
var _leg_tuck_smoothed: float = 0.0
var _sec_emissive: float = 0.45
var _alert_mix: float = 0.0
var _hit_flash_val: float = 0.0
var _floor_shadow_enabled: bool = false
var _recoil_offset: Vector2 = Vector2.ZERO
var _dissolve_val: float = 0.0
var _lunge_timer: float = 0.0
var _debug_view_mode: int = 0
var _variant_index: int = -1
var _has_custom_palette: bool = false
var _custom_use_recolor: bool = false
var _custom_armor_tint: Color = Color(0.22, 0.22, 0.36, 1.0)
var _custom_accent_tint: Color = Color(0.68, 0.24, 0.96, 1.0)
var _custom_energy_tint: Color = Color(0.22, 1.0, 0.56, 1.0)
var _flat_baseline: bool = false
var _zoom_scale: float = 2.15

var _cur_light_dir_2d: Vector2 = Vector2(-0.55, -0.78)
var _cur_light_z: float = 0.58

var _shatter_vels: Array[Vector2] = []
var _shatter_ang_vels: Array[float] = []
var _shatter_elapsed: float = 0.0


func _ready() -> void:
	if rig_config == null:
		rig_config = DefaultConfigRes.duplicate() as RigConfigScript
	if style_profile == null:
		style_profile = DefaultStyleRes
	_build_hierarchy()
	apply_rig_calibration()
	apply_style_profile(style_profile)


static func _build_subdivided_quad_mesh(tex_size: Vector2, cols: int, rows: int) -> ArrayMesh:
	var c_count: int = maxi(cols, 2)
	var r_count: int = maxi(rows, 2)
	var cache_key: String = "%dx%d|%dx%d" % [int(tex_size.x), int(tex_size.y), c_count, r_count]
	if _mesh_cache.has(cache_key) and _mesh_cache[cache_key] != null:
		return _mesh_cache[cache_key] as ArrayMesh

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: Vector2 = tex_size * 0.5

	for iy: int in range(r_count + 1):
		var v: float = float(iy) / float(r_count)
		var py: float = lerpf(-half.y, half.y, v)
		for ix: int in range(c_count + 1):
			var u: float = float(ix) / float(c_count)
			var px: float = lerpf(-half.x, half.x, u)
			st.set_uv(Vector2(u, v))
			st.set_color(Color.WHITE)
			st.add_vertex(Vector3(px, py, 0.0))

	var stride: int = c_count + 1
	for iy: int in range(r_count):
		for ix: int in range(c_count):
			var i00: int = iy * stride + ix
			var i10: int = i00 + 1
			var i01: int = i00 + stride
			var i11: int = i01 + 1
			st.add_index(i00)
			st.add_index(i10)
			st.add_index(i11)
			st.add_index(i00)
			st.add_index(i11)
			st.add_index(i01)

	var mesh_res: ArrayMesh = st.commit()
	_mesh_cache[cache_key] = mesh_res
	return mesh_res


func _load_png_tex(res_path: String, use_mipmaps: bool) -> Texture2D:
	var cache_key: String = "%s|%d" % [res_path, int(use_mipmaps)]
	if _texture_cache.has(cache_key) and _texture_cache[cache_key] != null:
		return _texture_cache[cache_key] as Texture2D

	var abs_path: String = ProjectSettings.globalize_path(res_path)
	var img: Image = null
	if FileAccess.file_exists(abs_path):
		img = Image.load_from_file(abs_path)
	elif ResourceLoader.exists(res_path):
		var loaded: Resource = ResourceLoader.load(res_path)
		if loaded is Texture2D:
			img = (loaded as Texture2D).get_image()
	if img == null or img.is_empty():
		return null
	if use_mipmaps:
		img.generate_mipmaps()
	else:
		img.clear_mipmaps()
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_texture_cache[cache_key] = tex
	return tex


func _build_hierarchy() -> void:
	_visual_root = Node2D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	_art_up_root = Node2D.new()
	_art_up_root.name = "ArtUpRoot"
	_art_up_root.rotation = PI * 0.5
	_visual_root.add_child(_art_up_root)

	# World-space flight ribbons (top-level so points stay in world space)
	if not combat_lite_mode or enable_combat_ribbons:
		_ribbon_l = _create_flight_ribbon("FlightRibbonL")
		_ribbon_r = _create_flight_ribbon("FlightRibbonR")
		add_child(_ribbon_l)
		add_child(_ribbon_r)

	var b_div: int = 10 if combat_lite_mode else 16
	var m_div: int = 6 if combat_lite_mode else 10
	var w_div: int = 8 if combat_lite_mode else 12
	var e_div: int = 16 if combat_lite_mode else 28

	# 1. Under-floor directional ambient shadow (disabled in Cosmic outer space & skipped in combat_lite_mode)
	if not combat_lite_mode:
		var floor_pair: Dictionary = _create_part_mesh("UnderFloorShadow", "body_core", 12, 12, true, false, false, true, false, 0.0)
		_under_shadow_mesh = floor_pair["mesh"] as MeshInstance2D
		_under_shadow_mat = floor_pair["mat"] as ShaderMaterial
		_under_shadow_mesh.visible = _floor_shadow_enabled
		_art_up_root.add_child(_under_shadow_mesh)

		# 2. Rear tail thruster embers
		_thruster_particles = _create_thruster_particles()
		_art_up_root.add_child(_thruster_particles)

		# 3. Articulated Mandible cast shadows (disabled in vacuum so jaws never leave ghost silhouettes)
		_mandible_l_shadow_pivot = Node2D.new()
		_mandible_l_shadow_pivot.name = "MandibleLShadowPivot"
		_mandible_l_shadow_pivot.visible = false
		_art_up_root.add_child(_mandible_l_shadow_pivot)
		var mls_pair: Dictionary = _create_part_mesh("MandibleLShadow", "mandible_l", 8, 8, false, false, false, true, false, 0.0)
		_mandible_l_shadow_mesh = mls_pair["mesh"] as MeshInstance2D
		_mandible_l_shadow_pivot.add_child(_mandible_l_shadow_mesh)

		_mandible_r_shadow_pivot = Node2D.new()
		_mandible_r_shadow_pivot.name = "MandibleRShadowPivot"
		_mandible_r_shadow_pivot.visible = false
		_art_up_root.add_child(_mandible_r_shadow_pivot)
		var mrs_pair: Dictionary = _create_part_mesh("MandibleRShadow", "mandible_r", 8, 8, false, false, false, true, false, 0.0)
		_mandible_r_shadow_mesh = mrs_pair["mesh"] as MeshInstance2D
		_mandible_r_shadow_pivot.add_child(_mandible_r_shadow_mesh)
		_mandible_shadow_mats = [mls_pair["mat"] as ShaderMaterial, mrs_pair["mat"] as ShaderMaterial]

	# 4. Scissor Mandibles (behind head cheek; Right drawn after Left so R crosses OVER L cleanly)
	_mandible_l_pivot = Node2D.new()
	_mandible_l_pivot.name = "MandibleLPivot"
	_art_up_root.add_child(_mandible_l_pivot)
	_mandible_l_shatter = Node2D.new()
	_mandible_l_shatter.name = "MandibleLShatter"
	_mandible_l_pivot.add_child(_mandible_l_shatter)
	var ml_pair: Dictionary = _create_part_mesh("MandibleLMesh", "mandible_l", m_div, m_div, false, false, false, false, false, 0.0)
	_mandible_l_mesh = ml_pair["mesh"] as MeshInstance2D
	_mandible_l_shatter.add_child(_mandible_l_mesh)

	_mandible_r_pivot = Node2D.new()
	_mandible_r_pivot.name = "MandibleRPivot"
	_art_up_root.add_child(_mandible_r_pivot)
	_mandible_r_shatter = Node2D.new()
	_mandible_r_shatter.name = "MandibleRShatter"
	_mandible_r_pivot.add_child(_mandible_r_shatter)
	var mr_pair: Dictionary = _create_part_mesh("MandibleRMesh", "mandible_r", m_div, m_div, false, false, false, false, false, 0.0)
	_mandible_r_mesh = mr_pair["mesh"] as MeshInstance2D
	_mandible_r_shatter.add_child(_mandible_r_mesh)

	# 5. Body core + optional 3 stacked 2.5D extrusion thickness shells
	_body_shatter = Node2D.new()
	_body_shatter.name = "BodyShatter"
	_art_up_root.add_child(_body_shatter)
	_body_shell_meshes.clear()
	_body_shell_mats.clear()
	if not combat_lite_mode:
		for layer_t: float in [1.0, 0.66, 0.33]:
			var bs_pair: Dictionary = _create_part_mesh("BodyShell_%.2f" % layer_t, "body_core", 14, 14, true, false, false, false, true, layer_t)
			var bs_m: MeshInstance2D = bs_pair["mesh"] as MeshInstance2D
			_body_shatter.add_child(bs_m)
			_body_shell_meshes.append(bs_m)
			_body_shell_mats.append(bs_pair["mat"] as ShaderMaterial)

	var body_pair: Dictionary = _create_part_mesh("BodyCoreMesh", "body_core", b_div, b_div, true, false, false, false, false, 0.0)
	_body_mesh = body_pair["mesh"] as MeshInstance2D
	_body_shatter.add_child(_body_mesh)

	# 6. Exposed dorsal reactor aura
	_core_glow_poly = _create_core_glow_poly()
	_body_shatter.add_child(_core_glow_poly)

	# 7. Inner translucent bio-wings (+ optional stroboscopic extreme afterimages & air arcs in studio mode)
	_wing_l_pivot = Node2D.new()
	_wing_l_pivot.name = "InnerWingLPivot"
	_art_up_root.add_child(_wing_l_pivot)
	_wing_l_shatter = Node2D.new()
	_wing_l_shatter.name = "InnerWingLShatter"
	_wing_l_pivot.add_child(_wing_l_shatter)
	if not combat_lite_mode:
		_wing_l_ghost_a_pivot = Node2D.new()
		_wing_l_ghost_a_pivot.name = "InnerWingLGhostUpperPivot"
		_wing_l_shatter.add_child(_wing_l_ghost_a_pivot)
		var wla_pair: Dictionary = _create_part_mesh("InnerWingLGhostUpper", "inner_wing_l", 10, 10, false, true, false, false, false, 0.0)
		_wing_l_ghost_a = wla_pair["mesh"] as MeshInstance2D
		_wing_l_ghost_a_pivot.add_child(_wing_l_ghost_a)
		_wing_l_ghost_b_pivot = Node2D.new()
		_wing_l_ghost_b_pivot.name = "InnerWingLGhostLowerPivot"
		_wing_l_shatter.add_child(_wing_l_ghost_b_pivot)
		var wlb_pair: Dictionary = _create_part_mesh("InnerWingLGhostLower", "inner_wing_l", 10, 10, false, true, false, false, false, 0.0)
		_wing_l_ghost_b = wlb_pair["mesh"] as MeshInstance2D
		_wing_l_ghost_b_pivot.add_child(_wing_l_ghost_b)
		_ghost_mats.append(wla_pair["mat"] as ShaderMaterial)
		_ghost_mats.append(wlb_pair["mat"] as ShaderMaterial)
	var wl_pair: Dictionary = _create_part_mesh("InnerWingLMesh", "inner_wing_l", w_div, w_div, false, true, false, false, false, 0.0)
	_wing_l_mesh = wl_pair["mesh"] as MeshInstance2D
	_wing_l_shatter.add_child(_wing_l_mesh)

	_wing_r_pivot = Node2D.new()
	_wing_r_pivot.name = "InnerWingRPivot"
	_art_up_root.add_child(_wing_r_pivot)
	_wing_r_shatter = Node2D.new()
	_wing_r_shatter.name = "InnerWingRShatter"
	_wing_r_pivot.add_child(_wing_r_shatter)
	if not combat_lite_mode:
		_wing_r_ghost_a_pivot = Node2D.new()
		_wing_r_ghost_a_pivot.name = "InnerWingRGhostUpperPivot"
		_wing_r_shatter.add_child(_wing_r_ghost_a_pivot)
		var wra_pair: Dictionary = _create_part_mesh("InnerWingRGhostUpper", "inner_wing_r", 10, 10, false, true, false, false, false, 0.0)
		_wing_r_ghost_a = wra_pair["mesh"] as MeshInstance2D
		_wing_r_ghost_a_pivot.add_child(_wing_r_ghost_a)
		_wing_r_ghost_b_pivot = Node2D.new()
		_wing_r_ghost_b_pivot.name = "InnerWingRGhostLowerPivot"
		_wing_r_shatter.add_child(_wing_r_ghost_b_pivot)
		var wrb_pair: Dictionary = _create_part_mesh("InnerWingRGhostLower", "inner_wing_r", 10, 10, false, true, false, false, false, 0.0)
		_wing_r_ghost_b = wrb_pair["mesh"] as MeshInstance2D
		_wing_r_ghost_b_pivot.add_child(_wing_r_ghost_b)
		_ghost_mats.append(wra_pair["mat"] as ShaderMaterial)
		_ghost_mats.append(wrb_pair["mat"] as ShaderMaterial)
	var wr_pair: Dictionary = _create_part_mesh("InnerWingRMesh", "inner_wing_r", w_div, w_div, false, true, false, false, false, 0.0)
	_wing_r_mesh = wr_pair["mesh"] as MeshInstance2D
	_wing_r_shatter.add_child(_wing_r_mesh)

	if not combat_lite_mode:
		_wing_buzz_vfx = _WingBuzzArcsVFX.new()
		_wing_buzz_vfx.name = "WingBuzzArcsVFX"
		_art_up_root.add_child(_wing_buzz_vfx)

		# 8. Inter-layer elytron cast shadows
		_ely_l_shadow_pivot = Node2D.new()
		_ely_l_shadow_pivot.name = "ElytronLShadowPivot"
		_art_up_root.add_child(_ely_l_shadow_pivot)
		var els_pair: Dictionary = _create_part_mesh("ElytronLShadow", "elytron_l", 10, 10, false, false, true, true, false, 0.0)
		_ely_l_shadow_mesh = els_pair["mesh"] as MeshInstance2D
		_ely_l_shadow_pivot.add_child(_ely_l_shadow_mesh)

		_ely_r_shadow_pivot = Node2D.new()
		_ely_r_shadow_pivot.name = "ElytronRShadowPivot"
		_art_up_root.add_child(_ely_r_shadow_pivot)
		var ers_pair: Dictionary = _create_part_mesh("ElytronRShadow", "elytron_r", 10, 10, false, false, true, true, false, 0.0)
		_ely_r_shadow_mesh = ers_pair["mesh"] as MeshInstance2D
		_ely_r_shadow_pivot.add_child(_ely_r_shadow_mesh)
		_ely_shadow_mats = [els_pair["mat"] as ShaderMaterial, ers_pair["mat"] as ShaderMaterial]

	# 9. Articulated concave 3D elytra: Inner Concave Bowl -> (Optional 2 Rim Layers) -> Outer Convex Dome
	_elytron_l_pivot = Node2D.new()
	_elytron_l_pivot.name = "ElytronLPivot"
	_art_up_root.add_child(_elytron_l_pivot)
	_elytron_l_shatter = Node2D.new()
	_elytron_l_shatter.name = "ElytronLShatter"
	_elytron_l_pivot.add_child(_elytron_l_shatter)
	var el_in_pair: Dictionary = _create_part_mesh("ElytronLInnerBowl", "elytron_l", e_div, e_div, false, false, true, false, false, 0.0)
	_elytron_l_inner_mesh = el_in_pair["mesh"] as MeshInstance2D
	(el_in_pair["mat"] as ShaderMaterial).set_shader_parameter("ely_face_mode", 2)
	_elytron_l_shatter.add_child(_elytron_l_inner_mesh)
	_elytron_l_shells.clear()
	_elytron_shell_mats.clear()
	if not combat_lite_mode:
		for layer_t: float in [1.0, 0.5]:
			var els_sh: Dictionary = _create_part_mesh("ElytronLShell_%.1f" % layer_t, "elytron_l", 18, 18, false, false, true, false, true, layer_t)
			var em_s: MeshInstance2D = els_sh["mesh"] as MeshInstance2D
			_elytron_l_shatter.add_child(em_s)
			_elytron_l_shells.append(em_s)
			_elytron_shell_mats.append(els_sh["mat"] as ShaderMaterial)
	var el_pair: Dictionary = _create_part_mesh("ElytronLMesh", "elytron_l", e_div, e_div, false, false, true, false, false, 0.0)
	_elytron_l_mesh = el_pair["mesh"] as MeshInstance2D
	(el_pair["mat"] as ShaderMaterial).set_shader_parameter("ely_face_mode", 1)
	_elytron_l_shatter.add_child(_elytron_l_mesh)

	_elytron_r_pivot = Node2D.new()
	_elytron_r_pivot.name = "ElytronRPivot"
	_art_up_root.add_child(_elytron_r_pivot)
	_elytron_r_shatter = Node2D.new()
	_elytron_r_shatter.name = "ElytronRShatter"
	_elytron_r_pivot.add_child(_elytron_r_shatter)
	var er_in_pair: Dictionary = _create_part_mesh("ElytronRInnerBowl", "elytron_r", e_div, e_div, false, false, true, false, false, 0.0)
	_elytron_r_inner_mesh = er_in_pair["mesh"] as MeshInstance2D
	(er_in_pair["mat"] as ShaderMaterial).set_shader_parameter("ely_face_mode", 2)
	_elytron_r_shatter.add_child(_elytron_r_inner_mesh)
	_elytron_r_shells.clear()
	if not combat_lite_mode:
		for layer_t: float in [1.0, 0.5]:
			var ers_sh: Dictionary = _create_part_mesh("ElytronRShell_%.1f" % layer_t, "elytron_r", 18, 18, false, false, true, false, true, layer_t)
			var em_s: MeshInstance2D = ers_sh["mesh"] as MeshInstance2D
			_elytron_r_shatter.add_child(em_s)
			_elytron_r_shells.append(em_s)
			_elytron_shell_mats.append(ers_sh["mat"] as ShaderMaterial)
	var er_pair: Dictionary = _create_part_mesh("ElytronRMesh", "elytron_r", e_div, e_div, false, false, true, false, false, 0.0)
	_elytron_r_mesh = er_pair["mesh"] as MeshInstance2D
	(er_pair["mat"] as ShaderMaterial).set_shader_parameter("ely_face_mode", 1)
	_elytron_r_shatter.add_child(_elytron_r_mesh)

	_elytron_inner_mats = [el_in_pair["mat"] as ShaderMaterial, er_in_pair["mat"] as ShaderMaterial]

	# Tip markers for flight ribbons
	_ribbon_l_tip = Marker2D.new()
	_ribbon_l_tip.position = Vector2(-24.0, 74.0)
	_elytron_l_shatter.add_child(_ribbon_l_tip)
	_ribbon_r_tip = Marker2D.new()
	_ribbon_r_tip.position = Vector2(24.0, 74.0)
	_elytron_r_shatter.add_child(_ribbon_r_tip)

	# 10. Bite Crunch HDR VFX at jaw intersection point
	_bite_vfx = _BiteCrunchVFX.new()
	_bite_vfx.name = "BiteCrunchVFX"
	_bite_vfx.position = Vector2(0.0, -142.0)
	_art_up_root.add_child(_bite_vfx)

	if not combat_lite_mode:
		_pivot_gizmo = _PivotGizmoOverlay.new()
		_pivot_gizmo.name = "PivotGizmoOverlay"
		_art_up_root.add_child(_pivot_gizmo)

	# Canonical 7-part lists
	_part_meshes = [_body_mesh, _mandible_l_mesh, _mandible_r_mesh, _wing_l_mesh, _wing_r_mesh, _elytron_l_mesh, _elytron_r_mesh]
	_part_mats = [
		body_pair["mat"] as ShaderMaterial,
		ml_pair["mat"] as ShaderMaterial,
		mr_pair["mat"] as ShaderMaterial,
		wl_pair["mat"] as ShaderMaterial,
		wr_pair["mat"] as ShaderMaterial,
		el_pair["mat"] as ShaderMaterial,
		er_pair["mat"] as ShaderMaterial,
	]
	_shell_meshes.clear()
	_shell_meshes.append_array(_body_shell_meshes)
	_shell_meshes.append_array(_elytron_l_shells)
	_shell_meshes.append_array(_elytron_r_shells)
	_shell_mats.clear()
	_shell_mats.append_array(_body_shell_mats)
	_shell_mats.append_array(_elytron_shell_mats)

	_shatter_nodes = [_body_shatter, _mandible_l_shatter, _mandible_r_shatter, _wing_l_shatter, _wing_r_shatter, _elytron_l_shatter, _elytron_r_shatter]

	_shatter_vels.resize(7)
	_shatter_ang_vels.resize(7)


func _create_part_mesh(
	node_name: String,
	part_key: String,
	cols: int,
	rows: int,
	is_body: bool,
	is_wing: bool,
	is_elytron: bool,
	is_shadow_caster: bool,
	is_extrusion_shell: bool,
	layer_t: float
) -> Dictionary:
	var mesh_inst := MeshInstance2D.new()
	mesh_inst.name = node_name

	var base_dir: String = rig_config.asset_dir.rstrip("/")
	var alb_tex: ImageTexture = _load_png_tex("%s/%s_albedo.png" % [base_dir, part_key], true)
	var nh_tex: ImageTexture = _load_png_tex("%s/%s_normal_height.png" % [base_dir, part_key], true)
	var ilm_tex: ImageTexture = _load_png_tex("%s/%s_ilm_sdf.png" % [base_dir, part_key], false)
	var fx_tex: ImageTexture = _load_png_tex("%s/%s_fx_motion.png" % [base_dir, part_key], true)

	var sz: Vector2 = alb_tex.get_size() if alb_tex != null else Vector2(256.0, 256.0)
	mesh_inst.mesh = _build_subdivided_quad_mesh(sz, cols, rows)
	mesh_inst.texture = alb_tex

	var mat := ShaderMaterial.new()
	mat.shader = EnemyShader
	mat.set_shader_parameter("tex_size_px", sz)
	if nh_tex != null:
		mat.set_shader_parameter("normal_height_tex", nh_tex)
	if ilm_tex != null:
		mat.set_shader_parameter("ilm_sdf_tex", ilm_tex)
	if fx_tex != null:
		mat.set_shader_parameter("fx_motion_tex", fx_tex)
		mat.set_shader_parameter("has_fx_motion", true)
	else:
		mat.set_shader_parameter("has_fx_motion", false)

	mat.set_shader_parameter("is_body_part", is_body)
	mat.set_shader_parameter("is_wing_part", is_wing)
	mat.set_shader_parameter("is_elytron_part", is_elytron)
	mat.set_shader_parameter("ely_hinge_active", is_elytron)
	mat.set_shader_parameter("shadow_caster_mode", is_shadow_caster)
	mat.set_shader_parameter("extrusion_shell_mode", is_extrusion_shell)
	mat.set_shader_parameter("extrusion_layer_t", layer_t)
	mat.set_shader_parameter("core_light_art_pos", Vector2(0.0, 19.5))
	mesh_inst.material = mat
	return {"mesh": mesh_inst, "mat": mat}


func _create_flight_ribbon(node_name: String) -> Line2D:
	var line := Line2D.new()
	line.name = node_name
	line.top_level = true
	line.width = 4.2
	line.z_index = 2
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var grad := Gradient.new()
	grad.set_color(0, Color(0.28, 0.95, 0.62, 0.0))
	grad.set_color(1, Color(0.55, 1.5, 0.85, 0.72))
	line.gradient = grad
	var w_curve := Curve.new()
	w_curve.add_point(Vector2(0.0, 0.1))
	w_curve.add_point(Vector2(1.0, 1.0))
	line.width_curve = w_curve
	return line


func _create_thruster_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "RearThrusterEmbers"
	p.position = Vector2(0.0, 178.0)
	p.amount = 28
	p.lifetime = 0.52
	p.direction = Vector2(0.0, 1.0)
	p.spread = 24.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 95.0
	p.initial_velocity_max = 195.0
	p.scale_amount_min = 3.5
	p.scale_amount_max = 7.5
	var grad := Gradient.new()
	grad.set_color(0, Color(0.55, 1.5, 0.78, 0.95))
	grad.set_color(1, Color(0.18, 0.85, 0.45, 0.0))
	p.color_ramp = grad
	return p


func _create_core_glow_poly() -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = "DorsalCoreAura"
	poly.position = Vector2(0.0, 19.5)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.append(Vector2.ZERO)
	cols.append(Color(0.35, 1.5, 0.72, 0.48))
	for i: int in range(17):
		var a: float = (TAU / 16.0) * float(i)
		pts.append(Vector2(cos(a) * 34.0, sin(a) * 58.0))
		cols.append(Color(0.20, 0.95, 0.52, 0.0))
	poly.polygon = pts
	poly.vertex_colors = cols
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	poly.material = mat
	return poly


func apply_rig_calibration() -> void:
	if rig_config == null or _visual_root == null:
		return
	_visual_root.scale = Vector2(rig_config.display_scale, rig_config.display_scale)

	# Scissor Mandibles
	_mandible_r_pivot.position = rig_config.mandible_offset
	_mandible_l_pivot.position = Vector2(-rig_config.mandible_offset.x, rig_config.mandible_offset.y)
	_mandible_r_pivot.scale = Vector2(rig_config.mandible_scale, rig_config.mandible_scale)
	_mandible_l_pivot.scale = Vector2(rig_config.mandible_scale, rig_config.mandible_scale)
	if _mandible_r_shadow_pivot != null:
		_mandible_r_shadow_pivot.position = rig_config.mandible_offset
		_mandible_r_shadow_pivot.scale = _mandible_r_pivot.scale
	if _mandible_l_shadow_pivot != null:
		_mandible_l_shadow_pivot.position = Vector2(-rig_config.mandible_offset.x, rig_config.mandible_offset.y)
		_mandible_l_shadow_pivot.scale = _mandible_l_pivot.scale

	if _mandible_r_mesh != null and _mandible_r_mesh.texture != null:
		var msz: Vector2 = _mandible_r_mesh.texture.get_size()
		var mr_off := Vector2((0.5 - rig_config.mandible_hinge_uv.x) * msz.x, (0.5 - rig_config.mandible_hinge_uv.y) * msz.y)
		var ml_off := Vector2((0.5 - (1.0 - rig_config.mandible_hinge_uv.x)) * msz.x, (0.5 - rig_config.mandible_hinge_uv.y) * msz.y)
		_mandible_r_mesh.position = mr_off
		_mandible_l_mesh.position = ml_off
		if _mandible_r_shadow_mesh != null:
			_mandible_r_shadow_mesh.position = mr_off
		if _mandible_l_shadow_mesh != null:
			_mandible_l_shadow_mesh.position = ml_off

	# Elytrons + Thickness Shells + Cast Shadows
	_elytron_r_pivot.position = rig_config.elytron_offset
	_elytron_l_pivot.position = Vector2(-rig_config.elytron_offset.x, rig_config.elytron_offset.y)
	_elytron_r_pivot.scale = Vector2(rig_config.elytron_scale, rig_config.elytron_scale)
	_elytron_l_pivot.scale = Vector2(rig_config.elytron_scale, rig_config.elytron_scale)
	if _ely_r_shadow_pivot != null:
		_ely_r_shadow_pivot.position = rig_config.elytron_offset
		_ely_r_shadow_pivot.scale = _elytron_r_pivot.scale
	if _ely_l_shadow_pivot != null:
		_ely_l_shadow_pivot.position = Vector2(-rig_config.elytron_offset.x, rig_config.elytron_offset.y)
		_ely_l_shadow_pivot.scale = _elytron_l_pivot.scale

	if _elytron_r_mesh != null and _elytron_r_mesh.texture != null:
		var esz: Vector2 = _elytron_r_mesh.texture.get_size()
		var r_off := Vector2((0.5 - rig_config.elytron_hinge_uv.x) * esz.x, (0.5 - rig_config.elytron_hinge_uv.y) * esz.y)
		var l_off := Vector2((0.5 - (1.0 - rig_config.elytron_hinge_uv.x)) * esz.x, (0.5 - rig_config.elytron_hinge_uv.y) * esz.y)
		_elytron_r_mesh.position = r_off
		_elytron_l_mesh.position = l_off
		if _elytron_r_inner_mesh != null:
			_elytron_r_inner_mesh.position = r_off
		if _elytron_l_inner_mesh != null:
			_elytron_l_inner_mesh.position = l_off
		if _ely_r_shadow_mesh != null:
			_ely_r_shadow_mesh.position = r_off
		if _ely_l_shadow_mesh != null:
			_ely_l_shadow_mesh.position = l_off
		for sm: MeshInstance2D in _elytron_r_shells:
			sm.position = r_off
		for sm: MeshInstance2D in _elytron_l_shells:
			sm.position = l_off

		var l_hinge_local: Vector2 = -l_off
		var r_hinge_local: Vector2 = -r_off
		var l_shell_count: int = _elytron_l_shells.size()
		if _part_mats.size() >= 7:
			for e_pair: Array in [[_part_mats[5], l_hinge_local], [_part_mats[6], r_hinge_local]]:
				var em: ShaderMaterial = e_pair[0] as ShaderMaterial
				if em != null:
					em.set_shader_parameter("ely_hinge_local_px", e_pair[1] as Vector2)
					em.set_shader_parameter("ely_scale", rig_config.elytron_scale)
					em.set_shader_parameter("ely_dome_height_px", rig_config.elytron_dome_height_px)
					em.set_shader_parameter("ely_rim_thickness_px", rig_config.elytron_rim_thickness_px)
		if _elytron_inner_mats.size() >= 2:
			for e_in_pair: Array in [[_elytron_inner_mats[0], l_hinge_local], [_elytron_inner_mats[1], r_hinge_local]]:
				var em_i: ShaderMaterial = e_in_pair[0] as ShaderMaterial
				if em_i != null:
					em_i.set_shader_parameter("ely_hinge_local_px", e_in_pair[1] as Vector2)
					em_i.set_shader_parameter("ely_scale", rig_config.elytron_scale)
					em_i.set_shader_parameter("ely_dome_height_px", rig_config.elytron_dome_height_px)
					em_i.set_shader_parameter("ely_rim_thickness_px", rig_config.elytron_rim_thickness_px)
		for s_i: int in range(_elytron_shell_mats.size()):
			var smat: ShaderMaterial = _elytron_shell_mats[s_i]
			if smat != null:
				smat.set_shader_parameter("ely_hinge_local_px", l_hinge_local if s_i < l_shell_count else r_hinge_local)
				smat.set_shader_parameter("ely_scale", rig_config.elytron_scale)
				smat.set_shader_parameter("ely_dome_height_px", rig_config.elytron_dome_height_px)
				smat.set_shader_parameter("ely_rim_thickness_px", rig_config.elytron_rim_thickness_px)
		if _ely_shadow_mats.size() >= 2:
			if _ely_shadow_mats[0] != null:
				_ely_shadow_mats[0].set_shader_parameter("ely_hinge_local_px", l_hinge_local)
				_ely_shadow_mats[0].set_shader_parameter("ely_scale", rig_config.elytron_scale)
				_ely_shadow_mats[0].set_shader_parameter("ely_dome_height_px", rig_config.elytron_dome_height_px)
			if _ely_shadow_mats[1] != null:
				_ely_shadow_mats[1].set_shader_parameter("ely_hinge_local_px", r_hinge_local)
				_ely_shadow_mats[1].set_shader_parameter("ely_scale", rig_config.elytron_scale)
				_ely_shadow_mats[1].set_shader_parameter("ely_dome_height_px", rig_config.elytron_dome_height_px)

	# Inner Bio-Wings
	_wing_r_pivot.position = rig_config.wing_offset
	_wing_l_pivot.position = Vector2(-rig_config.wing_offset.x, rig_config.wing_offset.y)
	_wing_r_pivot.scale = Vector2(rig_config.wing_scale, rig_config.wing_scale)
	_wing_l_pivot.scale = Vector2(rig_config.wing_scale, rig_config.wing_scale)

	if _wing_r_mesh != null and _wing_r_mesh.texture != null:
		var wsz: Vector2 = _wing_r_mesh.texture.get_size()
		var wr_off := Vector2((0.5 - rig_config.wing_hinge_uv.x) * wsz.x, (0.5 - rig_config.wing_hinge_uv.y) * wsz.y)
		var wl_off := Vector2((0.5 - (1.0 - rig_config.wing_hinge_uv.x)) * wsz.x, (0.5 - rig_config.wing_hinge_uv.y) * wsz.y)
		_wing_r_mesh.position = wr_off
		_wing_l_mesh.position = wl_off
		if _wing_r_ghost_a != null:
			_wing_r_ghost_a.position = wr_off
		if _wing_r_ghost_b != null:
			_wing_r_ghost_b.position = wr_off
		if _wing_l_ghost_a != null:
			_wing_l_ghost_a.position = wl_off
		if _wing_l_ghost_b != null:
			_wing_l_ghost_b.position = wl_off

	var r_hinge_uv: Vector2 = rig_config.wing_hinge_uv
	var l_hinge_uv := Vector2(1.0 - r_hinge_uv.x, r_hinge_uv.y)
	if _part_mats.size() >= 5:
		if _part_mats[3] != null:
			_part_mats[3].set_shader_parameter("wing_hinge_uv", l_hinge_uv)
		if _part_mats[4] != null:
			_part_mats[4].set_shader_parameter("wing_hinge_uv", r_hinge_uv)
	if _ghost_mats.size() >= 4:
		for li: int in [0, 1]:
			if _ghost_mats[li] != null:
				_ghost_mats[li].set_shader_parameter("wing_hinge_uv", l_hinge_uv)
		for ri: int in [2, 3]:
			if _ghost_mats[ri] != null:
				_ghost_mats[ri].set_shader_parameter("wing_hinge_uv", r_hinge_uv)


func apply_style_profile(style: FactionStyleScript) -> void:
	if style == null:
		return
	style_profile = style
	var all_mats: Array[ShaderMaterial] = []
	all_mats.append_array(_part_mats)
	all_mats.append_array(_elytron_inner_mats)
	all_mats.append_array(_ghost_mats)
	all_mats.append_array(_shell_mats)

	for mat: ShaderMaterial in all_mats:
		if mat == null:
			continue
		mat.set_shader_parameter("relief_depth_px", style.relief_depth_px)
		mat.set_shader_parameter("parallax_strength", style.parallax_strength)
		mat.set_shader_parameter("shell_thickness_px", style.shell_thickness_px)
		mat.set_shader_parameter("core_light_color", style.core_light_color)
		mat.set_shader_parameter("green_bounce_strength", style.green_bounce_strength)
		mat.set_shader_parameter("studio_exposure", style.studio_exposure)
		mat.set_shader_parameter("ambient_fill_strength", style.ambient_fill_strength)
		mat.set_shader_parameter("cel_strength", style.cel_strength)
		mat.set_shader_parameter("cel_threshold", style.cel_threshold)
		mat.set_shader_parameter("cel_softness", style.cel_softness)
		mat.set_shader_parameter("cel_mid_band_strength", style.cel_mid_band_strength)
		mat.set_shader_parameter("albedo_de_shade", style.albedo_de_shade)
		mat.set_shader_parameter("ao_strength", style.ao_strength)
		mat.set_shader_parameter("color_contrast", style.color_contrast)
		mat.set_shader_parameter("color_saturation", style.color_saturation)
		mat.set_shader_parameter("specular_strength", style.specular_strength)
		mat.set_shader_parameter("specular_threshold", style.specular_threshold)
		mat.set_shader_parameter("iridescence_strength", style.iridescence_strength)
		mat.set_shader_parameter("iridescence_color_a", style.iridescence_color_a)
		mat.set_shader_parameter("iridescence_color_b", style.iridescence_color_b)
		mat.set_shader_parameter("sss_color", style.sss_color)
		mat.set_shader_parameter("sss_strength", style.sss_strength)
		mat.set_shader_parameter("normal_rim_strength", style.normal_rim_strength)
		mat.set_shader_parameter("counter_rim_strength", style.counter_rim_strength)
		mat.set_shader_parameter("counter_rim_color", style.counter_rim_color)
		mat.set_shader_parameter("ink_strength", style.ink_strength)
		mat.set_shader_parameter("ink_color", style.ink_color)
		mat.set_shader_parameter("ink_sdf_bias_px", style.ink_sdf_bias_px)
		mat.set_shader_parameter("ink_sdf_softness", style.ink_sdf_softness)
		mat.set_shader_parameter("outer_outline_width_px", style.outer_outline_width_px)
		mat.set_shader_parameter("outer_outline_strength", style.outer_outline_strength)
		mat.set_shader_parameter("outer_outline_color", style.outer_outline_color)
		mat.set_shader_parameter("outer_alert_color", style.outer_alert_color)
		mat.set_shader_parameter("hdr_cap", style.hdr_cap)
		mat.set_shader_parameter("primary_emissive_strength", style.primary_emissive_strength)
		mat.set_shader_parameter("plasma_flow_speed", style.plasma_flow_speed)
		mat.set_shader_parameter("primary_emissive_tint", style.primary_emissive_tint)
		mat.set_shader_parameter("secondary_emissive_tint", style.secondary_emissive_tint)
		mat.set_shader_parameter("dissolve_edge_color", style.dissolve_edge_color)
		mat.set_shader_parameter("ao_tint", Color(0.10, 0.09, 0.22, 1.0))
		mat.set_shader_parameter("shadow_tint", Color(0.18, 0.17, 0.36, 1.0))
		if rig_config != null:
			mat.set_shader_parameter("wing_flex_amp", rig_config.wing_flex_amp)
			mat.set_shader_parameter("breath_amp", rig_config.breath_amp)
			mat.set_shader_parameter("leg_paddle_amp", rig_config.leg_paddle_amp)
			mat.set_shader_parameter("leg_paddle_freq", rig_config.leg_paddle_freq)
			mat.set_shader_parameter("ely_dome_height_px", rig_config.elytron_dome_height_px)
			mat.set_shader_parameter("ely_rim_thickness_px", rig_config.elytron_rim_thickness_px)

	if _under_shadow_mat != null:
		_under_shadow_mat.set_shader_parameter("shadow_caster_color", Color(0.015, 0.012, 0.045, style.cast_shadow_opacity * 0.65))
		_under_shadow_mat.set_shader_parameter("relief_depth_px", style.relief_depth_px)
	for smat: ShaderMaterial in _ely_shadow_mats:
		if smat != null:
			smat.set_shader_parameter("shadow_caster_color", Color(0.015, 0.012, 0.05, style.cast_shadow_opacity))
			smat.set_shader_parameter("relief_depth_px", style.relief_depth_px)
	for mmat: ShaderMaterial in _mandible_shadow_mats:
		if mmat != null:
			mmat.set_shader_parameter("shadow_caster_color", Color(0.015, 0.012, 0.05, style.cast_shadow_opacity * 0.85))
			mmat.set_shader_parameter("relief_depth_px", style.relief_depth_px)
	if _has_custom_palette:
		apply_custom_palette(_custom_use_recolor, _custom_armor_tint, _custom_accent_tint, _custom_energy_tint)
	elif _variant_index >= 0:
		set_variant_index(_variant_index)


func set_anim_state(new_state: int) -> void:
	if new_state == _state and new_state != AnimState.ATTACK_LUNGE and new_state != AnimState.DEATH_SHATTER:
		return
	_state = new_state
	if _state == AnimState.ATTACK_LUNGE:
		_lunge_timer = 0.44
		_ely_open_blend = maxf(_ely_open_blend, 0.85)
		_wing_open_blend = maxf(_wing_open_blend, 0.90)
		_wing_vis_alpha = 1.0
		_trigger_bite_impact_phase()
	elif _state == AnimState.DEATH_SHATTER:
		_start_shatter()
	elif _dissolve_val > 0.01:
		respawn()


func get_anim_state() -> int:
	return _state


func trigger_bite_snap() -> void:
	if _state == AnimState.DEATH_SHATTER:
		return
	_bite_phase = 1
	_bite_timer = 0.18


func _trigger_bite_impact_phase() -> void:
	_bite_phase = 2
	_bite_timer = 0.22
	_bite_hitstop = 0.042
	if rig_config != null:
		_mandible_deg_cur = rig_config.mandible_bite_deg
		_mandible_deg_vel = 180.0
	if _bite_vfx != null:
		_bite_vfx.trigger()
	if _visual_root != null and rig_config != null:
		_visual_root.scale = Vector2(rig_config.display_scale * 1.12, rig_config.display_scale * 0.88)


func is_bite_vfx_active() -> bool:
	return _bite_vfx != null and _bite_vfx.is_active()


func trigger_hit_flash() -> void:
	_hit_flash_val = 1.0
	_recoil_offset = Vector2(-18.0, 0.0)
	_tilt_smoothed.x = clampf(_tilt_smoothed.x + 0.58, -1.0, 1.0)
	if _visual_root != null and _state != AnimState.DEATH_SHATTER and rig_config != null:
		_visual_root.scale = Vector2(rig_config.display_scale * 0.88, rig_config.display_scale * 1.14)


func clear_ribbons() -> void:
	_ribbon_pts_l.clear()
	_ribbon_pts_r.clear()
	if _ribbon_l != null:
		_ribbon_l.clear_points()
	if _ribbon_r != null:
		_ribbon_r.clear_points()


func respawn() -> void:
	_dissolve_val = 0.0
	_shatter_elapsed = 0.0
	_bite_phase = 0
	_bite_timer = 0.0
	_bite_hitstop = 0.0
	_lunge_timer = 0.0
	_ely_open_blend = 0.0
	_ely_open_vel = 0.0
	_wing_open_blend = 0.0
	_wing_open_vel = 0.0
	_mandible_deg_cur = 0.0
	_mandible_deg_vel = 0.0
	_wing_speed_ramp = 0.0
	_wing_blur_arc_rad_cur = 0.0
	_state = AnimState.IDLE_HOVER
	if _wing_buzz_vfx != null:
		_wing_buzz_vfx.visible = false
	clear_ribbons()
	for sn: Node2D in _shatter_nodes:
		if sn != null:
			sn.position = Vector2.ZERO
			sn.rotation = 0.0
	if _under_shadow_mesh != null:
		_under_shadow_mesh.visible = _floor_shadow_enabled
	if _ely_l_shadow_pivot != null:
		_ely_l_shadow_pivot.visible = true
	if _ely_r_shadow_pivot != null:
		_ely_r_shadow_pivot.visible = true
	if _mandible_l_shadow_pivot != null:
		_mandible_l_shadow_pivot.visible = false
	if _mandible_r_shadow_pivot != null:
		_mandible_r_shadow_pivot.visible = false
	apply_rig_calibration()
	for mat: ShaderMaterial in _part_mats:
		if mat != null:
			mat.set_shader_parameter("dissolve_amount", 0.0)
	for smat: ShaderMaterial in _shell_mats:
		if smat != null:
			smat.set_shader_parameter("dissolve_amount", 0.0)
	for imat: ShaderMaterial in _elytron_inner_mats:
		if imat != null:
			imat.set_shader_parameter("dissolve_amount", 0.0)


func _start_shatter() -> void:
	_shatter_elapsed = 0.0
	_bite_phase = 0
	_hit_flash_val = 1.0
	var imp: float = rig_config.shatter_impulse if rig_config != null else 240.0
	_shatter_vels = [
		Vector2(0.0, 45.0),
		Vector2(-imp * 0.75, -imp * 1.25),
		Vector2(imp * 0.75, -imp * 1.25),
		Vector2(-imp * 1.15, -imp * 0.25),
		Vector2(imp * 1.15, -imp * 0.25),
		Vector2(-imp * 0.90, -imp * 0.65),
		Vector2(imp * 0.90, -imp * 0.65),
	]
	_shatter_ang_vels = [0.4, -5.2, 5.2, -4.5, 4.5, -3.2, 3.2]
	if _under_shadow_mesh != null:
		_under_shadow_mesh.visible = false
	if _ely_l_shadow_pivot != null:
		_ely_l_shadow_pivot.visible = false
	if _ely_r_shadow_pivot != null:
		_ely_r_shadow_pivot.visible = false
	if _mandible_l_shadow_pivot != null:
		_mandible_l_shadow_pivot.visible = false
	if _mandible_r_shadow_pivot != null:
		_mandible_r_shadow_pivot.visible = false


func set_tilt_25d(roll: float, pitch: float) -> void:
	_tilt_input = Vector2(clampf(roll, -1.0, 1.0), clampf(pitch, -1.0, 1.0))


func get_tilt_25d() -> Vector2:
	return _tilt_smoothed


func set_flat_baseline_mode(enabled: bool) -> void:
	_flat_baseline = enabled
	for mat: ShaderMaterial in _part_mats:
		if mat != null:
			mat.set_shader_parameter("flat_baseline_mode", enabled)
	for imat: ShaderMaterial in _elytron_inner_mats:
		if imat != null:
			imat.set_shader_parameter("flat_baseline_mode", enabled)
	for gmat: ShaderMaterial in _ghost_mats:
		if gmat != null:
			gmat.set_shader_parameter("flat_baseline_mode", enabled)
	for smat: ShaderMaterial in _shell_mats:
		if smat != null:
			smat.set_shader_parameter("flat_baseline_mode", enabled)


func set_floor_shadow_enabled(enabled: bool) -> void:
	_floor_shadow_enabled = enabled
	if _under_shadow_mesh != null:
		_under_shadow_mesh.visible = enabled and _state != AnimState.DEATH_SHATTER and not _flat_baseline


func is_floor_shadow_enabled() -> bool:
	return _floor_shadow_enabled


func get_core_aura_energy() -> float:
	return clampf(0.55 + maxf(_ely_open_blend, 0.0) * 1.15 + (_sec_emissive - 0.45) * 0.25, 0.45, 2.0)


func set_show_pivots(enabled: bool) -> void:
	_show_pivots = enabled
	if _pivot_gizmo != null:
		_pivot_gizmo.visible = enabled and _state != AnimState.DEATH_SHATTER


func set_zoom_scale(z: float) -> void:
	_zoom_scale = clampf(z, 0.35, 4.5)
	for mat: ShaderMaterial in _part_mats:
		if mat != null:
			mat.set_shader_parameter("zoom_scale", _zoom_scale)
	for imat: ShaderMaterial in _elytron_inner_mats:
		if imat != null:
			imat.set_shader_parameter("zoom_scale", _zoom_scale)
	for gmat: ShaderMaterial in _ghost_mats:
		if gmat != null:
			gmat.set_shader_parameter("zoom_scale", _zoom_scale)


func set_debug_view_mode(mode: int) -> void:
	_debug_view_mode = clampi(mode, 0, 7)
	for mat: ShaderMaterial in _part_mats:
		if mat != null:
			mat.set_shader_parameter("debug_view_mode", _debug_view_mode)
	for imat: ShaderMaterial in _elytron_inner_mats:
		if imat != null:
			imat.set_shader_parameter("debug_view_mode", _debug_view_mode)
	for gmat: ShaderMaterial in _ghost_mats:
		if gmat != null:
			gmat.set_shader_parameter("debug_view_mode", _debug_view_mode)


func get_active_energy_color() -> Color:
	if _has_custom_palette and _custom_use_recolor:
		return _custom_energy_tint
	if _variant_index >= 0 and style_profile != null and _variant_index < style_profile.variant_energy_tints.size():
		return style_profile.variant_energy_tints[_variant_index]
	return style_profile.core_light_color if style_profile != null else Color(0.22, 1.0, 0.56, 1.0)


func set_enable_ribbons(enabled: bool) -> void:
	enable_combat_ribbons = enabled
	if enabled and _ribbon_l == null and is_inside_tree():
		_ribbon_l = _create_flight_ribbon("FlightRibbonL")
		_ribbon_r = _create_flight_ribbon("FlightRibbonR")
		add_child(_ribbon_l)
		add_child(_ribbon_r)


func apply_custom_palette(use_recolor: bool, armor_tint: Color, accent_tint: Color, energy_tint: Color) -> void:
	_has_custom_palette = true
	_custom_use_recolor = use_recolor
	_custom_armor_tint = armor_tint
	_custom_accent_tint = accent_tint
	_custom_energy_tint = energy_tint
	_apply_palette_values(use_recolor, armor_tint, accent_tint, energy_tint)


func set_variant_index(idx: int) -> void:
	_has_custom_palette = false
	_variant_index = idx
	var use_recolor: bool = idx >= 0 and style_profile != null and idx < style_profile.variant_tints.size()
	var acc_tint: Color = style_profile.variant_tints[idx] if use_recolor else (style_profile.counter_rim_color if style_profile != null else Color(0.68, 0.24, 0.96, 1.0))
	var arm_tint: Color = style_profile.variant_armor_tints[idx] if (use_recolor and idx < style_profile.variant_armor_tints.size()) else Color(0.22, 0.22, 0.36, 1.0)
	var eng_tint: Color = style_profile.variant_energy_tints[idx] if (use_recolor and idx < style_profile.variant_energy_tints.size()) else (style_profile.core_light_color if style_profile != null else Color(0.22, 1.0, 0.56, 1.0))
	_apply_palette_values(use_recolor, arm_tint, acc_tint, eng_tint)


func _apply_palette_values(use_recolor: bool, arm_tint: Color, acc_tint: Color, eng_tint: Color) -> void:
	var pri_tint: Color = eng_tint if use_recolor else (style_profile.primary_emissive_tint if style_profile != null else Color(0.28, 1.0, 0.56, 1.0))
	var sec_tint: Color = eng_tint.lightened(0.18) if use_recolor else (style_profile.secondary_emissive_tint if style_profile != null else Color(0.35, 1.0, 0.72, 1.0))
	var sss_t: Color = eng_tint if use_recolor else (style_profile.sss_color if style_profile != null else Color(0.22, 0.98, 0.55, 1.0))
	var irid_a: Color = acc_tint if use_recolor else (style_profile.iridescence_color_a if style_profile != null else Color(0.56, 0.28, 1.0, 1.0))
	var irid_b: Color = eng_tint if use_recolor else (style_profile.iridescence_color_b if style_profile != null else Color(0.18, 0.96, 0.78, 1.0))

	var all_lit_mats: Array[ShaderMaterial] = []
	all_lit_mats.append_array(_part_mats)
	all_lit_mats.append_array(_elytron_inner_mats)
	all_lit_mats.append_array(_ghost_mats)
	for mat: ShaderMaterial in all_lit_mats:
		if mat == null:
			continue
		mat.set_shader_parameter("enable_variant_recolor", use_recolor)
		mat.set_shader_parameter("variant_recolor_tint", acc_tint)
		mat.set_shader_parameter("variant_armor_tint", arm_tint)
		mat.set_shader_parameter("variant_energy_tint", eng_tint)
		mat.set_shader_parameter("primary_emissive_tint", pri_tint)
		mat.set_shader_parameter("secondary_emissive_tint", sec_tint)
		mat.set_shader_parameter("core_light_color", eng_tint)
		mat.set_shader_parameter("sss_color", sss_t)
		mat.set_shader_parameter("counter_rim_color", acc_tint)
		mat.set_shader_parameter("iridescence_color_a", irid_a)
		mat.set_shader_parameter("iridescence_color_b", irid_b)
	for smat: ShaderMaterial in _shell_mats:
		if smat != null:
			smat.set_shader_parameter("core_light_color", eng_tint)

	var eff_aura: Color = eng_tint if use_recolor else Color(0.22, 1.0, 0.56, 1.0)
	if _core_glow_poly != null and _core_glow_poly.vertex_colors.size() > 1:
		var cols := PackedColorArray()
		cols.append(Color(eff_aura.r * 1.4, eff_aura.g * 1.4, eff_aura.b * 1.4, 0.48))
		for _i: int in range(_core_glow_poly.vertex_colors.size() - 1):
			cols.append(Color(eff_aura.r, eff_aura.g, eff_aura.b, 0.0))
		_core_glow_poly.vertex_colors = cols
	if _thruster_particles != null and _thruster_particles.color_ramp != null:
		_thruster_particles.color_ramp.set_color(0, Color(eff_aura.r * 1.4, eff_aura.g * 1.4, eff_aura.b * 1.4, 0.95))
		_thruster_particles.color_ramp.set_color(1, Color(eff_aura.r * 0.85, eff_aura.g * 0.85, eff_aura.b * 0.85, 0.0))
	for rib: Line2D in [_ribbon_l, _ribbon_r]:
		if rib != null and rib.gradient != null:
			rib.gradient.set_color(0, Color(eff_aura.r, eff_aura.g, eff_aura.b, 0.0))
			rib.gradient.set_color(1, Color(eff_aura.r * 1.4, eff_aura.g * 1.4, eff_aura.b * 1.4, 0.72))


func set_light_override(dir_2d: Vector2, light_z_val: float, eclipse_val: float = 0.0) -> void:
	_cur_light_dir_2d = dir_2d.normalized() if dir_2d.length_squared() > 0.0001 else Vector2(-0.55, -0.78)
	_cur_light_z = clampf(light_z_val, 0.12, 2.0)
	for mat: ShaderMaterial in _part_mats:
		if mat == null:
			continue
		mat.set_shader_parameter("light_dir_2d", _cur_light_dir_2d)
		mat.set_shader_parameter("light_z", _cur_light_z)
		mat.set_shader_parameter("eclipse_factor", eclipse_val)
	for imat: ShaderMaterial in _elytron_inner_mats:
		if imat == null:
			continue
		imat.set_shader_parameter("light_dir_2d", _cur_light_dir_2d)
		imat.set_shader_parameter("light_z", _cur_light_z)
		imat.set_shader_parameter("eclipse_factor", eclipse_val)
	for gmat: ShaderMaterial in _ghost_mats:
		if gmat == null:
			continue
		gmat.set_shader_parameter("light_dir_2d", _cur_light_dir_2d)
		gmat.set_shader_parameter("light_z", _cur_light_z)
		gmat.set_shader_parameter("eclipse_factor", eclipse_val)
	for smat: ShaderMaterial in _shell_mats:
		if smat != null:
			smat.set_shader_parameter("light_dir_2d", _cur_light_dir_2d)


func apply_cosmic_lighting(sample: CosmicLightingSampleScript) -> void:
	if sample == null:
		return
	_cur_light_dir_2d = sample.light_dir_2d
	var base_sh := Color(0.18, 0.17, 0.36, 1.0)
	var base_ao := Color(0.10, 0.09, 0.22, 1.0)
	var bio_w: float = clampf(sample.biome_shadow_weight, 0.0, 0.42)
	var eff_shadow_tint: Color = base_sh.lerp(sample.shadow_tint, bio_w)
	var eff_ao_tint: Color = base_ao.lerp(sample.ao_tint, bio_w * 0.9)
	var eff_key_tint: Color = Color(1.04, 1.02, 0.98, 1.0).lerp(sample.key_light_tint, 0.60)
	var eff_eclipse: float = sample.eclipse_factor * (1.0 - clampf(sample.visibility_floor, 0.0, 0.85) * 0.55)
	for mat: ShaderMaterial in _part_mats:
		if mat == null:
			continue
		mat.set_shader_parameter("light_dir_2d", sample.light_dir_2d)
		mat.set_shader_parameter("key_light_tint", eff_key_tint)
		mat.set_shader_parameter("shadow_tint", eff_shadow_tint)
		mat.set_shader_parameter("ao_tint", eff_ao_tint)
		mat.set_shader_parameter("rim_key_color", sample.rim_key_color)
		mat.set_shader_parameter("eclipse_factor", eff_eclipse)
		mat.set_shader_parameter("emissive_boost", sample.emissive_boost_mult)
	for imat: ShaderMaterial in _elytron_inner_mats:
		if imat == null:
			continue
		imat.set_shader_parameter("light_dir_2d", sample.light_dir_2d)
		imat.set_shader_parameter("key_light_tint", eff_key_tint)
		imat.set_shader_parameter("shadow_tint", eff_shadow_tint)
		imat.set_shader_parameter("ao_tint", eff_ao_tint)
		imat.set_shader_parameter("rim_key_color", sample.rim_key_color)
		imat.set_shader_parameter("eclipse_factor", eff_eclipse)
		imat.set_shader_parameter("emissive_boost", sample.emissive_boost_mult)
	for gmat: ShaderMaterial in _ghost_mats:
		if gmat == null:
			continue
		gmat.set_shader_parameter("light_dir_2d", sample.light_dir_2d)
		gmat.set_shader_parameter("key_light_tint", eff_key_tint)
		gmat.set_shader_parameter("shadow_tint", eff_shadow_tint)
		gmat.set_shader_parameter("ao_tint", eff_ao_tint)
		gmat.set_shader_parameter("rim_key_color", sample.rim_key_color)
		gmat.set_shader_parameter("eclipse_factor", eff_eclipse)
		gmat.set_shader_parameter("emissive_boost", sample.emissive_boost_mult)
	for smat: ShaderMaterial in _shell_mats:
		if smat != null:
			smat.set_shader_parameter("light_dir_2d", sample.light_dir_2d)
			smat.set_shader_parameter("shadow_tint", eff_shadow_tint)
			smat.set_shader_parameter("ao_tint", eff_ao_tint)


func step(delta: float, angular_velocity_rad: float = 0.0, forward_speed_norm: float = 0.0, accel_norm: float = 0.0) -> void:
	if _bite_vfx != null:
		_bite_vfx.step_vfx(delta)

	if _bite_hitstop > 0.0:
		_bite_hitstop = maxf(_bite_hitstop - delta, 0.0)
		return

	_time += delta
	_hit_flash_val = move_toward(_hit_flash_val, 0.0, delta * 9.0)
	_recoil_offset = _recoil_offset.lerp(Vector2.ZERO, clampf(delta * 14.0, 0.0, 1.0))

	# Constant 3D attitude: subtle organic figure-8 sway + flight roll + airbrake/dive pitch
	var sway_amp: float = rig_config.idle_sway_amp if rig_config != null else 0.24
	var idle_roll: float = sin(_time * 1.45) * sway_amp
	var idle_pitch: float = cos(_time * 1.95) * (sway_amp * 0.75)

	var bank_max: float = rig_config.bank_max if rig_config != null else 0.85
	var flight_roll: float = clampf(angular_velocity_rad * 0.30, -1.0, 1.0) * bank_max
	var is_braking: bool = accel_norm < -0.35
	var brake_flare: float = clampf((-accel_norm - 0.35) * 0.8, 0.0, 1.0) if is_braking else 0.0
	var flight_pitch: float = clampf(forward_speed_norm * 0.32 - brake_flare * 0.52, -0.75, 0.75)

	var bite_pitch_add: float = 0.0
	if _bite_phase == 1:
		bite_pitch_add = -0.38
		_bite_timer -= delta
		if _bite_timer <= 0.0:
			_trigger_bite_impact_phase()
	elif _bite_phase == 2:
		bite_pitch_add = 0.52 * clampf(_bite_timer / 0.22, 0.0, 1.0)
		_bite_timer -= delta
		if _bite_timer <= 0.0:
			_bite_phase = 0

	var target_tilt := Vector2(
		clampf(_tilt_input.x + flight_roll + idle_roll * (1.0 - minf(forward_speed_norm, 1.0) * 0.5), -1.0, 1.0),
		clampf(_tilt_input.y + flight_pitch + idle_pitch * (1.0 - minf(forward_speed_norm, 1.0) * 0.5) + bite_pitch_add, -1.0, 1.0)
	)
	_tilt_smoothed = _tilt_smoothed.lerp(target_tilt, clampf(delta * 10.0, 0.0, 1.0))
	_tail_whip_smoothed = lerpf(_tail_whip_smoothed, clampf(-angular_velocity_rad * 0.25, -1.0, 1.0), clampf(delta * 8.0, 0.0, 1.0))

	# Periodic predator wing-check flare in Idle
	_idle_flare_timer -= delta
	if _idle_flare_timer <= 0.0:
		_idle_flare_timer = 3.6
		_idle_flare_pulse = 1.0
	_idle_flare_pulse = move_toward(_idle_flare_pulse, 0.0, delta * 1.45)

	var target_ely: float = 0.0
	var target_wing: float = 0.0
	var target_wing_alpha: float = 0.0
	var target_sec_em: float = 0.45
	var target_alert: float = 0.0
	var target_mandible_deg: float = (rig_config.mandible_rest_deg if rig_config != null else 0.0) + sin(_time * 4.2) * 3.5
	var target_leg_tuck: float = clampf(forward_speed_norm * 0.65, 0.0, 0.75)
	var flap_freq: float = 0.0
	var leg_amp: float = rig_config.leg_paddle_amp if rig_config != null else 6.0
	var leg_freq: float = rig_config.leg_paddle_freq if rig_config != null else 8.5
	var bob_offset: Vector2 = Vector2.ZERO
	var squash_scale: Vector2 = Vector2.ONE
	var hover_lift: float = 0.0

	match _state:
		AnimState.IDLE_HOVER:
			var flare_ease: float = sin(_idle_flare_pulse * PI) * 0.26
			target_ely = 0.05 + 0.04 * sin(_time * 2.4) + flare_ease + brake_flare * 0.35
			target_wing = flare_ease * 0.75
			target_wing_alpha = flare_ease * 2.1
			target_sec_em = 0.45 + flare_ease * 1.8
			flap_freq = 8.0 if flare_ease > 0.02 else 0.0
			bob_offset = Vector2(sin(_time * 1.4) * 3.0, sin(_time * 2.7) * 5.0)
			hover_lift = 4.0 * sin(_time * 2.7)
		AnimState.CRUISE_BANK:
			target_ely = 0.76 + 0.05 * sin(_time * 4.5) + brake_flare * 0.25
			target_wing = 0.62
			target_wing_alpha = 0.88
			target_sec_em = 0.90
			target_mandible_deg = -8.0 + sin(_time * 6.5) * 4.0
			flap_freq = (rig_config.wing_flap_freq if rig_config != null else 16.0) * 0.65
			leg_amp *= 1.35
			leg_freq *= 1.5
			bob_offset = Vector2(0.0, sin(_time * 5.2) * 2.5)
			hover_lift = 6.0
		AnimState.CHARGE_TELEGRAPH:
			target_ely = 1.0
			target_wing = 1.0
			target_wing_alpha = 1.0
			target_sec_em = 3.1 + 0.9 * sin(_time * 20.0)
			target_alert = 0.65 + 0.35 * sin(_time * 16.0)
			target_mandible_deg = (rig_config.mandible_open_deg if rig_config != null else -26.0) + sin(_time * 28.0) * 2.5
			target_leg_tuck = 0.2
			flap_freq = (rig_config.wing_flap_freq if rig_config != null else 16.0) * 1.15
			leg_amp *= 1.6
			leg_freq *= 1.8
			_tilt_smoothed.y = lerpf(_tilt_smoothed.y, -0.38, clampf(delta * 8.0, 0.0, 1.0))
			bob_offset = Vector2(sin(_time * 42.0) * 2.2, cos(_time * 46.0) * 2.2)
			hover_lift = 10.0
		AnimState.ATTACK_LUNGE:
			_lunge_timer = maxf(_lunge_timer - delta, 0.0)
			var t_l: float = _lunge_timer / 0.44
			target_ely = lerpf(0.75, 1.0, t_l)
			target_wing = lerpf(0.55, 1.0, t_l)
			target_wing_alpha = lerpf(0.85, 1.0, t_l)
			target_sec_em = lerpf(1.1, 3.8, t_l)
			target_alert = t_l * 0.85
			target_leg_tuck = 1.0
			flap_freq = (rig_config.wing_flap_freq if rig_config != null else 16.0) * 1.35
			squash_scale = Vector2(1.0 + 0.18 * t_l, 1.0 - 0.14 * t_l)
			bob_offset = Vector2(24.0 * t_l, 0.0)
			if _lunge_timer <= 0.001:
				_state = AnimState.CRUISE_BANK
		AnimState.DEATH_SHATTER:
			_shatter_elapsed += delta
			var dur: float = rig_config.shatter_duration if rig_config != null else 0.58
			_dissolve_val = clampf((_shatter_elapsed - 0.05) / maxf(dur, 0.1), 0.0, 1.0)
			for i: int in range(_shatter_nodes.size()):
				var sn: Node2D = _shatter_nodes[i]
				if sn != null:
					sn.position += _shatter_vels[i] * delta
					sn.rotation += _shatter_ang_vels[i] * delta

	if _bite_phase == 1:
		target_mandible_deg = rig_config.mandible_open_deg if rig_config != null else -26.0
		target_sec_em = maxf(target_sec_em, 2.4)
		target_ely = maxf(target_ely, 0.25)
	elif _bite_phase == 2:
		target_mandible_deg = rig_config.mandible_bite_deg if rig_config != null else 34.0
		target_sec_em = maxf(target_sec_em, 3.6)

	# Spring-damper physics on elytra, wings & scissor mandibles (dt-clamped for Euler stability)
	var spring_dt: float = minf(delta, 0.05)
	var spring_k: float = 115.0
	var damp_c: float = 13.5
	_ely_open_vel += ((target_ely - _ely_open_blend) * spring_k - _ely_open_vel * damp_c) * spring_dt
	_ely_open_blend = clampf(_ely_open_blend + _ely_open_vel * spring_dt, -0.08, 1.25)

	_wing_open_vel += ((target_wing - _wing_open_blend) * spring_k - _wing_open_vel * damp_c) * spring_dt
	_wing_open_blend = clampf(_wing_open_blend + _wing_open_vel * spring_dt, -0.05, 1.20)

	var mand_k: float = 260.0 if _bite_phase > 0 else 130.0
	var mand_c: float = 18.0 if _bite_phase > 0 else 14.0
	_mandible_deg_vel += ((target_mandible_deg - _mandible_deg_cur) * mand_k - _mandible_deg_vel * mand_c) * spring_dt
	_mandible_deg_cur = clampf(_mandible_deg_cur + _mandible_deg_vel * spring_dt, -45.0, 50.0)

	var rate: float = clampf(delta * 12.0, 0.0, 1.0)
	_wing_vis_alpha = lerpf(_wing_vis_alpha, target_wing_alpha, rate)
	_sec_emissive = lerpf(_sec_emissive, target_sec_em, rate)
	_alert_mix = lerpf(_alert_mix, target_alert, rate)
	_leg_tuck_smoothed = lerpf(_leg_tuck_smoothed, target_leg_tuck, clampf(delta * 10.0, 0.0, 1.0))

	if _visual_root != null and rig_config != null:
		_visual_root.position = bob_offset + _recoil_offset
		var base_s: float = rig_config.display_scale
		_visual_root.scale = _visual_root.scale.lerp(Vector2(base_s * squash_scale.x, base_s * squash_scale.y), clampf(delta * 14.0, 0.0, 1.0))

	# Update articulated rotations, inter-layer 2.5D parallax & directional cast shadows
	var core_light_val: float = 0.0
	if style_profile != null:
		core_light_val = (0.14 + maxf(_ely_open_blend, 0.0) * style_profile.core_light_strength) * (1.0 + maxf(_sec_emissive - 0.45, 0.0) * 0.18)

	if _wing_vis_alpha > 0.03 and flap_freq > 0.01:
		_wing_flap_phase += delta * flap_freq

	var target_wing_speed: float = 0.0
	var wind_state_boost: float = 0.0
	match _state:
		AnimState.CRUISE_BANK:
			target_wing_speed = 0.78 if _wing_open_blend > 0.42 else 0.0
			wind_state_boost = 0.75
		AnimState.CHARGE_TELEGRAPH:
			target_wing_speed = 1.0 if _wing_open_blend > 0.42 else 0.0
			wind_state_boost = 1.20
		AnimState.ATTACK_LUNGE:
			target_wing_speed = 1.15 if _wing_open_blend > 0.42 else 0.0
			wind_state_boost = 1.35

	var ramp_rate: float = 7.0 if target_wing_speed > _wing_speed_ramp else 9.0
	_wing_speed_ramp = move_toward(_wing_speed_ramp, target_wing_speed, delta * ramp_rate)
	var shutter_spd: float = rig_config.wing_shutter_speed if rig_config != null else 36.0
	if _wing_speed_ramp > 0.01:
		_wing_strobe_phase += delta * shutter_spd * (0.45 + 0.85 * clampf(_wing_speed_ramp, 0.0, 1.25))

	var ramp_01: float = clampf(_wing_speed_ramp, 0.0, 1.0)
	var blur_max_deg: float = rig_config.wing_blur_max_deg if rig_config != null else 20.0
	_wing_blur_arc_rad_cur = clampf(deg_to_rad(blur_max_deg) * _wing_speed_ramp, 0.0, 0.72)

	if rig_config != null and _state != AnimState.DEATH_SHATTER:
		# Scissor Mandibles (locked strictly to skull socket — zero parallax separation!)
		_mandible_r_pivot.rotation = -deg_to_rad(_mandible_deg_cur)
		_mandible_l_pivot.rotation = deg_to_rad(_mandible_deg_cur)

		var ely_deg: float = lerpf(rig_config.elytron_closed_deg, rig_config.elytron_open_deg, _ely_open_blend)
		var slow_sweep: float = sin(_wing_flap_phase) * rig_config.wing_flap_sweep_deg * maxf(_wing_open_blend, 0.0) * (1.0 - ramp_01 * 0.72)
		var strobe_jitter: float = clampf(sin(_wing_strobe_phase * 1.15) * 2.2, -1.0, 1.0) * 3.0 * ramp_01
		var wing_deg: float = lerpf(rig_config.wing_closed_deg, rig_config.wing_open_deg, _wing_open_blend) + slow_sweep + strobe_jitter
		_elytron_r_pivot.rotation = -deg_to_rad(ely_deg)
		_elytron_l_pivot.rotation = deg_to_rad(ely_deg)
		_wing_r_pivot.rotation = -deg_to_rad(wing_deg)
		_wing_l_pivot.rotation = deg_to_rad(wing_deg)

		var wing_flap_sy: float = rig_config.wing_scale * (1.0 - 0.06 * ramp_01 + 0.08 * cos(_wing_flap_phase) * maxf(_wing_open_blend, 0.0) * (1.0 - ramp_01 * 0.55))
		_wing_r_pivot.scale = Vector2(rig_config.wing_scale, wing_flap_sy)
		_wing_l_pivot.scale = Vector2(rig_config.wing_scale, wing_flap_sy)

		# Inter-layer 2.5D parallax offset for elytra & wings (mandibles stay welded to head!)
		var par_px: float = rig_config.layer_parallax_px
		var ely_par: Vector2 = _tilt_smoothed * par_px * (0.75 + maxf(_ely_open_blend, 0.0) * 0.75)
		var wing_par: Vector2 = _tilt_smoothed * (par_px * 0.45)

		_mandible_r_pivot.position = rig_config.mandible_offset
		_mandible_l_pivot.position = Vector2(-rig_config.mandible_offset.x, rig_config.mandible_offset.y)
		_elytron_r_pivot.position = rig_config.elytron_offset + ely_par
		_elytron_l_pivot.position = Vector2(-rig_config.elytron_offset.x, rig_config.elytron_offset.y) + ely_par
		_wing_r_pivot.position = rig_config.wing_offset + wing_par
		_wing_l_pivot.position = Vector2(-rig_config.wing_offset.x, rig_config.wing_offset.y) + wing_par

		# Tight body-seam contact shadow under closed elytra only (fades out completely in open space flight)
		var shadow_off_px: float = style_profile.cast_shadow_offset_px if style_profile != null else 18.0
		var local_sh_dir: Vector2 = (-_cur_light_dir_2d).rotated(-_art_up_root.global_rotation)
		var ely_open_pos_sh: float = maxf(_ely_open_blend, 0.0)
		var ely_elev: float = 3.5 + ely_open_pos_sh * 4.0
		var ely_sh_alpha: float = clampf(1.0 - ely_open_pos_sh * 0.92, 0.0, 1.0)
		var show_ely_seam_sh: bool = (_state != AnimState.DEATH_SHATTER and not _flat_baseline and _ely_open_blend < 0.85)

		if _ely_r_shadow_pivot != null:
			_ely_r_shadow_pivot.visible = show_ely_seam_sh
			_ely_r_shadow_pivot.modulate = Color(1.0, 1.0, 1.0, ely_sh_alpha)
			_ely_r_shadow_pivot.rotation = _elytron_r_pivot.rotation
			_ely_r_shadow_pivot.position = _elytron_r_pivot.position + local_sh_dir * ely_elev
		if _ely_l_shadow_pivot != null:
			_ely_l_shadow_pivot.visible = show_ely_seam_sh
			_ely_l_shadow_pivot.modulate = Color(1.0, 1.0, 1.0, ely_sh_alpha)
			_ely_l_shadow_pivot.rotation = _elytron_l_pivot.rotation
			_ely_l_shadow_pivot.position = _elytron_l_pivot.position + local_sh_dir * ely_elev

		if _mandible_l_shadow_pivot != null:
			_mandible_l_shadow_pivot.visible = false
		if _mandible_r_shadow_pivot != null:
			_mandible_r_shadow_pivot.visible = false

		if _under_shadow_mesh != null:
			_under_shadow_mesh.visible = _floor_shadow_enabled and _state != AnimState.DEATH_SHATTER and not _flat_baseline
			if _under_shadow_mesh.visible:
				_under_shadow_mesh.position = local_sh_dir * (shadow_off_px + hover_lift)
				var floor_s: float = 1.02 - clampf(hover_lift * 0.008, -0.06, 0.10)
				_under_shadow_mesh.scale = Vector2(floor_s, floor_s)

	if _thruster_particles != null:
		_thruster_particles.emitting = (_state != AnimState.DEATH_SHATTER) and not _flat_baseline
		var vel_mult: float = 1.8 if (_state == AnimState.CRUISE_BANK or _state == AnimState.ATTACK_LUNGE or forward_speed_norm > 0.35) else (1.4 if _state == AnimState.CHARGE_TELEGRAPH else 0.75)
		_thruster_particles.speed_scale = vel_mult
	if _core_glow_poly != null:
		_core_glow_poly.visible = not _flat_baseline and (_state != AnimState.DEATH_SHATTER)
		var glow_a: float = clampf(0.18 + maxf(_ely_open_blend, 0.0) * 0.75 + (_sec_emissive - 0.45) * 0.15, 0.15, 1.0)
		_core_glow_poly.modulate = Color(1.0, 1.0, 1.0, glow_a)

	_step_flight_ribbons(forward_speed_norm)

	# 3D Carapace hinge angles + procedural 3D dorsal crystal
	var open_pos: float = maxf(_ely_open_blend, 0.0)
	var pitch_cfg: float = rig_config.elytron_open_pitch_deg if rig_config != null else 46.0
	var roll_cfg: float = rig_config.elytron_open_roll_deg if rig_config != null else 22.0
	var lift_cfg: float = rig_config.elytron_lift_px if rig_config != null else 14.0
	_ely_pitch_rad_cur = deg_to_rad(pitch_cfg) * open_pos
	_ely_roll_rad_cur = deg_to_rad(roll_cfg) * open_pos
	var ely_lift_z: float = lift_cfg * 1.75 * open_pos
	var ely_hinge_on: bool = (_state != AnimState.DEATH_SHATTER)
	var ely_3d_l := Vector3(-_ely_roll_rad_cur, _ely_pitch_rad_cur, ely_lift_z) if ely_hinge_on else Vector3.ZERO
	var ely_3d_r := Vector3(_ely_roll_rad_cur, _ely_pitch_rad_cur, ely_lift_z) if ely_hinge_on else Vector3.ZERO

	if _pivot_gizmo != null:
		_pivot_gizmo.update_pivots(
			_elytron_l_pivot.position,
			_elytron_r_pivot.position,
			_wing_l_pivot.position,
			_wing_r_pivot.position,
			_show_pivots and _state != AnimState.DEATH_SHATTER
		)

	# Push shader parameters to all 7 main meshes (including local ArtUpRoot coords for core point light)
	for i: int in range(_part_meshes.size()):
		var mi: MeshInstance2D = _part_meshes[i]
		var mat: ShaderMaterial = _part_mats[i]
		if mi == null or mat == null:
			continue
		if i == 3 or i == 4:
			var w_vis: bool = _wing_vis_alpha > 0.02
			mi.visible = w_vis
			mi.modulate = Color(1.0, 1.0, 1.0, clampf(_wing_vis_alpha * lerpf(1.0, 0.86, ramp_01), 0.0, 1.0))
			mat.set_shader_parameter("wing_blur_arc_rad", _wing_blur_arc_rad_cur)
			mat.set_shader_parameter("wing_shutter_intensity", _wing_speed_ramp)
			mat.set_shader_parameter("wing_strobe_phase", _wing_strobe_phase)
		elif i == 5 or i == 6:
			var is_r_ely: bool = (i == 6)
			var piv_e: Node2D = _elytron_r_pivot if is_r_ely else _elytron_l_pivot
			mat.set_shader_parameter("ely_hinge_active", ely_hinge_on)
			mat.set_shader_parameter("ely_open_3d", ely_3d_r if is_r_ely else ely_3d_l)
			mat.set_shader_parameter("ely_hinge_art_pos", piv_e.position)
			mat.set_shader_parameter("ely_yaw_rad", piv_e.rotation)
			if rig_config != null:
				mat.set_shader_parameter("ely_scale", rig_config.elytron_scale)
				mat.set_shader_parameter("ely_dome_height_px", rig_config.elytron_dome_height_px)
				mat.set_shader_parameter("ely_rim_thickness_px", rig_config.elytron_rim_thickness_px)

		var piece_tilt: Vector2 = _tilt_smoothed
		if i == 3 or i == 4:
			piece_tilt.y = clampf(_tilt_smoothed.y + cos(_wing_flap_phase) * 0.25 * maxf(_wing_open_blend, 0.0), -1.0, 1.0)

		var art_pos: Vector2 = _art_up_root.to_local(mi.global_position)
		var art_rot: float = mi.global_rotation - _art_up_root.global_rotation

		mat.set_shader_parameter("sprite_rotation_rad", mi.global_rotation)
		mat.set_shader_parameter("tilt_25d", piece_tilt)
		mat.set_shader_parameter("piece_art_pos", art_pos)
		mat.set_shader_parameter("piece_art_rot", art_rot)
		mat.set_shader_parameter("core_light_intensity", core_light_val)
		mat.set_shader_parameter("motion_time", _time)
		mat.set_shader_parameter("leg_paddle_amp", leg_amp)
		mat.set_shader_parameter("leg_paddle_freq", leg_freq)
		mat.set_shader_parameter("leg_tuck", _leg_tuck_smoothed)
		mat.set_shader_parameter("tail_whip", _tail_whip_smoothed)
		mat.set_shader_parameter("wing_flap_phase", _wing_flap_phase)
		mat.set_shader_parameter("secondary_emissive_strength", _sec_emissive)
		mat.set_shader_parameter("outer_alert_mix", _alert_mix)
		mat.set_shader_parameter("hit_flash", _hit_flash_val)
		mat.set_shader_parameter("dissolve_amount", _dissolve_val)

	# Sync all 7 extrusion thickness shells with exact same 3D tilt & deformation
	for bmat: ShaderMaterial in _body_shell_mats:
		if bmat == null:
			continue
		bmat.set_shader_parameter("sprite_rotation_rad", _body_mesh.global_rotation)
		bmat.set_shader_parameter("tilt_25d", _tilt_smoothed)
		bmat.set_shader_parameter("motion_time", _time)
		bmat.set_shader_parameter("leg_paddle_amp", leg_amp)
		bmat.set_shader_parameter("leg_paddle_freq", leg_freq)
		bmat.set_shader_parameter("leg_tuck", _leg_tuck_smoothed)
		bmat.set_shader_parameter("tail_whip", _tail_whip_smoothed)
		bmat.set_shader_parameter("hit_flash", _hit_flash_val)
		bmat.set_shader_parameter("dissolve_amount", _dissolve_val)

	var l_shell_count: int = _elytron_l_shells.size()
	for s_i: int in range(_elytron_shell_mats.size()):
		var emat: ShaderMaterial = _elytron_shell_mats[s_i]
		if emat == null:
			continue
		var is_r_sh: bool = s_i >= l_shell_count
		var ref_mi: MeshInstance2D = _elytron_r_mesh if is_r_sh else _elytron_l_mesh
		var piv_sh: Node2D = _elytron_r_pivot if is_r_sh else _elytron_l_pivot
		emat.set_shader_parameter("sprite_rotation_rad", ref_mi.global_rotation)
		emat.set_shader_parameter("tilt_25d", _tilt_smoothed)
		emat.set_shader_parameter("core_light_intensity", core_light_val)
		emat.set_shader_parameter("ely_hinge_active", ely_hinge_on)
		emat.set_shader_parameter("ely_open_3d", ely_3d_r if is_r_sh else ely_3d_l)
		emat.set_shader_parameter("ely_hinge_art_pos", piv_sh.position)
		emat.set_shader_parameter("ely_yaw_rad", piv_sh.rotation)
		if rig_config != null:
			emat.set_shader_parameter("ely_scale", rig_config.elytron_scale)
			emat.set_shader_parameter("ely_dome_height_px", rig_config.elytron_dome_height_px)
			emat.set_shader_parameter("ely_rim_thickness_px", rig_config.elytron_rim_thickness_px)
		emat.set_shader_parameter("hit_flash", _hit_flash_val)
		emat.set_shader_parameter("dissolve_amount", _dissolve_val)

	# Sync concave interior bowls (backface curved shell behind thin rim)
	var inner_meshes: Array[MeshInstance2D] = [_elytron_l_inner_mesh, _elytron_r_inner_mesh]
	var inner_vis: bool = not _flat_baseline and _debug_view_mode == 0
	for in_i: int in range(inner_meshes.size()):
		var in_mi: MeshInstance2D = inner_meshes[in_i]
		var in_mat: ShaderMaterial = _elytron_inner_mats[in_i] if in_i < _elytron_inner_mats.size() else null
		if in_mi == null or in_mat == null:
			continue
		in_mi.visible = inner_vis
		var is_r_in: bool = (in_i == 1)
		var piv_in: Node2D = _elytron_r_pivot if is_r_in else _elytron_l_pivot
		in_mat.set_shader_parameter("sprite_rotation_rad", in_mi.global_rotation)
		in_mat.set_shader_parameter("tilt_25d", _tilt_smoothed)
		in_mat.set_shader_parameter("core_light_intensity", core_light_val)
		in_mat.set_shader_parameter("ely_hinge_active", ely_hinge_on)
		in_mat.set_shader_parameter("ely_open_3d", ely_3d_r if is_r_in else ely_3d_l)
		in_mat.set_shader_parameter("ely_hinge_art_pos", piv_in.position)
		in_mat.set_shader_parameter("ely_yaw_rad", piv_in.rotation)
		if rig_config != null:
			in_mat.set_shader_parameter("ely_scale", rig_config.elytron_scale)
			in_mat.set_shader_parameter("ely_dome_height_px", rig_config.elytron_dome_height_px)
			in_mat.set_shader_parameter("ely_rim_thickness_px", rig_config.elytron_rim_thickness_px)
		in_mat.set_shader_parameter("motion_time", _time)
		in_mat.set_shader_parameter("outer_alert_mix", _alert_mix)
		in_mat.set_shader_parameter("hit_flash", _hit_flash_val)
		in_mat.set_shader_parameter("dissolve_amount", _dissolve_val)

	# 2 stroboscopic extreme afterimages per side (Upper & Lower dwell silhouettes)
	var strobe_ext_deg: float = rig_config.wing_strobe_extreme_deg if rig_config != null else 16.0
	var ext_rad: float = deg_to_rad(strobe_ext_deg) * clampf(_wing_speed_ramp, 0.0, 1.2)
	if _wing_r_ghost_a_pivot != null:
		_wing_r_ghost_a_pivot.rotation = -ext_rad
	if _wing_r_ghost_b_pivot != null:
		_wing_r_ghost_b_pivot.rotation = ext_rad
	if _wing_l_ghost_a_pivot != null:
		_wing_l_ghost_a_pivot.rotation = ext_rad
	if _wing_l_ghost_b_pivot != null:
		_wing_l_ghost_b_pivot.rotation = -ext_rad

	var strobe_step: float = clampf(sin(_wing_strobe_phase) * 2.1, -1.0, 1.0)
	var strobe_alpha_cfg: float = rig_config.wing_strobe_alpha if rig_config != null else 0.34
	var strobe_base: float = _wing_vis_alpha * clampf(_wing_speed_ramp, 0.0, 1.15) * strobe_alpha_cfg
	var alpha_upper: float = clampf(strobe_base * lerpf(0.28, 1.0, 0.5 + 0.5 * strobe_step), 0.0, 0.52)
	var alpha_lower: float = clampf(strobe_base * lerpf(0.28, 1.0, 0.5 - 0.5 * strobe_step), 0.0, 0.52)
	var ghost_meshes: Array[MeshInstance2D] = [_wing_l_ghost_a, _wing_l_ghost_b, _wing_r_ghost_a, _wing_r_ghost_b]
	var ghost_alphas: Array[float] = [alpha_upper, alpha_lower, alpha_upper, alpha_lower]
	for g_i: int in range(ghost_meshes.size()):
		var g_mi: MeshInstance2D = ghost_meshes[g_i]
		var g_mat: ShaderMaterial = _ghost_mats[g_i] if g_i < _ghost_mats.size() else null
		if g_mi == null or g_mat == null:
			continue
		var ga: float = ghost_alphas[g_i]
		var g_show: bool = ga > 0.02 and _state != AnimState.DEATH_SHATTER and not _flat_baseline and _debug_view_mode == 0
		g_mi.visible = g_show
		g_mi.modulate = Color(1.0, 1.0, 1.0, ga)
		g_mat.set_shader_parameter("sprite_rotation_rad", g_mi.global_rotation)
		g_mat.set_shader_parameter("tilt_25d", _tilt_smoothed)
		g_mat.set_shader_parameter("motion_time", _time)
		g_mat.set_shader_parameter("wing_flap_phase", _wing_flap_phase)
		g_mat.set_shader_parameter("wing_blur_arc_rad", _wing_blur_arc_rad_cur * 0.42)
		g_mat.set_shader_parameter("wing_shutter_intensity", _wing_speed_ramp * 0.85)
		g_mat.set_shader_parameter("wing_strobe_phase", _wing_strobe_phase + (1.57 if (g_i % 2 == 1) else 0.0))
		g_mat.set_shader_parameter("secondary_emissive_strength", _sec_emissive)

	if _wing_buzz_vfx != null and rig_config != null:
		var arcs_active: bool = _state != AnimState.DEATH_SHATTER and not _flat_baseline and _debug_view_mode == 0 and _wing_vis_alpha > 0.25
		_wing_buzz_vfx.update_arcs(
			_wing_speed_ramp,
			rig_config.wing_wind_arcs_strength,
			wind_state_boost,
			_wing_strobe_phase,
			_wing_l_pivot.position,
			_wing_r_pivot.position,
			_wing_l_pivot.rotation,
			_wing_r_pivot.rotation,
			rig_config.wing_scale,
			maxf(_wing_blur_arc_rad_cur, ext_rad),
			arcs_active
		)

	# Cast shadow meshes follow exact body/elytron/mandible tilt
	if _under_shadow_mat != null:
		_under_shadow_mat.set_shader_parameter("tilt_25d", _tilt_smoothed)
		_under_shadow_mat.set_shader_parameter("motion_time", _time)
		_under_shadow_mat.set_shader_parameter("leg_paddle_amp", leg_amp)
		_under_shadow_mat.set_shader_parameter("leg_paddle_freq", leg_freq)
		_under_shadow_mat.set_shader_parameter("leg_tuck", _leg_tuck_smoothed)
		_under_shadow_mat.set_shader_parameter("tail_whip", _tail_whip_smoothed)
	for s_k: int in range(_ely_shadow_mats.size()):
		var smat: ShaderMaterial = _ely_shadow_mats[s_k]
		if smat != null:
			var is_r_s: bool = (s_k == 1)
			var sh_piv: Node2D = _ely_r_shadow_pivot if is_r_s else _ely_l_shadow_pivot
			var e3: Vector3 = ely_3d_r if is_r_s else ely_3d_l
			smat.set_shader_parameter("tilt_25d", _tilt_smoothed)
			smat.set_shader_parameter("ely_hinge_active", ely_hinge_on)
			smat.set_shader_parameter("ely_open_3d", Vector3(e3.x * 0.45, e3.y * 0.45, 0.0))
			smat.set_shader_parameter("ely_hinge_art_pos", sh_piv.position)
			smat.set_shader_parameter("ely_yaw_rad", sh_piv.rotation)
	for mmat: ShaderMaterial in _mandible_shadow_mats:
		if mmat != null:
			mmat.set_shader_parameter("tilt_25d", _tilt_smoothed)


func _step_flight_ribbons(forward_speed_norm: float) -> void:
	if _ribbon_l == null or _ribbon_r == null or _ribbon_l_tip == null or _ribbon_r_tip == null:
		return
	var show_trails: bool = (forward_speed_norm > 0.18 or _state == AnimState.ATTACK_LUNGE) and _state != AnimState.DEATH_SHATTER and not _flat_baseline
	_ribbon_l.visible = show_trails or not _ribbon_pts_l.is_empty()
	_ribbon_r.visible = show_trails or not _ribbon_pts_r.is_empty()

	if show_trails:
		_ribbon_pts_l.append(_ribbon_l_tip.global_position)
		_ribbon_pts_r.append(_ribbon_r_tip.global_position)
		if _ribbon_pts_l.size() > 18:
			_ribbon_pts_l.remove_at(0)
		if _ribbon_pts_r.size() > 18:
			_ribbon_pts_r.remove_at(0)
	else:
		if not _ribbon_pts_l.is_empty():
			_ribbon_pts_l.remove_at(0)
		if not _ribbon_pts_r.is_empty():
			_ribbon_pts_r.remove_at(0)

	_ribbon_l.points = _ribbon_pts_l
	_ribbon_r.points = _ribbon_pts_r


func get_part_meshes() -> Array[MeshInstance2D]:
	return _part_meshes


func get_shell_meshes() -> Array[MeshInstance2D]:
	return _shell_meshes


func get_elytron_open_rad() -> float:
	return absf(_elytron_r_pivot.rotation) if _elytron_r_pivot != null else 0.0


func get_mandible_bite_rad() -> float:
	# Positive radians = closed/crossed inward bite; negative = spread wide open
	return -_mandible_r_pivot.rotation if _mandible_r_pivot != null else 0.0


func get_under_shadow_mesh() -> MeshInstance2D:
	return _under_shadow_mesh


func get_elytron_shadow_pivots() -> Array[Node2D]:
	return [_ely_l_shadow_pivot, _ely_r_shadow_pivot]


func get_wing_shutter_state() -> Dictionary:
	return {
		"speed_ramp": _wing_speed_ramp,
		"blur_arc_rad": _wing_blur_arc_rad_cur,
		"strobe_upper_visible": _wing_r_ghost_a != null and _wing_r_ghost_a.visible and _wing_l_ghost_a != null and _wing_l_ghost_a.visible,
		"strobe_lower_visible": _wing_r_ghost_b != null and _wing_r_ghost_b.visible and _wing_l_ghost_b != null and _wing_l_ghost_b.visible,
		"strobe_upper_alpha": _wing_r_ghost_a.modulate.a if _wing_r_ghost_a != null else 0.0,
		"strobe_lower_alpha": _wing_r_ghost_b.modulate.a if _wing_r_ghost_b != null else 0.0,
		"wind_arcs_visible": _wing_buzz_vfx != null and _wing_buzz_vfx.is_arcs_visible(),
	}


func get_carapace_3d_state() -> Dictionary:
	return {
		"ely_pitch_rad": _ely_pitch_rad_cur,
		"ely_roll_rad": _ely_roll_rad_cur,
		"ely_shell_count": _elytron_l_shells.size() + _elytron_r_shells.size(),
		"inner_bowl_count": _elytron_inner_mats.size(),
	}
