class_name HubWorld
extends Node3D

## HubWorld.gd
## Controlador del Hangar Espacial 3D (Nuevo Menú Principal Jugable).
## Contiene:
## - Entorno 3D cerrado con suelo, paredes, techo y Gran Ventanal Panorámico.
## - Sistema de Parallax 3D de 3 capas en el espacio exterior.
## - Terminal Central de Misiones: Continuar Run activa [E] o Nueva Run.
## - Terminal de Pantalla Trasera: High Scores [E].
## - Bahías de Pilotos con interactuables [E] para Árbol de Habilidades.
## - HUD con Badges de acceso rápido: [ESC] Ajustes y [Q] Salir.

const COLOR_HOT_PINK := Color("#FF1493")   # Neon Pink / Hot Pink
const COLOR_DEEP_BLACK := Color("#0A0A0E") # Deep Void Black
const COLOR_PURE_WHITE := Color("#FFFFFF") # Pure Crisp White
const COLOR_CYAN := Color("#00F0FF")       # Accent Neon Cyan
const COLOR_EMERALD := Color("#00FF9D")    # BioMasa Green
const COLOR_DARK_MATTER := Color("#BF00FF") # Materia Oscura Purple

const PILOT_ROSTER: Array[Dictionary] = [
	{
		"id": &"nova",
		"name": "Nova",
		"title": "Piloto de Vanguardia",
		"desc": "Especialista en asaltos frontales a hiper-velocidad. Su reactor sobrecalienta armas térmicas aumentando el daño base a quemarropa.",
		"stats": "HP: 100 | Vel: 340 px/s | Daño: 40 | Crítico: 5% | Suerte: 0",
		"color": Color(0.1, 0.9, 1.0, 1.0),
		"pedestal_pos": Vector3(-8.5, 0.15, -4.0)
	},
	{
		"id": &"valentina",
		"name": "Valentina",
		"title": "Francotiradora Táctica",
		"desc": "Calculista orbital de precisión quirúrgica. Sus lásers de telemetría perforan blindajes con un multiplicador de daño crítico masivo.",
		"stats": "HP: 85 | Vel: 300 px/s | Daño: 55 | Crítico: 18% | Suerte: +5",
		"color": Color(1.0, 0.35, 0.4, 1.0),
		"pedestal_pos": Vector3(-8.5, 0.15, 2.0)
	},
	{
		"id": &"kira",
		"name": "Kira",
		"title": "Ingeniera de Enjambre",
		"desc": "Despliega nanobots y munición de racimo automática. Su cadencia pasiva de misiles y drones satélites es un 35% más veloz.",
		"stats": "HP: 90 | Vel: 310 px/s | Daño: 35 | Crítico: 8% | Suerte: +12",
		"color": Color(1.0, 0.8, 0.1, 1.0),
		"pedestal_pos": Vector3(-8.5, 0.15, 8.0)
	},
	{
		"id": &"selene",
		"name": "Selene",
		"title": "Ocultista del Vacío",
		"desc": "Canaliza anomalías de gravedad negativa. Ralentiza proyectiles enemigos entrantes y tiene el doble de rango de aspiración de EXP.",
		"stats": "HP: 110 | Vel: 290 px/s | Daño: 38 | Crítico: 6% | Suerte: +20",
		"color": Color(0.75, 0.4, 1.0, 1.0),
		"pedestal_pos": Vector3(8.5, 0.15, -4.0)
	},
	{
		"id": &"roxy",
		"name": "Roxanne",
		"title": "Especialista Pesada",
		"desc": "Blindaje de casco reforzado y escopeta sísmica de metralla. Comienza con escudo cinético que absorbe impactos directos.",
		"stats": "HP: 150 | Vel: 260 px/s | Daño: 48 | Crítico: 4% | Suerte: -5",
		"color": Color(0.2, 0.95, 0.5, 1.0),
		"pedestal_pos": Vector3(8.5, 0.15, 2.0)
	},
	{
		"id": &"echo",
		"name": "Echo",
		"title": "Androide Ciber-Guerra",
		"desc": "Inyecta virus de latencia cuántica que encadenan arcos eléctricos y procs infinitos entre grupos densos de enemigos.",
		"stats": "HP: 80 | Vel: 360 px/s | Daño: 42 | Crítico: 12% | Suerte: +10",
		"color": Color(0.5, 0.85, 1.0, 1.0),
		"pedestal_pos": Vector3(8.5, 0.15, 8.0)
	},
	{
		"id": &"nyx",
		"name": "Nyx",
		"title": "Espadachina Dimensional",
		"desc": "Empuña la Hoja Crepuscular ejecutando ráfagas cortantes en medialuna, torbellinos defensivos y estelas de corte dimensional.",
		"stats": "HP: 110 | Vel: 350 px/s | Daño: 48 (Melee) | Crítico: 15% | Cortes: Escala con Proyectiles",
		"color": Color(0.9, 0.25, 1.0, 1.0),
		"pedestal_pos": Vector3(0.0, 0.15, 10.5)
	}
]

