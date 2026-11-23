class_name ValentinaFaceRig
extends Node2D
## Rig facial independiente y modular para calibrar y validar vida facial,
## soldadura cervical, parallax 2.5D Live2D, cabello en 3 zonas y monóculo táctico.

const MeshBuilderScript = preload("res://scenes/pilots/rig/planar_rig_mesh_builder.gd")
const MaterialCtrlScript = preload("res://scenes/pilots/rig/planar_rig_material_controller.gd")
const PilotLabSelectorScript = preload("res://sandbox/pilot_rig_lab/shared/pilot_lab_selector.gd")

const SHADER_PATH: String = "res://scenes/pilots/shaders/pilot_rig_stylizer.gdshader"
const PASS2_SHADER_PATH: String = "res://scenes/pilots/shaders/pilot_rig_pass2.gdshader"
const PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const STYLE_SHARP_PATH: String = "res://data/pilots/styles/02_valentina_razor_sharp.tres"

const CANONICAL_HEADS: Array[String] = [
	"head_front",
	"head_front_r",
	"head_front_l",
	"head_side_r",
	"head_side_l",
	"head_back_r",
	"head_back_l",
	"head_back",
]
const EYE_LIVE2D_HEADS: Array[String] = [
	"head_front",
	"head_front_r",
	"head_front_l",
	"head_side_r",
]

const HEAD_TO_VIEW: Dictionary = {
	"head_front": "s",
	"head_front_r": "se",
	"head_front_l": "sw",
	"head_side_r": "e",
	"head_side_l": "w",
	"head_back_r": "ne",
	"head_back_l": "nw",
	"head_back": "n",
}

var _materials: MaterialCtrlScript = null
var _conic_lut: GradientTexture2D = null
var _unified_group: CanvasGroup = null
var _head_under_anchor: Node2D = null
var _torso_mount: Node2D = null
var _head_over_anchor: Node2D = null

var _head_under_data: Dictionary = {}
var _head_over_data: Dictionary = {}
var _head_face_live_tex: Dictionary = {}
var _head_eye_iris_tex: Dictionary = {}
var _head_eye_closed_tex: Dictionary = {}
var _eye_live2d_meta: Dictionary = {}
var _head_neck_pivot_uv: Dictionary = {}
var _head_tex_per_du: Dictionary = {}
var _torso_sprites: Dictionary = {}
var _torso_materials: Array[ShaderMaterial] = []

var _active_head_key: String = "head_front"
var _show_torso_ref: bool = true
var _profile: PilotRigProfile = null
var _style_profile: RigStyleProfile = null
@export var pilot_profile_override: String = ""


func _ready() -> void:
	if _unified_group == null:
		build_face_rig()


func build_face_rig(pilot_root: String = "") -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	_torso_sprites.clear()
	_torso_materials.clear()
	_head_face_live_tex.clear()
	_head_eye_iris_tex.clear()
	_head_eye_closed_tex.clear()
	_eye_live2d_meta.clear()
	_head_neck_pivot_uv.clear()
	_head_tex_per_du.clear()

	_materials = MaterialCtrlScript.new()
	var active_profile_path: String = PilotLabSelectorScript.resolve_profile_path(pilot_profile_override, PROFILE_PATH)
	if ResourceLoader.exists(active_profile_path):
		_profile = ResourceLoader.load(active_profile_path) as PilotRigProfile
	if pilot_root.is_empty():
		pilot_root = _profile.assets_root if (_profile != null and not _profile.assets_root.is_empty()) else MeshBuilderScript.ASSETS_ROOT
	if ResourceLoader.exists(STYLE_SHARP_PATH):
		_style_profile = ResourceLoader.load(STYLE_SHARP_PATH) as RigStyleProfile
	if _profile != null:
		_materials.current_accent_color = _profile.default_accent_color

	_conic_lut = MeshBuilderScript.create_conic_rim_lut()
	var shader_res: Shader = ResourceLoader.load(SHADER_PATH) as Shader
	var pass2_shader_res: Shader = ResourceLoader.load(PASS2_SHADER_PATH) as Shader

	_unified_group = CanvasGroup.new()
	_unified_group.name = "UnifiedCharacterGroup"
	_unified_group.use_mipmaps = true
	_unified_group.fit_margin = 64.0
	_unified_group.clear_margin = 64.0
	_unified_group.z_index = 0
	if pass2_shader_res != null:
		var pass2_mat := ShaderMaterial.new()
		pass2_mat.shader = pass2_shader_res
		_unified_group.material = pass2_mat
		_materials.set_pass2_material(pass2_mat)
	add_child(_unified_group)

	_head_under_anchor = Node2D.new()
	_head_under_anchor.name = "HeadUnderMount"
	_head_under_anchor.z_index = 0
	_unified_group.add_child(_head_under_anchor)
	_head_under_data = MeshBuilderScript.build_decoupled_heads(_head_under_anchor, shader_res, _conic_lut, pilot_root, 1)
	_materials.add_materials(_head_under_data.get("materials", []) as Array)

	_torso_mount = Node2D.new()
	_torso_mount.name = "TorsoRefMount"
	_torso_mount.z_index = 0
	_unified_group.add_child(_torso_mount)
	_build_reference_torsos(pilot_root, shader_res)

	_head_over_anchor = Node2D.new()
	_head_over_anchor.name = "HeadOverMount"
	_head_over_anchor.z_index = 0
	_unified_group.add_child(_head_over_anchor)
	_head_over_data = MeshBuilderScript.build_decoupled_heads(_head_over_anchor, shader_res, _conic_lut, pilot_root, 2)
	_materials.add_materials(_head_over_data.get("materials", []) as Array)

	_bind_face_live_textures(pilot_root)
	_apply_default_style_and_skin()
	set_active_head(_active_head_key)
	set_show_torso_ref(_show_torso_ref)
	sync_rig_matrices()


