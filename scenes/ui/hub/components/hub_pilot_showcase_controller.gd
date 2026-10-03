class_name HubPilotShowcaseController
extends Node

## Controlador de pedestales 3D, VFX de selección, sprites billboarding y personalización de skins para los pilotos del Hangar.

var hub: Node3D = null
var current_pilot_index: int = 0
var sprite_nodes: Array[Sprite3D] = []
var pilot_vfx_data: Array[Dictionary] = []
var interactable_nodes: Array[HubInteractable3D] = []
var _pilot_tweens: Array[Tween] = []

func setup(p_hub: Node3D) -> void:
	hub = p_hub

func build_pilot_pedestals_and_vfx(roster: Array[Dictionary]) -> void:
	if not is_instance_valid(hub):
		return
	var pedestals_group := hub.get_node_or_null("PilotPedestals")
	if not pedestals_group:
		pedestals_group = Node3D.new()
		pedestals_group.name = "PilotPedestals"
		hub.add_child(pedestals_group)

	pilot_vfx_data.clear()

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

		# Colisión física sólida del pedestal (plataforma baja de 0.16m para step-up/slopes)
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

		pilot_vfx_data.append({
			"ped_root": ped_root,
			"rim_mat": rim_mat,
			"rotator_ring": rot_node,
			"holo_beam": beam_node,
			"holo_beam_mat": beam_mat,
			"omni_light": light_node,
			"floating_badge": badge_node,
			"color": col
		})

func collect_and_verify_sprites(roster: Array[Dictionary]) -> void:
	if not is_instance_valid(hub):
		return
	sprite_nodes.clear()
	var roster_group := hub.get_node_or_null("RosterCutouts")
	if not roster_group:
		roster_group = Node3D.new()
		roster_group.name = "RosterCutouts"
		hub.add_child(roster_group)

	for i in range(roster.size()):
		var char_data: Dictionary = roster[i]
		var char_id: String = String(char_data["id"])
		var sprite_name := "Cutout_" + char_id.capitalize()
		var sprite: Sprite3D = roster_group.get_node_or_null(sprite_name)
		if not sprite:
			sprite = Sprite3D.new()
			sprite.name = sprite_name
			roster_group.add_child(sprite)

		var old_shadow := roster_group.get_node_or_null("Shadow_" + char_id.capitalize())
		if old_shadow:
			old_shadow.queue_free()

		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		sprite.position = char_data["pedestal_pos"]

		var is_right_side: bool = char_data["pedestal_pos"].x > 0.0
		var fullbody_tex := ("res://assets/characters/fullbody/fullbody_%s_flipped.png" % char_id) if is_right_side else ("res://assets/characters/fullbody/fullbody_%s.png" % char_id)
		if ResourceLoader.exists(fullbody_tex):
			sprite.texture = load(fullbody_tex)
			sprite.pixel_size = 0.0013
			sprite.offset = Vector2(0, 800)
		else:
			var portrait_tex := "res://assets/portraits/portrait_%s.png" % char_id
			if ResourceLoader.exists(portrait_tex):
				sprite.texture = load(portrait_tex)
				sprite.pixel_size = 0.005
				sprite.offset = Vector2(0, 256)

		var is_unlocked := SaveManager.is_character_unlocked(char_data["id"])
		sprite.visible = is_unlocked
		if is_unlocked:
			var slot_key := "pilot:" + char_id
			var equipped_skin := SaveManager.get_equipped_skin(slot_key)
			if equipped_skin != "" and SaveManager.is_skin_unlocked(equipped_skin):
				var stars := SaveManager.get_skin_stars(equipped_skin)
				var CosmeticsManagerScript = preload("res://core/systems/cosmetics_manager.gd")
				var skin_info: Dictionary = CosmeticsManagerScript.get_skin(equipped_skin)
				var tex_path: String = skin_info.get("flipped_texture_path", "") if is_right_side else skin_info.get("texture_path", "")
				if tex_path.is_empty():
					tex_path = skin_info.get("texture_path", "")
				var custom_tex := CosmeticsManagerScript.load_texture(tex_path)
				if custom_tex:
					sprite.texture = custom_tex
				if stars > 1:
					var spatial_shader = load("res://shaders/skin_glow_spatial.gdshader")
					if spatial_shader:
						var mat := ShaderMaterial.new()
						mat.shader = spatial_shader
						mat.set_shader_parameter("texture_albedo", sprite.texture)
						mat.set_shader_parameter("star_level", stars)
						var glow_hex: String = skin_info.get("glow_hex", "#00F0FF")
						var accent_hex: String = skin_info.get("accent_hex", "#FF007F")
						mat.set_shader_parameter("glow_color", Color.from_string(glow_hex, Color.CYAN))
						mat.set_shader_parameter("accent_color", Color.from_string(accent_hex, Color.MAGENTA))
						mat.set_shader_parameter("glow_intensity", 1.8 if stars >= 3 else 1.2)
						mat.set_shader_parameter("pulse_speed", 3.0 if stars >= 3 else 2.0)
						sprite.material_override = mat

		var platform_ped: Node3D = hub.get_node_or_null("PilotPedestals/Pedestal_" + char_id.capitalize())
		if platform_ped:
			platform_ped.visible = is_unlocked
		var old_ped: Node3D = hub.get_node_or_null("Pedestals/Pedestal_" + char_id.capitalize())
		if old_ped:
			old_ped.visible = is_unlocked

		sprite_nodes.append(sprite)

