class_name PedestalVisualPresenter
extends RefCounted

## PedestalVisualPresenter.gd
## Presentador visual 3D para pedestales de pilotos en el Hangar:
## - Construcción de mallas (base cilíndrica, colisiones, torus neón, haz holográfico, luces y badges).
## - Aplicación de texturas, shaders de skins y efectos de estrellas para sprites 3D.

const SaveManager = preload("res://core/autoloads/save_manager.gd")
const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")

static func build_pedestals(hub: Node3D, roster: Array[Dictionary]) -> Array[Dictionary]:
	var vfx_data: Array[Dictionary] = []
	if not is_instance_valid(hub):
		return vfx_data

	var pedestals_group := hub.get_node_or_null("PilotPedestals")
	if not pedestals_group:
		pedestals_group = Node3D.new()
		pedestals_group.name = "PilotPedestals"
		hub.add_child(pedestals_group)

	for i in range(roster.size()):
		var char_data: Dictionary = roster[i]
		var cid: String = String(char_data["id"])
		var col: Color = char_data["color"]
		var pos: Vector3 = char_data["pedestal_pos"]

		var ped_root_name := "Pedestal_" + cid.capitalize()
		var ped_root: Node3D = pedestals_group.get_node_or_null(ped_root_name)
		if not ped_root:
			ped_root = Node3D.new()
			ped_root.name = ped_root_name
			pedestals_group.add_child(ped_root)

		ped_root.position = Vector3(pos.x, 0.0, pos.z)
		var is_unlocked := SaveManager.is_character_unlocked(char_data["id"])
		ped_root.visible = is_unlocked

		# 1. Base Cilíndrica Metálica Sci-Fi
		var base_mesh_node: MeshInstance3D = ped_root.get_node_or_null("BaseMesh")
		if not base_mesh_node:
			base_mesh_node = MeshInstance3D.new()
			base_mesh_node.name = "BaseMesh"
			var cyl := CylinderMesh.new()
			cyl.top_radius = 1.35
			cyl.bottom_radius = 1.5
			cyl.height = 0.16
			cyl.radial_segments = 36
			base_mesh_node.mesh = cyl
			base_mesh_node.position = Vector3(0, 0.08, 0)

			var base_mat := StandardMaterial3D.new()
			base_mat.albedo_color = Color(0.10, 0.12, 0.16, 1.0)
			base_mat.metallic = 0.85
			base_mat.roughness = 0.35
			base_mesh_node.material_override = base_mat
			ped_root.add_child(base_mesh_node)

		# Colisión física sólida del pedestal
		var ped_col: StaticBody3D = ped_root.get_node_or_null("PedestalCollision")
		if not ped_col:
			ped_col = StaticBody3D.new()
			ped_col.name = "PedestalCollision"
			ped_col.collision_layer = 1
			ped_col.collision_mask = 0
			var c_shape := CollisionShape3D.new()
			var cyl_shape := CylinderShape3D.new()
			cyl_shape.radius = 1.45
			cyl_shape.height = 0.16
			c_shape.shape = cyl_shape
			c_shape.position = Vector3(0, 0.08, 0)
			ped_col.add_child(c_shape)
			ped_root.add_child(ped_col)

		# 2. Anillo de Borde Neón (TorusMesh)
		var rim_node: MeshInstance3D = ped_root.get_node_or_null("RimNeon")
		var rim_mat: StandardMaterial3D = null
		if not rim_node:
			rim_node = MeshInstance3D.new()
			rim_node.name = "RimNeon"
			var torus := TorusMesh.new()
			torus.inner_radius = 1.30
			torus.outer_radius = 1.42
			torus.rings = 32
			torus.ring_segments = 16
			rim_node.mesh = torus
			rim_node.position = Vector3(0, 0.16, 0)

			rim_mat = StandardMaterial3D.new()
			rim_mat.albedo_color = col
			rim_mat.emission_enabled = true
			rim_mat.emission = col
			rim_mat.emission_energy_multiplier = 0.4
			rim_node.material_override = rim_mat
			ped_root.add_child(rim_node)
		else:
			rim_mat = rim_node.material_override as StandardMaterial3D

		# 3. Anillo Holográfico Interior Giratorio (Rotator Ring)
		var rot_node: MeshInstance3D = ped_root.get_node_or_null("RotatorRing")
		if not rot_node:
			rot_node = MeshInstance3D.new()
			rot_node.name = "RotatorRing"
			var inner_torus := TorusMesh.new()
			inner_torus.inner_radius = 0.90
			inner_torus.outer_radius = 1.05
			inner_torus.rings = 24
			inner_torus.ring_segments = 12
			rot_node.mesh = inner_torus
			rot_node.position = Vector3(0, 0.17, 0)

			var rot_mat := StandardMaterial3D.new()
			rot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			rot_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			rot_mat.albedo_color = Color(col.r, col.g, col.b, 0.7)
			rot_mat.emission_enabled = true
			rot_mat.emission = col
			rot_mat.emission_energy_multiplier = 2.0
			rot_node.material_override = rot_mat
			rot_node.visible = false
			ped_root.add_child(rot_node)

		# 4. Haz Vertical Holográfico (Holo Beam)
		var beam_node: MeshInstance3D = ped_root.get_node_or_null("HoloBeam")
		var beam_mat: StandardMaterial3D = null
		if not beam_node:
			beam_node = MeshInstance3D.new()
			beam_node.name = "HoloBeam"
			var beam_cyl := CylinderMesh.new()
			beam_cyl.top_radius = 1.15
			beam_cyl.bottom_radius = 1.32
			beam_cyl.height = 2.7
			beam_cyl.radial_segments = 32
			beam_cyl.cap_top = false
			beam_cyl.cap_bottom = false
			beam_node.mesh = beam_cyl
			beam_node.position = Vector3(0, 1.45, 0)

			beam_mat = StandardMaterial3D.new()
			beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			beam_mat.albedo_color = Color(col.r, col.g, col.b, 0.16)
			beam_mat.emission_enabled = true
			beam_mat.emission = col
			beam_mat.emission_energy_multiplier = 1.5
			beam_node.material_override = beam_mat
			beam_node.visible = false
			ped_root.add_child(beam_node)
		else:
			beam_mat = beam_node.material_override as StandardMaterial3D

		# 5. Foco Dinámico OmniLight3D
		var light_node: OmniLight3D = ped_root.get_node_or_null("PedestalLight")
		if not light_node:
			light_node = OmniLight3D.new()
			light_node.name = "PedestalLight"
			light_node.position = Vector3(0, 0.6, 0)
			light_node.light_color = col
			light_node.omni_range = 4.2
			light_node.light_energy = 0.0
			light_node.visible = false
			ped_root.add_child(light_node)

		# 6. Badge Holográfico Flotante
		var badge_node: Label3D = ped_root.get_node_or_null("ActiveBadge")
		if not badge_node:
			badge_node = Label3D.new()
			badge_node.name = "ActiveBadge"
			badge_node.position = Vector3(0, 2.85, 0)
			badge_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			badge_node.no_depth_test = false
			badge_node.text = "✦ EN DESPLIEGUE ✦"
			badge_node.font_size = 22
			badge_node.outline_size = 8
			badge_node.outline_modulate = Color("#0A0A0E")
			badge_node.modulate = col
			badge_node.visible = false
			ped_root.add_child(badge_node)

		vfx_data.append({
			"ped_root": ped_root,
			"rim_mat": rim_mat,
			"rotator_ring": rot_node,
			"holo_beam": beam_node,
			"holo_beam_mat": beam_mat,
			"omni_light": light_node,
			"floating_badge": badge_node,
			"color": col
		})

	return vfx_data