func _build_reference_torsos(pilot_root: String, shader_res: Shader) -> void:
	for h_key: String in CANONICAL_HEADS:
		var v_key: String = str(HEAD_TO_VIEW.get(h_key, "s"))
		var parts5_dir: String = "%s/%s/parts_5" % [pilot_root, v_key]
		var meta: Dictionary = MeshBuilderScript.load_json_dict("%s/parts_5_meta.json" % parts5_dir)
		if meta.is_empty():
			continue
		var rects: Dictionary = meta.get("rects", {}) as Dictionary
		if not rects.has("body_core"):
			continue
		var col_tex: Texture2D = MeshBuilderScript.load_texture_res("%s/body_core.png" % parts5_dir, true, true)
		if col_tex == null:
			continue

		var id_tex: Texture2D = MeshBuilderScript.load_texture_res("%s/body_core_id_mask.png" % parts5_dir, false, false)
		var nd_tex: Texture2D = MeshBuilderScript.load_texture_res("%s/body_core_normal_depth.png" % parts5_dir, false, true)
		var ilm_tex: Texture2D = MeshBuilderScript.load_texture_res("%s/body_core_ilm_mask.png" % parts5_dir, false, true)
		var ink_sdf_tex: Texture2D = MeshBuilderScript.load_texture_res("%s/body_core_ink_sdf.png" % parts5_dir, false, false)
		var pauldron_tex: Texture2D = MeshBuilderScript.load_texture_res("%s/body_core_pauldron_mask.png" % parts5_dir, false, false)

		var ro_arr: Array = meta.get("rig_origin", [260.0, 286.7]) as Array
		var na_arr: Array = meta.get("neck_anchor", [259.8, 182.5]) as Array
		var rig_origin := Vector2(float(ro_arr[0]), float(ro_arr[1]))
		var neck_anchor := Vector2(float(na_arr[0]), float(na_arr[1]))
		var r_arr: Array = rects["body_core"] as Array
		var bx: float = float(r_arr[0])
		var by: float = float(r_arr[1])
		var bw: float = float(r_arr[2])
		var bh: float = float(r_arr[3])

		var spr := Sprite2D.new()
		spr.name = "Torso_%s" % v_key
		spr.z_index = 0
		spr.texture = col_tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		spr.centered = true
		var tex_sz: Vector2 = col_tex.get_size()
		spr.scale = Vector2(bw / maxf(tex_sz.x, 1.0), bh / maxf(tex_sz.y, 1.0))
		spr.position = Vector2(bx + bw * 0.5 - neck_anchor.x, by + bh * 0.5 - neck_anchor.y)
		spr.visible = (h_key == _active_head_key)

		var mat := ShaderMaterial.new()
		mat.shader = shader_res
		if id_tex != null:
			mat.set_shader_parameter("id_mask_tex", id_tex)
		if nd_tex != null:
			mat.set_shader_parameter("normal_depth_tex", nd_tex)
		if ilm_tex != null:
			mat.set_shader_parameter("ilm_mask_tex", ilm_tex)
		mat.set_shader_parameter("has_ilm_mask", ilm_tex != null)
		if ink_sdf_tex != null:
			mat.set_shader_parameter("ink_sdf_tex", ink_sdf_tex)
		mat.set_shader_parameter("has_ink_sdf", ink_sdf_tex != null)
		if pauldron_tex != null:
			mat.set_shader_parameter("pauldron_mask_tex", pauldron_tex)
			mat.set_shader_parameter("has_pauldron_mask", true)
		if _conic_lut != null:
			mat.set_shader_parameter("conic_rim_lut", _conic_lut)
		mat.set_shader_parameter("use_normal_depth", nd_tex != null)
		mat.set_shader_parameter("is_head_part", false)
		mat.set_shader_parameter("suppress_alpha_rim", 1.0)
		mat.set_shader_parameter("weld_bottom_seam", true)
		mat.set_shader_parameter("neck_seam_u", clampf((neck_anchor.x - bx) / maxf(bw, 1.0), 0.05, 0.95))
		mat.set_shader_parameter("neck_seam_half_w", clampf(22.0 / maxf(bw, 1.0), 0.14, 0.28))
		mat.set_shader_parameter("neck_seam_max_v", maxf(0.085, clampf((neck_anchor.y - by) / maxf(bh, 1.0), 0.0, 0.22) + 0.04))
		var part_orig := Vector2(bx, by) - rig_origin
		mat.set_shader_parameter("part_rig_rect", Vector4(part_orig.x / 490.0, part_orig.y / 490.0, bw / 490.0, bh / 490.0))
		MeshBuilderScript._apply_part_edge_outline_from_meta(mat, meta, "body_core")
		spr.material = mat

		_torso_mount.add_child(spr)
		_torso_sprites[v_key] = spr
		_torso_materials.append(mat)
		_materials.materials.append(mat)


