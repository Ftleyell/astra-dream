class_name HubWestSanctuaryController
extends Node3D

## Controlador modular del Ala Oeste — Santuario Ceremonial Oscuro (#101324 / Materia Oscura #BF00FF).
## Construye el Arco Ceremonial de 5 Reliquias Cristalinas 3D con geometría secundaria y emisión HDR
## escaladas según SaveManager.get_trophy_mastery(...) o mastery_override para pruebas en Sandbox.

signal relic_interacted(trophy_id: StringName, pedestal_world_pos: Vector3)

const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_art_lab_config.gd")
const WestMeshBuilder = preload("res://scenes/ui/hub/astral_station/meshes/hub_west_sanctuary_mesh_builder.gd")
const PropShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_arcsys_prop_3d.gdshader")
const OutlineShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_arcsys_outline_3d.gdshader")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")

const COLOR_DARK_MATTER := Color(0.75, 0.05, 1.0, 1.0)
const COLOR_SANCTUARY_ARMOR := Color(0.24, 0.27, 0.44, 1.0)
const COLOR_SANCTUARY_CHASSIS := Color(0.06, 0.075, 0.14, 1.0)
const COLOR_CALIBRATING_SLATE := Color(0.28, 0.31, 0.42, 1.0)

const RELIC_SPECS: Array[Dictionary] = [
	{"id": &"trophy_boss_aegis", "title": "Corazón Aegis"},
	{"id": &"trophy_biosphere_core", "title": "Núcleo Bio-Planeta"},
	{"id": &"trophy_cryo_core", "title": "Núcleo Criogénico"},
	{"id": &"trophy_volcanic_core", "title": "Núcleo Volcánico"},
	{"id": &"trophy_monolith_master", "title": "Reliquia Monolito"},
]

var _config: ConfigScript = null
var _is_built: bool = false
var _mastery_override: int = -1
var _time_acc: float = 0.0
var _relics: Array[Dictionary] = []


func setup(p_config: ConfigScript) -> void:
	_config = p_config
	_ensure_built()
	refresh_all_relics()


