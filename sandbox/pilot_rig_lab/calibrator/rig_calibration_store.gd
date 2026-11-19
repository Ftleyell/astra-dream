class_name RigCalibrationStore
extends RefCounted
## Almacén de datos, historial Undo/Redo, simetría y persistencia JSON para el Calibrador de Valentina v2.

const ViewRouterScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_view_router.gd")
const DEFAULT_ASSETS_ROOT: String = "res://sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar"
const VIEW_ORDER: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
const PART_KEYS: Array[String] = ["body_core", "arm_r", "arm_l", "leg_r", "leg_l", "pauldron_r", "pauldron_l"]
const MIRROR_VIEW_PAIRS: Dictionary = {
	"se": "sw",
	"sw": "se",
	"e": "w",
	"w": "e",
	"ne": "nw",
	"nw": "ne",
}
const MAX_UNDO_STEPS: int = 80
const DEFAULT_HIP_SHADOW_OFFSET := Vector2(0.8, 3.2)
const DEFAULT_HIP_SHADOW_COLOR := Color(0.82, 0.68, 0.74, 1.0)
const DEFAULT_PART_OUTLINE_COLOR := Color(0.015, 0.015, 0.025, 1.0)
const HEAD_OUTLINE_KEYS: Array[String] = [
	"head_front", "head_front_r", "head_side_r", "head_back_r",
	"head_back", "head_back_l", "head_side_l", "head_front_l",
]

var assets_root: String = DEFAULT_ASSETS_ROOT
var _views_meta: Dictionary = {}
var _baseline_views_meta: Dictionary = {}
var _heads_meta: Dictionary = {}
var _baseline_heads_meta: Dictionary = {}

var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _dirty: bool = false


func load_from_root(root_path: String = DEFAULT_ASSETS_ROOT) -> bool:
	assets_root = root_path
	_views_meta.clear()
	_baseline_views_meta.clear()
	_heads_meta.clear()
	_baseline_heads_meta.clear()
	_undo_stack.clear()
	_redo_stack.clear()
	_dirty = false

	var loaded_any: bool = false
	for v_key: String in VIEW_ORDER:
		var p_path: String = "%s/%s/parts_5/parts_5_meta.json" % [assets_root, v_key]
		var d: Dictionary = _read_json_dict(p_path)
		if not d.is_empty():
			_views_meta[v_key] = d
			_baseline_views_meta[v_key] = d.duplicate(true)
			loaded_any = true

	var h_path: String = "%s/heads/heads_metadata.json" % assets_root
	var hd: Dictionary = _read_json_dict(h_path)
	if not hd.is_empty():
		_heads_meta = hd
		_baseline_heads_meta = hd.duplicate(true)

	return loaded_any


func is_dirty() -> bool:
	return _dirty


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func push_undo_snapshot() -> void:
	var snap: Dictionary = {
		"views": _views_meta.duplicate(true),
		"heads": _heads_meta.duplicate(true),
	}
	_undo_stack.append(snap)
	if _undo_stack.size() > MAX_UNDO_STEPS:
		_undo_stack.pop_front()
	_redo_stack.clear()


func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	var current_snap: Dictionary = {
		"views": _views_meta.duplicate(true),
		"heads": _heads_meta.duplicate(true),
	}
	_redo_stack.append(current_snap)
	var prev: Dictionary = _undo_stack.pop_back() as Dictionary
	_views_meta = (prev["views"] as Dictionary).duplicate(true)
	_heads_meta = (prev["heads"] as Dictionary).duplicate(true)
	_dirty = true
	return true


func redo() -> bool:
	if _redo_stack.is_empty():
		return false
	var current_snap: Dictionary = {
		"views": _views_meta.duplicate(true),
		"heads": _heads_meta.duplicate(true),
	}
	_undo_stack.append(current_snap)
	var nxt: Dictionary = _redo_stack.pop_back() as Dictionary
	_views_meta = (nxt["views"] as Dictionary).duplicate(true)
	_heads_meta = (nxt["heads"] as Dictionary).duplicate(true)
	_dirty = true
	return true


func get_view_meta(view_key: String) -> Dictionary:
	return _views_meta.get(view_key, {}) as Dictionary


func get_baseline_view_meta(view_key: String) -> Dictionary:
	return _baseline_views_meta.get(view_key, {}) as Dictionary


func get_head_entry(head_key: String) -> Dictionary:
	return _heads_meta.get(head_key, {}) as Dictionary


func get_baseline_head_entry(head_key: String) -> Dictionary:
	return _baseline_heads_meta.get(head_key, {}) as Dictionary


func get_rig_origin(view_key: String) -> Vector2:
	var m: Dictionary = get_view_meta(view_key)
	var arr: Array = m.get("rig_origin", [260.0, 286.7]) as Array
	if arr.size() < 2:
		return Vector2(260.0, 286.7)
	return Vector2(float(arr[0]), float(arr[1]))


func get_ordered_part_names(view_key: String) -> Array[String]:
	var m: Dictionary = get_view_meta(view_key)
	var rects: Dictionary = m.get("rects", {}) as Dictionary
	var z_orders: Dictionary = m.get("z_orders", {}) as Dictionary
	var names: Array[String] = []
	for pk: String in PART_KEYS:
		if rects.has(pk):
			names.append(pk)
	names.sort_custom(func(a: String, b: String) -> bool:
		var za: int = int(z_orders.get(a, 0))
		var zb: int = int(z_orders.get(b, 0))
		if za != zb:
			return za > zb
		return PART_KEYS.find(a) > PART_KEYS.find(b)
	)
	return names


