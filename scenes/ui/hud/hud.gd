class_name GameHUD
extends CanvasLayer

## ─── TABLE OF CONTENTS ──────────────────────────────────────────────────────
## COMPONENT PRELOADS & NODES    → L.25  - L.65
## RADAR & STATE PROXIES         → L.66  - L.125
## LIFECYCLE: _ready & keybinds  → L.126 - L.190
## SUBCONTROLLER INITIALIZATION   → L.191 - L.220
## FRAME PROCESS & RETICLE       → L.221 - L.235
## STATUS, BANNERS & RADAR       → L.236 - L.275
## ABILITIES, WEAPONS & ECONOMY  → L.276 - L.335
## ITEMS, KEYS & BOSS TRACKING   → L.336 - L.390
## PLAYER WIRING: set_player     → L.391 - L.455
## CURSE BADGE & STATS DOCK      → L.456 - L.485
## ─────────────────────────────────────────────────────────────────────────────


const TacticalAbilitiesControllerClass = preload("res://scenes/ui/hud/components/hud_tactical_abilities_controller.gd")
const InventoryBarControllerClass = preload("res://scenes/ui/hud/components/hud_inventory_bar_controller.gd")
const BannerManagerClass = preload("res://scenes/ui/hud/components/hud_banner_manager.gd")
const CombatStatsDock = preload("res://scenes/ui/hud/components/combat_stats_dock.gd")
const TomeControllerClass = preload("res://scenes/combat/player/tome_controller.gd")
const WeaponCooldownBarClass = preload("res://scenes/ui/hud/components/hud_weapon_cooldown_bar.gd")
const HealthShieldDisplayClass = preload("res://scenes/ui/hud/components/hud_health_shield_display.gd")
const HUDCurseBadgeControllerClass = preload("res://scenes/ui/hud/components/hud_curse_badge_controller.gd")
const HUDCombatStatsDockControllerClass = preload("res://scenes/ui/hud/components/hud_combat_stats_dock_controller.gd")
const HUDSatelliteRadarControllerClass = preload("res://scenes/ui/hud/components/hud_satellite_radar_controller.gd")
const HUDEdgeTrackerManagerClass = preload("res://scenes/ui/hud/components/hud_edge_tracker_manager.gd")

## GameHUD.gd
## Fachada y orquestador central del HUD de combate.
## Delega lógica específica a HUDTacticalAbilitiesController, HUDInventoryBarController, HudWeaponCooldownBar, HudHealthShieldDisplay, HUDBannerManager, HUDSatelliteRadarController y HUDEdgeTrackerManager.

@export var player: Player

@onready var dash_keybind_label: Label = find_child("DashKeybind", true, false) as Label
@onready var laser_keybind_label: Label = find_child("LaserKeybind", true, false) as Label
@onready var bomb_keybind_label: Label = find_child("BombKeybind", true, false) as Label
@onready var credits_label: Label = find_child("CreditsLabel", true, false) as Label
@onready var biomass_label: Label = find_child("BiomassLabel", true, false) as Label
@onready var credit_icon: TextureRect = find_child("CreditIcon", true, false) as TextureRect
@onready var timer_label: Label = find_child("TimerLabel", true, false) as Label
@onready var inventory_row: HBoxContainer = find_child("InventoryRow", true, false) as HBoxContainer
@onready var weapon_slots_row: HBoxContainer = find_child("WeaponSlotsRow", true, false) as HBoxContainer
@onready var tome_slots_row: HBoxContainer = find_child("TomeSlotsRow", true, false) as HBoxContainer
@onready var boss_health_bar: BossHealthBar = get_node_or_null("BossHealthBar")
@onready var satellite_tracker: SatelliteEdgeIndicator = find_child("SatelliteEdgeIndicator", true, false) as SatelliteEdgeIndicator
@onready var arcana_tracker: ArcanaEdgeIndicator = find_child("ArcanaEdgeIndicator", true, false) as ArcanaEdgeIndicator
@onready var boss_tracker: Control = find_child("BossEdgeIndicator", true, false) as Control
@onready var chest_tracker: Control = find_child("ChestEdgeIndicator", true, false) as Control
@onready var key_label: Label = find_child("KeyLabel", true, false) as Label

