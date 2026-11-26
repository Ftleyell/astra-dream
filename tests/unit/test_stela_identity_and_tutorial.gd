extends BaseTestSuite

## Suite aislada para Phase 1 de Stela Galactica:
## - Valida texturas de tipografía + medallón (albedo, normal, masks) y recursos .tres
## - Valida StelaLogoStage (4 capas + iluminación Cosmos), TitleMenuOverlay y SingularityTransitionPresenter
## - Valida StelaIntroLab: materialización Title -> Hub (reset demat_invert = false y demat_progress = 0.0)
## - Valida los 10 pasos del HubTutorialDirector (glow titilante activo > 0 y limpieza a 0.0 + cámara libre al cerrar)

const StelaLogoStageScript = preload("res://scenes/ui/title_screen/components/stela_logo_stage.gd")
const TitleMenuOverlayScript = preload("res://scenes/ui/title_screen/components/title_menu_overlay.gd")
const SingularityPresenterScript = preload("res://core/systems/singularity_transition_presenter.gd")
const StelaIntroLabScript = preload("res://sandbox/workbenches/stela_intro_lab/stela_intro_lab.gd")
const StelaIntroLabScene: PackedScene = preload("res://sandbox/workbenches/stela_intro_lab/stela_intro_lab.tscn")
const HubTutorialSeqScript = preload("res://data/hub/hub_tutorial_sequence_config.gd")
const StationNodeScript = preload("res://scenes/ui/hub/astral_station/components/hub_lab_station_node.gd")
const MainGameScene: PackedScene = preload("res://scenes/combat/main_game.tscn")
const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")
const TitleToHubSeqScript = preload("res://data/ui/title_to_hub_sequence_config.gd")


func _ready() -> void:
	timeout_seconds = 32.0
	super._ready()
	await _run_tests()


func _await_frames(count: int = 2) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _run_tests() -> void:
	_test_assets_and_resources()
	await _test_logo_stage_and_menu()
	await _test_singularity_presenter()
	await _test_stela_intro_lab_and_tutorial()
	await _test_production_title_hub_tutorial_and_prologue_guard()
	pass_suite("Identidad Stela Galactica, Singularidad, Materialización Hub, Tutorial y Integración Producción verificados")


func _test_assets_and_resources() -> void:
	for png_path: String in [
		"res://assets/ui/stela_galactica_logo_albedo.png",
		"res://assets/ui/stela_galactica_logo_normal.png",
		"res://assets/ui/stela_galactica_logo_masks.png",
		"res://assets/ui/stela_galactica_medallion_albedo.png",
		"res://assets/ui/stela_galactica_medallion_normal.png",
		"res://assets/ui/stela_galactica_medallion_masks.png",
	]:
		assert_true(FileAccess.file_exists(ProjectSettings.globalize_path(png_path)), "Debe existir %s" % png_path)

	var logo_cfg: Resource = load("res://data/ui/default_stela_logo_vfx_config.tres")
	var sing_cfg: Resource = load("res://data/ui/default_singularity_transition_config.tres")
	var seq_cfg: Resource = load("res://data/ui/default_title_to_hub_sequence_config.tres")
	var tut_cfg: HubTutorialSeqScript = load("res://data/hub/default_hub_tutorial_sequence.tres") as HubTutorialSeqScript

	assert_true(logo_cfg != null, "default_stela_logo_vfx_config.tres debe cargar")
	assert_true(sing_cfg != null, "default_singularity_transition_config.tres debe cargar")
	assert_true(seq_cfg != null, "default_title_to_hub_sequence_config.tres debe cargar")
	assert_true(tut_cfg != null and tut_cfg.steps.size() == 10, "default_hub_tutorial_sequence.tres debe tener exactamente 10 pasos")


func _test_logo_stage_and_menu() -> void:
	var stage: StelaLogoStageScript = StelaLogoStageScript.new() as StelaLogoStageScript
	add_child(stage)
	await _await_frames(2)

	assert_true(stage.get_logo_material() != null, "LogoHeroRect debe tener ShaderMaterial")
	assert_true(stage.get_medallion_material() != null, "MedallionRect debe tener ShaderMaterial")
	assert_true(stage.get_rings_material() != null, "AstrolabeRingsRect debe tener ShaderMaterial")
	assert_true(stage.get_slash_material() != null, "EnergySlashRect debe tener ShaderMaterial")

	stage.play_entrance()
	await _await_frames(2)
	stage.play_dissolve_to_hub()
	await _await_frames(2)
	stage.reset_visible()

	var menu: TitleMenuOverlayScript = TitleMenuOverlayScript.new() as TitleMenuOverlayScript
	add_child(menu)
	await _await_frames(1)
	menu.set_continue_available(true)
	assert_true(menu.get_continue_button().visible, "Botón CONTINUAR debe mostrarse si hay run activa")
	menu.set_continue_available(false)
	assert_true(not menu.get_continue_button().visible, "Botón CONTINUAR debe ocultarse si no hay run")

	menu.queue_free()
	stage.queue_free()
	await _await_frames(1)


