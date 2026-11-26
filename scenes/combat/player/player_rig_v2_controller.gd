class_name PlayerRigV2Controller
extends Node2D
## Orquestador desacoplado de combate in-game para pilotos con Valentina v2 (PlanarCombatRig).
## Coordina orientación Twin-Stick / Kiting 360°, iluminación cósmica zero-alloc,
## Repliegue Táctico / Sobre-Enfoque (Sandevistan + Alas + Ojo/Monóculo + Aberración),
## reacciones de combate (hit/escudo/OSP/bomba/muerte) y Anillo Orbital 2.5D multi-arma (1–4 slots).

const PlanarCombatRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const OrbitalRingCtrlScript = preload("res://scenes/pilots/weapons/orbital_weapon_ring_controller.gd")
const SandevistanCtrlScript = preload("res://scenes/pilots/vfx/sandevistan_trail_controller.gd")
const AstralWings3DCtrlScript = preload("res://scenes/pilots/vfx/astral_wings_3d_controller.gd")
const CosmeticsManagerScript = preload("res://core/systems/cosmetics_manager.gd")
const CombatRigConfigScript = preload("res://data/pilots/schemas/pilot_combat_rig_config.gd")
const OrbitalConfigScript = preload("res://data/pilots/schemas/pilot_orbital_weapon_config.gd")
const PropulsionVFXConfigScript = preload("res://data/pilots/schemas/pilot_propulsion_vfx_config.gd")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")
const EdgeAberrationShader = preload("res://scenes/pilots/shaders/sandevistan_edge_aberration.gdshader")

const DEFAULT_COMBAT_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_combat_rig.tres"
const DEFAULT_ORBITAL_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_orbital_weapon.tres"
const DEFAULT_VFX_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_propulsion_vfx.tres"

var _player: CharacterBody2D = null
var _character_data: CharacterData = null
var _profile: PilotRigProfile = null
var _combat_cfg: CombatRigConfigScript = null
var _vfx_cfg: PropulsionVFXConfigScript = null

var _rig: PlanarCombatRigScript = null
var _ring_ctrl: OrbitalRingCtrlScript = null
var _sandevistan_ctrl: SandevistanCtrlScript = null
var _aberration_layer: CanvasLayer = null
var _aberration_rect: ColorRect = null
var _aberration_mat: ShaderMaterial = null

var _weapon_ctrl: WeaponController = null
var _dash_ctrl: PlayerDashController = null
var _cosmos_host: CosmosHostController = null
var _cosmos_root: CosmosRootNode = null
var _camera: Camera2D = null
var _lighting_sample: CosmicLightingSampleScript = CosmicLightingSampleScript.new()

var _pilot_skin_preset: PilotSkinPreset = null
var _wings_skin_preset: PilotSkinPreset = null
var _weapon_skin_preset: PilotSkinPreset = null
var _pilot_skin_stars: int = 1
var _wings_skin_stars: int = 1
var _weapon_skin_stars: int = 1

var _active_aura_color: Color = Color(0.98, 0.16, 0.34, 1.0)
var _aura_fire_pulse: float = 0.0
var _last_aim_dir: Vector2 = Vector2.RIGHT
var _cinematic_duel_locked: bool = false
var _overfocus_was_active: bool = false
var _wings_override_timer: float = 0.0
var _aberration_timer: float = 0.0
var _is_dead: bool = false

var _is_hub_mode: bool = false
var _is_hub_flying: bool = false
var _is_hub_loadout_showcase: bool = false
var _hub_pose_override_active: bool = false
var _hub_pose_dir: Vector2 = Vector2.DOWN
var _hub_shadow_suppressed: bool = false
var _hub_feet_offset_y_px: float = 54.0
var _hub_wing_fold_pending: bool = false
var _hub_wing_bloom_timer: float = 0.0
var _hub_walk_speed_px: float = 440.0
var _hub_flight_speed_px: float = 760.0
var _hub_contact_shadow: Sprite2D = null
var _hub_facing_dir: Vector2 = Vector2.DOWN


func setup(p_player: CharacterBody2D, p_char_data: CharacterData) -> void:
	_player = p_player
	_character_data = p_char_data
	if _player == null or _character_data == null:
		return
	_profile = _character_data.pilot_rig_profile
	if _profile == null:
		return

	_combat_cfg = _resolve_combat_config()
	_vfx_cfg = _resolve_vfx_config()
	_sync_compensated_scale()
	hide_legacy_visuals(_player)

	_weapon_ctrl = _player.get_node_or_null("WeaponController") as WeaponController
	_dash_ctrl = _player.get("dash_controller") as PlayerDashController

	_build_nodes()
	_apply_style_profile()
	refresh_equipped_skins()
	_bind_signals()
	_sync_initial_pose()

	if _weapon_ctrl != null:
		sync_equipped_weapons(_weapon_ctrl.equipped_weapons)


static func hide_legacy_visuals(p_player: CharacterBody2D) -> void:
	if p_player == null:
		return
	for node_name: String in ["VisualPlaceholder", "ShipSprite", "ExoArmorSprite"]:
		var node: CanvasItem = p_player.get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.visible = false
	var w_ctrl: Node2D = p_player.get_node_or_null("WeaponController") as Node2D
	if w_ctrl != null:
		for w_name: String in ["WeaponVisual", "WeaponSprite"]:
			var w_item: CanvasItem = w_ctrl.get_node_or_null(w_name) as CanvasItem
			if w_item != null:
				w_item.visible = false


