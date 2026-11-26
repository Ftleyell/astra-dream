class_name HubGroundedMotor3D
extends RefCounted
## Motor 3D compartido para locomoción Grounded AAA en el Hub (HubWorld + HubArtLab).
## Provee:
## - Física responsiva WASD con frenado reforzado y pivote limpio en cambios >= 110°.
## - Stride-Lock real midiendo el desplazamiento horizontal efectivo post move_and_slide().
## - Contact Juice de pisada (SFX metálico vía AudioManager + pulso sutil de anillo en suelo 3D).
## - Contracción/atenuación dinámica de sombras durante la fase de paso.

const HubRigAvatar3DScript = preload("res://scenes/ui/hub/components/hub_rig_avatar_3d.gd")
const GroundedConfigScript = preload("res://data/pilots/schemas/pilot_grounded_locomotion_config.gd")
const ASTRAL_RIPPLE_SHADER: Shader = preload("res://scenes/ui/hub/shaders/hub_astral_ripple_3d.gdshader")

signal pivot_triggered(turn_sign: float)

var _prev_input_dir_2d: Vector2 = Vector2.DOWN
var _pivot_cooldown: float = 0.0
var _step_fx_ring_mesh: TorusMesh = null
var _ripple_plane_mesh: PlaneMesh = null
var _spark_quad_mesh: QuadMesh = null


func step_velocity(
	body: CharacterBody3D,
	input_dir: Vector3,
	delta: float,
	avatar: HubRigAvatar3DScript
) -> Dictionary:
	var cfg: GroundedConfigScript = avatar.get_grounded_config() if avatar != null else null
	var max_spd: float = cfg.hub_move_speed if cfg != null else 6.2
	var accel: float = cfg.hub_accel if cfg != null else 18.0
	var friction: float = cfg.hub_friction if cfg != null else 16.0
	var pivot_mul: float = cfg.hub_pivot_brake_mul if cfg != null else 2.35
	var pivot_deg: float = cfg.hub_pivot_angle_deg if cfg != null else 110.0

	_pivot_cooldown = maxf(0.0, _pivot_cooldown - delta)
	var did_pivot: bool = false
	var pivot_sign: float = 1.0

	var horiz_vel := Vector2(body.velocity.x, body.velocity.z)
	if input_dir.length_squared() > 0.01:
		var in_2d := Vector2(input_dir.x, input_dir.z).normalized()
		var eff_accel: float = accel
		if horiz_vel.length() > max_spd * 0.35:
			var vel_2d: Vector2 = horiz_vel.normalized()
			var dot_v: float = clampf(vel_2d.dot(in_2d), -1.0, 1.0)
			var angle_deg: float = rad_to_deg(acos(dot_v))
			if angle_deg >= pivot_deg:
				eff_accel = accel * pivot_mul
				if _pivot_cooldown <= 0.0:
					did_pivot = true
					var cross_v: float = vel_2d.x * in_2d.y - vel_2d.y * in_2d.x
					pivot_sign = 1.0 if cross_v >= 0.0 else -1.0
					_pivot_cooldown = 0.22
					if avatar != null:
						avatar.trigger_grounded_pivot(pivot_sign)
					pivot_triggered.emit(pivot_sign)
		_prev_input_dir_2d = in_2d
		var target_vel: Vector3 = input_dir * max_spd
		body.velocity.x = move_toward(body.velocity.x, target_vel.x, eff_accel * delta)
		body.velocity.z = move_toward(body.velocity.z, target_vel.z, eff_accel * delta)
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, friction * delta)
		body.velocity.z = move_toward(body.velocity.z, 0.0, friction * delta)

	var speed_norm: float = clampf(Vector2(body.velocity.x, body.velocity.z).length() / maxf(max_spd, 0.01), 0.0, 1.0)
	return {
		"speed_norm": speed_norm,
		"facing_dir_2d": _prev_input_dir_2d,
		"did_pivot": did_pivot,
		"pivot_sign": pivot_sign,
	}


func commit_stride_displacement(
	prev_pos: Vector3,
	new_pos: Vector3,
	avatar: HubRigAvatar3DScript
) -> float:
	var disp_xz: float = Vector2(new_pos.x - prev_pos.x, new_pos.z - prev_pos.z).length()
	if avatar != null:
		avatar.feed_world_displacement(disp_xz)
	return disp_xz


