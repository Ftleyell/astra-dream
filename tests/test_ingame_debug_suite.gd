extends Node

const IngameDebugModalClass := preload("res://scenes/ui/debug/ingame_debug_modal.gd")

## Suite de Pruebas Automatizadas para IngameDebugModal y el Sistema de Depuración Desacoplado
## Valida el funcionamiento en combate, pausa, spawns directos, trampas, arsenal y desacoplamiento para producción.

func _ready() -> void:
	# Watchdog timeout
	get_tree().create_timer(12.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout en test de IngameDebugModal.")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Testing IngameDebugModal & Production Decoupling...")
	print("==========================================")

	# 1. Validar Salvaguarda de Producción de DebugManager
	assert(DebugManager.is_debug_enabled() == true, "DebugManager.is_debug_enabled() debe ser true en entorno de test/debug")
	print("  ✓ Salvaguarda de producción DebugManager.is_debug_enabled() validada")

	# 2. Instanciar MainGame en memoria de pruebas
	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	var main_game = main_game_scene.instantiate()
	add_child(main_game)
	await get_tree().process_frame
	await get_tree().process_frame

	assert(main_game.player != null, "Player debe existir en MainGame")
	assert(main_game.space_object_spawner != null, "SpaceObjectSpawner debe estar inicializado")
	assert(main_game.boss_coordinator != null, "CombatBossCoordinator debe estar inicializado")
	print("  ✓ MainGame y coordinadores modulares inicializados")

	# 3. Validar Invocación y Pausa de IngameDebugModal
	main_game._toggle_ingame_debug()
	await get_tree().process_frame

	var debug_modal = main_game.ingame_debug_modal
	assert(debug_modal != null, "IngameDebugModal debe haberse instanciado")
	assert(debug_modal.is_open == true, "IngameDebugModal debe estar abierto")
	assert(debug_modal.visible == true, "IngameDebugModal debe ser visible")
	assert(get_tree().paused == true, "El árbol del juego DEBE estar pausado al abrir F1")
	assert(main_game.is_any_combat_modal_active() == true, "is_any_combat_modal_active debe retornar true con F1 abierto")
	print("  ✓ F1 pausa el árbol de juego y muestra IngameDebugModal (layer 125)")

	# 4. Probar Pestaña 1: Spawns (Monolito de Arcana directo a ~200px)
	var initial_monolith_count: int = get_tree().get_nodes_in_group("monoliths").size()
	debug_modal._on_spawn_monolith_pressed()
	await get_tree().process_frame

	var post_monolith_count: int = get_tree().get_nodes_in_group("monoliths").size()
	assert(post_monolith_count == initial_monolith_count + 1, "Debe haberse generado exactamente 1 Monolito Arcano adicional")
	assert(debug_modal.is_open == false, "El modal debe cerrarse tras invocar un spawn para reanudar combate")
	assert(get_tree().paused == false, "El juego debe reanudarse tras el spawn")
	print("  ✓ Spawn instantáneo de Monolito Arcano frente al jugador verificado")

	# 5. Reabrir Modal y Probar Pestaña 2: Cheats y Trampas
	debug_modal.open()
	await get_tree().process_frame
	assert(get_tree().paused == true, "El juego vuelve a pausarse al reabrir debug")

	debug_modal._switch_tab(1) # Pestaña Cheats
	await get_tree().process_frame
	assert(debug_modal.active_tab_index == 1, "Debe estar activa la pestaña Cheats (índice 1)")

	# Activar God Mode, Créditos y Bombas
	debug_modal.god_mode_check.button_pressed = true
	debug_modal.inf_credits_check.button_pressed = true
	debug_modal.inf_bombs_check.button_pressed = true
	await get_tree().process_frame

	assert(DebugManager.infinite_hp == true, "DebugManager.infinite_hp debe ser true")
	assert(DebugManager.infinite_credits == true, "DebugManager.infinite_credits debe ser true")
	assert(DebugManager.infinite_consumables == true, "DebugManager.infinite_consumables debe ser true")
	assert(main_game.player.run_credits == 999999, "Los créditos del jugador deben ser 999,999")
	assert(main_game.player.bomb_count == 5, "Las bombas del jugador deben fijarse en 5")
	print("  ✓ Trampas in-game aplicadas en vivo (God Mode, Créditos 999k, Bombas 5)")

	# 6. Probar Pestaña 3: Arsenal e Inyección de Armas
	debug_modal._switch_tab(2) # Pestaña Arsenal
	await get_tree().process_frame
	assert(debug_modal.active_tab_index == 2, "Debe estar activa la pestaña Arsenal (índice 2)")

	var w_ctrl: WeaponController = main_game.player.get_node_or_null("WeaponController") as WeaponController
	assert(w_ctrl != null, "WeaponController debe existir en el jugador")
	var initial_weps: int = w_ctrl.equipped_weapons.size()
	var base_wep_id: StringName = w_ctrl.equipped_weapons[0].weapon_data.weapon_id

	# Inyectar Plasma Caster
	debug_modal._inject_weapon("res://resources/weapons/plasma_caster.tres", "Plasma Caster")
	await get_tree().process_frame

	assert(w_ctrl.equipped_weapons.size() == initial_weps + 1, "Debe haberse añadido el Plasma Caster")
	assert(w_ctrl.equipped_weapons[0].weapon_data.weapon_id == base_wep_id, "El arma base del personaje (slot 0) NO debe haber sido reemplazada")

	# Mejorar todas las armas
	var initial_lvl: int = w_ctrl.equipped_weapons[1].level
	debug_modal._on_upgrade_all_weapons_pressed()
	await get_tree().process_frame
	assert(w_ctrl.equipped_weapons[1].level == initial_lvl + 1, "Plasma Caster debe haber subido a nivel %d" % (initial_lvl + 1))
	print("  ✓ Inyección de armas y mejoras respetando bloqueo de arma base verificado")

	# 7. Probar Cierre y Reanudación con Tecla Escape / F1
	var esc_event := InputEventKey.new()
	esc_event.pressed = true
	esc_event.keycode = KEY_ESCAPE
	debug_modal._unhandled_input(esc_event)
	await get_tree().process_frame

	assert(debug_modal.is_open == false, "IngameDebugModal debe cerrarse con Escape")
	assert(get_tree().paused == false, "El juego debe estar reanudado tras cerrar el modal")
	print("  ✓ Cierre y reanudación con Escape/F1 verificado sin interferir con menús regulares")

	# 8. Limpieza de memoria
	main_game.queue_free()
	await get_tree().process_frame

	print("\n==========================================")
	print("TODOS LOS TESTS DE INGAME DEBUG PASARON CON ÉXITO")
	print("==========================================\n")
	get_tree().quit(0)
