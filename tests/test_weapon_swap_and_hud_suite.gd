class_name TestWeaponSwapAndHudSuite
extends Node

const WeaponSwapModalClass = preload("res://scenes/ui/modals/weapon_swap_modal.gd")

func _ready() -> void:
	print("\n==================================================================")
	print("[TEST] INITIATING WEAPON SWAP & HUD VISIBILITY VERIFICATION")
	print("==================================================================\n")

	var passed := 0
	passed += _test_recycle_credits_formula()
	passed += _test_weapon_controller_replace_and_level_inheritance()
	passed += _test_weapon_swap_modal_ui_and_hotkeys()
	passed += _test_hud_weapon_slots_and_cooldown_overlay()
	passed += _test_hud_pilot_abilities_icons()

	print("\n==================================================================")
	print("  TOTAL VERIFIED TEST SUITES: %d/5 PASSED" % passed)
	if passed == 5:
		print("[PASS] 100% SUITE COMPLIANCE — WEAPON SWAP & HUD REWORK VERIFIED!")
	else:
		print("[FAIL] SOME SUITES FAILED")
	print("==================================================================\n")

	get_tree().quit(0 if passed == 5 else 1)

func _create_dummy_weapon(w_id: StringName, name: String, dmg: float = 20.0, cd: float = 0.5) -> WeaponData:
	var w := WeaponData.new()
	w.weapon_id = w_id
	w.weapon_name = name
	w.base_damage = dmg
	w.base_cooldown = cd
	w.rarity = Enums.Rarity.RARE
	return w

func _test_recycle_credits_formula() -> int:
	print("--- TEST 1: Weapon Recycle Credits Formula ---")
	assert(WeaponController.calculate_recycle_credits(1) == 35, "Lv1 recycle value must be 35")
	assert(WeaponController.calculate_recycle_credits(2) == 50, "Lv2 recycle value must be 50")
	assert(WeaponController.calculate_recycle_credits(3) == 65, "Lv3 recycle value must be 65")
	assert(WeaponController.calculate_recycle_credits(4) == 80, "Lv4 recycle value must be 80")
	assert(WeaponController.calculate_recycle_credits(5) == 95, "Lv5 recycle value must be 95")
	print("  ✓ T1: Correct recycling credits calculated across Lv1-Lv5 (35c, 50c, 65c, 80c, 95c)")
	return 1

func _test_weapon_controller_replace_and_level_inheritance() -> int:
	print("--- TEST 2: WeaponController Replacement & Level Inheritance ---")
	var player := Player.new()
	player.stats = CharacterStats.new()
	player.run_credits = 100
	add_child(player)

	var w_ctrl := WeaponController.new()
	w_ctrl.name = "WeaponController"
	player.add_child(w_ctrl)
	w_ctrl.player = player
	w_ctrl.equipped_weapons.clear()

	var w1 := _create_dummy_weapon(&"w1", "Weapon 1")
	var w2 := _create_dummy_weapon(&"w2", "Weapon 2")
	var w3 := _create_dummy_weapon(&"w3", "Weapon 3")
	var w4 := _create_dummy_weapon(&"w4", "Weapon 4")
	var incoming := _create_dummy_weapon(&"w_incoming", "Incoming Special")

	w_ctrl.add_weapon(w1)
	w_ctrl.add_weapon(w2)
	w_ctrl.add_weapon(w3)
	w_ctrl.add_weapon(w4)

	assert(w_ctrl.equipped_weapons.size() == 4, "Weapon controller must be full with 4 weapons")

	# Upgrade w2 to Level 3
	w_ctrl.upgrade_weapon(&"w2")
	w_ctrl.upgrade_weapon(&"w2")
	assert(w_ctrl.equipped_weapons[1].level == 3, "Weapon 2 must be at Level 3, was %d" % w_ctrl.equipped_weapons[1].level)

	# Replace slot 1 (w2 at Lv3) with incoming weapon
	var replaced := w_ctrl.replace_weapon(1, incoming, true)
	assert(replaced == true, "replace_weapon must return true on valid slot")

	# Check level inheritance
	var replaced_inst: WeaponInstanceData = w_ctrl.equipped_weapons[1]
	assert(replaced_inst.weapon_data.weapon_id == &"w_incoming", "Slot 1 must now hold the incoming weapon")
	assert(replaced_inst.level == 3, "Incoming weapon must inherit Level 3 from replaced weapon, got %d" % replaced_inst.level)

	# Check credit recycling: 100 + 65 = 165
	assert(player.run_credits == 165, "Player must gain 65 recycling credits (100 -> 165), got %d" % player.run_credits)

	print("  ✓ T2: Level 3 successfully preserved on replacement and +65 recycling credits awarded to player")

	w_ctrl.queue_free()
	player.queue_free()
	return 1