func get_part_rect_abs(view_key: String, part_name: String, use_baseline: bool = false) -> Rect2:
	var m: Dictionary = get_baseline_view_meta(view_key) if use_baseline else get_view_meta(view_key)
	var rects: Dictionary = m.get("rects", {}) as Dictionary
	if not rects.has(part_name):
		return Rect2()
	var arr: Array = rects[part_name] as Array
	if arr.size() < 4:
		return Rect2()
	return Rect2(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))


func get_part_rect_rel(view_key: String, part_name: String, use_baseline: bool = false) -> Rect2:
	var r: Rect2 = get_part_rect_abs(view_key, part_name, use_baseline)
	if r.size == Vector2.ZERO:
		return Rect2()
	return Rect2(r.position - get_rig_origin(view_key), r.size)


func set_part_pos_rel(view_key: String, part_name: String, rel_pos: Vector2) -> void:
	var m: Dictionary = get_view_meta(view_key)
	var rects: Dictionary = m.get("rects", {}) as Dictionary
	if not rects.has(part_name):
		return
	var arr: Array = rects[part_name] as Array
	var orig: Vector2 = get_rig_origin(view_key)
	arr[0] = snappedf(orig.x + rel_pos.x, 0.0001)
	arr[1] = snappedf(orig.y + rel_pos.y, 0.0001)
	_dirty = true


func set_part_pos_abs(view_key: String, part_name: String, abs_pos: Vector2) -> void:
	set_part_pos_rel(view_key, part_name, abs_pos - get_rig_origin(view_key))


func get_part_z_order(view_key: String, part_name: String) -> int:
	var m: Dictionary = get_view_meta(view_key)
	var z_orders: Dictionary = m.get("z_orders", {}) as Dictionary
	return int(z_orders.get(part_name, 0))


func set_part_z_order(view_key: String, part_name: String, z_val: int) -> void:
	var m: Dictionary = get_view_meta(view_key)
	var z_orders: Dictionary = m.get("z_orders", {}) as Dictionary
	z_orders[part_name] = z_val
	m["z_orders"] = z_orders
	_dirty = true


func get_neck_anchor_rel(view_key: String, use_baseline: bool = false) -> Vector2:
	var m: Dictionary = get_baseline_view_meta(view_key) if use_baseline else get_view_meta(view_key)
	var na: Array = m.get("neck_anchor", [260.0, 182.5]) as Array
	if na.size() < 2:
		return Vector2.ZERO
	return Vector2(float(na[0]), float(na[1])) - get_rig_origin(view_key)


func set_neck_anchor_rel(view_key: String, rel_pos: Vector2) -> void:
	var m: Dictionary = get_view_meta(view_key)
	if m.is_empty():
		return
	var orig: Vector2 = get_rig_origin(view_key)
	var abs_p: Vector2 = orig + rel_pos
	m["neck_anchor"] = [snappedf(abs_p.x, 0.0001), snappedf(abs_p.y, 0.0001)]
	_set_bone_abs_pos_internal(m, "Neck", abs_p)
	_dirty = true


func get_bone_names(view_key: String) -> Array[String]:
	var m: Dictionary = get_view_meta(view_key)
	var bones_list: Array = m.get("bones", []) as Array
	var out: Array[String] = []
	for entry_v: Variant in bones_list:
		if entry_v is Dictionary:
			out.append(str((entry_v as Dictionary).get("name", "")))
	return out


func get_bone_parent(view_key: String, bone_name: String) -> String:
	var m: Dictionary = get_view_meta(view_key)
	var bones_list: Array = m.get("bones", []) as Array
	for entry_v: Variant in bones_list:
		if entry_v is Dictionary and str((entry_v as Dictionary).get("name", "")) == bone_name:
			return str((entry_v as Dictionary).get("parent", ""))
	return ""


func get_bone_pos_rel(view_key: String, bone_name: String, use_baseline: bool = false) -> Vector2:
	var m: Dictionary = get_baseline_view_meta(view_key) if use_baseline else get_view_meta(view_key)
	var bones_list: Array = m.get("bones", []) as Array
	var orig: Vector2 = get_rig_origin(view_key)
	for entry_v: Variant in bones_list:
		if entry_v is Dictionary and str((entry_v as Dictionary).get("name", "")) == bone_name:
			var arr: Array = (entry_v as Dictionary).get("pos", [orig.x, orig.y]) as Array
			if arr.size() >= 2:
				return Vector2(float(arr[0]), float(arr[1])) - orig
	return Vector2.ZERO


func set_bone_pos_rel(view_key: String, bone_name: String, rel_pos: Vector2, move_children: bool = false) -> void:
	var m: Dictionary = get_view_meta(view_key)
	if m.is_empty():
		return
	var orig: Vector2 = get_rig_origin(view_key)
	var old_rel: Vector2 = get_bone_pos_rel(view_key, bone_name, false)
	var delta: Vector2 = rel_pos - old_rel
	var abs_p: Vector2 = orig + rel_pos
	_set_bone_abs_pos_internal(m, bone_name, abs_p)
	if bone_name == "Neck":
		m["neck_anchor"] = [snappedf(abs_p.x, 0.0001), snappedf(abs_p.y, 0.0001)]
	if move_children and delta.length_squared() > 0.000001:
		var descendants: Array[String] = _collect_bone_descendants(m, bone_name)
		for desc_name: String in descendants:
			var d_old: Vector2 = get_bone_pos_rel(view_key, desc_name, false)
			var d_abs: Vector2 = orig + d_old + delta
			_set_bone_abs_pos_internal(m, desc_name, d_abs)
			if desc_name == "Neck":
				m["neck_anchor"] = [snappedf(d_abs.x, 0.0001), snappedf(d_abs.y, 0.0001)]
	_dirty = true


