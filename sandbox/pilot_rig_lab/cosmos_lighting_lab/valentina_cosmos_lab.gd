extends Node2D

## Laboratorio visual de calibración Fase 1:
## Monta CosmosRootNode + CosmosHostController + PlanarCombatRig (Valentina v2) + OrbitalWeaponRingController
## para validar en vivo la estética Anime Space-Opera y la respuesta lumínica (Sol + Bioma + Eclipse).

const CosmosRootScene = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.tscn")
const CosmosHostControllerScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_host_controller.gd")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")
const PlanarRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const RingCtrlScript = preload("res://scenes/pilots/weapons/orbital_weapon_ring_controller.gd")
const OrbitalConfigScript = preload("res://data/pilots/schemas/pilot_orbital_weapon_config.gd")

const PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const STYLE_PATH: String = "res://data/pilots/styles/02_valentina_razor_sharp.tres"
const ORBITAL_CONFIG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_orbital_weapon.tres"
const RING_TEXTURE_PATH: String = "res://assets/pilots/valentina_v2/planar/weapons/valentina_mecha_ring_packed.png"

const BASE_SPEED_PX_S: float = 540.0
const TURBO_SPEED_PX_S: float = 2200.0

var _cosmos_root: CosmosRootNode = null
var _host_controller: CosmosHostControllerScript = null
var _pilot_anchor: Node2D = null
var _camera: Camera2D = null
var _rig: PlanarRigScript = null
var _ring_ctrl: RingCtrlScript = null
var _profile: PilotRigProfile = null
var _orbital_cfg: OrbitalConfigScript = null

var _lighting_sample: CosmicLightingSampleScript = CosmicLightingSampleScript.new()
var _velocity: Vector2 = Vector2.ZERO
var _target_zoom: float = 1.0
var _skin_index: int = 0
var _teleport_mode: int = 0
var _quality_level: int = 2
var _hud_label: Label = null
var _active_wing_aura_color: Color = Color(0.98, 0.16, 0.34, 1.0)
var _active_wing_offset: Vector2 = Vector2(0.0, -20.0)
var _aura_fire_pulse: float = 0.0
var _orbit_guides_enabled: bool = false
var _time_speed_index: int = 0
const TIME_SPEED_STEPS: Array[float] = [1.0, 6.0, 18.0, 0.0]
var _btn_orbit_guides: Button = null
var _btn_time_speed: Button = null
var _btn_non_stellar: Button = null
var _next_sector_archetype_idx: int = 0


func _ready() -> void:
	_build_environment()
	_build_cosmos()
	_build_pilot_and_ring()
	_build_hud()
	_apply_quality_level(2)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.12
	env.glow_intensity = 0.58
	env.glow_bloom = 0.14
	var we := WorldEnvironment.new()
	we.name = "CosmosLabWorldEnvironment"
	we.environment = env
	add_child(we)


func _build_cosmos() -> void:
	_cosmos_root = CosmosRootScene.instantiate() as CosmosRootNode
	_cosmos_root.name = "CosmosRoot"
	add_child(_cosmos_root)

	_host_controller = CosmosHostControllerScript.new()
	_host_controller.name = "CosmosHostController"
	_host_controller.cosmos_root = _cosmos_root
	_host_controller.default_region_id = &"perseus_rift"
	add_child(_host_controller)


