class_name HubWorld
extends Node3D

const HubHangarBuilder3D = preload("res://scenes/ui/hub/components/hub_hangar_builder_3d.gd")
const HubTerminalManager = preload("res://scenes/ui/hub/components/hub_terminal_manager.gd")
const HubPilotShowcaseController = preload("res://scenes/ui/hub/components/hub_pilot_showcase_controller.gd")
const HubTrophyRoomManager = preload("res://scenes/ui/hub/components/hub_trophy_room_manager.gd")
const PetDataScript = preload("res://data/pets/pet_data.gd")
const HubPetRoamerScript = preload("res://scenes/ui/hub/hub_pet_roamer.gd")

var hangar_builder: HubHangarBuilder3D = null
var terminal_manager: HubTerminalManager = null
var showcase_controller: HubPilotShowcaseController = null
var trophy_manager: HubTrophyRoomManager = null

## HubWorld.gd
## Controlador desacoplado del Hangar Espacial 3D (Menú Principal Jugable).

const COLOR_HOT_PINK := Color("#FF1493")
const COLOR_DEEP_BLACK := Color("#0A0A0E")
const COLOR_PURE_WHITE := Color("#FFFFFF")
const COLOR_CYAN := Color("#00F0FF")
const COLOR_EMERALD := Color("#00FF9D")
const COLOR_DARK_MATTER := Color("#BF00FF")

const PILOT_ROSTER: Array[Dictionary] = [
	{"id": &"nova", "name": "Nova", "title": "Piloto de Vanguardia", "desc": "Especialista en asaltos frontales a hiper-velocidad. Su reactor sobrecalienta armas térmicas aumentando el daño base a quemarropa.", "stats": "HP: 100 | Vel: 340 px/s | Daño: 40 | Crítico: 5% | Suerte: 0", "color": Color(0.1, 0.9, 1.0, 1.0), "pedestal_pos": Vector3(-8.5, 0.15, -4.0)},
	{"id": &"valentina", "name": "Valentina", "title": "Francotiradora Táctica", "desc": "Calculista orbital de precisión quirúrgica. Sus lásers de telemetría perforan blindajes con un multiplicador de daño crítico masivo.", "stats": "HP: 85 | Vel: 300 px/s | Daño: 55 | Crítico: 18% | Suerte: +5", "color": Color(1.0, 0.35, 0.4, 1.0), "pedestal_pos": Vector3(-8.5, 0.15, 2.0)},
	{"id": &"kira", "name": "Kira", "title": "Ingeniera de Enjambre", "desc": "Despliega nanobots y munición de racimo automática. Su cadencia pasiva de misiles y drones satélites es un 35% más veloz.", "stats": "HP: 90 | Vel: 310 px/s | Daño: 35 | Crítico: 8% | Suerte: +12", "color": Color(1.0, 0.8, 0.1, 1.0), "pedestal_pos": Vector3(-8.5, 0.15, 8.0)},
	{"id": &"selene", "name": "Selene", "title": "Ocultista del Vacío", "desc": "Canaliza anomalías de gravedad negativa. Ralentiza proyectiles enemigos entrantes y tiene el doble de rango de aspiración de EXP.", "stats": "HP: 110 | Vel: 290 px/s | Daño: 38 | Crítico: 6% | Suerte: +20", "color": Color(0.75, 0.4, 1.0, 1.0), "pedestal_pos": Vector3(8.5, 0.15, -4.0)},
	{"id": &"roxy", "name": "Roxanne", "title": "Especialista Pesada", "desc": "Blindaje de casco reforzado y escopeta sísmica de metralla. Comienza con escudo cinético que absorbe impactos directos.", "stats": "HP: 150 | Vel: 260 px/s | Daño: 48 | Crítico: 4% | Suerte: -5", "color": Color(0.2, 0.95, 0.5, 1.0), "pedestal_pos": Vector3(8.5, 0.15, 2.0)},
	{"id": &"echo", "name": "Echo", "title": "Androide Ciber-Guerra", "desc": "Inyecta virus de latencia cuántica que encadenan arcos eléctricos y procs infinitos entre grupos densos de enemigos.", "stats": "HP: 80 | Vel: 360 px/s | Daño: 42 | Crítico: 12% | Suerte: +10", "color": Color(0.5, 0.85, 1.0, 1.0), "pedestal_pos": Vector3(8.5, 0.15, 8.0)},
	{"id": &"nyx", "name": "Nyx", "title": "Espadachina Dimensional", "desc": "Empuña la Hoja Crepuscular ejecutando ráfagas cortantes en medialuna, torbellinos defensivos y estelas de corte dimensional.", "stats": "HP: 110 | Vel: 350 px/s | Daño: 48 (Melee) | Crítico: 15% | Cortes: Escala con Proyectiles", "color": Color(0.9, 0.25, 1.0, 1.0), "pedestal_pos": Vector3(0.0, 0.15, 10.5)}
]

var current_pilot_index: int = 0
var _is_transitioning: bool = false
var _idle_time: float = 0.0

