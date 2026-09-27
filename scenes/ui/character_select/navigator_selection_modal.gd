class_name NavigatorSelectionModal
extends CanvasLayer

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")

signal navigator_selected(nav_id: StringName)
signal skin_equipped(slot_key: String, skin_id: String)
signal closed()

@onready var index_badge: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ModalHeader/IndexBadge

@onready var prev_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/CoverFlowSection/CoverFlowRow/PrevButton
@onready var next_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/CoverFlowSection/CoverFlowRow/NextButton

@onready var left_card: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/CoverFlowSection/CoverFlowRow/CardsRow/LeftCard
@onready var left_texture: TextureRect = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/CoverFlowSection/CoverFlowRow/CardsRow/LeftCard/VBox/LeftTexture
@onready var left_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/CoverFlowSection/CoverFlowRow/CardsRow/LeftCard/VBox/LeftLabel

@onready var artwork_frame: PanelContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame
@onready var artwork_viewport: Control = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame/ArtworkViewport
@onready var fullbody_texture: TextureRect = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame/ArtworkViewport/FullbodyTexture
@onready var locked_overlay: Control = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame/LockedOverlay
@onready var lock_desc: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame/LockedOverlay/LockCenter/LockDesc

@onready var right_card: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/CoverFlowSection/CoverFlowRow/CardsRow/RightCard
@onready var right_texture: TextureRect = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/CoverFlowSection/CoverFlowRow/CardsRow/RightCard/VBox/RightTexture
@onready var right_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/CoverFlowSection/CoverFlowRow/CardsRow/RightCard/VBox/RightLabel

@onready var dots_container: HBoxContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/CoverFlowSection/DotsContainer

@onready var name_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/DossierSection/DossierHeader/NameRow/NameLabel
@onready var status_badge: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/DossierSection/DossierHeader/NameRow/StatusBadge
@onready var title_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/DossierSection/DossierHeader/TitleLabel
@onready var radio_dialogue: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/DossierSection/RadioCard/Margin/VBox/RadioDialogue

@onready var radar_desc: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/DossierSection/RadarCard/Margin/VBox/RadarDesc
@onready var buff_card: PanelContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/DossierSection/BuffCard
@onready var buff_name_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/DossierSection/BuffCard/Margin/VBox/BuffNameLabel
@onready var buff_desc_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/DossierSection/BuffCard/Margin/VBox/BuffDescLabel

@onready var select_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/DossierSection/ButtonsContainer/SelectButton
@onready var close_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/MainColumns/DossierSection/ButtonsContainer/CloseButton

var is_open: bool = false
var current_index: int = 0
var _navigators: Array = []
var _nav_buttons: Array[Button] = []
var _active_tween: Tween = null

# Modo Galería de Skins CoverFlow
var _is_skin_mode: bool = false
var _nav_skins: Array[Dictionary] = []
var _skin_index: int = 0
var skins_btn: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 126
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

	# Botón de Aspectos / Skins CoverFlow
	skins_btn = Button.new()
	skins_btn.name = "SkinsButton"
	skins_btn.text = "🎨 ASPECTOS / SKINS"
	skins_btn.custom_minimum_size = Vector2(180, 44)
	skins_btn.pressed.connect(_on_skins_toggle_pressed)
	UIFocusHelper.apply_cyber_focus(skins_btn)
	if select_btn and select_btn.get_parent():
		select_btn.get_parent().add_child(skins_btn)
		select_btn.get_parent().move_child(skins_btn, select_btn.get_index() + 1)

	_setup_focus_neighbors()

func open_modal() -> void:
	is_open = true
	_is_skin_mode = false
	show()
	_populate_navigators()
	if select_btn and not select_btn.disabled:
		select_btn.grab_focus()
	elif next_btn:
		next_btn.grab_focus()
	elif close_btn:
		close_btn.grab_focus()

func close_modal() -> void:
	if not is_open:
		return
	if _is_skin_mode:
		_is_skin_mode = false
		_populate_navigators()
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

	if skins_btn:
		skins_btn.text = "🎨 ASPECTOS / SKINS"
		skins_btn.modulate = Color(1.0, 0.85, 0.2, 1.0)

	_build_dots(_navigators.size(), current_index)
	_display_current_navigator(false, 0)