var target_reticle: Node2D = null
var target_reticle_scene: PackedScene = preload("res://scenes/ui/hud/target_reticle.tscn")

var _abilities_ctrl: RefCounted = null
var _inventory_ctrl: RefCounted = null
var _banner_mgr: RefCounted = null
var _weapon_bar: RefCounted = null
var _health_shield_display: RefCounted = null
var _curse_ctrl: RefCounted = HUDCurseBadgeControllerClass.new()
var _stats_dock_ctrl: RefCounted = HUDCombatStatsDockControllerClass.new()
var _radar_ctrl: RefCounted = HUDSatelliteRadarControllerClass.new()
var _edge_tracker_mgr: RefCounted = HUDEdgeTrackerManagerClass.new()

var run_time: float:
	get: return _radar_ctrl.run_time if _radar_ctrl else 0.0
	set(val): if _radar_ctrl: _radar_ctrl.run_time = val
var active_satellite_pos: Vector2:
	get: return _radar_ctrl.active_satellite_pos if _radar_ctrl else Vector2.ZERO
	set(val): if _radar_ctrl: _radar_ctrl.active_satellite_pos = val
var has_satellite: bool:
	get: return _radar_ctrl.has_satellite if _radar_ctrl else false
	set(val): if _radar_ctrl: _radar_ctrl.has_satellite = val
var satellite_index: int:
	get: return _radar_ctrl.satellite_index if _radar_ctrl else 1
	set(val): if _radar_ctrl: _radar_ctrl.satellite_index = val
var current_wave: int:
	get: return _radar_ctrl.current_wave if _radar_ctrl else 1
	set(val): if _radar_ctrl: _radar_ctrl.current_wave = val
var wave_time_left: float:
	get: return _radar_ctrl.wave_time_left if _radar_ctrl else 60.0
	set(val): if _radar_ctrl: _radar_ctrl.wave_time_left = val
var wave_satellites_spawned: int:
	get: return _radar_ctrl.wave_satellites_spawned if _radar_ctrl else 0
	set(val): if _radar_ctrl: _radar_ctrl.wave_satellites_spawned = val
var max_wave_satellites: int:
	get: return _radar_ctrl.max_wave_satellites if _radar_ctrl else 3
	set(val): if _radar_ctrl: _radar_ctrl.max_wave_satellites = val
var current_travel_dist: float:
	get: return _radar_ctrl.current_travel_dist if _radar_ctrl else 0.0
	set(val): if _radar_ctrl: _radar_ctrl.current_travel_dist = val
var required_travel_dist: float:
	get: return _radar_ctrl.required_travel_dist if _radar_ctrl else 600.0
	set(val): if _radar_ctrl: _radar_ctrl.required_travel_dist = val
var is_pre_round_active: bool:
	get: return _radar_ctrl.is_pre_round_active if _radar_ctrl else false
	set(val): if _radar_ctrl: _radar_ctrl.is_pre_round_active = val
var pre_round_time_left: float:
	get: return _radar_ctrl.pre_round_time_left if _radar_ctrl else 30.0
	set(val): if _radar_ctrl: _radar_ctrl.pre_round_time_left = val

var _inventory_chips: Dictionary:
	get: return _inventory_ctrl.get_inventory_chips() if _inventory_ctrl else {}
var _satellite_banner_node: Control:
	get: return _banner_mgr._satellite_banner_node if _banner_mgr else null
	set(val): if _banner_mgr: _banner_mgr._satellite_banner_node = val
var _unlock_banner_node: Control:
	get: return _banner_mgr._unlock_banner_node if _banner_mgr else null
	set(val): if _banner_mgr: _banner_mgr._unlock_banner_node = val
var _tactical_alert_node: Control:
	get: return _banner_mgr._tactical_alert_node if _banner_mgr else null
	set(val): if _banner_mgr: _banner_mgr._tactical_alert_node = val
var curse_badge: Control:
	get: return _curse_ctrl.curse_badge if _curse_ctrl else null
	set(val): if _curse_ctrl: _curse_ctrl.curse_badge = val
