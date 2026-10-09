class_name TestTransmutationRulesUnit
extends BaseTestSuite

## TestTransmutationRulesUnit
## Micro-test síncrono ultra-rápido (< 1.5s) que valida las reglas de TransmutationDataController
## (elegibilidad de consumibles/llaves, candidatos de sacrificio por rareza) sin instanciar la UI.

const TransmutationDataControllerClass = preload("res://scenes/ui/modals/transmutation_data_controller.gd")
const ItemDataScript = preload("res://data/items/item_data.gd")


func _ready() -> void:
	super._ready()
	test_transmutation_rules()
	pass_suite("TestTransmutationRulesUnit passed")


func test_transmutation_rules() -> void:
	# 1. Probar elegibilidad
	var regular_item := ItemData.new()
	regular_item.item_id = &"warp_drive"
	regular_item.rarity = Enums.Rarity.RARE
	assert_true(TransmutationDataController.is_item_eligible_for_transmutation(regular_item), "Un ítem pasivo común debe ser elegible")

	var key_item := ItemData.new()
	key_item.item_id = &"quantum_key"
	key_item.tags = [&"key"]
	assert_true(not TransmutationDataController.is_item_eligible_for_transmutation(key_item), "quantum_key no debe ser elegible")

	var consumable_item := ItemData.new()
	consumable_item.item_id = &"health_potion"
	consumable_item.tags = [&"consumable"]
	assert_true(not TransmutationDataController.is_item_eligible_for_transmutation(consumable_item), "Ítems consumibles no deben ser elegibles")

	# 2. Candidatos de sacrificio
	var item_a := ItemData.new()
	item_a.item_id = &"item_a"
	item_a.rarity = Enums.Rarity.RARE

	var item_b := ItemData.new()
	item_b.item_id = &"item_b"
	item_b.rarity = Enums.Rarity.RARE

	var item_c := ItemData.new()
	item_c.item_id = &"item_c"
	item_c.rarity = Enums.Rarity.COMMON

	var inventory_list: Array[Dictionary] = [
		{"data": item_a, "count": 1},
		{"data": item_b, "count": 1},
		{"data": item_c, "count": 3}
	]

	# Sacrificio para item_a debe ser item_b (misma rareza RARE, diferente id)
	var candidates_for_a := TransmutationDataController.find_sacrifice_candidates(item_a, inventory_list)
	assert_true(candidates_for_a.size() == 1, "Debe haber exactamente 1 candidato de sacrificio para item_a")
	assert_true(candidates_for_a[0].item_id == &"item_b", "El candidato debe ser item_b")

	# Sacrificio para item_c: es COMMON, no hay otro ítem COMMON pero tiene count = 3 (> 1)
	var candidates_for_c := TransmutationDataController.find_sacrifice_candidates(item_c, inventory_list)
	assert_true(candidates_for_c.size() == 1, "Con count > 1, el mismo ítem debe ser válido como sacrificio")
	assert_true(candidates_for_c[0].item_id == &"item_c", "El candidato debe ser item_c")
