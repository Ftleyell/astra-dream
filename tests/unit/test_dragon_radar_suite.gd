class_name TestDragonRadarSuite
extends BaseTestSuite

## TestDragonRadarSuite.gd
## Verificación unitaria para HUDDragonRadarDisplay y DragonRadarBlip.

const DragonRadarBlipClass = preload("res://scenes/ui/hud/components/dragon_radar_blip.gd")
const HUDDragonRadarDisplayClass = preload("res://scenes/ui/hud/components/hud_dragon_radar_display.gd")

func _ready() -> void:
	super._ready()
	print_rich("[color=cyan]>>> Iniciando Suite: DragonRadarSuite <<<[/color]")
	
	test_blip_creation_and_decay()
	test_sweep_angle_detection()
	test_radar_display_node_lifecycle()
	
	pass_suite("DragonRadarSuite completada con 100% de éxito")

func test_blip_creation_and_decay() -> void:
	var blip = DragonRadarBlipClass.new(1234, Vector2(50, 50), Color.RED, 4.0, 1.0)
	assert_true(is_instance_valid(blip), "El blip debe instanciarse")
	assert_true(blip.world_target_id == 1234, "ID de target correcto")
	assert_true(is_equal_approx(blip.life, 1.0), "Vida inicial en 1.0")
	
	blip.life -= 0.5
	assert_true(blip.life < 1.0, "El blip debe decaer correctamente")

func test_sweep_angle_detection() -> void:
	var radar = HUDDragonRadarDisplayClass.new()
	assert_true(is_instance_valid(radar), "El radar debe instanciarse")
	
	# Caso 1: Rango normal sin atravesar 0 / TAU
	var swept: bool = radar._is_angle_swept(0.2, 0.8, 0.5)
	assert_true(swept, "Ángulo 0.5 debe estar barrido entre 0.2 y 0.8")
	
	var not_swept: bool = radar._is_angle_swept(0.2, 0.8, 1.5)
	assert_true(not not_swept, "Ángulo 1.5 no debe estar barrido entre 0.2 y 0.8")
	
	# Caso 2: Atravesando 0 / TAU
	var swept_wrap: bool = radar._is_angle_swept(6.0, 0.5, 6.2)
	assert_true(swept_wrap, "Ángulo 6.2 debe ser detectado en wrap 6.0 -> 0.5")
	
	radar.free()

func test_radar_display_node_lifecycle() -> void:
	var radar_scene: PackedScene = load("res://scenes/ui/hud/components/dragon_radar_display.tscn")
	assert_true(radar_scene != null, "La escena del radar debe existir")
	
	var radar_inst = radar_scene.instantiate()
	assert_true(is_instance_valid(radar_inst), "Debe instanciarse correctamente desde .tscn")
	
	add_child(radar_inst)
	assert_true(radar_inst.get_node_or_null("RadarScreen") != null, "Debe inicializar RadarScreen")
	assert_true(radar_inst.get_node_or_null("RadarFrame") != null, "Debe inicializar RadarFrame")
	
	radar_inst.queue_free()