var current_pilot_index: int = 0
var sprite_nodes: Array[Sprite3D] = []
var _is_transitioning: bool = false
var _pilot_tweens: Array[Tween] = []
var pilot_vfx_data: Array[Dictionary] = []
var interactable_nodes: Array[HubInteractable3D] = []

@onready var player_controller: CharacterBody3D = $PlayerController
@onready var camera: Camera3D = get_node_or_null("Camera3D")
@onready var header_panel: PanelContainer = $HubUI/HeaderPanel
@onready var materials_panel: PanelContainer = $HubUI/MaterialsPanel
@onready var character_card: PanelContainer = $HubUI/CharacterCard
@onready var nav_bar: HBoxContainer = $HubUI/NavigationBar
@onready var btn_desplegar: Button = $HubUI/NavigationBar/DesplegarButton
@onready var btn_volver: Button = $HubUI/NavigationBar/VolverButton
@onready var skill_tree_modal: Control = $HubUI/CharacterSkillTreeModal

@onready var card_name: Label = $HubUI/CharacterCard/CardMargin/CardVBox/CardHeader/NameLabel
@onready var card_title: Label = $HubUI/CharacterCard/CardMargin/CardVBox/TitleLabel
@onready var card_desc: Label = $HubUI/CharacterCard/CardMargin/CardVBox/DescLabel
@onready var card_stats: Label = $HubUI/CharacterCard/CardMargin/CardVBox/StatsLabel
@onready var pilot_selector_container: HBoxContainer = $HubUI/CharacterCard/CardMargin/CardVBox/PilotSelectorContainer
@onready var btn_open_skill_tree: Button = $HubUI/CharacterCard/CardMargin/CardVBox/OpenSkillTreeButton

@onready var biomass_value_label: Label = $HubUI/MaterialsPanel/MatMargin/MatVBox/BiomassRow/BiomassValue
@onready var antimatter_value_label: Label = $HubUI/MaterialsPanel/MatMargin/MatVBox/AntimatterRow/AntimatterValue

# Nuevos componentes del Hub Menú Principal
@onready var top_right_hud: HBoxContainer = get_node_or_null("HubUI/TopRightHUD")
@onready var btn_settings: Button = get_node_or_null("HubUI/TopRightHUD/SettingsButton")
@onready var btn_quit: Button = get_node_or_null("HubUI/TopRightHUD/QuitButton")
@onready var settings_modal: SettingsModal = get_node_or_null("HubUI/SettingsModal")
@onready var highscores_modal: CanvasLayer = get_node_or_null("HubUI/HighscoresModal")
var trophy_modal: TrophyDetailsModal = null
var trophy_holo_nodes: Array[MeshInstance3D] = []
@onready var mission_interactable: HubInteractable3D = get_node_or_null("Terminals/MissionTerminal/Interactable_Mission")
@onready var highscores_interactable: HubInteractable3D = get_node_or_null("Terminals/HighScoresTerminal/Interactable_HighScores")
@onready var mission_prompt_modal: PanelContainer = get_node_or_null("HubUI/MissionPromptModal")
@onready var prompt_info_label: Label = get_node_or_null("HubUI/MissionPromptModal/VBox/PromptInfo")
@onready var btn_prompt_continue: Button = get_node_or_null("HubUI/MissionPromptModal/VBox/PromptButtons/ContinueRunButton")
@onready var btn_prompt_new_run: Button = get_node_or_null("HubUI/MissionPromptModal/VBox/PromptButtons/NewRunButton")
@onready var btn_prompt_cancel: Button = get_node_or_null("HubUI/MissionPromptModal/VBox/PromptButtons/CancelPromptButton")

# Parallax 3D
@onready var parallax_near: MeshInstance3D = get_node_or_null("SpaceParallax/Layer2_Near")
@onready var parallax_mid: MeshInstance3D = get_node_or_null("SpaceParallax/Layer1_Mid")
@onready var parallax_deep: MeshInstance3D = get_node_or_null("SpaceParallax/Layer0_Deep")

# Hologramas en terminales
@onready var mission_holo_core: MeshInstance3D = get_node_or_null("Terminals/MissionTerminal/HoloCore")
@onready var highscores_trophy_holo: MeshInstance3D = get_node_or_null("Terminals/HighScoresTerminal/TrophyHolo")
var _idle_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_setup_camera()
	_build_pilot_pedestals_and_vfx()
	_collect_and_verify_sprites()
	_setup_interactables()
	_setup_terminals()
	_apply_psychopop_styles()
	_build_pilot_selector_buttons()
	_update_materials_display()
	_setup_trophy_room()
	_update_dark_matter_display()
	_setup_hub_pets()

	var saved_cid := SaveManager.get_selected_character()
	var init_idx: int = 0
	for i in range(PILOT_ROSTER.size()):
		if PILOT_ROSTER[i]["id"] == saved_cid and SaveManager.is_character_unlocked(saved_cid):
			init_idx = i
			break
	_select_pilot(init_idx, false)

	_setup_navigation()
	_setup_skill_tree_integration()
	_setup_hub_top_buttons()
	_animate_entrance()

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_music"):
		audio_mgr.play_music("menu")


