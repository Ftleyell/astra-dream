class_name LevelUpModal
extends BaseModal

signal card_chosen(card: StatCardData)

const LevelUpStatsInspector = preload("res://scenes/ui/level_up/components/level_up_stats_inspector.gd")
const LevelUpCardBuilder = preload("res://scenes/ui/level_up/components/level_up_card_builder.gd")
const LevelUpRewardGenerator = preload("res://scenes/ui/level_up/components/level_up_reward_generator.gd")
const LevelUpRewardOption = preload("res://scenes/ui/level_up/components/level_up_reward_option.gd")

@export var stat_deck_manager: StatDeckManager
@export var player: Player

@onready var modal_panel: Panel = $Panel
@onready var cards_container: VBoxContainer = find_child("CardsContainer", true, false) as VBoxContainer
@onready var level_label: Label = $Panel/VBoxContainer/Title
@onready var stats_side_panel: PanelContainer = find_child("StatsSidePanel", true, false) as PanelContainer
@onready var stats_header_label: Label = find_child("StatsHeader", true, false) as Label
@onready var pilot_info_label: Label = find_child("PilotInfo", true, false) as Label
@onready var stats_list_container: VBoxContainer = find_child("StatsList", true, false) as VBoxContainer

var current_offered_cards: Array = []
var select_buttons: Array[Button] = []
var card_panels: Array[PanelContainer] = []
var card_tier_colors: Array[Color] = []
var current_selected_idx: int = 0

var pending_levels_queue: Array[int] = []
var is_presenting_level: bool = false
var current_level_shown: int = 1

var stats_inspector: LevelUpStatsInspector = null

var stat_card_ui_entries: Dictionary:
	get:
		var dock := _get_hud_stats_dock()
		if dock and "_stat_ui_entries" in dock and not dock._stat_ui_entries.is_empty():
			return dock._stat_ui_entries
		return stats_inspector.stat_card_ui_entries if stats_inspector else {}


func _ready() -> void:
	modal_token = &"level_up"
	mouse_grace_period = 0.3
	super._ready()
	if stats_list_container:
		stats_inspector = LevelUpStatsInspector.new()
		stats_inspector.setup(stats_list_container, stats_header_label, pilot_info_label)
	_apply_modal_styles()

	if stat_deck_manager:
		stat_deck_manager.cards_offered.connect(_on_cards_offered)


func _apply_modal_styles() -> void:
	var modal_style := StyleBoxFlat.new()
	modal_style.bg_color = Color(0.04, 0.06, 0.1, 0.96)
	modal_style.set_border_width_all(2)
	modal_style.border_color = Color(0.2, 0.6, 1.0, 0.7)
	modal_style.set_corner_radius_all(12)
	modal_style.set_content_margin_all(16.0)
	if modal_panel:
		modal_panel.add_theme_stylebox_override("panel", modal_style)

	if stats_side_panel:
		var side_style := StyleBoxFlat.new()
		side_style.bg_color = Color(0.03, 0.04, 0.07, 0.92)
		side_style.set_border_width_all(1)
		side_style.border_color = Color(0.2, 0.5, 0.8, 0.5)
		side_style.set_corner_radius_all(8)
		stats_side_panel.add_theme_stylebox_override("panel", side_style)


func show_level_up(level: int) -> void:
	var parent_game = get_parent()
	var shop_active: bool = (parent_game and parent_game.has_method("is_satellite_shop_active") and parent_game.is_satellite_shop_active())
	var diag_active: bool = (parent_game and parent_game.has_method("is_dialogue_active") and parent_game.is_dialogue_active())
	var arcana_active: bool = (parent_game and parent_game.has_method("is_arcana_modal_active") and parent_game.is_arcana_modal_active())
	var pause_active: bool = (parent_game and parent_game.has_method("is_pause_menu_active") and parent_game.is_pause_menu_active())
	var anim_active: bool = (parent_game and parent_game.has_method("is_cinematic_or_death_active") and parent_game.is_cinematic_or_death_active())
	var death_seq_active: bool = bool(CinematicDeathSequence.is_sequence_active)

	if is_presenting_level or visible or shop_active or diag_active or arcana_active or pause_active or anim_active or death_seq_active:
		if not pending_levels_queue.has(level) and level != current_level_shown:
			pending_levels_queue.append(level)
		_update_header_title()
		return

	_present_level(level)


func queue_level_up(level: int) -> void:
	if not pending_levels_queue.has(level) and level != current_level_shown:
		pending_levels_queue.append(level)
	_update_header_title()


func has_pending_levels() -> bool:
	return not pending_levels_queue.is_empty() or is_presenting_level


func show_next_level_up() -> void:
	if is_presenting_level and visible:
		return
	var parent_game = get_parent()
	if parent_game and parent_game.has_method("is_cinematic_or_death_active") and parent_game.is_cinematic_or_death_active():
		return
	if CinematicDeathSequence.is_sequence_active:
		return
	if not pending_levels_queue.is_empty():
		var next_level: int = pending_levels_queue.pop_front()
		_present_level(next_level)


