extends BaseTestSuite

## Suite de verificación headless para Lab Invocador Gacha 3D Hype (Fase 2 — Estación Astral v2).
## Valida contrato ArcSys de 3 superficies en las 7 mallas del Invocador, sesión aislada sobre
## GachaBannerEngine (sin mutar SaveManager), coreografía de 5 fases + Fake-Out + Saltar,
## cascada multi-tirada x10 con ShaderSkinLivePreview único y equipar en vivo sobre Valentina v2.

const LAB_SCENE_PATH: String = "res://sandbox/hub_art_lab/gacha_3d_lab.tscn"
const Gacha3DLabScript = preload("res://sandbox/hub_art_lab/gacha_3d_lab.gd")
const MeshBuilder = preload("res://sandbox/hub_art_lab/meshes/hub_gacha_summoner_mesh_builder.gd")
const SessionScript = preload("res://sandbox/hub_art_lab/components/gacha_3d_session_controller.gd")
const SummonerScript = preload("res://sandbox/hub_art_lab/components/hub_gacha_summoner_3d.gd")
const ConfigScript = preload("res://sandbox/hub_art_lab/resources/hub_gacha_3d_config.gd")
const DEFAULT_CONFIG: ConfigScript = preload("res://sandbox/hub_art_lab/data/default_hub_gacha_3d_config.tres")
const GachaBannerEngineScript = preload("res://scenes/ui/gacha/components/gacha_banner_engine.gd")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")

var _phase_history: Array[int] = []
var _fakeout_count: int = 0
var _burst_count: int = 0
var _reveal_count: int = 0


func _ready() -> void:
	timeout_seconds = 14.0
	super._ready()
	await _run_tests()


func _run_tests() -> void:
	_test_summoner_meshes_arcsys_contract()
	_test_session_and_gacha_banner_engine_isolated()
	_test_five_phase_choreography_fakeout_and_skip()
	await _test_gacha_3d_lab_scene_equip_and_multi_pull()
	pass_suite("Fase 2 Gacha3DLab verificada: 7 mallas ArcSys, GachaBannerEngine aislado, 5 fases + Fake-Out, x10 y equipar en vivo.")


func _test_summoner_meshes_arcsys_contract() -> void:
	var hero_meshes: Array[Dictionary] = [
		{"name": "PedestalBase", "mesh": MeshBuilder.build_pedestal_base_mesh()},
		{"name": "OuterRing", "mesh": MeshBuilder.build_outer_ring_mesh()},
		{"name": "MidRing", "mesh": MeshBuilder.build_mid_ring_mesh()},
		{"name": "InnerRing", "mesh": MeshBuilder.build_inner_ring_mesh()},
		{"name": "CoreUpperHalf", "mesh": MeshBuilder.build_core_upper_half_mesh()},
		{"name": "CoreLowerHalf", "mesh": MeshBuilder.build_core_lower_half_mesh()},
		{"name": "RewardCapsule", "mesh": MeshBuilder.build_reward_capsule_mesh()},
	]

	for item: Dictionary in hero_meshes:
		var m: ArrayMesh = item["mesh"] as ArrayMesh
		var label: String = str(item["name"])
		assert_true(m != null and m.get_surface_count() == 3, "%s debe tener exactamente 3 superficies (ARMOR/CHASSIS/CRYSTAL)" % label)
		for surf_idx: int in range(3):
			var arr: Array = m.surface_get_arrays(surf_idx)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] as PackedVector3Array
			assert_true(verts.size() >= 3 and norms.size() == verts.size(), "%s superficie %d debe tener vértices y normales válidas" % [label, surf_idx])
			var tri_cross: Vector3 = (verts[2] - verts[0]).cross(verts[1] - verts[0]).normalized()
			assert_true(tri_cross.dot(norms[0]) > 0.9, "%s superficie %d debe mantener winding horario saliente" % [label, surf_idx])

	var spark_m: ArrayMesh = MeshBuilder.build_spark_shard_mesh()
	assert_true(spark_m != null and spark_m.get_surface_count() == 1, "SparkShardMesh debe tener 1 superficie")


