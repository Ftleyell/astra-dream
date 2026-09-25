extends Node

func _ready() -> void:
	print("\n=======================================================")
	print("🧪 EJECUTANDO TEST SUITE: PRE-ALPHA 5 FEATURES")
	print("=======================================================\n")

	test_autoaim_fix()
	test_satellite_alert_and_ping()
	test_career_stats_and_nyx_unlock()
	test_rainbow_enemy()
	test_nyx_character_and_combat()
	test_career_modal_ui()

	print("\n=======================================================")
	print("🎉 TODOS LOS TESTS DE PRE-ALPHA 5 PASARON EXITOSAMENTE!")
	print("=======================================================\n")
	get_tree().quit(0)

func test_assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("❌ FALLO EN TEST: %s" % message)
		printerr("❌ FALLO EN TEST: %s" % message)
		assert(condition, message)
	else:
		print("  ✓ %s" % message)

# ── 1. AUTIO-AIM FIX ─────────────────────────────────────────────────────────
func test_autoaim_fix() -> void:
	print("[1/6] Verificando Corrección de Auto-Aim...")
	var player = CharacterBody2D.new()
	player.set_script(preload("res://scenes/combat/player/player.gd"))
	var hb = Node2D.new()
	hb.name = "HitboxCore"
	player.add_child(hb)
	var wc = Node2D.new()
	wc.name = "WeaponController"
	wc.set_script(preload("res://scenes/combat/player/weapon_controller.gd"))
	player.add_child(wc)
	add_child(player)

	# Rango base amplio de 850px
	var r: float = float(wc.get_autoaim_range())
	test_assert(r >= 850.0, "El rango de auto-apuntado debe tener base de al menos 850px (actual: %.1f)" % r)

	# Dirección inicial memorizada
	wc.last_known_target_dir = Vector2.RIGHT
	player.velocity = Vector2.DOWN * 300.0 # Nave huyendo hacia abajo

	# Cuando no hay enemigos, debe retornar la dirección memorizada, NO la velocidad de huida
	var aim_info = wc._get_passive_aim_info()
	test_assert(aim_info.direction == Vector2.RIGHT, "Auto-aim no debe disparar hacia atrás/velocidad de huida cuando no hay enemigos visibles")

	player.queue_free()

# ── 2. SATELLITE ALERT & PING ───────────────────────────────────────────────
func test_satellite_alert_and_ping() -> void:
	print("[2/6] Verificando Alerta y Ping Sonar del Satélite...")
	var indicator_scene: PackedScene = preload("res://scenes/ui/hud/satellite_edge_indicator.tscn")
	var indicator = indicator_scene.instantiate()
	add_child(indicator)
	test_assert(indicator.PING_INTERVAL == 10.0, "El intervalo de sonar ping del satélite debe ser 10s")

	indicator.set_target(Vector2(1000, 1000), 1)
	test_assert(indicator.has_satellite == true, "set_target activa el rastreador de satélite")
	test_assert(indicator.ping_timer == 0.0, "set_target resetea ping_timer a 0.0")

	indicator.trigger_ping()
	test_assert(indicator._ping_ring_alpha == 1.0, "trigger_ping inicia la onda holográfica expansiva")

	indicator.clear_target()
	test_assert(indicator.has_satellite == false, "clear_target desactiva satélite")
	indicator.queue_free()

	# Satélite baliza en mundo
	var beacon_scene: PackedScene = preload("res://scenes/combat/satellite/satellite_beacon.tscn")
	var beacon = beacon_scene.instantiate()
	add_child(beacon)
	test_assert(beacon.PING_INTERVAL == 10.0, "SatelliteBeacon tiene temporizador de ping de 10s")
	beacon.trigger_beacon_ping()
	test_assert(beacon._ping_line != null, "SatelliteBeacon crea y proyecta el anillo holográfico")
	beacon.queue_free()

# ── 3. CAREER STATS & NYX PROGRESSION ───────────────────────────────────────
func test_career_stats_and_nyx_unlock() -> void:
	print("[3/6] Verificando Estadísticas de Carrera y Desbloqueo de Nyx...")
	var career = SaveManager.get_career_stats()
	test_assert(career.has("total_time_survived"), "career_stats debe incluir total_time_survived")
	test_assert(career.has("total_bosses_killed"), "career_stats debe incluir total_bosses_killed")
	test_assert(career.has("total_runs_played"), "career_stats debe incluir total_runs_played")

	# Probar registro de fin de run
	SaveManager.record_career_run_end({
		"time_survived": 120.0,
		"credits_earned": 50,
		"biomass_earned": 10,
		"enemies_killed": 40,
		"satellites_collected": 2,
		"victory": false
	})
	var updated_career = SaveManager.get_career_stats()
	test_assert(updated_career["total_runs_played"] >= 1, "record_career_run_end incrementa total_runs_played")

	# Simular derrota de jefes hasta 10 para desbloquear a Nyx
	var prof = SaveManager.load_profile()
	var prev_bosses = int(updated_career.get("total_bosses_killed", 0))
	for i in range(10 - prev_bosses):
		SaveManager.record_boss_kill()

	test_assert(SaveManager.is_character_unlocked(&"nyx") == true, "Al derrotar 10 jefes se debe desbloquear a Nyx")

