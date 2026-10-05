class_name PetCoverFlowRenderer
extends RefCounted

## PetCoverFlowRenderer.gd
## Renderizador modular de carrusel 2D CoverFlow con profundidad pseudocilíndrica para mascotas (Pets).
## Horizontal (A/D): Cicla mascotas base (tarjetas izquierda/derecha con escala 0.75 y z_index 1).
## Vertical (W/S): Cicla aspectos/skins de la mascota (tarjetas superior/inferior con escala 0.65 y z_index 0).
## Centro: Tarjeta principal (escala 1.0, z_index 2, glow circular y estrellas).

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const PetDataScript = preload("res://data/pets/pet_data.gd")

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
var lock_desc: Label = null

var right_card: Button = null
var right_texture: TextureRect = null
var right_label: Label = null

var top_card: Button = null
var top_texture: TextureRect = null
var bottom_card: Button = null
var bottom_texture: TextureRect = null

var dots_container: HBoxContainer = null
var nav_buttons: Array[Button] = []
var active_tween: Tween = null
var circular_glow: TextureRect = null

var on_cycle_callback: Callable = Callable()
var on_cycle_v_callback: Callable = Callable()


func setup(
	p_prev_btn: Button,
	p_next_btn: Button,
	p_left_card: Button,
	p_left_tex: TextureRect,
	p_left_lbl: Label,
	p_artwork_frame: PanelContainer,
	p_artwork_viewport: Control,
	p_fullbody_tex: TextureRect,
	p_locked_overlay: Control,
	p_lock_desc: Label,
	p_right_card: Button,
	p_right_tex: TextureRect,
	p_right_lbl: Label,
	p_dots_container: HBoxContainer,
	p_on_cycle: Callable,
	p_cards_row: HBoxContainer = null
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
	lock_desc = p_lock_desc
	right_card = p_right_card
	right_texture = p_right_tex
	right_label = p_right_lbl
	dots_container = p_dots_container
	on_cycle_callback = p_on_cycle

	if artwork_frame:
		circular_glow = artwork_frame.get_node_or_null("GlowHolder/CircularGlow") as TextureRect

	if prev_btn:
		prev_btn.pressed.connect(func() -> void:
			if on_cycle_callback.is_valid():
				on_cycle_callback.call(-1)
		)
	if next_btn:
		next_btn.pressed.connect(func() -> void:
			if on_cycle_callback.is_valid():
				on_cycle_callback.call(1)
		)

	if left_card:
		left_card.pressed.connect(func() -> void:
			if on_cycle_callback.is_valid():
				on_cycle_callback.call(-1)
		)
	if right_card:
		right_card.pressed.connect(func() -> void:
			if on_cycle_callback.is_valid():
				on_cycle_callback.call(1)
		)


func setup_vertical(
	p_top_card: Button,
	p_top_tex: TextureRect,
	p_bottom_card: Button,
	p_bottom_tex: TextureRect,
	p_on_cycle_v: Callable
) -> void:
	top_card = p_top_card
	top_texture = p_top_tex
	bottom_card = p_bottom_card
	bottom_texture = p_bottom_tex
	on_cycle_v_callback = p_on_cycle_v

	if top_card:
		top_card.pressed.connect(func() -> void:
			if on_cycle_v_callback.is_valid():
				on_cycle_v_callback.call(-1)
		)

	if bottom_card:
		bottom_card.pressed.connect(func() -> void:
			if on_cycle_v_callback.is_valid():
				on_cycle_v_callback.call(1)
		)


func build_dots(count: int, active_idx: int, on_select_index: Callable) -> void:
	if not dots_container:
		return

	for child in dots_container.get_children():
		dots_container.remove_child(child)
		child.queue_free()
	nav_buttons.clear()

	for i in range(count):
		var dot_btn := Button.new()
		dot_btn.custom_minimum_size = Vector2(26, 26)
		dot_btn.flat = true
		dot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		dot_btn.text = "●" if i == active_idx else "○"
		dot_btn.add_theme_font_size_override("font_size", 18)
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

	# Centro: Z-Index 2, Escala 1.0x, Borde circular luminoso
	artwork_frame.z_index = 2
	artwork_frame.custom_minimum_size = Vector2(260, 260)
	artwork_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var af_sb := StyleBoxFlat.new()
	af_sb.bg_color = Color(0.02, 0.035, 0.065, 0.95)
	af_sb.border_color = theme_color
	af_sb.set_border_width_all(3)
	af_sb.set_corner_radius_all(130)
	af_sb.corner_detail = 32
	af_sb.shadow_size = 0
	artwork_frame.add_theme_stylebox_override("panel", af_sb)

	if circular_glow:
		circular_glow.modulate = theme_color

	# Cartas laterales (Bases): Z-Index 1, Escala 0.75x, Opacidad 0.60
	var side_sb := StyleBoxFlat.new()
	side_sb.bg_color = Color(0.02, 0.03, 0.06, 0.85)
	side_sb.border_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.45)
	side_sb.set_border_width_all(2)
	side_sb.set_corner_radius_all(75)
	side_sb.corner_detail = 32

	if left_card:
		left_card.z_index = 1
		left_card.modulate = Color(0.75, 0.82, 0.95, 0.60)
		left_card.custom_minimum_size = Vector2(150, 150)
		left_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		left_card.add_theme_stylebox_override("normal", side_sb)
		left_card.add_theme_stylebox_override("hover", side_sb)
		left_card.add_theme_stylebox_override("pressed", side_sb)
	if left_label:
		left_label.visible = false

	if right_card:
		right_card.z_index = 1
		right_card.modulate = Color(0.75, 0.82, 0.95, 0.60)
		right_card.custom_minimum_size = Vector2(150, 150)
		right_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		right_card.add_theme_stylebox_override("normal", side_sb)
		right_card.add_theme_stylebox_override("hover", side_sb)
		right_card.add_theme_stylebox_override("pressed", side_sb)
	if right_label:
		right_label.visible = false

	# Cartas verticales (Skins): Z-Index 0, Escala 0.65x, Opacidad 0.45 (atrás del centro)
	var skin_sb := StyleBoxFlat.new()
	skin_sb.bg_color = Color(0.02, 0.03, 0.06, 0.85)
	skin_sb.border_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.35)
	skin_sb.set_border_width_all(2)
	skin_sb.set_corner_radius_all(55)
	skin_sb.corner_detail = 32

	if top_card:
		top_card.z_index = 0
		top_card.modulate = Color(0.75, 0.82, 0.95, 0.45)
		top_card.custom_minimum_size = Vector2(110, 110)
		top_card.add_theme_stylebox_override("normal", skin_sb)
		top_card.add_theme_stylebox_override("hover", skin_sb)
		top_card.add_theme_stylebox_override("pressed", skin_sb)

	if bottom_card:
		bottom_card.z_index = 0
		bottom_card.modulate = Color(0.75, 0.82, 0.95, 0.45)
		bottom_card.custom_minimum_size = Vector2(110, 110)
		bottom_card.add_theme_stylebox_override("normal", skin_sb)
		bottom_card.add_theme_stylebox_override("hover", skin_sb)
		bottom_card.add_theme_stylebox_override("pressed", skin_sb)


