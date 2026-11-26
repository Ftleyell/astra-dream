class_name SniperWeakpointRailVFX
extends Node2D
## VFX zero-allocation AAA en mundo para la Skill [R] de Valentina v2:
## - Modo Hold-to-Aim interactivo: haz láser de telemetría vivo + brackets de lock-on convergentes + anillos de carga.
## - Disparo hipersónico Sniper Rail-Lance: núcleo blanco HDR, arcos eléctricos/plasma a lo largo del cañón,
##   4 conos sónicos direccionales en la boca y estallido crítico en el Punto Débil.
## - Marcadores rotativos de Vulnerabilidad Óptica sobre objetivos supervivientes.

signal shot_impacted(target: Node2D, hit_pos: Vector2, beam_end: Vector2)

const MAX_VULN_MARKS: int = 16

var _accent_color: Color = Color(0.98, 0.14, 0.34, 1.0)
var _secondary_color: Color = Color(0.545, 0.361, 0.965, 1.0)

# Estado Hold-to-Aim interactivo
var _aim_holding: bool = false
var _aim_origin: Vector2 = Vector2.ZERO
var _aim_target_node: Node2D = null
var _aim_target_pos: Vector2 = Vector2.ZERO
var _aim_hold_elapsed: float = 0.0

# Estado Lock-On rápido (pre-disparo)
var _lock_active: bool = false
var _lock_origin: Vector2 = Vector2.ZERO
var _lock_target_node: Node2D = null
var _lock_target_pos: Vector2 = Vector2.ZERO
var _lock_elapsed: float = 0.0
var _lock_duration: float = 0.14

# Estado Disparo Sniper Rail-Lance
var _beam_active: bool = false
var _beam_origin: Vector2 = Vector2.ZERO
var _beam_end: Vector2 = Vector2.ZERO
var _beam_impact_pos: Vector2 = Vector2.ZERO
var _beam_width: float = 44.0
var _beam_elapsed: float = 0.0
var _beam_duration: float = 0.32
var _time_scale: float = 1.0

var _vuln_marks: Array[Dictionary] = [] # {node: Node2D, pos: Vector2, remaining: float, duration: float}


func _ready() -> void:
	top_level = true
	z_index = 45
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_palette(accent: Color, secondary: Color = Color(0.545, 0.361, 0.965, 1.0)) -> void:
	_accent_color = accent
	_secondary_color = secondary


func set_time_scale(scale_val: float) -> void:
	_time_scale = clampf(scale_val, 0.05, 2.0)


func update_hold_aim(origin_pos: Vector2, target_node: Node2D, aim_world_pos: Vector2) -> void:
	if not _aim_holding:
		_aim_hold_elapsed = 0.0
	_aim_holding = true
	_aim_origin = origin_pos
	_aim_target_node = target_node
	_aim_target_pos = target_node.global_position if is_instance_valid(target_node) else aim_world_pos
	queue_redraw()


func stop_hold_aim() -> void:
	if _aim_holding:
		_aim_holding = false
		queue_redraw()


func is_holding_aim() -> bool:
	return _aim_holding


func begin_weakpoint_lock(origin_pos: Vector2, target_node: Node2D, fallback_pos: Vector2, lead_sec: float = 0.14) -> void:
	_aim_holding = false
	_lock_active = true
	_lock_origin = origin_pos
	_lock_target_node = target_node
	_lock_target_pos = target_node.global_position if is_instance_valid(target_node) else fallback_pos
	_lock_elapsed = 0.0
	_lock_duration = maxf(0.04, lead_sec)
	queue_redraw()


