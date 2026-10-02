class_name GameHUD
extends CanvasLayer

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
var _inventory_chips: Dictionary[StringName, PanelContainer] = {}

func _ready() -> void:
	add_to_group("hud")
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if satellite_tracker and is_instance_valid(player):
		satellite_tracker.set_player(player)
	if arcana_tracker and is_instance_valid(player):
		arcana_tracker.set_player(player)
	if boss_tracker and is_instance_valid(player):
		boss_tracker.set_player(player)

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

func update_laser_cooldown(current: float, max_val: float) -> void:
	if current <= 0.0:
		if laser_cd_overlay:
			laser_cd_overlay.visible = false
		if laser_cd_num:
			laser_cd_num.visible = false
			laser_cd_num.text = ""
		if laser_cd_label:
			laser_cd_label.text = "[LISTO]"
			laser_cd_label.modulate = Color(0.2, 1.0, 1.0, 1.0)
	else:
		var cd_fraction: float = clampf(current / maxf(0.001, max_val), 0.0, 1.0)
		if laser_cd_overlay and laser_button_body:
			laser_cd_overlay.visible = true
			var h: float = laser_button_body.size.y if laser_button_body.size.y > 0.0 else 88.0
			var w: float = laser_button_body.size.x if laser_button_body.size.x > 0.0 else 88.0
			laser_cd_overlay.size = Vector2(w, h * cd_fraction)
			laser_cd_overlay.position = Vector2.ZERO

		if laser_cd_num:
			laser_cd_num.visible = true
			laser_cd_num.text = "%.1f" % current

		if laser_cd_label:
			laser_cd_label.text = "[%.1fs]" % current
			laser_cd_label.modulate = Color(1.0, 0.7, 0.2, 1.0)

