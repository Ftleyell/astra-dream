class_name HUDCurseBadgeController
extends RefCounted

## HUDCurseBadgeController.gd
## Subcontrolador modular para la visualización del indicador de Maldición en el HUD.
## Extraído de GameHUD como parte de la Fase 4 del Plan de Erradicación de Monolitos.

var curse_badge: Control = null
var curse_label: Label = null

func setup_curse_badge(hud: CanvasLayer) -> void:
	if not hud:
		return
	var key_container: BoxContainer = hud.find_child("KeyBadgeContainer", true, false) as BoxContainer
	if not key_container:
		return
	curse_badge = key_container.find_child("CurseBadge", true, false) as Control
	if not curse_badge:
		var panel: PanelContainer = PanelContainer.new()
		panel.name = "CurseBadge"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.02, 0.05, 0.85)
		style.border_color = Color(1.0, 0.25, 0.35, 0.9)
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 12.0
		style.content_margin_right = 12.0
		style.content_margin_top = 3.0
		style.content_margin_bottom = 3.0
		style.shadow_color = Color(0.9, 0.1, 0.2, 0.25)
		style.shadow_size = 4
		panel.add_theme_stylebox_override("panel", style)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 4)

		var lbl: Label = Label.new()
		lbl.name = "CurseLabel"
		lbl.text = "MALDICIÓN +0"
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.48))
		lbl.add_theme_color_override("font_shadow_color", Color(0.8, 0.05, 0.15, 0.6))
		lbl.add_theme_constant_override("shadow_outline_size", 4)
		hbox.add_child(lbl)

		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.add_child(hbox)
		key_container.add_child(panel)

		key_container.move_child(panel, 0)
		curse_badge = panel
		curse_label = lbl
	else:
		curse_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		key_container.move_child(curse_badge, 0)
		curse_label = curse_badge.find_child("CurseLabel", true, false) as Label

	curse_badge.visible = false

func update_curse(hud: CanvasLayer, curse_val: float) -> void:
	if not curse_badge:
		setup_curse_badge(hud)
	if not curse_badge or not curse_label:
		return
	if curse_val > 0.0:
		curse_badge.visible = true
		curse_label.text = "MALDICIÓN +%d PTS" % int(curse_val)
		curse_badge.pivot_offset = curse_badge.size * 0.5
		if hud:
			var tw: Tween = hud.create_tween()
			if tw:
				tw.tween_property(curse_badge, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK)
				tw.tween_property(curse_badge, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
	else:
		curse_badge.visible = false
