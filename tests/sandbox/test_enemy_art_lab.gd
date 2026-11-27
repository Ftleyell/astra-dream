extends BaseTestSuite

## Headless verification for AAA 2.5D Enemy Workbench (7 articulated parts including
## scissor mandibles, 7 extrusion thickness shells, internal reactor point light,
## inter-layer cast shadows, bite crunch VFX, and zero Valentina).

const LAB_SCENE_PATH: String = "res://sandbox/enemy_art_lab/enemy_art_lab.tscn"
const VoidScarabRigScript = preload("res://scenes/combat/enemies/rig/void_scarab_rig_25d.gd")
const SequenceDirectorScript = preload("res://sandbox/enemy_art_lab/enemy_sequence_director.gd")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")

var _lab: Node2D = null


func _ready() -> void:
	timeout_seconds = 20.0
	super._ready()
	_run_tests()


func _run_tests() -> void:
	# 0. Verify shader brace balance before scene instantiation (guards against GPU silent fallback)
	var sh_src: String = FileAccess.get_file_as_string("res://scenes/combat/enemies/shaders/enemy_stylized_25d.gdshader")
	assert_true(not sh_src.is_empty(), "No se pudo leer enemy_stylized_25d.gdshader en producción")
	var sh_depth: int = 0
	var frag_entry_depth: int = -1
	for sh_line: String in sh_src.split("\n"):
		if sh_line.contains("void fragment()"):
			frag_entry_depth = sh_depth
		for ch_idx: int in range(sh_line.length()):
			var ch: String = sh_line[ch_idx]
			if ch == "{":
				sh_depth += 1
			elif ch == "}":
				sh_depth -= 1
	assert_true(frag_entry_depth == 0 and sh_depth == 0, "Shader tiene llaves desbalanceadas (frag_entry=%d, eof=%d)" % [frag_entry_depth, sh_depth])
	assert_true(not sh_src.contains("smoothstep(0.055, 0.165, orig_luma)"), "Shader no debe usar corte luma 0.165 que ennegrece quitina oscura")
	assert_true(sh_src.contains("orig_val") and sh_src.contains("sdf_ink_line"), "Shader debe proteger croma por HSV value (orig_val) y usar sdf_ink_line")
	assert_true(sh_src.contains("varying vec4 v_modulate;") and not sh_src.contains("* COLOR;"), "fragment() no debe multiplicar salida por COLOR (causa cuadrático oscuro), debe usar v_modulate")

	var packed: PackedScene = ResourceLoader.load(LAB_SCENE_PATH) as PackedScene
	assert_true(packed != null, "No se pudo cargar enemy_art_lab.tscn")
	_lab = packed.instantiate() as Node2D
	assert_true(_lab != null, "No se pudo instanciar enemy_art_lab.tscn")
	add_child(_lab)

	await _wait_frames(3)

	# 1. Dedicated Enemy Workbench in Native Cosmic Engine + Real Sequence Director (NO Valentina, NO floor shadow)
	assert_true(_lab.get_node_or_null("ValentinaReferenceRig") == null, "Workbench no debe instanciar a Valentina")
	assert_true(int(_lab.call("get_backdrop_mode")) == 2, "Lab debe iniciar directamente en Cosmos Live (BackdropMode=2)")
	assert_true(int(_lab.call("get_control_mode")) == 0, "Lab debe iniciar reproduciendo Secuencias Cosmos (ControlMode=0)")
	var cosmos_env: CosmosCombatEnvironment = _lab.call("get_cosmos_environment") as CosmosCombatEnvironment
	assert_true(cosmos_env != null and cosmos_env.cosmos_root != null and cosmos_env.get_host_controller() != null, "CosmosCombatEnvironment y host_controller deben estar activos al iniciar")
	var seq_dir: Node2D = _lab.call("get_sequence_director") as Node2D
	assert_true(seq_dir != null, "EnemySequenceDirector debe existir en EnemyArtLab")

	var scarab: VoidScarabRigScript = _lab.call("get_primary_scarab") as VoidScarabRigScript
	assert_true(scarab != null, "VoidScarabPrimary debe existir en EnemyArtLab")
	assert_true(not scarab.is_floor_shadow_enabled(), "Sombra de suelo debe estar desactivada por defecto en Cosmic Engine")
	var under_sh_init: MeshInstance2D = scarab.get_under_shadow_mesh()
	assert_true(under_sh_init != null and not under_sh_init.visible, "UnderFloorShadow no debe ser visible en el espacio")

	# Verify real sequences execute cleanly in Cosmic Engine
	var p_start: Vector2 = scarab.position
	_lab.call("select_sequence", 0, false) # PATROL_CRUISE
	await _wait_frames(8)
	assert_true(p_start.distance_to(scarab.position) > 8.0, "Secuencia Patrulla debe desplazar realmente al escarabajo por Cosmos")
	assert_true(not under_sh_init.visible, "UnderFloorShadow debe seguir oculto durante vuelo espacial")

	_lab.call("select_sequence", 2, false) # SWARM_INTERCEPT
	await _wait_frames(3)
	assert_true(bool(_lab.get("_swarm_enabled")), "Secuencia Enjambre 6x debe activar los 6 drones")

	_lab.call("select_sequence", 4, false) # HIT_SHATTER
	var typed_dir: SequenceDirectorScript = seq_dir as SequenceDirectorScript
	var empty_swarm: Array[VoidScarabRigScript] = []
	for _s: int in range(30):
		typed_dir.step_sequence(0.14, scarab, empty_swarm, null)
	assert_true(scarab.get_anim_state() == VoidScarabRigScript.AnimState.DEATH_SHATTER, "Secuencia Daño/Muerte debe alcanzar DEATH_SHATTER")
	scarab.respawn()
	assert_true(not under_sh_init.visible, "respawn() no debe reactivar UnderFloorShadow en Cosmic Engine")

	_lab.call("select_sequence", 1, false) # PREDATOR_STRIKE
	await _wait_frames(3)
	_lab.call("select_sequence", 3, false) # SOLAR_ECLIPSE
	await _wait_frames(3)

	# Switch to deterministic INSPECT_25D mode for pose/shader/alignment unit assertions
	_lab.call("set_control_mode", 1)
	scarab.respawn()
	scarab.position = Vector2.ZERO
	scarab.rotation = -PI * 0.5
	await _wait_frames(2)

	# 2. Verify all 7 articulated subdivided MeshInstance2D nodes & 3+1 maps + intact mandible art
	var meshes: Array[MeshInstance2D] = scarab.get_part_meshes()
	assert_true(meshes.size() == 7, "VoidScarab debe tener 7 piezas MeshInstance2D, tiene %d" % meshes.size())
	var mand_r_img: Image = (meshes[2].texture as ImageTexture).get_image()
	var green_edge_count: int = 0
	for py: int in range(20, 140):
		for px: int in range(60, 190):
			var c: Color = mand_r_img.get_pixel(px, py)
			if c.a > 0.5 and c.g > c.r + 0.15 and c.g > 0.45:
				green_edge_count += 1
	assert_true(green_edge_count > 40, "mandible_r_albedo debe conservar el filo verde brillante intacto (px=%d)" % green_edge_count)

	for mi: MeshInstance2D in meshes:
		assert_true(mi != null and mi.mesh != null and mi.texture != null, "Mesh %s incompleto" % [mi.name if mi else "null"])
		var arrays: Array = mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		assert_true(verts.size() >= 100, "%s debe tener malla subdividida (>=100 verts, tiene %d)" % [mi.name, verts.size()])

		var mat: ShaderMaterial = mi.material as ShaderMaterial
		assert_true(mat != null, "%s sin ShaderMaterial" % mi.name)
		var nh_tex: Texture2D = mat.get_shader_parameter("normal_height_tex") as Texture2D
		var ilm_tex: Texture2D = mat.get_shader_parameter("ilm_sdf_tex") as Texture2D
		var fx_tex: Texture2D = mat.get_shader_parameter("fx_motion_tex") as Texture2D
		assert_true(nh_tex != null and ilm_tex != null and fx_tex != null, "%s faltan mapas 3+1" % mi.name)
		assert_true(ilm_tex.get_width() == mi.texture.get_width() * 2, "%s ilm_sdf debe ser 2x albedo" % mi.name)
		if ilm_tex is ImageTexture:
			var img: Image = (ilm_tex as ImageTexture).get_image()
			assert_true(img != null and not img.has_mipmaps(), "%s ilm_sdf no debe tener mipmaps" % mi.name)

	var mat_wing_l: ShaderMaterial = meshes[3].material as ShaderMaterial
	var mat_wing_r: ShaderMaterial = meshes[4].material as ShaderMaterial
	var uv_l: Vector2 = mat_wing_l.get_shader_parameter("wing_hinge_uv") as Vector2
	var uv_r: Vector2 = mat_wing_r.get_shader_parameter("wing_hinge_uv") as Vector2
	assert_true(absf(uv_l.x + uv_r.x - 1.0) < 0.002 and absf(uv_l.y - uv_r.y) < 0.002, "wing_hinge_uv izquierdo y derecho deben ser espejo exacto")

	# 3. Verify 7 thin 2.5D/3D extrusion thickness shells (3 body + 2x2 elytra rims) + outer/inner face modes
	var shells: Array[MeshInstance2D] = scarab.get_shell_meshes()
	assert_true(shells.size() == 7, "Deben existir 7 shells finos de extrusión 2.5D/3D (tiene %d)" % shells.size())
	for sm: MeshInstance2D in shells:
		var smat: ShaderMaterial = sm.material as ShaderMaterial
		assert_true(smat != null and bool(smat.get_shader_parameter("extrusion_shell_mode")) == true, "Shell %s debe tener extrusion_shell_mode=true" % sm.name)

	var mat_ely_l: ShaderMaterial = meshes[5].material as ShaderMaterial
	var mat_ely_r_chk: ShaderMaterial = meshes[6].material as ShaderMaterial
	var hl: Vector2 = mat_ely_l.get_shader_parameter("ely_hinge_local_px") as Vector2
	var hr: Vector2 = mat_ely_r_chk.get_shader_parameter("ely_hinge_local_px") as Vector2
	assert_true(absf(hl.x + hr.x) < 0.5 and absf(hl.y - hr.y) < 0.5, "ely_hinge_local_px debe estar espejado entre élitro izq y der")
	assert_true(int(mat_ely_l.get_shader_parameter("ely_face_mode")) == 1 and int(mat_ely_r_chk.get_shader_parameter("ely_face_mode")) == 1, "Outer elytra deben tener ely_face_mode=1")

	# 4. Verify cast shadows react to light direction
	assert_true(scarab.get_under_shadow_mesh() != null, "UnderFloorShadow debe existir")
	var sh_pivots: Array[Node2D] = scarab.get_elytron_shadow_pivots()
	assert_true(sh_pivots.size() == 2 and sh_pivots[0] != null and sh_pivots[1] != null, "Elytron shadows deben existir")

	scarab.set_light_override(Vector2(1.0, 0.0), 0.5, 0.0)
	scarab.step(0.016, 0.0, 0.0, 0.0)
	var sh_pos_a: Vector2 = sh_pivots[1].position
	scarab.set_light_override(Vector2(-1.0, 0.0), 0.5, 0.0)
	scarab.step(0.016, 0.0, 0.0, 0.0)
	var sh_pos_b: Vector2 = sh_pivots[1].position
	assert_true(sh_pos_a.distance_to(sh_pos_b) > 2.0, "Sombra del élitro debe desplazarse según luz")

	# 5. Verify internal reactor point light intensifies when elytra open in Telegraph
	var mat_body: ShaderMaterial = meshes[0].material as ShaderMaterial
	var mat_ely_r: ShaderMaterial = meshes[6].material as ShaderMaterial
	var prev_blur_deg: float = scarab.rig_config.wing_blur_max_deg
	var prev_wind_str: float = scarab.rig_config.wing_wind_arcs_strength
	scarab.rig_config.wing_blur_max_deg = 20.0
	scarab.rig_config.wing_wind_arcs_strength = 0.78

	scarab.set_anim_state(VoidScarabRigScript.AnimState.IDLE_HOVER)
	for _i: int in range(6):
		scarab.step(0.02, 0.0, 0.0, 0.0)
	var core_idle: float = float(mat_body.get_shader_parameter("core_light_intensity"))
	var shutter_idle: Dictionary = scarab.get_wing_shutter_state()
	var carapace_idle: Dictionary = scarab.get_carapace_3d_state()
	assert_true(float(shutter_idle["speed_ramp"]) < 0.05 and float(shutter_idle["blur_arc_rad"]) < 0.02, "Alas plegadas en Idle no deben tener shutter blur")
	assert_true(not bool(shutter_idle["wind_arcs_visible"]), "WingBuzzArcsVFX debe estar oculto en Idle")
	assert_true(scarab.find_child("DorsalCrystal3D", true, false) == null, "No debe existir gema 3D procedural DorsalCrystal3D")
	assert_true(float(carapace_idle["ely_pitch_rad"]) < 0.15, "Caparazón 3D debe reposar bajo en Idle")

	scarab.set_anim_state(VoidScarabRigScript.AnimState.CHARGE_TELEGRAPH)
	for _i: int in range(18):
		scarab.step(0.025, 0.0, 0.0, 0.0)
	var core_tele: float = float(mat_body.get_shader_parameter("core_light_intensity"))
	var core_ely: float = float(mat_ely_r.get_shader_parameter("core_light_intensity"))
	assert_true(scarab.get_elytron_open_rad() > 0.40, "Élitros deben abrirse en Telegraph (> 0.40 rad)")
	assert_true(core_tele > core_idle + 0.5 and core_ely > 0.8, "Reactor point light debe intensificarse al abrir élitros")
	assert_true(scarab.get_mandible_bite_rad() < -0.25, "Pinzas deben abrirse amplio en Telegraph (< -0.25 rad)")

	var carapace_tele: Dictionary = scarab.get_carapace_3d_state()
	assert_true(int(carapace_tele["inner_bowl_count"]) == 2, "Deben existir 2 inner bowls cóncavos en los élitros")
	assert_true(float(carapace_tele["ely_pitch_rad"]) > 0.35 and float(carapace_tele["ely_roll_rad"]) > 0.50, "Caparazón cóncavo debe abrirse en Pitch + Roll para mostrar interior en Telegraph")
	var e3_l: Vector3 = mat_ely_l.get_shader_parameter("ely_open_3d") as Vector3
	var e3_r: Vector3 = mat_ely_r.get_shader_parameter("ely_open_3d") as Vector3
	assert_true(e3_l.x < -0.50 and e3_r.x > 0.50 and e3_r.y > 0.35 and e3_r.z > 12.0, "ely_open_3d cóncavo simétrico debe aplicarse en Pitch+Roll+LiftZ")

	var shutter_tele: Dictionary = scarab.get_wing_shutter_state()
	assert_true(float(shutter_tele["speed_ramp"]) > 0.70, "Wing speed_ramp debe acelerar > 0.70 en Telegraph (actual %.2f)" % float(shutter_tele["speed_ramp"]))
	assert_true(float(shutter_tele["blur_arc_rad"]) > 0.22, "wing_blur_arc_rad debe activarse > 0.22 rad (actual %.3f)" % float(shutter_tele["blur_arc_rad"]))
	assert_true(bool(shutter_tele["strobe_upper_visible"]) and bool(shutter_tele["strobe_lower_visible"]), "Ambos afterimages estroboscópicos deben estar visibles en Telegraph")
	assert_true(float(shutter_tele["strobe_upper_alpha"]) < 0.55 and float(shutter_tele["strobe_lower_alpha"]) < 0.55, "Opacidad de afterimages estroboscópicos debe ser baja (< 0.55)")
	assert_true(bool(shutter_tele["wind_arcs_visible"]), "WingBuzzArcsVFX debe estar visible en Telegraph")

	scarab.rig_config.wing_blur_max_deg = prev_blur_deg
	scarab.rig_config.wing_wind_arcs_strength = prev_wind_str

	# 6. Verify scissor-cross bite snap + HDR crunch VFX
	scarab.set_anim_state(VoidScarabRigScript.AnimState.IDLE_HOVER)
	scarab.trigger_bite_snap()
	for _i: int in range(7):
		scarab.step(0.025, 0.0, 0.0, 0.0)
	var jaw_open: float = scarab.get_mandible_bite_rad()
	assert_true(jaw_open < -0.20, "Fase 1 de mordida debe abrir pinzas (< -0.20 rad, actual %.3f)" % jaw_open)

	for _i: int in range(8):
		scarab.step(0.025, 0.0, 0.0, 0.0)
	assert_true(scarab.get_mandible_bite_rad() > 0.35, "Fase 2 de mordida debe cruzar pinzas (> 0.35 rad)")
	assert_true(scarab.is_bite_vfx_active(), "BiteCrunchVFX debe activarse al chocar las pinzas")

	# 7. Verify 2.5D tilt, A/B flat baseline, Hit Flash, X-Ray 0..7, Variants, Backdrop & Shatter/Respawn
	scarab.set_tilt_25d(0.75, -0.45)
	for _i: int in range(10):
		scarab.step(0.02, 0.0, 0.0, 0.0)
	assert_true(scarab.get_tilt_25d().length() > 0.3, "set_tilt_25d debe actualizar inclinación 2.5D")

	scarab.set_flat_baseline_mode(true)
	scarab.step(0.016, 0.0, 0.0, 0.0)
	assert_true(bool(mat_body.get_shader_parameter("flat_baseline_mode")) == true, "flat_baseline_mode ON")
	scarab.set_flat_baseline_mode(false)

	# Verify fine alignment calibration updates hinge & offsets immediately
	var prev_e_off: Vector2 = scarab.rig_config.elytron_offset
	var prev_e_uv: Vector2 = scarab.rig_config.elytron_hinge_uv
	var prev_w_off: Vector2 = scarab.rig_config.wing_offset
	var h_before: Vector2 = mat_ely_r.get_shader_parameter("ely_hinge_local_px") as Vector2
	scarab.rig_config.elytron_offset = prev_e_off + Vector2(2.5, -1.5)
	scarab.rig_config.elytron_hinge_uv = prev_e_uv + Vector2(0.01, -0.01)
	scarab.rig_config.wing_offset = prev_w_off + Vector2(3.0, 2.0)
	scarab.apply_rig_calibration()
	var h_after: Vector2 = mat_ely_r.get_shader_parameter("ely_hinge_local_px") as Vector2
	assert_true(h_before.distance_to(h_after) > 3.0, "apply_rig_calibration debe actualizar ely_hinge_local_px al ajustar bisagra UV")
	scarab.rig_config.elytron_offset = prev_e_off
	scarab.rig_config.elytron_hinge_uv = prev_e_uv
	scarab.rig_config.wing_offset = prev_w_off
	scarab.apply_rig_calibration()

	scarab.trigger_hit_flash()
	scarab.step(0.016, 0.0, 0.0, 0.0)
	assert_true(float(mat_body.get_shader_parameter("hit_flash")) > 0.5, "hit_flash debe activarse")

	for m: int in range(8):
		scarab.set_debug_view_mode(m)
	scarab.set_debug_view_mode(0)

	for v: int in range(4):
		scarab.set_variant_index(v)
	scarab.set_variant_index(1) # Crimson
	assert_true(bool(mat_body.get_shader_parameter("enable_variant_recolor")) == true, "Variant 1 debe activar enable_variant_recolor")
	var v_arm: Color = mat_body.get_shader_parameter("variant_armor_tint") as Color
	var v_eng: Color = mat_body.get_shader_parameter("variant_energy_tint") as Color
	var v_pri: Color = mat_body.get_shader_parameter("primary_emissive_tint") as Color
	assert_true(v_arm.r > v_arm.b and v_eng.r > v_eng.g and v_pri.r > v_pri.g, "Variante Crimson debe actualizar armadura, energía y emisivo primario")
	scarab.set_variant_index(-1)
	var base_pri: Color = mat_body.get_shader_parameter("primary_emissive_tint") as Color
	assert_true(base_pri.g > base_pri.r, "Volver a variante Base (-1) debe restaurar tinte emisivo esmeralda")

	# Verify full 3-way Backdrop cycling (Cosmos Live -> Studio Grid -> Deep Void -> Cosmos Live) and CanvasLayer visibility
	assert_true(int(_lab.call("get_backdrop_mode")) == 2, "Debe estar en Cosmos Live antes del ciclo")
	_lab.call("_on_backdrop_cycled") # -> 0 STUDIO_GRID
	await _wait_frames(2)
	assert_true(int(_lab.call("get_backdrop_mode")) == 0, "Backdrop debe cambiar a Studio Grid (0)")
	var neb_cl: CanvasLayer = cosmos_env.cosmos_root.get_node_or_null("ParallaxNebulaDeep") as CanvasLayer
	assert_true(neb_cl != null and not neb_cl.visible, "CanvasLayers de Cosmos deben ocultarse al pasar a Studio Grid")
	_lab.call("_on_backdrop_cycled") # -> 1 DEEP_VOID
	_lab.call("_on_backdrop_cycled") # -> 2 COSMOS_LIVE
	await _wait_frames(2)
	assert_true(int(_lab.call("get_backdrop_mode")) == 2 and neb_cl.visible, "Backdrop debe volver a Cosmos Live (2) restaurando CanvasLayers")

	# Verify apply_cosmic_lighting blends biome shadow gently without overwriting red/violet base shadow tint
	var teal_sample := CosmicLightingSampleScript.new()
	teal_sample.shadow_tint = Color(0.07, 0.34, 0.30, 1.0)
	teal_sample.ao_tint = Color(0.036, 0.17, 0.16, 1.0)
	teal_sample.biome_shadow_weight = 0.35
	scarab.apply_cosmic_lighting(teal_sample)
	var sh_blended: Color = mat_body.get_shader_parameter("shadow_tint") as Color
	assert_true(sh_blended.r > 0.12 and sh_blended.r < 0.175, "Cosmos shadow_tint debe mezclarse suavemente sin reemplazar tint base (R=%.3f)" % sh_blended.r)

	scarab.set_anim_state(VoidScarabRigScript.AnimState.DEATH_SHATTER)
	for _i: int in range(12):
		scarab.step(0.033, 0.0, 0.0, 0.0)
	assert_true(float(mat_body.get_shader_parameter("dissolve_amount")) > 0.15, "DEATH_SHATTER debe incrementar dissolve_amount")

	scarab.respawn()
	await _wait_frames(2)
	assert_true(float(mat_body.get_shader_parameter("dissolve_amount")) < 0.01, "respawn() debe resetear dissolve_amount a 0")
	var shutter_respawn: Dictionary = scarab.get_wing_shutter_state()
	assert_true(float(shutter_respawn["speed_ramp"]) < 0.01 and not bool(shutter_respawn["wind_arcs_visible"]), "respawn() debe resetear shutter ramp y wind arcs")

	pass_suite("test_enemy_art_lab: AAA 2.5D Workbench (7 partes, 7 shells, reactor light, scissor bite + VFX, no Valentina) OK")


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame
