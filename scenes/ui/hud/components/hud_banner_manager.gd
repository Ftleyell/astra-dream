class_name HUDBannerManager
extends RefCounted

## HUDBannerManager.gd
## Gestor de anuncios y banners flotantes cinematográficos en el HUD:
## - Banner holográfico de satélite detectado con animación elástica e indicador de radar.
## - Banner de desbloqueo de personaje nuevo (Nyx, etc.) con estilo de condecoración militar y estrellas.

var _satellite_banner_node: Control = null
var _satellite_banner_tween: Tween = null

var _unlock_banner_node: Control = null
var _unlock_banner_tween: Tween = null

var _tactical_alert_node: Control = null
var _tactical_alert_tween: Tween = null
var _tactical_alert_style: StyleBoxFlat = null

func show_satellite_banner(index: int, hud_node: CanvasLayer) -> void:
	if not _satellite_banner_node:
		_create_satellite_banner_ui(hud_node)
	if not _satellite_banner_node:
		return

	var title_lbl: Label = _satellite_banner_node.find_child("BannerTitle", true, false) as Label
	var sub_lbl: Label = _satellite_banner_node.find_child("BannerSubtitle", true, false) as Label
	if title_lbl:
		title_lbl.text = "🛰️ ENLACE DE SATÉLITE DETECTADO"
	if sub_lbl:
		sub_lbl.text = "Baliza orbital #%d en línea • Trayectoria en radar" % index

	if _satellite_banner_tween and _satellite_banner_tween.is_valid():
		_satellite_banner_tween.kill()

	_satellite_banner_node.visible = true
	_satellite_banner_node.modulate.a = 0.0
	_satellite_banner_node.offset_left = -230.0
	_satellite_banner_node.offset_right = 230.0
	_satellite_banner_node.offset_top = 100.0
	_satellite_banner_node.offset_bottom = 160.0

	var audio_mgr := hud_node.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.55)

	_satellite_banner_tween = hud_node.create_tween()
	_satellite_banner_tween.set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_satellite_banner_tween.tween_property(_satellite_banner_node, "offset_top", 125.0, 0.28)
	_satellite_banner_tween.tween_property(_satellite_banner_node, "offset_bottom", 185.0, 0.28)
	_satellite_banner_tween.tween_property(_satellite_banner_node, "modulate:a", 1.0, 0.22)
	_satellite_banner_tween.chain().tween_interval(5.0)
	_satellite_banner_tween.chain().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_satellite_banner_tween.tween_property(_satellite_banner_node, "offset_top", 100.0, 0.35)
	_satellite_banner_tween.tween_property(_satellite_banner_node, "offset_bottom", 160.0, 0.35)
	_satellite_banner_tween.tween_property(_satellite_banner_node, "modulate:a", 0.0, 0.35)
	_satellite_banner_tween.chain().tween_callback(func():
		if _satellite_banner_node:
			_satellite_banner_node.visible = false
	)

func _create_satellite_banner_ui(hud_node: CanvasLayer) -> void:
	var banner_box := PanelContainer.new()
	banner_box.name = "SatelliteBannerPanel"
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.layout_mode = 1
	banner_box.anchors_preset = Control.PRESET_CENTER_TOP
	banner_box.anchor_left = 0.5
	banner_box.anchor_right = 0.5
	banner_box.offset_left = -230.0
	banner_box.offset_top = 125.0
	banner_box.offset_right = 230.0
	banner_box.offset_bottom = 185.0
	banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_box.custom_minimum_size = Vector2(460, 60)
	banner_box.pivot_offset = Vector2(230, 30)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.12, 0.88)
	style.border_color = Color(0.0, 0.85, 1.0, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8.0)
	style.shadow_color = Color(0.0, 0.7, 0.9, 0.35)
	style.shadow_size = 8
	banner_box.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)

	var title := Label.new()
	title.name = "BannerTitle"
	title.text = "🛰️ ENLACE DE SATÉLITE DETECTADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#00E5FF"))
	vbox.add_child(title)

	var sub := Label.new()
	sub.name = "BannerSubtitle"
	sub.text = "Baliza orbital en línea"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 0.9))
	vbox.add_child(sub)

	banner_box.add_child(vbox)
	hud_node.add_child(banner_box)
	_satellite_banner_node = banner_box
	_satellite_banner_node.visible = false

func show_character_unlock_banner(_char_id: StringName, title_text: String, desc_text: String, hud_node: CanvasLayer) -> void:
	if not _unlock_banner_node:
		_create_unlock_banner_ui(hud_node)
	if not _unlock_banner_node:
		return

	var title_lbl: Label = _unlock_banner_node.find_child("UnlockTitle", true, false) as Label
	var desc_lbl: Label = _unlock_banner_node.find_child("UnlockDesc", true, false) as Label
	if title_lbl:
		title_lbl.text = title_text
	if desc_lbl:
		desc_lbl.text = desc_text

	if _unlock_banner_tween and _unlock_banner_tween.is_valid():
		_unlock_banner_tween.kill()

	_unlock_banner_node.visible = true
	_unlock_banner_node.modulate.a = 0.0
	_unlock_banner_node.scale = Vector2(0.8, 0.8)

	var audio_mgr := hud_node.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.8)

	_unlock_banner_tween = hud_node.create_tween()
	_unlock_banner_tween.set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_unlock_banner_tween.tween_property(_unlock_banner_node, "scale", Vector2(1.0, 1.0), 0.4)
	_unlock_banner_tween.tween_property(_unlock_banner_node, "modulate:a", 1.0, 0.28)
	_unlock_banner_tween.chain().tween_interval(5.0)
	_unlock_banner_tween.chain().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_unlock_banner_tween.tween_property(_unlock_banner_node, "modulate:a", 0.0, 0.5)
	_unlock_banner_tween.chain().tween_callback(func():
		if _unlock_banner_node:
			_unlock_banner_node.visible = false
	)

func _create_unlock_banner_ui(hud_node: CanvasLayer) -> void:
	var banner_box := PanelContainer.new()
	banner_box.name = "CharacterUnlockPanel"
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.layout_mode = 1
	banner_box.anchors_preset = Control.PRESET_CENTER_TOP
	banner_box.anchor_left = 0.5
	banner_box.anchor_right = 0.5
	banner_box.offset_left = -290.0
	banner_box.offset_top = 125.0
	banner_box.offset_right = 290.0
	banner_box.offset_bottom = 235.0
	banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_box.custom_minimum_size = Vector2(580, 110)
	banner_box.pivot_offset = Vector2(290, 55)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.02, 0.12, 0.95)
	style.border_color = Color(0.9, 0.25, 1.0, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16.0)
	style.shadow_color = Color(0.9, 0.2, 1.0, 0.5)
	style.shadow_size = 18
	banner_box.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var badge := Label.new()
	badge.text = "★ ARCHIVO DE CARRERA ACTUALIZADO ★"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.95))
	vbox.add_child(badge)

	var title := Label.new()
	title.name = "UnlockTitle"
	title.text = "¡NUEVO PILOTO DESBLOQUEADO: NYX!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.35, 1.0))
	vbox.add_child(title)

	var desc := Label.new()
	desc.name = "UnlockDesc"
	desc.text = "Has derrotado a 10 Jefes Titanes en tu Carrera espacial."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 0.9))
	vbox.add_child(desc)

	banner_box.add_child(vbox)
	hud_node.add_child(banner_box)
	_unlock_banner_node = banner_box
	_unlock_banner_node.visible = false
