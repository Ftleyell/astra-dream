extends Node

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")

func _ready() -> void:
	# Watchdog timeout
	get_tree().create_timer(15.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout en test de skins de diálogo.")
		get_tree().quit(1)
	)

	print("\n=======================================================")
	print("🧪 VERIFICACIÓN COMPLETA: SKINS Y SHADERS EN DIÁLOGOS (DIALOGIC)")
	print("=======================================================")

	# Asegurar que la base de datos de cosméticos esté cargada fresca
	CosmeticsManager.reload_database()

	# Configurar personaje activo del jugador: Nova y mascota Mochi
	SaveManager.set_selected_character(&"nova")
	SaveManager.set_selected_pet(&"mochi")

	# 1. Test 1★: Recolor limpio, sin material de shader
	print("\n[1/5] Verificando Skin 1★ en Diálogo (Recolor Puro)...")
	var skin_nova := "pilot_nova_crimson_void"
	if not SaveManager.is_skin_unlocked(skin_nova):
		SaveManager.unlock_or_upgrade_skin(skin_nova)
	SaveManager.equip_skin("pilot:nova", skin_nova)
	
	var tl_text := "join nova left\nnova: Hola comandante.\nleave nova\n"
	var tl := DialogicTimeline.new()
	tl.from_text(tl_text)
	var layout = Dialogic.start(tl)
	assert(layout != null, "Dialogic layout no debe ser null")
	await get_tree().create_timer(0.4).timeout

	var portraits_layer = layout.find_child("VN_PortraitLayer", true, false)
	assert(portraits_layer != null, "VN_PortraitLayer debe existir")
	var portraits = portraits_layer.get_node("%Portraits")
	var nova_container = portraits.get_node_or_null("Portrait_nova")
	assert(nova_container != null, "Portrait_nova debe existir")
	var nova_char = nova_container.get_node_or_null("nova")
	assert(nova_char != null, "Nodo nova debe existir dentro del container")
	var def_portrait = nova_char.get_child(0)
	var sprite: Sprite2D = def_portrait.get_node("Portrait")
	assert(sprite != null, "Sprite2D Portrait debe existir")
	
	print("  Textura actual del retrato: ", sprite.texture.resource_path)
	assert(sprite.texture.resource_path.ends_with("portrait_nova_crimson_void.png"), "Debe usar la textura recolor de la skin")
	var stars := SaveManager.get_skin_stars(skin_nova)
	if stars <= 1:
		assert(sprite.material == null, "A 1★ el material debe ser null (recolor limpio)")
	print("  ✓ Skin 1★ reflejada con éxito en el diálogo")

	Dialogic.end_timeline(true)
	await get_tree().process_frame

	# 2. Test 2★ y 3★: Halo pulsante de neón y aura iridiscente
	print("\n[2/5] Verificando Skin 2★/3★ con Efectos de Video/Shader...")
	while SaveManager.get_skin_stars(skin_nova) < 2:
		SaveManager.unlock_or_upgrade_skin(skin_nova)
	
	var stars_2 := SaveManager.get_skin_stars(skin_nova)
	assert(stars_2 >= 2, "Debe tener al menos 2 estrellas")

	layout = Dialogic.start(tl)
	await get_tree().create_timer(0.4).timeout
	portraits_layer = layout.find_child("VN_PortraitLayer", true, false)
	portraits = portraits_layer.get_node("%Portraits")
	nova_container = portraits.get_node_or_null("Portrait_nova")
	nova_char = nova_container.get_node_or_null("nova")
	def_portrait = nova_char.get_child(0)
	sprite = def_portrait.get_node("Portrait")

	assert(sprite.material is ShaderMaterial, "Con >= 2 estrellas debe tener ShaderMaterial asignado")
	var mat := sprite.material as ShaderMaterial
	assert(mat.shader != null, "ShaderMaterial debe tener shader asignado")
	assert(mat.get_shader_parameter("star_level") == stars_2, "Shader debe recibir el star_level correcto")
	assert(mat.get_shader_parameter("glow_color") != null, "glow_color debe estar configurado")
	assert(mat.get_shader_parameter("accent_color") != null, "accent_color debe estar configurado")
	print("  ✓ Shader con efectos de video/glow aplicado correctamente a la skin (★%d)" % stars_2)

	Dialogic.end_timeline(true)
	await get_tree().process_frame

	# 3. Test Flipped Portrait: cuando Dialogic pide retrato Flipped
	print("\n[3/5] Verificando Retrato Flipped con Skin...")
	var tl_flipped_text := "join nova (Flipped) right\nnova: Mirando al otro lado.\nleave nova\n"
	var tl_flip := DialogicTimeline.new()
	tl_flip.from_text(tl_flipped_text)
	layout = Dialogic.start(tl_flip)
	await get_tree().create_timer(0.4).timeout
	portraits_layer = layout.find_child("VN_PortraitLayer", true, false)
	portraits = portraits_layer.get_node("%Portraits")
	nova_container = portraits.get_node_or_null("Portrait_nova")
	nova_char = nova_container.get_node_or_null("nova")
	def_portrait = nova_char.get_child(0)
	sprite = def_portrait.get_node("Portrait")

	print("  Textura flipped del retrato: ", sprite.texture.resource_path)
	assert(sprite.texture.resource_path.ends_with("portrait_nova_crimson_void_flipped.png"), "Debe usar la textura flipped de la skin")
	assert(sprite.material is ShaderMaterial, "El retrato flipped debe conservar el shader de la skin")
	print("  ✓ Retrato Flipped refleja textura y shader correctamente")

	Dialogic.end_timeline(true)
	await get_tree().process_frame

	# 4. Test Mascota Activa: Mochi en diálogo
	print("\n[4/5] Verificando Mascota Activa (Mochi) en Diálogo...")
	var pet_skin := "pet_mochi_cyber_neon"
	if not SaveManager.is_skin_unlocked(pet_skin):
		SaveManager.unlock_or_upgrade_skin(pet_skin)
	SaveManager.equip_skin("pet:mochi", pet_skin)
	
	var tl_pet_text := "join mochi left\nmochi: Miau cósmico.\nleave mochi\n"
	var tl_pet := DialogicTimeline.new()
	tl_pet.from_text(tl_pet_text)
	layout = Dialogic.start(tl_pet)
	await get_tree().create_timer(0.4).timeout
	portraits_layer = layout.find_child("VN_PortraitLayer", true, false)
	portraits = portraits_layer.get_node("%Portraits")
	var mochi_container = portraits.get_node_or_null("Portrait_mochi")
	assert(mochi_container != null, "Portrait_mochi debe existir")
	var mochi_char = mochi_container.get_node_or_null("mochi")
	assert(mochi_char != null, "Nodo mochi debe existir")
	def_portrait = mochi_char.get_child(0)
	sprite = def_portrait.get_node("Portrait")

	print("  Textura de Mochi: ", sprite.texture.resource_path)
	assert(sprite.texture.resource_path.ends_with("pet_mochi_cyber_neon.png"), "Mascota activa debe mostrar su skin equipada")
	print("  ✓ Mascota activa refleja su skin en el diálogo")

	Dialogic.end_timeline(true)
	await get_tree().process_frame

	# 5. Test Personaje no activo / Rival: Nyx debe mantener arte base
	print("\n[5/5] Verificando que personajes no activos (Nyx) conserven arte base...")
	SaveManager.unlock_or_upgrade_skin("pilot_nyx_solar_gold")
	SaveManager.equip_skin("pilot:nyx", "pilot_nyx_solar_gold")

	var tl_rival_text := "join nyx right\nnyx: Soy el rival.\nleave nyx\n"
	var tl_rival := DialogicTimeline.new()
	tl_rival.from_text(tl_rival_text)
	layout = Dialogic.start(tl_rival)
	await get_tree().create_timer(0.4).timeout
	portraits_layer = layout.find_child("VN_PortraitLayer", true, false)
	portraits = portraits_layer.get_node("%Portraits")
	var nyx_container = portraits.get_node_or_null("Portrait_nyx")
	assert(nyx_container != null, "Portrait_nyx debe existir")
	var nyx_char = nyx_container.get_node_or_null("nyx")
	assert(nyx_char != null, "Nodo nyx debe existir")
	def_portrait = nyx_char.get_child(0)
	sprite = def_portrait.get_node("Portrait")

	print("  Textura de Nyx (rival): ", sprite.texture.resource_path)
	assert(not sprite.texture.resource_path.contains("recolors"), "Nyx debe usar su textura base de historia, no recolors")
	assert(sprite.material == null, "Nyx no debe tener shader de skin")
	print("  ✓ Personajes rivales y NPCs conservan su arte base estricto")

	Dialogic.end_timeline(true)
	await get_tree().process_frame

	# Limpiar
	SaveManager.unequip_skin("pilot:nova")
	SaveManager.unequip_skin("pet:mochi")
	SaveManager.unequip_skin("pilot:nyx")

	print("\n=======================================================")
	print("✅ TODOS LOS TESTS DE SKINS EN DIÁLOGOS PASARON CON ÉXITO")
	print("=======================================================\n")
	get_tree().quit(0)
