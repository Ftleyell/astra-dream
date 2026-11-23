class_name OrbitalWeaponRingController
extends Node2D
## Controlador desacoplado del Anillo Orbital 2.5D y Armamento (Guns Lab — Valentina v2).
## Proyecta una elipse 3D inclinada partida en arco trasero (z=2) y delantero (z=10),
## y anima de 1 a 4 armas con Z-sorting real, escala perspectiva, escorzo, trapezoide 2.5D,
## extrusión falsa, recoil físico, muzzle flash y trazadores.

const WeaponShader = preload("res://sandbox/pilot_rig_lab/guns_lab/orbital_weapon_25d.gdshader")
const RingTextureShader = preload("res://sandbox/pilot_rig_lab/guns_lab/orbital_ring_25d.gdshader")
const ConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_orbital_weapon_config.gd")
const SkinPresetScript = preload("res://sandbox/pilot_rig_lab/data/pilot_skin_preset.gd")
const Weapon3DRendererScript = preload("res://sandbox/pilot_rig_lab/guns_lab/orbital_weapon_3d_renderer.gd")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")

enum OrbitMode {
	AUTO_RADIAL = 0,
	MOUSE_AIM = 1,
	AUTO_TANGENT = 2,
}

const BACK_RING_Z: int = 2
const BACK_WEAPON_Z: int = 3
const BACK_RING_OVER_Z: int = 4
const FRONT_RING_Z: int = 10
const FRONT_WEAPON_Z: int = 11
const FRONT_RING_OVER_Z: int = 12
const FX_LAYER_Z: int = 13
const RING_SEGMENTS: int = 96
const MAX_SLOTS: int = 4
const MAX_TRACERS: int = 24
const MAIN_RAIL_UV_RADIUS: float = 0.3827


class _RingArcDrawer extends Node2D:
	var controller: OrbitalWeaponRingController = null
	var is_front_half: bool = false

	func _draw() -> void:
		if controller != null:
			controller.draw_ring_half(self, is_front_half)


class _FXDrawer extends Node2D:
	var controller: OrbitalWeaponRingController = null

	func _draw() -> void:
		if controller != null:
			controller.draw_combat_fx(self)


var _config: ConfigScript = null
var _weapon_texture: Texture2D = null
var _id_mask_tex: Texture2D = null
var _ilm_mask_tex: Texture2D = null
var _ink_sdf_tex: Texture2D = null
var _has_multi_maps: bool = false
var _use_3d_weapon: bool = false
var _active_skin: SkinPresetScript = null
var _orbit_mode: int = OrbitMode.AUTO_RADIAL
var _orbit_paused: bool = false
var _auto_fire_enabled: bool = false
var _auto_fire_timer: float = 0.0
var _auto_fire_slot_cursor: int = 0
var _sim_time: float = 0.0
var _base_orbit_angle: float = 0.25
var _target_mouse_local: Vector2 = Vector2(220.0, 0.0)
var _show_ring: bool = true
var _cosmic_lighting: CosmicLightingSampleScript = null

var _ring_back_drawer: _RingArcDrawer = null
var _ring_front_drawer: _RingArcDrawer = null
var _ring_texture: Texture2D = null
var _ring_back_sprite: Sprite2D = null
var _ring_front_sprite: Sprite2D = null
var _ring_back_over_sprite: Sprite2D = null
var _ring_front_over_sprite: Sprite2D = null
var _ring_back_mat: ShaderMaterial = null
var _ring_front_mat: ShaderMaterial = null
var _ring_back_over_mat: ShaderMaterial = null
var _ring_front_over_mat: ShaderMaterial = null
var _fx_drawer: _FXDrawer = null

var _slots: Array[Dictionary] = []
var _tracers: Array[Dictionary] = []


func _ready() -> void:
	if _config == null:
		_config = ConfigScript.new()
	_config.ensure_defaults()
	_build_layers()
	_rebuild_weapon_slots()


func set_config(cfg: ConfigScript) -> void:
	_config = cfg if cfg != null else ConfigScript.new()
	_config.ensure_defaults()
	if is_inside_tree():
		_rebuild_weapon_slots()
		_update_slots(0.0)


func get_config() -> ConfigScript:
	return _config


func set_weapon_3d_enabled(enabled: bool) -> void:
	if _use_3d_weapon == enabled:
		return
	_use_3d_weapon = enabled
	if is_inside_tree():
		_rebuild_weapon_slots()
		_update_slots(0.0)


func is_weapon_3d_enabled() -> bool:
	return _use_3d_weapon


func set_weapon_texture(tex: Texture2D) -> void:
	set_weapon_asset_bundle(tex, null, null, null)


func set_weapon_asset_bundle(
	albedo: Texture2D,
	id_mask: Texture2D = null,
	ilm_mask: Texture2D = null,
	ink_sdf: Texture2D = null
) -> void:
	var was_3d: bool = _use_3d_weapon
	_use_3d_weapon = false
	_weapon_texture = albedo
	_id_mask_tex = id_mask
	_ilm_mask_tex = ilm_mask
	_ink_sdf_tex = ink_sdf
	_has_multi_maps = (
		_weapon_texture != null
		and _id_mask_tex != null
		and _ilm_mask_tex != null
		and _ink_sdf_tex != null
	)
	if is_inside_tree() and was_3d:
		_rebuild_weapon_slots()
	else:
		for slot: Dictionary in _slots:
			var sprite: Sprite2D = slot["sprite"] as Sprite2D
			if is_instance_valid(sprite) and _weapon_texture != null:
				sprite.texture = _weapon_texture
				_apply_sprite_pivot(sprite)
			_bind_slot_static_maps(slot["material"] as ShaderMaterial)
	if is_inside_tree():
		_update_slots(0.0)


func set_ring_texture(tex: Texture2D) -> void:
	_ring_texture = tex
	for sp: Sprite2D in [_ring_back_sprite, _ring_front_sprite, _ring_back_over_sprite, _ring_front_over_sprite]:
		if is_instance_valid(sp):
			sp.texture = _ring_texture
	if is_inside_tree():
		_update_ring_sprites()


func has_ring_texture() -> bool:
	return _ring_texture != null


func apply_skin_preset(skin: SkinPresetScript) -> void:
	_active_skin = skin
	if is_inside_tree():
		_update_slots(0.0)
		_update_ring_sprites()
		if _ring_back_drawer != null:
			_ring_back_drawer.queue_redraw()
		if _ring_front_drawer != null:
			_ring_front_drawer.queue_redraw()


