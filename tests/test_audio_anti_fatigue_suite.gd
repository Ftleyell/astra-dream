extends Node

func _ready() -> void:
	print("\n==========================================")
	print("[TEST] Running Audio Anti-Fatigue Suite...")
	print("==========================================")

	var am = get_node_or_null("/root/AudioManager")
	assert(am != null, "AudioManager autoload must be present")

	# Test 1: Laser pitch modulation
	print("\n[1/4] Testing Laser Pitch Random Modulation...")
	var recorded_laser_pitches: Array[float] = []
	for i in range(5):
		am._last_played_msec.clear() # Limpiar cooldown para el test
		var p: AudioStreamPlayer = am.play_sfx("laser", 1.0, 0.0)
		if p:
			recorded_laser_pitches.append(snappedf(p.pitch_scale, 0.01))
	print("  - Laser pitches: ", recorded_laser_pitches)
	assert(recorded_laser_pitches.size() >= 3, "Multiple lasers should have fired with varied pitch")
	# Check that not all pitches are identical
	var first_p := recorded_laser_pitches[0]
	var has_diff := false
	for p in recorded_laser_pitches:
		if absf(p - first_p) > 0.001:
			has_diff = true
			break
	assert(has_diff, "Laser pitches must be randomized to prevent machine-gun fatigue")
	print("  -> Laser Modulation: PASSED")

	# Test 2: EXP Combo musical arpeggiation
	print("\n[2/4] Testing EXP Combo Musical Arpeggiation...")
	var recorded_exp_pitches: Array[float] = []
	am._exp_combo_count = 0
	am._last_exp_msec = Time.get_ticks_msec()
	for i in range(4):
		am._last_played_msec.clear()
		var p: AudioStreamPlayer = am.play_sfx("exp")
		if p:
			recorded_exp_pitches.append(snappedf(p.pitch_scale, 0.01))
	print("  - EXP ascending pitches: ", recorded_exp_pitches)
	assert(recorded_exp_pitches.size() >= 3, "EXP pickups should play consecutively")
	# Pitch should be ascending along the musical steps
	for i in range(1, recorded_exp_pitches.size()):
		assert(recorded_exp_pitches[i] >= recorded_exp_pitches[i - 1] * 0.95, "EXP pitch should scale musically upwards")
	print("  -> EXP Combo Arpeggio: PASSED")

	# Test 3: Anti-spam micro-interval throttling
	print("\n[3/4] Testing Anti-Spam Micro-Throttling (Clicks & Phase Cancellation)...")
	am._last_played_msec.clear()
	am.play_sfx("explosion")
	# Immediate trigger in the same millisecond
	am.play_sfx("explosion")
	# Should not have stacked twice in 0ms
	var active_explosions := 0
	for player in am._sfx_pool:
		if player.playing and am._active_sfx_map.get(player) == "explosion":
			active_explosions += 1
	print("  - Explosions triggered simultaneously: ", active_explosions)
	assert(active_explosions == 1, "Immediate microsecond spam must be throttled to prevent ear blowout")
	print("  -> Anti-Spam Throttling: PASSED")

	# Test 4: Polyphony Capping
	print("\n[4/4] Testing Polyphony Capping...")
	for i in range(15):
		am._last_played_msec.clear() # Simular tiempo transcurrido
		am.play_sfx("explosion")
	var capped_explosions := 0
	for player in am._sfx_pool:
		if player.playing and am._active_sfx_map.get(player) == "explosion":
			capped_explosions += 1
	print("  - Capped active explosion voices: %d (max: 4)" % capped_explosions)
	assert(capped_explosions <= 4, "Explosion voices must never exceed max polyphony limit")
	print("  -> Polyphony Capping: PASSED")

	print("\n==========================================")
	print(">>> ALL AUDIO ANTI-FATIGUE TESTS PASSED <<<")
	print("==========================================\n")
	get_tree().quit(0)
