extends Node

const SlotBeaconScript := preload("res://scenes/combat/satellite/slot_machine_beacon.gd")
const SlotChestScript := preload("res://scenes/combat/satellite/slot_machine_chest.gd")
const InRunSlotModalScript := preload("res://scenes/ui/modals/in_run_slot_machine_modal.gd")
const SlotRewardModalScript := preload("res://scenes/ui/modals/slot_machine_reward_modal.gd")
const GachaModalScript := preload("res://scenes/ui/gacha/gacha_modal.gd")
const PlayerScript := preload("res://scenes/combat/player/player.gd")
const CosmeticsManager := preload("res://core/systems/cosmetics_manager.gd")

func _ready() -> void:
	print("\n=======================================================")
	print("🎰 EJECUTANDO TEST SUITE: SLOTS IN-RUN & GACHA DEL HUB")
	print("=======================================================\n")

	test_cosmetics_database_and_manager()
	test_save_manager_gacha_and_skin_progression()
	test_in_run_slot_beacon_and_cost_scaling()
	test_in_run_slot_modal_payouts()
	test_slot_chest_and_item_reward_modal()
	test_hub_gacha_modal_and_pulls()
	test_cosmetics_canvas_item_and_shader_application()
	test_character_select_skin_buttons_and_modal()


	print("\n=======================================================")
	print("🎉 TODOS LOS TESTS DE SLOTS & GACHA PASARON EXITOSAMENTE!")
	print("=======================================================\n")
	get_tree().quit(0)

func test_assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("❌ FALLO EN TEST: %s" % message)
		printerr("❌ FALLO EN TEST: %s" % message)
		assert(condition, message)
	else:
		print("  ✓ %s" % message)

# ── 1. COSMETICS DATABASE & MANAGER ──────────────────────────────────────────
func test_cosmetics_database_and_manager() -> void:
	print("[1/7] Verificando Base de Datos de Cosméticos y CosmeticsManager...")
	var db: Dictionary = CosmeticsManager.load_database()
	test_assert(not db.is_empty(), "La base de datos de cosméticos no debe estar vacía")
	
	var skins: Dictionary = CosmeticsManager.get_all_skins()
	test_assert(skins.size() >= 100, "Debe haber al menos 100 skins generadas (actual: %d)" % skins.size())
	
	var ship_skins: Array[Dictionary] = CosmeticsManager.get_skins_by_category("ship")
	var pilot_skins: Array[Dictionary] = CosmeticsManager.get_skins_by_category("pilot")
	var pet_skins: Array[Dictionary] = CosmeticsManager.get_skins_by_category("pet")
	var nav_skins: Array[Dictionary] = CosmeticsManager.get_skins_by_category("navigator")
	var weapon_skins: Array[Dictionary] = CosmeticsManager.get_skins_by_category("weapon")

	test_assert(ship_skins.size() > 0, "Debe haber skins para naves (actual: %d)" % ship_skins.size())
	test_assert(pilot_skins.size() > 0, "Debe haber skins para pilotos (actual: %d)" % pilot_skins.size())
	test_assert(pet_skins.size() > 0, "Debe haber skins para mascotas (actual: %d)" % pet_skins.size())
	test_assert(nav_skins.size() > 0, "Debe haber skins para navegantes (actual: %d)" % nav_skins.size())
	test_assert(weapon_skins.size() > 0, "Debe haber skins para armas (actual: %d)" % weapon_skins.size())

	var random_skin: Dictionary = CosmeticsManager.roll_random_skin()
	test_assert(not random_skin.is_empty(), "roll_random_skin debe devolver una skin válida")
	test_assert(random_skin.has("id") and random_skin.has("skin_name"), "Skin debe tener id y skin_name")