func clear_pending_levels() -> void:
	pending_levels_queue.clear()
	is_presenting_level = false
	close_modal()


func _update_header_title() -> void:
	if not level_label:
		return
	var pending_count: int = pending_levels_queue.size()
	if pending_count > 0:
		level_label.text = "¡SUBIDA DE NIVEL %d! (+%d PENDIENTES) - SELECCIONA UNA MEJORA" % [current_level_shown, pending_count]
	else:
		level_label.text = "¡SUBIDA DE NIVEL %d! SELECCIONA UNA MEJORA" % current_level_shown
	level_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))


func _present_level(level: int) -> void:
	is_presenting_level = true
	current_level_shown = level

	_update_header_title()
	open_modal()

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(player) and get_parent():
		player = get_parent().get_node_or_null("Player") as Player

	if player:
		var char_id: StringName = &"nova"
		if "character_data" in player and player.character_data:
			char_id = player.character_data.character_id
		elif SaveManager.has_method("get_selected_character"):
			char_id = SaveManager.get_selected_character()

		var active_tomes: Array[StringName] = []
		if SaveManager.has_method("get_character_active_tomes"):
			active_tomes = SaveManager.get_character_active_tomes(char_id)

		var options: Array[LevelUpRewardOption] = LevelUpRewardGenerator.generate_reward_options(player, active_tomes, 3)
		if not options.is_empty():
			_display_reward_options(options)
			return

	if stat_deck_manager and player:
		stat_deck_manager.offer_cards(player.stats, level, 3)


func _display_reward_options(options: Array[LevelUpRewardOption]) -> void:
	current_offered_cards = options
	select_buttons.clear()
	card_panels.clear()
	card_tier_colors.clear()
	current_selected_idx = 0

	if cards_container:
		for child in cards_container.get_children():
			cards_container.remove_child(child)
			child.queue_free()

		for i in range(options.size()):
			var opt: LevelUpRewardOption = options[i]
			var on_chosen := Callable(self, "_select_card")
			var on_focused := Callable(self, "_update_card_selection")
			var is_locked := Callable(self, "_is_mouse_locked")
			var card_info: Dictionary = LevelUpCardBuilder.build_reward_option_card(opt, i, on_chosen, on_focused, is_locked)
			var card_panel: PanelContainer = card_info["panel"]
			var select_btn: Button = card_info["button"]
			var tier_color: Color = card_info["tier_color"]
			card_panels.append(card_panel)
			card_tier_colors.append(tier_color)
			select_buttons.append(select_btn)
			cards_container.add_child(card_panel)

	call_deferred("_update_card_selection", 0)


func _refresh_player_stats_display(level_override: int = -1) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(player) and get_parent():
		player = get_parent().get_node_or_null("Player") as Player

	var dock := _get_hud_stats_dock()
	if dock and is_instance_valid(player):
		dock.refresh_stats(player)
	elif stats_inspector and is_instance_valid(player):
		stats_inspector.refresh_player_stats(player, level_override)


func _highlight_target_stat(target_stat: StringName, card: StatCardData = null) -> void:
	var dock := _get_hud_stats_dock()
	if dock:
		dock.preview_stat_delta(target_stat, card)
	elif stats_inspector:
		stats_inspector.highlight_target_stat(target_stat, card)


