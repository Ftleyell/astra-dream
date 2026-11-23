class_name ValentinaBasePropulsionController
extends Node2D
## Controlador modular y data-driven de la Propulsión Base Zero-G de Valentina v2 (v2):
## - Capa 1: Alas Psíquicas Titánicas (6 cuchillas independientes por ala = 12 en total),
##           sin diamante de anclaje, flotando mágicamente fijadas al torso (UnifiedCharacterGroup, z_index=0).
##           Onda psíquica en Idle + Empuje Newtoniano asimétrico (brillo rojo HDR, rim carmesí y vibración).
## - Capa 2: 12 Cintas Rojas en espacio mundo (desde las 6 puntas de cada ala, con jerarquía y boost por esfuerzo).
## - Capa 3: Polvo Estelar (estrellas de 4 puntas plata/rubí, pool prealocado).

const WINGS_ASSET_DIR: String = "res://assets/pilots/valentina_v2/planar/wings"
const WINGS_META_PATH: String = "res://assets/pilots/valentina_v2/planar/wings/wings_metadata.json"
const STYLIZER_SHADER_PATH: String = "res://scenes/pilots/shaders/pilot_rig_stylizer.gdshader"
const RED_GLOW_SHADER_PATH: String = "res://scenes/pilots/shaders/wing_red_glow.gdshader"
const BasePropConfigScript = preload("res://data/pilots/schemas/pilot_base_propulsion_config.gd")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")
const MAX_SHARDS: int = 6

enum TurnBridgePhase {
	IDLE = 0,
	PRE_CUT = 1,
	POST_CUT = 2,
}

@export var config: BasePropConfigScript = null

var _assets_dir: String = WINGS_ASSET_DIR
var _meta_path: String = WINGS_META_PATH
var _has_explicit_config: bool = false
var _meta: Dictionary = {}
var _tex_scale: float = 3.0
var _shard_textures: Dictionary = {}   # piece_id -> {albedo, id, ilm, normal, ink_sdf}
var _side_materials_l: Dictionary = {} # piece_id -> ShaderMaterial (ala izquierda)
var _side_materials_r: Dictionary = {} # piece_id -> ShaderMaterial (ala derecha)
var _glow_mats_l: Dictionary = {}      # piece_id -> ShaderMaterial HDR glow (ala izquierda)
var _glow_mats_r: Dictionary = {}      # piece_id -> ShaderMaterial HDR glow (ala derecha)
var _stylizer_shader: Shader = null
var _glow_shader: Shader = null

var _attached_rig: Node2D = null
var _under_mount: Node2D = null
var _over_mount: Node2D = null
var _glow_under_layer: Node2D = null
var _glow_over_layer: Node2D = null
var _wing_l_pivot: Node2D = null
var _wing_r_pivot: Node2D = null

# 6 slots independientes de cuchillas por ala (+ 6 sprites de glow HDR externos al CanvasGroup)
var _blades_l: Array[Dictionary] = [] # {pivot, sprite, tip, rest_offset, length_norm, active, piece_id}
var _blades_r: Array[Dictionary] = []
var _glow_sprites_l: Array[Sprite2D] = []
var _glow_sprites_r: Array[Sprite2D] = []

# Capa 2: 12 Cintas Rojas (6 por ala, con Gradient prealocado zero-alloc)
var _ribbons_l: Array[Dictionary] = [] # {outer, grad_out, pts}
var _ribbons_r: Array[Dictionary] = []

# Capa 3: Polvo Estelar (pool prealocado dibujado en _draw)
var _stardust: Array[Dictionary] = []
var _stardust_accum: float = 0.0
var _rng := RandomNumberGenerator.new()

# Estelas de velocidad imposible en cambios de ángulo (6 Speed-Arcs + 2 Afterimages ultrabreves)
var _warp_arcs: Array[Dictionary] = []
var _warp_ghosts: Array[Dictionary] = []

# Estado cinemático, suavizado y Empuje Newtoniano
var _current_dir: String = "s"
var _sim_time: float = 0.0
var _open_factor: float = 0.0
var _effort_l: float = 0.0
var _effort_r: float = 0.0
var _glow_intensity_l: float = 0.0
var _glow_intensity_r: float = 0.0
var _brake_pulse: float = 0.0
var _kick_spring: float = 0.0
var _prev_vel: Vector2 = Vector2.ZERO
var _prev_move_dir: Vector2 = Vector2.RIGHT
var _bank_smooth: float = 0.0
var _smooth_drag_lag: Vector2 = Vector2.ZERO
var _smooth_pos_l: Vector2 = Vector2.ZERO
var _smooth_pos_r: Vector2 = Vector2.ZERO
var _smooth_rot_l: float = 0.0
var _smooth_rot_r: float = 0.0
var _smooth_scale_l: float = 0.5
var _smooth_scale_r: float = 0.5
var _has_smooth_init: bool = false
var _snap_pos_l_next: bool = false
var _snap_pos_r_next: bool = false

# Puente 2.5D Squash-X en cambios de ángulo
var _turn_phase: int = TurnBridgePhase.IDLE
var _turn_timer: float = 0.0
var _pending_dir: String = ""
var _turn_start_sx_l: float = 1.0
var _turn_start_sx_r: float = 1.0
var _turn_min_sx_l: float = 1.0
var _turn_min_sx_r: float = 1.0
var _turn_scale_x_l: float = 1.0
var _turn_scale_x_r: float = 1.0
var _turn_scale_y_l: float = 1.0
var _turn_scale_y_r: float = 1.0
var _cosmic_lighting_active: bool = false
var _cosmic_emissive_mult: float = 1.0
var _last_cosmic_sample: CosmicLightingSampleScript = null
var _wings_skin_override: PilotSkinPreset = null
var _wings_star_level: int = 1
var _rig_follow_skin_active: bool = false
var _rig_follow_accent: Color = Color(1.0, 0.12, 0.28, 1.0)


func _ready() -> void:
	_rng.seed = 20261120
	if config == null:
		config = BasePropConfigScript.new()
	_load_assets()
	_build_world_ribbons()


func set_config(cfg: BasePropConfigScript) -> void:
	if cfg != null:
		config = cfg
		_has_explicit_config = true
	else:
		config = BasePropConfigScript.new()
		_has_explicit_config = false


func set_assets_dir(dir_path: String) -> void:
	if dir_path.is_empty():
		return
	var clean_dir: String = dir_path.rstrip("/")
	if clean_dir == _assets_dir and not _meta.is_empty():
		return
	_assets_dir = clean_dir
	_meta_path = _assets_dir.path_join("wings_metadata.json")
	_meta.clear()
	_shard_textures.clear()


func detach_from_rig() -> void:
	clear_trails()
	_detach_from_rig()


func attach_to_rig(rig: Node2D) -> bool:
	if rig == null:
		return false
	_resolve_profile_settings(rig)
	if _meta.is_empty():
		_load_assets()
	if _meta.is_empty():
		return false

	_detach_from_rig()
	var unified: Node = rig.get_node_or_null("UnifiedCharacterGroup")
	if unified == null:
		return false

	_attached_rig = rig

	_under_mount = Node2D.new()
	_under_mount.name = "WingsUnderMount"
	_under_mount.z_index = 0
	unified.add_child(_under_mount)
	unified.move_child(_under_mount, 0)

	_over_mount = Node2D.new()
	_over_mount.name = "WingsOverMount"
	_over_mount.z_index = 0
	unified.add_child(_over_mount)
	var head_over: Node = unified.get_node_or_null("DecoupledHeadMount")
	if head_over != null:
		unified.move_child(_over_mount, head_over.get_index())

	_wing_l_pivot = Node2D.new()
	_wing_l_pivot.name = "WingLPivot"
	_wing_l_pivot.z_index = 0
	_under_mount.add_child(_wing_l_pivot)

	_wing_r_pivot = Node2D.new()
	_wing_r_pivot.name = "WingRPivot"
	_wing_r_pivot.z_index = 0
	_under_mount.add_child(_wing_r_pivot)

	_blades_l = _create_blade_slots(_wing_l_pivot, "L")
	_blades_r = _create_blade_slots(_wing_r_pivot, "R")

	# Capas HDR externas al CanvasGroup para atravesar el Bloom del WorldEnvironment
	_glow_under_layer = Node2D.new()
	_glow_under_layer.name = "WingsGlowUnder"
	_glow_under_layer.z_index = -1
	rig.add_child(_glow_under_layer)

	_glow_over_layer = Node2D.new()
	_glow_over_layer.name = "WingsGlowOver"
	_glow_over_layer.z_index = 1
	rig.add_child(_glow_over_layer)

	_glow_sprites_l = _create_glow_sprites(_glow_under_layer, "L")
	_glow_sprites_r = _create_glow_sprites(_glow_under_layer, "R")

	sync_materials_from_rig(rig)
	_apply_view_direction(_detect_rig_dir(rig), true)
	return true


func sync_materials_from_rig(rig: Node2D) -> void:
	if rig == null:
		return
	var template_mat: ShaderMaterial = _find_body_core_material(rig)
	_rig_follow_skin_active = false
	if template_mat != null:
		var rec_v: Variant = template_mat.get_shader_parameter("enable_shader_recolor")
		if rec_v is bool and bool(rec_v):
			_rig_follow_skin_active = true
			var acc_v: Variant = template_mat.get_shader_parameter("accent_color")
			if acc_v is Color:
				_rig_follow_accent = acc_v as Color
	_side_materials_l.clear()
	_side_materials_r.clear()
	_glow_mats_l.clear()
	_glow_mats_r.clear()
	for piece_id: String in _shard_textures.keys():
		var bundle: Dictionary = _shard_textures[piece_id] as Dictionary
		_side_materials_l[piece_id] = _build_piece_material(template_mat, bundle)
		_side_materials_r[piece_id] = _build_piece_material(template_mat, bundle)
		_glow_mats_l[piece_id] = _build_glow_material(bundle)
		_glow_mats_r[piece_id] = _build_glow_material(bundle)
	_apply_override_materials()
	_apply_view_direction(_current_dir, true)
	if _cosmic_lighting_active and _last_cosmic_sample != null:
		apply_cosmic_lighting(_last_cosmic_sample)


func apply_skin_preset(skin: PilotSkinPreset, star_level: int = 1) -> void:
	_wings_skin_override = skin
	_wings_star_level = clampi(star_level, 1, 3)
	if _wings_skin_override == null:
		if _attached_rig != null:
			sync_materials_from_rig(_attached_rig)
		return
	_apply_override_materials()


func get_active_skin_id() -> String:
	if _wings_skin_override == null:
		return "follow_pilot"
	if _wings_skin_override.is_base_skin or _wings_skin_override.id.is_empty():
		return "base"
	return _wings_skin_override.id


func _get_effective_accent_color(fallback: Color) -> Color:
	if _wings_skin_override != null:
		if _wings_skin_override.is_base_skin:
			return fallback
		var c: Color = _wings_skin_override.accent_color
		c.a = fallback.a
		return c
	if _rig_follow_skin_active:
		var c: Color = _rig_follow_accent
		c.a = fallback.a
		return c
	return fallback


func _get_star_glow_mult() -> float:
	if _wings_star_level == 2:
		return 1.18
	if _wings_star_level >= 3:
		return 1.38
	return 1.0


func _apply_override_materials() -> void:
	if _wings_skin_override != null:
		var enable_rec: bool = not _wings_skin_override.is_base_skin
		for mat_dict: Dictionary in [_side_materials_l, _side_materials_r]:
			for mat_v: Variant in mat_dict.values():
				var sm: ShaderMaterial = mat_v as ShaderMaterial
				if sm == null:
					continue
				sm.set_shader_parameter("enable_shader_recolor", enable_rec)
				sm.set_shader_parameter("enable_hair_recolor", false)
				sm.set_shader_parameter("accent_color", _wings_skin_override.accent_color)
				sm.set_shader_parameter("panel_color", _wings_skin_override.panel_color)
				sm.set_shader_parameter("suit_dark_color", _wings_skin_override.suit_dark_color)
	var eff_glow: Color = _get_effective_accent_color(config.red_glow_color if config != null else Color(1.0, 0.08, 0.22, 1.0))
	for glow_dict: Dictionary in [_glow_mats_l, _glow_mats_r]:
		for gmat_v: Variant in glow_dict.values():
			var gm: ShaderMaterial = gmat_v as ShaderMaterial
			if gm != null:
				gm.set_shader_parameter("glow_color", eff_glow)


func apply_cosmic_lighting(sample: CosmicLightingSampleScript) -> void:
	if sample == null:
		_cosmic_lighting_active = false
		_cosmic_emissive_mult = 1.0
		_last_cosmic_sample = null
		if _attached_rig != null:
			sync_materials_from_rig(_attached_rig)
		return

	_cosmic_lighting_active = true
	_cosmic_emissive_mult = maxf(sample.emissive_boost_mult, 1.0)
	if _last_cosmic_sample == null:
		_last_cosmic_sample = CosmicLightingSampleScript.new()
	_last_cosmic_sample.copy_from(sample)

	var n_dir: Vector2 = sample.light_dir_2d.normalized() if sample.light_dir_2d.length_squared() > 0.0001 else Vector2(-0.58, -0.81).normalized()
	var eclipse: float = clampf(sample.eclipse_factor, 0.0, 1.0)
	var floor_v: float = clampf(sample.visibility_floor, 0.25, 1.0)
	var eff_key_tint: Color = Color(1.04, 1.02, 0.97, 1.0).lerp(sample.key_light_tint, clampf(sample.star_tint_weight, 0.0, 1.0))
	var eff_key_boost: float = maxf(
		1.04 * (1.0 + clampf(sample.star_proximity, 0.0, 1.0) * 0.10) * lerpf(1.0, floor_v, eclipse),
		floor_v
	)
	var eff_rim_col: Color = Color(0.87, 0.95, 1.0, 1.0).lerp(sample.rim_key_color, clampf(sample.rim_tint_weight, 0.0, 1.0))
	var eff_rim_str: float = 0.88 * lerpf(1.0, 0.35, eclipse)
	var eff_shadow_tint: Color = Color(0.145, 0.145, 0.335, 1.0).lerp(sample.shadow_tint, clampf(sample.biome_shadow_weight, 0.0, 1.0)).darkened(eclipse * 0.16)
	var eff_ao_tint: Color = Color(0.078, 0.064, 0.175, 1.0).lerp(sample.ao_tint, clampf(sample.biome_shadow_weight, 0.0, 1.0)).darkened(eclipse * 0.18)

	for mat_dict: Dictionary in [_side_materials_l, _side_materials_r]:
		for mat_v: Variant in mat_dict.values():
			var sm: ShaderMaterial = mat_v as ShaderMaterial
			if sm == null:
				continue
			sm.set_shader_parameter("light_dir_2d", n_dir)
			sm.set_shader_parameter("key_light_tint", eff_key_tint)
			sm.set_shader_parameter("key_light_boost", eff_key_boost)
			sm.set_shader_parameter("rim_key_color", eff_rim_col)
			sm.set_shader_parameter("normal_rim_strength", eff_rim_str)
			sm.set_shader_parameter("shadow_tint", eff_shadow_tint)
			sm.set_shader_parameter("ao_tint", eff_ao_tint)


func clear_trails() -> void:
	for r: Dictionary in _ribbons_l:
		(r["pts"] as Array).clear()
	for r: Dictionary in _ribbons_r:
		(r["pts"] as Array).clear()
	_stardust.clear()
	_stardust_accum = 0.0
	_warp_arcs.clear()
	_warp_ghosts.clear()
	_sync_all_ribbon_lines()
	queue_redraw()


func is_wings_mounted() -> bool:
	return is_instance_valid(_under_mount) and is_instance_valid(_over_mount)


func get_under_mount() -> Node2D:
	return _under_mount


func get_over_mount() -> Node2D:
	return _over_mount


func get_current_view_dir() -> String:
	return _current_dir


func get_open_factor() -> float:
	return _open_factor


func get_effort_left() -> float:
	return _effort_l


func get_effort_right() -> float:
	return _effort_r


func get_glow_intensity_left() -> float:
	return _glow_intensity_l


func get_glow_intensity_right() -> float:
	return _glow_intensity_r


func get_wing_l_pivot() -> Node2D:
	return _wing_l_pivot


func get_wing_r_pivot() -> Node2D:
	return _wing_r_pivot


func is_turn_bridge_active() -> bool:
	return _turn_phase != TurnBridgePhase.IDLE


func get_turn_scale_x_left() -> float:
	return _turn_scale_x_l


func get_turn_scale_x_right() -> float:
	return _turn_scale_x_r


func get_active_warp_arc_count() -> int:
	return _warp_arcs.size()


func get_active_warp_ghost_count() -> int:
	return _warp_ghosts.size()


func get_top_blade_rotation_deg(is_left: bool) -> float:
	var pool: Array[Dictionary] = _blades_l if is_left else _blades_r
	if pool.is_empty():
		return 0.0
	var piv: Node2D = pool[0].get("pivot", null) as Node2D
	return piv.rotation_degrees if piv != null else 0.0


func has_external_glow_layers() -> bool:
	return (
		is_instance_valid(_glow_under_layer)
		and is_instance_valid(_glow_over_layer)
		and _attached_rig != null
		and _glow_under_layer.get_parent() == _attached_rig
		and _glow_over_layer.get_parent() == _attached_rig
	)


func get_active_blade_count() -> int:
	var total: int = 0
	for b: Dictionary in _blades_l:
		if bool(b["active"]):
			total += 1
	for b: Dictionary in _blades_r:
		if bool(b["active"]):
			total += 1
	return total


func get_active_ribbon_point_count() -> int:
	var total: int = 0
	for r: Dictionary in _ribbons_l:
		total += (r["pts"] as Array).size()
	for r: Dictionary in _ribbons_r:
		total += (r["pts"] as Array).size()
	return total


func get_active_stardust_count() -> int:
	return _stardust.size()


func force_view_direction(dir_key: String) -> void:
	if _meta.is_empty():
		return
	var views: Dictionary = _meta.get("views", {}) as Dictionary
	if views.has(dir_key):
		_reset_turn_bridge_state()
		_apply_view_direction(dir_key, true)