func update_weapon_slots(weapons: Array) -> void:
	if not weapon_slots_row:
		return
	for child in weapon_slots_row.get_children():
		weapon_slots_row.remove_child(child)
		child.queue_free()

	const TOTAL_SLOTS: int = 4
	for slot_idx in range(TOTAL_SLOTS):
		if slot_idx < weapons.size() and weapons[slot_idx] != null:
			var inst: WeaponInstanceData = weapons[slot_idx]
			var wdata: WeaponData = inst.weapon_data
			var w_level: int = inst.level

			var chip := PanelContainer.new()
			chip.name = "WeaponSlot_%d" % slot_idx
			chip.custom_minimum_size = Vector2(44, 44)
			chip.clip_contents = true

			var eff_dmg: float = inst.get_effective_damage(player.stats if is_instance_valid(player) else null)
			var eff_cd: float = inst.get_effective_cooldown(player.stats if is_instance_valid(player) else null)
			chip.tooltip_text = "[Ranura %d] %s (★%d)\nDaño: %.1f | Enfriamiento: %.2fs\n%s" % [
				slot_idx + 1,
				wdata.weapon_name,
				w_level,
				eff_dmg,
				eff_cd,
				wdata.description
			]

			var rarity_color := _get_rarity_color(wdata.rarity)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.04, 0.06, 0.12, 0.95)
			style.set_border_width_all(2)
			style.border_color = rarity_color
			style.set_corner_radius_all(6)
			chip.add_theme_stylebox_override("panel", style)

			var inner := Control.new()
			inner.set_anchors_preset(Control.PRESET_FULL_RECT)
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(inner)

			var icon_rect := TextureRect.new()
			icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if wdata.icon:
				icon_rect.texture = wdata.icon
				icon_rect.modulate = rarity_color
			inner.add_child(icon_rect)

			var cd_overlay := ColorRect.new()
			cd_overlay.name = "CDOverlay"
			cd_overlay.color = Color(0.01, 0.02, 0.05, 0.75)
			cd_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cd_overlay.visible = false
			inner.add_child(cd_overlay)

			var slot_lbl := Label.new()
			slot_lbl.text = str(slot_idx + 1)
			slot_lbl.add_theme_font_size_override("font_size", 9)
			slot_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9, 0.5))
			slot_lbl.position = Vector2(4, 28)
			slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(slot_lbl)

			var lvl_lbl := Label.new()
			lvl_lbl.text = "★%d" % w_level
			lvl_lbl.add_theme_font_size_override("font_size", 10)
			lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			lvl_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
			lvl_lbl.add_theme_constant_override("shadow_offset_x", 1)
			lvl_lbl.add_theme_constant_override("shadow_offset_y", 1)
			lvl_lbl.position = Vector2(24, 2)
			lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(lvl_lbl)

			weapon_slots_row.add_child(chip)
		else:
			var empty_chip := PanelContainer.new()
			empty_chip.name = "WeaponSlot_Empty_%d" % slot_idx
			empty_chip.custom_minimum_size = Vector2(44, 44)
			empty_chip.tooltip_text = "Ranura #%d [Vacía]\n(Espacio disponible para nuevas armas)" % [slot_idx + 1]

			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.02, 0.04, 0.08, 0.45)
			style.border_color = Color(0.2, 0.35, 0.5, 0.35)
			style.set_border_width_all(1)
			style.set_corner_radius_all(6)
			empty_chip.add_theme_stylebox_override("panel", style)

			var inner := Control.new()
			inner.set_anchors_preset(Control.PRESET_FULL_RECT)
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty_chip.add_child(inner)

			var plus_lbl := Label.new()
			plus_lbl.text = "+"
			plus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			plus_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			plus_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
			plus_lbl.add_theme_font_size_override("font_size", 18)
			plus_lbl.add_theme_color_override("font_color", Color(0.3, 0.45, 0.6, 0.4))
			plus_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(plus_lbl)

			var slot_lbl := Label.new()
			slot_lbl.text = str(slot_idx + 1)
			slot_lbl.add_theme_font_size_override("font_size", 9)
			slot_lbl.add_theme_color_override("font_color", Color(0.3, 0.4, 0.5, 0.35))
			slot_lbl.position = Vector2(4, 28)
			slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(slot_lbl)

			weapon_slots_row.add_child(empty_chip)

func _update_weapon_cooldown_sweeps() -> void:
	if not is_instance_valid(player) or not weapon_slots_row:
		return
	var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
	if not w_ctrl:
		return
	var slots := weapon_slots_row.get_children()
	var count: int = mini(slots.size(), w_ctrl.equipped_weapons.size())
	for i in range(count):
		var inst: WeaponInstanceData = w_ctrl.equipped_weapons[i]
		if not inst:
			continue
		var slot_card: Node = slots[i]
		var cd_overlay := slot_card.find_child("CDOverlay", true, false) as ColorRect
		if not cd_overlay:
			continue
		var max_cd: float = inst.get_effective_cooldown(player.stats if player else null)
		if inst.active_cooldown > 0.02 and max_cd > 0.0:
			cd_overlay.visible = true
			var ratio: float = clampf(inst.active_cooldown / max_cd, 0.0, 1.0)
			cd_overlay.anchor_top = 1.0 - ratio
		else:
			cd_overlay.visible = false

func set_active_satellite(pos: Vector2, index: int) -> void:
	active_satellite_pos = pos
	satellite_index = index
	has_satellite = true
	if satellite_tracker:
		if is_instance_valid(player):
			satellite_tracker.set_player(player)
		satellite_tracker.set_target(pos, index)
	show_satellite_banner(index)

var _satellite_banner_node: Control = null
var _satellite_banner_tween: Tween = null

