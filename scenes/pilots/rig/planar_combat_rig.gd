class_name PlanarCombatRig
extends Node2D
## Orquestador modular del Rig de Combate Planar 8-Direcciones + Cabeza Desacoplada.
## Delega en componentes especializados:
## - PlanarRigViewRouter: resolución de vistas S/N, Flip-H y cabezas 8-dir.
## - PlanarRigTransitionController: transiciones snappy (modos 4..6).
## - PlanarRigSecondaryPhysics: whiplash de extremidades y resortes 2D (busto/cabello).
## - PlanarRigWingsVFX: alas procedurales, propulsores y estela Sandevistan.
## - PlanarRigMaterialController: perfiles de estilo, skins, pelo, iluminación 2.5D y hit_flash.

const SHADER_PATH: String = "res://scenes/pilots/shaders/pilot_rig_stylizer.gdshader"
const PASS2_SHADER_PATH: String = "res://scenes/pilots/shaders/pilot_rig_pass2.gdshader"
const DEFAULT_PILOT_PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const ANIM_CONFIG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_anim_config.tres"

const MeshBuilder = preload("res://scenes/pilots/rig/planar_rig_mesh_builder.gd")
const RigAnimator = preload("res://scenes/pilots/rig/planar_rig_animator.gd")
const AnimConfigScript = preload("res://scenes/pilots/rig/planar_rig_anim_config.gd")
const ViewRouterScript = preload("res://scenes/pilots/rig/planar_rig_view_router.gd")
const TransitionCtrlScript = preload("res://scenes/pilots/rig/planar_rig_transition_controller.gd")
const SecondaryPhysScript = preload("res://scenes/pilots/rig/planar_rig_secondary_physics.gd")
const WingsVFXScript = preload("res://scenes/pilots/rig/planar_rig_wings_vfx.gd")
const MaterialCtrlScript = preload("res://scenes/pilots/rig/planar_rig_material_controller.gd")
const PerspectiveCtrlScript = preload("res://scenes/pilots/rig/planar_rig_perspective_controller.gd")
const ImpactCtrlScript = preload("res://scenes/pilots/rig/planar_rig_impact_controller.gd")
const FaceCtrlScript = preload("res://scenes/pilots/rig/planar_rig_face_controller.gd")
const FaceConfigScript = preload("res://data/pilots/schemas/pilot_face_anim_config.gd")
const GroundedConfigScript = preload("res://data/pilots/schemas/pilot_grounded_locomotion_config.gd")
const AnimRuntimeScript = preload("res://scenes/pilots/rig/planar_rig_animation_runtime.gd")
const BasePropCtrlScript = preload("res://scenes/pilots/vfx/valentina_base_propulsion_controller.gd")
const BasePropConfigScript = preload("res://data/pilots/schemas/pilot_base_propulsion_config.gd")
const Wings3DCtrlScript = preload("res://scenes/pilots/vfx/astral_wings_3d_controller.gd")
const Wings3DConfigScript = preload("res://data/pilots/schemas/pilot_wings_3d_config.gd")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")
const CosmicRigLightingConfigScript = preload("res://scenes/combat/environment/cosmos/resources/cosmic_rig_lighting_config.gd")

enum TransitionStyle {
	WHIP_SNAP_AFTERIMAGE = 4,
	MICRO_FLASH_SNAP = 5,
	HOLO_SNAP_FAST = 6,
}

enum LocomotionMode {
	ZERO_G_FLIGHT = 0,
	GROUNDED_HUB = 1,
}

@export var pilot_profile: Resource = null
@export var display_scale: float = 0.378
@export var enable_procedural_wings: bool = false
@export var enable_boot_thrusters: bool = false
@export var enable_afterimage: bool = false
@export var transition_style: int = TransitionStyle.WHIP_SNAP_AFTERIMAGE
@export var anim_config: Resource = null
@export var stepped_fps: float = 15.0
@export var enable_live_animations: bool = true
@export var enable_face_live: bool = false
@export var enable_base_propulsion_wings: bool = false
@export var enable_3d_wings: bool = false

var _animator: RigAnimator = null
var _anim_runtime: AnimRuntimeScript = null
var _anim_runtime_initialized: bool = false
var _locomotion_mode: int = LocomotionMode.ZERO_G_FLIGHT
var _is_turbo: bool = false
var _q_time: float = 0.0
var _router: PlanarRigViewRouter = null
var _transitions: PlanarRigTransitionController = null
var _physics: PlanarRigSecondaryPhysics = null
var _vfx: PlanarRigWingsVFX = null
var _materials: PlanarRigMaterialController = null
var _perspective: PerspectiveCtrlScript = null
var _impact: ImpactCtrlScript = null
var _face_ctrl: FaceCtrlScript = null
var _external_face_step: bool = false
var _base_prop_ctrl: BasePropCtrlScript = null
var _wings_3d_ctrl: Wings3DCtrlScript = null
var _last_skin_preset: PilotSkinPreset = null
var _wings_skin_override: PilotSkinPreset = null
var _pilot_star_level: int = 1
var _wings_star_level: int = 1
var _has_prev_wing_pos: bool = false
var _prev_wing_world_pos: Vector2 = Vector2.ZERO

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
var _static_inspect_enabled: bool = false
var calibration_manual_pose: bool = false
var _manual_head_offset: Vector2 = Vector2.ZERO
var _manual_head_rot: float = 0.0
var _synced_profile: PilotRigProfile = null
var _smoothed_cosmic_lighting: CosmicLightingSampleScript = null
var _has_cosmic_lighting_init: bool = false


func _ready() -> void:
	build_rig()


func load_pilot_profile(profile: PilotRigProfile) -> void:
	pilot_profile = profile
	if profile != null:
		display_scale = profile.display_scale
		anim_config = profile.anim_config
		stepped_fps = profile.stepped_fps
	_synced_profile = profile
	build_rig()


