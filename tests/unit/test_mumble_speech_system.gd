extends BaseTestSuite

const VoiceProfileDataScript = preload("res://data/voices/voice_profile_data.gd")
const VoiceProfileRegistryScript = preload("res://data/voices/voice_profile_registry.gd")
const MumbleSpeechControllerScript = preload("res://core/audio/mumble_speech_controller.gd")
const DialogicMumbleBridgeScript = preload("res://core/audio/dialogic_mumble_bridge.gd")

const EXPECTED_CAST_IDS: Array[StringName] = [
	&"default",
	&"valentina", &"nova", &"kira", &"selene", &"roxy", &"echo", &"nyx",
	&"mochi", &"kuro", &"luna", &"pip", &"cosmo",
	&"lyra", &"caelia", &"iris", &"vespera", &"zephyr",
	&"sombra_nyx",
]


class MockCharacterRes extends Resource:
	var display_name: String = ""


class MockTypeSounds extends Node:
	var enabled: bool = true
	var sounds: Array = ["dummy.wav"]


func _ready() -> void:
	super._ready()
	await _run_tests()


func _run_tests() -> void:
	# 1. Verificar VoiceProfileRegistry con todos los perfiles del elenco + fallback
	VoiceProfileRegistryScript.reload_all()
	var ids: Array[StringName] = VoiceProfileRegistryScript.get_all_profile_ids()
	assert_true(ids.size() >= EXPECTED_CAST_IDS.size(), "Se esperaban al menos %d perfiles .tres, encontrados: %d" % [EXPECTED_CAST_IDS.size(), ids.size()])

	for expected_id: StringName in EXPECTED_CAST_IDS:
		var prof: VoiceProfileDataScript = VoiceProfileRegistryScript.get_profile(expected_id)
		assert_true(prof != null, "Perfil nulo para %s" % String(expected_id))
		assert_true(prof.profile_id == expected_id, "profile_id incorrecto para %s (recibido: %s)" % [String(expected_id), String(prof.profile_id)])

	var fallback_prof: VoiceProfileDataScript = VoiceProfileRegistryScript.get_profile(&"inexistente_xyz")
	assert_true(fallback_prof != null and fallback_prof.profile_id == &"default", "Un ID inexistente debe resolver al fallback default.")

	# 2. Verificar MumbleSpeechController (banco procedural, filtros, cadencia, entonación, enabled=false)
	var ctrl: MumbleSpeechControllerScript = MumbleSpeechControllerScript.new()
	add_child(ctrl)

	var test_prof: VoiceProfileDataScript = VoiceProfileRegistryScript.get_profile(&"valentina").duplicate() as VoiceProfileDataScript
	test_prof.pitch_variance = 0.0
	test_prof.volume_jitter_db = 0.0
	test_prof.chars_per_blip = 2
	test_prof.min_interval_ms = 50
	ctrl.set_profile(test_prof)

	assert_true(ctrl.get_procedural_bank_size() == 5, "El banco procedural debe sintetizar 5 sílabas vocálicas.")

	ctrl.begin_utterance("Hola!")
	assert_true(not ctrl.on_character_revealed(" ", 0, 100), "Debe ignorar espacios.")
	assert_true(not ctrl.on_character_revealed("!", 1, 200), "Debe ignorar signos.")
	assert_true(ctrl.on_character_revealed("H", 0, 1000), "1er carácter hablado debe disparar blip.")
	assert_true(not ctrl.on_character_revealed("o", 1, 1060), "2do carácter debe saltarse por cadencia=2.")
	assert_true(not ctrl.on_character_revealed("l", 2, 1020), "Debe bloquearse por min_interval_ms=50.")
	assert_true(ctrl.get_last_volume_used() > test_prof.volume_db + 1.0, "Exclamación (!) debe aumentar el volumen.")

	ctrl.enabled = false
	assert_true(not ctrl.on_character_revealed("a", 3, 2000), "enabled=false no debe emitir blips.")
	ctrl.enabled = true

	# 3. Verificar DialogicMumbleBridge sobre layout mock
	var layout: Control = Control.new()
	layout.name = "MockDialogicLayout"
	add_child(layout)

	var mock_ts: MockTypeSounds = MockTypeSounds.new()
	mock_ts.name = "DialogicNode_TypeSounds"
	layout.add_child(mock_ts)

	var mock_dt: RichTextLabel = RichTextLabel.new()
	mock_dt.name = "DialogicNode_DialogText"
	mock_dt.text = "Motores estables en orbita!"
	mock_dt.visible_characters = 0
	layout.add_child(mock_dt)

	var bridge: DialogicMumbleBridgeScript = DialogicMumbleBridgeScript.new()
	add_child(bridge)
	bridge.attach_to_layout(layout, null, false)

	assert_true(not mock_ts.enabled and mock_ts.sounds.is_empty(), "Bridge debe desactivar DialogicNode_TypeSounds legado.")

	var mock_char: MockCharacterRes = MockCharacterRes.new()
	mock_char.display_name = "Mochi"
	bridge.call("_on_about_to_show_text", {
		"character": mock_char,
		"text": "Motores estables en orbita!"
	})
	assert_true(bridge.get_current_speaker_id() == &"mochi", "Debe resolver el speaker_id a 'mochi'.")
	assert_true(bridge.get_current_profile().profile_id == &"mochi", "Debe cargar el perfil de mochi.")

	var blip_count: Array[int] = [0]
	bridge.blip_played.connect(func(_p: float, _v: float, _r: bool) -> void:
		blip_count[0] += 1
	)

	mock_dt.visible_characters = 1
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(blip_count[0] == 1, "Incrementar visible_characters=1 debe disparar el primer blip.")

	# Verificar protección contra skip instantáneo (> 12 chars de golpe)
	var before_skip: int = blip_count[0]
	mock_dt.visible_characters = 25
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(blip_count[0] == before_skip, "Skip instantáneo de línea no debe disparar blips acumulados.")

	pass_suite("test_mumble_speech_system")