func fire_sniper_beam(origin_pos: Vector2, target_node: Node2D, fallback_pos: Vector2, cfg: PilotSkillConfig) -> void:
	_aim_holding = false
	_lock_active = false
	var target_pos: Vector2 = target_node.global_position if is_instance_valid(target_node) else fallback_pos
	var dir: Vector2 = (target_pos - origin_pos)
	var dist: float = dir.length()
	var dir_n: Vector2 = (dir / dist) if dist > 1.0 else Vector2.RIGHT

	var max_len: float = cfg.beam_max_length_px if cfg != null else 2200.0
	var pierce: bool = cfg.pierce_all_in_line if cfg != null else false
	var end_pos: Vector2 = origin_pos + dir_n * (max_len if pierce else maxf(dist + 120.0, 280.0))

	_beam_active = true
	_beam_origin = origin_pos
	_beam_end = end_pos
	_beam_impact_pos = target_pos
	_beam_width = cfg.beam_width_px if cfg != null else 44.0
	_beam_elapsed = 0.0
	_beam_duration = cfg.beam_duration_sec if cfg != null else 0.32

	if cfg != null and cfg.apply_vulnerability and is_instance_valid(target_node):
		add_vulnerability_mark(target_node, cfg.vulnerability_duration_sec)

	shot_impacted.emit(target_node, target_pos, end_pos)
	queue_redraw()


func add_vulnerability_mark(target_node: Node2D, duration_sec: float) -> void:
	if not is_instance_valid(target_node):
		return
	for entry: Dictionary in _vuln_marks:
		if entry.get("node") == target_node:
			entry["remaining"] = duration_sec
			entry["duration"] = duration_sec
			return
	if _vuln_marks.size() >= MAX_VULN_MARKS:
		_vuln_marks.pop_front()
	_vuln_marks.append({
		"node": target_node,
		"pos": target_node.global_position,
		"remaining": duration_sec,
		"duration": maxf(0.1, duration_sec),
	})


func clear_all() -> void:
	_aim_holding = false
	_lock_active = false
	_beam_active = false
	_vuln_marks.clear()
	queue_redraw()


func is_active() -> bool:
	return _aim_holding or _lock_active or _beam_active


func _process(delta: float) -> void:
	var dt: float = clampf(delta, 0.0, 0.05) * _time_scale
	var dirty: bool = false

	if _aim_holding:
		_aim_hold_elapsed += clampf(delta, 0.0, 0.05)
		if is_instance_valid(_aim_target_node):
			_aim_target_pos = _aim_target_node.global_position
		dirty = true

	if _lock_active:
		_lock_elapsed += dt
		if is_instance_valid(_lock_target_node):
			_lock_target_pos = _lock_target_node.global_position
		dirty = true

	if _beam_active:
		_beam_elapsed += dt
		if _beam_elapsed >= _beam_duration:
			_beam_active = false
		dirty = true

	if not _vuln_marks.is_empty():
		var idx: int = _vuln_marks.size() - 1
		while idx >= 0:
			var entry: Dictionary = _vuln_marks[idx]
			var node_ref: Node2D = entry.get("node") as Node2D
			entry["remaining"] = float(entry.get("remaining", 0.0)) - dt
			if not is_instance_valid(node_ref) or float(entry["remaining"]) <= 0.0:
				_vuln_marks.remove_at(idx)
			else:
				entry["pos"] = node_ref.global_position
			idx -= 1
		dirty = true

	if dirty:
		queue_redraw()


func _draw() -> void:
	if _aim_holding:
		_draw_hold_aim_telemetry()
	if _lock_active:
		_draw_weakpoint_lock()
	if _beam_active:
		_draw_sniper_beam()
	for entry: Dictionary in _vuln_marks:
		_draw_vulnerability_badge(entry)


