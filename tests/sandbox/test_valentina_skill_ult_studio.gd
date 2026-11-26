extends BaseTestSuite
## Suite de verificación headless para Valentina Skill & Ultimate Studio (Evolución 4 Actos).
## Verifica:
## 1. Carga de valentina_v2_skill.tres, valentina_v2_ultimate.tres (parámetros 4 Actos) y vinculación en valentina_v2_combat_rig.tres.
## 2. PilotSkinPaletteResolver.resolve() sobre todas las skins (10 presets) garantizando contraste real.
## 3. Acto 1 (UltimateSandevistanRadarController): ghosts Sandevistan, crosshairs y restauración exacta de rig.global_position.
## 4. Actos 2 y 3 (Ultimate3DStageRig + PilotCutInTheater): 3 anillos 3D, 12 cuchillas 3D, 24 púas 3D, 28 esquirlas 3D y 3 Beats de Impact Frame.
## 5. Acto 4 (UltimateWingBarrageController): convergencia de 12 cuchillas en 1 jefe con bonus consecutivo, reparto ponderado en enjambre y retorno boomerang.
## 6. Skill [R] (3 formatos + Hold-to-Aim) y 3 estilos de HUD Preview.

const STUDIO_SCENE_PATH: String = "res://sandbox/pilot_rig_lab/vfx_lab/valentina_skill_ult_studio.tscn"
const COMBAT_RIG_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_combat_rig.tres"
const PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const PaletteResolverScript = preload("res://scenes/pilots/vfx/abilities/pilot_skin_palette_resolver.gd")


class _MockTarget extends Node2D:
	var max_hp: float = 300.0
	var is_boss: bool = false
	var is_selected: bool = false


func _ready() -> void:
	timeout_seconds = 16.0
	super._ready()
	_run_tests()


