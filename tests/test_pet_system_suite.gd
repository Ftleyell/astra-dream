extends Node

const PetDataScript := preload("res://data/pets/pet_data.gd")
const CompanionPetScript := preload("res://scenes/combat/pets/companion_pet.gd")
const HubPetRoamerScript := preload("res://scenes/ui/hub/hub_pet_roamer.gd")
const PetSelectionModalScript := preload("res://scenes/ui/character_select/pet_selection_modal.gd")
const CharacterSelectUIScript := preload("res://scenes/ui/character_select/character_select.gd")
const DebugMenuModalScript := preload("res://scenes/ui/debug/debug_menu_modal.gd")

func _ready() -> void:
	print("\n=======================================================")
	print("🐾 EJECUTANDO TEST SUITE: SISTEMA DE MASCOTAS / PETS")
	print("=======================================================\n")

	test_pet_roster_and_resources()
	test_save_manager_pet_persistence()
	test_companion_pet_combat_instance()
	test_hub_pet_roamer_3d()
	test_pet_selection_modal_ui()
	test_character_select_pet_card()
	test_debug_menu_pet_actions()

	print("\n=======================================================")
	print("🎉 TODOS LOS TESTS DEL SISTEMA DE MASCOTAS PASARON EXITOSAMENTE!")
	print("=======================================================\n")
	get_tree().quit(0)

func test_assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("❌ FALLO EN TEST: %s" % message)
		printerr("❌ FALLO EN TEST: %s" % message)
		assert(condition, message)
	else:
		print("  ✓ %s" % message)

# ── 1. ROSTER Y RECURSOS DE MASCOTAS ─────────────────────────────────────────
func test_pet_roster_and_resources() -> void:
	print("[1/7] Verificando Roster y Recursos de Mascotas...")
	var roster := PetDataScript.load_roster()
	test_assert(roster.size() == 5, "El roster debe tener exactamente 5 mascotas (actual: %d)" % roster.size())
	test_assert(roster.has(&"mochi"), "Debe existir Mochi en el roster")
	test_assert(roster.has(&"kuro"), "Debe existir Kuro en el roster")
	test_assert(roster.has(&"luna"), "Debe existir Luna en el roster")
	test_assert(roster.has(&"pip"), "Debe existir Pip en el roster")
	test_assert(roster.has(&"cosmo"), "Debe existir Cosmo (secreto) en el roster")

	for pid in roster.keys():
		var p = roster[pid]
		test_assert(p != null, "El recurso de la mascota %s no debe ser nulo" % str(pid))
		test_assert(not p.display_name.is_empty(), "La mascota %s debe tener display_name" % str(pid))
		test_assert(not p.power_description.is_empty(), "La mascota %s debe tener power_description" % str(pid))
		test_assert(p.icon != null, "La mascota %s debe tener un icono asignado" % str(pid))

# ── 2. PERSISTENCIA EN SAVEMANAGER ───────────────────────────────────────────
func test_save_manager_pet_persistence() -> void:
	print("[2/7] Verificando Persistencia y Estado de Desbloqueo en SaveManager...")
	SaveManager.lock_pet(&"cosmo")
	var unlocked := SaveManager.get_unlocked_pets()
	test_assert(unlocked.has(&"mochi"), "Mochi debe estar desbloqueado por defecto")
	test_assert(unlocked.has(&"kuro"), "Kuro debe estar desbloqueado por defecto")
	test_assert(unlocked.has(&"luna"), "Luna debe estar desbloqueado por defecto")
	test_assert(unlocked.has(&"pip"), "Pip debe estar desbloqueado por defecto")
	test_assert(not unlocked.has(&"cosmo"), "Cosmo debe estar BLOQUEADO por defecto")
	test_assert(not SaveManager.is_pet_unlocked(&"cosmo"), "is_pet_unlocked(cosmo) debe ser false")

	# Selección de mascota
	SaveManager.set_selected_pet(&"kuro")
	test_assert(SaveManager.get_selected_pet() == &"kuro", "set_selected_pet(kuro) debe persistir kuro")

	# Desbloqueo de Cosmo
	var unlocked_now := SaveManager.unlock_pet(&"cosmo")
	test_assert(unlocked_now, "unlock_pet(cosmo) debe retornar true la primera vez")
	test_assert(SaveManager.is_pet_unlocked(&"cosmo"), "is_pet_unlocked(cosmo) debe retornar true tras desbloqueo")

	# Selección de Cosmo
	SaveManager.set_selected_pet(&"cosmo")
	test_assert(SaveManager.get_selected_pet() == &"cosmo", "Cosmo puede seleccionarse cuando está desbloqueado")

	# Bloqueo de Cosmo (debe reasignar si estaba seleccionado)
	SaveManager.lock_pet(&"cosmo")
	test_assert(not SaveManager.is_pet_unlocked(&"cosmo"), "Cosmo debe volver a estar bloqueado")
	test_assert(SaveManager.get_selected_pet() == &"mochi", "Si Cosmo estaba seleccionado al bloquearse, debe volver a mochi")

