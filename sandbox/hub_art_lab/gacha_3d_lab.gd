class_name Gacha3DLab
extends Node3D

## Escena Laboratorio Aislada (Fase 2) — Invocador Giroscópico Astral 3D (Ala Este Psycho-Pop).
## Integra HubGachaSummoner3D, Gacha3DSessionController (GachaBannerEngine sin mutar SaveManager),
## Gacha3DLabOverlay (Astral Pop-Ink + ShaderSkinLivePreview único) y HubRigAvatar3D de Valentina v2.

const ConfigScript = preload("res://sandbox/hub_art_lab/resources/hub_gacha_3d_config.gd")
const DEFAULT_CONFIG: ConfigScript = preload("res://sandbox/hub_art_lab/data/default_hub_gacha_3d_config.tres")
const SummonerScript = preload("res://sandbox/hub_art_lab/components/hub_gacha_summoner_3d.gd")
const SessionScript = preload("res://sandbox/hub_art_lab/components/gacha_3d_session_controller.gd")
const OverlayScript = preload("res://sandbox/hub_art_lab/components/gacha_3d_lab_overlay.gd")
const ArchBuilder = preload("res://sandbox/hub_art_lab/meshes/hub_architecture_mesh_builder.gd")
const Primitives = preload("res://sandbox/hub_art_lab/meshes/hub_arcsys_mesh_primitives.gd")
const TextureLoader = preload("res://sandbox/hub_art_lab/components/hub_texture_loader.gd")
const SurfaceShader = preload("res://sandbox/hub_art_lab/shaders/hub_arcsys_surface_3d.gdshader")
const PropShader = preload("res://sandbox/hub_art_lab/shaders/hub_arcsys_prop_3d.gdshader")
const OutlineShader = preload("res://sandbox/hub_art_lab/shaders/hub_arcsys_outline_3d.gdshader")
const HubRigAvatar3DScript = preload("res://scenes/ui/hub/components/hub_rig_avatar_3d.gd")
const DioramaConfigScript = preload("res://scenes/ui/hub/resources/hub_diorama_config.gd")
const DEFAULT_DIORAMA_CONFIG: DioramaConfigScript = preload("res://data/hub/default_hub_diorama_config.tres")
const SilhouetteShadowShader = preload("res://shaders/character_silhouette_shadow.gdshader")
const AstralWings3DScript = preload("res://scenes/pilots/vfx/astral_wings_3d_controller.gd")

const HUB_ART_LAB_PATH: String = "res://sandbox/hub_art_lab/hub_art_lab.tscn"
const WORKBENCH_HUB_PATH: String = "res://sandbox/workbenches/workbench_hub.tscn"

enum CamState {
	IDLE_BAY = 0,
	CINEMATIC = 1,
	BURST_REVEAL = 2,
}

@export var config: ConfigScript = DEFAULT_CONFIG

var camera: Camera3D = null
var summoner: SummonerScript = null
var session: SessionScript = null
var overlay: OverlayScript = null
var pilot_avatar: HubRigAvatar3DScript = null

var _world_env: WorldEnvironment = null
var _dir_light: DirectionalLight3D = null
var _override_mode: SessionScript.PullOverride = SessionScript.PullOverride.NATURAL
var _cam_state: CamState = CamState.IDLE_BAY
var _cam_base_pos: Vector3 = Vector3.ZERO
var _cam_look_pos: Vector3 = Vector3.ZERO
var _cam_fov: float = 38.0
var _shake_strength: float = 0.0
var _current_bloom: float = 0.72
var _last_batch: Dictionary = {}


