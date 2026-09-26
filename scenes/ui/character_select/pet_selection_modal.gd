class_name PetSelectionModal
extends CanvasLayer

signal pet_selected(pet_id: StringName)
signal closed()

@onready var index_badge: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ModalHeader/IndexBadge

@onready var prev_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/PrevButton
@onready var next_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/NextButton

@onready var left_card: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/LeftCard
@onready var left_texture: TextureRect = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/LeftCard/VBox/LeftTexture
@onready var left_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/LeftCard/VBox/LeftLabel

@onready var artwork_frame: PanelContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame
@onready var artwork_viewport: Control = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame/ArtworkViewport
@onready var fullbody_texture: TextureRect = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame/ArtworkViewport/FullbodyTexture
@onready var locked_overlay: Control = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame/LockedOverlay
@onready var lock_desc: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame/LockedOverlay/LockCenter/LockDesc

@onready var right_card: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/RightCard
@onready var right_texture: TextureRect = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/RightCard/VBox/RightTexture
@onready var right_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/RightCard/VBox/RightLabel

@onready var dots_container: HBoxContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/DotsContainer

@onready var name_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/HeaderRow/NameLabel
@onready var title_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/HeaderRow/TitleLabel
@onready var status_badge: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/HeaderRow/StatusBadge

@onready var bio_desc: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/CardsRow/BioCard/Margin/VBox/BioDesc
@onready var power_card: PanelContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/CardsRow/PowerCard
@onready var power_desc: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/CardsRow/PowerCard/Margin/VBox/PowerDesc

@onready var select_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/ActionsRow/SelectButton
@onready var close_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/ActionsRow/CloseButton

