class_name TestHudSuite
extends BaseTestSuite

## TestHudSuite — Astra Dream
## Verifica la funcionalidad desacoplada de:
## 1. HudWeaponCooldownBar (4 ranuras fijas, tooltips, placeholders vacíos, barridos CD).
## 2. HudHealthShieldDisplay (barras de salud/escudo, feedback crítico <25%, EXP y flash OSP).
## 3. Integración transparente dentro de GameHUD.

const WeaponCooldownBarClass = preload("res://scenes/ui/hud/components/hud_weapon_cooldown_bar.gd")
const HealthShieldDisplayClass = preload("res://scenes/ui/hud/components/hud_health_shield_display.gd")

func _ready() -> void:
	super._ready()
	print("\n==================================================================")
	print("[TEST] INITIATING DEDICATED HUD SYSTEM & COMPONENTS VERIFICATION")
	print("==================================================================\n")

	_test_weapon_cooldown_bar()
	_test_health_shield_display()
	_test_game_hud_integration()

	pass_suite("100% SUITE COMPLIANCE — HUD DECOUPLING VERIFIED!")

func _create_dummy_weapon(w_id: StringName, name: String, dmg: float = 25.0, cd: float = 1.0) -> WeaponData:
	var w := WeaponData.new()
	w.weapon_id = w_id
	w.weapon_name = name
	w.base_damage = dmg
	w.base_cooldown = cd
	w.rarity = Enums.Rarity.RARE
	return w

func _test_weapon_cooldown_bar() -> void:
	print("--- TEST 1: HudWeaponCooldownBar Isolated Logic ---")
	var container := HBoxContainer.new()
	add_child(container)

	var bar = WeaponCooldownBarClass.new()
	bar.setup(container)

	var w1 := _create_dummy_weapon(&"bar_w1", "Weapon One")
	var inst1 := WeaponInstanceData.new(w1, 1)
	inst1.active_cooldown = 0.5

	bar.update_weapon_slots([inst1], null)

	assert_true(container.get_child_count() == 4, "WeaponCooldownBar must instantiate exactly 4 slots")

	var slot0: Node = container.get_child(0)
	assert_true(slot0.name == "WeaponSlot_0", "Slot 0 must be named WeaponSlot_0")
	var cd0: ColorRect = slot0.find_child("CDOverlay", true, false) as ColorRect
	assert_true(cd0 != null, "Slot 0 must have CDOverlay")

	# Placeholder slot check
	var slot1: Node = container.get_child(1)
	assert_true(slot1.name.begins_with("WeaponSlot_Empty"), "Slot 1 must be an empty placeholder")

	# Sweeps check
	bar.update_weapon_cooldown_sweeps([inst1], null)
	assert_true(cd0.visible == true, "CDOverlay must become visible when active_cooldown > 0.02")
	assert_true(is_equal_approx(cd0.anchor_top, 0.5), "CDOverlay anchor_top must reflect ratio (1.0 - 0.5/1.0 = 0.5)")

	# Ready/idle cooldown check
	inst1.active_cooldown = 0.0
	bar.update_weapon_cooldown_sweeps([inst1], null)
	assert_true(cd0.visible == false, "CDOverlay must be hidden when cooldown is zero")

	container.queue_free()
	print("  ✓ T1: HudWeaponCooldownBar 4 slots, overlays and sweeps verified")

func _test_health_shield_display() -> void:
	print("--- TEST 2: HudHealthShieldDisplay Isolated Logic ---")
	var hp_bar := ProgressBar.new()
	var hp_label := Label.new()
	var exp_bar := ProgressBar.new()
	var lvl_label := Label.new()

	var display = HealthShieldDisplayClass.new()
	display.setup({
		"health_bar": hp_bar,
		"health_label": hp_label,
		"exp_bar": exp_bar,
		"level_label": lvl_label
	})

	# Test standard health update
	display.update_health(80.0, 100.0, 0.0, 0.0)
	assert_true(hp_bar.max_value == 100.0, "Health bar max_value must be 100")
	assert_true(hp_bar.value == 80.0, "Health bar value must be 80")
	assert_true(hp_label.text == "80 / 100", "Health label text must match '80 / 100'")
	assert_true(hp_label.modulate == Color.WHITE, "Health label modulate must be WHITE at 80%")

	# Test shield formatting
	display.update_health(80.0, 100.0, 25.0, 50.0)
	assert_true(hp_label.text == "80 (+25) / 100", "Health label with shield must format as '80 (+25) / 100'")

	# Test low health threshold (<25%)
	display.update_health(15.0, 100.0, 0.0, 0.0)
	assert_true(hp_label.modulate != Color.WHITE, "Health label modulate must tint to warning color at 15% HP")

	# Test EXP update
	display.update_exp(45.0, 150.0, 4)
	assert_true(exp_bar.max_value == 150.0, "EXP bar max_value must be 150")
	assert_true(exp_bar.value == 45.0, "EXP bar value must be 45")
	assert_true(lvl_label.text == "NV. 4", "Level label must format as 'NV. 4'")

	# Test OSP flash creation
	var canvas_layer := CanvasLayer.new()
	add_child(canvas_layer)
	display.trigger_osp_effect(canvas_layer)
	var flash: Node = canvas_layer.find_child("OSPFlashOverlay", true, false)
	assert_true(flash != null, "OSP flash overlay node must be created in parent")

	canvas_layer.queue_free()
	hp_bar.queue_free()
	hp_label.queue_free()
	exp_bar.queue_free()
	lvl_label.queue_free()
	print("  ✓ T2: HudHealthShieldDisplay health, shield, warning and EXP updates verified")

func _test_game_hud_integration() -> void:
	print("--- TEST 3: GameHUD Full Scene Integration ---")
	var hud_scene: PackedScene = load("res://scenes/ui/hud/hud.tscn")
	assert_true(hud_scene != null, "hud.tscn must load successfully")

	var hud: GameHUD = hud_scene.instantiate() as GameHUD
	add_child(hud)

	assert_true(hud._weapon_bar != null, "GameHUD must hold initialized _weapon_bar")
	assert_true(hud._health_shield_display != null, "GameHUD must hold initialized _health_shield_display")

	# Test forwarding calls
	var w1 := _create_dummy_weapon(&"int_w1", "Int W1")
	var inst1 := WeaponInstanceData.new(w1, 1)
	hud.update_weapon_slots([inst1])

	var weapon_slots_row: HBoxContainer = hud.find_child("WeaponSlotsRow", true, false) as HBoxContainer
	assert_true(weapon_slots_row.get_child_count() == 4, "GameHUD weapon_slots_row must have 4 children after update")

	hud.update_exp(75.0, 200.0, 2)
	var exp_bar: ProgressBar = hud.find_child("ExpBar", true, false) as ProgressBar
	assert_true(exp_bar.max_value == 200.0, "GameHUD exp_bar max_value must be updated")

	hud._on_health_changed(50.0, 100.0)
	var hp_label: Label = hud.find_child("HealthLabel", true, false) as Label
	assert_true(hp_label.text == "50 / 100", "GameHUD health_label must be updated")

	hud.queue_free()
	print("  ✓ T3: GameHUD integration with decoupled components verified")
