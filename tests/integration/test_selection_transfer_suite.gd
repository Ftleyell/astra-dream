class_name TestSelectionTransferSuite
extends BaseTestSuite

## TestSelectionTransferSuite.gd
## Valida la transferencia y sincronización de elecciones de:
## - Mascotas (Pet)
## - Navegadoras (Navigator)
## - Aspectos Cosméticos (Skins de Nave, Arma, Piloto, Mascota, Navegadora)
## hacia CharacterSelectUI, SaveManager y los sistemas de combate en ejecución (MainGame).

func _ready() -> void:
	super._ready()
	call_deferred("run_tests")


func run_tests() -> void:
	print("--- TEST SUITE: SELECTION & SKIN TRANSFER ---")
	_test_pet_modal_selection()
	_test_navigator_modal_selection()
	_test_character_select_loadout_synchronization()
	_test_combat_run_receives_selected_companions_and_skins()
	print("--- ALL SELECTION & SKIN TRANSFER TESTS COMPLETED ---")
	pass_suite("All selection transfer tests passed")


func _test_pet_modal_selection() -> void:
	print("[1/4] Testing Pet modal selection & skin equipment...")
	var pet_modal_scene := load("res://scenes/ui/character_select/pet_selection_modal.tscn") as PackedScene
	var pet_modal = pet_modal_scene.instantiate()
	add_child(pet_modal)

	pet_modal.open_modal()
	assert_true(pet_modal.is_open, "Pet modal debe estar abierto")
	assert_true(pet_modal._pets.size() > 1, "Debe haber más de 1 mascota en el roster")

	# Navegar a la siguiente mascota
	var initial_idx: int = pet_modal.current_index
	pet_modal._cycle_horizontal(1)
	var new_idx: int = pet_modal.current_index
	assert_true(new_idx != initial_idx, "El índice debe haber cambiado")
	var target_pid: StringName = pet_modal._pets[new_idx].pet_id

	var pet_res := {"emitted": false, "pid": &""}
	pet_modal.pet_selected.connect(func(pid: StringName):
		pet_res["emitted"] = true
		pet_res["pid"] = pid
	)

	pet_modal._confirm_and_close()
	assert_true(pet_res["emitted"], "Al confirmar, debe emitirse la señal pet_selected")
	assert_true(pet_res["pid"] == target_pid, "La mascota emitida debe coincidir con la seleccionada en el carrusel")
	assert_true(SaveManager.get_selected_pet() == target_pid, "SaveManager debe retener la mascota seleccionada")

	pet_modal.queue_free()
	print("  ✓ Pet modal selection verified.")


func _test_navigator_modal_selection() -> void:
	print("[2/4] Testing Navigator modal selection & skin equipment...")
	var nav_modal_scene := load("res://scenes/ui/character_select/navigator_selection_modal.tscn") as PackedScene
	var nav_modal = nav_modal_scene.instantiate()
	add_child(nav_modal)

	nav_modal.open_modal()
	assert_true(nav_modal.is_open, "Navigator modal debe estar abierto")
	assert_true(nav_modal._navigators.size() > 1, "Debe haber más de 1 navegadora en el roster")

	var initial_idx: int = nav_modal.current_index
	nav_modal._cycle_horizontal(1)
	var new_idx: int = nav_modal.current_index
	assert_true(new_idx != initial_idx, "El índice debe haber cambiado")
	var target_nid: StringName = nav_modal._navigators[new_idx].navigator_id

	var nav_res := {"emitted": false, "nid": &""}
	nav_modal.navigator_selected.connect(func(nid: StringName):
		nav_res["emitted"] = true
		nav_res["nid"] = nid
	)

	nav_modal._confirm_and_close()
	assert_true(nav_res["emitted"], "Al confirmar, debe emitirse la señal navigator_selected")
	assert_true(nav_res["nid"] == target_nid, "La navegadora emitida debe coincidir")
	assert_true(SaveManager.get_selected_navigator() == target_nid, "SaveManager debe retener la navegadora")

	nav_modal.queue_free()
	print("  ✓ Navigator modal selection verified.")