func build_rig() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_views.clear()
	_base_prop_ctrl = null
	_wings_3d_ctrl = null
	_has_prev_wing_pos = false

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
	if _impact == null:
		_impact = ImpactCtrlScript.new()
	if _face_ctrl == null:
		_face_ctrl = FaceCtrlScript.new()
	else:
		_face_ctrl.reset()
	_materials.clear()
	_impact.reset(null, null)

	_transitions.set_style(transition_style)

	var resolved_profile: PilotRigProfile = pilot_profile as PilotRigProfile
	if resolved_profile == null and ResourceLoader.exists(DEFAULT_PILOT_PROFILE_PATH):
		resolved_profile = ResourceLoader.load(DEFAULT_PILOT_PROFILE_PATH) as PilotRigProfile
		pilot_profile = resolved_profile
	if resolved_profile != null and resolved_profile != _synced_profile:
		display_scale = resolved_profile.display_scale
		if resolved_profile.anim_config != null:
			anim_config = resolved_profile.anim_config
		stepped_fps = resolved_profile.stepped_fps
		_synced_profile = resolved_profile

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
	_perspective = PerspectiveCtrlScript.new(resolved_cfg.perspective_config if resolved_cfg != null else null)
	_conic_lut = MeshBuilder.create_conic_rim_lut()
	var shader_res: Shader = ResourceLoader.load(SHADER_PATH) as Shader
	var pass2_shader_res: Shader = ResourceLoader.load(PASS2_SHADER_PATH) as Shader

	_vfx.build(self, _materials.current_accent_color)

	_unified_canvas_group = CanvasGroup.new()
	_unified_canvas_group.name = "UnifiedCharacterGroup"
	_unified_canvas_group.use_mipmaps = true
	_unified_canvas_group.fit_margin = 64.0
	_unified_canvas_group.clear_margin = 64.0
	_unified_canvas_group.z_index = 0
	if pass2_shader_res != null:
		var pass2_mat := ShaderMaterial.new()
		pass2_mat.shader = pass2_shader_res
		_unified_canvas_group.material = pass2_mat
		_materials.set_pass2_material(pass2_mat)
	add_child(_unified_canvas_group)

	_head_under_anchor = Node2D.new()
	_head_under_anchor.name = "DecoupledHeadUnderMount"
	_head_under_anchor.z_index = 0
	_unified_canvas_group.add_child(_head_under_anchor)
	_head_under_data = MeshBuilder.build_decoupled_heads(_head_under_anchor, shader_res, _conic_lut, pilot_root, 1)
	_materials.add_materials(_head_under_data.get("materials", []) as Array)

	_body_pivot = Node2D.new()
	_body_pivot.name = "BodyPivot"
	_body_pivot.z_index = 0
	_unified_canvas_group.add_child(_body_pivot)

	var discovered_views: Array[String] = []
	for v_key: String in ViewRouterScript.DIRECTION_ORDER_8:
		var meta_path: String = "%s/%s/parts_5/parts_5_meta.json" % [pilot_root, v_key]
		if not FileAccess.file_exists(meta_path):
			continue
		var vd: Dictionary = MeshBuilder.build_body_view_rig(_body_pivot, v_key, shader_res, _conic_lut, pilot_root)
		if vd.is_empty():
			continue
		var v_root: Node2D = vd["root"] as Node2D
		v_root.visible = (v_key == _router.active_view_key)
		_materials.add_materials(vd["materials"] as Array)
		_views[v_key] = vd
		discovered_views.append(v_key)

	_router.set_available_views(discovered_views)
	if not _views.has(_router.active_view_key) or (_router.has_8dir_body and _router.body_flip_x):
		var fb_body: String = "s" if _views.has("s") else (discovered_views[0] if not discovered_views.is_empty() else "s")
		_router.reset_to(fb_body, false, ViewRouterScript.get_default_head_for_body(fb_body), false)

	# Último hijo de BodyPivot con z_index=0 para cubrir el cuello sin escapar del CanvasGroup.
	_head_shadow_sprite = _create_head_contact_shadow()
	_body_pivot.add_child(_head_shadow_sprite)

	_head_anchor = Node2D.new()
	_head_anchor.name = "DecoupledHeadMount"
	_head_anchor.z_index = 0
	_unified_canvas_group.add_child(_head_anchor)
	_head_data = MeshBuilder.build_decoupled_heads(_head_anchor, shader_res, _conic_lut, pilot_root, 2)
	_materials.add_materials(_head_data.get("materials", []) as Array)

	_commit_instant_transitions()
	_sync_rig_space_matrices()
	_anim_runtime_initialized = false
	if _face_ctrl != null and not enable_face_live:
		_face_ctrl.clear_on_head_materials(_head_data, _head_under_data)
	if enable_3d_wings:
		_ensure_3d_wings_ready()
	elif enable_base_propulsion_wings:
		_ensure_base_propulsion_wings_ready()


func set_transition_style(style_idx: int) -> void:
	_transitions.set_style(style_idx)
	transition_style = _transitions.transition_style
	snap_transitions_instant()


func get_transition_style() -> int:
	return _transitions.transition_style


func set_static_inspection(enabled: bool, body_key: String = "s", head_key: String = "head_front", bypass_head_clamp: bool = false) -> void:
	_static_inspect_enabled = enabled
	if not enabled:
		return
	var safe_body: String = body_key if _views.has(body_key) else "s"
	var head_sprites: Dictionary = _head_data.get("sprites", {}) as Dictionary
	var safe_head: String = head_key if bypass_head_clamp else _router.sanitize_head_for_body(safe_body, false, head_key, 0.0)
	if not head_sprites.has(safe_head):
		safe_head = ViewRouterScript.get_default_head_for_body(safe_body)
	_router.reset_to(safe_body, false, safe_head, false)
	_smooth_move_dir = Vector2.DOWN
	_smooth_speed = 0.0
	if _impact != null:
		_impact.reset(_unified_canvas_group, _materials)
	if _body_pivot != null:
		_body_pivot.rotation = 0.0
		_body_pivot.position = Vector2.ZERO
		_body_pivot.scale = Vector2.ONE
	if _animator != null:
		_animator.reset()
	_commit_instant_transitions()
	_sync_rig_space_matrices()
	_anim_runtime_initialized = false
	if _face_ctrl != null and not enable_face_live:
		_face_ctrl.clear_on_head_materials(_head_data, _head_under_data)
	_reset_active_bones_to_rest()
	_sync_head_transform(0.0, true)


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
		_router.resolve_orientation(_smooth_move_dir, _smooth_speed, _smooth_aim_dir, head_sprites, true)
		_commit_instant_transitions()
		_sync_rig_space_matrices()
	else:
		_router.resolve_orientation(_smooth_move_dir, _smooth_speed, _smooth_aim_dir, head_sprites, false)


