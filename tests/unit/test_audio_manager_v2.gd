extends BaseTestSuite
## Suite unitaria integral para AudioManager v2, buses, SettingsManager.ambience_volume,
## variantes sin repetición, layering, prioridades, densidad, panning, Ambience y MixDirector.

const SfxCueDataScript = preload("res://core/audio/sfx_cue_data.gd")
const SfxCueBankScript = preload("res://core/audio/sfx_cue_bank.gd")
const SfxDensityTrackerScript = preload("res://core/audio/sfx_density_tracker.gd")


func _ready() -> void:
	timeout_seconds = 20.0
	super._ready()
	await _run_tests()


func _await_frames(count: int = 2) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _run_tests() -> void:
	_test_buses_and_settings_ambience()
	await _test_cue_bank_variants_and_layering()
	_test_density_tracker()
	_test_priority_voice_stealing()
	await _test_mix_director_and_ambience()
	_test_weapon_families_assigned()
	pass_suite("AudioManager v2, buses, Ambience, MixDirector y familias WeaponData verificados")


func _test_buses_and_settings_ambience() -> void:
	for bus_name: String in ["Master", "Music", "SFX", "Ambience", "SFX_Combat", "SFX_Heroic", "SFX_UI"]:
		assert_true(AudioServer.get_bus_index(bus_name) >= 0, "Debe existir bus '%s'" % bus_name)

	var prev_amb: float = SettingsManager.ambience_volume
	SettingsManager.save_audio_settings(
		SettingsManager.master_volume,
		SettingsManager.music_volume,
		SettingsManager.sfx_volume,
		0.45
	)
	assert_true(is_equal_approx(SettingsManager.ambience_volume, 0.45), "SettingsManager debe guardar ambience_volume")
	var amb_idx: int = AudioServer.get_bus_index("Ambience")
	assert_true(AudioServer.get_bus_volume_db(amb_idx) < -2.0, "Bus Ambience debe reflejar el volumen reducido")
	SettingsManager.save_audio_settings(
		SettingsManager.master_volume,
		SettingsManager.music_volume,
		SettingsManager.sfx_volume,
		prev_amb
	)


func _test_cue_bank_variants_and_layering() -> void:
	# Generar default_sfx_cue_bank.tres si aún no existe en disco
	var save_err: Error = SfxCueBankScript.rebuild_and_save_default_bank()
	assert_true(save_err == OK, "rebuild_and_save_default_bank debe guardar data/audio/default_sfx_cue_bank.tres")
	AudioManager.reload_cue_bank()

	var bank: SfxCueBankScript = SfxCueBankScript.create_default_bank()
	var lookup: Dictionary = bank.build_lookup()
	assert_true(lookup.size() >= 30, "SfxCueBank debe registrar >= 30 cues (actual: %d)" % lookup.size())
	assert_true(bank.resolve_key("exp_pickup") == "exp", "Alias exp_pickup debe resolver a exp")
	assert_true(bank.resolve_key("bomb_explode") == "bomb", "Alias bomb_explode debe resolver a bomb")

	# Probar rotación de variantes sin repetición consecutiva
	var cue: SfxCueDataScript = SfxCueDataScript.new()
	cue.cue_id = &"test_multi"
	cue.bus_name = &"SFX_Combat"
	cue.min_interval_ms = 0
	cue.max_polyphony = 8
	var s1: AudioStreamWAV = _make_dummy_wav(440.0)
	var s2: AudioStreamWAV = _make_dummy_wav(660.0)
	var l2: AudioStreamWAV = _make_dummy_wav(220.0)
	cue.streams = [s1, s2]
	cue.secondary_layer_streams = [l2]
	cue.secondary_layer_delay_sec = 0.0
	cue.duck_combat_db = 4.0
	cue.allow_panning = true
	AudioManager._cues_by_id["test_multi"] = cue

	AudioManager._last_played_msec.erase("test_multi")
	var p1: AudioStreamPlayer = AudioManager.play_sfx("test_multi")
	AudioManager._last_played_msec.erase("test_multi")
	var p2: AudioStreamPlayer = AudioManager.play_sfx("test_multi")
	assert_true(p1 != null and p2 != null, "Debe reproducir dos variantes consecutivas")
	assert_true(p1.stream != p2.stream, "Con 2 variantes no debe repetir la misma consecutivamente")

	# Probar panning estéreo con play_sfx_at
	AudioManager._last_played_msec.erase("test_multi")
	var pan_node: Node = AudioManager.play_sfx_at("test_multi", Vector2(320.0, -120.0))
	assert_true(pan_node is AudioStreamPlayer2D, "play_sfx_at debe usar pool AudioStreamPlayer2D cuando allow_panning=true")
	assert_true((pan_node as AudioStreamPlayer2D).global_position == Vector2(320.0, -120.0), "AudioStreamPlayer2D debe ubicarse en world_pos")
	await _await_frames(1)
	AudioManager._cues_by_id.erase("test_multi")