func _test_character_select_loadout_synchronization() -> void:
	print("[3/4] Testing CharacterSelectUI loadout synchronization...")
	var cs_scene := load("res://scenes/ui/character_select/character_select.tscn") as PackedScene
	var cs = cs_scene.instantiate()
	add_child(cs)

	# Probar cambio de personaje y persistencia de su loadout
	cs._select_character(&"nova")
	assert_true(cs.current_character_id == &"nova", "Personaje actual debe ser Nova")

	# Simular selección de mascota, navegadora y skins para Nova
	cs._on_pet_selected(&"kuro")
	cs._on_navigator_selected(&"vespera")
	cs._on_pet_skin_equipped("pet:kuro", "pet_kuro_cyber")
	cs._on_navigator_skin_equipped("navigator:vespera", "nav_vespera_void")
	cs._on_skin_selected("ship:nova", "ship_nova_plasma")
	cs._on_skin_selected("weapon:nova", "weapon_nova_gold")
	cs._on_skin_selected("pilot:nova", "pilot_nova_stealth")

	var nova_loadout: Dictionary = SaveManager.get_character_loadout(&"nova")
	assert_true(String(nova_loadout.get("selected_pet", "")) == "kuro", "Nova debe tener kuro en su loadout")
	assert_true(String(nova_loadout.get("selected_navigator", "")) == "vespera", "Nova debe tener vespera en su loadout")
	assert_true(String(nova_loadout.get("equipped_pet_skin", "")) == "pet_kuro_cyber", "Nova debe tener skin de pet")
	assert_true(String(nova_loadout.get("equipped_navigator_skin", "")) == "nav_vespera_void", "Nova debe tener skin de navegadora")
	assert_true(String(nova_loadout.get("equipped_ship_skin", "")) == "ship_nova_plasma", "Nova debe tener skin de nave")
	assert_true(String(nova_loadout.get("equipped_weapon_skin", "")) == "weapon_nova_gold", "Nova debe tener skin de arma")
	assert_true(String(nova_loadout.get("equipped_pilot_skin", "")) == "pilot_nova_stealth", "Nova debe tener skin de piloto")

	# Cambiar a Valentina
	cs._select_character(&"valentina")
	cs._on_pet_selected(&"luna")
	cs._on_navigator_selected(&"caelia")
	cs._on_skin_selected("ship:valentina", "ship_valentina_ruby")

	var val_loadout: Dictionary = SaveManager.get_character_loadout(&"valentina")
	assert_true(String(val_loadout.get("selected_pet", "")) == "luna", "Valentina debe tener luna")
	assert_true(String(val_loadout.get("selected_navigator", "")) == "caelia", "Valentina debe tener caelia")
	assert_true(String(val_loadout.get("equipped_ship_skin", "")) == "ship_valentina_ruby", "Valentina debe tener ship_valentina_ruby")

	# Volver a Nova: el loadout debe restaurar a Kuro, Vespera y todas las skins en SaveManager
	cs._select_character(&"nova")
	assert_true(SaveManager.get_selected_pet() == &"kuro", "Al volver a Nova, la mascota activa debe restaurarse a Kuro")
	assert_true(SaveManager.get_selected_navigator() == &"vespera", "Al volver a Nova, la navegadora debe restaurarse a Vespera")
	assert_true(SaveManager.get_equipped_skin("pet:kuro") == "pet_kuro_cyber", "SaveManager pet:kuro skin restored")
	assert_true(SaveManager.get_equipped_skin("navigator:vespera") == "nav_vespera_void", "SaveManager navigator:vespera skin restored")
	assert_true(SaveManager.get_equipped_skin("ship:nova") == "ship_nova_plasma", "SaveManager ship:nova skin restored")
	assert_true(SaveManager.get_equipped_skin("weapon:nova") == "weapon_nova_gold", "SaveManager weapon:nova skin restored")
	assert_true(SaveManager.get_equipped_skin("pilot:nova") == "pilot_nova_stealth", "SaveManager pilot:nova skin restored")

	cs.queue_free()
	print("  ✓ CharacterSelectUI loadout synchronization verified.")


func _test_combat_run_receives_selected_companions_and_skins() -> void:
	print("[4/4] Testing Combat Run initialization with selected companions & skins...")
	SaveManager.set_selected_character(&"nova")
	var nova_loadout: Dictionary = SaveManager.get_character_loadout(&"nova")
	nova_loadout["selected_pet"] = "kuro"
	nova_loadout["selected_navigator"] = "vespera"
	nova_loadout["equipped_pet_skin"] = "pet_kuro_cyber"
	nova_loadout["equipped_navigator_skin"] = "nav_vespera_void"
	SaveManager.set_character_loadout(&"nova", nova_loadout)

	var mg_scene := load("res://scenes/combat/main_game.tscn") as PackedScene
	var mg = mg_scene.instantiate()
	add_child(mg)

	assert_true(is_instance_valid(mg.active_pet), "active_pet debe ser instanciada en MainGame")
	if mg.active_pet and mg.active_pet.pet_data:
		assert_true(mg.active_pet.pet_data.pet_id == &"kuro", "La mascota en combate debe ser Kuro")

	assert_true(is_instance_valid(mg.active_navigator_controller), "NavigatorController debe instanciarse")
	if mg.active_navigator_controller and mg.active_navigator_controller.navigator_data:
		assert_true(mg.active_navigator_controller.navigator_data.navigator_id == &"vespera", "La navegadora en combate debe ser Vespera")

	assert_true(SaveManager.get_equipped_skin("pet:kuro") == "pet_kuro_cyber", "Combat run enforced pet skin")
	assert_true(SaveManager.get_equipped_skin("navigator:vespera") == "nav_vespera_void", "Combat run enforced nav skin")

	mg.queue_free()
	print("  ✓ Combat run companions verification passed.")
