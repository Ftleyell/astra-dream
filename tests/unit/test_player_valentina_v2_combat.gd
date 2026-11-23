extends BaseTestSuite
## Suite de verificación Fase 5: Integración de Valentina v2 en combate in-game,
## Twin-Stick Kiting 360°, iluminación cósmica, Sobre-Enfoque, reacciones y Anillo Orbital multi-arma (1–4 slots).

const CosmosEnvScene: PackedScene = preload("res://scenes/combat/environment/cosmos_combat_environment.tscn")
const AstralWings3DCtrlScript = preload("res://scenes/pilots/vfx/astral_wings_3d_controller.gd")
const PlayerRigV2ControllerScript = preload("res://scenes/combat/player/player_rig_v2_controller.gd")

var _had_save_backup: bool = false
var _save_backup_text: String = ""


class MockEnemy extends Node2D:
	var current_health: float = 200.0
	var is_dying: bool = false
	var is_invulnerable: bool = false

	func _ready() -> void:
		add_to_group("enemies")

	func take_damage(ctx: HitContext) -> void:
		current_health -= ctx.final_damage


func _ready() -> void:
	timeout_seconds = 14.0
	super._ready()
	_backup_profile_file()
	await _run_tests()


func _backup_profile_file() -> void:
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		_had_save_backup = true
		_save_backup_text = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)


func _restore_profile_file() -> void:
	Engine.time_scale = 1.0
	if _had_save_backup:
		var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_save_backup_text)
			f.close()
	elif FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))


func _cleanup_and_quit(exit_code: int) -> void:
	_restore_profile_file()
	await super._cleanup_and_quit(exit_code)


func _spawn_test_player(cdata: CharacterData, bserver: BulletServer, parent_node: Node) -> Player:
	var p := Player.new()
	p.character_data = cdata
	p.bullet_server = bserver
	p.global_position = Vector2(960.0, 540.0)

	var vp := Polygon2D.new()
	vp.name = "VisualPlaceholder"
	p.add_child(vp)

	var hb := Polygon2D.new()
	hb.name = "HitboxCore"
	p.add_child(hb)

	var wc := WeaponController.new()
	wc.name = "WeaponController"
	wc.player = p
	p.add_child(wc)

	var wvis := Polygon2D.new()
	wvis.name = "WeaponVisual"
	wc.add_child(wvis)

	parent_node.add_child(p)
	return p


func _assert_zero_z_recursive(node: Node, context_label: String) -> void:
	for child: Node in node.get_children():
		if child is CanvasItem:
			assert_true((child as CanvasItem).z_index == 0, "%s: nodo '%s' bajo UnifiedCharacterGroup debe mantener z_index=0" % [context_label, child.name])
		_assert_zero_z_recursive(child, context_label)


