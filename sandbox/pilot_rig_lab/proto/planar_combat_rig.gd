class_name PlanarCombatRig
extends Node2D
## Orquestador modular del Rig de Combate Planar 8-Direcciones + Cabeza Desacoplada.
## Delega en componentes especializados:
## - PlanarRigViewRouter: resolución de vistas S/N, Flip-H y cabezas 8-dir.
## - PlanarRigTransitionController: transiciones snappy (modos 4..6).
## - PlanarRigSecondaryPhysics: whiplash de extremidades y resortes 2D (busto/cabello).
## - PlanarRigWingsVFX: alas procedurales, propulsores y estela Sandevistan.
## - PlanarRigMaterialController: perfiles de estilo, skins, pelo, iluminación 2.5D y hit_flash.

const SHADER_PATH: String = "res://sandbox/pilot_rig_lab/pilot_rig_stylizer.gdshader"
const PASS2_SHADER_PATH: String = "res://sandbox/pilot_rig_lab/pilot_rig_pass2.gdshader"
const DEFAULT_PILOT_PROFILE_PATH: String = "res://sandbox/pilot_rig_lab/pilots/valentina/valentina_profile.tres"
const ANIM_CONFIG_PATH: String = "res://sandbox/pilot_rig_lab/combat_assets/valentina_planar/valentina_anim_config.tres"

const MeshBuilder = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_mesh_builder.gd")
const RigAnimator = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_animator.gd")
const AnimConfigScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_anim_config.gd")
const ViewRouterScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_view_router.gd")
const TransitionCtrlScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_transition_controller.gd")
const SecondaryPhysScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_secondary_physics.gd")
const WingsVFXScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_wings_vfx.gd")
const MaterialCtrlScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_material_controller.gd")

enum TransitionStyle {
	WHIP_SNAP_AFTERIMAGE = 4,
	MICRO_FLASH_SNAP = 5,
	HOLO_SNAP_FAST = 6,
}

enum HeadAlignMode {
	CRANIUM_CENTERED = 0,
	TORSO_PERSPECTIVE_COMP = 1,
	SLIM_PROFILES = 2,
}

@export var pilot_profile: Resource = null
@export var display_scale: float = 0.34
@export var enable_procedural_wings: bool = true
@export var enable_boot_thrusters: bool = true
@export var enable_afterimage: bool = false
@export var transition_style: int = TransitionStyle.WHIP_SNAP_AFTERIMAGE
@export var head_align_mode: int = HeadAlignMode.TORSO_PERSPECTIVE_COMP
@export var anim_config: Resource = null
@export var stepped_fps: float = 15.0

var _animator: RigAnimator = null
var _router: PlanarRigViewRouter = null
var _transitions: PlanarRigTransitionController = null
var _physics: PlanarRigSecondaryPhysics = null
var _vfx: PlanarRigWingsVFX = null
var _materials: PlanarRigMaterialController = null

var _conic_lut: GradientTexture2D = null
var _unified_canvas_group: CanvasGroup = null
var _body_pivot: Node2D = null
var _head_shadow_sprite: Sprite2D = null
var _views: Dictionary = {}
var _head_anchor: Node2D = null
var _head_data: Dictionary = {}
var _head_under_anchor: Node2D = null
var _head_under_data: Dictionary = {}

var _move_dir: Vector2 = Vector2.DOWN
var _aim_dir: Vector2 = Vector2.RIGHT
var _smooth_move_dir: Vector2 = Vector2.DOWN
var _smooth_aim_dir: Vector2 = Vector2.RIGHT
var _speed_norm: float = 0.0
var _smooth_speed: float = 0.0
var _flight_phase: float = 0.0
var _turn_bone_kick: float = 0.0
var _static_inspect_enabled: bool = false

var _step_accum: float = 0.0
var _q_time: float = 0.0
var _head_follow_through_timer: float = 0.0
var _pose_hold_timer: float = 0.0
var _prev_input_move_dir: Vector2 = Vector2.DOWN
var _prev_input_speed: float = 0.0
var _loco_event_cooldown: float = 0.0
var _head_spring_pos: Vector2 = Vector2.ZERO
var _head_spring_vel: Vector2 = Vector2.ZERO
var _prev_neck_global_pos: Vector2 = Vector2.ZERO
var _has_prev_neck_pos: bool = false
var _prev_neck_vel: Vector2 = Vector2.ZERO
var _has_prev_neck_vel: bool = false
var _head_rot: float = 0.0
var _head_rot_vel: float = 0.0
var _hit_stop_timer: float = 0.0
var _hit_stop_duration: float = 0.055
var _hit_stop_shake_px: float = 6.0
var _impact_frame_phase: int = 0


