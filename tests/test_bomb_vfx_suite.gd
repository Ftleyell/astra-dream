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

	# 4. Verify Echo dch default portrait is Flipped
	var echo_dch = load("res://narrative/characters/echo.dch")
	assert(echo_dch != null, "echo.dch must be valid")
	assert(echo_dch.default_portrait == "Flipped", "Echo default portrait must be Flipped")
	print("  ✓ Echo default_portrait is configured to 'Flipped'")

	# 5. Verify Timeline files join Echo flipped
	var timelines := [
		"res://narrative/timelines/prologue_briefing.dtl",
		"res://narrative/timelines/wave_interlude_cockpit.dtl",
		"res://narrative/timelines/boss_titan_alert.dtl"
	]
	for t_path in timelines:
		var file := FileAccess.open(t_path, FileAccess.READ)
		assert(file != null, "Could not open timeline %s" % t_path)
		var content := file.get_as_text()
		assert("join echo (Flipped)" in content, "Timeline %s must join echo (Flipped)" % t_path)
		print("  ✓ Timeline %s has 'join echo (Flipped)'" % t_path.get_file())

	print("\n==========================================")
	print("[PASS] ALL BOMB VFX & DIALOGUE ORIENTATION CHECKS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)