func show_satellite_banner(index: int) -> void:
	if not _satellite_banner_node:
		_create_satellite_banner_ui()
	if not _satellite_banner_node:
		return

	var title_lbl: Label = _satellite_banner_node.find_child("BannerTitle", true, false) as Label
	var sub_lbl: Label = _satellite_banner_node.find_child("BannerSubtitle", true, false) as Label
	if title_lbl:
		title_lbl.text = "🛰️ ENLACE DE SATÉLITE DETECTADO"
	if sub_lbl:
		sub_lbl.text = "Baliza orbital #%d en línea • Trayectoria en radar" % index

	if _satellite_banner_tween and _satellite_banner_tween.is_valid():
		_satellite_banner_tween.kill()

	_satellite_banner_node.visible = true
	_satellite_banner_node.modulate.a = 0.0
	_satellite_banner_node.offset_left = -230.0
	_satellite_banner_node.offset_right = 230.0
	_satellite_banner_node.offset_top = 100.0
	_satellite_banner_node.offset_bottom = 160.0

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.55)

	_satellite_banner_tween = create_tween()
	_satellite_banner_tween.set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_satellite_banner_tween.tween_property(_satellite_banner_node, "offset_top", 125.0, 0.28)
	_satellite_banner_tween.tween_property(_satellite_banner_node, "offset_bottom", 185.0, 0.28)
	_satellite_banner_tween.tween_property(_satellite_banner_node, "modulate:a", 1.0, 0.22)
	_satellite_banner_tween.chain().tween_interval(5.0)
	_satellite_banner_tween.chain().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_satellite_banner_tween.tween_property(_satellite_banner_node, "offset_top", 100.0, 0.35)
	_satellite_banner_tween.tween_property(_satellite_banner_node, "offset_bottom", 160.0, 0.35)
	_satellite_banner_tween.tween_property(_satellite_banner_node, "modulate:a", 0.0, 0.35)
	_satellite_banner_tween.chain().tween_callback(func():
		if _satellite_banner_node:
			_satellite_banner_node.visible = false
	)

func _create_satellite_banner_ui() -> void:
	var banner_box := PanelContainer.new()
	banner_box.name = "SatelliteBannerPanel"
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.layout_mode = 1
	banner_box.anchors_preset = Control.PRESET_CENTER_TOP
	banner_box.anchor_left = 0.5
	banner_box.anchor_right = 0.5
	banner_box.offset_left = -230.0
	banner_box.offset_top = 125.0
	banner_box.offset_right = 230.0
	banner_box.offset_bottom = 185.0
	banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_box.custom_minimum_size = Vector2(460, 60)
	banner_box.pivot_offset = Vector2(230, 30)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.12, 0.88)
	style.border_color = Color(0.0, 0.85, 1.0, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8.0)
	style.shadow_color = Color(0.0, 0.7, 0.9, 0.35)
	style.shadow_size = 8
	banner_box.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)

	var title := Label.new()
	title.name = "BannerTitle"
	title.text = "🛰️ ENLACE DE SATÉLITE DETECTADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#00E5FF"))
	vbox.add_child(title)

	var sub := Label.new()
	sub.name = "BannerSubtitle"
	sub.text = "Baliza orbital en línea"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 0.9))
	vbox.add_child(sub)

	banner_box.add_child(vbox)
	add_child(banner_box)
	_satellite_banner_node = banner_box
	_satellite_banner_node.visible = false

var _unlock_banner_node: Control = null
var _unlock_banner_tween: Tween = null