func _ensure_built() -> void:
	if _is_built or _config == null:
		return

	_relics.clear()
	var ped_mesh: ArrayMesh = WestMeshBuilder.build_relic_pedestal_mesh()
	var inner_ring_mesh: ArrayMesh = WestMeshBuilder.build_relic_orbit_ring_mesh(0.50)
	var outer_ring_mesh: ArrayMesh = WestMeshBuilder.build_relic_orbit_ring_mesh(0.68)

	for i: int in range(RELIC_SPECS.size()):
		var spec: Dictionary = RELIC_SPECS[i]
		var tid: StringName = spec["id"] as StringName
		var title_str: String = str(spec["title"])
		var pos: Vector3 = _config.west_relic_positions[i] if i < _config.west_relic_positions.size() else Vector3(-9.0, 0.0, -2.0 + float(i) * 1.4)

		var root := Node3D.new()
		root.name = "RelicPedestal_%s" % str(tid)
		root.position = pos
		var yaw_to_center: float = atan2(-pos.x, 0.8 - pos.z)
		root.rotation = Vector3(0.0, yaw_to_center, 0.0)
		add_child(root)

		var outline_mat := ShaderMaterial.new()
		outline_mat.shader = OutlineShader
		outline_mat.set_shader_parameter("outline_width", _config.outline_width)
		outline_mat.set_shader_parameter("reference_distance", _config.outline_ref_distance)

		var mats: Array[ShaderMaterial] = []
		var base_cols: Array[Color] = [COLOR_SANCTUARY_ARMOR, COLOR_SANCTUARY_CHASSIS, COLOR_DARK_MATTER]
		for surf_idx: int in range(3):
			var m := ShaderMaterial.new()
			m.shader = PropShader
			m.next_pass = outline_mat
			m.set_shader_parameter("material_kind", surf_idx)
			m.set_shader_parameter("base_color", base_cols[surf_idx])
			m.set_shader_parameter("pilot_accent_color", COLOR_DARK_MATTER)
			m.set_shader_parameter("calibrating_tint", COLOR_CALIBRATING_SLATE)
			m.set_shader_parameter("crease_ink_strength", _config.crease_ink_strength)
			m.set_shader_parameter("emissive_boost", _config.emissive_boost)
			m.set_shader_parameter("ambient_fill", 0.28)
			mats.append(m)

		var ped_mi := MeshInstance3D.new()
		ped_mi.name = "PedestalMesh"
		ped_mi.mesh = ped_mesh
		ped_mi.position = Vector3(0.0, -0.35, 0.0)
		ped_mi.scale = Vector3(0.58, 0.42, 0.58)
		ped_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surf_idx: int in range(3):
			ped_mi.set_surface_override_material(surf_idx, mats[surf_idx])
		root.add_child(ped_mi)

		# Filamento vertical de Materia Oscura + anillo orbital base anclando la reliquia al vacío
		var tether_mesh := CylinderMesh.new()
		tether_mesh.top_radius = 0.018
		tether_mesh.bottom_radius = 0.042
		tether_mesh.height = 1.15
		tether_mesh.radial_segments = 10
		var tether_mi := MeshInstance3D.new()
		tether_mi.name = "DarkMatterTether"
		tether_mi.mesh = tether_mesh
		tether_mi.position = Vector3(0.0, 0.42, 0.0)
		tether_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tether_mi.set_surface_override_material(0, mats[2])
		root.add_child(tether_mi)

		var halo_torus := TorusMesh.new()
		halo_torus.inner_radius = 0.44
		halo_torus.outer_radius = 0.50
		halo_torus.rings = 24
		halo_torus.ring_segments = 8
		var halo_mi := MeshInstance3D.new()
		halo_mi.name = "RelicBaseHalo"
		halo_mi.mesh = halo_torus
		halo_mi.position = Vector3(0.0, 0.14, 0.0)
		halo_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo_mi.set_surface_override_material(0, mats[2])
		root.add_child(halo_mi)

		var artifact_pivot := Node3D.new()
		artifact_pivot.name = "ArtifactPivot"
		artifact_pivot.position = Vector3(0.0, 1.15, 0.0)
		root.add_child(artifact_pivot)

		var artifact_mi := MeshInstance3D.new()
		artifact_mi.name = "ArtifactMesh"
		artifact_mi.mesh = WestMeshBuilder.build_relic_artifact_mesh(tid)
		artifact_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for surf_idx: int in range(3):
			artifact_mi.set_surface_override_material(surf_idx, mats[surf_idx])
		artifact_pivot.add_child(artifact_mi)

		var inner_ring_mi := MeshInstance3D.new()
		inner_ring_mi.name = "InnerOrbitRing"
		inner_ring_mi.mesh = inner_ring_mesh
		inner_ring_mi.rotation_degrees = Vector3(26.0, 0.0, 18.0)
		inner_ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inner_ring_mi.visible = false
		for surf_idx: int in range(3):
			inner_ring_mi.set_surface_override_material(surf_idx, mats[surf_idx])
		artifact_pivot.add_child(inner_ring_mi)

		var outer_ring_mi := MeshInstance3D.new()
		outer_ring_mi.name = "OuterOrbitRing"
		outer_ring_mi.mesh = outer_ring_mesh
		outer_ring_mi.rotation_degrees = Vector3(-28.0, 0.0, -22.0)
		outer_ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		outer_ring_mi.visible = false
		for surf_idx: int in range(3):
			outer_ring_mi.set_surface_override_material(surf_idx, mats[surf_idx])
		artifact_pivot.add_child(outer_ring_mi)

		var area := Area3D.new()
		area.name = "InteractArea"
		area.collision_layer = 0
		area.collision_mask = 2
		var a_cs := CollisionShape3D.new()
		var a_cyl := CylinderShape3D.new()
		a_cyl.radius = 2.85
		a_cyl.height = 2.6
		a_cs.shape = a_cyl
		a_cs.position = Vector3(0.0, 0.9, 0.0)
		area.add_child(a_cs)
		root.add_child(area)

		var lbl := Label3D.new()
		lbl.name = "PromptLabel"
		lbl.position = Vector3(0.0, 2.25, 0.0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.font_size = 28
		lbl.outline_size = 12
		lbl.outline_modulate = Color(0.03, 0.03, 0.08, 1.0)
		lbl.visible = false
		root.add_child(lbl)

		_relics.append({
			"id": tid,
			"title": title_str,
			"root": root,
			"artifact_pivot": artifact_pivot,
			"artifact_mesh": artifact_mi,
			"inner_ring": inner_ring_mi,
			"outer_ring": outer_ring_mi,
			"materials": mats,
			"outline_mat": outline_mat,
			"area": area,
			"label": lbl,
			"mastery": 0,
			"calibration_factor": 1.0,
		})

	_is_built = true


func set_mastery_override(level: int) -> void:
	_mastery_override = level
	refresh_all_relics()


func get_mastery_override() -> int:
	return _mastery_override


func refresh_all_relics() -> void:
	var base_emissive: float = _config.emissive_boost if _config != null else 1.65
	for entry: Dictionary in _relics:
		var tid: StringName = entry["id"] as StringName
		var mastery: int = _mastery_override if _mastery_override >= 0 else SaveManagerScript.get_trophy_mastery(tid)
		mastery = maxi(0, mastery)
		entry["mastery"] = mastery

		var is_unlocked: bool = mastery > 0
		var cal_factor: float = 0.0 if is_unlocked else 1.0
		entry["calibration_factor"] = cal_factor

		var emissive_val: float = base_emissive * (1.0 + float(maxi(0, mastery - 1)) * 0.35) if is_unlocked else base_emissive * 0.45
		var mats: Array = entry["materials"] as Array
		for m_var: Variant in mats:
			var mat: ShaderMaterial = m_var as ShaderMaterial
			if mat != null:
				mat.set_shader_parameter("calibration_factor", cal_factor)
				mat.set_shader_parameter("emissive_boost", emissive_val)
		var out_mat: ShaderMaterial = entry["outline_mat"] as ShaderMaterial
		if out_mat != null:
			out_mat.set_shader_parameter("calibration_factor", cal_factor)

		var inner_ring: MeshInstance3D = entry["inner_ring"] as MeshInstance3D
		var outer_ring: MeshInstance3D = entry["outer_ring"] as MeshInstance3D
		if inner_ring != null:
			inner_ring.visible = (mastery >= 2)
		if outer_ring != null:
			outer_ring.visible = (mastery >= 3)

		var art_mesh: MeshInstance3D = entry["artifact_mesh"] as MeshInstance3D
		if art_mesh != null:
			var sc: float = 1.0 + float(mini(mastery, 5)) * 0.045 if is_unlocked else 0.90
			art_mesh.scale = Vector3(sc, sc, sc)

		var lbl: Label3D = entry["label"] as Label3D
		if lbl != null:
			var title_str: String = str(entry["title"])
			if is_unlocked:
				lbl.text = "[E] %s · Nv.%d" % [title_str, mastery]
				lbl.modulate = Color(0.86, 0.45, 1.0, 1.0)
			else:
				lbl.text = "[E] %s · Sellada" % title_str
				lbl.modulate = Color(0.68, 0.72, 0.84, 1.0)


func _process(delta: float) -> void:
	_time_acc += delta
	for i: int in range(_relics.size()):
		var entry: Dictionary = _relics[i]
		var mastery: int = int(entry.get("mastery", 0))
		var pivot: Node3D = entry.get("artifact_pivot", null) as Node3D
		var art_mesh: MeshInstance3D = entry.get("artifact_mesh", null) as MeshInstance3D
		var inner_ring: MeshInstance3D = entry.get("inner_ring", null) as MeshInstance3D
		var outer_ring: MeshInstance3D = entry.get("outer_ring", null) as MeshInstance3D
		if pivot != null:
			var bob_amp: float = 0.055 if mastery > 0 else 0.015
			pivot.position.y = 1.15 + sin(_time_acc * 2.1 + float(i) * 0.9) * bob_amp
		if art_mesh != null:
			var spin: float = (0.85 + float(mastery) * 0.25) if mastery > 0 else 0.18
			art_mesh.rotation.y += delta * spin
		if inner_ring != null and inner_ring.visible:
			inner_ring.rotation.y += delta * (1.2 + float(mastery) * 0.22)
		if outer_ring != null and outer_ring.visible:
			outer_ring.rotation.y -= delta * (0.95 + float(mastery) * 0.18)


func update_proximity(player_body: Node3D, allow_prompts: bool) -> void:
	if player_body == null:
		return
	for entry: Dictionary in _relics:
		var area: Area3D = entry.get("area", null) as Area3D
		var lbl: Label3D = entry.get("label", null) as Label3D
		if lbl != null and area != null:
			lbl.visible = allow_prompts and area.overlaps_body(player_body)


func try_interact(player_body: Node3D) -> bool:
	if player_body == null:
		return false
	for entry: Dictionary in _relics:
		var area: Area3D = entry.get("area", null) as Area3D
		if area != null and area.overlaps_body(player_body):
			var root: Node3D = entry["root"] as Node3D
			relic_interacted.emit(entry["id"] as StringName, root.global_position)
			return true
	return false


func get_relic_count() -> int:
	return _relics.size()


func get_relic_state(trophy_id: StringName) -> Dictionary:
	for entry: Dictionary in _relics:
		if entry["id"] == trophy_id:
			var inner_ring: MeshInstance3D = entry["inner_ring"] as MeshInstance3D
			var outer_ring: MeshInstance3D = entry["outer_ring"] as MeshInstance3D
			return {
				"id": trophy_id,
				"mastery": int(entry["mastery"]),
				"calibration_factor": float(entry["calibration_factor"]),
				"inner_ring_visible": inner_ring != null and inner_ring.visible,
				"outer_ring_visible": outer_ring != null and outer_ring.visible,
			}
	return {}


func get_relic_world_pos(trophy_id: StringName) -> Vector3:
	for entry: Dictionary in _relics:
		if entry["id"] == trophy_id:
			var root: Node3D = entry["root"] as Node3D
			return root.global_position
	return Vector3(-9.0, 0.0, 0.8)


func apply_shader_calibration(crease_strength: float, outline_w: float, ref_dist: float, emissive_b: float) -> void:
	for entry: Dictionary in _relics:
		var mastery: int = int(entry.get("mastery", 0))
		var eff_emissive: float = emissive_b * (1.0 + float(maxi(0, mastery - 1)) * 0.35) if mastery > 0 else emissive_b * 0.45
		var mats: Array = entry["materials"] as Array
		for m_var: Variant in mats:
			var mat: ShaderMaterial = m_var as ShaderMaterial
			if mat != null:
				mat.set_shader_parameter("crease_ink_strength", crease_strength)
				mat.set_shader_parameter("emissive_boost", eff_emissive)
		var out_mat: ShaderMaterial = entry["outline_mat"] as ShaderMaterial
		if out_mat != null:
			out_mat.set_shader_parameter("outline_width", outline_w)
			out_mat.set_shader_parameter("reference_distance", ref_dist)


func apply_trim_sheet_maps(norm_tex: Texture2D, orm_tex: Texture2D, sdf_tex: Texture2D) -> void:
	var has_trim: bool = (norm_tex != null and orm_tex != null and sdf_tex != null)
	for entry: Dictionary in _relics:
		var mats: Array = entry["materials"] as Array
		for m_var: Variant in mats:
			var mat: ShaderMaterial = m_var as ShaderMaterial
			if mat != null:
				mat.set_shader_parameter("has_trim_maps", has_trim)
				if has_trim:
					mat.set_shader_parameter("trim_normal_tex", norm_tex)
					mat.set_shader_parameter("trim_orm_tex", orm_tex)
					mat.set_shader_parameter("trim_ink_sdf_tex", sdf_tex)


func apply_cosmic_lighting_tints(key_tint: Color, shadow_tint: Color, rim_col: Color) -> void:
	for entry: Dictionary in _relics:
		var mats: Array = entry["materials"] as Array
		for m_var: Variant in mats:
			var mat: ShaderMaterial = m_var as ShaderMaterial
			if mat != null:
				mat.set_shader_parameter("cosmic_key_tint", key_tint)
				mat.set_shader_parameter("cosmic_shadow_tint", shadow_tint)
				mat.set_shader_parameter("cosmic_rim_color", rim_col)


func get_demat_materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for entry: Dictionary in _relics:
		var mats: Array = entry["materials"] as Array
		for m_var: Variant in mats:
			var mat: ShaderMaterial = m_var as ShaderMaterial
			if mat != null and not out.has(mat):
				out.append(mat)
		var out_mat: ShaderMaterial = entry["outline_mat"] as ShaderMaterial
		if out_mat != null and not out.has(out_mat):
			out.append(out_mat)
	return out
