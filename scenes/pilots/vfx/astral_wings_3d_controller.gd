class_name AstralWings3DController
extends Node2D
## Controlador de Alas Psíquicas 3D Cel-Shaded "Astral Seraph" (3D Lab — Valentina v2).
## Usa 2 SubViewports sincronizados (Pasada Trasera z=3 y Pasada Delantera z=7) para que
## cada una de las 12 cuchillas 3D cruce suavemente detrás o delante del piloto 2D (z=5)
## según su profundidad Z real, proyectando las puntas 3D→2D para estelas HDR y disparos.

const ToonShader = preload("res://scenes/pilots/shaders/astral_wing_toon_3d.gdshader")
const OutlineShader = preload("res://scenes/pilots/shaders/astral_wing_outline_3d.gdshader")
const Post2DShader = preload("res://scenes/pilots/shaders/astral_wing_post_2d.gdshader")
const MeshBuilderScript = preload("res://scenes/pilots/vfx/astral_wings_3d_mesh_builder.gd")
const ConfigScript = preload("res://data/pilots/schemas/pilot_wings_3d_config.gd")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")

const VIEW_YAW_RAD: Dictionary = {
	"s": 0.0,
	"se": PI * 0.25,
	"e": PI * 0.5,
	"ne": PI * 0.75,
	"n": PI,
	"nw": -PI * 0.75,
	"w": -PI * 0.5,
	"sw": -PI * 0.25,
}

enum AnimState {
	IDLE_ZERO_G = 0,
	CRUISE_BOOST = 1,
	SERAPH_BLOOM = 2,
	AEGIS_GUARD = 3,
	FULL_BURST = 4,
	VORTEX_SPIN = 5,
	SERAPH_FOLD = 6,
}

const ANIM_LABELS: Array[String] = [
	"1 · Flotación Zero-G",
	"2 · Crucero / Boost",
	"3 · Despliegue Serafín",
	"4 · Escudo Aegis 3D",
	"5 · Salva Full Burst (Apunta Mouse)",
	"6 · Vórtice 360° (Giroscopio)",
	"7 · Repliegue Serafín",
]

const BLADES_PER_WING: int = 6
const TOTAL_BLADES: int = 12
const VIEWPORT_PX: int = 768
const VIEWPORT_REF_PX: float = 512.0
const CAMERA_FOV_DEG: float = 32.0
const CAMERA_DIST_Z: float = 14.5

const SLOT_TIERS: Array[int] = [0, 1, 1, 2, 2, 2]
# Escalas y geometría en reposo calibradas 1:1 con wings_metadata.json (wing_0deg_r_s0..s5)
const SLOT_SCALES: Array[float] = [1.00, 0.98, 0.82, 0.98, 0.92, 0.95]
const SLOT_REST_OFFSETS: Array[Vector2] = [
	Vector2(0.00, 0.00),   # s0: brazo cristalino principal
	Vector2(0.41, 0.30),   # s1: daga superior bajo s0
	Vector2(0.38, 0.15),   # s2: daga media-alta
	Vector2(0.32, 0.06),   # s3: daga media-baja
	Vector2(0.20, -0.01),  # s4: daga inferior media
	Vector2(0.07, -0.07),  # s5: daga inferior descendente
]
const SLOT_REST_ANGLES_DEG: Array[float] = [48.8, 31.2, 12.3, -15.4, -37.3, -61.3]

const BASE_ARMOR_COLOR := Color(0.92, 0.95, 1.00, 1.0)
const BASE_CHASSIS_COLOR := Color(0.14, 0.18, 0.28, 1.0)
const BASE_CRYSTAL_COLOR := Color(0.94, 0.16, 0.34, 1.0)
const BASE_SHADOW_TINT := Color(0.46, 0.50, 0.72, 1.0)
const BASE_KEY_LIGHT_DIR := Vector3(-0.48, 0.68, 0.55)

const MAX_STARDUST: int = 72
const MAX_TRACERS: int = 36


class _BladeSlot:
	var index: int = 0
	var side: int = 1 # -1 izquierda, +1 derecha
	var slot: int = 0 # 0..5 de arriba hacia abajo
	var tier: int = 0
	var base_scale: float = 1.0
	var back_mesh: MeshInstance3D = null
	var front_mesh: MeshInstance3D = null
	var mats: Array[ShaderMaterial] = []
	var outline_mat: ShaderMaterial = null
	var cur_pos: Vector3 = Vector3.ZERO
	var cur_basis: Basis = Basis.IDENTITY
	var cur_scale: Vector3 = Vector3.ONE
	var is_front: bool = false
	var world_z: float = -0.5
	var recoil: float = 0.0
	var fire_flash: float = 0.0
	var tip_2d: Vector2 = Vector2.ZERO
	var trail_points: Array[Vector2] = []
	var trail_line: Line2D = null


class _WingFXOverlay extends Node2D:
	var owner_ctrl: AstralWings3DController = null
	var is_front_layer: bool = true

	func _draw() -> void:
		if owner_ctrl != null:
			owner_ctrl._draw_fx_layer(self, is_front_layer)


var _config: ConfigScript = null
var _anim_state: AnimState = AnimState.IDLE_ZERO_G
var _time: float = 0.0
var _anim_state_time: float = 0.0

var _pilot_yaw_rad: float = 0.0
var _pilot_velocity_2d: Vector2 = Vector2.ZERO
var _mouse_target_local: Vector2 = Vector2(220.0, 0.0)
var _light_yaw_rad: float = 0.0
var _auto_light_orbit: bool = false
var _auto_fire_burst: bool = true
var _burst_fire_timer: float = 0.0
var _burst_next_blade: int = 0
var _global_pulse: float = 0.0

var _active_skin_id: String = "base"
var _skin_recolor: bool = false
var _skin_accent: Color = BASE_CRYSTAL_COLOR
var _skin_panel: Color = BASE_ARMOR_COLOR
var _skin_dark: Color = BASE_CHASSIS_COLOR
var _active_glow_color: Color = BASE_CRYSTAL_COLOR
var _star_emissive_mult: float = 1.0

var _back_vp: SubViewport = null
var _front_vp: SubViewport = null
var _back_cam: Camera3D = null
var _front_cam: Camera3D = null
var _back_sprite: Sprite2D = null
var _front_sprite: Sprite2D = null
var _post_mat_back: ShaderMaterial = null
var _post_mat_front: ShaderMaterial = null
var _fx_back: _WingFXOverlay = null
var _fx_front: _WingFXOverlay = null

var _blades: Array[_BladeSlot] = []
var _stardust: Array[Dictionary] = []
var _stardust_accum: float = 0.0
var _tracers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

var _front_count_cache: int = 0
var _back_count_cache: int = TOTAL_BLADES
var _total_tris_cache: int = 0

var _z_back_fx: int = 2
var _z_back_wings: int = 3
var _z_front_wings: int = 7
var _z_front_fx: int = 8

var _cosmic_active: bool = false
var _cosmic_light_dir: Vector3 = BASE_KEY_LIGHT_DIR
var _cosmic_key_tint: Color = Color.WHITE
var _cosmic_key_boost: float = 1.04
var _cosmic_shadow_tint: Color = BASE_SHADOW_TINT
var _cosmic_emissive_mult: float = 1.0
var _manual_anim_override: bool = false
var _world_delta_pending: Vector2 = Vector2.ZERO


func _ready() -> void:
	_rng.seed = 20260707
	if _config == null:
		_config = ConfigScript.new()
	_config.ensure_defaults()
	_active_glow_color = _config.fire_glow_color

	_build_viewports()
	_build_blades()
	_build_fx_layers()
	_update_camera_elev()
	_apply_palette_to_all_blades()
	step(0.0, true)


func set_config(cfg: ConfigScript) -> void:
	_config = cfg if cfg != null else ConfigScript.new()
	_config.ensure_defaults()
	_active_glow_color = _skin_accent if (_skin_recolor and _config.follow_skin_palette) else _config.fire_glow_color
	if is_inside_tree():
		_update_camera_elev()
		_apply_palette_to_all_blades()


func get_config() -> ConfigScript:
	return _config


func set_anim_state(state: int, snap_now: bool = false) -> void:
	var clamped: int = clampi(state, AnimState.IDLE_ZERO_G, AnimState.SERAPH_FOLD)
	_anim_state = clamped as AnimState
	_anim_state_time = 0.0
	_manual_anim_override = (
		_anim_state != AnimState.IDLE_ZERO_G
		and _anim_state != AnimState.CRUISE_BOOST
	)
	if _anim_state == AnimState.SERAPH_BLOOM:
		_global_pulse = 1.15
	if snap_now and is_inside_tree():
		step(0.0, true)


func is_fold_complete() -> bool:
	return _anim_state == AnimState.SERAPH_FOLD and _anim_state_time >= 0.40


func clear_manual_anim_override() -> void:
	_manual_anim_override = false


func is_wings_mounted() -> bool:
	return not _blades.is_empty()


func set_viewports_active(active: bool) -> void:
	var mode: SubViewport.UpdateMode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if _back_vp != null and is_instance_valid(_back_vp) and _back_vp.render_target_update_mode != mode:
		_back_vp.render_target_update_mode = mode
	if _front_vp != null and is_instance_valid(_front_vp) and _front_vp.render_target_update_mode != mode:
		_front_vp.render_target_update_mode = mode


func set_z_layer_offsets(back_fx_z: int, back_z: int, front_z: int, front_fx_z: int) -> void:
	_z_back_fx = back_fx_z
	_z_back_wings = back_z
	_z_front_wings = front_z
	_z_front_fx = front_fx_z
	if _back_sprite != null:
		_back_sprite.z_index = _z_back_wings
	if _front_sprite != null:
		_front_sprite.z_index = _z_front_wings
	if _fx_back != null:
		_fx_back.z_index = _z_back_fx
	if _fx_front != null:
		_fx_front.z_index = _z_front_fx


func apply_cosmic_lighting(sample: CosmicLightingSampleScript) -> void:
	if sample == null:
		_cosmic_active = false
		_cosmic_light_dir = BASE_KEY_LIGHT_DIR.normalized()
		_cosmic_key_tint = Color.WHITE
		_cosmic_key_boost = 1.04
		_cosmic_shadow_tint = BASE_SHADOW_TINT
		_cosmic_emissive_mult = 1.0
		return

	_cosmic_active = true
	_cosmic_light_dir = sample.light_dir_3d.normalized() if sample.light_dir_3d.length_squared() > 0.0001 else BASE_KEY_LIGHT_DIR.normalized()
	_cosmic_key_tint = Color.WHITE.lerp(sample.key_light_tint, clampf(sample.star_tint_weight, 0.0, 1.0))
	var eclipse: float = clampf(sample.eclipse_factor, 0.0, 1.0)
	var floor_v: float = clampf(sample.visibility_floor, 0.25, 1.0)
	_cosmic_key_boost = maxf(
		1.04 * (1.0 + clampf(sample.star_proximity, 0.0, 1.0) * 0.12) * lerpf(1.0, floor_v, eclipse),
		floor_v
	)
	_cosmic_shadow_tint = BASE_SHADOW_TINT.lerp(sample.shadow_tint.lightened(0.32), clampf(sample.biome_shadow_weight, 0.0, 1.0))
	_cosmic_emissive_mult = maxf(sample.emissive_boost_mult, 1.0)


func step_attached_rig(
	delta: float,
	view_key: String,
	speed_norm: float,
	velocity_world: Vector2,
	is_turbo: bool,
	delta_world_pos: Vector2,
	snap_now: bool = false
) -> void:
	var target_yaw: float = float(VIEW_YAW_RAD.get(view_key, 0.0))
	if snap_now:
		_pilot_yaw_rad = target_yaw
	else:
		var yaw_diff: float = wrapf(target_yaw - _pilot_yaw_rad, -PI, PI)
		_pilot_yaw_rad = wrapf(_pilot_yaw_rad + yaw_diff * clampf(delta * 12.0, 0.0, 1.0), -PI, PI)

	if not _manual_anim_override:
		var want_boost: bool = is_turbo or speed_norm > 0.68
		var next_state: AnimState = AnimState.CRUISE_BOOST if want_boost else AnimState.IDLE_ZERO_G
		if next_state != _anim_state:
			_anim_state = next_state
			_anim_state_time = 0.0

	_pilot_velocity_2d = velocity_world
	_world_delta_pending = delta_world_pos
	step(delta, snap_now)
	_world_delta_pending = Vector2.ZERO


func get_anim_state() -> int:
	return int(_anim_state)


func set_pilot_yaw_rad(yaw_rad: float) -> void:
	_pilot_yaw_rad = yaw_rad


func get_pilot_yaw_rad() -> float:
	return _pilot_yaw_rad


func set_pilot_velocity_2d(vel: Vector2) -> void:
	_pilot_velocity_2d = vel


func set_mouse_target_local(local_pos: Vector2) -> void:
	_mouse_target_local = local_pos


func set_auto_light_orbit(enabled: bool) -> void:
	_auto_light_orbit = enabled
	if not enabled:
		_light_yaw_rad = 0.0


func set_auto_fire_burst(enabled: bool) -> void:
	_auto_fire_burst = enabled