func setup_interactables(roster: Array[Dictionary], callback: Callable) -> void:
	if not is_instance_valid(hub):
		return
	var roster_group := hub.get_node_or_null("RosterCutouts")
	if not roster_group:
		return

	interactable_nodes.clear()

	for i in range(roster.size()):
		var char_data: Dictionary = roster[i]
		var cid: StringName = char_data["id"]
		var is_unlocked := SaveManager.is_character_unlocked(cid)
		var interact_name := "Interactable_" + String(cid).capitalize()
		var inter: Area3D = roster_group.get_node_or_null(interact_name)
		if not inter:
			var inter_script = load("res://scenes/ui/hub/hub_interactable_3d.gd")
			inter = inter_script.new()
			inter.name = interact_name
			inter.set("target_character_id", cid)
			inter.set("interaction_title", "Árbol de Habilidades")
			inter.position = char_data["pedestal_pos"]
			roster_group.add_child(inter)

		inter.visible = is_unlocked
		inter.monitoring = is_unlocked
		inter.monitorable = is_unlocked

		if inter is HubInteractable3D:
			interactable_nodes.append(inter as HubInteractable3D)

		if inter and not inter.interacted.is_connected(callback):
			inter.interacted.connect(callback)

func update_interactable_prompts(roster: Array[Dictionary], active_index: int) -> void:
	current_pilot_index = active_index
	for i in range(interactable_nodes.size()):
		var inter: HubInteractable3D = interactable_nodes[i]
		if not is_instance_valid(inter) or not is_instance_valid(inter.label_3d):
			continue
		var char_data: Dictionary = roster[i]
		var cname: String = String(char_data["name"]).capitalize()
		if i == current_pilot_index:
			inter.label_3d.text = "[E] Árbol de Habilidades: %s [ACTIVA]" % cname
			inter.label_3d.modulate = char_data["color"]
		else:
			inter.label_3d.text = "[E] Seleccionar a %s" % cname
			inter.label_3d.modulate = Color(0.85, 0.88, 0.95, 0.9)

func refresh_pedestal_skins(roster: Array[Dictionary]) -> void:
	for i in range(min(roster.size(), sprite_nodes.size())):
		var char_data: Dictionary = roster[i]
		var cid: String = String(char_data["id"])
		var sprite := sprite_nodes[i]
		if not is_instance_valid(sprite):
			continue
		var is_unlocked := SaveManager.is_character_unlocked(char_data["id"])
		sprite.visible = is_unlocked
		if not is_unlocked:
			continue
		var is_right_side: bool = char_data.get("pedestal_pos", Vector3.ZERO).x > 0.0
		var slot_key := "pilot:" + cid
		var equipped_skin := SaveManager.get_equipped_skin(slot_key)
		if equipped_skin != "" and SaveManager.is_skin_unlocked(equipped_skin):
			var stars := SaveManager.get_skin_stars(equipped_skin)
			var CosmeticsManagerScript = preload("res://core/systems/cosmetics_manager.gd")
			var skin_info: Dictionary = CosmeticsManagerScript.get_skin(equipped_skin)
			var tex_path: String = skin_info.get("flipped_texture_path", "") if is_right_side else skin_info.get("texture_path", "")
			if tex_path.is_empty():
				tex_path = skin_info.get("texture_path", "")
			var custom_tex := CosmeticsManagerScript.load_texture(tex_path)
			if custom_tex:
				sprite.texture = custom_tex
			if stars > 1:
				var spatial_shader = load("res://shaders/skin_glow_spatial.gdshader")
				if spatial_shader:
					var mat := ShaderMaterial.new()
					mat.shader = spatial_shader
					mat.set_shader_parameter("texture_albedo", sprite.texture)
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
			var fullbody_tex := ("res://assets/characters/fullbody/fullbody_%s_flipped.png" % cid) if is_right_side else ("res://assets/characters/fullbody/fullbody_%s.png" % cid)
			if ResourceLoader.exists(fullbody_tex):
				sprite.texture = load(fullbody_tex)
			else:
				var portrait_tex := "res://assets/portraits/portrait_%s.png" % cid
				if ResourceLoader.exists(portrait_tex):
					sprite.texture = load(portrait_tex)
			sprite.material_override = null