func _populate_navigator_skins() -> void:
	if _navigators.is_empty():
		return
	var cur_nav = _navigators[current_index]
	var nid_str := String(cur_nav.navigator_id).to_lower()
	_nav_skins = CosmeticsManager.get_skins_for_target("navigator", nid_str)

	var slot_key := "navigator:" + nid_str
	var equipped_sid := SaveManager.get_equipped_skin(slot_key)
	_skin_index = 0
	for i in range(_nav_skins.size()):
		if _nav_skins[i].get("id", "") == equipped_sid:
			_skin_index = i
			break

	if skins_btn:
		skins_btn.text = "↺ VOLVER A NAVEGADORAS"
		skins_btn.modulate = Color(0.2, 0.9, 1.0, 1.0)

	_build_dots(_nav_skins.size(), _skin_index)
	_display_current_skin(false, 0)

func _build_dots(count: int, active_idx: int) -> void:
	if not dots_container:
		return

	for child in dots_container.get_children():
		dots_container.remove_child(child)
		child.queue_free()
	_nav_buttons.clear()

	for i in range(count):
		var dot_btn := Button.new()
		dot_btn.custom_minimum_size = Vector2(24, 24)
		dot_btn.flat = true
		dot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		dot_btn.text = "●" if i == active_idx else "○"
		dot_btn.add_theme_font_size_override("font_size", 16)
		dot_btn.focus_mode = Control.FOCUS_NONE

		var target_idx := i
		dot_btn.pressed.connect(func():
			var cur := _skin_index if _is_skin_mode else current_index
			if cur != target_idx:
				var dir: int = 1 if target_idx > cur else -1
				_set_index(target_idx, dir)
		)

		dots_container.add_child(dot_btn)
		_nav_buttons.append(dot_btn)

func _cycle(direction: int) -> void:
	if _is_skin_mode:
		if _nav_skins.is_empty():
			return
		var count := _nav_skins.size()
		var next_idx := (_skin_index + direction) % count
		if next_idx < 0:
			next_idx += count
		_set_index(next_idx, direction)
	else:
		if _navigators.is_empty():
			return
		var count := _navigators.size()
		var next_idx := (current_index + direction) % count
		if next_idx < 0:
			next_idx += count
		_set_index(next_idx, direction)

func _set_index(new_idx: int, slide_direction: int = 0) -> void:
	if _is_skin_mode:
		if new_idx == _skin_index:
			return
		_skin_index = new_idx
		_display_current_skin(true, slide_direction)
	else:
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

	var count := _navigators.size()
	var nav_data = _navigators[current_index]
	var nid: StringName = nav_data.navigator_id
	var is_unlocked: bool = SaveManager.is_navigator_unlocked(nid)
	var is_selected: bool = (nid == SaveManager.get_selected_navigator())

	if index_badge:
		index_badge.text = "[ %02d / %02d ]" % [current_index + 1, count]

	# Cartas Laterales (Navegantes Fullbody)
	var left_idx := (current_index - 1 + count) % count
	var right_idx := (current_index + 1) % count
	var left_data = _navigators[left_idx]
	var right_data = _navigators[right_idx]

	if left_texture and left_data:
		left_texture.texture = left_data.get_fullbody_texture()
	if left_label and left_data:
		left_label.text = "◀ %s" % left_data.display_name.to_upper()
		left_label.modulate = left_data.theme_color

	if right_texture and right_data:
		right_texture.texture = right_data.get_fullbody_texture()
	if right_label and right_data:
		right_label.text = "%s ▶" % right_data.display_name.to_upper()
		right_label.modulate = right_data.theme_color

	if name_label:
		name_label.text = nav_data.display_name.to_upper()
		name_label.add_theme_color_override("font_color", nav_data.theme_color if is_unlocked else Color(0.6, 0.65, 0.75))

	if title_label:
		title_label.text = "— " + nav_data.title.to_upper()

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

	if radio_dialogue:
		if not nav_data.dialogue_callouts.is_empty():
			radio_dialogue.text = "\"%s\"" % nav_data.dialogue_callouts[0]
		else:
			radio_dialogue.text = "\"Frecuencia de telemetría a la espera...\""

	if radar_desc:
		radar_desc.text = nav_data.radar_description if is_unlocked else "Algoritmo de telemetría clasificado."
	if buff_desc_label:
		buff_desc_label.text = nav_data.passive_description if is_unlocked else "Enlace táctico bloqueado."

	# Botón de Selección
	if select_btn:
		select_btn.disabled = not is_unlocked
		if is_selected:
			select_btn.text = "✓ ENLACE ACTIVO (SELECCIONADA)"
			select_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		elif is_unlocked:
			select_btn.text = "⚡ ENLAZAR A %s [ESPACIO]" % nav_data.display_name.to_upper()
			select_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.85))
		else:
			select_btn.text = "🔒 NAVEGANTE BLOQUEADA"
			select_btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))

	# Retrato Central: siempre el Fullbody de la Navegante; si tiene skin equipada, aplicar shader cósmico sin perder el fullbody
	if fullbody_texture:
		fullbody_texture.texture = nav_data.get_fullbody_texture()
		var slot_key := "navigator:" + String(nid).to_lower()
		var equipped_skin := SaveManager.get_equipped_skin(slot_key)
		if equipped_skin != "" and SaveManager.is_skin_unlocked(equipped_skin):
			var stars := SaveManager.get_skin_stars(equipped_skin)
			CosmeticsManager.apply_skin_to_canvas_item(fullbody_texture, equipped_skin, stars, false)
		else:
			fullbody_texture.material = null

	if locked_overlay:
		locked_overlay.visible = not is_unlocked

	_update_carousel_layout(false, nav_data.theme_color)
	_update_dots(nav_data.theme_color, current_index)
	_animate_center_card(animate, slide_direction, is_unlocked)

