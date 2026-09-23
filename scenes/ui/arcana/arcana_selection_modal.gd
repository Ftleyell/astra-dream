class_name ArcanaSelectionModal
extends CanvasLayer
const ArcanaData = preload("res://data/arcanas/arcana_data.gd")
const SaveManager = preload("res://core/autoloads/save_manager.gd")


## ArcanaSelectionModal.gd
## Modal de selección táctica de Arcanas (Pactos de Alto Riesgo / Recompensa).
## Se activa al recolectar un ArcanaOrb liberado por el Monolito Arcano.
## Pausa la partida, ofrece 3 cartas estilizadas Psycho-Pop y aplica las alteraciones al jugador.

signal arcana_chosen(arcana: ArcanaData)
signal modal_closed()

const UIFocusHelper := preload("res://core/utils/ui_focus_helper.gd")

const COLOR_HOT_PINK := Color("#FF1493")
const COLOR_DEEP_BLACK := Color("#0A0A0E")
const COLOR_PURE_WHITE := Color("#FFFFFF")
const COLOR_NEON_CYAN := Color("#00F0FF")
const COLOR_BOON_GREEN := Color("#44FF88")
const COLOR_CURSE_RED := Color("#FF3366")

@export var player: Player = null

@onready var backdrop: ColorRect = $Backdrop
@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var cards_container: HBoxContainer = find_child("CardsContainer", true, false) as HBoxContainer
@onready var header_title: Label = find_child("HeaderTitle", true, false) as Label
@onready var header_subtitle: Label = find_child("HeaderSubtitle", true, false) as Label

