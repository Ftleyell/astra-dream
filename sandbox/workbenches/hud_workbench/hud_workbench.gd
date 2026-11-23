class_name HUDWorkbench
extends Node2D
## Workbench sobre producción real para calibrar GameHUD sin iniciar combate ni oleadas.

const HUDScene: PackedScene = preload("res://scenes/ui/hud/hud.tscn")
const CosmosEnvScene: PackedScene = preload("res://scenes/combat/environment/cosmos_combat_environment.tscn")
const HUDPanelScript = preload("res://sandbox/workbenches/hud_workbench/hud_workbench_panel.gd")
const AlignmentOverlayScript = preload("res://sandbox/workbenches/shared/workbench_alignment_overlay.gd")
const WORKBENCH_HUB_PATH: String = "res://sandbox/workbenches/workbench_hub.tscn"

var hud: GameHUD = null
var alignment_overlay: AlignmentOverlayScript = null
var _cosmos_env: CosmosCombatEnvironment = null
var _camera: Camera2D = null
var _backdrop_layer: CanvasLayer = null
var _panel_refs: Dictionary = {}

var _all_weapons: Array[WeaponData] = []
var _mock_weapons: Array[WeaponInstanceData] = []
var _weapon_count: int = 2
var _catalog_offset: int = 0
var _simulate_cooldowns: bool = false

var _hp_pct: float = 100.0
var _max_hp: float = 100.0
var _shield: float = 25.0
var _exp_pct: float = 40.0
var _level: int = 1
var _bombs: int = 3
var _credits: int = 120
var _biomass: int = 40
var _keys: int = 1
var _boss_visible: bool = false
var _boss_ratio: float = 0.72
var _sat_idx: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_backdrop_and_camera()
	_all_weapons = WeaponCatalog.get_all_weapons()
	alignment_overlay = AlignmentOverlayScript.attach_to(self, 75) as AlignmentOverlayScript
	_panel_refs = HUDPanelScript.build(self, self)
	_mount_hud()
	set_weapon_count(_weapon_count)
	_apply_all_mock_values()
	_refresh_metrics_label()


func _exit_tree() -> void:
	_cleanup_hud_node()


func _unhandled_input(event: InputEvent) -> void:
	var key_ev := event as InputEventKey
	if key_ev != null and key_ev.pressed and not key_ev.echo:
		if key_ev.keycode == KEY_G:
			toggle_guides()
			get_viewport().set_input_as_handled()
		elif key_ev.keycode == KEY_H:
			var panel: Control = _panel_refs.get("panel") as Control
			if is_instance_valid(panel):
				panel.visible = not panel.visible
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _simulate_cooldowns and not _mock_weapons.is_empty() and is_instance_valid(hud):
		for inst: WeaponInstanceData in _mock_weapons:
			var max_cd: float = inst.get_effective_cooldown(null)
			inst.active_cooldown -= delta
			if inst.active_cooldown <= 0.0:
				inst.active_cooldown = max_cd
		if hud._weapon_bar:
			hud._weapon_bar.update_weapon_cooldown_sweeps(_mock_weapons, null)
	_refresh_metrics_label()


func _build_backdrop_and_camera() -> void:
	_backdrop_layer = CanvasLayer.new()
	_backdrop_layer.name = "FlatBackdropLayer"
	_backdrop_layer.layer = -120
	add_child(_backdrop_layer)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.08, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_layer.add_child(bg)

	_camera = Camera2D.new()
	_camera.name = "WorkbenchCamera"
	_camera.position = Vector2(960.0, 540.0)
	_camera.enabled = true
	add_child(_camera)


func _mount_hud() -> void:
	_cleanup_hud_node()
	hud = HUDScene.instantiate() as GameHUD
	hud.name = "GameHUD"
	add_child(hud)
	_register_alignment_targets()


func _cleanup_hud_node() -> void:
	if is_instance_valid(hud):
		if is_instance_valid(hud.target_reticle):
			hud.target_reticle.queue_free()
		hud.queue_free()
		hud = null


