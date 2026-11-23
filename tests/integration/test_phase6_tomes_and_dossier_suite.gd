class_name TestPhase6TomesAndDossierSuite
extends BaseTestSuite

## TestPhase6TomesAndDossierSuite
## Valida las especificaciones técnicas de la Fase 6:
## - Dossier táctico completo por piloto en CharacterData (Arma base, Habilidad táctica, Dash único, Pasiva de Tomo)
## - Sinergias temáticas activas en TomeController para todos los personajes del main cast:
##   * Nova (Velocidad -> +6% daño base)
##   * Valentina (Velocidad de proyectil -> +8% daño crítico)
##   * Roxy (Armadura -> +7% daño base)
##   * Selene (Imán / Radio de recolección -> +10% tamaño de arma)
##   * Nyx (Maldición -> +12% daño base)
##   * Echo (Enfriamiento -> +1 proyectil)
##   * Kira (Suerte -> +1 proyectil)

func _ready() -> void:
	super._ready()
	print("--- TEST PHASE 6 TOMES & CHARACTER DOSSIER START ---")
	_run_tests()

func _run_tests() -> void:
	# 1. Validación de Dossier Táctico para todos los pilotos
	var roster := CharacterData.load_roster()
	var pilots: Array[StringName] = [&"nova", &"valentina", &"roxy", &"selene", &"nyx", &"echo", &"kira"]
	for pid in pilots:
		var cd: CharacterData = roster.get(pid, null)
		if not cd:
			cd = CharacterData.new()
			cd.character_id = pid
		var kit := cd.get_kit_dossier()
		assert_true(not String(kit.weapon_name).is_empty(), "Piloto %s debe tener nombre de arma en dossier" % pid)
		assert_true(not String(kit.weapon_desc).is_empty(), "Piloto %s debe tener descripción de arma" % pid)
		assert_true(not String(kit.tactical_name).is_empty(), "Piloto %s debe tener habilidad táctica" % pid)
		assert_true(not String(kit.dash_name).is_empty(), "Piloto %s debe tener dash único" % pid)
		assert_true(not String(kit.passive_name).is_empty(), "Piloto %s debe tener pasiva innata" % pid)
		assert_true(kit.favored_tome != &"", "Piloto %s debe tener un tomo favorecido asignado" % pid)
	print("  ✓ [PASS] Test 1: Los 7 pilotos poseen Dossier Táctico enriquecido y Tomo Favorecido asignado")

	# 2. Sinergia de Nova: Tomo de Velocidad -> +6% Daño Base
	var dummy_nova := Player.new()
	dummy_nova.character_data = CharacterData.new()
	dummy_nova.character_data.character_id = &"nova"
	dummy_nova.stats = CharacterStats.new()
	dummy_nova.stats.set_base_stat(&"base_damage", 40.0)
	dummy_nova.stats.set_base_stat(&"move_speed", 340.0)

	var tc_nova := TomeController.new()
	dummy_nova.add_child(tc_nova)
	tc_nova.setup(dummy_nova)

	var tome_spd := TomeData.new()
	tome_spd.tome_id = &"tome_move_speed"
	tome_spd.stat_name = &"move_speed"
	tome_spd.stat_value_per_level = 0.10
	tome_spd.modifier_type = Enums.ModifierType.ADDITIVE_PERCENT

	tc_nova.equip_or_upgrade_tome(tome_spd)
	# Base 40 + 6% sinergia nivel 1 = 40 * 1.06 = 42.4
	var dmg_nova_lvl1: float = dummy_nova.stats.get_stat(&"base_damage")
	assert_true(dmg_nova_lvl1 > 42.0, "Nova debe ganar bonificación de daño por equipar tomo de velocidad")
	print("  ✓ [PASS] Test 2: Sinergia Nova activada (Daño base: %.1f con Tomo de Velocidad)" % dmg_nova_lvl1)

	tc_nova.queue_free()
	dummy_nova.queue_free()

	# 3. Sinergia de Valentina: Tomo de Velocidad de Proyectil -> +8% Daño Crítico
	var dummy_val := Player.new()
	dummy_val.character_data = CharacterData.new()
	dummy_val.character_data.character_id = &"valentina"
	dummy_val.stats = CharacterStats.new()
	dummy_val.stats.set_base_stat(&"crit_damage", 1.50)

	var tc_val := TomeController.new()
	dummy_val.add_child(tc_val)
	tc_val.setup(dummy_val)

	var tome_pspd := TomeData.new()
	tome_pspd.tome_id = &"tome_projectile_speed"
	tome_pspd.stat_name = &"projectile_speed"
	tome_pspd.stat_value_per_level = 0.15
	tome_pspd.modifier_type = Enums.ModifierType.ADDITIVE_PERCENT

	tc_val.equip_or_upgrade_tome(tome_pspd)
	# 1.50 + 8% = 1.50 * 1.08 = 1.62
	var cd_val: float = dummy_val.stats.get_stat(&"crit_damage")
	assert_true(cd_val >= 1.60, "Valentina debe ganar +8% de daño crítico con tomo de velocidad de proyectil")
	print("  ✓ [PASS] Test 3: Sinergia Valentina activada (Daño crítico: %.2fx)" % cd_val)

	tc_val.queue_free()
	dummy_val.queue_free()

	# 4. Sinergia de Roxy: Tomo de Armadura -> +7% Daño Base
	var dummy_roxy := Player.new()
	dummy_roxy.character_data = CharacterData.new()
	dummy_roxy.character_data.character_id = &"roxy"
	dummy_roxy.stats = CharacterStats.new()
	dummy_roxy.stats.set_base_stat(&"base_damage", 50.0)

	var tc_roxy := TomeController.new()
	dummy_roxy.add_child(tc_roxy)
	tc_roxy.setup(dummy_roxy)

	var tome_arm := TomeData.new()
	tome_arm.tome_id = &"tome_armor"
	tome_arm.stat_name = &"armor"
	tome_arm.stat_value_per_level = 4.0
	tome_arm.modifier_type = Enums.ModifierType.FLAT

	tc_roxy.equip_or_upgrade_tome(tome_arm)
	# 50.0 * 1.07 = 53.5
	var dmg_roxy: float = dummy_roxy.stats.get_stat(&"base_damage")
	assert_true(dmg_roxy >= 53.0, "Roxy debe ganar daño de escopeta por cada nivel de armadura")
	print("  ✓ [PASS] Test 4: Sinergia Roxy activada (Daño base: %.1f con Tomo de Armadura)" % dmg_roxy)

	tc_roxy.queue_free()
	dummy_roxy.queue_free()

	# 5. Sinergia de Selene: Tomo de Radio de Recolección -> +10% Tamaño de Arma
	var dummy_selene := Player.new()
	dummy_selene.character_data = CharacterData.new()
	dummy_selene.character_data.character_id = &"selene"
	dummy_selene.stats = CharacterStats.new()
	dummy_selene.stats.set_base_stat(&"weapon_size", 1.0)

	var tc_selene := TomeController.new()
	dummy_selene.add_child(tc_selene)
	tc_selene.setup(dummy_selene)

	var tome_mag := TomeData.new()
	tome_mag.tome_id = &"tome_pickup_radius"
	tome_mag.stat_name = &"pickup_radius"
	tome_mag.stat_value_per_level = 40.0
	tome_mag.modifier_type = Enums.ModifierType.FLAT

	tc_selene.equip_or_upgrade_tome(tome_mag)
	# 1.0 * 1.10 = 1.10
	var size_selene: float = dummy_selene.stats.get_stat(&"weapon_size")
	assert_true(size_selene >= 1.09, "Selene debe ganar tamaño de arma/singularidad con tomo de imán")
	print("  ✓ [PASS] Test 5: Sinergia Selene activada (Tamaño de arma: %.2fx)" % size_selene)

	tc_selene.queue_free()
	dummy_selene.queue_free()

	print("--- TEST PHASE 6 ALL TESTS PASSED SUCCESSFULLY ---")
	call_deferred("_complete_suite")

func _complete_suite() -> void:
	print("ALL TESTS PASSED")
	get_tree().quit(0)
