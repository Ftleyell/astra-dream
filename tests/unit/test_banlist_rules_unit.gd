class_name TestBanlistRulesUnit
extends BaseTestSuite

## TestBanlistRulesUnit
## Micro-test síncrono puro (< 0.1s) para validar las reglas del 40%,
## conteos de ítems, límites matemáticos y persistencia por piloto
## sin instanciar ningún nodo de interfaz gráfica.

const DataControllerScript = preload("res://scenes/ui/character_select/components/arsenal_banlist_data_controller.gd")

func _ready() -> void:
	super._ready()
	_run_unit_tests()

func _run_unit_tests() -> void:
	var ctrl = DataControllerScript.new(&"nova")
	assert_true(ctrl != null, "Controlador debe instanciarse")
	assert_true(ctrl.tabs_info.size() == 7, "Debe tener 7 categorías definidas")

	# 1. Validar conteos y límites del 40%
	var expected_totals: Dictionary = {
		DataControllerScript.TabCategory.WEAPONS: 11,
		DataControllerScript.TabCategory.TOMES: 18,
		DataControllerScript.TabCategory.OVERLOADS: 8,
		DataControllerScript.TabCategory.REACTIVE_PROCS: 8,
		DataControllerScript.TabCategory.UTILITY_CORES: 8,
		DataControllerScript.TabCategory.STRATEGIC_MODULES: 12,
		DataControllerScript.TabCategory.CHEST_ITEMS: 24
	}

	for tab_id in expected_totals.keys():
		var total: int = ctrl.get_total_items_for_tab(tab_id)
		var expected: int = expected_totals[tab_id]
		assert_true(total == expected, "Total en tab %d debe ser %d (obtenido %d)" % [tab_id, expected, total])
		var max_bans: int = ctrl.get_max_bans_for_tab(tab_id)
		var expected_max_bans: int = int(floor(float(expected) * 0.40))
		assert_true(max_bans == expected_max_bans, "Max bans en tab %d debe ser %d (obtenido %d)" % [tab_id, expected_max_bans, max_bans])

	# 2. Validar toggles y límite de ban para armas
	var tab_wpn: int = DataControllerScript.TabCategory.WEAPONS
	var wpn_info: Dictionary = ctrl.get_tab_info(tab_wpn)
	var wpn_ids: Array = wpn_info["item_ids"]
	var max_wpn_bans: int = ctrl.get_max_bans_for_tab(tab_wpn)

	# Limpiar estado inicial
	SaveManager.set_character_active_weapons(&"nova", wpn_ids.duplicate())
	assert_true(ctrl.get_banned_ids_for_tab(tab_wpn).is_empty(), "Inicialmente no debe haber armas baneadas")

	# Banear hasta el tope
	for i in range(max_wpn_bans):
		var ok: bool = ctrl.toggle_item_ban(tab_wpn, wpn_ids[i])
		assert_true(ok, "Banear arma %s debería ser exitoso" % str(wpn_ids[i]))

	# Intentar exceder el límite
	var overflow_ok: bool = ctrl.toggle_item_ban(tab_wpn, wpn_ids[max_wpn_bans])
	assert_true(not overflow_ok, "Banear por encima del 40% debe ser denegado")

	# Desbanear una y volver a intentar
	var unban_ok: bool = ctrl.toggle_item_ban(tab_wpn, wpn_ids[0])
	assert_true(unban_ok, "Desbanear debe ser exitoso")
	assert_true(ctrl.get_banned_ids_for_tab(tab_wpn).size() == max_wpn_bans - 1, "Debe quedar max_bans - 1")

	# Restablecer estado de Nova
	SaveManager.set_character_active_weapons(&"nova", wpn_ids.duplicate())

	pass_suite("TestBanlistRulesUnit completado con éxito en tiempo récord.")
