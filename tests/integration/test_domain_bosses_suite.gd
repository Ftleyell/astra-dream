extends Node2D

func _ready() -> void:
	print("==========================================================")
	print("[TEST] Running Domain Bosses & Common Enemy Redesign Suite")
	print("==========================================================\n")

	var bullet_server := BulletServer.new()
	add_child(bullet_server)

	# 1. Test BulletServer common enemy bullet quota
	print("[1/5] Testing BulletServer common bullet quota (MAX 20)...")
	assert(bullet_server.active_common_bullets == 0, "Initial common bullets must be 0")
	assert(bullet_server.can_common_enemy_shoot() == true, "Should be allowed to shoot initially")

	for i in range(BulletServer.MAX_COMMON_ENEMY_BULLETS):
		var ok := bullet_server.fire_common_aimed_bullet(Vector2.ZERO, Vector2(100, 100))
		assert(ok == true, "Bullet %d should succeed" % i)

	assert(bullet_server.active_common_bullets == 20, "Should have reached exactly 20 active common bullets")
	assert(bullet_server.can_common_enemy_shoot() == false, "Should now refuse extra common enemy bullets")
	var blocked := bullet_server.fire_common_aimed_bullet(Vector2.ZERO, Vector2(100, 100))
	assert(blocked == false, "Bullet beyond quota must be blocked")

	bullet_server.bomb_clear_all()
	assert(bullet_server.active_common_bullets == 0, "bomb_clear_all must reset common bullets to 0")

	# Test Fórmulas Trigonométricas de Picayune (Senos y Cosenos)
	bullet_server.fire_rhodonea_flower(Vector2.ZERO, 16, 150.0, 5, 0.35, 0.0, 0)
	assert(bullet_server.active_count == 16, "Rhodonea flower should spawn 16 bullets")

	bullet_server.fire_serpentine_spread(Vector2.ZERO, Vector2(200, 0), 5, 30.0, 180.0, 15.0, 4.0, 2)
	assert(bullet_server.active_count == 21, "Serpentine spread should spawn 5 bullets")

	bullet_server.fire_braided_lissajous(Vector2.ZERO, Vector2(200, 0), 3, 200.0, 20.0, 5.0, 2)
	assert(bullet_server.active_count == 27, "Braided lissajous should spawn 6 bullets (3 pairs)")

	bullet_server.fire_breathing_fermat_spiral_tick(Vector2.ZERO, 1, 160.0, 0.0, 0.2, 0.3, 1)
	assert(bullet_server.active_count == 28, "Breathing spiral tick should spawn 1 bullet")
	bullet_server.bomb_clear_all()
	assert(bullet_server.active_count == 0, "bomb_clear_all must clear all bullets")
	print("  ✓ Common enemy bullet limiter correctly enforced (Quota: 20)")
	print("  ✓ Picayune Trigonometric Patterns (Rhodonea, Serpentine, Lissajous, Breathing Fermat) validated")

	# 2. Test EnemyShooter behavior
	print("\n[2/5] Testing EnemyShooter single telegraphed shot...")
	var shooter_scene: PackedScene = load("res://scenes/combat/enemies/enemy_shooter.tscn")
	assert(shooter_scene != null, "enemy_shooter.tscn must exist")
	var shooter := shooter_scene.instantiate() as CharacterBody2D
	add_child(shooter)

	assert(shooter.is_in_group("enemies"), "EnemyShooter must be in 'enemies' group")
	assert(shooter.has_method("take_damage"), "EnemyShooter must implement take_damage")
	assert(shooter.get("shoot_interval") >= 3.0, "Shooter interval should be adjusted for slower deliberate shots")
	shooter.queue_free()
	print("  ✓ EnemyShooter correctly configured for telegraphed deliberate shots")

	# 3. Test Hermit Void (Wave 2)
	print("\n[3/5] Testing Boss 1: Eremita del Vacío (Ola 2)...")
	var hermit_scene: PackedScene = load("res://scenes/combat/bosses/boss_hermit_void.tscn")
	assert(hermit_scene != null, "boss_hermit_void.tscn must exist")
	var hermit := hermit_scene.instantiate() as CharacterBody2D
	add_child(hermit)

	assert(hermit.is_in_group("enemies"), "Hermit must be in 'enemies' group")
	assert(hermit.is_in_group("bosses"), "Hermit must be in 'bosses' group")
	assert(hermit.get("max_health") == 1600.0, "Hermit max_health must be 1600")
	assert(hermit.get("current_phase") == 1, "Hermit starts in phase 1")

	var hit1 := HitContext.new()
	hit1.raw_damage = 850.0
	hit1.final_damage = 850.0
	hermit.take_damage(hit1)
	assert(hermit.get("current_phase") == 2, "Hermit must transition to Phase 2 below 50% HP")
	hermit.queue_free()
	print("  ✓ Eremita del Vacío (Dominio del Aislamiento) validated in Phase 1 & 2")

	# 4. Test Ash Clock (Wave 4)
	print("\n[4/5] Testing Boss 2: Reloj de Cenizas (Ola 4)...")
	var ash_scene: PackedScene = load("res://scenes/combat/bosses/boss_ash_clock.tscn")
	assert(ash_scene != null, "boss_ash_clock.tscn must exist")
	var ash := ash_scene.instantiate() as CharacterBody2D
	add_child(ash)

	assert(ash.is_in_group("enemies"), "Ash Clock must be in 'enemies' group")
	assert(ash.is_in_group("bosses"), "Ash Clock must be in 'bosses' group")
	assert(ash.get("max_health") == 2400.0, "Ash Clock max_health must be 2400")
	assert(ash.get("current_phase") == 1, "Ash Clock starts in phase 1")

	var hit2 := HitContext.new()
	hit2.raw_damage = 1300.0
	hit2.final_damage = 1300.0
	ash.take_damage(hit2)
	assert(ash.get("current_phase") == 2, "Ash Clock must transition to Phase 2 below 50% HP")
	ash.queue_free()
	print("  ✓ Reloj de Cenizas (Dominio del Arrepentimiento) validated in Phase 1 & 2")

	# 5. Test Broken Mirror & Overflow Vortex (Wave 6 & 8)
	print("\n[5/5] Testing Boss 3 & 4: Espejo Quebrado y Vórtice del Desborde...")
	var mirror_scene: PackedScene = load("res://scenes/combat/bosses/boss_broken_mirror.tscn")
	assert(mirror_scene != null, "boss_broken_mirror.tscn must exist")
	var mirror := mirror_scene.instantiate() as CharacterBody2D
	add_child(mirror)
	assert(mirror.is_in_group("enemies") and mirror.is_in_group("bosses"), "Mirror in groups")
	assert(mirror.get("max_health") == 3200.0, "Mirror max_health must be 3200")

	var hit3 := HitContext.new()
	hit3.raw_damage = 1700.0
	hit3.final_damage = 1700.0
	mirror.take_damage(hit3)
	assert(mirror.get("current_phase") == 2, "Mirror must transition to Phase 2")
	mirror.queue_free()

	var vortex_scene: PackedScene = load("res://scenes/combat/bosses/boss_overflow_vortex.tscn")
	assert(vortex_scene != null, "boss_overflow_vortex.tscn must exist")
	var vortex := vortex_scene.instantiate() as CharacterBody2D
	add_child(vortex)
	assert(vortex.is_in_group("enemies") and vortex.is_in_group("bosses"), "Vortex in groups")
	assert(vortex.get("max_health") == 4500.0, "Vortex max_health must be 4500")

	var hit4 := HitContext.new()
	hit4.raw_damage = 2300.0
	hit4.final_damage = 2300.0
	vortex.take_damage(hit4)
	assert(vortex.get("current_phase") == 2, "Vortex must transition to Phase 2")
	vortex.queue_free()

	print("  ✓ Espejo Quebrado (Dominio de la Disociación) validated")
	print("  ✓ Vórtice del Desborde (Dominio del Agobio) validated")

	bullet_server.queue_free()

	print("\n==========================================================")
	print(">>> ALL DOMAIN BOSSES & REDESIGN TESTS PASSED (100%) <<<")
	print("==========================================================\n")
	get_tree().quit(0)
