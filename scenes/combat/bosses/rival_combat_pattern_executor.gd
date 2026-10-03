class_name RivalCombatPatternExecutor
extends RefCounted

## Ejecutor de patrones de combate Danmaku y botín insignia para pilotos rivales.
## Gestiona la ráfaga de proyectiles mediante BulletServer (Zero-Allocation) y la entrega de armas al morir.

static func execute_signature_attack(bullet_server: BulletServer, pilot_id: StringName, global_pos: Vector2, target_pos: Vector2, rotation: float, sfx_callable: Callable) -> void:
	if not is_instance_valid(bullet_server):
		return

	match pilot_id:
		&"nova":
			# Ráfaga rápida de riel acelerada
			bullet_server.fire_aimed_spread(global_pos, target_pos, 3, 14.0, 340.0, 2)
			if sfx_callable.is_valid():
				sfx_callable.call("laser", 1.2)
		&"valentina":
			# Francotirador telegrafiado de altísima velocidad
			bullet_server.fire_common_aimed_bullet(global_pos, target_pos, 440.0, 1)
			if sfx_callable.is_valid():
				sfx_callable.call("laser", 0.8)
		&"kira":
			# Enjambre de proyectiles biomórficos en espiral
			bullet_server.fire_serpentine_spread(global_pos, target_pos, 5, 35.0, 210.0, 40.0, 3.5, 0)
			if sfx_callable.is_valid():
				sfx_callable.call("missile", 1.0)
		&"selene":
			# Pulso gravitatorio y abanico de estrellas
			bullet_server.fire_radial_ring(global_pos, 12, 180.0, rotation, 3)
			if sfx_callable.is_valid():
				sfx_callable.call("missile", 0.9)
		&"roxy":
			# Escopetazo titánico con dispersión pesada
			bullet_server.fire_aimed_spread(global_pos, target_pos, 7, 45.0, 260.0, 1)
			if sfx_callable.is_valid():
				sfx_callable.call("explosion", 1.1)
		&"echo":
			# Trenza eléctrica de doble lissajous
			bullet_server.fire_braided_lissajous(global_pos, target_pos, 3, 240.0, 50.0, 4.0, 2)
			if sfx_callable.is_valid():
				sfx_callable.call("laser", 1.4)
		&"nyx":
			# Cuchillas dimensionales en abanico
			bullet_server.fire_rhodonea_flower(global_pos, 14, 220.0, 4, 0.4, rotation, 1)
			if sfx_callable.is_valid():
				sfx_callable.call("laser", 1.3)
		_:
			bullet_server.fire_aimed_spread(global_pos, target_pos, 4, 25.0, 260.0, 1)

static func drop_weapon_pickup(tree: SceneTree, parent_node: Node, pos: Vector2, weapon_data: WeaponData, pilot_name: String) -> void:
	if not weapon_data:
		return
	var pickup_scene := load("res://scenes/combat/pickups/rival_weapon_pickup.tscn") as PackedScene
	if pickup_scene:
		var pickup = pickup_scene.instantiate()
		pickup.setup(pos, weapon_data, pilot_name)
		var spawn_parent: Node = parent_node if parent_node else tree.current_scene
		if spawn_parent:
			spawn_parent.call_deferred("add_child", pickup)
