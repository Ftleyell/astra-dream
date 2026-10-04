extends Node

## ==============================================================================
## TEST SUITE: Phase 5 UI & HUD Feedback Visual Verification
## Tests CurseBadge, Tactical Alert Banners (OSP, Chronos Bank, Heavy Salvager),
## and CharacterStatsOverlay integration.
## ==============================================================================

var _passed_count: int = 0
var _failed_count: int = 0
var _test_log: Array[String] = []

func _ready() -> void:
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		_log_fail("WATCHDOG", "Test suite execution timed out after 10 seconds!")
		_finish_and_quit()
	)

	print("\n==================================================================")
	print("[PHASE 5 UI FEEDBACK SUITE] STARTING AUTOMATED VERIFICATION")
	print("==================================================================")

	_run_test_1_hud_curse_badge_lifecycle()
	_run_test_2_player_stat_changed_curse_hook()
	_run_test_3_hud_tactical_alert_banner()
	_run_test_4_osp_triggers_tactical_alert()
	_run_test_5_chronos_bank_tactical_alert()
	_run_test_6_heavy_salvager_tactical_alert()
	_run_test_7_stats_overlay_curse_category()

	_finish_and_quit()

func _finish_and_quit() -> void:
	print("\n==================================================================")
	print("[PHASE 5 UI FEEDBACK SUITE] RESULTS: %d PASSED, %d FAILED" % [_passed_count, _failed_count])
	print("==================================================================")
	for entry in _test_log:
		print(entry)
	if _failed_count == 0:
		print(">> ALL PHASE 5 UI FEEDBACK TESTS PASSED PERFECTLY <<\n")
		get_tree().quit(0)
	else:
		printerr(">> SOME PHASE 5 UI FEEDBACK TESTS FAILED <<\n")
		get_tree().quit(1)

func _log_pass(tag: String, details: String) -> void:
	_passed_count += 1
	var msg := "  ✓ [PASS] %s: %s" % [tag, details]
	_test_log.append(msg)
	print(msg)

func _log_fail(tag: String, details: String) -> void:
	_failed_count += 1
	var msg := "  ✗ [FAIL] %s: %s" % [tag, details]
	_test_log.append(msg)
	printerr(msg)

## ─────────────────────────────────────────────────────────────────────────────
## TEST 1: HUD CurseBadge Lifecycle
## ─────────────────────────────────────────────────────────────────────────────
func _run_test_1_hud_curse_badge_lifecycle() -> void:
	print("\n--- TEST 1: HUD CurseBadge Lifecycle ---")
	var hud_scene: PackedScene = load("res://scenes/ui/hud/hud.tscn")
	if not hud_scene:
		_log_fail("Test 1 - Load HUD", "Could not load res://scenes/ui/hud/hud.tscn")
		return
	var hud: GameHUD = hud_scene.instantiate() as GameHUD
	add_child(hud)

	if hud.curse_badge != null:
		_log_pass("Test 1 - CurseBadge Created", "CurseBadge instance exists in HUD")
	else:
		_log_fail("Test 1 - CurseBadge Created", "hud.curse_badge is null")

	if hud.curse_badge and not hud.curse_badge.visible:
		_log_pass("Test 1 - Initial Visibility", "CurseBadge is initially hidden (curse = 0)")
	else:
		_log_fail("Test 1 - Initial Visibility", "CurseBadge should be initially hidden")

	# Test update_curse with positive value
	hud.update_curse(15.0)
	if hud.curse_badge.visible:
		_log_pass("Test 1 - Positive Visibility", "CurseBadge is visible when curse > 0")
	else:
		_log_fail("Test 1 - Positive Visibility", "CurseBadge should be visible when curse > 0")

	if hud.curse_label and hud.curse_label.text.contains("+15 pts"):
		_log_pass("Test 1 - Text Format", "CurseLabel shows correct text: '%s'" % hud.curse_label.text)
	else:
		_log_fail("Test 1 - Text Format", "CurseLabel expected '+15 pts', got: '%s'" % (hud.curse_label.text if hud.curse_label else "null"))

	# Test update_curse with zero
	hud.update_curse(0.0)
	if not hud.curse_badge.visible:
		_log_pass("Test 1 - Reset Visibility", "CurseBadge hidden when curse returns to 0")
	else:
		_log_fail("Test 1 - Reset Visibility", "CurseBadge should be hidden when curse returns to 0")

	hud.queue_free()