func get_head_sprite_offset(head_key: String, use_baseline: bool = false) -> Vector2:
	var src: Dictionary = _baseline_heads_meta if use_baseline else _heads_meta
	var entry: Dictionary = src.get(head_key, {}) as Dictionary
	if entry.is_empty():
		return Vector2.ZERO
	var disp_arr: Array = entry.get("disp_size", [84.0, 82.8]) as Array
	var off_arr: Array = entry.get("sprite_offset", [0.0, -22.0]) as Array
	var sx: float = float(off_arr[0]) if off_arr.size() >= 1 else 0.0
	var sy: float = float(off_arr[1]) if off_arr.size() >= 2 else 0.0
	if entry.has("neck_pivot_px") and entry["neck_pivot_px"] is Array and (entry["neck_pivot_px"] as Array).size() >= 2 and disp_arr.size() >= 1:
		sx = float(disp_arr[0]) * 0.5 - float((entry["neck_pivot_px"] as Array)[0])
	return Vector2(sx, sy)


func get_head_disp_size(head_key: String) -> Vector2:
	var entry: Dictionary = get_head_entry(head_key)
	var disp_arr: Array = entry.get("disp_size", [84.0, 82.8]) as Array
	if disp_arr.size() < 2:
		return Vector2(84.0, 82.8)
	return Vector2(float(disp_arr[0]), float(disp_arr[1]))


func get_head_neck_pivot_px(head_key: String) -> Vector2:
	var entry: Dictionary = get_head_entry(head_key)
	var np_arr: Array = entry.get("neck_pivot_px", [42.0, 64.0]) as Array
	if np_arr.size() < 2:
		return Vector2(42.0, 64.0)
	return Vector2(float(np_arr[0]), float(np_arr[1]))


static func get_allowed_heads_for_view(view_key: String) -> Array[String]:
	var raw: Array = ViewRouterScript.ALLOWED_HEADS_BY_BODY_8DIR.get(
		view_key,
		[ViewRouterScript.get_default_head_for_body(view_key)]
	) as Array
	var result: Array[String] = []
	for hk_v: Variant in raw:
		var hk: String = str(hk_v)
		if not hk.is_empty() and not result.has(hk):
			result.append(hk)
	return result


func ensure_head_combo(view_key: String, head_key: String) -> Dictionary:
	if not _heads_meta.has("combo_transforms") or not (_heads_meta["combo_transforms"] is Dictionary):
		_heads_meta["combo_transforms"] = {}
	var combos: Dictionary = _heads_meta["combo_transforms"] as Dictionary
	if not combos.has(view_key) or not (combos[view_key] is Dictionary):
		combos[view_key] = {}
	var v_combos: Dictionary = combos[view_key] as Dictionary
	if not v_combos.has(head_key) or not (v_combos[head_key] is Dictionary):
		var base_off: Vector2 = get_head_sprite_offset(head_key, false)
		v_combos[head_key] = {
			"sprite_offset": [snappedf(base_off.x, 0.0001), snappedf(base_off.y, 0.0001)],
			"scale": 1.0,
		}
	return v_combos[head_key] as Dictionary


func has_head_combo(view_key: String, head_key: String, use_baseline: bool = false) -> bool:
	var src: Dictionary = _baseline_heads_meta if use_baseline else _heads_meta
	var combos: Dictionary = src.get("combo_transforms", {}) as Dictionary
	if not combos.has(view_key):
		return false
	var v_combos: Dictionary = combos[view_key] as Dictionary
	return v_combos.has(head_key)


func get_head_combo_offset(view_key: String, head_key: String, use_baseline: bool = false) -> Vector2:
	if has_head_combo(view_key, head_key, use_baseline):
		var src: Dictionary = _baseline_heads_meta if use_baseline else _heads_meta
		var tf: Dictionary = ((src["combo_transforms"] as Dictionary)[view_key] as Dictionary)[head_key] as Dictionary
		var off_arr: Array = tf.get("sprite_offset", [0.0, 0.0]) as Array
		if off_arr.size() >= 2:
			return Vector2(float(off_arr[0]), float(off_arr[1]))
	return get_head_sprite_offset(head_key, use_baseline)


func get_head_combo_scale(view_key: String, head_key: String, use_baseline: bool = false) -> float:
	if has_head_combo(view_key, head_key, use_baseline):
		var src: Dictionary = _baseline_heads_meta if use_baseline else _heads_meta
		var tf: Dictionary = ((src["combo_transforms"] as Dictionary)[view_key] as Dictionary)[head_key] as Dictionary
		return float(tf.get("scale", 1.0))
	return 1.0


func set_head_combo_offset(view_key: String, head_key: String, sprite_off: Vector2) -> void:
	var tf: Dictionary = ensure_head_combo(view_key, head_key)
	tf["sprite_offset"] = [snappedf(sprite_off.x, 0.0001), snappedf(sprite_off.y, 0.0001)]
	_dirty = true


func set_head_combo_scale(view_key: String, head_key: String, scale_val: float) -> void:
	var tf: Dictionary = ensure_head_combo(view_key, head_key)
	tf["scale"] = snappedf(clampf(scale_val, 0.50, 1.50), 0.001)
	_dirty = true


func get_heads_meta_snapshot() -> Dictionary:
	return _heads_meta.duplicate(true)


