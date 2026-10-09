class_name BossCinematicSequence
extends RefCounted

## BossCinematicSequence.gd
## Orquestador especializado de secuencias cinemáticas para encuentros de jefes y rivales:
## - Encuadre y congelamiento de cámara 1v1.
## - Apertura y colapso de fracturas de realidad cósmica (CosmicRealityTear).
## - Diálogos pre-batalla, alertas de mascotas y secuencias de emergencia.
## - Coordinación de saltos hiperespaciales de rivales con temporizador de salvaguarda (watchdog).
## - Despliegue de escoltas y escuadrones aliados en rutas Pacifista y Slayer de Astra Prime.

const CosmicRealityTearScript := preload("res://scenes/combat/bosses/cosmic_reality_tear.gd")
const BossEmergenceHelperScript := preload("res://scenes/combat/bosses/boss_emergence_helper.gd")
const BossCinematicPresenterScript := preload("res://scenes/combat/bosses/boss_cinematic_presenter.gd")
const BossHealthBarManagerScript := preload("res://scenes/combat/directors/boss_health_bar_manager.gd")

var nyx_boss_escort_scene: PackedScene = preload("res://scenes/combat/bosses/nyx_boss_escort.tscn")

var main_game: Node2D = null
var health_bar_manager: BossHealthBarManagerScript = null

func setup(game: Node2D, p_health_bar_mgr: BossHealthBarManagerScript = null) -> void:
	main_game = game
	health_bar_manager = p_health_bar_mgr

func setup_cinematic_duel(cin_zoom: float = 1.0) -> Dictionary:
	if not main_game or not is_instance_valid(main_game):
		return {}
	return BossCinematicPresenterScript.setup_cinematic_duel(main_game, cin_zoom)

func play_wave_boss_sequence(
	boss_node: Node2D,
	boss_target_pos: Vector2,
	boss_id: String,
	boss_name: String,
	boss_hp: float,
	cam: GameCamera2D = null,
	player: Node2D = null,
	on_completed: Callable = Callable()
) -> void:
	if not main_game or not is_instance_valid(main_game) or not is_instance_valid(boss_node):
		return

	if not cam and main_game.get_tree():
		cam = main_game.get_tree().get_first_node_in_group("camera") as GameCamera2D
	if not player:
		player = main_game.get("player") as Node2D
	var domain_col: Color = CosmicRealityTearScript.get_boss_domain_color(boss_id)

	BossCinematicPresenterScript.play_reality_tear_emergence(
		main_game,
		boss_node,
		boss_target_pos,
		domain_col,
		250.0,
		750.0,
		func(next_step: Callable) -> void:
			if is_instance_valid(main_game) and main_game.has_method("_trigger_pet_boss_alert"):
				main_game.call("_trigger_pet_boss_alert", boss_name, next_step)
			elif next_step.is_valid():
				next_step.call(),
		func() -> void:
			if health_bar_manager:
				health_bar_manager.show_boss_bar(boss_node, boss_name, boss_hp, "JEFE")
			elif main_game:
				var hud = main_game.get("hud")
				if hud:
					hud.show_boss(boss_name, boss_hp)
					if hud.has_method("track_boss"):
						hud.track_boss(boss_node, "JEFE")
			BossCinematicPresenterScript.restore_combat_after_emergence(main_game, cam, player)
			if on_completed.is_valid():
				on_completed.call()
	)