func _resolve_combat_config() -> CombatRigConfigScript:
	if _profile != null and _profile.combat_rig_config is CombatRigConfigScript:
		return (_profile.combat_rig_config as CombatRigConfigScript).duplicate(true) as CombatRigConfigScript
	if ResourceLoader.exists(DEFAULT_COMBAT_CFG_PATH):
		var loaded: Resource = ResourceLoader.load(DEFAULT_COMBAT_CFG_PATH)
		if loaded is CombatRigConfigScript:
			return (loaded as CombatRigConfigScript).duplicate(true) as CombatRigConfigScript
	return CombatRigConfigScript.new()


func _resolve_orbital_config() -> OrbitalConfigScript:
	if _combat_cfg != null and _combat_cfg.orbital_weapon_config != null:
		return _combat_cfg.orbital_weapon_config.duplicate(true) as OrbitalConfigScript
	if ResourceLoader.exists(DEFAULT_ORBITAL_CFG_PATH):
		var loaded: Resource = ResourceLoader.load(DEFAULT_ORBITAL_CFG_PATH)
		if loaded is OrbitalConfigScript:
			return (loaded as OrbitalConfigScript).duplicate(true) as OrbitalConfigScript
	return OrbitalConfigScript.new()


func _resolve_vfx_config() -> PropulsionVFXConfigScript:
	if _combat_cfg != null and _combat_cfg.propulsion_vfx_config != null:
		return _combat_cfg.propulsion_vfx_config.duplicate(true) as PropulsionVFXConfigScript
	if ResourceLoader.exists(DEFAULT_VFX_CFG_PATH):
		var loaded: Resource = ResourceLoader.load(DEFAULT_VFX_CFG_PATH)
		if loaded is PropulsionVFXConfigScript:
			return (loaded as PropulsionVFXConfigScript).duplicate(true) as PropulsionVFXConfigScript
	return PropulsionVFXConfigScript.new()


func _sync_compensated_scale() -> void:
	if _player == null or _combat_cfg == null:
		return
	var target_s: float = maxf(_combat_cfg.combat_rig_scale, 0.05)
	var px: float = maxf(absf(_player.scale.x), 0.05)
	var py: float = maxf(absf(_player.scale.y), 0.05)
	scale = Vector2(target_s / px, target_s / py)


func _build_nodes() -> void:
	_sandevistan_ctrl = SandevistanCtrlScript.new()
	_sandevistan_ctrl.name = "SandevistanTrailController"
	_sandevistan_ctrl.top_level = true
	_sandevistan_ctrl.z_as_relative = false
	_sandevistan_ctrl.z_index = _combat_cfg.sandevistan_abs_z_index
	if _vfx_cfg != null:
		_vfx_cfg.ensure_defaults()
		_sandevistan_ctrl.set_config(_vfx_cfg)
	add_child(_sandevistan_ctrl)

	_rig = PlanarCombatRigScript.new()
	_rig.name = "ValentinaCombatRig"
	_rig.pilot_profile = _profile
	_rig.z_index = _combat_cfg.rig_z_offset
	_rig.enable_live_animations = true
	_rig.enable_face_live = true
	_rig.enable_3d_wings = _profile.prefer_3d_wings
	_rig.enable_base_propulsion_wings = not _profile.prefer_3d_wings
	_rig.enable_procedural_wings = false
	_rig.enable_boot_thrusters = false
	_rig.enable_afterimage = false
	add_child(_rig)

	_ring_ctrl = OrbitalRingCtrlScript.new()
	_ring_ctrl.name = "OrbitalWeaponRingController"
	_ring_ctrl.z_index = 0
	var orb_cfg: OrbitalConfigScript = _resolve_orbital_config()
	orb_cfg.ensure_defaults()
	_ring_ctrl.set_config(orb_cfg)
	_ring_ctrl.set_weapon_3d_enabled(true)
	_ring_ctrl.set_orbit_mode(OrbitalWeaponRingController.OrbitMode.MOUSE_AIM)
	add_child(_ring_ctrl)

	var ring_tex: Texture2D = _load_ring_texture_mipmapped(_combat_cfg.ring_texture_path)
	if ring_tex != null:
		_ring_ctrl.set_ring_texture(ring_tex)

	_aberration_layer = CanvasLayer.new()
	_aberration_layer.name = "OverfocusAberrationLayer"
	_aberration_layer.layer = _combat_cfg.overfocus_aberration_layer
	add_child(_aberration_layer)

	_aberration_rect = ColorRect.new()
	_aberration_rect.name = "EdgeAberrationRect"
	_aberration_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_aberration_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aberration_rect.color = Color.WHITE
	_aberration_rect.visible = false
	if EdgeAberrationShader != null:
		_aberration_mat = ShaderMaterial.new()
		_aberration_mat.shader = EdgeAberrationShader
		_aberration_mat.set_shader_parameter("strength_px", 0.0)
		_aberration_rect.material = _aberration_mat
	_aberration_layer.add_child(_aberration_rect)


func _load_ring_texture_mipmapped(res_path: String) -> Texture2D:
	if res_path.is_empty():
		return null
	var img: Image = null
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		img = Image.load_from_file(abs_path)
	elif ResourceLoader.exists(res_path):
		var res: Resource = ResourceLoader.load(res_path)
		if res is Texture2D:
			img = (res as Texture2D).get_image()
			if img != null and img.is_compressed():
				img.decompress()
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _apply_style_profile() -> void:
	if _rig == null:
		return
	var style: RigStyleProfile = null
	if _profile != null:
		for st: RigStyleProfile in _profile.style_profiles:
			if st != null and st.id == "02_valentina_razor_sharp":
				style = st
				break
	if style == null and _combat_cfg != null and not _combat_cfg.default_style_path.is_empty():
		if ResourceLoader.exists(_combat_cfg.default_style_path):
			style = ResourceLoader.load(_combat_cfg.default_style_path) as RigStyleProfile
	if style != null:
		_rig.apply_style_profile(style)


func _sync_initial_pose() -> void:
	if _rig == null:
		return
	var init_dir: Vector2 = Vector2.UP
	if _player != null:
		var last_dir_v: Variant = _player.get("last_facing_direction")
		if last_dir_v is Vector2 and (last_dir_v as Vector2).length_squared() > 0.01:
			init_dir = last_dir_v as Vector2
	_last_aim_dir = init_dir.normalized()
	_rig.set_locomotion_state(_last_aim_dir, 0.0, _last_aim_dir, true)
	if _ring_ctrl != null:
		_ring_ctrl.set_mouse_target_local(_last_aim_dir * 220.0)
		_ring_ctrl.step(0.0)


func _bind_signals() -> void:
	if _dash_ctrl != null and not _dash_ctrl.dash_executed.is_connected(on_dash_executed):
		_dash_ctrl.dash_executed.connect(on_dash_executed)
	if _player != null:
		if _player.has_signal("bomb_used") and not _player.is_connected("bomb_used", on_bomb_used):
			_player.connect("bomb_used", on_bomb_used)
		if _player.has_signal("osp_triggered") and not _player.is_connected("osp_triggered", _on_osp_triggered):
			_player.connect("osp_triggered", _on_osp_triggered)
		if _player.has_signal("player_died") and not _player.is_connected("player_died", _on_player_died_signal):
			_player.connect("player_died", _on_player_died_signal)
	if _weapon_ctrl != null and not _weapon_ctrl.weapons_updated.is_connected(sync_equipped_weapons):
		_weapon_ctrl.weapons_updated.connect(sync_equipped_weapons)


func refresh_equipped_skins() -> void:
	if _character_data == null:
		return
	var cid: StringName = _character_data.character_id

	_pilot_skin_preset = CosmeticsManagerScript.resolve_pilot_skin_preset(cid, "pilot")
	_pilot_skin_stars = CosmeticsManagerScript.resolve_equipped_skin_stars("pilot", cid)
	if _rig != null and _pilot_skin_preset != null:
		_rig.apply_skin_preset(_pilot_skin_preset, _pilot_skin_stars)

	var wings_skin_id: String = CosmeticsManagerScript.resolve_equipped_skin_id("wings", cid)
	_wings_skin_stars = CosmeticsManagerScript.resolve_equipped_skin_stars("wings", cid)
	if wings_skin_id == CosmeticsManagerScript.FOLLOW_PILOT_SKIN_ID:
		_wings_skin_preset = null
		if _rig != null:
			_rig.apply_wings_skin_preset(null, 1)
	else:
		_wings_skin_preset = CosmeticsManagerScript.resolve_pilot_skin_preset(cid, "wings")
		if _rig != null:
			_rig.apply_wings_skin_preset(_wings_skin_preset, _wings_skin_stars)

	_weapon_skin_preset = CosmeticsManagerScript.resolve_pilot_skin_preset(cid, "weapon")
	_weapon_skin_stars = CosmeticsManagerScript.resolve_equipped_skin_stars("weapon", cid)
	if _ring_ctrl != null:
		_ring_ctrl.apply_skin_preset(_weapon_skin_preset, _weapon_skin_stars)

	var aura_preset: PilotSkinPreset = _wings_skin_preset if _wings_skin_preset != null else _pilot_skin_preset
	if aura_preset != null:
		_active_aura_color = aura_preset.accent_color
	elif _profile != null:
		_active_aura_color = _profile.default_accent_color

	if _weapon_ctrl != null:
		sync_equipped_weapons(_weapon_ctrl.equipped_weapons)


func sync_equipped_weapons(weapons: Array) -> void:
	if _ring_ctrl == null:
		return
	var count: int = clampi(weapons.size(), 1, OrbitalWeaponRingController.MAX_SLOTS)
	_ring_ctrl.set_weapon_count(count)
	_ring_ctrl.clear_all_slot_palettes()

	var slot0_has_cosmetic_skin: bool = _weapon_skin_preset != null and not _weapon_skin_preset.is_base_skin
	for i: int in range(mini(weapons.size(), OrbitalWeaponRingController.MAX_SLOTS)):
		var inst: WeaponInstanceData = weapons[i] as WeaponInstanceData
		var wdata: WeaponData = inst.weapon_data if inst != null else null
		if wdata == null:
			continue
		if i == 0 and slot0_has_cosmetic_skin:
			continue
		_ring_ctrl.set_slot_palette(
			i,
			wdata.orbital_armor_color,
			wdata.orbital_chassis_color,
			wdata.orbital_crystal_color
		)


