class_name HubEastWingController
extends Node3D

## Controlador modular del Ala Este — Psycho-Pop Neón (#0D0E1A / #FF1493 / #00F0FF / #FFD54F).
## Reúne:
## - Invocador Giroscópico Astral 3D (reutiliza HubGachaSummoner3D + Gacha3DSessionController + Gacha3DLabOverlay)
## - Tótem de Telemetría (pantalla holográfica Ink/HUD -> HighscoresModal)
## - Lounge Antigravedad de Mascotas (3 pads flotantes + paseo en lounge para no equipadas + seguimiento al jugador)

signal gacha_focus_requested(world_pos: Vector3)
signal gacha_focus_exited()
signal telemetry_requested(world_pos: Vector3)
signal camera_shake_requested(amount: float)
signal bloom_boost_requested(bloom_val: float)
signal skin_equipped_live(equip_res: Dictionary)

const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_art_lab_config.gd")
const GachaConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_gacha_3d_config.gd")
const DEFAULT_GACHA_CONFIG: GachaConfigScript = preload("res://data/hub/default_hub_gacha_3d_config.tres")
const SummonerScript = preload("res://scenes/ui/hub/astral_station/components/hub_gacha_summoner_3d.gd")
const SessionScript = preload("res://scenes/ui/hub/astral_station/components/gacha_3d_session_controller.gd")
const OverlayScript = preload("res://scenes/ui/hub/astral_station/components/gacha_3d_lab_overlay.gd")
const EastMeshBuilder = preload("res://scenes/ui/hub/astral_station/meshes/hub_east_wing_mesh_builder.gd")
const WestMeshBuilder = preload("res://scenes/ui/hub/astral_station/meshes/hub_west_sanctuary_mesh_builder.gd")
const Primitives = preload("res://scenes/ui/hub/astral_station/meshes/hub_arcsys_mesh_primitives.gd")
const IslandsBuilder = preload("res://scenes/ui/hub/astral_station/meshes/hub_floating_islands_mesh_builder.gd")
const PropShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_arcsys_prop_3d.gdshader")
const OutlineShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_arcsys_outline_3d.gdshader")
const HoloScreenShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_console_holo_screen.gdshader")
const CircleShadowShader = preload("res://shaders/retro_circle_shadow.gdshader")
const PetDataScript = preload("res://data/pets/pet_data.gd")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")
const CosmeticsManagerScript = preload("res://core/systems/cosmetics_manager.gd")

const COLOR_PSYCHOPOP_ARMOR := Color(0.24, 0.28, 0.44, 1.0)
const COLOR_PSYCHOPOP_CHASSIS := Color(0.055, 0.060, 0.125, 1.0)
const COLOR_PSYCHOPOP_PINK := Color(1.0, 0.14, 0.58, 1.0)
const COLOR_PSYCHOPOP_CYAN := Color(0.05, 0.94, 1.0, 1.0)
const PET_ORBIT_RADIUS: float = 4.15

var _config: ConfigScript = null
var _gacha_config: GachaConfigScript = DEFAULT_GACHA_CONFIG
var _is_built: bool = false
var _is_gacha_open: bool = false
var _time_acc: float = 0.0

var summoner: SummonerScript = null
var gacha_session: SessionScript = null
var gacha_overlay: OverlayScript = null

var _gacha_area: Area3D = null
var _gacha_label: Label3D = null
var _totem_root: Node3D = null
var _totem_area: Area3D = null
var _totem_label: Label3D = null
var _totem_screen_mat: ShaderMaterial = null

var _outline_mat: ShaderMaterial = null
var _prop_mats: Array[ShaderMaterial] = []
var _lounge_pads: Array[MeshInstance3D] = []
var _beacon_entries: Array[Dictionary] = []

var _player_follow_target: Node3D = null
var _followed_pet_node: Node3D = null
var _followed_pet_sprite: Sprite3D = null
var _followed_pet_id: StringName = &""
var _lounge_pet_entries: Array[Dictionary] = []


func setup(p_config: ConfigScript, p_player_target: Node3D = null) -> void:
	_config = p_config
	_player_follow_target = p_player_target
	_ensure_built()
	refresh_pets(p_player_target)