func select_pilot_visuals(index: int, roster: Array[Dictionary]) -> void:
	current_pilot_index = index
	clean_tweens()

	for i in range(sprite_nodes.size()):
		var sp := sprite_nodes[i]
		if not is_instance_valid(sp):
			continue
		var tw := hub.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_pilot_tweens.append(tw)
		if i == index:
			tw.tween_property(sp, "scale", Vector3(1.2, 1.2, 1.2), 0.35)
			sp.modulate = Color(1.3, 1.3, 1.3, 1.0)
		else:
			tw.tween_property(sp, "scale", Vector3.ONE, 0.25)
			sp.modulate = Color(0.75, 0.75, 0.85, 0.85)

	# Actualizar VFX de pedestales 3D
	for i in range(pilot_vfx_data.size()):
		var vfx: Dictionary = pilot_vfx_data[i]
		var beam: MeshInstance3D = vfx.get("holo_beam")
		var rim_mat: StandardMaterial3D = vfx.get("rim_mat")
		var rot_ring: MeshInstance3D = vfx.get("rotator_ring")
		var light: OmniLight3D = vfx.get("omni_light")
		var badge: Label3D = vfx.get("floating_badge")

		if i == index:
			if beam and is_instance_valid(beam):
				beam.visible = true
				beam.scale = Vector3(1.0, 0.0, 1.0)
				var tw_beam := hub.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw_beam.tween_property(beam, "scale:y", 1.0, 0.35)
				_pilot_tweens.append(tw_beam)

			if rim_mat:
				var tw_rim := hub.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw_rim.tween_property(rim_mat, "emission_energy_multiplier", 3.2, 0.35)
				_pilot_tweens.append(tw_rim)

			if light and is_instance_valid(light):
				light.visible = true
				var tw_light := hub.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw_light.tween_property(light, "light_energy", 2.6, 0.35)
				_pilot_tweens.append(tw_light)

			if rot_ring and is_instance_valid(rot_ring):
				rot_ring.visible = true

			if badge and is_instance_valid(badge):
				badge.visible = true
				badge.scale = Vector3(0.2, 0.2, 0.2)
				var tw_badge := hub.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw_badge.tween_property(badge, "scale", Vector3.ONE, 0.3)
				_pilot_tweens.append(tw_badge)
		else:
			if beam and is_instance_valid(beam) and beam.visible:
				var tw_beam_off := hub.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tw_beam_off.tween_property(beam, "scale:y", 0.0, 0.2)
				tw_beam_off.tween_callback(func(): if is_instance_valid(beam): beam.visible = false)
				_pilot_tweens.append(tw_beam_off)

			if rim_mat:
				var tw_rim_off := hub.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tw_rim_off.tween_property(rim_mat, "emission_energy_multiplier", 0.4, 0.25)
				_pilot_tweens.append(tw_rim_off)

			if light and is_instance_valid(light) and light.visible:
				var tw_light_off := hub.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tw_light_off.tween_property(light, "light_energy", 0.0, 0.25)
				tw_light_off.tween_callback(func(): if is_instance_valid(light): light.visible = false)
				_pilot_tweens.append(tw_light_off)

			if rot_ring and is_instance_valid(rot_ring):
				rot_ring.visible = false

			if badge and is_instance_valid(badge):
				badge.visible = false

	update_interactable_prompts(roster, index)

func process_vfx(delta: float, idle_time: float) -> void:
	if current_pilot_index >= 0 and current_pilot_index < pilot_vfx_data.size():
		var active_vfx: Dictionary = pilot_vfx_data[current_pilot_index]
		var rot_ring: MeshInstance3D = active_vfx.get("rotator_ring")
		if rot_ring and is_instance_valid(rot_ring) and rot_ring.visible:
			rot_ring.rotation.y += delta * 2.2
		var beam: MeshInstance3D = active_vfx.get("holo_beam")
		if beam and is_instance_valid(beam) and beam.visible:
			var pulse: float = 1.0 + sin(idle_time * 3.5) * 0.04
			beam.scale.x = pulse
			beam.scale.z = pulse
		var badge: Label3D = active_vfx.get("floating_badge")
		if badge and is_instance_valid(badge) and badge.visible:
			badge.position.y = 2.8 + sin(idle_time * 2.8) * 0.06

func clean_tweens() -> void:
	for tw in _pilot_tweens:
		if is_instance_valid(tw) and tw.is_running():
			tw.kill()
	_pilot_tweens.clear()

func build_pilot_selector_buttons(container: HBoxContainer, roster: Array[Dictionary], select_callback: Callable, card: PanelContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
	for i in range(roster.size()):
		var data: Dictionary = roster[i]
		if not SaveManager.is_character_unlocked(data["id"]):
			continue
		var btn := Button.new()
		btn.text = String(data["name"]).substr(0, 3).to_upper()
		btn.custom_minimum_size = Vector2(52, 34)
		btn.add_theme_font_size_override("font_size", 11)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#0A0A0E")
		sb.border_width_left = 3
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(data["color"])
		sb.set_corner_radius_all(0)
		btn.add_theme_stylebox_override("normal", sb)
		btn.pressed.connect(func():
			select_callback.call(i, true)
			if card:
				card.visible = true
		)
		container.add_child(btn)