func snap_transitions_instant() -> void:
	_smooth_move_dir = _move_dir
	_smooth_aim_dir = _aim_dir
	_smooth_speed = _speed_norm
	_router.resolve_orientation(_smooth_move_dir, _smooth_speed, _smooth_aim_dir, _head_data.get("sprites", {}) as Dictionary)
	_commit_instant_transitions()
	_sync_rig_space_matrices()
	if _face_ctrl != null and not enable_face_live:
		_face_ctrl.clear_on_head_materials(_head_data, _head_under_data)


func _commit_instant_transitions() -> void:
	_router.active_view_key = _router.target_view_key
	_router.body_flip_x = _router.target_body_flip_x
	_router.active_head_key = _router.target_head_key
	_router.head_flip_x = _router.target_head_flip_x
	_transitions.reset()
	_physics.reset(_smooth_aim_dir)
	if _animator != null and not calibration_manual_pose:
		_animator.set_whiplash_offsets(0.0, 0.0, 0.0)
		_animator.apply_latched_pose(_views, _router.active_view_key)
		if _body_pivot != null:
			_body_pivot.rotation = _animator.get_latest_bank_rot()
	_materials.update_pass2_transition_fx(0.0, Vector2.RIGHT, -1.0, 0.0, Vector2(0.22, 0.92))
	_apply_transition_visual_state(true)


func _process(delta: float) -> void:
	if _impact != null and _impact.step(delta, self, _unified_canvas_group, _materials):
		return

	if _static_inspect_enabled:
		if _body_pivot != null:
			_body_pivot.rotation = 0.0
			_body_pivot.position = Vector2.ZERO
			_body_pivot.scale = Vector2.ONE
		if not calibration_manual_pose:
			_reset_active_bones_to_rest()
			if _perspective != null and _views.has(_router.active_view_key):
				_perspective.apply_to_view(_views[_router.active_view_key] as Dictionary, _router.active_view_key, true)
		_sync_head_transform(0.0)
		_vfx.animate(
			enable_procedural_wings,
			enable_boot_thrusters,
			0.0,
			Vector2.DOWN,
			0.0,
			0.0,
			_materials.current_accent_color,
			_views,
			_router.active_view_key,
			false,
			0.0,
			_body_pivot
		)
		_materials.update_motion_uniforms(delta, Vector2.ZERO, 0.0)
		_materials.update_pass2_transition_fx(0.0, Vector2.RIGHT, -1.0, 0.0, Vector2(0.22, 0.92))
		return

	var cfg: AnimConfigScript = _animator.config if (_animator != null and _animator.config != null) else AnimConfigScript.new()

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

	_router.resolve_orientation(_smooth_move_dir, _smooth_speed, _smooth_aim_dir, _head_data.get("sprites", {}) as Dictionary)
	var trans_ev: Dictionary = _transitions.update(delta, _router, false)
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
	var use_live_anim: bool = enable_live_animations and not calibration_manual_pose
	if use_live_anim:
		ensure_live_animations_ready()
		_q_time += delta
		_materials.set_q_time(_q_time)
	else:
		_materials.set_q_time(0.0)
	_apply_transition_visual_state(true)
	_materials.update_motion_uniforms(delta, Vector2.ZERO, 0.0)
	var p2_fx: Dictionary = _transitions.get_pass2_fx_params()
	_materials.update_pass2_transition_fx(
		float(p2_fx["smear_strength"]),
		p2_fx["smear_dir"] as Vector2,
		float(p2_fx["holo_pos"]),
		float(p2_fx["holo_strength"]),
		p2_fx["holo_dir"] as Vector2
	)

	if use_live_anim and _anim_runtime != null:
		if _body_pivot != null:
			_body_pivot.scale = _transitions.snap_scale_xy if _transitions.snap_active else Vector2.ONE
		_anim_runtime.step(delta, self, _smooth_speed, _smooth_move_dir, _smooth_aim_dir, _router.is_backpedaling, _is_turbo)
		_sync_head_transform(delta, true)
	else:
		if not calibration_manual_pose:
			_physics.update(
				delta,
				true,
				_animator,
				_views,
				_head_data,
				0.0,
				_move_dir,
				_speed_norm,
				_smooth_move_dir,
				_smooth_speed,
				_smooth_aim_dir,
				_router.body_flip_x,
				_router.head_flip_x,
				_head_under_data,
				true,
				true
			)
		if not calibration_manual_pose:
			_animate_active_body(delta, true)
			if _perspective != null and _views.has(_router.active_view_key):
				_perspective.apply_to_view(_views[_router.active_view_key] as Dictionary, _router.active_view_key, false)
		elif _body_pivot != null:
			_body_pivot.position = Vector2.ZERO
			_body_pivot.rotation = 0.0
			_body_pivot.scale = _transitions.snap_scale_xy if _transitions.snap_active else Vector2.ONE
		_sync_head_transform(delta, true)
		if enable_face_live and not _external_face_step and _face_ctrl != null:
			step_face_live(delta)

	_vfx.animate(
		false,
		false,
		0.0,
		Vector2.DOWN,
		0.0,
		0.0,
		_materials.current_accent_color,
		_views,
		_router.active_view_key,
		false,
		1.0,
		_body_pivot
	)

	if enable_3d_wings:
		_ensure_3d_wings_ready()
		if _wings_3d_ctrl != null:
			var cur_p3: Vector2 = global_position
			var delta_p3: Vector2 = (cur_p3 - _prev_wing_world_pos) if _has_prev_wing_pos else Vector2.ZERO
			var wing_vel3: Vector2 = delta_p3 / maxf(delta, 0.001)
			_prev_wing_world_pos = cur_p3
			_has_prev_wing_pos = true
			if wing_vel3.length_squared() < 4.0 and _smooth_speed > 0.05:
				wing_vel3 = _smooth_move_dir * _smooth_speed * 320.0
			_wings_3d_ctrl.step_attached_rig(delta, _router.active_view_key, _smooth_speed, wing_vel3, _is_turbo, delta_p3, false)
	elif enable_base_propulsion_wings:
		_ensure_base_propulsion_wings_ready()
		if _base_prop_ctrl != null:
			var cur_p: Vector2 = global_position
			var wing_vel: Vector2 = Vector2.ZERO
			if _has_prev_wing_pos:
				wing_vel = (cur_p - _prev_wing_world_pos) / maxf(delta, 0.001)
			_prev_wing_world_pos = cur_p
			_has_prev_wing_pos = true
			if wing_vel.length_squared() < 4.0 and _smooth_speed > 0.05:
				wing_vel = _smooth_move_dir * _smooth_speed * 320.0
			_base_prop_ctrl.step(delta, self, wing_vel, _is_turbo)