func _ensure_built() -> void:
	if _is_built or _config == null:
		return

	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = OutlineShader
	_outline_mat.set_shader_parameter("outline_width", _config.outline_width)
	_outline_mat.set_shader_parameter("reference_distance", _config.outline_ref_distance)

	var surf_colors: Array[Color] = [COLOR_PSYCHOPOP_ARMOR, COLOR_PSYCHOPOP_CHASSIS, COLOR_PSYCHOPOP_PINK]
	_prop_mats.clear()
	for i: int in range(3):
		var mat := ShaderMaterial.new()
		mat.shader = PropShader
		mat.next_pass = _outline_mat
		mat.set_shader_parameter("material_kind", i)
		mat.set_shader_parameter("base_color", surf_colors[i])
		mat.set_shader_parameter("pilot_accent_color", COLOR_PSYCHOPOP_CYAN if i == 2 else COLOR_PSYCHOPOP_PINK)
		mat.set_shader_parameter("crease_ink_strength", _config.crease_ink_strength)
		mat.set_shader_parameter("emissive_boost", _config.emissive_boost)
		mat.set_shader_parameter("ambient_fill", 0.30)
		_prop_mats.append(mat)

	_build_gacha_summoner()
	_build_east_gacha_beacons()
	_build_telemetry_totem()
	_is_built = true


func _build_gacha_summoner() -> void:
	var gacha_holder := Node3D.new()
	gacha_holder.name = "EastGachaSummonerRoot"
	gacha_holder.position = _config.gacha_summoner_pos
	gacha_holder.rotation = Vector3(0.0, deg_to_rad(-28.0), 0.0)
	add_child(gacha_holder)

	summoner = SummonerScript.new() as SummonerScript
	summoner.name = "HubGachaSummoner3D"
	summoner.config = _gacha_config
	summoner.scale = Vector3(0.84, 0.84, 0.84)
	gacha_holder.add_child(summoner)
	summoner.setup(_gacha_config)
	summoner.phase_changed.connect(_on_summoner_phase_changed)
	summoner.fakeout_triggered.connect(_on_summoner_fakeout)
	summoner.burst_triggered.connect(_on_summoner_burst)
	summoner.reveal_ready.connect(_on_summoner_reveal_ready)
	summoner.camera_shake_requested.connect(func(amt: float) -> void: camera_shake_requested.emit(amt))
	summoner.bloom_boost_requested.connect(func(b: float) -> void: bloom_boost_requested.emit(b))

	var body := StaticBody3D.new()
	body.name = "GachaSummonerCollider"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.48
	cyl.height = 2.2
	cs.shape = cyl
	cs.position = Vector3(0.0, 1.1, 0.0)
	body.add_child(cs)
	gacha_holder.add_child(body)

	_gacha_area = _create_trigger_area("GachaInteractArea", Vector3(0.0, 0.9, 0.0), 2.55)
	gacha_holder.add_child(_gacha_area)

	_gacha_label = _create_prompt_label("GachaPromptLabel", Vector3(0.0, 3.05, 0.0), "[E] INVOCADOR GACHA 3D")
	gacha_holder.add_child(_gacha_label)

	gacha_session = SessionScript.new() as SessionScript
	gacha_session.setup(_gacha_config)

	gacha_overlay = OverlayScript.new() as OverlayScript
	gacha_overlay.name = "EastGachaOverlay"
	add_child(gacha_overlay)
	gacha_overlay.setup(_gacha_config)
	gacha_overlay.set_station_clean_mode(true)
	gacha_overlay.visible = false
	_wire_gacha_overlay()
	_sync_gacha_overlay_status()


