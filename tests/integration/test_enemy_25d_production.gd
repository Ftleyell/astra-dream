extends BaseTestSuite

## Integration test suite verifying that all 10 production EnemyBase scenes (11 catalog IDs)
## mount VoidScarabRig25D via EnemyVisualController with combat_lite_mode, static GPU caching,
## zero sandbox leakage, distinct palettes/scales, and clean EnemyNodePool lifecycle reuse.

const VoidScarabRigScript = preload("res://scenes/combat/enemies/rig/void_scarab_rig_25d.gd")
const EnemyVisualControllerScript = preload("res://scenes/combat/enemies/rig/enemy_visual_controller.gd")
const EnemyNodePoolScript = preload("res://scenes/combat/enemies/enemy_node_pool.gd")
const CatalogRes: EnemyArchetypeVisualCatalog = preload("res://data/enemies/default_enemy_visual_catalog.tres")

const ENEMY_SCENES: Array[String] = [
	"res://scenes/combat/enemies/enemy_drone.tscn",
	"res://scenes/combat/enemies/enemy_kamikaze.tscn",
	"res://scenes/combat/enemies/enemy_shooter.tscn",
	"res://scenes/combat/enemies/enemy_tank.tscn",
	"res://scenes/combat/enemies/enemy_splitter.tscn",
	"res://scenes/combat/enemies/enemy_micro_flock.tscn",
	"res://scenes/combat/enemies/enemy_assault_cone.tscn",
	"res://scenes/combat/enemies/enemy_vanguard_ring.tscn",
	"res://scenes/combat/enemies/enemy_specter_wave.tscn",
	"res://scenes/combat/enemies/rainbow_enemy.tscn",
]

const EXPECTED_CATALOG_IDS: Array[StringName] = [
	&"enemy_drone",
	&"enemy_kamikaze",
	&"enemy_shooter",
	&"enemy_tank",
	&"enemy_splitter",
	&"enemy_splitter_micro",
	&"enemy_micro_flock",
	&"enemy_assault_cone",
	&"enemy_vanguard_ring",
	&"enemy_specter_wave",
	&"enemy_rainbow",
]


func _ready() -> void:
	timeout_seconds = 25.0
	super._ready()
	_run_tests()