func _apply_transition_visual_state(flush_head_latch: bool = true) -> void:
	_transitions.apply_visual_state(_body_pivot, _views, Vector2.ONE, _router, _head_data, _head_under_data)
	_sync_head_transform(0.0, flush_head_latch)


func _animate_active_body(delta: float, flush_pose_latch: bool = true) -> void:
	if _body_pivot == null or not _views.has(_router.active_view_key) or _animator == null:
		return
	var torso_fwd: Vector2 = _router.get_torso_forward(_router.active_view_key, _router.body_flip_x)
	_animator.update_and_apply(
		delta,
		_body_pivot,
		_views,
		0.0,
		_smooth_move_dir,
		_smooth_speed,
		_router.is_backpedaling,
		_router.body_flip_x,
		0.0,
		_router.shoulder_look_twist,
		_router.active_view_key,
		_smooth_aim_dir,
		torso_fwd,
		flush_pose_latch
	)
	_body_pivot.position = Vector2.ZERO
	_body_pivot.rotation = 0.0
	var s_xy: Vector2 = _transitions.snap_scale_xy if _transitions.snap_active else Vector2.ONE
	_body_pivot.scale = s_xy


func sync_head_to_active_neck(extra_offset: Vector2 = Vector2.ZERO, extra_rot: float = 0.0) -> void:
	_manual_head_offset = extra_offset
	_manual_head_rot = extra_rot
	_sync_head_transform(0.0, false)


func _sync_head_transform(_delta: float = 0.0, _flush_head_latch: bool = true) -> void:
	if _head_anchor == null or not _views.has(_router.active_view_key):
		return
	var vd: Dictionary = _views[_router.active_view_key] as Dictionary
	var neck_bone: Bone2D = vd.get("neck_bone", null) as Bone2D
	var use_head_offset: bool = calibration_manual_pose or (enable_live_animations and _anim_runtime != null)
	var head_off: Vector2 = _manual_head_offset if use_head_offset else Vector2.ZERO
	var head_rot: float = _manual_head_rot if use_head_offset else 0.0

	if neck_bone != null:
		_head_anchor.global_position = neck_bone.global_position
	_head_anchor.position += head_off
	_head_anchor.rotation = head_rot
	var h_scale: Vector2 = _transitions.snap_scale_xy if _transitions.snap_active else (_transitions.head_micro_snap_scale if _transitions.head_micro_snap_active else Vector2.ONE)
	_head_anchor.scale = h_scale

	if _head_under_anchor != null:
		_head_under_anchor.global_position = _head_anchor.global_position
		_head_under_anchor.rotation = head_rot
		_head_under_anchor.scale = h_scale

	_apply_head_combo_transform(_router.active_view_key, _router.active_head_key)

	if _head_shadow_sprite != null and _body_pivot != null and neck_bone != null:
		var is_back_body: bool = _router.active_view_key in ["n", "ne", "nw"]
		_head_shadow_sprite.visible = not is_back_body
		if not is_back_body:
			var l_dir: Vector2 = _materials.current_light_dir_2d if _materials != null else Vector2(-0.58, -0.81).normalized()
			var neck_local: Vector2 = _body_pivot.to_local(neck_bone.global_position)
			_head_shadow_sprite.position = neck_local + Vector2(-l_dir.x * 1.4, 0.8 - l_dir.y * 1.0) + head_off * 0.5
			_head_shadow_sprite.rotation = 0.0

	var skip_flip_overwrite: bool = _transitions.is_head_holo_split_active()
	for h_dict: Dictionary in [_head_data, _head_under_data]:
		if h_dict.is_empty():
			continue
		var h_mats: Array = h_dict.get("materials", []) as Array
		for mat: ShaderMaterial in h_mats:
			if not skip_flip_overwrite:
				mat.set_shader_parameter("normal_flip_x", 1.0)
			mat.set_shader_parameter("head_over_face_keep", 1.0)
	_sync_rig_space_matrices()


