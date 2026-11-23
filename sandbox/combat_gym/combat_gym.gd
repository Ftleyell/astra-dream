class_name CombatGym
extends Node2D
## Arena de calibración in-game sobre Player/HUD/Cosmos reales sin prólogo ni oleadas.

const CombatGymDummyScript = preload("res://sandbox/combat_gym/combat_gym_dummy.gd")
const CombatGymPanelScript = preload("res://sandbox/combat_gym/combat_gym_panel.gd")
const AlignmentOverlayScript = preload("res://sandbox/workbenches/shared/workbench_alignment_overlay.gd")
const SaveSandboxScript = preload("res://sandbox/workbenches/shared/workbench_save_sandbox.gd")
const CombatNarrativeDirectorScript = preload("res://scenes/combat/directors/combat_narrative_director.gd")
const DialogueBackdropScene: PackedScene = preload("res://scenes/ui/dialogue/dialogue_backdrop_layer.tscn")
const DialogueSkipScene: PackedScene = preload("res://scenes/ui/dialogue_skip_overlay.tscn")
const SkinCatalogPath: String = "res://data/pilots/valentina_v2/valentina_v2_skin_catalog.tres"
const WORKBENCH_HUB_PATH: String = "res://sandbox/workbenches/workbench_hub.tscn"

@onready var space_background: CosmosCombatEnvironment = $SpaceBackground
@onready var camera: GameCamera2D = $Camera2D
@onready var bullet_server: BulletServer = $BulletServer
@onready var player: Player = $Player
@onready var weapon_controller: WeaponController = $Player/WeaponController
@onready var overhead_health_bar: OverheadHealthBar = $Player/OverheadHealthBar
@onready var hud: GameHUD = $HUD

var alignment_overlay: AlignmentOverlayScript = null
var narrative_director: CombatNarrativeDirector = null
var dialogue_backdrop: DialogueBackdropLayer = null
var skip_badge_layer: DialogueSkipOverlay = null

var _save_sandbox: SaveSandboxScript = SaveSandboxScript.new()
var _panel_refs: Dictionary = {}
var _dummies_container: Node2D = null

var _all_weapons: Array[WeaponData] = []
var _weapon_count: int = 1
var _catalog_offset: int = 0
var _gym_paused: bool = false
var _sim_overfocus: bool = false

var _pilot_ids: Array[String] = ["base"]
var _pilot_labels: Array[String] = ["Base (Original)"]
var _wings_ids: Array[String] = ["follow_pilot", "base"]
var _wings_labels: Array[String] = ["Seguir Piloto", "Base (Original)"]
var _weapon_ids: Array[String] = ["follow_pilot", "base"]
var _weapon_labels: Array[String] = ["Seguir Piloto", "Base (Original)"]


class _MockGymRival extends Node2D:
	var pilot_id: StringName = &"nova"


var current_rival: Node2D = null
var is_boss_transmission_active: bool = false
var is_cockpit_active: bool = false
var is_rival_cinematic_active: bool = false
var current_boss: Node2D = null


func _enter_tree() -> void:
	_save_sandbox.backup()
	# Asegurar personaje Valentina ANTES de Player._ready()
	var roster: Dictionary[StringName, CharacterData] = CharacterData.load_roster()
	var val_data: CharacterData = roster.get(&"valentina", null)
	if val_data != null and is_instance_valid(get_node_or_null("Player")):
		var p_node: Player = get_node("Player") as Player
		p_node.character_data = val_data


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_all_weapons = WeaponCatalog.get_all_weapons()
	_load_skin_catalog_choices()

	if is_instance_valid(space_background) and is_instance_valid(camera):
		space_background.set_camera_reference(camera)
	if is_instance_valid(camera) and is_instance_valid(player):
		camera.target = player
		camera.global_position = player.global_position

	_dummies_container = Node2D.new()
	_dummies_container.name = "CombatGymDummies"
	add_child(_dummies_container)

	_wire_player_and_hud()
	_setup_dialogue_tools()

	alignment_overlay = AlignmentOverlayScript.attach_to(self, 75) as AlignmentOverlayScript
	_register_alignment_targets()
	_panel_refs = CombatGymPanelScript.build(self, self)

	spawn_dummies(1)
	_update_overlay_rings()
	_refresh_ring_metrics_label()


func _exit_tree() -> void:
	stop_active_dialogue()
	_disconnect_dialogic_signals()
	if is_instance_valid(hud) and is_instance_valid(hud.target_reticle):
		hud.target_reticle.queue_free()
	PauseArbitrator.release_pause(&"combat_gym_pause")
	PauseArbitrator.release_pause(&"dialogue")
	PauseArbitrator.release_pause(&"briefing")
	Engine.time_scale = 1.0
	_save_sandbox.restore()


func _process(_delta: float) -> void:
	if _sim_overfocus and is_instance_valid(player):
		player.set("is_focus_active", true)
	_update_overlay_rings()
	_refresh_ring_metrics_label()


func _unhandled_input(event: InputEvent) -> void:
	var key_ev := event as InputEventKey
	if key_ev != null and key_ev.pressed and not key_ev.echo:
		if key_ev.keycode == KEY_G:
			toggle_guides()
			get_viewport().set_input_as_handled()
		elif key_ev.keycode == KEY_H or key_ev.keycode == KEY_F9:
			var panel: Control = _panel_refs.get("panel") as Control
			if is_instance_valid(panel):
				panel.visible = not panel.visible
			get_viewport().set_input_as_handled()


func _wire_player_and_hud() -> void:
	if is_instance_valid(player) and is_instance_valid(hud):
		hud.set_player(player)
		if not player.exp_changed.is_connected(hud.update_exp):
			player.exp_changed.connect(hud.update_exp)
		if not player.credits_changed.is_connected(hud.update_credits):
			player.credits_changed.connect(hud.update_credits)
		if not player.biomass_changed.is_connected(hud.update_biomass):
			player.biomass_changed.connect(hud.update_biomass)
		if player.character_data != null:
			hud.update_pilot_abilities(player.character_data)
		hud.update_wave_status(1, 0.0, 0, 1)


func _setup_dialogue_tools() -> void:
	var mock_r := _MockGymRival.new()
	mock_r.name = "MockGymRival"
	add_child(mock_r)
	current_rival = mock_r

	skip_badge_layer = DialogueSkipScene.instantiate() as DialogueSkipOverlay
	skip_badge_layer.name = "SkipBadgeLayer"
	add_child(skip_badge_layer)

	dialogue_backdrop = DialogueBackdropScene.instantiate() as DialogueBackdropLayer
	dialogue_backdrop.name = "DialogueBackdropLayer"
	if is_instance_valid(hud):
		dialogue_backdrop.set_hud_reference(hud)
	add_child(dialogue_backdrop)

	narrative_director = CombatNarrativeDirectorScript.new()
	narrative_director.name = "CombatNarrativeDirector"
	add_child(narrative_director)
	narrative_director.setup(self, player, hud, skip_badge_layer, null)

	if skip_badge_layer.has_signal("skip_requested"):
		skip_badge_layer.skip_requested.connect(stop_active_dialogue)

	var dialogic_node: Node = narrative_director.get_dialogic()
	if dialogic_node != null:
		dialogic_node.process_mode = Node.PROCESS_MODE_ALWAYS
		if dialogic_node.has_signal("timeline_started") and not dialogic_node.timeline_started.is_connected(_on_dialogic_timeline_started):
			dialogic_node.timeline_started.connect(_on_dialogic_timeline_started)
		if dialogic_node.has_signal("timeline_ended") and not dialogic_node.timeline_ended.is_connected(_on_dialogic_timeline_ended):
			dialogic_node.timeline_ended.connect(_on_dialogic_timeline_ended)
		if dialogic_node.has_signal("signal_event") and not dialogic_node.signal_event.is_connected(_on_dialogic_signal_event):
			dialogic_node.signal_event.connect(_on_dialogic_signal_event)


func _disconnect_dialogic_signals() -> void:
	var dialogic_node: Node = narrative_director.get_dialogic() if is_instance_valid(narrative_director) else get_node_or_null("/root/Dialogic")
	if dialogic_node == null:
		return
	if dialogic_node.has_signal("timeline_started") and dialogic_node.timeline_started.is_connected(_on_dialogic_timeline_started):
		dialogic_node.timeline_started.disconnect(_on_dialogic_timeline_started)
	if dialogic_node.has_signal("timeline_ended") and dialogic_node.timeline_ended.is_connected(_on_dialogic_timeline_ended):
		dialogic_node.timeline_ended.disconnect(_on_dialogic_timeline_ended)
	if dialogic_node.has_signal("signal_event") and dialogic_node.signal_event.is_connected(_on_dialogic_signal_event):
		dialogic_node.signal_event.disconnect(_on_dialogic_signal_event)


