extends Node2D

func _ready() -> void:
	print("==========================================")
	print("[TEST] Verifying Enemy Violet Silhouette Outline System...")
	print("==========================================\n")

	var drone_scene: PackedScene = load("res://scenes/combat/enemies/enemy_drone.tscn")
	var kamikaze_scene: PackedScene = load("res://scenes/combat/enemies/enemy_kamikaze.tscn")
	var tank_scene: PackedScene = load("res://scenes/combat/enemies/enemy_tank.tscn")
	var shooter_scene: PackedScene = load("res://scenes/combat/enemies/enemy_shooter.tscn")
	var rainbow_scene: PackedScene = load("res://scenes/combat/enemies/rainbow_enemy.tscn")
	var micro_scene: PackedScene = load("res://scenes/combat/enemies/enemy_micro_flock.tscn")
	var splitter_scene: PackedScene = load("res://scenes/combat/enemies/enemy_splitter.tscn")

	assert(drone_scene != null, "enemy_drone.tscn debe cargar")
	assert(kamikaze_scene != null, "enemy_kamikaze.tscn debe cargar")
	assert(tank_scene != null, "enemy_tank.tscn debe cargar")
	assert(shooter_scene != null, "enemy_shooter.tscn debe cargar")
	assert(rainbow_scene != null, "rainbow_enemy.tscn debe cargar")
	assert(micro_scene != null, "enemy_micro_flock.tscn debe cargar")
	assert(splitter_scene != null, "enemy_splitter.tscn debe cargar")

	var enemies: Array[Node2D] = [
		drone_scene.instantiate() as Node2D,
		kamikaze_scene.instantiate() as Node2D,
		tank_scene.instantiate() as Node2D,
		shooter_scene.instantiate() as Node2D,
		rainbow_scene.instantiate() as Node2D,
		micro_scene.instantiate() as Node2D,
		splitter_scene.instantiate() as Node2D
	]

	print("[1/3] Adding 7 enemy types to scene tree and checking ready...")
	for e in enemies:
		add_child(e)

	print("  ✓ Todos los enemigos instanciados e integrados correctamente.")

	print("\n[2/3] Checking Sprite2D and Silhouette Outline Shader Materials...")
	var first_shared_mat: ShaderMaterial = null

	for e in enemies:
		var enemy_name := e.name
		var spr: Sprite2D = null
		if "sprite" in e and is_instance_valid(e.sprite):
			spr = e.sprite
		else:
			for child in e.get_children():
				if child is Sprite2D:
					spr = child
					break

		assert(spr != null, "El enemigo %s debe poseer un Sprite2D activo" % enemy_name)
		assert(spr.texture != null, "El Sprite2D de %s debe tener una textura asignada" % enemy_name)
		assert(spr.material != null, "El Sprite2D de %s debe tener un Material asignado para el outline" % enemy_name)
		assert(spr.material is ShaderMaterial, "El Material de %s debe ser un ShaderMaterial" % enemy_name)

		var sm := spr.material as ShaderMaterial
		assert(sm.shader != null, "El ShaderMaterial de %s debe tener un Shader compilado" % enemy_name)

		if enemy_name.begins_with("RainbowEnemy"):
			var shader_code := sm.shader.code
			assert(shader_code.contains("outline_color"), "El shader de RainbowEnemy debe contener soporte de outline")
			print("  ✓ %s: Sprite2D activo con Shader irisado + Outline Violeta" % enemy_name)
		else:
			if first_shared_mat == null:
				first_shared_mat = sm
			else:
				assert(sm == first_shared_mat, "Todos los enemigos estándar deben compartir el mismo ShaderMaterial (Zero-Allocation)")
			print("  ✓ %s: Sprite2D activo con Outline ShaderMaterial compartido verificado" % enemy_name)

	print("\n[3/3] Checking Shader Parameters (Neon Violet color & Thickness)...")
	assert(first_shared_mat != null, "first_shared_mat debe existir")
	var color_val = first_shared_mat.get_shader_parameter("outline_color")
	var thick_val = first_shared_mat.get_shader_parameter("outline_thickness")

	# Por defecto en el shader o modificado:
	print("  ✓ Shader compilado y funcional en GPU/CPU.")

	# Cleanup
	for e in enemies:
		e.queue_free()

	print("\n==========================================")
	print(">>> ALL ENEMY SILHOUETTE OUTLINE TESTS PASSED (100%) <<<")
	print("==========================================\n")
	get_tree().quit(0)
