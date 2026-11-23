extends Node2D
## Laboratorio aislado de Armamento Orbital 2.5D (Guns Lab — Valentina v2).
## Prueba un anillo orbital 3D inclinado alrededor de Valentina v2 con Z-sorting real,
## perspectiva trapezoidal, escorzo, extrusión 2.5D, recoil y 1..4 slots simultáneos.

const PlanarRigScript = preload("res://sandbox/pilot_rig_lab/proto/planar_combat_rig.gd")
const BackdropScript = preload("res://sandbox/pilot_rig_lab/shader_lab/shader_lab_backdrop.gd")
const RingCtrlScript = preload("res://sandbox/pilot_rig_lab/guns_lab/orbital_weapon_ring_controller.gd")
const ConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_orbital_weapon_config.gd")
const HUDScript = preload("res://sandbox/pilot_rig_lab/guns_lab/valentina_guns_lab_hud.gd")

const PROFILE_PATH: String = "res://sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_profile.tres"
const CONFIG_PATH: String = "res://sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_orbital_weapon.tres"
const STYLES_DIR: String = "res://sandbox/pilot_rig_lab/data/styles"
const RING_TEXTURE_PATH: String = "res://sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/weapons/valentina_mecha_ring_packed.png"

const WEAPON_CATALOG: Array[Dictionary] = [
	{
		"label": "Valentina v2 — Rail-Lance 3D Cel-Shaded (360° Real)",
		"mode": "3d_rail_lance",
	},
	{
		"label": "Valentina v2 — Rail-Lance 2.5D (Multi-Mapa)",
		"path": "res://sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/weapons/valentina_rail_lance.png",
		"id_mask": "res://sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/weapons/valentina_rail_lance_id_mask.png",
		"ilm_mask": "res://sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/weapons/valentina_rail_lance_ilm_mask.png",
		"ink_sdf": "res://sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/weapons/valentina_rail_lance_ink_sdf.png",
	},
	{"label": "Legacy — Valentina Railgun (HD)", "path": "res://assets/characters/weapons/weapon_valentina_hd.png"},
	{"label": "Echo — Rifle (HD)", "path": "res://assets/characters/weapons/weapon_echo_hd.png"},
	{"label": "Kira — Rifle (HD)", "path": "res://assets/characters/weapons/weapon_kira_hd.png"},
	{"label": "Nova — Cañón (HD)", "path": "res://assets/characters/weapons/weapon_nova_hd.png"},
	{"label": "Nyx — Arma (HD)", "path": "res://assets/characters/weapons/weapon_nyx_hd.png"},
	{"label": "Roxy — Arma (HD)", "path": "res://assets/characters/weapons/weapon_roxy_hd.png"},
	{"label": "Selene — Arma (HD)", "path": "res://assets/characters/weapons/weapon_selene_hd.png"},
]

const VIEW_DIR_MAP: Dictionary = {
	"s": Vector2(0.0, 1.0),
	"se": Vector2(0.7071, 0.7071),
	"e": Vector2(1.0, 0.0),
	"ne": Vector2(0.7071, -0.7071),
	"n": Vector2(0.0, -1.0),
	"nw": Vector2(-0.7071, -0.7071),
	"w": Vector2(-1.0, 0.0),
	"sw": Vector2(-0.7071, 0.7071),
}

var _profile: PilotRigProfile = null
var _config: ConfigScript = null
var _backdrop: BackdropScript = null
var _camera: Camera2D = null
var _rig: PlanarCombatRig = null
var _ring_ctrl: RingCtrlScript = null
var _hud_refs: Dictionary = {}

var _target_zoom: float = 1.45
var _current_view_key: String = "s"
var _idle_enabled: bool = false
var _wings_enabled: bool = false
var _orbit_paused: bool = false


