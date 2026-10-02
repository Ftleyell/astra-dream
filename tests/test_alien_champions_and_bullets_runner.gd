extends Node2D

## Suite de verificación automatizada para Campeones Élite y Balística Alienígena.
## Valida la carga de texturas, instanciación de escenas, funcionamiento del TelegraphIndicator
## y emisión de proyectiles Zero-Allocation en BulletServer.

func _ready() -> void:
	print("=== INICIANDO TEST: CAMPEONES ÉLITE Y BALÍSTICA ALIENÍGENA ===")
	_test_assets_exist()
	_test_bullet_server_alien_patterns()
	_test_champions_instantiation_and_telegraph()
	print("=== TODOS LOS TESTS DE CAMPEONES Y BALÍSTICA PASARON CON ÉXITO ===")
	get_tree().quit(0)

func _test_assets_exist() -> void:
	print("1. Verificando assets y texturas...")
	var assets: Array[String] = [
		"res://assets/sprites/bullets/bullet_alien_amber_cone.png",
		"res://assets/sprites/bullets/bullet_alien_cobalt_ring.png",
		"res://assets/sprites/bullets/bullet_alien_purple_wave.png",
		"res://assets/sprites/bullets/alien_bullet_atlas.png",
		"res://assets/sprites/telegraphs/telegraph_cone.png",
		"res://assets/sprites/telegraphs/telegraph_ring.png",
		"res://assets/sprites/telegraphs/telegraph_wave.png"
	]
	for p in assets:
		assert(ResourceLoader.exists(p), "Asset faltante: " + p)
		var tex: Texture2D = load(p) as Texture2D
		assert(tex != null, "No se pudo cargar textura: " + p)
	print("   [OK] Todos los 7 assets de balas y telegrafiados cargaron correctamente.")

func _test_bullet_server_alien_patterns() -> void:
	print("2. Verificando patrones balísticos en BulletServer...")
	var bs: BulletServer = BulletServer.new()
	add_child(bs)

	# Test Cono
	var initial_count: int = bs.active_count
	var fired_cone: int = bs.fire_alien_cone_spread(Vector2(100.0, 100.0), Vector2(200.0, 100.0), 5, 40.0, 230.0)
	assert(fired_cone == 5, "Deberían dispararse 5 balas en el cono")
	assert(bs.active_count == initial_count + 5, "active_count debería incrementarse en 5")

	# Test Anillo
	var fired_ring: int = bs.fire_alien_ring_burst(Vector2(200.0, 200.0), 12, 175.0)
	assert(fired_ring == 12, "Deberían dispararse 12 balas en el anillo")
	assert(bs.active_count == initial_count + 17, "active_count debería incrementarse en 12")

	# Test Ondas
	var fired_wave: int = bs.fire_alien_wave_lane(Vector2(300.0, 300.0), Vector2(400.0, 300.0), 2, 210.0, 65.0, 5.0)
	assert(fired_wave == 4, "Deberían dispararse 4 balas (2 pares) en las ondas")
	assert(bs.active_count == initial_count + 21, "active_count debería ser +21")

	# Limpiar
	bs.clear_all_bullets()
	assert(bs.active_count == 0, "clear_all_bullets debería vaciar el pool")
	bs.queue_free()
	print("   [OK] BulletServer disparó los 3 patrones y gestionó memoria SoA exitosamente.")

func _test_champions_instantiation_and_telegraph() -> void:
	print("3. Verificando instanciación de campeones y componente TelegraphIndicator...")
	var cone_scene: PackedScene = load("res://scenes/combat/enemies/enemy_assault_cone.tscn") as PackedScene
	var ring_scene: PackedScene = load("res://scenes/combat/enemies/enemy_vanguard_ring.tscn") as PackedScene
	var wave_scene: PackedScene = load("res://scenes/combat/enemies/enemy_specter_wave.tscn") as PackedScene

	assert(cone_scene != null, "enemy_assault_cone.tscn debe ser válido")
	assert(ring_scene != null, "enemy_vanguard_ring.tscn debe ser válido")
	assert(wave_scene != null, "enemy_specter_wave.tscn debe ser válido")

	var cone_inst: EnemyAssaultCone = cone_scene.instantiate() as EnemyAssaultCone
	var ring_inst: EnemyVanguardRing = ring_scene.instantiate() as EnemyVanguardRing
	var wave_inst: EnemySpecterWave = wave_scene.instantiate() as EnemySpecterWave

	assert(cone_inst is EnemyBase, "EnemyAssaultCone debe heredar de EnemyBase")
	assert(ring_inst is EnemyBase, "EnemyVanguardRing debe heredar de EnemyBase")
	assert(wave_inst is EnemyBase, "EnemySpecterWave debe heredar de EnemyBase")

	add_child(cone_inst)
	add_child(ring_inst)
	add_child(wave_inst)

	# Comprobar existencia del componente TelegraphIndicator
	var cone_tele: TelegraphIndicator = cone_inst.get_node_or_null("TelegraphIndicator") as TelegraphIndicator
	var ring_tele: TelegraphIndicator = ring_inst.get_node_or_null("TelegraphIndicator") as TelegraphIndicator
	var wave_tele: TelegraphIndicator = wave_inst.get_node_or_null("TelegraphIndicator") as TelegraphIndicator

	assert(cone_tele != null, "cone_inst debe tener TelegraphIndicator")
	assert(ring_tele != null, "ring_inst debe tener TelegraphIndicator")
	assert(wave_tele != null, "wave_inst debe tener TelegraphIndicator")

	cone_inst.queue_free()
	ring_inst.queue_free()
	wave_inst.queue_free()
	print("   [OK] Las 3 escenas de campeones instanciaron y verificaron sus componentes modulares.")