func _build_pilot_and_ring() -> void:
	_pilot_anchor = Node2D.new()
	_pilot_anchor.name = "PilotAnchor"
	_pilot_anchor.position = Vector2.ZERO
	add_child(_pilot_anchor)

	_camera = Camera2D.new()
	_camera.name = "LabCamera"
	_camera.enabled = true
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 9.0
	_camera.zoom = Vector2(_target_zoom, _target_zoom)
	_pilot_anchor.add_child(_camera)

	if ResourceLoader.exists(PROFILE_PATH):
		_profile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile
	if ResourceLoader.exists(ORBITAL_CONFIG_PATH):
		_orbital_cfg = ResourceLoader.load(ORBITAL_CONFIG_PATH) as OrbitalConfigScript
	if _orbital_cfg == null:
		_orbital_cfg = OrbitalConfigScript.new()
	_orbital_cfg.ensure_defaults()

	_rig = PlanarRigScript.new()
	_rig.name = "ValentinaCosmosRig"
	_rig.pilot_profile = _profile
	_rig.z_index = 5
	_rig.enable_face_live = true
	_rig.enable_3d_wings = true
	_rig.enable_live_animations = true
	_pilot_anchor.add_child(_rig)

	if ResourceLoader.exists(STYLE_PATH):
		var style_res: RigStyleProfile = ResourceLoader.load(STYLE_PATH) as RigStyleProfile
		if style_res != null:
			_rig.apply_style_profile(style_res)

	_ring_ctrl = RingCtrlScript.new()
	_ring_ctrl.name = "OrbitalWeaponRingController"
	_ring_ctrl.set_config(_orbital_cfg)
	_ring_ctrl.set_weapon_3d_enabled(true)
	_ring_ctrl.set_orbit_mode(RingCtrlScript.OrbitMode.MOUSE_AIM)
	_pilot_anchor.add_child(_ring_ctrl)

	var ring_tex: Texture2D = _load_tex_mipmap(RING_TEXTURE_PATH)
	if ring_tex != null:
		_ring_ctrl.set_ring_texture(ring_tex)

	_apply_skin_index(0)

	_cosmos_root.camera = _camera
	_cosmos_root.player_target = _pilot_anchor
	_cosmos_root.bind_camera_to_streamers()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CosmosLabHUD"
	layer.layer = 50
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 16.0)
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.03, 0.04, 0.08, 0.78)
	style_box.border_width_left = 1
	style_box.border_width_top = 1
	style_box.border_width_right = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.32, 0.78, 0.96, 0.6)
	style_box.set_corner_radius_all(6)
	style_box.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style_box)
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_hud_label = Label.new()
	_hud_label.add_theme_font_size_override("font_size", 13)
	_hud_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
	vbox.add_child(_hud_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_btn_orbit_guides = _create_lab_button("Órbitas 3D: OFF [O]", _toggle_orbit_guides)
	btn_row.add_child(_btn_orbit_guides)

	_btn_time_speed = _create_lab_button("Tiempo: 1x [G]", _cycle_time_speed)
	btn_row.add_child(_btn_time_speed)

	_btn_non_stellar = _create_lab_button("Sector Vivo [N]", _cycle_teleport_non_stellar)
	btn_row.add_child(_btn_non_stellar)
	_sync_control_buttons()


func _create_lab_button(label_text: String, pressed_cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(150.0, 28.0)
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(pressed_cb)
	return btn


func _toggle_orbit_guides() -> void:
	_orbit_guides_enabled = not _orbit_guides_enabled
	if _cosmos_root != null:
		_cosmos_root.set_orbit_guides_visible(_orbit_guides_enabled)
	_sync_control_buttons()


func _cycle_time_speed() -> void:
	_time_speed_index = (_time_speed_index + 1) % TIME_SPEED_STEPS.size()
	if _cosmos_root != null:
		_cosmos_root.time_scale = TIME_SPEED_STEPS[_time_speed_index]
	_sync_control_buttons()


func _sync_control_buttons() -> void:
	if _btn_orbit_guides != null:
		_btn_orbit_guides.text = "Órbitas 3D: ON [O]" if _orbit_guides_enabled else "Órbitas 3D: OFF [O]"
		_btn_orbit_guides.modulate = Color(0.42, 0.95, 1.0, 1.0) if _orbit_guides_enabled else Color(0.86, 0.90, 0.96, 1.0)
	if _btn_time_speed != null:
		var mult: float = TIME_SPEED_STEPS[_time_speed_index]
		if mult <= 0.001:
			_btn_time_speed.text = "Tiempo: PAUSA [G]"
			_btn_time_speed.modulate = Color(1.0, 0.72, 0.42, 1.0)
		else:
			_btn_time_speed.text = "Tiempo: %dx [G]" % int(mult)
			_btn_time_speed.modulate = Color(0.75, 0.98, 0.78, 1.0) if mult > 1.5 else Color(0.86, 0.90, 0.96, 1.0)
	if _btn_non_stellar != null:
		var arch_labels: Array[String] = ["Errante", "Pecio", "Relé", "Vivero"]
		var next_lbl: String = arch_labels[_next_sector_archetype_idx % 4]
		_btn_non_stellar.text = "Sector (%s) [N]" % next_lbl


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			match kev.keycode:
				KEY_B:
					if _cosmos_root != null:
						_cosmos_root.cycle_biome(true)
				KEY_T:
					_cycle_teleport_vantage()
				KEY_N:
					_cycle_teleport_non_stellar()
				KEY_O:
					_toggle_orbit_guides()
				KEY_G:
					_cycle_time_speed()
				KEY_K:
					if _profile != null and not _profile.skins.is_empty():
						_apply_skin_index((_skin_index + 1) % _profile.skins.size())
				KEY_SPACE:
					if _ring_ctrl != null:
						_ring_ctrl.trigger_fire(-1)
						_aura_fire_pulse = 1.0
				KEY_0:
					_apply_quality_level(0)
				KEY_1:
					_apply_quality_level(1)
				KEY_2:
					_apply_quality_level(2)
	elif event is InputEventMouseButton:
		var mev: InputEventMouseButton = event as InputEventMouseButton
		if mev.pressed:
			if mev.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = clampf(_target_zoom * 1.12, 0.16, 2.8)
			elif mev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = clampf(_target_zoom / 1.12, 0.16, 2.8)
			elif mev.button_index == MOUSE_BUTTON_LEFT and _ring_ctrl != null:
				_ring_ctrl.trigger_fire(-1)
				_aura_fire_pulse = 1.0


func _process(delta: float) -> void:
	_step_flight(delta)
	_step_rig_and_lighting(delta)
	_update_hud_text()


func _step_flight(delta: float) -> void:
	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_vec.length_squared() < 0.001:
		var raw_x: float = (1.0 if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) else 0.0)
		var raw_y: float = (1.0 if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) else 0.0)
		input_vec = Vector2(raw_x, raw_y)

	if input_vec.length_squared() > 1.0:
		input_vec = input_vec.normalized()

	var is_turbo: bool = Input.is_key_pressed(KEY_SHIFT)
	var max_spd: float = TURBO_SPEED_PX_S if is_turbo else BASE_SPEED_PX_S
	_velocity = _velocity.move_toward(input_vec * max_spd, max_spd * 6.0 * delta)
	if _pilot_anchor != null:
		_pilot_anchor.position += _velocity * delta

	if _camera != null:
		var next_z: float = lerpf(_camera.zoom.x, _target_zoom, clampf(delta * 10.0, 0.0, 1.0))
		_camera.zoom = Vector2(next_z, next_z)
		if _rig != null:
			_rig.set_zoom_scale(next_z)


