extends BaseTestSuite

const VoiceProfileDataScript = preload("res://data/voices/voice_profile_data.gd")
const MumbleSpeechControllerScript = preload("res://core/audio/mumble_speech_controller.gd")
const LAB_SCENE_PATH: String = "res://sandbox/mumble_speech_lab/mumble_speech_lab.tscn"
const PROFILE_PATHS: Array[String] = [
	"res://data/voices/profiles/valentina.tres",
	"res://data/voices/profiles/mochi.tres",
	"res://data/voices/profiles/lyra.tres",
	"res://data/voices/profiles/nova.tres",
]


func _ready() -> void:
	super._ready()
	_run_tests()


func _run_tests() -> void:
	# 1. Cargar todos los perfiles .tres
	var loaded_profiles: Array[VoiceProfileDataScript] = []
	for path: String in PROFILE_PATHS:
		var res: Resource = load(path)
		assert_true(res is VoiceProfileDataScript, "No se pudo cargar VoiceProfileData: %s" % path)
		loaded_profiles.append(res as VoiceProfileDataScript)

	# 2. Verificar MumbleSpeechController: banco procedural, filtrado, cadencia e intervalo mínimo
	var ctrl: MumbleSpeechControllerScript = MumbleSpeechControllerScript.new()
	add_child(ctrl)

	var profile: VoiceProfileDataScript = loaded_profiles[0].duplicate() as VoiceProfileDataScript
	profile.pitch_variance = 0.0
	profile.volume_jitter_db = 0.0
	profile.chars_per_blip = 2
	profile.min_interval_ms = 50
	ctrl.set_profile(profile)

	assert_true(ctrl.get_procedural_bank_size() == 5, "El banco procedural debe sintetizar 5 sílabas vocálicas.")

	# Ignorar espacios y puntuación
	ctrl.begin_utterance("Hola mundo.")
	assert_true(not ctrl.on_character_revealed(" ", 0, 100), "Debe ignorar espacios.")
	assert_true(not ctrl.on_character_revealed(".", 1, 200), "Debe ignorar puntuación.")
	assert_true(not ctrl.on_character_revealed("?", 2, 300), "Debe ignorar signos de interrogación.")

	# Cadencia chars_per_blip = 2 y anti-fatiga min_interval_ms = 50
	assert_true(ctrl.on_character_revealed("H", 0, 1000), "1er carácter hablado debe disparar blip.")
	assert_true(not ctrl.on_character_revealed("o", 1, 1060), "2do carácter hablado debe saltarse por cadencia=2.")
	assert_true(not ctrl.on_character_revealed("l", 2, 1020), "Debe bloquearse por min_interval_ms.")
	assert_true(ctrl.on_character_revealed("a", 3, 1060) == false, "4to carácter se salta por cadencia=2.")
	assert_true(ctrl.on_character_revealed("m", 4, 1120), "5to carácter con intervalo >= 50ms debe disparar blip.")

	# 3. Entonación de pregunta (?) y exclamación (!)
	ctrl.begin_utterance("Hola piloto?")
	var base_triggered: bool = ctrl.on_character_revealed("H", 0, 2000)
	assert_true(base_triggered, "Debe disparar blip inicial en pregunta.")
	var pitch_start: float = ctrl.get_last_pitch_used()
	ctrl.on_character_revealed("o", 1, 2100)
	var end_triggered: bool = ctrl.on_character_revealed("o", 10, 2200)
	assert_true(end_triggered, "Debe disparar blip final en pregunta.")
	var pitch_end: float = ctrl.get_last_pitch_used()
	assert_true(pitch_end > pitch_start + 0.05, "El pitch debe subir al final de una pregunta (?).")

	ctrl.begin_utterance("Alerta!")
	assert_true(ctrl.on_character_revealed("A", 0, 3000), "Debe disparar blip en exclamación.")
	assert_true(ctrl.get_last_volume_used() > profile.volume_db + 1.0, "La exclamación (!) debe aumentar volumen.")

	# 4. Instanciar la escena interactiva del lab sin errores
	var lab_scene: PackedScene = load(LAB_SCENE_PATH) as PackedScene
	assert_true(lab_scene != null, "No se pudo cargar la escena del lab.")
	var lab_inst: Control = lab_scene.instantiate() as Control
	assert_true(lab_inst != null, "No se pudo instanciar MumbleSpeechLab.")
	add_child(lab_inst)
	lab_inst.start_playback()
	lab_inst.stop_playback()

	pass_suite("test_mumble_speech_lab")
