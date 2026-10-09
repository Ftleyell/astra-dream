class_name PauseAudioSettings
extends RefCounted

## PauseAudioSettings — Astra Dream
## Controlador desacoplado de ajustes de audio para PauseMenu / SettingsModal.
## Gestiona el mapeo de buses (Master, BGM, SFX), conversión volumen <=> dB y persistencia.

static func slider_to_db(linear_value: float) -> float:
	if linear_value <= 0.01:
		return -80.0
	return linear_to_db(linear_value)

static func db_to_slider(db_value: float) -> float:
	if db_value <= -79.0:
		return 0.0
	return db_to_linear(db_value)

static func apply_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		if linear_value <= 0.01:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, slider_to_db(linear_value))

static func save_audio(master_vol: float, bgm_vol: float, sfx_vol: float) -> void:
	apply_bus_volume("Master", master_vol)
	apply_bus_volume("Music", bgm_vol)
	apply_bus_volume("SFX", sfx_vol)
	var mgr = Engine.get_main_loop().root.get_node_or_null("/root/SettingsManager") if Engine.get_main_loop() else null
	if mgr and mgr.has_method("save_audio_settings"):
		mgr.save_audio_settings(master_vol, bgm_vol, sfx_vol)
