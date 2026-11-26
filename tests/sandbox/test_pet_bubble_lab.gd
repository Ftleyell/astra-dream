extends BaseTestSuite

## Suite headless para validar assets compilados (512x512), shaders,
## órbita 3D con Z-ordering real y modos del Lab de 3D Pets.

const LAB_SCENE_PATH: String = "res://sandbox/pet_bubble_lab/pet_bubble_lab.tscn"
const PET_IDS: Array[StringName] = [&"mochi", &"kuro", &"luna", &"pip", &"cosmo"]


func _ready() -> void:
	timeout_seconds = 14.0
	super._ready()
	await _run_tests()


func _run_tests() -> void:
	_test_configs_and_512_assets()
	await _test_lab_scene_orbit_modes_and_layers()
	pass_suite("PetBubbleLab verificado: 5 configs .tres, assets 512x512, orbita 3D con Z-depth, emotes y capas.")


func _test_configs_and_512_assets() -> void:
	for pid: StringName in PET_IDS:
		var pid_str: String = String(pid)
		var cfg_path: String = "res://data/pets/bubble_v2/%s.tres" % pid_str
		var cfg: PetBubbleVisualConfig = ResourceLoader.load(cfg_path) as PetBubbleVisualConfig
		assert_true(cfg != null, "Debe cargar config .tres de %s" % pid_str)
		assert_true(cfg.pet_id == pid, "pet_id debe coincidir con %s" % pid_str)
		assert_true(cfg.edge_texture_opacity > 0.5 and cfg.bubble_bump_strength > 0.1, "Debe incluir parametros 3D de borde y relieve en %s" % pid_str)

		for suffix: String in ["albedo", "normal", "bubble_tex"]:
			var tex_path: String = "res://assets/pets/bubble_v2/%s/pet_%s_%s.png" % [pid_str, pid_str, suffix]
			var tex: Texture2D = PetBubbleRig25D._load_tex_safe(null, tex_path)
			assert_true(tex != null, "Debe existir textura %s" % tex_path)
			assert_true(tex.get_width() == 512 and tex.get_height() == 512, "%s debe medir 512x512" % tex_path)


func _test_lab_scene_orbit_modes_and_layers() -> void:
	var packed: PackedScene = ResourceLoader.load(LAB_SCENE_PATH) as PackedScene
	assert_true(packed != null, "Debe cargar pet_bubble_lab.tscn")
	var lab: PetBubbleLab = packed.instantiate() as PetBubbleLab
	assert_true(lab != null, "Debe instanciar PetBubbleLab")
	add_child(lab)
	await get_tree().process_frame

	var orb: PetOrbit3DController = lab.get_orbit_controller()
	assert_true(orb != null, "PetOrbit3DController debe estar presente")

	# Verificar selección individual y todas las 5 juntas
	for pid: StringName in PET_IDS:
		lab.select_pet_for_test(pid)
		var rigs: Array[PetBubbleRig25D] = orb.get_rigs()
		assert_true(rigs.size() == 1, "Modo individual debe instanciar 1 rig para %s" % String(pid))
		assert_true(rigs[0].pet_sprite.texture != null, "Sprite de %s debe tener textura asignada" % String(pid))

	lab.select_pet_for_test(&"all")
	assert_true(orb.get_rigs().size() == 5, "Modo ALL debe instanciar las 5 pets en orbita")

	# Simular una vuelta completa verificando que orbit_depth y z_index cruzan por delante y detrás del ancla
	# y que durante órbita tranquila NO dispara giros 2.5D automáticos
	lab.select_pet_for_test(&"mochi")
	var rig: PetBubbleRig25D = orb.get_rigs()[0]
	rig.set_auto_gestures_enabled(false)
	var anchor_z: int = lab.pilot_anchor.z_index
	var saw_front: bool = false
	var saw_back: bool = false
	for _step: int in range(60):
		orb.step_orbit(0.12)
		rig.step_animation(0.12)
		var d: float = rig.get_orbit_depth()
		if d > 0.25 and rig.z_index > anchor_z:
			saw_front = true
		elif d < -0.25 and rig.z_index < anchor_z:
			saw_back = true
	assert_true(saw_front and saw_back, "La orbita 3D debe pasar tanto por delante como por detras del piloto")
	assert_true(rig.get_flip_count() == 0, "La orbita tranquila no debe disparar flips 2.5D constantes")

	# Verificar gestos planos simpáticos sin disparar giros 2.5D
	for gesture: StringName in [&"roll_360", &"wiggle", &"hop", &"curious_tilt"]:
		rig.trigger_emote(gesture)
		assert_true(rig.get_active_gesture() == gesture, "Debe activar gesto plano %s" % String(gesture))
		rig.step_animation(0.20)
	assert_true(rig.get_flip_count() == 0, "Los gestos planos no deben disparar flips 2.5D")

	# Verificar que el giro 2.5D manual activa destello fuerte al cruzar
	rig.trigger_emote(&"flip")
	assert_true(rig.get_flip_count() == 1, "trigger_emote(&'flip') debe incrementar flip_count")
	rig.step_animation(0.11)
	assert_true(rig.get_flip_flash_strength() > 0.5, "El cruce 2.5D debe emitir destello ocultador > 0.5")
	rig.step_animation(0.20)

	# Probar modos restantes, emotes, capas y debug shader
	lab.set_mode_for_test(PetOrbit3DController.LabMode.CLOSEUP_HERO)
	assert_true(orb.get_mode() == PetOrbit3DController.LabMode.CLOSEUP_HERO, "Debe activar modo CLOSEUP_HERO")

	lab.set_mode_for_test(PetOrbit3DController.LabMode.FETCH_DEMO)
	orb.step_orbit(0.25)
	assert_true(lab.fetch_gem.visible, "FetchGem debe ser visible en FETCH_DEMO")

	lab.set_mode_for_test(PetOrbit3DController.LabMode.INGAME_SCALE)
	assert_true(is_equal_approx(rig.base_diameter_px, 64.0), "Modo INGAME_SCALE debe fijar diametro 64 px")

	rig.trigger_emote(&"bounce")
	rig.trigger_emote(&"flip")
	rig.trigger_emote(&"dash")
	orb.set_layer_visibility(true, true, false, true)
	assert_true(not rig.front_shell.visible, "Toggle debe ocultar FrontShell")
	orb.set_layer_visibility(true, true, true, true)
	orb.set_runtime_overrides(1.0, 1.0, 1.0, 1.0, 0.85, 0.42)
	orb.set_pet_debug_mode(2)

	lab.queue_free()
	await get_tree().process_frame