func step(delta: float, rig: Node2D, velocity_px_s: Vector2, is_burst_active: bool) -> void:
	if config == null or rig == null:
		return
	if not is_wings_mounted():
		if not attach_to_rig(rig):
			return

	_sim_time += delta
	var safe_dt: float = maxf(delta, 0.001)
	var speed: float = velocity_px_s.length()
	var speed_norm: float = clampf(speed / 320.0, 0.0, 1.0)
	var move_dir: Vector2 = velocity_px_s / speed if speed > 1.0 else _prev_move_dir
	var accel_vec: Vector2 = (velocity_px_s - _prev_vel) / safe_dt
	var prev_speed: float = _prev_vel.length()
	var speed_delta: float = (speed - prev_speed) / safe_dt

	# Detectar frenado brusco / aceleración -> kick y pulso de freno
	if speed_delta < -750.0 and prev_speed > 80.0:
		_brake_pulse = 1.0
		_kick_spring = clampf(_kick_spring - 0.65, -1.0, 1.0)
	elif speed_delta > 750.0:
		_kick_spring = clampf(_kick_spring + 0.55, -1.0, 1.0)

	var turn_cross: float = 0.0
	if speed > 30.0 and _prev_move_dir.length_squared() > 0.5:
		turn_cross = _prev_move_dir.cross(move_dir)
		_bank_smooth = lerpf(_bank_smooth, clampf(turn_cross * 3.8, -1.0, 1.0), clampf(delta * 8.0, 0.0, 1.0))
	else:
		_bank_smooth = lerpf(_bank_smooth, 0.0, clampf(delta * 6.0, 0.0, 1.0))

	_kick_spring = lerpf(_kick_spring, 0.0, clampf(delta * 8.5, 0.0, 1.0))
	_brake_pulse = maxf(0.0, _brake_pulse - delta * 3.8)
	_prev_vel = velocity_px_s
	if speed > 5.0:
		_prev_move_dir = move_dir

	# Empuje Newtoniano Asimétrico:
	# Moverse/acelerar hacia +X (derecha) -> empuja fuerte el ala IZQUIERDA (_effort_l).
	# Moverse/acelerar hacia -X (izquierda) -> empuja fuerte el ala DERECHA (_effort_r).
	var lateral_push: float = clampf(velocity_px_s.x / 240.0 + accel_vec.x / 1400.0, -1.0, 1.0)
	var base_drive: float = clampf(speed_norm * 0.90 + clampf(absf(velocity_px_s.y) / 260.0, 0.0, 0.45), 0.0, 1.0)
	var asym: float = config.effort_asymmetry_gain
	var target_l: float = clampf(base_drive * (1.0 + maxf(0.0, lateral_push) * asym - maxf(0.0, -lateral_push) * asym * 0.62), 0.0, 1.0)
	var target_r: float = clampf(base_drive * (1.0 + maxf(0.0, -lateral_push) * asym - maxf(0.0, lateral_push) * asym * 0.62), 0.0, 1.0)
	if is_burst_active or _brake_pulse > 0.15:
		var surge: float = 1.0 if is_burst_active else _brake_pulse
		target_l = maxf(target_l, surge)
		target_r = maxf(target_r, surge)

	var eff_lerp: float = clampf(delta * config.effort_smooth_rate, 0.0, 1.0)
	_effort_l = lerpf(_effort_l, target_l, eff_lerp)
	_effort_r = lerpf(_effort_r, target_r, eff_lerp)

	# Apertura global suave Idle (0) <-> Vuelo (1)
	var target_open: float = clampf(speed_norm * 1.15 + (0.25 if is_burst_active else 0.0) + _brake_pulse * 0.4, 0.0, 1.0)
	_open_factor = lerpf(_open_factor, target_open, clampf(delta * config.open_smooth_rate, 0.0, 1.0))

	# 1. Enrutado 8-dir con puente 2.5D Squash-X + animación de las 12 cuchillas psíquicas
	var detected_dir: String = _detect_rig_dir(rig)
	_step_turn_bridge(delta, detected_dir)
	_age_warp_effects(delta)

	_update_wing_and_blade_transforms(delta, rig, velocity_px_s, is_burst_active)

	# 2. 12 Cintas Rojas en espacio mundo
	_update_ribbons(delta, speed)

	# 3. Polvo Estelar
	_update_stardust(delta, rig, velocity_px_s, speed)
	queue_redraw()


func _draw() -> void:
	if config == null:
		return
	var inv_scale: float = _get_world_draw_inv_scale()
	if not _warp_ghosts.is_empty():
		_draw_warp_ghosts(inv_scale)
	if not _warp_arcs.is_empty():
		_draw_warp_arcs(inv_scale)
	if not config.stardust_enabled or _stardust.is_empty():
		return
	for p: Dictionary in _stardust:
		var age: float = float(p["age"])
		var life: float = maxf(0.01, float(p["life"]))
		var t: float = clampf(age / life, 0.0, 1.0)
		var fade: float = sin(t * PI)
		var twinkle: float = 0.72 + 0.28 * sin(_sim_time * 11.0 + float(p["phase"]))
		var ruby_col: Color = _get_effective_accent_color(config.stardust_ruby_color)
		var col: Color = ruby_col if bool(p["is_ruby"]) else config.stardust_silver_color
		col.a *= fade * twinkle
		var sz: float = float(p["size"]) * (0.65 + 0.35 * (1.0 - t)) * inv_scale
		_draw_four_point_star(to_local(p["pos"] as Vector2), sz, col)


func _draw_warp_ghosts(inv_scale: float) -> void:
	var base_ghost_tint: Color = _get_effective_accent_color(config.warp_ghost_color)
	for g: Dictionary in _warp_ghosts:
		var age: float = float(g["age"])
		var life: float = maxf(0.001, float(g["life"]))
		var t: float = clampf(age / life, 0.0, 1.0)
		var alpha: float = config.warp_ghost_opacity * float(g["alpha_mult"]) * (1.0 - t) * (1.0 - t)
		if alpha <= 0.01:
			continue
		var tint: Color = base_ghost_tint
		tint.a = alpha
		var g_pos: Vector2 = g["pos_world"] as Vector2
		var g_scale: Vector2 = g["scale_vec"] as Vector2
		var local_scale: Vector2 = g_scale * inv_scale
		for b_v: Variant in (g["blades"] as Array):
			var b: Dictionary = b_v as Dictionary
			var tex: Texture2D = b["tex"] as Texture2D
			if tex == null:
				continue
			var blade_world: Vector2 = g_pos + (b["local_pos"] as Vector2) * g_scale
			draw_set_transform(to_local(blade_world), float(b["rot"]), local_scale)
			draw_texture(tex, b["offset"] as Vector2, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_warp_arcs(inv_scale: float) -> void:
	const SEGMENTS: int = 10
	for arc: Dictionary in _warp_arcs:
		var age: float = float(arc["age"])
		var life: float = maxf(0.001, float(arc["life"]))
		var t: float = clampf(age / life, 0.0, 1.0)
		var u_start: float = pow(t, 1.35)
		var alpha: float = config.warp_arc_color.a * (1.0 - t)
		if alpha <= 0.01 or u_start >= 0.99:
			continue
		var p0: Vector2 = arc["p0"] as Vector2
		var pc: Vector2 = arc["pc"] as Vector2
		var p1: Vector2 = arc["p1"] as Vector2
		var base_w: float = float(arc["width"]) * (1.0 - t * 0.6) * inv_scale
		var prev_local: Vector2 = to_local(_eval_quad_bezier(p0, pc, p1, u_start))
		for s: int in range(1, SEGMENTS + 1):
			var seg_frac: float = float(s) / float(SEGMENTS)
			var u: float = lerpf(u_start, 1.0, seg_frac)
			var cur_local: Vector2 = to_local(_eval_quad_bezier(p0, pc, p1, u))
			var col: Color = _get_effective_accent_color(config.warp_arc_color)
			col.a = alpha * lerpf(0.25, 1.0, seg_frac)
			var seg_w: float = maxf(0.8, base_w * lerpf(0.20, 1.0, seg_frac))
			draw_line(prev_local, cur_local, col, seg_w, true)
			prev_local = cur_local


func _eval_quad_bezier(p0: Vector2, pc: Vector2, p1: Vector2, u: float) -> Vector2:
	var inv_u: float = 1.0 - u
	return (inv_u * inv_u) * p0 + (2.0 * inv_u * u) * pc + (u * u) * p1


func _get_world_draw_inv_scale() -> float:
	if not is_inside_tree():
		return 1.0
	return 1.0 / maxf(0.1, absf(global_scale.x))


func _draw_four_point_star(center: Vector2, radius: float, col: Color) -> void:
	var inner: float = radius * 0.26
	var pts := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(inner, -inner),
		center + Vector2(radius, 0.0),
		center + Vector2(inner, inner),
		center + Vector2(0.0, radius),
		center + Vector2(-inner, inner),
		center + Vector2(-radius, 0.0),
		center + Vector2(-inner, -inner),
	])
	draw_colored_polygon(pts, col)


