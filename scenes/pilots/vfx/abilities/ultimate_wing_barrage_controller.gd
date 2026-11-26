class_name UltimateWingBarrageController
extends Node2D
## Controlador zero-allocation de las 12 cuchillas reales de las alas de Valentina v2.
## Coreografía física en 3 fases sobre 12 nodos reales persistentes (pool fijo):
##   1. OUTBOUND: Las 12 cuchillas se desprenden de la espalda de Valentina y salen disparadas
##      hacia todos los enemigos visibles en pantalla dejando cortes láser cruzados HDR.
##   2. APEX_TURN: En su ápice exterior desaceleran, hacen un giro metálico con destello
##      y fijan la posición viva actual de Valentina.
##   3. RETURN_RECALL: Regresan volando en abanico hacia Valentina (cortando en retorno)
##      y se re-acoplan en su espalda con pulso SERAPH_BLOOM.

signal blade_impacted(target: Node2D, world_pos: Vector2, blade_idx: int, effective_damage_mult: float)
signal blades_returning()
signal finisher_detonated(targets: Array[Node2D])
signal barrage_finished()

const WINGS_ASSET_DIR: String = "res://assets/pilots/valentina_v2/planar/wings"
const WINGS_META_PATH: String = "res://assets/pilots/valentina_v2/planar/wings/wings_metadata.json"
const WING_GLOW_SHADER_PATH: String = "res://scenes/pilots/shaders/wing_red_glow.gdshader"
const MAX_BLADES: int = 12
const TRAIL_POINTS: int = 7

enum BladeStage {
	INACTIVE = 0,
	OUTBOUND = 1,
	APEX_TURN = 2,
	RETURN_RECALL = 3,
}

var _accent_color: Color = Color(0.98, 0.14, 0.34, 1.0)
var _secondary_color: Color = Color(0.545, 0.361, 0.965, 1.0)
var _time_scale: float = 1.0
var _is_active: bool = false
var _finisher_emitted: bool = false
var _return_signal_emitted: bool = false
var _cfg: PilotUltimateConfig = null
var _anchor_node: Node2D = null
var _origin_fallback: Vector2 = Vector2.ZERO
var _assigned_targets: Array[Node2D] = []

# Pool pre-alocado de 12 objetos físicos de cuchilla (Node2D + Sprite2D real + glow HDR)
var _blade_nodes: Array[Node2D] = []
var _blade_sprites: Array[Sprite2D] = []
var _blade_glow_mats: Array[ShaderMaterial] = []
var _blade_states: Array[Dictionary] = []
var _slash_lines: Array[Dictionary] = [] # {a: Vector2, b: Vector2, age: float, max_age: float}
var _bursts: Array[Dictionary] = []      # {pos: Vector2, age: float, max_age: float, is_finisher: bool}


func _ready() -> void:
	top_level = true
	z_index = 48
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_blade_pool()


func _build_blade_pool() -> void:
	var glow_shader: Shader = ResourceLoader.load(WING_GLOW_SHADER_PATH) as Shader if ResourceLoader.exists(WING_GLOW_SHADER_PATH) else null
	var textures: Array[Texture2D] = _load_wing_blade_textures()

	for i: int in range(MAX_BLADES):
		var blade_obj := Node2D.new()
		blade_obj.name = "AstralWingBlade_%02d" % i
		blade_obj.visible = false
		add_child(blade_obj)

		var sp := Sprite2D.new()
		sp.name = "BladeSprite"
		if i < textures.size() and textures[i] != null:
			sp.texture = textures[i]
		if glow_shader != null:
			var mat := ShaderMaterial.new()
			mat.shader = glow_shader
			mat.set_shader_parameter("glow_color", _accent_color)
			mat.set_shader_parameter("glow_intensity", 1.95)
			sp.material = mat
			_blade_glow_mats.append(mat)
		else:
			_blade_glow_mats.append(null)
		blade_obj.add_child(sp)

		_blade_nodes.append(blade_obj)
		_blade_sprites.append(sp)
		var trail_arr: PackedVector2Array = PackedVector2Array()
		trail_arr.resize(TRAIL_POINTS)
		_blade_states.append({
			"stage": BladeStage.INACTIVE,
			"delay": 0.0,
			"elapsed": 0.0,
			"out_dur": 0.24,
			"apex_dur": 0.12,
			"ret_dur": 0.28,
			"p0": Vector2.ZERO,
			"p1": Vector2.ZERO,
			"p2": Vector2.ZERO,
			"ret_ctrl": Vector2.ZERO,
			"fan_offset": Vector2.ZERO,
			"hit_pos": Vector2.ZERO,
			"target": null,
			"consecutive_idx": 0,
			"effective_damage_mult": 1.85,
			"impacted": false,
			"last_pos": Vector2.ZERO,
			"trail": trail_arr,
			"trail_len": 0,
		})


