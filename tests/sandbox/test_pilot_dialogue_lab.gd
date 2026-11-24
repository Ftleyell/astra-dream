extends BaseTestSuite
## Suite aislada de verificación para Living Dialogue Portraits y PilotDialogueLab.

const LAB_SCENE_PATH: String = "res://sandbox/pilot_rig_lab/dialogue_lab/pilot_dialogue_lab.tscn"
const PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const CONFIG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_dialogue_portraits.tres"
const DCH_PATH: String = "res://narrative/characters/valentina.dch"
const DialogueLabScript = preload("res://sandbox/pilot_rig_lab/dialogue_lab/pilot_dialogue_lab.gd")
const PortraitCtrlScript = preload("res://scenes/pilots/dialogue/pilot_dialogue_portrait_controller.gd")
const ConfigScript = preload("res://data/pilots/schemas/pilot_dialogue_portrait_config.gd")
const EntryScript = preload("res://data/pilots/schemas/pilot_dialogue_portrait_entry.gd")


func _ready() -> void:
	timeout_seconds = 12.0
	super._ready()
	await _run_tests()


func _run_tests() -> void:
	_test_resources_and_compiled_assets()
	_test_valentina_dch_entries()
	await _test_dialogue_lab_and_controller()
	pass_suite("Living Dialogue Portraits, máscaras, shader y PilotDialogueLab verificados")


func _test_resources_and_compiled_assets() -> void:
	var profile: PilotRigProfile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile
	assert_true(profile != null, "Debe cargar valentina_v2_profile.tres")
	assert_true(profile.dialogue_portraits_config != null, "valentina_v2_profile.tres debe enlazar dialogue_portraits_config")

	var cfg: ConfigScript = ResourceLoader.load(CONFIG_PATH) as ConfigScript
	assert_true(cfg != null, "Debe cargar valentina_v2_dialogue_portraits.tres")
	assert_true(cfg.base_display_height_px >= 520.0 and cfg.base_display_height_px <= 1280.0, "base_display_height_px debe estar calibrada dentro del rango 1080p (520..1280)")
	assert_true(cfg.left_slot_pos.is_equal_approx(Vector2(442.0, 1080.0)), "left_slot_pos debe ser (442, 1080)")
	assert_true(cfg.right_slot_pos.is_equal_approx(Vector2(1478.0, 1080.0)), "right_slot_pos debe ser (1478, 1080)")
	assert_true(is_equal_approx(cfg.speaking_bounce_px, 0.0) and is_equal_approx(cfg.speaking_scale_punch, 0.0), "speaking_bounce_px y speaking_scale_punch deben ser 0.0")
	assert_true(not cfg.follow_mouse and is_equal_approx(cfg.mouse_parallax_px, 0.0) and is_equal_approx(cfg.mouse_tilt_deg, 0.0), "follow_mouse debe estar desactivado con parallax/tilt en 0.0")
	assert_true(cfg.entries.size() >= 5, "Config de diálogos debe tener al menos 5 entradas (neutral/thinking/warm/focused/alert)")

	for em: String in ["neutral", "thinking", "warm", "focused"]:
		var entry: EntryScript = cfg.get_entry(StringName(em))
		assert_true(entry != null and entry.emotion_id == StringName(em), "Debe existir entrada '%s'" % em)
		for p_path: String in [
			entry.texture_path,
			entry.normal_map_path,
			entry.depth_map_path,
			entry.id_mask_path,
			entry.ilm_map_path,
			entry.motion_mask_path,
		]:
			assert_true(not p_path.is_empty(), "Ruta vacía para '%s'" % em)
			var abs_p: String = ProjectSettings.globalize_path(p_path)
			assert_true(FileAccess.file_exists(abs_p), "Debe existir PNG compilado: %s" % p_path)
			var img: Image = Image.load_from_file(abs_p)
			assert_true(img != null and img.get_width() == 1024 and img.get_height() == 1024, "PNG debe ser 1024x1024: %s" % p_path)

		# Verificar transparencia real en el albedo compilado
		var albedo_img: Image = Image.load_from_file(ProjectSettings.globalize_path(entry.texture_path))
		assert_true(albedo_img.get_pixel(8, 8).a < 0.05, "Esquina debe ser transparente en %s" % em)
		assert_true(albedo_img.get_pixel(512, 420).a > 0.90, "Centro del busto debe ser opaco en %s" % em)