func apply_skin_preset(skin: PilotSkinPreset, star_level: int = 1) -> void:
	var clamped_stars: int = clampi(star_level, 1, 3)
	if clamped_stars == 2:
		_star_emissive_mult = 1.22
	elif clamped_stars >= 3:
		_star_emissive_mult = 1.48
	else:
		_star_emissive_mult = 1.0
	if skin == null or skin.is_base_skin:
		_active_skin_id = "base"
		_skin_recolor = false
		_skin_accent = BASE_CRYSTAL_COLOR
		_skin_panel = BASE_ARMOR_COLOR
		_skin_dark = BASE_CHASSIS_COLOR
	else:
		_active_skin_id = skin.id if not skin.id.is_empty() else "base"
		_skin_recolor = true
		_skin_accent = skin.accent_color
		_skin_panel = skin.panel_color
		_skin_dark = skin.suit_dark_color
	_active_glow_color = _skin_accent if (_skin_recolor and _config != null and _config.follow_skin_palette) else (_config.fire_glow_color if _config != null else BASE_CRYSTAL_COLOR)
	_apply_palette_to_all_blades()


func get_active_skin_id() -> String:
	return _active_skin_id


func trigger_pulse(blade_index: int = -1) -> void:
	if _blades.is_empty():
		return
	if blade_index >= 0 and blade_index < _blades.size():
		_fire_single_blade(_blades[blade_index])
		return

	_global_pulse = 1.45
	if _anim_state == AnimState.SERAPH_BLOOM:
		_anim_state_time = 0.0
	for b: _BladeSlot in _blades:
		_fire_single_blade(b)


func step(delta: float, snap_now: bool = false) -> void:
	if _config == null or _blades.is_empty():
		return

	var dt: float = maxf(delta, 0.0)
	_time += dt
	_anim_state_time += dt
	_global_pulse = maxf(0.0, _global_pulse - dt * 2.6)

	if _auto_light_orbit:
		_light_yaw_rad = wrapf(_light_yaw_rad + dt * 1.1, -PI, PI)

	_update_camera_elev()
	_sync_sprite_transforms()

	# Disparo secuencial automático en modo FULL_BURST
	if _anim_state == AnimState.FULL_BURST and _auto_fire_burst and dt > 0.0:
		_burst_fire_timer += dt
		if _burst_fire_timer >= _config.full_burst_fire_interval:
			_burst_fire_timer = 0.0
			_fire_single_blade(_blades[_burst_next_blade % TOTAL_BLADES])
			_burst_next_blade = (_burst_next_blade + 1) % TOTAL_BLADES

	var key_dir: Vector3 = _compute_key_light_dir()
	var smooth_t: float = 1.0 if snap_now else clampf(dt * 10.5, 0.0, 1.0)
	var front_count: int = 0
	var back_count: int = 0

	for b: _BladeSlot in _blades:
		b.recoil = maxf(0.0, b.recoil - dt * _config.recoil_recover_rate)
		b.fire_flash = maxf(0.0, b.fire_flash - dt * 4.8)

		var target: Dictionary = _evaluate_blade_target(b)
		var tgt_pos: Vector3 = target["pos"] as Vector3
		var tgt_basis: Basis = (target["basis"] as Basis).orthonormalized()
		var tgt_scale: Vector3 = target["scale"] as Vector3

		if snap_now:
			b.cur_pos = tgt_pos
			b.cur_basis = tgt_basis
			b.cur_scale = tgt_scale
		else:
			b.cur_pos = b.cur_pos.lerp(tgt_pos, smooth_t)
			var q_cur: Quaternion = b.cur_basis.get_rotation_quaternion()
			var q_tgt: Quaternion = tgt_basis.get_rotation_quaternion()
			b.cur_basis = Basis(q_cur.slerp(q_tgt, smooth_t)).orthonormalized()
			b.cur_scale = b.cur_scale.lerp(tgt_scale, smooth_t)

		# Aplicar recoil axial sobre la orientación actual
		var final_pos: Vector3 = b.cur_pos - b.cur_basis.x * (b.recoil * _config.recoil_kick_units)
		var final_xform := Transform3D(b.cur_basis.scaled(b.cur_scale), final_pos)

		b.back_mesh.transform = final_xform
		b.front_mesh.transform = final_xform

		# Punto medio de la cuchilla en espacio 3D para decidir Z-sorting atrás vs adelante del piloto
		var mid_local := Vector3(MeshBuilderScript.TIER_LENGTHS[b.tier] * 0.35, 0.0, 0.0)
		var mid_world: Vector3 = final_xform * mid_local
		b.world_z = mid_world.z
		b.is_front = b.world_z >= 0.0

		b.back_mesh.visible = not b.is_front
		b.front_mesh.visible = b.is_front
		if b.is_front:
			front_count += 1
		else:
			back_count += 1

		# Proyección exacta de la punta cristalina 3D → 2D
		var tip_local: Vector3 = MeshBuilderScript.get_tip_local_pos(b.tier)
		var tip_world: Vector3 = final_xform * tip_local
		b.tip_2d = _unproject_3d_to_local_2d(tip_world)

		_update_blade_shader_params(b, key_dir)
		_update_blade_trail(b, dt, snap_now)

	_front_count_cache = front_count
	_back_count_cache = back_count

	_step_stardust(dt)
	_step_tracers(dt)

	if _fx_back != null:
		_fx_back.queue_redraw()
	if _fx_front != null:
		_fx_front.queue_redraw()


func get_blade_count() -> int:
	return _blades.size()


func get_front_back_counts() -> Vector2i:
	return Vector2i(_front_count_cache, _back_count_cache)


func get_total_triangle_count() -> int:
	return _total_tris_cache


func get_blade_state(index: int) -> Dictionary:
	if index < 0 or index >= _blades.size():
		return {}
	var b: _BladeSlot = _blades[index]
	return {
		"index": b.index,
		"side": b.side,
		"slot": b.slot,
		"tier": b.tier,
		"pos": b.cur_pos,
		"world_z": b.world_z,
		"is_front": b.is_front,
		"tip_2d": b.tip_2d,
		"recoil": b.recoil,
		"fire_flash": b.fire_flash,
	}


func _build_viewports() -> void:
	_back_vp = _create_wing_viewport("Wings3DBackViewport")
	add_child(_back_vp)
	_back_cam = _create_wing_camera("Wings3DBackCamera")
	_back_vp.add_child(_back_cam)

	_front_vp = _create_wing_viewport("Wings3DFrontViewport")
	add_child(_front_vp)
	_front_cam = _create_wing_camera("Wings3DFrontCamera")
	_front_vp.add_child(_front_cam)

	_post_mat_back = ShaderMaterial.new()
	_post_mat_back.shader = Post2DShader

	_post_mat_front = ShaderMaterial.new()
	_post_mat_front.shader = Post2DShader

	_back_sprite = Sprite2D.new()
	_back_sprite.name = "Wings3DBackSprite"
	_back_sprite.z_index = _z_back_wings
	_back_sprite.texture = _back_vp.get_texture()
	_back_sprite.material = _post_mat_back
	add_child(_back_sprite)

	_front_sprite = Sprite2D.new()
	_front_sprite.name = "Wings3DFrontSprite"
	_front_sprite.z_index = _z_front_wings
	_front_sprite.texture = _front_vp.get_texture()
	_front_sprite.material = _post_mat_front
	add_child(_front_sprite)