func _ready() -> void:
	if config == null:
		config = DEFAULT_CONFIG
	if get_viewport() != null:
		get_viewport().msaa_2d = Viewport.MSAA_DISABLED
	_current_bloom = config.bloom_idle
	_build_environment()
	_build_psychopop_bay()
	_build_summoner()
	_build_pilot_showcase()
	_build_camera()
	_build_session_and_overlay()
	_sync_overlay_session_status()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.018, 0.016, 0.048, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.14, 0.13, 0.26, 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.12
	env.glow_intensity = config.bloom_idle
	env.glow_bloom = 0.18

	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnvironment"
	_world_env.environment = env
	add_child(_world_env)

	_dir_light = DirectionalLight3D.new()
	_dir_light.name = "DirectionalLight3D"
	_dir_light.rotation_degrees = Vector3(-46.0, -22.0, 0.0)
	_dir_light.light_color = Color(1.0, 0.97, 0.96, 1.0)
	_dir_light.light_energy = 0.95
	_dir_light.shadow_enabled = true
	_dir_light.shadow_bias = 0.04
	_dir_light.shadow_normal_bias = 1.2
	_dir_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_dir_light.directional_shadow_max_distance = 32.0
	add_child(_dir_light)

	var left_pink := OmniLight3D.new()
	left_pink.name = "PsychoPopPinkLight"
	left_pink.position = Vector3(-4.5, 3.2, 2.2)
	left_pink.light_color = Color(1.0, 0.12, 0.58, 1.0)
	left_pink.light_energy = 1.35
	left_pink.omni_range = 13.0
	add_child(left_pink)

	var right_cyan := OmniLight3D.new()
	right_cyan.name = "PsychoPopCyanLight"
	right_cyan.position = Vector3(4.5, 3.2, 2.2)
	right_cyan.light_color = Color(0.05, 0.94, 1.0, 1.0)
	right_cyan.light_energy = 1.25
	right_cyan.omni_range = 13.0
	add_child(right_cyan)


func _build_psychopop_bay() -> void:
	var bay_root := Node3D.new()
	bay_root.name = "PsychoPopBay"
	add_child(bay_root)

	var floor_mat: ShaderMaterial = _create_surface_mat(
		config.floor_tex_base,
		Vector2(1.0, 1.0),
		Vector2(1024.0, 1024.0),
		Color(0.11, 0.12, 0.22, 1.0),
		Color(0.035, 0.040, 0.085, 1.0),
		Color(1.0, 0.16, 0.62, 1.0),
		0.45
	)
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "BayFloorMesh"
	floor_mi.mesh = ArchBuilder.build_floor_mesh(16.0, 14.0, 5.5)
	floor_mi.position = Vector3(0.0, 0.0, -0.5)
	floor_mi.material_override = floor_mat
	bay_root.add_child(floor_mi)

	var wall_mesh: ArrayMesh = ArchBuilder.build_side_wall_mesh(14.0, 4.4, 4.0)
	var wall_mat: ShaderMaterial = _create_surface_mat(
		config.wall_tex_base,
		Vector2(1.0, 1.0),
		Vector2(1024.0, 572.0),
		Color(0.14, 0.15, 0.28, 1.0),
		Color(0.04, 0.045, 0.10, 1.0),
		Color(1.0, 0.16, 0.62, 1.0),
		0.92
	)
	for wall_spec: Dictionary in [
		{"name": "BackBayWall", "pos": Vector3(0.0, 0.0, -6.2), "rot_y": -PI * 0.5},
		{"name": "LeftAngledWall", "pos": Vector3(-6.4, 0.0, -1.8), "rot_y": -PI * 0.16},
		{"name": "RightAngledWall", "pos": Vector3(6.4, 0.0, -1.8), "rot_y": -PI * 0.84},
	]:
		var w_mi := MeshInstance3D.new()
		w_mi.name = str(wall_spec["name"])
		w_mi.mesh = wall_mesh
		w_mi.position = wall_spec["pos"] as Vector3
		w_mi.rotation = Vector3(0.0, float(wall_spec["rot_y"]), 0.0)
		w_mi.material_override = wall_mat
		bay_root.add_child(w_mi)


func _build_summoner() -> void:
	summoner = SummonerScript.new() as SummonerScript
	summoner.name = "HubGachaSummoner3D"
	summoner.config = config
	add_child(summoner)
	summoner.setup(config)
	summoner.phase_changed.connect(_on_summoner_phase_changed)
	summoner.fakeout_triggered.connect(_on_summoner_fakeout_triggered)
	summoner.burst_triggered.connect(_on_summoner_burst_triggered)
	summoner.reveal_ready.connect(_on_summoner_reveal_ready)
	summoner.camera_shake_requested.connect(_on_camera_shake_requested)
	summoner.bloom_boost_requested.connect(_on_bloom_boost_requested)


