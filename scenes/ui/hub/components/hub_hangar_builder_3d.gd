class_name HubHangarBuilder3D
extends Node

## Constructor de geometría 3D, paredes, colisionadores estáticos y parallax para el Hangar Espacial.

var hub: Node3D = null

func setup(p_hub: Node3D) -> void:
	hub = p_hub

func setup_environment_collisions() -> void:
	if not is_instance_valid(hub):
		return

	# 1. Terminal Central de Misiones (Arcade Cabinet)
	var mission_term: Node3D = hub.get_node_or_null("Terminals/MissionTerminal")
	if mission_term:
		ensure_static_box_collider(mission_term, Vector3(1.6, 2.2, 1.4), Vector3(0.0, 1.1, 0.0))

	# 2. Terminal de Récords (Arcade Cabinet)
	var highscores_term: Node3D = hub.get_node_or_null("Terminals/HighScoresTerminal")
	if highscores_term:
		ensure_static_box_collider(highscores_term, Vector3(1.6, 2.2, 1.4), Vector3(0.0, 1.1, 0.0))

	# 3. Terminal de Gacha / Máquina de Garras
	var gacha_claw: Node3D = hub.get_node_or_null("SpaceParallax/claw-machine2")
	if gacha_claw:
		ensure_static_box_collider(gacha_claw, Vector3(0.55, 0.8, 0.5), Vector3(0.0, 0.4, 0.0))
	var gacha_term: Node3D = hub.get_node_or_null("Terminals/GachaTerminal")
	if gacha_term and not gacha_claw:
		ensure_static_box_collider(gacha_term, Vector3(1.6, 2.4, 1.5), Vector3(0.0, 1.2, 0.0))

	# 4. Vehículo Rover Espacial
	var rover_node: Node3D = hub.get_node_or_null("rover")
	if rover_node:
		ensure_static_box_collider(rover_node, Vector3(0.32, 0.38, 0.36), Vector3(0.0, 0.19, 0.0))

	# 5. Generador Eléctrico Sci-Fi
	var gen_node: Node3D = hub.get_node_or_null("machine_generator")
	if gen_node:
		ensure_static_box_collider(gen_node, Vector3(0.52, 0.42, 0.42), Vector3(0.0, 0.20, 0.0))

	# 6. Muros Perimetrales del Hangar (Bloqueo físico de 2m de espesor y 8m de alto para ambos hangares Z in [-9.5, 43.6])
	var hangar: Node3D = hub.get_node_or_null("HangarRoom")
	if hangar:
		setup_perimeter_wall(hangar, "LeftWall", Vector3(-12.5, 3.0, 17.0), Vector3(2.0, 8.0, 58.0))
		setup_perimeter_wall(hangar, "RightWall", Vector3(12.5, 3.0, 17.0), Vector3(2.0, 8.0, 58.0))
		setup_perimeter_wall(hangar, "BackWall", Vector3(0.0, 3.0, 43.6), Vector3(28.0, 8.0, 2.0))
		setup_perimeter_wall(hangar, "FrontWall", Vector3(0.0, 3.0, -9.5), Vector3(28.0, 8.0, 2.0))