func _ready() -> void:
	build_rig()


func load_pilot_profile(profile: PilotRigProfile) -> void:
	pilot_profile = profile
	if profile != null:
		display_scale = profile.display_scale
		anim_config = profile.anim_config
	build_rig()


func build_rig() -> void:
	_hit_stop_timer = 0.0
	_impact_frame_phase = 0
	_step_accum = 0.0
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_views.clear()

	if _router == null:
		_router = ViewRouterScript.new()
	if _transitions == null:
		_transitions = TransitionCtrlScript.new()
	if _physics == null:
		_physics = SecondaryPhysScript.new()
	if _vfx == null:
		_vfx = WingsVFXScript.new()
	if _materials == null:
		_materials = MaterialCtrlScript.new()
	_materials.clear()

	_transitions.set_style(transition_style)

	var resolved_profile: PilotRigProfile = pilot_profile as PilotRigProfile
	if resolved_profile == null and ResourceLoader.exists(DEFAULT_PILOT_PROFILE_PATH):
		resolved_profile = ResourceLoader.load(DEFAULT_PILOT_PROFILE_PATH) as PilotRigProfile
		pilot_profile = resolved_profile

	var pilot_root: String = resolved_profile.assets_root if resolved_profile != null and not resolved_profile.assets_root.is_empty() else MeshBuilder.ASSETS_ROOT
	var accent: Color = resolved_profile.default_accent_color if resolved_profile != null else Color(0.86, 0.18, 0.32, 1.0)
	_materials.current_accent_color = accent

	scale = Vector2(display_scale, display_scale)
	var resolved_cfg: AnimConfigScript = anim_config as AnimConfigScript
	if resolved_cfg == null and resolved_profile != null:
		resolved_cfg = resolved_profile.anim_config as AnimConfigScript
	if resolved_cfg == null and ResourceLoader.exists(ANIM_CONFIG_PATH):
		resolved_cfg = ResourceLoader.load(ANIM_CONFIG_PATH) as AnimConfigScript
	_animator = RigAnimator.new(resolved_cfg)
	_conic_lut = MeshBuilder.create_conic_rim_lut()
	var shader_res: Shader = ResourceLoader.load(SHADER_PATH) as Shader
	var pass2_shader_res: Shader = ResourceLoader.load(PASS2_SHADER_PATH) as Shader

	_vfx.build(self, _materials.current_accent_color)

	_unified_canvas_group = CanvasGroup.new()
	_unified_canvas_group.name = "UnifiedCharacterGroup"
	_unified_canvas_group.fit_margin = 64.0
	_unified_canvas_group.clear_margin = 64.0
	_unified_canvas_group.z_index = 0
	if pass2_shader_res != null:
		var pass2_mat := ShaderMaterial.new()
		pass2_mat.shader = pass2_shader_res
		_unified_canvas_group.material = pass2_mat
		_materials.set_pass2_material(pass2_mat)
	add_child(_unified_canvas_group)

	var out_str: float = resolved_profile.head_outline_strength if resolved_profile != null else -1.0
	var out_w: float = resolved_profile.head_outline_width_px if resolved_profile != null else -1.0

	_head_under_anchor = Node2D.new()
	_head_under_anchor.name = "DecoupledHeadUnderMount"
	_head_under_anchor.z_index = 0
	_unified_canvas_group.add_child(_head_under_anchor)
	_head_under_data = MeshBuilder.build_decoupled_heads(_head_under_anchor, shader_res, _conic_lut, pilot_root, 1, out_str, out_w)
	_materials.add_materials(_head_under_data.get("materials", []) as Array)

	_body_pivot = Node2D.new()
	_body_pivot.name = "BodyPivot"
	_body_pivot.z_index = 0
	_unified_canvas_group.add_child(_body_pivot)

	for v_key: String in ["s", "n"]:
		var vd: Dictionary = MeshBuilder.build_body_view_rig(_body_pivot, v_key, shader_res, _conic_lut, pilot_root)
		if vd.is_empty():
			continue
		var v_root: Node2D = vd["root"] as Node2D
		v_root.visible = (v_key == _router.active_view_key)
		_materials.add_materials(vd["materials"] as Array)
		_views[v_key] = vd

	# Último hijo de BodyPivot con z_index=0 para cubrir el cuello sin escapar del CanvasGroup.
	_head_shadow_sprite = _create_head_contact_shadow()
	_body_pivot.add_child(_head_shadow_sprite)

	_head_anchor = Node2D.new()
	_head_anchor.name = "DecoupledHeadMount"
	_head_anchor.z_index = 0
	_unified_canvas_group.add_child(_head_anchor)
	_head_data = MeshBuilder.build_decoupled_heads(_head_anchor, shader_res, _conic_lut, pilot_root, 2, out_str, out_w)
	_materials.add_materials(_head_data.get("materials", []) as Array)

	_commit_instant_transitions()


