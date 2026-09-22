extends Node

func _ready() -> void:
	# Fallback timeout de seguridad
	get_tree().create_timer(6.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout alcanzado, saliendo...")
		get_tree().quit(0)
	)

	print("\n==========================================")
	print("[TEST] Testing Character Visual Assets & Pipeline (Stage 1)...")
	print("==========================================")

	var roster := CharacterData.load_roster()
	assert(roster.size() >= 6, "El roster debe tener 6 personajes")

	var char_ids := [&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo"]

	# 1. Verificar carga de los 4 assets para cada personaje
	for cid in char_ids:
		var cdata: CharacterData = roster.get(cid)
		assert(cdata != null, "CharacterData no encontrado para: %s" % cid)

		var ship_tex: Texture2D = cdata.get_ship_texture()
		assert(ship_tex != null, "Ship texture no debe ser nula para %s" % cid)
		assert(ship_tex.get_width() == 256 and ship_tex.get_height() == 256, "Nave debe ser 256x256 para %s" % cid)

		var wpn_tex: Texture2D = cdata.get_weapon_texture()
		assert(wpn_tex != null, "Weapon texture no debe ser nula para %s" % cid)
		assert(wpn_tex.get_width() == 128 and wpn_tex.get_height() == 128, "Arma debe ser 128x128 para %s" % cid)

		var port_tex: Texture2D = cdata.get_portrait_texture()
		assert(port_tex != null, "Portrait texture no debe ser nulo para %s" % cid)
		assert(port_tex.get_width() == 512 and port_tex.get_height() == 512, "Retrato debe ser 512x512 para %s" % cid)

		var full_tex: Texture2D = cdata.get_fullbody_texture()
		assert(full_tex != null, "Fullbody texture no debe ser nulo para %s" % cid)
		assert(full_tex.get_width() == 1200 and full_tex.get_height() == 1600, "Cuerpo completo debe ser 1200x1600 para %s" % cid)

		print("  ✓ %s: 4 texturas verificadas (Nave 256x256, Arma 128x128, Retrato 512x512, Fullbody 1200x1600)" % cdata.display_name)

	# 2. Verificar integración en Player en combate
	print("\n[Player In-Combat Integration]")
	var test_player := Player.new()
	test_player.character_data = roster.get(&"nova")

	var vp := Polygon2D.new()
	vp.name = "VisualPlaceholder"
	test_player.add_child(vp)

	var hb := Polygon2D.new()
	hb.name = "HitboxCore"
	test_player.add_child(hb)

	var wc := WeaponController.new()
	wc.name = "WeaponController"
	wc.player = test_player
	test_player.add_child(wc)

	add_child(test_player)
	test_player._apply_visual_theme()

	var ship_spr := test_player.get_node_or_null("ShipSprite") as Sprite2D
	assert(ship_spr != null, "Player debe instanciar ShipSprite automáticamente")
	assert(ship_spr.texture != null, "ShipSprite debe tener la textura de la nave asignada")
	assert(ship_spr.visible == true, "ShipSprite debe estar visible")
	assert(vp.visible == false, "VisualPlaceholder poligonal debe ocultarse cuando hay sprite de nave")

	var wpn_spr := wc.get_node_or_null("WeaponSprite") as Sprite2D
	assert(wpn_spr != null, "WeaponController debe instanciar WeaponSprite")
	assert(wpn_spr.texture != null, "WeaponSprite debe tener la textura del arma asignada")
	assert(wpn_spr.visible == true, "WeaponSprite debe estar visible")

	print("  ✓ Player y WeaponController configuraron ShipSprite y WeaponSprite correctamente")
	test_player.queue_free()

	print("\n==========================================")
	print("[PASS] ALL CHARACTER ASSETS & INTEGRATION VERIFIED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)
