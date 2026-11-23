extends BaseTestSuite

## TestTomesAndInfiniteWeaponsSuite
## Suite de pruebas para:
## 1. Catálogo de 18 Tomos y recursos .tres.
## 2. Progresión infinita de armas con retornos decrecientes y proyectiles extra.
## 3. Componente TomeController (cap de 4 ranuras y aplicación de modificadores).
## 4. Generador de Level Up: 100% mejoras cuando se equipan 4 armas y 4 tomos.
## 5. Leash cuántico de cofres (>1500 px reubicación adelante del jugador).
## 6. Modal de selección de tomos y cota mínima de 6 tomos obligatorios.

const TomeCatalogScript = preload("res://data/tomes/tome_catalog.gd")
const TomeDataScript = preload("res://data/tomes/tome_data.gd")
const WeaponInstanceDataScript = preload("res://data/weapons/weapon_instance_data.gd")
const WeaponCatalogScript = preload("res://data/weapons/weapon_catalog.gd")
const TomeControllerScript = preload("res://scenes/combat/player/tome_controller.gd")
const LevelUpRewardGeneratorScript = preload("res://scenes/ui/level_up/components/level_up_reward_generator.gd")
const LevelUpRewardOptionScript = preload("res://scenes/ui/level_up/components/level_up_reward_option.gd")
const ChestDirectorScript = preload("res://scenes/combat/chests/chest_director.gd")
const TomeSelectionModalScript = preload("res://scenes/ui/character_select/tome_selection_modal.gd")


func _ready() -> void:
	print("\n=======================================================")
	print("[TEST] Testing Tomes, Infinite Weapons & Chest Leash...")
	print("=======================================================\n")

	_test_tome_catalog_and_resources()
	_test_infinite_weapons_and_diminishing_returns()
	_test_tome_controller_and_modifiers()
	_test_level_up_reward_generator_four_slots_guarantee()
	_test_chest_director_quantum_leash()
	_test_tome_selection_modal_min_rule()

	pass_suite("Todas las pruebas de Tomos, Armas Infinitas y Leash pasaron con éxito.")


func _test_tome_catalog_and_resources() -> void:
	print("[1/6] Verifying TomeCatalog and all 18 TomeData resources...")
	assert_true(TomeCatalogScript.ALL_TOME_IDS.size() == 18, "Deben existir exactamente 18 IDs de tomos")

	var all_tomes: Array = TomeCatalogScript.get_all_tomes()
	assert_true(all_tomes.size() == 18, "Se deben haber cargado los 18 tomos desde data/tomes/")

	for tome in all_tomes:
		assert_true(tome != null, "El recurso de tomo no debe ser nulo")
		assert_true(not tome.display_name.is_empty(), "El tomo %s debe tener display_name" % str(tome.tome_id))
		assert_true(not tome.stat_name.is_empty(), "El tomo %s debe apuntar a un stat_name válido" % str(tome.tome_id))
		assert_true(tome.stat_value_per_level > 0.0, "El tomo %s debe tener stat_value_per_level > 0" % str(tome.tome_id))
	print("  ✓ 18 Tomos verificados correctamente.")


func _test_infinite_weapons_and_diminishing_returns() -> void:
	print("[2/6] Verifying Infinite Weapons leveling & asymptotic diminishing returns...")
	var w_data: WeaponData = WeaponCatalogScript.get_weapon_by_id(&"rail_launcher")
	if not w_data:
		w_data = WeaponCatalogScript.load_weapon("res://data/weapons/roster/rail_launcher.tres")
	if not w_data:
		var all_w: Array = WeaponCatalogScript.get_all_weapons()
		assert_true(not all_w.is_empty(), "Debe haber armas en el catálogo")
		w_data = all_w[0] as WeaponData

	var inst := WeaponInstanceDataScript.new(w_data, 1)

	assert_true(is_equal_approx(inst.get_damage_multiplier(), 1.0), "Nivel 1 daño debe ser 1.0")

	# Subir más allá de nivel 5
	inst.level = 5
	var mult_5: float = inst.get_damage_multiplier()
	assert_true(mult_5 > 1.0, "Nivel 5 debe multiplicar el daño")

	inst.level = 10
	var mult_10: float = inst.get_damage_multiplier()
	assert_true(mult_10 > mult_5, "Nivel 10 debe dar más daño que nivel 5")

	inst.level = 50
	var mult_50: float = inst.get_damage_multiplier()
	assert_true(mult_50 > mult_10, "Nivel 50 debe dar más daño que nivel 10")
	assert_true(inst.level == 50, "Nivel debe persistir en 50 sin cap en 5")

	# Ganancia marginal por nivel decrece
	var gain_early: float = (mult_5 - 1.0) / 4.0
	var gain_late: float = (mult_50 - mult_10) / 40.0
	assert_true(gain_early > gain_late, "La progresión tardía debe presentar retornos decrecientes (asintóticos)")
	print("  ✓ Armas infinitas y curva asintótica de retornos decrecientes verificadas.")