func _bind_face_live_textures(pilot_root: String) -> void:
	_eye_live2d_meta = MeshBuilderScript.load_json_dict("%s/heads/eye_live2d_meta.json" % pilot_root)
	for h_dict: Dictionary in [_head_under_data, _head_over_data]:
		var sprites: Dictionary = h_dict.get("sprites", {}) as Dictionary
		var meta: Dictionary = h_dict.get("meta", {}) as Dictionary
		for h_key: String in sprites.keys():
			var spr: Sprite2D = sprites[h_key] as Sprite2D
			if spr == null or not (spr.material is ShaderMaterial):
				continue
			var mat: ShaderMaterial = spr.material as ShaderMaterial
			var flm_tex: Texture2D = _head_face_live_tex.get(h_key, null) as Texture2D
			if flm_tex == null:
				flm_tex = MeshBuilderScript.load_texture_res("%s/heads/%s_face_live_mask.png" % [pilot_root, h_key], false, false)
				if flm_tex != null:
					_head_face_live_tex[h_key] = flm_tex
			if flm_tex != null:
				mat.set_shader_parameter("face_live_mask_tex", flm_tex)

			_bind_eye_live2d_for_head(pilot_root, h_key, mat)

			var entry: Dictionary = meta.get(h_key, {}) as Dictionary
			var disp_arr: Array = entry.get("disp_size", [88.0, 102.0]) as Array
			var np_arr: Array = entry.get("neck_pivot_px", [44.0, 72.0]) as Array
			var disp_sz := Vector2(float(disp_arr[0]), float(disp_arr[1])) if disp_arr.size() >= 2 else Vector2(88.0, 102.0)
			var np_uv := Vector2(float(np_arr[0]) / maxf(disp_sz.x, 1.0), float(np_arr[1]) / maxf(disp_sz.y, 1.0)) if np_arr.size() >= 2 else Vector2(0.5, 0.72)
			_head_neck_pivot_uv[h_key] = np_uv
			if spr.texture != null:
				var t_sz: Vector2 = spr.texture.get_size()
				_head_tex_per_du[h_key] = Vector2(t_sz.x / maxf(disp_sz.x, 1.0), t_sz.y / maxf(disp_sz.y, 1.0))

			mat.set_shader_parameter("neck_pivot_uv", np_uv)
			mat.set_shader_parameter("head_over_face_keep", 1.0)
			mat.set_shader_parameter("normal_flip_x", 1.0)