func _process(delta: float) -> void:
	if _is_dead or _player == null or not is_instance_valid(_player) or _rig == null:
		return

	_sync_compensated_scale()

	var ts: float = maxf(Engine.time_scale, 0.1)
	var unscaled_delta: float = clampf(delta / ts, 0.0, 0.06)

	if _is_hub_mode:
		_process_hub_mode(unscaled_delta)
		return

	var mouse_world: Vector2 = _player.get_global_mouse_position()
	var primary_aim_world: Vector2 = _weapon_ctrl.get_primary_aim_world_pos() if (_weapon_ctrl != null and is_instance_valid(_weapon_ctrl)) else mouse_world
	var aim_vec: Vector2 = primary_aim_world - _player.global_position
	var aim_dir: Vector2 = aim_vec.normalized() if aim_vec.length_squared() >= _combat_cfg.aim_min_dist_sq else _last_aim_dir
	_last_aim_dir = aim_dir

	var spd: float = _player.velocity.length()
	var p_stats: CharacterStats = _player.get("stats") as CharacterStats
	var max_spd: float = maxf(1.0, p_stats.get_stat(&"move_speed") if p_stats != null else 300.0)
	var move_dir: Vector2 = (_player.velocity / spd) if spd > 5.0 else aim_dir
	var speed_norm: float = clampf(spd / max_spd, 0.0, 1.35)
	var is_dashing_now: bool = bool(_player.get("is_dashing"))
	var is_focus_now: bool = bool(_player.get("is_focus_active"))
	var overfocus_active: bool = is_dashing_now or is_focus_now
	var is_turbo: bool = overfocus_active or (spd >= max_spd * _combat_cfg.turbo_speed_ratio_thresh)

	if not _cinematic_duel_locked:
		_rig.set_turbo_active(is_turbo)
		_rig.set_locomotion_state(move_dir, speed_norm, aim_dir, false)

	var flash_t: float = float(_player.get("hit_flash_timer"))
	var flash_norm: float = clampf(flash_t / 0.22, 0.0, 1.0)
	_rig.set_hit_flash(flash_norm)

	_step_overfocus_and_vfx(unscaled_delta, overfocus_active)
	_step_orbital_ring(unscaled_delta, primary_aim_world)
	_step_cosmos_and_camera(unscaled_delta, overfocus_active, max_spd)


func _step_overfocus_and_vfx(unscaled_delta: float, overfocus_active: bool) -> void:
	if _wings_override_timer > 0.0:
		_wings_override_timer = maxf(0.0, _wings_override_timer - unscaled_delta)
		if _wings_override_timer <= 0.0 and not overfocus_active:
			_rig.clear_3d_wings_manual_override()

	if overfocus_active:
		_overfocus_was_active = true
		_rig.set_face_overfocus_boost(_combat_cfg.overfocus_eye_monocle_boost)
		if _wings_override_timer <= 0.0:
			_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.SERAPH_BLOOM)
		if _sandevistan_ctrl != null:
			_sandevistan_ctrl.step(unscaled_delta, _rig, _player.velocity, true)
	else:
		if _overfocus_was_active:
			_overfocus_was_active = false
			_rig.set_face_overfocus_boost(0.0)
			if _wings_override_timer <= 0.0:
				_rig.clear_3d_wings_manual_override()
		if _sandevistan_ctrl != null and (_sandevistan_ctrl.get_active_ghost_count() > 0 or _sandevistan_ctrl.get_sequence_progress() > 0.001):
			_sandevistan_ctrl.step(unscaled_delta, _rig, Vector2.ZERO, false)

	if _aberration_mat != null and _aberration_rect != null and _vfx_cfg != null:
		if _aberration_timer > 0.0 and _vfx_cfg.aberration_enabled:
			_aberration_timer = maxf(0.0, _aberration_timer - unscaled_delta)
			var norm_t: float = _aberration_timer / maxf(0.01, _vfx_cfg.aberration_decay_sec)
			_aberration_mat.set_shader_parameter("strength_px", _vfx_cfg.aberration_peak_px * norm_t * norm_t)
			_aberration_rect.visible = _aberration_timer > 0.001
		else:
			_aberration_mat.set_shader_parameter("strength_px", 0.0)
			_aberration_rect.visible = false


func _step_orbital_ring(unscaled_delta: float, primary_aim_world: Vector2) -> void:
	if _ring_ctrl == null:
		return
	_ring_ctrl.set_mouse_target_local(_ring_ctrl.to_local(primary_aim_world))
	if _weapon_ctrl != null and is_instance_valid(_weapon_ctrl):
		var slot_count: int = mini(_weapon_ctrl.equipped_weapons.size(), _ring_ctrl.get_slot_count())
		for i: int in range(slot_count):
			var slot_world: Vector2 = _weapon_ctrl.get_slot_aim_world_pos(i)
			_ring_ctrl.set_slot_target_local(i, _ring_ctrl.to_local(slot_world))
	_ring_ctrl.step(unscaled_delta)


