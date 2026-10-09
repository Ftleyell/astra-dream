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
const BossCinematicPresenter = preload("res://scenes/combat/bosses/boss_cinematic_presenter.gd")


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

	# 6. Validar que la grilla usa iconos cuadrados y posee panel lateral flotante sin foco
	var wpn_modal: WeaponSelectionModal = char_select.weapon_selection_modal as WeaponSelectionModal
	assert_true(wpn_modal.side_detail_panel != null, "WeaponSelectionModal debe tener side_detail_panel a la derecha")
	assert_true(wpn_modal.side_detail_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "side_detail_panel no debe capturar mouse ni foco")
	assert_true(wpn_modal.detail_title_label != null and not wpn_modal.detail_title_label.text.is_empty(), "detail_title_label debe mostrar información del arma activa")
	assert_true(wpn_modal.card_size == Vector2(80, 80), "Las tarjetas de arma deben ser cuadradas 80x80 px")

	wpn_modal.close_modal()
	assert_true(not char_select.weapon_selection_modal.is_open, "Cerrar el modal debe actualizar is_open a false")

	char_select.queue_free()
	print("  ✓ [PASS] Test 5 y 6: Botón [POOL ARMAS], panel lateral flotante y cuadrícula de iconos cuadrados validados")

	# 7. Restricción de armas base de otros pilotos en LevelUpRewardGenerator (Bug 2)
	var test_player := CharacterBody2D.new()
	var char_data := CharacterData.new()
	char_data.character_id = &"selene"
	var selene_wpn: WeaponData = WeaponCatalog.get_weapon_by_id(&"tesla_arc")
	char_data.starting_weapon = selene_wpn
	test_player.set("character_data", char_data)

	var options: Array[LevelUpRewardOption] = LevelUpRewardGenerator.generate_reward_options(
		test_player,
		[],
		20
	)
	var offered_w_ids: Array[StringName] = []
	for opt in options:
		if opt.weapon_data:
			offered_w_ids.append(opt.weapon_data.weapon_id)

	# Ninguna de las 6 armas iniciales de las otras pilotos debe aparecer para Selene
	for base_id: StringName in WeaponCatalog.PILOT_STARTING_WEAPON_IDS:
		if base_id != &"tesla_arc":
			assert_true(not offered_w_ids.has(base_id), "Arma base ajena %s no debe aparecer para Selene" % str(base_id))
	test_player.queue_free()
	print("  ✓ [PASS] Test 7: Armas base de otros pilotos correctamente excluidas como nuevas opciones")

	# 8. BossCinematicPresenter restauración de ambos componentes (bomb suppression y movement) (Bug 3)
	var mock_player := CharacterBody2D.new()
	var dummy_cam := GameCamera2D.new()
	var mock_main := Node2D.new()
	add_child(mock_main)
	add_child(dummy_cam)
	dummy_cam.add_to_group("camera")

	var mock_script := GDScript.new()
	mock_script.source_code = """extends CharacterBody2D
var bomb_cleared: bool = false
var movement_resumed: bool = false
func clear_bomb_suppression(_t: float = 0.4) -> void:
	bomb_cleared = true
func resume_movement_control() -> void:
	movement_resumed = true
"""
	mock_script.reload()
	mock_player.set_script(mock_script)
	add_child(mock_player)

	BossCinematicPresenter.restore_combat_after_emergence(mock_main, dummy_cam, mock_player)
	assert_true(mock_player.get("bomb_cleared") == true, "clear_bomb_suppression debe ejecutarse")
	assert_true(mock_player.get("movement_resumed") == true, "resume_movement_control debe ejecutarse (no ignorado por elif)")
	mock_player.queue_free()
	dummy_cam.queue_free()
	mock_main.queue_free()
	print("  ✓ [PASS] Test 8: BossCinematicPresenter restaura tanto bomb suppression como control de movimiento")

	# 9. Retorno al Hub directo con ESC / Back Button en CharacterSelect (Bug 1)
	var char_select_esc: Control = CharacterSelectScene.instantiate() as Control
	add_child(char_select_esc)
	assert_true(char_select_esc.has_method("_on_back_pressed"), "_on_back_pressed debe existir")
	# Tras confirmar heroína, el jugador está en la pantalla de equipamiento principal
	char_select_esc._on_hero_confirmed(&"nova")
	assert_true(not char_select_esc.hero_picker_modal.is_open, "hero_picker_modal debe estar cerrado tras confirmar héroe")
	# Presionar Back / ESC debe ir al Hub sin volver a abrir hero_picker_modal
	char_select_esc._on_back_pressed()
	assert_true(not char_select_esc.hero_picker_modal.is_open, "_on_back_pressed no debe reabrir hero_picker_modal")
	char_select_esc.queue_free()
	print("  ✓ [PASS] Test 9: _on_back_pressed en CharacterSelect sale al Hub sin reabrir hero_picker_modal")

	print("--- TEST WEAPON POOL MODAL SUITE FINISHED: ALL PASS ---")
	pass_suite("TestWeaponPoolModalSuite completely passed")

