extends BaseTestSuite

## Suite de verificación headless para Hub Art Lab (Fase 1 Vertical Slice — Estación Astral v2).
## Valida mallas 3D ArcSys (3 superficies + winding horario), carga de mapas Ink SDF 2x sin mipmaps,
## foco en Cápsula Central ("s"), progresión de Consolas (CALIBRATING/NEWLY_UNLOCKED/ONLINE) y
## Ventanal Norte con CosmosRootNode vivo y escalable por calidad.

const LAB_SCENE_PATH: String = "res://sandbox/hub_art_lab/hub_art_lab.tscn"
const HubArtLabScript = preload("res://sandbox/hub_art_lab/hub_art_lab.gd")
const ArchBuilder = preload("res://sandbox/hub_art_lab/meshes/hub_architecture_mesh_builder.gd")
const CapsuleBuilder = preload("res://sandbox/hub_art_lab/meshes/hub_capsule_mesh_builder.gd")
const ConsoleBuilder = preload("res://sandbox/hub_art_lab/meshes/hub_console_mesh_builder.gd")
const TextureLoader = preload("res://sandbox/hub_art_lab/components/hub_texture_loader.gd")
const CameraRigScript = preload("res://sandbox/hub_art_lab/components/hub_lab_camera_rig.gd")
const StationNodeScript = preload("res://sandbox/hub_art_lab/components/hub_lab_station_node.gd")
const CosmosWindowScript = preload("res://sandbox/hub_art_lab/components/hub_cosmos_window_controller.gd")
const HubRigAvatar3DScript = preload("res://scenes/ui/hub/components/hub_rig_avatar_3d.gd")


func _ready() -> void:
	timeout_seconds = 14.0
	super._ready()
	await _run_tests()


func _run_tests() -> void:
	_test_procedural_meshes_winding_and_surfaces()
	_test_compiled_assets_and_no_mipmaps()
	await _test_hub_art_lab_scene_interactions()
	pass_suite("Fase 1 HubArtLab verificada: mallas 3D ArcSys, mapas Ink SDF 2x, Cápsula 's', Consolas y Cosmos Ventanal.")