func _build_pilot_showcase() -> void:
	var pad_root := Node3D.new()
	pad_root.name = "PilotShowcasePad"
	pad_root.position = Vector3(-2.55, 0.0, 1.35)
	add_child(pad_root)

	# Disco octogonal bajo de exhibición para Valentina
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.03, 0.0), 0.92, 0.92, 0.06, 0.08, 8)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.070, 0.0), 0.78, 0.78, 0.03, 0.05, 8)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.088, 0.0), 0.68, 0.68, 0.014, 0.03, 8)
	for i: int in range(8):
		var a0: float = (PI / 8.0) + TAU * float(i) / 8.0
		var a1: float = (PI / 8.0) + TAU * float(i + 1) / 8.0
		Primitives.add_beam_segment(
			crystal_tris,
			Vector3(cos(a0) * 0.74, 0.092, sin(a0) * 0.74),
			Vector3(cos(a1) * 0.74, 0.092, sin(a1) * 0.74),
			0.018,
			0.010
		)
	var pad_mesh: ArrayMesh = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 0.12, 1)
	var outline_m := ShaderMaterial.new()
	outline_m.shader = OutlineShader
	var pad_mi := MeshInstance3D.new()
	pad_mi.name = "ShowcasePadMesh"
	pad_mi.mesh = pad_mesh
	var pad_cols: Array[Color] = [config.armor_color, config.chassis_color, Color(1.0, 0.16, 0.62, 1.0)]
	for surf_idx: int in range(3):
		var pm := ShaderMaterial.new()
		pm.shader = PropShader
		pm.next_pass = outline_m
		pm.set_shader_parameter("material_kind", surf_idx)
		pm.set_shader_parameter("base_color", pad_cols[surf_idx])
		pm.set_shader_parameter("pilot_accent_color", Color(1.0, 0.16, 0.62, 1.0))
		pad_mi.set_surface_override_material(surf_idx, pm)
	pad_root.add_child(pad_mi)

	pilot_avatar = HubRigAvatar3DScript.new() as HubRigAvatar3DScript
	pilot_avatar.name = "HubRigAvatar3D"
	pilot_avatar.diorama_config = DEFAULT_DIORAMA_CONFIG
	pilot_avatar.position = Vector3(0.0, 0.08, 0.0)
	pad_root.add_child(pilot_avatar)

	var profile: PilotRigProfile = ResourceLoader.load(DEFAULT_DIORAMA_CONFIG.default_profile_path) as PilotRigProfile
	if profile != null:
		pilot_avatar.load_pilot_profile(profile)
	pilot_avatar.set_light_dir_2d(Vector2(0.45, -0.89).normalized())
	pilot_avatar.set_motion_state(Vector2.DOWN, 0.0, Vector2.DOWN, true)

	var sprite3d: Sprite3D = pilot_avatar.get_sprite_3d()
	if sprite3d != null:
		var shadow := Sprite3D.new()
		shadow.name = "PilotShadow"
		shadow.axis = Vector3.AXIS_Y
		shadow.shaded = false
		shadow.pixel_size = sprite3d.pixel_size
		shadow.offset = sprite3d.offset
		shadow.position = Vector3(0.0, 0.095, 0.0)
		shadow.render_priority = 1
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var smat := ShaderMaterial.new()
		smat.shader = SilhouetteShadowShader
		smat.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.0, 0.45))
		smat.set_shader_parameter("texture_albedo", pilot_avatar.get_viewport_texture())
		shadow.texture = pilot_avatar.get_viewport_texture()
		shadow.material_override = smat
		pad_root.add_child(shadow)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	add_child(camera)
	_cam_base_pos = config.idle_cam_pos
	_cam_look_pos = config.idle_cam_look_at
	_cam_fov = config.idle_cam_fov
	_apply_camera_transform(true)


func _build_session_and_overlay() -> void:
	session = SessionScript.new() as SessionScript
	session.setup(config)

	overlay = OverlayScript.new() as OverlayScript
	overlay.name = "Gacha3DLabOverlay"
	add_child(overlay)
	overlay.setup(config)

	overlay.banner_selected.connect(select_banner)
	overlay.pull_requested.connect(func(cnt: int) -> void: request_pull(cnt))
	overlay.refill_tokens_requested.connect(_on_refill_tokens)
	overlay.override_changed.connect(_on_override_changed)
	overlay.skip_requested.connect(request_skip)
	overlay.equip_reward_requested.connect(_on_equip_reward_requested)
	overlay.reveal_closed.connect(close_reveal)
	overlay.reset_requested.connect(_on_reset_session)
	overlay.open_hub_art_lab_requested.connect(_open_hub_art_lab)
	overlay.back_to_workbench_requested.connect(_return_to_workbench)


