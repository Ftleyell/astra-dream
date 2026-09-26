extends Node2D

const EnemyMicroFlockClass = preload("res://scenes/combat/enemies/enemy_micro_flock.gd")
const EnemySplitterClass = preload("res://scenes/combat/enemies/enemy_splitter.gd")
const ResonanceContainmentNodeClass = preload("res://scenes/combat/enemies/resonance_containment_node.gd")
const CrisisEventManagerClass = preload("res://scenes/combat/events/crisis_event_manager.gd")
const EliteHeraldBossClass = preload("res://scenes/combat/bosses/elite_herald_boss.gd")

func _ready() -> void:
	print("==========================================================")
	print("[TEST] Running Wave Director & Crisis Events Suite")
	print("==========================================================\n")

	var bullet_server := get_node_or_null("/root/BulletServer") as BulletServer
	if not bullet_server:
		bullet_server = BulletServer.new()
		add_child(bullet_server)

	# 1. Test EnemyMicroFlock
	print("[1/5] Testing EnemyMicroFlock archetype...")
	var flock_scene: PackedScene = load("res://scenes/combat/enemies/enemy_micro_flock.tscn")
	assert(flock_scene != null, "enemy_micro_flock.tscn must exist")
	var flock: EnemyMicroFlockClass = flock_scene.instantiate()
	add_child(flock)
	assert(flock.is_in_group("enemies"), "EnemyMicroFlock must belong to 'enemies' group")
	assert(flock.has_method("take_damage"), "EnemyMicroFlock must implement take_damage")
	assert(flock.max_health == 12.0, "EnemyMicroFlock max_health should be 12.0")
	assert(flock.move_speed == 380.0, "EnemyMicroFlock move_speed should be 380.0")

	var hit_ctx := HitContext.create_direct_hit(15.0, false, 1.0)
	flock.take_damage(hit_ctx)
	assert(flock.is_dying == true, "Flock should be dying after 15.0 damage")
	print("  ✓ EnemyMicroFlock successfully validated (12 HP, 380 px/s, group 'enemies')")

	# 2. Test EnemySplitter & Mitosis
	print("\n[2/5] Testing EnemySplitter Mitosis & Tether...")
	var splitter_scene: PackedScene = load("res://scenes/combat/enemies/enemy_splitter.tscn")
	assert(splitter_scene != null, "enemy_splitter.tscn must exist")
	var splitter: EnemySplitterClass = splitter_scene.instantiate()
	add_child(splitter)
	assert(splitter.is_in_group("enemies"), "EnemySplitter must belong to 'enemies' group")
	assert(splitter.max_health == 75.0, "Parent Splitter max_health must be 75.0")
	assert(splitter.move_speed == 135.0, "Parent Splitter move_speed must be 135.0")

	# Simular muerte por mitosis
	splitter.take_damage(HitContext.create_direct_hit(100.0, false, 1.0))
	assert(splitter.is_dying == true, "Parent Splitter must be dying")

	# Comprobar micro clones generados en el árbol
	var micro_clones: Array[Node] = []
	for child in get_children():
		if child is EnemySplitterClass and child != splitter and child.is_micro_clone:
			micro_clones.append(child)

	assert(micro_clones.size() == 2, "Mitosis must spawn exactly 2 micro clones")
	var clone_a: EnemySplitterClass = micro_clones[0]
	var clone_b: EnemySplitterClass = micro_clones[1]
	assert(clone_a.twin_half == clone_b, "Clone A must be linked to Clone B")
	assert(clone_b.twin_half == clone_a, "Clone B must be linked to Clone A")
	assert(clone_a.max_health == 22.0, "Micro clone max_health must be 22.0")
	clone_a.queue_free()
	clone_b.queue_free()
	print("  ✓ EnemySplitter Mitosis and Tether pairs validated (75 HP -> 2x 22 HP clones)")

	# 3. Test ResonanceContainmentNode
	print("\n[3/5] Testing ResonanceContainmentNode (Static Barrier Arena)...")
	var node_scene: PackedScene = load("res://scenes/combat/enemies/resonance_containment_node.tscn")
	assert(node_scene != null, "resonance_containment_node.tscn must exist")
	var c_node_a: ResonanceContainmentNodeClass = node_scene.instantiate()
	var c_node_b: ResonanceContainmentNodeClass = node_scene.instantiate()
	add_child(c_node_a)
	add_child(c_node_b)
	c_node_a.global_position = Vector2(0, 0)
	c_node_b.global_position = Vector2(100, 0)
	c_node_a.set_neighbor(c_node_b)

	assert(c_node_a.is_in_group("enemies"), "ResonanceContainmentNode must be in 'enemies' group")
	assert(c_node_a.max_health == 150.0, "ResonanceContainmentNode must have 150.0 HP")
	assert(c_node_a.lifetime == 25.0, "ResonanceContainmentNode lifetime must be 25s")

	c_node_a.take_damage(HitContext.create_direct_hit(50.0, false, 1.0))
	assert(c_node_a.current_health == 100.0, "ResonanceContainmentNode should have 100 HP after 50 dmg")
	c_node_a.queue_free()
	c_node_b.queue_free()
	print("  ✓ ResonanceContainmentNode validated (150 HP, 25s decay, neighbor tether)")

	# 4. Test CrisisEventManager and Solar Storm Buff/Shader
	print("\n[4/5] Testing CrisisEventManager & Solar Storm Frenzy (+30% Atk Spd)...")
	var player := CharacterBody2D.new()
	var mock_script := GDScript.new()
	mock_script.source_code = "extends CharacterBody2D\nvar stats: CharacterStats = null\n"
	mock_script.reload()
	player.set_script(mock_script)
	var char_stats := CharacterStats.new()
	var dummy_char := CharacterData.new()
	dummy_char.attack_speed = 1.0
	dummy_char.max_health = 100.0
	char_stats.initialize(dummy_char)
	player.stats = char_stats
	player.add_to_group("player")
	add_child(player)

	var manager_scene: PackedScene = load("res://scenes/combat/events/crisis_event_manager.tscn")
	assert(manager_scene != null, "crisis_event_manager.tscn must exist")
	var crisis_mgr = manager_scene.instantiate()
	add_child(crisis_mgr)
	crisis_mgr.player = player
	crisis_mgr.auto_crisis_enabled = false # Evitar timers durante el test

	var initial_atk_spd: float = player.stats.get_stat(&"attack_speed")
	# Activar Tormenta Solar
	crisis_mgr._start_solar_storm()
	assert(crisis_mgr.solar_storm_active == true, "Solar storm must be active")
	var buffed_atk_spd: float = player.stats.get_stat(&"attack_speed")
	assert(buffed_atk_spd > initial_atk_spd, "Player attack speed must increase during solar storm")
	var ratio := buffed_atk_spd / initial_atk_spd
	assert(absf(ratio - 1.30) < 0.05, "Player attack speed should receive approximately +30% buff")

	# Finalizar Tormenta Solar
	crisis_mgr._end_solar_storm()
	assert(crisis_mgr.solar_storm_active == false, "Solar storm must be inactive")
	var restored_atk_spd: float = player.stats.get_stat(&"attack_speed")
	assert(absf(restored_atk_spd - initial_atk_spd) < 0.01, "Player attack speed must be restored after solar storm")

	# Probar spawn de formaciones
	var pre_count := get_child_count()
	crisis_mgr._spawn_containment_arena()
	var post_containment := get_child_count()
	assert(post_containment >= pre_count + 14, "Containment arena must spawn 14 nodes")

	crisis_mgr._spawn_flock_rush()
	var post_flock := get_child_count()
	assert(post_flock >= post_containment + 15, "Flock rush must spawn 15 micro-flock drones")

	crisis_mgr.queue_free()
	print("  ✓ CrisisEventManager correctly applied and removed +30% attack speed buff")
	print("  ✓ Formations (Containment Arena 14 nodes, Flock Rush 15 drones) spawned correctly")

	# 5. Test EliteHeraldBoss (Wave 3, 5, 7 Mini-Bosses)
	print("\n[5/5] Testing EliteHeraldBoss (Waves 3, 5, 7 Mini-Bosses)...")
	var herald_scene: PackedScene = load("res://scenes/combat/bosses/elite_herald_boss.tscn")
	assert(herald_scene != null, "elite_herald_boss.tscn must exist")
	var herald = herald_scene.instantiate()
	add_child(herald)

	assert(herald.is_in_group("enemies"), "EliteHeraldBoss must belong to 'enemies' group")
	assert(herald.is_in_group("bosses"), "EliteHeraldBoss must belong to 'bosses' group")
	assert(herald.has_method("take_damage"), "EliteHeraldBoss must implement take_damage")

	# Wave 3: Heraldo del Tiempo
	herald.setup_type(3)
	assert(herald.boss_id == "herald_time", "Wave 3 herald must be herald_time")
	assert(herald.max_health == 550.0, "Wave 3 herald max_health must be 550.0")

	# Wave 5: Heraldo del Espejo
	herald.setup_type(5)
	assert(herald.boss_id == "herald_mirror", "Wave 5 herald must be herald_mirror")
	assert(herald.max_health == 750.0, "Wave 5 herald max_health must be 750.0")

	# Wave 7: Heraldo del Vórtice
	herald.setup_type(7)
	assert(herald.boss_id == "herald_vortex", "Wave 7 herald must be herald_vortex")
	assert(herald.max_health == 950.0, "Wave 7 herald max_health must be 950.0")

	# Test danmaku execution via BulletServer
	herald.player = player
	herald.bullet_server = bullet_server
	herald.fire_timer = 1.0
	herald._process_time_herald(1.0)
	assert(bullet_server.active_count > 0, "Herald attack should fire bullets through BulletServer")
	bullet_server.bomb_clear_all()

	# Test daño
	herald.take_damage(HitContext.create_direct_hit(100.0, false, 1.0))
	assert(herald.current_health == 850.0, "Herald current health must decrease correctly")

	herald.queue_free()
	player.queue_free()
	if bullet_server.get_parent() == self:
		bullet_server.queue_free()
	print("  ✓ EliteHeraldBoss validated across Waves 3, 5, 7 with BulletServer danmaku")

	print("\n==========================================================")
	print("ALL 5 CRISIS & WAVE DIRECTOR TESTS COMPLETED SUCCESSFULLY!")
	print("==========================================================")
	get_tree().quit(0)
