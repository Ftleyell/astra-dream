class_name PilotSkinPaletteResolver
extends RefCounted
## Value Object puro que deriva la paleta cromática unificada de habilidades
## (accent, contrast_crosshair +165° HSV, stage_bg, hair_highlight, panel, sandevistan_gradient)
## a partir de cualquier PilotSkinPreset (o fallback base si es null / is_base_skin).


static func resolve(skin: PilotSkinPreset = null) -> Dictionary:
	var accent: Color = Color(0.98, 0.14, 0.34, 1.0)
	var suit_dark: Color = Color(0.06, 0.04, 0.11, 1.0)
	var panel: Color = Color(0.84, 0.88, 0.96, 1.0)
	var hair: Color = Color(0.88, 0.86, 0.96, 1.0)
	var has_cross_ovr: bool = false
	var has_bg_ovr: bool = false
	var cross_ovr: Color = Color(0.0, 0.0, 0.0, 0.0)
	var bg_ovr: Color = Color(0.0, 0.0, 0.0, 0.0)

	if skin != null:
		if not skin.is_base_skin:
			accent = skin.accent_color
			suit_dark = skin.suit_dark_color
			panel = skin.panel_color
			hair = skin.hair_color
		cross_ovr = skin.crosshair_override_color
		bg_ovr = skin.ult_bg_override_color
		has_cross_ovr = cross_ovr.a > 0.05
		has_bg_ovr = bg_ovr.a > 0.05

	# Color contrastante garantizado para Radar Ocular y Crosshairs (+165.6° HSV, S>=0.88, V=0.98)
	var contrast: Color = cross_ovr if has_cross_ovr else Color.from_hsv(
		fposmod(accent.h + 0.46, 1.0),
		maxf(accent.s, 0.88),
		0.98,
		1.0
	)
	var stage_bg: Color = bg_ovr if has_bg_ovr else Color.from_hsv(
		suit_dark.h,
		clampf(suit_dark.s * 1.15, 0.25, 0.72),
		clampf(suit_dark.v * 0.28, 0.025, 0.095),
		1.0
	)

	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	grad.colors = PackedColorArray([contrast, accent, hair.lerp(panel, 0.4)])

	return {
		"accent": accent,
		"contrast_crosshair": contrast,
		"stage_bg": stage_bg,
		"hair_highlight": hair,
		"panel": panel,
		"sandevistan_gradient": grad,
	}
