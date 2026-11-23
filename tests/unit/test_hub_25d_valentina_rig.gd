extends BaseTestSuite
## Suite de verificación Fase 3: Rework 2.5D Diorama del Hub 3D,
## HubRigAvatar3D (Valentina v2 sin alas ni anillo), locomoción 8-dir,
## apertura de oclusores en +Z y bloqueo de pedestales ("EN REWORK").

const HubWorldScene: PackedScene = preload("res://scenes/ui/hub/hub_world.tscn")
const HubRigAvatar3DScript = preload("res://scenes/ui/hub/components/hub_rig_avatar_3d.gd")


func _ready() -> void:
	timeout_seconds = 15.0
	super._ready()
	_run_tests()


func _run_tests() -> void:
	var hub: HubWorld = HubWorldScene.instantiate() as HubWorld
	assert_true(hub != null, "hub_world.tscn debe instanciar como HubWorld")
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	_test_default_valentina_and_avatar(hub)
	_test_diorama_camera_fixed_across_wings(hub)
	_test_wasd_8dir_native_mapping(hub)
	_test_ceiling_and_plus_z_occluders_opened(hub)
	_test_pedestal_rework_lockout(hub)
	_test_zero_sandbox_refs_in_hub()

	hub.queue_free()
	pass_suite("Fase 3 verificada: Hub 2.5D Diorama, HubRigAvatar3D Valentina v2 y lockout de pedestales.")


func _test_default_valentina_and_avatar(hub: HubWorld) -> void:
	var pc: HubPlayerController3D = hub.player_controller as HubPlayerController3D
	assert_true(pc != null, "HubWorld debe tener PlayerController")
	assert_true(pc.active_character_id == &"valentina", "Valentina debe iniciar seleccionada por defecto en HubPlayerController3D")
	assert_true(hub.current_pilot_index >= 0 and hub.PILOT_ROSTER[hub.current_pilot_index]["id"] == &"valentina", "HubWorld debe iniciar con Valentina seleccionada")

	var legacy_sprite: Node = pc.get_node_or_null("Sprite3D")
	assert_true(legacy_sprite == null, "No debe existir Sprite3D legacy en PlayerController")

	var avatar: HubRigAvatar3DScript = pc.get_node_or_null("HubRigAvatar3D") as HubRigAvatar3DScript
	assert_true(avatar != null, "Debe existir PlayerController/HubRigAvatar3D")

	var vp: SubViewport = avatar.get_subviewport()
	assert_true(vp != null, "HubRigAvatar3D debe tener SubViewport")
	assert_true(vp.size == Vector2i(512, 512), "AvatarSubViewport debe medir 512x512")
	assert_true(vp.transparent_bg, "AvatarSubViewport debe tener transparent_bg = true")
	assert_true(vp.use_hdr_2d, "AvatarSubViewport debe tener use_hdr_2d = true")
	assert_true(vp.msaa_2d == Viewport.MSAA_4X, "AvatarSubViewport debe tener MSAA_4X")

	var rig: PlanarCombatRig = avatar.get_rig()
	assert_true(rig != null, "HubRigAvatar3D debe instanciar PlanarCombatRig")
	assert_true(rig.pilot_profile != null and rig.pilot_profile.pilot_id == "valentina_v2", "PlanarCombatRig debe usar valentina_v2_profile")
	assert_true(rig.is_face_live_enabled(), "PlanarCombatRig debe tener enable_face_live = true")
	assert_true(not rig.enable_base_propulsion_wings, "Hub no debe activar alas base")
	assert_true(not rig.enable_3d_wings, "Hub no debe activar alas 3D")
	assert_true(rig.get_base_propulsion_controller() == null, "No debe instanciarse ValentinaBasePropulsionController en Hub")
	assert_true(rig.get_3d_wings_controller() == null, "No debe instanciarse AstralWings3DController en Hub")

	var style: RigStyleProfile = rig.get_current_style_profile()
	assert_true(style != null and style.id == "02_valentina_razor_sharp", "El estilo activo del rig debe ser 02_valentina_razor_sharp")
	assert_true(not _has_orbital_weapon_ring(avatar), "HubRigAvatar3D no debe contener OrbitalWeaponRingController")

	var sprite_3d: Sprite3D = avatar.get_sprite_3d()
	assert_true(sprite_3d != null, "HubRigAvatar3D debe exponer AvatarSprite3D")
	assert_true(sprite_3d.texture == vp.get_texture(), "AvatarSprite3D debe usar la textura del SubViewport")
	assert_true(sprite_3d.alpha_cut == SpriteBase3D.ALPHA_CUT_DISABLED, "AvatarSprite3D debe tener alpha_cut = ALPHA_CUT_DISABLED")

	var shadow: Sprite3D = pc.shadow_sprite
	assert_true(shadow != null, "PlayerController debe mantener PlayerShadow")
	assert_true(shadow.texture == sprite_3d.texture, "PlayerShadow debe compartir textura con AvatarSprite3D")
	assert_true(shadow.offset == sprite_3d.offset, "PlayerShadow debe compartir offset de pies con AvatarSprite3D")


func _has_orbital_weapon_ring(root: Node) -> bool:
	for child: Node in root.get_children():
		var scr: Script = child.get_script() as Script
		if scr != null and scr.resource_path.contains("orbital_weapon_ring"):
			return true
		if child.name.contains("OrbitalWeapon"):
			return true
		if _has_orbital_weapon_ring(child):
			return true
	return false


func _test_diorama_camera_fixed_across_wings(hub: HubWorld) -> void:
	var pc: HubPlayerController3D = hub.player_controller as HubPlayerController3D
	var cam: Camera3D = pc.camera
	assert_true(cam != null, "PlayerController debe tener Camera3D")
	assert_true(is_equal_approx(cam.fov, 38.0), "FOV de cámara Diorama debe ser 38.0")
	assert_true(is_equal_approx(cam.rotation_degrees.x, -42.0), "Pitch de cámara Diorama debe ser -42.0")
	assert_true(absf(cam.rotation_degrees.y) < 0.01, "Yaw de cámara Diorama debe ser 0.0")

	for z_pos: float in [-6.0, 0.0, 16.8, 32.0]:
		pc.global_position = Vector3(0.0, 0.05, z_pos)
		pc._update_camera(10.0)
		assert_true(is_equal_approx(cam.fov, 38.0), "FOV debe mantenerse fijo en 38.0 en Z=%.1f" % z_pos)
		assert_true(is_equal_approx(cam.rotation_degrees.x, -42.0), "Pitch debe mantenerse fijo en -42.0 en Z=%.1f" % z_pos)
		assert_true(absf(cam.rotation_degrees.y) < 0.01, "No debe haber giro orbital 180° en Z=%.1f" % z_pos)

	assert_true(is_equal_approx(cam.global_position.z, 42.2), "La cámara debe acompañar al ala sur hasta Z=42.2 (got %.2f)" % cam.global_position.z)


func _test_wasd_8dir_native_mapping(hub: HubWorld) -> void:
	var pc: HubPlayerController3D = hub.player_controller as HubPlayerController3D
	var avatar: HubRigAvatar3DScript = pc.rig_avatar
	var rig: PlanarCombatRig = avatar.get_rig()
	var cases: Array[Array] = [
		[Vector2(0.0, 1.0), "s"],
		[Vector2(1.0, 1.0), "se"],
		[Vector2(1.0, 0.0), "e"],
		[Vector2(1.0, -1.0), "ne"],
		[Vector2(0.0, -1.0), "n"],
		[Vector2(-1.0, -1.0), "nw"],
		[Vector2(-1.0, 0.0), "w"],
		[Vector2(-1.0, 1.0), "sw"],
	]
	for entry: Array in cases:
		var dir_v: Vector2 = entry[0] as Vector2
		var expected_key: String = str(entry[1])
		pc.set_input_direction_for_test(dir_v, 1.0, true)
		assert_true(rig.get_active_view_key() == expected_key, "Dirección %s debe enrutar a vista '%s' (actual: '%s')" % [str(dir_v), expected_key, rig.get_active_view_key()])
		assert_true(not rig.is_body_flipped(), "body_flip_x debe ser false en vista '%s'" % expected_key)
		assert_true(not rig.is_backpedaling(), "No debe haber backpedal en vista '%s'" % expected_key)


func _test_ceiling_and_plus_z_occluders_opened(hub: HubWorld) -> void:
	var ceiling: Node3D = hub.get_node_or_null("HangarRoom/Ceiling") as Node3D
	assert_true(ceiling != null, "Nodo HangarRoom/Ceiling debe existir")
	assert_true(ceiling.get_node_or_null("MeshInstance3D") == null, "Malla sólida del techo debe haberse retirado")
	var ceiling_col: CollisionShape3D = ceiling.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert_true(ceiling_col != null and ceiling_col.disabled, "Colisión del techo debe estar deshabilitada")

	for wall_name: String in ["BackWall_L1", "BackWall_L2", "BackWall_R1", "BackWall_R2"]:
		var wall: Node3D = hub.get_node_or_null("HangarRoom/" + wall_name) as Node3D
		assert_true(wall != null, "Muro %s debe existir" % wall_name)
		assert_true(wall.scale.y <= 0.30, "Muro %s debe estar rebajado (scale.y=%.2f)" % [wall_name, wall.scale.y])

	var gate: Node3D = hub.get_node_or_null("HangarRoom/KenneyGate") as Node3D
	assert_true(gate != null and not gate.visible, "HangarRoom/KenneyGate debe estar oculto para no ocluir el pasaje")

	var south_win: Node3D = hub.get_node_or_null("HangarRoom/MirroredWing/SouthWallWindow") as Node3D
	assert_true(south_win != null and not south_win.visible, "MirroredWing/SouthWallWindow debe estar oculto para despejar la cámara")

	for preserved_path: String in [
		"HangarRoom/Floor",
		"HangarRoom/template-floor-layer2",
		"HangarRoom/template-floor-layer3",
		"HangarRoom/NorthWindowGateFrame",
		"Terminals/MissionTerminal",
		"Terminals/GachaTerminal",
		"Terminals/HighScoresTerminal",
		"SpaceParallax/Layer0_Deep",
		"SpaceParallax/Layer1_Mid",
		"SpaceParallax/Layer2_Near",
	]:
		var node: Node3D = hub.get_node_or_null(preserved_path) as Node3D
		assert_true(node != null and node.visible, "Elemento preservado debe existir y estar visible: %s" % preserved_path)

	var trophy_room: Node3D = hub.get_node_or_null("TrophyRoom") as Node3D
	assert_true(trophy_room != null and trophy_room.get_child_count() >= 5, "TrophyRoom debe conservar sus 5 pedestales")


