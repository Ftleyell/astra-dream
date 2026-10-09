class_name TestWeaponPoolRulesUnit
extends BaseTestSuite

## TestWeaponPoolRulesUnit
## Micro-test síncrono ultra-rápido (< 1.5s) que valida las reglas de WeaponPoolDataController
## sin instanciar la UI ni depender del árbol de escena.

const WeaponPoolDataControllerClass = preload("res://scenes/ui/character_select/components/weapon_pool_data_controller.gd")
const WeaponCatalog = preload("res://data/weapons/weapon_catalog.gd")


func _ready() -> void:
	super._ready()
	test_weapon_pool_rules()
	pass_suite("TestWeaponPoolRulesUnit passed")


func test_weapon_pool_rules() -> void:
	var ctrl := WeaponPoolDataControllerClass.new()
	ctrl.initialize(&"test_pilot", 8)

	assert_true(ctrl.get_total_count() == 11, "Debe haber 11 armas en total en el catálogo del arsenal")
	assert_true(ctrl.get_active_count() == 11, "Todas las armas deben arrancar activas si no había save")

	# Desactivar armas una a una
	var success1: bool = ctrl.toggle_weapon(&"plasma_flak")
	assert_true(success1, "plasma_flak debe poder desactivarse")
	assert_true(not ctrl.is_weapon_active(&"plasma_flak"), "plasma_flak no debe estar activa")
	assert_true(ctrl.get_active_count() == 10, "Deben quedar 10 activas")

	var success2: bool = ctrl.toggle_weapon(&"scatter_laser")
	var success3: bool = ctrl.toggle_weapon(&"singularity_cannon")
	assert_true(success2 and success3, "scatter_laser y singularity_cannon deben poder desactivarse")
	assert_true(ctrl.get_active_count() == 8, "Debe quedar exactamente el mínimo de 8 armas activas")

	# Intentar desactivar una 4ta arma por debajo del mínimo de 8
	var underflow_attempt: bool = ctrl.toggle_weapon(&"solar_flare")
	assert_true(not underflow_attempt, "toggle_weapon debe fallar al intentar bajar de 8 armas")
	assert_true(ctrl.is_weapon_active(&"solar_flare"), "solar_flare debe seguir activa")
	assert_true(ctrl.get_active_count() == 8, "El conteo debe permanecer en 8")

	# Reactivar un arma
	var reactivate: bool = ctrl.toggle_weapon(&"plasma_flak")
	assert_true(reactivate, "Reactivar arma existente debe retornar true")
	assert_true(ctrl.is_weapon_active(&"plasma_flak"), "plasma_flak debe volver a estar activa")
	assert_true(ctrl.get_active_count() == 9, "El conteo debe subir a 9")

	# Resetear
	ctrl.reset_to_default()
	assert_true(ctrl.get_active_count() == 11, "Reset debe restaurar las 11 armas")
