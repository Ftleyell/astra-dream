class_name NavigatorCommsWidget
extends CanvasLayer

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

const SLIDE_DURATION: float = 0.35
const VISIBLE_DURATION: float = 5.8
const HIDDEN_OFFSET_X: float = -460.0
const SHOWN_OFFSET_X: float = 24.0

func _ready() -> void:
	layer = 15
	if anim_container:
		anim_container.position.x = HIDDEN_OFFSET_X
		anim_container.modulate.a = 0.0
	visible = true

func _process(delta: float) -> void:
	if _is_showing:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_is_showing = false
			slide_out()

func show_transmission(nav_data: Resource, message_text: String, target_hint: String = "") -> void:
	if not nav_data:
		return

	if portrait_rect:
		portrait_rect.texture = nav_data.get_portrait_texture()
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
