class_name IngameDebugActionExecutor
extends RefCounted

## IngameDebugActionExecutor.gd
## Ejecutor de acciones tácticas, cheats, inyección de arsenal y manipulación
## de oleadas para el modal de depuración IngameDebugModal.

static func get_forward_spawn_position(main_game: Node2D, distance: float = 200.0) -> Vector2:
	if not main_game or not ("player" in main_game) or not is_instance_valid(main_game.player):
		return Vector2.ZERO
	var p: Node2D = main_game.player
	var p_vel: Vector2 = p.get("velocity") if "velocity" in p else Vector2.ZERO
	var forward: Vector2 = p_vel.normalized() if p_vel.length_squared() > 10.0 else Vector2.UP
	return p.global_position + forward * distance

static func spawn_monolith(main_game: Node2D) -> String:
	if not main_game:
		return "Error: main_game no disponible"
	var spawner = main_game.get("space_object_spawner")
	if not spawner:
		return "Error: SpaceObjectSpawner no disponible"
	var spawn_pos: Vector2 = get_forward_spawn_position(main_game, 220.0)
	if spawner.has_method("spawn_monolith_at"):
		spawner.spawn_monolith_at(spawn_pos)
		return "Monolito Arcano generado a ~220px frente al jugador."
	elif spawner.has_method("force_spawn_monolith"):
		spawner.force_spawn_monolith(true)
		return "Monolito Arcano forzado en la periferia táctica."
	return "No se pudo spawnear el monolito."

static func spawn_boss(main_game: Node2D, boss_id: String, play_intro: bool) -> String:
	if not main_game:
		return "Error: main_game no disponible"
	var boss_coord = main_game.get("boss_coordinator")
	if not boss_coord:
		return "Error: BossCoordinator no disponible"
	if boss_coord.has_method("spawn_boss_by_id"):
		boss_coord.spawn_boss_by_id(boss_id, play_intro)
		return "Jefe %s instanciado (Cinemática: %s)." % [boss_id, str(play_intro)]
	elif boss_coord.has_method("jump_to_boss"):
		boss_coord.jump_to_boss(boss_id)
		return "Saltando a jefe %s..." % boss_id
	return "No se pudo invocar al jefe."

static func spawn_rival(main_game: Node2D, rival_id: String) -> String:
	if not main_game:
		return "Error: main_game no disponible"
	var boss_coord = main_game.get("boss_coordinator")
	if not boss_coord:
		return "Error: BossCoordinator no disponible"
	var r_pid: StringName = StringName(rival_id)
	if boss_coord.has_method("spawn_rival_pilot"):
		boss_coord.spawn_rival_pilot(r_pid)
		return "Piloto Rival instanciada: %s" % (rival_id if rival_id != "" else "Siguiente en cola")
	return "No se pudo invocar al rival."

static func spawn_satellite(main_game: Node2D) -> String:
	if not main_game:
		return "Error: main_game no disponible"
	var sat_coord = main_game.get("satellite_coordinator")
	if sat_coord and sat_coord.has_method("spawn_specific_satellite"):
		var pos: Vector2 = get_forward_spawn_position(main_game, 220.0)
		sat_coord.spawn_specific_satellite(pos)
		return "Satélite de tienda instanciado frente a la nave."
	return "Error al invocar satélite."

static func spawn_transmutation(main_game: Node2D) -> String:
	if not main_game:
		return "Error: main_game no disponible"
	var sat_coord = main_game.get("satellite_coordinator")
	if sat_coord and sat_coord.has_method("spawn_specific_transmutation"):
		var pos: Vector2 = get_forward_spawn_position(main_game, 220.0)
		sat_coord.spawn_specific_transmutation(pos)
		return "Estación de Forja Cuántica instanciada frente a la nave."
	return "Error al invocar forja cuántica."

static func spawn_slot_machine(main_game: Node2D) -> String:
	if not main_game:
		return "Error: main_game no disponible"
	var loot_coord = main_game.get("loot_coordinator")
	if loot_coord and loot_coord.has_method("spawn_slot_machine"):
		var pos: Vector2 = get_forward_spawn_position(main_game, 260.0)
		loot_coord.spawn_slot_machine(pos)
		return "Máquina tragamonedas arcade generada frente a la nave."
	return "Error al invocar tragamonedas."

