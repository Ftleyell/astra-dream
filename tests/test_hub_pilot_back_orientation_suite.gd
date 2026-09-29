extends Node

func _ready() -> void:
	print("\n==========================================")
	print("[TEST] Testing Hub3D Pilot Front/Back Orientation Dynamic Switching...")
	print("==========================================")

	var pilot_ids: Array[StringName] = [&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo", &"nyx"]

	# 1. Verificar existencia y dimensiones de assets de frente y espalda para todas las pilotos
	for pid in pilot_ids:
		var front_path := "res://assets/characters/fullbody/fullbody_%s.png" % String(pid).to_lower()
		var back_path := "res://assets/characters/fullbody/fullbody_%s_back.png" % String(pid).to_lower()

		assert(ResourceLoader.exists(front_path), "Asset frontal no encontrado para: %s" % pid)
		assert(ResourceLoader.exists(back_path), "Asset de espalda no encontrado para: %s" % pid)

		var f_tex: Texture2D = load(front_path)
		var b_tex: Texture2D = load(back_path)
		assert(f_tex != null, "Textura frontal no debe ser nula para: %s" % pid)
		assert(b_tex != null, "Textura de espalda no debe ser nula para: %s" % pid)
		assert(f_tex.get_width() == 1200 and f_tex.get_height() == 1600, "Dimensiones de frente deben ser 1200x1600 para: %s" % pid)
		assert(b_tex.get_width() == 1200 and b_tex.get_height() == 1600, "Dimensiones de espalda deben ser 1200x1600 para: %s" % pid)
		print("  ✓ %s: Assets de frente y espalda verificados (1200x1600)" % pid)

	# 2. Instanciar HubPlayerController3D y probar alternancia dinámica
	var controller := HubPlayerController3D.new()
	add_child(controller)

	for pid in pilot_ids:
		var slot_key := "pilot:" + String(pid).to_lower()
		var saved_skin := SaveManager.get_equipped_skin(slot_key)
		SaveManager.equip_skin(slot_key, "") # Desequipar temporalmente para probar asset base

		controller.set_character(pid)
		assert(controller.active_character_id == pid, "Piloto activo debe ser %s" % pid)
		assert(controller.visual_sprite.texture != null, "Sprite debe tener textura asignada")

		var expected_front_path := "res://assets/characters/fullbody/fullbody_%s.png" % String(pid).to_lower()
		var expected_back_path := "res://assets/characters/fullbody/fullbody_%s_back.png" % String(pid).to_lower()

		# Inicialmente frente
		assert(controller.visual_sprite.texture.resource_path == expected_front_path, "%s debe iniciar mirando al frente" % pid)

		# Simular movimiento opuesto a la cámara (hacia el fondo / W)
		controller._is_facing_back = true
		controller._update_character_texture()
		assert(controller.visual_sprite.texture.resource_path == expected_back_path, "%s debe cambiar a textura de espalda al avanzar opuesto a cámara" % pid)

		# Simular reposo (idle): debe conservar la textura de espalda
		controller._update_character_texture()
		assert(controller.visual_sprite.texture.resource_path == expected_back_path, "%s debe conservar textura de espalda en reposo" % pid)

		# Simular movimiento hacia la cámara (hacia el frente / S)
		controller._is_facing_back = false
		controller._update_character_texture()
		assert(controller.visual_sprite.texture.resource_path == expected_front_path, "%s debe volver a textura frontal al avanzar hacia la cámara" % pid)

		# Restaurar skin guardado
		if not saved_skin.is_empty():
			SaveManager.equip_skin(slot_key, saved_skin)

	controller.queue_free()

	print("\n==========================================")
	print("[PASS] HUB3D PILOT FRONT/BACK ORIENTATION VERIFIED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)