func _wire_gacha_overlay() -> void:
	if gacha_overlay == null:
		return
	gacha_overlay.banner_selected.connect(func(bid: String) -> void:
		gacha_session.set_active_banner_id(bid)
		if summoner != null:
			summoner.set_banner(bid)
		_sync_gacha_overlay_status()
	)
	gacha_overlay.pull_requested.connect(_on_gacha_pull_requested)
	gacha_overlay.refill_tokens_requested.connect(func() -> void:
		gacha_session.add_tokens(30)
		_sync_gacha_overlay_status()
	)
	gacha_overlay.skip_requested.connect(func() -> void:
		if summoner != null:
			summoner.request_skip()
	)
	gacha_overlay.equip_reward_requested.connect(func(reward_item: Dictionary) -> void:
		var skin_dict: Dictionary = reward_item.get("skin_data", {}) as Dictionary
		var stars: int = int(reward_item.get("new_stars", 1))
		var equip_res: Dictionary = gacha_session.equip_pulled_skin(skin_dict, stars)
		if bool(equip_res.get("ok", false)):
			var fb_note: String = "Equipado en vivo: %s (%s)" % [str(equip_res.get("skin_name", "")), str(equip_res.get("slot_key", ""))]
			_sync_gacha_overlay_status(fb_note)
			skin_equipped_live.emit(equip_res)
	)
	gacha_overlay.reveal_closed.connect(func() -> void:
		if summoner != null:
			summoner.reset_to_idle()
		bloom_boost_requested.emit(_config.bloom_intensity if _config != null else 0.72)
		if _is_gacha_open:
			gacha_overlay.set_standby_mode()
			_sync_gacha_overlay_status()
	)
	gacha_overlay.reset_requested.connect(func() -> void:
		gacha_session.reset_session()
		if summoner != null:
			summoner.set_banner(gacha_session.get_active_banner_id())
			summoner.reset_to_idle()
		_sync_gacha_overlay_status()
	)
	gacha_overlay.back_to_workbench_requested.connect(close_gacha_station)
	gacha_overlay.open_hub_art_lab_requested.connect(close_gacha_station)


func _on_gacha_pull_requested(count: int) -> void:
	if summoner == null or summoner.is_sequence_active():
		return
	var bid: String = gacha_session.get_active_banner_id()
	var batch: Dictionary = gacha_session.execute_pull_batch(bid, count, SessionScript.PullOverride.NATURAL)
	if not bool(batch.get("ok", false)):
		return
	_sync_gacha_overlay_status()
	gacha_overlay.set_cinematic_mode(_format_phase_prompt(SummonerScript.SequencePhase.FRAMING), false)
	summoner.start_pull_sequence(batch)


func _on_summoner_phase_changed(new_phase: int) -> void:
	if gacha_overlay == null or not _is_gacha_open:
		return
	var can_skip_now: bool = summoner != null and summoner.can_skip()
	gacha_overlay.update_cinematic_status(_format_phase_prompt(new_phase), can_skip_now)


func _on_summoner_fakeout() -> void:
	if gacha_overlay != null and _is_gacha_open:
		gacha_overlay.show_fakeout_banner()
		var can_skip_now: bool = summoner != null and summoner.can_skip()
		gacha_overlay.update_cinematic_status("SELLO QUEBRADO // OVERRIDE ÉPICO", can_skip_now)


func _on_summoner_burst(_is_epic: bool) -> void:
	pass


func _on_summoner_reveal_ready(batch: Dictionary) -> void:
	if gacha_overlay != null and _is_gacha_open:
		gacha_overlay.show_reveal(batch)


func _sync_gacha_overlay_status(note: String = "") -> void:
	if gacha_overlay == null or gacha_session == null:
		return
	var bid: String = gacha_session.get_active_banner_id()
	gacha_overlay.sync_session_status(
		gacha_session.get_tokens(),
		bid,
		gacha_session.get_pity(bid),
		gacha_session.get_equipped_summary(),
		note
	)


func _format_phase_prompt(phase: int) -> String:
	match phase:
		SummonerScript.SequencePhase.FRAMING:
			return "FASE 1/5 — SINCRONIZANDO ANILLOS GIROSCÓPICOS..."
		SummonerScript.SequencePhase.CHARGING:
			return "FASE 2/5 — ALINEACIÓN GIROSCÓPICA Y CARGA HDR..."
		SummonerScript.SequencePhase.TENSION:
			return "FASE 3/5 — SELLADO CRISTALINO AL MÁXIMO..."
		SummonerScript.SequencePhase.BLOOM_BURST:
			return "FASE 4/5 — APERTURA EN FLOR // ESTALLIDO HDR"
		_:
			return "INVOCACIÓN COMPLETADA"


