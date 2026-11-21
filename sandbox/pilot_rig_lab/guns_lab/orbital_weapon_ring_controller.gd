class_name OrbitalWeaponRingController
extends Node2D
## Controlador desacoplado del Anillo Orbital 2.5D y Armamento (Guns Lab — Valentina v2).
## Proyecta una elipse 3D inclinada partida en arco trasero (z=2) y delantero (z=10),
## y anima de 1 a 4 armas con Z-sorting real, escala perspectiva, escorzo, trapezoide 2.5D,
## extrusión falsa, recoil físico, muzzle flash y trazadores.

const WeaponShader = preload("res://sandbox/pilot_rig_lab/guns_lab/orbital_weapon_25d.gdshader")
const ConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_orbital_weapon_config.gd")

enum OrbitMode {
	AUTO_RADIAL = 0,
	MOUSE_AIM = 1,
	AUTO_TANGENT = 2,
}

const BACK_RING_Z: int = 2
const BACK_WEAPON_Z: int = 3
const FRONT_RING_Z: int = 10
const FRONT_WEAPON_Z: int = 11
const FX_LAYER_Z: int = 12
const RING_SEGMENTS: int = 96
const MAX_SLOTS: int = 4
const MAX_TRACERS: int = 24


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
var _orbit_mode: int = OrbitMode.AUTO_RADIAL
var _orbit_paused: bool = false
var _auto_fire_enabled: bool = false
var _auto_fire_timer: float = 0.0
var _auto_fire_slot_cursor: int = 0
var _sim_time: float = 0.0
var _base_orbit_angle: float = 0.25
var _target_mouse_local: Vector2 = Vector2(220.0, 0.0)
var _show_ring: bool = true

var _ring_back_drawer: _RingArcDrawer = null
var _ring_front_drawer: _RingArcDrawer = null
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


func set_weapon_texture(tex: Texture2D) -> void:
	_weapon_texture = tex
	for slot: Dictionary in _slots:
		var sprite: Sprite2D = slot["sprite"] as Sprite2D
		if is_instance_valid(sprite) and _weapon_texture != null:
			sprite.texture = _weapon_texture
			_apply_sprite_pivot(sprite)


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
	_update_tracers(delta)

	if _ring_back_drawer != null:
		_ring_back_drawer.queue_redraw()
	if _ring_front_drawer != null:
		_ring_front_drawer.queue_redraw()
	if _fx_drawer != null:
		_fx_drawer.queue_redraw()