func _process(delta: float) -> void:
	_update_camera(delta)
	_update_bloom(delta)
	if summoner != null and summoner.get_phase() in [
		SummonerScript.SequencePhase.FRAMING,
		SummonerScript.SequencePhase.CHARGING,
		SummonerScript.SequencePhase.TENSION,
		SummonerScript.SequencePhase.BLOOM_BURST,
	]:
		if overlay != null:
			overlay.update_cinematic_status(_format_phase_prompt(summoner.get_phase()), summoner.can_skip())


func _unhandled_input(event: InputEvent) -> void:
	var key_ev := event as InputEventKey
	if key_ev == null or not key_ev.pressed or key_ev.echo:
		return
	match key_ev.keycode:
		KEY_1:
			select_banner("general")
		KEY_2:
			select_banner("ships")
		KEY_3:
			select_banner("pilots")
		KEY_Q:
			request_pull(1)
		KEY_W:
			request_pull(5)
		KEY_E:
			request_pull(10)
		KEY_SPACE:
			request_skip()
		KEY_ESCAPE:
			if overlay != null and overlay.is_reveal_visible():
				close_reveal()
			else:
				request_skip()
		KEY_H:
			if overlay != null:
				overlay.toggle_sandbox_panel()


func select_banner(banner_id: String) -> void:
	if summoner != null and summoner.get_phase() != SummonerScript.SequencePhase.IDLE:
		return
	session.set_active_banner_id(banner_id)
	if summoner != null:
		summoner.set_banner(session.get_active_banner_id())
	_sync_overlay_session_status()


func request_pull(count: int, override_mode_override: int = -1) -> Dictionary:
	if summoner != null and summoner.get_phase() != SummonerScript.SequencePhase.IDLE:
		return {"ok": false, "error": "busy"}
	var eff_override: SessionScript.PullOverride = _override_mode
	if override_mode_override >= 0:
		eff_override = override_mode_override as SessionScript.PullOverride

	var batch: Dictionary = session.execute_pull_batch(session.get_active_banner_id(), count, eff_override)
	if not bool(batch.get("ok", false)):
		_sync_overlay_session_status("Saldo insuficiente — usa [+20 Fichas]")
		return batch

	_last_batch = batch
	_cam_state = CamState.CINEMATIC
	if overlay != null:
		overlay.set_cinematic_mode(_format_phase_prompt(SummonerScript.SequencePhase.FRAMING), false)
	if summoner != null:
		summoner.start_sequence(batch)
	_sync_overlay_session_status()
	return batch


func request_skip() -> bool:
	if summoner == null:
		return false
	if not summoner.can_skip():
		return false
	return summoner.skip_to_reveal()


func equip_selected_reward() -> Dictionary:
	if overlay == null:
		return {"ok": false}
	var reward: Dictionary = overlay.get_selected_reward()
	return _equip_reward(reward)


func close_reveal() -> void:
	_cam_state = CamState.IDLE_BAY
	if summoner != null:
		summoner.reset_to_idle()
	if overlay != null:
		overlay.set_standby_mode()
	_sync_overlay_session_status()


func _equip_reward(reward: Dictionary) -> Dictionary:
	if reward.is_empty():
		return {"ok": false}
	var skin_data: Dictionary = reward.get("skin_data", {}) as Dictionary
	var stars: int = int(reward.get("new_stars", 1))
	var eq_res: Dictionary = session.equip_pulled_skin(skin_data, stars)
	if not bool(eq_res.get("ok", false)):
		return eq_res

	var cat: String = str(eq_res.get("category", ""))
	var preset: PilotSkinPreset = eq_res.get("preset", null) as PilotSkinPreset
	if pilot_avatar != null:
		var rig: PlanarCombatRig = pilot_avatar.get_rig()
		if cat == "pilot" and preset != null:
			pilot_avatar.apply_skin_preset(preset, stars)
			if rig != null:
				rig.set_3d_wings_enabled(false)
		elif (cat == "wings" or cat == "ship") and preset != null:
			if rig != null:
				rig.set_3d_wings_enabled(true)
				rig.apply_wings_skin_preset(preset, stars)
				rig.set_3d_wings_anim_state(AstralWings3DScript.AnimState.IDLE_ZERO_G, false)
				rig.trigger_3d_wings_pulse()

	_sync_overlay_session_status("Equipado en vivo: %s" % str(eq_res.get("skin_name", "")))
	return eq_res