func _draw_hold_aim_telemetry() -> void:
	var charge_t: float = clampf(_aim_hold_elapsed / 0.35, 0.0, 1.0)
	var dir: Vector2 = (_aim_target_pos - _aim_origin).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var has_target: bool = is_instance_valid(_aim_target_node)

	# Corredor de puntería holográfico + línea láser central
	var corridor_w: float = lerpf(42.0, 14.0, ease(charge_t, 0.3))
	var rail_col: Color = Color(_accent_color.r * 1.4, _accent_color.g * 1.4, _accent_color.b * 1.4, 0.32 + 0.38 * charge_t)
	draw_line(_aim_origin + perp * corridor_w, _aim_target_pos + perp * corridor_w, Color(rail_col.r, rail_col.g, rail_col.b, 0.25), 1.5, true)
	draw_line(_aim_origin - perp * corridor_w, _aim_target_pos - perp * corridor_w, Color(rail_col.r, rail_col.g, rail_col.b, 0.25), 1.5, true)
	draw_line(_aim_origin, _aim_target_pos, rail_col, 2.6, true)
	draw_line(_aim_origin, _aim_target_pos, Color(1.85, 1.80, 1.95, 0.65 * charge_t), 1.1, true)

	# Anillo de carga en la boca de Valentina
	var muzzle_r: float = lerpf(46.0, 18.0, charge_t)
	draw_arc(_aim_origin, muzzle_r, _aim_hold_elapsed * 4.0, _aim_hold_elapsed * 4.0 + TAU * 0.72, 24, Color(_secondary_color.r * 1.5, _secondary_color.g * 1.5, _secondary_color.b * 1.5, 0.85), 2.5, true)

	# Retícula óptica viva sobre el enemigo seleccionado (o cursor)
	var lock_r: float = lerpf(72.0, 32.0, ease(charge_t, 0.28)) if has_target else 38.0
	var rot: float = _aim_hold_elapsed * (1.8 if has_target else 0.7)
	var ret_col: Color = Color(_accent_color.r * 1.8, _accent_color.g * 1.5, _accent_color.b * 1.6, 0.96) if has_target else Color(0.35, 0.92, 1.0, 0.85)
	draw_arc(_aim_target_pos, lock_r, rot, rot + TAU * 0.85, 28, ret_col, 2.8, true)

	# 4 brackets esquineros de francotirador
	var b_len: float = 12.0
	for i: int in range(4):
		var ang: float = rot + float(i) * (PI * 0.5) + PI * 0.25
		var corner: Vector2 = _aim_target_pos + Vector2(cos(ang), sin(ang)) * (lock_r + 6.0)
		var inward: Vector2 = -Vector2(cos(ang), sin(ang))
		draw_line(corner, corner + inward * b_len, Color(1.9, 1.85, 2.0, 0.95), 2.4, true)
	draw_circle(_aim_target_pos, 4.5, Color(1.95, 1.8, 1.9, 0.98))


func _draw_weakpoint_lock() -> void:
	var t: float = clampf(_lock_elapsed / maxf(_lock_duration, 0.001), 0.0, 1.0)
	var radius: float = lerpf(86.0, 28.0, ease(t, 0.28))
	var rot: float = lerpf(-0.9, 0.0, ease(t, 0.3))

	var guide_col: Color = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.45 + 0.50 * t)
	draw_line(_lock_origin, _lock_target_pos, guide_col, 2.4, true)

	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(7):
		var ang: float = rot + float(i) * (TAU / 6.0)
		pts.append(_lock_target_pos + Vector2(cos(ang), sin(ang)) * radius)
	draw_polyline(pts, Color(_accent_color.r * 1.65, _accent_color.g * 1.65, _accent_color.b * 1.65, 0.98), 3.2, true)
	draw_circle(_lock_target_pos, 6.0 + 3.0 * (1.0 - t), Color(1.9, 1.8, 2.0, 0.98))


