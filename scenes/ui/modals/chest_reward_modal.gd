class_name ChestRewardModal
extends CanvasLayer

## ChestRewardModal.gd
## Modal de inspección táctica desplegado al abrir un cofre espacial.
## Pausa el combate, exhibe la tarjeta estilizada del ítem adquirido,
## sus sinergias y estadísticas, antes de reanudar el juego.

signal modal_closed()

var _panel: PanelContainer
var _title_label: Label
var _free_badge_label: Label
var _icon_rect: TextureRect
var _item_name_label: Label
var _rarity_label: Label
var _desc_label: Label
var _stacks_label: Label
var _continue_btn: Button

func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("chest_reward_modal")
	_build_ui()
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.is_pressed() and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE)):
		close_modal()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	# 1. Fondo atenuado translúcido
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.02, 0.05, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 2. Contenedor centrado
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# 3. Panel de la tarjeta
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(420, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.96)
	style.set_border_width_all(2)
	style.border_color = Color(0.2, 0.7, 1.0, 0.8)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(24.0)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	# Encabezado
	_title_label = Label.new()
	_title_label.text = "RECOMPENSA DE COFRE ESPACIAL"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.theme_override_font_sizes/font_size = 13
	_title_label.modulate = Color(0.6, 0.8, 1.0, 0.8)
	vbox.add_child(_title_label)

	_free_badge_label = Label.new()
	_free_badge_label.text = "★ ¡APERTURA CUÁNTICA GRATUITA! (Llave Activada) ★"
	_free_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_free_badge_label.theme_override_font_sizes/font_size = 12
	_free_badge_label.modulate = Color(0.3, 1.0, 0.5, 1.0)
	_free_badge_label.hide()
	vbox.add_child(_free_badge_label)

	# Contenedor de Icono
	var icon_center := CenterContainer.new()
	icon_center.custom_minimum_size = Vector2(0, 90)
	vbox.add_child(icon_center)

	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(80, 80)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_center.add_child(_icon_rect)

	# Nombre y Rareza
	_item_name_label = Label.new()
	_item_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_name_label.theme_override_font_sizes/font_size = 18
	vbox.add_child(_item_name_label)

	_rarity_label = Label.new()
	_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rarity_label.theme_override_font_sizes/font_size = 11
	vbox.add_child(_rarity_label)

	# Descripción
	_desc_label = Label.new()
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(360, 48)
	_desc_label.theme_override_font_sizes/font_size = 13
	_desc_label.modulate = Color(0.85, 0.9, 0.95, 0.9)
	vbox.add_child(_desc_label)

	# Cantidad acumulada
	_stacks_label = Label.new()
	_stacks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stacks_label.theme_override_font_sizes/font_size = 12
	_stacks_label.modulate = Color(0.7, 0.85, 1.0, 0.7)
	vbox.add_child(_stacks_label)

	# Botón continuar
	_continue_btn = Button.new()
	_continue_btn.text = "CONTINUAR [ESPACIO]"
	_continue_btn.custom_minimum_size = Vector2(220, 38)
	_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_btn.pressed.connect(close_modal)
	vbox.add_child(_continue_btn)
	UIFocusHelper.apply_cyber_focus(_continue_btn)

func open_reward(item: ItemData, was_free: bool, total_stacks: int = 1) -> void:
	if not item:
		return

	get_tree().paused = true

	# Configurar textos y estética según rareza
	var rarity_col := _get_rarity_color(item.rarity)
	_item_name_label.text = item.item_name
	_item_name_label.modulate = rarity_col
	_rarity_label.text = "[ %s ]" % _get_rarity_name(item.rarity)
	_rarity_label.modulate = rarity_col
	_desc_label.text = item.description
	_stacks_label.text = "Acumulado en inventario: x%d" % total_stacks
	_free_badge_label.visible = was_free

	if item.icon:
		_icon_rect.texture = item.icon
		_icon_rect.modulate = Color.WHITE
	else:
		_icon_rect.texture = null

	# Actualizar color del borde del panel
	var style := _panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = rarity_col

	show()
	_continue_btn.grab_focus()

	# Animación de entrada
	_panel.scale = Vector2(0.85, 0.85)
	_panel.pivot_offset = _panel.size * 0.5
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close_modal() -> void:
	hide()
	get_tree().paused = false
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
		Enums.Rarity.COMMON: return Color(0.4, 0.9, 0.5, 1.0) # Verde
		Enums.Rarity.UNCOMMON: return Color(0.2, 0.7, 1.0, 1.0) # Azul
		Enums.Rarity.RARE: return Color(0.85, 0.35, 1.0, 1.0) # Magenta/Púrpura
		Enums.Rarity.EPIC: return Color(1.0, 0.5, 0.1, 1.0) # Naranja/Oro
		Enums.Rarity.LEGENDARY: return Color(1.0, 0.85, 0.2, 1.0) # Dorado
		_: return Color(0.8, 0.9, 1.0, 1.0)
