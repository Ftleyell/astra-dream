class_name GameHUD
extends CanvasLayer

const TacticalAbilitiesControllerClass = preload("res://scenes/ui/hud/components/hud_tactical_abilities_controller.gd")
const InventoryBarControllerClass = preload("res://scenes/ui/hud/components/hud_inventory_bar_controller.gd")
const BannerManagerClass = preload("res://scenes/ui/hud/components/hud_banner_manager.gd")

## GameHUD.gd
## Fachada y orquestador central del HUD de combate.
## Delega lógica específica a HUDTacticalAbilitiesController, HUDInventoryBarController y HUDBannerManager.

@export var player: Player

@onready var health_bar: ProgressBar = find_child("HealthBar", true, false) as ProgressBar
@onready var health_label: Label = find_child("HealthLabel", true, false) as Label
@onready var dash_label: Label = find_child("DashLabel", true, false) as Label
@onready var bomb_label: Label = find_child("BombLabel", true, false) as Label
@onready var laser_cd_label: Label = find_child("LaserCDLabel", true, false) as Label
@onready var aim_mode_label: Label = find_child("AimModeLabel", true, false) as Label
@onready var credits_label: Label = find_child("CreditsLabel", true, false) as Label
@onready var biomass_label: Label = find_child("BiomassLabel", true, false) as Label
@onready var credit_icon: TextureRect = find_child("CreditIcon", true, false) as TextureRect
@onready var timer_label: Label = find_child("TimerLabel", true, false) as Label
@onready var satellite_radar_label: Label = find_child("SatelliteRadarLabel", true, false) as Label
@onready var exp_bar: ProgressBar = find_child("ExpBar", true, false) as ProgressBar
@onready var level_label: Label = find_child("LevelLabel", true, false) as Label
@onready var inventory_row: HBoxContainer = find_child("InventoryRow", true, false) as HBoxContainer
@onready var weapon_slots_row: HBoxContainer = find_child("WeaponSlotsRow", true, false) as HBoxContainer
@onready var boss_health_bar: BossHealthBar = get_node_or_null("BossHealthBar")
@onready var satellite_tracker: SatelliteEdgeIndicator = find_child("SatelliteEdgeIndicator", true, false) as SatelliteEdgeIndicator
@onready var arcana_tracker: ArcanaEdgeIndicator = find_child("ArcanaEdgeIndicator", true, false) as ArcanaEdgeIndicator
@onready var boss_tracker: Control = find_child("BossEdgeIndicator", true, false) as Control
@onready var chest_tracker: Control = find_child("ChestEdgeIndicator", true, false) as Control
@onready var key_label: Label = find_child("KeyLabel", true, false) as Label

@onready var dash_button_body: Control = find_child("DashButtonBody", true, false) as Control
@onready var dash_cd_overlay: ColorRect = find_child("DashCDOverlay", true, false) as ColorRect
@onready var dash_cd_num: Label = find_child("DashCDNum", true, false) as Label
@onready var dash_pip_1: Panel = find_child("DashPip1", true, false) as Panel
@onready var dash_pip_2: Panel = find_child("DashPip2", true, false) as Panel

@onready var laser_button_body: Control = find_child("LaserButtonBody", true, false) as Control
@onready var laser_cd_overlay: ColorRect = find_child("LaserCDOverlay", true, false) as ColorRect
@onready var laser_cd_num: Label = find_child("LaserCDNum", true, false) as Label

@onready var bomb_button_body: Control = find_child("BombButtonBody", true, false) as Control
@onready var bomb_overlay: ColorRect = find_child("BombOverlay", true, false) as ColorRect
@onready var bomb_pip_1: Panel = find_child("BombPip1", true, false) as Panel
@onready var bomb_pip_2: Panel = find_child("BombPip2", true, false) as Panel
@onready var bomb_pip_3: Panel = find_child("BombPip3", true, false) as Panel

var target_reticle: Node2D = null
var target_reticle_scene: PackedScene = preload("res://scenes/ui/hud/target_reticle.tscn")

var run_time: float = 0.0
var active_satellite_pos: Vector2 = Vector2.ZERO
var has_satellite: bool = false
var satellite_index: int = 1
var current_wave: int = 1
var wave_time_left: float = 60.0
var wave_satellites_spawned: int = 0
var max_wave_satellites: int = 3
var current_travel_dist: float = 0.0
var required_travel_dist: float = 600.0
var is_pre_round_active: bool = false
var pre_round_time_left: float = 30.0

var _abilities_ctrl: RefCounted = null
var _inventory_ctrl: RefCounted = null
var _banner_mgr: RefCounted = null

var _inventory_chips: Dictionary:
	get:
		if _inventory_ctrl:
			return _inventory_ctrl.get_inventory_chips()
		return {}

