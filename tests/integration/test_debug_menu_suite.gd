extends Node

## Suite de Pruebas Automatizadas para el Menú de Depuración Pregame (CharacterSelectUI)
## Valida la gestión de Gacha, Economía, Desbloqueo de Skins, Mascotas, Navegantes y Progreso de Carrera.

func _ready() -> void:
	# Fallback timeout
	get_tree().create_timer(10.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout reached in Pregame Debug Menu test.")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Testing Pregame Debug Menu (Gacha, Skins, Companions & Save Data)...")
	print("==========================================")

	# 1. Resetear DebugManager a estado inicial
	DebugManager.reset_all()
	assert(DebugManager.is_debug_enabled() == true, "DebugManager debe estar habilitado en entorno de desarrollo/test")
	print("  ✓ DebugManager inicializado y activo")

	# 2. Instanciar CharacterSelectUI
	var char_select_scene: PackedScene = load("res://scenes/ui/character_select/character_select.tscn")
	var char_select = char_select_scene.instantiate()
	add_child(char_select)
	await get_tree().process_frame
	await get_tree().process_frame

	assert(CharacterSelectUI.DEBUG_MENU_AVAILABLE == true, "DEBUG_MENU_AVAILABLE debe estar habilitado")
	assert(char_select.debug_button != null, "DebugButton debe existir en el menú de despliegue")
	assert(char_select.debug_button.visible == true, "DebugButton debe ser visible")
	assert(char_select.debug_menu_modal != null, "DebugMenuModal debe estar instanciado")
	assert(not char_select.debug_menu_modal.is_open, "DebugMenuModal debe iniciar cerrado")
	print("  ✓ Interfaz de selección y botón de depuración validados")

	# 3. Abrir DebugMenuModal Pregame
	char_select._on_debug_pressed()
	await get_tree().process_frame
	assert(char_select.debug_menu_modal.is_open == true, "DebugMenuModal debe abrirse tras _on_debug_pressed()")
	assert(char_select.debug_menu_modal.visible == true, "DebugMenuModal debe ser visible")
	print("  ✓ DebugMenuModal abierto y visible en Hangar")

	var modal = char_select.debug_menu_modal

	# 4. Probar Pestaña 0: Gacha & Economía
	assert(modal.active_tab_idx == 0, "Debe iniciar en la pestaña de Gacha (índice 0)")
	assert(modal.gacha_content.visible == true, "GachaTabContent debe ser visible")
	assert(modal.career_content.visible == false, "CareerTabContent debe estar oculto")

	# Tokens de gacha
	var tokens_before: int = SaveManager.get_gacha_tokens()
	modal._on_add_tokens_10_pressed()
	assert(SaveManager.get_gacha_tokens() == tokens_before + 10, "Debe sumar 10 tokens de gacha")

	# Biomasa / Polvo estelar
	var biomass_before: int = SaveManager.get_biomass()
	modal._on_add_biomass_500_pressed()
	assert(SaveManager.get_biomass() == biomass_before + 500, "Debe sumar 500 de biomasa/stardust")

	# Desbloqueo de skins 1★ y 3★
	modal._on_unlock_all_1star_pressed()
	var unlocked_all = SaveManager.get_unlocked_skins()
	assert(unlocked_all.size() >= 180, "Deben haberse desbloqueado todas las skins (1★): %d" % unlocked_all.size())

	modal._on_unlock_all_3star_pressed()
	unlocked_all = SaveManager.get_unlocked_skins()
	for skin_id in unlocked_all:
		assert(unlocked_all[skin_id]["stars"] == 3, "Cada skin debe estar a nivel máximo de 3 estrellas")

	modal._on_lock_all_skins_pressed()
	assert(SaveManager.get_unlocked_skins().size() <= 4, "Las skins deben resetearse a las básicas predeterminadas")
	print("  ✓ Pestaña Gacha validada: Tokens (+10), Biomasa (+500), Unlocks 1★/3★ y reseteo")

	# 5. Probar Pestaña 1: Compañeros & Progreso
	modal._switch_tab(1)
	await get_tree().process_frame
	assert(modal.active_tab_idx == 1, "Debe estar en la pestaña de Progreso y Compañeros (índice 1)")
	assert(modal.gacha_content.visible == false, "GachaTabContent debe ocultarse")
	assert(modal.career_content.visible == true, "CareerTabContent debe mostrarse")

	# Desbloqueo y bloqueo de Iris (Navegante)
	modal._on_unlock_iris_pressed()
	assert(SaveManager.is_navigator_unlocked(&"iris") == true, "Iris debe estar desbloqueada")
	modal._on_lock_iris_pressed()
	assert(SaveManager.is_navigator_unlocked(&"iris") == false, "Iris debe estar bloqueada")

	# Ajustar 9 jefes derrotados
	modal._on_set_bosses_9_pressed()
	assert(SaveManager.get_bosses_defeated_count() == 9, "Debe fijar 9 jefes derrotados")
	print("  ✓ Pestaña Compañeros validada: Iris unlock/lock, simulación y 9 jefes derrotados")

	# 6. Cerrar Modal Pregame
	modal.close_menu()
	await get_tree().process_frame
	assert(not modal.is_open, "DebugMenuModal debe cerrarse limpiamente")
	print("  ✓ Cierre de modal completado")

	# 7. Validar Parallax de Fondo
	var deploy_bg = char_select.get_node_or_null("DeploymentSpaceBackground")
	if deploy_bg:
		assert(deploy_bg.has_node("SpaceBackground"), "SpaceBackground con parallax debe estar activo")
		print("  ✓ Fondo Parallax verificado")

	char_select.queue_free()
	await get_tree().process_frame

	print("\n==========================================")
	print("[PASS] ALL PREGAME DEBUG MENU TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)