func render_2d_carousel(
	pet_data: PetDataScript,
	left_data: PetDataScript,
	right_data: PetDataScript,
	available_skins: Array[Dictionary],
	skin_idx: int,
	is_unlocked: bool
) -> void:
	if not pet_data:
		return

	# 1. Horizontales: Mascotas adyacentes
	if left_texture and left_data:
		left_texture.texture = left_data.get_icon_texture()
	if left_label:
		left_label.visible = false

	if right_texture and right_data:
		right_texture.texture = right_data.get_icon_texture()
	if right_label:
		right_label.visible = false

	# 2. Verticales: Aspectos superior e inferior
	if top_card and bottom_card:
		if available_skins.size() <= 1:
			top_card.visible = false
			bottom_card.visible = false
		else:
			top_card.visible = true
			bottom_card.visible = true
			var top_idx: int = (skin_idx - 1 + available_skins.size()) % available_skins.size()
			var btm_idx: int = (skin_idx + 1) % available_skins.size()
			if top_texture:
				top_texture.texture = available_skins[top_idx].get("texture", null)
			if bottom_texture:
				bottom_texture.texture = available_skins[btm_idx].get("texture", null)

	# 3. Centro: Aspecto activo
	if fullbody_texture and not available_skins.is_empty() and skin_idx >= 0 and skin_idx < available_skins.size():
		var cur_skin: Dictionary = available_skins[skin_idx]
		fullbody_texture.texture = cur_skin.get("texture", pet_data.get_icon_texture())
		var sid: String = cur_skin.get("id", "")
		var stars: int = cur_skin.get("stars", 0)
		if cur_skin.get("is_base", false) or sid.is_empty():
			fullbody_texture.material = null
		elif cur_skin.get("is_unlocked", false):
			CosmeticsManager.apply_skin_to_canvas_item(fullbody_texture, sid, stars, false)
		else:
			fullbody_texture.material = null
	elif fullbody_texture:
		fullbody_texture.texture = pet_data.get_icon_texture()
		fullbody_texture.material = null

	# 4. Estado de bloqueo
	if locked_overlay:
		locked_overlay.visible = not is_unlocked


