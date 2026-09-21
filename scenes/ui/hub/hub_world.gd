class_name HubWorld
extends Node3D

## 2.5D Psycho-Pop Hub World Scene Controller
## Entorno 3D expandido: planeta verde de circuitos, control en 3ª persona,
## estaciones de pilotos con interactuables [E], y Árbol de Habilidades cibernético.

const COLOR_HOT_PINK := Color("#FF1493")   # Neon Pink / Hot Pink
const COLOR_DEEP_BLACK := Color("#0A0A0E") # Deep Void Black
const COLOR_PURE_WHITE := Color("#FFFFFF") # Pure Crisp White
const COLOR_CYAN := Color("#00F0FF")       # Accent Neon Cyan
const COLOR_EMERALD := Color("#00FF9D")    # BioMasa Green

const PILOT_ROSTER: Array[Dictionary] = [
	{
		"id": &"nova",
		"name": "Nova",
		"title": "Piloto de Vanguardia",
		"desc": "Especialista en asaltos frontales a hiper-velocidad. Su reactor sobrecalienta armas térmicas aumentando el daño base a quemarropa.",
		"stats": "HP: 100 | Vel: 340 px/s | Daño: 40 | Crítico: 5% | Suerte: 0",
		"color": Color(0.1, 0.9, 1.0, 1.0),
		"pedestal_pos": Vector3(-6.5, 0.15, 2.0)
	},
	{
		"id": &"valentina",
		"name": "Valentina",
		"title": "Francotiradora Táctica",
		"desc": "Calculista orbital de precisión quirúrgica. Sus lásers de telemetría perforan blindajes con un multiplicador de daño crítico masivo.",
		"stats": "HP: 85 | Vel: 300 px/s | Daño: 55 | Crítico: 18% | Suerte: +5",
		"color": Color(1.0, 0.35, 0.4, 1.0),
		"pedestal_pos": Vector3(-4.0, 0.15, -5.5)
	},
	{
		"id": &"kira",
		"name": "Kira",
		"title": "Ingeniera de Enjambre",
		"desc": "Despliega nanobots y munición de racimo automática. Su cadencia pasiva de misiles y drones satélites es un 35% más veloz.",
		"stats": "HP: 90 | Vel: 310 px/s | Daño: 35 | Crítico: 8% | Suerte: +12",
		"color": Color(1.0, 0.8, 0.1, 1.0),
		"pedestal_pos": Vector3(0.0, 0.15, -7.5)
	},
	{
		"id": &"selene",
		"name": "Selene",
		"title": "Ocultista del Vacío",
		"desc": "Canaliza anomalías de gravedad negativa. Ralentiza proyectiles enemigos entrantes y tiene el doble de rango de aspiración de EXP.",
		"stats": "HP: 110 | Vel: 290 px/s | Daño: 38 | Crítico: 6% | Suerte: +20",
		"color": Color(0.75, 0.4, 1.0, 1.0),
		"pedestal_pos": Vector3(4.0, 0.15, -5.5)
	},
	{
		"id": &"roxy",
		"name": "Roxanne",
		"title": "Especialista Pesada",
		"desc": "Blindaje de casco reforzado y escopeta sísmica de metralla. Comienza con escudo cinético que absorbe impactos directos.",
		"stats": "HP: 150 | Vel: 260 px/s | Daño: 48 | Crítico: 4% | Suerte: -5",
		"color": Color(0.2, 0.95, 0.5, 1.0),
		"pedestal_pos": Vector3(6.5, 0.15, 2.0)
	},
	{
		"id": &"echo",
		"name": "Echo",
		"title": "Androide Ciber-Guerra",
		"desc": "Inyecta virus de latencia cuántica que encadenan arcos eléctricos y procs infinitos entre grupos densos de enemigos.",
		"stats": "HP: 80 | Vel: 360 px/s | Daño: 42 | Crítico: 12% | Suerte: +10",
		"color": Color(0.5, 0.85, 1.0, 1.0),
		"pedestal_pos": Vector3(0.0, 0.15, 6.5)
	}
]