func _ready() -> void:
	_load_resources()
	_build_environment()
	_build_scene_nodes()
	_configure_rig_defaults()
	var ring_tex: Texture2D = _load_tex(RING_TEXTURE_PATH, true)
	if ring_tex != null and _ring_ctrl != null:
		_ring_ctrl.set_ring_texture(ring_tex)
	_load_weapon_index(0)

	var skin_choices: Array[PilotSkinPreset] = []
	if _profile != null:
		skin_choices = _profile.skins

	_hud_refs = HUDScript.build_hud(self, _config, WEAPON_CATALOG, {
		"on_mode_selected": Callable(self, "_on_mode_selected"),
		"on_weapon_selected": Callable(self, "_load_weapon_index"),
		"on_weapon_count_selected": Callable(self, "_on_weapon_count_selected"),
		"on_trigger_fire": Callable(self, "trigger_fire"),
		"on_orbit_pause_toggled": Callable(self, "_on_orbit_pause_toggled"),
		"on_auto_fire_toggled": Callable(self, "_on_auto_fire_toggled"),
		"on_show_ring_toggled": Callable(self, "_on_show_ring_toggled"),
		"on_ring_follow_skin_toggled": Callable(self, "_on_ring_follow_skin_toggled"),
		"on_ring_use_texture_toggled": Callable(self, "_on_ring_use_texture_toggled"),
		"on_view_selected": Callable(self, "_on_view_selected"),
		"on_skin_selected": Callable(self, "_on_skin_selected"),
		"on_wings_toggled": Callable(self, "_on_wings_toggled"),
		"on_idle_toggled": Callable(self, "_on_idle_toggled"),
		"on_save_config": Callable(self, "_on_save_config"),
		"on_reload_config": Callable(self, "_on_reload_config"),
	}, skin_choices)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_SPACE:
				trigger_fire()
			elif kev.keycode == KEY_P:
				_orbit_paused = not _orbit_paused
				if _ring_ctrl != null:
					_ring_ctrl.set_orbit_paused(_orbit_paused)
				var pbtn: Button = _hud_refs.get("pause_btn", null) as Button
				if is_instance_valid(pbtn):
					pbtn.set_pressed_no_signal(_orbit_paused)
					pbtn.text = "Reanudar" if _orbit_paused else "Pausar Órbita"
	elif event is InputEventMouseButton:
		var mev: InputEventMouseButton = event as InputEventMouseButton
		if mev.pressed:
			if mev.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = clampf(_target_zoom * 1.12, 0.55, 3.0)
			elif mev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = clampf(_target_zoom / 1.12, 0.55, 3.0)
			elif mev.button_index == MOUSE_BUTTON_LEFT:
				trigger_fire()


func _process(delta: float) -> void:
	if _camera != null:
		var cur_z: float = _camera.zoom.x
		var next_z: float = lerpf(cur_z, _target_zoom, clampf(delta * 10.0, 0.0, 1.0))
		_camera.zoom = Vector2(next_z, next_z)
		if _rig != null:
			_rig.set_zoom_scale(next_z)

	if _ring_ctrl != null:
		_ring_ctrl.set_mouse_target_local(_ring_ctrl.get_local_mouse_position())
		_ring_ctrl.step(delta)
		_update_telemetry()


func trigger_fire() -> void:
	if _ring_ctrl != null:
		_ring_ctrl.trigger_fire(-1)


func get_rig() -> PlanarCombatRig:
	return _rig


func get_ring_controller() -> RingCtrlScript:
	return _ring_ctrl


func get_config() -> ConfigScript:
	return _config