func _create_wing_viewport(vp_name: String) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = vp_name
	vp.size = Vector2i(VIEWPORT_PX, VIEWPORT_PX)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.use_hdr_2d = true
	vp.msaa_3d = SubViewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return vp


func _create_wing_camera(cam_name: String) -> Camera3D:
	var cam := Camera3D.new()
	cam.name = cam_name
	cam.fov = CAMERA_FOV_DEG
	cam.near = 0.1
	cam.far = 45.0
	cam.position = Vector3(0.0, 0.0, CAMERA_DIST_Z)
	return cam


func _build_blades() -> void:
	_blades.clear()
	_total_tris_cache = 0
	var idx: int = 0
	for side: int in [-1, 1]:
		for slot: int in range(BLADES_PER_WING):
			var b := _BladeSlot.new()
			b.index = idx
			b.side = side
			b.slot = slot
			b.tier = SLOT_TIERS[slot]
			b.base_scale = SLOT_SCALES[slot]

			var mesh: ArrayMesh = MeshBuilderScript.build_wing_blade_mesh(b.tier)
			_total_tris_cache += MeshBuilderScript.get_triangle_count(b.tier)

			b.outline_mat = ShaderMaterial.new()
			b.outline_mat.shader = OutlineShader

			var defaults: Array[Color] = [BASE_ARMOR_COLOR, BASE_CHASSIS_COLOR, BASE_CRYSTAL_COLOR]
			b.mats.clear()
			for surf: int in range(3):
				var mat := ShaderMaterial.new()
				mat.shader = ToonShader
				mat.set_shader_parameter("material_kind", surf)
				mat.set_shader_parameter("base_color", defaults[surf])
				mat.next_pass = b.outline_mat
				b.mats.append(mat)

			b.back_mesh = _create_blade_mesh_node("BladeBack_%d" % idx, mesh, b.mats)
			b.front_mesh = _create_blade_mesh_node("BladeFront_%d" % idx, mesh, b.mats)
			_back_vp.add_child(b.back_mesh)
			_front_vp.add_child(b.front_mesh)

			_blades.append(b)
			idx += 1