func _display_current_skin(animate: bool = true, slide_direction: int = 0) -> void:
	if _nav_skins.is_empty():
		return

	var count := _nav_skins.size()
	var cur_skin: Dictionary = _nav_skins[_skin_index]
	var sid: String = cur_skin.get("id", "")
	var sname: String = cur_skin.get("skin_name", "Aspecto")
	var pal_name: String = cur_skin.get("palette_id", "").replace("_", " ").capitalize()
	var desc: String = cur_skin.get("description", "")

	var is_unlocked: bool = bool(SaveManager.is_skin_unlocked(sid))
	var stars: int = SaveManager.get_skin_stars(sid) if is_unlocked else 1
	var slot_key := "navigator:" + String(_navigators[current_index].navigator_id).to_lower()
	var currently_equipped := SaveManager.get_equipped_skin(slot_key)
	var is_equipped: bool = (currently_equipped == sid)

	if index_badge:
		index_badge.text = "[ ASPECTO: %02d / %02d ]" % [_skin_index + 1, count]

	# Cartas Laterales (Skins)
	var left_idx := (_skin_index - 1 + count) % count
	var right_idx := (_skin_index + 1) % count
	var left_skin: Dictionary = _nav_skins[left_idx]
	var right_skin: Dictionary = _nav_skins[right_idx]

	if left_texture:
		left_texture.texture = CosmeticsManager.load_texture(left_skin.get("texture_path", ""))
	if left_label:
		left_label.text = "◀ " + left_skin.get("skin_name", "").to_upper()
		left_label.modulate = Color(0.7, 0.85, 1.0)

	if right_texture:
		right_texture.texture = CosmeticsManager.load_texture(right_skin.get("texture_path", ""))
	if right_label:
		right_label.text = right_skin.get("skin_name", "").to_upper() + " ▶"
		right_label.modulate = Color(0.7, 0.85, 1.0)

	if name_label:
		name_label.text = sname.to_upper()
		name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2) if is_unlocked else Color(0.6, 0.65, 0.75))

	if title_label:
		var star_str := ""
		for s in range(stars):
			star_str += "★"
		title_label.text = "[%s %d★ | Paleta: %s]" % [star_str, stars, pal_name]

	if status_badge:
		if is_equipped:
			status_badge.text = "[✓ EQUIPADO]"
			status_badge.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		elif is_unlocked:
			status_badge.text = "[DESBLOQUEADO]"
			status_badge.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
		else:
			status_badge.text = "[🔒 GACHA]"
			status_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	if radio_dialogue:
		radio_dialogue.text = desc
	if radar_desc:
		radar_desc.text = "Personalización de telemetría y comunicaciones tácticas."
	if buff_desc_label:
		buff_desc_label.text = "Aura holográfica y destellos estelares para la navegante."

	# Botón de Equipar Aspecto
	if select_btn:
		select_btn.disabled = not is_unlocked
		if is_equipped:
			select_btn.text = "✓ DESEQUIPAR ASPECTO"
			select_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		elif is_unlocked:
			select_btn.text = "★ EQUIPAR ESTE ASPECTO"
			select_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		else:
			select_btn.text = "🔒 BLOQUEADO EN GACHA"
			select_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	# Retrato Central con Shader
	if fullbody_texture:
		var tex := CosmeticsManager.load_texture(cur_skin.get("texture_path", ""))
		fullbody_texture.texture = tex
		if is_unlocked and stars > 1:
			CosmeticsManager.apply_skin_to_canvas_item(fullbody_texture, sid, stars)
		else:
			fullbody_texture.material = null

	if locked_overlay:
		locked_overlay.visible = not is_unlocked
		if lock_desc:
			lock_desc.text = "CONSEGUIR EN GACHA"

	var pal_color := Color.from_string(cur_skin.get("glow_hex", "#00F0FF"), Color.CYAN)
	_update_carousel_layout(true, pal_color)
	_update_dots(Color(1.0, 0.85, 0.2), _skin_index)
	_animate_center_card(animate, slide_direction, is_unlocked)

