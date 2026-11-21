extends BaseTestSuite
## Suite de verificación para el laboratorio aislado de VFX de Propulsión (ValentinaVFXLab).
## Verifica:
## 1. Carga limpia de la escena y del recurso data-driven valentina_v2_propulsion_vfx.tres.
## 2. Cero copias en reposo (idle) y disparo por distancia en vuelo continuo (Nivel A).
## 3. Límite de densidad en Nivel A vs Nivel B (Ráfaga Sandevistan).
## 4. Curvas independientes (relleno decae más rápido que outline = calco de animación).
## 5. Limpieza y expiración total de copias tras lifetime.

const VFX_LAB_SCENE_PATH: String = "res://sandbox/pilot_rig_lab/vfx_lab/valentina_vfx_lab.tscn"
const BasePropCtrlScript = preload("res://sandbox/pilot_rig_lab/vfx_lab/valentina_base_propulsion_controller.gd")
const BasePropConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_base_propulsion_config.gd")


func _ready() -> void:
	timeout_seconds = 10.0
	super._ready()
	_run_tests()


func _run_tests() -> void:
	var packed: PackedScene = load(VFX_LAB_SCENE_PATH) as PackedScene
	assert_true(packed != null, "Debe cargar valentina_vfx_lab.tscn")

	var lab: Node2D = packed.instantiate() as Node2D
	assert_true(lab != null, "Debe instanciar ValentinaVFXLab")
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame

	var rig: PlanarCombatRig = lab.call("get_rig") as PlanarCombatRig
	var trail: SandevistanTrailController = lab.call("get_trail_controller") as SandevistanTrailController
	var cfg: PilotPropulsionVFXConfig = lab.call("get_vfx_config") as PilotPropulsionVFXConfig

	assert_true(rig != null, "ValentinaVFXLab debe instanciar PlanarCombatRig")
	assert_true(trail != null, "ValentinaVFXLab debe instanciar SandevistanTrailController")
	assert_true(cfg != null, "ValentinaVFXLab debe cargar PilotPropulsionVFXConfig (.tres)")

	# 1. Validar contrato de curvas ("calco de animación": relleno cae más rápido que outline en 50% vida)
	var fill_mid: float = cfg.sample_fill_alpha(0.55)
	var outline_mid: float = cfg.sample_outline_alpha(0.55)
	assert_true(
		outline_mid > fill_mid,
		"A 55%% de vida el outline (%.3f) debe mantenerse más opaco que el relleno (%.3f)" % [outline_mid, fill_mid]
	)

	# 2. Validar compensación de luminancia en tramo Amatista (0.72) vs arranque (0.05)
	assert_true(
		cfg.compute_emissive_boost(0.72) > cfg.compute_emissive_boost(0.05),
		"El tramo Amatista debe recibir mayor boost emisivo que el tramo inicial"
	)

	# Desactivar _process de la escena para probar el controlador de forma 100% determinista
	lab.set_process(false)
	trail.clear_all_ghosts()
	assert_true(trail.get_active_ghost_count() == 0, "Tras clear_all_ghosts debe haber 0 copias")

	# 3. Reposo (idle): 0 copias nuevas
	rig.position = Vector2.ZERO
	for _i: int in range(6):
		trail.step(0.05, rig, Vector2.ZERO, false)
	assert_true(trail.get_active_ghost_count() == 0, "En reposo no deben generarse copias")

	# 4. Vuelo continuo (Nivel A): disparo por distancia + techo base_max_ghosts
	var vel_base := Vector2(300.0, 0.0)
	for _i: int in range(25):
		rig.position += vel_base * 0.05
		trail.step(0.05, rig, vel_base, false)
	assert_true(trail.get_active_ghost_count() > 0, "En vuelo continuo deben generarse afterimages")
	assert_true(
		trail.get_active_ghost_count() <= cfg.base_max_ghosts,
		"En Nivel A no debe superar base_max_ghosts (%d), actual=%d" % [cfg.base_max_ghosts, trail.get_active_ghost_count()]
	)
	assert_true(
		trail.get_sequence_progress() <= cfg.base_sequence_cap + 0.01,
		"En Nivel A la secuencia debe respetar base_sequence_cap"
	)

	# 5. Ráfaga Sandevistan (Nivel B): supera el techo base y alcanza el tramo amatista (> 0.60)
	var vel_burst := Vector2(520.0, 120.0)
	trail.trigger_burst_impulse(rig)
	for _i: int in range(18):
		rig.position += vel_burst * 0.03
		trail.step(0.03, rig, vel_burst, true)
	assert_true(
		trail.get_active_ghost_count() <= cfg.burst_max_ghosts,
		"En Nivel B no debe superar burst_max_ghosts"
	)
	assert_true(
		trail.get_sequence_progress() > 0.60,
		"En ráfaga prolongada la secuencia debe alcanzar el tramo amatista (> 0.60)"
	)

	# 6. Expiración total tras detenerse y reinicio del pincel de color a Turquesa (0.0)
	for _i: int in range(30):
		trail.step(0.05, rig, Vector2.ZERO, false)
	assert_true(
		trail.get_active_ghost_count() == 0,
		"Todas las copias deben expirar y limpiarse tras detenerse"
	)
	assert_true(
		is_zero_approx(trail.get_color_cursor()),
		"Al detenerse en reposo el pincel de color debe reiniciar en Turquesa (0.0)"
	)

	# 7. Propulsión Base Zero-G (Alas Serafín Astral 8-dir + Ribbons + Polvo Estelar)
	var base_ctrl: BasePropCtrlScript = lab.call("get_base_propulsion_controller") as BasePropCtrlScript
	var base_cfg: BasePropConfigScript = lab.call("get_base_propulsion_config") as BasePropConfigScript
	assert_true(base_ctrl != null, "ValentinaVFXLab debe instanciar ValentinaBasePropulsionController")
	assert_true(base_cfg != null, "ValentinaVFXLab debe cargar PilotBasePropulsionConfig (.tres)")
	assert_true(base_ctrl.is_wings_mounted(), "Las alas deben montarse dentro de UnifiedCharacterGroup")
	assert_true(base_ctrl.has_external_glow_layers(), "Debe montar capas HDR de glow rojo fuera de UnifiedCharacterGroup")
	assert_true(
		base_ctrl.get_under_mount().z_index == 0 and base_ctrl.get_over_mount().z_index == 0,
		"Invariante CanvasGroup: WingsUnderMount y WingsOverMount deben mantener z_index == 0"
	)

	# Verificar enrutado de las 8 direcciones y orden Z (behind_body, over_back, split_profile)
	for dir_key: String in ["s", "se", "sw", "e", "w", "ne", "nw", "n"]:
		base_ctrl.force_view_direction(dir_key)
		assert_true(
			base_ctrl.get_current_view_dir() == dir_key,
			"Debe enrutar correctamente la vista de alas '%s'" % dir_key
		)
		var p_l: Node = base_ctrl.get_wing_l_pivot().get_parent()
		var p_r: Node = base_ctrl.get_wing_r_pivot().get_parent()
		if dir_key in ["n", "ne", "nw"]:
			assert_true(
				p_l == base_ctrl.get_over_mount() and p_r == base_ctrl.get_over_mount(),
				"En vista de espalda '%s' ambas alas deben estar bajo WingsOverMount (por encima del torso)" % dir_key
			)
		elif dir_key == "e":
			assert_true(
				p_l == base_ctrl.get_under_mount() and p_r == base_ctrl.get_over_mount(),
				"En perfil 'e' el ala trasera debe ir bajo WingsUnderMount y la cercana bajo WingsOverMount"
			)
		elif dir_key == "w":
			assert_true(
				p_r == base_ctrl.get_under_mount() and p_l == base_ctrl.get_over_mount(),
				"En perfil 'w' el ala trasera debe ir bajo WingsUnderMount y la cercana bajo WingsOverMount"
			)
		else:
			assert_true(
				p_l == base_ctrl.get_under_mount() and p_r == base_ctrl.get_under_mount(),
				"En vista frontal '%s' ambas alas deben ir bajo WingsUnderMount (detrás del torso)" % dir_key
			)
	assert_true(
		base_ctrl.get_active_blade_count() == 12,
		"En vista 'n' deben existir exactamente 12 cuchillas psíquicas independientes (6 por ala), actual=%d" % base_ctrl.get_active_blade_count()
	)

	# Verificar transición Idle -> Vuelo + Empuje Newtoniano asimétrico (derecha -> ala izq. desliza más lejos)
	base_ctrl.clear_trails()
	for _i: int in range(14):
		base_ctrl.step(0.05, rig, Vector2.ZERO, false)
	var open_idle: float = base_ctrl.get_open_factor()
	var glow_idle: float = base_ctrl.get_glow_intensity_left()
	assert_true(open_idle < 0.15, "En reposo las alas deben permanecer plegadas (open=%.2f)" % open_idle)
	assert_true(base_ctrl.get_active_ribbon_point_count() == 0, "En reposo no debe haber cintas rojas activas")

	for _i: int in range(16):
		rig.position += Vector2(300.0, 0.0) * 0.05
		base_ctrl.step(0.05, rig, Vector2(300.0, 0.0), false)
	var open_flight: float = base_ctrl.get_open_factor()
	assert_true(open_flight > 0.70, "En vuelo las alas deben desplegarse (open=%.2f)" % open_flight)
	assert_true(
		base_ctrl.get_effort_left() > base_ctrl.get_effort_right() + 0.15,
		"Empuje Newtoniano (+X): ala izquierda (%.2f) debe empujar más que la derecha (%.2f)" % [base_ctrl.get_effort_left(), base_ctrl.get_effort_right()]
	)
	assert_true(
		base_ctrl.get_wing_l_pivot().position.x < -75.0,
		"En empuje (+X) el ala izquierda debe deslizarse linealmente hacia afuera (pos.x=%.1f)" % base_ctrl.get_wing_l_pivot().position.x
	)
	assert_true(
		base_ctrl.get_glow_intensity_left() > base_ctrl.get_glow_intensity_right() and base_ctrl.get_glow_intensity_left() > glow_idle,
		"El glow rojo HDR en empuje (+X) debe ser mayor en el ala izquierda (%.2f) que en la derecha (%.2f) y en reposo (%.2f)" % [base_ctrl.get_glow_intensity_left(), base_ctrl.get_glow_intensity_right(), glow_idle]
	)
	assert_true(base_ctrl.get_active_ribbon_point_count() >= 12, "En vuelo deben generarse cintas rojas desde todas las puntas")
	assert_true(base_ctrl.get_active_stardust_count() > 0, "En vuelo debe generarse Polvo Estelar")

	for _i: int in range(18):
		rig.position += Vector2(-300.0, 0.0) * 0.05
		base_ctrl.step(0.05, rig, Vector2(-300.0, 0.0), false)
	assert_true(
		base_ctrl.get_effort_right() > base_ctrl.get_effort_left() + 0.15,
		"Empuje Newtoniano (-X): ala derecha (%.2f) debe empujar más que la izquierda (%.2f)" % [base_ctrl.get_effort_right(), base_ctrl.get_effort_left()]
	)

	# Verificar frenado brusco en vista "n": cero superposición + apertura lineal (s0 sin rotación vertical)
	rig.set_locomotion_state(Vector2.UP, 0.0, Vector2.UP, true)
	for _i: int in range(8):
		rig.position += Vector2(300.0, 0.0) * 0.05
		base_ctrl.step(0.05, rig, Vector2(300.0, 0.0), false)
	for _i: int in range(6):
		base_ctrl.step(0.05, rig, Vector2.ZERO, false)
	var wing_l: Node2D = base_ctrl.get_wing_l_pivot()
	var wing_r: Node2D = base_ctrl.get_wing_r_pivot()
	assert_true(base_ctrl.get_current_view_dir() == "n", "El controlador debe detectar vista 'n' al orientar el rig hacia arriba")
	assert_true(
		wing_l.position.x < -30.0 and wing_r.position.x > 30.0,
		"Al frenar en vista 'n' ambas alas deben permanecer separadas lateralmente (L=%.1f, R=%.1f)" % [wing_l.position.x, wing_r.position.x]
	)
	assert_true(
		absf(wing_l.rotation_degrees) < 1.0 and absf(wing_r.rotation_degrees) < 1.0 and absf(base_ctrl.get_top_blade_rotation_deg(false)) < 1.0,
		"Apertura lineal pura: pivotes (L=%.2f°, R=%.2f°) y pluma superior s0 (%.2f°) no deben rotar hacia vertical" % [wing_l.rotation_degrees, wing_r.rotation_degrees, base_ctrl.get_top_blade_rotation_deg(false)]
	)

	base_ctrl.clear_trails()
	assert_true(base_ctrl.get_active_ribbon_point_count() == 0 and base_ctrl.get_active_stardust_count() == 0, "clear_trails debe limpiar cintas rojas y polvo estelar")

	# 7B. Puente 2.5D Squash-X en giro (se -> e): el ala derecha cruza +X -> -X comprimiendo scale.x
	base_ctrl.force_view_direction("se")
	rig.set_locomotion_state(Vector2.RIGHT, 1.0, Vector2.RIGHT, true)
	base_ctrl.step(0.025, rig, Vector2(280.0, 0.0), false)
	assert_true(base_ctrl.is_turn_bridge_active(), "Al cambiar de 'se' a 'e' debe activarse el puente 2.5D Squash-X")
	assert_true(
		base_ctrl.get_turn_scale_x_right() < 0.85,
		"En PRE_CUT (se -> e) el ala derecha debe comprimir scale.x al cruzar de lado (actual=%.2f)" % base_ctrl.get_turn_scale_x_right()
	)
	base_ctrl.step(0.025, rig, Vector2(280.0, 0.0), false)
	assert_true(base_ctrl.get_current_view_dir() == "e", "Justo al completar PRE_CUT (0.05s) debe conmutar a vista 'e'")
	assert_true(
		base_ctrl.get_wing_r_pivot().position.x < -30.0,
		"En el corte (se -> e) el ala derecha debe hacer snap instantáneo hacia la espalda sin cruzar sobre el cuerpo (pos.x=%.1f)" % base_ctrl.get_wing_r_pivot().position.x
	)
	assert_true(
		base_ctrl.get_active_warp_arc_count() > 0 and base_ctrl.get_active_warp_ghost_count() == 2,
		"En el snap (se -> e) deben generarse los speed-arcs y 2 afterimages ultrabreves (arcs=%d, ghosts=%d)" % [base_ctrl.get_active_warp_arc_count(), base_ctrl.get_active_warp_ghost_count()]
	)
	for _i: int in range(9):
		base_ctrl.step(0.025, rig, Vector2(280.0, 0.0), false)
	assert_true(base_ctrl.get_current_view_dir() == "e", "Tras completar el puente 2.5D la vista activa debe ser 'e'")
	assert_true(not base_ctrl.is_turn_bridge_active(), "Tras 0.25s el puente 2.5D debe volver a IDLE")
	assert_true(
		base_ctrl.get_active_warp_arc_count() == 0 and base_ctrl.get_active_warp_ghost_count() == 0,
		"Los speed-arcs y afterimages de giro deben expirar limpiamente tras su vida útil"
	)
	assert_true(
		is_equal_approx(base_ctrl.get_turn_scale_x_right(), 1.0),
		"Al finalizar POST_CUT scale.x debe estabilizarse exactamente en 1.0"
	)

	# 8. Estandarización Multi-Piloto en PlanarCombatRig (enable_base_propulsion_wings = true vía PilotRigProfile)
	var std_rig: PlanarCombatRig = (load("res://sandbox/pilot_rig_lab/proto/planar_combat_rig.gd") as Script).new() as PlanarCombatRig
	var std_profile: PilotRigProfile = load("res://sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_profile.tres") as PilotRigProfile
	assert_true(std_profile != null and std_profile.base_propulsion_config != null, "valentina_v2_profile.tres debe enlazar base_propulsion_config")
	std_rig.pilot_profile = std_profile
	std_rig.enable_base_propulsion_wings = true
	add_child(std_rig)
	await get_tree().process_frame
	var std_wings: BasePropCtrlScript = std_rig.get_base_propulsion_controller()
	assert_true(std_wings != null and std_wings.is_wings_mounted(), "PlanarCombatRig con enable_base_propulsion_wings debe montar alas automáticamente desde el perfil")
	assert_true(std_wings.get_active_blade_count() == 12, "El rig estandarizado debe inicializar 12 cuchillas psíquicas")
	if not std_profile.skins.is_empty():
		std_rig.apply_skin_preset(std_profile.skins[mini(1, std_profile.skins.size() - 1)])
		assert_true(std_wings.is_wings_mounted(), "apply_skin_preset debe mantener y sincronizar limpiamente las alas estandarizadas")
	std_rig.queue_free()

	# 9. Paridad Z-Order (piernas/cabeza) y Alas sincronizadas dentro de afterimages Sandevistan
	trail.clear_all_ghosts()
	rig.set_locomotion_state(Vector2.DOWN, 0.85, Vector2.DOWN, true)
	rig._process(0.02)
	base_ctrl.force_view_direction("s")
	base_ctrl.step(0.02, rig, Vector2(0.0, 260.0), true)
	trail.trigger_burst_impulse(rig)

	var ghosts_s: Array = trail.get("_ghosts") as Array
	assert_true(not ghosts_s.is_empty(), "Debe generar snapshot Sandevistan en vista 's'")
	var ghost_s: CanvasGroup = (ghosts_s.back() as Dictionary)["node"] as CanvasGroup
	var ghost_body_s: Node2D = ghost_s.get_node_or_null("GhostBodyPivot") as Node2D
	assert_true(ghost_body_s != null, "Snapshot 's' debe contener GhostBodyPivot")
	var st_r: Polygon2D = ghost_body_s.get_node_or_null("BodyView_S/Meshes/Part_leg_r_stocking") as Polygon2D
	var st_l: Polygon2D = ghost_body_s.get_node_or_null("BodyView_S/Meshes/Part_leg_l_stocking") as Polygon2D
	assert_true(st_r != null and st_l != null, "Snapshot 's' debe conservar Part_leg_r_stocking y Part_leg_l_stocking")
	var st_r_mat: ShaderMaterial = st_r.material as ShaderMaterial
	var st_l_mat: ShaderMaterial = st_l.material as ShaderMaterial
	assert_true(
		st_r_mat != null and int(st_r_mat.get_shader_parameter("leg_layer_pass")) == 2 and bool(st_r_mat.get_shader_parameter("has_id_mask")) == true,
		"Afterimage Part_leg_r_stocking debe propagar leg_layer_pass == 2 y has_id_mask == true"
	)
	assert_true(
		st_l_mat != null and int(st_l_mat.get_shader_parameter("leg_layer_pass")) == 2 and bool(st_l_mat.get_shader_parameter("has_id_mask")) == true,
		"Afterimage Part_leg_l_stocking debe propagar leg_layer_pass == 2 y has_id_mask == true"
	)
	var ghost_head_s: Node2D = ghost_s.get_node_or_null("Ghost_DecoupledHeadMount") as Node2D
	assert_true(ghost_head_s != null and ghost_head_s.get_child_count() > 0, "Snapshot 's' debe clonar Ghost_DecoupledHeadMount")
	var head_spr_s: Sprite2D = ghost_head_s.get_child(0) as Sprite2D
	var head_mat_s: ShaderMaterial = head_spr_s.material as ShaderMaterial if head_spr_s != null else null
	assert_true(
		head_mat_s != null and int(head_mat_s.get_shader_parameter("head_layer_pass")) == 2 and bool(head_mat_s.get_shader_parameter("has_id_mask")) == true,
		"Afterimage DecoupledHeadMount debe propagar head_layer_pass == 2 y has_id_mask == true"
	)

	# 9B. Alas sincronizadas en perfil 'e' (split_profile: WingsUnder -> Body -> WingsOver -> HeadOver)
	trail.clear_all_ghosts()
	rig.set_locomotion_state(Vector2.RIGHT, 1.0, Vector2.RIGHT, true)
	rig._process(0.02)
	base_ctrl.force_view_direction("e")
	base_ctrl.step(0.02, rig, Vector2(300.0, 0.0), true)
	trail.trigger_burst_impulse(rig)

	var ghosts_e: Array = trail.get("_ghosts") as Array
	assert_true(not ghosts_e.is_empty(), "Debe generar snapshot Sandevistan en vista 'e'")
	var ghost_e: CanvasGroup = (ghosts_e.back() as Dictionary)["node"] as CanvasGroup
	var w_under_e: Node2D = ghost_e.get_node_or_null("Ghost_WingsUnderMount") as Node2D
	var body_e: Node2D = ghost_e.get_node_or_null("GhostBodyPivot") as Node2D
	var w_over_e: Node2D = ghost_e.get_node_or_null("Ghost_WingsOverMount") as Node2D
	var head_e: Node2D = ghost_e.get_node_or_null("Ghost_DecoupledHeadMount") as Node2D
	assert_true(w_under_e != null and body_e != null and w_over_e != null and head_e != null, "Snapshot 'e' debe clonar Ghost_WingsUnderMount, GhostBodyPivot, Ghost_WingsOverMount y Ghost_DecoupledHeadMount")
	assert_true(
		w_under_e.get_index() < body_e.get_index() and body_e.get_index() < w_over_e.get_index() and w_over_e.get_index() < head_e.get_index(),
		"Orden Z en snapshot 'e' debe ser WingsUnder < Body < WingsOver < HeadOver"
	)
	var wing_sprites_e: Array[Sprite2D] = []
	_collect_sprites_recursive(w_under_e, wing_sprites_e)
	_collect_sprites_recursive(w_over_e, wing_sprites_e)
	assert_true(wing_sprites_e.size() == 12, "Snapshot 'e' debe clonar exactamente 12 cuchillas de alas (actual=%d)" % wing_sprites_e.size())
	for wspr: Sprite2D in wing_sprites_e:
		var wmat: ShaderMaterial = wspr.material as ShaderMaterial
		assert_true(
			wspr.z_index == 0 and wmat != null and bool(wmat.get_shader_parameter("has_ink_sdf")) == true,
			"Cada cuchilla de ala clonada debe mantener z_index == 0 y has_ink_sdf == true"
		)

	# 9C. Alas sincronizadas en espalda 'n' (over_back: todas las 12 cuchillas en WingsOverMount sobre Body)
	trail.clear_all_ghosts()
	rig.set_locomotion_state(Vector2.UP, 1.0, Vector2.UP, true)
	rig._process(0.02)
	base_ctrl.force_view_direction("n")
	base_ctrl.step(0.02, rig, Vector2(0.0, -300.0), true)
	trail.trigger_burst_impulse(rig)

	var ghosts_n: Array = trail.get("_ghosts") as Array
	assert_true(not ghosts_n.is_empty(), "Debe generar snapshot Sandevistan en vista 'n'")
	var ghost_n: CanvasGroup = (ghosts_n.back() as Dictionary)["node"] as CanvasGroup
	var body_n: Node2D = ghost_n.get_node_or_null("GhostBodyPivot") as Node2D
	var w_over_n: Node2D = ghost_n.get_node_or_null("Ghost_WingsOverMount") as Node2D
	assert_true(body_n != null and w_over_n != null and body_n.get_index() < w_over_n.get_index(), "En vista 'n' Ghost_WingsOverMount debe dibujarse sobre GhostBodyPivot")
	var wing_sprites_n: Array[Sprite2D] = []
	_collect_sprites_recursive(w_over_n, wing_sprites_n)
	assert_true(wing_sprites_n.size() == 12, "Snapshot 'n' debe ubicar las 12 cuchillas bajo Ghost_WingsOverMount (actual=%d)" % wing_sprites_n.size())

	lab.queue_free()
	await get_tree().process_frame
	pass_suite("ValentinaVFXLab + Sandevistan + Propulsión Base Multi-Piloto verificados")


func _collect_sprites_recursive(root: Node, out: Array[Sprite2D]) -> void:
	if root == null:
		return
	if root is Sprite2D:
		out.append(root as Sprite2D)
	for child: Node in root.get_children():
		_collect_sprites_recursive(child, out)