func _run_tests() -> void:
	var arena := Node2D.new()
	arena.name = "TestCombatArena"
	add_child(arena)

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position = Vector2(960.0, 540.0)
	cam.enabled = true
	cam.add_to_group("camera")
	arena.add_child(cam)

	var cosmos_env: CosmosCombatEnvironment = CosmosEnvScene.instantiate() as CosmosCombatEnvironment
	cosmos_env.name = "SpaceBackground"
	arena.add_child(cosmos_env)
	cosmos_env.set_camera_reference(cam)

	var bserver := BulletServer.new()
	bserver.name = "BulletServer"
	arena.add_child(bserver)

	var roster: Dictionary[StringName, CharacterData] = CharacterData.load_roster()
	var val_data: CharacterData = roster.get(&"valentina", null)
	var nova_data: CharacterData = roster.get(&"nova", null)
	assert_true(val_data != null and val_data.pilot_rig_profile != null, "valentina.tres debe tener pilot_rig_profile")
	assert_true(nova_data != null, "nova.tres debe existir")

	SaveManager.lock_all_skins()
	SaveManager.equip_skin("pilot:valentina", "base")
	SaveManager.equip_skin("wings:valentina", "follow_pilot")
	SaveManager.equip_skin("weapon:valentina", "follow_pilot")

	# 1. Montaje, compensación de escala e invariantes
	var val_player: Player = _spawn_test_player(val_data, bserver, arena)
	cosmos_env.set_player_reference(val_player)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(val_player.has_rig_v2(), "Valentina debe montar PlayerRigV2Controller en Player")
	var v2_ctrl: PlayerRigV2ControllerScript = val_player.get_rig_v2_controller()
	var rig: PlanarCombatRig = v2_ctrl.get_rig()
	var ring: OrbitalWeaponRingController = v2_ctrl.get_ring_controller()
	var sandevistan: SandevistanTrailController = v2_ctrl.get_sandevistan_controller()
	var ab_layer: CanvasLayer = v2_ctrl.get_aberration_layer()
	var ab_rect: ColorRect = v2_ctrl.get_aberration_rect()

	assert_true(rig != null and ring != null and sandevistan != null, "Rig, OrbitalRing y Sandevistan deben estar instanciados")
	assert_true((val_player.get_node("VisualPlaceholder") as CanvasItem).visible == false, "VisualPlaceholder debe quedar oculto")
	assert_true(val_player.get_node_or_null("ShipSprite") == null, "ShipSprite legacy no debe instanciarse para Valentina v2")
	assert_true((val_player.get_node("WeaponController/WeaponVisual") as CanvasItem).visible == false, "WeaponVisual legacy debe quedar oculto")
	assert_true(val_player.scale.is_equal_approx(Vector2(1.2, 1.2)), "Player.scale debe mantenerse en 1.2")
	assert_true(v2_ctrl.global_scale.is_equal_approx(Vector2(0.90, 0.90)), "PlayerRigV2Controller.global_scale debe compensar a 0.90 exacto")
	assert_true(val_player.hitbox_core.z_index == 25, "HitboxCore.z_index debe mantenerse en 25")
	assert_true(sandevistan.top_level == true and sandevistan.z_as_relative == false and sandevistan.z_index == 2, "SandevistanTrailController debe correr top_level en z_index absoluto 2")
	assert_true(ab_layer != null and ab_layer.layer < 5, "OverfocusAberrationLayer debe estar debajo de GameHUD (layer < 5)")
	_assert_zero_z_recursive(rig.get_unified_canvas_group(), "PlayerValentinaRig")

	# 2. Puente de iluminación cósmica
	assert_true(rig.get_last_cosmic_lighting() != null, "PlanarCombatRig debe recibir muestra CosmicLightingSample desde CosmosCombatEnvironment")

	# 3. Twin-Stick Kiting 360° y Set Cinematic Duel Facing
	var enemy_west := MockEnemy.new()
	enemy_west.global_position = val_player.global_position + Vector2(-260.0, 0.0)
	arena.add_child(enemy_west)

	val_player.velocity = Vector2(300.0, 0.0)
	for _i: int in range(8):
		await get_tree().process_frame
	assert_true(rig.is_backpedaling(), "Movimiento Este + blanco Oeste debe activar backpedaling en PlanarCombatRig")
	assert_true(rig.get_active_view_key() == "w", "Valentina debe mirar al blanco Oeste mientras se desplaza al Este (actual=%s)" % rig.get_active_view_key())

	val_player.set_cinematic_duel_facing()
	await get_tree().process_frame
	assert_true(rig.get_active_view_key() == "e", "set_cinematic_duel_facing debe forzar vista Este ('e')")
	val_player.resume_movement_control()

	# 4. Repliegue Táctico / Sobre-Enfoque (Dash + Bullet-Time 0.55x + Sandevistan + Ojo/Monóculo + Aberración)
	val_player.global_position = Vector2(960.0, 540.0)
	val_player.velocity = Vector2.ZERO
	val_player._execute_character_dash()
	assert_true(val_player.is_focus_active, "Dash de Valentina debe activar Sobre-Enfoque")
	assert_true(is_equal_approx(Engine.time_scale, 0.55), "Sobre-Enfoque debe aplicar time_scale 0.55")
	assert_true(rig.get_3d_wings_controller().get_anim_state() == AstralWings3DCtrlScript.AnimState.SERAPH_BLOOM, "Sobre-Enfoque debe activar alas en SERAPH_BLOOM")
	assert_true(rig.get_face_overfocus_boost() > 0.5, "Sobre-Enfoque debe elevar brillo de ojo/monóculo")
	assert_true(ab_rect.visible, "Pulso de aberración cromática debe activarse al iniciar Sobre-Enfoque")

	for _f: int in range(8):
		await get_tree().physics_frame
		await get_tree().process_frame
	assert_true(sandevistan.get_active_ghost_count() >= 1, "Sandevistan debe generar fantasmas usando unscaled_delta durante el Sobre-Enfoque")

	val_player.dash_controller.is_dashing = false
	val_player.dash_controller.focus_timer = 0.01
	v2_ctrl._aberration_timer = 0.01
	var wait_steps: int = 0
	while (val_player.is_focus_active or ab_rect.visible) and wait_steps < 60:
		await get_tree().physics_frame
		await get_tree().process_frame
		wait_steps += 1
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(not val_player.is_focus_active, "Sobre-Enfoque debe finalizar tras expirar timer")
	assert_true(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale debe restaurarse a 1.0")
	assert_true(is_equal_approx(rig.get_face_overfocus_boost(), 0.0), "Brillo de ojo/monóculo debe limpiarse al salir de Sobre-Enfoque")
	assert_true(not ab_rect.visible, "Aberración cromática debe ocultarse al decaer")

	sandevistan.clear_all_ghosts()
	val_player.velocity = Vector2(280.0, 0.0)
	for _f3: int in range(6):
		await get_tree().process_frame
	assert_true(sandevistan.get_active_ghost_count() == 0, "En vuelo normal fuera de Sobre-Enfoque, Sandevistan NO debe generar fantasmas")
	val_player.velocity = Vector2.ZERO

	# 5. Anillo Orbital Multi-Arma (1 -> 4 slots), paletas WeaponData + Regla Híbrida + Puntería independiente + Bocas 3D
	var all_weapon_paths: Array[String] = [
		"res://data/weapons/roster/sniper_rifle.tres",
		"res://data/weapons/roster/rail_launcher.tres",
		"res://data/weapons/roster/hive_cannon.tres",
		"res://data/weapons/roster/singularity_pulsar.tres",
		"res://data/weapons/roster/titan_shotgun.tres",
		"res://data/weapons/roster/tesla_arc.tres",
		"res://data/weapons/roster/crescent_blade.tres",
		"res://data/weapons/roster/plasma_flak.tres",
		"res://data/weapons/roster/scatter_laser.tres",
		"res://data/weapons/roster/singularity_cannon.tres",
		"res://data/weapons/roster/solar_flare.tres",
		"res://data/weapons/roster/swarm_missiles.tres",
		"res://data/weapons/roster/tachyon_beam.tres",
		"res://data/weapons/roster/void_siphon.tres",
		"res://data/weapons/shop/cluster_submunition.tres",
		"res://data/weapons/shop/dimensional_blade.tres",
		"res://data/weapons/shop/nova_flak.tres",
		"res://data/weapons/shop/solar_beam.tres",
	]
	for w_path: String in all_weapon_paths:
		var wd: WeaponData = ResourceLoader.load(w_path) as WeaponData
		assert_true(wd != null and wd.orbital_mesh_id == &"rail_lance", "WeaponData debe cargar con orbital_mesh_id='rail_lance': %s" % w_path)

	var w_ctrl: WeaponController = val_player.get_node("WeaponController") as WeaponController
	var w0: WeaponData = ResourceLoader.load("res://data/weapons/roster/sniper_rifle.tres") as WeaponData
	var w1: WeaponData = ResourceLoader.load("res://data/weapons/roster/rail_launcher.tres") as WeaponData
	var w2: WeaponData = ResourceLoader.load("res://data/weapons/roster/singularity_pulsar.tres") as WeaponData
	var w3: WeaponData = ResourceLoader.load("res://data/weapons/roster/tesla_arc.tres") as WeaponData

	assert_true(ring.get_slot_count() == 1, "Valentina debe iniciar con 1 slot en el anillo")
	assert_true(ring.get_slot_accent_color(0).is_equal_approx(w0.orbital_crystal_color), "Con skin base, Slot 0 debe usar paleta de sniper_rifle")

	assert_true(w_ctrl.add_weapon(w1), "Debe agregar arma en Slot 1")
	assert_true(ring.get_slot_count() == 2, "Anillo debe crecer a 2 slots")
	assert_true(w_ctrl.add_weapon(w2), "Debe agregar arma en Slot 2")
	assert_true(ring.get_slot_count() == 3, "Anillo debe crecer a 3 slots")
	assert_true(w_ctrl.add_weapon(w3), "Debe agregar arma en Slot 3")
	assert_true(ring.get_slot_count() == 4, "Anillo debe crecer a 4 slots")

	# Regla Híbrida: Slot 0 con skin cosmética vs Slots 1..3 con paleta WeaponData
	SaveManager.unlock_or_upgrade_skin("weapon_valentina_solar_valkyrie")
	SaveManager.equip_skin("weapon:valentina", "weapon_valentina_solar_valkyrie")
	v2_ctrl.refresh_equipped_skins()
	await get_tree().process_frame

	var solar_preset: PilotSkinPreset = CosmeticsManager.resolve_pilot_skin_preset(&"valentina", "weapon")
	var slot0_acc: Color = ring.get_slot_accent_color(0)
	assert_true(Color(slot0_acc.r, slot0_acc.g, slot0_acc.b, 1.0).is_equal_approx(Color(solar_preset.accent_color.r, solar_preset.accent_color.g, solar_preset.accent_color.b, 1.0)), "Slot 0 con skin cosmética debe usar RGB accent_color de solar_valkyrie")
	assert_true(ring.get_slot_3d_renderer(0).get_surface_base_color(2).is_equal_approx(solar_preset.accent_color), "Renderer 3D Slot 0 debe usar solar_valkyrie")
	assert_true(ring.get_slot_accent_color(1).is_equal_approx(w1.orbital_crystal_color), "Slot 1 debe conservar paleta propia WeaponData (rail_launcher)")
	assert_true(ring.get_slot_accent_color(2).is_equal_approx(w2.orbital_crystal_color), "Slot 2 debe conservar paleta propia WeaponData (singularity_pulsar)")
	assert_true(ring.get_slot_accent_color(3).is_equal_approx(w3.orbital_crystal_color), "Slot 3 debe conservar paleta propia WeaponData (tesla_arc)")

	# Puntería independiente sobre 2 enemigos opuestos en auto-aim
	var enemy_east := MockEnemy.new()
	enemy_east.global_position = val_player.global_position + Vector2(320.0, 0.0)
	arena.add_child(enemy_east)

	w_ctrl.is_manual_aim = false
	for _a: int in range(3):
		await get_tree().process_frame
	assert_true(ring.get_slot_aim_dir(0).x < -0.5, "Slot 0 en auto-aim debe apuntar al enemigo más cercano al Oeste")
	assert_true(ring.get_slot_aim_dir(1).x > 0.5, "Slot 1 en auto-aim debe repartirse hacia el enemigo Este")

	w_ctrl.is_manual_aim = true
	await get_tree().process_frame
	assert_true(w_ctrl.get_slot_aim_world_pos(0).is_equal_approx(w_ctrl.get_slot_aim_world_pos(1)), "En manual aim todos los slots deben converger al cursor")
	w_ctrl.is_manual_aim = false

	# Nacimiento desde bocas 3D + disparo activo y pasivo
	var muzzle0: Vector2 = val_player.get_weapon_muzzle_world_pos(0)
	assert_true(muzzle0.distance_to(val_player.global_position) > 10.0, "Boca 3D proyectada debe estar desplazada del centro del jugador")
	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var child_count_before: int = spawn_parent.get_child_count()
	w_ctrl._dispatch_weapon_active_fire(w_ctrl.equipped_weapons[0], Vector2.LEFT, false, 0.0)
	var slot0_st: Dictionary = ring.get_slot_state(0)
	assert_true(float(slot0_st["recoil"]) > 0.5 and float(slot0_st["fire_flash"]) > 0.5, "Disparo activo debe accionar recoil y muzzle flash en Slot 0")
	assert_true(spawn_parent.get_child_count() > child_count_before, "Disparo activo debe instanciar proyectil desde boca 3D")

	w_ctrl._dispatch_weapon_passive_fire(w_ctrl.equipped_weapons[1])
	var slot1_st: Dictionary = ring.get_slot_state(1)
	assert_true(float(slot1_st["recoil"]) > 0.5 and float(slot1_st["fire_flash"]) > 0.5, "Disparo pasivo debe accionar recoil y muzzle flash en Slot 1")

	# 6. Reacciones de combate (Daño, Escudo, OSP, Bomba, Muerte)
	val_player.is_invulnerable = false
	val_player.take_damage(12.0)
	await get_tree().process_frame
	assert_true(rig.get_hit_flash() > 0.0 and rig.is_hit_stop_active(), "Daño normal debe disparar hit_flash e impact_frame")
	await get_tree().create_timer(0.12, true, false, true).timeout

	val_player.set_meta("phase_inverter_shield", true)
	val_player.take_damage(20.0)
	assert_true(rig.get_3d_wings_controller().get_anim_state() == AstralWings3DCtrlScript.AnimState.AEGIS_GUARD, "Absorción de escudo debe activar alas en AEGIS_GUARD")

	val_player.current_health = val_player.stats.get_stat(&"max_health")
	val_player.is_invulnerable = false
	val_player.take_damage(9999.0)
	assert_true(val_player.current_health >= 1.0, "OSP debe proteger ante daño letal desde vida llena")
	assert_true(rig.get_3d_wings_controller().get_anim_state() == AstralWings3DCtrlScript.AnimState.AEGIS_GUARD, "OSP debe activar reacción AEGIS_GUARD")

	val_player.bomb_count = 2
	val_player._execute_bomb()
	assert_true(rig.get_3d_wings_controller().get_anim_state() == AstralWings3DCtrlScript.AnimState.SERAPH_BLOOM, "Bomba táctica debe activar alas en SERAPH_BLOOM")

	val_player.is_invulnerable = false
	val_player.current_health = 5.0
	var lethal_ctx := HitContext.create_direct_hit(500.0, false, 0.0)
	lethal_ctx.bypass_osp = true
	val_player.take_damage(lethal_ctx)
	assert_true(val_player.is_dead, "Daño letal con bypass_osp debe matar al jugador")
	assert_true(not v2_ctrl.visible and not ab_rect.visible, "Al morir deben ocultarse rig v2 y aberración")
	assert_true(rig.get_3d_wings_controller()._back_vp.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Al morir deben apagarse los SubViewports 3D de alas")

	# 7. Compatibilidad legacy (Nova) y cero referencias a sandbox/ en producción
	var nova_player: Player = _spawn_test_player(nova_data, bserver, arena)
	await get_tree().process_frame
	assert_true(not nova_player.has_rig_v2(), "Pilotos legacy sin pilot_rig_profile deben mantener has_rig_v2() == false")
	assert_true(nova_player.get_node_or_null("ShipSprite") != null, "Pilotos legacy deben conservar ShipSprite")

	var prod_scripts: Array[String] = [
		"res://data/pilots/schemas/pilot_combat_rig_config.gd",
		"res://data/weapons/weapon_data.gd",
		"res://scenes/combat/player/player_rig_v2_controller.gd",
		"res://scenes/combat/player/player.gd",
		"res://scenes/combat/player/player_visual_builder.gd",
		"res://scenes/combat/player/weapon_controller.gd",
	]
	for spath: String in prod_scripts:
		var txt: String = FileAccess.get_file_as_string(spath)
		assert_true(not txt.contains("sandbox/"), "Producción no debe referenciar sandbox/: %s" % spath)

	_restore_profile_file()
	pass_suite("Fase 5 verificada: Valentina v2 en combate (Twin-Stick, Cosmos, Sobre-Enfoque, Reacciones, Anillo Orbital 1-4 slots y compatibilidad legacy).")
