class_name TestPauseAudioUnit
extends BaseTestSuite

## TestPauseAudioUnit
## Micro-test síncrono ultra-rápido (< 0.05s) para conversiones numéricas de audio
## y límites de volumen en buses.

const AudioSettingsScript = preload("res://scenes/ui/pause_menu/components/pause_audio_settings.gd")

func _ready() -> void:
	super._ready()
	_run_unit_tests()

func _run_unit_tests() -> void:
	# 1. Test silencio absoluto <= 0.01
	var db_zero: float = AudioSettingsScript.slider_to_db(0.0)
	assert_true(db_zero <= -80.0, "Volumen 0.0 debe ser -80dB o inferior")

	var db_low: float = AudioSettingsScript.slider_to_db(0.005)
	assert_true(db_low <= -80.0, "Volumen 0.005 debe ser -80dB")

	# 2. Test escala lineal normal
	var db_full: float = AudioSettingsScript.slider_to_db(1.0)
	assert_true(is_equal_approx(db_full, 0.0), "Volumen 1.0 debe ser exactamente 0.0 dB (obtenido %f)" % db_full)

	var slider_full: float = AudioSettingsScript.db_to_slider(0.0)
	assert_true(is_equal_approx(slider_full, 1.0), "0 dB debe retornar slider 1.0 (obtenido %f)" % slider_full)

	var slider_silence: float = AudioSettingsScript.db_to_slider(-80.0)
	assert_true(slider_silence == 0.0, "-80 dB debe retornar slider 0.0 (obtenido %f)" % slider_silence)

	pass_suite("TestPauseAudioUnit completado exitosamente.")