func _test_procedural_meshes_winding_and_surfaces() -> void:
	var box_arr: Array = BoxMesh.new().get_mesh_arrays()
	var b_verts: PackedVector3Array = box_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var b_norms: PackedVector3Array = box_arr[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var b_idx: PackedInt32Array = box_arr[Mesh.ARRAY_INDEX] as PackedInt32Array
	var box_cross: Vector3 = (b_verts[b_idx[2]] - b_verts[b_idx[0]]).cross(b_verts[b_idx[1]] - b_verts[b_idx[0]]).normalized()
	assert_true(box_cross.dot(b_norms[b_idx[0]]) > 0.9, "Winding horario Godot 4 (c-a)x(b-a) debe coincidir con BoxMesh")

	var three_surface_meshes: Array[Dictionary] = [
		{"name": "CapsuleBase", "mesh": CapsuleBuilder.build_capsule_base_mesh()},
		{"name": "CapsuleHalo", "mesh": CapsuleBuilder.build_capsule_halo_mesh()},
		{"name": "ConsoleBody", "mesh": ConsoleBuilder.build_console_body_mesh()},
		{"name": "ConsoleHoloPrism", "mesh": ConsoleBuilder.build_console_holo_prism_mesh()},
		{"name": "StructuralRibs", "mesh": ArchBuilder.build_structural_ribs_mesh()},
		{"name": "NorthWindowFrame", "mesh": ArchBuilder.build_north_window_frame_mesh()},
		{"name": "SouthRailing", "mesh": ArchBuilder.build_south_railing_mesh()},
		{"name": "IgnitionPadSocket", "mesh": ArchBuilder.build_ignition_pad_socket_mesh()},
		{"name": "WingAlcovePads", "mesh": ArchBuilder.build_wing_alcove_pads_mesh()},
	]
	for item: Dictionary in three_surface_meshes:
		var m: ArrayMesh = item["mesh"] as ArrayMesh
		var label: String = str(item["name"])
		assert_true(m != null and m.get_surface_count() == 3, "%s debe tener exactamente 3 superficies (ARMOR/CHASSIS/CRYSTAL)" % label)
		var arr0: Array = m.surface_get_arrays(0)
		var verts0: PackedVector3Array = arr0[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var norms0: PackedVector3Array = arr0[Mesh.ARRAY_NORMAL] as PackedVector3Array
		assert_true(verts0.size() >= 3 and norms0.size() == verts0.size(), "%s debe tener vértices y normales planas válidas" % label)
		var tri_cross: Vector3 = (verts0[2] - verts0[0]).cross(verts0[1] - verts0[0]).normalized()
		assert_true(tri_cross.dot(norms0[0]) > 0.9, "%s debe mantener winding saliente compatible con cull_back" % label)

	var floor_m: ArrayMesh = ArchBuilder.build_floor_mesh()
	assert_true(floor_m != null and floor_m.get_surface_count() == 1, "FloorMesh debe tener 1 superficie")
	var f_arr: Array = floor_m.surface_get_arrays(0)
	var f_v: PackedVector3Array = f_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var f_n: PackedVector3Array = f_arr[Mesh.ARRAY_NORMAL] as PackedVector3Array
	assert_true(f_n[0].dot(Vector3.UP) > 0.999, "FloorMesh debe apuntar hacia +Y")
	assert_true(((f_v[2] - f_v[0]).cross(f_v[1] - f_v[0])).normalized().dot(Vector3.UP) > 0.9, "FloorMesh debe tener winding horario hacia +Y")

	var wall_m: ArrayMesh = ArchBuilder.build_side_wall_mesh()
	assert_true(wall_m != null and wall_m.get_surface_count() == 1, "SideWallMesh debe tener 1 superficie")
	var w_arr: Array = wall_m.surface_get_arrays(0)
	var w_v: PackedVector3Array = w_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var w_n: PackedVector3Array = w_arr[Mesh.ARRAY_NORMAL] as PackedVector3Array
	assert_true(w_n[0].dot(Vector3.RIGHT) > 0.9, "SideWallMesh debe apuntar hacia +X")
	assert_true(((w_v[2] - w_v[0]).cross(w_v[1] - w_v[0])).normalized().dot(Vector3.RIGHT) > 0.9, "SideWallMesh debe tener winding horario saliente hacia +X")


func _test_compiled_assets_and_no_mipmaps() -> void:
	var surface_bases: Array[String] = [
		"res://sandbox/hub_art_lab/assets/surfaces/hub_floor_astral",
		"res://sandbox/hub_art_lab/assets/surfaces/hub_wall_astral",
	]
	for base: String in surface_bases:
		var alb: Texture2D = TextureLoader.load_texture_2d(base + ".png", true)
		var id_m: Texture2D = TextureLoader.load_texture_2d(base + "_id_mask.png", false)
		var ilm_m: Texture2D = TextureLoader.load_texture_2d(base + "_ilm_mask.png", true)
		var sdf_m: Texture2D = TextureLoader.load_texture_2d(base + "_ink_sdf.png", false)
		assert_true(alb != null and id_m != null and ilm_m != null and sdf_m != null, "Deben cargarse los 4 mapas compilados de %s" % base)
		var sdf_img: Image = sdf_m.get_image()
		assert_true(sdf_img != null and not sdf_img.has_mipmaps(), "%s_ink_sdf.png debe cargarse estrictamente SIN mipmaps" % base)
		var alb_img: Image = alb.get_image()
		assert_true(sdf_img.get_width() == alb_img.get_width() * 2 and sdf_img.get_height() == alb_img.get_height() * 2, "%s_ink_sdf debe estar horneado a resolución 2x" % base)

	var ring_tex: Texture2D = TextureLoader.load_texture_2d("res://sandbox/hub_art_lab/assets/rings/hub_ignition_ring_packed.png", true)
	assert_true(ring_tex != null, "hub_ignition_ring_packed.png debe cargarse correctamente")


func _test_hub_art_lab_scene_interactions() -> void:
	var packed: PackedScene = load(LAB_SCENE_PATH) as PackedScene
	assert_true(packed != null, "Debe cargar hub_art_lab.tscn")

	var lab: HubArtLabScript = packed.instantiate() as HubArtLabScript
	assert_true(lab != null, "Debe instanciar HubArtLab")
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(lab.player != null, "HubArtLab debe instanciar HubArtLabPlayer")
	var avatar: HubRigAvatar3DScript = lab.player.rig_avatar
	assert_true(avatar != null, "HubArtLabPlayer debe montar HubRigAvatar3D")
	var rig: PlanarCombatRig = avatar.get_rig()
	assert_true(rig != null and rig.pilot_profile != null and rig.pilot_profile.pilot_id == "valentina_v2", "Rig del HubArtLab debe ser valentina_v2")
	var style: RigStyleProfile = rig.get_current_style_profile()
	assert_true(style != null and style.id == "02_valentina_razor_sharp", "Estilo activo debe ser 02_valentina_razor_sharp")

	assert_true(lab.camera != null, "HubArtLab debe tener Camera3D")
	assert_true(is_equal_approx(lab.camera.fov, 38.0), "FOV inicial FREE_ROAM debe ser 38.0")
	assert_true(is_equal_approx(lab.camera.rotation_degrees.x, -42.0), "Pitch inicial FREE_ROAM debe ser -42.0")

	# Test 3: Foco en Cápsula Central -> alinea vista "s" y modo CAPSULE_PILOT_FOCUS
	avatar.set_motion_state(Vector2.RIGHT, 0.8, Vector2.RIGHT, true)
	assert_true(avatar.get_active_view_key() == "e", "Precondición: piloto mirando al Este antes de entrar a Cápsula")
	lab.trigger_capsule_focus()
	await get_tree().process_frame
	assert_true(avatar.get_active_view_key() == "s", "La Cápsula Central debe alinear automáticamente al piloto mirando de frente ('s')")
	assert_true(lab.camera_rig.get_mode() == CameraRigScript.Mode.CAPSULE_PILOT_FOCUS, "La cámara debe cambiar a CAPSULE_PILOT_FOCUS")
	lab.exit_capsule_focus()
	assert_true(lab.camera_rig.get_mode() == CameraRigScript.Mode.FREE_ROAM, "exit_capsule_focus debe restaurar FREE_ROAM")

	# Test 4: Estados de progresión en Consola de Antesala
	var st_r: StationNodeScript = lab.right_station
	assert_true(st_r != null, "Debe existir RightTacticalConsole")
	assert_true(st_r.get_station_state() == StationNodeScript.StationState.CALIBRATING, "Consola Derecha debe iniciar en CALIBRATING")
	assert_true(is_equal_approx(st_r.get_calibration_factor(), 1.0), "CALIBRATING debe fijar calibration_factor = 1.0")
	var holo_node: Node3D = st_r.get_node_or_null("HoloPrismMesh") as Node3D
	assert_true(holo_node != null and not holo_node.visible, "HoloPrismMesh debe ocultarse en CALIBRATING")

	st_r.set_station_state(StationNodeScript.StationState.NEWLY_UNLOCKED)
	assert_true(is_equal_approx(st_r.get_calibration_factor(), 0.0) and holo_node.visible, "NEWLY_UNLOCKED debe activar el prisma holográfico")
	st_r.set_station_state(StationNodeScript.StationState.ONLINE)
	assert_true(st_r.get_station_state() == StationNodeScript.StationState.ONLINE and holo_node.visible, "ONLINE debe mantener la consola activa")

	# Test 5: Ventanal Norte CosmosRootNode (Semilla + Calidad SubViewport)
	var cw: CosmosWindowScript = lab.cosmos_window
	assert_true(cw != null, "Debe existir HubCosmosWindowController")
	assert_true(cw.get_cosmos_root() != null, "HubCosmosWindowController debe instanciar CosmosRootNode dentro del SubViewport")
	assert_true(cw.get_cosmos_root().floating_origin_tracker == null or not cw.get_cosmos_root().floating_origin_tracker.is_enabled, "FloatingOriginTracker debe permanecer desactivado en el preview")

	cw.set_preview_seed(123456, true)
	assert_true(cw.get_preview_seed() == 123456, "set_preview_seed debe registrar la semilla 123456")

	var expected_sizes: Array[Vector2i] = lab.config.cosmos_viewport_resolutions
	for tier: int in range(3):
		cw.apply_quality_tier(tier)
		assert_true(cw.get_subviewport().size == expected_sizes[tier], "SubViewport del Ventanal Cosmos debe escalar a %s en calidad %d" % [str(expected_sizes[tier]), tier])

	lab.queue_free()
	await get_tree().process_frame