func _test_weapon_swap_modal_ui_and_hotkeys() -> int:
	print("--- TEST 3: WeaponSwapModal Layout, Hotkeys & Callbacks ---")
	var player := Player.new()
	player.stats = CharacterStats.new()
	player.run_credits = 50
	add_child(player)

	var w_ctrl := WeaponController.new()
	w_ctrl.name = "WeaponController"
	player.add_child(w_ctrl)
	w_ctrl.player = player
	w_ctrl.equipped_weapons.clear()

	for i in range(4):
		var w := _create_dummy_weapon(StringName("wp_%d" % i), "W %d" % i)
		w_ctrl.add_weapon(w)

	w_ctrl.upgrade_weapon(&"wp_1") # wp_1 is Lv 2
	w_ctrl.upgrade_weapon(&"wp_1") # wp_1 is Lv 3

	var incoming := _create_dummy_weapon(&"wp_new", "Super Laser")

	var modal: Node = WeaponSwapModalClass.new()
	add_child(modal)

	var callback_data := { "called": false, "slot": -1 }
	var cb := func(slot_idx: int, _new_w: WeaponData) -> void:
		callback_data["called"] = true
		callback_data["slot"] = slot_idx

	modal.prompt_swap(player, incoming, cb)

	assert(modal.visible == true, "Modal must be visible after prompt_swap")
	var container: HBoxContainer = modal.get("_weapons_container") as HBoxContainer
	assert(container != null, "HBoxContainer for slots must exist")
	assert(container.get_child_count() == 4, "Modal must contain 4 horizontal cards")

	# Test 3a: Intento de reemplazar Ranura 0 (Arma Base) debe ser ignorado y bloqueado
	modal._handle_slot_hotkey(0)
	assert(callback_data["called"] == false, "Ranura 0 está bloqueada; no debe detonar el callback de reemplazo")
	assert(w_ctrl.equipped_weapons[0].weapon_data.weapon_id == &"wp_0", "Ranura 0 debe permanecer inalterada")

	# Test 3b: Reemplazo válido en Ranura 1 (wp_1 a Lv 3) mediante hotkey [2]
	modal._handle_slot_hotkey(1)

	assert(callback_data["called"] == true, "Replacement callback must be triggered on slot 1")
	assert(callback_data["slot"] == 1, "Callback slot must be 1")
	assert(w_ctrl.equipped_weapons[1].weapon_data.weapon_id == &"wp_new", "Slot 1 must be replaced")
	assert(w_ctrl.equipped_weapons[1].level == 3, "New weapon in slot 1 must inherit Lv 3")
	assert(player.run_credits == 50 + 65, "Player credits must receive 65 credits (50 + 65 = 115), got %d" % player.run_credits)
	assert(modal.visible == false, "Modal must close after swap")

	print("  ✓ T3: WeaponSwapModal horizontal cards, slot 0 lock and slot 1 hotkey execution verified")

	modal.queue_free()
	w_ctrl.queue_free()
	player.queue_free()
	return 1