func update_shadows(
	shadow_sprite: Sprite3D,
	shadow_mat: ShaderMaterial,
	shadow_proj_scale: Vector3,
	contact_shadow_mesh: MeshInstance3D,
	contact_shadow_mat: ShaderMaterial,
	hover_factor: float,
	delta: float,
	base_alpha: float,
	hop_alpha: float,
	visibility_alpha: float = 1.0,
	scale_amp: float = 0.08
) -> void:
	var t_lerp: float = clampf(16.0 * delta, 0.0, 1.0)
	var h: float = clampf(hover_factor, 0.0, 1.0)
	if shadow_sprite != null:
		var scale_mult: float = 1.0 - (h * scale_amp)
		var target_scale := Vector3(shadow_proj_scale.x * scale_mult, 1.0, shadow_proj_scale.z * scale_mult)
		shadow_sprite.scale = shadow_sprite.scale.lerp(target_scale, t_lerp)
		if shadow_mat != null:
			var target_a: float = lerpf(base_alpha, hop_alpha, h) * visibility_alpha
			var cur_col: Color = shadow_mat.get_shader_parameter("shadow_color") as Color
			var next_a: float = lerpf(cur_col.a, target_a, t_lerp)
			shadow_mat.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.0, next_a))

	if contact_shadow_mesh != null:
		var c_scale: float = 1.0 - (h * scale_amp * 0.75)
		contact_shadow_mesh.scale = contact_shadow_mesh.scale.lerp(Vector3(c_scale, 1.0, c_scale), t_lerp)
	if contact_shadow_mat != null:
		contact_shadow_mat.set_shader_parameter("opacity", visibility_alpha * lerpf(1.0, 0.80, h))


func on_footstep(
	body: CharacterBody3D,
	foot: StringName,
	strength: float,
	avatar: HubRigAvatar3DScript
) -> void:
	var cfg: GroundedConfigScript = avatar.get_grounded_config() if avatar != null else null
	var vol_db: float = cfg.footstep_sfx_volume_db if cfg != null else -11.0
	var s: float = clampf(strength, 0.35, 1.2)
	var pitch_base: float = 0.98 if foot == &"left" else 1.03
	var audio_mgr: Node = body.get_node_or_null("/root/AudioManager") if body != null else null
	if audio_mgr != null and audio_mgr.has_method("play_sfx"):
		audio_mgr.call("play_sfx", "hub_footstep", pitch_base, vol_db + lerpf(-3.0, 0.5, s))

	var vfx_on: bool = cfg.footstep_vfx_enabled if cfg != null else true
	if vfx_on and body != null and body.is_inside_tree() and body.get_parent() != null:
		if cfg != null and cfg.gait_style == GroundedConfigScript.GaitStyle.ASTRAL_GLIDE_HOP:
			if cfg.ripple_enabled:
				spawn_astral_ripple(body, s, avatar, cfg)
		else:
			_spawn_footstep_ring(body, foot, s)


