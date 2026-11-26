class_name HUDAbilityClusterPreview
extends Control
## Widget HUD interactivo zero-allocation para previsualizar en vivo los 3 formatos de iconos
## de Skill [R] (Cooldown / Aim) y Ultimate [Q] (Energía 0-100% / READY):
##   0 = WuWa / Genshin Circular (Inferior Derecho)
##   1 = ZZZ Hexagonal + Arco Decibel (Inferior Derecho)
##   2 = Cockpit Orbital Unificado (Inferior Central)

enum HUDStyle {
	WUWA_GENSHIN_CIRCULAR = 0,
	ZZZ_HEX_DECIBEL = 1,
	COCKPIT_ORBITAL_CENTER = 2,
}

var hud_style: int = HUDStyle.WUWA_GENSHIN_CIRCULAR
var skill_cd_left: float = 0.0
var skill_cd_max: float = 8.0
var skill_holding_aim: bool = false
var ult_energy: float = 100.0
var ult_energy_max: float = 100.0
var accent_color: Color = Color(0.98, 0.14, 0.34, 1.0)
var secondary_color: Color = Color(0.545, 0.361, 0.965, 1.0)
var _pulse_time: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_hud_style(style_idx: int) -> void:
	hud_style = clampi(style_idx, 0, 2)
	queue_redraw()


func set_state(p_skill_cd: float, p_skill_max: float, p_holding: bool, p_ult_energy: float, p_ult_max: float) -> void:
	skill_cd_left = maxf(0.0, p_skill_cd)
	skill_cd_max = maxf(0.1, p_skill_max)
	skill_holding_aim = p_holding
	ult_energy = clampf(p_ult_energy, 0.0, maxf(1.0, p_ult_max))
	ult_energy_max = maxf(1.0, p_ult_max)
	queue_redraw()


func set_palette(accent: Color, secondary: Color) -> void:
	accent_color = accent
	secondary_color = secondary
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += clampf(delta, 0.0, 0.05)
	if ult_energy >= ult_energy_max - 0.01 or skill_holding_aim or skill_cd_left > 0.0:
		queue_redraw()


func _draw() -> void:
	var sz: Vector2 = size
	if sz.x < 100.0 or sz.y < 100.0:
		return
	var font: Font = ThemeDB.fallback_font
	var ult_ratio: float = clampf(ult_energy / ult_energy_max, 0.0, 1.0)
	var ult_ready: bool = ult_ratio >= 0.999
	var skill_cd_ratio: float = clampf(skill_cd_left / skill_cd_max, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_pulse_time * 5.2)

	if hud_style == HUDStyle.WUWA_GENSHIN_CIRCULAR:
		_draw_wuwa_genshin(sz, font, ult_ratio, ult_ready, skill_cd_ratio, pulse)
	elif hud_style == HUDStyle.ZZZ_HEX_DECIBEL:
		_draw_zzz_hex(sz, font, ult_ratio, ult_ready, skill_cd_ratio, pulse)
	else:
		_draw_cockpit_center(sz, font, ult_ratio, ult_ready, skill_cd_ratio, pulse)