func _test_tome_controller_and_modifiers() -> void:
	print("[3/6] Verifying TomeController slots (max 4) and stat modifier application...")
	var player := Player.new()
	var stats := CharacterStats.new()
	stats.set_base_stat(&"base_damage", 20.0)
	stats.set_base_stat(&"attack_speed", 1.0)
	stats.set_base_stat(&"crit_chance", 0.05)
	stats.set_base_stat(&"move_speed", 250.0)
	player.stats = stats

	var tome_ctrl = TomeControllerScript.new()
	tome_ctrl.setup(player)

	# 1. Equipar primer tomo: tome_base_damage (+5 daño por nivel)
	var tome_dmg = TomeCatalogScript.load_tome(&"tome_base_damage")
	assert_true(tome_dmg != null, "tome_base_damage debe existir")
	var equipped: bool = tome_ctrl.equip_or_upgrade_tome(tome_dmg)
	assert_true(equipped, "Debe equipar el tomo con éxito")
	assert_true(tome_ctrl.get_tome_count() == 1, "Debe haber 1 tomo equipado")
	assert_true(tome_ctrl.get_tome_level(&"tome_base_damage") == 1, "Nivel debe ser 1")

	var effective_dmg_lvl1: float = player.stats.get_stat(&"base_damage")
	assert_true(is_equal_approx(effective_dmg_lvl1, 25.0), "Daño efectivo debe ser 20 + 5 = 25")

	# 2. Mejorar tomo a nivel 2
	var upgraded: bool = tome_ctrl.equip_or_upgrade_tome(tome_dmg)
	assert_true(upgraded, "Debe mejorar el tomo con éxito")
	assert_true(tome_ctrl.get_tome_level(&"tome_base_damage") == 2, "Nivel debe ser 2")
	var effective_dmg_lvl2: float = player.stats.get_stat(&"base_damage")
	assert_true(is_equal_approx(effective_dmg_lvl2, 30.0), "Daño efectivo debe ser 20 + 10 = 30")

	# 3. Equipar hasta completar las 4 ranuras
	var t_aspd = TomeCatalogScript.load_tome(&"tome_attack_speed")
	var t_crit = TomeCatalogScript.load_tome(&"tome_crit_chance")
	var t_ms = TomeCatalogScript.load_tome(&"tome_move_speed")
	var t_extra = TomeCatalogScript.load_tome(&"tome_max_health")

	assert_true(tome_ctrl.equip_or_upgrade_tome(t_aspd), "Debe equipar ranura 2")
	assert_true(tome_ctrl.equip_or_upgrade_tome(t_crit), "Debe equipar ranura 3")
	assert_true(tome_ctrl.equip_or_upgrade_tome(t_ms), "Debe equipar ranura 4")
	assert_true(tome_ctrl.is_full(), "TomeController debe reportar ranuras llenas (4/4)")

	# 4. Intentar equipar un 5to tomo distinto cuando está lleno
	var fifth_res: bool = tome_ctrl.equip_or_upgrade_tome(t_extra)
	assert_true(not fifth_res, "No debe permitir equipar un 5to tomo")
	assert_true(tome_ctrl.get_tome_count() == 4, "Debe mantenerse en 4 tomos")

	# 5. Serialización y deserialización
	var serialized: Dictionary = tome_ctrl.serialize()
	var fresh_ctrl = TomeControllerScript.new()
	fresh_ctrl.setup(player)
	fresh_ctrl.deserialize(serialized)
	assert_true(fresh_ctrl.get_tome_count() == 4, "Debe restaurar los 4 tomos")
	assert_true(fresh_ctrl.get_tome_level(&"tome_base_damage") == 2, "Debe restaurar el nivel 2 del tomo de daño")

	print("  ✓ TomeController y aplicación de modificadores verificados.")
	player.queue_free()
	tome_ctrl.queue_free()
	fresh_ctrl.queue_free()


