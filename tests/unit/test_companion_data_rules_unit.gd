class_name TestCompanionDataRulesUnit
extends BaseTestSuite

## TestCompanionDataRulesUnit
## Micro-test síncrono ultra-rápido (< 1.5s) que valida las reglas de
## NavigatorDataController y PetDataController sin instanciar UI compleja ni nodos pesados.

const NavigatorDataControllerClass = preload("res://scenes/ui/character_select/components/navigator_data_controller.gd")
const PetDataControllerClass = preload("res://scenes/ui/character_select/components/pet_data_controller.gd")


func _ready() -> void:
	super._ready()
	test_navigator_data_controller()
	test_pet_data_controller()
	pass_suite("TestCompanionDataRulesUnit passed")


func test_navigator_data_controller() -> void:
	var ctrl := NavigatorDataControllerClass.new()
	ctrl.load_roster()

	assert_true(ctrl.navigators.size() == 5, "Debe cargar 5 navegantes en el roster")
	assert_true(ctrl.get_current_navigator() != null, "Debe haber una navegante seleccionada actualmente")
	assert_true(ctrl.available_skins.size() >= 1, "Debe existir al menos el skin base (slot 0)")
	assert_true(ctrl.get_current_skin().get("is_base", false) == true, "Slot 0 debe ser skin base")

	# Ciclo horizontal
	var start_idx: int = ctrl.current_index
	var next_idx: int = ctrl.cycle_horizontal(1)
	assert_true(next_idx == (start_idx + 1) % 5, "cycle_horizontal(1) debe avanzar")
	ctrl.cycle_horizontal(-1)
	assert_true(ctrl.current_index == start_idx, "cycle_horizontal(-1) debe retroceder")

	# Ciclo vertical de skins
	if ctrl.available_skins.size() > 1:
		ctrl.cycle_vertical(1)
		assert_true(ctrl.skin_index == 1, "cycle_vertical(1) debe pasar al skin alternativo")
		ctrl.cycle_vertical(-1)
		assert_true(ctrl.skin_index == 0, "cycle_vertical(-1) debe retornar al skin base")

	# Confirmar selección sobre Lyra (desbloqueada por defecto)
	for i in range(ctrl.navigators.size()):
		if ctrl.navigators[i].navigator_id == &"lyra":
			ctrl.set_index(i)
			break
	var result: Dictionary = ctrl.confirm_selection()
	assert_true(result.get("success", false), "confirm_selection debe ser exitosa para Lyra")
	assert_true(result.get("navigator_id", &"") == &"lyra", "navigator_id confirmado debe ser Lyra")
	assert_true(SaveManager.get_selected_navigator() == &"lyra", "SaveManager debe guardar Lyra")


func test_pet_data_controller() -> void:
	var ctrl := PetDataControllerClass.new()
	ctrl.load_roster()

	assert_true(ctrl.pets.size() == 5, "Debe cargar 5 mascotas en el roster")
	assert_true(ctrl.get_current_pet() != null, "Debe haber una mascota seleccionada actualmente")
	assert_true(ctrl.available_skins.size() >= 1, "Debe existir al menos el skin base (slot 0)")
	assert_true(ctrl.get_current_skin().get("is_base", false) == true, "Slot 0 debe ser skin base")

	# Ciclo horizontal
	var start_idx: int = ctrl.current_index
	var next_idx: int = ctrl.cycle_horizontal(1)
	assert_true(next_idx == (start_idx + 1) % 5, "cycle_horizontal(1) debe avanzar")
	ctrl.cycle_horizontal(-1)
	assert_true(ctrl.current_index == start_idx, "cycle_horizontal(-1) debe retroceder")

	# Comprobar comportamiento de mascota bloqueada (Cosmo)
	SaveManager.lock_pet(&"cosmo")
	for i in range(ctrl.pets.size()):
		if ctrl.pets[i].pet_id == &"cosmo":
			ctrl.set_index(i)
			break
	assert_true(not ctrl.is_current_unlocked(), "Cosmo debe estar bloqueado")
	var locked_res: Dictionary = ctrl.confirm_selection()
	assert_true(not locked_res.get("success", false), "No se debe poder confirmar selección de mascota bloqueada")

	# Desbloqueo y confirmación
	SaveManager.unlock_pet(&"cosmo")
	assert_true(ctrl.is_current_unlocked(), "Cosmo debe estar desbloqueado ahora")
	var unlocked_res: Dictionary = ctrl.confirm_selection()
	assert_true(unlocked_res.get("success", false), "confirm_selection debe funcionar con mascota desbloqueada")
	assert_true(SaveManager.get_selected_pet() == &"cosmo", "SaveManager debe guardar Cosmo como seleccionado")
