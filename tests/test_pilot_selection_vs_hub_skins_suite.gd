extends Node

func _assert_check(cond: bool, msg: String) -> void:
	if not cond:
		printerr("[FAIL] Assertion failed: " + msg)
		get_tree().quit(1)
		assert(false, msg)

func _ready() -> void:
	print("\n==========================================")
	print("[TEST] Testing Pilot Selection Splash vs Hub 3D Fullbody Separation...")
	print("==========================================")

	var pilot_ids: Array[StringName] = [&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo", &"nyx"]

	# 1. Verificar existencia de ambos sets de texturas (selection y fullbody) en la base de datos de cosméticos
	for pid in pilot_ids:
		var skin_id := "pilot_%s_crimson_void" % String(pid).to_lower()
		var skin_data := CosmeticsManager.get_skin(skin_id)
		_assert_check(not skin_data.is_empty(), "Skin no encontrada: %s" % skin_id)

		var sel_path: String = skin_data.get("selection_texture_path", "")
		var fb_path: String = skin_data.get("texture_path", "")
		var back_path: String = skin_data.get("back_texture_path", "")

		_assert_check(not sel_path.is_empty(), "selection_texture_path no debe estar vacía para %s" % skin_id)
		_assert_check(not fb_path.is_empty(), "texture_path no debe estar vacía para %s" % skin_id)
		_assert_check(not back_path.is_empty(), "back_texture_path no debe estar vacía para %s" % skin_id)

		_assert_check(ResourceLoader.exists(sel_path), "Archivo de splash de selección no existe: %s" % sel_path)
		_assert_check(ResourceLoader.exists(fb_path), "Archivo de fullbody hub no existe: %s" % fb_path)
		_assert_check(ResourceLoader.exists(back_path), "Archivo de back hub no existe: %s" % back_path)

		_assert_check(sel_path != fb_path, "La ruta de selección y la de fullbody deben ser distintas para %s" % skin_id)
		print("  ✓ %s: selection_path ('%s') != fullbody_path ('%s')" % [pid, sel_path.get_file(), fb_path.get_file()])

	# 2. Instanciar CharacterSelect y verificar que muestra splash de selección con y sin skin
	var cs_scene := load("res://scenes/ui/character_select/character_select.tscn") as PackedScene
	_assert_check(cs_scene != null, "character_select.tscn debe cargar")
	var cs := cs_scene.instantiate()
	add_child(cs)

	var fullbody_tex_rect: TextureRect = cs.fullbody_texture
	_assert_check(fullbody_tex_rect != null, "FullbodyTexture node debe existir en CharacterSelect")

	# Probar con Valentina (caso crítico donde fullbody tiene piernas y splash es 3/4)
	var test_slot := "pilot:valentina"
	var prev_skin := SaveManager.get_equipped_skin(test_slot)

	# 2a. Valentina SIN skin (base): debe mostrar selection_valentina
	SaveManager.equip_skin(test_slot, "")
	cs.call("_select_character", &"valentina")
	var base_tex_path: String = fullbody_tex_rect.texture.resource_path
	_assert_check(base_tex_path.find("selection_valentina") != -1, "Valentina base en selección debe usar asset de selección (actual: %s)" % base_tex_path)
	_assert_check(base_tex_path.find("fullbody_valentina") == -1, "Valentina base en selección NO debe usar asset de fullbody")
	print("  ✓ Valentina base en Selección muestra asset de selección: %s" % base_tex_path.get_file())

	# 2b. Valentina CON skin equipada: debe mostrar selection_valentina_crimson_void
	var test_skin_id := "pilot_valentina_crimson_void"
	SaveManager.equip_skin(test_slot, test_skin_id)
	cs.call("_select_character", &"valentina")
	var equipped_tex_path: String = fullbody_tex_rect.texture.resource_path
	_assert_check(equipped_tex_path.find("selection_valentina_crimson_void") != -1, "Valentina con skin debe usar splash recolor de selección (actual: %s)" % equipped_tex_path)
	_assert_check(equipped_tex_path.find("fullbody_valentina_crimson_void") == -1, "Valentina con skin NO debe usar fullbody en pantalla de selección")
	print("  ✓ Valentina con skin en Selección muestra splash recolor: %s" % equipped_tex_path.get_file())

	# 3. Verificar que en el Hub 3D se usa el fullbody (frente y espalda), NO el splash de selección
	var hub_controller := HubPlayerController3D.new()
	var spr := Sprite3D.new()
	spr.name = "Sprite3D"
	hub_controller.add_child(spr)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	hub_controller.add_child(cam)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	hub_controller.add_child(col)
	add_child(hub_controller)
	hub_controller.visual_sprite = spr
	hub_controller.set_character(&"valentina")

	# Frente
	hub_controller._is_facing_back = false
	hub_controller._update_character_texture()
	var hub_front_path: String = hub_controller.visual_sprite.texture.resource_path
	_assert_check(hub_front_path.find("fullbody_valentina_crimson_void.png") != -1, "Hub3D de frente debe usar fullbody recolor (actual: %s)" % hub_front_path)
	_assert_check(hub_front_path.find("selection_") == -1, "Hub3D NO debe usar splash de selección")

	# Espalda
	hub_controller._is_facing_back = true
	hub_controller._update_character_texture()
	var hub_back_path: String = hub_controller.visual_sprite.texture.resource_path
	_assert_check(hub_back_path.find("fullbody_valentina_crimson_void_back.png") != -1, "Hub3D de espalda debe usar fullbody back recolor (actual: %s)" % hub_back_path)
	_assert_check(hub_back_path.find("selection_") == -1, "Hub3D de espalda NO debe usar splash de selección")
	print("  ✓ Hub 3D usa fullbody correctamente de frente (%s) y espalda (%s)" % [hub_front_path.get_file(), hub_back_path.get_file()])

	# Restaurar skin previa
	if not prev_skin.is_empty():
		SaveManager.equip_skin(test_slot, prev_skin)
	else:
		SaveManager.equip_skin(test_slot, "")

	print("\n==========================================")
	print("[PASS] ALL SELECTION VS HUB 3D SKIN TESTS PASSED!")
	print("==========================================\n")
	get_tree().quit(0)
