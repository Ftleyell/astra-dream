class_name TestPilotProceduralFlightSuite
extends BaseTestSuite

## Suite automatizada para validar el sistema de animación procedimental por máscara RGBA,
## cabello dinámico, inercia de piernas y propulsores de plasma soplete.

const PlayerScript = preload("res://scenes/combat/player/player.gd")
const PlayerVisualBuilderScript = preload("res://scenes/combat/player/player_visual_builder.gd")
const SandevistanFlightVFXScript = preload("res://scenes/combat/player/sandevistan_flight_vfx.gd")
const RivalPilotBossScript = preload("res://scenes/combat/bosses/rival_pilot_boss.gd")

func _ready() -> void:
	super._ready()
	_run_all_tests()

func _run_all_tests() -> void:
	print("--- INICIANDO TEST SUITE: ANIMACIÓN PROCEDIMENTAL Y SHADERS DE PILOTOS ---")
	_test_mask_assets_exist()
	_test_roster_character_data_masks_and_hair()
	_test_pilot_specific_hair_parameters()
	_test_unified_shader_resource_validity()
	_test_player_visual_builder_material_setup()
	_test_sandevistan_ghost_pool_optimization()
	_test_rival_pilot_boss_flight_shader_integration()
	
	await get_tree().process_frame
	await get_tree().process_frame
	print("--- TODAS LAS PRUEBAS DE ANIMACIÓN PROCEDIMENTAL PASARON CON ÉXITO ---")
	pass_suite("7/7 pruebas de animación procedimental superadas.")

func _test_mask_assets_exist() -> void:
	var pilots: Array[String] = ["nova", "valentina", "kira", "selene", "roxy", "echo", "nyx"]
	for p_id in pilots:
		var mask_path := "res://assets/characters/ships/ship_%s_mask.png" % p_id
		assert_true(ResourceLoader.exists(mask_path), "La máscara RGBA '%s' debe existir en disco." % mask_path)
	print("✓ Test 1: Las 7 máscaras RGBA existen en el proyecto.")

func _test_roster_character_data_masks_and_hair() -> void:
	var roster: Dictionary[StringName, CharacterData] = CharacterData.load_roster()
	assert_true(roster.size() >= 7, "El roster debe cargar al menos 7 heroínas.")
	for cid in roster.keys():
		var cd: CharacterData = roster[cid]
		assert_true(cd != null, "CharacterData para '%s' no debe ser nulo." % str(cid))
		var mask: Texture2D = cd.get_ship_mask()
		assert_true(mask != null, "La heroína '%s' debe tener una máscara de nave asignada o resoluble." % str(cid))
		assert_true(not cd.hair_direction.is_zero_approx(), "La heroína '%s' debe tener hair_direction no nulo." % str(cid))
		assert_true(cd.hair_wave_frequency > 0.0, "La heroína '%s' debe tener hair_wave_frequency positiva." % str(cid))
		assert_true(cd.hair_amplitude > 0.0, "La heroína '%s' debe tener hair_amplitude positiva." % str(cid))
	print("✓ Test 2: Todo el roster de CharacterData tiene máscara y configuración de peinado válida.")

func _test_pilot_specific_hair_parameters() -> void:
	var roster: Dictionary[StringName, CharacterData] = CharacterData.load_roster()
	var val: CharacterData = roster.get(&"valentina")
	assert_true(val != null, "Valentina debe existir en el roster.")
	assert_true(val.hair_direction.distance_to(Vector2(0.2, 1.0)) < 0.01, "Valentina debe tener hair_direction=(0.2, 1.0).")
	assert_true(is_equal_approx(val.hair_wave_frequency, 24.0), "Valentina debe tener wave_frequency=24.0.")

	var roxy: CharacterData = roster.get(&"roxy")
	assert_true(roxy != null, "Roxy debe existir en el roster.")
	assert_true(roxy.hair_direction.distance_to(Vector2(0.7, -0.7)) < 0.01, "Roxy debe tener hair_direction=(0.7, -0.7).")
	assert_true(is_equal_approx(roxy.hair_wave_frequency, 18.0), "Roxy debe tener wave_frequency=18.0.")
	print("✓ Test 3: Perfiles de peinado específicos de Valentina y Roxy verificados.")

func _test_unified_shader_resource_validity() -> void:
	var shader_path := "res://shaders/exo_pilot_flight.gdshader"
	assert_true(ResourceLoader.exists(shader_path), "El shader maestro debe existir en %s" % shader_path)
	var shader: Shader = load(shader_path) as Shader
	assert_true(shader != null, "El shader maestro exo_pilot_flight debe compilar y cargar como Shader.")
	print("✓ Test 4: Shader maestro exo_pilot_flight compilado y válido.")