func _test_session_and_gacha_banner_engine_isolated() -> void:
	var real_tokens_before: int = SaveManagerScript.get_gacha_tokens()
	var real_pity_gen_before: int = SaveManagerScript.get_banner_pity("general")
	var real_pity_ships_before: int = SaveManagerScript.get_banner_pity("ships")
	var real_pity_pilots_before: int = SaveManagerScript.get_banner_pity("pilots")
	var real_unlocked_before: int = SaveManagerScript.get_unlocked_skins().size()

	var session := SessionScript.new() as SessionScript
	session.setup(DEFAULT_CONFIG)
	assert_true(session.get_tokens() == DEFAULT_CONFIG.sandbox_initial_tokens, "Sesión sandbox debe iniciar con sandbox_initial_tokens")

	for banner_id: String in ["general", "ships", "pilots"]:
		var pool: Array[Dictionary] = session.get_pool_for_banner(banner_id)
		assert_true(not pool.is_empty(), "Pool de GachaBannerEngine para '%s' no debe estar vacío" % banner_id)
		var has_epic_in_pool: bool = false
		for entry: Dictionary in pool:
			if str(entry.get("rarity", "")) == "epic":
				has_epic_in_pool = true
				break
		assert_true(has_epic_in_pool, "Pool '%s' debe contener al menos una skin épica" % banner_id)

	var b1: Dictionary = session.execute_pull_batch("general", 1, SessionScript.PullOverride.FORCE_COMMON)
	assert_true(bool(b1.get("ok", false)), "Tirada x1 FORCE_COMMON debe ejecutarse")
	assert_true(str(b1.get("highest_rarity", "")) == "common", "FORCE_COMMON debe producir rareza common")
	assert_true(not bool(b1.get("is_fakeout", true)), "FORCE_COMMON nunca debe disparar Fake-Out")
	assert_true(session.get_tokens() == DEFAULT_CONFIG.sandbox_initial_tokens - 1, "Debe descontar 1 ficha en sesión simulada")

	var b5: Dictionary = session.execute_pull_batch("ships", 5, SessionScript.PullOverride.FORCE_EPIC)
	assert_true(bool(b5.get("ok", false)) and (b5.get("results", []) as Array).size() == 5, "Tirada x5 debe devolver 5 resultados")
	assert_true(bool(b5.get("has_epic", false)), "FORCE_EPIC debe garantizar al menos una épica")

	var b_pity: Dictionary = session.execute_pull_batch("pilots", 1, SessionScript.PullOverride.FORCE_PITY)
	assert_true(bool(b_pity.get("ok", false)) and bool(b_pity.get("has_pity", false)), "FORCE_PITY debe activar is_pity == true")
	assert_true(bool(b_pity.get("has_epic", false)), "FORCE_PITY debe otorgar resultado épico")
	assert_true(int(b_pity.get("final_pity", -1)) == 0, "Pity disparado debe reiniciar contador a 0 vía GachaBannerEngine")

	var b_fake: Dictionary = session.execute_pull_batch("general", 1, SessionScript.PullOverride.FORCE_FAKEOUT)
	assert_true(bool(b_fake.get("ok", false)) and bool(b_fake.get("is_fakeout", false)) and bool(b_fake.get("has_epic", false)), "FORCE_FAKEOUT debe marcar is_fakeout y has_epic")

	# Consumir saldo (restan 22 tras 1+5+1+1) hasta bajar de 10 y luego rechazar x10 y recargar
	var b10_a: Dictionary = session.execute_pull_batch("general", 10, SessionScript.PullOverride.NATURAL)
	assert_true(bool(b10_a.get("ok", false)) and (b10_a.get("results", []) as Array).size() == 10, "Primera tirada x10 debe devolver 10 resultados")
	var b10_b: Dictionary = session.execute_pull_batch("general", 10, SessionScript.PullOverride.NATURAL)
	assert_true(bool(b10_b.get("ok", false)) and (b10_b.get("results", []) as Array).size() == 10, "Segunda tirada x10 debe devolver 10 resultados")
	var b10_fail: Dictionary = session.execute_pull_batch("general", 10, SessionScript.PullOverride.NATURAL)
	assert_true(not bool(b10_fail.get("ok", true)) and str(b10_fail.get("error", "")) == "insufficient_tokens", "Debe rechazar tirada x10 si faltan fichas")
	var tokens_after_refill: int = session.add_tokens(DEFAULT_CONFIG.sandbox_refill_amount)
	assert_true(tokens_after_refill >= 20, "add_tokens debe recargar fichas de sandbox")

	assert_true(SaveManagerScript.get_gacha_tokens() == real_tokens_before, "SaveManager tokens reales NO deben mutar")
	assert_true(SaveManagerScript.get_banner_pity("general") == real_pity_gen_before, "SaveManager pity general NO debe mutar")
	assert_true(SaveManagerScript.get_banner_pity("ships") == real_pity_ships_before, "SaveManager pity ships NO debe mutar")
	assert_true(SaveManagerScript.get_banner_pity("pilots") == real_pity_pilots_before, "SaveManager pity pilots NO debe mutar")
	assert_true(SaveManagerScript.get_unlocked_skins().size() == real_unlocked_before, "SaveManager skins desbloqueadas NO deben mutar")


