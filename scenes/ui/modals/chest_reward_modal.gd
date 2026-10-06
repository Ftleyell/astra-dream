class_name ChestRewardModal
extends BaseModal

## ChestRewardModal.gd
## Modal táctico de selección de 3 ítems desplegado al abrir un cofre espacial.
## Pausa el combate mediante BaseModal/PauseArbitrator, exhibe 3 cartas interactivas
## y permite al jugador elegir 1 con ratón o atajos numéricos [1, 2, 3].

signal item_selected(chosen_item: ItemData)
signal modal_closed()

var _panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _free_badge_label: Label
var _cards_container: VBoxContainer

var _current_candidates: Array[ItemData] = []
var _current_player: Player = null
var _selection_callback: Callable = Callable()
var _card_buttons: Array[Button] = []
var _paid_cost: int = 0
var _skip_button: Button = null

func _ready() -> void:
	modal_token = &"chest_reward"
	layer = 125
	add_to_group("chest_reward_modal")
	_build_ui()
	super._ready()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			_select_index(0)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			if _current_candidates.size() >= 2:
				_select_index(1)
			else:
				# Si solo hay 1 ítem en oferta, presionar 2 rechaza la recompensa
				skip_and_recycle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
			if _current_candidates.size() >= 3:
				_select_index(2)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_4 or event.keycode == KEY_KP_4 or event.keycode == KEY_ESCAPE:
			skip_and_recycle()
			get_viewport().set_input_as_handled()

func _build_ui() -> void:
	# 1. Fondo atenuado translúcido
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.02, 0.05, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 2. Contenedor centrado
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# 3. Panel principal
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 480)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.09, 0.96)
	style.set_border_width_all(2)
	style.border_color = Color(0.1, 0.8, 1.0, 0.85)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(16.0)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	# Encabezado
	_title_label = Label.new()
	_title_label.text = "★ SELECCIÓN DE RECOMPENSA TÁCTICA ★"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 17)
	_title_label.modulate = Color(0.3, 0.95, 1.0, 1.0)
	vbox.add_child(_title_label)

	_free_badge_label = Label.new()
	_free_badge_label.text = "◆ ¡APERTURA CUÁNTICA GRATUITA! (Llave Activada) ◆"
	_free_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_free_badge_label.add_theme_font_size_override("font_size", 12)
	_free_badge_label.modulate = Color(0.3, 1.0, 0.6, 1.0)
	_free_badge_label.hide()
	vbox.add_child(_free_badge_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "Elige 1 de las 3 mejoras espaciales para tu nave [1, 2, 3 o Click]"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 12)
	_subtitle_label.modulate = Color(0.65, 0.8, 0.95, 0.75)
	vbox.add_child(_subtitle_label)

	# Contenedor de las 3 opciones en lista vertical
	_cards_container = VBoxContainer.new()
	_cards_container.add_theme_constant_override("separation", 10)
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_cards_container)

	_skip_button = Button.new()
	_skip_button.text = "[ 4 / ESC ] SALTAR Y RECICLAR (+50% Créditos)"
	_skip_button.custom_minimum_size = Vector2(320, 34)
	_skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skip_button.pressed.connect(skip_and_recycle)
	UIFocusHelper.apply_cyber_focus(_skip_button)
	vbox.add_child(_skip_button)

## Despliega el borrador de 3 opciones interactivas
func open_draft(items: Array[ItemData], was_free: bool, player: Player, on_selected: Callable = Callable(), paid_cost: int = 0) -> void:
	if items.is_empty():
		return

	_current_candidates = items
	_current_player = player
	_selection_callback = on_selected
	_paid_cost = paid_cost
	_card_buttons.clear()

	_free_badge_label.visible = was_free

	if _skip_button:
		var refund_preview: int = int(_paid_cost * 0.5)
		if refund_preview > 0:
			_skip_button.text = "[ 4 / ESC ] SALTAR Y RECICLAR (+%d Créditos)" % refund_preview
		else:
			_skip_button.text = "[ 4 / ESC ] SALTAR COFRE"

	# Limpiar cartas previas
	for child in _cards_container.get_children():
		child.queue_free()

	for i in range(items.size()):
		var it := items[i]
		var card := _create_draft_card(it, i, player)
		_cards_container.add_child(card)

	open_modal()
	if not _card_buttons.is_empty() and is_instance_valid(_card_buttons[0]):
		_card_buttons[0].grab_focus()

	# Animación de entrada
	_panel.scale = Vector2(0.9, 0.9)
	_panel.pivot_offset = _panel.size * 0.5
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Compatibilidad hacia atrás: abre con 1 solo ítem
func open_reward(item: ItemData, was_free: bool, _total_stacks: int = 1) -> void:
	if not item:
		return
	open_draft([item], was_free, _current_player)