## ─────────────────────────────────────────────────────────────────────────────
## TEST 2: Player stat_changed signal connection with HUD CurseBadge
## ─────────────────────────────────────────────────────────────────────────────
func _run_test_2_player_stat_changed_curse_hook() -> void:
	print("\n--- TEST 2: Player stat_changed signal connection with HUD CurseBadge ---")
	var hud_scene: PackedScene = load("res://scenes/ui/hud/hud.tscn")
	var hud: GameHUD = hud_scene.instantiate() as GameHUD
	add_child(hud)

	var player_data: CharacterData = CharacterData.new()
	player_data.max_health = 100.0
	var player: Player = Player.new()
	player.stats.initialize(player_data)
	add_child(player)

	hud.set_player(player)

	# Add curse modifier to player
	var mod := CharacterStats.StatModifier.new(&"test_curse", 35.0, Enums.ModifierType.FLAT)
	player.stats.add_modifier(&"curse", mod)

	if hud.curse_badge and hud.curse_badge.visible:
		_log_pass("Test 2 - Auto Update Visible", "CurseBadge automatically showed on stat_changed")
	else:
		_log_fail("Test 2 - Auto Update Visible", "CurseBadge did not show on stat_changed")

	if hud.curse_label and hud.curse_label.text.contains("+35 pts"):
		_log_pass("Test 2 - Auto Update Value", "CurseLabel automatically set to '+35 pts'")
	else:
		_log_fail("Test 2 - Auto Update Value", "CurseLabel did not update properly")

	# Remove modifier
	player.stats.remove_modifier(&"curse", &"test_curse")
	if hud.curse_badge and not hud.curse_badge.visible:
		_log_pass("Test 2 - Auto Reset", "CurseBadge automatically hid on stat_changed removal")
	else:
		_log_fail("Test 2 - Auto Reset", "CurseBadge did not hide after removing curse modifier")

	player.queue_free()
	hud.queue_free()

## ─────────────────────────────────────────────────────────────────────────────
## TEST 3: Tactical Alert Banner Creation and Styling
## ─────────────────────────────────────────────────────────────────────────────
func _run_test_3_hud_tactical_alert_banner() -> void:
	print("\n--- TEST 3: Tactical Alert Banner Creation and Styling ---")
	var hud_scene: PackedScene = load("res://scenes/ui/hud/hud.tscn")
	var hud: GameHUD = hud_scene.instantiate() as GameHUD
	add_child(hud)

	var alert_color := Color(1.0, 0.4, 0.2)
	hud.show_tactical_alert("ALERTA CRÍTICA", "Subtexto informativo de prueba", alert_color)

	var panel: Control = hud._tactical_alert_node
	if panel != null:
		_log_pass("Test 3 - Panel Created", "TacticalAlertPanel successfully created")
	else:
		_log_fail("Test 3 - Panel Created", "TacticalAlertPanel is null")
		hud.queue_free()
		return

	if panel.visible:
		_log_pass("Test 3 - Panel Visible", "TacticalAlertPanel is visible upon show")
	else:
		_log_fail("Test 3 - Panel Visible", "TacticalAlertPanel is not visible")

	var title_lbl: Label = panel.find_child("AlertTitle", true, false) as Label
	var sub_lbl: Label = panel.find_child("AlertSubtitle", true, false) as Label

	if title_lbl and title_lbl.text == "ALERTA CRÍTICA":
		_log_pass("Test 3 - Title Text", "AlertTitle matches: 'ALERTA CRÍTICA'")
	else:
		_log_fail("Test 3 - Title Text", "AlertTitle text mismatch: '%s'" % (title_lbl.text if title_lbl else "null"))

	if sub_lbl and sub_lbl.text == "Subtexto informativo de prueba":
		_log_pass("Test 3 - Subtitle Text", "AlertSubtitle matches expected subtext")
	else:
		_log_fail("Test 3 - Subtitle Text", "AlertSubtitle text mismatch: '%s'" % (sub_lbl.text if sub_lbl else "null"))

	hud.queue_free()