func _load_wing_blade_textures() -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var pieces: Array[String] = []
	var abs_meta: String = ProjectSettings.globalize_path(WINGS_META_PATH)
	if FileAccess.file_exists(abs_meta):
		var raw: String = FileAccess.get_file_as_string(abs_meta)
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary:
			var views: Variant = (parsed as Dictionary).get("views", {})
			if views is Dictionary:
				var front_view: Variant = (views as Dictionary).get("s", (views as Dictionary).values()[0] if not (views as Dictionary).is_empty() else {})
				if front_view is Dictionary:
					for side_key: String in ["left", "right"]:
						var side_arr: Variant = (front_view as Dictionary).get(side_key, [])
						if side_arr is Array:
							for item: Variant in (side_arr as Array):
								if item is Dictionary and (item as Dictionary).has("albedo"):
									pieces.append(str((item as Dictionary)["albedo"]))
	for i: int in range(MAX_BLADES):
		var tex: Texture2D = null
		if i < pieces.size():
			var res_path: String = "%s/%s" % [WINGS_ASSET_DIR, pieces[i]]
			if ResourceLoader.exists(res_path):
				tex = ResourceLoader.load(res_path) as Texture2D
		result.append(tex)
	return result


func set_palette(accent: Color, secondary: Color = Color(0.545, 0.361, 0.965, 1.0)) -> void:
	_accent_color = accent
	_secondary_color = secondary
	for mat: ShaderMaterial in _blade_glow_mats:
		if mat != null:
			mat.set_shader_parameter("glow_color", _accent_color)


func set_time_scale(scale_val: float) -> void:
	_time_scale = clampf(scale_val, 0.05, 2.0)


func is_active() -> bool:
	return _is_active


func get_pool_size() -> int:
	return _blade_nodes.size()


