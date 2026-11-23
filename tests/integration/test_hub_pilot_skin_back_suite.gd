extends BaseTestSuite

func _ready() -> void:
	super._ready()
	timeout_seconds = 10.0
	print("\n==========================================")
	print("[TEST] Testing Hub3D Pilot Skin Back/Front Dynamic Recolors & Shaders...")
	print("==========================================")

	var pilot_ids: Array[StringName] = [&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo", &"nyx"]
	var test_palettes := ["gotica", "cyber_mecha", "solar_valkyrie"]

	# 1. Verificar existencia de los assets de espalda recoloreados en disco
	for pid in pilot_ids:
		for pal in test_palettes:
			var back_recolor := "res://assets/recolors/pilots/fullbody_%s_%s_back.png" % [String(pid).to_lower(), pal]
			var back_recolor_flip := "res://assets/recolors/pilots/fullbody_%s_%s_back_flipped.png" % [String(pid).to_lower(), pal]
			assert(ResourceLoader.exists(back_recolor), "Asset de espalda recolor no encontrado: %s" % back_recolor)
			assert(ResourceLoader.exists(back_recolor_flip), "Asset de espalda flipped recolor no encontrado: %s" % back_recolor_flip)

	print("  ✓ Assets recoloreados de espalda verificados en disco para todas las pilotos y paletas de prueba")

	# 2. Instanciar HubPlayerController3D y probar con skins equipados
	var controller := HubPlayerController3D.new()
	add_child(controller)

	for pid in pilot_ids:
		var slot_key := "pilot:" + String(pid).to_lower()
		var original_skin := SaveManager.get_equipped_skin(slot_key)
		var test_skin := "pilot_%s_gotica" % String(pid).to_lower()

		# Desbloquear skin con 2 estrellas para probar shader neón
		SaveManager.unlock_or_upgrade_skin(test_skin)
		SaveManager.unlock_or_upgrade_skin(test_skin)
		SaveManager.equip_skin(slot_key, test_skin)

		controller.set_character(pid)
		assert(controller.active_character_id == pid, "Piloto activo debe ser %s" % pid)

		var expected_skin_front := "res://assets/recolors/pilots/fullbody_%s_gotica.png" % String(pid).to_lower()
		var expected_skin_back := "res://assets/recolors/pilots/fullbody_%s_gotica_back.png" % String(pid).to_lower()

		# A. Mirando al frente con skin equipado
		assert(controller.visual_sprite.texture.resource_path == expected_skin_front, "%s frente debe mostrar skin cyber_neon" % pid)
		assert(controller.visual_sprite.material_override != null, "Skin 2★ debe tener ShaderMaterial activo")

		# B. Caminar hacia el fondo (opuesto a la cámara): debe cambiar a la espalda del skin con el shader activo
		controller._is_facing_back = true
		controller._update_character_texture()
		assert(controller.visual_sprite.texture.resource_path == expected_skin_back, "%s espalda debe mostrar skin cyber_neon de espaldas" % pid)
		assert(controller.visual_sprite.material_override != null, "%s espalda con 2★ debe mantener ShaderMaterial neón activo" % pid)

		# C. Reposo (Idle): debe conservar la espalda del skin
		controller._update_character_texture()
		assert(controller.visual_sprite.texture.resource_path == expected_skin_back, "%s debe conservar skin de espalda en reposo" % pid)

		# D. Caminar hacia la cámara: debe volver al frente del skin
		controller._is_facing_back = false
		controller._update_character_texture()
		assert(controller.visual_sprite.texture.resource_path == expected_skin_front, "%s debe volver al frente del skin" % pid)

		# Restaurar estado original
		SaveManager.equip_skin(slot_key, original_skin)

	controller.queue_free()

	print("\n==========================================")
	print("[PASS] HUB3D PILOT SKIN BACK/FRONT RECOLORS & SHADERS VERIFIED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)