func set_transition_style(style_idx: int) -> void:
	_transitions.set_style(style_idx)
	transition_style = _transitions.transition_style
	snap_transitions_instant()


func get_transition_style() -> int:
	return _transitions.transition_style


func set_static_inspection(enabled: bool, body_key: String = "s", head_key: String = "head_front") -> void:
	_static_inspect_enabled = enabled
	if not enabled:
		return
	var safe_body: String = body_key if _views.has(body_key) else "s"
	var head_sprites: Dictionary = _head_data.get("sprites", {}) as Dictionary
	var safe_head: String = _router.sanitize_head_for_body(safe_body, false, head_key, 0.0)
	if not head_sprites.has(safe_head):
		safe_head = "head_back" if safe_body == "n" else "head_front"
	_router.reset_to(safe_body, false, safe_head, false)
	_smooth_move_dir = Vector2.DOWN
	_smooth_speed = 0.0
	_prev_input_move_dir = Vector2.DOWN
	_prev_input_speed = 0.0
	_loco_event_cooldown = 0.0
	_pose_hold_timer = 0.0
	_head_follow_through_timer = 0.0
	_head_spring_pos = Vector2.ZERO
	_head_spring_vel = Vector2.ZERO
	_has_prev_neck_pos = false
	_prev_neck_vel = Vector2.ZERO
	_has_prev_neck_vel = false
	_head_rot = 0.0
	_head_rot_vel = 0.0
	_turn_bone_kick = 0.0
	_flight_phase = 0.0
	_hit_stop_timer = 0.0
	_impact_frame_phase = 0
	if _unified_canvas_group != null:
		_unified_canvas_group.position = Vector2.ZERO
	if _materials != null:
		_materials.set_pass2_impact_phase(0)
	if _body_pivot != null:
		_body_pivot.rotation = 0.0
		_body_pivot.position = Vector2.ZERO
		_body_pivot.scale = Vector2.ONE
	if _animator != null:
		_animator.reset()
	_commit_instant_transitions()
	_reset_active_bones_to_rest()
	_sync_head_transform(0.0)


func is_static_inspection() -> bool:
	return _static_inspect_enabled


func _reset_active_bones_to_rest() -> void:
	for v_key: String in _views.keys():
		var vd: Dictionary = _views[v_key] as Dictionary
		var bones: Dictionary = vd["bones"] as Dictionary
		var rest_rots: Dictionary = vd["rest_rots"] as Dictionary
		for b_name: String in bones.keys():
			var bone: Bone2D = bones[b_name] as Bone2D
			bone.rotation = float(rest_rots.get(b_name, 0.0))


func set_head_align_mode(mode_idx: int) -> void:
	head_align_mode = clampi(mode_idx, 0, HeadAlignMode.SLIM_PROFILES)
	_router.resolve_orientation(_smooth_move_dir, _smooth_speed, _smooth_aim_dir, _head_data.get("sprites", {}) as Dictionary)
	_sync_head_transform(0.0)


func get_head_align_mode() -> int:
	return head_align_mode


func set_locomotion_state(move_dir: Vector2, speed_norm: float, aim_dir: Vector2, snap_instant: bool = false) -> void:
	if move_dir.length_squared() > 0.002:
		_move_dir = move_dir.normalized()
	_speed_norm = clampf(speed_norm, 0.0, 1.5)
	if aim_dir.length_squared() > 0.002:
		_aim_dir = aim_dir.normalized()
	var head_sprites: Dictionary = _head_data.get("sprites", {}) as Dictionary
	if snap_instant:
		_smooth_move_dir = _move_dir
		_smooth_aim_dir = _aim_dir
		_smooth_speed = _speed_norm
		_prev_input_move_dir = _move_dir
		_prev_input_speed = _speed_norm
		_router.resolve_orientation(_smooth_move_dir, _smooth_speed, _smooth_aim_dir, head_sprites, true)
		_commit_instant_transitions()
	else:
		_router.resolve_orientation(_smooth_move_dir, _smooth_speed, _smooth_aim_dir, head_sprites, false)


func snap_transitions_instant() -> void:
	_smooth_move_dir = _move_dir
	_smooth_aim_dir = _aim_dir
	_smooth_speed = _speed_norm
	_prev_input_move_dir = _move_dir
	_prev_input_speed = _speed_norm
	_router.resolve_orientation(_smooth_move_dir, _smooth_speed, _smooth_aim_dir, _head_data.get("sprites", {}) as Dictionary)
	_commit_instant_transitions()


