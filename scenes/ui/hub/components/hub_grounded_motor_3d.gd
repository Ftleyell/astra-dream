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

signal pivot_triggered(turn_sign: float)

var _prev_input_dir_2d: Vector2 = Vector2.DOWN
var _pivot_cooldown: float = 0.0
var _step_fx_ring_mesh: TorusMesh = null


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
		_spawn_footstep_ring(body, foot, s)


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