func _bind_eye_live2d_for_head(pilot_root: String, head_key: String, mat: ShaderMaterial) -> void:
	if not _eye_live2d_meta.has(head_key):
		mat.set_shader_parameter("has_eye_live2d_assets", false)
		return
	var iris_tex: Texture2D = _head_eye_iris_tex.get(head_key, null) as Texture2D
	if iris_tex == null:
		iris_tex = MeshBuilderScript.load_texture_res("%s/heads/%s_eye_iris.png" % [pilot_root, head_key], false, true)
		if iris_tex != null:
			_head_eye_iris_tex[head_key] = iris_tex
	var closed_tex: Texture2D = _head_eye_closed_tex.get(head_key, null) as Texture2D
	if closed_tex == null:
		closed_tex = MeshBuilderScript.load_texture_res("%s/heads/%s_eye_closed.png" % [pilot_root, head_key], false, true)
		if closed_tex != null:
			_head_eye_closed_tex[head_key] = closed_tex
	if iris_tex == null or closed_tex == null:
		mat.set_shader_parameter("has_eye_live2d_assets", false)
		return
	var em: Dictionary = _eye_live2d_meta[head_key] as Dictionary
	var c_arr: Array = em.get("eye_center_uv", [0.35, 0.47]) as Array
	var s_arr: Array = em.get("eye_iris_size_uv", [0.065, 0.058]) as Array
	var r_arr: Array = em.get("eye_patch_rect_uv", [0.22, 0.35, 0.26, 0.22]) as Array
	mat.set_shader_parameter("eye_iris_tex", iris_tex)
	mat.set_shader_parameter("eye_closed_tex", closed_tex)
	mat.set_shader_parameter("eye_center_uv", Vector2(float(c_arr[0]), float(c_arr[1])))
	mat.set_shader_parameter("eye_iris_size_uv", Vector2(float(s_arr[0]), float(s_arr[1])))
	mat.set_shader_parameter("eye_patch_rect_uv", Vector4(float(r_arr[0]), float(r_arr[1]), float(r_arr[2]), float(r_arr[3])))
	mat.set_shader_parameter("has_eye_live2d_assets", true)


func _apply_default_style_and_skin() -> void:
	if _style_profile != null:
		_materials.apply_style_profile(_style_profile)
	if _profile != null and not _profile.skins.is_empty():
		_materials.apply_skin_preset(_profile.skins[0])
	_materials.set_recolor_method(1)
	_materials.set_hair_style_mode(0)
	_materials.set_shader_param_all("enable_inward_outline", false)
	var use_nd: bool = _style_profile.use_normal_depth if _style_profile != null else true
	var rim_str: float = (_style_profile.normal_rim_strength if use_nd else 0.0) if _style_profile != null else 0.88
	var hdr_cap: float = _style_profile.hdr_cap if _style_profile != null else 1.78
	_materials.set_normal_depth_options(use_nd, Vector2(-0.58, -0.81).normalized(), rim_str, hdr_cap)


func set_active_head(head_key: String) -> void:
	var resolved_head: String = head_key if CANONICAL_HEADS.has(head_key) else "head_front"
	_active_head_key = resolved_head
	var view_key: String = str(HEAD_TO_VIEW.get(resolved_head, "s"))

	for h_dict: Dictionary in [_head_under_data, _head_over_data]:
		var sprites: Dictionary = h_dict.get("sprites", {}) as Dictionary
		var meta: Dictionary = h_dict.get("meta", {}) as Dictionary
		var base_scales: Dictionary = h_dict.get("base_scales", {}) as Dictionary
		var base_offsets: Dictionary = h_dict.get("base_offsets", {}) as Dictionary
		var combos: Dictionary = meta.get("combo_transforms", {}) as Dictionary
		var view_combos: Dictionary = combos.get(view_key, {}) as Dictionary
		for hk: String in sprites.keys():
			var spr: Sprite2D = sprites[hk] as Sprite2D
			if spr == null:
				continue
			spr.visible = (hk == resolved_head)
			if spr.visible:
				var b_scale: Vector2 = base_scales.get(hk, spr.scale) as Vector2
				var b_off: Vector2 = base_offsets.get(hk, spr.position) as Vector2
				if view_combos.has(hk):
					var tf: Dictionary = view_combos[hk] as Dictionary
					var off_arr: Array = tf.get("sprite_offset", [b_off.x, b_off.y]) as Array
					var cur_s: float = float(tf.get("scale", 1.0))
					if off_arr.size() >= 2:
						spr.position = Vector2(float(off_arr[0]), float(off_arr[1]))
					spr.scale = b_scale * cur_s
				else:
					spr.position = b_off
					spr.scale = b_scale

	for vk: String in _torso_sprites.keys():
		var tspr: Sprite2D = _torso_sprites[vk] as Sprite2D
		if tspr != null:
			tspr.visible = _show_torso_ref and (vk == view_key)


