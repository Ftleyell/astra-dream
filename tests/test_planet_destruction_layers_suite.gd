extends SceneTree

# Test suite enfocado: Destrucción de 2 capas de Planetas (Corteza + Manto), recolección al tocar el núcleo y túnel bidireccional

var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("\n=======================================================")
	print("ASTRA DREAM - TEST SUITE: PLANET DESTRUCTION & TUNNEL")
	print("=======================================================")
	call_deferred("_run_tests")

func _assert(condition: bool, test_name: String, details: String = "") -> void:
	if condition:
		passed_tests += 1
		print("  [PASS] %s%s" % [test_name, " (" + details + ")" if details != "" else ""])
	else:
		failed_tests += 1
		print("  [FAIL] %s - %s" % [test_name, details])

func _run_tests() -> void:
	# 1. Carga de escenas y recursos
	var planet_scene: PackedScene = load("res://scenes/combat/environment/planet.tscn")
	_assert(planet_scene != null, "Carga de planet.tscn")

	var verdant_data: PlanetData = load("res://data/planets/verdant_planet.tres")
	_assert(verdant_data != null and verdant_data.interior_texture != null, "PlanetData verdant con interior_texture")

	var planet: Planet = planet_scene.instantiate() as Planet
	planet.planet_data = verdant_data
	planet.disable_defenders = true
	root.add_child(planet)

	# Forzar proceso de inicialización
	_assert(planet.mantle_sprite != null, "MantleSprite presente")
	_assert(planet.crust_sprite != null, "CrustSprite presente")
	_assert(planet.planet_core != null, "PlanetCore presente")
	_assert(planet.crust_sprite.material is ShaderMaterial, "CrustSprite ShaderMaterial asignado")
	_assert(planet.mantle_sprite.material == null, "MantleSprite mantiene textura de fondo sin modificar (sin shader destructivo)")
	_assert(planet.mantle_sprite.z_index < planet.planet_core.z_index, "MantleSprite en el fondo (z_index=0) detrás del núcleo (z_index=1)")
	_assert(planet.planet_core.z_index < planet.crust_sprite.z_index, "PlanetCore detrás de la corteza (z_index=2)")

	# Verificar sectores generados
	var crust_container: Node2D = planet.crust_sectors_container
	var mantle_container: Node2D = planet.mantle_sectors_container
	_assert(crust_container != null and crust_container.get_child_count() == 8, "8 sectores de corteza generados")
	_assert(mantle_container != null and mantle_container.get_child_count() == 8, "8 sectores de manto generados")

	var sec_c_0: PlanetSector = crust_container.get_child(0) as PlanetSector
	var sec_m_0: PlanetSector = mantle_container.get_child(0) as PlanetSector
	_assert(sec_c_0 != null and sec_m_0 != null, "Sectores 0 instanciados")

	# 2. Romper Sector 0 desde afuera (Corteza 0 -> Manto 0)
	sec_c_0.take_damage(200.0)
	var crust_mat := planet.crust_sprite.material as ShaderMaterial
	var dmg_arr: Array = crust_mat.get_shader_parameter("sector_damage")
	_assert(dmg_arr[0] >= 1.0, "Corteza 0 destruida y shader al 100%")
	_assert(sec_c_0.is_dead, "Corteza 0 marcada como is_dead")

	sec_m_0.take_damage(800.0)
	_assert(sec_m_0.is_dead, "Manto 0 destruido y colisión abierta hacia el núcleo")
	_assert(planet.mantle_sprite.material == null, "Textura de fondo se mantiene intacta")

	# 3. Recolección automática del Núcleo al tocarlo (sin prompt de [E] ni error de InputMap)
	var core := planet.planet_core
	_assert(core != null and not core.is_digitized, "Núcleo intacto esperando contacto")

	var dummy_player := CharacterBody2D.new()
	dummy_player.add_to_group("player")
	root.add_child(dummy_player)
	dummy_player.global_position = core.global_position

	# Al entrar en contacto con el área del núcleo, se digitaliza inmediatamente
	core._on_body_entered(dummy_player)
	_assert(core.is_digitized, "Núcleo recolectado y digitalizado automáticamente al tocarlo")

	# 4. Proseguir rompiendo el planeta desde adentro hacia el otro lado (Sector 4 opuesto)
	var sec_m_4: PlanetSector = mantle_container.get_child(4) as PlanetSector
	var sec_c_4: PlanetSector = crust_container.get_child(4) as PlanetSector
	_assert(sec_m_4 != null and not sec_m_4.is_dead, "Manto 4 (lado opuesto) existe")
	_assert(sec_c_4 != null and not sec_c_4.is_dead, "Corteza 4 (lado opuesto) existe")

	# Atacar Manto 4 desde el interior del planeta
	var init_m4_hp: float = sec_m_4.health_component.current_health
	sec_m_4.take_damage(60.0)
	_assert(sec_m_4.health_component.current_health < init_m4_hp, "Manto 4 recibe daño atacando desde el interior")

	sec_m_4.take_damage(800.0)
	_assert(sec_m_4.is_dead, "Manto 4 destruido desde el interior")

	# Atacar Corteza 4 desde el interior hacia afuera
	var init_c4_hp: float = sec_c_4.health_component.current_health
	sec_c_4.take_damage(50.0)
	_assert(sec_c_4.health_component.current_health < init_c4_hp, "Corteza 4 recibe daño atacando desde el interior")
	dmg_arr = crust_mat.get_shader_parameter("sector_damage")
	_assert(dmg_arr[4] > 0.0, "Corteza 4 refleja daño en shader atacando desde adentro", "dmg: %.2f" % dmg_arr[4])

	sec_c_4.take_damage(200.0)
	_assert(sec_c_4.is_dead, "Corteza 4 destruida, abriendo el túnel completo al otro lado")
	dmg_arr = crust_mat.get_shader_parameter("sector_damage")
	_assert(dmg_arr[4] >= 1.0, "Corteza 4 shader al 100% (túnel de salida abierto)")

	print("\n=======================================================")
	print("TEST SUMMARY: %d Passed, %d Failed" % [passed_tests, failed_tests])
	print("=======================================================")

	if failed_tests == 0:
		print("SUCCESS: CORE TOUCH COLLECTION & BI-DIRECTIONAL TUNNELING VERIFIED!")
	
	planet.queue_free()
	dummy_player.queue_free()
	quit(0 if failed_tests == 0 else 1)