func _update_carousel_layout(is_skin: bool, theme_color: Color) -> void:
	if not artwork_frame:
		return

	if is_skin:
		# Modo Skins: carrusel redondo circular holográfico como las pets
		artwork_frame.custom_minimum_size = Vector2(285, 285)
		artwork_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var af_sb := StyleBoxFlat.new()
		af_sb.bg_color = Color(0.02, 0.035, 0.065, 0.95)
		af_sb.border_color = theme_color
		af_sb.set_border_width_all(3)
		af_sb.set_corner_radius_all(142) # Redondo / Circular
		af_sb.shadow_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.35)
		af_sb.shadow_size = 14
		artwork_frame.add_theme_stylebox_override("panel", af_sb)

		if left_card:
			left_card.custom_minimum_size = Vector2(200, 200)
			left_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var side_sb := StyleBoxFlat.new()
			side_sb.bg_color = Color(0.02, 0.03, 0.06, 0.85)
			side_sb.border_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.45)
			side_sb.set_border_width_all(2)
			side_sb.set_corner_radius_all(100) # Redondo / Circular
			left_card.add_theme_stylebox_override("normal", side_sb)
			left_card.add_theme_stylebox_override("hover", side_sb)
			left_card.add_theme_stylebox_override("pressed", side_sb)

		if right_card:
			right_card.custom_minimum_size = Vector2(200, 200)
			right_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var side_sb := StyleBoxFlat.new()
			side_sb.bg_color = Color(0.02, 0.03, 0.06, 0.85)
			side_sb.border_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.45)
			side_sb.set_border_width_all(2)
			side_sb.set_corner_radius_all(100) # Redondo / Circular
			right_card.add_theme_stylebox_override("normal", side_sb)
			right_card.add_theme_stylebox_override("hover", side_sb)
			right_card.add_theme_stylebox_override("pressed", side_sb)
	else:
		# Modo Navegadoras: marco esbelto para fullbody majestuoso
		artwork_frame.custom_minimum_size = Vector2(250, 480)
		artwork_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var af_sb := StyleBoxFlat.new()
		af_sb.bg_color = Color(0.02, 0.035, 0.065, 0.95)
		af_sb.border_color = theme_color
		af_sb.set_border_width_all(2)
		af_sb.set_corner_radius_all(8)
		af_sb.shadow_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.25)
		af_sb.shadow_size = 10
		artwork_frame.add_theme_stylebox_override("panel", af_sb)

		if left_card:
			left_card.custom_minimum_size = Vector2(170, 400)
			left_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var side_sb := StyleBoxFlat.new()
			side_sb.bg_color = Color(0.02, 0.03, 0.06, 0.85)
			side_sb.border_color = Color(0.2, 0.35, 0.5, 0.6)
			side_sb.set_border_width_all(1)
			side_sb.set_corner_radius_all(6)
			left_card.add_theme_stylebox_override("normal", side_sb)
			left_card.add_theme_stylebox_override("hover", side_sb)
			left_card.add_theme_stylebox_override("pressed", side_sb)

		if right_card:
			right_card.custom_minimum_size = Vector2(170, 400)
			right_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var side_sb := StyleBoxFlat.new()
			side_sb.bg_color = Color(0.02, 0.03, 0.06, 0.85)
			side_sb.border_color = Color(0.2, 0.35, 0.5, 0.6)
			side_sb.set_border_width_all(1)
			side_sb.set_corner_radius_all(6)
			right_card.add_theme_stylebox_override("normal", side_sb)
			right_card.add_theme_stylebox_override("hover", side_sb)
			right_card.add_theme_stylebox_override("pressed", side_sb)

