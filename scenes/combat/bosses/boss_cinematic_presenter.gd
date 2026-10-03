class_name BossCinematicPresenter
extends RefCounted

## Presentador especializado en la puesta en escena cinemática horizontal (1920x1080),
## encuadre de cámara, fracturas de realidad cósmica (CosmicRealityTear) y secuencias de emergencia.

const CosmicRealityTearScript := preload("res://scenes/combat/bosses/cosmic_reality_tear.gd")
const BossEmergenceHelperScript := preload("res://scenes/combat/bosses/boss_emergence_helper.gd")

## Prepara la posición de la cámara y orientación del jugador para duelos cinemáticos 1v1
static func setup_cinematic_duel(main_game: Node2D, cin_zoom: float = 1.0) -> Dictionary:
	var player: Node2D = main_game.get("player") as Node2D
	var half_width_world: float = 480.0 / cin_zoom
	var separation_world: float = 960.0 / cin_zoom

	if is_instance_valid(player):
		if player.has_method("set_cinematic_duel_facing"):
			player.set_cinematic_duel_facing()
		else:
			player.set("velocity", Vector2.ZERO)
			if "current_facing_angle" in player:
				player.set("current_facing_angle", 0.0)
		if player.has_method("suppress_bomb_input"):
			player.suppress_bomb_input(999.0)

	freeze_combat_environment(main_game)

	var p_pos: Vector2 = player.global_position if is_instance_valid(player) else Vector2.ZERO
	var cam_pos: Vector2 = p_pos + Vector2(half_width_world, 0.0)
	var boss_target_pos: Vector2 = p_pos + Vector2(separation_world, 0.0)

	var cam: GameCamera2D = main_game.get_tree().get_first_node_in_group("camera") as GameCamera2D
	if cam and cam.has_method("set_cinematic_focus"):
		cam.set_cinematic_focus(cam_pos, cin_zoom)

	return {
		"cam": cam,
		"player": player,
		"cam_pos": cam_pos,
		"boss_target_pos": boss_target_pos
	}

## Restablece los controles y cámara post-cinemática
static func restore_combat_after_emergence(main_game: Node2D, cam: GameCamera2D, player: Node2D) -> void:
	if cam and cam.has_method("clear_cinematic_focus"):
		cam.clear_cinematic_focus()
	if is_instance_valid(player) and player.has_method("resume_movement_control"):
		player.resume_movement_control()
	unfreeze_combat_environment(main_game)
	main_game.set("is_boss_transmission_active", false)
	main_game.get_tree().paused = false
	main_game.call("notify_menu_closed", 0.4)
	main_game.call("_resume_pending_systems_after_cinematics")

## Congela inmediatamente proyectiles, oleadas y enemigos menores sincronizados con la cinemática
static func freeze_combat_environment(main_game: Node2D) -> void:
	if not is_instance_valid(main_game):
		return

	# Otorgar invulnerabilidad total al jugador durante la cinemática
	var player: Node2D = main_game.get("player") as Node2D
	if not is_instance_valid(player) and main_game.get_tree():
		player = main_game.get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player):
		player.set("is_invulnerable", true)

	# Limpiar proyectiles hostiles en pantalla
	var bullet_srv: BulletServer = main_game.get_node_or_null("/root/BulletServer") as BulletServer
	if not bullet_srv and main_game.get_parent():
		bullet_srv = main_game.get_parent().get_node_or_null("BulletServer") as BulletServer
	if bullet_srv:
		bullet_srv.bomb_clear_all()

	# Pausar generación de nuevos enemigos
	var enemy_spawner: Node = main_game.get("enemy_spawner")
	if enemy_spawner and enemy_spawner.has_method("set_spawning_paused"):
		enemy_spawner.set_spawning_paused(true)

	# Detener en seco y congelar el procesamiento de todos los enemigos comunes
	var tree := main_game.get_tree()
	if tree:
		for enemy in tree.get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and not enemy.is_in_group("bosses") and not enemy.is_in_group("rival_pilots"):
				if enemy is CharacterBody2D:
					(enemy as CharacterBody2D).velocity = Vector2.ZERO
				enemy.set_physics_process(false)
				enemy.set_process(false)

		# Congelar amenazas ambientales activas (asteroides, esquirlas)
		for ast in tree.get_nodes_in_group("asteroids"):
			if is_instance_valid(ast):
				ast.set_physics_process(false)
				ast.set_process(false)
		for shard in tree.get_nodes_in_group("shrapnel_shards"):
			if is_instance_valid(shard):
				shard.set_physics_process(false)
				shard.set_process(false)