func _build_layers() -> void:
	_ring_back_drawer = _RingArcDrawer.new()
	_ring_back_drawer.name = "OrbitalRingBack"
	_ring_back_drawer.controller = self
	_ring_back_drawer.is_front_half = false
	_ring_back_drawer.z_index = BACK_RING_Z
	add_child(_ring_back_drawer)

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
		if _weapon_texture != null:
			sprite.texture = _weapon_texture
			_apply_sprite_pivot(sprite)

		var mat := ShaderMaterial.new()
		mat.shader = WeaponShader
		sprite.material = mat
		root.add_child(sprite)

		_slots.append({
			"index": i,
			"root": root,
			"sprite": sprite,
			"material": mat,
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

	for i: int in range(count):
		var slot: Dictionary = _slots[i]
		var root: Node2D = slot["root"] as Node2D
		var sprite: Sprite2D = slot["sprite"] as Sprite2D
		var mat: ShaderMaterial = slot["material"] as ShaderMaterial
		if not is_instance_valid(root) or not is_instance_valid(sprite):
			continue

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
		var barrel_z: float = 0.0

		if _orbit_mode == OrbitMode.AUTO_RADIAL:
			# Apunta radialmente hacia afuera sobre el plano 3D del anillo
			var radial_proj := Vector2(cos(theta), sin(theta) * _config.aim_pitch_compression).rotated(tilt_rad)
			aim_vec_2d = radial_proj.normalized() if radial_proj.length_squared() > 0.0001 else Vector2.RIGHT
			barrel_z = sin(theta) * (1.0 - ellipse_ratio * 0.35)
		elif _orbit_mode == OrbitMode.AUTO_TANGENT:
			var tan_angle: float = theta + PI * 0.5
			var tan_proj := Vector2(cos(tan_angle), sin(tan_angle) * _config.aim_pitch_compression).rotated(tilt_rad)
			aim_vec_2d = tan_proj.normalized() if tan_proj.length_squared() > 0.0001 else Vector2.RIGHT
			barrel_z = sin(tan_angle) * (1.0 - ellipse_ratio * 0.35)
		else:
			# MOUSE_AIM: apunta al cursor con proyección 2.5D según verticalidad
			var to_mouse: Vector2 = _target_mouse_local - ring_pos
			aim_vec_2d = to_mouse.normalized() if to_mouse.length_squared() > 1.0 else Vector2.RIGHT
			barrel_z = clampf(aim_vec_2d.y * (1.0 - ellipse_ratio * 0.25), -1.0, 1.0)

		barrel_z = clampf(barrel_z, -1.0, 1.0)

		# Escala perspectiva + bobbing Zero-G + offset radial + retroceso físico
		var persp_scale: float = 1.0 + depth * _config.perspective_scale_amp
		var bob_y: float = sin(_sim_time * _config.weapon_bob_speed + float(i) * 1.7) * _config.weapon_vertical_bob_px
		var radial_push: Vector2 = aim_vec_2d * (_config.weapon_radial_offset_px * persp_scale)
		var recoil_push: Vector2 = -aim_vec_2d * (recoil * _config.recoil_kick_px * persp_scale)

		root.position = ring_pos + radial_push + recoil_push + Vector2(0.0, bob_y)
		root.z_index = FRONT_WEAPON_Z if depth >= 0.0 else BACK_WEAPON_Z

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
			mat.set_shader_parameter("rim_strength", _config.rim_strength)
			mat.set_shader_parameter("rim_color", _config.ring_color_primary)
			mat.set_shader_parameter("specular_sweep_strength", _config.specular_sweep_strength)
			mat.set_shader_parameter("fire_flash", fire_flash * _config.fire_glow_boost)
			mat.set_shader_parameter("fire_glow_color", _config.ring_color_primary)

		# Calcular posición proyectada de la boca del cañón en espacio local del controlador
		var barrel_len_px: float = 0.0
		if sprite.texture != null:
			var tex_w: float = sprite.texture.get_size().x
			barrel_len_px = (_config.weapon_muzzle_u - _config.weapon_pivot_u) * tex_w * scale_x
		var muzzle_pos: Vector2 = root.position + Vector2.RIGHT.rotated(root.rotation) * barrel_len_px

		slot["theta"] = theta
		slot["depth"] = depth
		slot["barrel_z"] = barrel_z
		slot["aim_dir_2d"] = aim_vec_2d
		slot["muzzle_pos"] = muzzle_pos


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

	var main_pts := PackedVector2Array()
	var inner_pts := PackedVector2Array()
	main_pts.resize(half_steps + 1)
	inner_pts.resize(half_steps + 1)

	for k: int in range(half_steps + 1):
		var t: float = float(k) / float(half_steps)
		var a: float = lerpf(start_a, end_a, t)
		main_pts[k] = _project_ring_point(a, 1.0)
		inner_pts[k] = _project_ring_point(a, _config.ring_secondary_scale)

	# Glow externo suave del riel
	var glow_col := Color(
		_config.ring_color_primary.r * 1.35,
		_config.ring_color_primary.g * 1.35,
		_config.ring_color_primary.b * 1.35,
		_config.ring_color_primary.a * alpha_mult * 0.22
	)
	canvas.draw_polyline(main_pts, glow_col, _config.ring_thickness_px * 3.2, true)

	# Riel principal
	var main_col := Color(
		_config.ring_color_primary.r * 1.15,
		_config.ring_color_primary.g * 1.15,
		_config.ring_color_primary.b * 1.15,
		_config.ring_color_primary.a * alpha_mult
	)
	canvas.draw_polyline(main_pts, main_col, _config.ring_thickness_px, true)

	# Riel secundario interior (doble carril HUD)
	var inner_col := Color(
		_config.ring_color_primary.r,
		_config.ring_color_primary.g,
		_config.ring_color_primary.b,
		_config.ring_color_primary.a * alpha_mult * 0.35
	)
	canvas.draw_polyline(inner_pts, inner_col, maxf(1.0, _config.ring_thickness_px * 0.45), true)

	# Marcas de grado tácticas HUD en perspectiva
	var ticks: int = maxi(8, _config.ring_tick_count)
	var tick_col := Color(
		_config.ring_color_primary.r,
		_config.ring_color_primary.g,
		_config.ring_color_primary.b,
		_config.ring_color_primary.a * alpha_mult * 0.55
	)
	for i: int in range(ticks):
		var a: float = (TAU * float(i)) / float(ticks)
		var s: float = sin(a)
		if (is_front and s < -0.02) or (not is_front and s > 0.02):
			continue
		var is_major: bool = (i % 4 == 0)
		var outer_s: float = 1.045 if is_major else 1.022
		var inner_s: float = 0.955 if is_major else 0.978
		var p0: Vector2 = _project_ring_point(a, inner_s)
		var p1: Vector2 = _project_ring_point(a, outer_s)
		canvas.draw_line(p0, p1, tick_col, 1.8 if is_major else 1.0, true)

	# Anclajes magnéticos luminosos bajo cada arma en esta mitad del anillo
	for slot: Dictionary in _slots:
		var depth: float = float(slot["depth"])
		if (is_front and depth < 0.0) or (not is_front and depth >= 0.0):
			continue
		var theta: float = float(slot["theta"])
		var pulse: float = float(slot["anchor_pulse"])
		var anchor_pos: Vector2 = _project_ring_point(theta, 1.0)
		var persp_s: float = 1.0 + depth * _config.perspective_scale_amp
		var base_r: float = _config.ring_anchor_glow_radius * persp_s * (1.0 + pulse * 0.45)

		var halo_col := Color(
			_config.ring_color_accent.r * 1.4,
			_config.ring_color_accent.g * 1.4,
			_config.ring_color_accent.b * 1.4,
			(0.28 + pulse * 0.42) * alpha_mult
		)
		canvas.draw_circle(anchor_pos, base_r, halo_col)

		var core_col := Color(
			lerpf(_config.ring_color_primary.r, _config.ring_color_accent.r, 0.35 + pulse * 0.65) * 1.45,
			lerpf(_config.ring_color_primary.g, _config.ring_color_accent.g, 0.35 + pulse * 0.65) * 1.45,
			lerpf(_config.ring_color_primary.b, _config.ring_color_accent.b, 0.35 + pulse * 0.65) * 1.45,
			0.92 * alpha_mult
		)
		canvas.draw_circle(anchor_pos, base_r * 0.34, core_col)

		# Arco resaltado sobre el riel alrededor del anclaje
		var arc_pts := PackedVector2Array()
		var span: float = 0.22 + pulse * 0.14
		for j: int in range(9):
			var aa: float = theta + lerpf(-span, span, float(j) / 8.0)
			arc_pts.append(_project_ring_point(aa, 1.0))
		canvas.draw_polyline(arc_pts, core_col, _config.ring_thickness_px * 1.75, true)


func draw_combat_fx(canvas: Node2D) -> void:
	if _config == null:
		return

	# Muzzle flashes HDR en cada slot que disparó recientemente
	for slot: Dictionary in _slots:
		var flash: float = float(slot["fire_flash"])
		if flash <= 0.05:
			continue
		var muzzle: Vector2 = slot["muzzle_pos"] as Vector2
		var dir: Vector2 = slot["aim_dir_2d"] as Vector2
		var perp := Vector2(-dir.y, dir.x)
		var depth: float = float(slot["depth"])
		var s: float = (1.0 + depth * _config.perspective_scale_amp) * flash

		var flare_col := Color(
			_config.ring_color_primary.r * 1.65,
			_config.ring_color_primary.g * 1.65,
			_config.ring_color_primary.b * 1.65,
			clampf(flash * 0.9, 0.0, 1.0)
		)
		var core_col := Color(1.6, 1.7, 1.8, clampf(flash, 0.0, 1.0))

		# Destello en cruz + pico frontal
		canvas.draw_line(muzzle - dir * (10.0 * s), muzzle + dir * (38.0 * s), flare_col, 5.0 * s, true)
		canvas.draw_line(muzzle - perp * (20.0 * s), muzzle + perp * (20.0 * s), flare_col, 3.2 * s, true)
		canvas.draw_circle(muzzle, 8.5 * s, core_col)

	# Trazadores energéticos volando hacia afuera
	for tr: Dictionary in _tracers:
		var pos: Vector2 = tr["pos"] as Vector2
		var dir: Vector2 = tr["dir"] as Vector2
		var life_ratio: float = clampf(float(tr["life"]) / maxf(float(tr["max_life"]), 0.01), 0.0, 1.0)
		var sc: float = float(tr["scale"])
		var tail: Vector2 = pos - dir * (_config.tracer_length_px * sc)

		var outer_col := Color(
			_config.ring_color_primary.r * 1.5,
			_config.ring_color_primary.g * 1.5,
			_config.ring_color_primary.b * 1.5,
			life_ratio * 0.85
		)
		var inner_col := Color(1.65, 1.75, 1.85, life_ratio)
		canvas.draw_line(tail, pos, outer_col, 5.5 * sc, true)
		canvas.draw_line(tail.lerp(pos, 0.35), pos, inner_col, 2.4 * sc, true)