var _satellite_banner_node: Control:
	get:
		return _banner_mgr._satellite_banner_node if _banner_mgr else null
	set(val):
		if _banner_mgr:
			_banner_mgr._satellite_banner_node = val

var _unlock_banner_node: Control:
	get:
		return _banner_mgr._unlock_banner_node if _banner_mgr else null
	set(val):
		if _banner_mgr:
			_banner_mgr._unlock_banner_node = val

var current_credits: int:
	get:
		return _inventory_ctrl.current_credits if _inventory_ctrl else 120
	set(val):
		if _inventory_ctrl:
			_inventory_ctrl.current_credits = val

var current_biomass: int:
	get:
		return _inventory_ctrl.current_biomass if _inventory_ctrl else 0
	set(val):
		if _inventory_ctrl:
			_inventory_ctrl.current_biomass = val

func _ready() -> void:
	add_to_group("hud")
	_init_subcontrollers()

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if satellite_tracker and is_instance_valid(player):
		satellite_tracker.set_player(player)
	if arcana_tracker and is_instance_valid(player):
		arcana_tracker.set_player(player)
	if boss_tracker and is_instance_valid(player):
		boss_tracker.set_player(player)
	if chest_tracker and is_instance_valid(player) and chest_tracker.has_method("set_player"):
		chest_tracker.set_player(player)

	# Ocultar barra rectangular superior para priorizar el anillo diegético bajo la nave
	if health_bar:
		health_bar.visible = false
	if health_label:
		health_label.visible = false
	if satellite_radar_label:
		satellite_radar_label.visible = false

	if player:
		player.health_changed.connect(_on_health_changed)
		player.bomb_used.connect(_on_bomb_used)
		_on_health_changed(player.current_health, player.stats.get_stat(&"max_health"))
		_on_bomb_used(player.bomb_count)

		if player.has_signal("dash_updated"):
			player.dash_updated.connect(_on_dash_updated)
			_on_dash_updated(player.dash_charges, player.max_dash_charges, 1.0, player.is_focus_active)

		if player.inventory:
			player.inventory.item_added.connect(_on_inventory_item_added)

		if player.has_signal("biomass_changed"):
			player.biomass_changed.connect(update_biomass)
		update_biomass(player.run_biomass, SaveManager.get_biomass())

		if player.has_signal("credits_changed"):
			if not player.credits_changed.is_connected(update_credits):
				player.credits_changed.connect(update_credits)
		update_credits(player.run_credits)

		var weapon_ctrl := player.get_node_or_null("WeaponController") as WeaponController
		if weapon_ctrl:
			weapon_ctrl.laser_cooldown_updated.connect(update_laser_cooldown)
			weapon_ctrl.weapons_updated.connect(update_weapon_slots)
			if weapon_ctrl.has_signal("aim_mode_changed"):
				weapon_ctrl.aim_mode_changed.connect(_on_aim_mode_changed)
			update_weapon_slots(weapon_ctrl.equipped_weapons)
			_on_aim_mode_changed(weapon_ctrl.is_manual_aim)

	if not target_reticle and target_reticle_scene:
		target_reticle = target_reticle_scene.instantiate() as Node2D
		var spawn_parent: Node = get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
		if spawn_parent:
			spawn_parent.add_child.call_deferred(target_reticle)

func _init_subcontrollers() -> void:
	_abilities_ctrl = TacticalAbilitiesControllerClass.new()
	_abilities_ctrl.setup({
		"dash_button_body": dash_button_body,
		"dash_cd_overlay": dash_cd_overlay,
		"dash_cd_num": dash_cd_num,
		"dash_pip_1": dash_pip_1,
		"dash_pip_2": dash_pip_2,
		"dash_label": dash_label,
		"laser_button_body": laser_button_body,
		"laser_cd_overlay": laser_cd_overlay,
		"laser_cd_num": laser_cd_num,
		"laser_cd_label": laser_cd_label,
		"bomb_button_body": bomb_button_body,
		"bomb_overlay": bomb_overlay,
		"bomb_pip_1": bomb_pip_1,
		"bomb_pip_2": bomb_pip_2,
		"bomb_pip_3": bomb_pip_3,
		"bomb_label": bomb_label,
		"aim_mode_label": aim_mode_label
	})

	_inventory_ctrl = InventoryBarControllerClass.new()
	_inventory_ctrl.setup({
		"weapon_slots_row": weapon_slots_row,
		"inventory_row": inventory_row,
		"credits_label": credits_label,
		"biomass_label": biomass_label,
		"credit_icon": credit_icon
	})

	_banner_mgr = BannerManagerClass.new()

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

	run_time += delta
	if is_pre_round_active:
		var s: int = int(ceil(maxf(0.0, pre_round_time_left)))
		timer_label.text = "PRE-RONDA [00:%02d] | FASE DE DESPLIEGUE" % s
		timer_label.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
	else:
		timer_label.remove_theme_color_override("font_color")
		var wave_m: int = int(float(wave_time_left) / 60.0)
		var wave_s: int = int(wave_time_left) % 60
		timer_label.text = "Oleada %d [%02d:%02d] | Satélites: %d/%d" % [current_wave, wave_m, wave_s, wave_satellites_spawned, max_wave_satellites]

	if has_satellite and player:
		var dist: float = player.global_position.distance_to(active_satellite_pos)
		var dir := (active_satellite_pos - player.global_position).normalized()
		var arrow := "↑"
		if abs(dir.x) > abs(dir.y):
			arrow = "→" if dir.x > 0 else "←"
		else:
			arrow = "↓" if dir.y > 0 else "↑"
		satellite_radar_label.text = "Satélite #%d: %d m [%s]" % [satellite_index, int(dist), arrow]
	else:
		if wave_satellites_spawned < max_wave_satellites:
			satellite_radar_label.text = "Buscando satélite: %d / %d m" % [int(current_travel_dist), int(required_travel_dist)]
		else:
			satellite_radar_label.text = "Satélites de oleada agotados. Resiste hasta la prox. oleada"

