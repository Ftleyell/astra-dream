class_name HubTrophyRoomManager
extends Node

## Gestor de la Sala de Trofeos Ceremonial en el Ala Sur del Hangar:
## Pedestales, hologramas rotatorios, modal de detalles de trofeos y consumo de Materia Oscura.

const COLOR_DARK_MATTER := Color("#BF00FF")

var hub: Node3D = null
var trophy_modal: TrophyDetailsModal = null
var trophy_holo_nodes: Array[MeshInstance3D] = []

func setup(p_hub: Node3D) -> void:
	hub = p_hub

func setup_trophy_room() -> void:
	if not is_instance_valid(hub):
		return

	# 1. Instanciar modal de detalles de trofeos si no existe
	if not trophy_modal:
		var modal_scene := load("res://scenes/ui/hub/trophy_details_modal.tscn") as PackedScene
		if modal_scene:
			trophy_modal = modal_scene.instantiate() as TrophyDetailsModal
			var ui_root := hub.get_node_or_null("HubUI")
			if ui_root:
				ui_root.add_child(trophy_modal)
			else:
				hub.add_child(trophy_modal)
			if trophy_modal:
				trophy_modal.modal_closed.connect(_on_modal_closed)
				trophy_modal.trophy_upgraded.connect(_on_trophy_upgraded)

	# 2. Configurar pedestales e interactuables 3D en el Ala Sur ceremonial (Z = 30.2)
	var trophy_group := hub.get_node_or_null("TrophyRoom")
	if not trophy_group:
		trophy_group = Node3D.new()
		trophy_group.name = "TrophyRoom"
		hub.add_child(trophy_group)

	trophy_holo_nodes.clear()

	var trophies_spec: Array[Dictionary] = [
		{"id": &"trophy_boss_aegis", "title": "Nodriza Aegis", "pos": Vector3(-3.2, 0.16, 28.6), "mesh_type": "prism"},
		{"id": &"trophy_biosphere_core", "title": "Núcleo Bio-Planeta", "pos": Vector3(-1.8, 0.16, 31.6), "mesh_type": "sphere"},
		{"id": &"trophy_cryo_core", "title": "Núcleo Criogénico", "pos": Vector3(0.0, 0.16, 32.4), "mesh_type": "cylinder"},
		{"id": &"trophy_volcanic_core", "title": "Núcleo Volcánico", "pos": Vector3(1.8, 0.16, 31.6), "mesh_type": "box"},
		{"id": &"trophy_monolith_master", "title": "Reliquia Monolito", "pos": Vector3(3.2, 0.16, 28.6), "mesh_type": "prism"}
	]

	var inter_script = load("res://scenes/ui/hub/hub_interactable_3d.gd")

	for spec in trophies_spec:
		var tid: StringName = spec["id"]
		var p_name := "Pedestal_" + String(tid)
		var p_node := trophy_group.get_node_or_null(p_name)
		if not p_node:
			p_node = Node3D.new()
			p_node.name = p_name
			trophy_group.add_child(p_node)

		p_node.position = spec["pos"]

		# Purgar cualquier HoloMesh duplicado residual
		var extra_holos: Array[Node] = []
		for child in p_node.get_children():
			if child is MeshInstance3D and child.name.begins_with("HoloMesh"):
				extra_holos.append(child)
		while extra_holos.size() > 1:
			var duplicate_node: Node = extra_holos.pop_back()
			p_node.remove_child(duplicate_node)
			duplicate_node.queue_free()

		# Pedestal visual
		var base_mesh: MeshInstance3D = p_node.get_node_or_null("BaseMesh")
		if not base_mesh:
			base_mesh = MeshInstance3D.new()
			base_mesh.name = "BaseMesh"
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.55
			cyl.bottom_radius = 0.65
			cyl.height = 0.4
			base_mesh.mesh = cyl
			p_node.add_child(base_mesh)

		# Colisión sólida del pedestal de trofeo
		var trophy_col: StaticBody3D = p_node.get_node_or_null("TrophyCollision")
		if not trophy_col:
			trophy_col = StaticBody3D.new()
			trophy_col.name = "TrophyCollision"
			trophy_col.collision_layer = 1
			trophy_col.collision_mask = 0
			var t_col_shape := CollisionShape3D.new()
			var t_cyl_shape := CylinderShape3D.new()
			t_cyl_shape.radius = 0.65
			t_cyl_shape.height = 0.4
			t_col_shape.shape = t_cyl_shape
			t_col_shape.position = Vector3(0, 0.04, 0)
			trophy_col.add_child(t_col_shape)
			p_node.add_child(trophy_col)

		# Holograma rotatorio único
		var holo_mesh: MeshInstance3D = p_node.get_node_or_null("HoloMesh")
		if not holo_mesh:
			holo_mesh = MeshInstance3D.new()
			holo_mesh.name = "HoloMesh"
			holo_mesh.position = Vector3(0, 0.8, 0)
			match spec["mesh_type"]:
				"prism":
					var pm := PrismMesh.new()
					pm.size = Vector3(0.45, 0.45, 0.45)
					holo_mesh.mesh = pm
				"sphere":
					var sm := SphereMesh.new()
					sm.radius = 0.25
					sm.height = 0.5
					holo_mesh.mesh = sm
				"cylinder":
					var cm := CylinderMesh.new()
					cm.top_radius = 0.25
					cm.bottom_radius = 0.25
					cm.height = 0.45
					holo_mesh.mesh = cm
				"box":
					var bm := BoxMesh.new()
					bm.size = Vector3(0.45, 0.45, 0.45)
					holo_mesh.mesh = bm
			p_node.add_child(holo_mesh)

		if holo_mesh and not trophy_holo_nodes.has(holo_mesh):
			trophy_holo_nodes.append(holo_mesh)

		# Interactuable 3D
		var inter_node = p_node.get_node_or_null("Interactable_" + String(tid))
		if not inter_node:
			var inter = inter_script.new()
			inter.name = "Interactable_" + String(tid)
			inter.target_character_id = tid
			inter.interaction_title = "Trofeo: " + spec["title"]
			inter.interaction_radius = 2.2
			inter.prompt_offset_y = 1.6
			p_node.add_child(inter)
			inter_node = inter

		if inter_node and inter_node.has_signal("interacted") and not inter_node.interacted.is_connected(_on_trophy_pedestal_interacted):
			inter_node.interacted.connect(_on_trophy_pedestal_interacted)

	refresh_trophy_visuals()