func _register_alignment_targets() -> void:
	if alignment_overlay == null or not is_instance_valid(hud):
		return
	alignment_overlay.clear_targets()
	var w_row: Control = hud.find_child("WeaponSlotsRow", true, false) as Control
	var t_row: Control = hud.find_child("TacticalAbilitiesRow", true, false) as Control
	var b_bar: Control = hud.find_child("BottomBar", true, false) as Control
	var c_cluster: Control = hud.find_child("CenterCluster", true, false) as Control
	var radar: Control = hud.find_child("DragonRadar", true, false) as Control
	var bio: Control = hud.find_child("BiomassHBox", true, false) as Control

	alignment_overlay.register_control("WeaponSlotsRow", w_row)
	alignment_overlay.register_control("TacticalAbilitiesRow", t_row)
	alignment_overlay.register_control("BottomBar", b_bar)
	alignment_overlay.register_control("CenterCluster", c_cluster)
	alignment_overlay.register_control("DragonRadar", radar)
	alignment_overlay.register_control("BiomassHBox", bio)
	alignment_overlay.register_gap_pair("Armas↔Habs", w_row, t_row)
	alignment_overlay.register_gap_pair("Habs↔EXP", t_row, b_bar)


func toggle_guides() -> void:
	if alignment_overlay != null:
		alignment_overlay.show_guides = not alignment_overlay.show_guides
		_set_status("Guías: %s" % ("ON" if alignment_overlay.show_guides else "OFF"))


func toggle_cosmos_background() -> void:
	if is_instance_valid(_cosmos_env):
		_cosmos_env.queue_free()
		_cosmos_env = null
		_set_status("Fondo: Oscuro plano")
		return
	if CosmosEnvScene != null:
		_cosmos_env = CosmosEnvScene.instantiate() as CosmosCombatEnvironment
		_cosmos_env.name = "CosmosPreview"
		add_child(_cosmos_env)
		_cosmos_env.set_camera_reference(_camera)
		_set_status("Fondo: Cosmos Engine activo")


func reload_hud() -> void:
	_mount_hud()
	set_weapon_count(_weapon_count)
	_apply_all_mock_values()
	set_boss_bar_visible(_boss_visible, _boss_ratio)
	_set_status("HUD recargado desde escena real")


func return_to_hub() -> void:
	get_tree().change_scene_to_file(WORKBENCH_HUB_PATH)


func apply_window_preset(preset_str: String) -> void:
	var parts: PackedStringArray = preset_str.split("x")
	if parts.size() != 2:
		return
	var target_size := Vector2i(int(parts[0]), int(parts[1]))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(target_size)
	_set_status("Preset ventana solicitado: %dx%d" % [target_size.x, target_size.y])


func set_weapon_count(count: int) -> void:
	_weapon_count = clampi(count, 0, 4)
	_mock_weapons.clear()
	if not _all_weapons.is_empty():
		for i: int in range(_weapon_count):
			var wdata: WeaponData = _all_weapons[(_catalog_offset + i) % _all_weapons.size()]
			var inst := WeaponInstanceData.new(wdata, (i % 3) + 1)
			inst.active_cooldown = inst.get_effective_cooldown(null) * (0.25 * float(i + 1))
			_mock_weapons.append(inst)
	if is_instance_valid(hud):
		hud.update_weapon_slots(_mock_weapons)
		if _simulate_cooldowns and hud._weapon_bar:
			hud._weapon_bar.update_weapon_cooldown_sweeps(_mock_weapons, null)
	_set_status("Armas en HUD: %d/4" % _weapon_count)


func rotate_weapon_catalog() -> void:
	if _all_weapons.is_empty():
		return
	_catalog_offset = (_catalog_offset + 1) % _all_weapons.size()
	set_weapon_count(_weapon_count)


func set_simulate_cooldowns(enabled: bool) -> void:
	_simulate_cooldowns = enabled
	if not enabled and is_instance_valid(hud):
		for inst: WeaponInstanceData in _mock_weapons:
			inst.active_cooldown = 0.0
		if hud._weapon_bar:
			hud._weapon_bar.update_weapon_cooldown_sweeps(_mock_weapons, null)


func set_health_percent(pct: float) -> void:
	_hp_pct = clampf(pct, 0.0, 100.0)
	set_health_state(_max_hp * (_hp_pct / 100.0), _max_hp, _shield)


func set_shield_amount(shield_val: float) -> void:
	_shield = maxf(0.0, shield_val)
	set_health_state(_max_hp * (_hp_pct / 100.0), _max_hp, _shield)


func set_health_state(current_hp: float, max_hp: float, shield_val: float) -> void:
	_max_hp = maxf(1.0, max_hp)
	_hp_pct = clampf((current_hp / _max_hp) * 100.0, 0.0, 100.0)
	_shield = maxf(0.0, shield_val)
	if is_instance_valid(hud) and hud._health_shield_display:
		hud._health_shield_display.update_health(current_hp, _max_hp, _shield, 100.0, null)


func set_exp_percent(pct: float) -> void:
	_exp_pct = clampf(pct, 0.0, 100.0)
	if is_instance_valid(hud):
		hud.update_exp(_exp_pct, 100.0, _level)