func _draw_wuwa_genshin(sz: Vector2, font: Font, ult_ratio: float, ult_ready: bool, skill_cd_ratio: float, pulse: float) -> void:
	# Clúster circular inferior derecho estilo Wuthering Waves / Genshin
	var ult_c := Vector2(sz.x - 108.0, sz.y - 108.0)
	var skill_c := Vector2(sz.x - 222.0, sz.y - 88.0)
	var ult_r: float = 48.0
	var skill_r: float = 36.0

	# --- ULTIMATE [Q]: Orbe circular con llenado líquido vertical 0-100% ---
	draw_circle(ult_c, ult_r + 5.0, Color(0.03, 0.025, 0.07, 0.88))
	if ult_ratio > 0.01:
		var fill_col: Color = Color(accent_color.r * 1.4, accent_color.g * 1.15, accent_color.b * 1.3, 0.86) if ult_ready else Color(secondary_color.r, secondary_color.g, secondary_color.b, 0.65)
		var fill_pts := PackedVector2Array()
		var min_y: float = ult_c.y + ult_r - (ult_r * 2.0 * ult_ratio)
		for i: int in range(32):
			var a: float = float(i) * (TAU / 32.0)
			var pt: Vector2 = ult_c + Vector2(cos(a), sin(a)) * (ult_r - 3.0)
			if pt.y >= min_y:
				fill_pts.append(pt)
		if fill_pts.size() >= 3:
			draw_colored_polygon(fill_pts, fill_col)

	var ring_col: Color = Color(1.0, 0.86, 0.35, 0.9 + 0.1 * pulse) if ult_ready else Color(accent_color.r, accent_color.g, accent_color.b, 0.85)
	draw_arc(ult_c, ult_r, -PI * 0.5, -PI * 0.5 + TAU * ult_ratio, 40, ring_col, 5.0 if ult_ready else 3.5, true)
	if ult_ready:
		draw_arc(ult_c, ult_r + 6.0 + pulse * 4.0, 0.0, TAU, 36, Color(accent_color.r * 1.7, accent_color.g * 1.5, accent_color.b * 1.7, 0.55 * (1.0 - pulse * 0.4)), 2.5, true)
	_draw_wing_emblem(ult_c + Vector2(0.0, -4.0), 18.0, Color(1.0, 0.96, 1.0, 0.96) if ult_ready else Color(0.85, 0.88, 0.95, 0.72))
	_draw_centered_text(font, ult_c + Vector2(0.0, 26.0), "READY" if ult_ready else "%d%%" % int(roundf(ult_ratio * 100.0)), 12, Color(1.0, 0.92, 0.5, 1.0) if ult_ready else Color.WHITE)
	_draw_key_pill(font, ult_c + Vector2(0.0, ult_r + 18.0), "[Q] ULT", accent_color)

	# --- SKILL [R]: Círculo con barrido radial de Cooldown ---
	draw_circle(skill_c, skill_r + 3.0, Color(0.03, 0.04, 0.09, 0.88))
	var sk_ring: Color = Color(1.0, 0.82, 0.25, 1.0) if skill_holding_aim else (Color(0.25, 0.92, 1.0, 0.92) if skill_cd_left <= 0.0 else Color(0.35, 0.45, 0.60, 0.7))
	draw_arc(skill_c, skill_r, 0.0, TAU, 32, sk_ring, 3.2, true)
	if skill_cd_ratio > 0.001:
		draw_arc(skill_c, skill_r - 4.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - skill_cd_ratio), 28, Color(0.25, 0.92, 1.0, 0.9), 4.0, true)
	_draw_reticle_emblem(skill_c, 15.0, sk_ring)
	if skill_cd_left > 0.01:
		_draw_centered_text(font, skill_c + Vector2(0.0, 5.0), "%.1fs" % skill_cd_left, 15, Color.WHITE)
	elif skill_holding_aim:
		_draw_centered_text(font, skill_c + Vector2(0.0, -skill_r - 12.0), "AIMING", 11, Color(1.0, 0.86, 0.3, 1.0))
	_draw_key_pill(font, skill_c + Vector2(0.0, skill_r + 18.0), "[R] SKILL", Color(0.2, 0.85, 1.0, 1.0))


