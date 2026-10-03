class_name CharacterPilotShowcase
extends RefCounted

## CharacterPilotShowcase.gd
## Controlador del escaparate interactivo de la piloto en CharacterSelectUI.
## Gestiona el renderizado de la imagen fullbody, el halo de retroiluminación dinámico,
## las animaciones tweens de hover/clic y la aplicación de skins cosméticas.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")

var fullbody_texture: TextureRect = null
var backlight_glow: TextureRect = null
var pilot_button: Button = null
var on_pilot_pressed_callback: Callable = Callable()

var _pilot_hover_tween: Tween = null


func setup(
	p_fullbody: TextureRect,
	p_glow: TextureRect,
	p_btn: Button,
	p_on_pressed: Callable
) -> void:
	fullbody_texture = p_fullbody
	backlight_glow = p_glow
	pilot_button = p_btn
	on_pilot_pressed_callback = p_on_pressed

	_setup_pilot_backlight()

	if fullbody_texture:
		fullbody_texture.mouse_filter = Control.MOUSE_FILTER_PASS
		fullbody_texture.item_rect_changed.connect(func():
			fullbody_texture.pivot_offset = Vector2(fullbody_texture.size.x * 0.5, fullbody_texture.size.y)
		)

	if pilot_button:
		pilot_button.focus_mode = Control.FOCUS_NONE
		pilot_button.mouse_entered.connect(on_mouse_entered)
		pilot_button.mouse_exited.connect(on_mouse_exited)
		pilot_button.pressed.connect(on_button_pressed)
		pilot_button.tooltip_text = "Haz clic para ver y equipar los aspectos de la piloto"


func _setup_pilot_backlight() -> void:
	if not backlight_glow:
		return
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.85))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.45)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	grad_tex.width = 512
	grad_tex.height = 768
	backlight_glow.texture = grad_tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	backlight_glow.material = mat
	backlight_glow.modulate.a = 0.0


func on_mouse_entered() -> void:
	if not fullbody_texture:
		return
	fullbody_texture.pivot_offset = Vector2(fullbody_texture.size.x * 0.5, fullbody_texture.size.y)
	if _pilot_hover_tween and _pilot_hover_tween.is_valid():
		_pilot_hover_tween.kill()
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		return
	_pilot_hover_tween = tree.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pilot_hover_tween.tween_property(fullbody_texture, "scale", Vector2(1.035, 1.035), 0.22)
	if backlight_glow:
		_pilot_hover_tween.tween_property(backlight_glow, "modulate:a", 0.85, 0.22)

	var audio_mgr := tree.root.get_node_or_null("AudioManager") if tree.root else null
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_hover", 0.0, 1.15)


func on_mouse_exited() -> void:
	if not fullbody_texture:
		return
	if _pilot_hover_tween and _pilot_hover_tween.is_valid():
		_pilot_hover_tween.kill()
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		return
	_pilot_hover_tween = tree.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pilot_hover_tween.tween_property(fullbody_texture, "scale", Vector2.ONE, 0.22)
	if backlight_glow:
		_pilot_hover_tween.tween_property(backlight_glow, "modulate:a", 0.0, 0.22)


func on_button_pressed() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var audio_mgr := tree.root.get_node_or_null("AudioManager") if tree and tree.root else null
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.1)

	if fullbody_texture and tree:
		fullbody_texture.pivot_offset = Vector2(fullbody_texture.size.x * 0.5, fullbody_texture.size.y)
		var tw := tree.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(fullbody_texture, "scale", Vector2(1.06, 1.06), 0.08)
		tw.tween_property(fullbody_texture, "scale", Vector2(1.035, 1.035), 0.14)

	if on_pilot_pressed_callback.is_valid():
		on_pilot_pressed_callback.call()


func update_pilot_display(data: CharacterData, char_id: StringName, is_unlocked: bool) -> void:
	var pilot_slot := "pilot:" + String(char_id)
	var pilot_skin_id := SaveManager.get_equipped_skin(pilot_slot)

	if fullbody_texture:
		if not pilot_skin_id.is_empty():
			var stars := SaveManager.get_skin_stars(pilot_skin_id)
			CosmeticsManager.apply_pilot_selection_to_canvas_item(fullbody_texture, pilot_skin_id, stars, false)
		else:
			fullbody_texture.material = null
			fullbody_texture.texture = null

		if fullbody_texture.texture == null and data:
			var fb_tex: Texture2D = data.get_selection_texture(false) if data.has_method("get_selection_texture") else data.get_fullbody_texture(false)
			if not fb_tex:
				fb_tex = data.get_selection_texture(true) if data.has_method("get_selection_texture") else data.get_fullbody_texture(true)
			if not fb_tex:
				fb_tex = data.get_fullbody_texture(false)
			if not fb_tex:
				fb_tex = data.get_portrait_texture()
			fullbody_texture.texture = fb_tex

		fullbody_texture.flip_h = true
		fullbody_texture.visible = (fullbody_texture.texture != null)
		fullbody_texture.modulate = Color.WHITE if is_unlocked else Color(0.2, 0.2, 0.3, 0.85)

	if backlight_glow:
		var glow_col: Color = data.color if data else Color(0.2, 0.9, 1.0)
		backlight_glow.modulate = Color(glow_col.r, glow_col.g, glow_col.b, backlight_glow.modulate.a)
