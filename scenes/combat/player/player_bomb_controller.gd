class_name PlayerBombController
extends RefCounted

## PlayerBombController.gd
## Controlador táctico de bombas del jugador y supresor de detonaciones accidentales:
## - Gestiona el conteo de bombas (hasta un tope de 5).
## - Detecta si hay cualquier menú, modal o diálogo abierto en el árbol.
## - Implementa temporizador de gracia tras cerrar menús (evita que ESPACIO detone una bomba).
## - Detona la bomba táctica, limpiando proyectiles con BulletServer y generando VFX.

signal bomb_used(remaining_count: int)

var bomb_count: int = 2
var menu_close_suppress_timer: float = 0.0
var was_bomb_pressed_during_menu: bool = false

var bomb_shockwave_scene: PackedScene = preload("res://scenes/combat/player/bomb_shockwave_vfx.tscn")

func suppress_bomb_input(duration: float = 0.35) -> void:
	menu_close_suppress_timer = maxf(menu_close_suppress_timer, duration)
	was_bomb_pressed_during_menu = true

func update_suppression(delta: float) -> void:
	if menu_close_suppress_timer > 0.0:
		menu_close_suppress_timer = maxf(0.0, menu_close_suppress_timer - delta)
		if menu_close_suppress_timer <= 0.0:
			was_bomb_pressed_during_menu = false

func is_any_menu_or_modal_active(player: Node2D) -> bool:
	if not player or not player.is_inside_tree():
		return false
	var parent_node: Node = player.get_parent()
	if parent_node:
		if parent_node.has_method("is_any_combat_modal_active") and parent_node.is_any_combat_modal_active():
			return true
		if parent_node.has_method("is_pause_menu_active") and parent_node.is_pause_menu_active():
			return true
		if parent_node.has_method("is_level_up_modal_active") and parent_node.is_level_up_modal_active():
			return true
		if parent_node.has_method("is_satellite_shop_active") and parent_node.is_satellite_shop_active():
			return true
		if parent_node.has_method("is_character_stats_active") and parent_node.is_character_stats_active():
			return true
		if parent_node.has_method("is_dialogue_active") and parent_node.is_dialogue_active():
			return true

	var tree: SceneTree = player.get_tree()
	if tree:
		for arc_modal in tree.get_nodes_in_group("arcana_selection_modal"):
			if is_instance_valid(arc_modal) and arc_modal is CanvasItem and (arc_modal as CanvasItem).visible:
				return true
		for swap_modal in tree.get_nodes_in_group("weapon_swap_modal"):
			if is_instance_valid(swap_modal) and swap_modal is CanvasItem and (swap_modal as CanvasItem).visible:
				return true
		if tree.root:
			var dialogic: Node = tree.root.get_node_or_null("Dialogic")
			if dialogic and "current_timeline" in dialogic and dialogic.current_timeline != null:
				return true

	return false

func can_trigger_bomb(player: Node2D) -> bool:
	if not player or not player.is_inside_tree():
		return false

	var tree: SceneTree = player.get_tree()
	var debug_mgr: Node = tree.root.get_node_or_null("DebugManager") if tree and tree.root else null
	var inf_consumables: bool = debug_mgr and debug_mgr.has_method("is_infinite_consumables_active") and debug_mgr.is_infinite_consumables_active()
	if bomb_count <= 0 and not inf_consumables:
		return false
	if tree and tree.paused:
		return false
	if menu_close_suppress_timer > 0.0:
		return false
	if was_bomb_pressed_during_menu:
		return false
	if is_any_menu_or_modal_active(player):
		return false
	return true

func execute_bomb(player: CharacterBody2D, bullet_server: BulletServer) -> void:
	if not can_trigger_bomb(player):
		return

	var tree: SceneTree = player.get_tree()
	var debug_mgr: Node = tree.root.get_node_or_null("DebugManager") if tree and tree.root else null
	var inf_consumables: bool = debug_mgr and debug_mgr.has_method("is_infinite_consumables_active") and debug_mgr.is_infinite_consumables_active()
	if not inf_consumables:
		bomb_count -= 1
	bomb_used.emit(bomb_count)

	var audio_mgr: Node = tree.root.get_node_or_null("AudioManager") if tree and tree.root else null
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("bomb")

	if bullet_server:
		bullet_server.bomb_clear_all()

	spawn_bomb_vfx(tree, player.global_position)

func add_bombs(player: CharacterBody2D, bullet_server: BulletServer, amount: int = 1) -> bool:
	const MAX_BOMBS: int = 5
	if bomb_count < MAX_BOMBS:
		bomb_count = mini(MAX_BOMBS, bomb_count + amount)
		bomb_used.emit(bomb_count)
		return true
	else:
		# Límite alcanzado: detonación táctica inmediata
		var tree: SceneTree = player.get_tree()
		var audio_mgr: Node = tree.root.get_node_or_null("AudioManager") if tree and tree.root else null
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("bomb")
		if bullet_server:
			bullet_server.bomb_clear_all()
		spawn_bomb_vfx(tree, player.global_position)
		return false

func spawn_bomb_vfx(tree: SceneTree, at_position: Vector2) -> void:
	if not bomb_shockwave_scene:
		return
	var vfx: Node2D = bomb_shockwave_scene.instantiate() as Node2D
	if vfx:
		if vfx.has_method("setup"):
			vfx.setup(at_position)
		else:
			vfx.global_position = at_position
		var spawn_parent: Node = tree.current_scene if tree and tree.current_scene else null
		if spawn_parent:
			spawn_parent.add_child(vfx)