func _build_telemetry_totem() -> void:
	_totem_root = Node3D.new()
	_totem_root.name = "EastTelemetryTotem"
	_totem_root.position = _config.telemetry_totem_pos
	_totem_root.rotation = Vector3(0.0, deg_to_rad(-34.0), 0.0)
	add_child(_totem_root)

	var body_mi := MeshInstance3D.new()
	body_mi.name = "TelemetryTotemMesh"
	body_mi.mesh = EastMeshBuilder.build_telemetry_totem_mesh()
	body_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for s_idx: int in range(3):
		body_mi.set_surface_override_material(s_idx, _prop_mats[s_idx])
	_totem_root.add_child(body_mi)

	_totem_screen_mat = ShaderMaterial.new()
	_totem_screen_mat.shader = HoloScreenShader
	_totem_screen_mat.set_shader_parameter("screen_color", COLOR_PSYCHOPOP_CYAN)
	_totem_screen_mat.set_shader_parameter("gold_color", Color(1.0, 0.84, 0.30, 1.0))
	_totem_screen_mat.set_shader_parameter("calibration_factor", 0.0)
	_totem_screen_mat.set_shader_parameter("pulse_boost", 0.35)

	var screen_quad := QuadMesh.new()
	screen_quad.size = Vector2(0.84, 1.18)
	var screen_mi := MeshInstance3D.new()
	screen_mi.name = "TelemetryHoloScreen"
	screen_mi.mesh = screen_quad
	screen_mi.position = Vector3(0.0, 1.56, 0.25)
	screen_mi.material_override = _totem_screen_mat
	screen_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_totem_root.add_child(screen_mi)

	var col_body := StaticBody3D.new()
	col_body.name = "TelemetryTotemCollider"
	col_body.collision_layer = 1
	col_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.35, 2.8, 0.92)
	cs.shape = box
	cs.position = Vector3(0.0, 1.4, 0.0)
	col_body.add_child(cs)
	_totem_root.add_child(col_body)

	_totem_area = _create_trigger_area("TelemetryInteractArea", Vector3(0.0, 1.0, 0.35), 2.35)
	_totem_root.add_child(_totem_area)

	_totem_label = _create_prompt_label("TelemetryPromptLabel", Vector3(0.0, 3.25, 0.0), "[E] TÓTEM DE TELEMETRÍA")
	_totem_root.add_child(_totem_label)