static func apply_skin_to_sprite(sprite: Sprite3D, char_id: String, is_right_side: bool) -> void:
	if not is_instance_valid(sprite):
		return

	var slot_key := "pilot:" + char_id
	var equipped_skin := SaveManager.get_equipped_skin(slot_key)
	if equipped_skin != "" and SaveManager.is_skin_unlocked(equipped_skin):
		var stars := SaveManager.get_skin_stars(equipped_skin)
		var skin_info: Dictionary = CosmeticsManager.get_skin(equipped_skin)
		var tex_path: String = skin_info.get("flipped_texture_path", "") if is_right_side else skin_info.get("texture_path", "")
		if tex_path.is_empty():
			tex_path = skin_info.get("texture_path", "")
		var custom_tex := CosmeticsManager.load_texture(tex_path)
		if custom_tex:
			sprite.texture = custom_tex
		if stars > 1:
			var spatial_shader = load("res://shaders/skin_glow_spatial.gdshader")
			if spatial_shader:
				var mat := ShaderMaterial.new()
				mat.shader = spatial_shader
				mat.set_shader_parameter("texture_albedo", sprite.texture)
				var mask_path := ("res://assets/characters/fullbody/%sBack_skin_mask.jpg" % char_id.capitalize()) if is_right_side else ("res://assets/characters/fullbody/%s_skin_mask.jpg" % char_id.capitalize())
				if ResourceLoader.exists(mask_path):
					var mask_tex = load(mask_path)
					if mask_tex:
						mat.set_shader_parameter("skin_mask", mask_tex)
				mat.set_shader_parameter("star_level", stars)
				var glow_hex: String = skin_info.get("glow_hex", "#00F0FF")
				var accent_hex: String = skin_info.get("accent_hex", "#FF007F")
				mat.set_shader_parameter("glow_color", Color.from_string(glow_hex, Color.CYAN))
				mat.set_shader_parameter("accent_color", Color.from_string(accent_hex, Color.MAGENTA))
				mat.set_shader_parameter("glow_intensity", 1.8 if stars >= 3 else 1.2)
				mat.set_shader_parameter("pulse_speed", 3.0 if stars >= 3 else 2.0)
				sprite.material_override = mat
		else:
			sprite.material_override = null
	else:
		var fullbody_tex := ("res://assets/characters/fullbody/fullbody_%s_flipped.png" % char_id) if is_right_side else ("res://assets/characters/fullbody/fullbody_%s.png" % char_id)
		if ResourceLoader.exists(fullbody_tex):
			sprite.texture = load(fullbody_tex)
		else:
			var portrait_tex := "res://assets/portraits/portrait_%s.png" % char_id
			if ResourceLoader.exists(portrait_tex):
				sprite.texture = load(portrait_tex)
		sprite.material_override = null
