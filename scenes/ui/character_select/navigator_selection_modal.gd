class_name NavigatorSelectionModal
extends CanvasLayer

signal navigator_selected(nav_id: StringName)
signal closed()

@onready var index_badge: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ModalHeader/IndexBadge
@onready var up_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/CarouselColumn/UpButton
@onready var down_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/CarouselColumn/DownButton
@onready var artwork_frame: PanelContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/CarouselColumn/ArtworkFrame
@onready var artwork_viewport: Control = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/CarouselColumn/ArtworkFrame/ArtworkViewport
@onready var fullbody_texture: TextureRect = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/CarouselColumn/ArtworkFrame/ArtworkViewport/FullbodyTexture
@onready var locked_overlay: Control = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/CarouselColumn/ArtworkFrame/LockedOverlay
@onready var lock_desc: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/CarouselColumn/ArtworkFrame/LockedOverlay/LockCenter/LockDesc
@onready var dots_container: HBoxContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/CarouselColumn/ArtworkFrame/DotsContainer

@onready var name_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/DossierColumn/DossierHeader/NameRow/NameLabel
@onready var status_badge: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/DossierColumn/DossierHeader/NameRow/StatusBadge
@onready var title_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/DossierColumn/DossierHeader/TitleLabel
@onready var radar_desc: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/DossierColumn/DetailsVBox/RadarCard/Margin/VBox/RadarDesc
@onready var buff_card: PanelContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/DossierColumn/DetailsVBox/BuffCard
@onready var buff_name_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/DossierColumn/DetailsVBox/BuffCard/Margin/VBox/BuffNameLabel
@onready var buff_desc_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/DossierColumn/DetailsVBox/BuffCard/Margin/VBox/BuffDescLabel
@onready var radio_dialogue: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/DossierColumn/DetailsVBox/RadioCard/Margin/VBox/RadioDialogue
@onready var select_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/DossierColumn/ActionsHBox/SelectButton
@onready var close_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ContentHBox/DossierColumn/ActionsHBox/CloseButton

var is_open: bool = false
var current_index: int = 0
var _navigators: Array = []
var _nav_buttons: Array[Button] = []
var _active_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 126
	hide()

	if up_btn:
		up_btn.pressed.connect(func(): _cycle(-1))
		UIFocusHelper.apply_cyber_focus(up_btn)
	if down_btn:
		down_btn.pressed.connect(func(): _cycle(1))
		UIFocusHelper.apply_cyber_focus(down_btn)
	if select_btn:
		select_btn.pressed.connect(_on_select_pressed)
		UIFocusHelper.apply_cyber_focus(select_btn)
	if close_btn:
		close_btn.pressed.connect(close_modal)
		UIFocusHelper.apply_cyber_focus(close_btn)

	_setup_focus_neighbors()

func open_modal() -> void:
	is_open = true
	show()
	_populate_navigators()
	if select_btn and not select_btn.disabled:
		select_btn.grab_focus()
	elif up_btn:
		up_btn.grab_focus()
	elif close_btn:
		close_btn.grab_focus()