func render_pet_cards(
	pet_data: PetDataScript,
	left_data: PetDataScript,
	right_data: PetDataScript,
	is_unlocked: bool,
	equipped_skin: String,
	skin_stars: int
) -> void:
	var fake_skins: Array[Dictionary] = [
		{"id": "", "skin_name": "Aspecto Estándar", "texture": pet_data.get_icon_texture(), "is_base": true, "is_unlocked": true}
	]
	if not equipped_skin.is_empty():
		fake_skins.append({"id": equipped_skin, "skin_name": "Aspecto", "texture": CosmeticsManager.load_texture(equipped_skin), "is_base": false, "is_unlocked": true, "stars": skin_stars})
	render_2d_carousel(pet_data, left_data, right_data, fake_skins, 1 if not equipped_skin.is_empty() else 0, is_unlocked)


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
	if right_texture and not right_skin.is_empty():
		right_texture.texture = CosmeticsManager.load_texture(right_skin.get("texture_path", ""))
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


func animate_center_card(animate: bool, slide_direction: int, is_unlocked: bool) -> void:
	animate_center_card_2d(animate, slide_direction, 0, is_unlocked)


func animate_center_card_2d(animate: bool, slide_h: int, slide_v: int, is_unlocked: bool) -> void:
	if not fullbody_texture:
		return
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	fullbody_texture.position = Vector2.ZERO

	if not animate:
		if artwork_frame:
			artwork_frame.position = Vector2.ZERO
			artwork_frame.modulate = Color.WHITE
		fullbody_texture.modulate = Color.WHITE if is_unlocked else Color(0.2, 0.25, 0.35, 0.7)
		return

	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		if artwork_frame:
			artwork_frame.position = Vector2(50.0 * float(slide_h), 40.0 * float(slide_v))
			artwork_frame.modulate = Color(1.25, 1.25, 1.25, 1.0)
		var target_modulate := Color.WHITE if is_unlocked else Color(0.2, 0.25, 0.35, 0.7)
		fullbody_texture.modulate = target_modulate

		active_tween = tree.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if artwork_frame:
			active_tween.tween_property(artwork_frame, "position", Vector2.ZERO, 0.24)
			active_tween.tween_property(artwork_frame, "modulate", Color.WHITE, 0.24)