func set_head_sprite_offset(head_key: String, sprite_off: Vector2) -> void:
	if not _heads_meta.has(head_key):
		return
	var entry: Dictionary = _heads_meta[head_key] as Dictionary
	var old_off: Vector2 = get_head_sprite_offset(head_key, false)
	var delta_y: float = sprite_off.y - old_off.y
	var disp_sz: Vector2 = get_head_disp_size(head_key)
	entry["sprite_offset"] = [snappedf(sprite_off.x, 0.0001), snappedf(sprite_off.y, 0.0001)]
	var np_arr: Array = entry.get("neck_pivot_px", [disp_sz.x * 0.5, disp_sz.y * 0.78]) as Array
	var new_npx: float = disp_sz.x * 0.5 - sprite_off.x
	var new_npy: float = float(np_arr[1]) - delta_y if np_arr.size() >= 2 else disp_sz.y * 0.78
	entry["neck_pivot_px"] = [snappedf(new_npx, 0.0001), snappedf(new_npy, 0.0001)]
	if head_key == "head_side_r" and _heads_meta.has("head_side"):
		var alias_e: Dictionary = _heads_meta["head_side"] as Dictionary
		alias_e["sprite_offset"] = (entry["sprite_offset"] as Array).duplicate()
		alias_e["neck_pivot_px"] = (entry["neck_pivot_px"] as Array).duplicate()
	_dirty = true


func reset_item_to_baseline(view_key: String, target_kind: String, target_name: String) -> void:
	if target_kind == "part":
		var base_r: Rect2 = get_part_rect_rel(view_key, target_name, true)
		if base_r.size != Vector2.ZERO:
			set_part_pos_rel(view_key, target_name, base_r.position)
		var base_m: Dictionary = get_baseline_view_meta(view_key)
		var base_z: Dictionary = base_m.get("z_orders", {}) as Dictionary
		if base_z.has(target_name):
			set_part_z_order(view_key, target_name, int(base_z[target_name]))
		var base_po: Dictionary = get_part_outline(view_key, target_name, true)
		set_part_outline(
			view_key,
			target_name,
			bool(base_po["enabled"]),
			float(base_po["erode_du"]),
			float(base_po["outline_du"]),
			base_po["color"] as Color,
			bool(base_po["respect_seams"]),
			false
		)
	elif target_kind == "head":
		set_head_combo_offset(view_key, target_name, get_head_combo_offset(view_key, target_name, true))
		set_head_combo_scale(view_key, target_name, get_head_combo_scale(view_key, target_name, true))
		var base_ho: Dictionary = get_head_outline(target_name, true)
		set_head_outline(
			target_name,
			bool(base_ho["enabled"]),
			float(base_ho["erode_du"]),
			float(base_ho["outline_du"]),
			base_ho["color"] as Color,
			bool(base_ho["respect_seams"]),
			false
		)
	elif target_kind == "neck_anchor":
		set_neck_anchor_rel(view_key, get_neck_anchor_rel(view_key, true))
	elif target_kind == "bone":
		set_bone_pos_rel(view_key, target_name, get_bone_pos_rel(view_key, target_name, true), false)
	elif target_kind == "hip_shadow":
		var base_sh: Dictionary = get_hip_cast_shadow(view_key, true)
		set_hip_cast_shadow(view_key, bool(base_sh["enabled"]), base_sh["offset"] as Vector2, base_sh["color"] as Color, false)


func reset_view_to_baseline(view_key: String) -> void:
	if _baseline_views_meta.has(view_key):
		_views_meta[view_key] = (_baseline_views_meta[view_key] as Dictionary).duplicate(true)
		var base_combos: Dictionary = _baseline_heads_meta.get("combo_transforms", {}) as Dictionary
		if base_combos.has(view_key):
			if not _heads_meta.has("combo_transforms") or not (_heads_meta["combo_transforms"] is Dictionary):
				_heads_meta["combo_transforms"] = {}
			(_heads_meta["combo_transforms"] as Dictionary)[view_key] = (base_combos[view_key] as Dictionary).duplicate(true)
		_dirty = true


func get_mirror_partner_view(view_key: String) -> String:
	return str(MIRROR_VIEW_PAIRS.get(view_key, ""))