func _apply_head_combo_transform(view_key: String, head_key: String) -> void:
	for h_dict: Dictionary in [_head_data, _head_under_data]:
		if h_dict.is_empty():
			continue
		var sprites: Dictionary = h_dict.get("sprites", {}) as Dictionary
		var spr: Sprite2D = sprites.get(head_key, null) as Sprite2D
		if spr == null:
			continue
		var base_scales: Dictionary = h_dict.get("base_scales", {}) as Dictionary
		var base_offsets: Dictionary = h_dict.get("base_offsets", {}) as Dictionary
		var base_scale: Vector2 = base_scales.get(head_key, spr.scale) as Vector2
		var base_off: Vector2 = base_offsets.get(head_key, spr.position) as Vector2
		var meta: Dictionary = h_dict.get("meta", {}) as Dictionary
		var combos: Dictionary = meta.get("combo_transforms", {}) as Dictionary
		var view_combos: Dictionary = combos.get(view_key, {}) as Dictionary
		var cur_off: Vector2 = base_off
		var cur_s: float = 1.0
		if view_combos.has(head_key):
			var tf: Dictionary = view_combos[head_key] as Dictionary
			var off_arr: Array = tf.get("sprite_offset", [base_off.x, base_off.y]) as Array
			cur_s = float(tf.get("scale", 1.0))
			if off_arr.size() >= 2:
				cur_off = Vector2(float(off_arr[0]), float(off_arr[1]))
			spr.position = cur_off
			spr.scale = base_scale * cur_s
		else:
			spr.position = base_off
			spr.scale = base_scale
		if spr.material is ShaderMaterial:
			var h_entry: Dictionary = meta.get(head_key, {}) as Dictionary
			var d_arr: Array = h_entry.get("disp_size", [110.0, 120.0]) as Array
			if d_arr.size() >= 2:
				var scaled_sz := Vector2(float(d_arr[0]), float(d_arr[1])) * cur_s
				var neck_rel: Vector2 = (_views[view_key] as Dictionary).get("neck_rel", Vector2.ZERO) as Vector2 if _views.has(view_key) else Vector2.ZERO
				var h_orig: Vector2 = neck_rel + cur_off - scaled_sz * 0.5
				(spr.material as ShaderMaterial).set_shader_parameter(
					"part_rig_rect",
					Vector4(h_orig.x / 490.0, h_orig.y / 490.0, scaled_sz.x / 490.0, scaled_sz.y / 490.0)
				)


func _sync_rig_space_matrices() -> void:
	if _body_pivot == null or _materials == null:
		return
	var inv_pivot: Transform2D = _body_pivot.get_global_transform().affine_inverse()
	_materials.set_shader_param_all("inv_body_pivot_matrix", inv_pivot)


# --- API Pública de Materiales, Presets, Combate e Inspección ---

func apply_skin_preset(skin: PilotSkinPreset, star_level: int = 1) -> void:
	_last_skin_preset = skin
	_pilot_star_level = clampi(star_level, 1, 3)
	_materials.apply_skin_preset(skin, _pilot_star_level)
	if _wings_skin_override == null:
		if _base_prop_ctrl != null:
			_base_prop_ctrl.sync_materials_from_rig(self)
		if _wings_3d_ctrl != null:
			_wings_3d_ctrl.apply_skin_preset(skin, _pilot_star_level)


func apply_wings_skin_preset(skin: PilotSkinPreset, star_level: int = 1) -> void:
	_wings_skin_override = skin
	_wings_star_level = clampi(star_level, 1, 3)
	if _base_prop_ctrl != null:
		_base_prop_ctrl.apply_skin_preset(_wings_skin_override, _wings_star_level)
	if _wings_3d_ctrl != null:
		var eff_3d: PilotSkinPreset = _wings_skin_override if _wings_skin_override != null else _last_skin_preset
		var eff_stars: int = _wings_star_level if _wings_skin_override != null else _pilot_star_level
		_wings_3d_ctrl.apply_skin_preset(eff_3d, eff_stars)


func get_active_skin_id() -> String:
	if _last_skin_preset == null or _last_skin_preset.is_base_skin or _last_skin_preset.id.is_empty():
		return "base"
	return _last_skin_preset.id


func get_active_wings_skin_id() -> String:
	if _wings_skin_override == null:
		return "follow_pilot"
	if _wings_skin_override.is_base_skin or _wings_skin_override.id.is_empty():
		return "base"
	return _wings_skin_override.id


func apply_hair_preset(hair: PilotHairPreset, skin_hair_col: Color) -> void:
	_materials.apply_hair_preset(hair, skin_hair_col)


func apply_style_profile(profile: RigStyleProfile) -> void:
	_materials.apply_style_profile(profile)
	if _base_prop_ctrl != null:
		_base_prop_ctrl.sync_materials_from_rig(self)
		if _has_cosmic_lighting_init and _smoothed_cosmic_lighting != null and _base_prop_ctrl.has_method("apply_cosmic_lighting"):
			_base_prop_ctrl.apply_cosmic_lighting(_smoothed_cosmic_lighting)


func apply_cosmic_lighting(
	sample: CosmicLightingSampleScript,
	delta: float = 0.0,
	config: CosmicRigLightingConfigScript = null
) -> void:
	if sample == null:
		_has_cosmic_lighting_init = false
		if _materials != null:
			_materials.reset_cosmic_lighting()
		if _base_prop_ctrl != null and _base_prop_ctrl.has_method("apply_cosmic_lighting"):
			_base_prop_ctrl.apply_cosmic_lighting(null)
		if _wings_3d_ctrl != null:
			_wings_3d_ctrl.apply_cosmic_lighting(null)
		return

	if _smoothed_cosmic_lighting == null:
		_smoothed_cosmic_lighting = CosmicLightingSampleScript.new()

	if delta <= 0.0 or not _has_cosmic_lighting_init:
		_smoothed_cosmic_lighting.copy_from(sample)
		_has_cosmic_lighting_init = true
	else:
		var dir_rate: float = config.dir_smooth_rate if config != null else 8.0
		var col_rate: float = config.color_smooth_rate if config != null else 5.0
		var dir_t: float = 1.0 - exp(-dir_rate * delta)
		var col_t: float = 1.0 - exp(-col_rate * delta)
		_smoothed_cosmic_lighting.smooth_toward(sample, dir_t, col_t)

	if _materials != null:
		_materials.apply_cosmic_lighting(_smoothed_cosmic_lighting)
	if _base_prop_ctrl != null and _base_prop_ctrl.has_method("apply_cosmic_lighting"):
		_base_prop_ctrl.apply_cosmic_lighting(_smoothed_cosmic_lighting)
	if _wings_3d_ctrl != null:
		_wings_3d_ctrl.apply_cosmic_lighting(_smoothed_cosmic_lighting)


func get_last_cosmic_lighting() -> CosmicLightingSampleScript:
	return _smoothed_cosmic_lighting


func set_hair_style_mode(mode_idx: int) -> void:
	_materials.set_hair_style_mode(mode_idx)


func set_recolor_method(method_idx: int) -> void:
	_materials.set_recolor_method(method_idx)


