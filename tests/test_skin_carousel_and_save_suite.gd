extends Node

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const NavigatorSelectionModalScript = preload("res://scenes/ui/character_select/navigator_selection_modal.gd")
const HubPetRoamerScript = preload("res://scenes/ui/hub/hub_pet_roamer.gd")
const PetDataScript = preload("res://data/pets/pet_data.gd")

func _ready() -> void:
	print("\n=======================================================")
	print("🧪 VERIFICACIÓN COMPLETA: CAROUSEL, SAVEGAME & HUB SKINS")
	print("=======================================================")

	# 1. Verificación de persistencia de skins en SaveManager
	print("\n[1/4] Verificando que SaveManager NO pierda skins al guardar perfil parcialmente...")
	var skin_id := "pilot_nova_cyber_neon"
	var unlock_res := SaveManager.unlock_or_upgrade_skin(skin_id)
	assert(SaveManager.is_skin_unlocked(skin_id), "La skin debe estar desbloqueada")
	var initial_stars := SaveManager.get_skin_stars(skin_id)
	assert(initial_stars >= 1, "Debe tener al menos 1 estrella")

	# Llamada a set_game_speed o set_biomass (que llama a save_profile internamente)
	SaveManager.set_game_speed(1.25)
	SaveManager.set_biomass(SaveManager.get_biomass() + 10)

	# Verificar que la skin sigue presente y no fue borrada
	assert(SaveManager.is_skin_unlocked(skin_id), "ERROR: La skin fue borrada por save_profile parcial!")
	assert(SaveManager.get_skin_stars(skin_id) == initial_stars, "ERROR: Las estrellas se alteraron!")
	print("  ✓ Skins se conservan al 100% tras operaciones de guardado de perfil")

	# 2. Verificación de equipar y desequipar skins
	print("\n[2/4] Verificando equipar y desequipar skins en SaveManager...")
	SaveManager.equip_skin("pilot:nova", skin_id)
	assert(SaveManager.get_equipped_skin("pilot:nova") == skin_id, "Debe estar equipada")
	SaveManager.set_game_speed(1.0) # Forzar otro guardado
	assert(SaveManager.get_equipped_skin("pilot:nova") == skin_id, "Skin equipada debe persistir tras guardado")
	SaveManager.unequip_skin("pilot:nova")
	assert(SaveManager.get_equipped_skin("pilot:nova") == "", "Skin debe quedar desequipada")
	print("  ✓ Skins equipadas persisten correctamente en savegame")

	# 3. Verificación de HubPetRoamer y shader billboarding
	print("\n[3/4] Verificando HubPetRoamer y Shader Spatial con Billboarding...")
	var pet_res := PetDataScript.new()
	pet_res.pet_id = &"mochi"
	pet_res.display_name = "Mochi"
	var roamer = HubPetRoamerScript.new()
	roamer.setup(pet_res, Vector3.ZERO)
	assert(is_instance_valid(roamer.sprite), "Roamer debe tener sprite 3D")
	assert(roamer.sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Sprite3D debe tener BILLBOARD_ENABLED")
	
	# Probar aplicar skin con estrellas al Sprite3D
	SaveManager.unlock_or_upgrade_skin("pet_mochi_cyber_neon")
	SaveManager.unlock_or_upgrade_skin("pet_mochi_cyber_neon")
	var mochi_stars := SaveManager.get_skin_stars("pet_mochi_cyber_neon")
	CosmeticsManager.apply_skin_to_sprite3d(roamer.sprite, "pet_mochi_cyber_neon", mochi_stars)
	if mochi_stars > 1:
		assert(roamer.sprite.material_override is ShaderMaterial, "Con >1 estrella debe tener ShaderMaterial")
		var sm := roamer.sprite.material_override as ShaderMaterial
		assert(sm.shader != null, "ShaderMaterial debe tener shader asignado")
		assert(sm.get_shader_parameter("texture_albedo") != null, "texture_albedo debe estar configurado")
	print("  ✓ HubPetRoamer y ShaderMaterial 3D aplican texturas y billboarding sin errores")
	roamer.free()

	# 4. Verificación de NavigatorSelectionModal Carousel Layout en Modo Skins
	print("\n[4/4] Verificando Cover Flow circular y z_index en NavigatorSelectionModal...")
	var modal_scene := load("res://scenes/ui/character_select/navigator_selection_modal.tscn")
	assert(modal_scene != null, "Escena de modal debe existir")
	var modal = modal_scene.instantiate()
	add_child(modal)

	# Simular modo skins
	modal._is_skin_mode = true
	modal._update_carousel_layout(true, Color.CYAN)

	var cards_row_separation = modal.cards_row.get_theme_constant("separation")
	assert(cards_row_separation < 0, "En modo skins, la separación debe ser negativa para Cover Flow!")
	assert(modal.artwork_frame.z_index > modal.left_card.z_index, "Artwork central debe tener mayor z_index que las cartas laterales")
	assert(modal.left_label.visible == false, "En modo skins, las etiquetas laterales deben estar ocultas")
	assert(modal.right_label.visible == false, "En modo skins, las etiquetas laterales deben estar ocultas")
	assert(modal.artwork_frame.clip_contents == false, "ArtworkFrame NO debe recortar su resplandor/glow!")

	# Simular volver a modo navegadoras
	modal._is_skin_mode = false
	modal._update_carousel_layout(false, Color.CYAN)
	cards_row_separation = modal.cards_row.get_theme_constant("separation")
	assert(cards_row_separation > 0, "En modo navegadoras, la separación debe ser normal")
	assert(modal.left_label.visible == true, "En modo navegadoras, las etiquetas laterales deben ser visibles")

	modal.queue_free()
	print("  ✓ Cover Flow circular de skins y z-indexing verificado correctamente")

	# 5. Verificación de HubWorld: TrophyRoom y Pedestal de Nyx en Escena
	print("\n[5/5] Verificando HubWorld: TrophyRoom y Pedestal de Nyx...")
	var hub_scene := load("res://scenes/ui/hub/hub_world.tscn")
	assert(hub_scene != null, "HubWorld scene debe existir")
	var hub = hub_scene.instantiate()
	add_child(hub)
	await get_tree().process_frame

	# A) Verificar Sala de Trofeos
	var trophy_room = hub.get_node_or_null("TrophyRoom")
	assert(trophy_room != null, "TrophyRoom debe existir en la escena")
	assert(trophy_room.get_child_count() == 5, "TrophyRoom debe contener los 5 pedestales de trofeos")
	assert(hub.trophy_holo_nodes.size() == 5, "trophy_holo_nodes debe contener los 5 hologramas para animación")

	# B) Verificar Pedestal y Cutout de Nyx
	var ped_nyx: Node3D = hub.get_node_or_null("Pedestals/Pedestal_Nyx")
	assert(ped_nyx != null, "Pedestal_Nyx debe existir en la escena (visible para el editor)")
	var cutout_nyx: Sprite3D = hub.get_node_or_null("RosterCutouts/Cutout_Nyx")
	assert(cutout_nyx != null, "Cutout_Nyx debe existir en la escena (visible para el editor)")
	var inter_nyx: Area3D = hub.get_node_or_null("RosterCutouts/Interactable_Nyx")
	assert(inter_nyx != null, "Interactable_Nyx debe existir en la escena")

	# C) Probar comportamiento cuando Nyx está bloqueada vs desbloqueada
	# Probar bloqueada:
	SaveManager.lock_character(&"nyx")
	hub._collect_and_verify_sprites()
	hub._setup_interactables()
	assert(cutout_nyx.visible == false, "Cuando Nyx está bloqueada en savegame, su cutout DEBE estar oculto")
	assert(ped_nyx.visible == false, "Cuando Nyx está bloqueada en savegame, su pedestal DEBE estar oculto")
	assert(inter_nyx.visible == false, "Cuando Nyx está bloqueada, su interactuable DEBE estar oculto")

	# Probar desbloqueada:
	SaveManager.unlock_character(&"nyx")
	hub._collect_and_verify_sprites()
	hub._setup_interactables()
	assert(cutout_nyx.visible == true, "Cuando Nyx está desbloqueada en savegame, su cutout DEBE ser visible")
	assert(ped_nyx.visible == true, "Cuando Nyx está desbloqueada en savegame, su pedestal DEBE ser visible")
	assert(inter_nyx.visible == true, "Cuando Nyx está desbloqueada, su interactuable DEBE ser visible")

	# D) Verificar Alineación de Terminales (Run a la izq, Gacha en el medio exacto, HighScores a la der)
	var term_mission = hub.get_node_or_null("Terminals/MissionTerminal")
	var term_gacha = hub.get_node_or_null("Terminals/GachaTerminal")
	var term_scores = hub.get_node_or_null("Terminals/HighScoresTerminal")
	assert(term_mission != null and term_gacha != null and term_scores != null, "Todos los terminales deben existir")
	assert(is_equal_approx(term_mission.position.x, -3.2), "MissionTerminal debe estar en x = -3.2")
	assert(is_equal_approx(term_gacha.position.x, 0.0), "GachaTerminal debe estar exactamente en el centro x = 0.0")
	assert(is_equal_approx(term_scores.position.x, 3.2), "HighScoresTerminal debe estar en x = 3.2")
	assert(term_gacha.get_node_or_null("KenneyArcadeGacha") != null, "GachaTerminal debe contener la carcasa de arcade de Kenney")
	assert(hub.gacha_holo != null, "GachaCapsuleHolo debe estar vinculado")
	assert(hub.gacha_interactable != null, "Interactable_Gacha debe estar activo")

	hub._refresh_pedestal_skins()
	hub.queue_free()
	print("  ✓ TrophyRoom, Pedestal de Nyx y Alineación de Terminales (Arcade Gacha al centro) comprobados al 100%")


	print("\n=======================================================")
	print("🎉 TODAS LAS VERIFICACIONES COMPLETADAS CON ÉXITO!")
	print("=======================================================\n")
	get_tree().quit(0)