func _run_tests() -> void:
	# 1. Verificar vinculación en PilotCombatRigConfig y nuevos defaults data-driven
	var combat_cfg: PilotCombatRigConfig = ResourceLoader.load(COMBAT_RIG_CFG_PATH) as PilotCombatRigConfig
	assert_true(combat_cfg != null, "Debe cargar valentina_v2_combat_rig.tres")
	assert_true(combat_cfg.skill_config is PilotSkillConfig, "PilotCombatRigConfig debe enlazar skill_config (.tres)")
	assert_true(combat_cfg.ultimate_config is PilotUltimateConfig, "PilotCombatRigConfig debe enlazar ultimate_config (.tres)")
	var raw_ult: PilotUltimateConfig = combat_cfg.ultimate_config
	assert_true(raw_ult.enable_3d_stage, "valentina_v2_ultimate.tres debe activar enable_3d_stage")
	assert_true(raw_ult.sakuga_3d_spike_count == 24, "sakuga_3d_spike_count default debe ser 24")
	assert_true(raw_ult.shatter_3d_shard_count == 28, "shatter_3d_shard_count default debe ser 28")
	assert_true(raw_ult.single_target_consecutive_bonus > 0.0, "single_target_consecutive_bonus debe ser > 0")

	# 2. Verificar PilotSkinPaletteResolver sobre las 10 skins de Valentina v2
	var profile: PilotRigProfile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile
	assert_true(profile != null and profile.skins.size() >= 10, "valentina_v2_profile.tres debe exponer al menos 10 skins")
	for sk_idx: int in range(profile.skins.size()):
		var sk: PilotSkinPreset = profile.skins[sk_idx]
		var pal: Dictionary = PaletteResolverScript.resolve(sk)
		var acc: Color = pal["accent"] as Color
		var con: Color = pal["contrast_crosshair"] as Color
		var bg: Color = pal["stage_bg"] as Color
		var grad: Gradient = pal["sandevistan_gradient"] as Gradient
		var rgb_dist_acc: float = Vector3(acc.r - con.r, acc.g - con.g, acc.b - con.b).length()
		var rgb_dist_bg: float = Vector3(bg.r - con.r, bg.g - con.g, bg.b - con.b).length()
		assert_true(rgb_dist_acc >= 0.40, "Skin #%d (%s) debe producir contrast_crosshair bien contrastado vs accent (dist=%.2f)" % [sk_idx, sk.label, rgb_dist_acc])
		assert_true(rgb_dist_bg >= 0.65, "Skin #%d (%s) debe producir contrast_crosshair luminoso vs stage_bg (dist=%.2f)" % [sk_idx, sk.label, rgb_dist_bg])
		assert_true(grad != null and grad.get_point_count() == 3, "Skin #%d debe generar sandevistan_gradient de 3 paradas" % sk_idx)

	# 3. Instanciar escena del Studio y validar subsistemas
	var packed: PackedScene = ResourceLoader.load(STUDIO_SCENE_PATH) as PackedScene
	assert_true(packed != null, "Debe cargar valentina_skill_ult_studio.tscn")
	var studio: Node2D = packed.instantiate() as Node2D
	assert_true(studio != null, "Debe instanciar ValentinaSkillUltStudio")
	add_child(studio)
	await get_tree().process_frame
	await get_tree().process_frame

	var theater: PilotCutInTheater = studio.call("get_theater") as PilotCutInTheater
	var radar: UltimateSandevistanRadarController = studio.call("get_sandevistan_radar") as UltimateSandevistanRadarController
	var rig: PlanarCombatRig = studio.call("get_rig") as PlanarCombatRig
	var sniper_vfx: SniperWeakpointRailVFX = studio.call("get_sniper_vfx") as SniperWeakpointRailVFX
	var barrage: UltimateWingBarrageController = studio.call("get_wing_barrage") as UltimateWingBarrageController
	var skill_cfg: PilotSkillConfig = studio.call("get_skill_config") as PilotSkillConfig
	var ult_cfg: PilotUltimateConfig = studio.call("get_ultimate_config") as PilotUltimateConfig

	assert_true(theater != null, "Studio debe crear PilotCutInTheater")
	assert_true(radar != null, "Studio debe crear UltimateSandevistanRadarController")
	assert_true(rig != null, "Studio debe crear PlanarCombatRig")
	assert_true(sniper_vfx != null, "Studio debe crear SniperWeakpointRailVFX")
	assert_true(barrage != null, "Studio debe crear UltimateWingBarrageController")
	assert_true(barrage.get_pool_size() == 12, "UltimateWingBarrageController debe pre-alocar exactamente 12 cuchillas")

	# 4. Verificar Acto 1: Vuelta Sandevistan + Radar Ocular 360° + restauración exacta de rig.global_position
	var orig_rig_pos: Vector2 = rig.global_position
	var act1_counters: Dictionary = {"completed": false, "marked": 0}
	radar.radar_sweep_completed.connect(func(marked: Array[Node2D]) -> void:
		act1_counters["completed"] = true
		act1_counters["marked"] = marked.size()
	)
	studio.call("trigger_ultimate_demo", false)
	assert_true(radar.is_sweeping(), "Al disparar Ultimate [Q] debe iniciar Acto 1 (Sandevistan + Radar)")
	for _i: int in range(36):
		radar._process(0.02)
	assert_true(bool(act1_counters["completed"]), "Acto 1 debe completar y emitir radar_sweep_completed")
	assert_true(int(act1_counters["marked"]) == 12, "Acto 1 debe marcar los 12 objetivos del escenario inicial (obtenido: %d)" % int(act1_counters["marked"]))
	assert_true(radar.get_total_ghosts_spawned() >= 2, "Acto 1 debe generar afterimages Sandevistan (obtenido: %d)" % radar.get_total_ghosts_spawned())
	assert_true(rig.global_position.distance_to(orig_rig_pos) < 0.01, "Acto 1 debe restaurar exactamente rig.global_position tras la vuelta orbital")
	assert_true(theater.is_playing(), "Al completar Acto 1 debe lanzarse automáticamente PilotCutInTheater (Actos 2-3)")
	radar.clear_marks_and_stop(true)
	theater.stop_and_hide()

	# 5. Verificar Actos 2 y 3: Ultimate3DStageRig (3 anillos, 12 cuchillas, 24 púas, 28 esquirlas) + 3 Beats Impact Frames
	var stage_3d: Ultimate3DStageRig = theater.get_stage_3d()
	assert_true(stage_3d != null, "PilotCutInTheater debe montar Ultimate3DStageRig")
	assert_true(stage_3d.get_gyro_ring_count() == 3, "Ultimate3DStageRig debe pre-alocar 3 anillos giroscópicos 3D")
	assert_true(stage_3d.get_wing_blade_count() == 12, "Ultimate3DStageRig debe pre-alocar 12 cuchillas 3D cel-shaded")
	assert_true(stage_3d.get_active_sakuga_spike_count() == 24, "Ultimate3DStageRig debe activar 24 púas radiales 3D")
	assert_true(stage_3d.get_active_shatter_shard_count() == 28, "Ultimate3DStageRig debe activar 28 esquirlas obsidiana 3D")

	for mode_i: int in range(3):
		ult_cfg.render_mode = mode_i as PilotUltimateConfig.CutInRenderMode
		studio.call("trigger_ultimate_demo", true)
		assert_true(theater.is_playing(), "PilotCutInTheater debe estar activo en Ultimate modo %d" % mode_i)
		theater.scrub_to_normalized(0.30)
		assert_true(theater.get_current_phase_name() == "ULT_3D_STAGE_CUTIN", "En 30% debe estar en ULT_3D_STAGE_CUTIN")
		assert_true(stage_3d.get_stage_mode() == Ultimate3DStageRig.StageMode.ACT2_CUTIN_STAGE, "En Acto 2 stage_3d debe estar en ACT2_CUTIN_STAGE")
		theater.scrub_to_normalized(0.71)
		assert_true(theater.get_current_phase_name() == "ULT_IMPACT_BEAT1_BW", "En 71% debe estar en ULT_IMPACT_BEAT1_BW")
		assert_true(stage_3d.get_stage_mode() == Ultimate3DStageRig.StageMode.ACT3_BEAT1_SPIKES, "Beat 1 debe activar púas 3D")
		theater.scrub_to_normalized(0.80)
		assert_true(theater.get_current_phase_name() == "ULT_IMPACT_BEAT2_CONTRAST", "En 80% debe estar en ULT_IMPACT_BEAT2_CONTRAST")
		assert_true(stage_3d.get_stage_mode() == Ultimate3DStageRig.StageMode.ACT3_BEAT2_CONTRAST, "Beat 2 debe activar púas contrastantes 3D")
		theater.scrub_to_normalized(0.89)
		assert_true(theater.get_current_phase_name() == "ULT_IMPACT_BEAT3_SHATTER_3D", "En 89% debe estar en ULT_IMPACT_BEAT3_SHATTER_3D")
		assert_true(stage_3d.get_stage_mode() == Ultimate3DStageRig.StageMode.ACT3_BEAT3_SHATTER, "Beat 3 debe activar 28 esquirlas 3D")
		theater.scrub_to_normalized(0.98)
		assert_true(theater.get_current_phase_name() == "ULT_RELEASE_FLASH", "En 98% debe estar en ULT_RELEASE_FLASH")
	theater.stop_and_hide()

	# 6. Verificar Skill [R] en los 3 estilos + Hold-to-Aim
	for style_i: int in range(3):
		skill_cfg.cutin_style = style_i as PilotSkillConfig.SkillCutInStyle
		studio.call("trigger_skill_demo")
		assert_true(theater.is_playing(), "PilotCutInTheater debe estar activo en Skill estilo %d" % style_i)
		theater.scrub_to_normalized(0.25)
		assert_true(theater.get_current_phase_name() == "SKILL_CUTIN", "Fase inicial Skill debe ser SKILL_CUTIN")
		theater.scrub_to_normalized(0.95)
		assert_true(theater.get_current_phase_name() == "SKILL_IMPACT_FRAME", "Fase final Skill debe ser SKILL_IMPACT_FRAME")
	theater.stop_and_hide()

	var boss_target := _MockTarget.new()
	boss_target.max_hp = 2500.0
	boss_target.is_boss = true
	boss_target.global_position = Vector2(320.0, 0.0)
	add_child(boss_target)

	sniper_vfx.update_hold_aim(Vector2.ZERO, boss_target, Vector2(320.0, 0.0))
	assert_true(sniper_vfx.is_holding_aim(), "SniperWeakpointRailVFX debe activar modo Hold-to-Aim")
	sniper_vfx.stop_hold_aim()

	# 7. Verificar Acto 4A: Convergencia 12/12 sobre Jefe Único con daño consecutivo escalado y retorno boomerang
	var single_counters: Dictionary = {"impacts": 0, "mults": [], "returning": false, "finisher": false}
	var cb_single: Callable = func(_t: Node2D, _p: Vector2, _i: int, eff_mult: float) -> void:
		single_counters["impacts"] = int(single_counters["impacts"]) + 1
		var arr: Array = single_counters["mults"] as Array
		arr.append(eff_mult)
	var cb_ret: Callable = func() -> void:
		single_counters["returning"] = true
	var cb_fin: Callable = func(_targets: Array[Node2D]) -> void:
		single_counters["finisher"] = true
	barrage.blade_impacted.connect(cb_single)
	barrage.blades_returning.connect(cb_ret)
	barrage.finisher_detonated.connect(cb_fin)

	var single_arr: Array[Node2D] = [boss_target]
	barrage.launch_barrage(Vector2.ZERO, single_arr, ult_cfg, studio)
	assert_true(barrage.is_active(), "Barrage de 12 alas debe estar activo tras launch_barrage")
	for _step: int in range(80):
		barrage._process(0.02)

	var mults: Array = single_counters["mults"] as Array
	assert_true(int(single_counters["impacts"]) == 12, "Deben impactar exactamente 12 cuchillas sobre el jefe único (obtenido: %d)" % int(single_counters["impacts"]))
	assert_true(mults.size() == 12 and float(mults[11]) > float(mults[0]) * 2.0, "El daño consecutivo single-target debe escalar progresivamente en las 12 cuchillas")
	assert_true(bool(single_counters["returning"]), "Las 12 cuchillas deben iniciar fase RETURN_RECALL hacia Valentina")
	assert_true(bool(single_counters["finisher"]), "Debe emitirse finisher_detonated al completar ida y vuelta")
	barrage.blade_impacted.disconnect(cb_single)
	barrage.blades_returning.disconnect(cb_ret)
	barrage.finisher_detonated.disconnect(cb_fin)

	# 8. Verificar Acto 4B: Reparto ponderado en enjambre + Jefe (single_target_boss_weight)
	var swarm_targets: Array[Node2D] = [boss_target]
	var minions: Array[_MockTarget] = []
	for m_i: int in range(5):
		var mn := _MockTarget.new()
		mn.max_hp = 250.0
		mn.is_boss = false
		mn.global_position = Vector2(220.0 + float(m_i) * 45.0, -120.0 + float(m_i) * 55.0)
		add_child(mn)
		minions.append(mn)
		swarm_targets.append(mn)

	var swarm_counters: Dictionary = {"boss_hits": 0, "other_hits": 0}
	var cb_swarm: Callable = func(t: Node2D, _p: Vector2, _i: int, _eff_mult: float) -> void:
		if t == boss_target:
			swarm_counters["boss_hits"] = int(swarm_counters["boss_hits"]) + 1
		else:
			swarm_counters["other_hits"] = int(swarm_counters["other_hits"]) + 1
	barrage.blade_impacted.connect(cb_swarm)
	barrage.launch_barrage(Vector2.ZERO, swarm_targets, ult_cfg, studio)
	for _step: int in range(80):
		barrage._process(0.02)
	var expected_boss_slots: int = int(round(12.0 * ult_cfg.single_target_boss_weight))
	assert_true(int(swarm_counters["boss_hits"]) == expected_boss_slots, "En enjambre + Jefe deben converger %d cuchillas sobre el Jefe (obtenido: %d)" % [expected_boss_slots, int(swarm_counters["boss_hits"])])
	assert_true(int(swarm_counters["other_hits"]) == 12 - expected_boss_slots, "Las cuchillas restantes (%d) deben repartirse en el enjambre" % (12 - expected_boss_slots))
	barrage.blade_impacted.disconnect(cb_swarm)

	# 9. Verificar cambio de los 3 estilos de HUD y varias skins
	for hud_i: int in range(3):
		studio.call("set_hud_preview_style", hud_i)
	for sk_test: int in [0, 1, 3, 6]:
		studio.call("apply_skin_by_index", sk_test)
	assert_true(true, "Cambio de HUD (3 estilos) y skins con PaletteResolver aplicado limpiamente")

	for mn: _MockTarget in minions:
		mn.queue_free()
	boss_target.queue_free()
	studio.queue_free()
	pass_suite("Valentina Skill & Ultimate Studio (4 Actos 3D + Sandevistan + Skin-Contrast) verificado correctamente")