func set_shader_param_all(param_name: String, value: Variant) -> void:
	_materials.set_shader_param_all(param_name, value)


func set_pass2_param(param_name: String, value: Variant) -> void:
	_materials.set_pass2_param(param_name, value)


func get_current_style_profile() -> RigStyleProfile:
	return _materials.get_current_style_profile()


func get_shader_param(param_name: String, fallback: Variant = null) -> Variant:
	return _materials.get_shader_param(param_name, fallback)


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


func is_backpedaling() -> bool:
	return _router != null and _router.is_backpedaling


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


func get_available_view_keys() -> Array[String]:
	var keys: Array[String] = []
	for dir_k: String in ViewRouterScript.DIRECTION_ORDER_8:
		if _views.has(dir_k):
			keys.append(dir_k)
	return keys


func has_8dir_body() -> bool:
	return _router != null and _router.has_8dir_body


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


func get_stepped_fps() -> float:
	return stepped_fps


func set_q_time(q_time: float) -> void:
	if _materials != null:
		_materials.set_q_time(q_time)


func get_q_time() -> float:
	return _q_time


func is_head_follow_through_pending() -> bool:
	return false


func get_manual_head_offset() -> Vector2:
	return _manual_head_offset if (calibration_manual_pose or (enable_live_animations and _anim_runtime != null)) else Vector2.ZERO


func get_manual_head_rot() -> float:
	return _manual_head_rot if (calibration_manual_pose or (enable_live_animations and _anim_runtime != null)) else 0.0


func ensure_live_animations_ready() -> void:
	if _anim_runtime_initialized:
		return
	if _anim_runtime == null:
		_anim_runtime = AnimRuntimeScript.new()
	_anim_runtime_initialized = true
	_anim_runtime.set_locomotion_mode(_locomotion_mode, null)
	_anim_runtime.setup(pilot_profile as PilotRigProfile, self, true)


func set_locomotion_mode(mode: int) -> void:
	_locomotion_mode = LocomotionMode.GROUNDED_HUB if mode == LocomotionMode.GROUNDED_HUB else LocomotionMode.ZERO_G_FLIGHT
	if _anim_runtime != null:
		_anim_runtime.set_locomotion_mode(_locomotion_mode, self)


func get_locomotion_mode() -> int:
	return _locomotion_mode


func feed_world_displacement(dist_m: float) -> void:
	if _anim_runtime != null:
		_anim_runtime.feed_world_displacement(dist_m)


func trigger_grounded_pivot(turn_sign: float = 1.0) -> void:
	if _anim_runtime != null:
		_anim_runtime.trigger_grounded_pivot(turn_sign)


func consume_grounded_step_event() -> Dictionary:
	return _anim_runtime.consume_grounded_step_event() if _anim_runtime != null else {}


func get_grounded_pelvis_lift_norm() -> float:
	return _anim_runtime.get_grounded_pelvis_lift_norm() if _anim_runtime != null else 0.0


func get_grounded_gait_phase() -> float:
	return _anim_runtime.get_grounded_gait_phase() if _anim_runtime != null else 0.0


func get_grounded_locomotion_config() -> GroundedConfigScript:
	if _anim_runtime != null and _anim_runtime.grounded_loco_cfg != null:
		return _anim_runtime.grounded_loco_cfg
	if pilot_profile is PilotRigProfile and (pilot_profile as PilotRigProfile).grounded_locomotion_config is GroundedConfigScript:
		return (pilot_profile as PilotRigProfile).grounded_locomotion_config as GroundedConfigScript
	return null


func set_live_animations_enabled(enabled: bool) -> void:
	enable_live_animations = enabled
	if enabled:
		ensure_live_animations_ready()
	else:
		_anim_runtime_initialized = false
		_manual_head_offset = Vector2.ZERO
		_manual_head_rot = 0.0
		_is_turbo = false
		if _anim_runtime != null:
			_anim_runtime.reset_to_rest(self)
		if _body_pivot != null:
			_body_pivot.position = Vector2.ZERO
			_body_pivot.rotation = 0.0
			_body_pivot.scale = Vector2.ONE
		_reset_active_bones_to_rest()
		_sync_head_transform(0.0, true)


func is_live_animations_enabled() -> bool:
	return enable_live_animations and not calibration_manual_pose


func set_turbo_active(active: bool) -> void:
	_is_turbo = active


func set_anim_layer_mode(mode: int) -> void:
	ensure_live_animations_ready()
	if _anim_runtime != null:
		_anim_runtime.set_pose_layer_mode(mode, self)


func set_idle_anim_enabled(enabled: bool) -> void:
	ensure_live_animations_ready()
	if _anim_runtime != null:
		_anim_runtime.set_idle_enabled(enabled, self)


func set_loco_anim_enabled(enabled: bool) -> void:
	ensure_live_animations_ready()
	if _anim_runtime != null:
		_anim_runtime.set_loco_enabled(enabled, self)


func set_kiting_anim_enabled(enabled: bool) -> void:
	ensure_live_animations_ready()
	if _anim_runtime != null:
		_anim_runtime.set_kiting_enabled(enabled, self)


func set_turn_anim_enabled(enabled: bool) -> void:
	ensure_live_animations_ready()
	if _anim_runtime != null:
		_anim_runtime.set_turn_enabled(enabled, self)


func set_jiggle_anim_enabled(enabled: bool) -> void:
	ensure_live_animations_ready()
	if _anim_runtime != null:
		_anim_runtime.set_jiggle_enabled(enabled, self)


func set_face_anim_enabled_live(enabled: bool) -> void:
	ensure_live_animations_ready()
	if _anim_runtime != null:
		_anim_runtime.set_face_enabled(enabled, self)


func reload_animation_configs_from_disk() -> void:
	if _anim_runtime == null:
		_anim_runtime = AnimRuntimeScript.new()
	_anim_runtime_initialized = true
	_anim_runtime.reload_from_disk(pilot_profile as PilotRigProfile, self)


func get_animation_runtime() -> AnimRuntimeScript:
	return _anim_runtime


