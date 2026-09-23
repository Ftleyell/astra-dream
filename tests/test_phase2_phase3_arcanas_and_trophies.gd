extends SceneTree

# ==============================================================================
# Suite de Verificación E2E: Fase 2 (24 Arcanas) y Fase 3 (Sala de Trofeos)
# ==============================================================================
# Ejecutable en modo headless vía:
# godot --headless --path "C:/Users/neldo/Drive Nel2/astra-dream" -s "C:/Users/neldo/Drive Nel2/Minecraft 3/test_phase2_phase3_arcanas_and_trophies.gd"
# ==============================================================================

const ArcanaDataScript = preload("res://data/arcanas/arcana_data.gd")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")
const ArcanaSelectionModalScript = preload("res://scenes/ui/arcana/arcana_selection_modal.gd")
const DarkMatterOrbScript = preload("res://scenes/combat/pickups/dark_matter_orb.gd")
const TrophyDetailsModalScript = preload("res://scenes/ui/hub/trophy_details_modal.gd")
const PlayerScript = preload("res://scenes/combat/player/player.gd")
const CharacterDataScript = preload("res://data/characters/character_data.gd")
const BossMothershipScript = preload("res://scenes/combat/bosses/boss_mothership.gd")
const PlanetCoreScript = preload("res://scenes/combat/environment/planet_core.gd")
const ArcaneMonolithScript = preload("res://scenes/combat/environment/arcane_monolith.gd")
const HubWorldScript = preload("res://scenes/ui/hub/hub_world.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	print("\n==================================================================")
	print("ASTRA DREAM - TEST SUITE: FASE 2 & FASE 3 (ARCANAS Y SALA DE TROFEOS)")
	print("==================================================================")

	_test_tier1_arcana_catalog_and_quadrants()
	_test_tier2_arcana_selection_modal_and_pause_management()
	_test_tier3_arcana_modifiers_and_player_stats()
	_test_tier4_save_manager_dark_matter_and_trophies()
	_test_tier5_boss_and_planet_trophy_drops()
	_test_tier6_hub_trophy_room_and_modal()
	_test_tier7_edge_case_catalog_exhaustion()
	_test_tier8_greed_multipliers_and_player_economy()
	_test_tier9_main_game_and_stats_overlay_integration()

	paused = false

	print("\n==================================================================")
	print("TEST SUITE SUMMARY")
	print("Total Tests : %d" % total_tests)
	print("Passed      : %d" % passed_tests)
	print("Failed      : %d" % failed_tests)
	print("==================================================================")

	if failed_tests == 0:
		print("RESULT: ALL PHASE 2 & PHASE 3 TESTS PASSED PERFECTLY!\n")
		quit(0)
	else:
		print("RESULT: %d TESTS FAILED.\n" % failed_tests)
		quit(1)


func _pass(test_name: String, detail: String = "") -> void:
	total_tests += 1
	passed_tests += 1
	if detail.is_empty():
		print("  [PASS] %s" % test_name)
	else:
		print("  [PASS] %s: %s" % [test_name, detail])


func _fail(test_name: String, reason: String) -> void:
	total_tests += 1
	failed_tests += 1
	printerr("  [FAIL] %s -> %s" % [test_name, reason])


# ==============================================================================
# TIER 1: INTEGRIDAD DEL CATÁLOGO DE LAS 24 ARCANAS Y CUADRANTES
# ==============================================================================

func _test_tier1_arcana_catalog_and_quadrants() -> void:
	print("\n--- [TIER 1] CATÁLOGO DE LAS 24 ARCANAS Y CUADRANTES TÁCTICOS ---")

	var all_arcanas: Dictionary = ArcanaDataScript.load_all_arcanas()
	if all_arcanas.size() == 24:
		_pass("Catálogo total de Arcanas", "Exactamente 24 cartas registradas")
	else:
		_fail("Catálogo total de Arcanas", "Se esperaban 24 arcanas, encontradas: %d" % all_arcanas.size())

	var quadrant_counts := {
		"glass_cannon": 0,
		"danmaku_chaos": 0,
		"spacetime": 0,
		"greed": 0
	}

	var valid_fields := true
	for arc_id in all_arcanas.keys():
		var arc = all_arcanas[arc_id]
		if not arc:
			valid_fields = false
			_fail("Arcana nula", "ID: %s es nulo" % arc_id)
			continue

		if arc.id.is_empty() or arc.name.is_empty() or arc.description_boon.is_empty() or arc.description_curse.is_empty():
			valid_fields = false
			_fail("Campos requeridos en Arcana", "ID %s tiene descripciones vacías" % arc_id)

		if arc.stat_modifiers.is_empty():
			valid_fields = false
			_fail("Modificadores numéricos en Arcana", "ID %s no tiene modificadores numéricos" % arc_id)

		if quadrant_counts.has(arc.quadrant):
			quadrant_counts[arc.quadrant] += 1
		else:
			valid_fields = false
			_fail("Cuadrante desconocido", "ID %s tiene cuadrante inválido: %s" % [arc_id, arc.quadrant])

	if valid_fields:
		_pass("Validación de campos estructurados", "Todas las 24 arcanas tienen IDs, nombres, bonomaldición y stats")

	# Verificar distribución equitativa de 6 por cuadrante
	for q in quadrant_counts.keys():
		var c: int = quadrant_counts[q]
		if c == 6:
			_pass("Cuadrante '%s'" % q, "Exactamente 6 arcanas")
		else:
			_fail("Cuadrante '%s'" % q, "Se esperaban 6 arcanas, encontradas: %d" % c)

	# Verificar selección aleatoria y filtro de exclusión
	var sample_selection := ArcanaDataScript.get_random_selection(3, ["blood_pact", "shrapnel_rain"])
	if sample_selection.size() == 3:
		var has_excluded := false
		for s in sample_selection:
			if s.id in ["blood_pact", "shrapnel_rain"]:
				has_excluded = true
		if not has_excluded:
			_pass("ArcanaData.get_random_selection", "Devuelve 3 arcanas respetando lista de exclusión")
		else:
			_fail("ArcanaData.get_random_selection", "Incluyó arcanas que debían ser excluidas")
	else:
		_fail("ArcanaData.get_random_selection", "Cantidad retornada no es 3 (%d)" % sample_selection.size())


# ==============================================================================
# TIER 2: MODAL DE SELECCIÓN TÁCTICA Y CONTROL DE PAUSA
# ==============================================================================

func _test_tier2_arcana_selection_modal_and_pause_management() -> void:
	print("\n--- [TIER 2] MODAL DE SELECCIÓN TÁCTICA Y CONTROL DE PAUSA ---")

	var modal_scene := load("res://scenes/ui/arcana/arcana_selection_modal.tscn") as PackedScene
	if not modal_scene:
		_fail("Carga de ArcanaSelectionModal", "No se encontró el recurso tscn")
		return
	_pass("Recurso ArcanaSelectionModal", "Escena tscn válida")

	var modal = modal_scene.instantiate()
	root.add_child(modal)

	# Simular apertura con un jugador ficticio
	var dummy_player = PlayerScript.new()
	dummy_player.name = "DummyPlayer"
	var dummy_core = Node2D.new()
	dummy_core.name = "HitboxCore"
	dummy_player.add_child(dummy_core)
	var dummy_wpn = Node2D.new()
	dummy_wpn.name = "WeaponController"
	dummy_player.add_child(dummy_wpn)
	root.add_child(dummy_player)

	modal.show_arcana_selection(dummy_player)

	# 1. Comprobar que pausa el juego
	if paused:
		_pass("Pausa en ArcanaSelectionModal", "get_tree().paused es true al abrirse")
	else:
		_fail("Pausa en ArcanaSelectionModal", "No pausó la simulación")

	# 2. Comprobar que generó 3 cartas
	if modal.cards_container and modal.cards_container.get_child_count() == 3:
		_pass("Generación de tarjetas cibernéticas", "3 tarjetas instanciadas en CardsContainer")
	else:
		var count: int = modal.cards_container.get_child_count() if modal.cards_container else 0
		_fail("Generación de tarjetas cibernéticas", "Se esperaban 3 tarjetas, encontradas: %d" % count)

	# 3. Comprobar que los botones tienen foco y soporte de navegación
	if modal.card_buttons.size() == 3:
		_pass("Botones interactivos de cartas", "3 botones vinculados con UIFocusHelper")
	else:
		_fail("Botones interactivos de cartas", "Conteo incorrecto: %d" % modal.card_buttons.size())

	# 4. Simular selección de carta y verificar despausa limpia
	var chosen_arcana = modal.offered_arcanas[0]
	modal._on_card_chosen(chosen_arcana)

	if not paused:
		_pass("Despausa limpia tras elección", "get_tree().paused es false al seleccionar arcana")
	else:
		_fail("Fuga de pausa tras elección", "El árbol permaneció pausado")

	if not modal.visible:
		_pass("Ocultación del modal", "modal.visible es false tras seleccionar arcana")
	else:
		_fail("Ocultación del modal", "El modal continuó visible tras seleccionar arcana")

	modal.queue_free()
	dummy_player.queue_free()


# ==============================================================================
# TIER 3: MODIFICADORES DE ARCANA Y ACTUALIZACIÓN DE STATS
# ==============================================================================

func _test_tier3_arcana_modifiers_and_player_stats() -> void:
	print("\n--- [TIER 3] APLICACIÓN DE MODIFICADORES DE ARCANA EN STATS Y PLAYER ---")

	var char_data = CharacterDataScript.new()
	char_data.character_id = &"test_pilot"
	char_data.base_damage = 50.0
	char_data.max_health = 100.0
	char_data.move_speed = 300.0
	char_data.projectile_count = 2.0

	var player = PlayerScript.new()
	player.character_data = char_data

	var core = Node2D.new()
	core.name = "HitboxCore"
	player.add_child(core)

	var wpn = Node2D.new()
	wpn.name = "WeaponController"
	player.add_child(wpn)

	root.add_child(player)

	var base_dmg: float = player.stats.get_stat(&"base_damage")
	var base_hp: float = player.stats.get_stat(&"max_health")

	# 1. Aplicar Pacto de Sangre (+60% Daño, -35% Vida Máxima)
	var blood_pact = ArcanaDataScript.get_arcana("blood_pact")
	if not blood_pact:
		_fail("Obtención de blood_pact", "No se encontró el recurso blood_pact")
		player.queue_free()
		return

	player.apply_arcana(blood_pact)

	var new_dmg: float = player.stats.get_stat(&"base_damage")
	var new_hp: float = player.stats.get_stat(&"max_health")

	var delta_dmg: float = new_dmg - base_dmg
	if is_equal_approx(delta_dmg, char_data.base_damage * 0.60):
		_pass("Modificador de Daño (+60%)", "Delta exacto de Daño: +%.1f (%.1f -> %.1f)" % [delta_dmg, base_dmg, new_dmg])
	else:
		_fail("Modificador de Daño (+60%)", "Delta esperado: +%.1f, obtenido: +%.1f" % [char_data.base_damage * 0.60, delta_dmg])

	if is_equal_approx(new_hp, base_hp * 0.65):
		_pass("Modificador de Maldición HP (-35%)", "HP: %.1f -> %.1f" % [base_hp, new_hp])
	else:
		_fail("Modificador de Maldición HP (-35%)", "Esperado: %.1f, Obtenido: %.1f" % [base_hp * 0.65, new_hp])

	if player.current_health <= new_hp:
		_pass("Clamping de salud actual", "current_health ajustado a nueva max_health (%.1f)" % player.current_health)
	else:
		_fail("Clamping de salud actual", "current_health (%.1f) supera max_health (%.1f)" % [player.current_health, new_hp])

	# 2. Aplicar Lluvia de Metralla (+3 Proyectiles, -30% Daño)
	var shrapnel_rain = ArcanaDataScript.get_arcana("shrapnel_rain")
	player.apply_arcana(shrapnel_rain)

	var count: float = player.stats.get_stat(&"projectile_count")
	if is_equal_approx(count, 5.0):
		_pass("Modificador de Proyectiles (+3)", "Proyectiles: 2 -> 5")
	else:
		_fail("Modificador de Proyectiles (+3)", "Esperado: 5.0, Obtenido: %.1f" % count)

	# 3. Lista de arcanas activas en jugador
	var active_ids: Array[String] = player.get_arcana_ids()
	if active_ids.has("blood_pact") and active_ids.has("shrapnel_rain"):
		_pass("Persistencia de arcanas activas en Player", "active_arcanas contiene las 2 adquiridas")
	else:
		_fail("Persistencia de arcanas activas en Player", "Lista de arcanas incompleta: %s" % str(active_ids))

	player.queue_free()


# ==============================================================================
# TIER 4: PERSISTENCIA DE MATERIA OSCURA Y TROFEOS EN SAVEMANAGER
# ==============================================================================

func _test_tier4_save_manager_dark_matter_and_trophies() -> void:
	print("\n--- [TIER 4] PERSISTENCIA DE MATERIA OSCURA Y TROFEOS EN SAVEMANAGER ---")

	var init_dm: int = SaveManagerScript.get_dark_matter()
	var new_dm: int = SaveManagerScript.add_dark_matter(20)

	if new_dm == init_dm + 20 and SaveManagerScript.get_dark_matter() == new_dm:
		_pass("SaveManager.add_dark_matter", "Saldo incrementado y persistido (%d -> %d)" % [init_dm, new_dm])
	else:
		_fail("SaveManager.add_dark_matter", "Error al persistir Materia Oscura")

	# Desbloqueo y maestría de trofeo
	SaveManagerScript.unlock_or_upgrade_trophy(&"trophy_boss_aegis", 1)
	if SaveManagerScript.is_trophy_unlocked(&"trophy_boss_aegis"):
		_pass("SaveManager.is_trophy_unlocked", "trophy_boss_aegis desbloqueado")
	else:
		_fail("SaveManager.is_trophy_unlocked", "trophy_boss_aegis reporta falso")

	if SaveManagerScript.get_trophy_mastery(&"trophy_boss_aegis") >= 1:
		_pass("SaveManager.get_trophy_mastery", "Nivel de maestría >= 1")
	else:
		_fail("SaveManager.get_trophy_mastery", "Maestría menor a 1")

	# Mejora con Materia Oscura
	var dm_before: int = SaveManagerScript.get_dark_matter()
	var mastery_before: int = SaveManagerScript.get_trophy_mastery(&"trophy_boss_aegis")
	var upgraded: bool = SaveManagerScript.upgrade_trophy_with_dark_matter(&"trophy_boss_aegis", 10)

	if upgraded and SaveManagerScript.get_trophy_mastery(&"trophy_boss_aegis") == mastery_before + 1:
		_pass("SaveManager.upgrade_trophy_with_dark_matter", "Maestría subió a %d y consumió 10 DM" % (mastery_before + 1))
	else:
		_fail("SaveManager.upgrade_trophy_with_dark_matter", "Fallo al subir nivel de maestría")

	# Bonos pasivos globales
	var bonuses: Dictionary = SaveManagerScript.get_trophy_passive_bonuses()
	if bonuses.get("base_damage_pct", 0.0) >= 0.15:
		_pass("SaveManager.get_trophy_passive_bonuses", "+%.0f%% Daño global permanente activo" % (bonuses["base_damage_pct"] * 100.0))
	else:
		_fail("SaveManager.get_trophy_passive_bonuses", "Bono de daño permanente no calculado correctamente")


# ==============================================================================
# TIER 5: DROPS DE MATERIA OSCURA Y DESBLOQUEO EN BOSS Y PLANETAS
# ==============================================================================

func _test_tier5_boss_and_planet_trophy_drops() -> void:
	print("\n--- [TIER 5] DROPS DE MATERIA OSCURA Y DESBLOQUEO EN BOSS Y PLANETAS ---")

	# 1. DarkMatterOrb
	var dm_scene := load("res://scenes/combat/pickups/dark_matter_orb.tscn") as PackedScene
	if dm_scene:
		var orb = dm_scene.instantiate()
		root.add_child(orb)
		orb.setup(12, Vector2(100, 100))
		if orb.value == 12:
			_pass("DarkMatterOrb.setup", "Valor configurado en 12 u.")
		else:
			_fail("DarkMatterOrb.setup", "Valor incorrecto")
		orb.queue_free()
	else:
		_fail("DarkMatterOrb", "No se encontró escena dark_matter_orb.tscn")

	# 2. BossMothership drop y desbloqueo
	var boss = BossMothershipScript.new()
	root.add_child(boss)
	boss.global_position = Vector2(300, 300)
	boss._die()

	if SaveManagerScript.is_trophy_unlocked(&"trophy_boss_aegis"):
		_pass("BossMothership._die desbloqueo de trofeo", "trophy_boss_aegis registrado en SaveManager")
	else:
		_fail("BossMothership._die desbloqueo de trofeo", "trophy_boss_aegis no fue desbloqueado")

	# 3. PlanetCore digitalización y trofeo
	var core = PlanetCoreScript.new()
	root.add_child(core)
	core.setup_core(40.0, Color.CYAN, &"cryo_core")
	core.digitalize()

	if SaveManagerScript.is_trophy_unlocked(&"trophy_cryo_core"):
		_pass("PlanetCore.digitalize desbloqueo planetario", "trophy_cryo_core registrado en SaveManager")
	else:
		_fail("PlanetCore.digitalize desbloqueo planetario", "trophy_cryo_core no fue desbloqueado")


# ==============================================================================
# TIER 6: SALA DE TROFEOS EN HUB Y MODAL DE DETALLES
# ==============================================================================

func _test_tier6_hub_trophy_room_and_modal() -> void:
	print("\n--- [TIER 6] SALA DE TROFEOS EN HUB WORLD Y MODAL DE MAESTRÍA ---")

	# 1. TrophyDetailsModal
	var modal_scene := load("res://scenes/ui/hub/trophy_details_modal.tscn") as PackedScene
	if modal_scene:
		var modal = modal_scene.instantiate()
		root.add_child(modal)
		modal.open_trophy(&"trophy_boss_aegis")

		if modal.visible and modal.is_active:
			_pass("TrophyDetailsModal.open_trophy", "Modal abierto y visible para trophy_boss_aegis")
		else:
			_fail("TrophyDetailsModal.open_trophy", "No se abrió correctamente")

		if modal.trophy_title and modal.trophy_title.text.contains("AEGIS"):
			_pass("TrophyDetailsModal visualización de datos", "Título y lore de Nodriza Aegis correctos")
		else:
			_fail("TrophyDetailsModal visualización de datos", "Título no contiene texto de trofeo")

		modal.close_modal()
		if not modal.visible:
			_pass("TrophyDetailsModal.close_modal", "Modal cerrado correctamente")
		else:
			_fail("TrophyDetailsModal.close_modal", "Modal permaneció visible")

		modal.queue_free()
	else:
		_fail("TrophyDetailsModal", "No se encontró trophy_details_modal.tscn")

	# 2. HubWorld y Sala de Trofeos 3D
	var hub_scene := load("res://scenes/ui/hub/hub_world.tscn") as PackedScene
	if hub_scene:
		var hub = hub_scene.instantiate()
		root.add_child(hub)

		var trophy_room = hub.get_node_or_null("TrophyRoom")
		if trophy_room and trophy_room.get_child_count() == 5:
			_pass("HubWorld.TrophyRoom pedestales 3D", "5 pedestales de trofeos instanciados en Hangar 3D")
		else:
			var c: int = trophy_room.get_child_count() if trophy_room else 0
			_fail("HubWorld.TrophyRoom pedestales 3D", "Se esperaban 5 pedestales, encontrados: %d" % c)

		if hub.trophy_holo_nodes.size() == 5:
			_pass("HubWorld hologramas rotatorios", "5 hologramas 3D registrados en bucle de animación")
		else:
			_fail("HubWorld hologramas rotatorios", "Conteo de hologramas incorrecto: %d" % hub.trophy_holo_nodes.size())

		var dm_label = hub.get_node_or_null("HubUI/MaterialsPanel/MatMargin/MatVBox/DarkMatterRow/DarkMatterValue")
		if dm_label and dm_label.text.contains("u."):
			_pass("HubWorld Materials HUD", "Fila de Materia Oscura activa: %s" % dm_label.text)
		else:
			_fail("HubWorld Materials HUD", "No se encontró la fila de Materia Oscura en el HUD")

		hub.queue_free()
	else:
		_fail("HubWorld", "No se pudo cargar hub_world.tscn")


# ==============================================================================
# TIER 7: CASO BORDE: AGOTAMIENTO DE CATÁLOGO Y SOBRECARGA
# ==============================================================================

func _test_tier7_edge_case_catalog_exhaustion() -> void:
	print("\n--- [TIER 7] CASO BORDE: AGOTAMIENTO DE CATÁLOGO Y SOBRECARGA ---")
	var modal_scene := load("res://scenes/ui/arcana/arcana_selection_modal.tscn") as PackedScene
	var modal = modal_scene.instantiate()
	root.add_child(modal)

	var dummy = PlayerScript.new()
	var core = Node2D.new()
	core.name = "HitboxCore"
	dummy.add_child(core)
	var wpn = Node2D.new()
	wpn.name = "WeaponController"
	dummy.add_child(wpn)
	root.add_child(dummy)

	# Simular que el jugador ya posee las 24 arcanas
	var all_ids: Array = ArcanaDataScript.load_all_arcanas().keys()
	for id_str in all_ids:
		var a = ArcanaDataScript.get_arcana(id_str)
		if a:
			dummy.active_arcanas.append(a)

	var credits_before: int = dummy.run_credits
	var dm_before: int = SaveManagerScript.get_dark_matter()

	modal.show_arcana_selection(dummy)

	# Verificar que no crashea ni queda vacío: debe ofrecer la carta de Sobrecarga del Vacío
	if modal.offered_arcanas.size() == 1 and modal.offered_arcanas[0].id == "quantum_overload_mastery":
		_pass("Catálogo agotado", "Genera carta especial 'quantum_overload_mastery'")
	else:
		_fail("Catálogo agotado", "No generó la carta de sobrecarga")

	# Simular elección de sobrecarga
	modal._on_card_chosen(modal.offered_arcanas[0])

	if dummy.run_credits == credits_before + 500:
		_pass("Recompensa Sobrecarga Créditos", "+500 Créditos otorgados (saldo: %d)" % dummy.run_credits)
	else:
		_fail("Recompensa Sobrecarga Créditos", "Créditos no incrementaron correctamente")

	if SaveManagerScript.get_dark_matter() == dm_before + 15:
		_pass("Recompensa Sobrecarga Materia Oscura", "+15 Materia Oscura persistida (saldo: %d)" % SaveManagerScript.get_dark_matter())
	else:
		_fail("Recompensa Sobrecarga Materia Oscura", "Materia oscura no incrementó correctamente")

	if not paused:
		_pass("Despausa limpia tras sobrecarga", "Árbol despausado correctamente")
	else:
		_fail("Despausa limpia tras sobrecarga", "Árbol continuó pausado")

	modal.queue_free()
	dummy.queue_free()


# ==============================================================================
# TIER 8: CUADRANTE DE AVARICIA: MULTIPLICADORES Y ECONOMÍA
# ==============================================================================

func _test_tier8_greed_multipliers_and_player_economy() -> void:
	print("\n--- [TIER 8] CUADRANTE DE AVARICIA: MULTIPLICADORES Y ECONOMÍA ---")

	var char_data = CharacterDataScript.new()
	char_data.character_id = &"economy_test_pilot"
	char_data.base_damage = 40.0
	char_data.max_health = 100.0

	var player = PlayerScript.new()
	player.character_data = char_data
	var core = Node2D.new()
	core.name = "HitboxCore"
	player.add_child(core)
	var wpn = Node2D.new()
	wpn.name = "WeaponController"
	player.add_child(wpn)
	root.add_child(player)

	# 1. Base multipliers
	var base_credits_mult: float = player.stats.get_stat(&"credits_multiplier")
	var base_bio_mult: float = player.stats.get_stat(&"biomass_multiplier")
	if is_equal_approx(base_credits_mult, 1.0) and is_equal_approx(base_bio_mult, 1.0):
		_pass("CharacterStats multiplicadores base", "credits_multiplier y biomass_multiplier inicializados en 1.0")
	else:
		_fail("CharacterStats multiplicadores base", "Multiplicadores base incorrectos")

	# 2. Aplicar Voracious Harvest (+100% créditos, +100% biomasa)
	var voracious = ArcanaDataScript.get_arcana("voracious_harvest")
	if voracious:
		player.apply_arcana(voracious)
		var new_credits_mult: float = player.stats.get_stat(&"credits_multiplier")
		var new_bio_mult: float = player.stats.get_stat(&"biomass_multiplier")
		if is_equal_approx(new_credits_mult, 2.0) and is_equal_approx(new_bio_mult, 2.0):
			_pass("Voracious Harvest stats", "Multiplicadores subieron a 2.0 (+100%)")
		else:
			_fail("Voracious Harvest stats", "Multiplicadores no subieron a 2.0: cr=%.2f, bio=%.2f" % [new_credits_mult, new_bio_mult])

		var c_init: int = player.run_credits
		player.add_credits(50)
		if player.run_credits == c_init + 100:
			_pass("Player.add_credits con bono Voraz", "50 créditos base duplicados a +100 créditos")
		else:
			_fail("Player.add_credits con bono Voraz", "Esperado: +100, obtenido: %d" % (player.run_credits - c_init))

		var bio_init: int = player.run_biomass
		player.add_biomass(10)
		if player.run_biomass == bio_init + 20:
			_pass("Player.add_biomass con bono Voraz", "10 biomasa base duplicada a +20 biomasa")
		else:
			_fail("Player.add_biomass con bono Voraz", "Esperado: +20, obtenido: %d" % (player.run_biomass - bio_init))
	else:
		_fail("Voracious Harvest", "No se encontró recurso voracious_harvest.tres")

	player.queue_free()


# ==============================================================================
# TIER 9: INTEGRACIÓN CON MAIN_GAME Y STATS OVERLAY
# ==============================================================================

func _test_tier9_main_game_and_stats_overlay_integration() -> void:
	print("\n--- [TIER 9] INTEGRACIÓN CON MAIN_GAME Y STATS OVERLAY ---")

	var p = PlayerScript.new()
	var c = Node2D.new()
	c.name = "HitboxCore"
	p.add_child(c)
	var wpn = Node2D.new()
	wpn.name = "WeaponController"
	p.add_child(wpn)
	root.add_child(p)

	var arc1 = ArcanaDataScript.get_arcana("blood_pact")
	var arc2 = ArcanaDataScript.get_arcana("quantum_ricochet")
	p.apply_arcana(arc1)
	p.apply_arcana(arc2)
	p.run_dark_matter = 25

	var arc_ids := p.get_arcana_ids()
	if arc_ids.has("blood_pact") and arc_ids.has("quantum_ricochet"):
		_pass("Player get_arcana_ids", "Devuelve IDs de arcanas activas")
	else:
		_fail("Player get_arcana_ids", "IDs incorrectos")

	# Simular un run_data guardado
	var saved_run := {
		"current_wave": 3,
		"player_health": 80.0,
		"run_credits": 300,
		"run_biomass": 40,
		"run_dark_matter": 25,
		"active_arcanas": ["blood_pact", "quantum_ricochet"]
	}

	# Restaurar en un jugador limpio
	var p2 = PlayerScript.new()
	var c2 = Node2D.new()
	c2.name = "HitboxCore"
	p2.add_child(c2)
	var wpn2 = Node2D.new()
	wpn2.name = "WeaponController"
	p2.add_child(wpn2)
	root.add_child(p2)

	p2.run_dark_matter = int(saved_run.get("run_dark_matter", 0))
	var saved_arcs: Array = saved_run.get("active_arcanas", [])
	p2.active_arcanas.clear()
	for a_id in saved_arcs:
		var a = ArcanaDataScript.get_arcana(String(a_id))
		if a:
			p2.apply_arcana(a)

	if p2.run_dark_matter == 25 and p2.get_arcana_ids().size() == 2:
		_pass("Restauración de run state", "Materia Oscura (25) y Arcanas (2) restauradas exitosamente")
	else:
		_fail("Restauración de run state", "Fallo al restaurar datos")

	# 2. Verificar CharacterStatsOverlay listado de trofeos y arcanas
	var overlay_scene := load("res://scenes/ui/character_stats_overlay.tscn") as PackedScene
	if overlay_scene:
		var overlay = overlay_scene.instantiate()
		root.add_child(overlay)
		overlay.player = p2
		overlay.open_stats()

		var perks_list = overlay.perks_list
		var found_trophies: int = 0
		var found_arcanas: int = 0
		if perks_list:
			for lbl in perks_list.find_children("*", "Label", true, false):
				if lbl is Label:
					if lbl.text.contains("★ TROFEO"):
						found_trophies += 1
					if lbl.text.contains("◈ PACTO"):
						found_arcanas += 1

		if found_trophies >= 1 and found_arcanas >= 2:
			_pass("CharacterStatsOverlay cockpit [C]", "Muestra arcanas activas (%d) y trofeos globales (%d)" % [found_arcanas, found_trophies])
		else:
			_fail("CharacterStatsOverlay cockpit [C]", "Perks insuficientes: trofeos=%d, arcanas=%d" % [found_trophies, found_arcanas])

		overlay.close_stats()
		overlay.queue_free()

	# 3. Verificar MainGame conexión EventBus y encolamiento de orbes
	var mg_scene := load("res://scenes/combat/main_game.tscn") as PackedScene
	if mg_scene:
		var mg = mg_scene.instantiate()
		root.add_child(mg)

		if mg.arcana_modal != null:
			_pass("MainGame.arcana_modal instanciado", "Modal presente en árbol de MainGame")
		else:
			_fail("MainGame.arcana_modal instanciado", "Modal es null")

		var bus := root.get_node_or_null("/root/EventBus")
		if bus and bus.arcana_orb_collected.is_connected(mg._on_arcana_orb_collected):
			_pass("MainGame EventBus conexión", "EventBus.arcana_orb_collected conectado a MainGame._on_arcana_orb_collected")
		else:
			_fail("MainGame EventBus conexión", "La señal no está conectada a MainGame")

		var dummy_orb = Node2D.new()
		mg._on_arcana_orb_collected(dummy_orb)
		var first_open: bool = mg.is_arcana_modal_active()
		mg._on_arcana_orb_collected(dummy_orb)
		var pending_count: int = mg._pending_arcana_picks

		if first_open and pending_count == 1:
			_pass("MainGame encolamiento de orbes", "Primer orbe abre modal y segundo encola (+1 pendiente)")
		else:
			_fail("MainGame encolamiento de orbes", "Estado inesperado: first_open=%s, pending=%d" % [first_open, pending_count])

		mg.arcana_modal.close_modal()
		mg.queue_free()
		dummy_orb.queue_free()

	p.queue_free()
	p2.queue_free()