func _test_five_phase_choreography_fakeout_and_skip() -> void:
	var summoner := SummonerScript.new() as SummonerScript
	summoner.setup(DEFAULT_CONFIG)
	assert_true(summoner.get_ring_nodes().size() == 3, "HubGachaSummoner3D debe exponer los 3 pivotes de anillos")

	_phase_history.clear()
	_fakeout_count = 0
	_burst_count = 0
	_reveal_count = 0
	summoner.phase_changed.connect(func(p: int) -> void: _phase_history.append(p))
	summoner.fakeout_triggered.connect(func() -> void: _fakeout_count += 1)
	summoner.burst_triggered.connect(func(_e: bool) -> void: _burst_count += 1)
	summoner.reveal_ready.connect(func(_b: Dictionary) -> void: _reveal_count += 1)

	var fakeout_batch: Dictionary = {
		"ok": true,
		"banner_id": "general",
		"count": 1,
		"results": [],
		"highest_rarity": "epic",
		"has_epic": true,
		"has_pity": false,
		"is_fakeout": true,
	}
	summoner.start_sequence(fakeout_batch)
	assert_true(summoner.get_phase() == SummonerScript.SequencePhase.FRAMING, "Debe iniciar en FRAMING")
	assert_true(not summoner.can_skip(), "Saltar debe estar bloqueado en t = 0.0")

	for _step: int in range(90):
		summoner.step_sequence(0.025)

	var expected_seq: Array[int] = [
		SummonerScript.SequencePhase.FRAMING,
		SummonerScript.SequencePhase.CHARGING,
		SummonerScript.SequencePhase.TENSION,
		SummonerScript.SequencePhase.BLOOM_BURST,
		SummonerScript.SequencePhase.REVEAL,
	]
	assert_true(_phase_history == expected_seq, "Coreografía debe recorrer exactamente las 5 fases en orden: %s" % str(_phase_history))
	assert_true(_fakeout_count == 1 and summoner.was_fakeout_triggered(), "Fake-Out debe romperse una sola vez durante TENSION")
	assert_true(_burst_count == 1 and _reveal_count == 1, "Debe emitir exactamente 1 burst y 1 reveal_ready")
	assert_true(summoner.get_core_separation() > 0.25, "Las 2 mitades del núcleo deben separarse al estallar")

	# Segunda tirada: probar ventana de Saltar (t < 0.20 bloqueado, t >= 0.20 habilitado)
	summoner.reset_to_idle()
	assert_true(summoner.get_phase() == SummonerScript.SequencePhase.IDLE, "reset_to_idle debe volver a IDLE")
	assert_true(is_equal_approx(summoner.get_core_separation(), 0.0), "reset_to_idle debe cerrar el núcleo")

	_reveal_count = 0
	summoner.start_sequence({"ok": true, "banner_id": "ships", "count": 1, "results": [], "highest_rarity": "common", "has_epic": false, "is_fakeout": false})
	summoner.step_sequence(0.05)
	assert_true(not summoner.can_skip(), "can_skip debe seguir false a t = 0.05s (< 0.20s)")
	summoner.step_sequence(0.20)
	assert_true(summoner.can_skip(), "can_skip debe habilitarse a partir de t = 0.25s (>= 0.20s)")
	var skipped: bool = summoner.skip_to_reveal()
	assert_true(skipped and summoner.get_phase() == SummonerScript.SequencePhase.REVEAL, "skip_to_reveal debe llevar inmediatamente a REVEAL")
	assert_true(_reveal_count == 1, "skip_to_reveal debe emitir reveal_ready")

	summoner.queue_free()


func _test_gacha_3d_lab_scene_equip_and_multi_pull() -> void:
	var real_tokens_before: int = SaveManagerScript.get_gacha_tokens()
	var packed: PackedScene = load(LAB_SCENE_PATH) as PackedScene
	assert_true(packed != null, "Debe cargar gacha_3d_lab.tscn")

	var lab: Gacha3DLabScript = packed.instantiate() as Gacha3DLabScript
	assert_true(lab != null, "Debe instanciar Gacha3DLab")
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(lab.summoner != null and lab.session != null and lab.overlay != null and lab.camera != null, "Gacha3DLab debe montar todos sus sub-controladores")
	assert_true(lab.pilot_avatar != null, "Gacha3DLab debe montar HubRigAvatar3D de Valentina")
	var rig: PlanarCombatRig = lab.pilot_avatar.get_rig()
	assert_true(rig != null and rig.pilot_profile != null and rig.pilot_profile.pilot_id == "valentina_v2", "El avatar del lab debe ser valentina_v2")

	# Verificar color por banner
	lab.select_banner("ships")
	var ships_col: Color = (GachaBannerEngineScript.get_banner_config("ships").get("color", Color.WHITE) as Color)
	assert_true(lab.summoner.get_active_energy_color().is_equal_approx(ships_col), "Banner 'ships' debe actualizar el color del Invocador")

	lab.select_banner("pilots")
	var pilots_col: Color = (GachaBannerEngineScript.get_banner_config("pilots").get("color", Color.WHITE) as Color)
	assert_true(lab.summoner.get_active_energy_color().is_equal_approx(pilots_col), "Banner 'pilots' debe actualizar el color del Invocador")

	# Multi-pull x10 en banner pilots + skip + cascada + equipar skin de piloto en vivo
	var batch10: Dictionary = lab.request_pull(10, SessionScript.PullOverride.FORCE_EPIC)
	assert_true(bool(batch10.get("ok", false)), "request_pull(10) debe ejecutarse")
	lab.summoner.step_sequence(0.25)
	assert_true(lab.request_skip(), "request_skip debe funcionar tras 0.25s")
	await get_tree().process_frame

	assert_true(lab.overlay.is_reveal_visible(), "Reveal overlay debe abrirse tras skip")
	assert_true(lab.overlay.get_cascade_card_count() == 10, "La grilla multi-tirada debe mostrar 10 cartas")
	assert_true(lab.overlay.get_live_preview() != null, "Debe existir el ShaderSkinLivePreview compartido")

	var results10: Array = batch10.get("results", []) as Array
	var pilot_idx: int = -1
	for i: int in range(results10.size()):
		var item: Dictionary = results10[i] as Dictionary
		var sdata: Dictionary = item.get("skin_data", {}) as Dictionary
		if str(sdata.get("category", "")) == "pilot" and bool(item.get("is_shader_skin", false)):
			pilot_idx = i
			break

	assert_true(pilot_idx >= 0, "Una tirada x10 en 'pilots' debe incluir al menos una skin shader de piloto")
	lab.overlay.select_reward_index(pilot_idx)
	var eq_pilot: Dictionary = lab.equip_selected_reward()
	assert_true(bool(eq_pilot.get("ok", false)), "equip_selected_reward debe equipar la skin de piloto")
	var pilot_preset: PilotSkinPreset = eq_pilot.get("preset", null) as PilotSkinPreset
	assert_true(pilot_preset != null and lab.pilot_avatar.get_active_skin_id() == pilot_preset.id, "Valentina en el lab debe reflejar la skin equipada")

	# Probar equipar alas 3D desde banner 'ships'
	lab.close_reveal()
	lab.select_banner("ships")
	var wings_skin_dict: Dictionary = {}
	for entry: Dictionary in lab.session.get_pool_for_banner("ships"):
		if str(entry.get("category", "")) == "wings" and bool(entry.get("is_shader_skin", false)):
			wings_skin_dict = entry
			break
	assert_true(not wings_skin_dict.is_empty(), "El pool 'ships' debe tener skins shader de alas")
	lab._equip_reward({"skin_data": wings_skin_dict, "new_stars": 2})
	var wings_preset: PilotSkinPreset = CosmeticsManager.get_skin_preset(str(wings_skin_dict.get("id", "")))
	assert_true(rig.enable_3d_wings, "Equipar skin de alas debe encender Alas 3D en vivo sobre Valentina")
	assert_true(wings_preset != null and rig.get_active_wings_skin_id() == wings_preset.id, "Las alas 3D deben recibir el preset equipado")

	assert_true(SaveManagerScript.get_gacha_tokens() == real_tokens_before, "Gacha3DLab no debe modificar el archivo SaveManager real")

	lab.queue_free()
	await get_tree().process_frame