func play_final_boss_sequence(
	prime_node: Node2D,
	boss_target_pos: Vector2,
	route: String,
	wingmen_spawner: Callable = Callable(),
	cam: GameCamera2D = null,
	player: Node2D = null,
	on_completed: Callable = Callable()
) -> void:
	if not main_game or not is_instance_valid(main_game) or not is_instance_valid(prime_node):
		return

	if not cam and main_game.get_tree():
		cam = main_game.get_tree().get_first_node_in_group("camera") as GameCamera2D
	if not player:
		player = main_game.get("player") as Node2D

	var domain_col: Color = Color(1.0, 0.15, 0.25, 1.0) if route == "slayer" else CosmicRealityTearScript.get_boss_domain_color("boss_astra_prime")
	BossCinematicPresenterScript.play_reality_tear_emergence(
		main_game,
		prime_node,
		boss_target_pos,
		domain_col,
		280.0,
		850.0,
		func(next_step: Callable) -> void:
			if is_instance_valid(main_game) and main_game.has_method("_trigger_climax_dialogue"):
				main_game.call("_trigger_climax_dialogue", route, next_step)
			elif next_step.is_valid():
				next_step.call(),
		func() -> void:
			var b_name: String = prime_node.boss_name if "boss_name" in prime_node else "ASTRA PRIME"
			var b_hp: float = float(prime_node.get("max_health")) if "max_health" in prime_node else 10000.0
			if health_bar_manager:
				health_bar_manager.show_boss_bar(prime_node, b_name, b_hp, "JEFE FINAL")
			elif main_game:
				var hud = main_game.get("hud")
				if hud:
					hud.show_boss(b_name, b_hp)
					if hud.has_method("track_boss"):
						hud.track_boss(prime_node, "JEFE FINAL")

			BossCinematicPresenterScript.restore_combat_after_emergence(main_game, cam, player)

			if route == "pacifist":
				if wingmen_spawner.is_valid():
					wingmen_spawner.call()
			elif route == "slayer":
				if is_instance_valid(player):
					var p_stats = player.get("stats")
					if p_stats:
						p_stats.add_modifier(&"base_damage", CharacterStats.StatModifier.new(&"slayer_overload", 0.35, true, main_game))
				if nyx_boss_escort_scene:
					var escort = nyx_boss_escort_scene.instantiate()
					var escort_pid: StringName = main_game.call("_get_genocide_escort_pilot_id") if main_game.has_method("_get_genocide_escort_pilot_id") else &"nyx"
					escort.global_position = boss_target_pos + Vector2(0.0, 110.0)
					escort.setup(escort_pid, prime_node)
					main_game.add_child(escort)
					main_game.set("current_genocide_escort", escort)

			if on_completed.is_valid():
				on_completed.call()
	)

func play_rival_warp_sequence(
	rival_node: Node2D,
	on_completed: Callable = Callable()
) -> void:
	if not main_game or not is_instance_valid(main_game) or not is_instance_valid(rival_node):
		return

	main_game.set("is_rival_cinematic_active", true)

	var tree: SceneTree = main_game.get_tree()
	if not tree:
		return

	tree.create_timer(0.45, true, false, true).timeout.connect(func() -> void:
		if not is_instance_valid(rival_node) or not is_instance_valid(main_game) or main_game.get("is_rival_cinematic_active") != true:
			return
		if rival_node.has_method("open_warp_portal"):
			rival_node.open_warp_portal(func() -> void:
				if not is_instance_valid(rival_node) or not is_instance_valid(main_game):
					return
				main_game.call("_trigger_pet_rival_jump_warning", rival_node, func() -> void:
					if not is_instance_valid(rival_node) or not is_instance_valid(main_game):
						return
					var pl: Node2D = main_game.get("player") as Node2D
					if is_instance_valid(pl) and "is_movement_suppressed" in pl:
						pl.set("is_movement_suppressed", true)
						pl.set("velocity", Vector2.ZERO)
					# Salir del portal directamente
					rival_node.emerge_from_portal(func() -> void:
						if not is_instance_valid(rival_node) or not is_instance_valid(main_game):
							return
						rival_node.process_mode = Node.PROCESS_MODE_PAUSABLE
						main_game.call("_trigger_rival_face_to_face_dialogue", rival_node)
						if on_completed.is_valid():
							on_completed.call()
					)
				)
			)
		else:
			main_game.call("_trigger_rival_face_to_face_dialogue", rival_node)
			if on_completed.is_valid():
				on_completed.call()
	)

	tree.create_timer(18.0, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(main_game) and main_game.get("is_rival_cinematic_active") == true:
			push_warning("[CINEMATIC WATCHDOG] Rival cinematic sequence timed out; recovering and starting encounter.")
			main_game.call("_on_dialogue_skip_requested")
	)