func show_character_unlock_banner(char_id: StringName, title_text: String, desc_text: String) -> void:
	if not _unlock_banner_node:
		_create_unlock_banner_ui()
	if not _unlock_banner_node:
		return

	var title_lbl: Label = _unlock_banner_node.find_child("UnlockTitle", true, false) as Label
	var desc_lbl: Label = _unlock_banner_node.find_child("UnlockDesc", true, false) as Label
	if title_lbl:
		title_lbl.text = title_text
	if desc_lbl:
		desc_lbl.text = desc_text

	if _unlock_banner_tween and _unlock_banner_tween.is_valid():
		_unlock_banner_tween.kill()

	_unlock_banner_node.visible = true
	_unlock_banner_node.modulate.a = 0.0
	_unlock_banner_node.scale = Vector2(0.8, 0.8)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.8)

	_unlock_banner_tween = create_tween()
	_unlock_banner_tween.set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_unlock_banner_tween.tween_property(_unlock_banner_node, "scale", Vector2(1.0, 1.0), 0.4)
	_unlock_banner_tween.tween_property(_unlock_banner_node, "modulate:a", 1.0, 0.28)
	_unlock_banner_tween.chain().tween_interval(5.0)
	_unlock_banner_tween.chain().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_unlock_banner_tween.tween_property(_unlock_banner_node, "modulate:a", 0.0, 0.5)
	_unlock_banner_tween.chain().tween_callback(func():
		if _unlock_banner_node:
			_unlock_banner_node.visible = false
	)

func _create_unlock_banner_ui() -> void:
	var banner_box := PanelContainer.new()
	banner_box.name = "CharacterUnlockPanel"
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.layout_mode = 1
	banner_box.anchors_preset = Control.PRESET_CENTER_TOP
	banner_box.anchor_left = 0.5
	banner_box.anchor_right = 0.5
	banner_box.offset_left = -290.0
	banner_box.offset_top = 125.0
	banner_box.offset_right = 290.0
	banner_box.offset_bottom = 235.0
	banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_box.custom_minimum_size = Vector2(580, 110)
	banner_box.pivot_offset = Vector2(290, 55)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.02, 0.12, 0.95)
	style.border_color = Color(0.9, 0.25, 1.0, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16.0)
	style.shadow_color = Color(0.9, 0.2, 1.0, 0.5)
	style.shadow_size = 18
	banner_box.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var badge := Label.new()
	badge.text = "★ ARCHIVO DE CARRERA ACTUALIZADO ★"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.95))
	vbox.add_child(badge)

	var title := Label.new()
	title.name = "UnlockTitle"
	title.text = "¡NUEVO PILOTO DESBLOQUEADO: NYX!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.35, 1.0))
	vbox.add_child(title)

	var desc := Label.new()
	desc.name = "UnlockDesc"
	desc.text = "Has derrotado a 10 Jefes Titanes en tu Carrera espacial."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 0.9))
	vbox.add_child(desc)

	banner_box.add_child(vbox)
	add_child(banner_box)
	_unlock_banner_node = banner_box
	_unlock_banner_node.visible = false

var current_credits: int = 120
var current_biomass: int = 0

var _credit_punch_tween: Tween = null

func update_credits(amount: int) -> void:
	var diff: int = amount - current_credits
	current_credits = amount
	_refresh_economy_label()
	if diff > 0 and is_inside_tree() and is_instance_valid(credit_icon):
		if _credit_punch_tween and _credit_punch_tween.is_valid():
			_credit_punch_tween.kill()
		credit_icon.pivot_offset = credit_icon.size / 2.0
		_credit_punch_tween = create_tween()
		_credit_punch_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_credit_punch_tween.tween_property(credit_icon, "scale", Vector2(1.35, 1.35), 0.1)
		_credit_punch_tween.chain().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_credit_punch_tween.tween_property(credit_icon, "scale", Vector2(1.0, 1.0), 0.16)

func update_biomass(_run_amount: int, total_persistent: int) -> void:
	current_biomass = total_persistent
	_refresh_economy_label()

func _refresh_economy_label() -> void:
	if credits_label:
		credits_label.text = "%d C" % current_credits
	if biomass_label:
		biomass_label.text = "%d" % current_biomass

func update_exp(current: float, max_val: float, level: int) -> void:
	exp_bar.max_value = max_val
	exp_bar.value = current
	level_label.text = "NV. %d" % level

