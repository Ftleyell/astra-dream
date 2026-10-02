class_name NavigatorCommsWidget
extends CanvasLayer

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")

## Widget lateral de comunicaciones de Navegantes.
## Muestra el retrato, diálogo y objetivo detectado en el lateral izquierdo
## de manera no intrusiva (sin pausar ni bloquear la pantalla).

@onready var anim_container: Control = $CommsAnchor/PanelContainer
@onready var portrait_rect: TextureRect = $CommsAnchor/PanelContainer/Margin/HBox/PortraitFrame/Portrait
@onready var name_label: Label = $CommsAnchor/PanelContainer/Margin/HBox/ContentVBox/HeaderBox/NameLabel
@onready var badge_label: Label = $CommsAnchor/PanelContainer/Margin/HBox/ContentVBox/HeaderBox/BadgeLabel
@onready var message_label: Label = $CommsAnchor/PanelContainer/Margin/HBox/ContentVBox/MessageLabel
@onready var buff_hint_label: Label = $CommsAnchor/PanelContainer/Margin/HBox/ContentVBox/BuffHintLabel
@onready var border_panel: PanelContainer = $CommsAnchor/PanelContainer

var _current_tween: Tween = null
var _hide_timer: float = 0.0
var _is_showing: bool = false
var _waiting_for_input: bool = false
var _on_prologue_continue: Callable = Callable()

const SLIDE_DURATION: float = 0.35
const VISIBLE_DURATION: float = 5.8
const HIDDEN_OFFSET_X: float = -460.0
const SHOWN_OFFSET_X: float = 24.0

func _ready() -> void:
	layer = 55 # Por encima del dimmer (15) y Dialogic (50)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if anim_container:
		anim_container.position.x = HIDDEN_OFFSET_X
		anim_container.modulate.a = 0.0
	if portrait_rect:
		portrait_rect.pivot_offset = Vector2(40.0, 40.0)
	visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not _waiting_for_input:
		return

	var is_trigger: bool = false
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("dialogue_skip"):
		is_trigger = true
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			is_trigger = true
	elif event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		is_trigger = true

	if is_trigger:
		_waiting_for_input = false
		if get_viewport():
			get_viewport().set_input_as_handled()
		slide_out()
		if _on_prologue_continue.is_valid():
			_on_prologue_continue.call()

func _process(delta: float) -> void:
	if _is_showing and not _waiting_for_input:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_is_showing = false
			slide_out()

func show_prologue_transmission(nav_data: Resource, message_text: String, on_continue: Callable = Callable()) -> void:
	if not nav_data:
		if on_continue.is_valid():
			on_continue.call()
		return

	_waiting_for_input = true
	_on_prologue_continue = on_continue

	if portrait_rect:
		var nav_id_str: String = String(nav_data.nav_id) if "nav_id" in nav_data else ""
		var equipped_nav_skin: String = SaveManager.get_equipped_skin("navigator:" + nav_id_str)
		if not equipped_nav_skin.is_empty():
			var stars: int = SaveManager.get_skin_stars(equipped_nav_skin)
			CosmeticsManager.apply_skin_to_canvas_item(portrait_rect, equipped_nav_skin, stars)
		else:
			portrait_rect.texture = nav_data.get_portrait_texture()
			portrait_rect.material = null
	if name_label:
		name_label.text = "%s // OFICIAL TÁCTICA" % nav_data.display_name.to_upper()
		name_label.modulate = nav_data.theme_color
	if badge_label:
		badge_label.text = "[CANAL TÁCTICO EN LÍNEA]"
		badge_label.modulate = Color(0.2, 0.9, 1.0)
	if message_label:
		message_label.text = message_text
	if buff_hint_label:
		buff_hint_label.text = "✦ Pulsa [ESPACIO] o [CLICK] para despegar"
		buff_hint_label.modulate = Color(1.0, 0.88, 0.2)

	_apply_cyber_style(nav_data.theme_color)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.3)

	_is_showing = true
	_hide_timer = 99999.0

	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(anim_container, "position:x", SHOWN_OFFSET_X, SLIDE_DURATION)
	_current_tween.tween_property(anim_container, "modulate:a", 1.0, 0.2)
	if portrait_rect:
		portrait_rect.scale = Vector2(0.85, 0.85)
		_current_tween.tween_property(portrait_rect, "scale", Vector2.ONE, SLIDE_DURATION)