func _step_rig_and_lighting(delta: float) -> void:
	if _pilot_anchor == null:
		return
	var mouse_local: Vector2 = _pilot_anchor.get_local_mouse_position()
	var aim_dir: Vector2 = mouse_local.normalized() if mouse_local.length_squared() > 4.0 else Vector2.DOWN
	var spd: float = _velocity.length()
	var move_dir: Vector2 = (_velocity / spd) if spd > 5.0 else aim_dir
	var speed_norm: float = clampf(spd / BASE_SPEED_PX_S, 0.0, 1.35)
	var is_turbo: bool = Input.is_key_pressed(KEY_SHIFT) and spd > 20.0

	if _rig != null:
		_rig.set_turbo_active(is_turbo)
		_rig.set_locomotion_state(move_dir, speed_norm, aim_dir, false)

	if _ring_ctrl != null:
		_ring_ctrl.set_mouse_target_local(_ring_ctrl.get_local_mouse_position())
		_ring_ctrl.step(delta)

	_aura_fire_pulse = move_toward(_aura_fire_pulse, 0.0, delta * 3.8)
	if _cosmos_root != null:
		var aura_energy: float = 0.96 + (0.38 if is_turbo else 0.0) + _aura_fire_pulse * 0.44
		var tilt_x: float = clampf(_velocity.x / BASE_SPEED_PX_S, -1.0, 1.0) * 0.24
		var wing_axis := Vector2(1.0, tilt_x).normalized()
		_cosmos_root.set_player_aura_light(_active_wing_aura_color, _active_wing_offset, 225.0, aura_energy, wing_axis)

	if _host_controller != null:
		_host_controller.sample_lighting_at(_pilot_anchor.global_position, _lighting_sample)
		if _rig != null:
			_rig.apply_cosmic_lighting(_lighting_sample, delta, _host_controller.rig_lighting_config)
		if _ring_ctrl != null:
			var eff_sample: CosmicLightingSample = _rig.get_last_cosmic_lighting() if _rig != null else _lighting_sample
			_ring_ctrl.apply_cosmic_lighting(eff_sample)


