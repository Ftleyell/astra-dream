extends Node2D
## Arena de pruebas interactiva para el Pilot Rig Planar 8-Dir + Cabeza Desacoplada.
## Controles:
##   - WASD / Flechas: mover cuerpo en 8 direcciones (S/N + Flip-H)
##   - Ratón (o Demo Auto): apuntar cabeza independientemente de la dirección de vuelo
##   - Shift: turbo + fantasma Sandevistan

const PlanarRigScript = preload("res://sandbox/pilot_rig_lab/proto/planar_combat_rig.gd")
const HudBuilder = preload("res://sandbox/pilot_rig_lab/proto/planar_lab_hud_builder.gd")

var _rig: PlanarCombatRig = null
var _camera: Camera2D = null
var _reticle: Node2D = null
var _aim_line: Line2D = null
var _hud_refs: Dictionary = {}

var _bg_rect: ColorRect = null
var _nebula_sprite: Sprite2D = null
var _world_env: WorldEnvironment = null
var _grid_lines: Array[Line2D] = []
var _orbit_enemy: Sprite2D = null
var _orbit_enemy_enabled: bool = false
var _orbit_angle: float = 0.0
var _target_zoom: float = 2.0

var _auto_demo: bool = true
var _demo_time: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _aim_world: Vector2 = Vector2(180.0, -40.0)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _ready() -> void:
	_build_world_environment()
	_build_backdrop()

	_camera = Camera2D.new()
	_camera.zoom = Vector2(2.0, 2.0)
	add_child(_camera)

	_aim_line = Line2D.new()
	_aim_line.width = 1.6
	_aim_line.default_color = Color(1.0, 0.28, 0.42, 0.55)
	add_child(_aim_line)

	_reticle = _build_reticle()
	add_child(_reticle)

	_rig = PlanarRigScript.new()
	_rig.name = "PilotPlanarRig"
	add_child(_rig)

	_build_orbit_enemy()
	_hud_refs = HudBuilder.build_hud(self, _rig, {
		"sync_lighting": Callable(self, "_sync_lighting_uniforms"),
		"on_auto_demo": func(v: bool) -> void: _auto_demo = v,
		"on_zoom": func(idx: int) -> void:
			var z_vals: Array[float] = [2.0, 1.15, 0.65]
			var z: float = z_vals[clampi(idx, 0, z_vals.size() - 1)]
			_target_zoom = z
			_camera.zoom = Vector2(z, z),
		"on_white_bg": Callable(self, "_set_white_background"),
		"on_space_nebula": Callable(self, "_set_space_nebula_background"),
		"on_orbit_enemy": func(v: bool) -> void:
			_orbit_enemy_enabled = v
			if _orbit_enemy != null:
				_orbit_enemy.visible = v,
		"on_static_apply": Callable(self, "_apply_static_inspection_from_ui"),
		"on_static_step": Callable(self, "_step_static_combo"),
		"on_air_brake_test": Callable(self, "_trigger_air_brake_test"),
	})
	_apply_initial_defaults()


func _trigger_air_brake_test() -> void:
	if _rig == null:
		return
	var cur_dir: Vector2 = _velocity.normalized() if _velocity.length() > 10.0 else Vector2.RIGHT
	_velocity = -cur_dir * 260.0
	_rig.set_locomotion_state(-cur_dir, 1.15, (_aim_world - _rig.global_position).normalized())


func _build_world_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.05
	env.glow_intensity = 0.65
	env.glow_bloom = 0.25
	_world_env = WorldEnvironment.new()
	_world_env.name = "LabWorldEnvironment"
	_world_env.environment = env
	add_child(_world_env)


