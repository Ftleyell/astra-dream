class_name PetCoverFlowRenderer
extends RefCounted

## PetCoverFlowRenderer.gd
## Renderizador modular de carrusel CoverFlow para PetSelectionModal.
## Gestiona cartas laterales (iconos de mascotas), retrato central holográfico,
## paginación por puntos, overlays de bloqueo y animaciones elásticas tweens.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const PetDataScript = preload("res://data/pets/pet_data.gd")

var prev_btn: Button = null
var next_btn: Button = null

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

var dots_container: HBoxContainer = null
var nav_buttons: Array[Button] = []
var active_tween: Tween = null

var on_cycle_callback: Callable = Callable()


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
	p_on_cycle: Callable
) -> void:
	prev_btn = p_prev_btn
	next_btn = p_next_btn
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


func render_pet_cards(
	pet_data: PetDataScript,
	left_data: PetDataScript,
	right_data: PetDataScript,
	is_unlocked: bool,
	equipped_skin: String,
	skin_stars: int
) -> void:
	if not pet_data:
		return

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

	if fullbody_texture:
		if equipped_skin != "":
			CosmeticsManager.apply_skin_to_canvas_item(fullbody_texture, equipped_skin, skin_stars)
		else:
			fullbody_texture.texture = pet_data.get_icon_texture()
			fullbody_texture.material = null

	if locked_overlay:
		locked_overlay.visible = not is_unlocked


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
		if lock_desc:
			lock_desc.text = "CONSEGUIR EN GACHA"


func animate_center_card(animate: bool, slide_direction: int, is_unlocked: bool) -> void:
	if animate and is_instance_valid(fullbody_texture):
		if active_tween and active_tween.is_valid():
			active_tween.kill()

		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			active_tween = tree.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			var offset_x: float = 35.0 * (1.0 if slide_direction >= 0 else -1.0)
			fullbody_texture.position.x = offset_x
			active_tween.tween_property(fullbody_texture, "position:x", 0.0, 0.22)
			var target_modulate := Color.WHITE if is_unlocked else Color(0.2, 0.25, 0.35, 0.7)
			active_tween.tween_property(fullbody_texture, "modulate", target_modulate, 0.22)
	else:
		if fullbody_texture:
			fullbody_texture.position.x = 0.0
			fullbody_texture.modulate = Color.WHITE if is_unlocked else Color(0.2, 0.25, 0.35, 0.7)