func _cycle_teleport_vantage() -> void:
	if _host_controller == null or _pilot_anchor == null:
		return
	var active: Dictionary = _host_controller.get_active_solar_systems()
	var best_sys: CosmosSolarSystem2D = null
	var best_dist: float = INF
	for sys_v: Variant in active.values():
		var sys: CosmosSolarSystem2D = sys_v as CosmosSolarSystem2D
		if sys == null or not is_instance_valid(sys) or not sys.visible or sys.star_body == null:
			continue
		var d: float = _pilot_anchor.global_position.distance_to(sys.global_position)
		if d < best_dist:
			best_dist = d
			best_sys = sys

	if best_sys == null:
		return

	var star_world: Vector2 = best_sys.star_body.global_position
	var mode: int = _teleport_mode % 3
	_teleport_mode += 1

	if mode == 0 or best_sys.planets.is_empty():
		_pilot_anchor.global_position = star_world + Vector2(680.0, 220.0)
	else:
		var planet: CosmosOrbitalBody2D = best_sys.planets[0]
		var p_rad: float = float(planet.get_meta(&"visual_radius", 130.0))
		var p_dir: Vector2 = planet.position.normalized() if planet.position.length_squared() > 1.0 else Vector2.RIGHT
		if mode == 1:
			_pilot_anchor.global_position = star_world + planet.position + p_dir * (p_rad + 140.0)
		else:
			_pilot_anchor.global_position = star_world + planet.position - p_dir * (p_rad + 160.0)
	_velocity = Vector2.ZERO
	if _rig != null and _rig.get_3d_wings_controller() != null:
		_rig.get_3d_wings_controller().step(0.0, true)


func _cycle_teleport_non_stellar() -> void:
	if _cosmos_root == null or _cosmos_root.non_stellar_streamer == null or _pilot_anchor == null:
		return
	var streamer: CosmosNonStellarStreamer2D = _cosmos_root.non_stellar_streamer
	var target_arch: int = _next_sector_archetype_idx % 4
	_next_sector_archetype_idx += 1
	var found_info: Dictionary = streamer.find_nearby_sector_cell(_pilot_anchor.global_position, target_arch, 6)
	if not bool(found_info.get("found", false)):
		found_info = streamer.find_nearby_sector_cell(Vector2.ZERO, target_arch, 8)
	if bool(found_info.get("found", false)):
		var sec_pos: Vector2 = found_info["position"] as Vector2
		_pilot_anchor.global_position = sec_pos + Vector2(-420.0, 140.0)
		_velocity = Vector2.ZERO
		if _rig != null and _rig.get_3d_wings_controller() != null:
			_rig.get_3d_wings_controller().step(0.0, true)
	_sync_control_buttons()


func _apply_skin_index(idx: int) -> void:
	if _profile == null or _profile.skins.is_empty():
		return
	_skin_index = clampi(idx, 0, _profile.skins.size() - 1)
	var skin: PilotSkinPreset = _profile.skins[_skin_index]
	if _rig != null:
		_rig.apply_skin_preset(skin)
	if _ring_ctrl != null:
		_ring_ctrl.apply_skin_preset(skin)

	var raw_col: Color = _profile.default_accent_color
	if skin.is_base_skin:
		if _profile.wings_3d_config != null:
			raw_col = _profile.wings_3d_config.fire_glow_color
	else:
		raw_col = skin.accent_color
	_active_wing_aura_color = Color(clampf(raw_col.r * 1.08, 0.0, 1.0), clampf(raw_col.g * 1.08, 0.0, 1.0), clampf(raw_col.b * 1.08, 0.0, 1.0), 1.0)
	if _profile.wings_3d_config != null:
		_active_wing_offset = _profile.wings_3d_config.anchor_offset_px
	if _cosmos_root != null:
		_cosmos_root.set_player_aura_light(_active_wing_aura_color, _active_wing_offset, 225.0, 1.0, Vector2.RIGHT)