func _create_blade_mesh_node(
	node_name: String,
	mesh: ArrayMesh,
	mats: Array[ShaderMaterial]
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	for surf: int in range(mats.size()):
		mi.set_surface_override_material(surf, mats[surf])
	return mi


func _build_fx_layers() -> void:
	_fx_back = _WingFXOverlay.new()
	_fx_back.name = "Wings3DFXBack"
	_fx_back.z_index = _z_back_fx
	_fx_back.owner_ctrl = self
	_fx_back.is_front_layer = false
	add_child(_fx_back)

	_fx_front = _WingFXOverlay.new()
	_fx_front.name = "Wings3DFXFront"
	_fx_front.z_index = _z_front_fx
	_fx_front.owner_ctrl = self
	_fx_front.is_front_layer = true
	add_child(_fx_front)

	var width_curve := Curve.new()
	width_curve.add_point(Vector2(0.0, 1.0))
	width_curve.add_point(Vector2(0.45, 0.55))
	width_curve.add_point(Vector2(1.0, 0.0))

	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	for b: _BladeSlot in _blades:
		var line := Line2D.new()
		line.name = "WingTrail_%d" % b.index
		line.width = _config.trail_width_px
		line.width_curve = width_curve
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.antialiased = true
		line.material = add_mat
		line.z_index = 2
		add_child(line)
		b.trail_line = line


func _update_camera_elev() -> void:
	if _back_cam == null or _front_cam == null or _config == null:
		return
	var elev_rad: float = deg_to_rad(clampf(_config.camera_elev_deg, -35.0, 45.0))
	var cam_pos := Vector3(0.0, sin(elev_rad) * CAMERA_DIST_Z, cos(elev_rad) * CAMERA_DIST_Z)
	_back_cam.look_at_from_position(cam_pos, Vector3.ZERO, Vector3.UP)
	_front_cam.look_at_from_position(cam_pos, Vector3.ZERO, Vector3.UP)


func _get_effective_sprite_scale() -> float:
	if _config == null:
		return VIEWPORT_REF_PX / float(VIEWPORT_PX)
	return _config.wing_scale * (VIEWPORT_REF_PX / float(VIEWPORT_PX))


func _sync_sprite_transforms() -> void:
	if _back_sprite == null or _front_sprite == null or _config == null:
		return
	var eff_s: float = _get_effective_sprite_scale()
	var s := Vector2(eff_s, eff_s)
	_back_sprite.position = _config.anchor_offset_px
	_back_sprite.scale = s
	_front_sprite.position = _config.anchor_offset_px
	_front_sprite.scale = s

	var key_dir: Vector3 = _compute_key_light_dir()
	var light_2d := Vector2(key_dir.x, -key_dir.y)
	if light_2d.length_squared() < 0.001:
		light_2d = Vector2(-0.58, -0.81)
	light_2d = light_2d.normalized()

	for pmat: ShaderMaterial in [_post_mat_back, _post_mat_front]:
		if pmat == null:
			continue
		pmat.set_shader_parameter("enable_post_pass", _config.enable_post_pass)
		pmat.set_shader_parameter("cas_sharpen_strength", _config.cas_sharpen_strength)
		pmat.set_shader_parameter("post_outline_strength", _config.post_outline_strength)
		pmat.set_shader_parameter("post_outline_width_px", _config.post_outline_width_px)
		pmat.set_shader_parameter("outline_calligraphy_amount", _config.outline_calligraphy_amount)
		pmat.set_shader_parameter("light_dir_2d", light_2d)
		pmat.set_shader_parameter("outline_shadow_color", _config.outline_color)
		pmat.set_shader_parameter("outline_lit_color", _config.outline_lit_color)
		pmat.set_shader_parameter("post_rim_strength", _config.post_rim_strength)
		pmat.set_shader_parameter("rim_key_color", _config.rim_color)
		pmat.set_shader_parameter("rim_counter_color", _active_glow_color)


func _evaluate_blade_target(b: _BladeSlot) -> Dictionary:
	var u: float = float(b.slot) / float(BLADES_PER_WING - 1) # 0.0 (top) .. 1.0 (bottom)
	var sf: float = float(b.side)
	var yaw_basis := Basis(Vector3.UP, _pilot_yaw_rad)
	var base_scale_vec := Vector3(
		b.base_scale * _config.blade_length_scale,
		b.base_scale,
		b.base_scale * _config.blade_thickness_scale
	)

	var vel_norm: Vector2 = _pilot_velocity_2d / 320.0
	var vel_speed: float = clampf(vel_norm.length(), 0.0, 1.4)

	match _anim_state:
		AnimState.IDLE_ZERO_G:
			return _eval_idle_or_boost(b, u, sf, yaw_basis, base_scale_vec, vel_norm, vel_speed, false)
		AnimState.CRUISE_BOOST:
			return _eval_idle_or_boost(b, u, sf, yaw_basis, base_scale_vec, vel_norm, maxf(vel_speed, 1.0), true)
		AnimState.SERAPH_BLOOM:
			return _eval_seraph_bloom(b, u, sf, yaw_basis, base_scale_vec)
		AnimState.AEGIS_GUARD:
			return _eval_aegis_guard(b, u, sf, yaw_basis, base_scale_vec)
		AnimState.FULL_BURST:
			return _eval_full_burst(b, u, sf, yaw_basis, base_scale_vec)
		AnimState.VORTEX_SPIN:
			return _eval_vortex_spin(b, u, sf, base_scale_vec)
		AnimState.SERAPH_FOLD:
			return _eval_seraph_fold(b, u, sf, yaw_basis, base_scale_vec)
		_:
			return _eval_idle_or_boost(b, u, sf, yaw_basis, base_scale_vec, vel_norm, vel_speed, false)


func _eval_idle_or_boost(
	b: _BladeSlot,
	u: float,
	sf: float,
	yaw_basis: Basis,
	scale_vec: Vector3,
	vel_norm: Vector2,
	boost_factor: float,
	is_boost_mode: bool
) -> Dictionary:
	var breath: float = sin(_time * TAU * _config.idle_breath_hz)
	var wave_phase: float = _time * TAU * _config.wave_speed_hz - float(b.slot) * _config.wave_phase_step
	var wave: float = sin(wave_phase)
	var twist: float = cos(wave_phase * 0.85 + sf * 0.4)

	# Disposición 1:1 basada en wings_metadata.json (arco curvo s1..s5 bajo s0)
	var rest_off: Vector2 = SLOT_REST_OFFSETS[b.slot]
	var blade_t: float = 0.0 if b.slot == 0 else u # s0 mantiene postura regia como en el original
	var radial_expand: float = (0.14 if is_boost_mode else 0.0) + breath * _config.idle_breath_amp

	var spread_x: float = _config.root_spread_x + rest_off.x + radial_expand * (0.5 + 0.5 * blade_t)
	var root_y: float = _config.root_height_y + rest_off.y + wave * 0.042 + breath * 0.03
	var root_z: float = _config.root_depth_back_z - float(b.slot) * 0.045 - (0.24 if is_boost_mode else 0.0)

	# Empuje Newtoniano sutil al volar con WASD
	var lag_x: float = clampf(-vel_norm.x * 0.22, -0.35, 0.35)
	var lag_y: float = clampf(vel_norm.y * 0.20, -0.30, 0.30)

	var local_pos := Vector3(sf * spread_x, root_y, root_z)
	var world_pos: Vector3 = yaw_basis * local_pos + Vector3(lag_x, lag_y, 0.0)

	var fan_deg: float = SLOT_REST_ANGLES_DEG[b.slot]
	fan_deg += blade_t * wave * _config.wave_amp_deg
	fan_deg += breath * 2.2 * (1.0 - blade_t * 0.5)
	if is_boost_mode:
		# En impulso el abanico se barre levemente hacia afuera/abajo con micro-vibración
		fan_deg -= blade_t * 10.0
		fan_deg += sin(_time * 28.0 + float(b.index)) * 1.1

	var sweep_deg: float = _config.blade_sweep_back_deg + float(b.slot) * 2.2 + boost_factor * _config.thrust_sweep_deg
	var twist_deg: float = twist * _config.blade_twist_amp_deg * (0.45 + 0.55 * blade_t) + (12.0 if is_boost_mode else 4.0)

	var blade_basis: Basis = _build_wing_blade_basis(sf, yaw_basis, fan_deg, sweep_deg, twist_deg)
	var s_mul: float = 1.05 if is_boost_mode else 1.0
	return {"pos": world_pos, "basis": blade_basis, "scale": scale_vec * Vector3(s_mul, 1.0, 1.0)}


func _eval_seraph_bloom(
	b: _BladeSlot,
	u: float,
	sf: float,
	yaw_basis: Basis,
	scale_vec: Vector3
) -> Dictionary:
	# Ciclo dramático de 3.6 s: repliegue breve de anticipación → despliegue serafín monumental
	var cycle: float = fmod(_anim_state_time, 3.6)
	var bloom: float = 0.0
	if cycle < 0.45:
		var t: float = cycle / 0.45
		bloom = -0.55 * sin(t * PI)
	elif cycle < 1.10:
		var t: float = (cycle - 0.45) / 0.65
		var ease_out: float = 1.0 - pow(1.0 - t, 3.0)
		var overshoot: float = sin(t * PI) * 0.24
		bloom = ease_out + overshoot
	else:
		var hold_t: float = cycle - 1.10
		bloom = 1.0 + sin(hold_t * 2.6 - float(b.slot) * 0.45) * 0.08

	var rest_off: Vector2 = SLOT_REST_OFFSETS[b.slot]
	var spread_x: float = _config.root_spread_x + rest_off.x * (0.75 + 0.55 * bloom) + 0.34 * bloom
	var root_y: float = _config.root_height_y + rest_off.y * (0.75 + 0.45 * bloom) + (0.28 - u * 0.42) * maxf(bloom, 0.0)
	var root_z: float = _config.root_depth_back_z - 0.16 + bloom * 0.10 - float(b.slot) * 0.04

	var rest_ang: float = SLOT_REST_ANGLES_DEG[b.slot]
	var tucked_ang: float = rest_ang * 0.55 - 18.0
	var open_ang: float = rest_ang + (10.0 if b.slot == 0 else (6.0 - u * 16.0))
	var fan_deg: float = lerpf(tucked_ang, open_ang, clampf(bloom * 0.72 + 0.28, 0.0, 1.25))

	var sweep_deg: float = lerpf(38.0, 5.0, clampf(bloom, 0.0, 1.1)) + float(b.slot) * 1.8
	var twist_deg: float = (1.0 - bloom) * 34.0 + sin(_time * 3.4 - float(b.slot) * 0.6) * 14.0

	var blade_basis: Basis = _build_wing_blade_basis(sf, yaw_basis, fan_deg, sweep_deg, twist_deg)
	var s_bloom: float = lerpf(0.88, 1.12, clampf(bloom, 0.0, 1.15))
	return {
		"pos": yaw_basis * Vector3(sf * spread_x, root_y, root_z),
		"basis": blade_basis,
		"scale": scale_vec * Vector3(s_bloom, s_bloom, 1.0),
	}


func _eval_seraph_fold(
	b: _BladeSlot,
	u: float,
	sf: float,
	yaw_basis: Basis,
	scale_vec: Vector3
) -> Dictionary:
	# Repliegue escalonado de puntas inferiores (s5) hacia el brazo maestro (s0) en ~0.38 s
	var stagger: float = (1.0 - u) * 0.10
	var local_t: float = clampf((_anim_state_time - stagger) / 0.28, 0.0, 1.0)
	var ease_in: float = local_t * local_t * (3.0 - 2.0 * local_t)

	var rest_off: Vector2 = SLOT_REST_OFFSETS[b.slot]
	var spread_x: float = lerpf(_config.root_spread_x + rest_off.x, 0.04, ease_in)
	var root_y: float = lerpf(_config.root_height_y + rest_off.y, 0.0, ease_in)
	var root_z: float = lerpf(_config.root_depth_back_z, -0.35, ease_in)

	var rest_ang: float = SLOT_REST_ANGLES_DEG[b.slot]
	var fan_deg: float = lerpf(rest_ang, -78.0, ease_in)
	var sweep_deg: float = lerpf(_config.blade_sweep_back_deg, 74.0, ease_in)
	var twist_deg: float = lerpf(8.0, 42.0, ease_in)

	var blade_basis: Basis = _build_wing_blade_basis(sf, yaw_basis, fan_deg, sweep_deg, twist_deg)
	var s_fold: float = maxf(0.001, 1.0 - ease_in)
	return {
		"pos": yaw_basis * Vector3(sf * spread_x, root_y, root_z),
		"basis": blade_basis,
		"scale": scale_vec * Vector3(s_fold, s_fold, s_fold),
	}


func _eval_aegis_guard(
	b: _BladeSlot,
	u: float,
	sf: float,
	yaw_basis: Basis,
	scale_vec: Vector3
) -> Dictionary:
	# Las 12 cuchillas se proyectan ADELANTE del piloto formando un escudo cristalino giratorio 3D
	var angle_step: float = TAU / float(TOTAL_BLADES)
	var ring_angle: float = float(b.index) * angle_step + _time * _config.aegis_spin_speed
	var radius: float = _config.aegis_radius * (0.94 + 0.06 * sin(_time * 4.0 + float(b.index)))

	var local_pos := Vector3(
		cos(ring_angle) * radius * 0.78,
		sin(ring_angle) * radius * 0.84 + 0.05,
		1.35 + sin(ring_angle * 2.0) * 0.16 # Delante del plano Z=0 → pasa a Front SubViewport
	)
	var world_pos: Vector3 = yaw_basis * local_pos

	# Orientar cada cuchilla tangente al escudo con inclinación cónica hacia afuera
	var tangent_local := Vector3(-sin(ring_angle), cos(ring_angle), 0.22).normalized()
	var outward_local := Vector3(cos(ring_angle), sin(ring_angle), 0.35).normalized()
	var x_axis: Vector3 = (yaw_basis * tangent_local).normalized()
	var y_axis: Vector3 = (yaw_basis * outward_local).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	y_axis = z_axis.cross(x_axis).normalized()
	var blade_basis := Basis(x_axis, y_axis, z_axis).orthonormalized()

	var shield_scale := Vector3(0.68, 0.92, 1.15) * _config.blade_length_scale
	return {"pos": world_pos, "basis": blade_basis, "scale": shield_scale}


func _eval_full_burst(
	b: _BladeSlot,
	u: float,
	sf: float,
	yaw_basis: Basis,
	scale_vec: Vector3
) -> Dictionary:
	# Arco elevado de 12 funnels apuntando en 3D real hacia el cursor del ratón
	var arc_angle: float = lerpf(deg_to_rad(72.0), deg_to_rad(-34.0), u)
	var arc_r: float = 1.65 + (1.0 - absf(u - 0.35)) * 0.55
	var hover_bob: float = sin(_time * 3.2 + float(b.index) * 0.75) * 0.09

	var local_pos := Vector3(
		sf * (0.72 + cos(arc_angle) * arc_r * 0.78),
		0.15 + sin(arc_angle) * arc_r * 0.95 + hover_bob,
		-0.18 + (0.48 if b.slot < 3 else -0.25)
	)
	var world_pos: Vector3 = yaw_basis * local_pos

	# Convertir cursor 2D en objetivo 3D en plano Z = +2.8 para que los cañones giren en 3D real
	var rel_2d: Vector2 = (_mouse_target_local - _config.anchor_offset_px) / maxf(_config.wing_scale, 0.25)
	var px_per_unit: float = VIEWPORT_REF_PX / (2.0 * CAMERA_DIST_Z * tan(deg_to_rad(CAMERA_FOV_DEG * 0.5)))
	var target_3d := Vector3(
		clampf(rel_2d.x / px_per_unit, -6.5, 6.5),
		clampf(-rel_2d.y / px_per_unit, -4.5, 4.5),
		2.65
	)

	var aim_dir: Vector3 = (target_3d - world_pos).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector3.BACK

	var up_ref: Vector3 = Vector3.UP if absf(aim_dir.dot(Vector3.UP)) < 0.92 else Vector3.RIGHT
	var z_axis: Vector3 = aim_dir.cross(up_ref).normalized()
	var y_axis: Vector3 = z_axis.cross(aim_dir).normalized()
	var blade_basis := Basis(aim_dir, y_axis, z_axis).orthonormalized()

	return {"pos": world_pos, "basis": blade_basis, "scale": scale_vec * Vector3(0.92, 0.96, 1.0)}


func _eval_vortex_spin(
	b: _BladeSlot,
	u: float,
	sf: float,
	scale_vec: Vector3
) -> Dictionary:
	# Doble hélice 3D girando 360° alrededor de Valentina (cruza continuamente atrás ↔ adelante)
	var ring_id: float = 0.0 if b.side > 0 else 1.0
	var theta: float = (float(b.slot) / float(BLADES_PER_WING)) * TAU + _time * _config.vortex_spin_speed + ring_id * PI
	var radius: float = _config.vortex_radius * (0.90 + 0.12 * sin(_time * 2.1 + float(b.slot)))

	var tilt_x: float = deg_to_rad(26.0) if b.side > 0 else deg_to_rad(-26.0)
	var tilt_z: float = deg_to_rad(14.0 * sf)
	var ring_basis := Basis(Vector3.RIGHT, tilt_x) * Basis(Vector3.BACK, tilt_z)

	var orbit_local := Vector3(cos(theta) * radius, sin(theta * 2.0) * 0.22 + (u - 0.5) * 0.25, sin(theta) * radius)
	var world_pos: Vector3 = ring_basis * orbit_local

	var tangent_local := Vector3(-sin(theta), cos(theta * 2.0) * 0.18, cos(theta)).normalized()
	var radial_local := Vector3(cos(theta), 0.15, sin(theta)).normalized()
	var x_axis: Vector3 = (ring_basis * tangent_local).normalized()
	var y_axis: Vector3 = (ring_basis * radial_local).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	y_axis = z_axis.cross(x_axis).normalized()
	var blade_basis := Basis(x_axis, y_axis, z_axis).orthonormalized()

	return {"pos": world_pos, "basis": blade_basis, "scale": scale_vec * Vector3(0.76, 0.88, 1.0)}


func _build_wing_blade_basis(
	sf: float,
	yaw_basis: Basis,
	fan_deg: float,
	sweep_back_deg: float,
	twist_deg: float
) -> Basis:
	# Determinante +1.0 garantizado en ambos lados:
	# Para ala izquierda (sf < 0) espejamos con rotación PI en Y (nunca escala negativa).
	var fan_rad: float = deg_to_rad(fan_deg)
	var sweep_rad: float = deg_to_rad(sweep_back_deg)
	var twist_rad: float = deg_to_rad(twist_deg)

	if sf > 0.0:
		var local_b: Basis = Basis(Vector3.UP, sweep_rad) * Basis(Vector3.BACK, fan_rad) * Basis(Vector3.RIGHT, twist_rad)
		return (yaw_basis * local_b).orthonormalized()
	else:
		# Rotar 180° en Y envía +X→-X, +Y→+Y, +Z→-Z preservando winding horario
		var mirror_b: Basis = Basis(Vector3.UP, PI - sweep_rad) * Basis(Vector3.BACK, fan_rad) * Basis(Vector3.RIGHT, -twist_rad)
		return (yaw_basis * mirror_b).orthonormalized()


func _compute_key_light_dir() -> Vector3:
	if _cosmic_active and absf(_light_yaw_rad) < 0.001:
		return _cosmic_light_dir
	if absf(_light_yaw_rad) < 0.001:
		return BASE_KEY_LIGHT_DIR.normalized()
	var b := Basis(Vector3.UP, _light_yaw_rad)
	return (b * BASE_KEY_LIGHT_DIR).normalized()


func _apply_palette_to_all_blades() -> void:
	if _blades.is_empty():
		return
	var use_skin: bool = _skin_recolor and (_config == null or _config.follow_skin_palette)
	var armor_col: Color = _skin_panel.lerp(Color(0.92, 0.94, 0.98), 0.25) if use_skin else BASE_ARMOR_COLOR
	var chassis_col: Color = _skin_dark if use_skin else BASE_CHASSIS_COLOR
	var crystal_col: Color = _skin_accent if use_skin else BASE_CRYSTAL_COLOR

	for b: _BladeSlot in _blades:
		if b.mats.size() < 3:
			continue
		b.mats[0].set_shader_parameter("base_color", armor_col)
		b.mats[1].set_shader_parameter("base_color", chassis_col)
		b.mats[2].set_shader_parameter("base_color", crystal_col)


func _update_blade_shader_params(b: _BladeSlot, key_dir: Vector3) -> void:
	var depth_norm: float = clampf(b.world_z / 2.2, -1.0, 1.0)
	var active_boost: float = _config.emissive_active_boost if (
		_anim_state == AnimState.CRUISE_BOOST
		or _anim_state == AnimState.SERAPH_BLOOM
		or _anim_state == AnimState.FULL_BURST
	) else _config.emissive_idle_boost
	var pulse_wave: float = 0.5 + 0.5 * sin(_time * 4.2 - float(b.slot) * 0.65)
	var eff_flash: float = clampf(b.fire_flash + _global_pulse * 0.65, 0.0, 2.2)

	for mat: ShaderMaterial in b.mats:
		mat.set_shader_parameter("key_light_dir", key_dir)
		mat.set_shader_parameter("key_light_tint", _cosmic_key_tint if _cosmic_active else Color.WHITE)
		mat.set_shader_parameter("key_light_boost", _cosmic_key_boost if _cosmic_active else 1.04)
		mat.set_shader_parameter("shadow_tint", _cosmic_shadow_tint if _cosmic_active else BASE_SHADOW_TINT)
		mat.set_shader_parameter("orbit_depth", depth_norm)
		mat.set_shader_parameter("depth_back_dim", _config.depth_back_dim)
		mat.set_shader_parameter("depth_back_tint", _config.depth_back_tint)
		mat.set_shader_parameter("rim_strength", _config.rim_strength)
		mat.set_shader_parameter("rim_color", _config.rim_color)
		mat.set_shader_parameter("specular_sweep_strength", _config.specular_sweep_strength)
		mat.set_shader_parameter("crease_ink_strength", _config.crease_ink_strength)
		mat.set_shader_parameter("crease_ink_threshold", _config.crease_ink_threshold)
		mat.set_shader_parameter("crease_ink_color", _config.outline_color)
		mat.set_shader_parameter("emissive_boost", (active_boost + pulse_wave * 0.28) * (_cosmic_emissive_mult if _cosmic_active else 1.0) * _star_emissive_mult)
		mat.set_shader_parameter("channel_glow_strength", _config.channel_glow_strength)
		mat.set_shader_parameter("energy_flow_time", _time + float(b.slot) * 0.22)
		mat.set_shader_parameter("energy_flow_speed", _config.energy_flow_speed)
		mat.set_shader_parameter("energy_flow_amp", _config.energy_flow_amp)
		mat.set_shader_parameter("crimson_bounce_strength", _config.crimson_bounce_strength)
		mat.set_shader_parameter("fire_flash", eff_flash)
		mat.set_shader_parameter("fire_glow_color", _active_glow_color)

	if b.outline_mat != null:
		b.outline_mat.set_shader_parameter("outline_width", _config.outline_width)
		b.outline_mat.set_shader_parameter("outline_calligraphy_amount", _config.outline_calligraphy_amount)
		b.outline_mat.set_shader_parameter("key_light_dir", key_dir)
		b.outline_mat.set_shader_parameter("outline_color", _config.outline_color)
		b.outline_mat.set_shader_parameter("outline_lit_color", _config.outline_lit_color)
		b.outline_mat.set_shader_parameter("orbit_depth", depth_norm)
		b.outline_mat.set_shader_parameter("depth_back_dim", _config.depth_back_dim)


func _unproject_3d_to_local_2d(world_pos: Vector3) -> Vector2:
	if _front_cam == null:
		return _config.anchor_offset_px
	var vp_pos: Vector2 = _front_cam.unproject_position(world_pos)
	var centered: Vector2 = vp_pos - Vector2(float(VIEWPORT_PX) * 0.5, float(VIEWPORT_PX) * 0.5)
	return _config.anchor_offset_px + centered * _get_effective_sprite_scale()


func _update_blade_trail(b: _BladeSlot, dt: float, snap_now: bool) -> void:
	if b.trail_line == null:
		return
	b.trail_line.visible = _config.enable_trails
	b.trail_line.z_index = _z_front_fx if b.is_front else _z_back_fx
	b.trail_line.width = _config.trail_width_px * (1.15 if b.tier == 0 else 0.78)

	var c_head := Color(_active_glow_color.r * 1.45, _active_glow_color.g * 1.45, _active_glow_color.b * 1.45, _config.trail_alpha)
	var c_tail := Color(_active_glow_color.r, _active_glow_color.g, _active_glow_color.b, 0.0)
	var grad := Gradient.new()
	grad.set_color(0, c_head)
	grad.set_color(1, c_tail)
	b.trail_line.gradient = grad

	if snap_now or not _config.enable_trails:
		b.trail_points.clear()
		b.trail_points.append(b.tip_2d)
		b.trail_line.points = PackedVector2Array(b.trail_points)
		return

	# Desplazar la estela compensando movimiento real en mundo o viento simulado
	var drift: Vector2 = -_world_delta_pending if _world_delta_pending.length_squared() > 0.001 else (-_pilot_velocity_2d * dt * 0.65)
	if _anim_state == AnimState.CRUISE_BOOST and drift.length_squared() < 4.0 and _world_delta_pending.length_squared() < 0.001:
		drift = Vector2(0.0, 260.0 * dt)
	for i: int in range(b.trail_points.size()):
		b.trail_points[i] = b.trail_points[i] + drift

	b.trail_points.push_front(b.tip_2d)
	var max_pts: int = _config.trail_max_points
	if b.trail_points.size() > max_pts:
		b.trail_points.resize(max_pts)
	b.trail_line.points = PackedVector2Array(b.trail_points)


func _fire_single_blade(b: _BladeSlot) -> void:
	b.recoil = 1.0
	b.fire_flash = 1.65

	if _anim_state == AnimState.FULL_BURST and _tracers.size() < MAX_TRACERS:
		var dir: Vector2 = (_mouse_target_local - b.tip_2d)
		if dir.length_squared() < 16.0:
			dir = Vector2.RIGHT
		dir = dir.normalized()
		_tracers.append({
			"pos": b.tip_2d,
			"vel": dir * 1350.0,
			"life": 0.24,
			"max_life": 0.24,
			"is_front": b.is_front,
			"color": _active_glow_color,
		})


func _step_stardust(dt: float) -> void:
	if not _config.enable_stardust:
		_stardust.clear()
		return

	if dt > 0.0 and _stardust.size() < MAX_STARDUST:
		var rate_mult: float = 1.75 if (_anim_state == AnimState.CRUISE_BOOST or _anim_state == AnimState.SERAPH_BLOOM) else 1.0
		_stardust_accum += dt * _config.stardust_spawn_rate * rate_mult
		while _stardust_accum >= 1.0 and _stardust.size() < MAX_STARDUST:
			_stardust_accum -= 1.0
			var b: _BladeSlot = _blades[_rng.randi_range(0, TOTAL_BLADES - 1)]
			var drift := Vector2(_rng.randf_range(-28.0, 28.0), _rng.randf_range(-18.0, 42.0)) - _pilot_velocity_2d * 0.28
			_stardust.append({
				"pos": b.tip_2d + Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-6.0, 6.0)),
				"vel": drift,
				"life": _rng.randf_range(0.35, 0.72),
				"max_life": 0.72,
				"size": _config.stardust_size_px * _rng.randf_range(0.65, 1.35),
				"is_front": b.is_front,
			})

	var i: int = _stardust.size() - 1
	while i >= 0:
		var p: Dictionary = _stardust[i]
		p["life"] = float(p["life"]) - dt
		if float(p["life"]) <= 0.0:
			_stardust.remove_at(i)
		else:
			p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * dt
		i -= 1