func _draw_zzz_hex(sz: Vector2, font: Font, ult_ratio: float, ult_ready: bool, skill_cd_ratio: float, pulse: float) -> void:
	# Clúster hexagonal ZZZ + Arco Decibel segmentado inferior derecho
	var ult_c := Vector2(sz.x - 116.0, sz.y - 112.0)
	var skill_c := Vector2(sz.x - 236.0, sz.y - 102.0)

	# Arco Decibel segmentado (12 segmentos alrededor de [Q])
	var seg_count: int = 12
	var start_a: float = -PI * 0.88
	var span_a: float = PI * 1.18
	for i: int in range(seg_count):
		var a0: float = start_a + (float(i) / float(seg_count)) * span_a
		var a1: float = a0 + (span_a / float(seg_count)) * 0.78
		var lit: bool = (float(i + 1) / float(seg_count)) <= ult_ratio + 0.001
		var c: Color = (Color(accent_color.r * 1.6, accent_color.g * 1.3, accent_color.b * 1.4, 0.98) if i < 8 else Color(secondary_color.r * 1.5, secondary_color.g * 1.4, secondary_color.b * 1.6, 0.98)) if lit else Color(0.15, 0.14, 0.24, 0.75)
		draw_arc(ult_c, 64.0, a0, a1, 6, c, 9.0, true)

	_draw_hex_panel(ult_c, 48.0, Color(0.06, 0.025, 0.10, 0.92), Color(1.0, 0.85, 0.35, 1.0) if ult_ready else accent_color, 3.5)
	_draw_wing_emblem(ult_c, 20.0, Color(1.0, 0.96, 1.0, 1.0) if ult_ready else Color(0.8, 0.82, 0.92, 0.72))
	_draw_centered_text(font, ult_c + Vector2(0.0, -68.0), "MAXIMUM" if ult_ready else "DECIBEL %d%%" % int(roundf(ult_ratio * 100.0)), 12, Color(1.0, 0.85, 0.35, 0.9 + 0.1 * pulse) if ult_ready else Color(0.9, 0.82, 1.0, 0.92))
	_draw_key_pill(font, ult_c + Vector2(0.0, 58.0), "[Q] ULT", accent_color)

	# Hexágono Skill [R]
	var sk_col: Color = Color(1.0, 0.84, 0.25, 1.0) if skill_holding_aim else (Color(0.28, 0.92, 1.0, 0.95) if skill_cd_left <= 0.0 else Color(0.42, 0.48, 0.62, 0.8))
	_draw_hex_panel(skill_c, 38.0, Color(0.04, 0.05, 0.11, 0.92), sk_col, 3.0)
	_draw_reticle_emblem(skill_c, 16.0, sk_col)
	if skill_cd_ratio > 0.001:
		_draw_centered_text(font, skill_c + Vector2(0.0, 5.0), "%.1fs" % skill_cd_left, 15, Color.WHITE)
	_draw_key_pill(font, skill_c + Vector2(0.0, 48.0), "[R] SKILL", Color(0.28, 0.92, 1.0, 1.0))


