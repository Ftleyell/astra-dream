extends Node

func _ready() -> void:
	print("Capturing HUD rework visual...")
	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	var game: Node = main_game_scene.instantiate()
	add_child(game)

	# Give a few frames for ready
	for i in range(15):
		await get_tree().process_frame

	# End any dialogic timeline if active
	if Engine.has_singleton("Dialogic") or get_tree().root.has_node("Dialogic"):
		var dialogic_node: Node = get_tree().root.get_node_or_null("Dialogic")
		if dialogic_node and dialogic_node.has_method("end_timeline"):
			dialogic_node.call("end_timeline")

	var hud: GameHUD = game.get_node_or_null("HUD") as GameHUD
	if hud:
		hud.update_credits(850)
		hud.update_biomass(0, 1420)
		hud.update_exp(120.0, 150.0, 5)
		# Set laser on cooldown (2.1s left of 5.0s)
		hud.update_laser_cooldown(2.1, 5.0)

	var player_node: Player = game.get_node_or_null("Player") as Player
	if player_node:
		player_node.dash_charges = 1
		player_node.max_dash_charges = 2
		player_node.bomb_count = 2
		if hud:
			# Dash: 1 charge ready (pip 1 lit, pip 2 dim), 45% recharged into 2nd charge
			hud._on_dash_updated(1, 2, 0.45, false)
			# Bomb: 2 bombs available (pip 1 & 2 lit, pip 3 dim gray)
			hud._on_bomb_used(2)

	for i in range(30):
		await get_tree().process_frame

	var vp: Viewport = get_viewport()
	var img: Image = vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://tests/screenshots")
	img.save_png("res://tests/screenshots/hud_rework_stage4_check.png")
	print("Screenshot saved to res://tests/screenshots/hud_rework_stage4_check.png")
	get_tree().quit(0)