# ── 2. PERSISTENCIA EN SAVEMANAGER Y PROGRESIÓN 1★ -> 2★ -> 3★ ─────────────
func test_save_manager_gacha_and_skin_progression() -> void:
	print("[2/7] Verificando Persistencia de Gacha Tokens y Progresión de Estrellas...")
	var current_tok := SaveManager.get_gacha_tokens()
	SaveManager.add_gacha_tokens(10)
	test_assert(SaveManager.get_gacha_tokens() == current_tok + 10, "add_gacha_tokens(10) debe sumar 10 tokens")

	var spend_success := SaveManager.spend_gacha_tokens(5)
	test_assert(spend_success, "spend_gacha_tokens(5) debe ser exitoso")
	
	var spend_fail := SaveManager.spend_gacha_tokens(999999)
	test_assert(not spend_fail, "spend_gacha_tokens con cantidad excesiva debe fallar")

	# Progresión de Estrellas
	var test_skin_id := "ship_nova_crimson_void"
	
	# 1st pull: Desbloqueo a 1★
	var res1 := SaveManager.unlock_or_upgrade_skin(test_skin_id)
	test_assert(res1.status == "new" or res1.status == "upgraded" or res1.status == "max_converted", "Primer pull retorna estado válido")
	test_assert(SaveManager.get_skin_stars(test_skin_id) >= 1, "SaveManager debe registrar al menos 1★")

	# Subir a 2★
	var res2 := SaveManager.unlock_or_upgrade_skin(test_skin_id)
	test_assert(SaveManager.get_skin_stars(test_skin_id) >= 2, "SaveManager debe registrar al menos 2★")

	# Subir a 3★ (Máximo)
	var res3 := SaveManager.unlock_or_upgrade_skin(test_skin_id)
	test_assert(SaveManager.get_skin_stars(test_skin_id) == 3, "SaveManager debe registrar 3★")

	# Pull duplicado en 3★ -> Conversión a 150 Biomasa
	var bio_before := SaveManager.get_biomass()
	var res4 := SaveManager.unlock_or_upgrade_skin(test_skin_id)
	test_assert(res4.status == "max_converted" and res4.biomass_awarded == 150, "Duplicado en 3★ otorga 150 de Biomasa")
	test_assert(SaveManager.get_biomass() == bio_before + 150, "Biomasa sumada correctamente en SaveManager")

	# Equipamiento
	SaveManager.equip_skin("ship:nova", test_skin_id)
	test_assert(SaveManager.get_equipped_skin("ship:nova") == test_skin_id, "Debe equipar la skin para ship:nova")

# ── 3. TRAGAMONEDAS IN-RUN (BEACON & ESCALADO) ──────────────────────────────
func test_in_run_slot_beacon_and_cost_scaling() -> void:
	print("[3/7] Verificando Tragamonedas In-Run (SlotMachineBeacon y Costos)...")
	var beacon = SlotBeaconScript.new()
	beacon.current_spin_cost = 50
	beacon.remaining_uses = 3
	
	test_assert(beacon.get_current_cost() == 50, "Costo inicial debe ser 50")
	test_assert(beacon.has_uses_remaining() == true, "Debe tener usos restantes")
	
	beacon.record_use()
	test_assert(beacon.get_current_cost() == 75, "Segundo uso debe costar 75 (+25)")
	test_assert(beacon.remaining_uses == 2, "Deben quedar 2 usos")

	beacon.record_use()
	test_assert(beacon.get_current_cost() == 100, "Tercer uso debe costar 100 (+25)")
	
	beacon.record_use()
	test_assert(beacon.remaining_uses == 0, "Deben quedar 0 usos")
	test_assert(beacon.has_uses_remaining() == false, "No deben quedar usos")
	
	var signal_data := { "emitted": false, "pos": Vector2.ZERO }
	beacon.exploded.connect(func(pos: Vector2):
		signal_data["emitted"] = true
		signal_data["pos"] = pos
	)
	
	var expected_pos := Vector2(250, 400)
	beacon.position = expected_pos
	beacon.trigger_explosion()
	print("  DEBUG EXPLOSION: emitted=", signal_data["emitted"], " pos=", signal_data["pos"])
	test_assert(signal_data["emitted"] and signal_data["pos"] == expected_pos, "trigger_explosion debe emitir señal exploded con la posición")

