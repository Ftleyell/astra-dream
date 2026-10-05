class_name NavigatorCoverFlowRenderer
extends RefCounted

## NavigatorCoverFlowRenderer.gd
## Renderizador modular de carrusel CoverFlow para NavigatorSelectionModal.
## Gestiona cartas laterales (izquierda/derecha), tarjeta central full-body/shader,
## indicadores de paginación por puntos, layouts dinámicos (navegante vs skins) y tweens de animación.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const NavigatorDataScript = preload("res://data/navigators/navigator_data.gd")

var prev_btn: Button = null
var next_btn: Button = null

var cards_row: HBoxContainer = null
var left_card: Button = null
var left_texture: TextureRect = null
var left_label: Label = null

var artwork_frame: PanelContainer = null
var artwork_viewport: Control = null
var fullbody_texture: TextureRect = null
var locked_overlay: Control = null
var lock_title: Label = null
var lock_desc: Label = null

var right_card: Button = null
var right_texture: TextureRect = null
var right_label: Label = null

var dots_container: HBoxContainer = null
var nav_buttons: Array[Button] = []
var active_tween: Tween = null

var on_cycle_callback: Callable = Callable()


func setup(
	p_prev_btn: Button,
	p_next_btn: Button,
	p_cards_row: HBoxContainer,
	p_left_card: Button,
	p_left_tex: TextureRect,
	p_left_lbl: Label,
	p_artwork_frame: PanelContainer,
	p_artwork_viewport: Control,
	p_fullbody_tex: TextureRect,
	p_locked_overlay: Control,
	p_lock_title: Label,
	p_lock_desc: Label,
	p_right_card: Button,
	p_right_tex: TextureRect,
	p_right_lbl: Label,
	p_dots_container: HBoxContainer,
	p_on_cycle: Callable
) -> void:
	prev_btn = p_prev_btn
	next_btn = p_next_btn
	cards_row = p_cards_row
	left_card = p_left_card
	left_texture = p_left_tex
	left_label = p_left_lbl
	artwork_frame = p_artwork_frame
	artwork_viewport = p_artwork_viewport
	fullbody_texture = p_fullbody_tex
	locked_overlay = p_locked_overlay
	lock_title = p_lock_title
	lock_desc = p_lock_desc
	right_card = p_right_card
	right_texture = p_right_tex
	right_label = p_right_lbl
	dots_container = p_dots_container
	on_cycle_callback = p_on_cycle

	if prev_btn:
		prev_btn.pressed.connect(func() -> void:
			if on_cycle_callback.is_valid():
				on_cycle_callback.call(-1)
		)
		UIFocusHelper.apply_cyber_focus(prev_btn)
	if next_btn:
		next_btn.pressed.connect(func() -> void:
			if on_cycle_callback.is_valid():
				on_cycle_callback.call(1)
		)
		UIFocusHelper.apply_cyber_focus(next_btn)

	if left_card:
		left_card.pressed.connect(func() -> void:
			if on_cycle_callback.is_valid():
				on_cycle_callback.call(-1)
		)
		UIFocusHelper.apply_cyber_focus(left_card)
	if right_card:
		right_card.pressed.connect(func() -> void:
			if on_cycle_callback.is_valid():
				on_cycle_callback.call(1)
		)
		UIFocusHelper.apply_cyber_focus(right_card)


func build_dots(count: int, active_idx: int, on_select_index: Callable) -> void:
	if not dots_container:
		return

	for child in dots_container.get_children():
		dots_container.remove_child(child)
		child.queue_free()
	nav_buttons.clear()

	for i in range(count):
		var dot_btn := Button.new()
		dot_btn.custom_minimum_size = Vector2(24, 24)
		dot_btn.flat = true
		dot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		dot_btn.text = "●" if i == active_idx else "○"
		dot_btn.add_theme_font_size_override("font_size", 16)
		dot_btn.focus_mode = Control.FOCUS_NONE

		var target_idx := i
		dot_btn.pressed.connect(func() -> void:
			if on_select_index.is_valid():
				on_select_index.call(target_idx)
		)

		dots_container.add_child(dot_btn)
		nav_buttons.append(dot_btn)


func update_dots(active_color: Color, active_idx: int) -> void:
	for i in range(nav_buttons.size()):
		var dot_btn := nav_buttons[i]
		if i == active_idx:
			dot_btn.text = "●"
			dot_btn.add_theme_color_override("font_color", active_color)
			dot_btn.modulate = Color(1.3, 1.3, 1.3, 1.0)
		else:
			dot_btn.text = "○"
			dot_btn.add_theme_color_override("font_color", Color(0.4, 0.5, 0.65, 0.7))
			dot_btn.modulate = Color(1.0, 1.0, 1.0, 0.7)