func _step_cosmos_and_camera(unscaled_delta: float, overfocus_active: bool, max_spd: float) -> void:
	var cam: Camera2D = _resolve_camera()
	if cam != null:
		_rig.set_zoom_scale(cam.zoom.x)

	_aura_fire_pulse = move_toward(_aura_fire_pulse, 0.0, unscaled_delta * _combat_cfg.aura_fire_decay_rate)

	_resolve_cosmos_refs()
	if _cosmos_host != null and is_instance_valid(_cosmos_host):
		_cosmos_host.sample_lighting_at(_player.global_position, _lighting_sample)
		_rig.apply_cosmic_lighting(_lighting_sample, unscaled_delta, _cosmos_host.rig_lighting_config)
		if _ring_ctrl != null:
			var eff_sample: CosmicLightingSampleScript = _rig.get_last_cosmic_lighting()
			_ring_ctrl.apply_cosmic_lighting(eff_sample if eff_sample != null else _lighting_sample)

	if _cosmos_root != null and is_instance_valid(_cosmos_root):
		var aura_energy: float = (
			_combat_cfg.aura_base_energy
			+ (_combat_cfg.aura_overfocus_bonus if overfocus_active else 0.0)
			+ _aura_fire_pulse * _combat_cfg.aura_fire_pulse_bonus
		)
		var vel_x_norm: float = clampf(_player.velocity.x / maxf(max_spd, 1.0), -1.0, 1.0)
		var wing_axis := Vector2(1.0, vel_x_norm * 0.24).normalized()
		_cosmos_root.set_player_aura_light(
			_active_aura_color,
			_combat_cfg.aura_offset_px,
			_combat_cfg.aura_radius_px,
			aura_energy,
			wing_axis
		)


func _resolve_camera() -> Camera2D:
	if _camera != null and is_instance_valid(_camera):
		return _camera
	var vp: Viewport = get_viewport()
	if vp != null:
		_camera = vp.get_camera_2d()
	if _camera == null and is_inside_tree():
		_camera = get_tree().get_first_node_in_group("camera") as Camera2D
	return _camera


func _resolve_cosmos_refs() -> void:
	if (_cosmos_host == null or not is_instance_valid(_cosmos_host)) or (_cosmos_root == null or not is_instance_valid(_cosmos_root)):
		if _player != null:
			var p_parent: Node = _player.get_parent()
			if p_parent != null:
				var env_host: Variant = p_parent.get("environment_host")
				if env_host is Object:
					if (env_host as Object).has_method("get_cosmos_controller"):
						_cosmos_host = (env_host as Object).call("get_cosmos_controller") as CosmosHostController
					var active_env: Variant = (env_host as Object).get("active_environment")
					if active_env is CosmosCombatEnvironment:
						_cosmos_root = (active_env as CosmosCombatEnvironment).get_cosmos_root()
				if _cosmos_root == null:
					var bg: Node = p_parent.get_node_or_null("SpaceBackground")
					if bg is CosmosCombatEnvironment:
						var cenv: CosmosCombatEnvironment = bg as CosmosCombatEnvironment
						if _cosmos_host == null:
							_cosmos_host = cenv.get_cosmos_controller()
						_cosmos_root = cenv.get_cosmos_root()
		if _cosmos_root == null and is_inside_tree():
			_cosmos_root = get_tree().get_first_node_in_group("cosmos_root") as CosmosRootNode
		if _cosmos_host == null and _cosmos_root != null and is_instance_valid(_cosmos_root):
			var c_parent: Node = _cosmos_root.get_parent()
			if c_parent != null and c_parent.has_method("get_cosmos_controller"):
				_cosmos_host = c_parent.call("get_cosmos_controller") as CosmosHostController


func on_dash_executed(dash_dir: Vector2, cid: StringName) -> void:
	if _is_dead or _rig == null or _is_hub_mode:
		return
	_rig.trigger_dash_burst(dash_dir)
	var is_overfocus: bool = bool(_player != null and _player.get("is_focus_active")) or cid == &"valentina"
	if is_overfocus:
		_overfocus_was_active = true
		if _sandevistan_ctrl != null:
			_sandevistan_ctrl.trigger_burst_impulse(_rig)
		_rig.set_face_overfocus_boost(_combat_cfg.overfocus_eye_monocle_boost)
		_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.SERAPH_BLOOM)
		_rig.trigger_3d_wings_pulse()
		_rig.trigger_impact_frame(_combat_cfg.overfocus_impact_ms, _combat_cfg.overfocus_impact_shake_px)
		if _vfx_cfg != null and _vfx_cfg.aberration_enabled:
			_aberration_timer = _vfx_cfg.aberration_decay_sec
			if _aberration_rect != null and _aberration_mat != null:
				_aberration_mat.set_shader_parameter("strength_px", _vfx_cfg.aberration_peak_px)
				_aberration_rect.visible = true


func on_damage_taken(hit_dir: Vector2 = Vector2.ZERO, is_osp: bool = false) -> void:
	if _is_dead or _rig == null or _is_hub_mode:
		return
	_rig.trigger_hit_react(hit_dir, 1.35 if is_osp else 1.0)
	if is_osp:
		_rig.trigger_impact_frame(_combat_cfg.osp_impact_ms, _combat_cfg.osp_impact_shake_px)
		_wings_override_timer = maxf(_wings_override_timer, _combat_cfg.shield_absorb_wings_sec)
		_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.AEGIS_GUARD)
		_rig.trigger_3d_wings_pulse()
	else:
		_rig.trigger_impact_frame(_combat_cfg.hit_impact_ms, _combat_cfg.hit_impact_shake_px)