func refresh_trophy_visuals() -> void:
	if not is_instance_valid(hub):
		return
	var trophy_group := hub.get_node_or_null("TrophyRoom")
	if not trophy_group:
		return

	for child in trophy_group.get_children():
		var inter := child.get_node_or_null("Interactable_" + child.name.trim_prefix("Pedestal_")) as HubInteractable3D
		var holo := child.get_node_or_null("HoloMesh") as MeshInstance3D
		if inter and holo:
			var is_unlocked := SaveManager.is_trophy_unlocked(inter.target_character_id)
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			if is_unlocked:
				mat.albedo_color = Color(0.75, 0.1, 1.0, 0.85)
				mat.emission_enabled = true
				mat.emission = Color(0.75, 0.1, 1.0, 1.0)
				mat.emission_energy_multiplier = 2.5
			else:
				mat.albedo_color = Color(0.3, 0.3, 0.35, 0.4)
				mat.emission_enabled = false
			holo.material_override = mat

func process_trophy_holos(delta: float, idle_time: float) -> void:
	for holo in trophy_holo_nodes:
		if is_instance_valid(holo):
			holo.rotation.y += delta * 1.8
			holo.position.y = 0.8 + sin(idle_time * 2.2) * 0.05

func update_dark_matter_display() -> void:
	if not is_instance_valid(hub):
		return
	var mat_vbox := hub.get_node_or_null("HubUI/MaterialsPanel/MatMargin/MatVBox") as VBoxContainer
	if not mat_vbox:
		return

	var dm_row := mat_vbox.get_node_or_null("DarkMatterRow") as HBoxContainer
	if not dm_row:
		dm_row = HBoxContainer.new()
		dm_row.name = "DarkMatterRow"
		mat_vbox.add_child(dm_row)

		var icon_lbl := Label.new()
		icon_lbl.text = "⚛"
		icon_lbl.add_theme_color_override("font_color", COLOR_DARK_MATTER)
		icon_lbl.add_theme_font_size_override("font_size", 14)
		dm_row.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = " Materia Oscura:"
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
		name_lbl.add_theme_font_size_override("font_size", 12)
		dm_row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.name = "DarkMatterValue"
		val_lbl.add_theme_color_override("font_color", COLOR_DARK_MATTER)
		val_lbl.add_theme_font_size_override("font_size", 13)
		dm_row.add_child(val_lbl)

	var val_label := dm_row.get_node_or_null("DarkMatterValue") as Label
	if val_label:
		val_label.text = "%d u." % SaveManager.get_dark_matter()

func _on_trophy_pedestal_interacted(interactable: HubInteractable3D, _player: Node3D) -> void:
	if hub and hub.has_method("_play_sfx"):
		hub.call("_play_sfx", "ui_click")
	var pc = hub.get("player_controller")
	if pc:
		pc.set("is_movement_locked", true)
	if trophy_modal:
		trophy_modal.open_trophy(interactable.target_character_id)

func _on_trophy_upgraded(_trophy_id: StringName, _new_level: int) -> void:
	update_dark_matter_display()
	refresh_trophy_visuals()

func _on_modal_closed() -> void:
	if hub and hub.has_method("_on_modal_closed"):
		hub.call("_on_modal_closed")

func is_modal_active() -> bool:
	return trophy_modal != null and is_instance_valid(trophy_modal) and trophy_modal.visible

func close_modal() -> void:
	if trophy_modal and is_instance_valid(trophy_modal):
		trophy_modal.close_modal()