func _build_east_gacha_beacons() -> void:
	_lounge_pads.clear()
	_beacon_entries.clear()
	if _config == null:
		return

	var beacon_root := Node3D.new()
	beacon_root.name = "EastGachaPrismaticBeacons"
	add_child(beacon_root)

	var rarity_cols: Array[Color] = [
		Color(0.14, 0.94, 1.0, 1.0),
		Color(0.24, 1.0, 0.72, 1.0),
		Color(1.0, 0.84, 0.30, 1.0),
		Color(1.0, 0.16, 0.62, 1.0),
		Color(0.68, 0.36, 1.0, 1.0),
	]
	var crystal_mesh: ArrayMesh = _build_prismatic_crystal_mesh()
	var inner_ring_mesh: ArrayMesh = WestMeshBuilder.build_relic_orbit_ring_mesh(0.42)
	var outer_ring_mesh: ArrayMesh = WestMeshBuilder.build_relic_orbit_ring_mesh(0.58)
	var tether_mesh := CylinderMesh.new()
	tether_mesh.top_radius = 0.016
	tether_mesh.bottom_radius = 0.036
	tether_mesh.height = 1.05
	tether_mesh.radial_segments = 10
	var halo_torus := TorusMesh.new()
	halo_torus.inner_radius = 0.42
	halo_torus.outer_radius = 0.48
	halo_torus.rings = 24
	halo_torus.ring_segments = 8

	var positions: Array[Vector3] = _config.east_gacha_beacon_positions
	for i: int in range(positions.size()):
		var b_pos: Vector3 = positions[i]
		var col: Color = rarity_cols[i % rarity_cols.size()]

		var holder := Node3D.new()
		holder.name = "GachaBeacon_%d" % i
		holder.position = b_pos
		beacon_root.add_child(holder)

		var c_mat := ShaderMaterial.new()
		c_mat.shader = PropShader
		c_mat.next_pass = _outline_mat
		c_mat.set_shader_parameter("material_kind", 2)
		c_mat.set_shader_parameter("base_color", col)
		c_mat.set_shader_parameter("pilot_accent_color", col)
		c_mat.set_shader_parameter("use_pilot_accent", false)
		c_mat.set_shader_parameter("emissive_boost", _config.emissive_boost * 1.15)

		var ring_armor_mat := ShaderMaterial.new()
		ring_armor_mat.shader = PropShader
		ring_armor_mat.next_pass = _outline_mat
		ring_armor_mat.set_shader_parameter("material_kind", 0)
		ring_armor_mat.set_shader_parameter("base_color", COLOR_PSYCHOPOP_ARMOR)
		ring_armor_mat.set_shader_parameter("pilot_accent_color", col)

		var cradle_mi := MeshInstance3D.new()
		cradle_mi.name = "BeaconCradle"
		cradle_mi.mesh = EastMeshBuilder.build_pet_lounge_pad_mesh()
		cradle_mi.position = Vector3(0.0, -0.34, 0.0)
		cradle_mi.scale = Vector3(0.55, 0.40, 0.55)
		cradle_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s_idx: int in range(3):
			cradle_mi.set_surface_override_material(s_idx, _prop_mats[s_idx])
		holder.add_child(cradle_mi)

		var tether_mi := MeshInstance3D.new()
		tether_mi.name = "BeaconTether"
		tether_mi.mesh = tether_mesh
		tether_mi.position = Vector3(0.0, 0.44, 0.0)
		tether_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tether_mi.set_surface_override_material(0, c_mat)
		holder.add_child(tether_mi)

		var halo_mi := MeshInstance3D.new()
		halo_mi.name = "BeaconHalo"
		halo_mi.mesh = halo_torus
		halo_mi.position = Vector3(0.0, 0.14, 0.0)
		halo_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo_mi.set_surface_override_material(0, c_mat)
		holder.add_child(halo_mi)

		var crystal_pivot := Node3D.new()
		crystal_pivot.name = "BeaconCrystalPivot"
		crystal_pivot.position = Vector3(0.0, 1.06, 0.0)
		holder.add_child(crystal_pivot)

		var crystal_mi := MeshInstance3D.new()
		crystal_mi.name = "BeaconCrystal"
		crystal_mi.mesh = crystal_mesh
		crystal_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		crystal_mi.set_surface_override_material(0, c_mat)
		crystal_pivot.add_child(crystal_mi)

		var in_ring_mi := MeshInstance3D.new()
		in_ring_mi.name = "BeaconInnerOrbit"
		in_ring_mi.mesh = inner_ring_mesh
		in_ring_mi.rotation_degrees = Vector3(26.0, 0.0, 18.0)
		in_ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		in_ring_mi.set_surface_override_material(0, ring_armor_mat)
		in_ring_mi.set_surface_override_material(1, _prop_mats[1])
		in_ring_mi.set_surface_override_material(2, c_mat)
		crystal_pivot.add_child(in_ring_mi)

		var out_ring_mi := MeshInstance3D.new()
		out_ring_mi.name = "BeaconOuterOrbit"
		out_ring_mi.mesh = outer_ring_mesh
		out_ring_mi.rotation_degrees = Vector3(-28.0, 0.0, -22.0)
		out_ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out_ring_mi.set_surface_override_material(0, ring_armor_mat)
		out_ring_mi.set_surface_override_material(1, _prop_mats[1])
		out_ring_mi.set_surface_override_material(2, c_mat)
		crystal_pivot.add_child(out_ring_mi)

		_beacon_entries.append({
			"pivot": crystal_pivot,
			"crystal": crystal_mi,
			"inner_ring": in_ring_mi,
			"outer_ring": out_ring_mi,
			"halo": halo_mi,
			"mat": c_mat,
			"base_y": 1.06,
			"phase": float(i) * 1.15,
		})


static func _build_prismatic_crystal_mesh() -> ArrayMesh:
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []
	var r0: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, -0.38, 0.0), 0.02, 0.02, 6, 0.0)
	var r1: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, 0.0, 0.0), 0.22, 0.22, 6, 0.0)
	var r2: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, 0.42, 0.0), 0.02, 0.02, 6, 0.0)
	Primitives.add_loft(crystal_tris, [r0, r1, r2], true, true, Vector3.ZERO)
	return Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -0.4, 0.45, 1)


