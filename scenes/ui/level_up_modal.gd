class_name LevelUpModal
extends CanvasLayer

signal card_chosen(card: StatCardData)

@export var stat_deck_manager: StatDeckManager
@export var player: Player

@onready var modal_panel: Panel = $Panel
@onready var cards_container: HBoxContainer = $Panel/VBoxContainer/CardsContainer
@onready var level_label: Label = $Panel/VBoxContainer/Title

var current_offered_cards: Array[StatCardData] = []
var select_buttons: Array[Button] = []
var card_panels: Array[PanelContainer] = []
var card_tier_colors: Array[Color] = []
var current_selected_idx: int = 0

const STAT_ICON_MAP = {
	&"base_damage": "res://assets/icons/items/icon_sword.svg",
	&"attack_speed": "res://assets/icons/items/icon_gauntlet.svg",
	&"crit_chance": "res://assets/icons/items/icon_glasses.svg",
	&"crit_damage": "res://assets/icons/items/icon_lens.svg",
	&"max_health": "res://assets/icons/items/icon_heart.svg",
	&"move_speed": "res://assets/icons/items/icon_boots.svg",
	&"luck": "res://assets/icons/items/icon_clover.svg",
	&"projectile_count": "res://assets/icons/items/icon_quiver.svg",
	&"armor": "res://assets/icons/items/icon_shield.svg",
	&"health_regen": "res://assets/icons/items/icon_apple.svg",
	&"pickup_radius": "res://assets/icons/items/icon_magnet.svg",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	# Estilo translúcido de alta tecnología para el panel del modal
	var modal_style := StyleBoxFlat.new()
	modal_style.bg_color = Color(0.04, 0.06, 0.1, 0.96)
	modal_style.set_border_width_all(2)
	modal_style.border_color = Color(0.2, 0.6, 1.0, 0.7)
	modal_style.set_corner_radius_all(12)
	modal_style.set_content_margin_all(16.0)
	modal_panel.add_theme_stylebox_override("panel", modal_style)

	if stat_deck_manager:
		stat_deck_manager.cards_offered.connect(_on_cards_offered)

func show_level_up(level: int) -> void:
	level_label.text = "¡SUBIDA DE NIVEL %d! SELECCIONA UNA MEJORA" % level
	level_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	get_tree().paused = true
	show()
	if stat_deck_manager and player:
		stat_deck_manager.offer_cards(player.stats, level, 4)

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			# Atajos numéricos directos (1, 2, 3, 4)
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
			KEY_4, KEY_KP_4:
				_select_card_by_index(3)
				get_viewport().set_input_as_handled()
				return

			# Navegación con ASDW y Flechas Direccionales
			KEY_A, KEY_LEFT, KEY_W, KEY_UP:
				_change_selection(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_D, KEY_RIGHT, KEY_S, KEY_DOWN:
				_change_selection(1)
				get_viewport().set_input_as_handled()
				return

			# Confirmación con Barra Espaciadora o Enter
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_confirm_current_selection()
				get_viewport().set_input_as_handled()
				return

func _change_selection(direction: int) -> void:
	if card_panels.is_empty():
		return
	var new_idx := (current_selected_idx + direction) % card_panels.size()
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
		var panel := card_panels[i]
		var color := card_tier_colors[i]
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.set_content_margin_all(10.0)

		if i == current_selected_idx:
			style.bg_color = Color(0.10, 0.14, 0.22, 0.98)
			style.set_border_width_all(3)
			style.border_color = color.lightened(0.3)
			style.shadow_color = color * Color(1.0, 1.0, 1.0, 0.45)
			style.shadow_size = 8
			if i < select_buttons.size() and is_instance_valid(select_buttons[i]):
				select_buttons[i].grab_focus()
		else:
			style.bg_color = Color(0.06, 0.08, 0.13, 0.92)
			style.set_border_width_all(2)
			style.border_color = color * Color(1.0, 1.0, 1.0, 0.5)
			style.shadow_size = 0

		panel.add_theme_stylebox_override("panel", style)

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

	for child in cards_container.get_children():
		child.queue_free()

	for i in range(cards.size()):
		_create_stat_card_ui(cards[i], i)

	call_deferred("_update_card_selection", 0)

func _create_stat_card_ui(card: StatCardData, index: int) -> void:
	# Respaldo automático de icono según la estadística afectada si viene nulo
	if not card.icon:
		var stat_key: StringName = card.target_stat
		if STAT_ICON_MAP.has(stat_key) and ResourceLoader.exists(STAT_ICON_MAP[stat_key]):
			card.icon = load(STAT_ICON_MAP[stat_key]) as Texture2D

	var tier_info := _get_tier_info(card.tier)
	var tier_color: Color = tier_info["color"]

	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(220, 310)
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.08, 0.13, 0.92)
	card_style.set_border_width_all(2)
	card_style.border_color = tier_color * Color(1.0, 1.0, 1.0, 0.5)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(10.0)
	card_panel.add_theme_stylebox_override("panel", card_style)

	# Interacción táctil/mouse sobre toda la superficie de la carta
	card_panel.mouse_entered.connect(func():
		_update_card_selection(index)
	)
	card_panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.is_pressed() and ev.button_index == MOUSE_BUTTON_LEFT:
			_select_card(card)
	)

	card_panels.append(card_panel)
	card_tier_colors.append(tier_color)

	var vbox := VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 8)

	# Indicador de atajo de teclado
	var hotkey_lbl := Label.new()
	hotkey_lbl.text = "[ TECLA %d ]" % (index + 1)
	hotkey_lbl.modulate = Color(1.0, 0.9, 0.35, 0.95)
	hotkey_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkey_lbl.add_theme_font_size_override("font_size", 12)

	# Etiqueta de Tier con color indicador
	var tier_lbl := Label.new()
	tier_lbl.text = tier_info["name"]
	tier_lbl.modulate = tier_color
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_font_size_override("font_size", 12)

	# Título de la carta
	var title_lbl := Label.new()
	title_lbl.text = card.title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_lbl.add_theme_color_override("font_color", tier_color)
	title_lbl.add_theme_font_size_override("font_size", 15)

	# Marco contenedor del icono de 64x64 px centrado
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(64, 64)
	icon_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.03, 0.04, 0.07, 0.95)
	icon_style.set_border_width_all(2)
	icon_style.border_color = tier_color
	icon_style.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", icon_style)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(50, 50)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if card.icon:
		icon_rect.texture = card.icon
		icon_rect.modulate = tier_color
	icon_panel.add_child(icon_rect)

	# Descripción de mejora
	var desc_lbl := Label.new()
	desc_lbl.text = "Modificador permanente de estadísticas"
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.modulate = Color(0.75, 0.8, 0.9, 0.8)
	desc_lbl.add_theme_font_size_override("font_size", 12)

	# Botón de selección interactivo
	var select_btn := Button.new()
	select_btn.text = "Elegir [%d]" % (index + 1)
	select_btn.pressed.connect(func():
		_select_card(card)
	)
	select_btn.focus_entered.connect(func():
		if current_selected_idx != index:
			_update_card_selection(index)
	)

	vbox.add_child(hotkey_lbl)
	vbox.add_child(tier_lbl)
	vbox.add_child(title_lbl)
	vbox.add_child(icon_panel)
	vbox.add_child(desc_lbl)
	vbox.add_child(select_btn)
	card_panel.add_child(vbox)

	cards_container.add_child(card_panel)
	select_buttons.append(select_btn)

func _get_tier_info(tier: Enums.Tier) -> Dictionary:
	match tier:
		Enums.Tier.TIER_1:
			return {
				"name": "TIER 1 (Común)",
				"color": Color(0.5, 0.8, 1.0, 0.95)
			}
		Enums.Tier.TIER_2:
			return {
				"name": "TIER 2 (Poco Común)",
				"color": Color(0.2, 0.95, 0.4, 0.95)
			}
		Enums.Tier.TIER_3:
			return {
				"name": "TIER 3 (Raro)",
				"color": Color(1.0, 0.8, 0.15, 1.0)
			}
		Enums.Tier.TIER_4:
			return {
				"name": "TIER 4 (Legendario)",
				"color": Color(0.9, 0.35, 1.0, 1.0)
			}
		_:
			return {
				"name": "TIER 1",
				"color": Color.WHITE
			}

func _select_card(card: StatCardData) -> void:
	if stat_deck_manager and player:
		stat_deck_manager.apply_card_to_stats(card, player.stats)
		player.chosen_stat_cards.append(card)
	hide()
	get_tree().paused = false
	card_chosen.emit(card)
