class_name PlanarRigMeshBuilder
extends RefCounted
## Constructor modular de vistas planares (S/N en parts_5) y cabezas desacopladas (8 direcciones).
## Carga RGBA, Clown-Pass ID (_id_mask.png) y Normales+Profundidad 2.5D (_normal_depth.png),
## priorizando ResourceLoader.load() con fallback a Image.load_from_file() para sandbox.

const ASSETS_ROOT: String = "res://sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar"
const SHADER_PATH: String = "res://sandbox/pilot_rig_lab/pilot_rig_stylizer.gdshader"

const PARTS_5_ORDER: Array[String] = ["leg_r", "leg_l", "arm_r", "arm_l", "pelvis", "torso", "body_core", "pauldron_r", "pauldron_l"]
const HEAD_KEYS: Array[String] = [
	"head_front",
	"head_front_l",
	"head_front_r",
	"head_side",
	"head_back",
	"head_side_l",
	"head_side_r",
	"head_back_l",
	"head_back_r",
]


static func create_conic_rim_lut() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.55, 0.80, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.92, 0.82, 1.0),
		Color(0.95, 0.94, 0.92, 1.0),
		Color(0.70, 0.76, 0.88, 1.0),
		Color(0.78, 0.84, 0.94, 1.0),
		Color(1.0, 0.92, 0.82, 1.0),
	])
	var tex := GradientTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_CONIC
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex


static func load_json_dict(res_path: String) -> Dictionary:
	var read_path: String = res_path if FileAccess.file_exists(res_path) else ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(read_path):
		push_warning("PlanarRigMeshBuilder: falta JSON en " + read_path)
		return {}
	var txt: String = FileAccess.get_file_as_string(read_path)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func load_texture_res(res_path: String, fix_alpha: bool = false, use_mipmaps: bool = true) -> Texture2D:
	var img: Image = null
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		img = Image.load_from_file(abs_path)
	elif ResourceLoader.exists(res_path):
		var loaded: Resource = ResourceLoader.load(res_path)
		if loaded is Texture2D:
			img = (loaded as Texture2D).get_image()
			if img != null and img.is_compressed():
				img.decompress()
	if img == null or img.is_empty():
		return null
	if fix_alpha:
		img.fix_alpha_edges()
	if use_mipmaps:
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func load_image_res(res_path: String) -> Image:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		return Image.load_from_file(abs_path)
	if ResourceLoader.exists(res_path):
		var loaded: Resource = ResourceLoader.load(res_path)
		if loaded is Texture2D:
			return (loaded as Texture2D).get_image()
		if loaded is Image:
			return loaded as Image
	return null


static func build_body_view_rig(
	parent: Node2D,
	view_key: String,
	shader_res: Shader,
	conic_lut: GradientTexture2D,
	pilot_root: String = ASSETS_ROOT
) -> Dictionary:
	var parts5_dir: String = "%s/%s/parts_5" % [pilot_root, view_key]
	var parts5_meta: Dictionary = load_json_dict("%s/parts_5_meta.json" % parts5_dir)
	if parts5_meta.is_empty():
		return {}
	return _build_parts5_rig(parent, parts5_dir, view_key, parts5_meta, shader_res, conic_lut)


