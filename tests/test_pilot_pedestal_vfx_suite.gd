extends Node

func _ready() -> void:
	print("==========================================")
	print("[TEST] Testing Pilot Pedestal & Selection VFX System...")
	print("==========================================")

	var hub_scene = load("res://scenes/ui/hub/hub_world.tscn")
	var hub = hub_scene.instantiate()
	add_child(hub)

	var timer = get_tree().create_timer(0.3)
	await timer.timeout

	await _run_assertions(hub)

func _run_assertions(hub: Node) -> void:
	# 1. Verificar existencia del grupo de pedestales
	var ped_group = hub.get_node_or_null("PilotPedestals")
	assert(ped_group != null, "PilotPedestals group must exist in HubWorld")
	assert(hub.pilot_vfx_data.size() == 6, "pilot_vfx_data must contain entries for all 6 pilots")

	# 2. Verificar estructura de cada pedestal
	for i in range(hub.pilot_vfx_data.size()):
		var vfx = hub.pilot_vfx_data[i]
		assert(vfx.has("ped_root"), "Debe tener ped_root")
		assert(vfx.has("holo_beam"), "Debe tener holo_beam")
		assert(vfx.has("rim_mat"), "Debe tener rim_mat")
		assert(vfx.has("rotator_ring"), "Debe tener rotator_ring")
		assert(vfx.has("omni_light"), "Debe tener omni_light")
		assert(vfx.has("floating_badge"), "Debe tener floating_badge")

	print("  ✓ Pedestales 3D y componentes de VFX instanciados para las 6 heroínas.")

	# 3. Probar selección del piloto 0 (Nova)
	hub._select_pilot(0, false)
	# Esperar a que la transición de animación (0.25s) complete la retracción de anteriores y elevación de Nova
	await get_tree().create_timer(0.3).timeout

	var vfx0 = hub.pilot_vfx_data[0]
	var vfx3 = hub.pilot_vfx_data[3]

	assert(vfx0["holo_beam"].visible, "Nova holo_beam debe estar visible al seleccionarla")
	assert(vfx0["floating_badge"].visible, "Nova floating_badge debe estar visible al seleccionarla")
	assert(vfx0["omni_light"].visible, "Nova omni_light debe estar visible")
	assert(vfx0["omni_light"].light_energy > 0.0, "Nova omni_light debe tener energía positiva")
	assert(not vfx3["holo_beam"].visible, "Selene holo_beam debe estar apagado tras la transición")
	assert(not vfx3["floating_badge"].visible, "Selene floating_badge debe estar oculto")

	print("  ✓ Piloto Nova seleccionado: Haz holográfico, luz neón y badge activos. Demás heroínas inactivas.")

	# 4. Cambiar a Selene (index 3)
	hub._select_pilot(3, false)
	await get_tree().create_timer(0.3).timeout

	assert(vfx3["holo_beam"].visible, "Selene holo_beam debe activarse al seleccionarla")
	assert(vfx3["floating_badge"].visible, "Selene badge debe activarse al seleccionarla")
	assert(vfx3["omni_light"].visible, "Selene omni_light debe activarse")
	assert(vfx3["omni_light"].light_energy > 0.0, "Selene luz debe encenderse")
	assert(not vfx0["holo_beam"].visible, "Nova holo_beam debe haberse retraído y apagado")
	assert(not vfx0["floating_badge"].visible, "Nova floating_badge debe estar apagado")

	# Simular un frame de proceso
	hub._process(0.016)

	print("  ✓ Transición a Selene: El VFX pasó limpiamente a Selene y Nova volvió a la normalidad.")

	# 5. Cambiar a Valentina (index 1)
	hub._select_pilot(1, false)
	await get_tree().create_timer(0.3).timeout

	var vfx1 = hub.pilot_vfx_data[1]
	assert(vfx1["holo_beam"].visible, "Valentina holo_beam activo")
	assert(vfx1["omni_light"].light_color == hub.PILOT_ROSTER[1]["color"], "Luz de Valentina debe coincidir con su color insignia")
	assert(not vfx3["holo_beam"].visible, "Selene holo_beam debe estar apagado")

	print("  ✓ Transición a Valentina: VFX transferido dinámicamente con su color carmesí.")

	# 6. Probar actualización de prompts interactuables
	assert(hub.interactable_nodes.size() == 6, "Deben registrarse los 6 interactables de las heroínas")
	var inter1 = hub.interactable_nodes[1]
	var inter3 = hub.interactable_nodes[3]
	assert(inter1.label_3d.text.contains("ACTIVA") or inter1.label_3d.text.contains("SELECCIONADA"), "Prompt de heroína seleccionada debe indicar que está activa")
	assert(inter3.label_3d.text.contains("Seleccionar"), "Prompt de heroína inactiva debe invitar a seleccionarla")

	print("  ✓ Prompts 3D de proximidad [E] actualizados dinámicamente.")

	print("\n==========================================")
	print("[PASS] ALL PILOT PEDESTAL VFX TESTS PASSED (100%)!")
	print("==========================================")
	get_tree().quit(0)