# ── 4. RAINBOW ENEMY (LOOT GOBLIN) ──────────────────────────────────────────
func test_rainbow_enemy() -> void:
	print("[4/6] Verificando Enemigo Arcoíris (Loot Goblin)...")
	var rainbow_scene: PackedScene = preload("res://scenes/combat/enemies/rainbow_enemy.tscn")
	test_assert(rainbow_scene != null, "Escena de rainbow_enemy.tscn debe existir")

	var rainbow_enemy = rainbow_scene.instantiate()
	add_child(rainbow_enemy)
	test_assert(rainbow_enemy.enemy_id == &"enemy_rainbow", "ID del enemigo debe ser enemy_rainbow")
	test_assert(rainbow_enemy.max_health >= 300.0, "Enemigo arcoíris debe tener alta vida (actual: %.1f)" % rainbow_enemy.max_health)
	test_assert(rainbow_enemy.move_speed >= 380.0, "Enemigo arcoíris debe ser muy veloz para escapar (actual: %.1f)" % rainbow_enemy.move_speed)
	test_assert(rainbow_enemy.credits_reward >= 200, "Debe otorgar gran botín de créditos (actual: %d C)" % rainbow_enemy.credits_reward)

	# Simular muerte y nivel instantáneo para el jugador
	var test_player = CharacterBody2D.new()
	test_player.set_script(preload("res://scenes/combat/player/player.gd"))
	var hb = Node2D.new()
	hb.name = "HitboxCore"
	test_player.add_child(hb)
	var wc = Node2D.new()
	wc.name = "WeaponController"
	wc.set_script(preload("res://scenes/combat/player/weapon_controller.gd"))
	test_player.add_child(wc)
	add_child(test_player)

	test_player.current_level = 1
	test_player.current_exp = 5.0
	test_player.exp_to_next = 40.0
	rainbow_enemy.player = test_player

	rainbow_enemy._on_die_extra()
	test_assert(test_player.current_level >= 2, "La muerte del enemigo arcoíris debe otorgar un nivel completo instantáneo")

	test_player.queue_free()
	rainbow_enemy.queue_free()

# ── 5. NYX CHARACTER & MELEE COMBAT ─────────────────────────────────────────
func test_nyx_character_and_combat() -> void:
	print("[5/6] Verificando Heroína Nyx, Arma Melee y Dash Cortante...")
	var roster = CharacterData.load_roster()
	test_assert(roster.has(&"nyx"), "El roster debe incluir a la heroína Nyx")

	var nyx_data: CharacterData = roster[&"nyx"]
	test_assert(nyx_data.display_name == "Nyx", "Nombre de display debe ser Nyx")
	test_assert(nyx_data.starting_weapon != null, "Nyx debe tener su arma inicial asignada")
	test_assert(nyx_data.starting_weapon.weapon_id == &"crescent_blade", "El arma inicial debe ser crescent_blade")

	# Probar CrescentSlash (escala de golpes en ráfaga con projectile_count)
	var slash_scene: PackedScene = preload("res://scenes/combat/weapons/crescent_slash.tscn")
	test_assert(slash_scene != null, "Escena crescent_slash.tscn debe existir")

	var slash = slash_scene.instantiate()
	add_child(slash)
	var ctx := HitContext.new()
	ctx.final_damage = 50.0
	slash.setup(Vector2.ZERO, Vector2.RIGHT, ctx, 3, 1.0)
	test_assert(slash.flurry_count == 3, "CrescentSlash debe configurar la cantidad de tajos según projectiles_count (3 cortes)")
	slash.queue_free()

	# Probar CrescentCyclone (360° sweep)
	var cyclone_scene: PackedScene = preload("res://scenes/combat/weapons/crescent_cyclone.tscn")
	test_assert(cyclone_scene != null, "Escena crescent_cyclone.tscn debe existir")
	var cyclone = cyclone_scene.instantiate()
	add_child(cyclone)
	cyclone.setup(Vector2.ZERO, ctx, 1.0)
	test_assert(cyclone.max_radius >= 200.0, "CrescentCyclone barre en radio 360°")
	cyclone.queue_free()

	# Probar DimensionalCutLine
	var cut_scene: PackedScene = preload("res://scenes/combat/player/dash_effects/dimensional_cut_line.tscn")
	test_assert(cut_scene != null, "Escena dimensional_cut_line.tscn debe existir")
	var cut_line = cut_scene.instantiate()
	add_child(cut_line)
	cut_line.setup(Vector2(0, 0), Vector2(250, 0), null, ctx)
	test_assert(cut_line.cut_thickness >= 30.0, "Línea de corte dimensional tiene grosor de corte adecuado")
	cut_line.queue_free()

# ── 6. CAREER MODAL UI ──────────────────────────────────────────────────────
func test_career_modal_ui() -> void:
	print("[6/6] Verificando UI de Ventana de Carrera y Pestañas...")
	var modal_scene: PackedScene = preload("res://scenes/ui/highscores/highscores_modal.tscn")
	test_assert(modal_scene != null, "Escena de highscores_modal.tscn debe existir")

	var modal = modal_scene.instantiate() as HighscoresModal
	add_child(modal)
	modal.open_career()

	test_assert(modal.current_tab == 0, "open_career abre la pestaña de Carrera (tab 0)")
	test_assert(modal.career_container != null and modal.career_container.visible == true, "career_container debe ser visible en tab 0")

	modal._switch_tab(1)
	test_assert(modal.current_tab == 1, "_switch_tab(1) conmuta a Salón de la Fama")
	test_assert(modal.scroll_container.visible == true, "scroll_container de records debe ser visible en tab 1")

	modal.queue_free()