var curse_label: Label:
	get: return _curse_ctrl.curse_label if _curse_ctrl else null
	set(val): if _curse_ctrl: _curse_ctrl.curse_label = val
var combat_stats_dock: CombatStatsDock:
	get: return _stats_dock_ctrl.combat_stats_dock if _stats_dock_ctrl else null
	set(val): if _stats_dock_ctrl: _stats_dock_ctrl.combat_stats_dock = val
var stats_dock_layer: CanvasLayer:
	get: return _stats_dock_ctrl.stats_dock_layer if _stats_dock_ctrl else null
	set(val): if _stats_dock_ctrl: _stats_dock_ctrl.stats_dock_layer = val
var current_credits: int:
	get: return _inventory_ctrl.current_credits if _inventory_ctrl else 120
	set(val): if _inventory_ctrl: _inventory_ctrl.current_credits = val
var current_biomass: int:
	get: return _inventory_ctrl.current_biomass if _inventory_ctrl else 0
	set(val): if _inventory_ctrl: _inventory_ctrl.current_biomass = val

func _ready() -> void:
	add_to_group("hud")
	_init_subcontrollers()
	_setup_curse_badge()
	_setup_combat_stats_dock()

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if is_instance_valid(player) and _edge_tracker_mgr:
		_edge_tracker_mgr.set_player(player)

	# Ocultar barra rectangular superior para priorizar el anillo diegético bajo la nave
	if _health_shield_display:
		if _health_shield_display.health_bar:
			_health_shield_display.health_bar.visible = false
		if _health_shield_display.health_label:
			_health_shield_display.health_label.visible = false
	if _radar_ctrl and _radar_ctrl.satellite_radar_label:
		_radar_ctrl.satellite_radar_label.visible = false

	if player:
		set_player(player)

	if not target_reticle and target_reticle_scene:
		target_reticle = target_reticle_scene.instantiate() as Node2D
		var spawn_parent: Node = get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
		if spawn_parent:
			spawn_parent.add_child.call_deferred(target_reticle)

	_update_ability_keybind_labels()
	var settings_mgr = get_node_or_null("/root/SettingsManager")
	if settings_mgr and settings_mgr.has_signal("settings_changed"):
		settings_mgr.settings_changed.connect(_update_ability_keybind_labels)
	_setup_combat_stats_dock()

func _get_action_key_text(act: StringName) -> String:
	var events := InputMap.action_get_events(act)
	for ev in events:
		if ev is InputEventKey:
			return ev.as_text_physical_keycode() if ev.physical_keycode != 0 else ev.as_text_keycode()
		elif ev is InputEventMouseButton:
			match ev.button_index:
				MOUSE_BUTTON_LEFT: return "CLIC IZQ"
				MOUSE_BUTTON_RIGHT: return "CLIC DER"
				MOUSE_BUTTON_MIDDLE: return "CLIC CEN"
				_: return "RATÓN %d" % ev.button_index
	return "N/A"

func _update_ability_keybind_labels() -> void:
	if dash_keybind_label:
		dash_keybind_label.text = "[%s]" % _get_action_key_text(&"dash")
	if laser_keybind_label:
		laser_keybind_label.text = "[%s]" % _get_action_key_text(&"fire_active")
	if bomb_keybind_label:
		bomb_keybind_label.text = "[%s] BOMBA" % _get_action_key_text(&"bomb")

func _init_subcontrollers() -> void:
	_abilities_ctrl = TacticalAbilitiesControllerClass.new()
	_abilities_ctrl.setup_from_root(self)

	_inventory_ctrl = InventoryBarControllerClass.new()
	_inventory_ctrl.setup({
		"weapon_slots_row": weapon_slots_row,
		"tome_slots_row": tome_slots_row,
		"inventory_row": inventory_row,
		"credits_label": credits_label,
		"biomass_label": biomass_label,
		"credit_icon": credit_icon
	})

	_weapon_bar = WeaponCooldownBarClass.new()
	_weapon_bar.setup(weapon_slots_row)

	_health_shield_display = HealthShieldDisplayClass.new()
	_health_shield_display.setup_from_root(self)

	_banner_mgr = BannerManagerClass.new()

	_radar_ctrl.setup_from_root(self)

	_edge_tracker_mgr.setup({
		"satellite_tracker": satellite_tracker,
		"arcana_tracker": arcana_tracker,
		"boss_tracker": boss_tracker,
		"chest_tracker": chest_tracker
	})