static func _build_parts5_rig(
	parent: Node2D,
	parts5_dir: String,
	view_key: String,
	meta: Dictionary,
	shader_res: Shader,
	conic_lut: GradientTexture2D
) -> Dictionary:
	var orig_arr: Array = meta.get("rig_origin", [270.0, 242.5]) as Array
	var rig_origin := Vector2(float(orig_arr[0]), float(orig_arr[1]))
	var z_orders: Dictionary = meta.get("z_orders", {}) as Dictionary
	var rects: Dictionary = meta.get("rects", {}) as Dictionary

	var view_root := Node2D.new()
	view_root.name = "BodyView_%s" % view_key.to_upper()
	parent.add_child(view_root)

	var skel := Skeleton2D.new()
	skel.name = "Skeleton2D"
	view_root.add_child(skel)

	var bones_list: Array = meta.get("bones", []) as Array
	var bone_refs: Dictionary = {}
	var world_pos_map: Dictionary = {}
	var rest_rots: Dictionary = {}
	var rest_pos: Dictionary = {}

	for entry_v: Variant in bones_list:
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v as Dictionary
		var b_name: String = str(entry.get("name", ""))
		var p_name: String = str(entry.get("parent", ""))
		var raw_xy: Array = entry.get("pos", [rig_origin.x, rig_origin.y]) as Array
		var local_world := Vector2(float(raw_xy[0]), float(raw_xy[1])) - rig_origin

		var bone := Bone2D.new()
		bone.name = b_name
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(24.0)

		var parent_node: Node = skel
		var parent_world := Vector2.ZERO
		if not p_name.is_empty() and bone_refs.has(p_name):
			parent_node = bone_refs[p_name] as Bone2D
			parent_world = world_pos_map[p_name] as Vector2

		parent_node.add_child(bone)
		bone.position = local_world - parent_world
		bone.rest = bone.transform

		bone_refs[b_name] = bone
		world_pos_map[b_name] = local_world
		rest_rots[b_name] = bone.rotation
		rest_pos[b_name] = bone.position

	var meshes_root := Node2D.new()
	meshes_root.name = "Meshes"
	view_root.add_child(meshes_root)

	var poly_refs: Dictionary = {}
	var part_rects: Dictionary = {}
	var materials: Array[ShaderMaterial] = []
	var ordered_parts: Array[String] = []
	for raw_name: String in PARTS_5_ORDER:
		if rects.has(raw_name):
			ordered_parts.append(raw_name)
	var body_z: int = int(z_orders.get("body_core", 2))
	var split_stocking_legs: Dictionary = {}
	if view_key == "s":
		split_stocking_legs["leg_r"] = true
		split_stocking_legs["leg_l"] = true
	elif view_key == "se":
		split_stocking_legs["leg_r"] = true
	elif view_key == "sw":
		split_stocking_legs["leg_l"] = true

	ordered_parts.sort_custom(func(a: String, b: String) -> bool:
		var za: int = int(z_orders.get(a, 0))
		var zb: int = int(z_orders.get(b, 0))
		if split_stocking_legs.has(a) and za >= body_z:
			za = body_z - 1
		if split_stocking_legs.has(b) and zb >= body_z:
			zb = body_z - 1
		if za != zb:
			return za < zb
		return PARTS_5_ORDER.find(a) < PARTS_5_ORDER.find(b)
	)
	var pending_stockings: Array[Dictionary] = []

	for p_name: String in ordered_parts:
		var rect_arr: Array = rects[p_name] as Array
		var dx: float = float(rect_arr[0])
		var dy: float = float(rect_arr[1])
		var dw: float = float(rect_arr[2])
		var dh: float = float(rect_arr[3])

		var col_tex: Texture2D = load_texture_res("%s/%s.png" % [parts5_dir, p_name], true, true)
		var id_tex: Texture2D = load_texture_res("%s/%s_id_mask.png" % [parts5_dir, p_name], false, true)
		var nd_tex: Texture2D = load_texture_res("%s/%s_normal_depth.png" % [parts5_dir, p_name], false, true)
		if col_tex == null:
			continue

		var tex_sz: Vector2 = col_tex.get_size()
		var part_origin := Vector2(dx, dy) - rig_origin
		var cols: int = 12 if (p_name == "torso" or p_name == "pelvis" or p_name == "body_core") else 10
		var rows: int = 24 if (p_name == "leg_r" or p_name == "leg_l") else 18
		var mesh_data: Dictionary = _build_grid_mesh(part_origin, dw, dh, tex_sz, cols, rows)

		var poly := Polygon2D.new()
		poly.name = "Part_%s" % p_name
		poly.z_index = 0
		poly.texture = col_tex
		poly.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		poly.polygon = mesh_data["verts"] as PackedVector2Array
		poly.uv = mesh_data["uvs"] as PackedVector2Array
		poly.polygons = mesh_data["tris"] as Array
		meshes_root.add_child(poly)
		poly.skeleton = poly.get_path_to(skel)

		var anim_mask_img: Image = null
		if p_name == "arm_r" or p_name == "arm_l" or p_name == "leg_r" or p_name == "leg_l":
			anim_mask_img = load_image_res("%s/%s_anim_mask.png" % [parts5_dir, p_name])
		_bind_parts5_weights(
			poly,
			p_name,
			Vector2(dw, dh),
			skel,
			bone_refs,
			world_pos_map,
			mesh_data["uvs_norm"] as PackedVector2Array,
			anim_mask_img,
			view_key
		)

		var mat := ShaderMaterial.new()
		mat.shader = shader_res
		if id_tex != null:
			mat.set_shader_parameter("id_mask_tex", id_tex)
		if nd_tex != null:
			mat.set_shader_parameter("normal_depth_tex", nd_tex)
		if conic_lut != null:
			mat.set_shader_parameter("conic_rim_lut", conic_lut)
		mat.set_shader_parameter("use_normal_depth", nd_tex != null)
		mat.set_shader_parameter("is_head_part", false)
		mat.set_shader_parameter("is_leg_part", p_name == "leg_r" or p_name == "leg_l")
		mat.set_shader_parameter("weld_top_seam", p_name == "body_core" or p_name == "arm_r" or p_name == "arm_l" or p_name == "leg_r" or p_name == "leg_l")
		mat.set_shader_parameter("weld_bottom_seam", p_name == "body_core")
		mat.set_shader_parameter("suppress_alpha_rim", 1.0)
		mat.set_shader_parameter("part_rig_rect", Vector4(part_origin.x / 490.0, part_origin.y / 490.0, dw / 490.0, dh / 490.0))
		poly.material = mat

		poly_refs[p_name] = poly
		part_rects[p_name] = Rect2(part_origin, Vector2(dw, dh))
		materials.append(mat)
		if p_name == "body_core":
			var neck_u: float = 0.42
			var neck_half_w: float = 0.14
			var neck_max_v: float = 0.085
			var na_val: Variant = meta.get("neck_anchor", null)
			if na_val is Array and (na_val as Array).size() >= 2 and dw > 1.0 and dh > 1.0:
				var na_arr: Array = na_val as Array
				neck_u = clampf((float(na_arr[0]) - dx) / dw, 0.05, 0.95)
				var neck_v_norm: float = clampf((float(na_arr[1]) - dy) / dh, 0.0, 0.22)
				neck_max_v = maxf(0.085, neck_v_norm + 0.040)
				neck_half_w = clampf(22.0 / dw, 0.14, 0.28)
			mat.set_shader_parameter("neck_seam_u", neck_u)
			mat.set_shader_parameter("neck_seam_half_w", neck_half_w)
			mat.set_shader_parameter("neck_seam_max_v", neck_max_v)
			var sec_tex: Texture2D = load_texture_res("%s/body_core_secondary_mask.png" % parts5_dir, false, false)
			if sec_tex != null:
				mat.set_shader_parameter("secondary_jiggle_mask_tex", sec_tex)
				mat.set_shader_parameter("enable_secondary_jiggle", true)
			var pauldron_mask_tex: Texture2D = load_texture_res("%s/body_core_pauldron_mask.png" % parts5_dir, false, false)
			if pauldron_mask_tex != null:
				mat.set_shader_parameter("pauldron_mask_tex", pauldron_mask_tex)
				mat.set_shader_parameter("has_pauldron_mask", true)
			for st_item: Dictionary in pending_stockings:
				var p_st: Polygon2D = st_item["poly"] as Polygon2D
				var st_key: String = str(st_item["part_name"])
				meshes_root.add_child(p_st)
				p_st.skeleton = p_st.get_path_to(skel)
				_bind_parts5_weights(
					p_st,
					st_key,
					st_item["size"] as Vector2,
					skel,
					bone_refs,
					world_pos_map,
					st_item["uvs_norm"] as PackedVector2Array,
					st_item["anim_mask_img"] as Image,
					view_key
				)
				var m_st: ShaderMaterial = st_item["mat"] as ShaderMaterial
				p_st.material = m_st
				poly_refs["%s_stocking" % st_key] = p_st
				materials.append(m_st)
		elif split_stocking_legs.has(p_name):
			var poly_st := Polygon2D.new()
			poly_st.name = "Part_%s_stocking" % p_name
			poly_st.z_index = 0
			poly_st.texture = col_tex
			poly_st.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			poly_st.polygon = poly.polygon
			poly_st.uv = poly.uv
			poly_st.polygons = poly.polygons
			var mat_st := mat.duplicate() as ShaderMaterial
			mat_st.set_shader_parameter("leg_layer_pass", 2)
			pending_stockings.append({
				"part_name": p_name,
				"poly": poly_st,
				"size": Vector2(dw, dh),
				"uvs_norm": mesh_data["uvs_norm"] as PackedVector2Array,
				"anim_mask_img": anim_mask_img,
				"mat": mat_st,
			})

	var view_neck_rel := Vector2(-12.9, -122.0)
	var na_meta_val: Variant = meta.get("neck_anchor", null)
	if na_meta_val is Array and (na_meta_val as Array).size() >= 2:
		var na_meta_arr: Array = na_meta_val as Array
		view_neck_rel = Vector2(float(na_meta_arr[0]), float(na_meta_arr[1])) - rig_origin

	return {
		"root": view_root,
		"skeleton": skel,
		"bones": bone_refs,
		"rest_rots": rest_rots,
		"rest_pos": rest_pos,
		"world_pos": world_pos_map,
		"polys": poly_refs,
		"part_rects": part_rects,
		"materials": materials,
		"body_core_mat": (poly_refs.get("body_core", null) as Polygon2D).material if poly_refs.has("body_core") else null,
		"neck_bone": bone_refs.get("Neck", null),
		"neck_rel": view_neck_rel,
		"is_parts_5": true,
	}