func _test_pedestal_rework_lockout(hub: HubWorld) -> void:
	var val_ped: Node3D = hub.get_node_or_null("PilotPedestals/Pedestal_Valentina") as Node3D
	assert_true(val_ped != null and val_ped.visible, "Pedestal_Valentina debe existir y ser visible")
	var val_beam: Node3D = val_ped.get_node_or_null("HoloBeam") as Node3D
	assert_true(val_beam != null and val_beam.visible, "HoloBeam de Valentina debe estar activo")
	var val_inter: HubInteractable3D = hub.get_node_or_null("RosterCutouts/Interactable_Valentina") as HubInteractable3D
	assert_true(val_inter != null and val_inter.monitoring, "Interactable_Valentina debe estar habilitado")
	var val_cutout: Sprite3D = hub.get_node_or_null("RosterCutouts/Cutout_Valentina") as Sprite3D
	assert_true(val_cutout == null or not val_cutout.visible, "Cutout_Valentina debe permanecer oculto (avatar v2 vivo)")

	for locked_name: String in ["Nova", "Kira", "Selene", "Roxy", "Echo", "Nyx"]:
		var ped: Node3D = hub.get_node_or_null("PilotPedestals/Pedestal_" + locked_name) as Node3D
		assert_true(ped != null and ped.visible, "Pedestal apagado de %s debe ser visible" % locked_name)
		var beam: Node3D = ped.get_node_or_null("HoloBeam") as Node3D
		var rot: Node3D = ped.get_node_or_null("RotatorRing") as Node3D
		var light: OmniLight3D = ped.get_node_or_null("PedestalLight") as OmniLight3D
		var badge: Label3D = ped.get_node_or_null("ActiveBadge") as Label3D
		assert_true(beam != null and not beam.visible, "HoloBeam de %s debe estar apagado" % locked_name)
		assert_true(rot != null and not rot.visible, "RotatorRing de %s debe estar apagado" % locked_name)
		assert_true(light != null and not light.visible, "PedestalLight de %s debe estar apagado" % locked_name)
		assert_true(badge != null and badge.visible and badge.text.contains("EN REWORK"), "Badge de %s debe mostrar EN REWORK" % locked_name)

		var cutout: Sprite3D = hub.get_node_or_null("RosterCutouts/Cutout_" + locked_name) as Sprite3D
		assert_true(cutout == null or not cutout.visible, "Cutout de %s debe estar oculto" % locked_name)
		var inter: HubInteractable3D = hub.get_node_or_null("RosterCutouts/Interactable_" + locked_name) as HubInteractable3D
		assert_true(inter != null and not inter.monitoring and not inter.visible, "Interactable de %s debe estar deshabilitado" % locked_name)

	hub._select_pilot(0)
	assert_true(hub.PILOT_ROSTER[hub.current_pilot_index]["id"] == &"valentina", "Intentar seleccionar piloto bloqueada debe mantener a Valentina")


func _test_zero_sandbox_refs_in_hub() -> void:
	var bad_refs: Array[String] = _scan_dir_for_sandbox_refs("res://scenes/ui/hub")
	assert_true(bad_refs.is_empty(), "No deben existir referencias a res://sandbox/ en scenes/ui/hub/: %s" % str(bad_refs))


func _scan_dir_for_sandbox_refs(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var full_path: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				found.append_array(_scan_dir_for_sandbox_refs(full_path))
			elif entry.ends_with(".gd") or entry.ends_with(".tscn") or entry.ends_with(".tres"):
				var txt: String = FileAccess.get_file_as_string(full_path)
				if txt.contains("res://sandbox/"):
					found.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