func _apply_quality_level(q: int) -> void:
	_quality_level = clampi(q, 0, 2)
	var sm: Node = get_node_or_null("/root/SettingsManager")
	if sm != null and "space_background_quality" in sm:
		sm.space_background_quality = _quality_level
	if _cosmos_root != null:
		_cosmos_root.apply_graphics_quality(_quality_level)


func _update_hud_text() -> void:
	if _hud_label == null:
		return
	var biome_name: String = "N/A"
	if _cosmos_root != null and _cosmos_root.nebula_controller != null and _cosmos_root.nebula_controller.biome_a != null:
		biome_name = _cosmos_root.nebula_controller.biome_a.display_name
	var skin_name: String = _profile.skins[_skin_index].id if (_profile != null and _skin_index < _profile.skins.size()) else "base"
	var eff: CosmicLightingSample = _rig.get_last_cosmic_lighting() if (_rig != null and _rig.get_last_cosmic_lighting() != null) else _lighting_sample
	var star_txt: String = "%s (%.0f px)" % [String(eff.dominant_star_name), eff.dominant_star_distance] if eff.has_active_star else "Espacio Profundo"
	if _cosmos_root != null and _cosmos_root.non_stellar_streamer != null and _pilot_anchor != null:
		var best_sec: CosmosDeepSpaceSector2D = null
		var best_sec_d: float = 2800.0
		for sec_v: Variant in _cosmos_root.non_stellar_streamer.get_active_sectors().values():
			var sec: CosmosDeepSpaceSector2D = sec_v as CosmosDeepSpaceSector2D
			if sec != null and is_instance_valid(sec) and sec.visible:
				var d_sec: float = _pilot_anchor.global_position.distance_to(sec.global_position)
				if d_sec < best_sec_d:
					best_sec_d = d_sec
					best_sec = sec
		if best_sec != null:
			var sec_info: String = "%s [%s] (%.0f px)" % [best_sec.get_archetype_label(), best_sec.sector_name, best_sec_d]
			star_txt = sec_info if not eff.has_active_star else "%s | %s" % [star_txt, sec_info]
	if _cosmos_root != null and _cosmos_root.corridor_controller != null:
		star_txt += " | Rutas: %d | BowShocks: %d" % [_cosmos_root.corridor_controller.get_active_lane_count(), _cosmos_root.corridor_controller.get_active_bow_shock_count()]
	var boost_val: Variant = _rig.get_shader_param("key_light_boost", 1.0) if _rig != null else 1.0

	var guide_legend: String = ""
	if _orbit_guides_enabled:
		guide_legend = "\nAnillos: Celeste=Planetas | Ámbar=Destructible/BowShock | Lavanda=Lunas | Cian=Estaciones/Rutas | Menta=Cometas | Rojo=Sol"

	_hud_label.text = (
		"VALENTINA v2 — COSMOS LIGHTING LAB (Fase 1)\n"
		+ "Bioma: %s | Calidad: %d | Skin: %s\n" % [biome_name, _quality_level, skin_name]
		+ "Sol / Sector: %s | Prox: %.2f\n" % [star_txt, eff.star_proximity]
		+ "Dir Luz 2D: (%.2f, %.2f) | Eclipse: %.2f | Boost: %.2f | Emissive×: %.2f\n" % [
			eff.light_dir_2d.x, eff.light_dir_2d.y, eff.eclipse_factor, float(boost_val), eff.emissive_boost_mult
		]
		+ "[WASD+Shift] Volar | [Mouse] Apuntar | [Click/Espacio] Disparar | [O] Órbitas 3D | [G] Vel. Tiempo\n"
		+ "[B] Bioma | [T] Sol / Eclipse / Día | [N] Sector Vivo | [K] Skin | [0/1/2] Calidad | [Rueda] Zoom"
		+ guide_legend
	)


func _load_tex_mipmap(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var loaded: Texture2D = ResourceLoader.load(res_path) as Texture2D
		if loaded != null:
			return loaded
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		return null
	var img := Image.new()
	if img.load(abs_path) != OK:
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