func refresh_pets(p_player_target: Node3D = null) -> void:
	if p_player_target != null:
		_player_follow_target = p_player_target

	if _followed_pet_node != null and is_instance_valid(_followed_pet_node):
		_followed_pet_node.queue_free()
		_followed_pet_node = null
		_followed_pet_sprite = null

	for entry: Dictionary in _lounge_pet_entries:
		var node: Node3D = entry.get("node", null) as Node3D
		if node != null and is_instance_valid(node):
			node.queue_free()
	_lounge_pet_entries.clear()

	var roster: Array[PetData] = PetDataScript.load_roster_ordered()
	var selected_id: StringName = SaveManagerScript.get_selected_pet()
	_followed_pet_id = selected_id

	var orbit_center: Vector3 = _config.console_right_pos if _config != null else Vector3(-10.20, 0.0, 10.20)
	var orb_idx: int = 0
	for p_data: PetData in roster:
		if p_data == null:
			continue
		if not SaveManagerScript.is_pet_unlocked(p_data.pet_id):
			continue

		if p_data.pet_id == selected_id and _player_follow_target != null:
			var follower: Dictionary = _create_pet_visual_node(p_data, "ActiveCompanionPet")
			_followed_pet_node = follower["node"] as Node3D
			_followed_pet_sprite = follower["sprite"] as Sprite3D
			_followed_pet_node.position = _player_follow_target.global_position + Vector3(-1.1, 0.04, 0.8)
			add_child(_followed_pet_node)
		else:
			var orb_pet: Dictionary = _create_pet_visual_node(p_data, "OrbitPet_%s" % str(p_data.pet_id), true)
			var lp_node: Node3D = orb_pet["node"] as Node3D
			var init_ang: float = float(orb_idx) * 2.1
			lp_node.position = orbit_center + Vector3(cos(init_ang) * PET_ORBIT_RADIUS, 0.55, sin(init_ang) * PET_ORBIT_RADIUS)
			add_child(lp_node)
			_lounge_pet_entries.append({
				"node": lp_node,
				"sprite": orb_pet["sprite"],
				"center": orbit_center,
				"angle_offset": init_ang,
				"phase": float(orb_idx) * 1.35,
			})
			orb_idx += 1


func _create_pet_visual_node(p_data: PetData, node_name: String, with_orbit_ring: bool = false) -> Dictionary:
	var root := Node3D.new()
	root.name = node_name

	var sprite := Sprite3D.new()
	sprite.name = "PetSprite"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.render_priority = 2
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sprite)

	var tex: Texture2D = p_data.get_icon_texture()
	var pid_str: String = String(p_data.pet_id).to_lower()
	var slot_key: String = "pet:" + pid_str
	var eq_skin: String = SaveManagerScript.get_equipped_skin(slot_key)
	if not eq_skin.is_empty() and SaveManagerScript.is_skin_unlocked(eq_skin):
		var stars: int = SaveManagerScript.get_skin_stars(eq_skin)
		CosmeticsManagerScript.apply_skin_to_sprite3d(sprite, eq_skin, stars)
		if sprite.texture != null:
			tex = sprite.texture
	else:
		sprite.texture = tex
		sprite.material_override = null

	var tex_h: float = float(tex.get_height()) if is_instance_valid(tex) else 64.0
	sprite.pixel_size = 0.011 * (64.0 / maxf(1.0, tex_h))
	sprite.offset = Vector2(0.0, tex_h * 0.5)

	if with_orbit_ring:
		var halo := TorusMesh.new()
		halo.inner_radius = 0.34
		halo.outer_radius = 0.38
		halo.rings = 24
		halo.ring_segments = 8
		var halo_mi := MeshInstance3D.new()
		halo_mi.name = "PetOrbitHalo"
		halo_mi.mesh = halo
		halo_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var h_mat := ShaderMaterial.new()
		h_mat.shader = PropShader
		h_mat.set_shader_parameter("material_kind", 2)
		h_mat.set_shader_parameter("base_color", Color(0.24, 0.96, 0.78, 1.0))
		h_mat.set_shader_parameter("pilot_accent_color", Color(0.24, 0.96, 0.78, 1.0))
		h_mat.set_shader_parameter("emissive_boost", 1.8)
		halo_mi.set_surface_override_material(0, h_mat)
		root.add_child(halo_mi)
	else:
		var shadow := MeshInstance3D.new()
		shadow.name = "PetShadow"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.50, 0.50)
		quad.orientation = PlaneMesh.FACE_Y
		shadow.mesh = quad
		var sh_mat := ShaderMaterial.new()
		sh_mat.shader = CircleShadowShader
		sh_mat.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.0, 0.42))
		sh_mat.set_shader_parameter("edge_sharpness", 0.015)
		shadow.material_override = sh_mat
		shadow.position = Vector3(0.0, 0.012, 0.0)
		root.add_child(shadow)

	return {"node": root, "sprite": sprite}