func update_pre_round_status(time_left: float) -> void:
	is_pre_round_active = true
	pre_round_time_left = time_left

func update_wave_status(wave: int, time_left: float, satellites_spawned: int, max_satellites: int) -> void:
	is_pre_round_active = false
	current_wave = wave
	wave_time_left = time_left
	wave_satellites_spawned = satellites_spawned
	max_wave_satellites = max_satellites

func update_satellite_travel_dist(current_d: float, req_d: float) -> void:
	current_travel_dist = current_d
	required_travel_dist = req_d

func clear_satellite() -> void:
	has_satellite = false
	if satellite_tracker:
		satellite_tracker.clear_target()

func set_active_satellite(pos: Vector2, index: int) -> void:
	active_satellite_pos = pos
	satellite_index = index
	has_satellite = true
	if satellite_tracker:
		if is_instance_valid(player):
			satellite_tracker.set_player(player)
		satellite_tracker.set_target(pos, index)
	show_satellite_banner(index)

func show_satellite_banner(index: int) -> void:
	if _banner_mgr:
		_banner_mgr.show_satellite_banner(index, self)

func show_character_unlock_banner(char_id: StringName, title_text: String, desc_text: String) -> void:
	if _banner_mgr:
		_banner_mgr.show_character_unlock_banner(char_id, title_text, desc_text, self)

func update_laser_cooldown(current: float, max_val: float) -> void:
	if _abilities_ctrl:
		_abilities_ctrl.update_laser_cooldown(current, max_val)

func update_weapon_slots(weapons: Array) -> void:
	if _inventory_ctrl:
		_inventory_ctrl.update_weapon_slots(weapons, player.stats if is_instance_valid(player) else null)

func _update_weapon_cooldown_sweeps() -> void:
	if not is_instance_valid(player) or not _inventory_ctrl:
		return
	var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
	if w_ctrl:
		_inventory_ctrl.update_weapon_cooldown_sweeps(w_ctrl.equipped_weapons, player.stats if player else null)

func update_credits(amount: int) -> void:
	if _inventory_ctrl:
		_inventory_ctrl.update_credits(amount, get_tree())

func update_biomass(run_amount: int, total_persistent: int) -> void:
	if _inventory_ctrl:
		_inventory_ctrl.update_biomass(run_amount, total_persistent)

func update_exp(current: float, max_val: float, level: int) -> void:
	if exp_bar:
		exp_bar.max_value = max_val
		exp_bar.value = current
	if level_label:
		level_label.text = "NV. %d" % level

func _on_health_changed(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current
	if health_label:
		health_label.text = "%d / %d" % [int(current), int(max_val)]

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
	var chance_pct: int = 0
	if keys_count > 0:
		var k: float = float(keys_count)
		chance_pct = int(round((k / (10.0 + k)) * 100.0))
	key_label.text = "x%d (%d%% Gratis)" % [keys_count, chance_pct]
	var badge := find_child("KeyBadge", true, false) as Control
	if keys_count > 0:
		key_label.modulate = Color(0.35, 1.0, 0.65, 1.0)
		if badge:
			badge.pivot_offset = badge.size * 0.5
			var tw := create_tween()
			tw.tween_property(badge, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK)
			tw.tween_property(badge, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
	else:
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
	if boss_tracker:
		if is_instance_valid(player):
			boss_tracker.set_player(player)
		boss_tracker.set_target_node(target, title)

func clear_boss_tracking() -> void:
	if boss_tracker:
		boss_tracker.clear_target()

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