func _process(delta: float) -> void:
	# Efecto de Parallax 3D suave según la posición y proximidad de la cámara
	if camera and is_instance_valid(camera):
		var cam_pos: Vector3 = camera.global_position
		var approach: float = clampf((-cam_pos.z) / 7.5, 0.0, 1.0)

		if parallax_near:
			parallax_near.position.x = cam_pos.x * 0.35
			parallax_near.position.y = 4.0 + (cam_pos.y - 3.2) * 0.25
			var s_near: float = 1.0 + approach * 0.12
			parallax_near.scale = Vector3(s_near, s_near, 1.0)
		if parallax_mid:
			parallax_mid.position.x = cam_pos.x * 0.14
			parallax_mid.position.y = 6.0 + (cam_pos.y - 3.2) * 0.12
			var s_mid: float = 1.0 + approach * 0.06
			parallax_mid.scale = Vector3(s_mid, s_mid, 1.0)
		if parallax_deep:
			parallax_deep.position.x = cam_pos.x * 0.04
			parallax_deep.position.y = 10.0 + (cam_pos.y - 3.2) * 0.04

	# Animación idle de hologramas en las máquinas
	_idle_time += delta
	if mission_holo_core and is_instance_valid(mission_holo_core):
		mission_holo_core.rotation.y += delta * 1.5
		mission_holo_core.position.y = 2.3 + sin(_idle_time * 2.5) * 0.08
	if highscores_trophy_holo and is_instance_valid(highscores_trophy_holo):
		highscores_trophy_holo.rotation.y += delta * 2.0
		highscores_trophy_holo.position.y = 2.3 + sin(_idle_time * 2.0) * 0.06
	for holo in trophy_holo_nodes:
		if is_instance_valid(holo):
			holo.rotation.y += delta * 1.8
			holo.position.y = 0.8 + sin(_idle_time * 2.2) * 0.05

	# Animación continua del VFX del pedestal de la heroína seleccionada
	if current_pilot_index >= 0 and current_pilot_index < pilot_vfx_data.size():
		var active_vfx: Dictionary = pilot_vfx_data[current_pilot_index]
		var rot_ring: MeshInstance3D = active_vfx.get("rotator_ring")
		if rot_ring and is_instance_valid(rot_ring) and rot_ring.visible:
			rot_ring.rotation.y += delta * 2.2
		var beam: MeshInstance3D = active_vfx.get("holo_beam")
		if beam and is_instance_valid(beam) and beam.visible:
			var pulse: float = 1.0 + sin(_idle_time * 3.5) * 0.04
			beam.scale.x = pulse
			beam.scale.z = pulse
		var badge: Label3D = active_vfx.get("floating_badge")
		if badge and is_instance_valid(badge) and badge.visible:
			badge.position.y = 2.8 + sin(_idle_time * 2.8) * 0.06


func _unhandled_input(event: InputEvent) -> void:
	if _is_modal_active():
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
			if trophy_modal and trophy_modal.visible:
				trophy_modal.close_modal()
				get_viewport().set_input_as_handled()
				return
			if skill_tree_modal and skill_tree_modal.visible:
				if skill_tree_modal.has_method("close_modal"):
					skill_tree_modal.close_modal()
				else:
					skill_tree_modal.visible = false
					_on_skill_tree_closed()
				get_viewport().set_input_as_handled()
				return
			if mission_prompt_modal and mission_prompt_modal.visible:
				_on_prompt_cancelled()
				get_viewport().set_input_as_handled()
				return
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_open_settings()
				get_viewport().set_input_as_handled()
			KEY_Q:
				_quit_game()
				get_viewport().set_input_as_handled()


func _setup_camera() -> void:
	if player_controller and player_controller.camera:
		camera = player_controller.camera
	elif not camera:
		camera = get_node_or_null("Camera3D")
		if camera:
			camera.fov = 85.0
			camera.position = Vector3(0.0, 3.2, 5.0)
			camera.look_at(Vector3.ZERO, Vector3.UP)


func _build_pilot_pedestals_and_vfx() -> void:
	var pedestals_group := get_node_or_null("PilotPedestals")
	if not pedestals_group:
		pedestals_group = Node3D.new()
		pedestals_group.name = "PilotPedestals"
		add_child(pedestals_group)

	pilot_vfx_data.clear()

	for i in range(PILOT_ROSTER.size()):
		var char_data: Dictionary = PILOT_ROSTER[i]
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

		# 2. Anillo de Borde Neón (TorusMesh)
		var rim_node: MeshInstance3D = ped_root.get_node_or_null("RimNeon")
		var rim_mat: StandardMaterial3D
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
		var beam_mat: StandardMaterial3D
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


