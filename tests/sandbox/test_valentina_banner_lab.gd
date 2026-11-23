extends BaseTestSuite
## Suite de verificación para el laboratorio aislado de Live Banner 2.5D (ValentinaBannerLab).

const BANNER_LAB_SCENE_PATH: String = "res://sandbox/pilot_rig_lab/banner_lab/valentina_banner_lab.tscn"
const BannerCtrlScript = preload("res://sandbox/pilot_rig_lab/banner_lab/pilot_live_banner_controller.gd")
const ConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_live_banner_config.gd")


func _ready() -> void:
	timeout_seconds = 10.0
	super._ready()
	_run_tests()


func _run_tests() -> void:
	var packed: PackedScene = load(BANNER_LAB_SCENE_PATH) as PackedScene
	assert_true(packed != null, "Debe cargar valentina_banner_lab.tscn")

	var lab: Node2D = packed.instantiate() as Node2D
	assert_true(lab != null, "Debe instanciar ValentinaBannerLab")
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame

	var ctrl: BannerCtrlScript = lab.call("get_banner_controller") as BannerCtrlScript
	var cfg: ConfigScript = lab.call("get_config") as ConfigScript

	assert_true(ctrl != null, "ValentinaBannerLab debe instanciar PilotLiveBannerController")
	assert_true(cfg != null, "ValentinaBannerLab debe cargar PilotLiveBannerConfig (.tres)")
	assert_true(ctrl.get_banner_sprite() != null, "Debe existir LiveBannerSprite")
	assert_true(ctrl.get_banner_sprite().texture != null, "LiveBannerSprite debe cargar textura base")

	lab.set_process(false)

	# 1. Parpadeo natural: dispara y vuelve a 0 tras blink_duration_sec
	ctrl.trigger_blink()
	ctrl.step(cfg.blink_duration_sec * 0.5)
	assert_true(ctrl.get_blink_amount() > 0.7, "A mitad del parpadeo blink_amount debe acercarse a 1.0")
	ctrl.step(cfg.blink_duration_sec * 0.7)
	assert_true(ctrl.get_blink_amount() <= 0.05, "Al completar el ciclo blink_amount debe volver a 0.0")

	# 2. Impulso de hover/jiggle: desplaza el resorte y amortigua limpiamente
	ctrl.trigger_hover_impulse(1.0)
	ctrl.step(0.05)
	assert_true(ctrl.get_jiggle_offset().length() > 0.001, "trigger_hover_impulse debe excitar el resorte 2D")
	for _i: int in range(30):
		ctrl.step(0.05)
	assert_true(ctrl.get_jiggle_offset().length() < 0.002, "El resorte 2D debe amortiguarse hasta reposo")

	# 3. Coreografía Idle autónoma 2.5D + invariante CanvasGroup (hijos siempre z_index = 0)
	ctrl.step(0.6)
	var char_root: Node2D = ctrl.call("get_character_root") as Node2D
	var ugroup: CanvasGroup = ctrl.call("get_unified_group") as CanvasGroup
	assert_true(ugroup != null, "Debe usar UnifiedBannerGroup (CanvasGroup) con pilot_rig_pass2.gdshader")
	assert_true(char_root != null and absf(char_root.rotation) > 0.001, "El Idle autónomo 2.5D debe oscilar suavemente sin mover el mouse")
	assert_true(char_root.z_index == 0 and ctrl.get_banner_sprite().z_index == 0, "Invariante CanvasGroup: hijos deben mantener z_index = 0")

	# 4. Secuencia Lock-In "Full Anime Overdrive": cascada 6x2 -> trabado con Impact Frames 1->2->0 + chispas
	assert_true(ctrl.get_wing_shard_count() == 12, "Debe cargar las 12 cuchillas reales de alas psíquicas (actual=%d)" % ctrl.get_wing_shard_count())
	ctrl.trigger_select_sequence()
	ctrl.step(0.05)
	assert_true(ctrl.is_pilot_selected() and ctrl.get_impact_frame_phase() == 0, "Durante la cascada inicial aún no debe dispararse Impact Frame")
	assert_true(ctrl.get_wings_deploy() > 0.0 and ctrl.get_wings_deploy() < 0.99, "Durante la cascada las alas deben estar abriéndose progresivamente")
	ctrl.step(cfg.wings_cascade_duration_sec - 0.03)
	assert_true(ctrl.get_impact_frame_phase() == 1, "Al trabar la cascada debe dispararse Impact Frame fase 1")
	assert_true(ctrl.get_lock_eye_flare() > 0.8, "Al trabar debe encenderse el brillo amatista del ojo")
	assert_true(ctrl.get_active_ember_count() > 0, "Al trabar deben generarse chispas carmesí")
	ctrl.step(cfg.impact_frame_1_sec)
	assert_true(ctrl.get_impact_frame_phase() == 2, "Debe pasar a Impact Frame fase 2")
	ctrl.step(cfg.impact_frame_2_sec + 0.12)
	assert_true(ctrl.get_impact_frame_phase() == 0, "Tras impact frames debe volver a fase normal 0")
	assert_true(ctrl.get_wings_deploy() >= 0.99, "Las alas deben quedar desplegadas firmes (deploy=%.2f)" % ctrl.get_wings_deploy())
	assert_true(ctrl.get_active_ember_count() > 0, "Mientras siga seleccionada deben persistir chispas carmesí")
	ctrl.reset_select_sequence()
	assert_true(
		not ctrl.is_pilot_selected() and ctrl.get_wings_deploy() == 0.0 and ctrl.get_active_ember_count() == 0,
		"reset_select_sequence debe plegar las alas y limpiar las chispas"
	)

	lab.queue_free()
	await get_tree().process_frame
	pass_suite("ValentinaBannerLab + Live Banner 2.5D + Alas & Impact Frames verificados")