static func spawn_chest(main_game: Node2D) -> String:
	if not main_game:
		return "Error: main_game no disponible"
	var loot_coord = main_game.get("loot_coordinator")
	if loot_coord and loot_coord.has_method("spawn_slot_chest"):
		var pos: Vector2 = get_forward_spawn_position(main_game, 180.0)
		loot_coord.spawn_slot_chest(pos)
		return "Cofre dorado de botín instanciado frente a la nave."
	return "Error al invocar cofre."

static func clear_all_bullets(tree: SceneTree) -> String:
	var bullet_srv: BulletServer = tree.root.get_node_or_null("BulletServer") as BulletServer if tree and tree.root else null
	if not bullet_srv and tree:
		var main_g = tree.get_first_node_in_group("main_game")
		if main_g and "bullet_server" in main_g:
			bullet_srv = main_g.bullet_server
	if bullet_srv:
		bullet_srv.bomb_clear_all()
		return "Todas las balas en pantalla han sido neutralizadas."
	return "BulletServer no encontrado."

static func kill_common_enemies(tree: SceneTree) -> String:
	if not tree:
		return "Árbol no disponible."
	var killed_count: int = 0
	for enemy in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.is_in_group("bosses") or enemy.is_in_group("boss") or enemy.is_in_group("rivals"):
			continue
		if enemy.has_method("take_damage"):
			var ctx := HitContext.create_direct_hit(999999.0)
			enemy.take_damage(ctx)
			killed_count += 1
		else:
			enemy.queue_free()
			killed_count += 1
	return "Eliminados %d enemigos comunes en el cuadrante." % killed_count

static func inject_weapon(main_game: Node2D, res_path: String, w_name: String) -> String:
	if not main_game or not is_instance_valid(main_game.get("player")):
		return "Jugador no encontrado."
	var p: Player = main_game.player
	var w_ctrl := p.get_node_or_null("WeaponController") as WeaponController
	if not w_ctrl:
		return "Error: WeaponController no encontrado."
	var res := load(res_path) as WeaponData
	if not res:
		return "Error cargando recurso: " + res_path
	var success := w_ctrl.add_weapon(res)
	if success:
		return "Arma equipada/subida de nivel: " + w_name
	return "Ranuras llenas. No se pudo equipar " + w_name

static func upgrade_all_weapons(main_game: Node2D) -> String:
	if not main_game or not is_instance_valid(main_game.get("player")):
		return "Jugador no disponible."
	var w_ctrl := main_game.player.get_node_or_null("WeaponController") as WeaponController
	if not w_ctrl:
		return "WeaponController no disponible."
	for inst in w_ctrl.equipped_weapons:
		w_ctrl.upgrade_weapon(inst.weapon_data.weapon_id)
	return "Todas las armas equipadas recibieron +1 nivel."

static func max_all_weapons(main_game: Node2D) -> String:
	if not main_game or not is_instance_valid(main_game.get("player")):
		return "Jugador no disponible."
	var w_ctrl := main_game.player.get_node_or_null("WeaponController") as WeaponController
	if not w_ctrl:
		return "WeaponController no disponible."
	for inst in w_ctrl.equipped_weapons:
		inst.level = inst.weapon_data.max_level
		inst.apply_level_modifiers()
	w_ctrl.weapons_updated.emit(w_ctrl.equipped_weapons)
	return "Todas las armas alcanzaron su nivel máximo."

static func jump_to_wave(main_game: Node2D, tree: SceneTree, target_wave: int) -> String:
	if not main_game:
		return "main_game no disponible."
	main_game.set("current_wave", target_wave)
	main_game.set("wave_timer", 45.0)
	main_game.set("_wave_encounter_pending", false)
	main_game.set("_wave_encounter_spawned_for_wave", 0)

	var hud = main_game.get("hud")
	if hud and hud.has_method("update_wave_status"):
		hud.update_wave_status(target_wave, 45.0, 0, 3)

	kill_common_enemies(tree)
	clear_all_bullets(tree)
	return "Salto efectuado a Oleada %d." % target_wave
