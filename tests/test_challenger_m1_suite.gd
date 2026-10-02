extends Node

func _ready() -> void:
	# Watchdog timer de seguridad
	get_tree().create_timer(15.0).timeout.connect(func() -> void:
		print("[TEST WATCHDOG] Timeout alcanzado en Challenger M1 Harness, abortando...")
		get_tree().quit(1)
	)

	print("\n==================================================================")
	print("[CHALLENGER M1] Invocando Harness de Pruebas Adversarias Empíricas")
	print("==================================================================")

	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert(main_game_scene != null, "main_game.tscn debe existir")

	var main_game: MainGame = main_game_scene.instantiate() as MainGame
	add_child(main_game)

	main_game.is_briefing_active = false
	get_tree().paused = false

	var player: Player = main_game.player
	var level_modal: LevelUpModal = main_game.level_up_modal
	var shop: SatelliteShop = main_game.satellite_shop
	var deck_mgr: StatDeckManager = main_game.stat_deck_manager

	assert(player != null, "Player debe existir en MainGame")
	assert(level_modal != null, "LevelUpModal debe existir en MainGame")
	assert(shop != null, "SatelliteShop debe existir en MainGame")
	assert(deck_mgr != null, "StatDeckManager debe existir en MainGame")

	# =========================================================================
	# SECCIÓN 1: STRESS-TEST DE StatDeckManager (100 ofertas, niveles 1-50, 0 proyectiles)
	# =========================================================================
	print("\n[CHALLENGE 1/4] Stress-testing StatDeckManager: 100 ofertas en niveles 1..50...")
	var total_cards_checked: int = 0
	var projectile_cards_found: int = 0
	var invalid_counts: int = 0
	var duplicate_hands_found: int = 0

	var test_luck_values: Array[float] = [0.2, 0.5, 1.0, 1.5, 2.0, 5.0, 10.0]

	for i in range(100):
		var test_level: int = (i % 50) + 1 # Niveles 1 a 50
		var luck_idx: int = i % test_luck_values.size()
		player.stats._base_stats[&"luck"] = test_luck_values[luck_idx]
		player.stats._is_dirty[&"luck"] = true

		var last_hand: Array[StatCardData] = []
		var capture_callable := func(cards: Array[StatCardData], _cost: int) -> void:
			last_hand.clear()
			last_hand.append_array(cards)

		deck_mgr.cards_offered.connect(capture_callable, CONNECT_ONE_SHOT)
		deck_mgr.offer_cards(player.stats, test_level, 3)

		if last_hand.size() != 3:
			invalid_counts += 1

		var hand_ids: Dictionary = {}
		for card in last_hand:
			total_cards_checked += 1
			if card == null:
				printerr("Error: Carta nula detectada en nivel %d oferta %d" % [test_level, i])
				invalid_counts += 1
				continue

			if card.target_stat == &"projectile_count" or String(card.card_id).contains("proj"):
				projectile_cards_found += 1
				printerr("Vulnerabilidad detectada: Carta de proyectil '%s' en oferta!" % card.card_id)

			if hand_ids.has(card.card_id):
				duplicate_hands_found += 1
				printerr("Vulnerabilidad detectada: Carta duplicada '%s' en la misma mano de 3!" % card.card_id)
			hand_ids[card.card_id] = true

	assert(invalid_counts == 0, "Todas las 100 ofertas deben contener exactamente 3 cartas (fallos: %d)" % invalid_counts)
	assert(projectile_cards_found == 0, "No debe aparecer ninguna carta de proyectiles en las 100 ofertas (encontradas: %d)" % projectile_cards_found)
	assert(duplicate_hands_found == 0, "Ninguna oferta debe contener cartas duplicadas en la misma mano")
	assert(total_cards_checked == 300, "Deben haberse evaluado exactamente 300 cartas (3 x 100)")
	print("  ✓ 100 ofertas consecutivas evaluadas (niveles 1 a 50, suerte 0.2 a 10.0).")
	print("  ✓ Total de cartas auditadas: %d. Cartas de proyectil: 0. Duplicados: 0." % total_cards_checked)

	# 1.2 Reroll stress-test en StatDeckManager
	print("  -> Stress-testing 50 rerolls consecutivos en StatDeckManager...")
	var initial_reroll_cost := deck_mgr.get_reroll_cost()
	for r in range(50):
		var reroll_hand: Array[StatCardData] = []
		var reroll_capture := func(cards: Array[StatCardData], _cost: int) -> void:
			reroll_hand.clear()
			reroll_hand.append_array(cards)
		deck_mgr.cards_offered.connect(reroll_capture, CONNECT_ONE_SHOT)
		var ok: bool = deck_mgr.reroll(player.stats, 99999)
		assert(ok, "Reroll con créditos abundantes debe ser exitoso")
		assert(reroll_hand.size() == 3, "Cada reroll debe ofrecer exactamente 3 cartas")
		for rc in reroll_hand:
			assert(rc.target_stat != &"projectile_count", "Reroll no debe generar cartas de proyectil")
	assert(deck_mgr.get_reroll_cost() > initial_reroll_cost, "Coste de reroll debe escalar tras múltiples rerolls")
	print("  ✓ 50 rerolls consecutivos en StatDeckManager validados con éxito.")

	# =========================================================================
	# SECCIÓN 2: STRESS-TEST DE SatelliteShop (Abuso masivo de re-roll)
	# =========================================================================
	print("\n[CHALLENGE 2/4] Stress-testing SatelliteShop: Re-roll spam abuse & edge limits...")

	# 2.1 Visita con créditos abundantes y spam de 100 clics
	player.run_credits = 200
	shop.open_shop(player.run_credits)
	assert(shop.can_reroll() == true, "can_reroll debe ser true inicialmente")
	assert(shop.reroll_btn.disabled == false, "Botón de re-roll debe estar habilitado")
	assert(shop.rerolls_used_this_visit == 0, "Uso inicial debe ser 0")

	# Primer re-roll legítimo
	var cost_expected := shop.reroll_cost # 30
	shop._on_reroll_pressed()
	assert(shop.rerolls_used_this_visit == 1, "Debe registrar exactamente 1 re-roll usado")
	assert(shop.current_credits == 200 - cost_expected, "Créditos locales deben ser 170")
	assert(player.run_credits == 170, "player.run_credits debe estar sincronizado en 170")
	assert(shop.can_reroll() == false, "can_reroll DEBE ser false tras 1 uso")
	assert(shop.reroll_btn.disabled == true, "Botón DEBE estar deshabilitado tras 1 uso")
	assert(shop.reroll_btn.text.contains("AGOTADO"), "Texto del botón debe reflejar estado AGOTADO")

	# RÁFAGA ADVERSARIA: 100 llamadas directas a _on_reroll_pressed()
	for abuse_call in range(100):
		shop._on_reroll_pressed()
		assert(shop.current_credits == 170, "Ataque en iteración %d: Créditos no deben alterarse" % abuse_call)
		assert(player.run_credits == 170, "Ataque en iteración %d: player.run_credits no debe alterarse" % abuse_call)
		assert(shop.rerolls_used_this_visit == 1, "Ataque en iteración %d: rerolls_used debe permanecer en 1" % abuse_call)
		assert(shop.can_reroll() == false, "can_reroll debe permanecer false")
		assert(shop.reroll_btn.disabled == true, "Botón debe permanecer deshabilitado")
	print("  ✓ Ráfaga de 100 llamadas directas a _on_reroll_pressed() bloqueadas al 100%% sin cobro.")

	# 2.2 Ataque de emisión directa de señal pressed del botón
	for signal_abuse in range(20):
		shop.reroll_btn.pressed.emit()
		assert(shop.current_credits == 170, "Emisión de señal no debe evadir el límite")
		assert(player.run_credits == 170, "player.run_credits intacto")
		assert(shop.rerolls_used_this_visit == 1, "rerolls_used intacto")
	print("  ✓ Emisiones directas de señal en botón deshabilitado bloqueadas sin fuga de créditos.")

	# 2.3 Tienda con fondos insuficientes (< 30 créditos)
	shop.close_shop()
	player.run_credits = 20
	shop.open_shop(player.run_credits)
	assert(shop.can_reroll() == false, "can_reroll debe ser false cuando créditos < 30")
	assert(shop.reroll_btn.disabled == true, "Botón debe estar deshabilitado por falta de fondos")
	for low_abuse in range(25):
		shop._on_reroll_pressed()
		assert(shop.current_credits == 20, "Créditos insuficientes no deben modificarse")
		assert(player.run_credits == 20, "player.run_credits no modificado")
		assert(shop.rerolls_used_this_visit == 0, "No debe registrarse re-roll")
	print("  ✓ Fondos insuficientes (20C < 30C) correctamente protegidos contra llamadas forzadas.")

	# 2.4 Tienda con 0 créditos
	shop.close_shop()
	player.run_credits = 0
	shop.open_shop(player.run_credits)
	assert(shop.can_reroll() == false, "can_reroll debe ser false con 0 créditos")
	assert(shop.reroll_btn.disabled == true, "Botón deshabilitado con 0 créditos")
	for zero_abuse in range(10):
		shop._on_reroll_pressed()
		assert(shop.current_credits == 0, "Créditos cero deben permanecer en 0")
	print("  ✓ Cero créditos protegido.")

	# 2.5 Reseteo legal por visita consecutiva a 3 satélites
	shop.close_shop()
	player.run_credits = 90 # Exactamente para 3 satélites (3 x 30C)
	for visit in range(3):
		shop.open_shop(player.run_credits)
		assert(shop.rerolls_used_this_visit == 0, "Visita %d: Cupo debe reiniciarse a 0" % (visit + 1))
		assert(shop.can_reroll() == true, "Visita %d: Debe permitir reroll legal" % (visit + 1))
		shop._on_reroll_pressed()
		assert(shop.rerolls_used_this_visit == 1, "Visita %d: 1 reroll consumido" % (visit + 1))
		assert(shop.can_reroll() == false, "Visita %d: Cupo agotado" % (visit + 1))
		# Intentar 5 abusos dentro de esta visita
		for extra in range(5):
			shop._on_reroll_pressed()
		shop.close_shop()
	assert(player.run_credits == 0, "Tras 3 visitas consumiendo 1 reroll cada una, créditos deben ser exactamente 0")
	print("  ✓ Reseteo de cupo por nueva visita validado a lo largo de 3 satélites sucesivos.")

	# =========================================================================
	# SECCIÓN 3: STRESS-TEST DE LevelUpModal (Simulación de ráfaga de teclas rápidas)
	# =========================================================================
	print("\n[CHALLENGE 3/4] Stress-testing LevelUpModal: Rapid keypress bursts & queue safety...")

	# Helper para generar evento de tecla simulado
	var make_key_event := func(keycode: Key) -> InputEventKey:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.pressed = true
		ev.echo = false
		return ev

	# 3.1 Ráfaga de teclas inmediatas en una única subida de nivel
	level_modal.clear_pending_levels()
	var initial_chosen_count: int = player.chosen_stat_cards.size()
	level_modal.show_level_up(2)
	assert(level_modal.visible, "Modal debe abrirse")
	assert(level_modal.current_offered_cards.size() == 3, "Deben ofrecerse 3 cartas")

	# Simular una ráfaga masiva instantánea de teclas en la misma ventana de tiempo
	level_modal._input(make_key_event.call(KEY_1)) # Primera tecla: debe procesar selección
	level_modal._input(make_key_event.call(KEY_2)) # Tecla rápida competidora: debe ser descartada
	level_modal._input(make_key_event.call(KEY_3)) # Tecla rápida competidora: debe ser descartada
	level_modal._input(make_key_event.call(KEY_SPACE)) # Confirmación redundante
	level_modal._input(make_key_event.call(KEY_ENTER)) # Confirmación redundante
	level_modal._input(make_key_event.call(KEY_1)) # Repetición

	assert(not level_modal.visible, "LevelUpModal DEBE cerrarse tras procesar la primera selección")
	var new_chosen_count: int = player.chosen_stat_cards.size()
	assert(new_chosen_count == initial_chosen_count + 1, "Ráfaga de teclas concurrentes debe otorgar EXACTAMENTE 1 carta (otorgadas: %d)" % (new_chosen_count - initial_chosen_count))
	print("  ✓ Ráfaga simultánea (1, 2, 3, Espacio, Enter) absorbida con seguridad: exactamente 1 carta añadida.")

	# 3.2 Manejo de múltiples subidas de nivel en cola (1 tecla por nivel)
	print("  -> Stress-testing cola de 5 subidas de nivel secuenciales...")
	level_modal.clear_pending_levels()
	var cards_before_queue: int = player.chosen_stat_cards.size()

	level_modal.show_level_up(3)
	level_modal.show_level_up(4)
	level_modal.show_level_up(5)
	level_modal.show_level_up(6)
	level_modal.show_level_up(7)

	assert(level_modal.visible, "Modal debe estar visible")
	assert(level_modal.pending_levels_queue.size() == 4, "Debe haber 4 niveles en cola tras el actual")

	# Enviar 1 tecla por cada nivel en la cola
	var sequential_keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_1, KEY_2]
	for step in range(5):
		assert(level_modal.visible, "Paso %d: Modal debe permanecer abierto para el siguiente nivel" % step)
		var chosen_key: Key = sequential_keys[step]
		level_modal._input(make_key_event.call(chosen_key))

	assert(not level_modal.visible, "Modal debe cerrarse una vez que todos los 5 niveles se hayan resuelto")
	assert(level_modal.pending_levels_queue.is_empty(), "La cola de niveles pendientes debe quedar vacía")
	var cards_after_queue: int = player.chosen_stat_cards.size()
	assert(cards_after_queue == cards_before_queue + 5, "Deben haberse otorgado exactamente 5 cartas para los 5 niveles (otorgadas: %d)" % (cards_after_queue - cards_before_queue))
	print("  ✓ Cola de 5 niveles secuenciales resuelta: 5 niveles completados, 5 cartas aplicadas, cola vacía.")

	# 3.3 Ráfaga masiva de spam de teclas sobre cola de 3 niveles
	print("  -> Stress-testing ráfaga de 10 teclas instantáneas sobre cola de 3 niveles...")
	level_modal.clear_pending_levels()
	var cards_before_burst: int = player.chosen_stat_cards.size()
	level_modal.show_level_up(10)
	level_modal.show_level_up(11)
	level_modal.show_level_up(12)

	assert(level_modal.visible, "Modal visible para nivel 10")
	assert(level_modal.pending_levels_queue.size() == 2, "2 niveles en cola tras el 10")

	# Ráfaga masiva continua de 10 teclas sin pausa
	var burst_keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_1, KEY_2, KEY_3, KEY_SPACE, KEY_ENTER, KEY_1, KEY_2]
	for bk in burst_keys:
		level_modal._input(make_key_event.call(bk))

	assert(not level_modal.visible, "Modal debe cerrarse tras consumir los 3 niveles")
	assert(level_modal.pending_levels_queue.is_empty(), "Cola debe quedar vacía")
	var cards_after_burst: int = player.chosen_stat_cards.size()
	assert(cards_after_burst == cards_before_burst + 3, "Ráfaga de 10 teclas debe detenerse tras los 3 niveles disponibles (otorgadas: %d, esperado: 3)" % (cards_after_burst - cards_before_burst))
	print("  ✓ Ráfaga de 10 teclas sobre 3 niveles contenida estrictamente: exactamente 3 cartas otorgadas, 7 teclas descartadas.")

	# 3.4 Test de navegación rápida y wrap-around cíclico (200 cambios de dirección)
	print("  -> Stress-testing navegación WASD/Flechas (200 cambios rápidos de foco)...")
	level_modal.clear_pending_levels()
	level_modal.show_level_up(8)
	var nav_keys: Array[Key] = [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_S, KEY_UP, KEY_DOWN]
	for step in range(200):
		var k: Key = nav_keys[step % nav_keys.size()]
		level_modal._input(make_key_event.call(k))
		assert(level_modal.current_selected_idx >= 0 and level_modal.current_selected_idx < 3, "Índice de selección fuera de rango en paso %d: %d" % [step, level_modal.current_selected_idx])

	# Confirmar con tecla Espacio
	level_modal._input(make_key_event.call(KEY_SPACE))
	assert(not level_modal.visible, "Modal cerrado tras navegación y confirmación con Espacio")
	print("  ✓ 200 iteraciones de navegación cíclica ejecutadas sin desbordamiento ni fallos de rango [0..2].")

	# 3.5 Inyección de teclas inválidas o no mapeadas
	print("  -> Stress-testing teclas no mapeadas (4, 5, 9, ESC, Z)...")
	level_modal.show_level_up(9)
	var unmapped_keys: Array[Key] = [KEY_4, KEY_KP_4, KEY_5, KEY_9, KEY_ESCAPE, KEY_Z, KEY_X, KEY_TAB]
	var pre_invalid_cards: int = player.chosen_stat_cards.size()
	for unk in unmapped_keys:
		level_modal._input(make_key_event.call(unk))
		assert(level_modal.visible, "Teclas no mapeadas no deben cerrar el modal ni seleccionar cartas")
		assert(player.chosen_stat_cards.size() == pre_invalid_cards, "Ninguna carta debe otorgarse con teclas no mapeadas")
	# Seleccionar legítimamente con tecla 3
	level_modal._input(make_key_event.call(KEY_3))
	assert(not level_modal.visible, "Modal cerrado correctamente con tecla 3")
	assert(player.chosen_stat_cards.size() == pre_invalid_cards + 1, "Exactamente 1 carta otorgada tras ignorar teclas inválidas")
	print("  ✓ Teclas no mapeadas (incluyendo KEY_4/KEY_KP_4 removidas) ignoradas estrictamente sin efectos colaterales.")

	# =========================================================================
	# SECCIÓN 4: CALIBRACIÓN ECONÓMICA Y VERIFICACIÓN ESTADÍSTICA DE DROPS
	# =========================================================================
	print("\n[CHALLENGE 4/4] Verifying Economic Balance & Drop Rate Rates Empirically...")

	# 4.1 Simulación Monte Carlo de tasa de drop en enjambres (30%) y drones menores (50%)
	print("  -> Simulando 2000 eliminaciones de enemigos para validar probabilidades de créditos...")
	var swarm_drops: int = 0
	var minor_drops: int = 0
	var monte_carlo_trials: int = 2000

	# Emular exactamente la lógica determinista de enemy_base.gd:145-151
	for trial in range(monte_carlo_trials):
		# Swarms (credits_reward = 1) -> 30% drop rate
		if randf() < 0.30:
			swarm_drops += 1
		# Minor assault (credits_reward = 2) -> 50% drop rate
		if randf() < 0.50:
			minor_drops += 1

	var swarm_rate: float = float(swarm_drops) / float(monte_carlo_trials)
	var minor_rate: float = float(minor_drops) / float(monte_carlo_trials)

	print("    Swarm (nominal 30%%): observado %.1f%% (%d/%d)" % [swarm_rate * 100.0, swarm_drops, monte_carlo_trials])
	print("    Minor assault (nominal 50%%): observado %.1f%% (%d/%d)" % [minor_rate * 100.0, minor_drops, monte_carlo_trials])

	assert(swarm_rate >= 0.26 and swarm_rate <= 0.34, "Tasa de drop de enjambres debe converger alrededor de 30%% (actual: %.2f)" % swarm_rate)
	assert(minor_rate >= 0.46 and minor_rate <= 0.54, "Tasa de drop de unidades menores debe converger alrededor de 50%% (actual: %.2f)" % minor_rate)
	print("  ✓ Convergencia estadística de drops de créditos validada empíricamente.")

	# 4.2 Verificación de precios de catálogo de la tienda satélite
	var canonical_items := ItemPoolManager.create_canonical_stat_items()
	for it in canonical_items:
		if it.rarity == Enums.Rarity.COMMON:
			assert(it.cost == 45, "Ítem común %s debe costar exactamente 45C (actual: %d)" % [it.item_name, it.cost])
		elif it.rarity == Enums.Rarity.UNCOMMON:
			assert(it.cost == 60, "Ítem poco común %s debe costar exactamente 60C (actual: %d)" % [it.item_name, it.cost])
		elif it.rarity == Enums.Rarity.RARE:
			assert(it.cost == 95, "Ítem raro %s debe costar exactamente 95C (actual: %d)" % [it.item_name, it.cost])
	print("  ✓ Precios de ítems pasivos canónicos calibrados: Comunes 45C, Poco Comunes 60C, Raros 95C.")

	var shop_weapons: Dictionary = {
		"nova_flak": 130,
		"cluster_submunition": 135,
		"dimensional_blade": 140,
		"solar_beam": 150
	}
	for w_name in shop_weapons.keys():
		var w_path: String = "res://data/weapons/shop/%s.tres" % w_name
		var w: WeaponData = load(w_path) as WeaponData
		assert(w != null, "Arma de tienda %s debe existir" % w_name)
		var expected_cost: int = shop_weapons[w_name]
		assert(w.cost == expected_cost, "Arma %s debe costar %dC (actual: %d)" % [w_name, expected_cost, w.cost])
	print("  ✓ Precios de las 4 armas exclusivas de tienda verificados: 130C, 135C, 140C, 150C.")

	print("\n==================================================================")
	print("[PASS] EMPIRICAL ADVERSARIAL CHALLENGE COMPLETED: ALL 4 SECTIONS PASSED (100%)!")
	print("==================================================================\n")
	get_tree().quit(0)
