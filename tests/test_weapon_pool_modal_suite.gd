class_name TestWeaponPoolModalSuite
extends BaseTestSuite

## TestWeaponPoolModalSuite
## Verifica el funcionamiento de WeaponSelectionModal:
## - 11 armas en el pool de armas del arsenal (excluyendo las 7 armas base de pilotos).
## - Mínimo 8 armas obligatorias (bloqueo de underflow).
## - Persistencia por personaje en ProfileStorage y SaveManager.
## - Exclusión efectiva de armas en LevelUpRewardGenerator.
## - Integración en CharacterSelect con el botón [POOL ARMAS].

const WeaponCatalog = preload("res://data/weapons/weapon_catalog.gd")
const WeaponSelectionModalScript = preload("res://scenes/ui/character_select/weapon_selection_modal.gd")
const WeaponSelectionModalScene = preload("res://scenes/ui/character_select/weapon_selection_modal.tscn")
const CharacterSelectScene = preload("res://scenes/ui/character_select/character_select.tscn")


func _ready() -> void:
	super._ready()
	print("--- TEST WEAPON POOL MODAL SUITE START ---")
	_run_tests()


func _run_tests() -> void:
	# 1. Catálogo y constantes de armas
	assert_true(WeaponCatalog.POOL_WEAPON_IDS.size() == 11, "POOL_WEAPON_IDS debe contener exactamente 11 armas")
	assert_true(WeaponCatalog.PILOT_STARTING_WEAPON_IDS.size() == 7, "PILOT_STARTING_WEAPON_IDS debe contener 7 armas base")
	var pool_weapons: Array[WeaponData] = WeaponCatalog.get_pool_weapons()
	assert_true(pool_weapons.size() == 11, "get_pool_weapons() debe retornar 11 recursos WeaponData")
	print("  ✓ [PASS] Test 1: Catálogo y constantes de 11 armas del arsenal validados")

	# 2. Instanciación y comportamiento de WeaponSelectionModal
	var modal: Node = WeaponSelectionModalScene.instantiate()
	add_child(modal)

	modal.open_modal(&"nova")
	assert_true(modal.is_open, "Modal debe estar abierto tras open_modal()")
	assert_true(modal.active_weapon_ids.size() == 11, "Nova debe tener las 11 armas activas inicialmente")

	# Deseleccionar una por una hasta llegar al límite mínimo de 8
	modal._on_card_pressed(&"plasma_flak")
	assert_true(not modal.active_weapon_ids.has(&"plasma_flak"), "plasma_flak debe estar excluida")
	assert_true(modal.active_weapon_ids.size() == 10, "Debe quedar 10 armas activas")

	modal._on_card_pressed(&"scatter_laser")
	modal._on_card_pressed(&"singularity_cannon")
	assert_true(modal.active_weapon_ids.size() == 8, "Debe quedar 8 armas activas")

	# Intentar excluir una 4ª arma (debería bloquearse por MIN_ACTIVE_WEAPONS = 8)
	modal._on_card_pressed(&"solar_flare")
	assert_true(modal.active_weapon_ids.size() == 8, "No debe permitir bajar de 8 armas activas")
	assert_true(modal.active_weapon_ids.has(&"solar_flare"), "solar_flare debe seguir activa al superar el límite")
	assert_true(modal.warning_label.text.contains("8"), "Warning debe indicar el mínimo de 8 armas")
	print("  ✓ [PASS] Test 2: Mínimo 8 armas obligatorias respetado y bloqueo activo comprobado")

	# 3. Persistencia en SaveManager
	var saved_weapons: Array[StringName] = SaveManager.get_character_active_weapons(&"nova")
	assert_true(saved_weapons.size() == 8, "SaveManager debe persistir las 8 armas activas de Nova")
	assert_true(not saved_weapons.has(&"plasma_flak"), "plasma_flak debe persistir como excluida")

	# Reset
	modal._on_reset_pressed()
	assert_true(modal.active_weapon_ids.size() == 11, "Reset debe restaurar las 11 armas activas")
	assert_true(SaveManager.get_character_active_weapons(&"nova").size() == 11, "SaveManager debe reflejar el reset a 11 armas")
	modal.close_modal()
	modal.queue_free()
	print("  ✓ [PASS] Test 3: Persistencia y restauración de armas verificadas")

	# 4. Filtrado en LevelUpRewardGenerator
	var dummy_player := CharacterBody2D.new()
	var test_active_weapons: Array[StringName] = [&"plasma_flak", &"scatter_laser"]
	var generated_rewards: Array[LevelUpRewardOption] = LevelUpRewardGenerator.generate_reward_options(
		dummy_player,
		[],
		10,
		test_active_weapons
	)
	var offered_weapon_ids: Array[StringName] = []
	for r in generated_rewards:
		if r.weapon_data:
			offered_weapon_ids.append(r.weapon_data.weapon_id)

	assert_true(not offered_weapon_ids.has(&"singularity_cannon"), "singularity_cannon excluida no debe ser ofrecida")
	assert_true(not offered_weapon_ids.has(&"solar_flare"), "solar_flare excluida no debe ser ofrecida")
	dummy_player.queue_free()
	print("  ✓ [PASS] Test 4: LevelUpRewardGenerator filtra con éxito armas excluidas")

	# 5. Integración en CharacterSelect
	var char_select: Control = CharacterSelectScene.instantiate() as Control
	add_child(char_select)

	assert_true(char_select.get("loadout_button") != null, "loadout_button debe existir en la escena")
	assert_true(char_select.loadout_button.text == "[POOL ARMAS]", "Texto de loadout_button debe ser '[POOL ARMAS]'")
	assert_true(char_select.get("weapon_selection_modal") != null, "weapon_selection_modal debe estar instanciado en character_select")

	char_select._on_loadout_pressed()
	assert_true(char_select.weapon_selection_modal.is_open, "Presionar loadout_button debe abrir weapon_selection_modal")

	char_select.weapon_selection_modal.close_modal()
	assert_true(not char_select.weapon_selection_modal.is_open, "Cerrar el modal debe actualizar is_open a false")

	char_select.queue_free()
	print("  ✓ [PASS] Test 5: Botón [POOL ARMAS] y apertura de WeaponSelectionModal integrados perfectamente")

	print("--- TEST WEAPON POOL MODAL SUITE FINISHED: ALL PASS ---")
	pass_suite("TestWeaponPoolModalSuite completely passed")