func _update_dots(active_color: Color, active_idx: int) -> void:
	for i in range(_nav_buttons.size()):
		var dot_btn := _nav_buttons[i]
		if i == active_idx:
			dot_btn.text = "●"
			dot_btn.add_theme_color_override("font_color", active_color)
			dot_btn.modulate = Color(1.3, 1.3, 1.3, 1.0)
		else:
			dot_btn.text = "○"
			dot_btn.add_theme_color_override("font_color", Color(0.4, 0.5, 0.65, 0.7))
			dot_btn.modulate = Color(1.0, 1.0, 1.0, 0.7)

func _animate_center_card(animate: bool, slide_direction: int, is_unlocked: bool) -> void:
	if animate and is_instance_valid(fullbody_texture):
		if _active_tween and _active_tween.is_valid():
			_active_tween.kill()

		_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var offset_x: float = 45.0 * (1.0 if slide_direction >= 0 else -1.0)
		fullbody_texture.position.x = offset_x
		_active_tween.tween_property(fullbody_texture, "position:x", 0.0, 0.22)
		var target_modulate := Color.WHITE if is_unlocked else Color(0.2, 0.25, 0.35, 0.7)
		_active_tween.tween_property(fullbody_texture, "modulate", target_modulate, 0.22)
	else:
		if fullbody_texture:
			fullbody_texture.position.x = 0.0
			fullbody_texture.modulate = Color.WHITE if is_unlocked else Color(0.2, 0.25, 0.35, 0.7)

func _on_skins_toggle_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.2)

	if _is_skin_mode:
		_is_skin_mode = false
		_populate_navigators()
	else:
		_is_skin_mode = true
		_populate_navigator_skins()

func _on_select_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.25)

	if _is_skin_mode:
		if _nav_skins.is_empty():
			return
		var cur_skin: Dictionary = _nav_skins[_skin_index]
		var sid: String = cur_skin.get("id", "")
		var slot_key := "navigator:" + String(_navigators[current_index].navigator_id).to_lower()
		var currently_equipped := SaveManager.get_equipped_skin(slot_key)

		if currently_equipped == sid:
			SaveManager.unequip_skin(slot_key)
			skin_equipped.emit(slot_key, "")
		elif SaveManager.is_skin_unlocked(sid):
			SaveManager.equip_skin(slot_key, sid)
			skin_equipped.emit(slot_key, sid)

		_display_current_skin(false, 0)
	else:
		if _navigators.is_empty() or current_index < 0 or current_index >= _navigators.size():
			return
		var nav_data = _navigators[current_index]
		var nid: StringName = nav_data.navigator_id
		if not SaveManager.is_navigator_unlocked(nid):
			return
		SaveManager.set_selected_navigator(nid)
		navigator_selected.emit(nid)
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
		if skins_btn:
			select_btn.focus_neighbor_right = skins_btn.get_path()
			skins_btn.focus_neighbor_left = select_btn.get_path()
			skins_btn.focus_neighbor_right = close_btn.get_path()
			close_btn.focus_neighbor_left = skins_btn.get_path()
		else:
			select_btn.focus_neighbor_right = close_btn.get_path()
			close_btn.focus_neighbor_left = select_btn.get_path()
		close_btn.focus_neighbor_top = next_btn.get_path()
