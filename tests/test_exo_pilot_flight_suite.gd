extends Node

const SandevistanFlightVFX = preload("res://scenes/combat/player/sandevistan_flight_vfx.gd")

func _ready() -> void:
	print("--- TEST EXO PILOT FLIGHT SUITE START ---")

	# 1. Cargar la escena de combate o instanciar el player con su jerarquía completa
	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert(main_game_scene != null, "main_game.tscn failed to load")
	var game: Node = main_game_scene.instantiate()
	add_child(game)

	# Esperar 2 frames para que _ready() procese
	for i in range(2):
		await get_tree().process_frame

	var player: Player = game.get_node_or_null("Player") as Player
	assert(player != null, "Player node must exist in main game")

	# 2. Cargar roster y asignar una piloto (Nova)
	var roster = CharacterData.load_roster()
	assert(not roster.is_empty(), "Roster is empty")
	var nova: CharacterData = roster.get(&"nova", roster.values()[0])
	player.character_data = nova
	player._apply_visual_theme()

	# 3. Verificar que ShipSprite tiene el ShaderMaterial Sandevistan
	var ship_spr: Sprite2D = player.get_node_or_null("ShipSprite") as Sprite2D
	assert(ship_spr != null, "ShipSprite should be created")
	assert(ship_spr.material is ShaderMaterial, "ShipSprite must have ShaderMaterial")
	var mat: ShaderMaterial = ship_spr.material as ShaderMaterial
	assert(mat.shader != null, "Shader must be assigned to ShaderMaterial")

	var p_color: Color = mat.get_shader_parameter("primary_color")
	print("Pilot primary color configured: ", p_color)
	assert(p_color == nova.color, "Primary color should match character data color")

	var sec_color: Color = mat.get_shader_parameter("secondary_color")
	print("Pilot secondary harmonic color: ", sec_color)
	assert(sec_color != Color.BLACK, "Secondary color should be initialized")

	var noise_tex = mat.get_shader_parameter("noise_texture")
	print("Noise texture assigned: ", noise_tex != null)
	assert(noise_tex != null, "Noise texture must be assigned to shader")

	# 4. Verificar existencia y pooling del componente SandevistanFlightVFX
	var vfx_comp: SandevistanFlightVFX = player.get_node_or_null("SandevistanFlightVFX") as SandevistanFlightVFX
	assert(vfx_comp != null, "SandevistanFlightVFX component must be attached to player")
	assert(vfx_comp._pool.size() == SandevistanFlightVFX.POOL_CAPACITY, "Afterimages pool must have capacity 20")
	print("Sandevistan pool initialized with %d pre-allocated ghost sprites" % vfx_comp._pool.size())

	# 5. Probar cinemática y dirección de flameo en movimiento
	player.velocity = Vector2(300.0, 0.0)
	player._update_pilot_shader(0.016, true)

	var thrust_cruise: float = mat.get_shader_parameter("thrust_intensity")
	var flame_dir: Vector2 = mat.get_shader_parameter("flame_direction")
	print("Thrust intensity during flight: ", thrust_cruise, " | Flame dir: ", flame_dir)
	assert(thrust_cruise >= 0.6, "Thrust intensity should be active during flight")
	assert(flame_dir != Vector2.ZERO, "Flame direction must be calculated")

	# 6. Probar estado de Dash (sobrecarga Sandevistan)
	player.is_dashing = true
	player._update_pilot_shader(0.016, true)
	var thrust_dash: float = mat.get_shader_parameter("thrust_intensity")
	var gem_dash: float = mat.get_shader_parameter("core_gem_glow")
	print("Thrust during dash: ", thrust_dash, " | Gem glow during dash: ", gem_dash)
	assert(thrust_dash >= 2.0, "Thrust intensity should be at overdrive during dash")
	assert(gem_dash >= 2.0, "Gem glow should flare during dash")
	player.is_dashing = false

	# 7. Probar estado de reposo (Idle)
	player.velocity = Vector2.ZERO
	player._update_pilot_shader(0.016, false)
	var thrust_idle: float = mat.get_shader_parameter("thrust_intensity")
	print("Thrust intensity at idle: ", thrust_idle)
	assert(thrust_idle < 0.45, "Thrust intensity should be soft pilot flame at idle")

	# 8. Probar Hit Flash y reactor ante daño
	player.take_damage(10.0)
	assert(player.hit_flash_timer > 0.0, "hit_flash_timer should be triggered on damage")
	player._update_pilot_shader(0.016, false)
	var flash_param: float = mat.get_shader_parameter("hit_flash")
	var gem_glow_param: float = mat.get_shader_parameter("core_gem_glow")
	print("Hit flash param: ", flash_param, " | Gem glow on damage: ", gem_glow_param)
	assert(flash_param == 1.0, "hit_flash shader param should be 1.0 on damage")
	assert(gem_glow_param > 2.0, "core_gem_glow should flare up on damage")

	print("--- TEST EXO PILOT FLIGHT SUITE PASSED SUCCESSFULLY ---")
	get_tree().quit(0)