func _build_backdrop() -> void:
	_bg_rect = ColorRect.new()
	_bg_rect.color = Color(0.055, 0.062, 0.095, 1.0)
	_bg_rect.size = Vector2(3600.0, 3600.0)
	_bg_rect.position = Vector2(-1800.0, -1800.0)
	_bg_rect.z_index = -50
	add_child(_bg_rect)

	var neb_grad := Gradient.new()
	neb_grad.offsets = PackedFloat32Array([0.0, 0.42, 0.78, 1.0])
	neb_grad.colors = PackedColorArray([
		Color(0.24, 0.09, 0.34, 0.55),
		Color(0.08, 0.16, 0.36, 0.38),
		Color(0.03, 0.05, 0.14, 0.18),
		Color(0.01, 0.015, 0.04, 0.0),
	])
	var neb_tex := GradientTexture2D.new()
	neb_tex.width = 512
	neb_tex.height = 512
	neb_tex.gradient = neb_grad
	neb_tex.fill = GradientTexture2D.FILL_RADIAL
	neb_tex.fill_from = Vector2(0.5, 0.5)
	neb_tex.fill_to = Vector2(0.95, 0.15)
	_nebula_sprite = Sprite2D.new()
	_nebula_sprite.name = "SpaceNebulaBackdrop"
	_nebula_sprite.texture = neb_tex
	_nebula_sprite.scale = Vector2(5.5, 5.5)
	_nebula_sprite.z_index = -45
	_nebula_sprite.visible = false
	add_child(_nebula_sprite)

	for gx: int in range(-9, 10):
		var line_v := Line2D.new()
		line_v.points = PackedVector2Array([Vector2(gx * 160.0, -1440.0), Vector2(gx * 160.0, 1440.0)])
		line_v.width = 1.0
		line_v.default_color = Color(0.18, 0.24, 0.36, 0.28)
		line_v.z_index = -40
		add_child(line_v)
		_grid_lines.append(line_v)
	for gy: int in range(-9, 10):
		var line_h := Line2D.new()
		line_h.points = PackedVector2Array([Vector2(-1440.0, gy * 160.0), Vector2(1440.0, gy * 160.0)])
		line_h.width = 1.0
		line_h.default_color = Color(0.18, 0.24, 0.36, 0.28)
		line_h.z_index = -40
		add_child(line_h)
		_grid_lines.append(line_h)


func _set_white_background(enabled: bool) -> void:
	if _bg_rect != null:
		_bg_rect.color = Color(0.97, 0.97, 0.98, 1.0) if enabled else Color(0.055, 0.062, 0.095, 1.0)
	if _nebula_sprite != null and enabled:
		_nebula_sprite.visible = false
	var grid_col := Color(0.78, 0.80, 0.85, 0.40) if enabled else Color(0.18, 0.24, 0.36, 0.28)
	for line: Line2D in _grid_lines:
		if line != null:
			line.default_color = grid_col


func _set_space_nebula_background(enabled: bool) -> void:
	if _bg_rect != null:
		_bg_rect.color = Color(0.014, 0.016, 0.036, 1.0) if enabled else Color(0.055, 0.062, 0.095, 1.0)
	if _nebula_sprite != null:
		_nebula_sprite.visible = enabled
	var grid_col := Color(0.22, 0.30, 0.48, 0.14) if enabled else Color(0.18, 0.24, 0.36, 0.28)
	for line: Line2D in _grid_lines:
		if line != null:
			line.default_color = grid_col


func _build_orbit_enemy() -> void:
	var tex: Texture2D = load("res://assets/sprites/enemies/enemy_drone.png") as Texture2D
	if tex == null:
		return
	_orbit_enemy = Sprite2D.new()
	_orbit_enemy.name = "OrbitingBaseEnemy"
	_orbit_enemy.texture = tex
	_orbit_enemy.scale = Vector2(0.045, 0.045)
	_orbit_enemy.z_index = 12
	_orbit_enemy.visible = false
	add_child(_orbit_enemy)


func _build_reticle() -> Node2D:
	var n := Node2D.new()
	n.z_index = 25
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i: int in range(25):
		var a: float = float(i) / 24.0 * TAU
		pts.append(Vector2(cos(a), sin(a)) * 14.0)
	ring.points = pts
	ring.width = 2.0
	ring.default_color = Color(1.0, 0.22, 0.38, 0.92)
	n.add_child(ring)
	return n


func _apply_static_inspection_from_ui() -> void:
	var static_chk: CheckBox = _hud_refs.get("static_inspect_chk", null) as CheckBox
	var body_opt: OptionButton = _hud_refs.get("static_body_opt", null) as OptionButton
	var head_opt: OptionButton = _hud_refs.get("static_head_opt", null) as OptionButton
	var combo_lbl: Label = _hud_refs.get("static_combo_lbl", null) as Label
	var auto_chk: CheckBox = _hud_refs.get("auto_demo_chk", null) as CheckBox
	if _rig == null or static_chk == null:
		return
	var enabled: bool = static_chk.button_pressed
	var view_keys: Array[String] = _rig.get_available_view_keys()
	if view_keys.is_empty():
		view_keys.assign(HudBuilder.BODY_KEYS)
	var b_idx: int = clampi(body_opt.selected, 0, view_keys.size() - 1)
	var h_idx: int = clampi(head_opt.selected, 0, HudBuilder.HEAD_KEYS.size() - 1)
	var b_key: String = view_keys[b_idx]
	var h_key: String = HudBuilder.HEAD_KEYS[h_idx]
	if enabled:
		_auto_demo = false
		if auto_chk != null:
			auto_chk.button_pressed = false
		_velocity = Vector2.ZERO
		_rig.set_static_inspection(true, b_key, h_key)
		var combo_num: int = b_idx * HudBuilder.HEAD_KEYS.size() + h_idx + 1
		var total: int = view_keys.size() * HudBuilder.HEAD_KEYS.size()
		var shown_head: String = _rig.get_active_head_key()
		if shown_head != h_key:
			combo_lbl.text = "Combo %d/%d: %s + %s (bloqueado -> %s)" % [combo_num, total, b_key.to_upper(), h_key, shown_head]
		else:
			combo_lbl.text = "Combo %d/%d: %s + %s" % [combo_num, total, b_key.to_upper(), h_key]
	else:
		_rig.set_static_inspection(false)
		combo_lbl.text = "Combo: (Modo Dinámico)"
	if _aim_line != null:
		_aim_line.visible = not enabled
	if _reticle != null:
		_reticle.visible = not enabled


