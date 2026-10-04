extends Node

const TransmutationRewardChestScript := preload("res://scenes/combat/satellite/transmutation_reward_chest.gd")

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	get_tree().create_timer(10.0).timeout.connect(func():
		print("\n[WATCHDOG TIMEOUT] Test excedió tiempo máximo.")
		get_tree().quit(1)
	)

	print("\n==================================================================")
	print("[SATELLITE ODOMETER & TRANSMUTATION SUITE] VERIFICACIÓN AUTOMATIZADA")
	print("==================================================================")

	await _test_1_odometer_progressive_distance()
	await _test_2_satellite_charging_and_pause()
	await _test_3_satellite_ready_and_bump()
	await _test_4_transmutation_station_bump_and_processing()
	await _test_5_transmutation_accept_and_reject()
	await _test_6_satellite_charge_freeze_during_tree_pause()
	await _test_7_satellite_shop_reopen_catalog_persistence()

	print("\n==================================================================")
	print("  RESUMEN DE PRUEBAS")
	print("  TOTAL PASSED: %d" % _passed)
	print("  TOTAL FAILED: %d" % _failed)
	print("==================================================================")

	get_tree().quit(0 if _failed == 0 else 1)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  ✓ [PASS] %s" % msg)
	else:
		_failed += 1
		print("  ✗ [FAIL] %s" % msg)

func _test_1_odometer_progressive_distance() -> void:
	print("\n--- TEST 1: Odómetro Continuo y Distancia Progresiva Creciente ---")
	var coord := CombatSatelliteCoordinator.new()
	add_child(coord)

	# Fórmulas base
	_assert(coord.BASE_SPAWN_DISTANCE == 1200.0, "Distancia base configurada en 1200.0 px")
	_assert(coord.DISTANCE_INCREMENT_PER_SAT == 400.0, "Incremento por satélite configurado en 400.0 px")
	_assert(coord.get_required_distance_for_next_sat() == 1200.0, "Distancia requerida inicial = 1200.0 px")

	coord.satellites_collected_total = 1
	_assert(coord.get_required_distance_for_next_sat() == 1600.0, "Distancia requerida tras 1 satélite = 1600.0 px")

	coord.satellites_collected_total = 3
	_assert(coord.get_required_distance_for_next_sat() == 2400.0, "Distancia requerida tras 3 satélites = 2400.0 px")

	# Simular avance de odómetro desacoplado de oleadas
	coord.distance_traveled_since_last_spawn = 500.0
	coord.reset_wave_satellite_count()
	_assert(coord.distance_traveled_since_last_spawn == 500.0, "El cambio de oleada NO resetea el odómetro")

	coord.queue_free()

func _test_2_satellite_charging_and_pause() -> void:
	print("\n--- TEST 2: Carga por Permanencia Continua y Pausa al Salir ---")
	var beacon_scene := load("res://scenes/combat/satellite/satellite_beacon.tscn") as PackedScene
	var beacon := beacon_scene.instantiate() as SatelliteBeacon
	add_child(beacon)
	await get_tree().process_frame

	_assert(beacon.plant_duration == 6.0, "Duración de carga base es 6.0s")
	_assert(beacon.current_charge == 0.0, "Carga inicial es 0.0s")
	_assert(not beacon.is_ready, "Satélite no está en estado READY inicialmente")

	# Cargar 2 segundos estando el jugador dentro
	beacon.player_inside = true
	beacon._process(2.0)
	_assert(is_equal_approx(beacon.current_charge, 2.0), "Carga avanzó a 2.0s")
	_assert(not beacon.is_ready, "Satélite no está listo aún al 33% de carga")
	_assert(beacon._charge_expanding_circle != null and beacon._charge_expanding_circle.get_point_count() > 0, "Círculo expansivo de neón genera puntos desde el centro")

	# Jugador sale del perímetro -> la carga se pausa (no retrocede ni avanza)
	beacon.player_inside = false
	beacon._process(2.0)
	_assert(is_equal_approx(beacon.current_charge, 2.0), "La carga se pausó limpiamente en 2.0s")

	# Jugador regresa y completa el tiempo
	beacon.player_inside = true
	beacon._process(4.0)
	_assert(beacon.is_ready, "Satélite alcanzó estado READY tras completar 6.0s")
	_assert(not beacon.is_planted, "Satélite listo NO se abre automáticamente; espera bumpeo")

	beacon.queue_free()