func _collect_and_verify_sprites() -> void:
	sprite_nodes.clear()
	var roster_group := get_node_or_null("RosterCutouts")
	if not roster_group:
		roster_group = Node3D.new()
		roster_group.name = "RosterCutouts"
		add_child(roster_group)

	for i in range(PILOT_ROSTER.size()):
		var char_data: Dictionary = PILOT_ROSTER[i]
		var char_id: String = String(char_data["id"])
		var sprite_name := "Cutout_" + char_id.capitalize()
		var sprite: Sprite3D = roster_group.get_node_or_null(sprite_name)
		if not sprite:
			sprite = Sprite3D.new()
			sprite.name = sprite_name
			roster_group.add_child(sprite)

		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		sprite.position = char_data["pedestal_pos"]

		# Usar Full Body orientado hacia el pasillo central (heroínas de la derecha usan _flipped)
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
		sprite_nodes.append(sprite)


func _setup_interactables() -> void:
	var roster_group := get_node_or_null("RosterCutouts")
	if not roster_group:
		return

	interactable_nodes.clear()

	for i in range(PILOT_ROSTER.size()):
		var char_data: Dictionary = PILOT_ROSTER[i]
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

		if inter and not inter.interacted.is_connected(_on_interactable_triggered):
			inter.interacted.connect(_on_interactable_triggered)


func _update_interactable_prompts() -> void:
	for i in range(interactable_nodes.size()):
		var inter: HubInteractable3D = interactable_nodes[i]
		if not is_instance_valid(inter) or not is_instance_valid(inter.label_3d):
			continue
		var char_data: Dictionary = PILOT_ROSTER[i]
		var cname: String = String(char_data["name"]).capitalize()
		if i == current_pilot_index:
			inter.label_3d.text = "[E] Árbol de Habilidades: %s [ACTIVA]" % cname
			inter.label_3d.modulate = char_data["color"]
		else:
			inter.label_3d.text = "[E] Seleccionar a %s" % cname
			inter.label_3d.modulate = Color(0.85, 0.88, 0.95, 0.9)


func _setup_terminals() -> void:
	# 1. Terminal Central de Misiones
	if mission_interactable:
		_update_mission_terminal_label()
		if not mission_interactable.interacted.is_connected(_on_mission_terminal_interacted):
			mission_interactable.interacted.connect(_on_mission_terminal_interacted)

	# 2. Terminal de Récords
	if highscores_interactable:
		if not highscores_interactable.interacted.is_connected(_on_highscores_terminal_interacted):
			highscores_interactable.interacted.connect(_on_highscores_terminal_interacted)

	# 3. Modal de Prompt de Misión
	if btn_prompt_continue and not btn_prompt_continue.pressed.is_connected(_on_continue_run_confirmed):
		btn_prompt_continue.pressed.connect(_on_continue_run_confirmed)
	if btn_prompt_new_run and not btn_prompt_new_run.pressed.is_connected(_on_new_run_confirmed):
		btn_prompt_new_run.pressed.connect(_on_new_run_confirmed)
	if btn_prompt_cancel and not btn_prompt_cancel.pressed.is_connected(_on_prompt_cancelled):
		btn_prompt_cancel.pressed.connect(_on_prompt_cancelled)


func _setup_hub_pets() -> void:
	var pets_group := get_node_or_null("HubPets")
	if not pets_group:
		pets_group = Node3D.new()
		pets_group.name = "HubPets"
		add_child(pets_group)
	else:
		for c in pets_group.get_children():
			c.queue_free()

	var roster := PetData.load_roster_ordered()
	for p_data in roster:
		var pid := p_data.pet_id
		# Mascota secreta Cosmo solo aparece si fue desbloqueada
		if not SaveManager.is_pet_unlocked(pid):
			continue

		var roamer := HubPetRoamer.new()
		pets_group.add_child(roamer)
		var spawn_pos := Vector3(
			randf_range(-3.0, 3.0),
			0.32,
			randf_range(0.0, 6.0)
		)
		roamer.setup(p_data, spawn_pos)


func _update_mission_terminal_label() -> void:
	if not mission_interactable or not mission_interactable.label_3d:
		return
	if SaveManager.has_active_run():
		var active_data := SaveManager.load_active_run()
		var wave: int = int(active_data.get("current_wave", 1))
		var pilot: String = str(active_data.get("pilot_name", "Piloto"))
		mission_interactable.label_3d.text = "[E] CONTINUAR RUN\n(%s - OLEADA %d)" % [pilot.to_upper(), wave]
	else:
		mission_interactable.label_3d.text = "[E] DESPLEGAR MISIÓN"