func _step_static_combo(dir: int) -> void:
	var static_chk: CheckBox = _hud_refs.get("static_inspect_chk", null) as CheckBox
	var body_opt: OptionButton = _hud_refs.get("static_body_opt", null) as OptionButton
	var head_opt: OptionButton = _hud_refs.get("static_head_opt", null) as OptionButton
	var view_keys: Array[String] = _rig.get_available_view_keys()
	if view_keys.is_empty():
		view_keys.assign(HudBuilder.BODY_KEYS)
	var total: int = view_keys.size() * HudBuilder.HEAD_KEYS.size()
	var b_idx: int = clampi(body_opt.selected, 0, view_keys.size() - 1)
	var h_idx: int = clampi(head_opt.selected, 0, HudBuilder.HEAD_KEYS.size() - 1)
	var cur: int = b_idx * HudBuilder.HEAD_KEYS.size() + h_idx
	if static_chk != null and static_chk.button_pressed:
		cur = posmod(cur + dir, total)
	body_opt.selected = cur / HudBuilder.HEAD_KEYS.size()
	head_opt.selected = cur % HudBuilder.HEAD_KEYS.size()
	if static_chk != null:
		static_chk.button_pressed = true
	_apply_static_inspection_from_ui()


func _apply_initial_defaults() -> void:
	_rig.set_transition_style(PlanarCombatRig.TransitionStyle.WHIP_SNAP_AFTERIMAGE)
	var pilot_opt: OptionButton = _hud_refs.get("pilot_opt", null) as OptionButton
	var profiles: Array = _hud_refs.get("pilot_profiles", []) as Array
	var preferred_idx: int = -1
	for i: int in range(profiles.size()):
		var p: PilotRigProfile = profiles[i] as PilotRigProfile
		if p != null and p.pilot_id == "valentina_v2":
			preferred_idx = i
			break
	if preferred_idx >= 0 and pilot_opt != null:
		pilot_opt.select(preferred_idx)
		pilot_opt.item_selected.emit(preferred_idx)
	else:
		var prof: PilotRigProfile = _hud_refs.get("active_profile", null) as PilotRigProfile
		if prof != null:
			if not prof.style_profiles.is_empty():
				_rig.apply_style_profile(prof.style_profiles[0])
			if not prof.skins.is_empty():
				_rig.apply_skin_preset(prof.skins[0])
	_rig.enable_afterimage = false
	_sync_lighting_uniforms()


func _sync_lighting_uniforms() -> void:
	var normal_chk: CheckBox = _hud_refs.get("normal_chk", null) as CheckBox
	var light_slider: HSlider = _hud_refs.get("light_slider", null) as HSlider
	var hdr_slider: HSlider = _hud_refs.get("hdr_slider", null) as HSlider
	if _rig == null or normal_chk == null or light_slider == null or hdr_slider == null:
		return
	var ang: float = deg_to_rad(light_slider.value)
	var l_dir := Vector2(cos(ang), sin(ang))
	var rim_s: float = 0.90 if normal_chk.button_pressed else 0.0
	_rig.set_normal_depth_options(normal_chk.button_pressed, l_dir, rim_s, hdr_slider.value)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = clampf(_target_zoom * 1.15, 0.40, 8.0)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = clampf(_target_zoom / 1.15, 0.40, 8.0)
			elif mb.button_index == MOUSE_BUTTON_LEFT and _rig != null and not _rig.is_static_inspection():
				_rig.trigger_attack_recoil((_aim_world - _rig.global_position).normalized())
	elif event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo and _rig != null and not _rig.is_static_inspection():
			if ke.keycode == KEY_SPACE:
				_rig.trigger_dash_burst()
			elif ke.keycode == KEY_J:
				_rig.trigger_attack_recoil((_aim_world - _rig.global_position).normalized())
			elif ke.keycode == KEY_K:
				_rig.trigger_hit_react()
			elif ke.keycode == KEY_B:
				_trigger_air_brake_test()