func increment_level() -> void:
	_level += 1
	if is_instance_valid(hud):
		hud.update_exp(_exp_pct, 100.0, _level)


func trigger_osp_preview() -> void:
	if is_instance_valid(hud) and hud._health_shield_display:
		hud._health_shield_display.trigger_osp_effect(hud)


func step_bombs(delta_val: int) -> void:
	_bombs = clampi(_bombs + delta_val, 0, 5)
	if is_instance_valid(hud) and hud._abilities_ctrl:
		hud._abilities_ctrl.update_bomb_count(_bombs)


func set_laser_cd_preview(ratio: float) -> void:
	if is_instance_valid(hud):
		hud.update_laser_cooldown(ratio * 4.0, 4.0)


func add_credits_preview(delta_val: int) -> void:
	_credits += delta_val
	if is_instance_valid(hud):
		hud.update_credits(_credits)


func add_biomass_preview(delta_val: int) -> void:
	_biomass += delta_val
	if is_instance_valid(hud):
		hud.update_biomass(_biomass, _biomass + 500)


func add_key_preview(delta_val: int) -> void:
	_keys += delta_val
	if is_instance_valid(hud):
		hud.update_quantum_keys(_keys)


func set_boss_bar_visible(active: bool, ratio: float = 0.72) -> void:
	_boss_visible = active
	_boss_ratio = clampf(ratio, 0.0, 1.0)
	if not is_instance_valid(hud):
		return
	if active:
		if hud.boss_health_bar and not hud.boss_health_bar.is_active:
			hud.show_boss("VALENTINA SIMULADA", 1200.0)
		hud.update_boss_health(1200.0 * _boss_ratio, 1200.0)
	else:
		hud.hide_boss()


func trigger_tactical_alert_preview() -> void:
	if is_instance_valid(hud):
		hud.show_tactical_alert("ALERTA TÁCTICA SIMULADA", "Verificando ancho y superposición con CenterCluster", Color(0.2, 0.9, 1.0))


func trigger_satellite_banner_preview() -> void:
	if is_instance_valid(hud):
		hud.show_satellite_banner(_sat_idx)
		_sat_idx += 1


func get_layout_metrics_text() -> String:
	if not is_instance_valid(hud):
		return "HUD no montado"
	var w_row: Control = hud.find_child("WeaponSlotsRow", true, false) as Control
	var t_row: Control = hud.find_child("TacticalAbilitiesRow", true, false) as Control
	var b_bar: Control = hud.find_child("BottomBar", true, false) as Control
	if w_row == null or t_row == null or b_bar == null:
		return "Nodos de HUD pendientes"
	var wr: Rect2 = w_row.get_global_rect()
	var tr: Rect2 = t_row.get_global_rect()
	var br: Rect2 = b_bar.get_global_rect()
	var gap_wt: float = tr.position.y - wr.end.y
	var gap_tb: float = br.position.y - tr.end.y
	return "Armas: %dx%d @ (%.0f, %.0f)\nHabs:  %dx%d @ (%.0f, %.0f)\nEXP:   %dx%d @ (%.0f, %.0f)\nGaps: Armas↔Habs=%.1fpx | Habs↔EXP=%.1fpx" % [
		int(wr.size.x), int(wr.size.y), wr.position.x, wr.position.y,
		int(tr.size.x), int(tr.size.y), tr.position.x, tr.position.y,
		int(br.size.x), int(br.size.y), br.position.x, br.position.y,
		gap_wt,
		gap_tb,
	]


func _apply_all_mock_values() -> void:
	set_health_state(_max_hp * (_hp_pct / 100.0), _max_hp, _shield)
	set_exp_percent(_exp_pct)
	step_bombs(0)
	if is_instance_valid(hud):
		hud.update_credits(_credits)
		hud.update_biomass(_biomass, _biomass + 500)
		hud.update_quantum_keys(_keys)
		hud.update_wave_status(3, 18.5, 1, 2)
		var roster: Dictionary[StringName, CharacterData] = CharacterData.load_roster()
		var val_data: CharacterData = roster.get(&"valentina", null)
		if val_data != null:
			hud.update_pilot_abilities(val_data)


func _refresh_metrics_label() -> void:
	var lbl: Label = _panel_refs.get("metrics_label") as Label
	if is_instance_valid(lbl):
		lbl.text = get_layout_metrics_text()


func _set_status(msg: String) -> void:
	var lbl: Label = _panel_refs.get("status_label") as Label
	if is_instance_valid(lbl):
		lbl.text = msg