func _step_tracers(dt: float) -> void:
	var i: int = _tracers.size() - 1
	while i >= 0:
		var tr: Dictionary = _tracers[i]
		tr["life"] = float(tr["life"]) - dt
		if float(tr["life"]) <= 0.0:
			_tracers.remove_at(i)
		else:
			tr["pos"] = (tr["pos"] as Vector2) + (tr["vel"] as Vector2) * dt
		i -= 1


func _draw_fx_layer(canvas: Node2D, is_front_layer: bool) -> void:
	# 1. Polvo estelar 4-puntas anclado a las puntas 3D
	for p: Dictionary in _stardust:
		if bool(p["is_front"]) != is_front_layer:
			continue
		var alpha: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var pos: Vector2 = p["pos"] as Vector2
		var sz: float = float(p["size"]) * (0.45 + 0.55 * alpha)
		var col := Color(_active_glow_color.r * 1.5, _active_glow_color.g * 1.5, _active_glow_color.b * 1.5, alpha * 0.9)
		var core := Color(1.4, 1.4, 1.5, alpha)
		canvas.draw_line(pos - Vector2(sz, 0.0), pos + Vector2(sz, 0.0), col, 1.5, true)
		canvas.draw_line(pos - Vector2(0.0, sz), pos + Vector2(0.0, sz), col, 1.5, true)
		canvas.draw_circle(pos, sz * 0.25, core)

	# 2. Destellos de disparo en las puntas en Full Burst
	for b: _BladeSlot in _blades:
		if b.is_front != is_front_layer or b.fire_flash < 0.25:
			continue
		var f: float = clampf((b.fire_flash - 0.25) / 1.4, 0.0, 1.0)
		var r: float = 11.0 * f
		var glow_col := Color(_active_glow_color.r * 1.8, _active_glow_color.g * 1.8, _active_glow_color.b * 1.8, f * 0.72)
		canvas.draw_circle(b.tip_2d, r, glow_col)
		canvas.draw_circle(b.tip_2d, r * 0.42, Color(1.6, 1.6, 1.6, f))

	# 3. Trazadores láser HDR (Full Burst)
	for tr: Dictionary in _tracers:
		if bool(tr["is_front"]) != is_front_layer:
			continue
		var alpha: float = clampf(float(tr["life"]) / float(tr["max_life"]), 0.0, 1.0)
		var pos: Vector2 = tr["pos"] as Vector2
		var dir: Vector2 = (tr["vel"] as Vector2).normalized()
		var tail: Vector2 = pos - dir * 48.0
		var base_c: Color = tr["color"] as Color
		var outer := Color(base_c.r * 1.7, base_c.g * 1.7, base_c.b * 1.7, alpha * 0.85)
		canvas.draw_line(tail, pos, outer, 4.2, true)
		canvas.draw_line(tail + dir * 10.0, pos, Color(1.8, 1.8, 1.8, alpha), 1.8, true)
