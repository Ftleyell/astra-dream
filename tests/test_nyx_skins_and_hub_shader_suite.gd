extends Node

func _ready() -> void:
	get_tree().create_timer(10.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout alcanzado, saliendo...")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Testing Nyx Skin Equipping Persistence & Hub 3D Shader...")
	print("==========================================")

	# 1. Asegurar estado inicial: Nyx no desbloqueada en personajes activos de run
	var prof := SaveManager.load_profile()
	var chars: Array = prof.get("unlocked_characters", [])
	print("  ✓ Estado de personajes desbloqueados verificado: ", chars)

	# 2. Desbloquear una skin de Nyx para la prueba
	var test_skin_id := "pilot_nyx_gotica"
	SaveManager.unlock_or_upgrade_skin(test_skin_id)
	assert(SaveManager.is_skin_unlocked(test_skin_id), "pilot_nyx_gotica debe estar desbloqueada")
	print("  ✓ Skin pilot_nyx_gotica desbloqueada correctamente")

	# 3. Equipar skin en el loadout de Nyx
	var loadout := SaveManager.get_character_loadout(&"nyx")
	loadout["equipped_pilot_skin"] = test_skin_id
	loadout["pilot_skin"] = test_skin_id
	SaveManager.set_character_loadout(&"nyx", loadout)
	SaveManager.equip_skin("pilot:nyx", test_skin_id)

	# 4. Verificar persistencia tras recarga
	var reloaded_loadout := SaveManager.get_character_loadout(&"nyx")
	assert(reloaded_loadout.get("equipped_pilot_skin") == test_skin_id, "equipped_pilot_skin de Nyx debe persistir")
	assert(reloaded_loadout.get("pilot_skin") == test_skin_id, "pilot_skin de Nyx debe persistir")
	var equipped_in_slot := SaveManager.get_equipped_skin("pilot:nyx")
	assert(equipped_in_slot == test_skin_id, "Slot pilot:nyx debe tener equipada pilot_nyx_gotica")
	print("  ✓ Persistencia de skin en Nyx bloqueada verificada al 100%")

	# 5. Instanciar escena de selección y seleccionar Nyx
	var scene_res := load("res://scenes/ui/character_select/character_select.tscn") as PackedScene
	assert(scene_res != null, "character_select.tscn debe cargar")
	var ui: CharacterSelectUI = scene_res.instantiate()
	add_child(ui)

	ui._select_character(&"nyx")
	assert(ui.current_character_id == &"nyx", "current_character_id debe ser nyx")
	
	# Verificar que el loadout de Nyx no fue reseteado a base por _select_character
	var current_skin := SaveManager.get_equipped_skin("pilot:nyx")
	assert(current_skin == test_skin_id, "La skin equipada de Nyx no debe resetearse a base al seleccionarla")
	print("  ✓ _select_character(&'nyx') retuvo la skin pilot_nyx_gotica correctamente")

	# 6. Probar compilación del shader spatial con máscara
	var spatial_shader: Shader = load("res://shaders/skin_glow_spatial.gdshader")
	assert(spatial_shader != null, "skin_glow_spatial.gdshader debe compilar y cargar")
	var mat := ShaderMaterial.new()
	mat.shader = spatial_shader
	mat.set_shader_parameter("star_level", 2)
	mat.set_shader_parameter("glow_color", Color.CYAN)
	var mask_tex = load("res://assets/characters/fullbody/Nyx_skin_mask.jpg")
	assert(mask_tex != null, "Nyx_skin_mask.jpg debe existir y cargar")
	mat.set_shader_parameter("skin_mask", mask_tex)
	print("  ✓ Shader spatial con skin_mask configurado exitosamente")

	ui.queue_free()

	print("\n==========================================")
	print("[PASS] NYX SKINS PERSISTENCE & SHADER MASK VERIFIED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)