func _on_dialogic_timeline_started() -> void:
	if is_instance_valid(narrative_director):
		narrative_director.on_timeline_started()


func _on_dialogic_timeline_ended() -> void:
	if is_instance_valid(narrative_director):
		narrative_director.on_timeline_ended()


func _on_dialogic_signal_event(arg: Variant) -> void:
	if is_instance_valid(narrative_director):
		narrative_director.on_dialogic_signal(arg)


func _register_alignment_targets() -> void:
	if alignment_overlay == null:
		return
	alignment_overlay.clear_targets()
	alignment_overlay.set_world_target(player)
	if is_instance_valid(hud):
		var w_row: Control = hud.find_child("WeaponSlotsRow", true, false) as Control
		var t_row: Control = hud.find_child("TacticalAbilitiesRow", true, false) as Control
		var b_bar: Control = hud.find_child("BottomBar", true, false) as Control
		alignment_overlay.register_control("WeaponSlotsRow", w_row)
		alignment_overlay.register_control("TacticalAbilitiesRow", t_row)
		alignment_overlay.register_control("BottomBar", b_bar)
		alignment_overlay.register_gap_pair("Armas↔Habs", w_row, t_row)
		alignment_overlay.register_gap_pair("Habs↔EXP", t_row, b_bar)


func get_ring_equidistance_metrics() -> Dictionary:
	var hp_radius_px: float = 0.0
	var orb_rx_px: float = 0.0
	var orb_ry_px: float = 0.0
	var orb_offset_px: Vector2 = Vector2.ZERO

	if is_instance_valid(overhead_health_bar):
		var hp_scale_x: float = overhead_health_bar.global_transform.x.length()
		hp_radius_px = OverheadHealthBar.HEALTH_RING_RADIUS * hp_scale_x

	if is_instance_valid(player) and player.has_rig_v2():
		var ring_ctrl: OrbitalWeaponRingController = player.get_rig_v2_controller().get_ring_controller()
		if is_instance_valid(ring_ctrl):
			var cfg: PilotOrbitalWeaponConfig = ring_ctrl.get_config()
			if cfg != null:
				var rsx: float = ring_ctrl.global_transform.x.length()
				var rsy: float = ring_ctrl.global_transform.y.length()
				orb_rx_px = cfg.ring_radius_x * rsx
				orb_ry_px = cfg.ring_radius_y * rsy
				orb_offset_px = Vector2(cfg.ring_center_offset.x * rsx, cfg.ring_center_offset.y * rsy)

	return {
		"health_ring_radius_px": hp_radius_px,
		"orbital_radius_x_px": orb_rx_px,
		"orbital_radius_y_px": orb_ry_px,
		"orbital_center_offset_px": orb_offset_px,
		"gap_x_px": orb_rx_px - hp_radius_px,
		"gap_y_px": orb_ry_px - hp_radius_px,
	}


func _update_overlay_rings() -> void:
	if alignment_overlay == null:
		return
	var m: Dictionary = get_ring_equidistance_metrics()
	var hp_r: float = float(m.get("health_ring_radius_px", 0.0))
	var orb_rx: float = float(m.get("orbital_radius_x_px", 0.0))
	var orb_ry: float = float(m.get("orbital_radius_y_px", 0.0))
	var orb_off: Vector2 = m.get("orbital_center_offset_px", Vector2.ZERO) as Vector2
	alignment_overlay.set_world_rings([
		{
			"label": "HealthRing",
			"radius_x": hp_r,
			"radius_y": hp_r,
			"offset": Vector2.ZERO,
			"color": Color(0.25, 1.0, 0.55, 0.90),
		},
		{
			"label": "OrbitalRing",
			"radius_x": orb_rx,
			"radius_y": orb_ry,
			"offset": orb_off,
			"color": Color(0.25, 0.88, 1.0, 0.90),
		},
	])


func _refresh_ring_metrics_label() -> void:
	var lbl: Label = _panel_refs.get("ring_metrics_label") as Label
	if not is_instance_valid(lbl):
		return
	var m: Dictionary = get_ring_equidistance_metrics()
	lbl.text = "HealthRing R: %.1fpx | Orbital rx=%.1f ry=%.1f\nGap X: %.1fpx | Gap Y: %.1fpx | Off: (%.1f, %.1f)" % [
		float(m["health_ring_radius_px"]),
		float(m["orbital_radius_x_px"]),
		float(m["orbital_radius_y_px"]),
		float(m["gap_x_px"]),
		float(m["gap_y_px"]),
		(m["orbital_center_offset_px"] as Vector2).x,
		(m["orbital_center_offset_px"] as Vector2).y,
	]