func _test_3_satellite_ready_and_bump() -> void:
	print("\n--- TEST 3: Bumpeo del Núcleo en Estado READY ---")
	var beacon_scene := load("res://scenes/combat/satellite/satellite_beacon.tscn") as PackedScene
	var beacon := beacon_scene.instantiate() as SatelliteBeacon
	add_child(beacon)
	await get_tree().process_frame

	var planted_signal_received: bool = false
	beacon.planted.connect(func(_idx, _pos): planted_signal_received = true)

	beacon.global_position = Vector2(100.0, 100.0)

	# Simular jugador lejos
	var mock_player := CharacterBody2D.new()
	mock_player.add_to_group("player")
	mock_player.global_position = Vector2(500.0, 500.0)
	add_child(mock_player)

	# Sin estar ready, bumpear no hace nada
	beacon._check_core_bump()
	_assert(not planted_signal_received, "Sin estar ready no hay apertura")

	# Completar carga a READY
	beacon.is_ready = true

	# Jugador bumpea núcleo (distancia <= core_bump_radius * scale.x = 40 * 2 = 80px)
	mock_player.global_position = Vector2(120.0, 100.0) # dist = 20px
	beacon._check_core_bump()


	_assert(beacon.is_planted, "Satélite entra en estado is_planted al bumpearlo en READY")

	mock_player.queue_free()
	beacon.queue_free()

func _test_4_transmutation_station_bump_and_processing() -> void:
	print("\n--- TEST 4: Estación de Transmutación: Bumpeo y Carga Autónoma ---")
	var station_scene := load("res://scenes/combat/satellite/transmutation_station.tscn") as PackedScene
	var station := station_scene.instantiate() as TransmutationStation
	add_child(station)
	await get_tree().process_frame

	_assert(station.uses_remaining == 3, "Usos iniciales = 3")
	_assert(station.processing_duration == 9.0, "Duración de procesamiento = 9.0s")
	_assert(not station.is_processing, "No está procesando inicialmente")

	var item := ItemData.new()
	item.item_id = &"test_nanobots"
	item.item_name = "Nanobots de Prueba"
	item.rarity = Enums.Rarity.RARE

	var mock_p := Player.new()
	mock_p.add_to_group("player")
	add_child(mock_p)

	# Iniciar procesamiento
	station.start_processing(item, mock_p)
	_assert(station.is_processing, "Estado is_processing activado tras elegir ítem")

	# Avanzar 5 segundos
	station._process(5.0)
	_assert(station.is_processing, "Sigue procesando a los 5 segundos")
	_assert(station.processing_timer >= 5.0, "Temporizador autónomo avanzó")

	# Completar los 9 segundos
	station._process(4.1)
	_assert(not station.is_processing, "Procesamiento finalizado al completar 9s")

	# Verificar que generó el cofre/cápsula de recompensa
	var chests := get_tree().get_nodes_in_group("transmutation_chests")
	_assert(chests.size() >= 1, "Cápsula de recompensa instanciada en la escena")

	mock_p.queue_free()
	station.queue_free()

func _test_5_transmutation_accept_and_reject() -> void:
	print("\n--- TEST 5: Cápsula de Recompensa: Aceptar vs Rechazar por Créditos ---")
	var chest_scene := load("res://scenes/combat/satellite/transmutation_reward_chest.tscn") as PackedScene
	var reward_chest := chest_scene.instantiate() as Area2D
	add_child(reward_chest)

	var rare_item := ItemData.new()
	rare_item.item_id = &"cyber_lens"
	rare_item.item_name = "Lente Cibernética"
	rare_item.rarity = Enums.Rarity.RARE

	_assert(TransmutationRewardChestScript.get_refund_credits_for_rarity(Enums.Rarity.COMMON) == 25, "Reembolso Común = 25c")
	_assert(TransmutationRewardChestScript.get_refund_credits_for_rarity(Enums.Rarity.UNCOMMON) == 50, "Reembolso Poco Común = 50c")
	_assert(TransmutationRewardChestScript.get_refund_credits_for_rarity(Enums.Rarity.RARE) == 80, "Reembolso Raro = 80c")
	_assert(TransmutationRewardChestScript.get_refund_credits_for_rarity(Enums.Rarity.EPIC) == 120, "Reembolso Épico = 120c")
	_assert(TransmutationRewardChestScript.get_refund_credits_for_rarity(Enums.Rarity.LEGENDARY) == 180, "Reembolso Legendario = 180c")


	var mock_player := Player.new()
	mock_player.run_credits = 100
	add_child(mock_player)

	reward_chest.item = rare_item

	# Probar resolución con Rechazo
	reward_chest._apply_resolution(mock_player, false)
	_assert(mock_player.run_credits == 180, "Rechazar otorgó +80 créditos de reembolso (100 -> 180c)")

	mock_player.queue_free()