func _draw_sniper_beam() -> void:
	var t: float = clampf(_beam_elapsed / maxf(_beam_duration, 0.001), 0.0, 1.0)
	var fade: float = pow(1.0 - t, 1.35)
	var w_scale: float = lerpf(1.38, 0.12, t)
	var beam_vec: Vector2 = _beam_end - _beam_origin
	var beam_len: float = maxf(beam_vec.length(), 1.0)
	var dir: Vector2 = beam_vec / beam_len
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	# 1. Halo plasma exterior HDR + vaina carmesí + núcleo blanco incandescente
	draw_line(_beam_origin, _beam_end, Color(_secondary_color.r * 1.5, _secondary_color.g * 1.5, _secondary_color.b * 1.5, 0.38 * fade), _beam_width * 2.25 * w_scale, true)
	draw_line(_beam_origin, _beam_end, Color(_accent_color.r * 1.9, _accent_color.g * 1.4, _accent_color.b * 1.6, 0.92 * fade), _beam_width * 1.05 * w_scale, true)
	draw_line(_beam_origin, _beam_end, Color(2.0, 1.96, 2.1, 1.0 * fade), _beam_width * 0.42 * w_scale, true)

	# 2. Arcos eléctricos / plasma en zigzag a lo largo del cañón Sniper
	var segs: int = 16
	var arc_pts := PackedVector2Array()
	var seed_t: float = floor(_beam_elapsed * 42.0) * 3.7
	for s: int in range(segs + 1):
		var frac: float = float(s) / float(segs)
		var jitter: float = 0.0 if (s == 0 or s == segs) else sin(float(s) * 4.3 + seed_t) * (_beam_width * 0.85 * fade)
		arc_pts.append(_beam_origin + dir * (beam_len * frac) + perp * jitter)
	draw_polyline(arc_pts, Color(1.9, 1.75, 2.05, 0.88 * fade), 2.6 * fade, true)

	# 3. 4 Conos sónicos direccionales en la boca del disparo
	for i: int in range(4):
		var ring_dist: float = 26.0 + float(i) * 48.0 + t * 75.0
		var ring_pos: Vector2 = _beam_origin + dir * ring_dist
		var ring_h: float = (_beam_width * (1.55 - float(i) * 0.22)) * (0.65 + t * 0.95)
		var cone_back: Vector2 = ring_pos - dir * (20.0 + float(i) * 6.0)
		var cone_col: Color = Color(_accent_color.r * 1.8, _accent_color.g * 1.7, _accent_color.b * 1.8, 0.82 * fade)
		draw_line(cone_back - perp * ring_h, ring_pos, cone_col, 3.2 * fade, true)
		draw_line(cone_back + perp * ring_h, ring_pos, cone_col, 3.2 * fade, true)

	# 4. Estrella de retroceso en la boca + Estallido crítico devastador en el Punto Débil
	var muzzle_flash_r: float = lerpf(52.0, 8.0, t)
	draw_circle(_beam_origin, muzzle_flash_r * 0.45, Color(2.0, 1.9, 2.0, 0.95 * fade))
	var burst_r: float = lerpf(24.0, 165.0, ease(t, 0.28))
	draw_arc(_beam_impact_pos, burst_r, 0.0, TAU, 36, Color(_accent_color.r * 1.9, _accent_color.g * 1.7, _accent_color.b * 1.8, 0.92 * fade), 5.0 * fade, true)
	draw_arc(_beam_impact_pos, burst_r * 0.58, 0.0, TAU, 28, Color(2.0, 1.95, 2.1, 0.96 * fade), 3.0 * fade, true)
	for k: int in range(12):
		var ang: float = float(k) * (TAU / 12.0) + 0.22
		var inner_p: Vector2 = _beam_impact_pos + Vector2(cos(ang), sin(ang)) * (burst_r * 0.28)
		var outer_p: Vector2 = _beam_impact_pos + Vector2(cos(ang), sin(ang)) * (burst_r * (1.42 if k % 2 == 0 else 0.98))
		draw_line(inner_p, outer_p, Color(2.0, 1.75, 1.95, 0.92 * fade), (3.4 if k % 2 == 0 else 2.0) * fade, true)


func _draw_vulnerability_badge(entry: Dictionary) -> void:
	var pos: Vector2 = entry.get("pos", Vector2.ZERO)
	var rem: float = float(entry.get("remaining", 0.0))
	var rot: float = rem * 2.4
	var r: float = 21.0 + sin(rem * 8.0) * 2.5
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(5):
		var a: float = rot + float(i) * (TAU / 4.0)
		pts.append(pos + Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, Color(_secondary_color.r * 1.5, _secondary_color.g * 1.5, _secondary_color.b * 1.5, 0.90), 2.5, true)
	draw_circle(pos, 3.8, Color(_accent_color.r * 1.8, _accent_color.g * 1.8, _accent_color.b * 1.8, 0.95))
