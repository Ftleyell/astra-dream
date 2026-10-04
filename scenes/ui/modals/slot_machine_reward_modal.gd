class_name SlotMachineRewardModal
extends CanvasLayer

const WeaponSwapModalClass = preload("res://scenes/ui/modals/weapon_swap_modal.gd")

signal item_claimed(item: ItemData)
signal item_rejected(compensation_credits: int)
signal modal_closed()

var current_chest: Node2D = null
var current_player: Player = null
var current_item: ItemData = null
var current_weapon: WeaponData = null
var current_pilot_name: String = ""

const RECYCLE_CREDITS: int = 100
const RECYCLE_WEAPON_CREDITS: int = 250

var _panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _item_name_label: Label
var _item_desc_label: Label
var _item_icon: TextureRect
var _rarity_label: Label
var _take_button: Button
var _reject_button: Button

func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("slot_machine_reward_modal")
	_build_ui()
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			if _take_button and is_instance_valid(_take_button) and not _take_button.disabled:
				_on_take_pressed()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			if _reject_button and is_instance_valid(_reject_button) and not _reject_button.disabled:
				_on_reject_pressed()
				get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 380)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.12, 0.96)
	sb.border_color = Color(1.0, 0.84, 0.0, 1.0) # Gold
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "🎁 RECOMPENSA DEL COFRE MISTERIOSO"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2, 1.0))
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "La máquina tragamonedas detonó dejando este ítem de alta tecnología."
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 13)
	_subtitle_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85, 1.0))
	vbox.add_child(_subtitle_label)

	# Item Card Frame
	var card_frame := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.12, 0.09, 0.22, 0.9)
	csb.border_color = Color(0.8, 0.6, 1.0, 0.6)
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(8)
	csb.content_margin_left = 20
	csb.content_margin_right = 20
	csb.content_margin_top = 16
	csb.content_margin_bottom = 16
	card_frame.add_theme_stylebox_override("panel", csb)
	vbox.add_child(card_frame)

	var card_vbox := VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 8)
	card_frame.add_child(card_vbox)

	var icon_center := CenterContainer.new()
	card_vbox.add_child(icon_center)

	_item_icon = TextureRect.new()
	_item_icon.custom_minimum_size = Vector2(64, 64)
	_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_center.add_child(_item_icon)

	_item_name_label = Label.new()
	_item_name_label.text = "Nombre del Ítem"
	_item_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_name_label.add_theme_font_size_override("font_size", 18)
	_item_name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	card_vbox.add_child(_item_name_label)

	_rarity_label = Label.new()
	_rarity_label.text = "RARO"
	_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rarity_label.add_theme_font_size_override("font_size", 12)
	_rarity_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 1.0))
	card_vbox.add_child(_rarity_label)

	_item_desc_label = Label.new()
	_item_desc_label.text = "+10% Daño Base y Cadencia."
	_item_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_desc_label.add_theme_font_size_override("font_size", 14)
	_item_desc_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1.0))
	card_vbox.add_child(_item_desc_label)

	# Action Buttons
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_box)

	_take_button = Button.new()
	_take_button.text = "✨ [1] TOMAR ÍTEM"
	_take_button.custom_minimum_size = Vector2(200, 46)
	UIFocusHelper.apply_cyber_focus(_take_button)
	_take_button.pressed.connect(_on_take_pressed)
	btn_box.add_child(_take_button)

	_reject_button = Button.new()
	_reject_button.text = "♻️ [2] RECHAZAR (+%d Créditos)" % RECYCLE_CREDITS
	_reject_button.custom_minimum_size = Vector2(230, 46)
	UIFocusHelper.apply_cyber_focus(_reject_button)
	_reject_button.pressed.connect(_on_reject_pressed)
	btn_box.add_child(_reject_button)

func setup(item: ItemData, p_player: Player) -> void:
	current_item = item
	current_player = p_player
	if not _panel:
		_build_ui()
	_populate_item_ui()

func show_reward(chest: Node2D, player: Player) -> void:
	current_chest = chest
	current_player = player
	current_weapon = null
	current_pilot_name = ""

	# Pick random item from canonical catalog
	var catalog := ItemPoolManager.create_canonical_stat_items()
	if not catalog.is_empty():
		current_item = catalog[randi() % catalog.size()]

	if not _panel:
		_build_ui()
	_populate_item_ui()
	show()
	get_tree().paused = true
	if _take_button:
		_take_button.grab_focus()

func show_weapon_reward(pickup: Node2D, player: Player, weapon: WeaponData, pilot_name: String) -> void:
	current_chest = pickup
	current_player = player
	current_weapon = weapon
	current_item = null
	current_pilot_name = pilot_name

	if not _panel:
		_build_ui()
	_populate_weapon_ui()
	show()
	get_tree().paused = true
	if _take_button:
		_take_button.grab_focus()

