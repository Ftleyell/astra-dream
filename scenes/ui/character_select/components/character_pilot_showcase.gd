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
		if not fullbody_texture.resized.is_connected(_on_fullbody_resized):
			fullbody_texture.resized.connect(_on_fullbody_resized)

	if pilot_button:
		pilot_button.focus_mode = Control.FOCUS_NONE
		pilot_button.mouse_entered.connect(on_mouse_entered)
		pilot_button.mouse_exited.connect(on_mouse_exited)
		pilot_button.pressed.connect(on_button_pressed)
		pilot_button.tooltip_text = "Haz clic para ver y equipar los aspectos de la piloto"


func _on_fullbody_resized() -> void:
	if is_instance_valid(fullbody_texture):
		var target_pivot := Vector2(fullbody_texture.size.x * 0.5, fullbody_texture.size.y)
		if not fullbody_texture.pivot_offset.is_equal_approx(target_pivot):
			fullbody_texture.pivot_offset = target_pivot


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
	if not fullbody_texture or not fullbody_texture.is_inside_tree():
		return
	_on_fullbody_resized()
	if _pilot_hover_tween and _pilot_hover_tween.is_valid():
		_pilot_hover_tween.kill()
	_pilot_hover_tween = fullbody_texture.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pilot_hover_tween.tween_property(fullbody_texture, "scale", Vector2(1.035, 1.035), 0.22)
	if backlight_glow:
		_pilot_hover_tween.tween_property(backlight_glow, "modulate:a", 0.85, 0.22)

	var audio_mgr := fullbody_texture.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_hover", 0.0, 1.15)


func on_mouse_exited() -> void:
	if not fullbody_texture or not fullbody_texture.is_inside_tree():
		return
	if _pilot_hover_tween and _pilot_hover_tween.is_valid():
		_pilot_hover_tween.kill()
	_pilot_hover_tween = fullbody_texture.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pilot_hover_tween.tween_property(fullbody_texture, "scale", Vector2.ONE, 0.22)
	if backlight_glow:
		_pilot_hover_tween.tween_property(backlight_glow, "modulate:a", 0.0, 0.22)


func on_button_pressed() -> void:
	if not fullbody_texture or not fullbody_texture.is_inside_tree():
		return
	var audio_mgr := fullbody_texture.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.1)

	_on_fullbody_resized()
	var tw := fullbody_texture.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(fullbody_texture, "scale", Vector2(1.06, 1.06), 0.08)
	tw.tween_property(fullbody_texture, "scale", Vector2(1.035, 1.035), 0.14)

	if on_pilot_pressed_callback.is_valid():
		on_pilot_pressed_callback.call()


func cleanup() -> void:
	if _pilot_hover_tween and _pilot_hover_tween.is_valid():
		_pilot_hover_tween.kill()
	if _breathe_tween and _breathe_tween.is_valid():
		_breathe_tween.kill()


const SHOWCASE_SHADER := preload("res://shaders/pilot_showcase_hologram.gdshader")

var _breathe_tween: Tween = null


func start_idle_breathing() -> void:
	if _breathe_tween and _breathe_tween.is_valid():
		_breathe_tween.kill()
	if not fullbody_texture or not fullbody_texture.is_inside_tree():
		return
	fullbody_texture.position.y = 0.0
	_breathe_tween = fullbody_texture.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe_tween.tween_property(fullbody_texture, "position:y", 4.0, 2.4)
	_breathe_tween.tween_property(fullbody_texture, "position:y", 0.0, 2.4)


func update_pilot_display(data: CharacterData, char_id: StringName, is_unlocked: bool) -> void:
	if not data:
		return

	var loadout: Dictionary = SaveManager.get_character_loadout(char_id)
	var pilot_skin_id: String = str(loadout.get("equipped_pilot_skin", loadout.get("pilot_skin", "base")))
	if pilot_skin_id.is_empty():
		pilot_skin_id = "base"

	if fullbody_texture:
		fullbody_texture.material = null
		fullbody_texture.texture = null

		if pilot_skin_id != "base":
			var stars := SaveManager.get_skin_stars(pilot_skin_id)
			CosmeticsManager.apply_pilot_selection_to_canvas_item(fullbody_texture, pilot_skin_id, stars, false)

		if fullbody_texture.texture == null:
			var fb_tex: Texture2D = data.get_selection_texture(false) if data.has_method("get_selection_texture") else data.get_fullbody_texture(false)
			if not fb_tex:
				fb_tex = data.get_selection_texture(true) if data.has_method("get_selection_texture") else data.get_fullbody_texture(true)
			if not fb_tex:
				fb_tex = data.get_fullbody_texture(false)
			if not fb_tex:
				fb_tex = data.get_portrait_texture()
			fullbody_texture.texture = fb_tex

		# Si no tiene shader cosmético de estrellas altas, aplicar nuestro shader holográfico para defringing y rim-light
		if fullbody_texture.material == null:
			var mat := ShaderMaterial.new()
			mat.shader = SHOWCASE_SHADER
			var theme_col: Color = data.color if data else Color(0.2, 0.9, 1.0)
			mat.set_shader_parameter("rim_color", theme_col)
			mat.set_shader_parameter("bottom_fade_start", 0.78 if char_id == &"valentina" else 0.90)
			fullbody_texture.material = mat

		fullbody_texture.flip_h = false
		fullbody_texture.visible = (fullbody_texture.texture != null)
		fullbody_texture.modulate = Color.WHITE if is_unlocked else Color(0.2, 0.2, 0.3, 0.85)

	if backlight_glow:
		var glow_col: Color = data.color if data else Color(0.2, 0.9, 1.0)
		backlight_glow.modulate = Color(glow_col.r, glow_col.g, glow_col.b, backlight_glow.modulate.a)

	start_idle_breathing()