func _load_skin_catalog_choices() -> void:
	_pilot_ids = ["base"]
	_pilot_labels = ["Base (Original)"]
	_wings_ids = ["follow_pilot", "base"]
	_wings_labels = ["Seguir Piloto", "Base (Original)"]
	_weapon_ids = ["follow_pilot", "base"]
	_weapon_labels = ["Seguir Piloto", "Base (Original)"]

	if not ResourceLoader.exists(SkinCatalogPath):
		return
	var catalog: PilotShaderSkinCatalog = ResourceLoader.load(SkinCatalogPath) as PilotShaderSkinCatalog
	if catalog == null:
		return
	for entry: ShaderSkinEntry in catalog.entries:
		if entry == null or entry.id.is_empty():
			continue
		var label_str: String = entry.skin_name if not entry.skin_name.is_empty() else entry.id
		match entry.category:
			"pilot":
				_pilot_ids.append(entry.id)
				_pilot_labels.append(label_str)
			"wings", "ship":
				_wings_ids.append(entry.id)
				_wings_labels.append(label_str)
			"weapon":
				_weapon_ids.append(entry.id)
				_weapon_labels.append(label_str)


func get_skin_display_lists() -> Dictionary:
	return {
		"pilot_labels": _pilot_labels,
		"wings_labels": _wings_labels,
		"weapon_labels": _weapon_labels,
	}


func select_skin_by_index(slot_category: String, idx: int) -> void:
	match slot_category:
		"pilot":
			if idx >= 0 and idx < _pilot_ids.size():
				apply_valentina_skin("pilot:valentina", _pilot_ids[idx])
		"wings":
			if idx >= 0 and idx < _wings_ids.size():
				apply_valentina_skin("wings:valentina", _wings_ids[idx])
		"weapon":
			if idx >= 0 and idx < _weapon_ids.size():
				apply_valentina_skin("weapon:valentina", _weapon_ids[idx])


func apply_valentina_skin(slot_key: String, skin_id: String) -> void:
	if not skin_id.is_empty() and skin_id != "base" and skin_id != "follow_pilot":
		SaveManager.unlock_or_upgrade_skin(skin_id)
	SaveManager.equip_skin(slot_key, skin_id)
	if is_instance_valid(player) and player.has_rig_v2():
		player.get_rig_v2_controller().refresh_equipped_skins()
	_set_status("Skin %s -> %s" % [slot_key, skin_id])


func set_weapon_count(count: int) -> void:
	_weapon_count = clampi(count, 1, 4)
	if not is_instance_valid(weapon_controller) or _all_weapons.is_empty():
		return
	weapon_controller.clear_equipped_weapons()
	for i: int in range(_weapon_count):
		var wdata: WeaponData = _all_weapons[(_catalog_offset + i) % _all_weapons.size()]
		weapon_controller.add_weapon(wdata)
	_set_status("Armas equipadas: %d/4" % weapon_controller.equipped_weapons.size())


func rotate_weapon_catalog() -> void:
	if _all_weapons.is_empty():
		return
	_catalog_offset = (_catalog_offset + 1) % _all_weapons.size()
	set_weapon_count(_weapon_count)


func toggle_aim_mode() -> void:
	if is_instance_valid(weapon_controller):
		weapon_controller.toggle_aim_mode()
		_set_status("Aim: %s" % ("MANUAL" if weapon_controller.is_manual_aim else "AUTO"))


func apply_damage_test(amount: float) -> void:
	if is_instance_valid(player):
		player.is_invulnerable = false
		player.take_damage(HitContext.create_direct_hit(amount))


func heal_full() -> void:
	if is_instance_valid(player) and player.stats != null:
		player.heal(player.stats.get_stat(&"max_health"))


func add_shield_test(amount: float) -> void:
	if is_instance_valid(player) and player.shield_controller != null:
		player.shield_controller.max_shield = maxf(player.shield_controller.max_shield, 100.0)
		player.shield_controller.current_shield = minf(player.shield_controller.max_shield, player.shield_controller.current_shield + amount)
		var max_hp: float = player.stats.get_stat(&"max_health") if player.stats != null else 100.0
		player.health_changed.emit(player.current_health, max_hp)