func _test_level_up_reward_generator_four_slots_guarantee() -> void:
	print("[4/6] Verifying LevelUpRewardGenerator (100% upgrades when 4 weapons & 4 tomes equipped)...")
	var player := Player.new()
	player.stats = CharacterStats.new()

	var w_ctrl := WeaponController.new()
	player.weapon_controller = w_ctrl

	var t_ctrl = TomeControllerScript.new()
	t_ctrl.setup(player)
	player.tome_controller = t_ctrl

	# Equipar 4 armas
	var all_w: Array = WeaponCatalogScript.get_all_weapons()
	w_ctrl.equipped_weapons.clear()
	for i in range(mini(4, all_w.size())):
		var inst := WeaponInstanceDataScript.new(all_w[i] as WeaponData, 1)
		w_ctrl.equipped_weapons.append(inst)

	# Equipar 4 tomos
	var all_t: Array = TomeCatalogScript.get_all_tomes()
	for i in range(4):
		t_ctrl.equip_or_upgrade_tome(all_t[i])

	var active_ids: Array[StringName] = TomeCatalogScript.ALL_TOME_IDS.duplicate()
	var options: Array = LevelUpRewardGeneratorScript.generate_reward_options(player, active_ids, 3)

	assert_true(options.size() == 3, "Debe retornar 3 opciones")
	for opt in options:
		assert_true(
			opt.type == LevelUpRewardOptionScript.OptionType.WEAPON_UPGRADE or opt.type == LevelUpRewardOptionScript.OptionType.TOME_UPGRADE,
			"Con 4 armas y 4 tomos, el 100%% de las opciones deben ser MEJORAS (tipo %d)" % opt.type
		)
		assert_true(opt.next_level > opt.current_level, "Cada opción de mejora debe subir de nivel")

	print("  ✓ LevelUpRewardGenerator garantiza 100% opciones de mejora con ranuras llenas.")
	player.queue_free()
	w_ctrl.queue_free()
	t_ctrl.queue_free()


func _test_chest_director_quantum_leash() -> void:
	print("[5/6] Verifying ChestDirector quantum leash relocation (>1800 px)...")
	var director := ChestDirectorScript.new()
	var chest := SpatialChest.new()
	chest.global_position = Vector2(2400, 0) # Lejos del jugador (>1800 px)
	director.active_chests.append(chest)

	# Simular jugador en el origen moviéndose hacia la derecha
	var dummy_parent := Node2D.new()
	var dummy_player := Node2D.new()
	dummy_player.set("velocity", Vector2(300, 0))
	dummy_parent.set("player", dummy_player)

	director._relocate_distant_chests(Vector2.ZERO, dummy_parent)

	var new_dist: float = chest.global_position.distance_to(Vector2.ZERO)
	assert_true(new_dist <= 1500.0 and new_dist >= 1100.0, "El cofre reubicado debe estar entre 1150 y 1450 px (distancia medida: %.1f)" % new_dist)

	chest.free()
	dummy_player.free()
	dummy_parent.free()
	director.free()
	print("  ✓ Leash cuántico de cofres verificado.")


func _test_tome_selection_modal_min_rule() -> void:
	print("[6/6] Verifying TomeSelectionModal minimum 6 active tomes constraint...")
	var modal = TomeSelectionModalScript.new()
	add_child(modal)

	modal.current_character_id = &"test_pilot"
	# Inicializar con 6 tomos
	var test_ids: Array[StringName] = [
		&"tome_base_damage",
		&"tome_attack_speed",
		&"tome_crit_chance",
		&"tome_move_speed",
		&"tome_max_health",
		&"tome_armor"
	]
	modal.active_tome_ids = test_ids
	assert_true(modal.active_tome_ids.size() == 6, "Debe iniciar con 6 tomos")

	# Intentar desactivar uno de los 6 tomos activos (debe bloquearse)
	modal._on_card_pressed(&"tome_base_damage")
	assert_true(modal.active_tome_ids.size() == 6, "Debe bloquear la desactivación para no bajar de 6 tomos")
	assert_true(modal.active_tome_ids.has(&"tome_base_damage"), "tome_base_damage debe permanecer activo")
	assert_true(not modal.warning_label.text.is_empty(), "Debe mostrar advertencia de mínimo 6 tomos")

	# Probar restauración de todos
	modal._on_reset_pressed()
	assert_true(modal.active_tome_ids.size() == 18, "Reset debe restaurar los 18 tomos activos")

	modal.free()
	print("  ✓ Restricción de cota mínima de 6 tomos en TomeSelectionModal verificada.")