## ─────────────────────────────────────────────────────────────────────────────
## TEST 4: OSP triggers tactical alert
## ─────────────────────────────────────────────────────────────────────────────
func _run_test_4_osp_triggers_tactical_alert() -> void:
	print("\n--- TEST 4: OSP triggers tactical alert ---")
	var hud_scene: PackedScene = load("res://scenes/ui/hud/hud.tscn")
	var hud: GameHUD = hud_scene.instantiate() as GameHUD
	add_child(hud)

	hud._on_osp_triggered(1.0)

	var panel: Control = hud._tactical_alert_node
	if panel and panel.visible:
		var title_lbl: Label = panel.find_child("AlertTitle", true, false) as Label
		if title_lbl and title_lbl.text.contains("PROTOCOLO OSP"):
			_log_pass("Test 4 - OSP Banner", "Tactical alert banner displayed for OSP activation")
		else:
			_log_fail("Test 4 - OSP Banner", "Banner text does not contain 'PROTOCOLO OSP': '%s'" % (title_lbl.text if title_lbl else "null"))
	else:
		_log_fail("Test 4 - OSP Banner", "Tactical alert panel not visible after OSP triggered")

	hud.queue_free()

## ─────────────────────────────────────────────────────────────────────────────
## TEST 5: Chronos Bank tactical alert
## ─────────────────────────────────────────────────────────────────────────────
func _run_test_5_chronos_bank_tactical_alert() -> void:
	print("\n--- TEST 5: Chronos Bank tactical alert ---")
	var mg: MainGame = MainGame.new()

	var hud_scene: PackedScene = load("res://scenes/ui/hud/hud.tscn")
	var hud: GameHUD = hud_scene.instantiate() as GameHUD
	add_child(hud)
	mg.hud = hud

	var player: Player = Player.new()
	var p_data: CharacterData = CharacterData.new()
	p_data.max_health = 100.0
	player.stats.initialize(p_data)
	player.run_credits = 250
	mg.player = player

	var bank_item: ItemData = ItemData.new()
	bank_item.item_id = &"chronos_bank"
	player.inventory.add_item(bank_item)

	mg.apply_chronos_bank_interest()

	if player.run_credits == 275:
		_log_pass("Test 5 - Interest Credits", "Chronos Bank added 25 credits (got 275)")
	else:
		_log_fail("Test 5 - Interest Credits", "Expected 275 credits, got %d" % player.run_credits)

	var panel: Control = hud._tactical_alert_node
	if panel and panel.visible:
		var title_lbl: Label = panel.find_child("AlertTitle", true, false) as Label
		var sub_lbl: Label = panel.find_child("AlertSubtitle", true, false) as Label
		if title_lbl and title_lbl.text.contains("BANCO CRONOS") and sub_lbl and sub_lbl.text.contains("+25 créditos"):
			_log_pass("Test 5 - Bank Alert Banner", "Chronos Bank tactical alert banner showed with +25 credits")
		else:
			_log_fail("Test 5 - Bank Alert Banner", "Chronos Bank banner contents mismatch: '%s' / '%s'" % [title_lbl.text if title_lbl else "", sub_lbl.text if sub_lbl else ""])
	else:
		_log_fail("Test 5 - Bank Alert Banner", "Chronos Bank tactical alert panel not visible")

	player.queue_free()
	hud.queue_free()
	mg.queue_free()