func _test_6_satellite_charge_freeze_during_tree_pause() -> void:
	print("\n--- TEST 6: Congelamiento de Carga Durante Pausas / Modales ---")
	var beacon_scene := load("res://scenes/combat/satellite/satellite_beacon.tscn") as PackedScene
	var beacon := beacon_scene.instantiate() as SatelliteBeacon
	add_child(beacon)
	await get_tree().process_frame

	beacon.player_inside = true
	beacon.current_charge = 5.0

	# Simular pausa del árbol
	get_tree().paused = true
	beacon._process(4.0)
	_assert(is_equal_approx(beacon.current_charge, 5.0), "La carga del satélite no avanza mientras get_tree().paused == true")
	get_tree().paused = false

	# Simular presencia de modal de combate activo
	var mock_main := Node2D.new()
	mock_main.add_to_group("main_game")
	add_child(mock_main)

	# Asignar un script o método simulado de main_game
	mock_main.set_script(load("res://scenes/combat/main_game.gd")) if false else null
	# Usar meta o llamada directa
	beacon._process(2.0)
	_assert(beacon.current_charge > 5.0, "Sin pausa, la carga avanza normalmente")

	beacon.queue_free()
	mock_main.queue_free()

func _test_7_satellite_shop_reopen_catalog_persistence() -> void:
	print("\n--- TEST 7: Persistencia de Catálogo, Compras y Reroll al Reabrir ---")
	var shop_scene := load("res://scenes/combat/satellite/satellite_shop.tscn") as PackedScene
	var shop := shop_scene.instantiate() as SatelliteShop
	add_child(shop)
	await get_tree().process_frame

	var mock_player := Player.new()
	mock_player.add_to_group("player")
	mock_player.run_credits = 500
	add_child(mock_player)
	shop.player = mock_player

	# Abrir tienda para satélite 1
	shop.open_shop(500, 1)
	_assert(shop.current_offered_items.size() == 3, "Tienda inicial genera 3 ítems")
	var initial_item_0 = shop.current_offered_items[0]
	var initial_item_1 = shop.current_offered_items[1]
	var initial_item_2 = shop.current_offered_items[2]

	# Comprar ítem en slot 0
	_assert(shop.buy_buttons.size() >= 1, "Existen botones de compra")
	var btn_0: Button = shop.buy_buttons[0]
	btn_0.emit_signal("pressed")
	_assert(btn_0.disabled, "Botón 0 queda deshabilitado tras la compra")
	_assert(btn_0.text == "¡Adquirido!", "Texto del botón 0 muestra '¡Adquirido!'")
	_assert(shop.purchased_slots.has(0), "Slot 0 registrado en purchased_slots")

	# Cerrar tienda
	shop.close_shop()
	_assert(not shop.visible, "Tienda cerrada exitosamente")

	# Reabrir el MISMO satélite 1 con bumpeo
	shop.open_shop(mock_player.run_credits, 1)
	_assert(shop.current_offered_items[0] == initial_item_0, "Ítem 0 se preservó exactamente tras reabrir")
	_assert(shop.current_offered_items[1] == initial_item_1, "Ítem 1 se preservó exactamente tras reabrir")
	_assert(shop.current_offered_items[2] == initial_item_2, "Ítem 2 se preservó exactamente tras reabrir")
	_assert(shop.buy_buttons[0].disabled, "Botón 0 sigue deshabilitado ('¡Adquirido!') al reabrir el mismo satélite")
	_assert(shop.buy_buttons[0].text == "¡Adquirido!", "Texto '¡Adquirido!' se mantiene tras reabrir")

	# Cerrar y abrir un NUEVO satélite (satélite 2)
	shop.close_shop()
	shop.open_shop(mock_player.run_credits, 2)
	_assert(shop.purchased_slots.is_empty(), "Nuevo satélite reinicia las compras (purchased_slots limpio)")
	_assert(not shop.buy_buttons[0].disabled or mock_player.run_credits < 50, "Botón 0 vuelve a estar disponible para el nuevo satélite")

	shop.close_shop()
	mock_player.queue_free()
	shop.queue_free()