func on_shield_absorbed() -> void:
	if _is_dead or _rig == null:
		return
	_wings_override_timer = maxf(_wings_override_timer, _combat_cfg.shield_absorb_wings_sec)
	_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.AEGIS_GUARD)
	_rig.trigger_3d_wings_pulse()


func on_bomb_used(_remaining: int = 0) -> void:
	if _is_dead or _rig == null or _is_hub_mode:
		return
	_rig.trigger_impact_frame(_combat_cfg.bomb_impact_ms, _combat_cfg.bomb_impact_shake_px)
	_wings_override_timer = maxf(_wings_override_timer, _combat_cfg.bomb_wings_bloom_sec)
	_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.SERAPH_BLOOM)
	_rig.trigger_3d_wings_pulse()
	_aura_fire_pulse = 1.35


func on_weapon_fired(slot_idx: int, aim_dir: Vector2, is_active: bool) -> void:
	if _is_dead or _is_hub_mode:
		return
	if _ring_ctrl != null and slot_idx >= 0:
		_ring_ctrl.trigger_fire(slot_idx, false)
	if _rig != null:
		var recoil_str: float = _combat_cfg.active_fire_recoil_strength if is_active else _combat_cfg.passive_fire_recoil_strength
		_rig.trigger_attack_recoil(aim_dir, recoil_str)
	_aura_fire_pulse = maxf(_aura_fire_pulse, 1.0 if is_active else 0.55)


func set_cinematic_duel_facing(facing_dir: Vector2 = Vector2.RIGHT) -> void:
	_cinematic_duel_locked = true
	var dir: Vector2 = facing_dir.normalized() if facing_dir.length_squared() > 0.001 else Vector2.RIGHT
	_last_aim_dir = dir
	if _rig != null:
		_rig.set_turbo_active(false)
		_rig.set_locomotion_state(dir, 0.0, dir, true)


func resume_movement_control() -> void:
	_cinematic_duel_locked = false


func on_player_died() -> void:
	if _is_dead:
		return
	_is_dead = true
	visible = false
	if _sandevistan_ctrl != null:
		_sandevistan_ctrl.clear_all_ghosts()
	if _aberration_mat != null:
		_aberration_mat.set_shader_parameter("strength_px", 0.0)
	if _aberration_rect != null:
		_aberration_rect.visible = false
	if _rig != null:
		_rig.set_face_overfocus_boost(0.0)
		var wings_3d: AstralWings3DController = _rig.get_3d_wings_controller()
		if wings_3d != null:
			wings_3d.set_viewports_active(false)


func _on_osp_triggered(_remaining_hp: float) -> void:
	on_damage_taken(Vector2.ZERO, true)


func _on_player_died_signal() -> void:
	on_player_died()


func get_weapon_muzzle_world_pos(slot_idx: int) -> Vector2:
	if _ring_ctrl != null and slot_idx >= 0 and slot_idx < _ring_ctrl.get_slot_count():
		return _ring_ctrl.get_slot_muzzle_world_pos(slot_idx)
	return _player.global_position if _player != null else global_position


func get_muzzle_reaim_min_dist() -> float:
	return _combat_cfg.muzzle_reaim_min_dist if _combat_cfg != null else 48.0


func get_rig() -> PlanarCombatRigScript:
	return _rig


func get_ring_controller() -> OrbitalRingCtrlScript:
	return _ring_ctrl


func get_sandevistan_controller() -> SandevistanCtrlScript:
	return _sandevistan_ctrl


func get_aberration_layer() -> CanvasLayer:
	return _aberration_layer


func get_aberration_rect() -> ColorRect:
	return _aberration_rect


func get_combat_config() -> CombatRigConfigScript:
	return _combat_cfg


func is_hub_mode() -> bool:
	return _is_hub_mode


func is_hub_flying() -> bool:
	return _is_hub_flying


func set_hub_mode(enabled: bool, feet_offset_y_px: float = 54.0) -> void:
	_is_hub_mode = enabled
	_hub_feet_offset_y_px = feet_offset_y_px
	if enabled:
		_is_hub_loadout_showcase = false
		_hub_pose_override_active = false
		_hub_shadow_suppressed = false
		_hub_wing_fold_pending = false
		_hub_wing_bloom_timer = 0.0
		_overfocus_was_active = false
		_aberration_timer = 0.0
		if _aberration_mat != null:
			_aberration_mat.set_shader_parameter("strength_px", 0.0)
		if _aberration_rect != null:
			_aberration_rect.visible = false
		if _ring_ctrl != null:
			_ring_ctrl.visible = false
			_ring_ctrl.process_mode = Node.PROCESS_MODE_DISABLED
		_ensure_hub_contact_shadow()
		set_hub_traversal_state(false, true)
	else:
		_is_hub_loadout_showcase = false
		_hub_pose_override_active = false
		_hub_shadow_suppressed = false
		_hub_wing_fold_pending = false
		_hub_wing_bloom_timer = 0.0
		if _hub_contact_shadow != null and is_instance_valid(_hub_contact_shadow):
			_hub_contact_shadow.visible = false
		if _rig != null:
			_rig.set_locomotion_mode(PlanarCombatRig.LocomotionMode.ZERO_G_FLIGHT)
			var zero_g_fps: float = _profile.stepped_fps if _profile != null else 15.0
			_rig.set_stepped_fps(zero_g_fps)
			var want_3d_wings: bool = _profile.prefer_3d_wings if _profile != null else true
			_rig.set_3d_wings_enabled(want_3d_wings)
			_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.SERAPH_BLOOM, false)
			_rig.trigger_3d_wings_pulse()
			_wings_override_timer = 0.55
		if _ring_ctrl != null:
			_ring_ctrl.visible = true
			_ring_ctrl.process_mode = Node.PROCESS_MODE_INHERIT
			if _weapon_ctrl != null:
				sync_equipped_weapons(_weapon_ctrl.equipped_weapons)
		refresh_equipped_skins()


