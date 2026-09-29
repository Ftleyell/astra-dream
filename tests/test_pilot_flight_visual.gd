extends Node

func _ready() -> void:
	print("Capturing Pilot Sandevistan flight visual...")
	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	var game: Node = main_game_scene.instantiate()
	add_child(game)

	# Give a few frames for ready
	for i in range(10):
		await get_tree().process_frame

	# End any dialogic timeline if active
	if Engine.has_singleton("Dialogic") or get_tree().root.has_node("Dialogic"):
		var dialogic_node: Node = get_tree().root.get_node_or_null("Dialogic")
		if dialogic_node and dialogic_node.has_method("end_timeline"):
			dialogic_node.call("end_timeline")

	# Limpiar capas de UI y retratos en la raíz
	for c in get_tree().root.get_children():
		if c.name.begins_with("Dialogic") or c is CanvasLayer:
			c.queue_free()

	# Ocultar HUD y overlays en game
	var hud = game.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	var skip_badge = game.get_node_or_null("SkipBadgeLayer")
	if skip_badge:
		skip_badge.visible = false

	# Esperar a que se limpien las capas
	for i in range(15):
		await get_tree().process_frame

	var player_node: Player = game.get_node_or_null("Player") as Player
	if player_node:
		# Centrar cámara en el jugador
		var cam: Camera2D = game.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.global_position = player_node.global_position
			cam.zoom = Vector2(3.0, 3.0) # Zoom nítido sobre la piloto

		# Simular vuelo con Dash Sandevistan hacia arriba
		player_node.velocity = Vector2(0.0, -320.0)
		player_node.is_dashing = true
		player_node._update_pilot_shader(0.016, true)

		# Spawnear manualmente un par de afterimages detrás para la foto
		var vfx_comp = player_node.get_node_or_null("SandevistanFlightVFX")
		if vfx_comp:
			vfx_comp._spawn_ghost(player_node.global_position + Vector2(0, 45), true)
			vfx_comp._spawn_ghost(player_node.global_position + Vector2(0, 90), true)

	for i in range(10):
		await get_tree().process_frame

	var vp: Viewport = get_viewport()
	var img: Image = vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://tests/screenshots")
	img.save_png("res://tests/screenshots/pilot_sandevistan_preview.png")
	print("Screenshot saved to res://tests/screenshots/pilot_sandevistan_preview.png")
	get_tree().quit(0)