static func _bind_parts5_weights(
	poly: Polygon2D,
	part_name: String,
	part_size: Vector2,
	skel: Skeleton2D,
	bone_refs: Dictionary,
	world_pos: Dictionary,
	uvs_norm: PackedVector2Array = PackedVector2Array(),
	anim_mask_img: Image = null,
	view_key: String = ""
) -> void:
	poly.clear_bones()
	var v_count: int = poly.polygon.size()
	var target_bones: Array[String] = []
	var sigma: float = 28.0
	match part_name:
		"pelvis":
			target_bones = ["Pelvis"]
		"body_core":
			target_bones = ["Pelvis", "Waist", "Chest", "Neck"]
			sigma = maxf(26.0, part_size.y * 0.20)
		"torso":
			target_bones = ["Pelvis", "Waist", "Chest", "Neck"]
			sigma = maxf(24.0, part_size.y * 0.22)
		"arm_r":
			target_bones = ["Shoulder_R", "Elbow_R", "Wrist_R"]
			sigma = maxf(20.0, part_size.y * 0.16)
		"arm_l":
			target_bones = ["Shoulder_L", "Elbow_L", "Wrist_L"]
			sigma = maxf(20.0, part_size.y * 0.16)
		"leg_r":
			target_bones = ["Thigh_R", "Knee_R", "Ankle_R"]
			sigma = 30.0
		"leg_l":
			target_bones = ["Thigh_L", "Knee_L", "Ankle_L"]
			sigma = 30.0
		"pauldron_r":
			if bone_refs.has("Pauldron_R") and bone_refs.has("Chest"):
				target_bones = ["Pauldron_R", "Chest", "Shoulder_R"]
			elif bone_refs.has("Pauldron_R"):
				target_bones = ["Pauldron_R"]
			else:
				target_bones = ["Chest", "Shoulder_R"]
			sigma = 24.0
		"pauldron_l":
			if bone_refs.has("Pauldron_L") and bone_refs.has("Chest"):
				target_bones = ["Pauldron_L", "Chest", "Shoulder_L"]
			elif bone_refs.has("Pauldron_L"):
				target_bones = ["Pauldron_L"]
			else:
				target_bones = ["Chest", "Shoulder_L"]
			sigma = 24.0

	var w_by_bone: Dictionary = {}
	for b_name: String in target_bones:
		var arr: Array[float] = []
		arr.resize(v_count)
		arr.fill(0.0)
		w_by_bone[b_name] = arr

	var has_limb_mask: bool = anim_mask_img != null and not anim_mask_img.is_empty() and target_bones.size() == 3 and uvs_norm.size() == v_count
	var mask_w: int = anim_mask_img.get_width() if has_limb_mask else 0
	var mask_h: int = anim_mask_img.get_height() if has_limb_mask else 0
	var verts: PackedVector2Array = poly.polygon
	for i: int in range(v_count):
		if target_bones.size() == 1:
			(w_by_bone[target_bones[0]] as Array)[i] = 1.0
		elif has_limb_mask:
			var uv_n: Vector2 = uvs_norm[i]
			var mx: int = clampi(int(round(uv_n.x * float(mask_w - 1))), 0, mask_w - 1)
			var my: int = clampi(int(round(uv_n.y * float(mask_h - 1))), 0, mask_h - 1)
			var mc: Color = anim_mask_img.get_pixel(mx, my)
			var m_sum: float = mc.r + mc.g + mc.b
			if m_sum > 0.001:
				(w_by_bone[target_bones[0]] as Array)[i] = mc.r / m_sum
				(w_by_bone[target_bones[1]] as Array)[i] = mc.g / m_sum
				(w_by_bone[target_bones[2]] as Array)[i] = mc.b / m_sum
			else:
				var ws_fb: Array[float] = _inverse_dist_weights(verts[i], target_bones, world_pos, sigma)
				for k: int in range(target_bones.size()):
					(w_by_bone[target_bones[k]] as Array)[i] = ws_fb[k]
		else:
			var ws: Array[float] = _inverse_dist_weights(verts[i], target_bones, world_pos, sigma)
			for k: int in range(target_bones.size()):
				(w_by_bone[target_bones[k]] as Array)[i] = ws[k]

	if part_name == "body_core":
		for sh_name: String in ["Shoulder_R", "Shoulder_L"]:
			if world_pos.has(sh_name) and bone_refs.has(sh_name):
				_blend_seam_joint_weight(w_by_bone, target_bones, verts, world_pos[sh_name] as Vector2, sh_name, 16.0, 0.18, -10.0, 14.0)
		var is_profile_hip: bool = view_key in ["e", "w"]
		var is_back_hip: bool = view_key in ["ne", "n", "nw"]
		var front_thigh: String = "Thigh_R" if view_key == "e" else ("Thigh_L" if view_key == "w" else "")
		var pel_wpos: Vector2 = world_pos.get("Pelvis", Vector2.ZERO) as Vector2
		for th_name: String in ["Thigh_R", "Thigh_L"]:
			if world_pos.has(th_name) and bone_refs.has(th_name):
				var th_wpos: Vector2 = world_pos[th_name] as Vector2
				if is_profile_hip and th_name == front_thigh:
					_blend_hip_sheet_weight(w_by_bone, target_bones, verts, th_wpos, pel_wpos, th_name, -8.0, 40.0, 0.62, false)
				elif is_back_hip:
					_blend_hip_sheet_weight(w_by_bone, target_bones, verts, th_wpos, pel_wpos, th_name, -8.0, 36.0, 0.76, true)
				elif not is_profile_hip:
					_blend_hip_sheet_weight(w_by_bone, target_bones, verts, th_wpos, pel_wpos, th_name, -8.0, 36.0, 0.42, true)
	elif (part_name == "leg_r" or part_name == "leg_l") and world_pos.has("Pelvis") and bone_refs.has("Pelvis"):
		var th_key: String = "Thigh_R" if part_name == "leg_r" else "Thigh_L"
		if world_pos.has(th_key):
			var th_pos: Vector2 = world_pos[th_key] as Vector2
			var is_profile_hip: bool = view_key in ["e", "w"]
			var is_back_hip: bool = view_key in ["ne", "n", "nw"]
			var pel_arr: Array[float] = []
			pel_arr.resize(v_count)
			pel_arr.fill(0.0)
			for i: int in range(v_count):
				var dy_down: float = verts[i].y - th_pos.y
				var w_pel: float = 0.0
				if is_back_hip:
					# Coincide en la banda del gluteo (-8..+36 -> w_thigh 0..0.76) con body_core y baja a 0 antes de la media (+52)
					if dy_down < 36.0:
						var t_top: float = clampf((dy_down + 8.0) / 44.0, 0.0, 1.0)
						w_pel = 1.0 - 0.76 * (t_top * t_top * (3.0 - 2.0 * t_top))
					elif dy_down < 52.0:
						var t_bot: float = clampf((dy_down - 36.0) / 16.0, 0.0, 1.0)
						w_pel = 0.24 * (1.0 - t_bot * t_bot * (3.0 - 2.0 * t_bot))
				else:
					var hip_span: float = 44.0 if is_profile_hip else 48.0
					var hip_peak: float = 0.85 if is_profile_hip else 0.94
					if dy_down < hip_span:
						var dy_off: float = 2.0 if is_profile_hip else 4.0
						var t_hip: float = clampf((dy_down + dy_off) / maxf(hip_span + dy_off, 1.0), 0.0, 1.0)
						w_pel = hip_peak * (1.0 - t_hip * t_hip * (3.0 - 2.0 * t_hip))
				if w_pel > 0.0001:
					pel_arr[i] = w_pel
					var keep_pel: float = 1.0 - w_pel
					for tb: String in target_bones:
						(w_by_bone[tb] as Array)[i] = float((w_by_bone[tb] as Array)[i]) * keep_pel
			w_by_bone["Pelvis"] = pel_arr
			target_bones.append("Pelvis")

	elif part_name == "pauldron_r" or part_name == "pauldron_l":
		var p_key: String = "Pauldron_R" if part_name == "pauldron_r" else "Pauldron_L"
		var sh_key: String = "Shoulder_R" if part_name == "pauldron_r" else "Shoulder_L"
		var has_p: bool = w_by_bone.has(p_key)
		var has_c: bool = w_by_bone.has("Chest")
		var has_sh: bool = w_by_bone.has(sh_key)
		if has_p and has_c and has_sh and world_pos.has("Chest") and world_pos.has(sh_key):
			var is_rear_profile_pauldron: bool = (view_key == "e" and part_name == "pauldron_l") or (view_key == "w" and part_name == "pauldron_r")
			if is_rear_profile_pauldron:
				(w_by_bone["Chest"] as Array).fill(0.85)
				(w_by_bone[p_key] as Array).fill(0.15)
				(w_by_bone[sh_key] as Array).fill(0.0)
			else:
				var chest_pos: Vector2 = world_pos["Chest"] as Vector2
				var sh_pos: Vector2 = world_pos[sh_key] as Vector2
				var span_x: float = sh_pos.x - chest_pos.x
				var is_prof: bool = view_key == "e" or view_key == "w" or absf(span_x) < 10.0
				for i: int in range(v_count):
					var v: Vector2 = verts[i]
					var t_raw: float = 0.0
					if is_prof:
						t_raw = clampf((v.y - (sh_pos.y - 20.0)) / 22.0, 0.0, 1.0)
					else:
						var u: float = (v.x - chest_pos.x) / span_x
						t_raw = clampf((u - 0.25) / 0.65, 0.0, 1.0)
					var t_sm: float = t_raw * t_raw * (3.0 - 2.0 * t_raw)
					var c_min: float = 0.64 if is_prof else 0.84
					var p_min: float = 0.30 if is_prof else 0.16
					var s_min: float = 0.06 if is_prof else 0.00
					var w_c: float = lerpf(c_min, 0.18 if is_prof else 0.10, t_sm)
					var w_p: float = lerpf(p_min, 0.58 if is_prof else 0.54, t_sm)
					var w_s: float = lerpf(s_min, 0.24 if is_prof else 0.36, t_sm)
					(w_by_bone["Chest"] as Array)[i] = w_c
					(w_by_bone[p_key] as Array)[i] = w_p
					(w_by_bone[sh_key] as Array)[i] = w_s
		elif has_p and has_c and has_sh:
			(w_by_bone[p_key] as Array).fill(0.72)
			(w_by_bone["Chest"] as Array).fill(0.18)
			(w_by_bone[sh_key] as Array).fill(0.10)
		elif has_c and has_sh:
			(w_by_bone["Chest"] as Array).fill(0.80)
			(w_by_bone[sh_key] as Array).fill(0.20)

	for b_name: String in target_bones:
		if not bone_refs.has(b_name):
			continue
		var bone: Bone2D = bone_refs[b_name] as Bone2D
		poly.add_bone(skel.get_path_to(bone), PackedFloat32Array(w_by_bone[b_name] as Array))


static func _blend_hip_sheet_weight(
	w_by_bone: Dictionary,
	target_bones: Array[String],
	verts: PackedVector2Array,
	th_pos: Vector2,
	pel_pos: Vector2,
	joint_bone: String,
	dy_start: float,
	dy_end: float,
	peak: float,
	use_side_split: bool,
) -> void:
	"""Blends lower glute/hip flap of body_core uniformly along Y to match leg_r/leg_l deformation."""
	var v_count: int = verts.size()
	var arr: Array[float] = []
	arr.resize(v_count)
	arr.fill(0.0)
	var side_dx: float = th_pos.x - pel_pos.x
	var side_sign: float = signf(side_dx) if absf(side_dx) > 1.0 else 0.0
	var span_y: float = maxf(dy_end - dy_start, 1.0)
	for i: int in range(v_count):
		var v: Vector2 = verts[i]
		var dy: float = v.y - th_pos.y
		if dy <= dy_start:
			continue
		var t_y: float = clampf((dy - dy_start) / span_y, 0.0, 1.0)
		var t_sm: float = t_y * t_y * (3.0 - 2.0 * t_y)
		var side_w: float = 1.0
		if use_side_split and absf(side_sign) > 0.5:
			var lat: float = (v.x - pel_pos.x) * side_sign
			var t_s: float = clampf((lat + 2.0) / 14.0, 0.0, 1.0)
			side_w = t_s * t_s * (3.0 - 2.0 * t_s)
		var w: float = peak * t_sm * side_w
		if w > 0.0001:
			arr[i] = w
			var keep: float = 1.0 - w
			for tb: String in target_bones:
				(w_by_bone[tb] as Array)[i] = float((w_by_bone[tb] as Array)[i]) * keep
	w_by_bone[joint_bone] = arr
	target_bones.append(joint_bone)