func _commit_instant_transitions() -> void:
	_router.active_view_key = _router.target_view_key
	_router.body_flip_x = _router.target_body_flip_x
	_router.active_head_key = _router.target_head_key
	_router.head_flip_x = _router.target_head_flip_x
	_head_follow_through_timer = 0.0
	_pose_hold_timer = 0.0
	_head_spring_pos = Vector2.ZERO
	_head_spring_vel = Vector2.ZERO
	_has_prev_neck_pos = false
	_prev_neck_vel = Vector2.ZERO
	_has_prev_neck_vel = false
	_head_rot = 0.0
	_head_rot_vel = 0.0
	_transitions.reset()
	_physics.reset(_smooth_aim_dir)
	if _animator != null:
		_animator.set_whiplash_offsets(0.0, 0.0, 0.0)
	_turn_bone_kick = 0.0
	_materials.update_pass2_transition_fx(0.0, Vector2.RIGHT, -1.0, 0.0, Vector2(0.22, 0.92))
	_apply_transition_visual_state()


func _process(delta: float) -> void:
	_update_pass2_impact_center_uv()
	if _hit_stop_timer > 0.0:
		_hit_stop_timer = maxf(0.0, _hit_stop_timer - delta)
		if _hit_stop_timer <= 0.0:
			_impact_frame_phase = 0
			if _unified_canvas_group != null:
				_unified_canvas_group.position = Vector2.ZERO
		else:
			var elapsed: float = _hit_stop_duration - _hit_stop_timer
			_impact_frame_phase = 1 if elapsed < (_hit_stop_duration * 0.5) else 2
			if _unified_canvas_group != null:
				var shake_dir := Vector2(1.0, 0.0) if _impact_frame_phase == 1 else Vector2(0.0, -1.0)
				_unified_canvas_group.position = shake_dir * _hit_stop_shake_px * (_hit_stop_timer / maxf(_hit_stop_duration, 0.001))
		_materials.set_pass2_impact_phase(_impact_frame_phase)
		return

	if _static_inspect_enabled:
		if _body_pivot != null:
			_body_pivot.rotation = 0.0
			_body_pivot.position = Vector2.ZERO
			_body_pivot.scale = Vector2.ONE
		_reset_active_bones_to_rest()
		_sync_head_transform(0.0)
		_materials.update_motion_uniforms(delta, _move_dir, _speed_norm)
		_materials.update_pass2_transition_fx(0.0, Vector2.RIGHT, -1.0, 0.0, Vector2(0.22, 0.92))
		return

	var cfg: AnimConfigScript = _animator.config if (_animator != null and _animator.config != null) else AnimConfigScript.new()

	# --- Reloj Fluido (60+ FPS): Interpolación exponencial independiente de FPS (sin triple-lerp) ---
	var dir_blend: float = 1.0 - exp(-cfg.dir_smooth_rate * delta)
	var aim_blend: float = 1.0 - exp(-cfg.aim_smooth_rate * delta)
	var spd_blend: float = 1.0 - exp(-cfg.speed_smooth_rate * delta)
	if _smooth_move_dir.dot(_move_dir) < -0.98:
		_smooth_move_dir = _smooth_move_dir.rotated(0.18)
	_smooth_move_dir = _smooth_move_dir.lerp(_move_dir, dir_blend).normalized()
	if _smooth_aim_dir.dot(_aim_dir) < -0.98:
		_smooth_aim_dir = _smooth_aim_dir.rotated(0.18)
	_smooth_aim_dir = _smooth_aim_dir.lerp(_aim_dir, aim_blend).normalized()
	_smooth_speed = lerpf(_smooth_speed, _speed_norm, spd_blend)

	# Detección automática de Launch y Air-Brake / Drift sobre input directo
	_loco_event_cooldown = maxf(0.0, _loco_event_cooldown - delta)
	if _animator != null and _loco_event_cooldown <= 0.0:
		if _prev_input_speed < 0.20 and _speed_norm >= 0.45:
			_animator.trigger_launch(_move_dir)
			_physics.trigger_impulse(-_move_dir * 45.0, -_move_dir * 55.0)
			_loco_event_cooldown = 0.12
		elif _prev_input_speed >= 0.45 and ((_prev_input_move_dir.dot(_move_dir) < -0.35 and _speed_norm >= 0.35) or (_speed_norm < _prev_input_speed - 0.50)):
			_animator.trigger_air_brake(_prev_input_move_dir)
			_physics.trigger_impulse(_prev_input_move_dir * 65.0, _prev_input_move_dir * 82.0)
			_loco_event_cooldown = 0.14
	_prev_input_move_dir = _move_dir
	_prev_input_speed = _speed_norm

	_router.resolve_orientation(_smooth_move_dir, _smooth_speed, _smooth_aim_dir, _head_data.get("sprites", {}) as Dictionary)
	var trans_ev: Dictionary = _transitions.update(delta, _router, true)
	var head_just_deferred: bool = false
	if bool(trans_ev["started_snap"]):
		_physics.trigger_snap_impulse(_transitions.snap_turn_dir)
	if bool(trans_ev.get("head_micro_snap", false)):
		_head_rot_vel += float(trans_ev.get("head_turn_dir", 0.0)) * 1.45
	if bool(trans_ev["body_swapped"]):
		_head_follow_through_timer = cfg.head_snap_lag_sec
		_pose_hold_timer = maxf(_pose_hold_timer, cfg.snap_pose_hold_sec)
		head_just_deferred = true
	if bool(trans_ev["spawn_afterimage"]):
		_vfx.spawn_snap_afterimage(
			get_parent(),
			global_position,
			z_index,
			_transitions.snap_turn_dir,
			_materials.current_accent_color,
			scale,
			_body_pivot,
			_views,
			_router.active_view_key,
			_router.body_flip_x,
			_head_anchor,
			_head_data,
			_router.active_head_key
		)
	var kick: float = float(trans_ev["turn_bone_kick"])
	if absf(kick) > 0.0001:
		_turn_bone_kick = kick

	if _head_follow_through_timer > 0.0:
		if not head_just_deferred:
			_head_follow_through_timer = maxf(0.0, _head_follow_through_timer - delta)
	elif not _transitions.snap_active:
		_router.active_head_key = _router.target_head_key
		_router.head_flip_x = _router.target_head_flip_x

	_flight_phase += delta * (2.2 + _smooth_speed * 1.6)
	_apply_transition_visual_state()
	_materials.update_motion_uniforms(delta, _move_dir, _speed_norm)
	var p2_fx: Dictionary = _transitions.get_pass2_fx_params()
	_materials.update_pass2_transition_fx(
		float(p2_fx["smear_strength"]),
		p2_fx["smear_dir"] as Vector2,
		float(p2_fx["holo_pos"]),
		float(p2_fx["holo_strength"]),
		p2_fx["holo_dir"] as Vector2
	)

	# --- Reloj Escalonado (solo para q_time del shader) ---
	var stepped_dt: float = 0.0
	if stepped_fps >= 59.0:
		stepped_dt = delta
		_step_accum = 0.0
	else:
		var step_interval: float = 1.0 / maxf(stepped_fps, 1.0)
		_step_accum += delta
		if _step_accum >= step_interval:
			var ticks: int = int(floor(_step_accum / step_interval))
			_step_accum -= float(ticks) * step_interval
			stepped_dt = float(ticks) * step_interval
	if stepped_dt > 0.0:
		_q_time += stepped_dt
		_materials.set_q_time(_q_time)

	# --- Dinámica de Esqueleto y Física Secundaria a 60+ FPS (con pose hold breve selectivo) ---
	_physics.update(
		delta,
		_static_inspect_enabled,
		_animator,
		_views,
		_head_data,
		_flight_phase,
		_move_dir,
		_speed_norm,
		_smooth_move_dir,
		_smooth_speed,
		_smooth_aim_dir,
		_router.body_flip_x,
		_router.head_flip_x,
		_head_under_data
	)
	if _pose_hold_timer > 0.0:
		_pose_hold_timer = maxf(0.0, _pose_hold_timer - delta)
	else:
		_animate_active_body(delta)
		_turn_bone_kick *= exp(-cfg.turn_kick_decay * delta)
	_sync_head_transform(delta)

	var holo_split: bool = (_transitions.transition_style == TransitionStyle.HOLO_SNAP_FAST and _transitions.snap_active and _transitions.snap_from_view != _transitions.snap_to_view)
	_vfx.animate(
		enable_procedural_wings,
		enable_boot_thrusters,
		_flight_phase,
		_smooth_move_dir,
		_smooth_speed,
		_physics.whiplash_wing_kick,
		_materials.current_accent_color,
		_views,
		_router.active_view_key,
		holo_split,
		_transitions.snap_t,
		_body_pivot
	)
	_vfx.process_sandevistan_trail(
		delta,
		enable_afterimage,
		_speed_norm,
		_move_dir,
		_body_pivot,
		get_parent(),
		global_position,
		z_index,
		_materials.current_accent_color,
		scale,
		_views,
		_router.active_view_key,
		_router.body_flip_x,
		_head_anchor,
		_head_data,
		_router.active_head_key
	)