func _test_density_tracker() -> void:
	var dt: SfxDensityTrackerScript = SfxDensityTrackerScript.new()
	var a1: float = dt.record_and_get_attenuation_db("laser", 1000, 4.0)
	var a2: float = dt.record_and_get_attenuation_db("laser", 1050, 4.0)
	assert_true(is_equal_approx(a1, 0.0) and is_equal_approx(a2, 0.0), "Los primeros 2 disparos en ventana no atenúan")
	var a_dense: float = 0.0
	for i: int in range(8):
		a_dense = dt.record_and_get_attenuation_db("laser", 1100 + i * 20, 4.0)
	assert_true(a_dense <= -3.5, "En ráfaga densa debe atenuar progresivamente (actual: %.2f)" % a_dense)


func _test_priority_voice_stealing() -> void:
	# Simular todas las 24 voces ocupadas con prioridad CRITICAL
	var dummy: AudioStreamWAV = _make_dummy_wav(330.0)
	for p: AudioStreamPlayer in AudioManager._sfx_pool:
		p.stream = dummy
		p.play()
		AudioManager._voice_priorities[p] = SfxCueDataScript.Priority.CRITICAL

	var stolen_by_crowd: AudioStreamPlayer = AudioManager._get_available_player(SfxCueDataScript.Priority.CROWD)
	assert_true(stolen_by_crowd == null, "Un sonido CROWD no debe robar una voz CRITICAL")

	for p: AudioStreamPlayer in AudioManager._sfx_pool:
		p.stop()
		AudioManager._release_player_voice(p)


func _test_mix_director_and_ambience() -> void:
	assert_true(AudioManager.mix_director != null, "AudioManager debe tener AudioMixDirector")
	assert_true(AudioManager.ambience_controller != null, "AudioManager debe tener AmbienceCrossfadeController")

	AudioManager.set_pause_muffle(true)
	AudioManager.set_tactical_focus(1.0)
	for _i: int in range(10):
		AudioManager.mix_director._process(0.05)
	assert_true(AudioManager.mix_director.get_current_music_cutoff_hz() < 10000.0, "Pausa debe reducir LowPass de Music")
	assert_true(AudioManager.mix_director.get_current_combat_cutoff_hz() < 12000.0, "Tactical focus debe reducir LowPass de SFX_Combat")

	AudioManager.set_pause_muffle(false)
	AudioManager.set_tactical_focus(0.0)
	for _i: int in range(15):
		AudioManager.mix_director._process(0.08)

	AudioManager.set_ambience("hub", 0.2)
	assert_true(AudioManager.ambience_controller.current_track_id == "hub", "Ambience debe registrar estado 'hub'")
	AudioManager.set_ambience("off", 0.1)
	await _await_frames(1)


func _test_weapon_families_assigned() -> void:
	var rail: WeaponData = load("res://data/weapons/roster/rail_launcher.tres") as WeaponData
	var blade: WeaponData = load("res://data/weapons/roster/crescent_blade.tres") as WeaponData
	var tesla: WeaponData = load("res://data/weapons/roster/tesla_arc.tres") as WeaponData
	var void_w: WeaponData = load("res://data/weapons/roster/singularity_cannon.tres") as WeaponData
	assert_true(rail != null and rail.fire_sfx_id == &"weapon_railgun", "rail_launcher debe usar weapon_railgun")
	assert_true(blade != null and blade.fire_sfx_id == &"weapon_blade", "crescent_blade debe usar weapon_blade")
	assert_true(tesla != null and tesla.fire_sfx_id == &"weapon_tesla", "tesla_arc debe usar weapon_tesla")
	assert_true(void_w != null and void_w.fire_sfx_id == &"weapon_void", "singularity_cannon debe usar weapon_void")


func _make_dummy_wav(freq_hz: float) -> AudioStreamWAV:
	var sr: int = 22050
	var count: int = 2205
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for i: int in range(count):
		var s: float = sin(TAU * freq_hz * (float(i) / float(sr))) * 0.35
		pcm.encode_s16(i * 2, int(roundf(s * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.stereo = false
	wav.data = pcm
	return wav