func build_mirrored_hangar_wing() -> void:
	if not is_instance_valid(hub):
		return
	var hangar: Node3D = hub.get_node_or_null("HangarRoom")
	if not hangar:
		return

	if hangar.get_node_or_null("MirroredWing"):
		build_south_parallax()
		return

	var wing := Node3D.new()
	wing.name = "MirroredWing"
	hangar.add_child(wing)

	if ResourceLoader.exists("res://scratch/downloads/space_kit/Models/OBJ format/hangar_smallA.obj"):
		var hangar_mesh_res = load("res://scratch/downloads/space_kit/Models/OBJ format/hangar_smallA.obj")
		if hangar_mesh_res:
			var south_roof := MeshInstance3D.new()
			south_roof.name = "SouthHangarRoofMesh"
			south_roof.mesh = hangar_mesh_res as Mesh
			south_roof.transform = Transform3D(
				Basis.from_euler(Vector3(0.0, PI, 0.0)).scaled(Vector3(16.0, 16.0, 16.0)),
				Vector3(-0.042, -15.725, 33.704)
			)
			wing.add_child(south_roof)

	var wall_res: PackedScene = load("res://assets/models/kenney_modular_space/template-wall.glb") as PackedScene
	var wall_detail_res: PackedScene = load("res://assets/models/kenney_modular_space/template-wall-detail-a.glb") as PackedScene
	var wall_window_res: PackedScene = load("res://assets/models/kenney_mini_arcade/wall-window.glb") as PackedScene
	var corner_res: PackedScene = load("res://assets/models/kenney_modular_space/template-wall-corner.glb") as PackedScene

	var left_positions: Array[float] = [39.57, 34.57, 29.57, 24.57, 19.57]
	for idx in range(left_positions.size()):
		var z_pos: float = left_positions[idx]
		var seg_scene: PackedScene = wall_detail_res if (idx % 2 == 1) else wall_res
		if seg_scene:
			var seg: Node3D = seg_scene.instantiate() as Node3D
			seg.name = "South_LeftWall_Seg%d" % idx
			seg.transform = Transform3D(
				Basis(Vector3(0.0, 0.0, 1.3), Vector3(0.0, 1.35, 0.0), Vector3(-1.3, 0.0, 0.0)),
				Vector3(-12.915, 0.215, z_pos)
			)
			wing.add_child(seg)

	var right_positions: Array[float] = [39.56, 34.56, 29.56, 24.56, 19.56]
	for idx in range(right_positions.size()):
		var z_pos: float = right_positions[idx]
		var seg_scene: PackedScene = wall_detail_res if (idx % 2 == 1) else wall_res
		if seg_scene:
			var seg: Node3D = seg_scene.instantiate() as Node3D
			seg.name = "South_RightWall_Seg%d" % idx
			seg.transform = Transform3D(
				Basis(Vector3(0.0, 0.0, -1.3), Vector3(0.0, 1.35, 0.0), Vector3(1.3, 0.0, 0.0)),
				Vector3(12.892, 0.1, z_pos)
			)
			wing.add_child(seg)

	if corner_res:
		var c_bl: Node3D = corner_res.instantiate() as Node3D
		c_bl.name = "South_Corner_BL"
		c_bl.transform = Transform3D(
			Basis(Vector3(1.3, 0.0, 0.0), Vector3(0.0, 1.35, 0.0), Vector3(0.0, 0.0, 1.3)),
			Vector3(-12.4, 0.0, 43.1)
		)
		wing.add_child(c_bl)

		var c_br: Node3D = corner_res.instantiate() as Node3D
		c_br.name = "South_Corner_BR"
		c_br.transform = Transform3D(
			Basis(Vector3(0.0, 0.0, 1.3), Vector3(0.0, 1.35, 0.0), Vector3(-1.3, 0.0, 0.0)),
			Vector3(12.4, 0.0, 43.1)
		)
		wing.add_child(c_br)

	if wall_window_res:
		var south_win: Node3D = wall_window_res.instantiate() as Node3D
		south_win.name = "SouthWallWindow"
		south_win.transform = Transform3D(
			Basis.from_euler(Vector3(0.0, PI, 0.0)).scaled(Vector3(17.0, 17.0, 17.0)),
			Vector3(-0.398, 0.848, 43.6)
		)
		wing.add_child(south_win)

	var rail_mesh: BoxMesh = BoxMesh.new()
	rail_mesh.size = Vector3(26.0, 1.2, 0.5)
	var rail_mat: StandardMaterial3D = StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.9, 0.92, 0.96, 1.0)
	rail_mat.metallic = 0.9
	rail_mat.roughness = 0.2
	rail_mat.emission_enabled = true
	rail_mat.emission = Color(0.0, 0.94, 1.0, 1.0)
	rail_mat.emission_energy_multiplier = 0.8
	rail_mesh.material = rail_mat

	var south_railing_mesh := MeshInstance3D.new()
	south_railing_mesh.name = "SouthFrontRailingMesh"
	south_railing_mesh.mesh = rail_mesh
	south_railing_mesh.position = Vector3(0.0, 0.816, 43.1)
	wing.add_child(south_railing_mesh)

	build_south_parallax()