## Reanuda el procesamiento del entorno y restaura los controles con buffer de invulnerabilidad
static func unfreeze_combat_environment(main_game: Node2D) -> void:
	if not is_instance_valid(main_game):
		return

	var tree := main_game.get_tree()
	if tree:
		# Reactivar procesamiento de enemigos comunes
		for enemy in tree.get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and not enemy.is_in_group("bosses") and not enemy.is_in_group("rival_pilots"):
				enemy.set_physics_process(true)
				enemy.set_process(true)

		# Reactivar amenazas ambientales
		for ast in tree.get_nodes_in_group("asteroids"):
			if is_instance_valid(ast):
				ast.set_physics_process(true)
				ast.set_process(true)
		for shard in tree.get_nodes_in_group("shrapnel_shards"):
			if is_instance_valid(shard):
				shard.set_physics_process(true)
				shard.set_process(true)

	# Reanudar generador de enemigos
	var enemy_spawner: Node = main_game.get("enemy_spawner")
	if enemy_spawner and enemy_spawner.has_method("set_spawning_paused"):
		enemy_spawner.set_spawning_paused(false)

	# Levantar invulnerabilidad del jugador con buffer de gracia (0.5s) para reacción justa
	var player: Node2D = main_game.get("player") as Node2D
	if not is_instance_valid(player) and tree:
		player = tree.get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and tree:
		tree.create_timer(0.5, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(player):
				player.set("is_invulnerable", false)
		)

## Ejecuta la secuencia cósmica de fractura de realidad y emergencia
static func play_reality_tear_emergence(
	main_game: Node2D,
	boss_node: Node2D,
	boss_target_pos: Vector2,
	domain_color: Color,
	tear_inner_radius: float,
	tear_outer_radius: float,
	trigger_alert_callback: Callable,
	on_emerged_callback: Callable
) -> void:
	var tear = CosmicRealityTearScript.new()
	tear.setup(boss_target_pos, domain_color, tear_inner_radius, tear_outer_radius)
	tear.auto_collapse = false
	tear.process_mode = Node.PROCESS_MODE_ALWAYS
	main_game.add_child(tear)

	main_game.get_tree().create_timer(0.40, true, false, true).timeout.connect(func() -> void:
		if not is_instance_valid(boss_node):
			return
		tear.shockwave_completed.connect(func() -> void:
			trigger_alert_callback.call(func() -> void:
				main_game.get_tree().create_timer(0.25, true, false, true).timeout.connect(func() -> void:
					if not is_instance_valid(boss_node):
						if is_instance_valid(tear):
							tear.queue_free()
						return
					var on_emerge_finished := func() -> void:
						if is_instance_valid(boss_node):
							boss_node.set("is_invulnerable", false)
							boss_node.set_meta("_is_emerging", false)
						if is_instance_valid(tear):
							tear.start_collapse()
						on_emerged_callback.call()

					if boss_node.has_method("emerge_from_tear"):
						boss_node.emerge_from_tear(on_emerge_finished)
					else:
						BossEmergenceHelperScript.emerge_boss(boss_node, tear, on_emerge_finished)
				)
			)
		, Object.CONNECT_ONE_SHOT)
	)