func close_modal() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_modal()
		return

	# Navegación vertical de carousel con teclado
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_W or event.keycode == KEY_UP:
			get_viewport().set_input_as_handled()
			_cycle(-1)
			return
		elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
			get_viewport().set_input_as_handled()
			_cycle(1)
			return
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if select_btn and not select_btn.disabled:
				get_viewport().set_input_as_handled()
				_on_select_pressed()
				return

	# Rueda del ratón para desplazarse en el carrusel
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			get_viewport().set_input_as_handled()
			_cycle(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()
			_cycle(1)

func _populate_navigators() -> void:
	const NavigatorDataScript := preload("res://data/navigators/navigator_data.gd")
	_navigators = NavigatorDataScript.load_roster_ordered()

	var selected_nid := SaveManager.get_selected_navigator()
	var initial_index: int = 0
	for i in range(_navigators.size()):
		if _navigators[i].navigator_id == selected_nid:
			initial_index = i
			break
	current_index = initial_index

	_build_dots()
	_display_current_navigator(false, 0)

func _build_dots() -> void:
	if not dots_container:
		return

	for child in dots_container.get_children():
		dots_container.remove_child(child)
		child.queue_free()
	_nav_buttons.clear()

	for i in range(_navigators.size()):
		var dot_btn := Button.new()
		dot_btn.custom_minimum_size = Vector2(26, 26)
		dot_btn.flat = true
		dot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		dot_btn.text = "●" if i == current_index else "○"
		dot_btn.add_theme_font_size_override("font_size", 18)
		dot_btn.focus_mode = Control.FOCUS_NONE

		var target_idx := i
		dot_btn.pressed.connect(func():
			if current_index != target_idx:
				var dir: int = 1 if target_idx > current_index else -1
				_set_index(target_idx, dir)
		)

		dots_container.add_child(dot_btn)
		_nav_buttons.append(dot_btn)

func _cycle(direction: int) -> void:
	if _navigators.is_empty():
		return
	var count := _navigators.size()
	var next_idx := (current_index + direction) % count
	if next_idx < 0:
		next_idx += count
	_set_index(next_idx, direction)

func _set_index(new_idx: int, slide_direction: int = 0) -> void:
	if new_idx == current_index:
		return
	current_index = new_idx
	_display_current_navigator(true, slide_direction)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_hover", 0.0, 1.1)

func _display_current_navigator(animate: bool = true, slide_direction: int = 0) -> void:
	if _navigators.is_empty() or current_index < 0 or current_index >= _navigators.size():
		return

	var nav_data = _navigators[current_index]
	var nid: StringName = nav_data.navigator_id
	var is_unlocked: bool = SaveManager.is_navigator_unlocked(nid)
	var is_selected: bool = (nid == SaveManager.get_selected_navigator())

	# 1. Indicador numérico de carrusel
	if index_badge:
		index_badge.text = "[ %02d / %02d ]" % [current_index + 1, _navigators.size()]

	# 2. Textos de Identidad en Dossier exterior
	if name_label:
		name_label.text = nav_data.display_name.to_upper()
		name_label.add_theme_color_override("font_color", nav_data.theme_color if is_unlocked else Color(0.6, 0.65, 0.75))
		# Jugoso micro-bump de escala al cambiar
		if animate:
			name_label.pivot_offset = Vector2(0, name_label.size.y * 0.5)
			var tw_name := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_name.tween_property(name_label, "scale", Vector2(1.08, 1.08), 0.06)
			tw_name.tween_property(name_label, "scale", Vector2(1.0, 1.0), 0.12)

	if title_label:
		title_label.text = nav_data.title.to_upper()

	if status_badge:
		if is_selected:
			status_badge.text = "[✓ ENLACE ACTIVO]"
			status_badge.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		elif is_unlocked:
			status_badge.text = "[DISPONIBLE]"
			status_badge.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
		else:
			status_badge.text = "[🔒 BLOQUEADA]"
			status_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	# 3. Radar Táctico
	if radar_desc:
		if is_unlocked:
			radar_desc.text = nav_data.specialty_desc
			radar_desc.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.95))
		else:
			radar_desc.text = "Alcanza cualquiera de los 3 finales del juego (Pacifista, Genocida o Neutral) para sincronizar las frecuencias de esta navegante."
			radar_desc.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.8))

	# 4. Buff Táctico
	if buff_name_label:
		buff_name_label.text = nav_data.buff_name if is_unlocked else "✦ Enlace Cuántico Desconocido"
	if buff_desc_label:
		buff_desc_label.text = nav_data.buff_desc if is_unlocked else "Alcanza un final cósmico para sintonizar este buff activo en combate."

	# Modulación de borde en la tarjeta de buff según el color temático
	if buff_card:
		var sb := buff_card.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var sb_dup := sb.duplicate() as StyleBoxFlat
			if is_unlocked:
				sb_dup.border_color = nav_data.theme_color
				sb_dup.shadow_color = Color(nav_data.theme_color.r, nav_data.theme_color.g, nav_data.theme_color.b, 0.25)
			else:
				sb_dup.border_color = Color(0.3, 0.35, 0.45, 0.6)
				sb_dup.shadow_color = Color(0, 0, 0, 0)
			buff_card.add_theme_stylebox_override("panel", sb_dup)

	# 5. Cita de Radio / Comms
	if radio_dialogue:
		if not nav_data.dialogue_callouts.is_empty():
			radio_dialogue.text = "\"%s\"" % nav_data.dialogue_callouts[0]
		else:
			radio_dialogue.text = "\"Frecuencia de telemetría a la espera...\""

	# 6. Botón de Enlace / Selección
	if select_btn:
		if is_selected:
			select_btn.text = "✓ ENLACE ACTIVO (SELECCIONADA)"
			select_btn.disabled = false
			select_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		elif is_unlocked:
			select_btn.text = "⚡ ENLAZAR A %s [ESPACIO]" % nav_data.display_name.to_upper()
			select_btn.disabled = false
			select_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.85))
		else:
			select_btn.text = "🔒 NAVEGANTE BLOQUEADA"
			select_btn.disabled = true
			select_btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))

	# 7. Arte Full-Body & Estado de Bloqueo
	if fullbody_texture:
		var tex = nav_data.get_fullbody_texture()
		fullbody_texture.texture = tex

	if locked_overlay:
		locked_overlay.visible = not is_unlocked

	# 8. Actualizar indicadores de puntos (Dots)
	_update_dots(nav_data.theme_color)

	# 9. Transición vertical animada del Fullbody
	if animate and is_instance_valid(fullbody_texture):
		if _active_tween and _active_tween.is_valid():
			_active_tween.kill()

		_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		var offset_y: float = 40.0 * (1.0 if slide_direction >= 0 else -1.0)
		fullbody_texture.position.y = offset_y
		fullbody_texture.modulate = Color(1.0, 1.0, 1.0, 0.2) if is_unlocked else Color(0.2, 0.25, 0.35, 0.3)

		_active_tween.tween_property(fullbody_texture, "position:y", 0.0, 0.22)
		var target_modulate := Color.WHITE if is_unlocked else Color(0.2, 0.25, 0.35, 0.7)
		_active_tween.tween_property(fullbody_texture, "modulate", target_modulate, 0.22)
	else:
		if fullbody_texture:
			fullbody_texture.position.y = 0.0
			fullbody_texture.modulate = Color.WHITE if is_unlocked else Color(0.2, 0.25, 0.35, 0.7)