var is_open: bool = false
var current_index: int = 0
var _pets: Array[PetData] = []
var _nav_buttons: Array[Button] = []
var _active_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 125
	hide()

	if prev_btn:
		prev_btn.pressed.connect(func(): _cycle(-1))
		UIFocusHelper.apply_cyber_focus(prev_btn)
	if next_btn:
		next_btn.pressed.connect(func(): _cycle(1))
		UIFocusHelper.apply_cyber_focus(next_btn)

	if left_card:
		left_card.pressed.connect(func(): _cycle(-1))
		UIFocusHelper.apply_cyber_focus(left_card)
	if right_card:
		right_card.pressed.connect(func(): _cycle(1))
		UIFocusHelper.apply_cyber_focus(right_card)

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
	_populate_pets()
	if select_btn and not select_btn.disabled:
		select_btn.grab_focus()
	elif next_btn:
		next_btn.grab_focus()
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

	# Navegación Cover Flow con teclas A / D, flechas y W / S
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A or event.keycode == KEY_LEFT or event.keycode == KEY_W or event.keycode == KEY_UP:
			get_viewport().set_input_as_handled()
			_cycle(-1)
			return
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT or event.keycode == KEY_S or event.keycode == KEY_DOWN:
			get_viewport().set_input_as_handled()
			_cycle(1)
			return
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if select_btn and not select_btn.disabled:
				get_viewport().set_input_as_handled()
				_on_select_pressed()
				return

	# Rueda del ratón para Cover Flow
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			get_viewport().set_input_as_handled()
			_cycle(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()
			_cycle(1)

func _populate_pets() -> void:
	const PetDataScript := preload("res://data/pets/pet_data.gd")
	_pets = PetDataScript.load_roster_ordered()

	var selected_pid := SaveManager.get_selected_pet()
	var initial_index: int = 0
	for i in range(_pets.size()):
		if _pets[i].pet_id == selected_pid:
			initial_index = i
			break
	current_index = initial_index

	_build_dots()
	_display_current_pet(false, 0)

func _build_dots() -> void:
	if not dots_container:
		return

	for child in dots_container.get_children():
		dots_container.remove_child(child)
		child.queue_free()
	_nav_buttons.clear()

	for i in range(_pets.size()):
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
	if _pets.is_empty():
		return
	var count := _pets.size()
	var next_idx := (current_index + direction) % count
	if next_idx < 0:
		next_idx += count
	_set_index(next_idx, direction)

func _set_index(new_idx: int, slide_direction: int = 0) -> void:
	if new_idx == current_index:
		return
	current_index = new_idx
	_display_current_pet(true, slide_direction)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_hover", 0.0, 1.1)

func _display_current_pet(animate: bool = true, slide_direction: int = 0) -> void:
	if _pets.is_empty() or current_index < 0 or current_index >= _pets.size():
		return

	var count := _pets.size()
	var pet_data: PetData = _pets[current_index]
	var pid: StringName = pet_data.pet_id
	var is_unlocked: bool = SaveManager.is_pet_unlocked(pid)
	var is_selected: bool = (pid == SaveManager.get_selected_pet())

	# 1. Indicador numérico
	if index_badge:
		index_badge.text = "[ %02d / %02d ]" % [current_index + 1, count]

	# 2. Cartas Laterales de Cover Flow
	var left_idx := (current_index - 1 + count) % count
	var right_idx := (current_index + 1) % count
	var left_data: PetData = _pets[left_idx]
	var right_data: PetData = _pets[right_idx]

	if left_texture and left_data:
		left_texture.texture = left_data.get_icon_texture()
	if left_label and left_data:
		left_label.text = "◀ %s" % left_data.display_name.to_upper()
		left_label.modulate = left_data.theme_color

	if right_texture and right_data:
		right_texture.texture = right_data.get_icon_texture()
	if right_label and right_data:
		right_label.text = "%s ▶" % right_data.display_name.to_upper()
		right_label.modulate = right_data.theme_color

	# 3. Textos de Identidad en Dossier
	if name_label:
		name_label.text = pet_data.display_name.to_upper()
		name_label.add_theme_color_override("font_color", pet_data.theme_color if is_unlocked else Color(0.6, 0.65, 0.75))
		if animate:
			name_label.pivot_offset = Vector2(0, name_label.size.y * 0.5)
			var tw_name := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_name.tween_property(name_label, "scale", Vector2(1.08, 1.08), 0.06)
			tw_name.tween_property(name_label, "scale", Vector2(1.0, 1.0), 0.12)

	if title_label:
		title_label.text = "— " + pet_data.title.to_upper()

	if status_badge:
		if is_selected:
			status_badge.text = "[✓ EQUIPADO]"
			status_badge.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		elif is_unlocked:
			status_badge.text = "[DISPONIBLE]"
			status_badge.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
		else:
			status_badge.text = "[🔒 BLOQUEADO (10 MIN)]"
			status_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	# 4. Biografía y Protocolo
	if bio_desc:
		if is_unlocked:
			bio_desc.text = pet_data.description
			bio_desc.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.95))
		else:
			bio_desc.text = "Mascota secreta astral imbuida de energía cuántica. Requiere sintonización en el hiperespacio."
			bio_desc.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.85))

	# 5. Habilidad en Combate
	if power_desc:
		if is_unlocked:
			power_desc.text = pet_data.power_description
			power_desc.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0, 0.95))
		else:
			power_desc.text = "Sobrevive al menos 10 minutos continuos en cualquier incursión de combate para liberar su poder."
			power_desc.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.85))

	if power_card:
		var sb_p := power_card.get_theme_stylebox("panel")
		if sb_p is StyleBoxFlat:
			sb_p.border_color = pet_data.theme_color if is_unlocked else Color(0.3, 0.35, 0.45)
			sb_p.shadow_color = Color(pet_data.theme_color.r, pet_data.theme_color.g, pet_data.theme_color.b, 0.25 if is_unlocked else 0.05)

	# 6. Botón de Selección
	if select_btn:
		var sb_btn := StyleBoxFlat.new()
		sb_btn.set_corner_radius_all(6)
		if is_selected:
			sb_btn.bg_color = Color(0.02, 0.16, 0.22, 0.95)
			sb_btn.border_color = Color(0.0, 0.94, 1.0, 0.9)
			sb_btn.set_border_width_all(2)
			sb_btn.shadow_color = Color(0.0, 0.94, 1.0, 0.3)
			sb_btn.shadow_size = 6
		elif is_unlocked:
			sb_btn.bg_color = Color(0.05, 0.10, 0.18, 0.95)
			sb_btn.border_color = pet_data.theme_color
			sb_btn.set_border_width_all(1)
		else:
			sb_btn.bg_color = Color(0.04, 0.05, 0.08, 0.85)
			sb_btn.border_color = Color(0.25, 0.3, 0.4, 0.5)
			sb_btn.set_border_width_all(1)

		select_btn.add_theme_stylebox_override("normal", sb_btn)
		select_btn.add_theme_stylebox_override("hover", sb_btn)
		select_btn.add_theme_stylebox_override("pressed", sb_btn)

		if is_selected:
			select_btn.text = "✓ EQUIPADO (SELECCIONADA)"
			select_btn.disabled = false
			select_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.85))
		elif is_unlocked:
			select_btn.text = "⚡ EQUIPAR MASCOTA [ESPACIO]"
			select_btn.disabled = false
			select_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.85))
		else:
			select_btn.text = "🔒 MASCOTA BLOQUEADA"
			select_btn.disabled = true
			select_btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))

	# 7. Marco de Arte y Borde dinámico con el color temático
	if artwork_frame:
		var sb: StyleBoxFlat = artwork_frame.get_theme_stylebox("panel")
		if sb:
			var active_color: Color = pet_data.theme_color if is_unlocked else Color(0.3, 0.35, 0.45)
			sb.border_color = active_color
			sb.shadow_color = Color(active_color.r, active_color.g, active_color.b, 0.35 if is_unlocked else 0.05)

	# 8. Retrato Central & Bloqueo
	if fullbody_texture:
		var tex = pet_data.get_icon_texture()
		fullbody_texture.texture = tex

	if locked_overlay:
		locked_overlay.visible = not is_unlocked

	# 9. Actualizar puntos indicadores (Dots)
	_update_dots(pet_data.theme_color)

	# 10. Transición animada horizontal del Cover Flow central
	if animate and is_instance_valid(fullbody_texture):
		if _active_tween and _active_tween.is_valid():
			_active_tween.kill()

		_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		var offset_x: float = 35.0 * (1.0 if slide_direction >= 0 else -1.0)
		fullbody_texture.position.x = offset_x
		fullbody_texture.modulate = Color(1.0, 1.0, 1.0, 0.25) if is_unlocked else Color(0.2, 0.25, 0.35, 0.3)

		_active_tween.tween_property(fullbody_texture, "position:x", 0.0, 0.22)
		var target_modulate := Color.WHITE if is_unlocked else Color(0.2, 0.25, 0.35, 0.7)
		_active_tween.tween_property(fullbody_texture, "modulate", target_modulate, 0.22)
	else:
		if fullbody_texture:
			fullbody_texture.position.x = 0.0
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
	if _pets.is_empty() or current_index < 0 or current_index >= _pets.size():
		return

	var pet_data = _pets[current_index]
	var pid: StringName = pet_data.pet_id
	if not SaveManager.is_pet_unlocked(pid):
		return

	SaveManager.set_selected_pet(pid)
	pet_selected.emit(pid)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.25)

	close_modal()

func _setup_focus_neighbors() -> void:
	if left_card:
		left_card.focus_mode = Control.FOCUS_NONE
	if right_card:
		right_card.focus_mode = Control.FOCUS_NONE

	if prev_btn and next_btn and select_btn and close_btn:
		prev_btn.focus_neighbor_right = next_btn.get_path()
		prev_btn.focus_neighbor_bottom = select_btn.get_path()
		next_btn.focus_neighbor_left = prev_btn.get_path()
		next_btn.focus_neighbor_bottom = select_btn.get_path()
		select_btn.focus_neighbor_top = next_btn.get_path()
		select_btn.focus_neighbor_right = close_btn.get_path()
		close_btn.focus_neighbor_left = select_btn.get_path()
		close_btn.focus_neighbor_top = next_btn.get_path()