func _on_mission_terminal_interacted(_interactable: HubInteractable3D, _player: Node3D) -> void:
	_play_sfx("ui_click")
	if SaveManager.has_active_run():
		_show_mission_prompt()
	else:
		_start_new_run()


func _show_mission_prompt() -> void:
	if not mission_prompt_modal:
		_start_new_run()
		return

	var active_data := SaveManager.load_active_run()
	var wave: int = int(active_data.get("current_wave", 1))
	var pilot: String = str(active_data.get("pilot_name", "Piloto"))
	if prompt_info_label:
		prompt_info_label.text = "Transmisión activa detectada:\nPiloto: %s  |  Oleada alcanzada: %d\n¿Deseas continuar la misión o comenzar una nueva?" % [pilot.to_upper(), wave]

	mission_prompt_modal.visible = true
	if player_controller:
		player_controller.is_movement_locked = true
	if btn_prompt_continue:
		btn_prompt_continue.grab_focus()


func _on_continue_run_confirmed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_sfx("ui_click")
	SaveManager.is_resuming_run = true
	get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")


func _on_new_run_confirmed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_sfx("ui_click")
	_start_new_run()


func _on_prompt_cancelled() -> void:
	if mission_prompt_modal:
		mission_prompt_modal.visible = false
	if player_controller:
		player_controller.is_movement_locked = false


func _start_new_run() -> void:
	SaveManager.is_resuming_run = false
	get_tree().change_scene_to_file("res://scenes/ui/character_select/character_select.tscn")


func _on_highscores_terminal_interacted(_interactable: HubInteractable3D, _player: Node3D) -> void:
	_play_sfx("ui_click")
	if highscores_modal:
		if player_controller:
			player_controller.is_movement_locked = true
		if highscores_modal.has_method("open_highscores"):
			highscores_modal.open_highscores()
		elif highscores_modal.has_method("show_modal"):
			highscores_modal.show_modal()
		else:
			highscores_modal.visible = true


func _setup_hub_top_buttons() -> void:
	if btn_settings and not btn_settings.pressed.is_connected(_open_settings):
		btn_settings.pressed.connect(_open_settings)
	if btn_quit and not btn_quit.pressed.is_connected(_quit_game):
		btn_quit.pressed.connect(_quit_game)

	if settings_modal and not settings_modal.closed.is_connected(_on_modal_closed):
		settings_modal.closed.connect(_on_modal_closed)
	if highscores_modal and not highscores_modal.closed.is_connected(_on_modal_closed):
		highscores_modal.closed.connect(_on_modal_closed)


func _open_settings() -> void:
	if _is_modal_active() and settings_modal and settings_modal.visible:
		return
	_play_sfx("ui_click")
	if settings_modal:
		if player_controller:
			player_controller.is_movement_locked = true
		if settings_modal.has_method("open_settings"):
			settings_modal.open_settings()
		else:
			settings_modal.visible = true


func _quit_game() -> void:
	_play_sfx("ui_click")
	get_tree().quit(0)


func _on_modal_closed() -> void:
	if player_controller:
		player_controller.is_movement_locked = false
	_update_materials_display()
	_update_dark_matter_display()
	_refresh_trophy_visuals()


func _is_modal_active() -> bool:
	if settings_modal and settings_modal.visible:
		return true
	if trophy_modal and trophy_modal.visible:
		return true
	if highscores_modal and highscores_modal.visible:
		return true
	if skill_tree_modal and skill_tree_modal.visible:
		return true
	if mission_prompt_modal and mission_prompt_modal.visible:
		return true
	return false


func _on_interactable_triggered(inter: HubInteractable3D, _body: Node3D) -> void:
	if not SaveManager.is_character_unlocked(inter.target_character_id):
		return
	for i in range(PILOT_ROSTER.size()):
		if PILOT_ROSTER[i]["id"] == inter.target_character_id:
			_select_pilot(i, true)
			if character_card:
				character_card.visible = true
			_open_skill_tree_for_pilot(inter.target_character_id)
			break


func _apply_psychopop_styles() -> void:
	if header_panel:
		header_panel.add_theme_stylebox_override("panel", create_psychopop_stylebox(COLOR_DEEP_BLACK, COLOR_CYAN, 6, 2, 2, 2))
	if materials_panel:
		materials_panel.add_theme_stylebox_override("panel", create_psychopop_stylebox(COLOR_DEEP_BLACK, COLOR_EMERALD, 6, 2, 2, 2))
	if character_card:
		character_card.add_theme_stylebox_override("panel", create_psychopop_stylebox(COLOR_DEEP_BLACK, COLOR_HOT_PINK, 8, 2, 2, 2))