func apply_cosmic_lighting(sample: CosmicLightingSampleScript) -> void:
	if sample == null:
		_cosmic_lighting = null
	else:
		if _cosmic_lighting == null:
			_cosmic_lighting = CosmicLightingSampleScript.new()
		_cosmic_lighting.copy_from(sample)
	for slot: Dictionary in _slots:
		var renderer_3d: Weapon3DRendererScript = slot.get("renderer_3d", null) as Weapon3DRendererScript
		if is_instance_valid(renderer_3d):
			renderer_3d.apply_cosmic_lighting(_cosmic_lighting)
	if is_inside_tree():
		_update_slots(0.0)


func get_has_multi_maps() -> bool:
	return _has_multi_maps


func get_active_skin_id() -> String:
	if _active_skin == null:
		return "base"
	if _active_skin.is_base_skin or _active_skin.id.is_empty():
		return "base"
	return _active_skin.id


func _bind_slot_static_maps(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("has_multi_maps", _has_multi_maps)
	if _has_multi_maps:
		mat.set_shader_parameter("id_mask_tex", _id_mask_tex)
		mat.set_shader_parameter("ilm_mask_tex", _ilm_mask_tex)
		mat.set_shader_parameter("ink_sdf_tex", _ink_sdf_tex)


func _get_effective_ring_primary() -> Color:
	if _config == null:
		return Color(0.84, 0.90, 0.98, 0.85)
	if _active_skin != null and not _active_skin.is_base_skin and _config.ring_follow_skin:
		var tinted: Color = _active_skin.panel_color.lerp(Color.WHITE, 0.52)
		return Color(tinted.r, tinted.g, tinted.b, _config.ring_color_primary.a)
	return _config.ring_color_primary


func _get_effective_ring_accent() -> Color:
	if _config == null:
		return Color(0.95, 0.18, 0.36, 0.96)
	if _active_skin != null and not _active_skin.is_base_skin and _config.ring_follow_skin:
		return Color(
			_active_skin.accent_color.r,
			_active_skin.accent_color.g,
			_active_skin.accent_color.b,
			_config.ring_color_accent.a
		)
	return _config.ring_color_accent


func set_orbit_mode(mode: int) -> void:
	_orbit_mode = clampi(mode, OrbitMode.AUTO_RADIAL, OrbitMode.AUTO_TANGENT)


func get_orbit_mode() -> int:
	return _orbit_mode


func set_orbit_paused(paused: bool) -> void:
	_orbit_paused = paused


func set_auto_fire(enabled: bool) -> void:
	_auto_fire_enabled = enabled
	_auto_fire_timer = 0.0


func set_show_ring(visible_flag: bool) -> void:
	_show_ring = visible_flag
	if _ring_back_drawer != null:
		_ring_back_drawer.visible = _show_ring
	if _ring_front_drawer != null:
		_ring_front_drawer.visible = _show_ring
	_update_ring_sprites()


func set_weapon_count(count: int) -> void:
	if _config == null:
		return
	_config.weapon_count = clampi(count, 1, MAX_SLOTS)
	if is_inside_tree():
		_rebuild_weapon_slots()
		_update_slots(0.0)


func set_mouse_target_local(local_pos: Vector2) -> void:
	_target_mouse_local = local_pos


func set_orbit_angle_manual(angle_rad: float) -> void:
	_base_orbit_angle = wrapf(angle_rad, 0.0, TAU)
	_update_slots(0.0)


func get_orbit_angle() -> float:
	return _base_orbit_angle


func get_slot_count() -> int:
	return _slots.size()


func get_slot_state(index: int) -> Dictionary:
	if index < 0 or index >= _slots.size():
		return {}
	var s: Dictionary = _slots[index]
	var root: Node2D = s["root"] as Node2D
	return {
		"theta": float(s["theta"]),
		"depth": float(s["depth"]),
		"barrel_z": float(s["barrel_z"]),
		"z_index": root.z_index if is_instance_valid(root) else 0,
		"position": root.position if is_instance_valid(root) else Vector2.ZERO,
		"recoil": float(s["recoil"]),
		"fire_flash": float(s["fire_flash"]),
	}


func trigger_fire(slot_index: int = -1) -> void:
	if _slots.is_empty():
		return
	if slot_index >= 0 and slot_index < _slots.size():
		_fire_slot(_slots[slot_index])
		return
	for slot: Dictionary in _slots:
		_fire_slot(slot)


func step(delta: float) -> void:
	if _config == null:
		return
	_sim_time += delta

	if not _orbit_paused:
		if _orbit_mode == OrbitMode.AUTO_RADIAL or _orbit_mode == OrbitMode.AUTO_TANGENT:
			_base_orbit_angle = wrapf(_base_orbit_angle + _config.orbit_speed_rad * delta, 0.0, TAU)
		elif _orbit_mode == OrbitMode.MOUSE_AIM:
			var desired_angle: float = _compute_mouse_orbit_angle()
			var diff: float = wrapf(desired_angle - _base_orbit_angle, -PI, PI)
			var t: float = 1.0 - exp(-_config.mouse_follow_rate * delta)
			_base_orbit_angle = wrapf(_base_orbit_angle + diff * t, 0.0, TAU)

	if _auto_fire_enabled and not _slots.is_empty():
		_auto_fire_timer -= delta
		if _auto_fire_timer <= 0.0:
			_auto_fire_timer = maxf(0.08, _config.auto_fire_interval_sec / float(_slots.size()))
			_auto_fire_slot_cursor = _auto_fire_slot_cursor % _slots.size()
			_fire_slot(_slots[_auto_fire_slot_cursor])
			_auto_fire_slot_cursor = (_auto_fire_slot_cursor + 1) % _slots.size()

	_update_slots(delta)
	_update_ring_sprites()
	_update_tracers(delta)

	if _ring_back_drawer != null:
		_ring_back_drawer.queue_redraw()
	if _ring_front_drawer != null:
		_ring_front_drawer.queue_redraw()
	if _fx_drawer != null:
		_fx_drawer.queue_redraw()


func _build_layers() -> void:
	_ring_back_mat = ShaderMaterial.new()
	_ring_back_mat.shader = RingTextureShader
	_ring_back_mat.set_shader_parameter("is_front_half", false)
	_ring_back_mat.set_shader_parameter("over_hug_pass", false)

	_ring_back_sprite = _make_ring_sprite("OrbitalRingTexBack", BACK_RING_Z, _ring_back_mat)

	_ring_back_over_mat = ShaderMaterial.new()
	_ring_back_over_mat.shader = RingTextureShader
	_ring_back_over_mat.set_shader_parameter("is_front_half", false)
	_ring_back_over_mat.set_shader_parameter("over_hug_pass", true)

	_ring_back_over_sprite = _make_ring_sprite("OrbitalRingTexBackOver", BACK_RING_OVER_Z, _ring_back_over_mat)

	_ring_back_drawer = _RingArcDrawer.new()
	_ring_back_drawer.name = "OrbitalRingBack"
	_ring_back_drawer.controller = self
	_ring_back_drawer.is_front_half = false
	_ring_back_drawer.z_index = BACK_RING_Z
	add_child(_ring_back_drawer)

	_ring_front_mat = ShaderMaterial.new()
	_ring_front_mat.shader = RingTextureShader
	_ring_front_mat.set_shader_parameter("is_front_half", true)
	_ring_front_mat.set_shader_parameter("over_hug_pass", false)

	_ring_front_sprite = _make_ring_sprite("OrbitalRingTexFront", FRONT_RING_Z, _ring_front_mat)

	_ring_front_over_mat = ShaderMaterial.new()
	_ring_front_over_mat.shader = RingTextureShader
	_ring_front_over_mat.set_shader_parameter("is_front_half", true)
	_ring_front_over_mat.set_shader_parameter("over_hug_pass", true)

	_ring_front_over_sprite = _make_ring_sprite("OrbitalRingTexFrontOver", FRONT_RING_OVER_Z, _ring_front_over_mat)

	_ring_front_drawer = _RingArcDrawer.new()
	_ring_front_drawer.name = "OrbitalRingFront"
	_ring_front_drawer.controller = self
	_ring_front_drawer.is_front_half = true
	_ring_front_drawer.z_index = FRONT_RING_Z
	add_child(_ring_front_drawer)

	_fx_drawer = _FXDrawer.new()
	_fx_drawer.name = "OrbitalWeaponFX"
	_fx_drawer.controller = self
	_fx_drawer.z_index = FX_LAYER_Z
	add_child(_fx_drawer)


func _make_ring_sprite(node_name: String, z_ord: int, mat: ShaderMaterial) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = node_name
	sp.centered = true
	sp.z_index = z_ord
	sp.material = mat
	sp.visible = false
	if _ring_texture != null:
		sp.texture = _ring_texture
	add_child(sp)
	return sp


func _update_ring_sprites() -> void:
	if _config == null:
		return
	var use_tex: bool = _show_ring and _ring_texture != null and _config.ring_use_texture
	for sp: Sprite2D in [_ring_back_sprite, _ring_front_sprite, _ring_back_over_sprite, _ring_front_over_sprite]:
		if is_instance_valid(sp):
			sp.visible = use_tex
	if not use_tex:
		return

	var tex_sz: Vector2 = _ring_texture.get_size()
	var sx: float = (_config.ring_radius_x / maxf(tex_sz.x * MAIN_RAIL_UV_RADIUS, 1.0)) * _config.ring_texture_scale_mult
	var sy: float = (_config.ring_radius_y / maxf(tex_sz.y * MAIN_RAIL_UV_RADIUS, 1.0)) * _config.ring_texture_scale_mult
	var tilt_rad: float = deg_to_rad(_config.ring_tilt_deg)

	for sp: Sprite2D in [_ring_back_sprite, _ring_front_sprite, _ring_back_over_sprite, _ring_front_over_sprite]:
		if is_instance_valid(sp):
			sp.position = _config.ring_center_offset
			sp.rotation = tilt_rad
			sp.scale = Vector2(sx, sy)

	var eff_primary: Color = _get_effective_ring_primary()
	var eff_accent: Color = _get_effective_ring_accent()
	var outer_rot: float = _sim_time * _config.ring_outer_rot_speed
	var inner_rot: float = _sim_time * _config.ring_inner_arc_speed

	var angles := Vector4.ZERO
	var pulses := Vector4.ZERO
	var s_count: int = mini(_slots.size(), MAX_SLOTS)
	if s_count > 0:
		angles.x = float(_slots[0]["theta"])
		pulses.x = float(_slots[0]["anchor_pulse"])
	if s_count > 1:
		angles.y = float(_slots[1]["theta"])
		pulses.y = float(_slots[1]["anchor_pulse"])
	if s_count > 2:
		angles.z = float(_slots[2]["theta"])
		pulses.z = float(_slots[2]["anchor_pulse"])
	if s_count > 3:
		angles.w = float(_slots[3]["theta"])
		pulses.w = float(_slots[3]["anchor_pulse"])

	var mats: Array[ShaderMaterial] = [_ring_back_mat, _ring_front_mat, _ring_back_over_mat, _ring_front_over_mat]
	var front_flags: Array[bool] = [false, true, false, true]
	var over_flags: Array[bool] = [false, false, true, true]
	var alphas: Array[float] = [
		_config.ring_back_alpha_mult,
		_config.ring_front_alpha_mult,
		_config.ring_back_alpha_mult,
		_config.ring_front_alpha_mult,
	]
	for mi: int in range(4):
		var m: ShaderMaterial = mats[mi]
		if m == null:
			continue
		m.set_shader_parameter("is_front_half", front_flags[mi])
		m.set_shader_parameter("over_hug_pass", over_flags[mi])
		m.set_shader_parameter("main_rail_uv_radius", MAIN_RAIL_UV_RADIUS)
		m.set_shader_parameter("outer_rot_rad", outer_rot)
		m.set_shader_parameter("inner_rot_rad", inner_rot)
		m.set_shader_parameter("ring_primary_color", eff_primary)
		m.set_shader_parameter("ring_accent_color", eff_accent)
		m.set_shader_parameter("alpha_mult", alphas[mi])
		m.set_shader_parameter("slot_count", s_count)
		m.set_shader_parameter("slot_angles", angles)
		m.set_shader_parameter("slot_pulses", pulses)


func _rebuild_weapon_slots() -> void:
	for s: Dictionary in _slots:
		var old_root: Node2D = s.get("root", null) as Node2D
		if is_instance_valid(old_root):
			old_root.queue_free()
	_slots.clear()

	var count: int = clampi(_config.weapon_count, 1, MAX_SLOTS)
	for i: int in range(count):
		var root := Node2D.new()
		root.name = "OrbitalWeaponSlot_%d" % i
		add_child(root)

		var sprite := Sprite2D.new()
		sprite.name = "WeaponSprite"
		sprite.centered = true
		var mat: ShaderMaterial = null
		var renderer_3d: Weapon3DRendererScript = null

		if _use_3d_weapon:
			renderer_3d = Weapon3DRendererScript.new()
			renderer_3d.name = "Weapon3DRenderer"
			root.add_child(renderer_3d)
			if _cosmic_lighting != null:
				renderer_3d.apply_cosmic_lighting(_cosmic_lighting)
			sprite.texture = renderer_3d.get_texture()
			sprite.offset = Vector2.ZERO
		else:
			if _weapon_texture != null:
				sprite.texture = _weapon_texture
				_apply_sprite_pivot(sprite)
			mat = ShaderMaterial.new()
			mat.shader = WeaponShader
			_bind_slot_static_maps(mat)
			sprite.material = mat
		root.add_child(sprite)

		_slots.append({
			"index": i,
			"root": root,
			"sprite": sprite,
			"material": mat,
			"renderer_3d": renderer_3d,
			"theta": _base_orbit_angle + (TAU * float(i) / float(count)),
			"depth": 0.0,
			"barrel_z": 0.0,
			"aim_dir_2d": Vector2.RIGHT,
			"muzzle_pos": Vector2.ZERO,
			"recoil": 0.0,
			"fire_flash": 0.0,
			"anchor_pulse": 0.0,
		})


func _apply_sprite_pivot(sprite: Sprite2D) -> void:
	if sprite == null or sprite.texture == null or _config == null:
		return
	var tex_size: Vector2 = sprite.texture.get_size()
	sprite.offset = Vector2((0.5 - _config.weapon_pivot_u) * tex_size.x, 0.0)


func _compute_mouse_orbit_angle() -> float:
	var rel: Vector2 = _target_mouse_local - _config.ring_center_offset
	if rel.length_squared() < 1.0:
		return _base_orbit_angle
	var unrot: Vector2 = rel.rotated(-deg_to_rad(_config.ring_tilt_deg))
	var nx: float = unrot.x / maxf(_config.ring_radius_x, 1.0)
	var ny: float = unrot.y / maxf(_config.ring_radius_y, 1.0)
	return wrapf(atan2(ny, nx), 0.0, TAU)


func _project_ring_point(theta: float, scale_mult: float = 1.0) -> Vector2:
	var tilt_rad: float = deg_to_rad(_config.ring_tilt_deg)
	var local_p := Vector2(
		cos(theta) * _config.ring_radius_x * scale_mult,
		sin(theta) * _config.ring_radius_y * scale_mult
	)
	return _config.ring_center_offset + local_p.rotated(tilt_rad)


func _update_slots(delta: float) -> void:
	var count: int = _slots.size()
	if count == 0:
		return
	var tilt_rad: float = deg_to_rad(_config.ring_tilt_deg)
	var ellipse_ratio: float = clampf(_config.ring_radius_y / maxf(_config.ring_radius_x, 1.0), 0.15, 1.0)
	var elev_rad: float = asin(clampf(ellipse_ratio, 0.15, 0.98))
	var view_basis: Basis = Basis(Vector3.BACK, -tilt_rad) * Basis(Vector3.RIGHT, elev_rad)
	var ring_up_3d: Vector3 = (view_basis * Vector3.UP).normalized()

	for i: int in range(count):
		var slot: Dictionary = _slots[i]
		var root: Node2D = slot["root"] as Node2D
		var sprite: Sprite2D = slot["sprite"] as Sprite2D
		var mat: ShaderMaterial = slot.get("material", null) as ShaderMaterial
		var renderer_3d: Weapon3DRendererScript = slot.get("renderer_3d", null) as Weapon3DRendererScript
		if not is_instance_valid(root) or not is_instance_valid(sprite):
			continue

		if not _use_3d_weapon:
			_apply_sprite_pivot(sprite)

		# Distribución angular según modo
		var slot_offset: float = 0.0
		if count > 1:
			if _orbit_mode == OrbitMode.MOUSE_AIM:
				# Formación en abanico táctico alrededor de la dirección de apuntado
				var spread: float = 0.42
				var centered_i: float = float(i) - float(count - 1) * 0.5
				slot_offset = centered_i * spread
			else:
				slot_offset = TAU * float(i) / float(count)

		var theta: float = wrapf(_base_orbit_angle + slot_offset, 0.0, TAU)
		var depth: float = sin(theta) # -1 atrás (arriba), +1 adelante (abajo)
		var ring_pos: Vector2 = _project_ring_point(theta, 1.0)

		# Decaimiento de recoil y flash
		var recoil: float = float(slot["recoil"])
		var fire_flash: float = float(slot["fire_flash"])
		var anchor_pulse: float = float(slot["anchor_pulse"])
		if delta > 0.0:
			recoil = recoil * exp(-_config.recoil_recover_rate * delta)
			if recoil < 0.005:
				recoil = 0.0
			fire_flash = maxf(0.0, fire_flash - delta * 6.5)
			anchor_pulse = maxf(0.0, anchor_pulse - delta * 4.5)
		slot["recoil"] = recoil
		slot["fire_flash"] = fire_flash
		slot["anchor_pulse"] = anchor_pulse

		# Dirección de apuntado 3D proyectada a 2D y profundidad del cañón (barrel_z)
		var aim_vec_2d: Vector2 = Vector2.RIGHT
		var aim_dir_3d: Vector3 = Vector3.RIGHT
		var barrel_z: float = 0.0

		if _orbit_mode == OrbitMode.AUTO_RADIAL:
			# Apunta radialmente hacia afuera sobre el plano 3D del anillo
			var radial_proj := Vector2(cos(theta), sin(theta) * _config.aim_pitch_compression).rotated(tilt_rad)
			aim_vec_2d = radial_proj.normalized() if radial_proj.length_squared() > 0.0001 else Vector2.RIGHT
			barrel_z = sin(theta) * (1.0 - ellipse_ratio * 0.35)
			aim_dir_3d = (view_basis * Vector3(cos(theta), 0.0, sin(theta))).normalized()
		elif _orbit_mode == OrbitMode.AUTO_TANGENT:
			var tan_angle: float = theta + PI * 0.5
			var tan_proj := Vector2(cos(tan_angle), sin(tan_angle) * _config.aim_pitch_compression).rotated(tilt_rad)
			aim_vec_2d = tan_proj.normalized() if tan_proj.length_squared() > 0.0001 else Vector2.RIGHT
			barrel_z = sin(tan_angle) * (1.0 - ellipse_ratio * 0.35)
			aim_dir_3d = (view_basis * Vector3(-sin(theta), 0.0, cos(theta))).normalized()
		else:
			# MOUSE_AIM: apunta al cursor con proyección 2.5D según verticalidad
			var to_mouse: Vector2 = _target_mouse_local - ring_pos
			aim_vec_2d = to_mouse.normalized() if to_mouse.length_squared() > 1.0 else Vector2.RIGHT
			barrel_z = clampf(aim_vec_2d.y * (1.0 - ellipse_ratio * 0.25), -1.0, 1.0)
			aim_dir_3d = Vector3(aim_vec_2d.x, -aim_vec_2d.y, barrel_z * 0.45).normalized()

		barrel_z = clampf(barrel_z, -1.0, 1.0)

		# Escala perspectiva + bobbing Zero-G + offset radial + retroceso físico
		var persp_scale: float = 1.0 + depth * _config.perspective_scale_amp
		var bob_y: float = sin(_sim_time * _config.weapon_bob_speed + float(i) * 1.7) * _config.weapon_vertical_bob_px
		var radial_push: Vector2 = aim_vec_2d * (_config.weapon_radial_offset_px * persp_scale)
		var eff_primary: Color = _get_effective_ring_primary()
		var eff_accent: Color = _get_effective_ring_accent()
		var eff_rim_color: Color = eff_primary
		var eff_rim_strength: float = _config.rim_strength
		if _cosmic_lighting != null:
			eff_rim_color = eff_primary.lerp(_cosmic_lighting.rim_key_color, clampf(_cosmic_lighting.rim_tint_weight, 0.0, 1.0))
			eff_rim_strength = _config.rim_strength * lerpf(1.0, 0.45, clampf(_cosmic_lighting.eclipse_factor, 0.0, 1.0))
		var muzzle_pos: Vector2 = Vector2.ZERO

		root.z_index = FRONT_WEAPON_Z if depth >= 0.0 else BACK_WEAPON_Z

		if _use_3d_weapon and is_instance_valid(renderer_3d):
			root.position = ring_pos + radial_push + Vector2(0.0, bob_y)
			root.rotation = 0.0
			sprite.offset = Vector2.ZERO
			sprite.modulate = Color.WHITE
			var vp_scale: float = (_config.weapon_base_scale / 0.135) * 0.76 * persp_scale
			sprite.scale = Vector2(vp_scale, vp_scale)

			var skin_recolor_on: bool = _active_skin != null and not _active_skin.is_base_skin
			if skin_recolor_on:
				renderer_3d.apply_skin_palette(
					true,
					_active_skin.accent_color,
					_active_skin.panel_color,
					_active_skin.suit_dark_color
				)
			else:
				renderer_3d.apply_skin_palette(false, eff_accent, eff_primary, Color.BLACK)

			renderer_3d.update_pose(
				aim_dir_3d,
				ring_up_3d,
				recoil,
				deg_to_rad(_config.recoil_pitch_kick_deg) * recoil,
				depth,
				_config.depth_back_dim,
				_config.depth_back_tint,
				eff_rim_strength,
				eff_rim_color,
				_config.specular_sweep_strength,
				fire_flash * _config.fire_glow_boost,
				eff_accent
			)

			var proj_2d := Vector2(aim_dir_3d.x, -aim_dir_3d.y)
			if proj_2d.length_squared() > 0.0001:
				aim_vec_2d = proj_2d.normalized()
			var muzzle_off: Vector2 = renderer_3d.get_muzzle_uv_offset() * vp_scale
			if muzzle_off.length_squared() < 1.0:
				muzzle_off = aim_vec_2d * (64.0 * vp_scale)
			muzzle_pos = root.position + muzzle_off
		else:
			var recoil_push: Vector2 = -aim_vec_2d * (recoil * _config.recoil_kick_px * persp_scale)
			root.position = ring_pos + radial_push + recoil_push + Vector2(0.0, bob_y)

			# Rotación + flip limpio (el cruce vertical coincide con máximo escorzo, ocultando el flip)
			var aim_angle: float = aim_vec_2d.angle()
			var facing_left: bool = cos(aim_angle) < 0.0
			var flip_sign: float = -1.0 if facing_left else 1.0
			var recoil_pitch: float = deg_to_rad(_config.recoil_pitch_kick_deg) * recoil * (-flip_sign)
			root.rotation = aim_angle + recoil_pitch

			# Escorzo longitudinal del cañón (barrel_z -> compresión en X)
			var abs_bz: float = absf(barrel_z)
			var foreshorten_x: float = lerpf(1.0, _config.foreshorten_min_x, pow(abs_bz, 1.15) * _config.foreshorten_strength)
			var scale_x: float = _config.weapon_base_scale * persp_scale * foreshorten_x
			var scale_y: float = _config.weapon_base_scale * persp_scale * flip_sign
			sprite.scale = Vector2(scale_x, scale_y)

			# Actualizar uniforms del shader 2.5D
			var recolor_on: bool = _has_multi_maps and _active_skin != null and not _active_skin.is_base_skin
			if mat != null:
				mat.set_shader_parameter("barrel_z", barrel_z)
				mat.set_shader_parameter("orbit_depth", depth)
				mat.set_shader_parameter("orbit_angle", theta)
				mat.set_shader_parameter("pivot_u", _config.weapon_pivot_u)
				mat.set_shader_parameter("trapezoid_strength", _config.trapezoid_strength)
				mat.set_shader_parameter("extrude_depth_px", _config.extrude_depth_px)
				var ext_dir := Vector2(-0.35 * signf(barrel_z if absf(barrel_z) > 0.05 else 1.0), 0.92 * flip_sign).normalized()
				mat.set_shader_parameter("extrude_dir", ext_dir)
				mat.set_shader_parameter("extrude_tint", _config.extrude_tint)
				mat.set_shader_parameter("depth_back_dim", _config.depth_back_dim)
				mat.set_shader_parameter("depth_back_tint", _config.depth_back_tint)
				mat.set_shader_parameter("rim_strength", eff_rim_strength)
				mat.set_shader_parameter("rim_color", eff_rim_color)
				mat.set_shader_parameter("specular_sweep_strength", _config.specular_sweep_strength)
				mat.set_shader_parameter("fire_flash", fire_flash * _config.fire_glow_boost)
				mat.set_shader_parameter("fire_glow_color", eff_accent)
				mat.set_shader_parameter("has_multi_maps", _has_multi_maps)
				mat.set_shader_parameter("ink_sdf_strength", _config.ink_sdf_strength)
				mat.set_shader_parameter("skin_recolor_enabled", recolor_on)
				if recolor_on:
					mat.set_shader_parameter("skin_accent_color", _active_skin.accent_color)
					mat.set_shader_parameter("skin_panel_color", _active_skin.panel_color)
					mat.set_shader_parameter("skin_dark_color", _active_skin.suit_dark_color)

			# Calcular posición proyectada de la boca del cañón en espacio local del controlador
			var barrel_len_px: float = 0.0
			if sprite.texture != null:
				var tex_w: float = sprite.texture.get_size().x
				barrel_len_px = (_config.weapon_muzzle_u - _config.weapon_pivot_u) * tex_w * scale_x
			muzzle_pos = root.position + Vector2.RIGHT.rotated(root.rotation) * barrel_len_px

		slot["theta"] = theta
		slot["depth"] = depth
		slot["barrel_z"] = barrel_z
		slot["aim_dir_2d"] = aim_vec_2d
		slot["muzzle_pos"] = muzzle_pos

	_update_ring_sprites()


func _fire_slot(slot: Dictionary) -> void:
	slot["recoil"] = 1.0
	slot["fire_flash"] = 1.0
	slot["anchor_pulse"] = 1.0
	if _tracers.size() >= MAX_TRACERS:
		_tracers.pop_front()
	var muzzle: Vector2 = slot["muzzle_pos"] as Vector2
	var dir: Vector2 = slot["aim_dir_2d"] as Vector2
	var depth: float = float(slot["depth"])
	_tracers.append({
		"pos": muzzle,
		"dir": dir.normalized(),
		"life": 0.34,
		"max_life": 0.34,
		"scale": 1.0 + depth * _config.perspective_scale_amp,
	})


func _update_tracers(delta: float) -> void:
	if delta <= 0.0:
		return
	var write_idx: int = 0
	for i: int in range(_tracers.size()):
		var tr: Dictionary = _tracers[i]
		var life: float = float(tr["life"]) - delta
		if life > 0.0:
			var dir: Vector2 = tr["dir"] as Vector2
			tr["pos"] = (tr["pos"] as Vector2) + dir * (_config.tracer_speed_px * delta)
			tr["life"] = life
			_tracers[write_idx] = tr
			write_idx += 1
	_tracers.resize(write_idx)


func draw_ring_half(canvas: Node2D, is_front: bool) -> void:
	if _config == null or not _show_ring:
		return

	var start_a: float = 0.0 if is_front else PI
	var end_a: float = PI if is_front else TAU
	var half_steps: int = RING_SEGMENTS / 2
	var alpha_mult: float = _config.ring_front_alpha_mult if is_front else _config.ring_back_alpha_mult
	var eff_primary: Color = _get_effective_ring_primary()
	var eff_accent: Color = _get_effective_ring_accent()
	var using_tex_ring: bool = _ring_texture != null and _config.ring_use_texture

	if not using_tex_ring:
		var main_pts := PackedVector2Array()
		main_pts.resize(half_steps + 1)
		for k: int in range(half_steps + 1):
			var t: float = float(k) / float(half_steps)
			var a: float = lerpf(start_a, end_a, t)
			main_pts[k] = _project_ring_point(a, 1.0)

		# 1. Riel principal minimalista + glow HDR sutil + núcleo fino plata
		var glow_col := Color(
			eff_primary.r * 1.25,
			eff_primary.g * 1.25,
			eff_primary.b * 1.25,
			eff_primary.a * alpha_mult * 0.16
		)
		canvas.draw_polyline(main_pts, glow_col, _config.ring_thickness_px * 3.0, true)

		var main_col := Color(
			eff_primary.r * 1.10,
			eff_primary.g * 1.10,
			eff_primary.b * 1.10,
			eff_primary.a * alpha_mult * 0.88
		)
		canvas.draw_polyline(main_pts, main_col, _config.ring_thickness_px, true)

		var core_line_col := Color(
			lerpf(eff_primary.r, 1.0, 0.55) * 1.20,
			lerpf(eff_primary.g, 1.0, 0.55) * 1.20,
			lerpf(eff_primary.b, 1.0, 0.55) * 1.20,
			eff_primary.a * alpha_mult * 0.92
		)
		canvas.draw_polyline(main_pts, core_line_col, maxf(1.0, _config.ring_thickness_px * 0.42), true)

		# 2. Arcos astrolabio interiores segmentados contrarrotativos
		_draw_astrolabe_inner_arcs(canvas, is_front, alpha_mult, eff_primary)

		# 3. Micro-marcas cardinales discretas en el riel secundario
		_draw_cardinal_diamond_pips(canvas, is_front, alpha_mult, eff_primary, eff_accent)

		# 4. Cristales romboidales facetados y pulso sobre cada anclaje de arma
		_draw_crystal_anchors(canvas, is_front, alpha_mult, eff_primary, eff_accent)
	else:
		# Con textura IA activa, solo halo sutil de energía bajo cada arma (el cristal 3D ya protagoniza el anclaje)
		_draw_soft_anchor_halos(canvas, is_front, alpha_mult, eff_accent)

	# 5. Polvo estelar de 4 puntas orbitando suavemente el anillo
	_draw_ring_stardust(canvas, is_front, alpha_mult, eff_primary, eff_accent)


func _draw_soft_anchor_halos(
	canvas: Node2D,
	is_front: bool,
	alpha_mult: float,
	eff_accent: Color
) -> void:
	for slot: Dictionary in _slots:
		var depth: float = float(slot["depth"])
		if (is_front and depth < 0.0) or (not is_front and depth >= 0.0):
			continue
		var theta: float = float(slot["theta"])
		var pulse: float = float(slot["anchor_pulse"])
		var anchor_pos: Vector2 = _project_ring_point(theta, 1.0)
		var persp_s: float = 1.0 + depth * _config.perspective_scale_amp
		var base_r: float = _config.ring_anchor_glow_radius * 0.9 * persp_s * (1.0 + pulse * 0.45)

		var outer_halo := Color(
			eff_accent.r * 1.35,
			eff_accent.g * 1.35,
			eff_accent.b * 1.35,
			(0.18 + pulse * 0.36) * alpha_mult
		)
		var core_halo := Color(
			lerpf(eff_accent.r, 1.0, 0.55) * 1.45,
			lerpf(eff_accent.g, 1.0, 0.55) * 1.45,
			lerpf(eff_accent.b, 1.0, 0.55) * 1.45,
			(0.32 + pulse * 0.50) * alpha_mult
		)
		canvas.draw_circle(anchor_pos, base_r, outer_halo)
		canvas.draw_circle(anchor_pos, base_r * 0.42, core_halo)


func _draw_astrolabe_inner_arcs(
	canvas: Node2D,
	is_front: bool,
	alpha_mult: float,
	eff_primary: Color
) -> void:
	var arc_count: int = clampi(_config.ring_inner_arc_count, 1, 6)
	var span: float = _config.ring_inner_arc_span_rad
	var rot_offset: float = _sim_time * _config.ring_inner_arc_speed
	var arc_col := Color(
		eff_primary.r,
		eff_primary.g,
		eff_primary.b,
		eff_primary.a * alpha_mult * 0.42
	)
	var cap_col := Color(
		lerpf(eff_primary.r, 1.0, 0.5) * 1.2,
		lerpf(eff_primary.g, 1.0, 0.5) * 1.2,
		lerpf(eff_primary.b, 1.0, 0.5) * 1.2,
		eff_primary.a * alpha_mult * 0.72
	)
	var steps_per_arc: int = 18

	for i: int in range(arc_count):
		var center_a: float = rot_offset + (TAU * float(i) / float(arc_count))
		var run_pts := PackedVector2Array()
		var run_start_visible: bool = false
		var run_end_pt: Vector2 = Vector2.ZERO

		for s_idx: int in range(steps_per_arc + 1):
			var u: float = float(s_idx) / float(steps_per_arc)
			var a: float = center_a + lerpf(-span * 0.5, span * 0.5, u)
			var sa: float = sin(a)
			var in_half: bool = (sa >= -0.02) if is_front else (sa <= 0.02)
			if in_half:
				var pt: Vector2 = _project_ring_point(a, _config.ring_secondary_scale)
				if run_pts.is_empty():
					run_start_visible = (s_idx == 0)
				run_pts.append(pt)
				run_end_pt = pt
			elif not run_pts.is_empty():
				if run_pts.size() >= 2:
					canvas.draw_polyline(run_pts, arc_col, maxf(1.0, _config.ring_thickness_px * 0.55), true)
					if run_start_visible:
						_draw_rhombus(canvas, run_pts[0], 2.6, 2.6, cap_col)
				run_pts.clear()

		if run_pts.size() >= 2:
			canvas.draw_polyline(run_pts, arc_col, maxf(1.0, _config.ring_thickness_px * 0.55), true)
			if run_start_visible:
				_draw_rhombus(canvas, run_pts[0], 2.6, 2.6, cap_col)
			_draw_rhombus(canvas, run_end_pt, 2.6, 2.6, cap_col)


func _draw_cardinal_diamond_pips(
	canvas: Node2D,
	is_front: bool,
	alpha_mult: float,
	eff_primary: Color,
	eff_accent: Color
) -> void:
	var rot_offset: float = _sim_time * (_config.ring_inner_arc_speed * 0.5)
	for i: int in range(4):
		var a: float = rot_offset + (PI * 0.5) * float(i)
		var sa: float = sin(a)
		if (is_front and sa < -0.02) or (not is_front and sa > 0.02):
			continue
		var pos: Vector2 = _project_ring_point(a, 1.0)
		var outer_col := Color(eff_primary.r * 1.15, eff_primary.g * 1.15, eff_primary.b * 1.15, 0.80 * alpha_mult)
		var inner_col := Color(eff_accent.r * 1.25, eff_accent.g * 1.25, eff_accent.b * 1.25, 0.72 * alpha_mult)
		_draw_rhombus(canvas, pos, 4.4, 3.0, outer_col)
		_draw_rhombus(canvas, pos, 2.2, 1.5, inner_col)


func _draw_crystal_anchors(
	canvas: Node2D,
	is_front: bool,
	alpha_mult: float,
	eff_primary: Color,
	eff_accent: Color
) -> void:
	var diamond_sz: float = _config.ring_diamond_size_px
	for slot: Dictionary in _slots:
		var depth: float = float(slot["depth"])
		if (is_front and depth < 0.0) or (not is_front and depth >= 0.0):
			continue
		var theta: float = float(slot["theta"])
		var pulse: float = float(slot["anchor_pulse"])
		var anchor_pos: Vector2 = _project_ring_point(theta, 1.0)
		var persp_s: float = 1.0 + depth * _config.perspective_scale_amp
		var base_r: float = _config.ring_anchor_glow_radius * persp_s * (1.0 + pulse * 0.45)

		# Halo suave HDR detrás del cristal romboidal
		var halo_col := Color(
			eff_accent.r * 1.35,
			eff_accent.g * 1.35,
			eff_accent.b * 1.35,
			(0.22 + pulse * 0.42) * alpha_mult
		)
		canvas.draw_circle(anchor_pos, base_r * 0.95, halo_col)

		# Arco energetizado local sobre el riel alrededor del arma
		var arc_pts := PackedVector2Array()
		var span: float = 0.24 + pulse * 0.16
		for j: int in range(11):
			var aa: float = theta + lerpf(-span, span, float(j) / 10.0)
			arc_pts.append(_project_ring_point(aa, 1.0))
		var rail_flare_col := Color(
			lerpf(eff_primary.r, eff_accent.r, 0.45 + pulse * 0.50) * 1.45,
			lerpf(eff_primary.g, eff_accent.g, 0.45 + pulse * 0.50) * 1.45,
			lerpf(eff_primary.b, eff_accent.b, 0.45 + pulse * 0.50) * 1.45,
			(0.75 + pulse * 0.25) * alpha_mult
		)
		canvas.draw_polyline(arc_pts, rail_flare_col, _config.ring_thickness_px * (1.65 + pulse * 0.65), true)

		# Cristal romboidal facetado (borde plata + cuerpo acento + faceta brillante)
		var rx: float = diamond_sz * 0.58 * persp_s * (1.0 + pulse * 0.35)
		var ry: float = diamond_sz * 1.15 * persp_s * (1.0 + pulse * 0.35)
		var rim_col := Color(
			lerpf(eff_primary.r, 1.0, 0.65),
			lerpf(eff_primary.g, 1.0, 0.65),
			lerpf(eff_primary.b, 1.0, 0.65),
			0.95 * alpha_mult
		)
		var crystal_col := Color(
			eff_accent.r * (1.25 + pulse * 0.45),
			eff_accent.g * (1.25 + pulse * 0.45),
			eff_accent.b * (1.25 + pulse * 0.45),
			0.96 * alpha_mult
		)
		var facet_hi_col := Color(
			lerpf(eff_accent.r, 1.0, 0.65) * 1.35,
			lerpf(eff_accent.g, 1.0, 0.65) * 1.35,
			lerpf(eff_accent.b, 1.0, 0.65) * 1.35,
			0.92 * alpha_mult
		)
		_draw_rhombus(canvas, anchor_pos, rx + 1.5, ry + 1.8, rim_col)
		_draw_rhombus(canvas, anchor_pos, rx, ry, crystal_col)
		var top_facet := PackedVector2Array([
			anchor_pos + Vector2(0.0, -ry * 0.85),
			anchor_pos + Vector2(rx * 0.72, 0.0),
			anchor_pos,
			anchor_pos + Vector2(-rx * 0.72, 0.0),
		])
		canvas.draw_colored_polygon(top_facet, facet_hi_col)


func _draw_ring_stardust(
	canvas: Node2D,
	is_front: bool,
	alpha_mult: float,
	eff_primary: Color,
	eff_accent: Color
) -> void:
	var count: int = clampi(_config.ring_stardust_count, 0, 24)
	if count == 0:
		return
	for i: int in range(count):
		var fi: float = float(i)
		var speed: float = 0.28 if (i % 2 == 0) else -0.22
		var a: float = wrapf((TAU * fi / float(count)) + _sim_time * speed, 0.0, TAU)
		var sa: float = sin(a)
		if (is_front and sa < -0.02) or (not is_front and sa > 0.02):
			continue
		var radial_scale: float = lerpf(0.90, 1.09, 0.5 + 0.5 * sin(fi * 2.13 + _sim_time * 1.4))
		var pos: Vector2 = _project_ring_point(a, radial_scale)
		pos.y += sin(_sim_time * 2.1 + fi * 1.7) * 4.5
		var twinkle: float = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(_sim_time * 3.4 + fi * 2.7), 2.0)
		var sz: float = lerpf(2.8, 5.2, fmod(fi * 0.37, 1.0)) * (0.7 + 0.3 * twinkle)
		var col_base: Color = eff_accent if (i % 3 == 0) else eff_primary.lerp(Color.WHITE, 0.45)
		var star_col := Color(col_base.r * 1.35, col_base.g * 1.35, col_base.b * 1.35, twinkle * 0.82 * alpha_mult)
		canvas.draw_line(pos - Vector2(sz, 0.0), pos + Vector2(sz, 0.0), star_col, 1.2, true)
		canvas.draw_line(pos - Vector2(0.0, sz), pos + Vector2(0.0, sz), star_col, 1.2, true)
		canvas.draw_circle(pos, 1.1, Color(1.4, 1.4, 1.5, twinkle * alpha_mult))