func show_transmission(nav_data: Resource, message_text: String, target_hint: String = "") -> void:
	if not nav_data:
		return

	if portrait_rect:
		var nav_id_str: String = String(nav_data.nav_id) if "nav_id" in nav_data else ""
		var equipped_nav_skin: String = SaveManager.get_equipped_skin("navigator:" + nav_id_str)
		if not equipped_nav_skin.is_empty():
			var stars: int = SaveManager.get_skin_stars(equipped_nav_skin)
			CosmeticsManager.apply_skin_to_canvas_item(portrait_rect, equipped_nav_skin, stars)
		else:
			portrait_rect.texture = nav_data.get_portrait_texture()
			portrait_rect.material = null
	if name_label:
		name_label.text = "%s // OFICIAL TÁCTICA" % nav_data.display_name.to_upper()
		name_label.modulate = nav_data.theme_color
	if badge_label:
		badge_label.text = "[OBJETIVO DETECTADO]"
		badge_label.modulate = Color(0.3, 1.0, 0.7)
	if message_label:
		message_label.text = message_text
	if buff_hint_label:
		if target_hint.is_empty():
			buff_hint_label.text = "✦ Sincroniza el punto: %s" % nav_data.buff_name
		else:
			buff_hint_label.text = "✦ %s — %s" % [target_hint, nav_data.buff_name]
		buff_hint_label.modulate = nav_data.theme_color.lerp(Color.WHITE, 0.3)

	# Estilo del borde con el color temático
	_apply_cyber_style(nav_data.theme_color)

	# Reproducir audio de radio
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.3)

	slide_in()

func show_buff_activated(nav_data: Resource) -> void:
	if not nav_data:
		return
	if badge_label:
		badge_label.text = "¡ENLACE SINCRONIZADO!"
		badge_label.modulate = Color(1.0, 0.85, 0.2)
	if message_label:
		message_label.text = "¡Objetivo alcanzado! Buff de navegación activado: %s." % nav_data.buff_name
	if buff_hint_label:
		buff_hint_label.text = "⚡ %s" % nav_data.buff_desc
		buff_hint_label.modulate = Color(0.2, 1.0, 0.6)

	_apply_cyber_style(Color(0.2, 1.0, 0.6))

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.6)

	slide_in(4.0)

func slide_in(display_time: float = VISIBLE_DURATION) -> void:
	_hide_timer = display_time
	_is_showing = true
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(anim_container, "position:x", SHOWN_OFFSET_X, SLIDE_DURATION)
	_current_tween.tween_property(anim_container, "modulate:a", 1.0, 0.2)
	if portrait_rect:
		portrait_rect.scale = Vector2(0.85, 0.85)
		_current_tween.tween_property(portrait_rect, "scale", Vector2.ONE, SLIDE_DURATION)

func slide_out() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_current_tween.tween_property(anim_container, "position:x", HIDDEN_OFFSET_X, 0.3)
	_current_tween.tween_property(anim_container, "modulate:a", 0.0, 0.25)

func _apply_cyber_style(glow_color: Color) -> void:
	if not border_panel:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.09, 0.92)
	sb.border_width_left = 3
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = glow_color
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_top_left = 4
	sb.corner_radius_bottom_left = 4
	sb.shadow_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.35)
	sb.shadow_size = 8
	border_panel.add_theme_stylebox_override("panel", sb)