func _process(delta: float) -> void:
	_time_acc += delta
	var is_summon_active: bool = summoner != null and summoner.get_phase() != SummonerScript.SequencePhase.IDLE and summoner.get_phase() != SummonerScript.SequencePhase.REVEAL
	if _is_gacha_open and is_summon_active and gacha_overlay != null:
		gacha_overlay.update_cinematic_status(_format_phase_prompt(summoner.get_phase()), summoner.can_skip())

	var gacha_boost: float = 2.4 if is_summon_active else 1.15
	var spin_mult: float = 2.4 if is_summon_active else 1.0
	for b_entry: Dictionary in _beacon_entries:
		var piv: Node3D = b_entry.get("pivot", null) as Node3D
		var c_mi: MeshInstance3D = b_entry.get("crystal", null) as MeshInstance3D
		var in_r: MeshInstance3D = b_entry.get("inner_ring", null) as MeshInstance3D
		var out_r: MeshInstance3D = b_entry.get("outer_ring", null) as MeshInstance3D
		var h_mi: MeshInstance3D = b_entry.get("halo", null) as MeshInstance3D
		var c_mat: ShaderMaterial = b_entry.get("mat", null) as ShaderMaterial
		var b_ph: float = float(b_entry.get("phase", 0.0))
		if piv != null and is_instance_valid(piv):
			piv.position.y = float(b_entry.get("base_y", 1.06)) + sin(_time_acc * 2.1 + b_ph) * 0.08
		if c_mi != null and is_instance_valid(c_mi):
			c_mi.rotation.y += delta * 0.85 * spin_mult
		if in_r != null and is_instance_valid(in_r):
			in_r.rotation.y += delta * 1.25 * spin_mult
		if out_r != null and is_instance_valid(out_r):
			out_r.rotation.y -= delta * 0.90 * spin_mult
		if h_mi != null and is_instance_valid(h_mi):
			h_mi.rotation.y -= delta * 0.9
		if c_mat != null and _config != null:
			c_mat.set_shader_parameter("emissive_boost", _config.emissive_boost * gacha_boost)

	for entry: Dictionary in _lounge_pet_entries:
		var lp_node: Node3D = entry.get("node", null) as Node3D
		var lp_sprite: Sprite3D = entry.get("sprite", null) as Sprite3D
		var center: Vector3 = entry.get("center", Vector3(-10.20, 0.0, 10.20)) as Vector3
		var ang0: float = float(entry.get("angle_offset", 0.0))
		var ph: float = float(entry.get("phase", 0.0))
		if lp_node != null and is_instance_valid(lp_node):
			var cur_ang: float = ang0 + _time_acc * 0.34
			lp_node.position = center + Vector3(cos(cur_ang) * PET_ORBIT_RADIUS, 0.56 + sin(_time_acc * 2.2 + ph) * 0.12, sin(cur_ang) * PET_ORBIT_RADIUS)
			if lp_sprite != null:
				lp_sprite.flip_h = (-sin(cur_ang) < 0.0)
				lp_sprite.position.y = 0.08 + absf(sin(_time_acc * 3.1 + ph)) * 0.045

	if _followed_pet_node != null and is_instance_valid(_followed_pet_node) and _player_follow_target != null and is_instance_valid(_player_follow_target):
		var target_pos: Vector3 = _player_follow_target.global_position + Vector3(-1.05, 0.04, 0.75)
		var cur: Vector3 = _followed_pet_node.position
		var diff := Vector2(target_pos.x - cur.x, target_pos.z - cur.z)
		var dist: float = diff.length()
		if dist > 0.25:
			var step_v: Vector2 = diff.normalized() * minf(dist, 4.6 * delta)
			_followed_pet_node.position.x += step_v.x
			_followed_pet_node.position.z += step_v.y
			_followed_pet_node.position.y = 0.04
			if _followed_pet_sprite != null:
				if absf(step_v.x) > 0.002:
					_followed_pet_sprite.flip_h = (step_v.x < 0.0)
				_followed_pet_sprite.position.y = absf(sin(_time_acc * 8.5)) * 0.065
		elif _followed_pet_sprite != null:
			_followed_pet_sprite.position.y = sin(_time_acc * 3.2) * 0.025


func open_gacha_station() -> void:
	if _is_gacha_open:
		return
	_is_gacha_open = true
	if gacha_overlay != null:
		gacha_overlay.visible = true
		gacha_overlay.set_standby_mode()
		_sync_gacha_overlay_status()
	if summoner != null:
		gacha_focus_requested.emit(summoner.global_position)