func _test_valentina_dch_entries() -> void:
	var raw: String = FileAccess.get_file_as_string(DCH_PATH)
	assert_true(not raw.is_empty(), "Debe existir narrative/characters/valentina.dch")
	for key_name: String in ["\"Normal\"", "\"Flipped\"", "\"Thinking\"", "\"Warm\"", "\"Focused\""]:
		assert_true(raw.contains(key_name), "valentina.dch debe contener retrato %s" % key_name)
	assert_true(raw.contains("valentina_v2_dialogue_neutral.png"), "valentina.dch debe apuntar al nuevo portrait compilado")


func _test_dialogue_lab_and_controller() -> void:
	var packed: PackedScene = load(LAB_SCENE_PATH) as PackedScene
	assert_true(packed != null, "Debe cargar pilot_dialogue_lab.tscn")

	var lab: DialogueLabScript = packed.instantiate() as DialogueLabScript
	assert_true(lab != null, "Debe instanciar PilotDialogueLab")
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame

	var ctrl: PortraitCtrlScript = lab.get_portrait_controller()
	assert_true(ctrl != null, "PilotDialogueLab debe montar PilotDialoguePortraitController")
	assert_true(ctrl.get_available_emotions().size() >= 5, "Controlador debe exponer al menos 5 emociones")

	# Cambiar emociones y verificar step + animaciones
	for em_id: StringName in [&"thinking", &"warm", &"focused", &"alert", &"neutral"]:
		lab.select_emotion(em_id)
		assert_true(ctrl.get_current_emotion() == em_id, "Emoción activa debe ser %s" % String(em_id))
		ctrl.step(0.08)

	# Probar skin recolor, modos debug 0..6, radio comms, turno escucha, espejo y A/B
	lab.set_skin_index(1)
	lab.set_hair_recolor_enabled(true)
	for mode_i: int in range(7):
		lab.set_debug_view_mode(mode_i)
	lab.set_debug_view_mode(0)

	lab.set_comms_enabled(true)
	lab.set_focused_enabled(false)
	lab.set_mirrored_enabled(true)
	lab.trigger_speech_pulse()
	ctrl.step(0.20)
	lab.set_mirrored_enabled(false)

	# Verificar cero rebote/temblor posicional al escribir
	ctrl.set_emotion(&"neutral", true)
	ctrl.set_focused(true, true)
	ctrl.step(0.05)
	var portrait_root: Node2D = ctrl.get_portrait_root()
	assert_true(portrait_root != null, "Controlador debe exponer PortraitRoot")
	var pos_before: Vector2 = portrait_root.position
	var scale_before: Vector2 = portrait_root.scale
	ctrl.set_speaking(true)
	lab.trigger_speech_pulse()
	ctrl.step(0.0)
	assert_true(portrait_root.position.distance_to(pos_before) < 0.001, "Hablar/pulsar no debe producir salto posicional")
	assert_true(portrait_root.scale.distance_to(scale_before) < 0.001, "Hablar/pulsar no debe producir punch de escala posicional")

	# Verificar raíz anclada sin seguimiento de puntero tras entrada
	ctrl.set_mouse_normalized(Vector2(1.0, -1.0))
	ctrl.step(0.35)
	assert_true(portrait_root.position.length() < 0.001, "PortraitRoot debe permanecer anclado sin seguir al mouse ni oscilar")
	assert_true(absf(portrait_root.rotation_degrees) < 0.001, "PortraitRoot debe mantener rotacion 0.0 sin inclinacion de mouse ni balanceo")

	# Verificar Interlocutor Pet, HUD colapsable [H] y Guías [G]
	lab.set_pet_id("kuro")
	assert_true(lab.get_pet_id() == "kuro", "Pet activa debe cambiar a kuro")
	var pet_root: Node2D = lab.get_pet_root()
	assert_true(pet_root != null and pet_root.position.is_equal_approx(Vector2(1478.0, 820.0)), "Pet debe ubicarse en slot in-game (1478, 820)")
	lab.set_hud_panel_visible(false)
	assert_true(not lab.is_hud_panel_visible(), "Drawer HUD debe poder colapsarse")
	lab.set_hud_panel_visible(true)
	lab.set_guides_visible(true)
	assert_true(lab.is_guides_visible(), "Capa de guías 1080p debe poder activarse")
	lab.set_guides_visible(false)

	lab.set_living_enabled(false)
	ctrl.step(0.05)
	lab.set_living_enabled(true)

	# Probar avance de conversación en el teatro con escritura activa sin hop
	lab.start_conversation("mochi")
	lab.advance_conversation()
	lab._process(0.15)
	assert_true(float(ctrl.get("_speech_hop")) == 0.0, "El typewriter nunca debe activar _speech_hop")
	lab.advance_conversation()

	lab.queue_free()
	await get_tree().process_frame