# ── PROPIEDADES DELEGADAS PARA COMPATIBILIDAD CON SUITES DE TEST ──────────────
var sprite_nodes: Array[Sprite3D]:
	get: return showcase_controller.sprite_nodes if showcase_controller else []
var pilot_vfx_data: Array[Dictionary]:
	get: return showcase_controller.pilot_vfx_data if showcase_controller else []
var interactable_nodes: Array[HubInteractable3D]:
	get: return showcase_controller.interactable_nodes if showcase_controller else []
var trophy_modal: TrophyDetailsModal:
	get: return trophy_manager.trophy_modal if trophy_manager else null
var trophy_holo_nodes: Array[MeshInstance3D]:
	get: return trophy_manager.trophy_holo_nodes if trophy_manager else []
var gacha_modal: CanvasLayer:
	get: return terminal_manager.gacha_modal if terminal_manager else null
var highscores_modal: CanvasLayer:
	get: return terminal_manager.highscores_modal if terminal_manager else null
var mission_interactable: HubInteractable3D:
	get: return terminal_manager.mission_interactable if terminal_manager else null
var highscores_interactable: HubInteractable3D:
	get: return terminal_manager.highscores_interactable if terminal_manager else null
var gacha_holo: MeshInstance3D:
	get: return terminal_manager.gacha_holo if terminal_manager else null
var gacha_interactable: HubInteractable3D:
	get: return terminal_manager.gacha_interactable if terminal_manager else null

@onready var parallax_near: MeshInstance3D = get_node_or_null("SpaceParallax/Layer2_Near")
@onready var parallax_mid: MeshInstance3D = get_node_or_null("SpaceParallax/Layer1_Mid")
@onready var parallax_deep: MeshInstance3D = get_node_or_null("SpaceParallax/Layer0_Deep")

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

@onready var top_right_hud: HBoxContainer = get_node_or_null("HubUI/TopRightHUD")
@onready var btn_settings: Button = get_node_or_null("HubUI/TopRightHUD/SettingsButton")
@onready var btn_quit: Button = get_node_or_null("HubUI/TopRightHUD/QuitButton")
@onready var settings_modal: SettingsModal = get_node_or_null("HubUI/SettingsModal")


func _ready() -> void:
	hangar_builder = HubHangarBuilder3D.new()
	hangar_builder.name = "HubHangarBuilder3D"
	add_child(hangar_builder)
	hangar_builder.setup(self)

	terminal_manager = HubTerminalManager.new()
	terminal_manager.name = "HubTerminalManager"
	add_child(terminal_manager)
	terminal_manager.setup(self)

	showcase_controller = HubPilotShowcaseController.new()
	showcase_controller.name = "HubPilotShowcaseController"
	add_child(showcase_controller)
	showcase_controller.setup(self)

	trophy_manager = HubTrophyRoomManager.new()
	trophy_manager.name = "HubTrophyRoomManager"
	add_child(trophy_manager)
	trophy_manager.setup(self)

	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Engine.time_scale = 1.0
	SaveManager.set_game_speed(1.0)
	_setup_camera()

	showcase_controller.build_pilot_pedestals_and_vfx(PILOT_ROSTER)
	showcase_controller.collect_and_verify_sprites(PILOT_ROSTER)
	showcase_controller.setup_interactables(PILOT_ROSTER, _on_interactable_triggered)

	hangar_builder.build_mirrored_hangar_wing()
	hangar_builder.setup_environment_collisions()
	_apply_psychopop_styles()
	_build_pilot_selector_buttons()
	_update_materials_display()
	trophy_manager.setup_trophy_room()
	trophy_manager.update_dark_matter_display()
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
	if camera and is_instance_valid(camera) and hangar_builder:
		hangar_builder.update_parallax(camera.global_position)

	_idle_time += delta
	if terminal_manager:
		terminal_manager.process_terminal_holos(delta, _idle_time)
	if trophy_manager:
		trophy_manager.process_trophy_holos(delta, _idle_time)
	if showcase_controller:
		showcase_controller.process_vfx(delta, _idle_time)


func _unhandled_input(event: InputEvent) -> void:
	if _is_modal_active():
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
			if terminal_manager and terminal_manager.handle_esc_input():
				get_viewport().set_input_as_handled()
				return
			if trophy_manager and trophy_manager.is_modal_active():
				trophy_manager.close_modal()
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


func _setup_hub_pets() -> void:
	var pets_group := get_node_or_null("HubPets")
	if not pets_group:
		pets_group = Node3D.new()
		pets_group.name = "HubPets"
		add_child(pets_group)

	var existing_roamers := pets_group.get_children()
	if not existing_roamers.is_empty():
		for roamer in existing_roamers:
			if roamer.has_method("update_skin"):
				roamer.update_skin()
		return

	var roster := PetDataScript.load_roster_ordered()
	for p_data in roster:
		var pid := p_data.pet_id
		if not SaveManager.is_pet_unlocked(pid):
			continue
		var roamer = HubPetRoamerScript.new()
		pets_group.add_child(roamer)
		var spawn_pos := Vector3(randf_range(-3.0, 3.0), 0.32, randf_range(0.0, 6.0))
		roamer.setup(p_data, spawn_pos)


