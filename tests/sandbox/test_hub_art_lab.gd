extends BaseTestSuite

## Suite de verificación headless para Estación Astral Flotante v3 (Hub Art Lab).
## Valida:
## 1. Mallas 3D ArcSys v2 (Islas Flotantes + Puentes + Props): 3 superficies, winding horario Godot 4,
##    UVs, Tangentes y normales suaves en ARRAY_COLOR.
## 2. Trim-Sheet PBR (albedo, normal, pbr_orm, id, ilm) e Ink SDF 2x (2048x2048) cargado SIN mipmaps.
## 3. Composición 2-Capas (CosmosRootNode vivo a pantalla completa + SubViewport 3D transparente).
## 4. Cámara Telefoto Fija 1:1 (FOV 26°, Pitch -46°, Yaw 0° incluso en Isla Medialuna Oeste).
## 5. Travesía libre Plataforma ↔ Espacio (GROUNDED_HUB + SERAPH_FOLD ↔ Vuelo Zero-G + SERAPH_BLOOM).
## 6. Despegue Radial 8 Direcciones Cardinales + Desmaterialización Tecnológica + Rematerialización.

const LAB_SCENE_PATH: String = "res://sandbox/hub_art_lab/hub_art_lab.tscn"
const HubArtLabScript = preload("res://sandbox/hub_art_lab/hub_art_lab.gd")
const IslandsBuilder = preload("res://scenes/ui/hub/astral_station/meshes/hub_floating_islands_mesh_builder.gd")
const CapsuleBuilder = preload("res://scenes/ui/hub/astral_station/meshes/hub_capsule_mesh_builder.gd")
const ConsoleBuilder = preload("res://scenes/ui/hub/astral_station/meshes/hub_console_mesh_builder.gd")
const TextureLoader = preload("res://scenes/ui/hub/astral_station/components/hub_texture_loader.gd")
const CameraRigScript = preload("res://scenes/ui/hub/astral_station/components/hub_lab_camera_rig.gd")
const StationNodeScript = preload("res://scenes/ui/hub/astral_station/components/hub_lab_station_node.gd")
const CosmosBackdropScript = preload("res://scenes/ui/hub/astral_station/components/hub_cosmos_backdrop_controller.gd")
const LayoutConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_floating_layout_config.gd")
const HubRigAvatar3DScript = preload("res://scenes/ui/hub/components/hub_rig_avatar_3d.gd")
const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")


func _ready() -> void:
	timeout_seconds = 18.0
	super._ready()
	await _run_tests()


func _run_tests() -> void:
	_test_floating_meshes_winding_tangents_and_color_normals()
	_test_trim_sheet_assets_and_no_mipmaps()
	_test_8dir_sector_quantization()
	await _test_floating_hub_scene_and_traversal()
	pass_suite("Estación Astral Flotante v3 verificada: Trim-Sheet PBR, Telefoto 26°/-46°/Yaw 0°, Plataforma↔Espacio + SERAPH_FOLD y Despegue 8-Dir.")