func set_show_torso_ref(enabled: bool) -> void:
	_show_torso_ref = enabled
	var view_key: String = str(HEAD_TO_VIEW.get(_active_head_key, "s"))
	for vk: String in _torso_sprites.keys():
		var tspr: Sprite2D = _torso_sprites[vk] as Sprite2D
		if tspr != null:
			tspr.visible = _show_torso_ref and (vk == view_key)


func set_zoom_scale(z: float) -> void:
	if _materials != null:
		_materials.set_pass2_zoom_scale(z)


func set_debug_view_mode(mode_idx: int) -> void:
	if _materials != null:
		_materials.set_debug_view_mode(mode_idx)


func apply_skin_preset(skin: PilotSkinPreset) -> void:
	if _materials != null and skin != null:
		_materials.apply_skin_preset(skin)


func apply_hair_preset(hair: PilotHairPreset, fallback_col: Color) -> void:
	if _materials != null and hair != null:
		_materials.apply_hair_preset(hair, fallback_col)


func apply_face_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	var head_rot: float = float(state.get("head_rot_rad", 0.0))
	var head_shift_du: Vector2 = state.get("head_shift_du", Vector2.ZERO) as Vector2
	for anchor: Node2D in [_head_under_anchor, _head_over_anchor]:
		if anchor != null:
			anchor.position = head_shift_du
			anchor.rotation = head_rot

	var tex_per_du: Vector2 = _head_tex_per_du.get(_active_head_key, Vector2(3.45, 3.45)) as Vector2
	var shift_texels := Vector2(head_shift_du.x * tex_per_du.x, head_shift_du.y * tex_per_du.y)

	var enable_live: bool = bool(state.get("enable_face_live", false))
	var eye_look: Vector2 = state.get("eye_look_px", Vector2.ZERO) as Vector2
	var blink_v: float = float(state.get("blink", 0.0))
	var squint_v: float = float(state.get("squint", 0.0))
	var iris_scale_v: float = float(state.get("iris_scale", 1.0))
	var eye_spec_v: float = float(state.get("eye_highlight_strength", 0.0))
	var eye_lid_sh_v: float = float(state.get("eye_lid_shadow_strength", 0.0))
	var eye_far_v: float = float(state.get("eye_far_clarity", 0.0))
	var eye_glow_v: float = float(state.get("eye_combat_glow", 0.0))
	var brow_y: float = float(state.get("brow_offset_px", 0.0))
	var brow_t: float = float(state.get("brow_tilt", 0.0))
	var mouth_o: float = float(state.get("mouth_open", 0.0))
	var mouth_s: float = float(state.get("mouth_smile", 0.0))
	var weld_str: float = float(state.get("neck_weld_strength", 0.0))
	var chin_sh: float = float(state.get("chin_shadow_strength", 0.0))
	var tilt_2d: Vector2 = state.get("banking_tilt_2d", Vector2.ZERO) as Vector2
	var parallax_px: float = float(state.get("depth_parallax_px", 0.0))
	var parallax_piv: float = float(state.get("face_parallax_pivot", 0.60))
	var hair_on: bool = bool(state.get("enable_hair_3zone", false))
	var h_bangs: Vector2 = state.get("hair_bangs_px", Vector2.ZERO) as Vector2
	var h_sides: Vector2 = state.get("hair_sides_px", Vector2.ZERO) as Vector2
	var h_back: Vector2 = state.get("hair_back_px", Vector2.ZERO) as Vector2
	var h_norm_str: float = float(state.get("hair_normal_light_strength", 0.0))
	var hud_str: float = float(state.get("monocle_hud_strength", 0.0))
	var hud_act: float = float(state.get("monocle_activity", 0.0))
	var q_t: float = float(state.get("q_time", 0.0))

	if _materials != null:
		_materials.set_q_time(q_t)

	for mat: ShaderMaterial in get_head_materials(_active_head_key):
		mat.set_shader_parameter("enable_face_live", enable_live)
		mat.set_shader_parameter("face_neck_weld_strength", weld_str)
		mat.set_shader_parameter("face_neck_rot_rad", head_rot)
		mat.set_shader_parameter("face_neck_shift_px", shift_texels)
		mat.set_shader_parameter("face_eye_look_px", eye_look)
		mat.set_shader_parameter("face_blink", blink_v)
		mat.set_shader_parameter("face_squint", squint_v)
		mat.set_shader_parameter("face_iris_scale", iris_scale_v)
		mat.set_shader_parameter("face_eye_highlight_strength", eye_spec_v)
		mat.set_shader_parameter("face_eye_lid_shadow_strength", eye_lid_sh_v)
		mat.set_shader_parameter("face_eye_far_clarity", eye_far_v)
		mat.set_shader_parameter("face_eye_combat_glow", eye_glow_v)
		mat.set_shader_parameter("face_brow_offset_px", brow_y)
		mat.set_shader_parameter("face_brow_tilt", brow_t)
		mat.set_shader_parameter("face_mouth_open", mouth_o)
		mat.set_shader_parameter("face_mouth_smile", mouth_s)
		mat.set_shader_parameter("face_chin_shadow_strength", chin_sh)
		mat.set_shader_parameter("banking_tilt_2d", tilt_2d)
		mat.set_shader_parameter("depth_parallax_px", parallax_px)
		mat.set_shader_parameter("face_parallax_pivot", parallax_piv)
		mat.set_shader_parameter("enable_secondary_jiggle", hair_on)
		mat.set_shader_parameter("secondary_jiggle_l_px", h_bangs)
		mat.set_shader_parameter("secondary_jiggle_r_px", h_sides)
		mat.set_shader_parameter("secondary_jiggle_b_px", h_back)
		mat.set_shader_parameter("secondary_jiggle_normal_strength", h_norm_str)
		mat.set_shader_parameter("face_monocle_hud_strength", hud_str)
		mat.set_shader_parameter("face_monocle_activity", hud_act)

	sync_rig_matrices()