func set_hub_traversal_state(is_flying: bool, instant: bool = false) -> void:
	if _is_hub_flying == is_flying and not instant:
		return
	_is_hub_flying = is_flying
	if _rig == null or not _is_hub_mode:
		return

	var want_zero_g: bool = is_flying or _is_hub_loadout_showcase
	_rig.set_locomotion_mode(PlanarCombatRig.LocomotionMode.ZERO_G_FLIGHT if want_zero_g else PlanarCombatRig.LocomotionMode.GROUNDED_HUB)
	var zero_g_fps: float = _profile.stepped_fps if _profile != null else 15.0
	_rig.set_stepped_fps(zero_g_fps if want_zero_g else 60.0)

	if want_zero_g:
		_hub_wing_fold_pending = false
		_rig.set_3d_wings_enabled(_profile.prefer_3d_wings if _profile != null else true)
		if instant:
			_hub_wing_bloom_timer = 0.0
			_rig.clear_3d_wings_manual_override()
			_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.IDLE_ZERO_G, true)
		else:
			_hub_wing_bloom_timer = 0.58
			_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.SERAPH_BLOOM, false)
			_rig.trigger_3d_wings_pulse()
		if _wings_skin_preset != null:
			_rig.apply_wings_skin_preset(_wings_skin_preset, _wings_skin_stars)
	else:
		_hub_wing_bloom_timer = 0.0
		if instant or not _rig.enable_3d_wings:
			_hub_wing_fold_pending = false
			_rig.clear_3d_wings_manual_override()
			_rig.set_3d_wings_enabled(false)
		else:
			_hub_wing_fold_pending = true
			_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.SERAPH_FOLD, false)


func set_hub_loadout_showcase(enabled: bool) -> void:
	_is_hub_loadout_showcase = enabled
	if not _is_hub_mode:
		return
	if enabled:
		if _rig != null:
			_rig.set_locomotion_mode(PlanarCombatRig.LocomotionMode.ZERO_G_FLIGHT)
			_rig.set_stepped_fps(_profile.stepped_fps if _profile != null else 15.0)
			_rig.set_3d_wings_enabled(_profile.prefer_3d_wings if _profile != null else true)
			_rig.set_3d_wings_anim_state(AstralWings3DController.AnimState.IDLE_ZERO_G, false)
			_rig.trigger_3d_wings_pulse()
		if _ring_ctrl != null:
			_ring_ctrl.visible = true
			_ring_ctrl.process_mode = Node.PROCESS_MODE_INHERIT
			_ring_ctrl.set_mouse_target_local(Vector2(0.0, 200.0))
		refresh_equipped_skins()
	else:
		if _ring_ctrl != null:
			_ring_ctrl.visible = false
			_ring_ctrl.process_mode = Node.PROCESS_MODE_DISABLED
		set_hub_traversal_state(_is_hub_flying, true)


func set_hub_pose_override(active: bool, dir: Vector2 = Vector2.DOWN, snap: bool = true) -> void:
	_hub_pose_override_active = active
	if dir.length_squared() > 0.001:
		_hub_pose_dir = dir.normalized()
		_hub_facing_dir = _hub_pose_dir
	if active and _rig != null:
		_rig.set_turbo_active(false)
		_rig.set_locomotion_state(_hub_pose_dir, 0.0, _hub_pose_dir, snap)


func set_hub_shadow_suppressed(suppressed: bool) -> void:
	_hub_shadow_suppressed = suppressed
	if _hub_contact_shadow != null and is_instance_valid(_hub_contact_shadow):
		_hub_contact_shadow.visible = _is_hub_mode and not suppressed and not _is_hub_flying and not _is_hub_loadout_showcase


func feed_hub_walk_displacement(dist_m: float) -> void:
	if _rig != null and _is_hub_mode and not _is_hub_flying and not _is_hub_loadout_showcase:
		_rig.feed_world_displacement(dist_m)


func set_hub_speed_refs(walk_px: float, flight_px: float) -> void:
	_hub_walk_speed_px = maxf(walk_px, 1.0)
	_hub_flight_speed_px = maxf(flight_px, 1.0)