func _build_pilot_selector_buttons() -> void:
	if not pilot_selector_container:
		return

	for child in pilot_selector_container.get_children():
		child.queue_free()

	for i in range(PILOT_ROSTER.size()):
		var data: Dictionary = PILOT_ROSTER[i]
		if not SaveManager.is_character_unlocked(data["id"]):
			continue
		var btn := Button.new()
		btn.text = String(data["name"]).substr(0, 3).to_upper()
		btn.custom_minimum_size = Vector2(52, 34)
		btn.add_theme_font_size_override("font_size", 11)

		var sb := StyleBoxFlat.new()
		sb.bg_color = COLOR_DEEP_BLACK
		sb.border_width_left = 3
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(data["color"])
		sb.set_corner_radius_all(0)
		btn.add_theme_stylebox_override("normal", sb)

		btn.pressed.connect(func():
			_select_pilot(i, true)
			if character_card:
				character_card.visible = true
		)
		pilot_selector_container.add_child(btn)


func _setup_skill_tree_integration() -> void:
	if btn_open_skill_tree and not btn_open_skill_tree.pressed.is_connected(_on_open_skill_tree_pressed):
		btn_open_skill_tree.pressed.connect(_on_open_skill_tree_pressed)

	if skill_tree_modal:
		skill_tree_modal.visible = false
		if skill_tree_modal.has_signal("modal_closed") and not skill_tree_modal.modal_closed.is_connected(_on_skill_tree_closed):
			skill_tree_modal.modal_closed.connect(_on_skill_tree_closed)
		if skill_tree_modal.has_signal("closed") and not skill_tree_modal.closed.is_connected(_on_skill_tree_closed):
			skill_tree_modal.closed.connect(_on_skill_tree_closed)


func _on_open_skill_tree_pressed() -> void:
	if current_pilot_index < 0 or current_pilot_index >= PILOT_ROSTER.size():
		return
	var cid: StringName = PILOT_ROSTER[current_pilot_index]["id"]
	_open_skill_tree_for_pilot(cid)


func _open_skill_tree_for_pilot(cid: StringName) -> void:
	if not skill_tree_modal:
		return

	_play_sfx("ui_click")
	if player_controller:
		player_controller.is_movement_locked = true

	if skill_tree_modal.has_method("open_for_character"):
		skill_tree_modal.open_for_character(cid)
	elif skill_tree_modal.has_method("open_tree_for_character"):
		skill_tree_modal.open_tree_for_character(cid)
	else:
		skill_tree_modal.visible = true


func _on_skill_tree_closed() -> void:
	if player_controller:
		player_controller.is_movement_locked = false
	_update_materials_display()
	_setup_trophy_room()
	_update_dark_matter_display()