func _update_wing_and_blade_transforms(delta: float, rig: Node2D, velocity_px_s: Vector2, is_burst_active: bool) -> void:
	if _under_mount == null or _over_mount == null:
		return
	var show_wings: bool = config.wings_enabled
	_under_mount.visible = show_wings
	_over_mount.visible = show_wings
	if _glow_under_layer != null:
		_glow_under_layer.visible = show_wings
	if _glow_over_layer != null:
		_glow_over_layer.visible = show_wings
	if not show_wings:
		return

	var anchor_local: Vector2 = _get_chest_anchor_in_unified(rig) + config.shoulder_anchor_offset_du
	var body_pivot: Node2D = rig.get_node_or_null("UnifiedCharacterGroup/BodyPivot") as Node2D
	var body_rot: float = body_pivot.rotation if body_pivot != null else 0.0
	var body_scale: Vector2 = body_pivot.scale if body_pivot != null else Vector2.ONE

	_under_mount.position = anchor_local
	_under_mount.rotation = body_rot
	_under_mount.scale = body_scale
	_over_mount.position = anchor_local
	_over_mount.rotation = body_rot
	_over_mount.scale = body_scale

	var views: Dictionary = _meta.get("views", {}) as Dictionary
	var vinfo: Dictionary = views.get(_current_dir, {}) as Dictionary
	var rear_darken: float = minf(float(vinfo.get("rear_darken", 1.0)), 0.78)

	# Deslizamiento lineal independiente por ala (sin rotación circular del pivote)
	var spread_base: float = config.wing_root_spread_x_du
	var brake_slide: float = _brake_pulse * config.brake_spread_extra_du
	var slide_l: float = _effort_l * config.thrust_linear_slide_du + brake_slide
	var slide_r: float = _effort_r * config.thrust_linear_slide_du + brake_slide

	var scale_base: float = config.wing_scale * lerpf(config.idle_scale_factor, config.flight_scale_factor, _open_factor) / _tex_scale
	var target_scale_l: float = scale_base * (1.0 + _effort_l * 0.05)
	var target_scale_r: float = scale_base * (1.0 + _effort_r * 0.05)

	# Flotación mágica del anillo orbital + lag suavizado exponencialmente
	var hover_y: float = sin(_sim_time * TAU * config.idle_breathe_hz) * 4.5
	_smooth_drag_lag = _smooth_drag_lag.lerp(-velocity_px_s.limit_length(320.0) * 0.028, 1.0 - exp(-7.5 * delta))

	var target_pos_l := Vector2.ZERO
	var target_pos_r := Vector2.ZERO
	var target_rot_l: float = 0.0
	var target_rot_r: float = 0.0

	if _current_dir == "e":
		target_pos_l = Vector2(-(spread_base * 1.18 + 22.0 + slide_l), -16.0 + hover_y) + _smooth_drag_lag
		target_pos_r = Vector2(-(spread_base * 0.85 + slide_r), 4.0 + hover_y) + _smooth_drag_lag
		target_scale_l *= 0.86
	elif _current_dir == "w":
		target_pos_r = Vector2((spread_base * 1.18 + 22.0 + slide_r), -16.0 + hover_y) + _smooth_drag_lag
		target_pos_l = Vector2((spread_base * 0.85 + slide_l), 4.0 + hover_y) + _smooth_drag_lag
		target_scale_r *= 0.86
	elif _current_dir in ["se", "ne"]:
		target_pos_l = Vector2(-(spread_base * 1.02 + slide_l), -8.0 + hover_y) + _smooth_drag_lag
		target_pos_r = Vector2((spread_base * 0.86 + slide_r), 2.0 + hover_y) + _smooth_drag_lag
	elif _current_dir in ["sw", "nw"]:
		target_pos_l = Vector2(-(spread_base * 0.86 + slide_l), 2.0 + hover_y) + _smooth_drag_lag
		target_pos_r = Vector2((spread_base * 1.02 + slide_r), -8.0 + hover_y) + _smooth_drag_lag
	else:
		target_pos_l = Vector2(-(spread_base + slide_l), hover_y) + _smooth_drag_lag
		target_pos_r = Vector2((spread_base + slide_r), hover_y) + _smooth_drag_lag

	var did_snap_l: bool = _snap_pos_l_next and _has_smooth_init
	var did_snap_r: bool = _snap_pos_r_next and _has_smooth_init
	var old_root_l: Vector2 = _wing_l_pivot.global_position if (did_snap_l and _wing_l_pivot.is_inside_tree()) else Vector2.ZERO
	var old_root_r: Vector2 = _wing_r_pivot.global_position if (did_snap_r and _wing_r_pivot.is_inside_tree()) else Vector2.ZERO
	var old_tips_l: Array[Vector2] = _capture_blade_world_tips(_blades_l) if did_snap_l else ([] as Array[Vector2])
	var old_tips_r: Array[Vector2] = _capture_blade_world_tips(_blades_r) if did_snap_r else ([] as Array[Vector2])

	var smooth_k: float = 1.0 - exp(-11.0 * delta)
	if not _has_smooth_init:
		_smooth_pos_l = target_pos_l
		_smooth_pos_r = target_pos_r
		_smooth_rot_l = target_rot_l
		_smooth_rot_r = target_rot_r
		_smooth_scale_l = target_scale_l
		_smooth_scale_r = target_scale_r
		_has_smooth_init = true
		_snap_pos_l_next = false
		_snap_pos_r_next = false
	else:
		if _snap_pos_l_next:
			_smooth_pos_l = target_pos_l
			_snap_pos_l_next = false
		else:
			_smooth_pos_l = _smooth_pos_l.lerp(target_pos_l, smooth_k)
		if _snap_pos_r_next:
			_smooth_pos_r = target_pos_r
			_snap_pos_r_next = false
		else:
			_smooth_pos_r = _smooth_pos_r.lerp(target_pos_r, smooth_k)
		_smooth_rot_l = lerpf(_smooth_rot_l, target_rot_l, smooth_k)
		_smooth_rot_r = lerpf(_smooth_rot_r, target_rot_r, smooth_k)
		_smooth_scale_l = lerpf(_smooth_scale_l, target_scale_l, smooth_k)
		_smooth_scale_r = lerpf(_smooth_scale_r, target_scale_r, smooth_k)

	_wing_l_pivot.position = _smooth_pos_l
	_wing_r_pivot.position = _smooth_pos_r
	_wing_l_pivot.rotation_degrees = _smooth_rot_l
	_wing_r_pivot.rotation_degrees = _smooth_rot_r
	_wing_l_pivot.scale = Vector2(_smooth_scale_l * _turn_scale_x_l, _smooth_scale_l * _turn_scale_y_l)
	_wing_r_pivot.scale = Vector2(_smooth_scale_r * _turn_scale_x_r, _smooth_scale_r * _turn_scale_y_r)

	var mod_l: Color = Color(rear_darken, rear_darken, rear_darken, 0.92) if _current_dir == "e" else Color(1.0, 1.0, 1.0, 1.0)
	var mod_r: Color = Color(rear_darken, rear_darken, rear_darken, 0.92) if _current_dir == "w" else Color(1.0, 1.0, 1.0, 1.0)
	var sweep_l: float = 1.0 if _current_dir == "w" else -1.0
	var sweep_r: float = -1.0 if _current_dir == "e" else 1.0

	_animate_wing_blades(_blades_l, _glow_sprites_l, show_wings, sweep_l, _effort_l, mod_l)
	_animate_wing_blades(_blades_r, _glow_sprites_r, show_wings, sweep_r, _effort_r, mod_r)

	if config.warp_streak_enabled:
		if did_snap_l:
			_spawn_warp_effect(rig, _blades_l, _wing_l_pivot, _smooth_scale_l, old_root_l, old_tips_l)
		if did_snap_r:
			_spawn_warp_effect(rig, _blades_r, _wing_r_pivot, _smooth_scale_r, old_root_r, old_tips_r)

	# Sobrecarga de Vetas + Rim Carmesí + Luz Roja HDR externa diferenciada por ala
	_glow_intensity_l = _apply_side_effort_shader(_side_materials_l, _glow_mats_l, _effort_l, is_burst_active)
	_glow_intensity_r = _apply_side_effort_shader(_side_materials_r, _glow_mats_r, _effort_r, is_burst_active)


func _capture_blade_world_tips(blades: Array[Dictionary]) -> Array[Vector2]:
	var tips: Array[Vector2] = []
	for b: Dictionary in blades:
		if bool(b["active"]):
			var tip_m: Marker2D = b["tip"] as Marker2D
			var wpos: Vector2 = b.get("clean_tip_world", tip_m.global_position if tip_m.is_inside_tree() else Vector2.ZERO) as Vector2
			tips.append(wpos)
	return tips