func on_hub_dash_started(dash_dir: Vector2) -> void:
	if _is_dead or _rig == null or not _is_hub_mode:
		return
	if dash_dir.length_squared() > 0.001:
		_hub_facing_dir = dash_dir.normalized()
	_rig.trigger_dash_burst(_hub_facing_dir)
	if _sandevistan_ctrl != null:
		_sandevistan_ctrl.trigger_burst_impulse(_rig)
	if _is_hub_flying:
		_rig.trigger_3d_wings_pulse()


func apply_live_gacha_skin(category: String, preset: PilotSkinPreset, stars: int) -> void:
	if preset == null:
		return
	var clamp_stars: int = clampi(stars, 1, 3)
	if category == "wings" or category == "ship":
		_wings_skin_preset = preset
		_wings_skin_stars = clamp_stars
		if _rig != null:
			_rig.apply_wings_skin_preset(preset, clamp_stars)
	elif category == "weapon":
		_weapon_skin_preset = preset
		_weapon_skin_stars = clamp_stars
		if _ring_ctrl != null:
			_ring_ctrl.apply_skin_preset(preset, clamp_stars)
	else:
		_pilot_skin_preset = preset
		_pilot_skin_stars = clamp_stars
		if _rig != null:
			_rig.apply_skin_preset(preset, clamp_stars)


func _ensure_hub_contact_shadow() -> void:
	if _hub_contact_shadow != null and is_instance_valid(_hub_contact_shadow):
		_hub_contact_shadow.visible = true
		return
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.52, 1.0])
	grad.colors = PackedColorArray([
		Color(0.02, 0.02, 0.06, 0.44),
		Color(0.02, 0.02, 0.06, 0.18),
		Color(0.02, 0.02, 0.06, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	_hub_contact_shadow = Sprite2D.new()
	_hub_contact_shadow.name = "HubContactShadow2D"
	_hub_contact_shadow.texture = tex
	_hub_contact_shadow.z_index = -1
	add_child(_hub_contact_shadow)


func _process_hub_mode(unscaled_delta: float) -> void:
	if _hub_wing_bloom_timer > 0.0:
		_hub_wing_bloom_timer = maxf(0.0, _hub_wing_bloom_timer - unscaled_delta)
		if _hub_wing_bloom_timer <= 0.0 and (_is_hub_flying or _is_hub_loadout_showcase):
			_rig.clear_3d_wings_manual_override()
	if _hub_wing_fold_pending:
		var w_ctrl: AstralWings3DController = _rig.get_3d_wings_controller()
		if w_ctrl == null or w_ctrl.is_fold_complete():
			_hub_wing_fold_pending = false
			if not _is_hub_flying and not _is_hub_loadout_showcase:
				_rig.clear_3d_wings_manual_override()
				_rig.set_3d_wings_enabled(false)

	var p_stats: CharacterStats = _player.get("stats") as CharacterStats
	var max_spd: float = maxf(1.0, p_stats.get_stat(&"move_speed") if p_stats != null else 300.0)
	var spd: float = _player.velocity.length()

	var is_hub_dash_now: bool = _player.has_method("is_hub_dashing") and bool(_player.call("is_hub_dashing"))

	if _hub_pose_override_active:
		_rig.set_turbo_active(false)
		_rig.set_locomotion_state(_hub_pose_dir, 0.0, _hub_pose_dir, false)
	else:
		var move_dir: Vector2 = _hub_facing_dir
		if spd > 8.0:
			move_dir = _player.velocity / spd
			_hub_facing_dir = move_dir
		var ref_spd: float = maxf(_hub_flight_speed_px, 1.0) if _is_hub_flying else maxf(_hub_walk_speed_px, 1.0)
		var speed_norm: float = clampf(spd / ref_spd, 0.0, 1.25)
		_rig.set_turbo_active(is_hub_dash_now)
		_rig.set_locomotion_state(_hub_facing_dir, speed_norm, _hub_facing_dir, false)

	_rig.set_hit_flash(0.0)

	if _sandevistan_ctrl != null and (is_hub_dash_now or _sandevistan_ctrl.get_active_ghost_count() > 0 or _sandevistan_ctrl.get_sequence_progress() > 0.001):
		_sandevistan_ctrl.step(unscaled_delta, _rig, _player.velocity if is_hub_dash_now else Vector2.ZERO, is_hub_dash_now)

	if _hub_contact_shadow != null and is_instance_valid(_hub_contact_shadow):
		var show_sh: bool = not _is_hub_flying and not _hub_shadow_suppressed and not _is_hub_loadout_showcase
		_hub_contact_shadow.visible = show_sh
		if show_sh:
			var p_scale_y: float = maxf(absf(_player.scale.y) * absf(scale.y), 0.1)
			var lift_norm: float = _rig.get_grounded_pelvis_lift_norm()
			_hub_contact_shadow.position = Vector2(0.0, _hub_feet_offset_y_px / p_scale_y)
			var sh_scale: float = 1.0 - lift_norm * 0.12
			_hub_contact_shadow.scale = Vector2(1.42 * sh_scale, 0.50 * sh_scale)

	if _is_hub_loadout_showcase and _ring_ctrl != null and _ring_ctrl.visible:
		_ring_ctrl.set_mouse_target_local(Vector2(0.0, 200.0))
		_ring_ctrl.step(unscaled_delta)

	_step_cosmos_and_camera(unscaled_delta, false, max_spd)