# ── 4. LOGICA DE PAGOS DEL MODAL DE SLOTS ────────────────────────────────────
func test_in_run_slot_modal_payouts() -> void:
	print("[4/7] Verificando Cálculo de Pagos del Modal de Tragamonedas...")
	var modal = InRunSlotModalScript.new()
	
	# Test 3x Jackpot
	var payout_jackpot := modal.evaluate_payout(["gold", "gold", "gold"], 50)
	test_assert(payout_jackpot.type == "jackpot" and payout_jackpot.credits == 250, "3x ORO debe ser Jackpot de 250 créditos")

	# Test 3x Bomba
	var payout_bomb := modal.evaluate_payout(["bomb", "bomb", "bomb"], 50)
	test_assert(payout_bomb.type == "bomb" and payout_bomb.bombs == 2, "3x BOMBA debe otorgar 2 bombas")

	# Test 3x Imán
	var payout_magnet := modal.evaluate_payout(["magnet", "magnet", "magnet"], 50)
	test_assert(payout_magnet.type == "magnet" and payout_magnet.magnet == true, "3x IMÁN debe otorgar atracción global")

	# Test 3x Corazón
	var payout_heal := modal.evaluate_payout(["heart", "heart", "heart"], 50)
	test_assert(payout_heal.type == "heal" and payout_heal.heal == true, "3x CORAZÓN debe curar al 100%")

	# Test Par (Reembolso)
	var payout_pair := modal.evaluate_payout(["gold", "gold", "skull"], 75)
	test_assert(payout_pair.type == "pair" and payout_pair.credits == 75, "2 iguales debe reembolsar el costo del tiro (75)")

	# Test Nada (Miss)
	var payout_miss := modal.evaluate_payout(["gold", "bomb", "skull"], 50)
	test_assert(payout_miss.type == "none" and payout_miss.credits == 0, "3 diferentes sin par debe dar 0 créditos")
	
	modal.free()

# ── 5. COFRE DE RECOMPENSA Y MODAL TOMAR / RECHAZAR ──────────────────────────
func test_slot_chest_and_item_reward_modal() -> void:
	print("[5/7] Verificando Cofre de Tragamonedas y Modal Tomar/Rechazar...")
	var chest = SlotChestScript.new()
	test_assert(is_instance_valid(chest), "SlotChest debe instanciarse correctamente")
	
	var reward_modal = SlotRewardModalScript.new()
	var test_item := ItemData.new()
	test_item.item_id = &"slot_nanite_core"
	test_item.item_name = "Núcleo de Nanitas Tragamonedas"
	test_item.description = "+25% Daño y +10% Regeneración"
	test_item.rarity = Enums.Rarity.EPIC
	
	var dummy_player = PlayerScript.new()
	dummy_player.run_credits = 100
	add_child(chest)
	add_child(reward_modal)
	
	# Test Rechazar -> Otorga +100 créditos
	reward_modal.setup(test_item, dummy_player)
	reward_modal._on_reject_pressed()
	test_assert(dummy_player.run_credits == 200, "Rechazar ítem del cofre debe sumar +100 créditos a la run (actual: %d)" % dummy_player.run_credits)

	# Test Tomar -> Agrega ítem al inventario
	reward_modal.setup(test_item, dummy_player)
	reward_modal._on_take_pressed()
	test_assert(dummy_player.inventory.get_item_count(&"slot_nanite_core") == 1, "Tomar ítem debe agregarlo al inventario del jugador")

	chest.queue_free()
	reward_modal.queue_free()
	dummy_player.free()