# ── 3. COMPONENTE DE COMBATE COMPANION PET ────────────────────────────────────
func test_companion_pet_combat_instance() -> void:
	print("[3/7] Verificando CompanionPet en combate (sin hitbox, poderes específicos)...")
	var pet_scene := preload("res://scenes/combat/pets/companion_pet.tscn")
	var pet = pet_scene.instantiate()
	add_child(pet)

	var mochi_data := PetDataScript.get_pet(&"mochi")
	pet.setup(mochi_data, null)

	# Verificar que no es ni tiene CollisionShape2D que bloquee
	var shapes := pet.find_children("*", "CollisionShape2D", true, false)
	test_assert(shapes.is_empty(), "El companion pet no debe tener ningún CollisionShape2D (sin hitbox)")

	# Simular órbita y proceso
	pet._process(0.016)
	test_assert(pet.sprite != null, "CompanionPet debe tener un Sprite2D")
	test_assert(pet.sprite.texture == mochi_data.icon, "CompanionPet debe mostrar la textura de la mascota")

	# Probar Kuro
	var kuro_data := PetDataScript.get_pet(&"kuro")
	pet.setup(kuro_data, null)
	test_assert(pet.pet_data.pet_id == &"kuro", "Debe cambiar a Kuro correctamente")

	# Probar Luna
	var luna_data := PetDataScript.get_pet(&"luna")
	pet.setup(luna_data, null)
	test_assert(pet.pet_data.pet_id == &"luna", "Debe cambiar a Luna correctamente")

	# Probar Pip
	var pip_data := PetDataScript.get_pet(&"pip")
	pet.setup(pip_data, null)
	test_assert(pet.pet_data.pet_id == &"pip", "Debe cambiar a Pip correctamente")

	# Probar Cosmo
	var cosmo_data := PetDataScript.get_pet(&"cosmo")
	pet.setup(cosmo_data, null)
	test_assert(pet.pet_data.pet_id == &"cosmo", "Debe cambiar a Cosmo correctamente")

	pet.queue_free()

