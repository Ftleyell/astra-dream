extends Node

func _ready() -> void:
	print("\n==========================================")
	print("[TEST] Testing Hub 3D Character & Pet Shadows...")
	print("==========================================")
	
	# 1. Test Pet Shadow
	var PetRoamerScript := preload("res://scenes/ui/hub/hub_pet_roamer.gd")
	var pet_instance = Node3D.new()
	pet_instance.set_script(PetRoamerScript)
	pet_instance.setup(null, Vector3.ZERO)
	add_child(pet_instance)
	await get_tree().process_frame
	
	var pet_shadow: MeshInstance3D = pet_instance.get_node_or_null("PetShadow") as MeshInstance3D
	assert(pet_shadow != null, "PetShadow node must exist under PetRoamer")
	assert(pet_shadow.mesh is QuadMesh, "PetShadow mesh must be a QuadMesh")
	assert(pet_shadow.material_override is ShaderMaterial, "PetShadow must have a ShaderMaterial override")
	var pet_mat: ShaderMaterial = pet_shadow.material_override as ShaderMaterial
	assert(pet_mat.shader != null, "PetShadow shader must be assigned")
	assert(pet_mat.shader.resource_path == "res://shaders/retro_circle_shadow.gdshader", "PetShadow must use retro_circle_shadow.gdshader")
	var pet_col = pet_mat.get_shader_parameter("shadow_color")
	print("Pet shadow_color param: ", pet_col)
	assert(is_equal_approx(pet_col.a, 0.45), "PetShadow alpha must be 0.45")
	print("  ✓ Sombra redonda de la mascota verificada con retro_circle_shadow.gdshader (Alpha: 0.45)")
	pet_instance.queue_free()
	
	# 2. Test Player Silhouette Shadow
	var hub_packed := load("res://scenes/ui/hub/hub_world.tscn") as PackedScene
	assert(hub_packed != null, "hub_world.tscn must load successfully")
	var hub: Node = hub_packed.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	
	var player = hub.get_node_or_null("PlayerController")
	assert(player != null, "PlayerController must exist in hub_world")
	
	var shadow_sprite: Sprite3D = player.get_node_or_null("PlayerShadow") as Sprite3D
	assert(shadow_sprite != null, "PlayerShadow Sprite3D must exist under PlayerController")
	assert(shadow_sprite.axis == Vector3.AXIS_Y, "PlayerShadow must be aligned with axis Y (ground plane)")
	assert(shadow_sprite.shaded == false, "PlayerShadow must be unshaded")
	assert(shadow_sprite.material_override is ShaderMaterial, "PlayerShadow must have a ShaderMaterial override")
	var p_shadow_mat: ShaderMaterial = shadow_sprite.material_override as ShaderMaterial
	assert(p_shadow_mat.shader != null, "PlayerShadow shader must be assigned")
	assert(p_shadow_mat.shader.resource_path == "res://shaders/character_silhouette_shadow.gdshader", "PlayerShadow must use character_silhouette_shadow.gdshader")
	var p_col = p_shadow_mat.get_shader_parameter("shadow_color")
	assert(is_equal_approx(p_col.a, 0.48), "PlayerShadow alpha must be 0.48")
	assert(shadow_sprite.position.y >= 0.03, "PlayerShadow must be above the floor mesh surface (top Y = 0.0253)")
	assert(shadow_sprite.scale.z >= 0.5, "PlayerShadow scale.z must be projected along ground (>= 0.5)")
	assert(shadow_sprite.offset == player.visual_sprite.offset, "PlayerShadow offset must match visual_sprite (feet pivot)")
	assert(not shadow_sprite.rotation.is_zero_approx(), "PlayerShadow rotation must be aligned with DirectionalLight3D ground projection")
	assert(shadow_sprite.texture != null, "PlayerShadow must have the character texture assigned")
	print("  ✓ Sombra del jugador verificada como Proyección Direccional con pivot en los pies y orientada por luz (Scale: %s, Rotation: %s, Offset: %s)" % [shadow_sprite.scale, shadow_sprite.rotation, shadow_sprite.offset])
	
	# 3. Test Silhouette Update on Character Change
	player.set_character(&"valentina")
	await get_tree().process_frame
	assert(shadow_sprite.texture != null, "PlayerShadow must maintain texture when switching to Valentina")
	assert(shadow_sprite.texture == player.visual_sprite.texture, "PlayerShadow texture must match visual_sprite texture")
	assert(shadow_sprite.offset == player.visual_sprite.offset, "PlayerShadow offset must track visual_sprite offset on character change")
	print("  ✓ Silueta de sombra de Valentina actualizada dinámicamente con su PNG: ", shadow_sprite.texture.resource_path)
	
	# 4. Test Facing Back Texture Sync
	player._is_facing_back = true
	player._update_character_texture()
	await get_tree().process_frame
	assert(shadow_sprite.texture == player.visual_sprite.texture, "PlayerShadow must sync when facing back")
	assert(shadow_sprite.offset == player.visual_sprite.offset, "PlayerShadow offset must match when facing back")
	print("  ✓ Silueta de sombra sincronizada con textura de espalda al girar: ", shadow_sprite.texture.resource_path)
	
	# 5. Test Dynamic Hop Reaction (Squash & Fade)
	player._update_shadow_hop(1.0, 1.0)
	assert(shadow_sprite.scale.z < player._shadow_proj_scale.z, "Shadow scale.z must contract at the peak of the hop")
	var hop_col = p_shadow_mat.get_shader_parameter("shadow_color")
	assert(hop_col.a < 0.48, "Shadow alpha must fade at the peak of the hop")
	print("  ✓ Dinámica reactiva de saltito verificada: escala contraída (%s) y alpha atenuado (%s)" % [shadow_sprite.scale, hop_col.a])
	
	player._update_shadow_hop(0.0, 1.0)
	assert(is_equal_approx(shadow_sprite.scale.z, player._shadow_proj_scale.z), "Shadow scale.z must restore on ground")
	var ground_col = p_shadow_mat.get_shader_parameter("shadow_color")
	assert(is_equal_approx(ground_col.a, 0.48), "Shadow alpha must restore to 0.48 on ground")
	print("  ✓ Restauración en suelo/reposo verificada: escala base restablecida y alpha a 0.48")
	
	# 5. Verify Pedestal Pilot Cutouts DO NOT Have Shadows
	var roster_group: Node3D = hub.get_node_or_null("RosterCutouts") as Node3D
	assert(roster_group != null, "RosterCutouts Node3D must exist in hub_world")
	
	for i in range(hub.PILOT_ROSTER.size()):
		var char_data: Dictionary = hub.PILOT_ROSTER[i]
		var char_id: String = String(char_data["id"])
		var cname: String = char_id.capitalize()
		
		var ped_shadow = roster_group.get_node_or_null("Shadow_" + cname)
		assert(ped_shadow == null, "Pedestals must NOT have shadows (Shadow_%s should not exist)" % cname)
		print("  ✓ Verificado que el pedestal de %s no tiene sombra (solo la piloto activa la tiene)" % cname)
	
	hub.queue_free()
	
	print("\n==========================================")
	print("[PASS] ALL HUB 3D SHADOW TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)