# ── 6. GACHA DEL HANGAR (PULLS, BANNER Y ROPERO) ────────────────────────────
func test_hub_gacha_modal_and_pulls() -> void:
	print("[6/8] Verificando Modal de Gacha del Hangar (Pulls x1, x5, x10 y Ropero)...")
	var gacha_modal = GachaModalScript.new()
	add_child(gacha_modal)
	await get_tree().process_frame
	SaveManager.add_gacha_tokens(20)
	var tokens_before := SaveManager.get_gacha_tokens()
	
	# Roll x1
	var single_results := gacha_modal.execute_pulls(1)
	test_assert(single_results.size() == 1, "Tirada x1 debe devolver 1 resultado")
	test_assert(SaveManager.get_gacha_tokens() == tokens_before - 1, "Debe haber consumido 1 token")

	# Roll x5
	var multi_5_results := gacha_modal.execute_pulls(5)
	test_assert(multi_5_results.size() == 5, "Tirada x5 debe devolver 5 resultados")
	test_assert(SaveManager.get_gacha_tokens() == tokens_before - 6, "Debe haber consumido 5 tokens")

	# Roll x10
	var multi_10_results := gacha_modal.execute_pulls(10)
	test_assert(multi_10_results.size() == 10, "Tirada x10 debe devolver 10 resultados")
	test_assert(SaveManager.get_gacha_tokens() == tokens_before - 16, "Debe haber consumido 10 tokens")

	# Intento de Roll sin saldo suficiente
	SaveManager.spend_gacha_tokens(SaveManager.get_gacha_tokens())
	var fail_pulls := gacha_modal.execute_pulls(5)
	test_assert(fail_pulls.is_empty(), "Tirada sin saldo suficiente debe devolver array vacío")

	# Verificación de Armario / Colección, Toggle Ocultar no adquiridos y Desequipar
	gacha_modal._switch_tab(1)
	test_assert(gacha_modal._active_tab == 1, "Debe estar en la pestaña de Armario")
	test_assert(gacha_modal._hide_locked_check != null, "El CheckBox _hide_locked_check debe existir")

	# Desbloquear una skin de prueba
	var test_ship_skin := "ship_nova_crimson_void"
	SaveManager.unlock_or_upgrade_skin(test_ship_skin)
	SaveManager.equip_skin("ship:nova", test_ship_skin)
	test_assert(SaveManager.get_equipped_skin("ship:nova") == test_ship_skin, "Debe estar equipada la skin de prueba")

	# Con toggle inactivo: muestra todas las skins (186)
	gacha_modal._hide_locked = false
	gacha_modal._filter_wardrobe("all")
	var count_all: int = gacha_modal._wardrobe_grid.get_child_count()
	test_assert(count_all >= 180, "Con toggle desactivado deben mostrarse todas las skins en la colección (actual: %d)" % count_all)

	# Con toggle activo: solo muestra desbloqueadas
	gacha_modal._hide_locked = true
	gacha_modal._filter_wardrobe("all")
	var count_unlocked: int = gacha_modal._wardrobe_grid.get_child_count()
	test_assert(count_unlocked <= count_all, "Con toggle activado solo deben mostrarse las desbloqueadas")
	test_assert(count_unlocked >= 1, "Al menos la skin desbloqueada debe ser visible")

	# Probar desequipar
	SaveManager.unequip_skin("ship:nova")
	test_assert(SaveManager.get_equipped_skin("ship:nova").is_empty(), "La skin de ship:nova debe haberse desequipado correctamente")

	gacha_modal.queue_free()
	await get_tree().process_frame

# ── 7. APLICACIÓN DE SHADER Y EFECTOS COSMÉTICOS ─────────────────────────────
func test_cosmetics_canvas_item_and_shader_application() -> void:
	print("[7/8] Verificando Aplicación de Materiales, Shaders y Estrellas en CanvasItems...")
	var test_sprite := Sprite2D.new()
	var test_skin_id := "ship_nova_crimson_void"
	
	# 1★: Solo textura recoloreada, material nulo
	CosmeticsManager.apply_skin_to_canvas_item(test_sprite, test_skin_id, 1)
	test_assert(test_sprite.texture != null, "1★ debe cargar la textura de la skin")
	test_assert(test_sprite.material == null, "1★ no debe tener shader material")

	# 2★: Textura + ShaderMaterial con star_level = 2
	CosmeticsManager.apply_skin_to_canvas_item(test_sprite, test_skin_id, 2)
	test_assert(test_sprite.material is ShaderMaterial, "2★ debe tener ShaderMaterial aplicado")
	var mat2 := test_sprite.material as ShaderMaterial
	test_assert(mat2.get_shader_parameter("star_level") == 2, "Shader parameter star_level debe ser 2")

	# 3★: Textura + ShaderMaterial con star_level = 3
	CosmeticsManager.apply_skin_to_canvas_item(test_sprite, test_skin_id, 3)
	test_assert(test_sprite.material is ShaderMaterial, "3★ debe tener ShaderMaterial aplicado")
	var mat3 := test_sprite.material as ShaderMaterial
	test_assert(mat3.get_shader_parameter("star_level") == 3, "Shader parameter star_level debe ser 3")

	test_sprite.free()