func spawn_astral_ripple(
	body: CharacterBody3D,
	strength: float,
	avatar: HubRigAvatar3DScript,
	cfg: GroundedConfigScript = null
) -> void:
	if body == null or not body.is_inside_tree():
		return
	var parent_3d: Node = body.get_parent()
	if parent_3d == null:
		return

	var eff_cfg: GroundedConfigScript = cfg if cfg != null else (avatar.get_grounded_config() if avatar != null else null)
	var outer_r: float = eff_cfg.ripple_outer_radius_m if eff_cfg != null else 0.78
	var inner_r: float = eff_cfg.ripple_inner_radius_m if eff_cfg != null else 0.42
	var dur: float = maxf(eff_cfg.ripple_duration_sec if eff_cfg != null else 0.48, 0.12)
	var inten: float = (eff_cfg.ripple_intensity if eff_cfg != null else 1.15) * clampf(strength, 0.5, 1.25)
	var use_accent: bool = eff_cfg.ripple_use_skin_accent if eff_cfg != null else true
	var fallback_col: Color = eff_cfg.ripple_fallback_color if eff_cfg != null else Color(0.55, 0.88, 1.0, 1.0)
	var base_col: Color = fallback_col
	if use_accent and avatar != null:
		base_col = avatar.get_active_accent_color().lerp(Color(0.62, 0.90, 1.0, 1.0), 0.35)
	base_col.a = clampf(0.85 * clampf(strength, 0.45, 1.15), 0.25, 1.0)

	if _ripple_plane_mesh == null:
		_ripple_plane_mesh = PlaneMesh.new()
		_ripple_plane_mesh.size = Vector2(2.0, 2.0)

	var ripple_mesh := MeshInstance3D.new()
	ripple_mesh.name = "AstralBounceRipple"
	ripple_mesh.mesh = _ripple_plane_mesh
	ripple_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ripple_mesh.position = body.global_position + Vector3(0.0, 0.036, 0.02)
	ripple_mesh.scale = Vector3(outer_r, 1.0, outer_r)

	var mat := ShaderMaterial.new()
	mat.shader = ASTRAL_RIPPLE_SHADER
	mat.render_priority = 3
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("ripple_color", base_col)
	mat.set_shader_parameter("core_color", Color(0.96, 0.98, 1.0, 1.0))
	mat.set_shader_parameter("intensity", inten)
	mat.set_shader_parameter("inner_ratio", clampf(inner_r / maxf(outer_r, 0.05), 0.25, 0.85))
	ripple_mesh.material_override = mat
	parent_3d.add_child(ripple_mesh)

	var tw: Tween = ripple_mesh.create_tween()
	tw.tween_method(func(v: float) -> void:
		if is_instance_valid(mat):
			mat.set_shader_parameter("progress", v)
	, 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ripple_mesh.queue_free)

	var spark_count: int = clampi(eff_cfg.ripple_spark_count if eff_cfg != null else 5, 0, 8)
	if spark_count > 0:
		_spawn_bounce_sparks(parent_3d, body.global_position + Vector3(0.0, 0.05, 0.02), base_col, spark_count, outer_r * 0.48, dur * 0.72)


func _spawn_bounce_sparks(
	parent_3d: Node,
	origin: Vector3,
	base_col: Color,
	count: int,
	ring_r: float,
	dur: float
) -> void:
	if _spark_quad_mesh == null:
		_spark_quad_mesh = QuadMesh.new()
		_spark_quad_mesh.size = Vector2(0.085, 0.085)

	for i: int in range(count):
		var ang: float = (float(i) / float(count)) * TAU + randf_range(-0.22, 0.22)
		var start_pos: Vector3 = origin + Vector3(cos(ang) * 0.14, 0.01, sin(ang) * 0.14)
		var end_pos: Vector3 = origin + Vector3(cos(ang) * ring_r, randf_range(0.18, 0.34), sin(ang) * ring_r)

		var spark := MeshInstance3D.new()
		spark.name = "AstralBounceSpark"
		spark.mesh = _spark_quad_mesh
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.position = start_pos
		spark.scale = Vector3.ONE * randf_range(0.75, 1.15)

		var s_mat := StandardMaterial3D.new()
		s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		s_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		s_mat.no_depth_test = false
		s_mat.albedo_color = Color(base_col.r, base_col.g, base_col.b, 0.85).lerp(Color.WHITE, 0.45)
		spark.material_override = s_mat
		parent_3d.add_child(spark)

		var tw_s: Tween = spark.create_tween()
		tw_s.set_parallel(true)
		tw_s.tween_property(spark, "position", end_pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_s.tween_property(spark, "scale", Vector3(0.15, 0.15, 0.15), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_s.tween_property(s_mat, "albedo_color:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_s.chain().tween_callback(spark.queue_free)


func _spawn_footstep_ring(body: CharacterBody3D, foot: StringName, strength: float) -> void:
	var parent_3d: Node = body.get_parent()
	if parent_3d == null:
		return
	if _step_fx_ring_mesh == null:
		_step_fx_ring_mesh = TorusMesh.new()
		_step_fx_ring_mesh.inner_radius = 0.14
		_step_fx_ring_mesh.outer_radius = 0.175
		_step_fx_ring_mesh.rings = 14
		_step_fx_ring_mesh.ring_segments = 6

	var ring := MeshInstance3D.new()
	ring.name = "FootstepPulse"
	ring.mesh = _step_fx_ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = false
	mat.albedo_color = Color(0.76, 0.92, 1.0, 0.24 * clampf(strength, 0.4, 1.0))
	ring.material_override = mat

	var x_off: float = -0.11 if foot == &"left" else 0.11
	ring.position = body.global_position + Vector3(x_off, 0.032, 0.03)
	ring.scale = Vector3(0.45, 0.18, 0.45)
	parent_3d.add_child(ring)

	var tw: Tween = ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(1.18, 0.14, 1.18), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)
