class_name CombatModalCoordinator
extends Node

## Coordinador modular de modales y menús de combate.
## Gestiona la cola secuencial de LevelUp, Tienda Satélite, Selección de Arcanas,
## Menú de Pausa y comprobaciones de bloqueo de combate.

signal modal_opened(modal_name: StringName)
signal modal_closed(modal_name: StringName)
signal resume_encounters_requested()

var main_game: Node = null
var player: CharacterBody2D = null

# Referencias a modales (CanvasLayer / Control)
var level_up_modal: Node = null
var satellite_shop: Node = null
var arcana_modal: Node = null
var pause_menu: Node = null
var game_over_modal: Node = null
var character_stats_overlay: Node = null
var slot_machine_modal: Node = null
var slot_machine_reward_modal: Node = null
var chest_reward_modal: Node = null
var transmutation_modal: Node = null

# Estado de colas pendientes
var pending_arcana_picks: int = 0
var pending_satellite_credits: int = -1
var pending_satellite_index: int = -1
var pending_rival_for_dialogue: Node2D = null

func setup(p_main_game: Node, p_player: CharacterBody2D) -> void:
	main_game = p_main_game
	player = p_player

func is_pause_menu_active() -> bool:
	return pause_menu != null and pause_menu.visible

func is_satellite_shop_active() -> bool:
	return satellite_shop != null and satellite_shop.visible

func is_transmutation_active() -> bool:
	return transmutation_modal != null and transmutation_modal.visible

func is_chest_reward_active() -> bool:
	return chest_reward_modal != null and chest_reward_modal.visible

func is_arcana_modal_active() -> bool:
	return arcana_modal != null and (arcana_modal.visible or ("is_active" in arcana_modal and arcana_modal.is_active))

func is_level_up_modal_active() -> bool:
	return level_up_modal != null and level_up_modal.visible

func is_character_stats_active() -> bool:
	return character_stats_overlay != null and (("is_open" in character_stats_overlay and character_stats_overlay.is_open) or character_stats_overlay.visible)

func is_game_over_active() -> bool:
	return game_over_modal != null and (game_over_modal.visible or ("is_active" in game_over_modal and game_over_modal.is_active))

func is_upgrade_or_shop_modal_active() -> bool:
	if is_satellite_shop_active() or is_transmutation_active() or is_chest_reward_active() or is_level_up_modal_active() or is_arcana_modal_active():
		return true
	if is_pause_menu_active() or is_game_over_active() or is_character_stats_active():
		return true
	if slot_machine_modal and slot_machine_modal.visible:
		return true
	if slot_machine_reward_modal and slot_machine_reward_modal.visible:
		return true
	return false

func has_pending_upgrades() -> bool:
	if level_up_modal and level_up_modal.has_method("has_pending_levels") and level_up_modal.has_pending_levels():
		return true
	if arcana_modal and arcana_modal.has_method("has_pending_arcanas") and arcana_modal.get("pending_arcanas_queue") > 0:
		return true
	if pending_arcana_picks > 0:
		return true
	if pending_satellite_credits >= 0:
		return true
	return false

func is_any_combat_modal_active() -> bool:
	if main_game and main_game.has_method("is_dialogue_active") and main_game.is_dialogue_active():
		return true
	if is_upgrade_or_shop_modal_active():
		return true
	if main_game:
		var reset_overlay = main_game.get_node_or_null("HoldToResetOverlay")
		if reset_overlay and (reset_overlay.visible or ("current_hold" in reset_overlay and reset_overlay.current_hold > 0.0)):
			return true
	var vp := get_viewport()
	if vp:
		var focused := vp.gui_get_focus_owner()
		if focused and focused.is_visible_in_tree():
			var p: Node = focused.get_parent()
			var in_hidden_layer: bool = false
			while p:
				if p is CanvasLayer and not (p as CanvasLayer).visible:
					in_hidden_layer = true
					break
				p = p.get_parent()
			if not in_hidden_layer:
				return true
	return false

func notify_menu_closed(duration: float = 0.35) -> void:
	if is_instance_valid(player) and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(duration)

func restore_combat_modal_focus() -> void:
	if is_pause_menu_active() and pause_menu.has_method("restore_focus"):
		pause_menu.restore_focus()
	elif is_arcana_modal_active() and arcana_modal.has_method("restore_focus"):
		arcana_modal.restore_focus()
	elif is_level_up_modal_active() and level_up_modal.has_method("restore_focus"):
		level_up_modal.restore_focus()
	elif is_satellite_shop_active() and satellite_shop.has_method("restore_focus"):
		satellite_shop.restore_focus()

func on_level_up_requested(level: int) -> void:
	if not level_up_modal:
		return
	if is_satellite_shop_active() or (main_game and main_game.has_method("is_dialogue_active") and main_game.is_dialogue_active()) or is_arcana_modal_active() or (main_game and main_game.has_method("is_cinematic_or_death_active") and main_game.is_cinematic_or_death_active()):
		if level_up_modal.has_method("queue_level_up"):
			level_up_modal.queue_level_up(level)
	else:
		if level_up_modal.has_method("show_level_up"):
			level_up_modal.show_level_up(level)
	if main_game and main_game.has_method("save_current_run_state"):
		main_game.save_current_run_state()

func on_level_up_modal_closed() -> void:
	modal_closed.emit(&"level_up")
	_step_next_modal()

func on_satellite_shop_closed() -> void:
	modal_closed.emit(&"satellite_shop")
	_step_next_modal()

func on_arcana_modal_closed() -> void:
	modal_closed.emit(&"arcana")
	_step_next_modal()

func on_arcana_orb_collected(_orb: Node2D) -> void:
	if not arcana_modal:
		return
	if is_any_combat_modal_active() and not is_arcana_modal_active():
		if arcana_modal.has_method("queue_arcana"):
			arcana_modal.queue_arcana()
		else:
			pending_arcana_picks += 1
	elif is_arcana_modal_active():
		if arcana_modal.has_method("queue_arcana"):
			arcana_modal.queue_arcana()
		else:
			pending_arcana_picks += 1
	else:
		if arcana_modal.has_method("show_arcana_selection"):
			arcana_modal.show_arcana_selection(player)

func open_next_pending_arcana() -> void:
	if arcana_modal and is_instance_valid(player) and arcana_modal.has_method("show_arcana_selection"):
		arcana_modal.show_arcana_selection(player)

func _step_next_modal() -> void:
	if arcana_modal and arcana_modal.has_method("has_pending_arcanas") and arcana_modal.get("pending_arcanas_queue") > 0:
		arcana_modal.call("show_next_arcana")
	elif pending_arcana_picks > 0:
		pending_arcana_picks -= 1
		open_next_pending_arcana()
	elif level_up_modal and level_up_modal.has_method("has_pending_levels") and level_up_modal.has_pending_levels():
		level_up_modal.call("show_next_level_up")
	elif pending_satellite_credits >= 0 and satellite_shop:
		var creds: int = pending_satellite_credits
		var sat_idx: int = pending_satellite_index
		pending_satellite_credits = -1
		pending_satellite_index = -1
		if satellite_shop.has_method("open_shop"):
			satellite_shop.open_shop(creds, sat_idx)
	elif not is_any_combat_modal_active():
		if main_game and main_game.get_tree():
			main_game.get_tree().paused = false
		resume_encounters_requested.emit()
