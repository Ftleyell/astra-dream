extends BaseTestSuite

## Suite integral headless para Fase 3 — Estación Astral Completa + Alas Temáticas.
## Verifica:
## 1. Mallas ArcSys 3D (3 superficies + winding horario Godot 4) de Ala Este y Ala Oeste.
## 2. Las 5 zonas ensambladas en hub_art_lab.tscn (Cápsula, 4 Consolas, Anillo Norte, Ala Este, Ala Oeste).
## 3. Progresión CALIBRATING / NEWLY_UNLOCKED / ONLINE con presets sin mutar SaveManager.
## 4. Transición limpia por los 7 modos de cámara de HubLabCameraRig.
## 5. Espejo de Skins (SKINS_MIRROR_FOCUS) encendiendo/apagando Alas 3D + Anillo Orbital 3D en HubRigAvatar3D.
## 6. Escalado visual de las 5 Reliquias del Ala Oeste por maestría (0..3+) y apertura de TrophyDetailsModal.
## 7. Sincronía Consola Táctica (tactical_seed CUSTOM) <-> Ventanal Cosmos + Ritual de Ignición completo.

const LAB_SCENE_PATH: String = "res://sandbox/hub_art_lab/hub_art_lab.tscn"
const HubArtLabScript = preload("res://sandbox/hub_art_lab/hub_art_lab.gd")
const CameraRigScript = preload("res://sandbox/hub_art_lab/components/hub_lab_camera_rig.gd")
const StationNodeScript = preload("res://sandbox/hub_art_lab/components/hub_lab_station_node.gd")
const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")

var _ritual_completed_seen: bool = false
var _ritual_completed_seed: int = 0


func _ready() -> void:
	timeout_seconds = 14.0
	super._ready()
	await _run_tests()


func _run_tests() -> void:
	await _test_full_astral_station_integration()
	pass_suite("Fase 3 Estación Astral Completa verificada: 5 zonas, 7 cámaras, Espejo 3D, Ala Este/Oeste, RunLaunchRequest e Ignición.")