func set_hud_visible(p_visible: bool) -> void:
	visible = p_visible
	var tracker_layer := get_node_or_null("SatelliteTrackerLayer") as CanvasLayer
	if tracker_layer:
		tracker_layer.visible = p_visible

func _process(delta: float) -> void:
	if target_reticle and is_instance_valid(player):
		var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
		if w_ctrl and target_reticle.has_method("set_target"):
			var lock_target: Node2D = w_ctrl.current_locked_target if is_instance_valid(w_ctrl.current_locked_target) else null
			target_reticle.call("set_target", lock_target)
		elif target_reticle.has_method("set_target"):
			target_reticle.call("set_target", null)

	_update_weapon_cooldown_sweeps()

	if _radar_ctrl:
		_radar_ctrl.process_frame(delta, player)

func update_pre_round_status(time_left: float) -> void:
	if _radar_ctrl:
		_radar_ctrl.update_pre_round_status(time_left)

func update_wave_status(wave: int, time_left: float, satellites_spawned: int, max_satellites: int) -> void:
	if _radar_ctrl:
		_radar_ctrl.update_wave_status(wave, time_left, satellites_spawned, max_satellites)

func update_satellite_travel_dist(current_d: float, req_d: float) -> void:
	if _radar_ctrl:
		_radar_ctrl.update_satellite_travel_dist(current_d, req_d)

func clear_satellite() -> void:
	if _radar_ctrl:
		_radar_ctrl.clear_satellite()
	if _edge_tracker_mgr:
		_edge_tracker_mgr.clear_satellite_tracking()

func set_active_satellite(pos: Vector2, index: int) -> void:
	if _radar_ctrl:
		_radar_ctrl.set_active_satellite(pos, index)
	if _edge_tracker_mgr:
		_edge_tracker_mgr.track_satellite(pos, index, player)
	show_satellite_banner(index)

func show_satellite_banner(index: int) -> void:
	if _banner_mgr:
		_banner_mgr.show_satellite_banner(index, self)

func show_character_unlock_banner(char_id: StringName, title_text: String, desc_text: String) -> void:
	if _banner_mgr:
		_banner_mgr.show_character_unlock_banner(char_id, title_text, desc_text, self)

func show_rival_defeated_banner(pilot_id: StringName, pilot_name: String, weapon: WeaponData = null) -> void:
	if _banner_mgr and _banner_mgr.has_method("show_rival_defeated_banner"):
		_banner_mgr.show_rival_defeated_banner(pilot_id, pilot_name, weapon, self)

func show_tactical_alert(title_text: String, subtitle_text: String = "", border_color: Color = Color(0.2, 0.9, 1.0)) -> void:
	if _banner_mgr and _banner_mgr.has_method("show_tactical_alert_banner"):
		_banner_mgr.show_tactical_alert_banner(title_text, subtitle_text, border_color, self)


func update_laser_cooldown(current: float, max_val: float) -> void:
	if _abilities_ctrl:
		_abilities_ctrl.update_laser_cooldown(current, max_val)

func update_pilot_abilities(data: CharacterData) -> void:
	if _abilities_ctrl and data:
		_abilities_ctrl.update_ability_icons(data)

func update_weapon_slots(weapons: Array) -> void:
	if _weapon_bar:
		_weapon_bar.update_weapon_slots(weapons, player.stats if is_instance_valid(player) else null)
	elif _inventory_ctrl:
		_inventory_ctrl.update_weapon_slots(weapons, player.stats if is_instance_valid(player) else null)

func update_tome_slots(tomes: Array, levels: Dictionary) -> void:
	if _inventory_ctrl:
		_inventory_ctrl.update_tome_slots(tomes, levels)

func _update_weapon_cooldown_sweeps() -> void:
	if not is_instance_valid(player):
		return
	var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
	if not w_ctrl:
		return
	if _weapon_bar:
		_weapon_bar.update_weapon_cooldown_sweeps(w_ctrl.equipped_weapons, player.stats if player else null)
	elif _inventory_ctrl:
		_inventory_ctrl.update_weapon_cooldown_sweeps(w_ctrl.equipped_weapons, player.stats if player else null)

