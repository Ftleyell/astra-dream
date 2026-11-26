class_name CharacterPilotShowcase
extends RefCounted

## CharacterPilotShowcase.gd
## Controlador del escaparate interactivo de la piloto en CharacterSelectUI.
## Gestiona el renderizado de la imagen fullbody, el halo de retroiluminación dinámico,
## las animaciones tweens de hover/clic y la aplicación de skins cosméticas.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const LiveBannerViewportScript = preload("res://scenes/ui/character_select/components/character_live_banner_viewport.gd")

const BASE_LIVE_BACKLIGHT_ALPHA: float = 0.42
const HOVER_LIVE_BACKLIGHT_ALPHA: float = 0.72
const LOADOUT_BANNER_OFFSET: Vector2 = Vector2(-210.0, -88.0)
const LOADOUT_BANNER_ZOOM_MULT: float = 1.35

var fullbody_texture: TextureRect = null
var live_banner_viewport: CharacterLiveBannerViewport = null
var backlight_glow: TextureRect = null
var pilot_button: Button = null
var on_pilot_pressed_callback: Callable = Callable()

var _pilot_hover_tween: Tween = null


func setup_from_root(root: Control, p_on_pressed: Callable) -> void:
	var base_path: String = "MarginContainer/RootVBox/MainWorkspace/RightShowcaseArea/"
	var fb: TextureRect = root.get_node_or_null(base_path + "FullbodyTexture") as TextureRect
	var glow: TextureRect = root.get_node_or_null(base_path + "BacklightGlow") as TextureRect
	var btn: Button = root.get_node_or_null(base_path + "PilotButton") as Button
	setup(fb, glow, btn, p_on_pressed)


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
		var showcase_parent: Node = fullbody_texture.get_parent()
		if showcase_parent != null and live_banner_viewport == null:
			live_banner_viewport = LiveBannerViewportScript.new() as CharacterLiveBannerViewport
			live_banner_viewport.name = "CharacterLiveBannerViewport"
			live_banner_viewport.visible = false
			live_banner_viewport.set_framing(LOADOUT_BANNER_OFFSET, LOADOUT_BANNER_ZOOM_MULT)
			live_banner_viewport.set_background_integration(false)
			live_banner_viewport.framing_changed.connect(_update_backlight_position)
			showcase_parent.add_child(live_banner_viewport)
			showcase_parent.move_child(live_banner_viewport, fullbody_texture.get_index() + 1)

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
	grad.offsets = PackedFloat32Array([0.0, 0.42, 0.78, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.72),
		Color(1.0, 1.0, 1.0, 0.28),
		Color(1.0, 1.0, 1.0, 0.06),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	grad_tex.width = 512
	grad_tex.height = 512
	backlight_glow.texture = grad_tex
	backlight_glow.stretch_mode = TextureRect.STRETCH_SCALE
	backlight_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	backlight_glow.material = mat
	backlight_glow.modulate.a = 0.0


func _update_backlight_position() -> void:
	if not is_instance_valid(backlight_glow) or not is_instance_valid(live_banner_viewport):
		return
	if not live_banner_viewport.visible:
		return
	var vp_size: Vector2 = live_banner_viewport.size
	if vp_size.x < 8.0 or vp_size.y < 8.0:
		return
	var char_center: Vector2 = live_banner_viewport.get_character_local_center(Vector2(0.0, -55.0))
	var glow_h: float = maxf(vp_size.y * 1.15, 520.0)
	var glow_w: float = glow_h * 0.82
	backlight_glow.set_anchors_preset(Control.PRESET_TOP_LEFT)
	backlight_glow.size = Vector2(glow_w, glow_h)
	backlight_glow.position = char_center - Vector2(glow_w * 0.5, glow_h * 0.5)


func on_mouse_entered() -> void:
	var has_live: bool = live_banner_viewport != null and live_banner_viewport.visible
	if has_live:
		live_banner_viewport.trigger_hover_impulse(0.65)
		if backlight_glow and backlight_glow.is_inside_tree():
			if _pilot_hover_tween and _pilot_hover_tween.is_valid():
				_pilot_hover_tween.kill()
			_pilot_hover_tween = backlight_glow.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_pilot_hover_tween.tween_property(backlight_glow, "modulate:a", HOVER_LIVE_BACKLIGHT_ALPHA, 0.22)
		var audio_live := live_banner_viewport.get_node_or_null("/root/AudioManager")
		if audio_live and audio_live.has_method("play_sfx"):
			audio_live.play_sfx(&"ui_hover", 1.15, 0.0)
		return
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
		audio_mgr.play_sfx(&"ui_hover", 1.15, 0.0)


func on_mouse_exited() -> void:
	var has_live: bool = live_banner_viewport != null and live_banner_viewport.visible
	if has_live:
		if backlight_glow and backlight_glow.is_inside_tree():
			if _pilot_hover_tween and _pilot_hover_tween.is_valid():
				_pilot_hover_tween.kill()
			_pilot_hover_tween = backlight_glow.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_pilot_hover_tween.tween_property(backlight_glow, "modulate:a", BASE_LIVE_BACKLIGHT_ALPHA, 0.22)
		return
	if not fullbody_texture or not fullbody_texture.is_inside_tree():
		return
	if _pilot_hover_tween and _pilot_hover_tween.is_valid():
		_pilot_hover_tween.kill()
	_pilot_hover_tween = fullbody_texture.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pilot_hover_tween.tween_property(fullbody_texture, "scale", Vector2.ONE, 0.22)
	if backlight_glow:
		_pilot_hover_tween.tween_property(backlight_glow, "modulate:a", 0.0, 0.22)


func on_button_pressed() -> void:
	var has_live: bool = live_banner_viewport != null and live_banner_viewport.visible
	if has_live:
		var audio_live := live_banner_viewport.get_node_or_null("/root/AudioManager")
		if audio_live and audio_live.has_method("play_sfx"):
			audio_live.play_sfx(&"ui_click", 1.1, 0.0)
		live_banner_viewport.trigger_hover_impulse(1.0)
		if on_pilot_pressed_callback.is_valid():
			on_pilot_pressed_callback.call()
		return
	if not fullbody_texture or not fullbody_texture.is_inside_tree():
		return
	var audio_mgr := fullbody_texture.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 1.1, 0.0)

	_on_fullbody_resized()
	var tw := fullbody_texture.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(fullbody_texture, "scale", Vector2(1.06, 1.06), 0.08)
	tw.tween_property(fullbody_texture, "scale", Vector2(1.035, 1.035), 0.14)

	if on_pilot_pressed_callback.is_valid():
		on_pilot_pressed_callback.call()


