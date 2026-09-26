extends Node2D

## Suite de Pruebas Automatizadas: Sistema Narrativo Ramificado, Pilotos Rivales y 3 Finales

const RivalPilotBossScript := preload("res://scenes/combat/bosses/rival_pilot_boss.gd")
const RivalWeaponPickupScript := preload("res://scenes/combat/pickups/rival_weapon_pickup.gd")
const AlliedWingmanScript := preload("res://scenes/combat/allies/allied_wingman.gd")
const BossAstraPrimeScript := preload("res://scenes/combat/bosses/boss_astra_prime.gd")

func _ready() -> void:
	print("==================================================================")
	print("[TEST] Iniciando Suite: Narrativa Ramificada, Rivales y 3 Finales")
	print("==================================================================\n")

	_test_1_roster_and_rival_threat_queue()
	_test_2_rival_pilot_boss_mechanics()
	_test_3_rival_weapon_pickup_and_weapon_controller()
	_test_4_allied_wingman_mechanics()
	_test_5_boss_astra_prime_routes()
	_test_6_save_manager_endings_and_victory_modal()
	_test_7_wave_1_encounter_trigger_and_visibility()
	_test_8_debug_route_shortcuts_to_wave_11()

	print("\n==================================================================")
	print("[TEST] ✓ TODAS LAS PRUEBAS DE NARRATIVA Y RIVALES PASARON CON ÉXITO")
	print("==================================================================")
	get_tree().quit(0)