func get_live_loco_weights() -> Dictionary:
	return _anim_runtime.live_loco_weights.duplicate() if _anim_runtime != null else {}


func get_live_kiting_weights() -> Dictionary:
	return _anim_runtime.live_kiting_weights.duplicate() if _anim_runtime != null else {}


func get_loco_state_tag() -> String:
	return _anim_runtime.format_loco_state_tag() if (_anim_runtime != null and enable_live_animations) else "LOCO OFF"


func set_face_live_enabled(enabled: bool, cfg: FaceConfigScript = null) -> void:
	enable_face_live = enabled
	if _face_ctrl == null:
		_face_ctrl = FaceCtrlScript.new(cfg)
	elif cfg != null:
		_face_ctrl.set_config(cfg)
	if not enabled and _face_ctrl != null:
		_face_ctrl.reset()
		_face_ctrl.clear_on_head_materials(_head_data, _head_under_data)


func is_face_live_enabled() -> bool:
	return enable_face_live


func set_external_face_step(external: bool) -> void:
	_external_face_step = external


func set_face_anim_config(cfg: FaceConfigScript) -> void:
	if _face_ctrl == null:
		_face_ctrl = FaceCtrlScript.new(cfg)
	else:
		_face_ctrl.set_config(cfg)


func set_face_personality_profile(profile_id: int) -> void:
	if _face_ctrl != null:
		_face_ctrl.set_personality_profile(profile_id)


func set_face_overfocus_boost(amount: float) -> void:
	if _face_ctrl != null:
		_face_ctrl.set_overfocus_boost(amount)


func get_face_overfocus_boost() -> float:
	return _face_ctrl.get_overfocus_boost() if _face_ctrl != null else 0.0


func set_base_propulsion_wings_enabled(enabled: bool) -> void:
	enable_base_propulsion_wings = enabled
	if enabled:
		if _wings_3d_ctrl != null:
			set_3d_wings_enabled(false)
		_ensure_base_propulsion_wings_ready()
	elif _base_prop_ctrl != null:
		_base_prop_ctrl.detach_from_rig()
		_base_prop_ctrl.queue_free()
		_base_prop_ctrl = null


func get_base_propulsion_controller() -> BasePropCtrlScript:
	return _base_prop_ctrl


func set_3d_wings_enabled(enabled: bool) -> void:
	enable_3d_wings = enabled
	if enabled:
		if _base_prop_ctrl != null:
			set_base_propulsion_wings_enabled(false)
		_ensure_3d_wings_ready()
	elif _wings_3d_ctrl != null:
		_wings_3d_ctrl.queue_free()
		_wings_3d_ctrl = null


func get_3d_wings_controller() -> Wings3DCtrlScript:
	return _wings_3d_ctrl


func set_3d_wings_anim_state(state: int, snap_now: bool = false) -> void:
	if _wings_3d_ctrl != null:
		_wings_3d_ctrl.set_anim_state(state, snap_now)


func trigger_3d_wings_pulse() -> void:
	if _wings_3d_ctrl != null:
		_wings_3d_ctrl.trigger_pulse(-1)


func clear_3d_wings_manual_override() -> void:
	if _wings_3d_ctrl != null:
		_wings_3d_ctrl.clear_manual_anim_override()


func _ensure_3d_wings_ready() -> void:
	if not enable_3d_wings or _wings_3d_ctrl != null:
		return
	_wings_3d_ctrl = Wings3DCtrlScript.new()
	_wings_3d_ctrl.name = "AstralWings3D"
	var inv_s: float = 1.0 / maxf(display_scale, 0.05)
	_wings_3d_ctrl.scale = Vector2(inv_s, inv_s)
	_wings_3d_ctrl.set_z_layer_offsets(-2, -1, 1, 2)
	if pilot_profile != null and pilot_profile.wings_3d_config is Wings3DConfigScript:
		_wings_3d_ctrl.set_config(pilot_profile.wings_3d_config as Wings3DConfigScript)
	add_child(_wings_3d_ctrl)
	if _wings_skin_override != null:
		_wings_3d_ctrl.apply_skin_preset(_wings_skin_override, _wings_star_level)
	elif _last_skin_preset != null:
		_wings_3d_ctrl.apply_skin_preset(_last_skin_preset, _pilot_star_level)
	elif pilot_profile != null and not pilot_profile.skins.is_empty():
		_wings_3d_ctrl.apply_skin_preset(pilot_profile.skins[0])
	if _has_cosmic_lighting_init and _smoothed_cosmic_lighting != null:
		_wings_3d_ctrl.apply_cosmic_lighting(_smoothed_cosmic_lighting)
	_wings_3d_ctrl.step_attached_rig(0.0, _router.active_view_key, _smooth_speed, Vector2.ZERO, _is_turbo, Vector2.ZERO, true)


func _ensure_base_propulsion_wings_ready() -> void:
	if not enable_base_propulsion_wings or _base_prop_ctrl != null:
		return
	_base_prop_ctrl = BasePropCtrlScript.new()
	_base_prop_ctrl.name = "BasePropulsionWings"
	_base_prop_ctrl.z_index = -2
	add_child(_base_prop_ctrl)
	if pilot_profile != null and pilot_profile.base_propulsion_config is BasePropConfigScript:
		_base_prop_ctrl.set_config(pilot_profile.base_propulsion_config as BasePropConfigScript)
	_base_prop_ctrl.attach_to_rig(self)
	if _wings_skin_override != null:
		_base_prop_ctrl.apply_skin_preset(_wings_skin_override, _wings_star_level)
	if _has_cosmic_lighting_init and _smoothed_cosmic_lighting != null and _base_prop_ctrl.has_method("apply_cosmic_lighting"):
		_base_prop_ctrl.apply_cosmic_lighting(_smoothed_cosmic_lighting)


func get_face_controller() -> FaceCtrlScript:
	return _face_ctrl


func get_face_mood_tag() -> String:
	return _face_ctrl.get_mood_tag() if (enable_face_live and _face_ctrl != null) else "STATIC"