var current_pilot_index: int = 0
var sprite_nodes: Array[Sprite3D] = []
var _is_transitioning: bool = false
var _pilot_tweens: Array[Tween] = []

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


func _ready() -> void:
	_setup_camera()
	_collect_and_verify_sprites()
	_setup_interactables()
	_apply_psychopop_styles()
	_build_pilot_selector_buttons()
	_update_materials_display()
	_select_pilot(0, false)
	_setup_navigation()
	_setup_skill_tree_integration()
	_animate_entrance()


func _setup_camera() -> void:
	# Si existe controlador de jugador en tercera persona, la cámara es gestionada por él
	if player_controller and player_controller.camera:
		camera = player_controller.camera
	elif not camera:
		camera = get_node_or_null("Camera3D")
		if camera:
			camera.fov = 85.0
			camera.position = Vector3(0.0, 4.0, 7.5)
			camera.look_at(Vector3.ZERO, Vector3.UP)


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
		sprite.pixel_size = 0.005
		sprite.offset = Vector2(0, 256)
		sprite.position = char_data["pedestal_pos"]

		var tex_path := "res://assets/portraits/portrait_%s.png" % char_id
		if ResourceLoader.exists(tex_path):
			sprite.texture = load(tex_path)

		sprite_nodes.append(sprite)


func _setup_interactables() -> void:
	# Configurar o asegurar que cada estación de piloto tenga su HubInteractable3D
	var roster_group := get_node_or_null("RosterCutouts")
	if not roster_group:
		return

	for i in range(PILOT_ROSTER.size()):
		var char_data: Dictionary = PILOT_ROSTER[i]
		var cid: StringName = char_data["id"]
		var interact_name := "Interactable_" + String(cid).capitalize()
		var inter: Area3D = roster_group.get_node_or_null(interact_name)
		if not inter:
			var inter_script = load("res://scenes/ui/hub/hub_interactable_3d.gd")
			inter = inter_script.new()
			inter.name = interact_name
			inter.set("target_character_id", cid)
			inter.set("interaction_title", "Árbol de Habilidades")
			inter.position = char_data["pedestal_pos"]
			inter.set("interaction_radius", 2.6)
			roster_group.add_child(inter)

		if inter.has_signal("interacted") and not inter.interacted.is_connected(_on_interactable_triggered):
			inter.interacted.connect(_on_interactable_triggered)


func _on_interactable_triggered(interactable: Area3D, _player: Node3D) -> void:
	if not interactable:
		return
	_play_sfx("ui_click")
	var target_id: StringName = interactable.get("target_character_id") if "target_character_id" in interactable else &"nova"
	_open_skill_tree_for(target_id)


func _setup_skill_tree_integration() -> void:
	if btn_open_skill_tree and not btn_open_skill_tree.pressed.is_connected(_on_open_skill_tree_pressed):
		btn_open_skill_tree.pressed.connect(_on_open_skill_tree_pressed)
		_setup_button_elastic_tween(btn_open_skill_tree)

	if skill_tree_modal:
		if not skill_tree_modal.modal_closed.is_connected(_on_skill_tree_closed):
			skill_tree_modal.modal_closed.connect(_on_skill_tree_closed)
		if not skill_tree_modal.skill_unlocked.is_connected(_on_skill_unlocked):
			skill_tree_modal.skill_unlocked.connect(_on_skill_unlocked)


func _on_open_skill_tree_pressed() -> void:
	if current_pilot_index < 0 or current_pilot_index >= PILOT_ROSTER.size():
		return
	var cid: StringName = PILOT_ROSTER[current_pilot_index]["id"]
	_open_skill_tree_for(cid)


func _open_skill_tree_for(cid: StringName) -> void:
	if not skill_tree_modal:
		return

	if player_controller:
		player_controller.is_movement_locked = true

	# Sincronizar piloto seleccionado con el interactuado
	for i in range(PILOT_ROSTER.size()):
		if PILOT_ROSTER[i]["id"] == cid:
			_select_pilot(i, true)
			break

	skill_tree_modal.open_for_character(cid)