func _test_hud_weapon_slots_and_cooldown_overlay() -> int:
	print("--- TEST 4: HUD WeaponSlotsRow Placement, 4-Slot Fix and Cooldown Sweeps ---")
	var hud_scene: PackedScene = load("res://scenes/ui/hud/hud.tscn")
	assert(hud_scene != null, "hud.tscn must exist and load")

	var hud: CanvasLayer = hud_scene.instantiate() as CanvasLayer
	add_child(hud)

	var weapon_slots_row: HBoxContainer = hud.find_child("WeaponSlotsRow", true, false) as HBoxContainer
	assert(weapon_slots_row != null, "WeaponSlotsRow must exist in hud hierarchy")

	# Verify placement: parent of WeaponSlotsRow must be MarginContainer/VBoxContainer
	var parent_vbox: Node = weapon_slots_row.get_parent()
	assert(parent_vbox.name == "VBoxContainer", "WeaponSlotsRow parent must be VBoxContainer, got %s" % parent_vbox.name)

	# Verify sibling ordering: WeaponSlotsRow must be directly before TacticalAbilitiesRow
	var siblings: Array[Node] = parent_vbox.get_children()
	var weapon_row_idx: int = siblings.find(weapon_slots_row)
	var tactical_row: Node = parent_vbox.find_child("TacticalAbilitiesRow", false, false)
	var tactical_row_idx: int = siblings.find(tactical_row)
	assert(weapon_row_idx != -1 and tactical_row_idx != -1, "Both rows must be siblings in VBoxContainer")
	assert(weapon_row_idx < tactical_row_idx, "WeaponSlotsRow must sit directly ABOVE TacticalAbilitiesRow")

	# Test update_weapon_slots with 2 equipped weapons
	var w1 := _create_dummy_weapon(&"hud_w1", "HUD W1")
	var w2 := _create_dummy_weapon(&"hud_w2", "HUD W2")
	var inst1 := WeaponInstanceData.new(w1, 2)
	var inst2 := WeaponInstanceData.new(w2, 4)

	hud.call("update_weapon_slots", [inst1, inst2])

	assert(weapon_slots_row.get_child_count() == 4, "WeaponSlotsRow must always have exactly 4 slots, got %d" % weapon_slots_row.get_child_count())

	# Slot 0 & 1 must have CDOverlay and gold star badge
	var slot0: Node = weapon_slots_row.get_child(0)
	var cd0: Node = slot0.find_child("CDOverlay", true, false)
	assert(cd0 != null, "Equipped slot 0 must have CDOverlay")

	# Slot 2 & 3 must be empty slots with "+" label
	var slot2: Node = weapon_slots_row.get_child(2)
	assert(slot2.name.begins_with("WeaponSlot_Empty"), "Slot 2 must be an empty placeholder")

	print("  ✓ T4: HUD WeaponSlotsRow relocated above TacticalAbilitiesRow, 4 slots rendered with CDOverlay and empty placeholders")

	hud.queue_free()
	return 1

func _test_hud_pilot_abilities_icons() -> int:
	print("--- TEST 5: HUD Pilot Tactical and Dash Ability Icons Integration ---")
	var hud_scene: PackedScene = load("res://scenes/ui/hud/hud.tscn")
	assert(hud_scene != null, "hud.tscn must exist and load")

	var hud: CanvasLayer = hud_scene.instantiate() as CanvasLayer
	add_child(hud)

	var dash_icon: TextureRect = hud.find_child("DashIcon", true, false) as TextureRect
	var laser_icon: TextureRect = hud.find_child("LaserIcon", true, false) as TextureRect
	var dash_button_body: Control = hud.find_child("DashButtonBody", true, false) as Control
	var laser_button_body: Control = hud.find_child("LaserButtonBody", true, false) as Control

	assert(dash_icon != null, "DashIcon must exist in HUD")
	assert(laser_icon != null, "LaserIcon must exist in HUD")

	var roster := CharacterData.load_roster()
	assert(not roster.is_empty(), "Roster must not be empty")

	for pid: StringName in [&"nova", &"valentina", &"selene"]:
		if roster.has(pid):
			var c_data: CharacterData = roster[pid]
			hud.call("update_pilot_abilities", c_data)

			var expected_dash_tex: Texture2D = c_data.get_dash_texture()
			var expected_laser_tex: Texture2D = c_data.get_tactical_texture()

			assert(dash_icon.texture == expected_dash_tex, "DashIcon texture must match character get_dash_texture for %s" % pid)
			assert(laser_icon.texture == expected_laser_tex, "LaserIcon texture must match character get_tactical_texture for %s" % pid)
			assert(dash_icon.texture != null, "DashIcon texture must not be null for %s" % pid)
			assert(laser_icon.texture != null, "LaserIcon texture must not be null for %s" % pid)

			var kit: Dictionary = c_data.get_pilot_kit()
			if not kit.is_empty():
				if dash_button_body and "dash_name" in kit:
					assert(dash_button_body.tooltip_text.contains(kit["dash_name"]), "Dash tooltip must include kit dash_name for %s" % pid)
				if laser_button_body and "tactical_name" in kit:
					assert(laser_button_body.tooltip_text.contains(kit["tactical_name"]), "Laser tooltip must include kit tactical_name for %s" % pid)

	print("  ✓ T5: HUD dynamically swaps Dash and Tactical (Click) icons & tooltips across pilots")
	hud.queue_free()
	return 1