func _apply_transition_visual_state() -> void:
	var f_scale: Vector2 = _animator.get_foreshorten_scale() if _animator != null else Vector2.ONE
	_transitions.apply_visual_state(_body_pivot, _views, f_scale, _router, _head_data, _head_under_data)
	_sync_head_transform(0.0)


func _animate_active_body(delta: float) -> void:
	if _body_pivot == null or not _views.has(_router.active_view_key) or _animator == null:
		return
	_animator.update_and_apply(
		delta,
		_body_pivot,
		_views,
		_flight_phase,
		_smooth_move_dir,
		_smooth_speed,
		_router.is_backpedaling,
		_router.body_flip_x,
		_turn_bone_kick,
		_router.shoulder_look_twist,
		_router.active_view_key,
		_smooth_aim_dir
	)
	var f_scale: Vector2 = _animator.get_foreshorten_scale()
	var s_xy: Vector2 = _transitions.snap_scale_xy if _transitions.snap_active else Vector2.ONE
	_body_pivot.scale = Vector2(s_xy.x * f_scale.x, s_xy.y * f_scale.y)


func _sync_head_transform(delta: float = 0.0) -> void:
	if _head_anchor == null or not _views.has(_router.active_view_key):
		return
	var cfg: AnimConfigScript = _animator.config if (_animator != null and _animator.config != null) else AnimConfigScript.new()
	var vd: Dictionary = _views[_router.active_view_key] as Dictionary
	var neck_bone: Bone2D = vd.get("neck_bone", null) as Bone2D
	var rest_rots: Dictionary = vd.get("rest_rots", {}) as Dictionary
	var neck_world_delta: float = 0.0
	if neck_bone != null:
		var neck_rest: float = float(rest_rots.get("Neck", 0.0))
		var flip_sign: float = -1.0 if _router.body_flip_x else 1.0
		neck_world_delta = (neck_bone.rotation - neck_rest) * flip_sign

		if delta > 0.0 and not _static_inspect_enabled:
			var neck_pos: Vector2 = neck_bone.global_position
			if _has_prev_neck_pos:
				var neck_vel: Vector2 = (neck_pos - _prev_neck_global_pos) / maxf(delta, 0.001)
				if _has_prev_neck_vel:
					var neck_dv: Vector2 = neck_vel - _prev_neck_vel
					_head_spring_vel -= neck_dv * 0.45
				_prev_neck_vel = neck_vel
				_has_prev_neck_vel = true
			_prev_neck_global_pos = neck_pos
			_has_prev_neck_pos = true

			var steps: int = maxi(1, int(ceil(delta / 0.012)))
			var h: float = delta / float(steps)
			for _i: int in range(steps):
				var acc: Vector2 = -_head_spring_pos * cfg.head_spring_stiffness - _head_spring_vel * cfg.head_spring_damping
				_head_spring_vel += acc * h
				_head_spring_pos = (_head_spring_pos + _head_spring_vel * h).limit_length(cfg.head_max_lag_px)
		elif _static_inspect_enabled:
			_head_spring_pos = Vector2.ZERO
			_head_spring_vel = Vector2.ZERO
			_has_prev_neck_pos = false
			_prev_neck_vel = Vector2.ZERO
			_has_prev_neck_vel = false

		_head_anchor.global_position = neck_bone.global_position + _head_spring_pos

	var body_rot: float = _body_pivot.rotation if _body_pivot != null else 0.0
	var target_head_rot: float = body_rot * (1.0 + cfg.head_counter_balance_mul) + neck_world_delta * cfg.head_neck_rot_mul
	if delta > 0.0 and not _static_inspect_enabled:
		var rot_freq: float = sqrt(maxf(cfg.head_rot_stiffness, 1.0))
		var rot_zeta: float = clampf(cfg.head_rot_damping / maxf(2.0 * rot_freq, 0.01), 0.15, 1.5)
		var rot_res: Vector2 = RigAnimator.step_spring(_head_rot, _head_rot_vel, target_head_rot, rot_freq, rot_zeta, delta)
		_head_rot = rot_res.x
		_head_rot_vel = rot_res.y
	else:
		_head_rot = target_head_rot
		_head_rot_vel = 0.0
	_head_anchor.rotation = _head_rot

	if _head_under_anchor != null:
		_head_under_anchor.global_position = _head_anchor.global_position
		_head_under_anchor.rotation = _head_anchor.rotation

	var over_face_keep: float = 1.0 if _router.active_view_key == "s" else 0.0
	var h_scale: Vector2 = _transitions.snap_scale_xy if _transitions.snap_active else (_transitions.head_micro_snap_scale if _transitions.head_micro_snap_active else Vector2.ONE)
	_head_anchor.scale = h_scale
	if _head_under_anchor != null:
		_head_under_anchor.scale = h_scale

	if _head_shadow_sprite != null and _body_pivot != null and neck_bone != null:
		var l_dir: Vector2 = _materials.current_light_dir_2d if _materials != null else Vector2(-0.58, -0.81).normalized()
		var shadow_world: Vector2 = neck_bone.global_position + Vector2(0.0, 10.0) + Vector2(-l_dir.x * 3.5, -l_dir.y * 6.5) + _head_spring_pos * 0.45
		_head_shadow_sprite.position = _body_pivot.to_local(shadow_world)
		_head_shadow_sprite.rotation = -_body_pivot.rotation

	var skip_flip_overwrite: bool = _transitions.is_head_holo_split_active()
	for h_dict: Dictionary in [_head_data, _head_under_data]:
		if h_dict.is_empty():
			continue
		var h_mats: Array = h_dict.get("materials", []) as Array
		for mat: ShaderMaterial in h_mats:
			if not skip_flip_overwrite:
				mat.set_shader_parameter("normal_flip_x", -1.0 if _router.head_flip_x else 1.0)
			mat.set_shader_parameter("head_over_face_keep", over_face_keep)