func _update_dots(active_color: Color) -> void:
	for i in range(_nav_buttons.size()):
		var dot_btn := _nav_buttons[i]
		if i == current_index:
			dot_btn.text = "●"
			dot_btn.add_theme_color_override("font_color", active_color)
			dot_btn.modulate = Color(1.3, 1.3, 1.3, 1.0)
		else:
			dot_btn.text = "○"
			dot_btn.add_theme_color_override("font_color", Color(0.4, 0.5, 0.65, 0.7))
			dot_btn.modulate = Color(1.0, 1.0, 1.0, 0.7)

func _on_select_pressed() -> void:
	if _navigators.is_empty() or current_index < 0 or current_index >= _navigators.size():
		return

	var nav_data = _navigators[current_index]
	var nid: StringName = nav_data.navigator_id
	if not SaveManager.is_navigator_unlocked(nid):
		return

	SaveManager.set_selected_navigator(nid)
	navigator_selected.emit(nid)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.25)

	close_modal()

func _setup_focus_neighbors() -> void:
	if up_btn and down_btn and select_btn and close_btn:
		up_btn.focus_neighbor_bottom = down_btn.get_path()
		up_btn.focus_neighbor_right = select_btn.get_path()
		down_btn.focus_neighbor_top = up_btn.get_path()
		down_btn.focus_neighbor_right = select_btn.get_path()
		select_btn.focus_neighbor_left = down_btn.get_path()
		select_btn.focus_neighbor_right = close_btn.get_path()
		close_btn.focus_neighbor_left = select_btn.get_path()