func _on_equip_reward_requested(reward_item: Dictionary) -> void:
	_equip_reward(reward_item)


func _on_summoner_phase_changed(new_phase: int) -> void:
	match new_phase:
		SummonerScript.SequencePhase.FRAMING, SummonerScript.SequencePhase.CHARGING, SummonerScript.SequencePhase.TENSION:
			_cam_state = CamState.CINEMATIC
		SummonerScript.SequencePhase.BLOOM_BURST, SummonerScript.SequencePhase.REVEAL:
			_cam_state = CamState.BURST_REVEAL
		_:
			_cam_state = CamState.IDLE_BAY


func _on_summoner_fakeout_triggered() -> void:
	if overlay != null:
		overlay.show_fakeout_banner()


func _on_summoner_burst_triggered(_is_epic: bool) -> void:
	_cam_state = CamState.BURST_REVEAL


func _on_summoner_reveal_ready(batch: Dictionary) -> void:
	_cam_state = CamState.BURST_REVEAL
	if overlay != null:
		overlay.show_reveal(batch)


func _on_camera_shake_requested(amount: float) -> void:
	_shake_strength = maxf(_shake_strength, amount)


func _on_bloom_boost_requested(bloom_val: float) -> void:
	_current_bloom = maxf(_current_bloom, bloom_val)


func _on_refill_tokens() -> void:
	session.add_tokens(config.sandbox_refill_amount)
	_sync_overlay_session_status("+%d fichas recargadas" % config.sandbox_refill_amount)


func _on_override_changed(override_idx: int) -> void:
	_override_mode = clampi(override_idx, 0, 4) as SessionScript.PullOverride
	_sync_overlay_session_status()


func _on_reset_session() -> void:
	session.reset_session()
	if summoner != null:
		summoner.set_banner(session.get_active_banner_id())
		summoner.reset_to_idle()
	if pilot_avatar != null:
		var rig: PlanarCombatRig = pilot_avatar.get_rig()
		if rig != null:
			rig.set_3d_wings_enabled(false)
			var base_p: PilotSkinPreset = rig.pilot_profile.skins[0] if (rig.pilot_profile != null and not rig.pilot_profile.skins.is_empty()) else null
			if base_p != null:
				pilot_avatar.apply_skin_preset(base_p, 1)
	if overlay != null:
		overlay.set_standby_mode()
	_sync_overlay_session_status("Sesión simulada reiniciada")


func _open_hub_art_lab() -> void:
	if ResourceLoader.exists(HUB_ART_LAB_PATH) and get_tree() != null:
		get_tree().change_scene_to_file(HUB_ART_LAB_PATH)


func _return_to_workbench() -> void:
	if ResourceLoader.exists(WORKBENCH_HUB_PATH) and get_tree() != null:
		get_tree().change_scene_to_file(WORKBENCH_HUB_PATH)


func _sync_overlay_session_status(note: String = "") -> void:
	if overlay == null or session == null:
		return
	var phase_names: Array[String] = ["IDLE", "FRAMING", "CHARGING", "TENSION", "BLOOM_BURST", "REVEAL"]
	var p_idx: int = clampi(int(summoner.get_phase()) if summoner != null else 0, 0, phase_names.size() - 1)
	var info: String = "Fase: %s  |  [1..3] Banner  [Q/W/E] ×1/×5/×10" % phase_names[p_idx]
	if not note.is_empty():
		info = note
	overlay.sync_session_status(
		session.get_tokens(),
		session.get_active_banner_id(),
		session.get_pity(session.get_active_banner_id()),
		session.get_equipped_summary(),
		info
	)