func mirror_view_to_partner(src_view: String) -> String:
	var dst_view: String = get_mirror_partner_view(src_view)
	if dst_view.is_empty():
		return ""
	var src_m: Dictionary = get_view_meta(src_view)
	var dst_m: Dictionary = get_view_meta(dst_view)
	if src_m.is_empty() or dst_m.is_empty():
		return ""
	var src_orig: Vector2 = get_rig_origin(src_view)
	var dst_orig: Vector2 = get_rig_origin(dst_view)

	# 1. Espejar neck_anchor respecto a rig_origin.x
	var src_na: Vector2 = get_neck_anchor_rel(src_view, false)
	var dst_na_abs: Vector2 = dst_orig + Vector2(-src_na.x, src_na.y)
	dst_m["neck_anchor"] = [snappedf(dst_na_abs.x, 0.0001), snappedf(dst_na_abs.y, 0.0001)]

	# 2. Espejar rects y z_orders intercambiando _r <-> _l
	var src_rects: Dictionary = src_m.get("rects", {}) as Dictionary
	var dst_rects: Dictionary = dst_m.get("rects", {}) as Dictionary
	var src_z: Dictionary = src_m.get("z_orders", {}) as Dictionary
	var dst_z: Dictionary = dst_m.get("z_orders", {}) as Dictionary

	for src_part: String in src_rects.keys():
		var dst_part: String = _swap_rl_part(src_part)
		if not dst_rects.has(dst_part):
			continue
		var sr: Array = src_rects[src_part] as Array
		var dr: Array = dst_rects[dst_part] as Array
		if sr.size() < 4 or dr.size() < 4:
			continue
		var rel_x: float = float(sr[0]) - src_orig.x
		var rel_y: float = float(sr[1]) - src_orig.y
		var dst_w: float = float(dr[2])
		dr[0] = snappedf(dst_orig.x - (rel_x + dst_w), 0.0001)
		dr[1] = snappedf(dst_orig.y + rel_y, 0.0001)
		if src_z.has(src_part):
			dst_z[dst_part] = int(src_z[src_part])

	# 3. Espejar huesos intercambiando _R <-> _L
	var src_bones: Array = src_m.get("bones", []) as Array
	for sb_v: Variant in src_bones:
		if not (sb_v is Dictionary):
			continue
		var sb: Dictionary = sb_v as Dictionary
		var s_name: String = str(sb.get("name", ""))
		var d_name: String = _swap_rl_bone(s_name)
		var s_pos: Array = sb.get("pos", [src_orig.x, src_orig.y]) as Array
		if s_pos.size() < 2:
			continue
		var rel_b := Vector2(float(s_pos[0]) - src_orig.x, float(s_pos[1]) - src_orig.y)
		_set_bone_abs_pos_internal(dst_m, d_name, dst_orig + Vector2(-rel_b.x, rel_b.y))

	# 4. Espejar hip_cast_shadow (invirtiendo offset.x)
	var src_sh: Dictionary = get_hip_cast_shadow(src_view, false)
	var sh_off: Vector2 = src_sh["offset"] as Vector2
	set_hip_cast_shadow(dst_view, bool(src_sh["enabled"]), Vector2(-sh_off.x, sh_off.y), src_sh["color"] as Color, false)

	# 5. Espejar stocking_pinch (intercambiando R<->L en V y tilt, e invirtiendo signo de tilt)
	var src_sp: Dictionary = get_stocking_pinch(src_view, false)
	set_stocking_pinch(
		dst_view,
		bool(src_sp["enabled"]),
		float(src_sp["v_l"]),
		float(src_sp["v_r"]),
		-float(src_sp["tilt_l"]),
		-float(src_sp["tilt_r"]),
		float(src_sp["strength"]),
		float(src_sp["width"]),
		float(src_sp["shadow"]),
		false
	)

	# 6. Espejar combo_transforms de cabeza (intercambiando _r <-> _l e invirtiendo offset.x)
	var combos: Dictionary = _heads_meta.get("combo_transforms", {}) as Dictionary
	if combos.has(src_view):
		var src_c: Dictionary = combos[src_view] as Dictionary
		var dst_allowed: Array[String] = get_allowed_heads_for_view(dst_view)
		for src_hk: String in src_c.keys():
			var dst_hk: String = _swap_rl_part(src_hk)
			if not dst_allowed.has(dst_hk):
				continue
			var stf: Dictionary = src_c[src_hk] as Dictionary
			var dtf: Dictionary = ensure_head_combo(dst_view, dst_hk)
			var soff: Array = stf.get("sprite_offset", [0.0, 0.0]) as Array
			if soff.size() >= 2:
				dtf["sprite_offset"] = [snappedf(-float(soff[0]), 0.0001), snappedf(float(soff[1]), 0.0001)]
			dtf["scale"] = snappedf(float(stf.get("scale", 1.0)), 0.001)

	# 7. Espejar part_outlines por pieza (intercambiando _r <-> _l)
	for src_part_o: String in PART_KEYS:
		var dst_part_o: String = _swap_rl_part(src_part_o)
		var spo: Dictionary = get_part_outline(src_view, src_part_o, false)
		if bool(spo["enabled"]) or ((dst_m.get("part_outlines", {}) as Dictionary).has(dst_part_o)):
			set_part_outline(
				dst_view,
				dst_part_o,
				bool(spo["enabled"]),
				float(spo["erode_du"]),
				float(spo["outline_du"]),
				spo["color"] as Color,
				bool(spo["respect_seams"]),
				false
			)

	_dirty = true
	return dst_view


static func parse_hip_cast_shadow_from_meta(meta: Dictionary, view_key: String) -> Dictionary:
	var def_x: float = -DEFAULT_HIP_SHADOW_OFFSET.x if view_key in ["sw", "w", "nw"] else DEFAULT_HIP_SHADOW_OFFSET.x
	var def_off := Vector2(def_x, DEFAULT_HIP_SHADOW_OFFSET.y)
	var raw: Variant = meta.get("hip_cast_shadow", null)
	if not (raw is Dictionary):
		return {"enabled": true, "offset": def_off, "color": DEFAULT_HIP_SHADOW_COLOR}
	var d: Dictionary = raw as Dictionary
	var off_arr: Array = d.get("offset", [def_off.x, def_off.y]) as Array
	var col_arr: Array = d.get("color", [DEFAULT_HIP_SHADOW_COLOR.r, DEFAULT_HIP_SHADOW_COLOR.g, DEFAULT_HIP_SHADOW_COLOR.b]) as Array
	var off_v := Vector2(float(off_arr[0]), float(off_arr[1])) if off_arr.size() >= 2 else def_off
	var col_v := Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]), 1.0) if col_arr.size() >= 3 else DEFAULT_HIP_SHADOW_COLOR
	return {
		"enabled": bool(d.get("enabled", true)),
		"offset": off_v,
		"color": col_v,
	}


func get_hip_cast_shadow(view_key: String, from_baseline: bool = false) -> Dictionary:
	var src: Dictionary = _baseline_views_meta if from_baseline else _views_meta
	var m: Dictionary = src.get(view_key, {}) as Dictionary
	return parse_hip_cast_shadow_from_meta(m, view_key)