func _create_draft_card(item: ItemData, index: int, player: Player) -> PanelContainer:
	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(510, 72)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rarity_col := _get_rarity_color(item.rarity)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.13, 0.95)
	style.set_border_width_all(2)
	style.border_color = rarity_col
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10.0)
	card_panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	card_panel.add_child(hbox)

	# 1. Icono
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(56, 56)
	icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.02, 0.04, 0.08, 0.95)
	icon_style.set_border_width_all(1)
	icon_style.border_color = rarity_col
	icon_style.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", icon_style)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(44, 44)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if item.icon:
		icon_rect.texture = item.icon
	icon_panel.add_child(icon_rect)
	hbox.add_child(icon_panel)

	# 2. Información central
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vbox.add_theme_constant_override("separation", 3)

	var top_line := HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 10)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.modulate = rarity_col
	top_line.add_child(name_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = "• [ %s ]" % _get_rarity_name(item.rarity)
	rarity_lbl.add_theme_font_size_override("font_size", 11)
	rarity_lbl.modulate = rarity_col
	top_line.add_child(rarity_lbl)

	var stacks: int = player.inventory.get_item_count(item.item_id) if (player and player.inventory) else 0
	if stacks > 0:
		var stacks_lbl := Label.new()
		stacks_lbl.text = "(En posesión: x%d)" % stacks
		stacks_lbl.add_theme_font_size_override("font_size", 11)
		stacks_lbl.modulate = Color(0.65, 0.8, 0.95, 0.7)
		top_line.add_child(stacks_lbl)

	if item.stat_name != &"":
		var val_s: String = LevelUpStatsInspector.format_stat_modifier(item.stat_name, item.stat_value, item.is_percentage, true)
		var stat_badge := Label.new()
		var stat_title: String = LevelUpStatsInspector.get_stat_display_name(item.stat_name)
		if item.secondary_stat_name != &"":
			var sec_val_s: String = LevelUpStatsInspector.format_stat_modifier(item.secondary_stat_name, item.secondary_stat_value, item.secondary_is_percentage, true)
			stat_badge.text = "• [ ⚖ %s / %s ]" % [val_s, sec_val_s]
			stat_badge.modulate = Color(1.0, 0.75, 0.4)
		else:
			stat_badge.text = "• [ ▲ %s %s ]" % [val_s, stat_title]
			stat_badge.modulate = Color("#00FF9D") if item.stat_value >= 0 else Color("#FF4466")
		stat_badge.add_theme_font_size_override("font_size", 11)
		top_line.add_child(stat_badge)

	info_vbox.add_child(top_line)

	var desc_lbl := Label.new()
	desc_lbl.text = item.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.modulate = Color(0.85, 0.9, 0.96, 0.9)
	info_vbox.add_child(desc_lbl)

	hbox.add_child(info_vbox)

	# 3. Columna derecha: Atajo y Botón de Selección
	var btn_vbox := VBoxContainer.new()
	btn_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_vbox.add_theme_constant_override("separation", 4)

	var hotkey_lbl := Label.new()
	hotkey_lbl.text = "[ TECLA %d ]" % (index + 1)
	hotkey_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkey_lbl.add_theme_font_size_override("font_size", 11)
	hotkey_lbl.modulate = Color(1.0, 0.9, 0.35, 0.95)
	btn_vbox.add_child(hotkey_lbl)

	var select_btn := Button.new()
	select_btn.text = "ELEGIR [%d]" % (index + 1)
	select_btn.custom_minimum_size = Vector2(130, 36)
	select_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	select_btn.pressed.connect(func(): _select_index(index))
	var on_highlight := func():
		var hud: Node = get_tree().get_first_node_in_group("hud") if get_tree() else null
		if hud and "combat_stats_dock" in hud and is_instance_valid(hud.combat_stats_dock):
			hud.combat_stats_dock.preview_item_stat(item)
	select_btn.focus_entered.connect(on_highlight)
	select_btn.mouse_entered.connect(on_highlight)
	UIFocusHelper.apply_cyber_focus(select_btn)
	btn_vbox.add_child(select_btn)
	_card_buttons.append(select_btn)

	hbox.add_child(btn_vbox)

	return card_panel

func _select_index(idx: int) -> void:
	if idx < 0 or idx >= _current_candidates.size():
		return

	var chosen: ItemData = _current_candidates[idx]
	if _current_player and is_instance_valid(_current_player) and _current_player.inventory:
		_current_player.inventory.add_item(chosen, 1, "COFRE ESPACIAL")
		_current_player.inventory.process_chest_opened_procs(_current_player)

	if _selection_callback.is_valid():
		_selection_callback.call(chosen)

	item_selected.emit(chosen)
	close_modal()

func skip_and_recycle() -> void:
	if _paid_cost > 0 and is_instance_valid(_current_player):
		var refund: int = int(_paid_cost * 0.5)
		if refund > 0:
			_current_player.run_credits += refund
			if _current_player.has_signal("credits_changed"):
				_current_player.credits_changed.emit(_current_player.run_credits)
			var hud: Node = get_tree().get_first_node_in_group("hud") if get_tree() else null
			if hud and hud.has_method("show_tactical_alert"):
				hud.show_tactical_alert("COFRE RECICLADO", "+%d créditos recuperados (50%%)" % refund, Color(0.3, 0.9, 1.0))
			elif _current_player.has_method("show_tactical_alert"):
				_current_player.show_tactical_alert("COFRE RECICLADO", "+%d créditos recuperados (50%%)" % refund, Color(0.3, 0.9, 1.0))

	close_modal()

func close_modal() -> void:
	super.close_modal()
	modal_closed.emit()

func _get_rarity_name(rarity: Enums.Rarity) -> String:
	match rarity:
		Enums.Rarity.COMMON: return "COMÚN"
		Enums.Rarity.UNCOMMON: return "POCO COMÚN"
		Enums.Rarity.RARE: return "RARO"
		Enums.Rarity.EPIC: return "ÉPICO"
		Enums.Rarity.LEGENDARY: return "LEGENDARIO"
		_: return "ESTÁNDAR"

func _get_rarity_color(rarity: Enums.Rarity) -> Color:
	match rarity:
		Enums.Rarity.COMMON: return Color(0.4, 0.9, 0.5, 1.0)
		Enums.Rarity.UNCOMMON: return Color(0.2, 0.7, 1.0, 1.0)
		Enums.Rarity.RARE: return Color(0.85, 0.35, 1.0, 1.0)
		Enums.Rarity.EPIC: return Color(1.0, 0.5, 0.1, 1.0)
		Enums.Rarity.LEGENDARY: return Color(1.0, 0.85, 0.2, 1.0)
		_: return Color(0.8, 0.9, 1.0, 1.0)