func update_credits(amount: int) -> void:
	if _inventory_ctrl:
		_inventory_ctrl.update_credits(amount, get_tree())

func update_biomass(run_amount: int, total_persistent: int) -> void:
	if _inventory_ctrl:
		_inventory_ctrl.update_biomass(run_amount, total_persistent)

func update_exp(current: float, max_val: float, level: int) -> void:
	if _health_shield_display:
		_health_shield_display.update_exp(current, max_val, level, get_tree())

func _on_health_changed(current: float, max_val: float) -> void:
	if _health_shield_display:
		var shield_val: float = 0.0
		var max_sh: float = 0.0
		if is_instance_valid(player) and "shield_controller" in player and player.shield_controller:
			shield_val = player.shield_controller.get("current_shield") if "current_shield" in player.shield_controller else 0.0
			max_sh = player.shield_controller.get("max_shield") if "max_shield" in player.shield_controller else 0.0
		_health_shield_display.update_health(current, max_val, shield_val, max_sh, get_tree())

func _on_bomb_used(remaining: int) -> void:
	if _abilities_ctrl:
		_abilities_ctrl.update_bomb_count(remaining)

func _on_inventory_item_added(item: ItemData, count: int) -> void:
	if _inventory_ctrl:
		_inventory_ctrl.add_or_update_inventory_chip(item, count)
	if item and item.item_id == &"quantum_key":
		update_quantum_keys(count)