# ── 4. MASCOTAS 3D EN EL HUB ──────────────────────────────────────────────────
func test_hub_pet_roamer_3d() -> void:
	print("[4/7] Verificando HubPetRoamer (desplazamiento 3D en el centro del Hangar)...")
	var roamer = HubPetRoamerScript.new()
	add_child(roamer)

	var mochi_data := PetDataScript.get_pet(&"mochi")
	roamer.setup(mochi_data, Vector3(0.0, 0.32, 2.0))

	test_assert(roamer.sprite != null, "HubPetRoamer debe tener un Sprite3D")
	test_assert(roamer.sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Sprite3D debe tener modo Billboard activo para mirar a la cámara")
	test_assert(roamer.shadow != null, "HubPetRoamer debe tener un MeshInstance3D para la sombra")

	# Procesar movimiento
	roamer._process(0.1)
	test_assert(roamer.position.x >= HubPetRoamerScript.CENTER_MIN_X - 1.0 and roamer.position.x <= HubPetRoamerScript.CENTER_MAX_X + 1.0, "La mascota debe permanecer en los límites X del centro del hangar")
	test_assert(roamer.position.z >= HubPetRoamerScript.CENTER_MIN_Z - 1.0 and roamer.position.z <= HubPetRoamerScript.CENTER_MAX_Z + 1.0, "La mascota debe permanecer en los límites Z del centro del hangar")

	roamer.queue_free()

# ── 5. MODAL DE SELECCIÓN DE MASCOTAS ─────────────────────────────────────────
func test_pet_selection_modal_ui() -> void:
	print("[5/7] Verificando PetSelectionModal (ocultar pet secreto hasta desbloquearse)...")
	var modal_scene := preload("res://scenes/ui/character_select/pet_selection_modal.tscn")
	var modal = modal_scene.instantiate()
	add_child(modal)

	# 1. Con Cosmo bloqueado: no debe verse (4 mascotas en lista)
	SaveManager.lock_pet(&"cosmo")
	modal.open_modal()
	test_assert(modal.is_open, "El modal debe estar abierto tras open_modal()")
	test_assert(modal.visible, "El modal debe ser visible")

	var cards_container = modal.get_node_or_null("DimOverlay/CenterContainer/MainPanel/Margin/VBox/Scroll/PetsList")
	test_assert(cards_container != null, "Debe existir el contenedor PetsList")
	test_assert(cards_container.get_child_count() == 4, "Con Cosmo bloqueado, el modal solo debe listar 4 mascotas (Cosmo oculto)")

	modal.close_modal()

	# 2. Con Cosmo desbloqueado: debe verse (5 mascotas en lista)
	SaveManager.unlock_pet(&"cosmo")
	modal.open_modal()
	test_assert(cards_container.get_child_count() == 5, "Con Cosmo desbloqueado, el modal debe listar las 5 mascotas")
	modal.close_modal()

	# Restaurar bloqueo de Cosmo
	SaveManager.lock_pet(&"cosmo")

	test_assert(not modal.is_open, "El modal debe marcarse cerrado tras close_modal()")
	test_assert(not modal.visible, "El modal debe ocultarse")

	modal.queue_free()

# ── 6. PET CARD EN CHARACTER SELECT ───────────────────────────────────────────
func test_character_select_pet_card() -> void:
	print("[6/7] Verificando PetCard en Pantalla de Despliegue (botón grande abajo)...")
	var charsel_scene := preload("res://scenes/ui/character_select/character_select.tscn")
	var charsel = charsel_scene.instantiate()
	add_child(charsel)

	test_assert(charsel.pet_card != null, "Debe existir PetCard en CenterPanel debajo de los botones de acción")
	test_assert(charsel.pet_icon != null, "Debe existir PetIcon grande en PetCard")
	test_assert(charsel.pet_name != null, "Debe existir PetName en PetCard")
	test_assert(charsel.pet_desc != null, "Debe existir PetDesc en PetCard")
	test_assert(charsel.pet_button != null, "Debe existir PetButton interactivo en PetCard")
	test_assert(charsel.pet_selection_modal != null, "Debe existir la instancia de PetSelectionModal en character_select")

	SaveManager.set_selected_pet(&"mochi")
	charsel._refresh_pet_display()
	test_assert(charsel.pet_name.text.find("MOCHI") != -1, "PetName debe incluir 'MOCHI' cuando Mochi está seleccionado")
	test_assert(not charsel.pet_desc.text.is_empty(), "PetDesc debe mostrar la descripción del poder de Mochi")

	SaveManager.set_selected_pet(&"kuro")
	charsel._refresh_pet_display()
	test_assert(charsel.pet_name.text.find("KURO") != -1, "PetName debe incluir 'KURO' cuando Kuro está seleccionado")

	charsel.queue_free()

# ── 7. ACCIONES DE DEBUG PARA MASCOTAS ────────────────────────────────────────
func test_debug_menu_pet_actions() -> void:
	print("[7/7] Verificando Botones de Depuración de Mascotas...")
	var debug_scene := preload("res://scenes/ui/debug/debug_menu_modal.tscn")
	var debug_modal = debug_scene.instantiate()
	add_child(debug_modal)

	test_assert(debug_modal.simulate_10m_btn != null, "Debe existir Simulate10mButton en debug menu")
	test_assert(debug_modal.lock_cosmo_btn != null, "Debe existir LockCosmoButton en debug menu")

	# Probar simular 10m
	SaveManager.lock_pet(&"cosmo")
	test_assert(not SaveManager.is_pet_unlocked(&"cosmo"), "Cosmo debe estar bloqueado")

	debug_modal._on_simulate_10m_pressed()
	test_assert(SaveManager.is_pet_unlocked(&"cosmo"), "Simular 10 min debe desbloquear a Cosmo")

	# Probar re-bloquear Cosmo
	debug_modal._on_lock_cosmo_pressed()
	test_assert(not SaveManager.is_pet_unlocked(&"cosmo"), "Bloquear Cosmo debe bloquearlo de nuevo")

	debug_modal.queue_free()