func _on_skill_tree_closed() -> void:
	if player_controller:
		player_controller.is_movement_locked = false
	_update_materials_display()


func _on_skill_unlocked(_char_id: StringName, _node_idx: int) -> void:
	_update_materials_display()


func _apply_psychopop_styles() -> void:
	if header_panel:
		var sb_head := create_psychopop_stylebox(COLOR_DEEP_BLACK, COLOR_HOT_PINK, 8, 2, 2, 2)
		header_panel.add_theme_stylebox_override("panel", sb_head)

	if materials_panel:
		var sb_mat := create_psychopop_stylebox(COLOR_DEEP_BLACK, COLOR_CYAN, 6, 2, 2, 2)
		materials_panel.add_theme_stylebox_override("panel", sb_mat)

	if character_card:
		var sb_card := create_psychopop_stylebox(COLOR_DEEP_BLACK, COLOR_HOT_PINK, 8, 2, 2, 2)
		character_card.add_theme_stylebox_override("panel", sb_card)

	if btn_open_skill_tree:
		var sb_st := create_psychopop_stylebox(COLOR_DEEP_BLACK, COLOR_EMERALD, 6, 2, 2, 2)
		btn_open_skill_tree.add_theme_stylebox_override("normal", sb_st)
		btn_open_skill_tree.add_theme_color_override("font_color", COLOR_EMERALD)


func _build_pilot_selector_buttons() -> void:
	if not pilot_selector_container:
		return

	for c in pilot_selector_container.get_children():
		c.queue_free()

	for i in range(PILOT_ROSTER.size()):
		var data: Dictionary = PILOT_ROSTER[i]
		var btn := Button.new()
		btn.text = String(data["name"]).to_upper()
		btn.custom_minimum_size = Vector2(88, 38)
		btn.add_theme_font_size_override("font_size", 12)

		var sb := create_psychopop_stylebox(COLOR_DEEP_BLACK, data.get("color", COLOR_HOT_PINK), 4, 1, 1, 1)
		btn.add_theme_stylebox_override("normal", sb)

		var idx: int = i
		btn.pressed.connect(func():
			_play_sfx("ui_click")
			_select_pilot(idx, true)
		)
		_setup_button_elastic_tween(btn)
		pilot_selector_container.add_child(btn)


func _select_pilot(index: int, animate_card: bool = true) -> void:
	if index < 0 or index >= PILOT_ROSTER.size():
		return
	current_pilot_index = index
	var data: Dictionary = PILOT_ROSTER[index]

	if card_name:
		card_name.text = String(data["name"]).to_upper()
		card_name.add_theme_color_override("font_color", data.get("color", COLOR_HOT_PINK))
	if card_title:
		card_title.text = String(data["title"]).to_upper()
	if card_desc:
		card_desc.text = String(data["desc"])
	if card_stats:
		card_stats.text = String(data["stats"])

	# Actualizar el personaje en el controlador 3D si aplica
	if player_controller:
		player_controller.set_character(data["id"])

	# Eliminar tweens activos anteriores
	for tw in _pilot_tweens:
		if is_instance_valid(tw) and tw.is_running():
			tw.kill()
	_pilot_tweens.clear()

	# Resaltar el Sprite3D seleccionado y atenuar los demás
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
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")


func _setup_button_elastic_tween(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.mouse_entered.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.07, 1.07), 0.16)
	)
	btn.mouse_exited.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.16)
	)
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.08)
	)
	btn.button_up.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.25)
	)


func _animate_entrance() -> void:
	if header_panel:
		_tween_slide_pop(header_panel, Vector2(0, -60), 0.0)
	if materials_panel:
		_tween_slide_pop(materials_panel, Vector2(-80, 0), 0.1)
	if character_card:
		_tween_slide_pop(character_card, Vector2(80, 0), 0.15)
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
