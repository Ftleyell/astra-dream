extends BaseTestSuite
## Suite de verificación para el laboratorio aislado de Armamento Orbital 2.5D (ValentinaGunsLab).

const GUNS_LAB_SCENE_PATH: String = "res://sandbox/pilot_rig_lab/guns_lab/valentina_guns_lab.tscn"
const RingCtrlScript = preload("res://sandbox/pilot_rig_lab/guns_lab/orbital_weapon_ring_controller.gd")
const ConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_orbital_weapon_config.gd")


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

	lab.queue_free()
	await get_tree().process_frame
	pass_suite("ValentinaGunsLab + Anillo Orbital 2.5D verificados")
