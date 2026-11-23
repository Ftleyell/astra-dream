extends Node2D

const CinematicDeathSequenceScript = preload("res://scenes/combat/bosses/cinematic_death_sequence.gd")
const CinematicMicroExplosionScript = preload("res://scenes/combat/bosses/cinematic_micro_explosion.gd")
const CinematicResidualDebrisScript = preload("res://scenes/combat/bosses/cinematic_residual_debris.gd")

func _ready() -> void:
	# Temporizador de seguridad para evitar bloqueos
	var safety_timer := get_tree().create_timer(6.0)
	safety_timer.timeout.connect(func():
		printerr("[FATAL] Timeout de seguridad excedido en test_cinematic_death_suite (6s).")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Testing Cinematic Death & Supernova Sequence...")
	print("==========================================\n")

	# 1. Validar escena y componentes del orquestador
	print("[1/4] Verifying CinematicDeathSequence structure...")
	var seq_scene := load("res://scenes/combat/bosses/cinematic_death_sequence.tscn") as PackedScene
	assert(seq_scene != null, "cinematic_death_sequence.tscn debe existir y cargar limpiamente")
	
	var seq: Node2D = seq_scene.instantiate()
	assert(seq != null, "La escena debe instanciarse como CinematicDeathSequence")
	assert(seq.process_mode == Node.PROCESS_MODE_ALWAYS, "CinematicDeathSequence debe tener process_mode ALWAYS")
	add_child(seq)

	var overlay = seq.get_node_or_null("OverlayLayer") as CanvasLayer
	assert(overlay != null, "OverlayLayer debe existir")
	assert(overlay.layer == 125, "OverlayLayer debe tener layer 125 para quedar sobre el juego")

	var shockwave = overlay.get_node_or_null("ShockwaveRect") as ColorRect
	assert(shockwave != null, "ShockwaveRect debe existir")
	assert(shockwave.material is ShaderMaterial, "ShockwaveRect debe tener ShaderMaterial")

	var flash = overlay.get_node_or_null("FlashRect") as ColorRect
	assert(flash != null, "FlashRect debe existir")
	print("  ✓ Estructura de escena, CanvasLayer y ColorRects verificada al 100%")

	# 2. Validar Shaders y Parámetros
	print("\n[2/4] Testing Shaders and Resources...")
	var death_shader = load("res://shaders/boss_energy_death.gdshader") as Shader
	assert(death_shader != null, "boss_energy_death.gdshader debe compilar y cargar")

	var shockwave_shader = load("res://shaders/screen_refraction_shockwave.gdshader") as Shader
	assert(shockwave_shader != null, "screen_refraction_shockwave.gdshader debe compilar y cargar")

	var noise_res = load("res://shaders/death_noise.tres")
	assert(noise_res != null, "death_noise.tres debe existir y cargar")
	print("  ✓ Shaders de muerte por energía, refracción de pantalla y mapa de ruido validados")

	# 3. Validar Micro-Explosiones y Debris Residual
	print("\n[3/4] Testing Micro-Explosion & Residual Debris VFX...")
	var micro = CinematicMicroExplosionScript.new()
	micro.setup(Vector2(500, 500), 40.0, Color(0.2, 0.9, 1.0, 1.0))
	add_child(micro)
	assert(micro.process_mode == Node.PROCESS_MODE_ALWAYS, "Micro-explosión debe tener process_mode ALWAYS")
	assert(micro.max_radius == 40.0, "Radio configurado correctamente")
	assert(micro.z_index == 120, "Micro-explosión debe tener z_index = 120")
	micro.queue_free()

	var debris = CinematicResidualDebrisScript.new()
	debris.setup(Vector2(500, 500), 16, Color(0.25, 0.95, 1.0, 1.0))
	add_child(debris)
	assert(debris.process_mode == Node.PROCESS_MODE_ALWAYS, "Debris residual debe tener process_mode ALWAYS")
	debris.queue_free()
	print("  ✓ Componentes procedurales ligeros (micro-explosiones y debris) validados")

	# 4. Validar método desacoplado play_for_boss
	print("\n[4/4] Testing play_for_boss decoupling & callback...")
	var dummy_boss := Node2D.new()
	add_child(dummy_boss)
	var tracker: Array[bool] = [false]
	CinematicDeathSequenceScript.play_for_boss(dummy_boss, func():
		tracker[0] = true
	, true)

	for frame in range(20):
		if tracker[0]:
			break
		await get_tree().process_frame

	assert(tracker[0] == true, "play_for_boss debe invocar el callback de finalización")
	dummy_boss.queue_free()
	seq.queue_free()
	print("  ✓ Método estático play_for_boss y ejecución de callback verificados")

	print("\n==========================================")
	print(">>> ALL CINEMATIC DEATH TESTS PASSED (100%) <<<")
	print("==========================================\n")
	get_tree().quit(0)