func _setup_hub_top_buttons() -> void:
	if btn_settings and not btn_settings.pressed.is_connected(_open_settings):
		btn_settings.pressed.connect(_open_settings)
	if btn_quit and not btn_quit.pressed.is_connected(_quit_game):
		btn_quit.pressed.connect(_quit_game)

	if settings_modal and not settings_modal.closed.is_connected(_on_modal_closed):
		settings_modal.closed.connect(_on_modal_closed)
	var highscores_modal_node = get_node_or_null("HubUI/HighscoresModal")
	if highscores_modal_node and highscores_modal_node.has_signal("closed") and not highscores_modal_node.closed.is_connected(_on_modal_closed):
		highscores_modal_node.closed.connect(_on_modal_closed)


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
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_sfx("ui_click")
	var st: Node = get_node_or_null("/root/SceneTransition")
	if st and st.has_method("change_scene_to_file"):
		st.change_scene_to_file("res://scenes/ui/title_screen/title_screen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/title_screen/title_screen.tscn")


func _on_modal_closed() -> void:
	if player_controller:
		player_controller.is_movement_locked = false
	_update_materials_display()
	if trophy_manager:
		trophy_manager.update_dark_matter_display()
		trophy_manager.refresh_trophy_visuals()
	_setup_hub_pets()
	if showcase_controller:
		showcase_controller.refresh_pedestal_skins(PILOT_ROSTER)


func _is_modal_active() -> bool:
	return (settings_modal != null and settings_modal.visible) \
		or (trophy_manager != null and trophy_manager.is_modal_active()) \
		or (terminal_manager != null and terminal_manager.is_modal_active()) \
		or (skill_tree_modal != null and skill_tree_modal.visible)


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
	if showcase_controller:
		showcase_controller.build_pilot_selector_buttons(pilot_selector_container, PILOT_ROSTER, _select_pilot, character_card)


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
	if trophy_manager:
		trophy_manager.setup_trophy_room()
		trophy_manager.update_dark_matter_display()


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
	if card_title: card_title.text = String(data["title"]).to_upper()
	if card_desc: card_desc.text = String(data["desc"])
	if card_stats: card_stats.text = String(data["stats"])

	if player_controller:
		player_controller.set_character(data["id"])

	if showcase_controller:
		showcase_controller.select_pilot_visuals(index, PILOT_ROSTER)

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


# ── COMPATIBILIDAD CON SUITES Y DELEGACIÓN A COMPONENTES ──────────────────────

func _setup_environment_collisions() -> void:
	if hangar_builder:
		hangar_builder.setup_environment_collisions()

func _build_mirrored_hangar_wing() -> void:
	if hangar_builder:
		hangar_builder.build_mirrored_hangar_wing()

func _build_south_parallax() -> void:
	if hangar_builder:
		hangar_builder.build_south_parallax()

func _refresh_pedestal_skins() -> void:
	if showcase_controller:
		showcase_controller.refresh_pedestal_skins(PILOT_ROSTER)

func _setup_trophy_room() -> void:
	if trophy_manager:
		trophy_manager.setup_trophy_room()

func _refresh_trophy_visuals() -> void:
	if trophy_manager:
		trophy_manager.refresh_trophy_visuals()

func _update_dark_matter_display() -> void:
	if trophy_manager:
		trophy_manager.update_dark_matter_display()

func _build_pilot_pedestals_and_vfx() -> void:
	if showcase_controller:
		showcase_controller.build_pilot_pedestals_and_vfx(PILOT_ROSTER)

func _collect_and_verify_sprites() -> void:
	if showcase_controller:
		showcase_controller.collect_and_verify_sprites(PILOT_ROSTER)

func _setup_interactables() -> void:
	if showcase_controller:
		showcase_controller.setup_interactables(PILOT_ROSTER, _on_interactable_triggered)

func _update_interactable_prompts() -> void:
	if showcase_controller:
		showcase_controller.update_interactable_prompts(PILOT_ROSTER, current_pilot_index)

func _show_mission_prompt() -> void:
	if terminal_manager:
		terminal_manager.show_mission_prompt()

func _update_mission_terminal_label() -> void:
	if terminal_manager:
		terminal_manager.update_mission_terminal_label()

func _on_gacha_terminal_interacted(inter: HubInteractable3D, p: Node3D) -> void:
	if terminal_manager:
		terminal_manager._on_gacha_interacted(inter, p)

func _on_highscores_terminal_interacted(inter: HubInteractable3D, p: Node3D) -> void:
	if terminal_manager:
		terminal_manager._on_highscores_interacted(inter, p)

func _start_new_run() -> void:
	if terminal_manager:
		terminal_manager._start_new_run()