func restore_focus() -> void:
	if current_selected_idx >= 0 and current_selected_idx < select_buttons.size():
		var btn: Button = select_buttons[current_selected_idx]
		if is_instance_valid(btn):
			btn.grab_focus()
	elif not select_buttons.is_empty() and is_instance_valid(select_buttons[0]):
		select_buttons[0].grab_focus()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Si el Menú de Pausa está abierto por encima, ignorar cualquier entrada
	var parent_game = get_parent()
	if parent_game and parent_game.has_method("is_pause_menu_active") and parent_game.is_pause_menu_active():
		return
	var root_pm = get_tree().root.find_child("PauseMenu", true, false)
	if root_pm and root_pm.visible:
		return

	# Si el período de gracia contra spam de clicks está activo, bloquear clicks del ratón
	if event is InputEventMouseButton and event.is_pressed() and _mouse_lockout_active:
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_1, KEY_KP_1:
				_select_card_by_index(0)
				get_viewport().set_input_as_handled()
				return
			KEY_2, KEY_KP_2:
				_select_card_by_index(1)
				get_viewport().set_input_as_handled()
				return
			KEY_3, KEY_KP_3:
				_select_card_by_index(2)
				get_viewport().set_input_as_handled()
				return
			KEY_A, KEY_LEFT, KEY_W, KEY_UP:
				_change_selection(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_D, KEY_RIGHT, KEY_S, KEY_DOWN:
				_change_selection(1)
				get_viewport().set_input_as_handled()
				return
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_confirm_current_selection()
				get_viewport().set_input_as_handled()
				return


func _change_selection(direction: int) -> void:
	if card_panels.is_empty():
		return
	var new_idx: int = (current_selected_idx + direction) % card_panels.size()
	if new_idx < 0:
		new_idx += card_panels.size()
	if new_idx != current_selected_idx:
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("ui_click")
	_update_card_selection(new_idx)


func _update_card_selection(idx: int) -> void:
	if idx < 0 or idx >= card_panels.size():
		return
	current_selected_idx = idx

	for i in range(card_panels.size()):
		var panel_node: PanelContainer = card_panels[i]
		var color: Color = card_tier_colors[i]
		var btn: Button = select_buttons[i] if i < select_buttons.size() else null
		var is_selected: bool = (i == current_selected_idx)
		LevelUpCardBuilder.apply_card_selection_style(panel_node, btn, color, is_selected)

	if idx < current_offered_cards.size():
		var card_item: Variant = current_offered_cards[idx]
		if card_item is LevelUpRewardOption:
			_highlight_target_stat((card_item as LevelUpRewardOption).target_stat, null)
		elif card_item is StatCardData:
			_highlight_target_stat((card_item as StatCardData).target_stat, card_item as StatCardData)


func _confirm_current_selection() -> void:
	_select_card_by_index(current_selected_idx)


func _select_card_by_index(idx: int) -> void:
	if idx >= 0 and idx < current_offered_cards.size():
		_select_card(current_offered_cards[idx])


func _on_cards_offered(cards: Array[StatCardData], _cost: int) -> void:
	current_offered_cards = cards
	select_buttons.clear()
	card_panels.clear()
	card_tier_colors.clear()
	current_selected_idx = 0

	if cards_container:
		for child in cards_container.get_children():
			cards_container.remove_child(child)
			child.queue_free()

		for i in range(cards.size()):
			_create_stat_card_ui(cards[i], i)

	call_deferred("_update_card_selection", 0)


func _create_stat_card_ui(card: StatCardData, index: int) -> void:
	var on_chosen := Callable(self, "_select_card")
	var on_focused := Callable(self, "_update_card_selection")
	var is_locked := Callable(self, "_is_mouse_locked")

	var card_info: Dictionary = LevelUpCardBuilder.build_stat_card(card, index, on_chosen, on_focused, is_locked)
	var card_panel: PanelContainer = card_info["panel"]
	var select_btn: Button = card_info["button"]
	var tier_color: Color = card_info["tier_color"]

	card_panels.append(card_panel)
	card_tier_colors.append(tier_color)
	select_buttons.append(select_btn)

	if cards_container:
		cards_container.add_child(card_panel)


func _is_mouse_locked() -> bool:
	return _mouse_lockout_active


func _get_tier_info(tier: Enums.Tier) -> Dictionary:
	return LevelUpCardBuilder.get_tier_info(tier)


func _select_card(card: Variant) -> void:
	if card is LevelUpRewardOption:
		var opt := card as LevelUpRewardOption
		match opt.type:
			LevelUpRewardOption.OptionType.WEAPON_NEW:
				if player and "weapon_controller" in player and player.weapon_controller:
					player.weapon_controller.add_weapon(opt.weapon_data)
			LevelUpRewardOption.OptionType.WEAPON_UPGRADE:
				if player and "weapon_controller" in player and player.weapon_controller:
					player.weapon_controller.upgrade_weapon(opt.weapon_data.weapon_id, opt.tier)
			LevelUpRewardOption.OptionType.TOME_NEW, LevelUpRewardOption.OptionType.TOME_UPGRADE:
				if player and "tome_controller" in player and player.tome_controller:
					player.tome_controller.equip_or_upgrade_tome(opt.tome_data)
		_refresh_player_stats_display(current_level_shown)
	elif card is StatCardData:
		if stat_deck_manager and player:
			stat_deck_manager.apply_card_to_stats(card as StatCardData, player.stats)
			player.chosen_stat_cards.append(card)
			_refresh_player_stats_display(current_level_shown)

	if player and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(0.4)

	card_chosen.emit(card)

	if not pending_levels_queue.is_empty():
		var next_level: int = pending_levels_queue.pop_front()
		_present_level(next_level)
		return

	is_presenting_level = false
	close_modal()
	var parent_game = get_parent()
	if parent_game and parent_game.has_method("notify_menu_closed"):
		parent_game.notify_menu_closed(0.4)
	if parent_game and parent_game.has_method("restore_combat_modal_focus") and parent_game.has_method("is_any_combat_modal_active") and parent_game.is_any_combat_modal_active():
		parent_game.restore_combat_modal_focus()

	if parent_game and parent_game.has_method("_on_level_up_modal_closed"):
		parent_game._on_level_up_modal_closed()