func _run_tests() -> void:
	# 1. Single Source of Truth: zero sandbox leaks in production enemies or data/enemies
	var leaks: Array[String] = []
	_scan_dir_for_sandbox_refs("res://scenes/combat/enemies", leaks)
	_scan_dir_for_sandbox_refs("res://data/enemies", leaks)
	assert_true(leaks.is_empty(), "Producción no debe referenciar res://sandbox/: %s" % str(leaks))

	# 2. Verify catalog resolves all 11 archetype IDs cleanly
	assert_true(CatalogRes != null, "default_enemy_visual_catalog.tres debe cargar correctamente")
	for eid: StringName in EXPECTED_CATALOG_IDS:
		var entry: EnemyArchetypeVisualEntry = CatalogRes.resolve_entry(eid)
		assert_true(entry != null and entry.enemy_id == eid, "Catálogo debe resolver %s" % String(eid))

	# Dummy player anchor so enemy steering AI has a valid target
	var dummy_player := Node2D.new()
	dummy_player.add_to_group(&"player")
	dummy_player.global_position = Vector2(900.0, 0.0)
	add_child(dummy_player)

	var arena := Node2D.new()
	arena.name = "EnemyTestArena"
	add_child(arena)

	var scales_by_id: Dictionary = {}
	var emissive_by_id: Dictionary = {}

	# 3. Instantiate all 10 production enemy scenes and verify VoidScarabRig25D mounting
	for idx: int in range(ENEMY_SCENES.size()):
		var scene_path: String = ENEMY_SCENES[idx]
		var packed: PackedScene = ResourceLoader.load(scene_path) as PackedScene
		assert_true(packed != null, "No se pudo cargar escena enemiga: %s" % scene_path)

		var enemy: Node2D = packed.instantiate() as Node2D
		assert_true(enemy != null, "No se pudo instanciar: %s" % scene_path)
		enemy.position = Vector2(float(idx) * 140.0, 0.0)
		arena.add_child(enemy)

		var ctrl: EnemyVisualController = enemy.get("visual_controller") as EnemyVisualController
		assert_true(ctrl != null, "%s debe montar EnemyVisualController" % scene_path)
		var rig: VoidScarabRigScript = ctrl.get_rig()
		assert_true(rig != null, "%s debe crear VoidScarabRig25D" % scene_path)
		assert_true(rig.combat_lite_mode, "%s debe usar combat_lite_mode=true en producción" % scene_path)
		assert_true(rig.get_part_meshes().size() == 7, "%s debe tener exactamente 7 MeshInstance2D principales" % scene_path)
		assert_true(rig.get_shell_meshes().is_empty(), "%s en combat_lite_mode no debe crear extruded shells" % scene_path)

		for legacy_name: String in ["Sprite2D", "SplitterSprite", "FlockSprite", "Visual", "CoreGlow", "CellCore", "EngineParticles"]:
			var legacy_item: CanvasItem = enemy.get_node_or_null(legacy_name) as CanvasItem
			if legacy_item != null:
				assert_true(not legacy_item.visible, "%s debe ocultar nodo legacy %s (visible=false)" % [scene_path, legacy_name])
		var spr_prop: CanvasItem = enemy.get("sprite") as CanvasItem
		if spr_prop != null:
			assert_true(not spr_prop.visible, "%s debe ocultar propiedad sprite" % scene_path)
		if scene_path.ends_with("enemy_drone.tscn"):
			assert_true(enemy.get_node_or_null("Sprite2D") != null, "enemy_drone debe conservar Sprite2D")

		var eid: StringName = enemy.get("enemy_id") as StringName
		scales_by_id[eid] = ctrl.scale.x

		var body_mat: ShaderMaterial = rig.get_part_meshes()[0].material as ShaderMaterial
		assert_true(body_mat != null, "%s body_core debe tener ShaderMaterial" % scene_path)
		emissive_by_id[eid] = body_mat.get_shader_parameter("primary_emissive_tint")

	await _wait_frames(3)

	# 4. Verify archetype size hierarchy and palette differentiation
	assert_true(float(scales_by_id[&"enemy_tank"]) > float(scales_by_id[&"enemy_drone"]), "Tank debe ser más grande que Drone")
	assert_true(float(scales_by_id[&"enemy_drone"]) > float(scales_by_id[&"enemy_micro_flock"]), "Drone debe ser más grande que MicroFlock")

	var drone_em: Color = emissive_by_id[&"enemy_drone"] as Color
	var kamikaze_em: Color = emissive_by_id[&"enemy_kamikaze"] as Color
	var tank_em: Color = emissive_by_id[&"enemy_tank"] as Color
	assert_true(drone_em.g > drone_em.r, "Drone base debe conservar energía verde")
	assert_true(kamikaze_em.r > kamikaze_em.g, "Kamikaze debe tener energía roja carmesí")
	assert_true(not drone_em.is_equal_approx(tank_em), "Tank debe tener paleta distinta a Drone")

	# 5. Verify GPU texture & mesh static caching across all 10 enemies
	assert_true(VoidScarabRigScript.get_cached_texture_count() <= 28, "Texturas cacheadas no deben superar 28 (actual=%d)" % VoidScarabRigScript.get_cached_texture_count())
	assert_true(VoidScarabRigScript.get_cached_mesh_count() <= 8, "Mallas cacheadas no deben superar 8 (actual=%d)" % VoidScarabRigScript.get_cached_mesh_count())

	# 6. Verify EnemySplitter micro-clone entry resolution & scale
	var splitter_packed: PackedScene = ResourceLoader.load("res://scenes/combat/enemies/enemy_splitter.tscn") as PackedScene
	var micro_clone: Node2D = splitter_packed.instantiate() as Node2D
	arena.add_child(micro_clone)
	micro_clone.set("enemy_id", &"enemy_splitter_micro")
	var micro_ctrl: EnemyVisualController = micro_clone.get("visual_controller") as EnemyVisualController
	micro_ctrl.reset_for_pool()
	assert_true(micro_ctrl.get_visual_entry().enemy_id == &"enemy_splitter_micro", "Micro-clone debe resolver entrada enemy_splitter_micro")
	assert_true(micro_ctrl.scale.x < float(scales_by_id[&"enemy_splitter"]), "Micro-clone debe ser más pequeño que Splitter padre")

	# 7. Verify EnemyNodePool acquire -> hit -> die -> recycle -> reset_from_pool
	var pool: Node = EnemyNodePoolScript.new()
	add_child(pool)
	var drone_scene: PackedScene = ResourceLoader.load("res://scenes/combat/enemies/enemy_drone.tscn") as PackedScene
	var pooled_enemy: Node2D = pool.call("acquire_enemy", drone_scene, Vector2(200.0, 120.0), arena) as Node2D
	assert_true(pooled_enemy != null, "Pool debe instanciar EnemyDrone")
	var pooled_ctrl: EnemyVisualController = pooled_enemy.get("visual_controller") as EnemyVisualController
	assert_true(pooled_ctrl != null and pooled_ctrl.get_rig() != null, "Enemigo del pool debe tener rig válido")

	pooled_enemy.call("take_damage", 1.0)
	await _wait_frames(2)

	pooled_enemy.call("_die")
	await get_tree().create_timer(0.32).timeout
	assert_true(pooled_ctrl.get_rig().get_anim_state() == VoidScarabRigScript.AnimState.DEATH_SHATTER, "_die() debe poner el rig en DEATH_SHATTER")

	pool.call("recycle_enemy", pooled_enemy)
	var reused_enemy: Node2D = pool.call("acquire_enemy", drone_scene, Vector2(-150.0, -80.0), arena) as Node2D
	assert_true(reused_enemy == pooled_enemy, "Pool debe reutilizar la instancia reciclada")
	var reused_ctrl: EnemyVisualController = reused_enemy.get("visual_controller") as EnemyVisualController
	assert_true(reused_enemy.modulate.a >= 0.99, "reset_from_pool debe restaurar modulate.a = 1.0")
	assert_true(reused_ctrl.get_rig().get_anim_state() != VoidScarabRigScript.AnimState.DEATH_SHATTER, "reset_from_pool debe resetear estado DEATH_SHATTER")
	assert_true(not (reused_enemy.get_node("Sprite2D") as Sprite2D).visible, "Sprite2D debe mantenerse oculto tras reutilización de pool")

	var ctrl_count: int = 0
	for child: Node in reused_enemy.get_children():
		if child is EnemyVisualController:
			ctrl_count += 1
	assert_true(ctrl_count == 1, "Reutilización de pool no debe duplicar EnemyVisualController (count=%d)" % ctrl_count)

	pool.call("clear_all")
	pass_suite("test_enemy_25d_production: 10 escenas (11 IDs), cachés GPU (%d tex, %d mesh), pooling y cero sandbox leaks OK" % [
		VoidScarabRigScript.get_cached_texture_count(),
		VoidScarabRigScript.get_cached_mesh_count(),
	])


func _scan_dir_for_sandbox_refs(dir_path: String, out_leaks: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full_path: String = dir_path.path_join(name)
		if dir.current_is_dir():
			_scan_dir_for_sandbox_refs(full_path, out_leaks)
		elif name.ends_with(".gd") or name.ends_with(".tscn") or name.ends_with(".tres") or name.ends_with(".gdshader"):
			var content: String = FileAccess.get_file_as_string(full_path)
			if content.contains("res://sandbox/"):
				out_leaks.append(full_path)
		name = dir.get_next()
	dir.list_dir_end()


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame
