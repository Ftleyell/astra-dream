extends Node

func _ready() -> void:
	print("--- TEST EXO PILOT FLIGHT SUITE START ---")
	
	# 1. Instanciar escena principal o player
	var player_script = load("res://scenes/combat/player/player.gd")
	assert(player_script != null, "player.gd failed to load")
	
	var player = CharacterBody2D.new()
	player.set_script(player_script)
	add_child(player)
	
	# Mock WeaponController child
	var weapon_ctrl_script = load("res://scenes/combat/player/weapon_controller.gd")
	var w_ctrl = Node2D.new()
	w_ctrl.name = "WeaponController"
	w_ctrl.set_script(weapon_ctrl_script)
	player.add_child(w_ctrl)
	
	# Mock HitboxCore
	var hitbox_core = Node2D.new()
	hitbox_core.name = "HitboxCore"
	player.add_child(hitbox_core)
	
	# Cargar roster y asignar una piloto (Nova)
	var roster = CharacterData.load_roster()
	assert(not roster.is_empty(), "Roster is empty")
	var nova: CharacterData = roster.get(&"nova", roster.values()[0])
	player.character_data = nova
	
	# Simular _ready de player
	player._ready()
	
	# 2. Verificar que ShipSprite tiene el ShaderMaterial de vuelo
	var ship_spr: Sprite2D = player.get_node_or_null("ShipSprite") as Sprite2D
	assert(ship_spr != null, "ShipSprite should be created")
	assert(ship_spr.material is ShaderMaterial, "ShipSprite must have ShaderMaterial")
	var mat: ShaderMaterial = ship_spr.material as ShaderMaterial
	assert(mat.shader != null, "Shader must be assigned to ShaderMaterial")
	
	var p_color: Color = mat.get_shader_parameter("primary_color")
	print("Pilot primary color configured: ", p_color)
	assert(p_color == nova.color, "Primary color should match character data color")
	
	# 3. Probar cinemática de vuelo hacia la derecha
	player.velocity = Vector2(250.0, 0.0) # Moviéndose hacia la derecha
	player._physics_process(0.1)
	
	var angle_after_move: float = player.current_facing_angle
	print("Current facing angle moving right: ", angle_after_move)
	# Vector2(1, 0).angle() == 0.0
	assert(abs(angle_after_move) < 1.0, "Facing angle should interpolate towards 0 radians")
	
	var thrust_cruise: float = mat.get_shader_parameter("thrust_intensity")
	print("Thrust intensity during cruise: ", thrust_cruise)
	assert(thrust_cruise >= 0.6, "Thrust intensity should be active during flight")
	
	# 4. Probar estado de Dash
	player.is_dashing = true
	player._physics_process(0.016)
	var thrust_dash: float = mat.get_shader_parameter("thrust_intensity")
	print("Thrust intensity during dash: ", thrust_dash)
	assert(thrust_dash >= 2.0, "Thrust intensity should be at overdrive during dash")
	player.is_dashing = false
	
	# 5. Probar estado de reposo (Idle)
	player.velocity = Vector2.ZERO
	player._physics_process(0.016)
	var thrust_idle: float = mat.get_shader_parameter("thrust_intensity")
	print("Thrust intensity at idle: ", thrust_idle)
	assert(thrust_idle < 0.45, "Thrust intensity should be soft pilot flame at idle")
	
	# 6. Probar Hit Flash y reactor
	player.take_damage(10.0)
	assert(player.hit_flash_timer > 0.0, "hit_flash_timer should be triggered on damage")
	player._physics_process(0.016)
	var flash_param: float = mat.get_shader_parameter("hit_flash")
	var gem_glow_param: float = mat.get_shader_parameter("core_gem_glow")
	print("Hit flash param: ", flash_param, " | Gem glow: ", gem_glow_param)
	assert(flash_param == 1.0, "hit_flash shader param should be 1.0 on damage")
	assert(gem_glow_param > 2.0, "core_gem_glow should flare up on damage")
	
	# 7. Probar desacoplamiento de apuntado de WeaponController
	w_ctrl.global_position = Vector2(500, 500)
	w_ctrl.is_manual_aim = false
	w_ctrl.last_known_target_dir = Vector2.DOWN # Apuntando hacia abajo (PI / 2)
	w_ctrl._process(0.1)
	print("WeaponController rotation: ", w_ctrl.rotation)
	assert(w_ctrl.rotation != player.current_facing_angle, "Weapon rotation should decouple from flight angle")
	
	print("--- TEST EXO PILOT FLIGHT SUITE PASSED SUCCESSFULLY ---")
	get_tree().quit(0)