# --- API Pública de Materiales, Presets, Combate e Inspección ---

func apply_skin_preset(skin: PilotSkinPreset) -> void:
	_materials.apply_skin_preset(skin)


func apply_hair_preset(hair: PilotHairPreset, skin_hair_col: Color) -> void:
	_materials.apply_hair_preset(hair, skin_hair_col)


func apply_style_profile(profile: RigStyleProfile) -> void:
	_materials.apply_style_profile(profile)


func set_hair_style_mode(mode_idx: int) -> void:
	_materials.set_hair_style_mode(mode_idx)


func set_recolor_method(method_idx: int) -> void:
	_materials.set_recolor_method(method_idx)


func set_shader_param_all(param_name: String, value: Variant) -> void:
	_materials.set_shader_param_all(param_name, value)


func set_debug_view_mode(mode_idx: int) -> void:
	_materials.set_debug_view_mode(mode_idx)


func set_normal_depth_options(enabled: bool, light_dir: Vector2, rim_str: float, hdr_boost: float) -> void:
	_materials.set_normal_depth_options(enabled, light_dir, rim_str, hdr_boost)


func set_hit_flash(amount: float) -> void:
	_materials.set_hit_flash(amount)


func trigger_hit_flash(intensity: float = 1.0) -> void:
	_materials.set_hit_flash(intensity)


