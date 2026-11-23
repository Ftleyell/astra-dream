extends BaseTestSuite
## Suite de verificación para el laboratorio 3D Cel-Shaded (Valentina3DLab — Alas Astral Seraph 3D).

const LAB_SCENE_PATH: String = "res://sandbox/pilot_rig_lab/3d_lab/valentina_3d_lab.tscn"
const WingsCtrlScript = preload("res://scenes/pilots/vfx/astral_wings_3d_controller.gd")
const MeshBuilderScript = preload("res://scenes/pilots/vfx/astral_wings_3d_mesh_builder.gd")
const ConfigScript = preload("res://data/pilots/schemas/pilot_wings_3d_config.gd")
const SkinPresetScript = preload("res://data/pilots/schemas/pilot_skin_preset.gd")


func _ready() -> void:
	timeout_seconds = 10.0
	super._ready()
	_run_tests()


func _run_tests() -> void:
	var packed: PackedScene = load(LAB_SCENE_PATH) as PackedScene
	assert_true(packed != null, "Debe cargar valentina_3d_lab.tscn")

	var lab: Node2D = packed.instantiate() as Node2D
	assert_true(lab != null, "Debe instanciar Valentina3DLab")
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame

	var rig: PlanarCombatRig = lab.call("get_rig") as PlanarCombatRig
	var ctrl: WingsCtrlScript = lab.call("get_wings_controller") as WingsCtrlScript
	var cfg: ConfigScript = lab.call("get_config") as ConfigScript

	assert_true(rig != null, "Valentina3DLab debe instanciar PlanarCombatRig")
	assert_true(ctrl != null, "Valentina3DLab debe instanciar AstralWings3DController")
	assert_true(cfg != null, "Valentina3DLab debe cargar PilotWings3DConfig (.tres)")
	assert_true(ctrl.get_blade_count() == 12, "Debe construir exactamente 12 cuchillas 3D (6 por ala)")
	assert_true(ctrl.get_total_triangle_count() > 200, "Las mallas 3D procedurales deben tener geometría facetada real")

	# Validar contrato de 3 superficies en los 3 tiers
	for tier: int in range(3):
		var m: ArrayMesh = MeshBuilderScript.build_wing_blade_mesh(tier)
		assert_true(m != null and m.get_surface_count() == 3, "Tier %d debe tener exactamente 3 superficies (Armor/Chassis/Crystal)" % tier)

	# Validar winding horario contra BoxMesh de Godot 4
	var box_arr: Array = BoxMesh.new().get_mesh_arrays()
	var b_verts: PackedVector3Array = box_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var b_norms: PackedVector3Array = box_arr[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var b_idx: PackedInt32Array = box_arr[Mesh.ARRAY_INDEX] as PackedInt32Array
	var box_cross: Vector3 = (b_verts[b_idx[2]] - b_verts[b_idx[0]]).cross(b_verts[b_idx[1]] - b_verts[b_idx[0]]).normalized()
	assert_true(box_cross.dot(b_norms[b_idx[0]]) > 0.9, "Winding (c-a)x(b-a) debe coincidir con BoxMesh")

	# Validar determinismo pausando _process
	lab.set_process(false)

	# 1. Vista Sur (0°): las 12 cuchillas quedan detrás de Valentina
	ctrl.set_pilot_yaw_rad(0.0)
	ctrl.set_anim_state(WingsCtrlScript.AnimState.IDLE_ZERO_G, true)
	var fb_south: Vector2i = ctrl.get_front_back_counts()
	assert_true(fb_south.x == 0 and fb_south.y == 12, "En vista Sur (0°) todas las cuchillas deben estar detrás (got front=%d back=%d)" % [fb_south.x, fb_south.y])

	# 2. Vista Norte (180°): las 12 cuchillas pasan delante de la espalda de Valentina
	ctrl.set_pilot_yaw_rad(PI)
	ctrl.step(0.0, true)
	var fb_north: Vector2i = ctrl.get_front_back_counts()
	assert_true(fb_north.x == 12 and fb_north.y == 0, "En vista Norte (180°) todas las cuchillas deben pasar adelante (got front=%d back=%d)" % [fb_north.x, fb_north.y])

	# 3. Vista Este (90°): ala cercana adelante (6), ala lejana atrás (6)
	ctrl.set_pilot_yaw_rad(PI * 0.5)
	ctrl.step(0.0, true)
	var fb_east: Vector2i = ctrl.get_front_back_counts()
	assert_true(fb_east.x == 6 and fb_east.y == 6, "En vista Este (90°) debe dividir 6 adelante y 6 atrás (got front=%d back=%d)" % [fb_east.x, fb_east.y])

	# 4. Escudo Aegis en vista Sur (0°): cruza adelante del piloto (front == 12)
	ctrl.set_pilot_yaw_rad(0.0)
	ctrl.set_anim_state(WingsCtrlScript.AnimState.AEGIS_GUARD, true)
	var fb_aegis: Vector2i = ctrl.get_front_back_counts()
	assert_true(fb_aegis.x == 12, "Escudo Aegis en vista Sur debe proyectar las 12 cuchillas adelante (got front=%d)" % fb_aegis.x)

	# 5. Probar las 6 animaciones 3D con step continuo y proyección 3D→2D finita
	for anim_id: int in range(6):
		ctrl.set_anim_state(anim_id, false)
		ctrl.step(0.12, false)
		var st0: Dictionary = ctrl.get_blade_state(0)
		var st6: Dictionary = ctrl.get_blade_state(6)
		var tip0: Vector2 = st0["tip_2d"] as Vector2
		var tip6: Vector2 = st6["tip_2d"] as Vector2
		assert_true(is_finite(tip0.x) and is_finite(tip0.y), "Anim %d debe proyectar tip_2d finita en ala izquierda" % anim_id)
		assert_true(is_finite(tip6.x) and is_finite(tip6.y), "Anim %d debe proyectar tip_2d finita en ala derecha" % anim_id)

	# 6. Verificar pulso/recoil y decaimiento
	ctrl.set_anim_state(WingsCtrlScript.AnimState.FULL_BURST, true)
	ctrl.trigger_pulse(0)
	var st_fire: Dictionary = ctrl.get_blade_state(0)
	assert_true(float(st_fire["recoil"]) > 0.9, "trigger_pulse debe activar recoil en la cuchilla")
	assert_true(float(st_fire["fire_flash"]) > 1.0, "trigger_pulse debe activar fire_flash en la cuchilla")
	ctrl.step(0.25, false)
	var st_decay: Dictionary = ctrl.get_blade_state(0)
	assert_true(float(st_decay["recoil"]) < 0.35, "recoil debe recuperarse suavemente")

	# 7. Verificar sincronización de skin personalizada
	var test_skin := SkinPresetScript.new()
	test_skin.id = "emerald_test"
	test_skin.is_base_skin = false
	test_skin.accent_color = Color(0.15, 0.95, 0.55, 1.0)
	test_skin.panel_color = Color(0.78, 0.92, 0.88, 1.0)
	test_skin.suit_dark_color = Color(0.08, 0.16, 0.14, 1.0)
	ctrl.apply_skin_preset(test_skin)
	assert_true(ctrl.get_active_skin_id() == "emerald_test", "Debe sincronizar skin personalizada en las alas 3D")

	# 8. Estandarización Multi-Piloto en PlanarCombatRig (enable_3d_wings vía PilotRigProfile)
	var std_profile: PilotRigProfile = load("res://data/pilots/valentina_v2/valentina_v2_profile.tres") as PilotRigProfile
	assert_true(std_profile != null and std_profile.wings_3d_config != null, "valentina_v2_profile.tres debe enlazar wings_3d_config")
	assert_true(std_profile.prefer_3d_wings == true, "valentina_v2_profile.tres debe preferir alas 3D estandarizadas")

	var std_rig: PlanarCombatRig = (load("res://scenes/pilots/rig/planar_combat_rig.gd") as Script).new() as PlanarCombatRig
	std_rig.pilot_profile = std_profile
	std_rig.enable_3d_wings = true
	add_child(std_rig)
	await get_tree().process_frame

	var std_w3d: WingsCtrlScript = std_rig.get_3d_wings_controller()
	assert_true(std_w3d != null and std_w3d.is_wings_mounted(), "PlanarCombatRig con enable_3d_wings debe montar AstralWings3DController automáticamente")
	assert_true(std_w3d.get_blade_count() == 12, "Las alas 3D estandarizadas deben inicializar 12 cuchillas")
	assert_true(absf(std_w3d.scale.x * std_rig.display_scale - 1.0) < 0.01, "Las alas 3D montadas deben compensar 1/display_scale exactamente")

	std_rig.apply_skin_preset(test_skin)
	assert_true(std_w3d.get_active_skin_id() == "emerald_test", "PlanarCombatRig.apply_skin_preset debe propagar la skin a las alas 3D")

	var cosmic_script: Script = load("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd") as Script
	if cosmic_script != null:
		var sample: Variant = cosmic_script.new()
		std_rig.apply_cosmic_lighting(sample, 0.0, null)

	std_rig.trigger_dash_burst(Vector2.RIGHT)
	var st_dash: Dictionary = std_w3d.get_blade_state(0)
	assert_true(float(st_dash["fire_flash"]) > 0.8, "trigger_dash_burst debe disparar pulso luminoso en las alas 3D")

	std_rig.queue_free()
	lab.queue_free()
	await get_tree().process_frame
	pass_suite("Valentina3DLab + Alas Astral Seraph 3D estandarizadas en PlanarCombatRig verificados")