func _format_phase_prompt(phase: int) -> String:
	match phase:
		SummonerScript.SequencePhase.FRAMING:
			return "FASE 1/5 — SINCRONIZANDO ANILLOS GIROSCÓPICOS..."
		SummonerScript.SequencePhase.CHARGING:
			return "FASE 2/5 — ACELERACIÓN ECUATORIAL Y CARGA HDR..."
		SummonerScript.SequencePhase.TENSION:
			return "FASE 3/5 — PUNTO CRÍTICO DE CONTENCIÓN..."
		SummonerScript.SequencePhase.BLOOM_BURST:
			return "FASE 4/5 — APERTURA EN FLOR Y ESTALLIDO ASTRAL"
		_:
			return "INVOCACIÓN COMPLETADA"


func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var target_pos: Vector3 = config.idle_cam_pos
	var target_look: Vector3 = config.idle_cam_look_at
	var target_fov: float = config.idle_cam_fov
	match _cam_state:
		CamState.CINEMATIC:
			target_pos = config.cinematic_cam_pos
			target_look = config.cinematic_cam_look_at
			target_fov = config.cinematic_cam_fov
		CamState.BURST_REVEAL:
			target_pos = config.burst_cam_pos
			target_look = config.cinematic_cam_look_at
			target_fov = config.burst_cam_fov

	var w: float = clampf(config.camera_smooth * delta, 0.0, 1.0)
	_cam_base_pos = _cam_base_pos.lerp(target_pos, w)
	_cam_look_pos = _cam_look_pos.lerp(target_look, w)
	_cam_fov = lerpf(_cam_fov, target_fov, w)

	_shake_strength = move_toward(_shake_strength, 0.0, config.shake_decay * delta)
	_apply_camera_transform(false)


func _apply_camera_transform(snap: bool) -> void:
	if camera == null:
		return
	var shake_off := Vector3.ZERO
	if not snap and _shake_strength > 0.0005:
		shake_off = Vector3(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength),
			0.0
		)
	var final_pos: Vector3 = _cam_base_pos + shake_off
	if camera.is_inside_tree():
		camera.look_at_from_position(final_pos, _cam_look_pos, Vector3.UP)
	else:
		camera.position = final_pos
	camera.fov = _cam_fov


func _update_bloom(delta: float) -> void:
	_current_bloom = move_toward(_current_bloom, config.bloom_idle, delta * 1.45)
	if _world_env != null and _world_env.environment != null:
		_world_env.environment.glow_intensity = _current_bloom


func _create_surface_mat(
	base_path: String,
	uv_sc: Vector2,
	native_sz: Vector2,
	plate_tint: Color,
	chassis_tint: Color,
	accent_col: Color,
	tile_emit: float
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SurfaceShader
	var tex_alb: Texture2D = TextureLoader.load_texture_2d(base_path + ".png", true)
	var tex_id: Texture2D = TextureLoader.load_texture_2d(base_path + "_id_mask.png", false)
	var tex_ilm: Texture2D = TextureLoader.load_texture_2d(base_path + "_ilm_mask.png", true)
	var tex_sdf: Texture2D = TextureLoader.load_texture_2d(base_path + "_ink_sdf.png", false)
	var has_all: bool = (tex_alb != null and tex_id != null and tex_ilm != null and tex_sdf != null)
	mat.set_shader_parameter("has_maps", has_all)
	if has_all:
		mat.set_shader_parameter("albedo_tex", tex_alb)
		mat.set_shader_parameter("id_mask_tex", tex_id)
		mat.set_shader_parameter("ilm_mask_tex", tex_ilm)
		mat.set_shader_parameter("ink_sdf_tex", tex_sdf)
	mat.set_shader_parameter("uv_scale", uv_sc)
	mat.set_shader_parameter("tex_native_size", native_sz)
	mat.set_shader_parameter("wing_plate_tint", plate_tint)
	mat.set_shader_parameter("wing_chassis_tint", chassis_tint)
	mat.set_shader_parameter("pilot_accent_color", accent_col)
	mat.set_shader_parameter("enable_deck_zoning", false)
	mat.set_shader_parameter("tile_emissive_mult", tile_emit)
	mat.set_shader_parameter("ambient_fill", 0.34)
	return mat