func update_quantum_keys(keys_count: int) -> void:
	if not key_label:
		return
	if keys_count > 0:
		key_label.text = "x%d (-20%% Desc.)" % keys_count
		key_label.modulate = Color(0.35, 1.0, 0.65, 1.0)
		var badge := find_child("KeyBadge", true, false) as Control
		if badge:
			badge.pivot_offset = badge.size * 0.5
			var tw := create_tween()
			tw.tween_property(badge, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK)
			tw.tween_property(badge, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
	else:
		key_label.text = "x0"
		key_label.modulate = Color(0.7, 0.88, 1.0, 0.85)

func _get_rarity_color(rarity: Enums.Rarity) -> Color:
	if _inventory_ctrl:
		return _inventory_ctrl.get_rarity_color(rarity)
	return Color.WHITE

func show_boss(boss_name: String, max_hp: float) -> void:
	if boss_health_bar:
		boss_health_bar.setup_boss(boss_name, max_hp)

func update_boss_health(current: float, max_val: float) -> void:
	if boss_health_bar:
		boss_health_bar.update_health(current, max_val)

func set_boss_phase(new_phase: int) -> void:
	if boss_health_bar:
		boss_health_bar.set_phase(new_phase)

func track_boss(target: Node2D, title: String = "JEFE") -> void:
	if _edge_tracker_mgr:
		_edge_tracker_mgr.track_boss(target, title, player)

func clear_boss_tracking() -> void:
	if _edge_tracker_mgr:
		_edge_tracker_mgr.clear_boss_tracking()

func hide_boss() -> void:
	if boss_health_bar:
		boss_health_bar.hide_boss()
	clear_boss_tracking()

func _on_dash_updated(current_charges: int, max_charges: int, recharge_ratio: float, is_focus: bool) -> void:
	if _abilities_ctrl:
		var dash_max_time: float = player.dash_recharge_max if (is_instance_valid(player) and "dash_recharge_max" in player) else 1.6
		_abilities_ctrl.update_dash(current_charges, max_charges, recharge_ratio, is_focus, dash_max_time)

func _on_aim_mode_changed(is_manual: bool) -> void:
	if _abilities_ctrl:
		_abilities_ctrl.update_aim_mode(is_manual)

func _on_osp_triggered(_remaining_hp: float) -> void:
	if _health_shield_display:
		_health_shield_display.trigger_osp_effect(self)
	show_tactical_alert("🛡️ PROTOCOLO OSP ACTIVADO", "¡Impacto letal absorbido! 1.0s de inmunidad concedida", Color(0.2, 0.9, 1.0))

func set_player(p: Player) -> void:
	player = p
	if not is_inside_tree() or not is_instance_valid(player):
		return
	if _edge_tracker_mgr:
		_edge_tracker_mgr.set_player(player)

	if not player.bomb_used.is_connected(_on_bomb_used):
		player.bomb_used.connect(_on_bomb_used)
	_on_bomb_used(player.bomb_count)

	if not player.health_changed.is_connected(_on_health_changed):
		player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.current_health, player.stats.get_stat(&"max_health") if player.stats else 100.0)

	var target_stats: CharacterStats = player.character_stats if player.character_stats else player.stats
	if target_stats:
		if not target_stats.stat_changed.is_connected(_on_stat_changed):
			target_stats.stat_changed.connect(_on_stat_changed)
		update_curse(target_stats.get_stat(&"curse"))

	if player.has_signal("dash_updated") and not player.dash_updated.is_connected(_on_dash_updated):
		player.dash_updated.connect(_on_dash_updated)
		_on_dash_updated(player.dash_charges, player.max_dash_charges, 1.0, player.is_focus_active)

	if player.character_data and _abilities_ctrl:
		_abilities_ctrl.update_ability_icons(player.character_data)

	if player.inventory and not player.inventory.item_added.is_connected(_on_inventory_item_added):
		player.inventory.item_added.connect(_on_inventory_item_added)

	if player.has_signal("osp_triggered") and not player.osp_triggered.is_connected(_on_osp_triggered):
		player.osp_triggered.connect(_on_osp_triggered)

	if player.has_signal("biomass_changed") and not player.biomass_changed.is_connected(update_biomass):
		player.biomass_changed.connect(update_biomass)
	update_biomass(player.run_biomass, SaveManager.get_biomass())

	if player.has_signal("credits_changed") and not player.credits_changed.is_connected(update_credits):
		player.credits_changed.connect(update_credits)
	update_credits(player.run_credits)

	var weapon_ctrl := player.get_node_or_null("WeaponController") as WeaponController
	if weapon_ctrl:
		if not weapon_ctrl.laser_cooldown_updated.is_connected(update_laser_cooldown):
			weapon_ctrl.laser_cooldown_updated.connect(update_laser_cooldown)
		if not weapon_ctrl.weapons_updated.is_connected(update_weapon_slots):
			weapon_ctrl.weapons_updated.connect(update_weapon_slots)
		if weapon_ctrl.has_signal("aim_mode_changed") and not weapon_ctrl.aim_mode_changed.is_connected(_on_aim_mode_changed):
			weapon_ctrl.aim_mode_changed.connect(_on_aim_mode_changed)
		update_weapon_slots(weapon_ctrl.equipped_weapons)
		_on_aim_mode_changed(weapon_ctrl.is_manual_aim)

	var tome_ctrl = player.tome_controller if "tome_controller" in player else null
	if tome_ctrl:
		if not tome_ctrl.tomes_updated.is_connected(update_tome_slots):
			tome_ctrl.tomes_updated.connect(update_tome_slots)
		update_tome_slots(tome_ctrl.equipped_tomes, tome_ctrl.tome_levels)

func _setup_curse_badge() -> void:
	if _curse_ctrl:
		_curse_ctrl.setup_curse_badge(self)

func update_curse(curse_val: float) -> void:
	if _curse_ctrl:
		_curse_ctrl.update_curse(self, curse_val)

func _on_stat_changed(stat_name: StringName, new_val: float) -> void:
	if stat_name == &"curse":
		update_curse(new_val)
	if _stats_dock_ctrl:
		_stats_dock_ctrl.refresh_if_visible(player)

func _setup_combat_stats_dock() -> void:
	if _stats_dock_ctrl:
		_stats_dock_ctrl.setup_combat_stats_dock(self)

func _unhandled_input(event: InputEvent) -> void:
	if _stats_dock_ctrl:
		_stats_dock_ctrl.handle_input(self, player, event)

func set_stats_dock_requested(requester_id: StringName, requested: bool) -> void:
	if _stats_dock_ctrl:
		_stats_dock_ctrl.set_stats_dock_requested(self, player, requester_id, requested)

