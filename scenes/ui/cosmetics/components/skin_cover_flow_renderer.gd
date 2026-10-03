class_name SkinCoverFlowRenderer
extends RefCounted

## SkinCoverFlowRenderer.gd
## Renderizador visual del carrusel CoverFlow para SkinSelectionModal.
## Gestiona la tarjeta hero principal con shaders cósmicos, estrellas, candado,
## tarjetas laterales izquierda/derecha, animaciones elásticas tweens y paginador de puntos.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")

var prev_btn: Button = null
var next_btn: Button = null
var left_card: Button = null
var left_texture: TextureRect = null
var left_label: Label = null

var artwork_frame: PanelContainer = null
var fullbody_texture: TextureRect = null
var locked_overlay: Control = null
var lock_desc: Label = null
var stars_badge: Label = null

var right_card: Button = null
var right_texture: TextureRect = null
var right_label: Label = null

var dots_container: HBoxContainer = null
var nav_dots: Array[Button] = []
var active_tween: Tween = null

var on_cycle_callback: Callable = Callable()
var on_select_index_callback: Callable = Callable()


func setup(
	p_prev: Button,
	p_next: Button,
	p_left_card: Button,
	p_left_tex: TextureRect,
	p_left_lbl: Label,
	p_frame: PanelContainer,
	p_fullbody: TextureRect,
	p_locked: Control,
	p_lock_desc: Label,
	p_stars: Label,
	p_right_card: Button,
	p_right_tex: TextureRect,
	p_right_lbl: Label,
	p_dots_box: HBoxContainer,
	p_on_cycle: Callable,
	p_on_select_index: Callable
) -> void:
	prev_btn = p_prev
	next_btn = p_next
	left_card = p_left_card
	left_texture = p_left_tex
	left_label = p_left_lbl

	artwork_frame = p_frame
	fullbody_texture = p_fullbody
	locked_overlay = p_locked
	lock_desc = p_lock_desc
	stars_badge = p_stars

	right_card = p_right_card
	right_texture = p_right_tex
	right_label = p_right_lbl

	dots_container = p_dots_box
	on_cycle_callback = p_on_cycle
	on_select_index_callback = p_on_select_index

	if prev_btn:
		UIFocusHelper.apply_cyber_focus(prev_btn)
		prev_btn.pressed.connect(func(): on_cycle_callback.call(-1))
	if next_btn:
		UIFocusHelper.apply_cyber_focus(next_btn)
		next_btn.pressed.connect(func(): on_cycle_callback.call(1))

	if left_card:
		UIFocusHelper.apply_cyber_focus(left_card)
		left_card.pressed.connect(func(): on_cycle_callback.call(-1))
	if right_card:
		UIFocusHelper.apply_cyber_focus(right_card)
		right_card.pressed.connect(func(): on_cycle_callback.call(1))


func build_dots(skins_count: int, current_index: int) -> void:
	if not dots_container:
		return

	for child in dots_container.get_children():
		dots_container.remove_child(child)
		child.queue_free()
	nav_dots.clear()

	for i in range(skins_count):
		var dot := Button.new()
		dot.custom_minimum_size = Vector2(24, 24)
		dot.flat = true
		dot.text = "●" if i == current_index else "○"
		dot.add_theme_font_size_override("font_size", 16)
		dot.focus_mode = Control.FOCUS_NONE
		var target_idx := i
		dot.pressed.connect(func():
			if on_select_index_callback.is_valid():
				var dir := 1 if target_idx > current_index else -1
				on_select_index_callback.call(target_idx, dir)
		)
		dots_container.add_child(dot)
		nav_dots.append(dot)


func update_dots(current_index: int) -> void:
	for i in range(nav_dots.size()):
		nav_dots[i].text = "●" if i == current_index else "○"