func _test_singularity_presenter() -> void:
	var sing: SingularityPresenterScript = SingularityPresenterScript.new() as SingularityPresenterScript
	var cfg: Resource = load("res://data/ui/default_singularity_transition_config.tres").duplicate()
	cfg.set("crunch_duration_sec", 0.06)
	cfg.set("min_singularity_hold_sec", 0.05)
	cfg.set("big_bang_duration_sec", 0.06)
	sing.config = cfg
	add_child(sing)

	var callback_ran: Array[bool] = [false]
	await sing.play_custom_transition(func() -> void:
		callback_ran[0] = true
	)
	assert_true(callback_ran[0], "SingularityTransitionPresenter debe ejecutar callback en punto blanco")
	assert_true(not sing.is_transition_active(), "SingularityTransitionPresenter debe limpiar estado al terminar")
	sing.queue_free()
	await _await_frames(1)


func _test_stela_intro_lab_and_tutorial() -> void:
	var lab: StelaIntroLabScript = StelaIntroLabScene.instantiate() as StelaIntroLabScript
	assert_true(lab != null, "StelaIntroLab debe instanciar")
	add_child(lab)
	await _await_frames(3)

	assert_true(lab.mode == StelaIntroLabScript.LabMode.TITLE_ACTIVE, "Lab debe arrancar en TITLE_ACTIVE")
	assert_true(not lab.player.visible, "Player debe estar oculto en Title")

	# Probar materialización directa y validar reset exacto de demat_invert/demat_progress
	lab.sequence_config = lab.sequence_config.duplicate()
	lab.sequence_config.station_materialize_duration_sec = 0.22
	lab.play_materialization_only()

	var waited: float = 0.0
	while waited < 1.2:
		await get_tree().create_timer(0.05, true).timeout
		waited += 0.05
		if lab.hub_stage != null and lab.hub_stage.departure_controller != null:
			var dc: HubRadialDepartureController = lab.hub_stage.departure_controller
			if not dc.get("_is_embedded_materializing") and is_equal_approx(dc.get_demat_progress(), 0.0):
				break

	var mats: Array = lab.hub_stage.departure_controller.get("_demat_materials") as Array
	assert_true(mats.size() > 0, "Debe haber materiales de desmaterialización registrados")
	var first_mat: ShaderMaterial = mats[0] as ShaderMaterial
	assert_true(not bool(first_mat.get_shader_parameter("demat_invert")), "demat_invert debe resetearse a false al finalizar materialización")
	assert_true(is_equal_approx(float(first_mat.get_shader_parameter("demat_progress")), 0.0), "demat_progress debe resetearse a 0.0")

	# Probar los 10 pasos del Tutorial vía Dialogic nativo (incluyendo estado CALIBRATING y Spotlight Blur)
	var dialogic_node: Node = get_node_or_null("/root/Dialogic")
	var spotlight: CanvasLayer = lab.tutorial_director.get_spotlight_overlay()
	assert_true(spotlight != null, "HubTutorialSpotlightOverlay debe estar instanciado")
	assert_true(spotlight.layer == 38, "Spotlight overlay debe vivir en layer 38 (debajo de Dialogic 42)")
	lab.hub_stage.set_all_stations_state_override(StationNodeScript.StationState.CALIBRATING)
	lab.tutorial_director.start_tutorial(&"mochi")
	await _await_frames(2)
	assert_true(lab.tutorial_director.is_active(), "TutorialDirector debe quedar activo")
	assert_true(lab.tutorial_director.get_current_step_index() == 0, "Tutorial debe iniciar en paso 0")
	assert_true(is_equal_approx(float(spotlight.call("get_effect_alpha")), 0.0), "Paso 0 (overview) no debe activar spotlight blur")
	if dialogic_node != null:
		assert_true(dialogic_node.current_timeline != null, "Dialogic debe tener un timeline activo durante el tutorial")

	# Avanzar al paso 1 (Cápsula de Piloto) y verificar glow titilante > 0 + spotlight blur activo
	lab.tutorial_director.next_step()
	await _await_frames(4)
	assert_true(lab.tutorial_director.get_current_step_index() == 1, "Debe avanzar al paso 1")
	assert_true(bool(spotlight.call("is_spotlight_visible")), "Spotlight blur debe hacerse visible en paso 1")
	assert_true(float(spotlight.call("get_effect_alpha")) > 0.0, "Spotlight effect_alpha debe subir > 0 en paso 1")
	var focus_uv: Vector2 = spotlight.call("get_focus_uv") as Vector2
	assert_true(focus_uv.x >= 0.0 and focus_uv.x <= 1.0 and focus_uv.y >= 0.0 and focus_uv.y <= 1.0, "Spotlight focus_uv debe estar normalizado en [0, 1]")
	var cap_bundle: Dictionary = lab.hub_stage.get_station_materials_for_tutorial(&"pilot_capsule")
	var cap_prop: ShaderMaterial = (cap_bundle["prop_mats"] as Array)[0] as ShaderMaterial
	var cap_pulse_v: Variant = cap_prop.get_shader_parameter("tutorial_highlight_pulse")
	assert_true((float(cap_pulse_v) if cap_pulse_v != null else 0.0) > 0.0, "Cápsula debe tener tutorial_highlight_pulse > 0 en paso 1")

	# Verificar paso 2 (Espejo de Skins en CALIBRATING) y que Cápsula quedó en 0.0
	lab.tutorial_director.next_step()
	await _await_frames(2)
	var cap_pulse_after: Variant = cap_prop.get_shader_parameter("tutorial_highlight_pulse")
	assert_true(is_equal_approx(float(cap_pulse_after) if cap_pulse_after != null else 0.0, 0.0), "Cápsula debe limpiarse a 0.0 al pasar a Skins")
	var skins_bundle: Dictionary = lab.hub_stage.get_station_materials_for_tutorial(&"skins_mirror")
	var skins_prop: ShaderMaterial = (skins_bundle["prop_mats"] as Array)[0] as ShaderMaterial
	var skins_pulse_v: Variant = skins_prop.get_shader_parameter("tutorial_highlight_pulse")
	assert_true((float(skins_pulse_v) if skins_pulse_v != null else 0.0) > 0.0, "Estación CALIBRATING debe brillar igual en tutorial")

	# Retroceder y luego saltar al último paso (10/10) y completar
	lab.tutorial_director.prev_step()
	await _await_frames(2)
	assert_true(lab.tutorial_director.get_current_step_index() == 1, "prev_step debe volver al paso 1")
	lab.tutorial_director.go_to_step(9)
	await _await_frames(2)
	assert_true(lab.tutorial_director.get_current_step_index() == 9, "Debe ir al último paso (index 9)")

	lab.tutorial_director.next_step()
	await _await_frames(2)
	assert_true(not lab.tutorial_director.is_active(), "next_step en último paso debe finalizar el tutorial")
	if dialogic_node != null:
		assert_true(dialogic_node.current_timeline == null, "Dialogic debe cerrar su timeline al finalizar tutorial")
	var cap_pulse_end: Variant = cap_prop.get_shader_parameter("tutorial_highlight_pulse")
	assert_true(is_equal_approx(float(cap_pulse_end) if cap_pulse_end != null else 0.0, 0.0), "Todos los glows deben quedar en 0.0 al cerrar")
	assert_true(lab.camera.custom_focus_point == Vector2.INF, "GameCamera2D debe liberar foco cinemático al terminar tutorial")
	spotlight.call("deactivate", true)
	assert_true(is_equal_approx(float(spotlight.call("get_effect_alpha")), 0.0), "Spotlight blur debe desactivarse a 0.0 al cerrar")
	assert_true(not bool(spotlight.call("is_spotlight_visible")), "Spotlight rect debe ocultarse al cerrar")

	lab.queue_free()
	await _await_frames(2)