func _draw_rhombus(canvas: Node2D, center: Vector2, half_w: float, half_h: float, col: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0.0, -half_h),
		center + Vector2(half_w, 0.0),
		center + Vector2(0.0, half_h),
		center + Vector2(-half_w, 0.0),
	])
	canvas.draw_colored_polygon(pts, col)


func draw_combat_fx(canvas: Node2D) -> void:
	if _config == null:
		return

	var eff_primary: Color = _get_effective_ring_primary()
	var eff_accent: Color = _get_effective_ring_accent()

	# Muzzle flashes Astral Seraph en forma de estrella-diamante HDR
	for slot: Dictionary in _slots:
		var flash: float = float(slot["fire_flash"])
		if flash <= 0.05:
			continue
		var muzzle: Vector2 = slot["muzzle_pos"] as Vector2
		var dir: Vector2 = slot["aim_dir_2d"] as Vector2
		var perp := Vector2(-dir.y, dir.x)
		var depth: float = float(slot["depth"])
		var s: float = (1.0 + depth * _config.perspective_scale_amp) * flash

		var outer_col := Color(
			eff_accent.r * 1.65,
			eff_accent.g * 1.65,
			eff_accent.b * 1.65,
			clampf(flash * 0.92, 0.0, 1.0)
		)
		var rim_col := Color(
			lerpf(eff_primary.r, 1.0, 0.5) * 1.5,
			lerpf(eff_primary.g, 1.0, 0.5) * 1.5,
			lerpf(eff_primary.b, 1.0, 0.5) * 1.5,
			clampf(flash * 0.85, 0.0, 1.0)
		)
		var core_col := Color(1.75, 1.75, 1.85, clampf(flash, 0.0, 1.0))

		# Destello diamante asimétrico hacia adelante + cruz estelar
		var star_pts := PackedVector2Array([
			muzzle + dir * (44.0 * s),
			muzzle + perp * (11.0 * s),
			muzzle - dir * (12.0 * s),
			muzzle - perp * (11.0 * s),
		])
		canvas.draw_colored_polygon(star_pts, outer_col)

		var inner_pts := PackedVector2Array([
			muzzle + dir * (26.0 * s),
			muzzle + perp * (5.2 * s),
			muzzle - dir * (6.0 * s),
			muzzle - perp * (5.2 * s),
		])
		canvas.draw_colored_polygon(inner_pts, core_col)
		canvas.draw_line(muzzle - perp * (24.0 * s), muzzle + perp * (24.0 * s), rim_col, 2.2 * s, true)

	# Trazadores estilo Lance-Beam volando hacia afuera
	for tr: Dictionary in _tracers:
		var pos: Vector2 = tr["pos"] as Vector2
		var dir: Vector2 = tr["dir"] as Vector2
		var perp := Vector2(-dir.y, dir.x)
		var life_ratio: float = clampf(float(tr["life"]) / maxf(float(tr["max_life"]), 0.01), 0.0, 1.0)
		var sc: float = float(tr["scale"])
		var len_px: float = _config.tracer_length_px * sc
		var tip: Vector2 = pos + dir * (10.0 * sc)
		var shoulder: Vector2 = pos - dir * (len_px * 0.16)
		var tail: Vector2 = pos - dir * len_px

		var outer_col := Color(
			eff_accent.r * 1.55,
			eff_accent.g * 1.55,
			eff_accent.b * 1.55,
			life_ratio * 0.88
		)
		var inner_col := Color(1.70, 1.75, 1.85, life_ratio)

		var outer_lance := PackedVector2Array([
			tip,
			shoulder + perp * (4.2 * sc),
			tail,
			shoulder - perp * (4.2 * sc),
		])
		canvas.draw_colored_polygon(outer_lance, outer_col)

		var core_lance := PackedVector2Array([
			pos + dir * (6.0 * sc),
			shoulder + perp * (1.7 * sc),
			pos - dir * (len_px * 0.65),
			shoulder - perp * (1.7 * sc),
		])
		canvas.draw_colored_polygon(core_lance, inner_col)