func set_hip_cast_shadow(view_key: String, enabled: bool, offset: Vector2, color: Color, record_undo: bool = true) -> void:
	var m: Dictionary = get_view_meta(view_key)
	if m.is_empty():
		return
	if record_undo:
		push_undo_snapshot()
	m["hip_cast_shadow"] = {
		"enabled": enabled,
		"offset": [snappedf(offset.x, 0.01), snappedf(offset.y, 0.01)],
		"color": [snappedf(color.r, 0.001), snappedf(color.g, 0.001), snappedf(color.b, 0.001)],
	}
	_dirty = true


static func parse_stocking_pinch_from_meta(meta: Dictionary) -> Dictionary:
	var raw: Variant = meta.get("stocking_pinch", null)
	if not (raw is Dictionary):
		return {"enabled": true, "v": 0.25, "v_r": 0.25, "v_l": 0.25, "tilt": 0.0, "tilt_r": 0.0, "tilt_l": 0.0, "strength": 0.045, "width": 0.032, "shadow": 0.20}
	var d: Dictionary = raw as Dictionary
	var legacy_v: float = float(d.get("v", 0.25))
	var vr: float = float(d.get("v_r", legacy_v))
	var vl: float = float(d.get("v_l", legacy_v))
	var legacy_tilt: float = float(d.get("tilt", 0.0))
	var tr: float = float(d.get("tilt_r", legacy_tilt))
	var tl: float = float(d.get("tilt_l", legacy_tilt))
	return {
		"enabled": bool(d.get("enabled", true)),
		"v": vr,
		"v_r": vr,
		"v_l": vl,
		"tilt": tr,
		"tilt_r": tr,
		"tilt_l": tl,
		"strength": float(d.get("strength", 0.045)),
		"width": float(d.get("width", 0.032)),
		"shadow": float(d.get("shadow", 0.20)),
	}


static func compute_pinch_center_u(tex: Texture2D, v_norm: float) -> float:
	if tex == null:
		return 0.5
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return 0.5
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w <= 0 or h <= 0:
		return 0.5
	var y: int = clampi(int(round(v_norm * float(h))), 0, h - 1)
	var x_min: int = w
	var x_max: int = -1
	for x: int in range(w):
		if img.get_pixel(x, y).a > 0.5:
			if x < x_min:
				x_min = x
			if x > x_max:
				x_max = x
	if x_max < x_min:
		return 0.5
	return (float(x_min) + float(x_max)) * 0.5 / float(w)


func get_stocking_pinch(view_key: String, from_baseline: bool = false) -> Dictionary:
	var src: Dictionary = _baseline_views_meta if from_baseline else _views_meta
	return parse_stocking_pinch_from_meta(src.get(view_key, {}) as Dictionary)


func set_stocking_pinch(
	view_key: String,
	enabled: bool,
	v_r: float,
	v_l: float,
	tilt_r: float,
	tilt_l: float,
	strength: float,
	width: float,
	shadow: float,
	record_undo: bool = true
) -> void:
	var m: Dictionary = get_view_meta(view_key)
	if m.is_empty():
		return
	if record_undo:
		push_undo_snapshot()
	m["stocking_pinch"] = {
		"enabled": enabled,
		"v": snappedf(v_r, 0.001),
		"v_r": snappedf(v_r, 0.001),
		"v_l": snappedf(v_l, 0.001),
		"tilt": snappedf(tilt_r, 0.001),
		"tilt_r": snappedf(tilt_r, 0.001),
		"tilt_l": snappedf(tilt_l, 0.001),
		"strength": snappedf(strength, 0.001),
		"width": snappedf(width, 0.001),
		"shadow": snappedf(shadow, 0.01),
	}
	_dirty = true


static func parse_part_outline_from_meta(meta: Dictionary, item_key: String) -> Dictionary:
	var outlines: Variant = meta.get("part_outlines", null)
	if not (outlines is Dictionary):
		return {
			"enabled": false,
			"erode_du": 0.0,
			"outline_du": 0.0,
			"color": DEFAULT_PART_OUTLINE_COLOR,
			"respect_seams": false,
		}
	var raw: Variant = (outlines as Dictionary).get(item_key, null)
	if not (raw is Dictionary):
		return {
			"enabled": false,
			"erode_du": 0.0,
			"outline_du": 0.0,
			"color": DEFAULT_PART_OUTLINE_COLOR,
			"respect_seams": false,
		}
	var d: Dictionary = raw as Dictionary
	var col_arr: Array = d.get("color", [DEFAULT_PART_OUTLINE_COLOR.r, DEFAULT_PART_OUTLINE_COLOR.g, DEFAULT_PART_OUTLINE_COLOR.b]) as Array
	var col_v := Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]), 1.0) if col_arr.size() >= 3 else DEFAULT_PART_OUTLINE_COLOR
	return {
		"enabled": bool(d.get("enabled", false)),
		"erode_du": clampf(float(d.get("erode_du", 0.0)), 0.0, 8.0),
		"outline_du": clampf(float(d.get("outline_du", 0.0)), 0.0, 8.0),
		"color": col_v,
		"respect_seams": bool(d.get("respect_seams", false)),
	}


static func _encode_part_outline_dict(enabled: bool, erode_du: float, outline_du: float, color: Color, respect_seams: bool) -> Dictionary:
	return {
		"enabled": enabled,
		"erode_du": snappedf(clampf(erode_du, 0.0, 8.0), 0.01),
		"outline_du": snappedf(clampf(outline_du, 0.0, 8.0), 0.01),
		"color": [snappedf(color.r, 0.001), snappedf(color.g, 0.001), snappedf(color.b, 0.001)],
		"respect_seams": respect_seams,
	}


