extends Node

func _ready() -> void:
	print("Capturando screenshot in-game de los monstruos Lovecraftianos en combate...")
	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	var game: Node = main_game_scene.instantiate()
	add_child(game)

	# Esperar frames iniciales de carga
	for i in range(12):
		await get_tree().process_frame

	# Finalizar Dialogic y remover capas de tutorial/narrativa
	if Engine.has_singleton("Dialogic") or get_tree().root.has_node("Dialogic"):
		var dialogic_node: Node = get_tree().root.get_node_or_null("Dialogic")
		if dialogic_node and dialogic_node.has_method("end_timeline"):
			dialogic_node.call("end_timeline")

	for c in get_tree().root.get_children():
		if c.name.begins_with("Dialogic") or c is CanvasLayer:
			if c != game.get_node_or_null("HUD"):
				c.queue_free()

	# Desactivar el spawner aleatorio para componer la escena cinematográfica
	var spawner = game.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.queue_free()

	# Limpiar enemigos aleatorios que hayan spawneado en ready
	for node in get_tree().get_nodes_in_group("enemies"):
		node.queue_free()

	await get_tree().process_frame

	var player: Player = game.get_node_or_null("Player") as Player
	if not player:
		print("Error: Player no encontrado.")
		get_tree().quit(1)
		return

	var center_pos: Vector2 = player.global_position

	# Instanciar los 4 monstruos Lovecraftianos
	var shooter_scene: PackedScene = load("res://scenes/combat/enemies/enemy_shooter.tscn")
	var kamikaze_scene: PackedScene = load("res://scenes/combat/enemies/enemy_kamikaze.tscn")
	var tank_scene: PackedScene = load("res://scenes/combat/enemies/enemy_tank.tscn")
	var rainbow_scene: PackedScene = load("res://scenes/combat/enemies/rainbow_enemy.tscn")

	# 1. Shooter (Artillero Ocular con fauces y pústulas) arriba a la derecha
	var shooter = shooter_scene.instantiate() as EnemyShooter
	shooter.global_position = center_pos + Vector2(230.0, -90.0)
	shooter.rotation = (center_pos - shooter.global_position).angle()
	game.add_child(shooter)

	# 2. Kamikaze (Engendro Voraz con colmillos y sangre) arriba a la izquierda
	var kamikaze = kamikaze_scene.instantiate() as EnemyKamikaze
	kamikaze.global_position = center_pos + Vector2(-220.0, -80.0)
	kamikaze.rotation = (center_pos - kamikaze.global_position).angle()
	kamikaze.modulate = Color(1.2, 1.0, 1.0, 1.0)
	game.add_child(kamikaze)

	# 3. Tank (Titán Acorazado con coraza y tentáculos) abajo a la derecha
	var tank = tank_scene.instantiate() as EnemyTank
	tank.global_position = center_pos + Vector2(210.0, 110.0)
	tank.rotation = (center_pos - tank.global_position).angle()
	tank.modulate = Color(1.15, 1.15, 1.25, 1.0)
	game.add_child(tank)

	# 4. Rainbow (Anomalía Astral Iridescente) abajo a la izquierda
	var rainbow = rainbow_scene.instantiate() as RainbowEnemy
	rainbow.global_position = center_pos + Vector2(-200.0, 100.0)
	rainbow.rotation = (center_pos - rainbow.global_position).angle()
	game.add_child(rainbow)
	if is_instance_valid(rainbow.hp_bar):
		rainbow.hp_bar.visible = false

	# Centrar cámara en el jugador con encuadre cercano y cinematográfico
	var cam: Camera2D = game.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.global_position = center_pos
		cam.zoom = Vector2(2.1, 2.1)

	# Disparar algunas balas de muestra del BulletServer para acción visual
	var bullet_server = game.get_node_or_null("BulletServer")
	if bullet_server and bullet_server.has_method("fire_bullet"):
		for a in range(8):
			var ang := (TAU / 8.0) * a
			var bdir := Vector2(cos(ang), sin(ang))
			bullet_server.fire_bullet(shooter.global_position, bdir * 220.0, 1)

	# Dejar que las partículas, shaders de silueta y estelas se desarrollen
	for i in range(25):
		await get_tree().process_frame

	var vp: Viewport = get_viewport()
	var img: Image = vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://tests/screenshots")
	var save_path := "res://tests/screenshots/enemies_in_combat_showcase.png"
	img.save_png(save_path)
	print("Screenshot guardado exitosamente en: ", save_path)
	get_tree().quit(0)