func _select_pilot(index: int, animate_card: bool = true) -> void:
	if index < 0 or index >= PILOT_ROSTER.size():
		return
	if not SaveManager.is_character_unlocked(PILOT_ROSTER[index]["id"]):
		return

	current_pilot_index = index
	var data: Dictionary = PILOT_ROSTER[index]
	var col: Color = data["color"]

	SaveManager.set_selected_character(data["id"])

	if card_name:
		card_name.text = String(data["name"]).to_upper()
		card_name.add_theme_color_override("font_color", col)
	if card_title:
		card_title.text = String(data["title"]).to_upper()
	if card_desc:
		card_desc.text = String(data["desc"])
	if card_stats:
		card_stats.text = String(data["stats"])

	if player_controller:
		player_controller.set_character(data["id"])

	for tw in _pilot_tweens:
		if is_instance_valid(tw) and tw.is_running():
			tw.kill()
	_pilot_tweens.clear()

	for i in range(sprite_nodes.size()):
		var sp := sprite_nodes[i]
		if not is_instance_valid(sp):
			continue
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_pilot_tweens.append(tw)
		if i == index:
			tw.tween_property(sp, "scale", Vector3(1.2, 1.2, 1.2), 0.35)
			sp.modulate = Color(1.3, 1.3, 1.3, 1.0)
		else:
			tw.tween_property(sp, "scale", Vector3.ONE, 0.25)
			sp.modulate = Color(0.75, 0.75, 0.85, 0.85)

	# Actualizar VFX de pedestales 3D (activar en seleccionado, desactivar en los demás)
	for i in range(pilot_vfx_data.size()):
		var vfx: Dictionary = pilot_vfx_data[i]
		var beam: MeshInstance3D = vfx.get("holo_beam")
		var rim_mat: StandardMaterial3D = vfx.get("rim_mat")
		var rot_ring: MeshInstance3D = vfx.get("rotator_ring")
		var light: OmniLight3D = vfx.get("omni_light")
		var badge: Label3D = vfx.get("floating_badge")

		if i == index:
			# ACTIVAR VFX EN LA HEROÍNA SELECCIONADA
			if beam and is_instance_valid(beam):
				beam.visible = true
				beam.scale = Vector3(1.0, 0.0, 1.0)
				var tw_beam := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw_beam.tween_property(beam, "scale:y", 1.0, 0.35)
				_pilot_tweens.append(tw_beam)

			if rim_mat:
				var tw_rim := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw_rim.tween_property(rim_mat, "emission_energy_multiplier", 3.2, 0.35)
				_pilot_tweens.append(tw_rim)

			if light and is_instance_valid(light):
				light.visible = true
				var tw_light := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw_light.tween_property(light, "light_energy", 2.6, 0.35)
				_pilot_tweens.append(tw_light)

			if rot_ring and is_instance_valid(rot_ring):
				rot_ring.visible = true

			if badge and is_instance_valid(badge):
				badge.visible = true
				badge.scale = Vector3(0.2, 0.2, 0.2)
				var tw_badge := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw_badge.tween_property(badge, "scale", Vector3.ONE, 0.3)
				_pilot_tweens.append(tw_badge)
		else:
			# VOLVER A LA NORMALIDAD EN LAS DEMÁS
			if beam and is_instance_valid(beam) and beam.visible:
				var tw_beam_off := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tw_beam_off.tween_property(beam, "scale:y", 0.0, 0.2)
				tw_beam_off.tween_callback(func(): if is_instance_valid(beam): beam.visible = false)
				_pilot_tweens.append(tw_beam_off)

			if rim_mat:
				var tw_rim_off := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tw_rim_off.tween_property(rim_mat, "emission_energy_multiplier", 0.4, 0.25)
				_pilot_tweens.append(tw_rim_off)

			if light and is_instance_valid(light) and light.visible:
				var tw_light_off := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tw_light_off.tween_property(light, "light_energy", 0.0, 0.25)
				tw_light_off.tween_callback(func(): if is_instance_valid(light): light.visible = false)
				_pilot_tweens.append(tw_light_off)

			if rot_ring and is_instance_valid(rot_ring):
				rot_ring.visible = false

			if badge and is_instance_valid(badge):
				badge.visible = false

	_update_interactable_prompts()

	if animate_card and character_card:
		character_card.pivot_offset = character_card.size * 0.5
		var tw_card := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_card.tween_property(character_card, "scale", Vector2(1.04, 1.04), 0.12)
		tw_card.tween_property(character_card, "scale", Vector2.ONE, 0.18)


func _update_materials_display() -> void:
	var biomass: int = SaveManager.get_biomass()
	var antimatter: int = SaveManager.get_antimatter()

	if biomass_value_label:
		biomass_value_label.text = "%d u." % biomass
	if antimatter_value_label:
		antimatter_value_label.text = "%d u." % antimatter


func _setup_navigation() -> void:
	if btn_desplegar and not btn_desplegar.pressed.is_connected(_on_desplegar_pressed):
		btn_desplegar.pressed.connect(_on_desplegar_pressed)
	if btn_volver and not btn_volver.pressed.is_connected(_on_volver_pressed):
		btn_volver.pressed.connect(_on_volver_pressed)


func _on_desplegar_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	if btn_desplegar:
		btn_desplegar.disabled = true
	if btn_volver:
		btn_volver.disabled = true
	_play_sfx("ui_click")
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn_desplegar, "scale", Vector2(0.94, 0.94), 0.08)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/ui/character_select/character_select.tscn")


func _on_volver_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	if btn_volver:
		btn_volver.disabled = true
	if btn_desplegar:
		btn_desplegar.disabled = true
	_play_sfx("ui_click")
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn_volver, "scale", Vector2(0.94, 0.94), 0.08)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/ui/title_screen/title_screen.tscn")


func _animate_entrance() -> void:
	if header_panel:
		_tween_slide_pop(header_panel, Vector2(0, -60), 0.0)
	if materials_panel:
		_tween_slide_pop(materials_panel, Vector2(-80, 0), 0.1)
	if top_right_hud:
		_tween_slide_pop(top_right_hud, Vector2(60, 0), 0.1)
	if nav_bar:
		_tween_slide_pop(nav_bar, Vector2(0, 60), 0.2)


func _tween_slide_pop(ctrl: Control, offset: Vector2, delay: float) -> void:
	var final_pos := ctrl.position
	ctrl.position = final_pos + offset
	ctrl.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if delay > 0.0:
		tw.chain().tween_interval(delay)
	tw.tween_property(ctrl, "position", final_pos, 0.45)
	tw.tween_property(ctrl, "modulate:a", 1.0, 0.3)


func _play_sfx(sfx_name: String) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name)