static func _blend_seam_joint_weight(
	w_by_bone: Dictionary,
	target_bones: Array[String],
	verts: PackedVector2Array,
	joint_pos: Vector2,
	joint_bone: String,
	radius: float,
	peak: float,
	min_dy: float = -9999.0,
	max_dy: float = 9999.0,
) -> void:
	"""Blends a localized seam-locked bone weight around a joint socket without distorting distant silhouettes."""
	var v_count: int = verts.size()
	var arr: Array[float] = []
	arr.resize(v_count)
	arr.fill(0.0)
	for i: int in range(v_count):
		var dy: float = verts[i].y - joint_pos.y
		if dy < min_dy or dy > max_dy:
			continue
		var d: float = verts[i].distance_to(joint_pos)
		if d < radius:
			var t: float = clampf(1.0 - d / radius, 0.0, 1.0)
			var w: float = (t * t * (3.0 - 2.0 * t)) * peak
			arr[i] = w
			var keep: float = 1.0 - w
			for tb: String in target_bones:
				(w_by_bone[tb] as Array)[i] = float((w_by_bone[tb] as Array)[i]) * keep
	w_by_bone[joint_bone] = arr
	target_bones.append(joint_bone)


static func build_decoupled_heads(
	head_anchor: Node2D,
	shader_res: Shader,
	conic_lut: GradientTexture2D,
	pilot_root: String = ASSETS_ROOT,
	layer_pass: int = 0
) -> Dictionary:
	var heads_dir: String = "%s/heads" % pilot_root
	var meta: Dictionary = load_json_dict("%s/heads_metadata.json" % heads_dir)
	var parts5_meta: Dictionary = load_json_dict("%s/s/parts_5/parts_5_meta.json" % pilot_root)
	var neck_rel := Vector2(-12.9, -122.0)
	if parts5_meta.has("rig_origin") and parts5_meta.has("neck_anchor"):
		var ro: Array = parts5_meta["rig_origin"] as Array
		var na: Array = parts5_meta["neck_anchor"] as Array
		if ro.size() >= 2 and na.size() >= 2:
			neck_rel = Vector2(float(na[0]) - float(ro[0]), float(na[1]) - float(ro[1]))
	var sprites: Dictionary = {}
	var materials: Array[ShaderMaterial] = []
	var base_scales: Dictionary = {}
	var base_offsets: Dictionary = {}

	for h_key: String in HEAD_KEYS:
		var col_tex: Texture2D = load_texture_res("%s/%s.png" % [heads_dir, h_key], true, true)
		var id_tex: Texture2D = load_texture_res("%s/%s_id_mask.png" % [heads_dir, h_key], false, true)
		var nd_tex: Texture2D = load_texture_res("%s/%s_normal_depth.png" % [heads_dir, h_key], false, true)
		var jiggle_tex: Texture2D = load_texture_res("%s/%s_hair_jiggle_mask.png" % [heads_dir, h_key], false, false)
		var sdf_tex: Texture2D = load_texture_res("%s/%s_outline_sdf.png" % [heads_dir, h_key], false, false)
		if col_tex == null:
			continue

		var entry: Dictionary = meta.get(h_key, {}) as Dictionary
		var disp_sz_arr: Array = entry.get("disp_size", [110.0, 120.0]) as Array
		var disp_size := Vector2(float(disp_sz_arr[0]), float(disp_sz_arr[1]))
		var off_arr: Array = entry.get("sprite_offset", [0.0, -45.0]) as Array
		var sprite_off := Vector2(float(off_arr[0]), float(off_arr[1]))
		if entry.has("neck_pivot_px") and entry["neck_pivot_px"] is Array and (entry["neck_pivot_px"] as Array).size() >= 2:
			var np_arr: Array = entry["neck_pivot_px"] as Array
			# Alinear el eje X del cuello exactamente sobre el pivote anatómico para evitar bamboleo al rotar.
			sprite_off.x = disp_size.x * 0.5 - float(np_arr[0])

		var spr := Sprite2D.new()
		spr.name = h_key
		spr.texture = col_tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		spr.centered = true
		spr.position = sprite_off
		var tex_sz: Vector2 = col_tex.get_size()
		spr.scale = Vector2(disp_size.x / maxf(tex_sz.x, 1.0), disp_size.y / maxf(tex_sz.y, 1.0))
		spr.visible = (h_key == "head_front")

		var mat := ShaderMaterial.new()
		mat.shader = shader_res
		if id_tex != null:
			mat.set_shader_parameter("id_mask_tex", id_tex)
		if nd_tex != null:
			mat.set_shader_parameter("normal_depth_tex", nd_tex)
		if jiggle_tex != null:
			mat.set_shader_parameter("secondary_jiggle_mask_tex", jiggle_tex)
		if sdf_tex != null:
			mat.set_shader_parameter("outline_sdf_tex", sdf_tex)
			mat.set_shader_parameter("has_outline_sdf", true)
			mat.set_shader_parameter("sdf_pad_px", 32.0)
			mat.set_shader_parameter("head_outline_width_px", 4.0)
		if conic_lut != null:
			mat.set_shader_parameter("conic_rim_lut", conic_lut)
		mat.set_shader_parameter("use_normal_depth", nd_tex != null)
		mat.set_shader_parameter("is_head_part", true)
		mat.set_shader_parameter("head_layer_pass", layer_pass)
		mat.set_shader_parameter("suppress_alpha_rim", 1.0 if layer_pass == 1 else 0.0)
		var h_orig := neck_rel + sprite_off - disp_size * 0.5
		mat.set_shader_parameter("part_rig_rect", Vector4(h_orig.x / 490.0, h_orig.y / 490.0, disp_size.x / 490.0, disp_size.y / 490.0))
		spr.material = mat

		head_anchor.add_child(spr)
		sprites[h_key] = spr
		base_scales[h_key] = spr.scale
		base_offsets[h_key] = spr.position
		materials.append(mat)

	return {
		"sprites": sprites,
		"materials": materials,
		"meta": meta,
		"base_scales": base_scales,
		"base_offsets": base_offsets,
	}