func _test_floating_meshes_winding_tangents_and_color_normals() -> void:
	var three_surface_meshes: Array[Dictionary] = [
		{"name": "CentralFlagshipIsland", "mesh": IslandsBuilder.build_central_flagship_island_mesh()},
		{"name": "WestCrescentIsland", "mesh": IslandsBuilder.build_west_crescent_island_mesh()},
		{"name": "EastSatelliteIsland", "mesh": IslandsBuilder.build_east_island_mesh()},
		{"name": "CompactOctagonIsland", "mesh": IslandsBuilder.build_compact_octagon_island_mesh()},
		{"name": "CentralUnderKeelRing", "mesh": IslandsBuilder.build_central_under_keel_ring_mesh()},
		{"name": "CentralCornerBeacons", "mesh": IslandsBuilder.build_central_corner_beacons_mesh()},
		{"name": "NWFutureMonolith", "mesh": IslandsBuilder.build_future_slot_anchor_mesh()},
		{"name": "PerimeterCompassArc", "mesh": IslandsBuilder.build_perimeter_compass_arc_mesh()},
		{"name": "CapsuleBase", "mesh": CapsuleBuilder.build_capsule_base_mesh()},
		{"name": "ConsoleBody", "mesh": ConsoleBuilder.build_console_body_mesh()},
	]
	for item: Dictionary in three_surface_meshes:
		var m: ArrayMesh = item["mesh"] as ArrayMesh
		var label: String = str(item["name"])
		assert_true(m != null and m.get_surface_count() == 3, "%s debe tener exactamente 3 superficies (ARMOR/CHASSIS/CRYSTAL)" % label)
		var arr0: Array = m.surface_get_arrays(0)
		var verts0: PackedVector3Array = arr0[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var norms0: PackedVector3Array = arr0[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var cols0: PackedColorArray = arr0[Mesh.ARRAY_COLOR] as PackedColorArray
		var uvs0: PackedVector2Array = arr0[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		var tans0: PackedFloat32Array = arr0[Mesh.ARRAY_TANGENT] as PackedFloat32Array
		assert_true(verts0.size() >= 3 and norms0.size() == verts0.size(), "%s debe tener vértices y normales planas válidas" % label)
		assert_true(cols0.size() == verts0.size(), "%s debe almacenar normal suave del outline en ARRAY_COLOR" % label)
		assert_true(uvs0.size() == verts0.size(), "%s debe tener UVs métricos para Trim-Sheet" % label)
		assert_true(tans0.size() == verts0.size() * 4, "%s debe generar tangentes reales para Normal Map" % label)
		var tri_cross: Vector3 = (verts0[2] - verts0[0]).cross(verts0[1] - verts0[0]).normalized()
		assert_true(tri_cross.dot(norms0[0]) > 0.9, "%s debe mantener winding saliente compatible con cull_back" % label)

	for deck_item: Dictionary in [
		{"name": "CentralDeckSurface", "mesh": IslandsBuilder.build_central_deck_surface_mesh()},
		{"name": "NorthObservatoryDeckSurface", "mesh": IslandsBuilder.build_north_observatory_deck_surface_mesh()},
		{"name": "SouthTalentsDeckSurface", "mesh": IslandsBuilder.build_south_talents_deck_surface_mesh()},
		{"name": "WestCrescentDeckSurface", "mesh": IslandsBuilder.build_west_crescent_deck_surface_mesh()},
		{"name": "EastDeckSurface", "mesh": IslandsBuilder.build_east_deck_surface_mesh()},
		{"name": "CompactOctagonDeckSurface", "mesh": IslandsBuilder.build_compact_octagon_deck_surface_mesh()},
		{"name": "CentralGlassCutouts", "mesh": IslandsBuilder.build_central_glass_cutouts_mesh()},
		{"name": "CapsuleDaisSurface", "mesh": CapsuleBuilder.build_capsule_dais_surface_mesh()},
	]:
		var dm: ArrayMesh = deck_item["mesh"] as ArrayMesh
		assert_true(dm != null and dm.get_surface_count() == 1 and dm.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() >= 6, "%s debe construir geometría HQ válida" % str(deck_item["name"]))
	var c_gold: ArrayMesh = IslandsBuilder.build_central_gold_collar_mesh()
	assert_true(c_gold != null and c_gold.get_surface_count() >= 1, "CentralGoldCollar debe construir borde en Oro Astral")


func _test_trim_sheet_assets_and_no_mipmaps() -> void:
	var base: String = "res://assets/environments/astral_station/trims/hub_arcsys_trim"
	var alb: Texture2D = TextureLoader.load_texture_2d(base + ".png", true)
	var id_m: Texture2D = TextureLoader.load_texture_2d(base + "_id_mask.png", false)
	var ilm_m: Texture2D = TextureLoader.load_texture_2d(base + "_ilm_mask.png", true)
	var norm_m: Texture2D = TextureLoader.load_texture_2d(base + "_normal.png", true)
	var orm_m: Texture2D = TextureLoader.load_texture_2d(base + "_pbr_orm.png", true)
	var sdf_m: Texture2D = TextureLoader.load_texture_2d(base + "_ink_sdf.png", false)
	assert_true(alb != null and id_m != null and ilm_m != null and norm_m != null and orm_m != null and sdf_m != null, "Deben cargarse los 6 mapas compilados del Trim-Sheet")
	var sdf_img: Image = sdf_m.get_image()
	assert_true(sdf_img != null and not sdf_img.has_mipmaps(), "hub_arcsys_trim_ink_sdf.png debe cargarse estrictamente SIN mipmaps")
	var alb_img: Image = alb.get_image()
	assert_true(sdf_img.get_width() == alb_img.get_width() * 2 and sdf_img.get_height() == alb_img.get_height() * 2, "hub_arcsys_trim_ink_sdf.png debe estar horneado a resolución 2x")


func _test_8dir_sector_quantization() -> void:
	var layout: LayoutConfigScript = ResourceLoader.load("res://data/hub/default_astral_floating_layout.tres") as LayoutConfigScript
	assert_true(layout != null, "Debe cargar default_hub_floating_layout.tres")
	var cases: Array[Array] = [
		[Vector2(0.0, -1.0), &"N"],
		[Vector2(1.0, -1.0), &"NE"],
		[Vector2(1.0, 0.0), &"E"],
		[Vector2(1.0, 1.0), &"SE"],
		[Vector2(0.0, 1.0), &"S"],
		[Vector2(-1.0, 1.0), &"SW"],
		[Vector2(-1.0, 0.0), &"W"],
		[Vector2(-1.0, -1.0), &"NW"],
	]
	for item: Array in cases:
		var v: Vector2 = item[0] as Vector2
		var expected: StringName = item[1] as StringName
		var sec: Dictionary = layout.quantize_departure_sector(v)
		assert_true(sec.get("id", &"") == expected, "Vector %s debe cuantizarse a sector '%s' (actual='%s')" % [str(v), str(expected), str(sec.get("id", &""))])


func _test_floating_hub_scene_and_traversal() -> void:
	RunLaunchRequestScript.clear_pending()
	var packed: PackedScene = load(LAB_SCENE_PATH) as PackedScene
	assert_true(packed != null, "Debe cargar hub_art_lab.tscn")

	var lab: HubArtLabScript = packed.instantiate() as HubArtLabScript
	assert_true(lab != null, "Debe instanciar HubArtLab")
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame

	# 1. Viewport Stack 2-Capas + Eliminación de Ventanal Plano y Anillo Norte
	var backdrop: CosmosBackdropScript = lab.cosmos_backdrop
	assert_true(backdrop != null and backdrop.get_cosmos_root() != null, "HubCosmosBackdropController debe instanciar CosmosRootNode vivo a pantalla completa")
	assert_true(lab.hub_3d_viewport != null and lab.hub_3d_viewport.transparent_bg, "Hub3DSubViewport debe ser transparente sobre CosmosRootNode")
	assert_true(lab.find_child("NorthCosmosWindowMesh", true, false) == null, "No debe existir el cartel plano NorthCosmosWindowMesh")
	assert_true(lab.find_child("IgnitionRingMesh", true, false) == null, "No debe existir IgnitionRingMesh")

	backdrop.set_preview_seed(123456, true)
	assert_true(backdrop.get_preview_seed() == 123456, "set_preview_seed debe registrar la semilla 123456")

	# 2. Cámara Telefoto 1:1 (FOV 26°, Pitch -46°, Yaw 0° bloqueado incluso en Reliquias Oeste)
	assert_true(lab.player != null and lab.camera != null, "HubArtLab debe instanciar Player y Camera3D")
	var avatar: HubRigAvatar3DScript = lab.player.rig_avatar
	assert_true(avatar != null, "HubArtLabPlayer debe montar HubRigAvatar3D")
	assert_true(avatar.diorama_config.viewport_size >= 1280 and avatar.diorama_config.rig_camera_zoom <= 3.0, "AvatarSubViewport debe tener canvas amplio para alas 3D y anillo orbital sin recorte cuadrado")
	var rig: PlanarCombatRig = avatar.get_rig()
	assert_true(rig != null and rig.pilot_profile != null and rig.pilot_profile.pilot_id == "valentina_v2", "Rig del HubArtLab debe ser valentina_v2")
	assert_true(is_equal_approx(lab.camera.fov, 26.0), "FOV Telefoto FREE_ROAM debe ser 26.0")
	assert_true(is_equal_approx(lab.camera.rotation_degrees.x, -46.0), "Pitch Telefoto FREE_ROAM debe ser -46.0")
	assert_true(absf(lab.camera.rotation_degrees.y) < 0.01, "Yaw de cámara debe iniciar en 0.0")
	assert_true(is_equal_approx(avatar.diorama_config.avatar_tilt_deg, -46.0) and is_equal_approx(avatar.diorama_config.avatar_aspect_y_comp, 1.0), "Sprite 3D debe alinearse 1:1 con cámara (-46°, aspect 1.0)")

	# 3. Travesía Plataforma ↔ Espacio (Alas 3D abren en espacio y se pliegan con SERAPH_FOLD en isla)
	assert_true(not lab.player.is_flying_in_space and avatar.is_grounded_mode(), "En Isla Central la piloto debe caminar en GROUNDED_HUB")
	assert_true(not rig.enable_3d_wings, "En cubierta las alas 3D deben iniciar desactivadas")

	lab.player.global_position = Vector3(9.5, 0.02, 3.8) # Vacío espacial entre Octágono Central e Isla Este
	for _i: int in range(4):
		lab.player.evaluate_platform_traversal(0.05, false)
		await get_tree().process_frame
	assert_true(lab.player.is_flying_in_space, "Al salir al espacio abierto debe conmutar a vuelo Zero-G")
	assert_true(rig.enable_3d_wings and not avatar.is_grounded_mode(), "En vuelo espacial debe desplegar Alas 3D (SERAPH_BLOOM)")

	# Volar hacia Bastión Espejado Oeste (Reliquias): cero giro de cámara y repliegue SERAPH_FOLD
	lab.player.global_position = Vector3(-15.42, 0.02, 0.0)
	for _j: int in range(4):
		lab.player.evaluate_platform_traversal(0.05, false)
		await get_tree().process_frame
	lab.camera_rig.update(lab.camera, lab.player.global_position, 0.0, lab.config, true)
	assert_true(absf(lab.camera.rotation_degrees.y) < 0.01 and is_equal_approx(lab.camera.rotation_degrees.x, -46.0), "En Isla Medialuna Oeste la cámara NO debe girar yaw ni alterar pitch")
	assert_true(not lab.player.is_flying_in_space, "Al pisar Isla Medialuna Oeste debe volver a estado plataforma")
	var w_ctrl: AstralWings3DController = rig.get_3d_wings_controller()
	assert_true(w_ctrl == null or w_ctrl.get_anim_state() == AstralWings3DController.AnimState.SERAPH_FOLD or not rig.enable_3d_wings, "Al aterrizar debe disparar SERAPH_FOLD antes de apagar alas")

	# Avanzar determinísticamente para completar repliegue SERAPH_FOLD (>= 0.40 s)
	for _k: int in range(6):
		if w_ctrl != null and is_instance_valid(w_ctrl):
			w_ctrl.step(0.10, false)
		avatar._process(0.10)
		await get_tree().process_frame
	assert_true(not rig.enable_3d_wings, "Al completar SERAPH_FOLD las alas 3D deben apagarse limpiamente")

	# 4. Cápsula Central -> alinea 's' y Estados de Progresión
	lab.trigger_capsule_focus()
	await get_tree().process_frame
	assert_true(avatar.get_active_view_key() == "s", "La Cápsula Central debe alinear al piloto mirando al frente ('s')")
	assert_true(lab.camera_rig.get_mode() == CameraRigScript.Mode.CAPSULE_PILOT_FOCUS, "Cámara debe cambiar a CAPSULE_PILOT_FOCUS")
	lab.exit_capsule_focus()

	lab.apply_progression_preset(&"run1")
	var st_r: StationNodeScript = lab.right_station
	assert_true(st_r != null and st_r.get_station_state() == StationNodeScript.StationState.CALIBRATING, "RightStation debe iniciar CALIBRATING en run1")
	st_r.set_station_state(StationNodeScript.StationState.ONLINE)
	assert_true(st_r.get_station_state() == StationNodeScript.StationState.ONLINE, "RightStation debe pasar a ONLINE")

	# 5. Despegue Radial 8-Dir (Sector NE) + Desmaterialización Tecnológica + Rematerialización
	assert_true(lab.layout_config.bridges.size() == 8, "La Mandala Octagonal debe definir exactamente 8 puentes perpendiculares")
	lab.departure_controller.launch_real_combat = false
	lab.player.global_position = Vector3(23.0, 0.44, -23.0) # ~32.5m > launch_radius (30.0) en NE
	for _d: int in range(20):
		lab.departure_controller._process(0.10)
		await get_tree().process_frame
		if lab.departure_controller.is_dissolved_preview():
			break

	assert_true(lab.departure_controller.is_dissolved_preview(), "Despegue radial debe completar desmaterialización en modo Preview")
	assert_true(lab.departure_controller.get_demat_progress() >= 0.99, "demat_progress debe llegar a 1.0")
	assert_true(avatar.is_orbital_weapon_showcase_enabled(), "Despegue radial debe desplegar el Anillo Orbital de Armamento")
	var pending_req: RunLaunchRequestScript = RunLaunchRequestScript.consume_pending()
	assert_true(pending_req != null and pending_req.seamless_entry and pending_req.departure_sector == &"NE", "RunLaunchRequest debe registrar seamless_entry=true y departure_sector='NE'")

	lab.departure_controller.rematerialize_hub(true)
	for _r: int in range(14):
		lab.departure_controller._process(0.10)
		await get_tree().process_frame
		if lab.departure_controller.get_demat_progress() <= 0.01:
			break
	assert_true(lab.departure_controller.get_demat_progress() <= 0.01, "Rematerializar debe restaurar demat_progress a 0.0")
	assert_true(not avatar.is_orbital_weapon_showcase_enabled(), "Rematerializar debe replegar el Anillo Orbital")

	lab.queue_free()
	await get_tree().process_frame
