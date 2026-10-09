class_name TestSpaceBiomeSandboxSuite
extends BaseTestSuite

## Test automatizado para verificar el sistema de fondos cósmicos,
## atlas estelar 8K, proyección espacial de biomas y reactividad de chatarra.

const SANDBOX_SCENE: PackedScene = preload("res://sandbox/space_biome_sandbox.tscn")
const CosmicOrbitalSystemScript = preload("res://sandbox/cosmic_orbital_system.gd")
const CosmicViewportArbiterScript = preload("res://sandbox/cosmic_viewport_arbiter.gd")

func _ready() -> void:

	super._ready()
	_run_verification()


func _run_verification() -> void:
	var sandbox: SpaceBiomeSandbox = SANDBOX_SCENE.instantiate() as SpaceBiomeSandbox
	assert_true(sandbox != null, "La escena space_biome_sandbox.tscn debe instanciarse correctamente.")
	add_child(sandbox)

	await get_tree().process_frame
	await get_tree().process_frame

	var sm: SectorManager = sandbox.sector_manager
	assert_true(is_instance_valid(sm), "SectorManager debe ser un nodo válido.")

	# 1. En el origen (0, 0), la influencia del Cementerio Mecánico debe ser 0.0
	var initial_gy_inf: float = sm.get_graveyard_influence()
	assert_true(initial_gy_inf < 0.01, "En el origen (0, 0), la influencia del cementerio debe ser ~0.0 (obtenido: %.3f)" % initial_gy_inf)

	# 2. Verificar que los uniformes espaciales se hayan cargado en el quad
	var quad: ColorRect = sandbox.cosmic_quad
	assert_true(is_instance_valid(quad), "CosmicBackgroundQuad debe ser válido.")
	var mat: ShaderMaterial = quad.material as ShaderMaterial
	assert_true(is_instance_valid(mat), "El material del fondo debe ser ShaderMaterial.")
	var sector_cnt: Variant = mat.get_shader_parameter("sector_count")
	assert_true(sector_cnt == 4, "Debe haber 4 sectores subidos al shader (obtenido: %s)" % str(sector_cnt))

	# 3. Mover la nave simulada al centro del Cementerio Mecánico (-6500, 4200)
	var ship_node: Node2D = sandbox.ship
	assert_true(is_instance_valid(ship_node), "La nave del sandbox debe ser válida.")
	ship_node.global_position = Vector2(-6500.0, 4200.0)

	# Procesar varios frames para que las interpolaciones suaves reaccionen
	for _i in range(15):
		await get_tree().process_frame

	var graveyard_gy_inf: float = sm.get_graveyard_influence()
	assert_true(graveyard_gy_inf >= 0.99, "En el centro del Cementerio Mecánico, la influencia debe ser 1.0 (obtenido: %.3f)" % graveyard_gy_inf)

	# 4. Validar el nuevo sistema de zócalos solares y pooling cósmico
	var pool: CosmicObjectPool = sandbox.cosmic_pool
	var director: Node2D = sandbox.get("cosmic_director") as Node2D
	assert_true(is_instance_valid(pool), "CosmicObjectPool debe existir e instanciarse.")
	assert_true(is_instance_valid(director), "CosmicSocketDirector debe existir e instanciarse.")

	# Forzar actualización inicial de cámara en el origen
	director.call("update_camera_position", Vector2.ZERO)
	await get_tree().process_frame

	assert_true(pool.get_active_count() > 0, "El pool debe tener objetos activos generados por los zócalos solares (obtenido: %d)." % pool.get_active_count())
	var active_sockets: int = director.call("get_active_sockets_count") as int
	assert_true(active_sockets > 0, "Debe haber al menos un zócalo solar activo en el radio de la nave.")

	# 5. Validar presencia de Soles con las nuevas texturas y shader de corona
	var active_items: Array[Dictionary] = pool.get_active_items()
	var found_sun: bool = false
	var sun_has_corona_shader: bool = false
	for item in active_items:
		if item.get("type") == "sun":
			found_sun = true
			var s_sprite: Sprite2D = item.get("sprite") as Sprite2D
			if is_instance_valid(s_sprite) and s_sprite.material is ShaderMaterial:
				sun_has_corona_shader = true
			break

	assert_true(found_sun, "Debe haberse generado al menos un Sol anfitrión en los zócalos solares.")
	assert_true(sun_has_corona_shader, "El Sol debe tener asignado el shader de corona incandescente sun_corona.gdshader.")

	# 6. Validar Cinemática Orbital Viva y Coherencia Lumínica Radial
	var sun_pos := Vector2(5000.0, 5000.0)
	var orbit_r: float = 2400.0
	var period: float = 300.0 # 5 minutos
	var phase: float = 0.0

	var state_t0: Dictionary = CosmicOrbitalSystemScript.evaluate_orbit(sun_pos, orbit_r, period, phase, 0.0, true)
	var state_t150: Dictionary = CosmicOrbitalSystemScript.evaluate_orbit(sun_pos, orbit_r, period, phase, 150.0, true) # Media órbita
	var pos_t0: Vector2 = state_t0["position"]
	var pos_t150: Vector2 = state_t150["position"]
	var l_dir_t0: Vector2 = state_t0["light_direction"]

	assert_true(pos_t0.distance_to(sun_pos) >= 2399.0 and pos_t0.distance_to(sun_pos) <= 2401.0, "La distancia orbital inicial debe ser igual al radio.")
	assert_true(pos_t0.distance_to(pos_t150) >= 4790.0, "En medio periodo (150s), el cuerpo debe encontrarse en el extremo opuesto del diámetro orbital.")

	# El vector de luz debe apuntar exactamente del planeta al sol: (sun_pos - pos_t0).normalized()
	var expected_ldir: Vector2 = (sun_pos - pos_t0).normalized()
	assert_true(l_dir_t0.distance_to(expected_ldir) < 0.001, "El vector de luz L_dir debe coincidir con normalize(P_sun - P_body).")

	# 7. Validar Regla Anti-Duplicado del Árbitro de Viewport (+20% Frustum)
	var arbiter: RefCounted = CosmicViewportArbiterScript.new(sandbox.env_config as SpaceEnvironmentConfig)
	var cam_pos := Vector2(1000.0, 1000.0)
	var vp_size := Vector2(1920.0, 1080.0)

	arbiter.call("reset_frame")
	# Primer galaxia en pantalla -> admitida
	var gal1_allowed: bool = arbiter.call("evaluate_item", "galaxy", 0, cam_pos, cam_pos, vp_size) as bool
	# Segunda galaxia en pantalla -> rechazada por anti-duplicado
	var gal2_allowed: bool = arbiter.call("evaluate_item", "galaxy", 0, cam_pos + Vector2(100.0, 50.0), cam_pos, vp_size) as bool
	assert_true(gal1_allowed, "La primera galaxia dentro del frustum debe ser admitida.")
	assert_true(not gal2_allowed, "La segunda galaxia dentro del frustum debe ser bloqueada por la regla anti-duplicado.")

	# Primer planeta variante 1 en pantalla -> admitido
	var p_var1_a: bool = arbiter.call("evaluate_item", "planet", 1, cam_pos, cam_pos, vp_size) as bool
	# Segundo planeta misma variante 1 en pantalla -> rechazado
	var p_var1_b: bool = arbiter.call("evaluate_item", "planet", 1, cam_pos + Vector2(50.0, 50.0), cam_pos, vp_size) as bool
	# Planeta variante 2 en pantalla -> admitido (distinta variante)
	var p_var2: bool = arbiter.call("evaluate_item", "planet", 2, cam_pos + Vector2(-50.0, 50.0), cam_pos, vp_size) as bool

	assert_true(p_var1_a, "El primer planeta de variante 1 debe ser admitido.")
	assert_true(not p_var1_b, "El segundo planeta de variante 1 debe ser rechazado por anti-duplicado.")
	assert_true(p_var2, "Un planeta de variante 2 distinta debe ser admitido.")

	sandbox.queue_free()
	pass_suite("TestSpaceBiomeSandboxSuite completada con éxito. Zócalos solares, cinemática kepleriana, luz radial y regla anti-duplicados validados al 100%.")


