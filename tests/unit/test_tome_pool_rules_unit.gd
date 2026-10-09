class_name TestTomePoolRulesUnit
extends BaseTestSuite

## TestTomePoolRulesUnit
## Micro-test síncrono puro (< 0.1s) para validar las reglas de mínimo obligatorio (6 tomos),
## toggles, conteos y persistencia de tomos arcanos sin UI.

const TomePoolDataControllerClass = preload("res://scenes/ui/character_select/components/tome_pool_data_controller.gd")
const TomeCatalog = preload("res://data/tomes/tome_catalog.gd")

func _ready() -> void:
	super._ready()
	_run_unit_tests()

func _run_unit_tests() -> void:
	var ctrl: TomePoolDataController = TomePoolDataControllerClass.new()
	assert_true(ctrl != null, "Controlador de tomos debe instanciarse")

	var char_id: StringName = &"test_pilot"
	ctrl.initialize(char_id, 6)

	var total_tomes: int = ctrl.get_total_count()
	assert_true(total_tomes >= 6, "El catálogo debe tener al menos 6 tomos (tiene %d)" % total_tomes)
	assert_true(ctrl.get_active_count() == total_tomes, "Por defecto todos los tomos inician activos")

	# Probar desactivar tomos hasta llegar al mínimo de 6
	var all_ids: Array[StringName] = TomeCatalog.ALL_TOME_IDS.duplicate()
	var can_deactivate_count: int = total_tomes - 6

	for i in range(can_deactivate_count):
		var tid: StringName = all_ids[i]
		var ok: bool = ctrl.toggle_tome(tid)
		assert_true(ok, "Debería poder desactivar el tomo %s (quedan %d activos)" % [str(tid), ctrl.get_active_count()])
		assert_true(not ctrl.is_tome_active(tid), "El tomo %s no debe estar activo" % str(tid))

	assert_true(ctrl.get_active_count() == 6, "Deben quedar exactamente 6 tomos activos")
	assert_true(not ctrl.can_deactivate_tome(), "can_deactivate_tome() debe ser falso con 6 tomos")

	# Intentar desactivar el 7mo tomo (debe fallar la regla de mínimo 6)
	var restricted_id: StringName = all_ids[can_deactivate_count]
	var fail_toggle: bool = ctrl.toggle_tome(restricted_id)
	assert_true(not fail_toggle, "No debe permitir desactivar por debajo del mínimo de 6 tomos")
	assert_true(ctrl.is_tome_active(restricted_id), "El tomo no debe haberse desactivado")
	assert_true(ctrl.get_active_count() == 6, "El conteo debe permanecer en 6")

	# Reactivar uno de los desactivados
	var reactivate_id: StringName = all_ids[0]
	var reactivate_ok: bool = ctrl.toggle_tome(reactivate_id)
	assert_true(reactivate_ok, "Reactivar tomo debe tener éxito")
	assert_true(ctrl.is_tome_active(reactivate_id), "El tomo reactivado debe figurar activo")
	assert_true(ctrl.get_active_count() == 7, "Ahora debe haber 7 tomos activos")

	# Reset a default
	ctrl.reset_to_default()
	assert_true(ctrl.get_active_count() == total_tomes, "Reset debe volver a activar todos los tomos")

	# Limpiar persistencia del piloto de prueba
	if SaveManager.has_method("set_character_active_tomes"):
		SaveManager.set_character_active_tomes(char_id, TomeCatalog.ALL_TOME_IDS.duplicate())

	pass_suite("TestTomePoolRulesUnit completado con éxito.")
