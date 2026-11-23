class_name TestInterstellarCorridors
extends BaseTestSuite

## Suite unitaria para Cosmos Engine v3.2c: Corredores Interestelares & Ríos Laminares.
## Valida topología simétrica de rutas hiperespaciales, frentes bow-shock solares,
## micro-convoyes, micro-meteoros, alineación de cometas errantes, reversibilidad t=0->50000->0,
## guías [O] y ríos laminares en CosmosDebrisLayoutGenerator.

const COSMOS_ROOT_SCENE: PackedScene = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.tscn")


func _ready() -> void:
	super._ready()
	_test_corridors_topology_reversibility_and_alignment()
	_test_laminar_debris_river_bounds()
	pass_suite("TestInterstellarCorridors completado (rutas, convoyes, meteoros, cometas, bow-shocks y ríos).")


func _test_corridors_topology_reversibility_and_alignment() -> void:
	var root := COSMOS_ROOT_SCENE.instantiate() as CosmosRootNode
	assert_true(root != null, "Debe instanciar cosmos_root.tscn.")
	assert_true(root.corridor_controller != null, "CosmosRootNode debe referenciar corridor_controller.")

	var cam := Camera2D.new()
	cam.name = "CorridorTestCam"
	cam.zoom = Vector2(0.45, 0.45)
	add_child(cam)
	root.camera = cam
	add_child(root)
	root.is_frozen = true
	root.bind_camera_to_streamers()

	var corr: CosmosInterstellarCorridorController2D = root.corridor_controller
	corr.set_camera_override(Vector2.ZERO, Vector2(0.45, 0.45))
	corr.update_corridors(0.0)

	assert_true(corr.get_active_lane_count() >= 1, "Debe generar al menos 1 ruta hiperespacial cerca del origen.")
	assert_true(corr.get_active_bow_shock_count() >= 1, "Debe generar al menos 1 arco bow-shock entre estrellas cercanas.")
	assert_true(not corr._convoys.is_empty(), "Debe poblar micro-convoyes sobre las rutas activas.")
	assert_true(not corr._meteors.is_empty(), "Debe poblar lluvia analítica de micro-meteoros.")
	assert_true(corr._particle_mm.visible_instance_count == corr._total_active_particles, "MultiMesh debe exponer todos los particles activos.")
	assert_true(corr._particle_mm.custom_aabb.size.x > 0.0, "MultiMesh debe configurar custom_aabb positivo contra culling 2D.")
	assert_true(corr._slipstream_drawer != null, "Debe instanciar el hilo visual aditivo _slipstream_drawer.")

	# Verificar toggle de guías [O] y niveles de calidad 0..2
	corr.set_orbit_guides_visible(true)
	assert_true(corr._guides_drawer.visible, "_guides_drawer debe activarse con set_orbit_guides_visible(true).")
	corr.set_orbit_guides_visible(false)
	for q: int in range(3):
		corr.apply_graphics_quality(q)
	corr.update_biome_harmony(Color(0.28, 0.06, 0.52, 1.0), Color(0.03, 0.38, 0.62, 1.0))

	# Snapshot t = 0.0 usando caché CPU (RenderingServerDummy retorna IDENTITY en headless)
	corr.update_corridors(0.0)
	var c_count: int = corr._convoys.size()
	var convoy_t0: Array[Vector2] = []
	for i: int in range(c_count):
		convoy_t0.append(corr.get_convoy_world_position(i))

	var comet_pos_t0: Array[Vector2] = []
	var comet_rot_t0: Array[float] = []
	for k: int in range(corr.get_active_interstellar_comet_count()):
		var cspr: Sprite2D = corr._comet_sprites[k]
		comet_pos_t0.append(cspr.position)
		comet_rot_t0.append(cspr.rotation)
		var cm: Dictionary = corr._active_comets_meta[k]
		var u: float = fposmod(float(cm["u0"]), 1.0)
		var vel: Vector2 = corr._eval_bezier_tangent(cm["p0"] as Vector2, cm["p1"] as Vector2, cm["p2"] as Vector2, u)
		if vel.length_squared() > 0.001:
			var ang_err: float = absf(wrapf(cspr.rotation - (-vel).angle(), -PI, PI))
			assert_true(ang_err < 0.02, "Cometa interestelar %d debe alinearse con -vel (err=%.4f)." % [k, ang_err])

	# Avanzar hasta t = 50000.0 y confirmar movimiento real
	corr.update_corridors(50000.0)
	var moved_convoy: bool = false
	for i: int in range(c_count):
		var pos_far: Vector2 = corr.get_convoy_world_position(i)
		if pos_far.distance_to(convoy_t0[i]) > 1.0:
			moved_convoy = true
			break
	assert_true(moved_convoy, "Los micro-convoyes deben avanzar sobre la ruta al incrementar global_time.")

	# Regresar exactamente a t = 0.0 (reversibilidad analítica sin deriva)
	corr.update_corridors(0.0)
	for i: int in range(c_count):
		var pos_back: Vector2 = corr.get_convoy_world_position(i)
		var err: float = pos_back.distance_to(convoy_t0[i])
		assert_true(err < 0.1, "Convoy %d debe volver exactamente a t=0 (err=%.4f)." % [i, err])

	for k: int in range(corr.get_active_interstellar_comet_count()):
		var cspr: Sprite2D = corr._comet_sprites[k]
		var pos_err: float = cspr.position.distance_to(comet_pos_t0[k])
		var rot_err: float = absf(wrapf(cspr.rotation - comet_rot_t0[k], -PI, PI))
		assert_true(pos_err < 0.1, "Cometa interestelar %d debe regresar a pos t=0 (err=%.4f)." % [k, pos_err])
		assert_true(rot_err < 0.001, "Cometa interestelar %d debe mantener rot t=0 (err=%.5f)." % [k, rot_err])


func _test_laminar_debris_river_bounds() -> void:
	var grid := CosmosMacroGrid.new(11200.0, 428175)
	var micro: Array[Dictionary] = [{"uv_rect": Rect2(0, 0, 0.25, 0.25), "pixel_size": Vector2(120, 120)}]
	var items: Array[CosmosDebrisLayoutGenerator.DebrisInstanceData] = CosmosDebrisLayoutGenerator.generate_cell_layout(
		Vector2i(1, -2), 11200.0, 120, 428175, false, null, grid, micro, micro, micro, true, Vector2.ZERO, 3600.0
	)
	assert_true(items.size() == 120, "El generador laminar debe producir exactamente el conteo pedido.")
	var half_c: float = 11200.0 * 0.5 + 1.0
	for d: CosmosDebrisLayoutGenerator.DebrisInstanceData in items:
		assert_true(absf(d.position.x) <= half_c and absf(d.position.y) <= half_c, "Ríos laminares no deben exceder límites de celda (%s)." % str(d.position))
