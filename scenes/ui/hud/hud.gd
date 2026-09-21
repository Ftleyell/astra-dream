class_name GameHUD
extends CanvasLayer

@export var player: Player

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/TopRow/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/TopRow/HealthLabel
@onready var bomb_label: Label = $MarginContainer/VBoxContainer/TopRow/BombLabel
@onready var laser_cd_label: Label = $MarginContainer/VBoxContainer/TopRow/LaserCDLabel
@onready var credits_label: Label = $MarginContainer/VBoxContainer/TopRow/CreditsLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/TopRow/TimerLabel
@onready var satellite_radar_label: Label = $MarginContainer/VBoxContainer/BottomRow/SatelliteRadarLabel
@onready var exp_bar: ProgressBar = $MarginContainer/VBoxContainer/BottomRow/ExpBar
@onready var level_label: Label = $MarginContainer/VBoxContainer/BottomRow/LevelLabel
@onready var inventory_row: HBoxContainer = $MarginContainer/VBoxContainer/InventoryRow

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
var _inventory_chips: Dictionary[StringName, PanelContainer] = {}

func _ready() -> void:
	if player:
		player.health_changed.connect(_on_health_changed)
		player.bomb_used.connect(_on_bomb_used)
		_on_health_changed(player.current_health, player.stats.get_stat(&"max_health"))
		_on_bomb_used(player.bomb_count)

		if player.inventory:
			player.inventory.item_added.connect(_on_inventory_item_added)

		if player.has_signal("biomass_changed"):
			player.biomass_changed.connect(update_biomass)
		update_biomass(player.run_biomass, SaveManager.get_biomass())

		var weapon_ctrl := player.get_node_or_null("WeaponController") as WeaponController
		if weapon_ctrl:
			weapon_ctrl.laser_cooldown_updated.connect(update_laser_cooldown)

func _process(delta: float) -> void:
	run_time += delta
	var wave_m: int = int(wave_time_left) / 60
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

func update_wave_status(wave: int, time_left: float, satellites_spawned: int, max_satellites: int) -> void:
	current_wave = wave
	wave_time_left = time_left
	wave_satellites_spawned = satellites_spawned
	max_wave_satellites = max_satellites

func update_satellite_travel_dist(current_d: float, req_d: float) -> void:
	current_travel_dist = current_d
	required_travel_dist = req_d

func clear_satellite() -> void:
	has_satellite = false

func update_laser_cooldown(current: float, max_val: float) -> void:
	if not laser_cd_label:
		return
	if current <= 0.0:
		laser_cd_label.text = "Láser: [LISTO]"
		laser_cd_label.modulate = Color(0.2, 1.0, 1.0, 1.0)
	else:
		laser_cd_label.text = "Láser: [%.1fs]" % current
		laser_cd_label.modulate = Color(1.0, 0.7, 0.2, 1.0)

func set_active_satellite(pos: Vector2, index: int) -> void:
	active_satellite_pos = pos
	satellite_index = index
	has_satellite = true

var current_credits: int = 120
var current_biomass: int = 0

func update_credits(amount: int) -> void:
	current_credits = amount
	_refresh_economy_label()

func update_biomass(_run_amount: int, total_persistent: int) -> void:
	current_biomass = total_persistent
	_refresh_economy_label()

func _refresh_economy_label() -> void:
	if credits_label:
		credits_label.text = "Créditos: %d C | BioMasa: %d" % [current_credits, current_biomass]

func update_exp(current: float, max_val: float, level: int) -> void:
	exp_bar.max_value = max_val
	exp_bar.value = current
	level_label.text = "NV. %d" % level

func _on_health_changed(current: float, max_val: float) -> void:
	health_bar.max_value = max_val
	health_bar.value = current
	health_label.text = "%d / %d" % [int(current), int(max_val)]

func _on_bomb_used(remaining: int) -> void:
	bomb_label.text = "Bombas: %d" % remaining

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