func _draw_cockpit_center(sz: Vector2, font: Font, ult_ratio: float, ult_ready: bool, skill_cd_ratio: float, pulse: float) -> void:
	# Cockpit Orbital Unificado inferior central (núcleo [Q] al centro + ala [R] a la izquierda)
	var center_x: float = sz.x * 0.5 + 110.0 # ligeramente desplazado para no chocar con el panel lateral del Studio
	var base_y: float = sz.y - 78.0
	var ult_c := Vector2(center_x, base_y - 12.0)
	var skill_c := Vector2(center_x - 118.0, base_y + 4.0)

	# Chasis inferior
	draw_rect(Rect2(center_x - 185.0, base_y - 34.0, 370.0, 74.0), Color(0.03, 0.04, 0.09, 0.84), true)
	draw_rect(Rect2(center_x - 185.0, base_y - 34.0, 370.0, 74.0), Color(0.22, 0.72, 0.95, 0.45), false, 2.0)

	# Núcleo central [Q]
	draw_circle(ult_c, 46.0, Color(0.05, 0.02, 0.09, 0.95))
	draw_arc(ult_c, 44.0, -PI * 0.5, -PI * 0.5 + TAU * ult_ratio, 36, Color(1.0, 0.86, 0.35, 1.0) if ult_ready else accent_color, 5.0, true)
	_draw_wing_emblem(ult_c + Vector2(0.0, -5.0), 17.0, Color.WHITE if ult_ready else Color(0.85, 0.85, 0.92, 0.75))
	_draw_centered_text(font, ult_c + Vector2(0.0, 22.0), "100% READY" if ult_ready else "%d%%" % int(roundf(ult_ratio * 100.0)), 11, Color(1.0, 0.88, 0.4, 0.9 + 0.1 * pulse) if ult_ready else Color.WHITE)
	_draw_key_pill(font, ult_c + Vector2(0.0, 48.0), "[Q] ULTIMATE", accent_color)

	# Ala izquierda [R] Skill
	var sk_col: Color = Color(1.0, 0.84, 0.25, 1.0) if skill_holding_aim else (Color(0.28, 0.92, 1.0, 0.95) if skill_cd_left <= 0.0 else Color(0.4, 0.48, 0.6, 0.8))
	draw_circle(skill_c, 28.0, Color(0.03, 0.05, 0.11, 0.92))
	draw_arc(skill_c, 28.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - skill_cd_ratio), 28, sk_col, 3.2, true)
	_draw_reticle_emblem(skill_c, 13.0, sk_col)
	if skill_cd_left > 0.01:
		_draw_centered_text(font, skill_c + Vector2(0.0, 4.0), "%.1fs" % skill_cd_left, 13, Color.WHITE)
	_draw_key_pill(font, skill_c + Vector2(0.0, 36.0), "[R] SKILL", Color(0.28, 0.92, 1.0, 1.0))


func _draw_hex_panel(c: Vector2, r: float, fill: Color, border: Color, border_w: float) -> void:
	var pts := PackedVector2Array()
	for i: int in range(6):
		var a: float = float(i) * (TAU / 6.0) - PI * 0.5
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, border, border_w, true)


func _draw_wing_emblem(c: Vector2, s: float, col: Color) -> void:
	for side: float in [-1.0, 1.0]:
		var pts := PackedVector2Array([
			c + Vector2(side * 2.0, s * 0.4),
			c + Vector2(side * s * 1.15, -s * 0.65),
			c + Vector2(side * s * 0.72, s * 0.08),
			c + Vector2(side * s * 0.92, s * 0.55),
		])
		draw_colored_polygon(pts, col)


func _draw_reticle_emblem(c: Vector2, r: float, col: Color) -> void:
	draw_arc(c, r, 0.0, TAU, 24, col, 2.0, true)
	draw_line(c + Vector2(-r * 1.3, 0.0), c + Vector2(-r * 0.45, 0.0), col, 2.0, true)
	draw_line(c + Vector2(r * 0.45, 0.0), c + Vector2(r * 1.3, 0.0), col, 2.0, true)
	draw_line(c + Vector2(0.0, -r * 1.3), c + Vector2(0.0, -r * 0.45), col, 2.0, true)
	draw_line(c + Vector2(0.0, r * 0.45), c + Vector2(0.0, r * 1.3), col, 2.0, true)
	draw_circle(c, 2.5, col)


func _draw_key_pill(font: Font, c: Vector2, txt: String, border_col: Color) -> void:
	var w: float = 78.0
	var h: float = 18.0
	var rect := Rect2(c - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
	draw_rect(rect, Color(0.03, 0.035, 0.08, 0.90), true)
	draw_rect(rect, Color(border_col.r, border_col.g, border_col.b, 0.75), false, 1.4)
	_draw_centered_text(font, c + Vector2(0.0, 4.0), txt, 10, Color(0.95, 0.97, 1.0, 0.98))


func _draw_centered_text(font: Font, pos: Vector2, txt: String, fsize: int, col: Color) -> void:
	if font == null:
		return
	var sz_t: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	draw_string(font, pos - Vector2(sz_t.x * 0.5, 0.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