## ─────────────────────────────────────────────────────────────────────────────
## TEST 6: Heavy Salvager tactical alert
## ─────────────────────────────────────────────────────────────────────────────
func _run_test_6_heavy_salvager_tactical_alert() -> void:
	print("\n--- TEST 6: Heavy Salvager tactical alert ---")
	var mg: MainGame = MainGame.new()

	var hud_scene: PackedScene = load("res://scenes/ui/hud/hud.tscn")
	var hud: GameHUD = hud_scene.instantiate() as GameHUD
	add_child(hud)
	mg.hud = hud

	var player: Player = Player.new()
	var p_data: CharacterData = CharacterData.new()
	p_data.max_health = 100.0
	player.stats.initialize(p_data)
	player.current_health = 100.0
	player.run_credits = 10
	mg.player = player

	var salvager_item: ItemData = ItemData.new()
	salvager_item.item_id = &"heavy_salvager"
	player.inventory.add_item(salvager_item)

	mg.on_salvage_capsule_opened(player)

	if player.run_credits == 13:
		_log_pass("Test 6 - Salvager Credits", "Heavy Salvager added 3 credits (got 13)")
	else:
		_log_fail("Test 6 - Salvager Credits", "Expected 13 credits, got %d" % player.run_credits)

	var panel: Control = hud._tactical_alert_node
	if panel and panel.visible:
		var title_lbl: Label = panel.find_child("AlertTitle", true, false) as Label
		var sub_lbl: Label = panel.find_child("AlertSubtitle", true, false) as Label
		if title_lbl and title_lbl.text.contains("RECUPERADOR PESADO") and sub_lbl and sub_lbl.text.contains("+2 HP"):
			_log_pass("Test 6 - Salvager Alert Banner", "Heavy Salvager tactical alert banner showed with reward")
		else:
			_log_fail("Test 6 - Salvager Alert Banner", "Heavy Salvager banner contents mismatch: '%s' / '%s'" % [title_lbl.text if title_lbl else "", sub_lbl.text if sub_lbl else ""])
	else:
		_log_fail("Test 6 - Salvager Alert Banner", "Heavy Salvager tactical alert panel not visible")

	player.queue_free()
	hud.queue_free()
	mg.queue_free()

## ─────────────────────────────────────────────────────────────────────────────
## TEST 7: CharacterStatsOverlay contains Curse category
## ─────────────────────────────────────────────────────────────────────────────
func _run_test_7_stats_overlay_curse_category() -> void:
	print("\n--- TEST 7: CharacterStatsOverlay contains Curse category ---")
	var overlay_scene: PackedScene = load("res://scenes/ui/character_stats_overlay.tscn")
	if not overlay_scene:
		_log_fail("Test 7 - Load Overlay", "Could not load character_stats_overlay.tscn")
		return

	var overlay: CharacterStatsOverlay = overlay_scene.instantiate() as CharacterStatsOverlay
	add_child(overlay)

	var player: Player = Player.new()
	var p_data: CharacterData = CharacterData.new()
	p_data.max_health = 100.0
	player.stats.initialize(p_data)
	player.character_data = p_data
	add_child(player)

	overlay.player = player
	overlay.open_stats()

	# Inspect child labels in category panels
	var found_curse_category := false
	var found_curse_stat := false

	var all_labels := overlay.find_children("*", "Label", true, false)
	for lbl_node in all_labels:
		var lbl: Label = lbl_node as Label
		if lbl and lbl.text.contains("RIESGO Y CORRUPCIÓN"):
			found_curse_category = true
		if lbl and lbl.text.contains("MALDICIÓN"):
			found_curse_stat = true

	if found_curse_category:
		_log_pass("Test 7 - Category Found", "Category 'RIESGO Y CORRUPCIÓN' displayed in overlay")
	else:
		_log_fail("Test 7 - Category Found", "Category 'RIESGO Y CORRUPCIÓN' not found in overlay labels")

	if found_curse_stat:
		_log_pass("Test 7 - Stat Found", "Stat 'MALDICIÓN' displayed in overlay")
	else:
		_log_fail("Test 7 - Stat Found", "Stat 'MALDICIÓN' not found in overlay labels")

	player.queue_free()
	overlay.queue_free()