func _populate_weapon_ui() -> void:
	if not current_weapon:
		return
	if _title_label:
		var p_name := current_pilot_name.to_upper() if not current_pilot_name.is_empty() else "RIVAL"
		_title_label.text = "🎁 BOTÍN DE COMBATE: PILOTO %s" % p_name
	if _subtitle_label:
		_subtitle_label.text = "Cápsula de armamento insignia recuperada tras el combate."
	if _item_name_label:
		_item_name_label.text = current_weapon.name.to_upper() if "name" in current_weapon and not current_weapon.name.is_empty() else str(current_weapon.weapon_id).to_upper()
	if _item_desc_label:
		_item_desc_label.text = current_weapon.description if "description" in current_weapon else "Arma insignia de tecnología avanzada."
	if _item_icon:
		if current_weapon.icon:
			_item_icon.texture = current_weapon.icon
			_item_icon.show()
		else:
			_item_icon.hide()
	if _rarity_label:
		_rarity_label.text = "INSIGNIA MILITAR"
		_rarity_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	if _take_button:
		_take_button.text = "✨ [1] EQUIPAR / MEJORAR"
	if _reject_button:
		_reject_button.text = "♻️ [2] RECICLAR (+%d Créditos)" % RECYCLE_WEAPON_CREDITS

func _populate_item_ui() -> void:
	if not current_item:
		return
	if _title_label:
		_title_label.text = "🎁 RECOMPENSA DEL COFRE MISTERIOSO"
	if _subtitle_label:
		_subtitle_label.text = "La máquina tragamonedas detonó dejando este ítem de alta tecnología."
	if _take_button:
		_take_button.text = "✨ [1] TOMAR ÍTEM"
	if _reject_button:
		_reject_button.text = "♻️ [2] RECHAZAR (+%d Créditos)" % RECYCLE_CREDITS

	if _item_name_label:
		_item_name_label.text = current_item.item_name
	if _item_desc_label:
		_item_desc_label.text = current_item.description
	if _item_icon:
		if current_item.icon:
			_item_icon.texture = current_item.icon
			_item_icon.show()
		else:
			_item_icon.hide()

	var r_text := "COMÚN"
	var r_color := Color(0.7, 0.7, 0.7, 1.0)
	match current_item.rarity:
		Enums.Rarity.UNCOMMON:
			r_text = "POCO COMÚN"
			r_color = Color(0.2, 0.8, 0.4, 1.0)
		Enums.Rarity.RARE:
			r_text = "RARO"
			r_color = Color(0.2, 0.6, 1.0, 1.0)
		Enums.Rarity.EPIC:
			r_text = "ÉPICO"
			r_color = Color(0.8, 0.3, 1.0, 1.0)
		Enums.Rarity.LEGENDARY:
			r_text = "LEGENDARIO"
			r_color = Color(1.0, 0.8, 0.1, 1.0)

	_rarity_label.text = r_text
	_rarity_label.add_theme_color_override("font_color", r_color)

func _on_take_pressed() -> void:
	if current_weapon and current_player:
		var w_ctrl := current_player.get_node_or_null("WeaponController") as WeaponController
		if w_ctrl:
			if w_ctrl.has_method("is_full") and w_ctrl.is_full() and not w_ctrl.get_weapon_instance(current_weapon.weapon_id):
				_open_weapon_swap_modal(w_ctrl, current_weapon)
				return
			w_ctrl.add_weapon(current_weapon)
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx(&"upgrade_obtained")
	elif current_item and current_player:
		if current_player.inventory:
			var player_origin: String = "BOTÍN DE RIVAL" if not current_pilot_name.is_empty() else "COFRE MISTERIOSO"
			current_player.inventory.add_item(current_item, 1, player_origin)
		if current_player.stats and current_item.has_method("apply_to_stats"):
			current_item.apply_to_stats(current_player.stats)
		item_claimed.emit(current_item)

	_close_and_cleanup()

func _open_weapon_swap_modal(w_ctrl: WeaponController, w_data: WeaponData) -> void:
	var swap_modal := WeaponSwapModalClass.new()
	get_tree().root.add_child(swap_modal)
	swap_modal.prompt_swap(current_player, w_data,
		func(_idx, _new_w):
			_close_and_cleanup()
			swap_modal.queue_free(),
		func(_discarded_w):
			_close_and_cleanup()
			swap_modal.queue_free()
	)
	hide()

func _on_reject_pressed() -> void:
	if current_player:
		var credits: int = RECYCLE_WEAPON_CREDITS if current_weapon else RECYCLE_CREDITS
		current_player.run_credits += credits
		item_rejected.emit(credits)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("update_credits"):
			hud.update_credits(current_player.run_credits)

	_close_and_cleanup()

func _close_and_cleanup() -> void:
	if current_chest and is_instance_valid(current_chest):
		if current_chest.has_method("open_and_destroy"):
			current_chest.open_and_destroy()
		else:
			current_chest.queue_free()
	hide()
	var tree := get_tree()
	if tree:
		tree.paused = false
	modal_closed.emit()