func trigger_comms_talk(duration_sec: float = -1.0) -> void:
	if enable_face_live and _face_ctrl != null:
		_face_ctrl.trigger_comms_talk(duration_sec)


func step_face_live(delta: float, ctx: Dictionary = {}) -> Dictionary:
	if not enable_face_live or _face_ctrl == null:
		return {}
	var full_ctx: Dictionary = {
		"head_key": str(ctx.get("head_key", _router.active_head_key)),
		"aim_dir": ctx.get("aim_dir", _smooth_aim_dir),
		"vel_norm": ctx.get("vel_norm", _smooth_move_dir * _smooth_speed),
		"speed_norm": float(ctx.get("speed_norm", _smooth_speed)),
		"is_turbo": bool(ctx.get("is_turbo", false)),
		"is_backpedaling": bool(ctx.get("is_backpedaling", is_backpedaling())),
		"loco_weights": ctx.get("loco_weights", {}),
		"turn_state": ctx.get("turn_state", get_turn_anim_state()),
		"head_rot_rad": float(ctx.get("head_rot_rad", get_manual_head_rot())),
		"head_offset_du": ctx.get("head_offset_du", get_manual_head_offset()),
		"sync_q_time": bool(ctx.get("sync_q_time", not _external_face_step)),
	}
	return _face_ctrl.step_and_apply(delta, full_ctx, _head_data, _head_under_data)


func trigger_dash_burst(dir: Vector2 = Vector2.ZERO) -> void:
	if enable_live_animations and not calibration_manual_pose:
		ensure_live_animations_ready()
		if _anim_runtime != null:
			_anim_runtime.trigger_dash_burst(dir if dir.length_squared() > 0.01 else _smooth_move_dir)
	if enable_face_live and _face_ctrl != null:
		_face_ctrl.trigger_dash_burst(dir)
	if _wings_3d_ctrl != null:
		_wings_3d_ctrl.trigger_pulse(-1)


func trigger_attack_recoil(aim_dir: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	if enable_live_animations and not calibration_manual_pose:
		ensure_live_animations_ready()
		if _anim_runtime != null:
			_anim_runtime.trigger_attack_recoil(aim_dir if aim_dir.length_squared() > 0.01 else _smooth_aim_dir, strength)
	if enable_face_live and _face_ctrl != null:
		_face_ctrl.trigger_attack_recoil(aim_dir, strength)


func trigger_hit_react(hit_dir: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	if enable_live_animations and not calibration_manual_pose:
		ensure_live_animations_ready()
		if _anim_runtime != null:
			_anim_runtime.trigger_hit_react(hit_dir, strength, self)
	if enable_face_live and _face_ctrl != null:
		_face_ctrl.trigger_hit_react(hit_dir, strength)


func trigger_air_brake(strength: float = 1.0) -> void:
	if enable_live_animations and not calibration_manual_pose:
		ensure_live_animations_ready()
		if _anim_runtime != null:
			_anim_runtime.trigger_air_brake(strength)
	if _wings_3d_ctrl != null:
		_wings_3d_ctrl.trigger_pulse(-1)


func is_launch_active() -> bool:
	return _animator != null and _animator.is_launch_active()


func is_air_brake_active() -> bool:
	if enable_live_animations and _anim_runtime != null and _anim_runtime.is_air_brake_active():
		return true
	return _animator != null and _animator.is_air_brake_active()


func is_dash_burst_active() -> bool:
	if enable_live_animations and _anim_runtime != null and _anim_runtime.is_dash_burst_active():
		return true
	return _animator != null and _animator.is_dash_burst_active()


func is_attack_recoil_active() -> bool:
	if enable_live_animations and _anim_runtime != null and _anim_runtime.is_attack_recoil_active():
		return true
	return _animator != null and _animator.is_attack_recoil_active()


func is_hit_react_active() -> bool:
	if enable_live_animations and _anim_runtime != null and _anim_runtime.is_hit_react_active():
		return true
	return _animator != null and _animator.is_hit_react_active()


func get_active_additive_summary() -> String:
	if enable_live_animations and _anim_runtime != null:
		var rt_sum: String = _anim_runtime.get_active_additive_summary()
		if rt_sum != "NONE":
			return rt_sum
	return _animator.get_active_additive_summary() if _animator != null else "NONE"


func get_head_spring_offset() -> Vector2:
	return Vector2.ZERO


func get_anim_config() -> PlanarRigAnimConfig:
	return _animator.config if _animator != null else null


func get_perspective_controller() -> PerspectiveCtrlScript:
	return _perspective


func set_outer_outline_params(enabled: bool, width_px: float, strength: float) -> void:
	if _materials != null:
		_materials.set_outer_outline_params(enabled, width_px, strength)


func trigger_impact_frame(duration_ms: float = 55.0, shake_px: float = 6.0) -> void:
	if _impact != null:
		_impact.trigger(duration_ms, shake_px, self, _materials)
	if enable_face_live and _face_ctrl != null:
		_face_ctrl.trigger_hit_react(Vector2.ZERO, 1.25)


func is_hit_stop_active() -> bool:
	return _impact != null and _impact.is_active()


func get_impact_frame_phase() -> int:
	return _impact.get_phase() if _impact != null else 0


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
	spr.scale = Vector2(0.28, 0.20)
	spr.modulate.a = 0.72
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


## Devuelve el estado instantáneo del giro snappy activo para cuerpo y cabeza.
func get_turn_anim_state() -> Dictionary:
	return _transitions.get_turn_anim_state() if _transitions != null else {}


## Configura duraciones y punto de corte personalizados para giros snappy.
func configure_turn_timings(body_dur: float, swap_pt: float, head_dur: float) -> void:
	if _transitions != null:
		_transitions.set_custom_timings(body_dur, swap_pt, head_dur)


func get_active_view_summary() -> String:
	var mirror_b: String = "FLIP" if _router.body_flip_x else "NORM"
	var mirror_h: String = "FLIP" if _router.head_flip_x else "NORM"
	return "T%d | Body=%s(%s) | Head=%s(%s)" % [_transitions.transition_style, _router.active_view_key.to_upper(), mirror_b, _router.active_head_key, mirror_h]