func _test_production_title_hub_tutorial_and_prologue_guard() -> void:
	var prev_tut_done: bool = SaveManager.is_hub_tutorial_completed()

	# 1. Round-trip de persistencia hub_tutorial_completed
	SaveManager.set_hub_tutorial_completed(false)
	assert_true(not SaveManager.is_hub_tutorial_completed(), "hub_tutorial_completed debe persistir false")
	SaveManager.set_hub_tutorial_completed(true)
	assert_true(SaveManager.is_hub_tutorial_completed(), "hub_tutorial_completed debe persistir true")

	# 2. Flujo MainGame EntryMode.TITLE -> HUB_MATERIALIZING -> HUB_ACTIVE -> Tutorial -> Retorno Seamless a Título
	RunLaunchRequestScript.request_title_entry()
	var mg: MainGame = MainGameScene.instantiate() as MainGame
	assert_true(mg != null, "MainGame debe instanciarse en EntryMode.TITLE")
	add_child(mg)
	await _await_frames(2)

	assert_true(mg.is_title_or_materializing_active(), "MainGame debe arrancar activo en TitleScreen")
	assert_true(mg.title_session_controller != null and mg.title_session_controller.is_title_active(), "Debe estar en TITLE_ACTIVE")
	assert_true(mg.hub_session_controller != null and mg.hub_session_controller.display_sprite != null and not mg.hub_session_controller.display_sprite.visible, "Hub 3D debe permanecer oculto en TITLE_ACTIVE")

	# Acelerar secuencia Title -> Hub para verificación rápida en test
	var fast_seq := mg.title_session_controller.sequence_config.duplicate(true) as TitleToHubSeqScript
	fast_seq.station_materialize_delay_sec = 0.02
	fast_seq.station_materialize_duration_sec = 0.05
	fast_seq.pilot_flyin_delay_sec = 0.04
	fast_seq.pilot_flyin_duration_sec = 0.05
	mg.title_session_controller.sequence_config = fast_seq

	SaveManager.set_hub_tutorial_completed(false)
	mg.title_session_controller.play_title_to_hub_sequence()
	assert_true(mg.title_session_controller.is_materializing_hub(), "play_title_to_hub_sequence debe entrar a HUB_MATERIALIZING")

	var start_wait: int = Time.get_ticks_msec()
	while not mg.is_hub_mode_active() and (Time.get_ticks_msec() - start_wait) < 3500:
		await get_tree().process_frame
	assert_true(mg.is_hub_mode_active(), "Al aterrizar la piloto debe activar HUB_ACTIVE")
	assert_true(mg.hub_session_controller.display_sprite.visible and mg.player.visible, "Display 3D y Player deben quedar visibles en HUB_ACTIVE")

	# Verificar botón ? Guía en HUD y lanzamiento manual del tutorial con blindaje Dialogic/NarrativeDirector
	var hub_stage: AstralStationHub = mg.hub_session_controller.get_hub_stage()
	assert_true(hub_stage != null and hub_stage.hud != null, "AstralStationHUD debe existir en Hub embebido")
	assert_true(hub_stage.hud.find_child("GuideButton", true, false) != null, "AstralStationHUD debe mostrar el botón '? Guía'")

	mg.hub_session_controller.start_hub_tutorial(&"mochi")
	await _await_frames(3)
	assert_true(mg.hub_session_controller.is_hub_tutorial_active(), "Tutorial de Mochi debe quedar activo en Hub embebido")
	assert_true(not get_tree().paused, "Tutorial del Hub no debe pausar el SceneTree")
	assert_true(not mg.hud.visible, "HUD de combate debe seguir oculto durante el tutorial del Hub (blindaje NarrativeDirector)")

	mg.hub_session_controller.get_tutorial_director().finish_tutorial(false)
	await _await_frames(2)
	assert_true(not mg.hub_session_controller.is_hub_tutorial_active(), "Tutorial debe cerrarse limpiamente")
	assert_true(SaveManager.is_hub_tutorial_completed(), "Terminar el tutorial debe persistir hub_tutorial_completed = true")

	# Retorno seamless Hub -> Título sobre el mismo Cosmos
	mg.return_from_hub_to_title()
	await _await_frames(2)
	assert_true(mg.title_session_controller.is_title_active(), "return_from_hub_to_title debe volver a TITLE_ACTIVE sin recargar escena")
	assert_true(not mg.is_hub_mode_active() and not mg.hub_session_controller.display_sprite.visible, "Hub debe ocultarse al volver a Título")

	mg.queue_free()
	await _await_frames(2)

	# 3. Verificar combate directo sin prólogo automático + bono silencioso de +50 créditos
	RunLaunchRequestScript.request_direct_combat_entry()
	var mg_combat: MainGame = MainGameScene.instantiate() as MainGame
	add_child(mg_combat)
	await _await_frames(2)
	assert_true(not mg_combat.is_briefing_active, "Combate directo no debe abrir prólogo Dialogic al iniciar")
	assert_true(mg_combat.prologue_bonus_chosen, "Bono inicial de +50 créditos debe aplicarse silenciosamente")
	assert_true(mg_combat.player.run_credits >= 50, "Player debe iniciar combate con >= 50 créditos")
	mg_combat.queue_free()
	await _await_frames(2)

	SaveManager.set_hub_tutorial_completed(prev_tut_done)
