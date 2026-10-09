class_name PauseVideoSettings
extends RefCounted

## PauseVideoSettings — Astra Dream
## Controlador desacoplado de configuración gráfica y de pantalla.
## Gestiona resoluciones estándar, pantalla completa y visibilidad de core hitbox.

static var RESOLUTIONS: Array[Dictionary] = [
	{ "name": "1920 × 1080 (16:9 Full HD)", "size": Vector2i(1920, 1080) },
	{ "name": "2560 × 1440 (16:9 QHD / 2K)", "size": Vector2i(2560, 1440) },
	{ "name": "3840 × 2160 (16:9 4K UHD)", "size": Vector2i(3840, 2160) },
	{ "name": "1280 × 720 (16:9 HD)", "size": Vector2i(1280, 720) },
	{ "name": "2560 × 1080 (21:9 Ultrawide)", "size": Vector2i(2560, 1080) },
	{ "name": "3440 × 1440 (21:9 UWQHD)", "size": Vector2i(3440, 1440) },
	{ "name": "1920 × 1200 (16:10 WUXGA)", "size": Vector2i(1920, 1200) },
	{ "name": "1280 × 800 (16:10 Steam Deck)", "size": Vector2i(1280, 800) },
	{ "name": "1366 × 768 (16:9 Laptop)", "size": Vector2i(1366, 768) }
]

static func apply_display_settings(new_size: Vector2i, is_fullscreen: bool) -> void:
	var mgr = Engine.get_main_loop().root.get_node_or_null("/root/SettingsManager") if Engine.get_main_loop() else null
	if mgr and mgr.has_method("save_display_settings"):
		mgr.save_display_settings(new_size, is_fullscreen)
	else:
		if is_fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(new_size)

static func is_fullscreen_active() -> bool:
	var mgr = Engine.get_main_loop().root.get_node_or_null("/root/SettingsManager") if Engine.get_main_loop() else null
	if mgr:
		return bool(mgr.fullscreen)
	var mode := DisplayServer.window_get_mode()
	return (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

static func get_current_resolution() -> Vector2i:
	var mgr = Engine.get_main_loop().root.get_node_or_null("/root/SettingsManager") if Engine.get_main_loop() else null
	if mgr and "resolution_size" in mgr:
		return mgr.resolution_size
	return DisplayServer.window_get_size()