func update_carousel_layout(_is_skin: bool, theme_color: Color) -> void:
	if not artwork_frame:
		return

	if cards_row:
		cards_row.add_theme_constant_override("separation", -45)

	artwork_frame.z_index = 2
	artwork_frame.custom_minimum_size = Vector2(260, 260)
	artwork_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var af_sb := StyleBoxFlat.new()
	af_sb.bg_color = Color(0.02, 0.035, 0.065, 0.95)
	af_sb.border_color = theme_color
	af_sb.set_border_width_all(3)
	af_sb.set_corner_radius_all(130)
	af_sb.shadow_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.45)
	af_sb.shadow_size = 18
	artwork_frame.add_theme_stylebox_override("panel", af_sb)

	if left_card:
		left_card.z_index = 0
		left_card.modulate = Color(0.75, 0.82, 0.95, 0.65)
		left_card.custom_minimum_size = Vector2(150, 150)
		left_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var side_sb := StyleBoxFlat.new()
		side_sb.bg_color = Color(0.02, 0.03, 0.06, 0.85)
		side_sb.border_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.45)
		side_sb.set_border_width_all(2)
		side_sb.set_corner_radius_all(75)
		left_card.add_theme_stylebox_override("normal", side_sb)
		left_card.add_theme_stylebox_override("hover", side_sb)
		left_card.add_theme_stylebox_override("pressed", side_sb)
	if left_label:
		left_label.visible = false

	if right_card:
		right_card.z_index = 0
		right_card.modulate = Color(0.75, 0.82, 0.95, 0.65)
		right_card.custom_minimum_size = Vector2(150, 150)
		right_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var side_sb := StyleBoxFlat.new()
		side_sb.bg_color = Color(0.02, 0.03, 0.06, 0.85)
		side_sb.border_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.45)
		side_sb.set_border_width_all(2)
		side_sb.set_corner_radius_all(75)
		right_card.add_theme_stylebox_override("normal", side_sb)
		right_card.add_theme_stylebox_override("hover", side_sb)
		right_card.add_theme_stylebox_override("pressed", side_sb)
	if right_label:
		right_label.visible = false


func render_navigator_cards(
	nav_data: NavigatorDataScript,
	left_data: NavigatorDataScript,
	right_data: NavigatorDataScript,
	is_unlocked: bool,
	equipped_skin: String,
	skin_stars: int
) -> void:
	if not nav_data:
		return

	if left_texture and left_data:
		var l_tex: Texture2D = left_data.get_portrait_texture()
		if not l_tex:
			l_tex = left_data.get_fullbody_texture()
		left_texture.texture = l_tex
	if left_label:
		left_label.visible = false

	if right_texture and right_data:
		var r_tex: Texture2D = right_data.get_portrait_texture()
		if not r_tex:
			r_tex = right_data.get_fullbody_texture()
		right_texture.texture = r_tex
	if right_label:
		right_label.visible = false

	if fullbody_texture:
		var cur_tex: Texture2D = nav_data.get_portrait_texture()
		if not cur_tex:
			cur_tex = nav_data.get_fullbody_texture()
		fullbody_texture.texture = cur_tex
		if equipped_skin != "":
			CosmeticsManager.apply_skin_to_canvas_item(fullbody_texture, equipped_skin, skin_stars, false)
		else:
			fullbody_texture.material = null

	if locked_overlay:
		locked_overlay.visible = not is_unlocked
		if not is_unlocked:
			if lock_title:
				lock_title.text = "%s BLOQUEADA" % nav_data.display_name.to_upper()
			if lock_desc:
				if nav_data.navigator_id == &"iris":
					lock_desc.text = "Completa cualquiera de los 3 finales (Pacifista, Genocida o Neutral) para sintonizar a Iris, o actívala en Debug [F1]."
				else:
					lock_desc.text = "Sintonización requerida. Desbloquea a %s en el menú de progresión o en Debug [F1]." % nav_data.display_name


func render_skin_cards(
	cur_skin: Dictionary,
	left_skin: Dictionary,
	right_skin: Dictionary,
	is_unlocked: bool,
	stars: int
) -> void:
	if cur_skin.is_empty():
		return

	var sid: String = cur_skin.get("id", "")

	if left_texture and not left_skin.is_empty():
		left_texture.texture = CosmeticsManager.load_texture(left_skin.get("texture_path", ""))
	if left_label and not left_skin.is_empty():
		left_label.text = "◀ " + left_skin.get("skin_name", "").to_upper()
		left_label.modulate = Color(0.7, 0.85, 1.0)

	if right_texture and not right_skin.is_empty():
		right_texture.texture = CosmeticsManager.load_texture(right_skin.get("texture_path", ""))
	if right_label and not right_skin.is_empty():
		right_label.text = right_skin.get("skin_name", "").to_upper() + " ▶"
		right_label.modulate = Color(0.7, 0.85, 1.0)

	if fullbody_texture:
		var tex := CosmeticsManager.load_texture(cur_skin.get("texture_path", ""))
		fullbody_texture.texture = tex
		if is_unlocked and stars > 1:
			CosmeticsManager.apply_skin_to_canvas_item(fullbody_texture, sid, stars)
		else:
			fullbody_texture.material = null

	if locked_overlay:
		locked_overlay.visible = not is_unlocked
		if lock_title:
			lock_title.text = "ASPECTO BLOQUEADO"
		if lock_desc:
			lock_desc.text = "CONSEGUIR EN GACHA ESTELAR"


func animate_center_card(animate: bool, slide_direction: int, is_unlocked: bool) -> void:
	if animate and is_instance_valid(fullbody_texture):
		if active_tween and active_tween.is_valid():
			active_tween.kill()

		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			active_tween = tree.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			var offset_x: float = 45.0 * (1.0 if slide_direction >= 0 else -1.0)
			fullbody_texture.position.x = offset_x
			active_tween.tween_property(fullbody_texture, "position:x", 0.0, 0.22)
			var target_modulate := Color.WHITE if is_unlocked else Color(0.68, 0.72, 0.85, 0.85)
			active_tween.tween_property(fullbody_texture, "modulate", target_modulate, 0.22)
	else:
		if fullbody_texture:
			fullbody_texture.position.x = 0.0
			fullbody_texture.modulate = Color.WHITE if is_unlocked else Color(0.68, 0.72, 0.85, 0.85)