var offered_arcanas: Array[ArcanaData] = []
var card_buttons: Array[Button] = []
var is_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_apply_modal_styles()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active or not visible:
		return

	# Navegación con teclado / gamepad
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if not offered_arcanas.is_empty():
					_on_card_chosen(offered_arcanas[0])
				else:
					close_modal()
				get_viewport().set_input_as_handled()
				return
			KEY_LEFT, KEY_A:
				_cycle_focus(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_RIGHT, KEY_D:
				_cycle_focus(1)
				get_viewport().set_input_as_handled()
				return
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_choose_focused_card()
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("ui_left"):
		_cycle_focus(-1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_right"):
		_cycle_focus(1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_accept"):
		_choose_focused_card()
		get_viewport().set_input_as_handled()
		return


func _cycle_focus(delta_dir: int) -> void:
	if card_buttons.is_empty():
		return
	var current_idx := -1
	var vp := get_viewport()
	var owner_node := vp.gui_get_focus_owner() if vp else null
	for i in range(card_buttons.size()):
		if card_buttons[i] == owner_node:
			current_idx = i
			break
	var next_idx := (current_idx + delta_dir) % card_buttons.size()
	if next_idx < 0:
		next_idx += card_buttons.size()
	if next_idx >= 0 and next_idx < card_buttons.size() and is_instance_valid(card_buttons[next_idx]):
		card_buttons[next_idx].grab_focus()


func _choose_focused_card() -> void:
	if card_buttons.is_empty():
		return
	var vp := get_viewport()
	var owner_node := vp.gui_get_focus_owner() if vp else null
	for i in range(card_buttons.size()):
		if card_buttons[i] == owner_node and i < offered_arcanas.size():
			_on_card_chosen(offered_arcanas[i])
			return
	if not offered_arcanas.is_empty():
		_on_card_chosen(offered_arcanas[0])


func show_arcana_selection(p_player: Player = null) -> void:
	if p_player:
		player = p_player
	elif not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player

	# Pausar la simulación de juego
	get_tree().paused = true
	is_active = true
	visible = true

	var excluded_ids: Array = []
	if is_instance_valid(player) and player.has_method("get_arcana_ids"):
		excluded_ids = player.get_arcana_ids()

	offered_arcanas = ArcanaData.get_random_selection(3, excluded_ids)

	# Manejo seguro si el catálogo está agotado (24 arcanas adquiridas)
	if offered_arcanas.is_empty():
		var overload_arc := ArcanaData.new()
		overload_arc.id = "quantum_overload_mastery"
		overload_arc.name = "Sobrecarga del Vacío"
		overload_arc.description_boon = "Todas las 24 Arcanas asimiladas. +500 Créditos y +15 Materia Oscura inmediata."
		overload_arc.description_curse = "Sobrecarga canalizada. Sin penalizaciones adicionales."
		overload_arc.quadrant = "greed"
		overload_arc.color_accent = Color(0.85, 0.2, 1.0)
		overload_arc.stat_modifiers = {}
		offered_arcanas.append(overload_arc)

	_build_cards_ui()

	# Audio místico de apertura
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("level_up", 1.1)

	# Foco inicial en la primera carta
	call_deferred("_focus_first_card")


func close_modal() -> void:
	is_active = false
	visible = false
	get_tree().paused = false

	# Notificar cierre a MainGame y Player para suprimir disparador de bomba accidental
	var main_node = get_parent()
	if main_node and main_node.has_method("notify_menu_closed"):
		main_node.notify_menu_closed(0.35)
	elif is_instance_valid(player) and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(0.35)

	modal_closed.emit()


func restore_focus() -> void:
	if is_active and not card_buttons.is_empty() and is_instance_valid(card_buttons[0]):
		card_buttons[0].grab_focus()


func _build_cards_ui() -> void:
	if not cards_container:
		return

	# Limpiar cartas anteriores
	for child in cards_container.get_children():
		child.queue_free()
	card_buttons.clear()

	for i in range(offered_arcanas.size()):
		var arc: ArcanaData = offered_arcanas[i]
		var card := _create_cyber_card(arc, i)
		cards_container.add_child(card)

	# Enlace horizontal cíclico de foco para teclado / gamepad
	var n := card_buttons.size()
	for i in range(n):
		var prev_btn := card_buttons[(i - 1 + n) % n]
		var next_btn := card_buttons[(i + 1) % n]
		card_buttons[i].focus_neighbor_left = prev_btn.get_path()
		card_buttons[i].focus_neighbor_right = next_btn.get_path()


func _create_cyber_card(arc: ArcanaData, index: int) -> Control:
	var accent: Color = arc.color_accent if arc.color_accent != Color.BLACK else COLOR_NEON_CYAN

	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(320, 480)
	card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Estilo Psycho-Pop: fondo negro con bordes rectos (corner_radius = 0)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.04, 0.05, 0.08, 0.96)
	card_sb.border_color = accent
	card_sb.set_border_width_all(2)
	card_sb.border_width_top = 6
	card_sb.set_corner_radius_all(0)
	card_sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.25)
	card_sb.shadow_size = 10
	card_panel.add_theme_stylebox_override("panel", card_sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	card_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# 1. Badge del Cuadrante
	var quad_badge := Label.new()
	quad_badge.text = "[ %s ]" % arc.get_quadrant_title().to_upper()
	quad_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quad_badge.add_theme_color_override("font_color", accent.lightened(0.2))
	quad_badge.add_theme_font_size_override("font_size", 11)
	vbox.add_child(quad_badge)

	# 2. Nombre de la Arcana
	var name_label := Label.new()
	name_label.text = arc.name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", COLOR_PURE_WHITE)
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	# 3. Separador decorativo neón
	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = accent
	sep_style.thickness = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# 4. Icono o Glifo Central
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if arc.icon:
		icon_rect.texture = arc.icon
	icon_rect.modulate = accent
	vbox.add_child(icon_rect)

	# 5. Sección de Bendición (Boon)
	var boon_panel := PanelContainer.new()
	boon_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var boon_sb := StyleBoxFlat.new()
	boon_sb.bg_color = Color(0.05, 0.15, 0.08, 0.75)
	boon_sb.border_color = COLOR_BOON_GREEN
	boon_sb.border_width_left = 3
	boon_sb.set_corner_radius_all(0)
	boon_panel.add_theme_stylebox_override("panel", boon_sb)

	var boon_margin := MarginContainer.new()
	boon_margin.add_theme_constant_override("margin_left", 10)
	boon_margin.add_theme_constant_override("margin_right", 10)
	boon_margin.add_theme_constant_override("margin_top", 8)
	boon_margin.add_theme_constant_override("margin_bottom", 8)
	boon_panel.add_child(boon_margin)

	var boon_vbox := VBoxContainer.new()
	boon_vbox.add_theme_constant_override("separation", 4)
	boon_margin.add_child(boon_vbox)

	var boon_header := Label.new()
	boon_header.text = "▲ BENDICIÓN TÁCTICA"
	boon_header.add_theme_color_override("font_color", COLOR_BOON_GREEN)
	boon_header.add_theme_font_size_override("font_size", 12)
	boon_vbox.add_child(boon_header)

	var boon_desc := Label.new()
	boon_desc.text = arc.description_boon
	boon_desc.add_theme_color_override("font_color", COLOR_PURE_WHITE)
	boon_desc.add_theme_font_size_override("font_size", 12)
	boon_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boon_vbox.add_child(boon_desc)

	vbox.add_child(boon_panel)

	# 6. Sección de Maldición / Tributo (Curse)
	var curse_panel := PanelContainer.new()
	curse_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var curse_sb := StyleBoxFlat.new()
	curse_sb.bg_color = Color(0.2, 0.04, 0.06, 0.75)
	curse_sb.border_color = COLOR_CURSE_RED
	curse_sb.border_width_left = 3
	curse_sb.set_corner_radius_all(0)
	curse_panel.add_theme_stylebox_override("panel", curse_sb)

	var curse_margin := MarginContainer.new()
	curse_margin.add_theme_constant_override("margin_left", 10)
	curse_margin.add_theme_constant_override("margin_right", 10)
	curse_margin.add_theme_constant_override("margin_top", 8)
	curse_margin.add_theme_constant_override("margin_bottom", 8)
	curse_panel.add_child(curse_margin)

	var curse_vbox := VBoxContainer.new()
	curse_vbox.add_theme_constant_override("separation", 4)
	curse_margin.add_child(curse_vbox)

	var curse_header := Label.new()
	curse_header.text = "▼ TRIBUTO / MALDICIÓN"
	curse_header.add_theme_color_override("font_color", COLOR_CURSE_RED)
	curse_header.add_theme_font_size_override("font_size", 12)
	curse_vbox.add_child(curse_header)

	var curse_desc := Label.new()
	curse_desc.text = arc.description_curse
	curse_desc.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	curse_desc.add_theme_font_size_override("font_size", 12)
	curse_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	curse_vbox.add_child(curse_desc)

	vbox.add_child(curse_panel)

	# 7. Botón de Selección con UIFocusHelper
	var btn := Button.new()
	btn.text = "PACTAR CON ARCANA"
	btn.custom_minimum_size = Vector2(0, 42)
	btn.focus_mode = Control.FOCUS_ALL

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = COLOR_DEEP_BLACK
	btn_normal.border_color = accent
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = accent
	btn_hover.border_color = COLOR_PURE_WHITE
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_color_override("font_hover_color", COLOR_DEEP_BLACK)

	UIFocusHelper.apply_cyber_focus(btn)
	btn.pressed.connect(_on_card_chosen.bind(arc))

	vbox.add_child(btn)
	card_buttons.append(btn)

	return card_panel


func _focus_first_card() -> void:
	if not card_buttons.is_empty() and is_instance_valid(card_buttons[0]):
		card_buttons[0].grab_focus()


func _on_card_chosen(arc: ArcanaData) -> void:
	if arc.id == "quantum_overload_mastery":
		if is_instance_valid(player):
			player.add_credits(500)
			if player.has_method("add_dark_matter"):
				player.add_dark_matter(15)
			else:
				SaveManager.add_dark_matter(15)
	else:
		# Aplicar bonos y maldiciones al jugador
		if is_instance_valid(player) and player.has_method("apply_arcana"):
			player.apply_arcana(arc)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 1.2)

	arcana_chosen.emit(arc)
	close_modal()


func _apply_modal_styles() -> void:
	if backdrop:
		backdrop.color = Color(0.02, 0.02, 0.04, 0.88)

	if main_panel:
		var sb := StyleBoxFlat.new()
		sb.bg_color = COLOR_DEEP_BLACK
		sb.border_color = COLOR_HOT_PINK
		sb.set_border_width_all(2)
		sb.border_width_top = 4
		sb.set_corner_radius_all(0)
		sb.shadow_color = Color(1.0, 0.08, 0.58, 0.25)
		sb.shadow_size = 18
		main_panel.add_theme_stylebox_override("panel", sb)

	if header_title:
		header_title.text = "◈ INVOCACIÓN DE ARCANA ◈"
		header_title.add_theme_color_override("font_color", COLOR_HOT_PINK)

	if header_subtitle:
		header_subtitle.text = "PACTOS DE ALTO RIESGO / RECOMPENSA - SELECCIONA UNA ALTERACIÓN CUÁNTICA"
		header_subtitle.add_theme_color_override("font_color", COLOR_NEON_CYAN)