func _load_resources() -> void:
	if ResourceLoader.exists(PROFILE_PATH):
		_profile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile
	if ResourceLoader.exists(CONFIG_PATH):
		_config = ResourceLoader.load(CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ConfigScript
	if _config == null:
		_config = ConfigScript.new()
	_config.ensure_defaults()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.12
	env.glow_intensity = 0.58
	env.glow_bloom = 0.12
	var we := WorldEnvironment.new()
	we.name = "GunsLabWorldEnvironment"
	we.environment = env
	add_child(we)


func _build_scene_nodes() -> void:
	_backdrop = BackdropScript.new()
	_backdrop.name = "SpaceBackdrop"
	_backdrop.show_light_gizmo = false
	add_child(_backdrop)
	_backdrop.set_mode(BackdropScript.BackdropMode.SPACE_NEBULA)

	_camera = Camera2D.new()
	_camera.name = "GunsLabCamera"
	_camera.position = Vector2(-75.0, 0.0) # Compensa panel izquierdo para centrar visualmente a Valentina
	_camera.zoom = Vector2(_target_zoom, _target_zoom)
	add_child(_camera)

	_rig = PlanarRigScript.new()
	_rig.name = "ValentinaGunsRig"
	_rig.pilot_profile = _profile
	_rig.z_index = 5
	_rig.enable_face_live = true
	_rig.enable_base_propulsion_wings = false
	add_child(_rig)

	_ring_ctrl = RingCtrlScript.new()
	_ring_ctrl.name = "OrbitalWeaponRingController"
	_ring_ctrl.set_config(_config)
	add_child(_ring_ctrl)


func _configure_rig_defaults() -> void:
	if _rig == null:
		return
	var latest_style: RigStyleProfile = null
	var dir := DirAccess.open(STYLES_DIR)
	if dir != null:
		var files: Array[String] = []
		for f: String in dir.get_files():
			if f.ends_with(".tres"):
				files.append(f)
		files.sort()
		if not files.is_empty():
			latest_style = ResourceLoader.load("%s/%s" % [STYLES_DIR, files[-1]]) as RigStyleProfile
	if latest_style != null:
		_rig.apply_style_profile(latest_style)
	if _profile != null and not _profile.skins.is_empty():
		_rig.apply_skin_preset(_profile.skins[0])
		if _ring_ctrl != null:
			_ring_ctrl.apply_skin_preset(_profile.skins[0])

	_rig.set_idle_anim_enabled(_idle_enabled)
	_rig.set_3d_wings_enabled(_wings_enabled)
	_apply_rig_view(_current_view_key)


func _apply_rig_view(view_key: String) -> void:
	_current_view_key = view_key
	if _rig == null:
		return
	var dir_vec: Vector2 = VIEW_DIR_MAP.get(view_key, Vector2.DOWN) as Vector2
	_rig.set_locomotion_state(dir_vec, 0.0, dir_vec, true)


func _load_tex(res_path: String, disable_mipmaps: bool = false) -> Texture2D:
	if res_path.is_empty():
		return null
	if not disable_mipmaps and ResourceLoader.exists(res_path):
		var loaded: Texture2D = ResourceLoader.load(res_path) as Texture2D
		if loaded != null:
			return loaded
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(res_path) and not FileAccess.file_exists(abs_path):
		return null
	var img := Image.new()
	var err: Error = img.load(abs_path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)


func _load_weapon_index(idx: int) -> void:
	if idx < 0 or idx >= WEAPON_CATALOG.size() or _ring_ctrl == null:
		return
	var entry: Dictionary = WEAPON_CATALOG[idx]
	if String(entry.get("mode", "")) == "3d_rail_lance":
		_ring_ctrl.set_weapon_3d_enabled(true)
		return
	var path: String = String(entry.get("path", ""))
	var albedo: Texture2D = _load_tex(path, false)
	if albedo == null:
		return
	var id_path: String = String(entry.get("id_mask", ""))
	var ilm_path: String = String(entry.get("ilm_mask", ""))
	var sdf_path: String = String(entry.get("ink_sdf", ""))
	if id_path.is_empty() or ilm_path.is_empty() or sdf_path.is_empty():
		_ring_ctrl.set_weapon_texture(albedo)
		return
	var id_tex: Texture2D = _load_tex(id_path, true)
	var ilm_tex: Texture2D = _load_tex(ilm_path, true)
	var sdf_tex: Texture2D = _load_tex(sdf_path, true)
	_ring_ctrl.set_weapon_asset_bundle(albedo, id_tex, ilm_tex, sdf_tex)


func _update_telemetry() -> void:
	var lbl: Label = _hud_refs.get("telemetry_label", null) as Label
	if not is_instance_valid(lbl) or _ring_ctrl == null:
		return
	var st: Dictionary = _ring_ctrl.get_slot_state(0)
	if st.is_empty():
		return
	var deg: float = rad_to_deg(float(st["theta"]))
	lbl.text = "θ: %5.1f° | depth: %+.2f | barrel_z: %+.2f | z: %d" % [
		deg,
		float(st["depth"]),
		float(st["barrel_z"]),
		int(st["z_index"]),
	]


func _on_mode_selected(mode_idx: int) -> void:
	if _ring_ctrl != null:
		_ring_ctrl.set_orbit_mode(mode_idx)


func _on_weapon_count_selected(count: int) -> void:
	if _ring_ctrl != null:
		_ring_ctrl.set_weapon_count(count)


func _on_orbit_pause_toggled(paused: bool) -> void:
	_orbit_paused = paused
	if _ring_ctrl != null:
		_ring_ctrl.set_orbit_paused(paused)


func _on_auto_fire_toggled(enabled: bool) -> void:
	if _ring_ctrl != null:
		_ring_ctrl.set_auto_fire(enabled)


func _on_show_ring_toggled(visible_flag: bool) -> void:
	if _ring_ctrl != null:
		_ring_ctrl.set_show_ring(visible_flag)


func _on_ring_follow_skin_toggled(enabled: bool) -> void:
	if _config != null:
		_config.ring_follow_skin = enabled
	if _ring_ctrl != null:
		_ring_ctrl.set_config(_config)


func _on_ring_use_texture_toggled(enabled: bool) -> void:
	if _config != null:
		_config.ring_use_texture = enabled
	if _ring_ctrl != null:
		_ring_ctrl.set_config(_config)


func _on_skin_selected(skin_idx: int) -> void:
	if _profile == null or skin_idx < 0 or skin_idx >= _profile.skins.size():
		return
	var skin: PilotSkinPreset = _profile.skins[skin_idx]
	if _rig != null:
		_rig.apply_skin_preset(skin)
	if _ring_ctrl != null:
		_ring_ctrl.apply_skin_preset(skin)


func _on_view_selected(view_key: String) -> void:
	_apply_rig_view(view_key)


func _on_wings_toggled(enabled: bool) -> void:
	_wings_enabled = enabled
	if _rig != null:
		_rig.set_3d_wings_enabled(enabled)


func _on_idle_toggled(enabled: bool) -> void:
	_idle_enabled = enabled
	if _rig != null:
		_rig.set_idle_anim_enabled(enabled)


func _on_save_config() -> void:
	if _config == null:
		return
	var err: Error = ResourceSaver.save(_config, CONFIG_PATH)
	var status: Label = _hud_refs.get("status_label", null) as Label
	if is_instance_valid(status):
		status.text = "Guardado OK: valentina_v2_orbital_weapon.tres" if err == OK else ("Error al guardar: %d" % err)


func _on_reload_config() -> void:
	if not ResourceLoader.exists(CONFIG_PATH):
		return
	var reloaded: ConfigScript = ResourceLoader.load(CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ConfigScript
	if reloaded != null:
		_config = reloaded
		_config.ensure_defaults()
		if _ring_ctrl != null:
			_ring_ctrl.set_config(_config)
		HUDScript.sync_sliders_from_config(_hud_refs, _config)
		var sync_chk: CheckBox = _hud_refs.get("ring_sync_chk", null) as CheckBox
		if is_instance_valid(sync_chk):
			sync_chk.set_pressed_no_signal(_config.ring_follow_skin)
		var tex_chk: CheckBox = _hud_refs.get("ring_tex_chk", null) as CheckBox
		if is_instance_valid(tex_chk):
			tex_chk.set_pressed_no_signal(_config.ring_use_texture)
		var status: Label = _hud_refs.get("status_label", null) as Label
		if is_instance_valid(status):
			status.text = "Recargado desde .tres"