func close_gacha_station() -> void:
	if not _is_gacha_open:
		return
	_is_gacha_open = false
	if summoner != null and summoner.is_sequence_active():
		summoner.reset_to_idle()
	if gacha_overlay != null:
		gacha_overlay.visible = false
	if _config != null:
		bloom_boost_requested.emit(_config.bloom_intensity)
	gacha_focus_exited.emit()


func is_gacha_open() -> bool:
	return _is_gacha_open


func update_proximity(player_body: Node3D, allow_prompts: bool) -> void:
	if player_body == null:
		return
	if _gacha_label != null and _gacha_area != null:
		_gacha_label.visible = allow_prompts and _gacha_area.overlaps_body(player_body)
		_gacha_label.modulate = COLOR_PSYCHOPOP_PINK
	if _totem_label != null and _totem_area != null:
		_totem_label.visible = allow_prompts and _totem_area.overlaps_body(player_body)
		_totem_label.modulate = COLOR_PSYCHOPOP_CYAN


func try_interact(player_body: Node3D) -> bool:
	if player_body == null:
		return false
	if _gacha_area != null and _gacha_area.overlaps_body(player_body):
		open_gacha_station()
		return true
	if _totem_area != null and _totem_area.overlaps_body(player_body):
		if _totem_root != null:
			telemetry_requested.emit(_totem_root.global_position)
		return true
	return false


func apply_shader_calibration(crease_strength: float, outline_w: float, ref_dist: float, emissive_b: float) -> void:
	for mat: ShaderMaterial in _prop_mats:
		mat.set_shader_parameter("crease_ink_strength", crease_strength)
		mat.set_shader_parameter("emissive_boost", emissive_b)
	if _outline_mat != null:
		_outline_mat.set_shader_parameter("outline_width", outline_w)
		_outline_mat.set_shader_parameter("reference_distance", ref_dist)


func apply_trim_sheet_maps(norm_tex: Texture2D, orm_tex: Texture2D, sdf_tex: Texture2D) -> void:
	var has_trim: bool = (norm_tex != null and orm_tex != null and sdf_tex != null)
	for mat: ShaderMaterial in get_demat_materials():
		mat.set_shader_parameter("has_trim_maps", has_trim)
		if has_trim:
			mat.set_shader_parameter("trim_normal_tex", norm_tex)
			mat.set_shader_parameter("trim_orm_tex", orm_tex)
			mat.set_shader_parameter("trim_ink_sdf_tex", sdf_tex)


func apply_cosmic_lighting_tints(key_tint: Color, shadow_tint: Color, rim_col: Color) -> void:
	for mat: ShaderMaterial in get_demat_materials():
		mat.set_shader_parameter("cosmic_key_tint", key_tint)
		mat.set_shader_parameter("cosmic_shadow_tint", shadow_tint)
		mat.set_shader_parameter("cosmic_rim_color", rim_col)


func get_demat_materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for mat: ShaderMaterial in _prop_mats:
		if mat != null and not out.has(mat):
			out.append(mat)
	if _outline_mat != null and not out.has(_outline_mat):
		out.append(_outline_mat)
	_collect_shader_materials_recursive(self, out)
	return out


func _collect_shader_materials_recursive(node: Node, out: Array[ShaderMaterial]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.material_override is ShaderMaterial:
			var sm := mi.material_override as ShaderMaterial
			if not out.has(sm):
				out.append(sm)
		for si: int in range(mi.get_surface_override_material_count()):
			var surf_m: Material = mi.get_surface_override_material(si)
			if surf_m is ShaderMaterial:
				var s_mat := surf_m as ShaderMaterial
				if not out.has(s_mat):
					out.append(s_mat)
				if s_mat.next_pass is ShaderMaterial and not out.has(s_mat.next_pass as ShaderMaterial):
					out.append(s_mat.next_pass as ShaderMaterial)
	for child: Node in node.get_children():
		_collect_shader_materials_recursive(child, out)


func get_lounge_pad_count() -> int:
	return _lounge_pads.size()


func get_telemetry_totem_node() -> Node3D:
	return _totem_root


func get_followed_pet_id() -> StringName:
	return _followed_pet_id


func _create_trigger_area(node_name: String, pos: Vector3, radius: float) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 2.0
	cs.shape = cyl
	area.add_child(cs)
	return area


func _create_prompt_label(node_name: String, pos: Vector3, text: String) -> Label3D:
	var lbl := Label3D.new()
	lbl.name = node_name
	lbl.position = pos
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 30
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0.03, 0.03, 0.08, 1.0)
	lbl.visible = false
	return lbl