func trigger_deploy_lock_in() -> void:
	if live_banner_viewport != null and live_banner_viewport.visible:
		live_banner_viewport.trigger_select_sequence()


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

	var is_active_pilot: bool = is_unlocked and data.is_playable_rework_ready
	if data.live_banner_config != null and live_banner_viewport != null:
		if _breathe_tween and _breathe_tween.is_valid():
			_breathe_tween.kill()
		live_banner_viewport.load_banner(data.live_banner_config, data.pilot_rig_profile)
		var pilot_preset: PilotSkinPreset = CosmeticsManager.resolve_pilot_skin_preset(char_id, "pilot")
		var pilot_stars: int = CosmeticsManager.resolve_equipped_skin_stars("pilot", char_id)
		live_banner_viewport.apply_skin_preset(pilot_preset, pilot_stars)
		var wings_skin_id: String = CosmeticsManager.resolve_equipped_skin_id("wings", char_id)
		var wings_override: PilotSkinPreset = null
		var wings_stars: int = pilot_stars
		if not wings_skin_id.is_empty() and wings_skin_id != CosmeticsManager.FOLLOW_PILOT_SKIN_ID:
			wings_override = CosmeticsManager.resolve_pilot_skin_preset(char_id, "wings")
			wings_stars = CosmeticsManager.resolve_equipped_skin_stars("wings", char_id)
		live_banner_viewport.apply_wings_skin_preset(wings_override, wings_stars)
		live_banner_viewport.reset_select_sequence()
		live_banner_viewport.visible = true
		live_banner_viewport.modulate = Color.WHITE if is_active_pilot else Color(0.35, 0.38, 0.45, 0.8)
		if fullbody_texture:
			fullbody_texture.visible = false
		if backlight_glow:
			var live_glow_col: Color = pilot_preset.accent_color if (pilot_preset != null and not pilot_preset.is_base_skin) else (data.color if data else Color(0.2, 0.9, 1.0))
			backlight_glow.modulate = Color(live_glow_col.r, live_glow_col.g, live_glow_col.b, BASE_LIVE_BACKLIGHT_ALPHA)
			live_banner_viewport.set_showcase_lighting(0.45, live_glow_col.lerp(Color.WHITE, 0.45), 0.14)
			_update_backlight_position()
		return

	if live_banner_viewport != null:
		live_banner_viewport.visible = false

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
		fullbody_texture.modulate = Color.WHITE if is_active_pilot else Color(0.2, 0.2, 0.3, 0.85)

	if backlight_glow:
		var glow_col: Color = data.color if data else Color(0.2, 0.9, 1.0)
		backlight_glow.modulate = Color(glow_col.r, glow_col.g, glow_col.b, backlight_glow.modulate.a)

	start_idle_breathing()