static func _build_grid_mesh(
	origin: Vector2,
	dw: float,
	dh: float,
	tex_size: Vector2,
	cols: int,
	rows: int
) -> Dictionary:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var uvs_norm := PackedVector2Array()
	var tris: Array = []

	for r: int in range(rows + 1):
		var v: float = float(r) / float(rows)
		for c: int in range(cols + 1):
			var u: float = float(c) / float(cols)
			verts.append(origin + Vector2(u * dw, v * dh))
			uvs.append(Vector2(u * tex_size.x, v * tex_size.y))
			uvs_norm.append(Vector2(u, v))

	var stride: int = cols + 1
	for r: int in range(rows):
		for c: int in range(cols):
			var i0: int = r * stride + c
			var i1: int = i0 + 1
			var i2: int = (r + 1) * stride + c
			var i3: int = i2 + 1
			tris.append(PackedInt32Array([i0, i1, i3]))
			tris.append(PackedInt32Array([i0, i3, i2]))

	return {
		"verts": verts,
		"uvs": uvs,
		"uvs_norm": uvs_norm,
		"tris": tris,
	}


static func _inverse_dist_weights(
	pt: Vector2,
	bone_names: Array[String],
	world_pos: Dictionary,
	sigma: float
) -> Array[float]:
	var raw: Array[float] = []
	var sum_w: float = 0.0
	var two_sig_sq: float = maxf(2.0 * sigma * sigma, 1.0)
	for b_name: String in bone_names:
		var b_pos: Vector2 = world_pos.get(b_name, pt) as Vector2
		var d2: float = pt.distance_squared_to(b_pos)
		var w: float = exp(-d2 / two_sig_sq) + 0.0005
		raw.append(w)
		sum_w += w
	var inv_sum: float = 1.0 / maxf(sum_w, 0.0001)
	for i: int in range(raw.size()):
		raw[i] *= inv_sum
	return raw