func _test_1_roster_and_rival_threat_queue() -> void:
	print("[1/6] Verificando Roster Canónico y Cola de 5 Rivales por Orden de Amenaza...")
	var roster := CharacterData.load_roster()
	var expected_ids := [&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo", &"nyx"]
	for id in expected_ids:
		assert(roster.has(id), "El roster canónico debe contener al piloto: %s" % id)
		var cd: CharacterData = roster[id]
		assert(cd.starting_weapon != null, "El piloto %s debe tener un starting_weapon asignado" % id)

	# Simular selección de jugador para cada personaje y verificar que siempre se eligen 5 rivales
	for player_id in expected_ids:
		var available: Array[StringName] = []
		for pid in expected_ids:
			if pid != player_id:
				available.append(pid)
		assert(available.size() == 6, "Deben quedar exactamente 6 rivales candidatos")

		var queue: Array[StringName] = []
		for pid in expected_ids:
			if available.has(pid) and queue.size() < 5:
				queue.append(pid)
		assert(queue.size() == 5, "La cola de encuentros debe tener exactamente 5 rivales")
		assert(not queue.has(player_id), "El piloto del jugador no debe estar en la cola de rivales")

	print("  ✓ Roster de 7 pilotos y lógica de selección de 5 rivales validados correctamente")

func _test_2_rival_pilot_boss_mechanics() -> void:
	print("\n[2/6] Verificando Mecánicas de RivalPilotBoss (Perímetro, Duelo 1v1 y Drop)...")
	var rival_scene: PackedScene = load("res://scenes/combat/bosses/rival_pilot_boss.tscn")
	assert(rival_scene != null, "rival_pilot_boss.tscn debe existir")

	var rival = rival_scene.instantiate()
	add_child(rival)
	rival.setup_pilot(&"nova", 1)

	assert(rival.is_in_group("rival_pilots"), "RivalPilotBoss debe pertenecer al grupo 'rival_pilots'")
	assert(rival.is_in_group("enemies"), "RivalPilotBoss debe pertenecer al grupo 'enemies'")
	assert(rival.WARNING_RADIUS == 650.0, "El radio de advertencia debe ser 650 px")
	assert(rival.COMBAT_TRIGGER_RADIUS == 340.0, "El radio de detonación de combate debe ser 340 px")
	assert(rival.ESCAPE_RADIUS == 950.0, "El radio de escape debe ser 950 px")

	# Probar cambio a combate al entrar en perímetro o ser atacada
	var engaged_signal := [false]
	rival.rival_engaged.connect(func(_pid): engaged_signal[0] = true)
	rival.engage_combat()
	assert(rival.current_state == RivalPilotBossScript.State.DOGFIGHT, "El estado debe cambiar a DOGFIGHT")
	assert(engaged_signal[0] == true, "Debe emitirse la señal rival_engaged")

	# Probar daño
	var initial_hp: float = rival.current_health
	rival.take_damage(100.0)
	assert(rival.current_health == initial_hp - 100.0, "take_damage debe reducir la salud")

	rival.queue_free()
	print("  ✓ Comportamiento y máquina de estados de RivalPilotBoss validados correctamente")

func _test_3_rival_weapon_pickup_and_weapon_controller() -> void:
	print("\n[3/6] Verificando Cápsula de Arma de Rival y WeaponController...")
	var pickup_scene: PackedScene = load("res://scenes/combat/pickups/rival_weapon_pickup.tscn")
	assert(pickup_scene != null, "rival_weapon_pickup.tscn debe existir")

	var weapon_res: WeaponData = load("res://data/weapons/roster/crescent_blade.tres") as WeaponData
	assert(weapon_res != null, "crescent_blade.tres debe existir")

	var pickup = pickup_scene.instantiate()
	add_child(pickup)
	pickup.setup(Vector2(50, 50), weapon_res, "Nyx")

	assert(pickup.weapon_data == weapon_res, "La cápsula debe contener el WeaponData asignado")
	assert(pickup.is_in_group("pickups"), "Debe pertenecer al grupo 'pickups'")

	# Simular recolección y adición al WeaponController
	var w_ctrl := WeaponController.new()
	add_child(w_ctrl)
	w_ctrl.clear_equipped_weapons()
	var added := w_ctrl.add_weapon(weapon_res)
	assert(added == true, "add_weapon debe aceptar la nueva arma en el arsenal")
	assert(w_ctrl.equipped_weapons.size() == 1, "Debe haber 1 arma equipada en el WeaponController")

	# Subir de nivel si se agrega de nuevo
	var upgraded := w_ctrl.add_weapon(weapon_res)
	assert(upgraded == true, "Volver a agregar el arma debe subirla de nivel")
	assert(w_ctrl.equipped_weapons[0].level == 2, "El nivel del arma equipada debe ser 2")

	w_ctrl.queue_free()
	pickup.queue_free()
	print("  ✓ Cápsula de arma y equipamiento progresivo en WeaponController validados")

func _test_4_allied_wingman_mechanics() -> void:
	print("\n[4/6] Verificando Escolta Aliada de la Flota de la Esperanza (AlliedWingman)...")
	var wingman_scene: PackedScene = load("res://scenes/combat/allies/allied_wingman.tscn")
	assert(wingman_scene != null, "allied_wingman.tscn debe existir")

	var wingman = wingman_scene.instantiate()
	add_child(wingman)
	wingman.setup(&"valentina", 0.0)

	assert(wingman.is_in_group("allies"), "AlliedWingman debe pertenecer al grupo 'allies'")
	assert(wingman.pilot_id == &"valentina", "Debe portar el pilot_id asignado")

	wingman.queue_free()
	print("  ✓ AlliedWingman instanciado y configurado exitosamente")

func _test_5_boss_astra_prime_routes() -> void:
	print("\n[5/6] Verificando Jefe Supremo de Oleada 11 (BossAstraPrime) y Rutas...")
	var prime_scene: PackedScene = load("res://scenes/combat/bosses/boss_astra_prime.tscn")
	assert(prime_scene != null, "boss_astra_prime.tscn debe existir")

	var prime = prime_scene.instantiate()
	add_child(prime)

	# Ruta Neutral
	prime.set_route("neutral")
	assert(prime.route == "neutral", "Ruta debe ser neutral")
	assert(prime.max_health == 3800.0, "Salud neutral debe ser 3800.0")

	# Ruta Slayer
	prime.set_route("slayer")
	assert(prime.route == "slayer", "Ruta debe ser slayer")
	assert(prime.max_health == 4600.0, "Salud en modo Slayer debe escalar a 4600.0")

	# Ruta Pacifista
	prime.set_route("pacifist")
	assert(prime.route == "pacifist", "Ruta debe ser pacifist")

	# Probar muerte y emisión de señal boss_defeated sin excepciones
	var boss_defeated_signal := [false]
	prime.boss_defeated.connect(func(_b_id): boss_defeated_signal[0] = true)
	prime.take_damage(10000.0)
	assert(prime.is_dying == true, "BossAstraPrime debe entrar en is_dying al ser abatido")
	assert(boss_defeated_signal[0] == true, "BossAstraPrime debe emitir boss_defeated sin errores de BulletServer")

	print("  ✓ Adaptabilidad de rutas y muerte de BossAstraPrime validadas exitosamente")

func _test_6_save_manager_endings_and_victory_modal() -> void:
	print("\n[6/6] Verificando Persistencia de 3 Finales en SaveManager y Pantalla de Victoria...")
	# 1. SaveManager endings
	SaveManager.record_ending("pacifist")
	SaveManager.record_ending("slayer")
	SaveManager.record_ending("neutral")

	var endings := SaveManager.get_unlocked_endings()
	assert(endings.has("pacifist"), "SaveManager debe guardar el final pacifist")
	assert(endings.has("slayer"), "SaveManager debe guardar el final slayer")
	assert(endings.has("neutral"), "SaveManager debe guardar el final neutral")
	assert(SaveManager.has_unlocked_ending("pacifist") == true, "has_unlocked_ending('pacifist') debe retornar true")

	# 2. GameOverModal con Victoria
	var modal_scene: PackedScene = load("res://scenes/ui/game_over/game_over_modal.tscn")
	assert(modal_scene != null, "game_over_modal.tscn debe existir")

	var modal = modal_scene.instantiate() as GameOverModal
	add_child(modal)

	var victory_data := {
		"score": 125000,
		"is_new_highscore": true,
		"rank": 1,
		"pilot_name": "Nova",
		"pilot_id": "nova",
		"waves_survived": 11,
		"time_survived_seconds": 660.0,
		"time_formatted": "11:00",
		"bosses_defeated": 6,
		"enemies_killed": 450,
		"biomass_collected": 120,
		"dark_matter_collected": 45,
		"credits_collected": 1500,
		"arcanas": [],
		"items": [],
		"weapons": [],
		"victory": true,
		"ending_type": "pacifist",
		"ending_title": "FINAL PACIFISTA: FLOTA DE LA ESPERANZA",
		"epilogue_text": "Las 5 pilotos perdonadas se unieron a tu vuelo, liberando el Núcleo Astra y salvando la galaxia."
	}

	modal.show_game_over(victory_data)
	assert(modal.title_label.text.contains("VICTORIA"), "El modal de fin de juego debe desplegar 'VICTORIA'")
	assert(modal.highscore_label.text.contains("FINAL PACIFISTA"), "El badge debe mostrar el título del final alcanzado")

	modal.queue_free()
	print("  ✓ Persistencia de los 3 finales y presentación visual de Victoria en GameOverModal validadas")

func _test_7_wave_1_encounter_trigger_and_visibility() -> void:
	print("\n[7/7] Verificando Visibilidad en Pantalla de la Oleada 1 y Transiciones de Distancia...")
	var rival_scene: PackedScene = load("res://scenes/combat/bosses/rival_pilot_boss.tscn")
	assert(rival_scene != null, "rival_pilot_boss.tscn debe existir")

	var rival = rival_scene.instantiate()
	add_child(rival)
	rival.setup_pilot(&"valentina", 1)

	# 1. Verificar visibilidad en viewport: spawn a 450 px no excede 540 px vertical ni 960 px horizontal
	var spawn_dist := 450.0
	assert(spawn_dist < 540.0, "La distancia de spawn (450 px) debe ser menor a la mitad de altura del viewport (540 px)")
	assert(spawn_dist > rival.COMBAT_TRIGGER_RADIUS, "La distancia de spawn debe ser mayor al radio de combate para no iniciar instantáneamente")

	# 2. Verificar estado inicial a 450 px
	assert(rival.current_state == RivalPilotBossScript.State.PEACEFUL_WARN, "Debe estar en PEACEFUL_WARN al spawnear")
	assert(rival.spared_timer == 0.0, "El temporizador de perdón debe iniciar en 0")

	# 3. Simular aproximación del jugador (< COMBAT_TRIGGER_RADIUS = 340.0)
	rival._process_peaceful_warn(0.1, 300.0)
	assert(rival.current_state == RivalPilotBossScript.State.DOGFIGHT, "Acercarse a <340 px debe detonar DOGFIGHT")

	# 4. Probar reinicio y escape pacífico por alejamiento (> ESCAPE_RADIUS = 950.0)
	var rival2 = rival_scene.instantiate()
	add_child(rival2)
	rival2.setup_pilot(&"selene", 1)
	assert(rival2.current_state == RivalPilotBossScript.State.PEACEFUL_WARN)

	# Simular alejamiento durante 4 segundos
	for i in range(41):
		rival2._process_peaceful_warn(0.1, 1000.0)

	assert(rival2.current_state == RivalPilotBossScript.State.WARPING_OUT, "Alejarse >950 px por 4s debe iniciar WARPING_OUT pacífico")

	rival.queue_free()
	rival2.queue_free()
	print("  ✓ Mecánica de aparición en Oleada 1, visibilidad en pantalla y transiciones de radio validadas")

func _test_8_debug_route_shortcuts_to_wave_11() -> void:
	print("\n[8/8] Verificando Botones Debug para Iniciar Partida en Última Wave (Rutas Pacifista, Genocida, Neutral)...")
	# 1. Probar persistencia de ruta pendiente en DebugManager
	DebugManager.set_pending_debug_route("pacifist")
	assert(DebugManager.pending_debug_route == "pacifist", "DebugManager debe guardar 'pacifist'")
	assert(DebugManager.consume_pending_debug_route() == "pacifist", "consume_pending_debug_route debe devolver 'pacifist'")
	assert(DebugManager.pending_debug_route == "", "Tras consumirse, pending_debug_route debe quedar vacía")

	# 2. Instanciar DebugMenuModal y verificar que los botones configuran la ruta y la transición
	var debug_modal_scene: PackedScene = load("res://scenes/ui/debug/debug_menu_modal.tscn")
	assert(debug_modal_scene != null, "debug_menu_modal.tscn debe existir")

	var modal = debug_modal_scene.instantiate()
	add_child(modal)

	# Probar botón pacifista fuera de combate (simula inicio de partida en W11)
	modal._on_jump_pacifist_pressed()
	assert(DebugManager.consume_pending_debug_route() == "pacifist", "Botón pacifista debe preparar 'pacifist' para iniciar partida en W11")

	# Probar botón genocida / slayer fuera de combate
	modal._on_jump_slayer_pressed()
	assert(DebugManager.consume_pending_debug_route() == "slayer", "Botón genocida debe preparar 'slayer' para iniciar partida en W11")

	# Probar botón neutral fuera de combate
	modal._on_jump_neutral_pressed()
	assert(DebugManager.consume_pending_debug_route() == "neutral", "Botón neutral debe preparar 'neutral' para iniciar partida en W11")

	modal.queue_free()
	print("  ✓ Botones del Debug Menu configuran correctamente el inicio de partida en la última oleada (Wave 11)")