# ── 8. BOTONES DE SKINS EN SELECCIÓN DE PERSONAJES & MODAL COMPACTO ────────────
func test_character_select_skin_buttons_and_modal() -> void:
	print("[8/8] Verificando Botones de Skin en CharacterSelectUI y SkinSelectionModal...")
	var charsel_scene: PackedScene = load("res://scenes/ui/character_select/character_select.tscn")
	var charsel: CharacterSelectUI = charsel_scene.instantiate()
	add_child(charsel)
	await get_tree().process_frame

	# Validar existencia de los botones rápidos de cada sistema
	test_assert(charsel.ship_skin_button != null, "ShipSkinButton debe existir en CharacterSelect")
	test_assert(charsel.weapon_skin_button != null, "WeaponSkinButton debe existir en CharacterSelect")
	test_assert(charsel.pet_skin_button != null, "PetSkinButton debe existir en CharacterSelect")
	test_assert(charsel.navigator_skin_button != null, "NavigatorSkinButton debe existir en CharacterSelect")
	test_assert(charsel.pilot_skin_button != null, "PilotSkinButton debe existir en CharacterSelect")
	test_assert(charsel.skins_button != null, "SkinsButton debe existir en ActionsRow")
	test_assert(charsel.skin_selection_modal != null, "SkinSelectionModal debe estar instanciado en CharacterSelect")

	# Probar apertura del selector de skins para la nave
	charsel._on_ship_skin_pressed()
	await get_tree().process_frame
	test_assert(charsel.skin_selection_modal.is_open == true, "SkinSelectionModal debe abrirse al presionar ShipSkinButton")
	test_assert(charsel.skin_selection_modal.visible == true, "SkinSelectionModal debe estar visible")

	# Equipar una skin de prueba desde el modal
	var test_skin_id := "ship_nova_crimson_void"
	SaveManager.unlock_or_upgrade_skin(test_skin_id)
	SaveManager.unlock_or_upgrade_skin(test_skin_id) # 2 estrellas (Glow)
	charsel.skin_selection_modal._selected_skin_id = test_skin_id
	charsel.skin_selection_modal._on_equip_pressed()
	await get_tree().process_frame

	test_assert(SaveManager.get_equipped_skin("ship:nova") == test_skin_id, "SaveManager debe registrar la skin equipada para ship:nova")
	charsel._select_character(&"nova")
	test_assert(charsel.ship_icon.material is ShaderMaterial, "ship_icon debe tener el shader aplicado para la skin 2★")

	# Probar equipar por defecto (desequipar)
	charsel.skin_selection_modal._on_default_pressed()
	await get_tree().process_frame
	test_assert(SaveManager.get_equipped_skin("ship:nova").is_empty(), "SaveManager no debe tener skin equipada tras _on_default_pressed")
	charsel._select_character(&"nova")
	test_assert(charsel.ship_icon.material == null, "ship_icon debe volver a material nulo tras desequipar")

	# Cerrar modal
	charsel.skin_selection_modal.close_modal()
	test_assert(charsel.skin_selection_modal.is_open == false, "SkinSelectionModal debe cerrarse correctamente")

	charsel.queue_free()
	await get_tree().process_frame

