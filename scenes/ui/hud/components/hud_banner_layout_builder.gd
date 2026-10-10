class_name HUDBannerLayoutBuilder
extends RefCounted

## HUDBannerLayoutBuilder.gd
## Factoría procedural de contenedores y paneles visuales para HUDBannerManager.

static func create_satellite_banner_panel() -> PanelContainer:
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
	sub.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.9))
	vbox.add_child(sub)

	banner_box.add_child(vbox)
	return banner_box


static func create_rival_banner_panel() -> PanelContainer:
	var banner_box := PanelContainer.new()
	banner_box.name = "RivalDefeatedBannerPanel"
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.layout_mode = 1
	banner_box.anchors_preset = Control.PRESET_CENTER_TOP
	banner_box.anchor_left = 0.5
	banner_box.anchor_right = 0.5
	banner_box.offset_left = -270.0
	banner_box.offset_top = 120.0
	banner_box.offset_right = 270.0
	banner_box.offset_bottom = 215.0
	banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_box.custom_minimum_size = Vector2(540, 95)
	banner_box.pivot_offset = Vector2(270, 47)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.08, 0.94)
	style.border_color = Color(1.0, 0.3, 0.4, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12.0)
	style.shadow_color = Color(1.0, 0.2, 0.4, 0.35)
	style.shadow_size = 14
	banner_box.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)

	var portrait_frame := PanelContainer.new()
	portrait_frame.name = "PortraitFrame"
	portrait_frame.custom_minimum_size = Vector2(68, 68)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.1, 0.16, 0.9)
	p_style.border_color = Color(1.0, 0.3, 0.4, 1.0)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(8)
	portrait_frame.add_theme_stylebox_override("panel", p_style)

	var portrait_rect := TextureRect.new()
	portrait_rect.name = "RivalPortrait"
	portrait_rect.custom_minimum_size = Vector2(64, 64)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_frame.add_child(portrait_rect)
	hbox.add_child(portrait_frame)

	var center_vbox := VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 3)

	var top_badge := Label.new()
	top_badge.text = "⚡ OBJETIVO NEUTRALIZADO // PILOTO RIVAL ABATIDA"
	top_badge.add_theme_font_size_override("font_size", 11)
	top_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.9))
	center_vbox.add_child(top_badge)

	var name_lbl := Label.new()
	name_lbl.name = "RivalName"
	name_lbl.text = "RIVAL"
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.45, 1.0))
	center_vbox.add_child(name_lbl)

	var status_lbl := Label.new()
	status_lbl.text = "Frecuencia de combate desarticulada"
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88, 0.85))
	center_vbox.add_child(status_lbl)

	hbox.add_child(center_vbox)
	banner_box.add_child(hbox)
	return banner_box


static func create_unlock_banner_panel() -> PanelContainer:
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
	return banner_box


static func create_alert_banner_panel() -> Dictionary:
	var banner_box := PanelContainer.new()
	banner_box.name = "TacticalAlertPanel"
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.layout_mode = 1
	banner_box.anchors_preset = Control.PRESET_CENTER_TOP
	banner_box.anchor_left = 0.5
	banner_box.anchor_right = 0.5
	banner_box.offset_left = -260.0
	banner_box.offset_top = 195.0
	banner_box.offset_right = 260.0
	banner_box.offset_bottom = 260.0
	banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_box.custom_minimum_size = Vector2(520, 65)
	banner_box.pivot_offset = Vector2(260, 32.5)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.08, 0.92)
	style.border_color = Color(0.2, 0.9, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8.0)
	style.shadow_color = Color(0.2, 0.9, 1.0, 0.35)
	style.shadow_size = 10
	banner_box.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)

	var title := Label.new()
	title.name = "AlertTitle"
	title.text = "ALERTA TÁCTICA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	vbox.add_child(title)

	var sub := Label.new()
	sub.name = "AlertSubtitle"
	sub.text = ""
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.95))
	vbox.add_child(sub)

	banner_box.add_child(vbox)
	return {
		"panel": banner_box,
		"style": style
	}
