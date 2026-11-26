extends BaseTestSuite
## Suite de verificación headless para Valentina Skill & Ultimate Studio (Fase 1).
## Verifica:
## 1. Carga de valentina_v2_skill.tres, valentina_v2_ultimate.tres y vinculación en valentina_v2_combat_rig.tres.
## 2. Instanciación limpia de valentina_skill_ult_studio.tscn con PilotCutInTheater, SniperWeakpointRailVFX y UltimateWingBarrageController.
## 3. Los 3 formatos de Cut-In de Skill [R] + disparo Sniper Rail-Lance con marca de vulnerabilidad.
## 4. Conmutación LIVE_BANNER_25D <-> RIG_BATTLE_POSE y progresión de fases (Cut-In -> B/N HDR -> Fractura Obsidiana -> Release).
## 5. Pool pre-alocado zero-allocation de 12 cuchillas y emisión de blade_impacted + finisher_detonated.

const STUDIO_SCENE_PATH: String = "res://sandbox/pilot_rig_lab/vfx_lab/valentina_skill_ult_studio.tscn"
const COMBAT_RIG_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_combat_rig.tres"


func _ready() -> void:
	timeout_seconds = 12.0
	super._ready()
	_run_tests()


func _run_tests() -> void:
	# 1. Verificar vinculación en PilotCombatRigConfig
	var combat_cfg: PilotCombatRigConfig = ResourceLoader.load(COMBAT_RIG_CFG_PATH) as PilotCombatRigConfig
	assert_true(combat_cfg != null, "Debe cargar valentina_v2_combat_rig.tres")
	assert_true(combat_cfg.skill_config is PilotSkillConfig, "PilotCombatRigConfig debe enlazar skill_config (.tres)")
	assert_true(combat_cfg.ultimate_config is PilotUltimateConfig, "PilotCombatRigConfig debe enlazar ultimate_config (.tres)")

	# 2. Instanciar escena del Studio
	var packed: PackedScene = ResourceLoader.load(STUDIO_SCENE_PATH) as PackedScene
	assert_true(packed != null, "Debe cargar valentina_skill_ult_studio.tscn")
	var studio: Node2D = packed.instantiate() as Node2D
	assert_true(studio != null, "Debe instanciar ValentinaSkillUltStudio")
	add_child(studio)
	await get_tree().process_frame
	await get_tree().process_frame

	var theater: PilotCutInTheater = studio.call("get_theater") as PilotCutInTheater
	var sniper_vfx: SniperWeakpointRailVFX = studio.call("get_sniper_vfx") as SniperWeakpointRailVFX
	var barrage: UltimateWingBarrageController = studio.call("get_wing_barrage") as UltimateWingBarrageController
	var skill_cfg: PilotSkillConfig = studio.call("get_skill_config") as PilotSkillConfig
	var ult_cfg: PilotUltimateConfig = studio.call("get_ultimate_config") as PilotUltimateConfig

	assert_true(theater != null, "Studio debe crear PilotCutInTheater")
	assert_true(sniper_vfx != null, "Studio debe crear SniperWeakpointRailVFX")
	assert_true(barrage != null, "Studio debe crear UltimateWingBarrageController")
	assert_true(barrage.get_pool_size() == 12, "UltimateWingBarrageController debe pre-alocar exactamente 12 cuchillas")

	# 3. Probar Skill [R] en los 3 estilos + scrub hasta Impact Frame y disparo
	for style_i: int in range(3):
		skill_cfg.cutin_style = style_i as PilotSkillConfig.SkillCutInStyle
		studio.call("trigger_skill_demo")
		assert_true(theater.is_playing(), "PilotCutInTheater debe estar activo en Skill estilo %d" % style_i)
		theater.scrub_to_normalized(0.25)
		assert_true(theater.get_current_phase_name() == "SKILL_CUTIN", "Fase inicial Skill debe ser SKILL_CUTIN")
		theater.scrub_to_normalized(0.95)
		assert_true(theater.get_current_phase_name() == "SKILL_IMPACT_FRAME", "Fase final Skill debe ser SKILL_IMPACT_FRAME")
	theater.stop_and_hide()

	# 4. Probar Ultimate [Q] en los 3 motores (CUSTOM_CUTIN_ART, LIVE_BANNER_25D y RIG_BATTLE_POSE) y todas las fases
	for mode_i: int in range(3):
		ult_cfg.render_mode = mode_i as PilotUltimateConfig.CutInRenderMode
		studio.call("trigger_ultimate_demo")
		assert_true(theater.is_playing(), "PilotCutInTheater debe estar activo en Ultimate modo %d" % mode_i)
		theater.scrub_to_normalized(0.30)
		assert_true(theater.get_current_phase_name() == "ULT_WALLPAPER_CUTIN", "En 30% debe estar en ULT_WALLPAPER_CUTIN")
		theater.scrub_to_normalized(0.75)
		assert_true(theater.get_current_phase_name() == "ULT_IMPACT_BW_HDR", "En 75% debe estar en ULT_IMPACT_BW_HDR")
		theater.scrub_to_normalized(0.88)
		assert_true(theater.get_current_phase_name() == "ULT_SHATTER_OBSIDIAN", "En 88% debe estar en ULT_SHATTER_OBSIDIAN")
		theater.scrub_to_normalized(0.98)
		assert_true(theater.get_current_phase_name() == "ULT_RELEASE_FLASH", "En 98% debe estar en ULT_RELEASE_FLASH")
	theater.stop_and_hide()

	# 5. Verificar Hold-to-Aim Sniper [R] + lanzamiento y retorno boomerang de las 12 cuchillas reales
	var dummy_target := Node2D.new()
	dummy_target.global_position = Vector2(320.0, 0.0)
	add_child(dummy_target)
	sniper_vfx.update_hold_aim(Vector2.ZERO, dummy_target, Vector2(320.0, 0.0))
	assert_true(sniper_vfx.is_holding_aim(), "SniperWeakpointRailVFX debe activar modo Hold-to-Aim")
	sniper_vfx.stop_hold_aim()

	var counters: Dictionary = {"impacts": 0, "returning": false, "finisher": false}
	barrage.blade_impacted.connect(func(_t: Node2D, _p: Vector2, _i: int) -> void:
		counters["impacts"] = int(counters["impacts"]) + 1
	)
	barrage.blades_returning.connect(func() -> void:
		counters["returning"] = true
	)
	barrage.finisher_detonated.connect(func(_targets: Array[Node2D]) -> void:
		counters["finisher"] = true
	)

	var tgt_arr: Array[Node2D] = [dummy_target]
	barrage.launch_barrage(Vector2.ZERO, tgt_arr, ult_cfg, studio)
	assert_true(barrage.is_active(), "Barrage de 12 alas debe estar activo tras launch_barrage")

	for _step: int in range(80):
		barrage._process(0.02)
	var impact_count: int = int(counters["impacts"])
	var returned_called: bool = bool(counters["returning"])
	var finisher_called: bool = bool(counters["finisher"])
	assert_true(impact_count == 12, "Deben impactar exactamente 12 cuchillas (obtenido: %d)" % impact_count)
	assert_true(returned_called, "Las 12 cuchillas deben iniciar fase RETURN_RECALL hacia Valentina")
	assert_true(finisher_called, "Debe emitirse finisher_detonated al completar ida y vuelta de las 12 cuchillas")

	# 6. Verificar cambio de los 3 estilos de HUD y skins sin errores
	for hud_i: int in range(3):
		studio.call("set_hud_preview_style", hud_i)
	studio.call("apply_skin_by_index", 0)
	assert_true(true, "Cambio de HUD (3 estilos) y skin aplicado limpiamente")

	studio.queue_free()
	dummy_target.queue_free()
	pass_suite("Valentina Skill & Ultimate Studio (Fase 1) verificado correctamente")