func _spawn_warp_effect(
	rig: Node2D,
	blades: Array[Dictionary],
	wing_pivot: Node2D,
	base_scale_val: float,
	old_root_world: Vector2,
	old_tips: Array[Vector2]
) -> void:
	if not is_inside_tree() or not wing_pivot.is_inside_tree() or old_tips.is_empty():
		return
	var new_root_world: Vector2 = wing_pivot.global_position
	var center_world: Vector2 = _under_mount.global_position if (_under_mount != null and _under_mount.is_inside_tree()) else rig.global_position

	# 1. 6 Speed-Arcs curvos conectando cada punta antes y después del snap
	for i: int in range(blades.size()):
		var b: Dictionary = blades[i]
		if not bool(b["active"]):
			continue
		var p0: Vector2 = old_tips[mini(i, old_tips.size() - 1)]
		var tip_m: Marker2D = b["tip"] as Marker2D
		var p1: Vector2 = b.get("clean_tip_world", tip_m.global_position) as Vector2
		if p0.distance_squared_to(p1) < 100.0:
			continue
		var mid: Vector2 = (p0 + p1) * 0.5
		var out_dir: Vector2 = (mid - center_world).normalized() if mid.distance_squared_to(center_world) > 64.0 else Vector2.UP
		var pc: Vector2 = mid + out_dir * config.warp_arc_curve_px
		var tier: float = 1.0 if i == 0 else (0.82 if i == 1 else 0.48)
		_warp_arcs.append({
			"p0": p0,
			"pc": pc,
			"p1": p1,
			"age": 0.0,
			"life": config.warp_arc_lifetime_sec * (1.0 if i < 2 else 0.82),
			"width": config.warp_arc_width_px * tier,
		})

	# 2. 2 Afterimages ultrabreves a lo largo de la trayectoria curva
	var blade_snaps: Array[Dictionary] = []
	for b: Dictionary in blades:
		if bool(b["active"]):
			var piv: Node2D = b["pivot"] as Node2D
			var spr: Sprite2D = b["sprite"] as Sprite2D
			if spr.texture != null:
				blade_snaps.append({
					"tex": spr.texture,
					"local_pos": piv.position,
					"offset": spr.offset,
					"rot": piv.rotation,
				})
	if blade_snaps.is_empty():
		return

	var parent_gs: Vector2 = (wing_pivot.get_parent() as Node2D).global_scale if wing_pivot.get_parent() is Node2D else Vector2.ONE
	var full_world_scale: Vector2 = parent_gs * base_scale_val
	var root_mid: Vector2 = (old_root_world + new_root_world) * 0.5 + Vector2(0.0, -config.warp_arc_curve_px * 0.45)
	var ghost_steps: Array[Array] = [[0.35, 0.55, 0.70], [0.68, 0.78, 1.0]]
	for gs_v: Array in ghost_steps:
		var u_arc: float = float(gs_v[0])
		var smear_sx: float = float(gs_v[1])
		var alpha_mult: float = float(gs_v[2])
		_warp_ghosts.append({
			"pos_world": _eval_quad_bezier(old_root_world, root_mid, new_root_world, u_arc),
			"scale_vec": Vector2(full_world_scale.x * smear_sx, full_world_scale.y * 1.04),
			"age": 0.0,
			"life": config.warp_ghost_lifetime_sec,
			"alpha_mult": alpha_mult,
			"blades": blade_snaps,
		})


func _age_warp_effects(delta: float) -> void:
	var i: int = _warp_arcs.size() - 1
	while i >= 0:
		var age: float = float(_warp_arcs[i]["age"]) + delta
		if age >= float(_warp_arcs[i]["life"]):
			_warp_arcs.remove_at(i)
		else:
			_warp_arcs[i]["age"] = age
		i -= 1

	var j: int = _warp_ghosts.size() - 1
	while j >= 0:
		var age: float = float(_warp_ghosts[j]["age"]) + delta
		if age >= float(_warp_ghosts[j]["life"]):
			_warp_ghosts.remove_at(j)
		else:
			_warp_ghosts[j]["age"] = age
		j -= 1


func _animate_wing_blades(
	blades: Array[Dictionary],
	glow_sprites: Array[Sprite2D],
	show_wings: bool,
	side_sign: float,
	effort: float,
	mod_col: Color
) -> void:
	var wave_t: float = _sim_time * TAU * config.idle_breathe_hz
	var vib_t: float = _sim_time * TAU * config.effort_vibration_hz
	var vib_power: float = pow(clampf(effort, 0.0, 1.0), 1.45)
	var wing_scale_inv: float = 1.0 / maxf(0.5, config.wing_scale)
	var fan_drive: float = _open_factor * 0.65 + effort * 0.35 + _brake_pulse * 0.60

	for i: int in range(blades.size()):
		var b: Dictionary = blades[i]
		var piv: Node2D = b["pivot"] as Node2D
		var spr: Sprite2D = b["sprite"] as Sprite2D
		var tip_m: Marker2D = b["tip"] as Marker2D
		var active: bool = bool(b["active"])
		piv.visible = active
		if not active:
			if i < glow_sprites.size():
				glow_sprites[i].visible = false
			continue

		var fi: float = float(i)
		var blade_t: float = fi / maxf(1.0, float(MAX_SHARDS - 1))  # 0.0 (s0 intocable en ángulo) .. 1.0 (s5)
		var phase: float = fi * config.blade_wave_phase_step + (0.0 if side_sign > 0.0 else 0.9)

		# Onda psíquica en Idle (levitación desfasada arriba->abajo)
		var wave_sin: float = sin(wave_t - phase)
		var wave_cos: float = cos(wave_t * 0.85 - phase)
		var float_px: float = config.blade_wave_float_du * _tex_scale * wing_scale_inv * (1.0 - 0.35 * _open_factor)

		# Apertura lineal coherente: s0 y s1..s5 se deslizan en línea recta alejándose del cuerpo
		var rest_off: Vector2 = b["rest_offset"] as Vector2
		var tip_dir: Vector2 = tip_m.position.normalized() if tip_m.position.length_squared() > 4.0 else Vector2(side_sign, 0.0)
		var radial_dir: Vector2 = rest_off.normalized() if rest_off.length_squared() > 4.0 else tip_dir
		var linear_out_px: float = (config.blade_radial_expand_du * _tex_scale * wing_scale_inv) * (_open_factor * 0.55 + effort * 0.45 + _brake_pulse * 0.50)

		# Pose suave (sin vibración) -> de aquí nace la cinta roja para que nunca haga zigzag
		var smooth_pos: Vector2 = rest_off + radial_dir * (linear_out_px + wave_cos * float_px * 0.35) + Vector2(0.0, wave_sin * float_px)
		# s0 (blade_t == 0.0) conserva su ángulo original intacto; s1..s5 abanican hacia abajo/afuera
		var fan_deg: float = blade_t * config.blade_fan_spread_deg * fan_drive * side_sign
		var wave_rot: float = blade_t * wave_sin * config.blade_wave_amp_deg * side_sign
		var smooth_rot: float = fan_deg + wave_rot

		var parent_piv: Node2D = piv.get_parent() as Node2D
		if parent_piv != null:
			var local_tip_clean: Vector2 = smooth_pos + tip_m.position.rotated(deg_to_rad(smooth_rot))
			b["clean_tip_world"] = parent_piv.to_global(local_tip_clean)

		# Micro-vibración psíquica sutil y contenida (en du reales, independiente de wing_scale)
		var vib_amp_px: float = config.effort_vibration_amp_du * _tex_scale * wing_scale_inv * vib_power
		var vib_vec := Vector2(
			sin(vib_t + fi * 2.17) * vib_amp_px,
			cos(vib_t * 1.13 + fi * 1.73) * vib_amp_px
		)
		var vib_rot: float = (0.15 + 0.85 * blade_t) * sin(vib_t * 0.95 + fi * 1.9) * (0.25 * vib_power)

		piv.position = smooth_pos + vib_vec
		piv.rotation_degrees = smooth_rot + vib_rot
		spr.modulate = mod_col

		if i < glow_sprites.size():
			var gspr: Sprite2D = glow_sprites[i]
			gspr.visible = show_wings and active
			if gspr.visible and spr.is_inside_tree() and gspr.is_inside_tree():
				gspr.global_transform = spr.global_transform


func _apply_side_effort_shader(
	mat_dict: Dictionary,
	glow_dict: Dictionary,
	effort: float,
	is_burst_active: bool
) -> float:
	var eff_curve: float = pow(clampf(effort, 0.0, 1.0), 1.15)
	var emissive_val: float = lerpf(config.idle_emissive_boost, config.thrust_emissive_boost, eff_curve)
	if is_burst_active:
		emissive_val *= 1.25
	if _cosmic_lighting_active:
		emissive_val *= _cosmic_emissive_mult
	var rim_val: float = lerpf(0.25, config.effort_rim_strength, eff_curve)
	var eff_rim_col: Color = _get_effective_accent_color(config.effort_rim_color)
	for mat_v: Variant in mat_dict.values():
		var sm: ShaderMaterial = mat_v as ShaderMaterial
		if sm != null:
			sm.set_shader_parameter("emissive_glow_strength", emissive_val)
			sm.set_shader_parameter("counter_rim_strength", rim_val)
			sm.set_shader_parameter("counter_rim_use_skin_accent", false)
			sm.set_shader_parameter("counter_rim_override_color", eff_rim_col)

	var base_glow: float = lerpf(config.red_glow_idle_intensity, config.red_glow_thrust_intensity, pow(clampf(effort, 0.0, 1.0), 1.1))
	if _brake_pulse > 0.05 or is_burst_active:
		base_glow = maxf(base_glow, config.red_glow_brake_intensity * (1.0 if is_burst_active else _brake_pulse))
	if _cosmic_lighting_active:
		base_glow *= lerpf(1.0, _cosmic_emissive_mult, 0.85)
	var shader_glow: float = (maxf(base_glow, 0.42) if base_glow > 0.05 else base_glow) * _get_star_glow_mult()
	var eff_glow_col: Color = _get_effective_accent_color(config.red_glow_color)
	var pulse_spd: float = lerpf(3.4, 6.2, clampf(effort, 0.0, 1.0))
	var pulse_str: float = lerpf(0.65, 1.15, clampf(effort, 0.0, 1.0))
	var ign_flash: float = clampf(_brake_pulse * 1.2 + (1.2 if is_burst_active else 0.0), 0.0, 2.5)
	for gmat_v: Variant in glow_dict.values():
		var gm: ShaderMaterial = gmat_v as ShaderMaterial
		if gm != null:
			gm.set_shader_parameter("glow_intensity", shader_glow)
			gm.set_shader_parameter("glow_color", eff_glow_col)
			gm.set_shader_parameter("pulse_time", _sim_time)
			gm.set_shader_parameter("pulse_speed", pulse_spd)
			gm.set_shader_parameter("pulse_strength", pulse_str)
			gm.set_shader_parameter("ignition_flash", ign_flash)
	return base_glow