func get_hit_flash() -> float:
	return _materials.get_hit_flash()


func get_active_anim_state_name() -> String:
	return _animator.get_active_state_name() if _animator != null else "IDLE_HOVER"


func get_active_view_key() -> String:
	return _router.active_view_key


func get_active_head_key() -> String:
	return _router.active_head_key


func is_body_flipped() -> bool:
	return _router.body_flip_x


func is_snap_active() -> bool:
	return _transitions.snap_active


func get_snap_scale_xy() -> Vector2:
	return _transitions.snap_scale_xy


func is_whiplash_active() -> bool:
	return _physics.whiplash_active


func get_secondary_jiggle_pos_l() -> Vector2:
	return _physics.jiggle_pos_l


func get_hair_jiggle_pos() -> Vector2:
	return _physics.hair_jiggle_pos


func get_views() -> Dictionary:
	return _views


func get_head_data() -> Dictionary:
	return _head_data


func get_head_under_data() -> Dictionary:
	return _head_under_data


func get_body_pivot() -> Node2D:
	return _body_pivot


func get_head_anchor() -> Node2D:
	return _head_anchor


func get_unified_canvas_group() -> CanvasGroup:
	return _unified_canvas_group


func get_pass2_material() -> ShaderMaterial:
	return _materials.pass2_material if _materials != null else null


func set_stepped_fps(fps: float) -> void:
	stepped_fps = clampf(fps, 1.0, 120.0)
	_step_accum = 0.0


func get_stepped_fps() -> float:
	return stepped_fps


func get_q_time() -> float:
	return _q_time


func is_head_follow_through_pending() -> bool:
	return _head_follow_through_timer > 0.0


func trigger_dash_burst(dir: Vector2 = Vector2.ZERO) -> void:
	var use_dir: Vector2 = dir.normalized() if dir.length_squared() > 0.002 else _move_dir
	var cfg: AnimConfigScript = _animator.config if (_animator != null and _animator.config != null) else AnimConfigScript.new()
	if _animator != null:
		_animator.trigger_dash_burst(use_dir)
	_pose_hold_timer = maxf(_pose_hold_timer, cfg.dash_pose_hold_sec)
	if _physics != null:
		_physics.trigger_impulse(-use_dir * 85.0, -use_dir * 105.0)
	_head_spring_vel -= use_dir * 110.0


