extends Node

func _ready() -> void:
	print("\n==========================================")
	print("[TEST] Testing 10 Weapons & 6-Slot System...")
	print("==========================================")

	# 1. Verificar carga de las 10 armas (.tres)
	print("\n[1/4] Verifying all 10 weapon resources...")
	var roster_weapon_paths := [
		"res://data/weapons/roster/rail_launcher.tres",
		"res://data/weapons/roster/sniper_rifle.tres",
		"res://data/weapons/roster/hive_cannon.tres",
		"res://data/weapons/roster/singularity_pulsar.tres",
		"res://data/weapons/roster/titan_shotgun.tres",
		"res://data/weapons/roster/tesla_arc.tres"
	]
	var shop_weapon_paths := [
		"res://data/weapons/shop/nova_flak.tres",
		"res://data/weapons/shop/dimensional_blade.tres",
		"res://data/weapons/shop/solar_beam.tres",
		"res://data/weapons/shop/cluster_submunition.tres"
	]

	var all_paths := roster_weapon_paths + shop_weapon_paths
	assert(all_paths.size() == 10, "Debe haber 10 rutas de armas")

	var loaded_weapons: Array[WeaponData] = []
	for p in all_paths:
		assert(ResourceLoader.exists(p), "El archivo de arma no existe: " + p)
		var w = load(p) as WeaponData
		assert(w != null, "No se pudo cargar como WeaponData: " + p)
		print("  ✓ Arma cargada: %s [%s] (Costo: %d C, Tipo Activo: %s, Tipo Pasivo: %s)" % [
			w.weapon_name, w.weapon_id, w.cost, w.active_behavior_type, w.passive_behavior_type
		])
		loaded_weapons.append(w)

	# 2. Verificar que los 6 pilotos tienen su starting_weapon asignada
	print("\n[2/4] Verifying Pilot Roster starting_weapon configuration...")
	var pilots := ["nova", "valentina", "kira", "selene", "roxy", "echo"]
	for pid in pilots:
		var cpath := "res://data/characters/roster/%s.tres" % pid
		var cdata = load(cpath) as CharacterData
		assert(cdata != null, "No se pudo cargar piloto: " + cpath)
		assert(cdata.starting_weapon != null, "El piloto %s no tiene starting_weapon asignada" % pid)
		print("  ✓ Piloto %s -> Arma inicial: %s" % [cdata.display_name, cdata.starting_weapon.weapon_name])

	# 3. Probar WeaponController con 6 slots simultáneos
	print("\n[3/4] Testing WeaponController multi-weapon (6 slots) & duplicates...")
	var controller := WeaponController.new()
	add_child(controller)

	# Limpiar default y agregar 6 armas diferentes
	controller.equipped_weapons.clear()
	for i in range(6):
		var ok := controller.add_weapon(loaded_weapons[i])
		assert(ok, "Error al equipar arma %d" % i)

	assert(controller.equipped_weapons.size() == 6, "Deben estar equipados exactamente 6 slots")
	print("  ✓ 6 slots equipados con éxito")

	# Intentar equipar una 7ma arma (debe rechazarse por cupo lleno)
	var extra_ok := controller.add_weapon(loaded_weapons[6])
	assert(not extra_ok, "No debe permitir equipar una 7ma arma sin cupo")
	print("  ✓ Límite de 6 slots respetado estrictamente")

	# Probar fusión por duplicado: agregar nuevamente la primera arma
	var initial_lvl := controller.equipped_weapons[0].level
	var initial_dmg := controller.equipped_weapons[0].get_effective_damage()
	var dup_ok := controller.add_weapon(loaded_weapons[0])
	assert(dup_ok, "Comprar duplicado debe retornar true")
	assert(controller.equipped_weapons[0].level == initial_lvl + 1, "El arma debe subir a Nivel 2")
	assert(controller.equipped_weapons[0].get_effective_damage() > initial_dmg, "El daño debe incrementarse con el nivel")
	assert(controller.equipped_weapons.size() == 6, "El número de slots debe permanecer en 6")
	print("  ✓ Fusión por duplicado verificada: Nivel %d -> Daño %s" % [
		controller.equipped_weapons[0].level,
		controller.equipped_weapons[0].get_effective_damage()
	])

	# 4. Probar instanciación de proyectiles y efectos en escena de combate
	print("\n[4/4] Testing projectile scene instantiations...")
	var test_ctx := HitContext.new()
	test_ctx.raw_damage = 50.0
	test_ctx.final_damage = 50.0

	var proj_scene: PackedScene = load("res://scenes/combat/weapons/kinetic_projectile.tscn")
	var proj = proj_scene.instantiate() as KineticProjectile
	proj.setup(Vector2.ZERO, Vector2.RIGHT, test_ctx)
	add_child(proj)
	print("  ✓ KineticProjectile instanciado")

	var vortex_scene: PackedScene = load("res://scenes/combat/weapons/singularity_vortex.tscn")
	var vortex = vortex_scene.instantiate() as SingularityVortex
	vortex.setup(Vector2(100, 100), test_ctx)
	add_child(vortex)
	print("  ✓ SingularityVortex instanciado")

	var shock_scene: PackedScene = load("res://scenes/combat/weapons/shockwave_area.tscn")
	var shock = shock_scene.instantiate() as ShockwaveArea
	shock.setup(Vector2.ZERO, test_ctx)
	add_child(shock)
	print("  ✓ ShockwaveArea instanciado")

	var chain_scene: PackedScene = load("res://scenes/combat/weapons/chain_lightning_effect.tscn")
	var chain = chain_scene.instantiate() as ChainLightningEffect
	chain.setup(Vector2.ZERO, Vector2(100, 0), test_ctx)
	add_child(chain)
	print("  ✓ ChainLightningEffect instanciado")

	var cluster_scene: PackedScene = load("res://scenes/combat/weapons/cluster_grenade.tscn")
	var cluster = cluster_scene.instantiate() as ClusterGrenade
	cluster.setup(Vector2.ZERO, Vector2(80, 80), test_ctx)
	add_child(cluster)
	print("  ✓ ClusterGrenade instanciado")

	var solar_scene: PackedScene = load("res://scenes/combat/weapons/solar_beam.tscn")
	var solar = solar_scene.instantiate() as SolarBeam
	solar.setup(Vector2.ZERO, Vector2.RIGHT, test_ctx)
	add_child(solar)
	print("  ✓ SolarBeam instanciado")

	# 5. Probar exclusividad de carga para el Láser y disparo instantáneo / tap para armas normales
	print("\n[5/5] Testing Laser Charge Exclusivity & Non-Laser Instant Tap-Fire...")
	var echo_controller := WeaponController.new()
	var tesla_res: WeaponData = load("res://data/weapons/roster/tesla_arc.tres")
	echo_controller.weapon_data = tesla_res
	add_child(echo_controller)
	assert(echo_controller.equipped_weapons.size() == 1, "Echo debe tener equipado tesla_arc")
	var tesla_inst := echo_controller.equipped_weapons[0]
	assert(tesla_inst.active_cooldown == 0.0, "Cooldown inicial de tesla debe ser 0")

	# Simular Input pressed con el arma de Echo
	Input.action_press("fire_active")
	echo_controller._handle_active_fire(0.016)
	assert(echo_controller.is_charging == false, "El arma de Echo NO debe cargar")
	assert(echo_controller.charge_timer == 0.0, "Charge timer de Echo debe ser 0")
	assert(tesla_inst.active_cooldown > 0.0, "El arma de Echo debe disparar inmediatamente en tap/press")
	print("  ✓ Arma de Echo dispara instantáneamente al presionar, SIN activar carga")

	Input.action_release("fire_active")
	echo_controller._handle_active_fire(0.016)
	assert(echo_controller.is_charging == false, "Echo permanece sin carga al soltar")
	echo_controller.queue_free()

	# Probar con el Láser de Nova
	var nova_controller := WeaponController.new()
	var rail_res: WeaponData = load("res://data/weapons/roster/rail_launcher.tres")
	nova_controller.weapon_data = rail_res
	add_child(nova_controller)
	var rail_inst := nova_controller.equipped_weapons[0]

	Input.action_press("fire_active")
	nova_controller._handle_active_fire(0.05)
	assert(nova_controller.is_charging == true, "El arma láser DEBE activar la carga al mantener")
	assert(nova_controller.charge_timer > 0.0, "Charge timer de láser debe avanzar")
	assert(rail_inst.active_cooldown == 0.0, "El láser retiene el disparo mientras se carga")
	print("  ✓ Cañón Láser activa y acumula carga correctamente al mantener presionado")

	Input.action_release("fire_active")
	nova_controller._handle_active_fire(0.016)
	assert(nova_controller.is_charging == false, "La carga del láser finaliza al soltar")
	assert(rail_inst.active_cooldown > 0.0, "El láser dispara y entra en cooldown al soltar")
	print("  ✓ Cañón Láser dispara al soltar con carga y entra en cooldown")
	nova_controller.queue_free()

	print("\n==========================================")
	print(">>> ALL WEAPON & MULTI-SLOT TESTS PASSED (100%) <<<")
	print("==========================================\n")
	get_tree().quit(0)