func _process(delta: float) -> void:
	var status_lbl: Label = _hud_refs.get("status_lbl", null) as Label
	var static_chk: CheckBox = _hud_refs.get("static_inspect_chk", null) as CheckBox
	var auto_chk: CheckBox = _hud_refs.get("auto_demo_chk", null) as CheckBox
	var flash_hold_chk: CheckBox = _hud_refs.get("flash_hold_chk", null) as CheckBox
	if flash_hold_chk != null and flash_hold_chk.button_pressed:
		_rig.set_hit_flash(1.0)

	var input_vec := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if Input.is_key_pressed(KEY_D):
		input_vec.x += 1.0
	if Input.is_key_pressed(KEY_A):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vec.y += 1.0
	if Input.is_key_pressed(KEY_W):
		input_vec.y -= 1.0

	if input_vec.length_squared() > 0.01:
		_auto_demo = false
		if auto_chk != null:
			auto_chk.button_pressed = false

	if static_chk != null and static_chk.button_pressed:
		_camera.global_position = _camera.global_position.lerp(_rig.global_position, minf(1.0, delta * 8.0))
		var cur_z_s: float = lerpf(_camera.zoom.x, _target_zoom, minf(1.0, delta * 14.0))
		_camera.zoom = Vector2(cur_z_s, cur_z_s)
		_rig.set_zoom_scale(cur_z_s)
		if status_lbl != null:
			status_lbl.text = _rig.get_active_view_summary()
		return

	if _auto_demo:
		_demo_time += delta
		var aim_dir := Vector2(cos(_demo_time * 0.95), sin(_demo_time * 0.95))
		var demo_dirs: Array[Vector2] = [
			Vector2.RIGHT,
			Vector2(1.0, 1.0).normalized(),
			Vector2.DOWN,
			Vector2(-1.0, 1.0).normalized(),
			Vector2.LEFT,
			Vector2(-1.0, -1.0).normalized(),
			Vector2.UP,
			Vector2(1.0, -1.0).normalized(),
		]
		var step_dur: float = 2.4
		var total_dur: float = step_dur * float(demo_dirs.size())
		var cycle_t: float = fmod(_demo_time, total_dur)
		var dir_idx: int = int(cycle_t / step_dur) % demo_dirs.size()
		var local_t: float = fmod(cycle_t, step_dur)
		var target_vel: Vector2 = demo_dirs[dir_idx] * 220.0 if local_t < 1.85 else Vector2.ZERO
		_velocity = _velocity.lerp(target_vel, 1.0 - exp(-18.0 * delta))
		_rig.position += _velocity * delta
		_aim_world = _rig.global_position + aim_dir * 180.0
		var demo_mv_dir: Vector2 = target_vel.normalized() if target_vel.length() > 10.0 else (_velocity.normalized() if _velocity.length() > 10.0 else Vector2.DOWN)
		var demo_spd_n: float = clampf(target_vel.length() / 220.0, 0.0, 1.4)
		_rig.set_locomotion_state(demo_mv_dir, demo_spd_n, aim_dir)
	else:
		var spd: float = 360.0 if Input.is_key_pressed(KEY_SHIFT) else 220.0
		var has_input: bool = input_vec.length_squared() > 0.01
		var target_v: Vector2 = input_vec.normalized() * spd if has_input else Vector2.ZERO
		var vel_rate: float = 22.0 if has_input else 15.0
		_velocity = _velocity.lerp(target_v, 1.0 - exp(-vel_rate * delta))
		_rig.position += _velocity * delta
		_aim_world = get_global_mouse_position()
		var mv_dir: Vector2 = input_vec.normalized() if has_input else (_velocity.normalized() if _velocity.length() > 10.0 else Vector2.DOWN)
		var spd_n: float = clampf(target_v.length() / 220.0, 0.0, 1.4)
		_rig.set_locomotion_state(mv_dir, spd_n, (_aim_world - _rig.global_position).normalized())

	_camera.global_position = _camera.global_position.lerp(_rig.global_position, 1.0 - exp(-10.0 * delta))
	var cur_z: float = lerpf(_camera.zoom.x, _target_zoom, 1.0 - exp(-14.0 * delta))
	_camera.zoom = Vector2(cur_z, cur_z)
	_rig.set_zoom_scale(cur_z)
	_reticle.global_position = _aim_world
	_aim_line.points = PackedVector2Array([_rig.global_position + Vector2(0.0, -28.0), _aim_world])
	if status_lbl != null:
		var add_fx: String = _rig.get_active_additive_summary()
		status_lbl.text = "%s | %s" % [_rig.get_active_view_summary(), add_fx] if add_fx != "NONE" else _rig.get_active_view_summary()

	if _orbit_enemy_enabled and _orbit_enemy != null:
		_orbit_angle += delta * 1.45
		_orbit_enemy.global_position = _rig.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * 115.0
		_orbit_enemy.rotation = (_rig.global_position - _orbit_enemy.global_position).angle() + PI * 0.5