func _test_full_astral_station_integration() -> void:
	var tokens_before: int = SaveManagerScript.get_gacha_tokens()
	var speed_before: float = SaveManagerScript.get_game_speed()
	var char_before: StringName = SaveManagerScript.get_selected_character()

	var packed: PackedScene = load(LAB_SCENE_PATH) as PackedScene
	assert_true(packed != null, "Debe cargar hub_art_lab.tscn")
	var lab: HubArtLabScript = packed.instantiate() as HubArtLabScript
	assert_true(lab != null, "Debe instanciar HubArtLab")
	add_child(lab)
	await get_tree().process_frame

	# 1. Presencia de las 5 zonas, HD 1024, HUD Dev oculto y colisiones completas
	assert_true(lab.east_wing != null and lab.east_wing.summoner != null, "Ala Este debe montar HubGachaSummoner3D")
	assert_true(lab.east_wing.gacha_overlay != null and lab.east_wing.gacha_overlay.is_station_clean_mode(), "Gacha en Estación debe iniciar en modo limpio sin controles de sandbox")
	assert_true(lab.east_wing.get_telemetry_totem_node() != null, "Ala Este debe montar Tótem de Telemetría")
	assert_true(lab.east_wing.get_lounge_pad_count() == 3, "Ala Este debe montar 3 pads antigravedad de Lounge")
	assert_true(lab.west_sanctuary != null and lab.west_sanctuary.get_relic_count() == 5, "Ala Oeste debe montar las 5 Reliquias Cristalinas")
	assert_true(lab.modal_coordinator != null and lab.ignition_controller != null, "Debe montar ModalCoordinator e IgnitionRitualController")
	assert_true(lab.hud != null and not lab.hud.is_dev_panel_visible(), "Panel Dev debe iniciar oculto por defecto")
	assert_true(lab.player.rig_avatar.get_subviewport().size.x >= 1024, "HubRigAvatar3D en Estación debe correr en HD >= 1024px")
	assert_true(lab.get_node_or_null("CentralPilotCapsule/CapsuleRearArchCollider") != null, "Cápsula Central debe tener colisión trasera")
	assert_true(lab.get_node_or_null("StationArchitecture/NWCornerCollider") != null and lab.get_node_or_null("StationArchitecture/NECornerCollider") != null, "Esquinas NO/NE deben tener colisión")

	# 2. Simulador de progresión en Antesala
	lab.apply_progression_preset(&"run1")
	assert_true(lab.left_station.get_station_state() == StationNodeScript.StationState.CALIBRATING, "Run 1: Espejo de Skins en CALIBRATING")
	assert_true(lab.right_far_station.get_station_state() == StationNodeScript.StationState.CALIBRATING, "Run 1: Consola Táctica en CALIBRATING")
	lab.open_station_by_id(&"skins_mirror")
	assert_true(not lab.modal_coordinator.is_any_modal_open(), "Consola en CALIBRATING no debe abrir modal")

	lab.apply_progression_preset(&"post_run1")
	assert_true(lab.left_station.get_station_state() == StationNodeScript.StationState.NEWLY_UNLOCKED, "PostRun1: Espejo de Skins debe pasar a NEWLY_UNLOCKED")
	assert_true(lab.right_far_station.get_station_state() == StationNodeScript.StationState.NEWLY_UNLOCKED, "PostRun1: Consola Táctica debe pasar a NEWLY_UNLOCKED")

	lab.apply_progression_preset(&"all_online")
	assert_true(lab.left_station.get_station_state() == StationNodeScript.StationState.ONLINE, "AllOnline: Espejo de Skins debe pasar a ONLINE")
	assert_true(lab.right_far_station.get_station_state() == StationNodeScript.StationState.ONLINE, "AllOnline: Consola Táctica debe pasar a ONLINE")

	# 3. 7 modos de cámara en HubLabCameraRig
	for mode_val: int in [
		CameraRigScript.Mode.CAPSULE_PILOT_FOCUS,
		CameraRigScript.Mode.SKINS_MIRROR_FOCUS,
		CameraRigScript.Mode.STATION_FOCUS,
		CameraRigScript.Mode.GACHA_SUMMON_CINEMATIC,
		CameraRigScript.Mode.TROPHY_FOCUS,
		CameraRigScript.Mode.FREE_ROAM,
	]:
		lab._on_hud_camera_mode_requested(mode_val)
		assert_true(int(lab.camera_rig.get_mode()) == mode_val, "HubLabCameraRig debe cambiar al modo %d" % mode_val)

	# 4. Espejo de Skins -> activa Alas 3D + Anillo Orbital 3D y al cerrar los apaga
	lab.open_station_by_id(&"skins_mirror")
	assert_true(int(lab.camera_rig.get_mode()) == CameraRigScript.Mode.SKINS_MIRROR_FOCUS, "Abrir skins_mirror debe activar SKINS_MIRROR_FOCUS")
	assert_true(lab.player.rig_avatar.is_3d_wings_showcase_enabled(), "Espejo de Skins debe encender Alas 3D")
	assert_true(lab.player.rig_avatar.is_orbital_weapon_showcase_enabled(), "Espejo de Skins debe encender Anillo Orbital 3D")
	lab.modal_coordinator.close_active_modal()
	assert_true(not lab.player.rig_avatar.is_3d_wings_showcase_enabled(), "Al cerrar Espejo de Skins debe apagar Alas 3D")
	assert_true(not lab.player.rig_avatar.is_orbital_weapon_showcase_enabled(), "Al cerrar Espejo de Skins debe apagar Anillo Orbital 3D")

	# 4b. Proyector de Compañía abre y cierra limpiamente
	lab.open_station_by_id(&"companions_projector")
	assert_true(lab.modal_coordinator.is_any_modal_open(), "Proyector de Compañía ONLINE debe abrir su panel")
	lab.modal_coordinator.close_active_modal()
	assert_true(not lab.modal_coordinator.is_any_modal_open() and not lab.player.is_movement_locked, "Cerrar Proyector debe liberar movimiento")

	# 5. Ala Oeste: escalado visual por maestría 0 -> 1 -> 2 -> 3
	lab.set_west_mastery_override(0)
	var r0: Dictionary = lab.west_sanctuary.get_relic_state(&"trophy_cryo_core")
	assert_true(is_equal_approx(float(r0["calibration_factor"]), 1.0) and not bool(r0["inner_ring_visible"]), "Maestría 0 debe quedar sellada sin anillos")

	lab.set_west_mastery_override(1)
	var r1: Dictionary = lab.west_sanctuary.get_relic_state(&"trophy_cryo_core")
	assert_true(is_equal_approx(float(r1["calibration_factor"]), 0.0) and not bool(r1["inner_ring_visible"]), "Maestría 1 activa emisión sin anillos orbitales")

	lab.set_west_mastery_override(2)
	var r2: Dictionary = lab.west_sanctuary.get_relic_state(&"trophy_cryo_core")
	assert_true(bool(r2["inner_ring_visible"]) and not bool(r2["outer_ring_visible"]), "Maestría 2 debe activar aro orbital interior")

	lab.set_west_mastery_override(3)
	var r3: Dictionary = lab.west_sanctuary.get_relic_state(&"trophy_cryo_core")
	assert_true(bool(r3["inner_ring_visible"]) and bool(r3["outer_ring_visible"]), "Maestría 3 debe activar ambos aros orbitales")

	# 6. Consola Táctica (tactical_seed CUSTOM) <-> Ventanal Cosmos + Ritual de Ignición completo
	lab.open_station_by_id(&"tactical_console")
	var applied_ok: bool = lab.modal_coordinator.apply_custom_seed_code("ASTR-0096D3")
	assert_true(applied_ok, "Debe aplicar coordenada CUSTOM ASTR-0096D3")
	assert_true(lab.active_launch_request.is_custom_seeded(), "active_launch_request debe quedar en modo CUSTOM")
	assert_true(lab.cosmos_window.get_preview_seed() == lab.active_launch_request.cosmos_seed, "Ventanal Norte debe reflejar cosmos_seed de RunLaunchRequest")
	lab.modal_coordinator.close_active_modal()

	_ritual_completed_seen = false
	_ritual_completed_seed = 0
	lab.ignition_controller.ritual_completed.connect(func(req: RunLaunchRequestScript, _launched: bool) -> void:
		_ritual_completed_seen = true
		_ritual_completed_seed = req.cosmos_seed if req != null else 0
	)
	lab.ignition_controller.dry_run_sandbox_launch = true
	lab.trigger_ignition_preview()
	await get_tree().process_frame
	assert_true(lab.ignition_controller.is_ritual_active(), "Ritual de Ignición debe arrancar")
	assert_true(lab.player.rig_avatar.is_3d_wings_showcase_enabled() and lab.player.rig_avatar.is_orbital_weapon_showcase_enabled(), "Ritual de Ignición debe desplegar Alas 3D y Anillo Orbital")
	assert_true(int(lab.camera_rig.get_mode()) == CameraRigScript.Mode.IGNITION_LAUNCH, "Cámara debe pasar a IGNITION_LAUNCH")

	lab._finish_ignition_preview()
	assert_true(_ritual_completed_seen, "Ritual de Ignición debe emitir ritual_completed")
	assert_true(_ritual_completed_seed == lab.active_launch_request.cosmos_seed, "ritual_completed debe transportar el mismo cosmos_seed")
	assert_true(int(lab.camera_rig.get_mode()) == CameraRigScript.Mode.FREE_ROAM, "Tras dry-run de Ignición debe volver a FREE_ROAM")
	assert_true(not lab.player.rig_avatar.is_3d_wings_showcase_enabled(), "Tras Ignición debe apagar Alas 3D showcase")

	# 7. Sin mutaciones no solicitadas en SaveManager
	assert_true(SaveManagerScript.get_gacha_tokens() == tokens_before, "No debe mutar gacha_tokens")
	assert_true(is_equal_approx(SaveManagerScript.get_game_speed(), speed_before), "No debe mutar game_speed")
	assert_true(SaveManagerScript.get_selected_character() == char_before, "No debe mutar selected_character")

	lab.queue_free()
	await get_tree().process_frame
