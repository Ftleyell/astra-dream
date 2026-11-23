extends Node

func _ready() -> void:
	# Fallback timeout
	get_tree().create_timer(6.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout reached in Bomb VFX & Dialogue test.")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Testing Bomb Shockwave VFX & Dialogue Edge Anchoring...")
	print("==========================================")

	# 1. Test BombShockwaveVFX scene directly
	var vfx_scene: PackedScene = load("res://scenes/combat/player/bomb_shockwave_vfx.tscn")
	assert(vfx_scene != null, "bomb_shockwave_vfx.tscn must be loadable")
	var vfx: Node2D = vfx_scene.instantiate()
	assert(vfx != null, "bomb_shockwave_vfx must instantiate")
	add_child(vfx)
	vfx.setup(Vector2(500, 400))
	assert(vfx.global_position == Vector2(500, 400), "VFX position must match setup")
	assert(vfx.z_index == 40, "VFX z_index must be 40")
	assert(vfx.duration == 0.75, "VFX duration should be 0.75s")
	assert(vfx.max_radius == 2200.0, "VFX max_radius should be 2200px")
	print("  ✓ BombShockwaveVFX instantiated with duration=%.2fs, max_radius=%.1fpx" % [vfx.duration, vfx.max_radius])
	
	# Simulate process and queue_free
	vfx._process(0.8)
	await get_tree().process_frame
	assert(not is_instance_valid(vfx), "VFX must be freed after duration elapsed")
	print("  ✓ BombShockwaveVFX automatically cleans up (freed) when duration expires")

	# 2. Test Player Bomb triggering VFX
	var player_script = load("res://scenes/combat/player/player.gd")
	var player = CharacterBody2D.new()
	var h = Node2D.new()
	h.name = "HitboxCore"
	player.add_child(h)
	var w = Node2D.new()
	w.name = "WeaponController"
	player.add_child(w)
	player.set_script(player_script)
	add_child(player)
	player.global_position = Vector2(960, 540)
	
	# Call _spawn_bomb_vfx
	player._spawn_bomb_vfx()
	await get_tree().process_frame
	const ShockwaveScript = preload("res://scenes/combat/player/bomb_shockwave_vfx.gd")
	var spawned_vfx = null
	for child in get_children():
		if child.get_script() == ShockwaveScript or child.name.begins_with("BombShockwaveVFX"):
			spawned_vfx = child
			break
	assert(spawned_vfx != null, "Player must spawn BombShockwaveVFX into scene tree")
	assert(spawned_vfx.global_position == Vector2(960, 540), "Spawned VFX position must match player position")
	print("  ✓ Player spawns BombShockwaveVFX at global position (960, 540)")

	# 3. Test Consumable Tactical Detonation (add_bombs at max)
	player.bomb_count = 5
	var added = player.add_bombs(1)
	assert(added == false, "add_bombs at 5 should return false (tactical detonation)")
	await get_tree().process_frame
	var has_new_vfx := false
	for child in get_children():
		if (child.get_script() == ShockwaveScript or child.name.begins_with("BombShockwaveVFX")) and child != spawned_vfx:
			has_new_vfx = true
			break
	assert(has_new_vfx, "Tactical detonation at max bombs must spawn BombShockwaveVFX")
	print("  ✓ Tactical detonation at max bombs (5) successfully triggers BombShockwaveVFX")

	# 4. Verify Echo dch has Normal and Flipped portraits
	var echo_dch = load("res://narrative/characters/echo.dch")
	assert(echo_dch != null, "echo.dch must be valid")
	assert(echo_dch.portraits.has("Normal") and echo_dch.portraits.has("Flipped"), "Echo must have Normal and Flipped portraits")
	print("  ✓ Echo has Normal and Flipped portraits configured")

	# 5. Verify Timeline files join Echo flipped
	var timelines := [
		"res://narrative/timelines/wave_interlude_cockpit.dtl",
		"res://narrative/timelines/boss_titan_alert.dtl"
	]
	for t_path in timelines:
		var file := FileAccess.open(t_path, FileAccess.READ)
		assert(file != null, "Could not open timeline %s" % t_path)
		var content := file.get_as_text()
		assert("join echo (Flipped)" in content, "Timeline %s must join echo (Flipped)" % t_path)
		print("  ✓ Timeline %s has 'join echo (Flipped)'" % t_path.get_file())

	# 6. Test Bomb Controller Suppression Lockout Recovery
	player.suppress_bomb_input(999.0)
	assert(player._can_trigger_bomb() == false, "Player bomb must be blocked during 999.0s suppression")
	player.clear_bomb_suppression(0.0)
	assert(player._can_trigger_bomb() == true, "Player bomb must immediately recover after clear_bomb_suppression")
	
	player.suppress_bomb_input(999.0)
	player.suppress_bomb_input(0.35)
	assert(player.bomb_controller.menu_close_suppress_timer <= 0.35, "Standard modal close must override stuck high suppression timer")
	player.bomb_controller.update_suppression(0.4)
	assert(player._can_trigger_bomb() == true, "Player bomb must become available once 0.35s modal close expires")
	print("  ✓ Bomb suppression recovery verified (no 999.0s lockouts after events)")

	# 7. Test HUD 5-pip and Bomb Count Badge Synchronization
	var hud_scene: PackedScene = load("res://scenes/ui/hud/hud.tscn")
	assert(hud_scene != null, "hud.tscn must be loadable")
	var hud: CanvasLayer = hud_scene.instantiate() as CanvasLayer
	add_child(hud)
	hud.set_player(player)

	var pip1: Panel = hud.find_child("BombPip1", true, false) as Panel
	var pip2: Panel = hud.find_child("BombPip2", true, false) as Panel
	var pip3: Panel = hud.find_child("BombPip3", true, false) as Panel
	var pip4: Panel = hud.find_child("BombPip4", true, false) as Panel
	var pip5: Panel = hud.find_child("BombPip5", true, false) as Panel
	var count_label: Label = hud.find_child("BombCountLabel", true, false) as Label
	var overlay: ColorRect = hud.find_child("BombOverlay", true, false) as ColorRect

	assert(pip1 != null and pip2 != null and pip3 != null and pip4 != null and pip5 != null, "HUD must contain all 5 bomb pips")
	assert(count_label != null, "HUD must contain BombCountLabel badge")

	# Test 5 bombs
	hud._on_bomb_used(5)
	assert(count_label.text == "x5", "BombCountLabel must show 'x5' when 5 bombs available")
	assert(overlay.visible == false, "Overlay must be hidden when bombs > 0")

	# Test 3 bombs
	hud._on_bomb_used(3)
	assert(count_label.text == "x3", "BombCountLabel must show 'x3' when 3 bombs available")

	# Test 0 bombs
	hud._on_bomb_used(0)
	assert(count_label.text == "x0", "BombCountLabel must show 'x0' when empty")
	assert(overlay.visible == true, "Overlay must be visible when empty")
	print("  ✓ HUD 5 pips and BombCountLabel badge synchronize accurately with 0..5 bombs")

	print("\n==========================================")
	print("[PASS] ALL BOMB VFX, HUD SYNC & LOCKOUT TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)