func _pick_priority_target(targets: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_score: float = -1.0
	for t_node: Node2D in targets:
		if not is_instance_valid(t_node):
			continue
		var score: float = 1.0
		var v_boss: Variant = t_node.get("is_boss")
		if v_boss is bool and bool(v_boss):
			score += 100000.0
		var v_sel: Variant = t_node.get("is_selected")
		if v_sel is bool and bool(v_sel):
			score += 25000.0
		var v_max_hp: Variant = t_node.get("max_hp")
		if v_max_hp is float or v_max_hp is int:
			score += float(v_max_hp)
		if score > best_score:
			best_score = score
			best = t_node
	return best


func _assign_targets_smart_single_target(targets: Array[Node2D], count: int, boss_weight: float) -> Array[Node2D]:
	var plan: Array[Node2D] = []
	plan.resize(count)
	if targets.is_empty():
		return plan
	if targets.size() == 1:
		for i: int in range(count):
			plan[i] = targets[0]
		return plan

	var primary: Node2D = _pick_priority_target(targets)
	var others: Array[Node2D] = []
	for t_node: Node2D in targets:
		if t_node != primary and is_instance_valid(t_node):
			others.append(t_node)

	var clamped_w: float = clampf(boss_weight, 0.25, 1.0)
	var primary_slots: int = clampi(int(round(float(count) * clamped_w)), 1, count)
	if others.is_empty():
		primary_slots = count

	for i: int in range(count):
		if i < primary_slots:
			plan[i] = primary
		else:
			plan[i] = others[(i - primary_slots) % others.size()]
	return plan


func launch_barrage(origin_pos: Vector2, targets: Array[Node2D], cfg: PilotUltimateConfig, anchor_node: Node2D = null) -> void:
	_cfg = cfg if cfg != null else PilotUltimateConfig.new()
	_cfg.ensure_defaults()
	_anchor_node = anchor_node
	_origin_fallback = origin_pos
	_is_active = true
	_finisher_emitted = false
	_return_signal_emitted = false
	_slash_lines.clear()
	_bursts.clear()
	_assigned_targets.clear()

	for t_node: Node2D in targets:
		if is_instance_valid(t_node):
			_assigned_targets.append(t_node)

	var count: int = clampi(_cfg.blade_count, 2, MAX_BLADES)
	var half: int = maxi(1, count / 2)
	var target_plan: Array[Node2D] = _assign_targets_smart_single_target(_assigned_targets, count, _cfg.single_target_boss_weight)
	var hit_counter_by_id: Dictionary = {}
	var is_pure_single_target: bool = (_assigned_targets.size() == 1)

	for i: int in range(MAX_BLADES):
		var st: Dictionary = _blade_states[i]
		var b_node: Node2D = _blade_nodes[i]
		if i >= count:
			st["stage"] = BladeStage.INACTIVE
			b_node.visible = false
			continue

		var is_right: bool = (i >= half)
		var fan_idx: int = (i - half) if is_right else i
		var side_sign: float = 1.0 if is_right else -1.0
		var fan_offset: Vector2 = Vector2(side_sign * (38.0 + float(fan_idx) * 14.0), -26.0 + float(fan_idx) * 12.0)
		var start_p: Vector2 = origin_pos + fan_offset

		var tgt_node: Node2D = target_plan[i] if i < target_plan.size() else null
		var tgt_pos: Vector2 = Vector2.ZERO
		var consecutive_idx: int = 0
		if is_instance_valid(tgt_node):
			tgt_pos = tgt_node.global_position
			var tid: int = tgt_node.get_instance_id()
			consecutive_idx = int(hit_counter_by_id.get(tid, 0))
			hit_counter_by_id[tid] = consecutive_idx + 1
		else:
			var radial_ang: float = (float(i) / float(count)) * TAU
			tgt_pos = origin_pos + Vector2(cos(radial_ang), sin(radial_ang)) * 520.0

		var to_tgt: Vector2 = tgt_pos - start_p
		var dist: float = maxf(to_tgt.length(), 1.0)
		var dir_n: Vector2 = to_tgt / dist
		var perp: Vector2 = Vector2(-dir_n.y, dir_n.x)

		# En convergencia 100% single-target, abrir 12 arcos radiales distintos para rodear al jefe
		var mid_p: Vector2 = Vector2.ZERO
		var apex_p: Vector2 = Vector2.ZERO
		var curve_sign: float = 1.0 if (i % 2 == 0) else -1.0
		if is_pure_single_target:
			var converge_ang: float = (float(i) / float(count)) * TAU
			var ring_dir := Vector2(cos(converge_ang), sin(converge_ang))
			mid_p = tgt_pos + ring_dir * maxf(_cfg.blade_arc_curvature_px * 1.45, 165.0)
			apex_p = tgt_pos - ring_dir * 225.0
		else:
			mid_p = (start_p + tgt_pos) * 0.5 + perp * (_cfg.blade_arc_curvature_px * curve_sign)
			apex_p = tgt_pos + dir_n * 210.0

		var eff_mult: float = _cfg.blade_damage_mult * (1.0 + float(consecutive_idx) * _cfg.single_target_consecutive_bonus)

		st["stage"] = BladeStage.OUTBOUND
		st["delay"] = float(i) * _cfg.blade_launch_stagger_sec
		st["elapsed"] = 0.0
		st["out_dur"] = _cfg.blade_flight_sec
		st["apex_dur"] = maxf(0.04, _cfg.blade_apex_hold_sec)
		st["ret_dur"] = maxf(0.10, _cfg.blade_return_sec)
		st["p0"] = start_p
		st["p1"] = mid_p
		st["p2"] = apex_p
		st["ret_ctrl"] = apex_p - perp * (_cfg.blade_arc_curvature_px * 0.85 * curve_sign)
		st["fan_offset"] = fan_offset
		st["hit_pos"] = tgt_pos
		st["target"] = tgt_node
		st["consecutive_idx"] = consecutive_idx
		st["effective_damage_mult"] = eff_mult
		st["impacted"] = false
		st["last_pos"] = start_p
		st["trail_len"] = 0

		b_node.position = start_p
		b_node.scale = Vector2(_cfg.blade_scale, _cfg.blade_scale)
		b_node.visible = false
	queue_redraw()


func clear_all() -> void:
	_is_active = false
	_finisher_emitted = false
	_return_signal_emitted = false
	for i: int in range(MAX_BLADES):
		_blade_states[i]["stage"] = BladeStage.INACTIVE
		_blade_nodes[i].visible = false
	_slash_lines.clear()
	_bursts.clear()
	queue_redraw()


func _get_live_anchor_pos() -> Vector2:
	if is_instance_valid(_anchor_node):
		return _anchor_node.global_position
	return _origin_fallback


func _push_trail(st: Dictionary, pt: Vector2) -> void:
	var tr: PackedVector2Array = st["trail"]
	var t_len: int = int(st["trail_len"])
	if t_len < TRAIL_POINTS:
		tr[t_len] = pt
		st["trail_len"] = t_len + 1
	else:
		for k: int in range(TRAIL_POINTS - 1):
			tr[k] = tr[k + 1]
		tr[TRAIL_POINTS - 1] = pt
	st["trail"] = tr


func _process(delta: float) -> void:
	if not _is_active and _slash_lines.is_empty() and _bursts.is_empty():
		return
	var dt: float = clampf(delta, 0.0, 0.05) * _time_scale
	var any_blade_alive: bool = false
	var any_returning: bool = false
	var live_anchor: Vector2 = _get_live_anchor_pos()

	for i: int in range(MAX_BLADES):
		var st: Dictionary = _blade_states[i]
		var stage: int = int(st["stage"])
		if stage == BladeStage.INACTIVE:
			continue
		any_blade_alive = true

		var delay: float = float(st["delay"])
		if delay > 0.0:
			st["delay"] = delay - dt
			continue

		var b_node: Node2D = _blade_nodes[i]
		var el: float = float(st["elapsed"]) + dt
		st["elapsed"] = el

		if stage == BladeStage.OUTBOUND:
			var dur: float = maxf(0.05, float(st["out_dur"]))
			var t: float = clampf(el / dur, 0.0, 1.0)
			var u: float = 1.0 - t
			var p0: Vector2 = st["p0"]
			var p1: Vector2 = st["p1"]
			var p2: Vector2 = st["p2"]
			var cur_pos: Vector2 = (u * u) * p0 + (2.0 * u * t) * p1 + (t * t) * p2
			var vel_v: Vector2 = cur_pos - (st["last_pos"] as Vector2)
			st["last_pos"] = cur_pos
			_push_trail(st, cur_pos)

			b_node.position = cur_pos
			if vel_v.length_squared() > 0.01:
				b_node.rotation = vel_v.angle() + PI * 0.5
			b_node.visible = true

			if not bool(st["impacted"]) and t >= 0.65:
				st["impacted"] = true
				var tgt_node: Node2D = st["target"] as Node2D
				var hit_p: Vector2 = tgt_node.global_position if is_instance_valid(tgt_node) else (st["hit_pos"] as Vector2)
				var slash_dir: Vector2 = (p2 - p1).normalized() if (p2 - p1).length_squared() > 0.01 else Vector2.RIGHT
				_slash_lines.append({
					"a": hit_p - slash_dir * 350.0,
					"b": hit_p + slash_dir * 350.0,
					"age": 0.0,
					"max_age": _cfg.slash_trail_linger_sec if _cfg != null else 0.40,
				})
				_bursts.append({"pos": hit_p, "age": 0.0, "max_age": 0.28, "is_finisher": false})
				var eff_mult: float = float(st.get("effective_damage_mult", _cfg.blade_damage_mult if _cfg != null else 1.85))
				blade_impacted.emit(tgt_node, hit_p, i, eff_mult)

			if t >= 1.0:
				st["stage"] = BladeStage.APEX_TURN
				st["elapsed"] = 0.0
				_bursts.append({"pos": cur_pos, "age": 0.0, "max_age": 0.16, "is_finisher": false})

		elif stage == BladeStage.APEX_TURN:
			var apex_dur: float = maxf(0.04, float(st["apex_dur"]))
			var t_a: float = clampf(el / apex_dur, 0.0, 1.0)
			# Giro metálico rápido en el ápice antes de regresar a Valentina
			b_node.rotation += dt * 18.0
			var pulse_s: float = (_cfg.blade_scale if _cfg != null else 0.46) * (1.0 + sin(t_a * PI) * 0.25)
			b_node.scale = Vector2(pulse_s, pulse_s)
			if t_a >= 1.0:
				st["stage"] = BladeStage.RETURN_RECALL
				st["elapsed"] = 0.0
				st["p0"] = b_node.position

		elif stage == BladeStage.RETURN_RECALL:
			any_returning = true
			var ret_dur: float = maxf(0.08, float(st["ret_dur"]))
			var t_r: float = clampf(el / ret_dur, 0.0, 1.0)
			var t_eased: float = t_r * t_r # Aceleración magnética al regresar a las alas
			var u_r: float = 1.0 - t_eased
			var r0: Vector2 = st["p0"]
			var r1: Vector2 = st["ret_ctrl"]
			var r2: Vector2 = live_anchor + (st["fan_offset"] as Vector2)
			var cur_r: Vector2 = (u_r * u_r) * r0 + (2.0 * u_r * t_eased) * r1 + (t_eased * t_eased) * r2
			var vel_r: Vector2 = cur_r - (st["last_pos"] as Vector2)
			st["last_pos"] = cur_r
			_push_trail(st, cur_r)

			b_node.position = cur_r
			if vel_r.length_squared() > 0.01:
				b_node.rotation = vel_r.angle() + PI * 0.5
			var s_ret: float = (_cfg.blade_scale if _cfg != null else 0.46) * lerpf(1.0, 0.72, t_r)
			b_node.scale = Vector2(s_ret, s_ret)

			if t_r >= 1.0:
				st["stage"] = BladeStage.INACTIVE
				b_node.visible = false
				_bursts.append({"pos": r2, "age": 0.0, "max_age": 0.14, "is_finisher": false})

	if any_returning and not _return_signal_emitted:
		_return_signal_emitted = true
		blades_returning.emit()

	# Envejecer cortes y estallidos
	var s_idx: int = _slash_lines.size() - 1
	while s_idx >= 0:
		_slash_lines[s_idx]["age"] = float(_slash_lines[s_idx]["age"]) + dt
		if float(_slash_lines[s_idx]["age"]) >= float(_slash_lines[s_idx]["max_age"]):
			_slash_lines.remove_at(s_idx)
		s_idx -= 1

	var b_idx: int = _bursts.size() - 1
	while b_idx >= 0:
		_bursts[b_idx]["age"] = float(_bursts[b_idx]["age"]) + dt
		if float(_bursts[b_idx]["age"]) >= float(_bursts[b_idx]["max_age"]):
			_bursts.remove_at(b_idx)
		b_idx -= 1

	if _is_active and not any_blade_alive:
		if not _finisher_emitted:
			_finisher_emitted = true
			for tgt_node: Node2D in _assigned_targets:
				if is_instance_valid(tgt_node):
					_bursts.append({"pos": tgt_node.global_position, "age": 0.0, "max_age": 0.34, "is_finisher": true})
			finisher_detonated.emit(_assigned_targets)
		if _slash_lines.is_empty() and _bursts.is_empty():
			_is_active = false
			barrage_finished.emit()

	queue_redraw()


func _draw() -> void:
	# 1. Estelas dinámicas de las 12 cuchillas reales (carmesí en ida, amatista-blanco en regreso)
	for i: int in range(MAX_BLADES):
		var st: Dictionary = _blade_states[i]
		var stage: int = int(st["stage"])
		if stage == BladeStage.INACTIVE or float(st["delay"]) > 0.0:
			continue
		var t_len: int = int(st["trail_len"])
		var tr: PackedVector2Array = st["trail"]
		var trail_tint: Color = _secondary_color if stage == BladeStage.RETURN_RECALL else _accent_color
		if t_len >= 2:
			for k: int in range(t_len - 1):
				var frac: float = float(k + 1) / float(t_len)
				draw_line(tr[k], tr[k + 1], Color(trail_tint.r * 1.8, trail_tint.g * 1.8, trail_tint.b * 1.8, 0.85 * frac), 7.5 * frac, true)
				draw_line(tr[k], tr[k + 1], Color(1.95, 1.90, 2.05, 0.95 * frac), 2.5 * frac, true)
		if _blade_sprites[i].texture == null:
			var p_now: Vector2 = _blade_nodes[i].position
			var ang: float = _blade_nodes[i].rotation - PI * 0.5
			var fwd := Vector2(cos(ang), sin(ang))
			var perp := Vector2(-fwd.y, fwd.x)
			var tri := PackedVector2Array([p_now + fwd * 30.0, p_now - fwd * 22.0 + perp * 8.0, p_now - fwd * 22.0 - perp * 8.0])
			draw_colored_polygon(tri, Color(trail_tint.r * 1.8, trail_tint.g * 1.8, trail_tint.b * 1.8, 0.95))

	# 2. Cortes láser cruzados a pantalla entera
	for sl: Dictionary in _slash_lines:
		var a: Vector2 = sl["a"]
		var b: Vector2 = sl["b"]
		var t: float = clampf(float(sl["age"]) / maxf(0.01, float(sl["max_age"])), 0.0, 1.0)
		var fade: float = pow(1.0 - t, 1.4)
		draw_line(a, b, Color(_accent_color.r * 1.85, _accent_color.g * 1.85, _accent_color.b * 1.85, 0.78 * fade), 10.5 * fade, true)
		draw_line(a, b, Color(2.0, 1.95, 2.1, 0.98 * fade), 3.6 * fade, true)

	# 3. Estallidos de fractura obsidiana + chispas de re-acoplamiento
	for br: Dictionary in _bursts:
		var pos: Vector2 = br["pos"]
		var t: float = clampf(float(br["age"]) / maxf(0.01, float(br["max_age"])), 0.0, 1.0)
		var fade: float = pow(1.0 - t, 1.35)
		var is_fin: bool = bool(br["is_finisher"])
		var max_r: float = 115.0 if is_fin else 54.0
		var r: float = lerpf(10.0, max_r, ease(t, 0.3))
		var ring_col: Color = _secondary_color if is_fin else _accent_color
		draw_arc(pos, r, 0.0, TAU, 24, Color(ring_col.r * 1.8, ring_col.g * 1.8, ring_col.b * 1.8, 0.92 * fade), (4.8 if is_fin else 2.6) * fade, true)
		var d_pts := PackedVector2Array([
			pos + Vector2(0.0, -r * 0.72),
			pos + Vector2(r * 0.72, 0.0),
			pos + Vector2(0.0, r * 0.72),
			pos + Vector2(-r * 0.72, 0.0),
			pos + Vector2(0.0, -r * 0.72),
		])
		draw_polyline(d_pts, Color(1.9, 1.82, 2.0, 0.94 * fade), 2.4 * fade, true)