func get_part_outline(view_key: String, part_name: String, from_baseline: bool = false) -> Dictionary:
	var src: Dictionary = _baseline_views_meta if from_baseline else _views_meta
	return parse_part_outline_from_meta(src.get(view_key, {}) as Dictionary, part_name)


func set_part_outline(
	view_key: String,
	part_name: String,
	enabled: bool,
	erode_du: float,
	outline_du: float,
	color: Color,
	respect_seams: bool,
	record_undo: bool = true
) -> void:
	var m: Dictionary = get_view_meta(view_key)
	if m.is_empty():
		return
	if record_undo:
		push_undo_snapshot()
	if not m.has("part_outlines") or not (m["part_outlines"] is Dictionary):
		m["part_outlines"] = {}
	(m["part_outlines"] as Dictionary)[part_name] = _encode_part_outline_dict(enabled, erode_du, outline_du, color, respect_seams)
	_dirty = true


func get_head_outline(head_key: String, from_baseline: bool = false) -> Dictionary:
	var src: Dictionary = _baseline_heads_meta if from_baseline else _heads_meta
	return parse_part_outline_from_meta(src, head_key)


func set_head_outline(
	head_key: String,
	enabled: bool,
	erode_du: float,
	outline_du: float,
	color: Color,
	respect_seams: bool,
	record_undo: bool = true
) -> void:
	if _heads_meta.is_empty():
		return
	if record_undo:
		push_undo_snapshot()
	if not _heads_meta.has("part_outlines") or not (_heads_meta["part_outlines"] is Dictionary):
		_heads_meta["part_outlines"] = {}
	var encoded: Dictionary = _encode_part_outline_dict(enabled, erode_du, outline_du, color, respect_seams)
	(_heads_meta["part_outlines"] as Dictionary)[head_key] = encoded
	if head_key == "head_side_r":
		(_heads_meta["part_outlines"] as Dictionary)["head_side"] = encoded.duplicate(true)
	_dirty = true


func copy_part_outline_to_view(view_key: String, src_part_name: String) -> void:
	var src_o: Dictionary = get_part_outline(view_key, src_part_name, false)
	push_undo_snapshot()
	for pk: String in PART_KEYS:
		set_part_outline(
			view_key,
			pk,
			bool(src_o["enabled"]),
			float(src_o["erode_du"]),
			float(src_o["outline_du"]),
			src_o["color"] as Color,
			bool(src_o["respect_seams"]),
			false
		)


func copy_part_outline_to_all_views(src_view_key: String, part_name: String) -> void:
	var src_o: Dictionary = get_part_outline(src_view_key, part_name, false)
	push_undo_snapshot()
	for vk: String in VIEW_ORDER:
		set_part_outline(
			vk,
			part_name,
			bool(src_o["enabled"]),
			float(src_o["erode_du"]),
			float(src_o["outline_du"]),
			src_o["color"] as Color,
			bool(src_o["respect_seams"]),
			false
		)


func copy_head_outline_to_all_heads(src_head_key: String) -> void:
	var src_o: Dictionary = get_head_outline(src_head_key, false)
	push_undo_snapshot()
	for hk: String in HEAD_OUTLINE_KEYS:
		set_head_outline(
			hk,
			bool(src_o["enabled"]),
			float(src_o["erode_du"]),
			float(src_o["outline_du"]),
			src_o["color"] as Color,
			bool(src_o["respect_seams"]),
			false
		)


func symmetrize_lr_in_view(view_key: String, copy_from_side: String = "r") -> bool:
	if view_key != "s" and view_key != "n":
		return false
	var m: Dictionary = get_view_meta(view_key)
	if m.is_empty():
		return false
	var orig: Vector2 = get_rig_origin(view_key)
	var rects: Dictionary = m.get("rects", {}) as Dictionary
	var src_suf: String = "_r" if copy_from_side == "r" else "_l"
	var dst_suf: String = "_l" if copy_from_side == "r" else "_r"

	for base_k: String in ["arm", "leg", "pauldron"]:
		var sp: String = base_k + src_suf
		var dp: String = base_k + dst_suf
		if not rects.has(sp) or not rects.has(dp):
			continue
		var sr: Array = rects[sp] as Array
		var dr: Array = rects[dp] as Array
		var rel_x: float = float(sr[0]) - orig.x
		var rel_y: float = float(sr[1]) - orig.y
		var dst_w: float = float(dr[2])
		dr[0] = snappedf(orig.x - (rel_x + dst_w), 0.0001)
		dr[1] = snappedf(orig.y + rel_y, 0.0001)

	var bone_src_suf: String = "_R" if copy_from_side == "r" else "_L"
	var bone_dst_suf: String = "_L" if copy_from_side == "r" else "_R"
	for b_base: String in ["Shoulder", "Elbow", "Wrist", "Thigh", "Knee", "Ankle", "Pauldron"]:
		var sb_name: String = b_base + bone_src_suf
		var db_name: String = b_base + bone_dst_suf
		var rel_b: Vector2 = get_bone_pos_rel(view_key, sb_name, false)
		_set_bone_abs_pos_internal(m, db_name, orig + Vector2(-rel_b.x, rel_b.y))

	var combos: Dictionary = _heads_meta.get("combo_transforms", {}) as Dictionary
	if combos.has(view_key):
		var v_combos: Dictionary = combos[view_key] as Dictionary
		var h_base: String = "head_front" if view_key == "s" else "head_back"
		var h_src: String = h_base + src_suf
		var h_dst: String = h_base + dst_suf
		if v_combos.has(h_src) and v_combos.has(h_dst):
			var stf: Dictionary = v_combos[h_src] as Dictionary
			var dtf: Dictionary = v_combos[h_dst] as Dictionary
			var soff: Array = stf.get("sprite_offset", [0.0, 0.0]) as Array
			if soff.size() >= 2:
				dtf["sprite_offset"] = [snappedf(-float(soff[0]), 0.0001), snappedf(float(soff[1]), 0.0001)]
			dtf["scale"] = snappedf(float(stf.get("scale", 1.0)), 0.001)

	for base_ko: String in ["arm", "leg", "pauldron"]:
		var sp_o: String = base_ko + src_suf
		var dp_o: String = base_ko + dst_suf
		var src_po: Dictionary = get_part_outline(view_key, sp_o, false)
		if bool(src_po["enabled"]) or ((m.get("part_outlines", {}) as Dictionary).has(dp_o)):
			set_part_outline(
				view_key,
				dp_o,
				bool(src_po["enabled"]),
				float(src_po["erode_du"]),
				float(src_po["outline_du"]),
				src_po["color"] as Color,
				bool(src_po["respect_seams"]),
				false
			)

	_dirty = true
	return true