func _test_player_visual_builder_material_setup() -> void:
	var roster: Dictionary[StringName, CharacterData] = CharacterData.load_roster()
	var nova_data: CharacterData = roster.get(&"nova")
	assert_true(nova_data != null, "Nova debe estar en el roster.")

	var mock_player := CharacterBody2D.new()
	var builder := PlayerVisualBuilderScript.new()
	builder.apply_visual_theme(mock_player, nova_data)

	var spr: Sprite2D = mock_player.get_node_or_null("ShipSprite") as Sprite2D
	assert_true(spr != null, "ShipSprite debe haber sido instanciado por PlayerVisualBuilder.")
	assert_true(spr.material is ShaderMaterial, "ShipSprite debe poseer un ShaderMaterial.")

	var mat: ShaderMaterial = spr.material as ShaderMaterial
	assert_true(mat.get_shader_parameter("has_mask") == true, "has_mask debe ser true para Nova.")
	assert_true(mat.get_shader_parameter("mask_texture") != null, "mask_texture debe estar asignada.")
	assert_true(mat.get_shader_parameter("enable_thrusters") == true, "enable_thrusters debe ser true.")

	# Validar actualización cinemática de shader
	mock_player.set_meta("current_bank_tilt", 0.8)
	mock_player.set_meta("is_dashing", true)
	builder.update_pilot_shader(mock_player, 0.016, true)

	var leg_bend_val: float = float(mat.get_shader_parameter("leg_bend"))
	assert_true(leg_bend_val < 0.0, "leg_bend debe ser negativo cuando bank_tilt es positivo por inercia centrífuga.")
	var thruster_len: float = float(mat.get_shader_parameter("thruster_length"))
	assert_true(thruster_len >= 0.70, "thruster_length debe sobrecargarse a >= 0.70 durante el dash.")

	mock_player.free()
	print("✓ Test 5: PlayerVisualBuilder configura máscara, pelo, leg_bend y sobrecarga de toberas.")

func _test_sandevistan_ghost_pool_optimization() -> void:
	var mock_spr := Sprite2D.new()
	var vfx: SandevistanFlightVFX = SandevistanFlightVFXScript.new()
	vfx.source_sprite = mock_spr
	add_child(vfx)

	# El pool se inicializa en _ready
	assert_true(vfx._pool.size() == 20, "El pool de Sandevistan debe tener 20 clones estáticos preasignados.")
	for ghost in vfx._pool:
		var mat: ShaderMaterial = ghost.material as ShaderMaterial
		assert_true(mat != null, "Cada clon debe tener un ShaderMaterial.")
		assert_true(mat.get_shader_parameter("has_mask") == false, "Los clones de Sandevistan deben tener has_mask=false.")
		assert_true(mat.get_shader_parameter("enable_thrusters") == false, "Los clones de Sandevistan no deben recalcular toberas.")

	vfx.queue_free()
	mock_spr.free()
	print("✓ Test 6: SandevistanFlightVFX pool optimizado sin cálculo redundante en afterimages.")

func _test_rival_pilot_boss_flight_shader_integration() -> void:
	var rival: RivalPilotBoss = RivalPilotBossScript.new()
	add_child(rival)
	rival.setup_pilot(&"valentina", 3)
	rival._setup_visuals()

	var ship_spr: Sprite2D = rival.get_node_or_null("ShipSprite") as Sprite2D
	assert_true(ship_spr != null, "RivalPilotBoss debe tener ShipSprite.")
	assert_true(ship_spr.material is ShaderMaterial, "RivalPilotBoss debe usar ShaderMaterial.")

	var mat: ShaderMaterial = ship_spr.material as ShaderMaterial
	assert_true(mat.get_shader_parameter("has_mask") == true, "Rival debe tener has_mask=true.")
	assert_true(mat.get_shader_parameter("mask_texture") != null, "Rival debe tener máscara cargada.")

	# Simular giro rápido y verificar inclinación e inercia de piernas
	rival.rotation = 1.5
	rival._update_flight_shader(0.016)
	assert_true(float(mat.get_shader_parameter("bank_tilt")) != 0.0, "Rival debe registrar bank_tilt con velocidad angular.")

	rival.queue_free()
	print("✓ Test 7: RivalPilotBoss integra el shader maestro de vuelo y modula inercia en combate.")
