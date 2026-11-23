class_name PlanarRigCalibrationHelpers
extends RefCounted
## Pure static calibration parsing helpers shared between production rig builders and sandbox calibrator.

const DEFAULT_HIP_SHADOW_OFFSET := Vector2(0.8, 3.2)
const DEFAULT_HIP_SHADOW_COLOR := Color(0.82, 0.68, 0.74, 1.0)


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
	if img.is_compressed():
		img.decompress()
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