func _apply_view_direction(dir_key: String, force_update: bool) -> void:
	if not force_update and dir_key == _current_dir:
		return
	var views: Dictionary = _meta.get("views", {}) as Dictionary
	if not views.has(dir_key):
		return
	_current_dir = dir_key
	var vinfo: Dictionary = views[dir_key] as Dictionary
	var wing_l_key: String = str(vinfo.get("wing_l", "wing_0deg_l"))
	var wing_r_key: String = str(vinfo.get("wing_r", "wing_0deg_r"))
	var layer_mode: String = str(vinfo.get("layer", "behind_body"))

	_bind_wing_blades(_blades_l, _glow_sprites_l, wing_l_key, _side_materials_l, _glow_mats_l)
	_bind_wing_blades(_blades_r, _glow_sprites_r, wing_r_key, _side_materials_r, _glow_mats_r)

	if layer_mode == "over_back":
		_reparent_keep_zero_z(_wing_l_pivot, _over_mount)
		_reparent_keep_zero_z(_wing_r_pivot, _over_mount)
		_reparent_glow_sprites(_glow_sprites_l, _glow_over_layer)
		_reparent_glow_sprites(_glow_sprites_r, _glow_over_layer)
	elif layer_mode == "split_profile":
		if dir_key == "e":
			_reparent_keep_zero_z(_wing_l_pivot, _under_mount)
			_reparent_keep_zero_z(_wing_r_pivot, _over_mount)
			_reparent_glow_sprites(_glow_sprites_l, _glow_under_layer)
			_reparent_glow_sprites(_glow_sprites_r, _glow_over_layer)
		else:
			_reparent_keep_zero_z(_wing_r_pivot, _under_mount)
			_reparent_keep_zero_z(_wing_l_pivot, _over_mount)
			_reparent_glow_sprites(_glow_sprites_r, _glow_under_layer)
			_reparent_glow_sprites(_glow_sprites_l, _glow_over_layer)
	else:
		_reparent_keep_zero_z(_wing_l_pivot, _under_mount)
		_reparent_keep_zero_z(_wing_r_pivot, _under_mount)
		_reparent_glow_sprites(_glow_sprites_l, _glow_under_layer)
		_reparent_glow_sprites(_glow_sprites_r, _glow_under_layer)


func _reset_turn_bridge_state() -> void:
	_turn_phase = TurnBridgePhase.IDLE
	_turn_timer = 0.0
	_pending_dir = ""
	_turn_start_sx_l = 1.0
	_turn_start_sx_r = 1.0
	_turn_min_sx_l = 1.0
	_turn_min_sx_r = 1.0
	_turn_scale_x_l = 1.0
	_turn_scale_x_r = 1.0
	_turn_scale_y_l = 1.0
	_turn_scale_y_r = 1.0


func _compute_wing_turn_min_scale_x(from_dir: String, to_dir: String, is_left: bool) -> float:
	var crosses_x: bool = ((from_dir == "w") != (to_dir == "w")) if is_left else ((from_dir == "e") != (to_dir == "e"))
	if crosses_x:
		return config.turn_flip_min_scale_x
	var views: Dictionary = _meta.get("views", {}) as Dictionary
	var from_layer: String = str((views.get(from_dir, {}) as Dictionary).get("layer", "behind_body"))
	var to_layer: String = str((views.get(to_dir, {}) as Dictionary).get("layer", "behind_body"))
	if from_layer != to_layer:
		return config.turn_adj_min_scale_x
	return config.turn_adj_min_scale_x


func _mark_wing_snap_for_dir_change(from_dir: String, to_dir: String) -> void:
	if (from_dir == "w") != (to_dir == "w"):
		_snap_pos_l_next = true
	if (from_dir == "e") != (to_dir == "e"):
		_snap_pos_r_next = true


func _step_turn_bridge(delta: float, detected_dir: String) -> void:
	if not config.turn_bridge_enabled:
		if detected_dir != _current_dir:
			_mark_wing_snap_for_dir_change(_current_dir, detected_dir)
			_apply_view_direction(detected_dir, false)
		_reset_turn_bridge_state()
		return

	if detected_dir != _current_dir and detected_dir != _pending_dir:
		_pending_dir = detected_dir
		_turn_phase = TurnBridgePhase.PRE_CUT
		_turn_timer = 0.0
		_turn_start_sx_l = _turn_scale_x_l
		_turn_start_sx_r = _turn_scale_x_r
		_turn_min_sx_l = _compute_wing_turn_min_scale_x(_current_dir, detected_dir, true)
		_turn_min_sx_r = _compute_wing_turn_min_scale_x(_current_dir, detected_dir, false)

	if _turn_phase == TurnBridgePhase.PRE_CUT:
		_turn_timer += delta
		var t: float = clampf(_turn_timer / maxf(0.01, config.turn_pre_cut_sec), 0.0, 1.0)
		var ease_in: float = t * t
		_turn_scale_x_l = lerpf(_turn_start_sx_l, _turn_min_sx_l, ease_in)
		_turn_scale_x_r = lerpf(_turn_start_sx_r, _turn_min_sx_r, ease_in)
		_turn_scale_y_l = lerpf(1.0, config.turn_squash_stretch_y, ease_in * (1.0 - _turn_min_sx_l))
		_turn_scale_y_r = lerpf(1.0, config.turn_squash_stretch_y, ease_in * (1.0 - _turn_min_sx_r))
		if t >= 1.0:
			_mark_wing_snap_for_dir_change(_current_dir, _pending_dir)
			_apply_view_direction(_pending_dir, false)
			_pending_dir = ""
			_turn_phase = TurnBridgePhase.POST_CUT
			_turn_timer = 0.0
	elif _turn_phase == TurnBridgePhase.POST_CUT:
		_turn_timer += delta
		var t: float = clampf(_turn_timer / maxf(0.01, config.turn_post_cut_sec), 0.0, 1.0)
		if t < 0.65:
			var u: float = t / 0.65
			var ease_out: float = 1.0 - pow(1.0 - u, 2.5)
			_turn_scale_x_l = lerpf(_turn_min_sx_l, config.turn_overshoot_scale_x, ease_out)
			_turn_scale_x_r = lerpf(_turn_min_sx_r, config.turn_overshoot_scale_x, ease_out)
		else:
			var u: float = (t - 0.65) / 0.35
			var smooth_u: float = u * u * (3.0 - 2.0 * u)
			_turn_scale_x_l = lerpf(config.turn_overshoot_scale_x, 1.0, smooth_u)
			_turn_scale_x_r = lerpf(config.turn_overshoot_scale_x, 1.0, smooth_u)
		var sy_peak_l: float = lerpf(1.0, config.turn_squash_stretch_y, 1.0 - _turn_min_sx_l)
		var sy_peak_r: float = lerpf(1.0, config.turn_squash_stretch_y, 1.0 - _turn_min_sx_r)
		_turn_scale_y_l = lerpf(sy_peak_l, 1.0, t)
		_turn_scale_y_r = lerpf(sy_peak_r, 1.0, t)
		if t >= 1.0:
			_reset_turn_bridge_state()


func _bind_wing_blades(
	blades: Array[Dictionary],
	glow_sprites: Array[Sprite2D],
	wing_key: String,
	mat_dict: Dictionary,
	glow_dict: Dictionary
) -> void:
	var wings_dict: Dictionary = _meta.get("wings", {}) as Dictionary
	var shard_list: Array = wings_dict.get(wing_key, []) as Array
	for i: int in range(blades.size()):
		var b: Dictionary = blades[i]
		var spr: Sprite2D = b["sprite"] as Sprite2D
		var tip: Marker2D = b["tip"] as Marker2D
		var gspr: Sprite2D = glow_sprites[i] if i < glow_sprites.size() else null
		if i < shard_list.size():
			var sinfo: Dictionary = shard_list[i] as Dictionary
			var pid: String = str(sinfo["id"])
			var piv_arr: Array = sinfo["pivot_px"] as Array
			var tip_arr: Array = sinfo["tip_offset_px"] as Array
			var rest_arr: Array = sinfo["rest_offset_px"] as Array
			var piv_v := Vector2(float(piv_arr[0]), float(piv_arr[1]))
			var tip_v := Vector2(float(tip_arr[0]), float(tip_arr[1]))
			b["rest_offset"] = Vector2(float(rest_arr[0]), float(rest_arr[1]))
			b["length_norm"] = float(sinfo.get("length_norm", 1.0))
			b["piece_id"] = pid
			b["active"] = true
			var albedo_tex: Texture2D = null
			if _shard_textures.has(pid):
				var tex_bundle: Dictionary = _shard_textures[pid] as Dictionary
				albedo_tex = tex_bundle["albedo"] as Texture2D
				spr.texture = albedo_tex
			spr.offset = -piv_v
			if mat_dict.has(pid):
				spr.material = mat_dict[pid] as ShaderMaterial
			tip.position = tip_v - piv_v
			if gspr != null:
				gspr.texture = albedo_tex
				gspr.offset = -piv_v
				if glow_dict.has(pid):
					gspr.material = glow_dict[pid] as ShaderMaterial
		else:
			b["active"] = false
			b["piece_id"] = ""
			if gspr != null:
				gspr.visible = false


