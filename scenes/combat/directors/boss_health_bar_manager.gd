class_name BossHealthBarManager
extends RefCounted

## BossHealthBarManager.gd
## Gestor especializado para la vinculación y actualización de la interfaz de jefes y rivales en el HUD:
## - Conexión fuertemente tipada de señales (health_changed, phase_changed, boss_defeated).
## - Visualización y seguimiento dinámico en el HUD (show_boss, track_boss, hide_boss).
## - Gestión de avisos y carteles de desbloqueo/victoria (character_unlock_banner, rival_defeated_banner).

var main_game: Node2D = null

func setup(game: Node2D) -> void:
	main_game = game

func _get_hud() -> Object:
	return main_game.get("hud") if is_instance_valid(main_game) else null

func bind_boss(boss_node: Node2D, on_defeated: Callable = Callable()) -> void:
	if not is_instance_valid(boss_node):
		return
	var hud: Object = _get_hud()
	if boss_node.has_signal("health_changed") and hud:
		boss_node.connect("health_changed", Callable(hud, "update_boss_health"))
	if boss_node.has_signal("phase_changed") and hud:
		boss_node.connect("phase_changed", Callable(hud, "set_boss_phase"))
	if boss_node.has_signal("boss_defeated"):
		var defeat_cb: Callable = on_defeated if on_defeated.is_valid() else Callable(main_game, "_on_boss_defeated")
		boss_node.connect("boss_defeated", defeat_cb)

func show_boss_bar(boss_node: Node2D, boss_name: String, max_hp: float, track_type: String = "JEFE") -> void:
	var hud: Object = _get_hud()
	if hud:
		if hud.has_method("show_boss"):
			hud.call("show_boss", boss_name, max_hp)
		if hud.has_method("track_boss") and is_instance_valid(boss_node):
			hud.call("track_boss", boss_node, track_type)

func bind_rival(rival_node: Node2D, on_spared: Callable, on_engaged: Callable, on_defeated: Callable) -> void:
	if not is_instance_valid(rival_node):
		return
	if rival_node.has_signal("rival_spared"):
		rival_node.connect("rival_spared", on_spared)
	if rival_node.has_signal("rival_engaged"):
		rival_node.connect("rival_engaged", on_engaged)
	if rival_node.has_signal("rival_defeated"):
		rival_node.connect("rival_defeated", on_defeated)
	var hud: Object = _get_hud()
	if hud and hud.has_method("track_boss"):
		hud.call("track_boss", rival_node, "RIVAL")

func show_rival_duel(rival_node: Node2D, duel_title: String, max_hp: float) -> void:
	var hud: Object = _get_hud()
	if hud:
		if hud.has_method("show_boss"):
			hud.call("show_boss", duel_title, max_hp)
		if is_instance_valid(rival_node) and rival_node.has_signal("health_changed"):
			if not rival_node.is_connected("health_changed", Callable(hud, "update_boss_health")):
				rival_node.connect("health_changed", Callable(hud, "update_boss_health"))

func hide_boss_bar() -> void:
	var hud: Object = _get_hud()
	if hud and hud.has_method("hide_boss"):
		hud.call("hide_boss")

func show_character_unlock_banner(character_id: StringName, title: String, subtitle: String) -> void:
	var hud: Object = _get_hud()
	if hud and hud.has_method("show_character_unlock_banner"):
		hud.call("show_character_unlock_banner", character_id, title, subtitle)

func show_rival_defeated_banner(pilot_id: StringName, pilot_name: String) -> void:
	var hud: Object = _get_hud()
	if hud and hud.has_method("show_rival_defeated_banner"):
		hud.call("show_rival_defeated_banner", pilot_id, pilot_name)
	elif hud and hud.has_method("show_character_unlock_banner"):
		hud.call("show_character_unlock_banner", pilot_id, "RIVAL ELIMINADA: " + pilot_name.to_upper(), "Has neutralizado a " + pilot_name + ". Amenaza táctica disipada.")
