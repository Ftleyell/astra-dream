extends BaseTestSuite
## Suite de verificación para el laboratorio aislado de Armamento Orbital 2.5D (ValentinaGunsLab).

const GUNS_LAB_SCENE_PATH: String = "res://sandbox/pilot_rig_lab/guns_lab/valentina_guns_lab.tscn"
const RingCtrlScript = preload("res://scenes/pilots/weapons/orbital_weapon_ring_controller.gd")
const ConfigScript = preload("res://data/pilots/schemas/pilot_orbital_weapon_config.gd")
const SkinPresetScript = preload("res://data/pilots/schemas/pilot_skin_preset.gd")


func _ready() -> void:
	timeout_seconds = 10.0
	super._ready()
	_run_tests()


func _run_tests() -> void:
	var packed: PackedScene = load(GUNS_LAB_SCENE_PATH) as PackedScene
	assert_true(packed != null, "Debe cargar valentina_guns_lab.tscn")

	var lab: Node2D = packed.instantiate() as Node2D
	assert_true(lab != null, "Debe instanciar ValentinaGunsLab")
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame

	var rig: PlanarCombatRig = lab.call("get_rig") as PlanarCombatRig
	var ctrl: RingCtrlScript = lab.call("get_ring_controller") as RingCtrlScript
	var cfg: ConfigScript = lab.call("get_config") as ConfigScript

	assert_true(rig != null, "ValentinaGunsLab debe instanciar PlanarCombatRig")
	assert_true(ctrl != null, "ValentinaGunsLab debe instanciar OrbitalWeaponRingController")
	assert_true(cfg != null, "ValentinaGunsLab debe cargar PilotOrbitalWeaponConfig (.tres)")
	assert_true(ctrl.get_slot_count() == 1, "Por defecto debe iniciar con 1 arma base")
	assert_true(ctrl.is_weapon_3d_enabled(), "Por defecto debe iniciar con el Rail-Lance 3D Cel-Shaded")
	assert_true(ctrl.has_ring_texture(), "Por defecto debe cargar la textura IA empaquetada del anillo")
	assert_true(ctrl.get_active_skin_id() == "base", "La skin inicial debe ser base")

	# Verificar que el winding del ArrayMesh 3D coincide exactamente con BoxMesh (Godot cull_back)
	var box_arr: Array = BoxMesh.new().get_mesh_arrays()
	var b_verts: PackedVector3Array = box_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var b_norms: PackedVector3Array = box_arr[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var b_idx: PackedInt32Array = box_arr[Mesh.ARRAY_INDEX] as PackedInt32Array
	var ba: Vector3 = b_verts[b_idx[0]]
	var bb: Vector3 = b_verts[b_idx[1]]
	var bc: Vector3 = b_verts[b_idx[2]]
	var box_cross_cb: Vector3 = (bc - ba).cross(bb - ba).normalized()
	assert_true(box_cross_cb.dot(b_norms[b_idx[0]]) > 0.9, "Winding (c-a)x(b-a) debe coincidir con normal saliente de BoxMesh")

	# Detener _process para validación determinista
	lab.set_process(false)
	ctrl.set_orbit_paused(true)
	ctrl.set_orbit_mode(RingCtrlScript.OrbitMode.AUTO_RADIAL)

	# 1. Frente del anillo (theta = PI/2): debe quedar DELANTE de Valentina y con barrel_z positivo
	ctrl.set_orbit_angle_manual(PI * 0.5)
	var st_front: Dictionary = ctrl.get_slot_state(0)
	assert_true(int(st_front["z_index"]) > rig.z_index, "En frente del anillo el arma debe estar delante del rig (z=%d > %d)" % [int(st_front["z_index"]), rig.z_index])
	assert_true(float(st_front["depth"]) > 0.9, "En theta=PI/2 depth debe ser cercano a +1.0")
	assert_true(float(st_front["barrel_z"]) > 0.3, "En frente radial barrel_z debe ser positivo")

	# 2. Atrás del anillo (theta = 3*PI/2): debe quedar DETRÁS de Valentina y con barrel_z negativo
	ctrl.set_orbit_angle_manual(PI * 1.5)
	var st_back: Dictionary = ctrl.get_slot_state(0)
	assert_true(int(st_back["z_index"]) < rig.z_index, "Atrás del anillo el arma debe estar detrás del rig (z=%d < %d)" % [int(st_back["z_index"]), rig.z_index])
	assert_true(float(st_back["depth"]) < -0.9, "En theta=3*PI/2 depth debe ser cercano a -1.0")
	assert_true(float(st_back["barrel_z"]) < -0.3, "Atrás radial barrel_z debe ser negativo")

	# 3. Disparo, recoil y decaimiento
	ctrl.trigger_fire(0)
	var st_fire: Dictionary = ctrl.get_slot_state(0)
	assert_true(float(st_fire["recoil"]) > 0.9, "trigger_fire debe activar recoil")
	assert_true(float(st_fire["fire_flash"]) > 0.9, "trigger_fire debe activar fire_flash")
	ctrl.step(0.18)
	var st_after: Dictionary = ctrl.get_slot_state(0)
	assert_true(float(st_after["recoil"]) < 0.5, "recoil debe recuperarse suavemente con el tiempo")

	# 4. Escalado a 4 slots simultáneos en el anillo
	ctrl.set_weapon_count(4)
	assert_true(ctrl.get_slot_count() == 4, "Debe permitir hasta 4 armas simultáneas en el anillo")

	# 5. Sincronización de skin en anillo y arma 3D + cambio a 2.5D multi-mapa + fallback legacy
	var test_skin := SkinPresetScript.new()
	test_skin.id = "cyber_emerald"
	test_skin.is_base_skin = false
	test_skin.accent_color = Color(0.0, 0.96, 0.58, 1.0)
	ctrl.apply_skin_preset(test_skin)
	assert_true(ctrl.get_active_skin_id() == "cyber_emerald", "apply_skin_preset debe actualizar la skin del anillo y arma")

	lab.call("_load_weapon_index", 1)
	assert_true(not ctrl.is_weapon_3d_enabled(), "El índice 1 debe cambiar al Rail-Lance 2.5D")
	assert_true(ctrl.get_has_multi_maps(), "El índice 1 debe cargar el Rail-Lance 2.5D en formato multi-mapa")

	var fallback_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var fallback_tex := ImageTexture.create_from_image(fallback_img)
	ctrl.set_weapon_texture(fallback_tex)
	assert_true(not ctrl.get_has_multi_maps(), "set_weapon_texture legacy debe desactivar multi-mapa limpiamente")

	lab.queue_free()
	await get_tree().process_frame
	pass_suite("ValentinaGunsLab + Anillo Orbital 2.5D verificados")