func sync_rig_matrices() -> void:
	if _torso_mount == null or _materials == null:
		return
	var inv_mat: Transform2D = _torso_mount.get_global_transform().affine_inverse()
	_materials.set_shader_param_all("inv_body_pivot_matrix", inv_mat)


func get_active_head_key() -> String:
	return _active_head_key


func get_active_head_screen_center() -> Vector2:
	if _head_over_anchor != null:
		return _head_over_anchor.global_position
	return global_position


func get_head_materials(head_key: String) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for h_dict: Dictionary in [_head_under_data, _head_over_data]:
		var sprites: Dictionary = h_dict.get("sprites", {}) as Dictionary
		var spr: Sprite2D = sprites.get(head_key, null) as Sprite2D
		if spr != null and spr.material is ShaderMaterial:
			out.append(spr.material as ShaderMaterial)
	return out


func has_face_live_textures() -> bool:
	for hk: String in CANONICAL_HEADS:
		if not _head_face_live_tex.has(hk) or _head_face_live_tex[hk] == null:
			return false
		var mats: Array[ShaderMaterial] = get_head_materials(hk)
		if mats.size() != 2:
			return false
		for mat: ShaderMaterial in mats:
			if mat.get_shader_parameter("face_live_mask_tex") == null:
				return false
			if mat.get_shader_parameter("secondary_jiggle_mask_tex") == null:
				return false
			if mat.get_shader_parameter("normal_depth_tex") == null:
				return false
	return true


func has_eye_live2d_textures() -> bool:
	for hk: String in EYE_LIVE2D_HEADS:
		if not _head_eye_iris_tex.has(hk) or _head_eye_iris_tex[hk] == null:
			return false
		if not _head_eye_closed_tex.has(hk) or _head_eye_closed_tex[hk] == null:
			return false
		var mats: Array[ShaderMaterial] = get_head_materials(hk)
		if mats.size() != 2:
			return false
		for mat: ShaderMaterial in mats:
			if not bool(mat.get_shader_parameter("has_eye_live2d_assets")):
				return false
			if mat.get_shader_parameter("eye_iris_tex") == null or mat.get_shader_parameter("eye_closed_tex") == null:
				return false
	for hk_non: String in ["head_side_l", "head_back_r", "head_back_l", "head_back"]:
		for mat_non: ShaderMaterial in get_head_materials(hk_non):
			if bool(mat_non.get_shader_parameter("has_eye_live2d_assets")):
				return false
	return true
