class_name EnemyNodePool
extends Node

## Pool de nodos reutilizables para oleadas masivas de enemigos (Zero-Allocation).
## Previene micro-tirones y fragmentación de memoria por .instantiate() y .queue_free() masivos.

var _pools: Dictionary = {}
var _active_instances: Dictionary = {}

func acquire_enemy(scene: PackedScene, pos: Vector2, parent: Node) -> Node2D:
	if not scene:
		return null

	var free_list: Array = _pools.get(scene, [])
	var enemy: Node2D = null

	while not free_list.is_empty():
		var candidate: Node2D = free_list.pop_back() as Node2D
		if is_instance_valid(candidate):
			enemy = candidate
			break

	if enemy:
		if not enemy.is_inside_tree() and parent:
			parent.add_child(enemy)
		if enemy.has_method("reset_from_pool"):
			enemy.call("reset_from_pool", pos)
		else:
			enemy.global_position = pos
			enemy.visible = true
			enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
			if not enemy.is_in_group("enemies"):
				enemy.add_to_group("enemies")
	else:
		enemy = scene.instantiate() as Node2D
		if enemy:
			enemy.global_position = pos
			if "pool_source" in enemy:
				enemy.set("pool_source", self)
			if parent:
				parent.add_child(enemy)

	if enemy:
		_active_instances[enemy] = scene

	return enemy

func recycle_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return

	var scene: PackedScene = _active_instances.get(enemy, null)
	_active_instances.erase(enemy)

	enemy.visible = false
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	if enemy.is_in_group("enemies"):
		enemy.remove_from_group("enemies")

	var col: Node = enemy.get_node_or_null("CollisionShape2D")
	if col and "disabled" in col:
		col.set_deferred("disabled", true)

	if scene:
		if not _pools.has(scene):
			_pools[scene] = []
		(_pools[scene] as Array).append(enemy)
	else:
		enemy.queue_free()

func clear_all() -> void:
	for enemy in _active_instances.keys():
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_instances.clear()

	for scene in _pools:
		var arr: Array = _pools[scene]
		for enemy in arr:
			if is_instance_valid(enemy):
				enemy.queue_free()
	_pools.clear()