func _on_health_changed(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current
	if health_label:
		health_label.text = "%d / %d" % [int(current), int(max_val)]

var _bomb_pip_lit_style: StyleBoxFlat = null
var _bomb_pip_dim_style: StyleBoxFlat = null

func _setup_bomb_pip_styles() -> void:
	_bomb_pip_lit_style = StyleBoxFlat.new()
	_bomb_pip_lit_style.bg_color = Color(1.0, 0.35, 1.0, 1.0)
	_bomb_pip_lit_style.set_corner_radius_all(3)
	_bomb_pip_lit_style.shadow_color = Color(1.0, 0.2, 1.0, 0.7)
	_bomb_pip_lit_style.shadow_size = 4

	_bomb_pip_dim_style = StyleBoxFlat.new()
	_bomb_pip_dim_style.bg_color = Color(0.12, 0.08, 0.16, 0.55)
	_bomb_pip_dim_style.set_border_width_all(1)
	_bomb_pip_dim_style.border_color = Color(0.28, 0.18, 0.35, 0.5)
	_bomb_pip_dim_style.set_corner_radius_all(3)

func _on_bomb_used(remaining: int) -> void:
	if not _bomb_pip_lit_style:
		_setup_bomb_pip_styles()

	if bomb_pip_1:
		bomb_pip_1.add_theme_stylebox_override("panel", _bomb_pip_lit_style if remaining >= 1 else _bomb_pip_dim_style)
	if bomb_pip_2:
		bomb_pip_2.add_theme_stylebox_override("panel", _bomb_pip_lit_style if remaining >= 2 else _bomb_pip_dim_style)
	if bomb_pip_3:
		bomb_pip_3.add_theme_stylebox_override("panel", _bomb_pip_lit_style if remaining >= 3 else _bomb_pip_dim_style)

	if bomb_overlay:
		bomb_overlay.visible = (remaining <= 0)
		if remaining <= 0:
			bomb_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	if bomb_label:
		bomb_label.text = "x%d" % remaining

func _on_inventory_item_added(item: ItemData, count: int) -> void:
	if not inventory_row:
		return

	var id: StringName = item.item_id
	if _inventory_chips.has(id):
		var chip: PanelContainer = _inventory_chips[id]
		var count_lbl := chip.get_node_or_null("Margin/CountLabel") as Label
		if count_lbl:
			count_lbl.text = "x%d" % count
		chip.tooltip_text = "%s (x%d)\n%s" % [item.item_name, count, item.description]
		return

	# Crear ficha de inventario de 32x32 px con icono de 24x24 px
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(32, 32)
	chip.tooltip_text = "%s (x%d)\n%s" % [item.item_name, count, item.description]

	var rarity_color := _get_rarity_color(item.rarity)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.9)
	style.set_border_width_all(1)
	style.border_color = rarity_color
	style.set_corner_radius_all(4)
	chip.add_theme_stylebox_override("panel", style)
	chip.modulate.a = 0.85

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if item.icon:
		icon_rect.texture = item.icon
		icon_rect.modulate = rarity_color

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set("theme_override_constants/margin_left", 2)
	margin.set("theme_override_constants/margin_right", 2)
	margin.set("theme_override_constants/margin_top", 2)
	margin.set("theme_override_constants/margin_bottom", 2)

	var count_lbl := Label.new()
	count_lbl.name = "CountLabel"
	count_lbl.text = "x%d" % count
	count_lbl.add_theme_font_size_override("font_size", 10)
	count_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	count_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	count_lbl.add_theme_constant_override("shadow_offset_x", 1)
	count_lbl.add_theme_constant_override("shadow_offset_y", 1)
	count_lbl.size_flags_horizontal = Control.SIZE_SHRINK_END
	count_lbl.size_flags_vertical = Control.SIZE_SHRINK_END

	chip.add_child(icon_rect)
	margin.add_child(count_lbl)
	chip.add_child(margin)

	inventory_row.add_child(chip)
	_inventory_chips[id] = chip

func _get_rarity_color(rarity: Enums.Rarity) -> Color:
	match rarity:
		Enums.Rarity.COMMON:
			return Color(0.5, 0.8, 1.0, 0.95)
		Enums.Rarity.UNCOMMON:
			return Color(0.2, 0.95, 0.4, 0.95)
		Enums.Rarity.RARE:
			return Color(1.0, 0.8, 0.15, 1.0)
		Enums.Rarity.LEGENDARY:
			return Color(0.9, 0.3, 1.0, 1.0)
		_:
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

var _pip_lit_style: StyleBoxFlat = null
var _pip_dim_style: StyleBoxFlat = null

func _setup_pip_styles() -> void:
	_pip_lit_style = StyleBoxFlat.new()
	_pip_lit_style.bg_color = Color(0.1, 0.95, 0.8, 1.0)
	_pip_lit_style.set_corner_radius_all(3)
	_pip_lit_style.shadow_color = Color(0.0, 0.9, 1.0, 0.6)
	_pip_lit_style.shadow_size = 4

	_pip_dim_style = StyleBoxFlat.new()
	_pip_dim_style.bg_color = Color(0.08, 0.14, 0.22, 0.55)
	_pip_dim_style.set_border_width_all(1)
	_pip_dim_style.border_color = Color(0.15, 0.25, 0.38, 0.5)
	_pip_dim_style.set_corner_radius_all(3)

func _on_dash_updated(current_charges: int, max_charges: int, recharge_ratio: float, is_focus: bool) -> void:
	if not _pip_lit_style:
		_setup_pip_styles()

	if dash_pip_1:
		dash_pip_1.add_theme_stylebox_override("panel", _pip_lit_style if current_charges >= 1 else _pip_dim_style)
	if dash_pip_2:
		dash_pip_2.add_theme_stylebox_override("panel", _pip_lit_style if current_charges >= 2 else _pip_dim_style)

	var is_recharging: bool = (current_charges < max_charges)
	if is_recharging:
		var cd_fraction: float = clampf(1.0 - recharge_ratio, 0.0, 1.0)
		if dash_cd_overlay and dash_button_body:
			dash_cd_overlay.visible = true
			var h: float = dash_button_body.size.y if dash_button_body.size.y > 0.0 else 88.0
			var w: float = dash_button_body.size.x if dash_button_body.size.x > 0.0 else 88.0
			dash_cd_overlay.size = Vector2(w, h * cd_fraction)
			dash_cd_overlay.position = Vector2.ZERO

		if dash_cd_num:
			dash_cd_num.visible = true
			var dash_max_time: float = player.dash_recharge_max if (is_instance_valid(player) and "dash_recharge_max" in player) else 1.6
			var time_left: float = maxf(0.0, dash_max_time * (1.0 - recharge_ratio))
			dash_cd_num.text = "%.1f" % time_left
	else:
		if dash_cd_overlay:
			dash_cd_overlay.visible = false
		if dash_cd_num:
			dash_cd_num.visible = false
			dash_cd_num.text = ""

	if dash_label:
		if is_focus:
			dash_label.text = "ENFOQUE"
			dash_label.modulate = Color(1.0, 0.3, 0.9, 1.0)
		elif current_charges > 0:
			dash_label.text = "[LISTO]"
			dash_label.modulate = Color(0.3, 1.0, 0.6, 1.0)
		else:
			dash_label.text = "[%d%%]" % int(recharge_ratio * 100.0)
			dash_label.modulate = Color(0.7, 0.7, 0.7, 1.0)

func _on_aim_mode_changed(is_manual: bool) -> void:
	if not aim_mode_label:
		return
	if is_manual:
		aim_mode_label.text = "[E] AIM: MANUAL"
		aim_mode_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15, 1.0))
	else:
		aim_mode_label.text = "[E] AIM: AUTO"
		aim_mode_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0, 1.0))