static func create_psychopop_stylebox(
	bg_col: Color = COLOR_DEEP_BLACK,
	border_col: Color = COLOR_HOT_PINK,
	left_thick: int = 6,
	top_thick: int = 2,
	right_thick: int = 2,
	bottom_thick: int = 2
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.set_corner_radius_all(0)
	sb.border_width_left = left_thick
	sb.border_width_top = top_thick
	sb.border_width_right = right_thick
	sb.border_width_bottom = bottom_thick
	sb.border_color = border_col
	sb.set_content_margin_all(14.0)
	return sb

func _setup_trophy_room() -> void:
	# 1. Instanciar modal de detalles de trofeos
	var modal_scene := load("res://scenes/ui/hub/trophy_details_modal.tscn") as PackedScene
	if modal_scene:
		trophy_modal = modal_scene.instantiate() as TrophyDetailsModal
		var ui_root := get_node_or_null("HubUI")
		if ui_root:
			ui_root.add_child(trophy_modal)
		else:
			add_child(trophy_modal)
		if trophy_modal:
			trophy_modal.modal_closed.connect(_on_modal_closed)
			trophy_modal.trophy_upgraded.connect(_on_trophy_upgraded)

	# 2. Configurar pedestales e interactuables 3D de la Sala de Trofeos
	var trophy_group := get_node_or_null("TrophyRoom")
	if not trophy_group:
		trophy_group = Node3D.new()
		trophy_group.name = "TrophyRoom"
		add_child(trophy_group)

	var trophies_spec := [
		{"id": &"trophy_boss_aegis", "title": "Nodriza Aegis", "pos": Vector3(-4.5, 0.15, 13.5), "mesh_type": "prism"},
		{"id": &"trophy_biosphere_core", "title": "Núcleo Bio-Planeta", "pos": Vector3(-2.2, 0.15, 13.5), "mesh_type": "sphere"},
		{"id": &"trophy_cryo_core", "title": "Núcleo Criogénico", "pos": Vector3(0.0, 0.15, 13.5), "mesh_type": "cylinder"},
		{"id": &"trophy_volcanic_core", "title": "Núcleo Volcánico", "pos": Vector3(2.2, 0.15, 13.5), "mesh_type": "box"},
		{"id": &"trophy_monolith_master", "title": "Reliquia Monolito", "pos": Vector3(4.5, 0.15, 13.5), "mesh_type": "prism"}
	]

	var inter_script = load("res://scenes/ui/hub/hub_interactable_3d.gd")

	for spec in trophies_spec:
		var tid: StringName = spec["id"]
		var p_name := "Pedestal_" + String(tid)
		var p_node := trophy_group.get_node_or_null(p_name)
		if not p_node:
			p_node = Node3D.new()
			p_node.name = p_name
			p_node.position = spec["pos"]
			trophy_group.add_child(p_node)

			# Pedestal visual
			var base_mesh := MeshInstance3D.new()
			base_mesh.name = "BaseMesh"
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.55
			cyl.bottom_radius = 0.65
			cyl.height = 0.4
			base_mesh.mesh = cyl
			p_node.add_child(base_mesh)

			# Holograma rotatorio
			var holo_mesh := MeshInstance3D.new()
			holo_mesh.name = "HoloMesh"
			holo_mesh.position = Vector3(0, 0.8, 0)
			match spec["mesh_type"]:
				"prism":
					holo_mesh.mesh = PrismMesh.new()
				"sphere":
					holo_mesh.mesh = SphereMesh.new()
				"cylinder":
					holo_mesh.mesh = CylinderMesh.new()
				"box":
					holo_mesh.mesh = BoxMesh.new()
			if holo_mesh.mesh:
				if "size" in holo_mesh.mesh:
					holo_mesh.mesh.set("size", Vector3(0.45, 0.45, 0.45))
				elif "radius" in holo_mesh.mesh:
					holo_mesh.mesh.set("radius", 0.25)
			p_node.add_child(holo_mesh)
			trophy_holo_nodes.append(holo_mesh)

			# Interactuable 3D
			var inter = inter_script.new()
			inter.name = "Interactable_" + String(tid)
			inter.target_character_id = tid
			inter.interaction_title = "Trofeo: " + spec["title"]
			inter.interaction_radius = 2.2
			inter.prompt_offset_y = 1.6
			p_node.add_child(inter)
			inter.interacted.connect(_on_trophy_pedestal_interacted)

	_refresh_trophy_visuals()

func _refresh_trophy_visuals() -> void:
	var trophy_group := get_node_or_null("TrophyRoom")
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

func _on_trophy_pedestal_interacted(interactable: HubInteractable3D, _player: Node3D) -> void:
	_play_sfx("ui_click")
	if player_controller:
		player_controller.is_movement_locked = true
	if trophy_modal:
		trophy_modal.open_trophy(interactable.target_character_id)

func _on_trophy_upgraded(_trophy_id: StringName, _new_level: int) -> void:
	_update_dark_matter_display()
	_refresh_trophy_visuals()

func _update_dark_matter_display() -> void:
	var mat_vbox := get_node_or_null("HubUI/MaterialsPanel/MatMargin/MatVBox") as VBoxContainer
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