func _create_glow_sprites(parent_layer: Node2D, side_tag: String) -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	for i: int in range(MAX_SHARDS):
		var gspr := Sprite2D.new()
		gspr.name = "GlowBlade_%s_%d" % [side_tag, i]
		gspr.centered = false
		gspr.z_index = 0
		gspr.visible = false
		parent_layer.add_child(gspr)
		sprites.append(gspr)
	return sprites


func _reparent_glow_sprites(sprites: Array[Sprite2D], target_layer: Node2D) -> void:
	if target_layer == null:
		return
	for gspr: Sprite2D in sprites:
		_reparent_keep_zero_z(gspr, target_layer)


func _create_blade_slots(parent_pivot: Node2D, side_tag: String) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i: int in range(MAX_SHARDS):
		var bp := Node2D.new()
		bp.name = "Blade_%s_%d" % [side_tag, i]
		bp.z_index = 0
		parent_pivot.add_child(bp)

		var spr := Sprite2D.new()
		spr.name = "Sprite"
		spr.centered = false
		spr.z_index = 0
		bp.add_child(spr)

		var tip := Marker2D.new()
		tip.name = "Tip"
		bp.add_child(tip)

		slots.append({
			"pivot": bp,
			"sprite": spr,
			"tip": tip,
			"rest_offset": Vector2.ZERO,
			"length_norm": 1.0,
			"active": false,
			"piece_id": "",
		})
	return slots


func _reparent_keep_zero_z(node: Node2D, target_parent: Node2D) -> void:
	if node == null or target_parent == null or node.get_parent() == target_parent:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	target_parent.add_child(node)
	node.z_index = 0


func _update_ribbons(delta: float, speed: float) -> void:
	if config == null or not config.ribbons_enabled or not config.wings_enabled:
		for r: Dictionary in _ribbons_l:
			(r["pts"] as Array).clear()
		for r: Dictionary in _ribbons_r:
			(r["pts"] as Array).clear()
		_sync_all_ribbon_lines()
		return

	_step_side_ribbons(_ribbons_l, _blades_l, delta, speed)
	_step_side_ribbons(_ribbons_r, _blades_r, delta, speed)
	_sync_all_ribbon_lines()


func _step_side_ribbons(ribbons: Array[Dictionary], blades: Array[Dictionary], delta: float, speed: float) -> void:
	for i: int in range(ribbons.size()):
		var r: Dictionary = ribbons[i]
		var pts: Array = r["pts"] as Array
		var is_primary: bool = i < 2
		var life_mult: float = 1.0 if is_primary else lerpf(config.ribbon_secondary_scale, 0.85, 0.35)
		var life: float = maxf(0.06, config.ribbon_lifetime_sec * life_mult)

		var j: int = pts.size() - 1
		while j >= 0:
			var age: float = float((pts[j] as Dictionary)["age"]) + delta
			if age >= life:
				pts.remove_at(j)
			else:
				(pts[j] as Dictionary)["age"] = age
			j -= 1

		if speed >= config.ribbon_min_speed_px_s and i < blades.size() and bool(blades[i]["active"]):
			var wpos: Vector2 = blades[i].get("clean_tip_world", (blades[i]["tip"] as Marker2D).global_position) as Vector2
			var max_pts: int = config.ribbon_max_points if is_primary else maxi(6, int(roundf(float(config.ribbon_max_points) * life_mult)))
			if pts.is_empty():
				pts.push_front({"pos": wpos, "age": 0.0})
			else:
				var prev_p: Vector2 = (pts[0] as Dictionary)["pos"] as Vector2
				var dist_sq: float = prev_p.distance_squared_to(wpos)
				# Si hubo salto de vista 8-dir (> 90 px en un frame), cortar cinta suavemente sin línea recta cruzada
				if dist_sq > 8100.0:
					pts.clear()
					pts.push_front({"pos": wpos, "age": 0.0})
				elif dist_sq >= 9.0:
					pts.push_front({"pos": wpos, "age": 0.0})
					while pts.size() > max_pts:
						pts.pop_back()


func _sync_all_ribbon_lines() -> void:
	_sync_side_ribbon_lines(_ribbons_l, _blades_l, _effort_l)
	_sync_side_ribbon_lines(_ribbons_r, _blades_r, _effort_r)


func _sync_side_ribbon_lines(ribbons: Array[Dictionary], blades: Array[Dictionary], effort: float) -> void:
	if config == null:
		return
	var eff_boost: float = 1.0 + effort * config.ribbon_effort_boost
	var inv_scale: float = _get_world_draw_inv_scale()
	for i: int in range(ribbons.size()):
		var r: Dictionary = ribbons[i]
		var pts: Array = r["pts"] as Array
		var outer: Line2D = r["outer"] as Line2D
		var grad_out: Gradient = r["grad_out"] as Gradient

		var packed := PackedVector2Array()
		for entry: Variant in pts:
			packed.append(to_local((entry as Dictionary)["pos"] as Vector2))
		outer.points = packed

		var is_primary: bool = i < 2
		var len_norm: float = float(blades[i]["length_norm"]) if i < blades.size() else 0.6
		var tier_w: float = (1.0 if i == 0 else 0.84) if is_primary else (config.ribbon_secondary_scale * lerpf(0.7, 1.0, len_norm))
		var w: float = config.ribbon_width_px * tier_w * (0.90 + 0.22 * effort)
		outer.width = maxf(1.2, w) * inv_scale

		var tier_alpha: float = 1.0 if is_primary else 0.68
		var alpha: float = clampf(config.ribbon_opacity * tier_alpha * _open_factor * 1.25 * eff_boost, 0.0, 0.92)

		var base_rib_col: Color = _get_effective_accent_color(config.ribbon_primary_color)
		var c_out_h: Color = base_rib_col
		c_out_h.a = alpha
		var c_out_t: Color = base_rib_col
		c_out_t.a = 0.0
		grad_out.set_color(0, c_out_h)
		grad_out.set_color(1, c_out_t)


func _update_stardust(delta: float, rig: Node2D, velocity_px_s: Vector2, speed: float) -> void:
	if config == null or not config.stardust_enabled:
		_stardust.clear()
		return

	var i: int = _stardust.size() - 1
	while i >= 0:
		var p: Dictionary = _stardust[i]
		var age: float = float(p["age"]) + delta
		if age >= float(p["life"]):
			_stardust.remove_at(i)
		else:
			p["age"] = age
			p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
			p["vel"] = (p["vel"] as Vector2) * pow(0.28, delta)
		i -= 1

	var max_eff: float = maxf(_effort_l, _effort_r)
	var rate: float = lerpf(config.stardust_idle_rate_hz, config.stardust_flight_rate_hz, maxf(_open_factor, max_eff))
	_stardust_accum += rate * delta
	while _stardust_accum >= 1.0 and _stardust.size() < config.stardust_max_particles:
		_stardust_accum -= 1.0
		var spawn_pos: Vector2 = rig.global_position
		var use_left: bool = _rng.randf() < (0.5 + (_effort_l - _effort_r) * 0.35)
		var pool: Array[Dictionary] = _blades_l if use_left else _blades_r
		var active_indices: Array[int] = []
		for bi: int in range(pool.size()):
			if bool(pool[bi]["active"]):
				active_indices.append(bi)
		if not active_indices.is_empty():
			var pick: int = active_indices[_rng.randi_range(0, active_indices.size() - 1)]
			var tip_p: Vector2 = (pool[pick]["tip"] as Marker2D).global_position
			spawn_pos = rig.global_position.lerp(tip_p, _rng.randf_range(0.45, 1.0))
		spawn_pos += Vector2(_rng.randf_range(-18.0, 18.0), _rng.randf_range(-18.0, 18.0))

		var drift: Vector2 = Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-26.0, 12.0))
		if speed > 30.0:
			drift -= velocity_px_s * 0.14
		_stardust.append({
			"pos": spawn_pos,
			"vel": drift,
			"age": 0.0,
			"life": config.stardust_lifetime_sec * _rng.randf_range(0.75, 1.25),
			"size": config.stardust_size_px * _rng.randf_range(0.65, 1.25),
			"is_ruby": _rng.randf() < (0.52 + max_eff * 0.28),
			"phase": _rng.randf_range(0.0, TAU),
		})


func _build_world_ribbons() -> void:
	var width_curve := Curve.new()
	width_curve.add_point(Vector2(0.0, 1.0))
	width_curve.add_point(Vector2(0.55, 0.55))
	width_curve.add_point(Vector2(1.0, 0.04))

	_ribbons_l = _create_ribbon_side("L", width_curve)
	_ribbons_r = _create_ribbon_side("R", width_curve)