func render_skin(
	cur_skin: Dictionary,
	is_unlocked: bool,
	stars: int,
	is_pilot: bool,
	default_texture: Texture2D,
	prev_skin: Dictionary,
	next_skin: Dictionary,
	animated: bool,
	slide_dir: int
) -> void:
	var sid: String = cur_skin.get("id", "")

	# Estrellas y efectos
	if stars_badge:
		var star_str := ""
		for s in range(stars):
			star_str += "★"
		if stars == 1:
			stars_badge.text = "%s 1★ RECOLOR BASE" % star_str
			stars_badge.modulate = Color(0.8, 0.9, 1.0)
		elif stars == 2:
			stars_badge.text = "%s 2★ AURA DE PLASMA Y RESPLANDOR" % star_str
			stars_badge.modulate = Color(0.2, 0.95, 1.0)
		else:
			stars_badge.text = "%s 3★ MÁXIMO NIVEL (DESTELLOS CÓSMICOS)" % star_str
			stars_badge.modulate = Color(1.0, 0.88, 0.2)

	if locked_overlay:
		locked_overlay.visible = not is_unlocked

	# Orientación flip_h para pilotos fullbody
	if fullbody_texture:
		fullbody_texture.flip_h = is_pilot
	if left_texture:
		left_texture.flip_h = is_pilot
	if right_texture:
		right_texture.flip_h = is_pilot

	# Cargar Textura y Shader en Tarjeta Central
	if fullbody_texture:
		var tex_path: String = cur_skin.get("texture_path", "")
		var tex: Texture2D = CosmeticsManager.load_texture(tex_path)
		if not tex and default_texture:
			tex = default_texture
		fullbody_texture.texture = tex

		if is_unlocked and stars > 1:
			CosmeticsManager.apply_skin_to_canvas_item(fullbody_texture, sid, stars)
		else:
			fullbody_texture.material = null

	# Previews Lateral Izquierdo y Derecho (CoverFlow)
	if left_texture and not prev_skin.is_empty():
		var prev_tex: Texture2D = CosmeticsManager.load_texture(prev_skin.get("texture_path", ""))
		left_texture.texture = prev_tex if prev_tex else default_texture
		if left_label:
			left_label.text = prev_skin.get("skin_name", "")

	if right_texture and not next_skin.is_empty():
		var next_tex: Texture2D = CosmeticsManager.load_texture(next_skin.get("texture_path", ""))
		right_texture.texture = next_tex if next_tex else default_texture
		if right_label:
			right_label.text = next_skin.get("skin_name", "")

	# Animación de CoverFlow elástica
	if animated and is_instance_valid(fullbody_texture):
		if active_tween and active_tween.is_valid():
			active_tween.kill()
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			active_tween = tree.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			if artwork_frame:
				artwork_frame.scale = Vector2(0.94, 0.94)
				active_tween.tween_property(artwork_frame, "scale", Vector2(1.0, 1.0), 0.24)
			var offset_x: float = 45.0 * (1.0 if slide_dir >= 0 else -1.0)
			fullbody_texture.position.x = offset_x
			active_tween.tween_property(fullbody_texture, "position:x", 0.0, 0.24)
			fullbody_texture.modulate = Color(1.0, 1.0, 1.0, 0.3) if is_unlocked else Color(0.2, 0.25, 0.35, 0.3)
			var target_modulate := Color.WHITE if is_unlocked else Color(0.3, 0.35, 0.45, 0.8)
			active_tween.tween_property(fullbody_texture, "modulate", target_modulate, 0.24)
	else:
		if artwork_frame:
			artwork_frame.scale = Vector2.ONE
		if fullbody_texture:
			fullbody_texture.position.x = 0.0
			fullbody_texture.modulate = Color.WHITE if is_unlocked else Color(0.3, 0.35, 0.45, 0.8)


func render_empty(default_texture: Texture2D) -> void:
	if fullbody_texture:
		fullbody_texture.texture = default_texture
		fullbody_texture.material = null
	if locked_overlay:
		locked_overlay.hide()