func build_south_parallax() -> void:
	if not is_instance_valid(hub):
		return
	var existing_sp := hub.get_node_or_null("SpaceParallax_South")
	if existing_sp:
		if "parallax_south_deep" in hub and not hub.get("parallax_south_deep"):
			hub.set("parallax_south_deep", existing_sp.get_node_or_null("Layer0_Deep_South") as MeshInstance3D)
		if "parallax_south_mid" in hub and not hub.get("parallax_south_mid"):
			hub.set("parallax_south_mid", existing_sp.get_node_or_null("Layer1_Mid_South") as MeshInstance3D)
		if "parallax_south_near" in hub and not hub.get("parallax_south_near"):
			hub.set("parallax_south_near", existing_sp.get_node_or_null("Layer2_Near_South") as MeshInstance3D)
		return

	var south_px := Node3D.new()
	south_px.name = "SpaceParallax_South"
	hub.add_child(south_px)

	var tex0: Texture2D = load("res://assets/environments/space_parallax/space_parallax_layer0_deep.png") as Texture2D
	var tex1: Texture2D = load("res://assets/environments/space_parallax/space_parallax_layer1_mid.png") as Texture2D
	var tex2: Texture2D = load("res://assets/environments/space_parallax/space_parallax_layer2_near.png") as Texture2D

	var rot180_basis := Basis.from_euler(Vector3(0.0, PI, 0.0))

	var mat0 := StandardMaterial3D.new()
	mat0.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat0.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat0.albedo_texture = tex0
	var qmesh0 := QuadMesh.new()
	qmesh0.size = Vector2(380.0, 210.0)
	qmesh0.material = mat0
	var p_deep := MeshInstance3D.new()
	p_deep.name = "Layer0_Deep_South"
	p_deep.mesh = qmesh0
	p_deep.transform = Transform3D(rot180_basis, Vector3(0.0, 10.0, 128.0))
	south_px.add_child(p_deep)
	if "parallax_south_deep" in hub:
		hub.set("parallax_south_deep", p_deep)

	var mat1 := StandardMaterial3D.new()
	mat1.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat1.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat1.albedo_texture = tex1
	var qmesh1 := QuadMesh.new()
	qmesh1.size = Vector2(260.0, 145.0)
	qmesh1.material = mat1
	var p_mid := MeshInstance3D.new()
	p_mid.name = "Layer1_Mid_South"
	p_mid.mesh = qmesh1
	p_mid.transform = Transform3D(rot180_basis, Vector3(0.0, 6.0, 92.0))
	south_px.add_child(p_mid)
	if "parallax_south_mid" in hub:
		hub.set("parallax_south_mid", p_mid)

	var mat2 := StandardMaterial3D.new()
	mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat2.albedo_texture = tex2
	var qmesh2 := QuadMesh.new()
	qmesh2.size = Vector2(180.0, 100.0)
	qmesh2.material = mat2
	var p_near := MeshInstance3D.new()
	p_near.name = "Layer2_Near_South"
	p_near.mesh = qmesh2
	p_near.transform = Transform3D(rot180_basis, Vector3(0.0, 4.1, 64.0))
	south_px.add_child(p_near)
	if "parallax_south_near" in hub:
		hub.set("parallax_south_near", p_near)

func setup_perimeter_wall(parent: Node3D, wall_name: String, pos: Vector3, box_size: Vector3) -> void:
	var wall: StaticBody3D = parent.get_node_or_null(wall_name)
	if not wall:
		wall = StaticBody3D.new()
		wall.name = wall_name
		parent.add_child(wall)
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = pos

	var cshape: CollisionShape3D = wall.get_node_or_null("CollisionShape3D")
	if not cshape:
		cshape = CollisionShape3D.new()
		cshape.name = "CollisionShape3D"
		wall.add_child(cshape)

	var box := BoxShape3D.new()
	box.size = box_size
	cshape.shape = box
	cshape.position = Vector3.ZERO

func ensure_static_box_collider(parent: Node3D, box_size: Vector3, center_pos: Vector3) -> void:
	if not parent:
		return
	var existing: StaticBody3D = parent.get_node_or_null("EnvironmentCollision")
	if not existing:
		existing = StaticBody3D.new()
		existing.name = "EnvironmentCollision"
		parent.add_child(existing)
	existing.collision_layer = 1
	existing.collision_mask = 0

	var cshape: CollisionShape3D = existing.get_node_or_null("CollisionShape3D")
	if not cshape:
		cshape = CollisionShape3D.new()
		cshape.name = "CollisionShape3D"
		existing.add_child(cshape)

	var box := BoxShape3D.new()
	box.size = box_size
	cshape.shape = box
	cshape.position = center_pos

func ensure_static_cylinder_collider(parent: Node3D, radius: float, height: float, center_pos: Vector3) -> void:
	if not parent:
		return
	var existing: StaticBody3D = parent.get_node_or_null("EnvironmentCollision")
	if not existing:
		existing = StaticBody3D.new()
		existing.name = "EnvironmentCollision"
		existing.collision_layer = 1
		existing.collision_mask = 0
		var cshape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = radius
		cyl.height = height
		cshape.shape = cyl
		cshape.position = center_pos
		existing.add_child(cshape)
		parent.add_child(existing)