func trigger_attack_recoil(aim_dir: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	var use_aim: Vector2 = aim_dir.normalized() if aim_dir.length_squared() > 0.002 else _aim_dir
	if _animator != null:
		_animator.trigger_attack_recoil(use_aim, strength)
	if _physics != null:
		_physics.trigger_impulse(-use_aim * 55.0 * strength, -use_aim * 65.0 * strength)
	_head_spring_vel -= use_aim * 75.0 * strength


func trigger_hit_react(hit_dir: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	var use_dir: Vector2 = hit_dir.normalized() if hit_dir.length_squared() > 0.002 else -_aim_dir
	if _animator != null:
		_animator.trigger_hit_react(use_dir, strength)
	trigger_hit_flash(clampf(0.85 * strength, 0.25, 1.0))
	if _physics != null:
		_physics.trigger_impulse(use_dir * 90.0 * strength, use_dir * 110.0 * strength)
	_head_spring_vel += use_dir * 120.0 * strength


func is_launch_active() -> bool:
	return _animator != null and _animator.is_launch_active()


func is_air_brake_active() -> bool:
	return _animator != null and _animator.is_air_brake_active()


func is_dash_burst_active() -> bool:
	return _animator != null and _animator.is_dash_burst_active()


func is_attack_recoil_active() -> bool:
	return _animator != null and _animator.is_attack_recoil_active()


func is_hit_react_active() -> bool:
	return _animator != null and _animator.is_hit_react_active()


func get_active_additive_summary() -> String:
	return _animator.get_active_additive_summary() if _animator != null else "NONE"


func get_head_spring_offset() -> Vector2:
	return _head_spring_pos


func get_anim_config() -> PlanarRigAnimConfig:
	return _animator.config if _animator != null else null


func set_outer_outline_params(enabled: bool, width_px: float, strength: float) -> void:
	if _materials != null:
		_materials.set_outer_outline_params(enabled, width_px, strength)


func trigger_impact_frame(duration_ms: float = 55.0, shake_px: float = 6.0) -> void:
	_hit_stop_duration = clampf(duration_ms / 1000.0, 0.040, 0.065)
	_hit_stop_timer = _hit_stop_duration
	_hit_stop_shake_px = clampf(shake_px, 0.0, 24.0)
	_impact_frame_phase = 1
	_update_pass2_impact_center_uv()
	if _materials != null:
		_materials.set_pass2_impact_phase(1)


func _update_pass2_impact_center_uv() -> void:
	if _materials == null:
		return
	var center_uv := Vector2(0.5, 0.5)
	if is_inside_tree() and get_viewport() != null:
		var vp_rect: Rect2 = get_viewport_rect()
		if vp_rect.size.x > 1.0 and vp_rect.size.y > 1.0:
			var screen_pos: Vector2 = get_viewport().get_canvas_transform() * global_position
			center_uv = (screen_pos / vp_rect.size).clamp(Vector2.ZERO, Vector2.ONE)
	_materials.set_pass2_impact_center_uv(center_uv)


func is_hit_stop_active() -> bool:
	return _hit_stop_timer > 0.0


func get_impact_frame_phase() -> int:
	return _impact_frame_phase


func _create_head_contact_shadow() -> Sprite2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.031, 0.031, 0.071, 0.42),
		Color(0.031, 0.031, 0.071, 0.18),
		Color(0.031, 0.031, 0.071, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var spr := Sprite2D.new()
	spr.name = "HeadContactShadow"
	spr.texture = tex
	spr.scale = Vector2(0.35, 0.30)
	spr.z_index = 0
	return spr


func set_zoom_scale(zoom_scale: float) -> void:
	if _materials != null:
		_materials.set_pass2_zoom_scale(zoom_scale)


func get_head_contact_shadow() -> Sprite2D:
	return _head_shadow_sprite


func get_active_ghost_count() -> int:
	return _vfx.get_active_ghost_count() if _vfx != null else 0


func is_head_micro_snap_active() -> bool:
	return _transitions != null and _transitions.head_micro_snap_active


func get_active_view_summary() -> String:
	var mirror_b: String = "FLIP" if _router.body_flip_x else "NORM"
	var mirror_h: String = "FLIP" if _router.head_flip_x else "NORM"
	return "T%d | Body=%s(%s) | Head=%s(%s)" % [_transitions.transition_style, _router.active_view_key.to_upper(), mirror_b, _router.active_head_key, mirror_h]