func _create_ribbon_side(side_tag: String, curve: Curve) -> Array[Dictionary]:
	var arr: Array[Dictionary] = []
	for i: int in range(MAX_SHARDS):
		var grad_out := Gradient.new()
		grad_out.colors = PackedColorArray([Color(0.92, 0.05, 0.18, 0.0), Color(0.92, 0.05, 0.18, 0.0)])

		var outer := Line2D.new()
		outer.name = "Ribbon_%s_%d" % [side_tag, i]
		outer.width_curve = curve
		outer.gradient = grad_out
		outer.joint_mode = Line2D.LINE_JOINT_ROUND
		outer.begin_cap_mode = Line2D.LINE_CAP_ROUND
		outer.end_cap_mode = Line2D.LINE_CAP_ROUND
		outer.antialiased = true
		add_child(outer)

		arr.append({
			"outer": outer,
			"grad_out": grad_out,
			"pts": [],
		})
	return arr


func _detect_rig_dir(rig: Node2D) -> String:
	var body_pivot: Node = rig.get_node_or_null("UnifiedCharacterGroup/BodyPivot")
	if body_pivot != null:
		for child: Node in body_pivot.get_children():
			if child is Node2D and (child as Node2D).visible and child.name.begins_with("BodyView_"):
				return child.name.substr("BodyView_".length()).to_lower()
	return _current_dir


func _get_chest_anchor_in_unified(rig: Node2D) -> Vector2:
	var unified: Node2D = rig.get_node_or_null("UnifiedCharacterGroup") as Node2D
	var body_pivot: Node2D = rig.get_node_or_null("UnifiedCharacterGroup/BodyPivot") as Node2D
	if unified == null or body_pivot == null:
		return Vector2.ZERO
	var view_node: Node2D = body_pivot.get_node_or_null("BodyView_" + _current_dir.to_upper()) as Node2D
	if view_node != null:
		var chest: Node2D = view_node.get_node_or_null("Skeleton2D/Pelvis/Waist/Chest") as Node2D
		if chest != null:
			return unified.to_local(chest.global_position)
	return body_pivot.position + Vector2(0.0, -70.0)


func _find_body_core_material(rig: Node2D) -> ShaderMaterial:
	var body_pivot: Node = rig.get_node_or_null("UnifiedCharacterGroup/BodyPivot")
	if body_pivot == null:
		return null
	for child: Node in body_pivot.get_children():
		var part: CanvasItem = child.get_node_or_null("Meshes/Part_body_core") as CanvasItem
		if part != null and part.material is ShaderMaterial:
			return part.material as ShaderMaterial
	return null


func _build_piece_material(template_mat: ShaderMaterial, bundle: Dictionary) -> ShaderMaterial:
	var mat: ShaderMaterial = null
	if template_mat != null:
		mat = template_mat.duplicate() as ShaderMaterial
	else:
		if _stylizer_shader == null and ResourceLoader.exists(STYLIZER_SHADER_PATH):
			_stylizer_shader = ResourceLoader.load(STYLIZER_SHADER_PATH) as Shader
		mat = ShaderMaterial.new()
		mat.shader = _stylizer_shader

	mat.set_shader_parameter("id_mask_tex", bundle["id"] as Texture2D)
	mat.set_shader_parameter("ilm_mask_tex", bundle["ilm"] as Texture2D)
	mat.set_shader_parameter("has_ilm_mask", true)
	mat.set_shader_parameter("normal_depth_tex", bundle["normal"] as Texture2D)
	mat.set_shader_parameter("use_normal_depth", true)
	mat.set_shader_parameter("ink_sdf_tex", bundle["ink_sdf"] as Texture2D)
	mat.set_shader_parameter("has_ink_sdf", true)
	mat.set_shader_parameter("enable_secondary_jiggle", false)
	mat.set_shader_parameter("has_pauldron_mask", false)
	mat.set_shader_parameter("enable_face_live", false)
	mat.set_shader_parameter("head_layer_pass", 0)
	mat.set_shader_parameter("leg_layer_pass", 0)
	mat.set_shader_parameter("persp_mode", 0)
	mat.set_shader_parameter("enable_part_edge_outline", false)
	return mat


func _build_glow_material(bundle: Dictionary) -> ShaderMaterial:
	if _glow_shader == null and ResourceLoader.exists(RED_GLOW_SHADER_PATH):
		_glow_shader = ResourceLoader.load(RED_GLOW_SHADER_PATH) as Shader
	var mat := ShaderMaterial.new()
	mat.shader = _glow_shader
	mat.set_shader_parameter("ilm_mask_tex", bundle["ilm"] as Texture2D)
	mat.set_shader_parameter("glow_color", _get_effective_accent_color(config.red_glow_color if config != null else Color(1.0, 0.08, 0.22, 1.0)))
	var init_glow: float = config.red_glow_idle_intensity if config != null else 0.12
	mat.set_shader_parameter("glow_intensity", maxf(init_glow, 0.42) if init_glow > 0.05 else init_glow)
	mat.set_shader_parameter("blade_pivot_uv", bundle.get("blade_pivot_uv", Vector2(0.05, 0.95)))
	mat.set_shader_parameter("blade_tip_uv", bundle.get("blade_tip_uv", Vector2(0.95, 0.05)))
	mat.set_shader_parameter("pulse_phase_offset", float(bundle.get("shard_index", 0)) * 0.17)
	return mat


func _resolve_profile_settings(rig: Node2D) -> void:
	if rig == null:
		return
	var prof_v: Variant = rig.get("pilot_profile")
	if not (prof_v is PilotRigProfile):
		return
	var prof: PilotRigProfile = prof_v as PilotRigProfile
	if not prof.assets_root.is_empty() and not prof.wings_assets_subdir.is_empty():
		var desired_dir: String = prof.assets_root.path_join(prof.wings_assets_subdir)
		var desired_meta: String = desired_dir.path_join("wings_metadata.json")
		if FileAccess.file_exists(ProjectSettings.globalize_path(desired_meta)):
			set_assets_dir(desired_dir)
	if not _has_explicit_config and prof.base_propulsion_config is BasePropConfigScript:
		config = prof.base_propulsion_config as BasePropConfigScript


func _load_assets() -> void:
	_meta.clear()
	_shard_textures.clear()
	var abs_meta: String = ProjectSettings.globalize_path(_meta_path)
	if not FileAccess.file_exists(abs_meta):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(abs_meta))
	if not (parsed is Dictionary):
		return
	_meta = parsed as Dictionary
	_tex_scale = maxf(1.0, float(_meta.get("tex_scale", 3.0)))

	var wings_dict: Dictionary = _meta.get("wings", {}) as Dictionary
	for wing_key: String in wings_dict.keys():
		var shard_list: Array = wings_dict[wing_key] as Array
		for sinfo_v: Variant in shard_list:
			var sinfo: Dictionary = sinfo_v as Dictionary
			var pid: String = str(sinfo["id"])
			if _shard_textures.has(pid):
				continue
			var sz_arr: Array = sinfo.get("size_px", [256, 256]) as Array
			var piv_arr: Array = sinfo.get("pivot_px", [0.0, 256.0]) as Array
			var tip_arr: Array = sinfo.get("tip_offset_px", [256.0, 0.0]) as Array
			var tex_sz := Vector2(maxf(1.0, float(sz_arr[0])), maxf(1.0, float(sz_arr[1])))
			var piv_px := Vector2(float(piv_arr[0]), float(piv_arr[1]))
			var tip_px := Vector2(float(tip_arr[0]), float(tip_arr[1]))
			_shard_textures[pid] = {
				"albedo": _load_tex("%s/%s.png" % [_assets_dir, pid], true),
				"id": _load_tex("%s/%s_id_mask.png" % [_assets_dir, pid], true),
				"ilm": _load_tex("%s/%s_ilm_mask.png" % [_assets_dir, pid], true),
				"normal": _load_tex("%s/%s_normal_depth.png" % [_assets_dir, pid], true),
				"ink_sdf": _load_tex("%s/%s_ink_sdf.png" % [_assets_dir, pid], false),
				"blade_pivot_uv": (piv_px / tex_sz).clamp(Vector2.ZERO, Vector2.ONE),
				"blade_tip_uv": (tip_px / tex_sz).clamp(Vector2.ZERO, Vector2.ONE),
				"shard_index": int(sinfo.get("shard_index", 0)),
			}


func _load_tex(res_path: String, use_mipmaps: bool) -> ImageTexture:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		return null
	var img := Image.new()
	if img.load(abs_path) != OK:
		return null
	if use_mipmaps:
		img.generate_mipmaps()
	else:
		img.clear_mipmaps()
	return ImageTexture.create_from_image(img)


func _detach_from_rig() -> void:
	if is_instance_valid(_under_mount):
		_under_mount.queue_free()
	if is_instance_valid(_over_mount):
		_over_mount.queue_free()
	if is_instance_valid(_glow_under_layer):
		_glow_under_layer.queue_free()
	if is_instance_valid(_glow_over_layer):
		_glow_over_layer.queue_free()
	_under_mount = null
	_over_mount = null
	_glow_under_layer = null
	_glow_over_layer = null
	_wing_l_pivot = null
	_wing_r_pivot = null
	_blades_l.clear()
	_blades_r.clear()
	_glow_sprites_l.clear()
	_glow_sprites_r.clear()
	_has_smooth_init = false
	_snap_pos_l_next = false
	_snap_pos_r_next = false
	_warp_arcs.clear()
	_warp_ghosts.clear()
	_reset_turn_bridge_state()
	_attached_rig = null