func save_all() -> Dictionary:
	var saved_views: Array[String] = []
	var errors: Array[String] = []

	for v_key: String in VIEW_ORDER:
		if not _views_meta.has(v_key):
			continue
		var p_path: String = "%s/%s/parts_5/parts_5_meta.json" % [assets_root, v_key]
		if not _write_json_with_backup(p_path, _views_meta[v_key] as Dictionary):
			errors.append(p_path)
		else:
			saved_views.append(v_key)
			_baseline_views_meta[v_key] = (_views_meta[v_key] as Dictionary).duplicate(true)

	var h_path: String = "%s/heads/heads_metadata.json" % assets_root
	if not _heads_meta.is_empty():
		if not _write_json_with_backup(h_path, _heads_meta):
			errors.append(h_path)
		else:
			_baseline_heads_meta = _heads_meta.duplicate(true)

	var overrides_path: String = "%s/manual_calibration_overrides.json" % assets_root
	var overrides_payload: Dictionary = _build_overrides_payload()
	if not _write_json_raw(overrides_path, overrides_payload):
		errors.append(overrides_path)

	if errors.is_empty():
		_dirty = false

	return {
		"ok": errors.is_empty(),
		"saved_views": saved_views,
		"overrides_path": overrides_path,
		"errors": errors,
	}


func _build_overrides_payload() -> Dictionary:
	var views_out: Dictionary = {}
	for v_key: String in VIEW_ORDER:
		if not _views_meta.has(v_key):
			continue
		var m: Dictionary = _views_meta[v_key] as Dictionary
		views_out[v_key] = {
			"rig_origin": (m.get("rig_origin", []) as Array).duplicate(true),
			"neck_anchor": (m.get("neck_anchor", []) as Array).duplicate(true),
			"z_orders": (m.get("z_orders", {}) as Dictionary).duplicate(true),
			"rects": (m.get("rects", {}) as Dictionary).duplicate(true),
			"bones": (m.get("bones", []) as Array).duplicate(true),
			"part_outlines": (m.get("part_outlines", {}) as Dictionary).duplicate(true),
		}
	return {
		"format_version": 1,
		"views": views_out,
		"heads": _heads_meta.duplicate(true),
	}


func _set_bone_abs_pos_internal(meta: Dictionary, bone_name: String, abs_pos: Vector2) -> void:
	var bones_list: Array = meta.get("bones", []) as Array
	for entry_v: Variant in bones_list:
		if entry_v is Dictionary and str((entry_v as Dictionary).get("name", "")) == bone_name:
			(entry_v as Dictionary)["pos"] = [snappedf(abs_pos.x, 0.0001), snappedf(abs_pos.y, 0.0001)]
			return


func _collect_bone_descendants(meta: Dictionary, root_bone: String) -> Array[String]:
	var bones_list: Array = meta.get("bones", []) as Array
	var result: Array[String] = []
	var queue: Array[String] = [root_bone]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for entry_v: Variant in bones_list:
			if not (entry_v is Dictionary):
				continue
			var ed: Dictionary = entry_v as Dictionary
			var b_n: String = str(ed.get("name", ""))
			var p_n: String = str(ed.get("parent", ""))
			if p_n == cur and not result.has(b_n):
				result.append(b_n)
				queue.append(b_n)
	return result


static func _swap_rl_part(part_name: String) -> String:
	if part_name.ends_with("_r"):
		return part_name.substr(0, part_name.length() - 2) + "_l"
	if part_name.ends_with("_l"):
		return part_name.substr(0, part_name.length() - 2) + "_r"
	return part_name


static func _swap_rl_bone(bone_name: String) -> String:
	if bone_name.ends_with("_R"):
		return bone_name.substr(0, bone_name.length() - 2) + "_L"
	if bone_name.ends_with("_L"):
		return bone_name.substr(0, bone_name.length() - 2) + "_R"
	return bone_name


static func _read_json_dict(res_path: String) -> Dictionary:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		return {}
	var txt: String = FileAccess.get_file_as_string(abs_path)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func _write_json_with_backup(res_path: String, data: Dictionary) -> bool:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	var bak_path: String = abs_path + ".bak"
	if FileAccess.file_exists(abs_path) and not FileAccess.file_exists(bak_path):
		var orig_txt: String = FileAccess.get_file_as_string(abs_path)
		var bf := FileAccess.open(bak_path, FileAccess.WRITE)
		if bf != null:
			bf.store_string(orig_txt)
			bf.close()
	return _write_json_raw(res_path, data)


static func _write_json_raw(res_path: String, data: Dictionary) -> bool:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "  ") + "\n")
	f.close()
	return true