func trigger_osp_test() -> void:
	if not is_instance_valid(player) or player.stats == null:
		return
	var max_hp: float = player.stats.get_stat(&"max_health")
	player.current_health = max_hp
	if player.shield_controller != null:
		player.shield_controller.current_shield = 0.0
	player.is_invulnerable = false
	player.take_damage(HitContext.create_direct_hit(max_hp * 2.5))


func set_overhead_bar_visible(vis: bool) -> void:
	if is_instance_valid(overhead_health_bar):
		overhead_health_bar.visible = vis


func toggle_guides() -> void:
	if alignment_overlay != null:
		alignment_overlay.show_guides = not alignment_overlay.show_guides
		_set_status("Guías: %s" % ("ON" if alignment_overlay.show_guides else "OFF"))


func refill_dash_and_bombs() -> void:
	if is_instance_valid(player):
		player.dash_charges = player.max_dash_charges
		player.dash_updated.emit(player.dash_charges, player.max_dash_charges, 1.0, player.is_focus_active)
		player.bomb_count = 5
		player.bomb_used.emit(player.bomb_count)


func toggle_simulated_overfocus() -> void:
	_sim_overfocus = not _sim_overfocus
	if is_instance_valid(player):
		player.set("is_focus_active", _sim_overfocus)
	_set_status("Overfocus Sim: %s" % ("ON" if _sim_overfocus else "OFF"))


func spawn_dummies(count: int) -> void:
	clear_dummies()
	if not is_instance_valid(_dummies_container) or not is_instance_valid(player):
		return
	var origin: Vector2 = player.global_position
	var offsets: Array[Vector2] = [
		Vector2(340.0, -60.0),
		Vector2(-320.0, -90.0),
		Vector2(40.0, -300.0),
	]
	for i: int in range(clampi(count, 1, offsets.size())):
		var dummy: CombatGymDummyScript = CombatGymDummyScript.new() as CombatGymDummyScript
		dummy.name = "CombatGymDummy_%d" % i
		dummy.global_position = origin + offsets[i]
		_dummies_container.add_child(dummy)
	_set_status("Dummies en arena: %d" % _dummies_container.get_child_count())


func clear_dummies() -> void:
	if not is_instance_valid(_dummies_container):
		return
	for ch: Node in _dummies_container.get_children():
		_dummies_container.remove_child(ch)
		ch.queue_free()


func set_camera_zoom(zoom_val: float) -> void:
	if is_instance_valid(camera):
		var z: float = clampf(zoom_val, 0.2, 4.0)
		camera.target_zoom = z
		camera.zoom = Vector2(z, z)
		_set_status("Zoom cámara: %.1fx" % z)


func set_gym_time_scale(ts: float) -> void:
	Engine.time_scale = clampf(ts, 0.05, 2.0)
	_set_status("TimeScale: %.2fx" % Engine.time_scale)


func toggle_gym_pause() -> void:
	_gym_paused = not _gym_paused
	if _gym_paused:
		PauseArbitrator.acquire_pause(&"combat_gym_pause")
	else:
		PauseArbitrator.release_pause(&"combat_gym_pause")
	_set_status("Pausa Gym: %s" % ("PAUSADO" if _gym_paused else "ACTIVO"))


func toggle_hud_visible() -> void:
	if is_instance_valid(hud):
		hud.set_hud_visible(not hud.visible)


func trigger_dialogue_preview(kind: String) -> void:
	stop_active_dialogue()
	if not is_instance_valid(narrative_director):
		return
	if kind == "prologue":
		narrative_director.prologue_bonus_chosen = false
		narrative_director.start_prologue_briefing()
	elif kind == "rival_face":
		narrative_director.trigger_rival_face_to_face_dialogue(current_rival)


func stop_active_dialogue() -> void:
	if is_instance_valid(narrative_director) and narrative_director.is_dialogue_active():
		narrative_director.skip_dialogue()
	else:
		var dialogic_node: Node = get_node_or_null("/root/Dialogic")
		if dialogic_node != null and "current_timeline" in dialogic_node and dialogic_node.current_timeline != null:
			if dialogic_node.has_method("end_timeline"):
				dialogic_node.end_timeline(true)
	PauseArbitrator.release_pause(&"dialogue")
	PauseArbitrator.release_pause(&"briefing")


func return_to_hub() -> void:
	stop_active_dialogue()
	get_tree().change_scene_to_file(WORKBENCH_HUB_PATH)


func _set_status(msg: String) -> void:
	var lbl: Label = _panel_refs.get("status_label") as Label
	if is_instance_valid(lbl):
		lbl.text = msg
