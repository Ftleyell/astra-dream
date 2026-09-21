class_name CharacterSelectUI
extends Control

@onready var char_list_container: VBoxContainer = $MarginContainer/HBoxContainer/LeftPanel/CharScroll/CharList
@onready var portrait_emblem: Polygon2D = $MarginContainer/HBoxContainer/RightPanel/PortraitFrame/PortraitEmblem
@onready var portrait_texture: TextureRect = $MarginContainer/HBoxContainer/RightPanel/PortraitFrame/PortraitTexture
@onready var portrait_border: Panel = $MarginContainer/HBoxContainer/RightPanel/PortraitFrame
@onready var name_label: Label = $MarginContainer/HBoxContainer/RightPanel/InfoVBox/NameLabel
@onready var title_label: Label = $MarginContainer/HBoxContainer/RightPanel/InfoVBox/TitleLabel
@onready var desc_label: Label = $MarginContainer/HBoxContainer/RightPanel/InfoVBox/DescLabel
@onready var stats_label: Label = $MarginContainer/HBoxContainer/RightPanel/InfoVBox/StatsLabel
@onready var launch_button: Button = $MarginContainer/HBoxContainer/RightPanel/ActionsRow/LaunchButton
@onready var loadout_button: Button = $MarginContainer/HBoxContainer/RightPanel/ActionsRow/LoadoutButton
@onready var back_button: Button = $MarginContainer/HBoxContainer/LeftPanel/BackButton

var current_character_id: StringName = &"nova"

var characters_data = {
	&"nova": {
		"name": "Nova",
		"title": "Piloto de Vanguardia",
		"desc": "Especialista en asaltos frontales a hiper-velocidad. Su reactor sobrecalienta armas térmicas aumentando el daño base a quemarropa.",
		"stats": "HP: 100 | Vel: 340 px/s | Daño: 40 | Crítico: 5% | Suerte: 0",
		"color": Color(0.1, 0.9, 1.0, 1.0),
		"pts": PackedVector2Array([-40, 50, 0, -60, 40, 50, 0, 20])
	},
	&"valentina": {
		"name": "Valentina",
		"title": "Francotiradora Táctica",
		"desc": "Calculista orbital de precisión quirúrgica. Sus lásers de telemetría perforan blindajes con un multiplicador de daño crítico masivo.",
		"stats": "HP: 85 | Vel: 300 px/s | Daño: 55 | Crítico: 18% | Suerte: +5",
		"color": Color(1.0, 0.35, 0.4, 1.0),
		"pts": PackedVector2Array([-20, 60, -10, -50, 0, -70, 10, -50, 20, 60, 0, 30])
	},
	&"kira": {
		"name": "Kira",
		"title": "Ingeniera de Enjambre",
		"desc": "Despliega nanobots y munición de racimo automática. Su cadencia pasiva de misiles y drones satélites es un 35% más veloz.",
		"stats": "HP: 90 | Vel: 310 px/s | Daño: 35 | Crítico: 8% | Suerte: +12",
		"color": Color(1.0, 0.8, 0.1, 1.0),
		"pts": PackedVector2Array([-50, 20, -25, -40, 25, -40, 50, 20, 0, 50])
	},
	&"selene": {
		"name": "Selene",
		"title": "Ocultista del Vacío",
		"desc": "Canaliza anomalías de gravedad negativa. Ralentiza proyectiles enemigos entrantes y tiene el doble de rango de aspiración de EXP.",
		"stats": "HP: 110 | Vel: 290 px/s | Daño: 38 | Crítico: 6% | Suerte: +20",
		"color": Color(0.75, 0.4, 1.0, 1.0),
		"pts": PackedVector2Array([-40, -40, 40, -40, 50, 10, 0, 60, -50, 10])
	},
	&"roxy": {
		"name": "Roxanne",
		"title": "Especialista Pesada",
		"desc": "Blindaje de casco reforzado y escopeta sísmica de metralla. Comienza con escudo cinético que absorbe impactos directos.",
		"stats": "HP: 150 | Vel: 260 px/s | Daño: 48 | Crítico: 4% | Suerte: -5",
		"color": Color(0.2, 0.95, 0.5, 1.0),
		"pts": PackedVector2Array([-50, -30, 50, -30, 45, 50, -45, 50])
	},
	&"echo": {
		"name": "Echo",
		"title": "Androide Ciber-Guerra",
		"desc": "Inyecta virus de latencia cuántica que encadenan arcos eléctricos y procs infinitos entre grupos densos de enemigos.",
		"stats": "HP: 80 | Vel: 360 px/s | Daño: 42 | Crítico: 12% | Suerte: +10",
		"color": Color(0.5, 0.85, 1.0, 1.0),
		"pts": PackedVector2Array([-30, -50, 0, -20, 30, -50, 20, 50, -20, 50])
	}
}

func _ready() -> void:
	_populate_roster()
	_select_character(&"nova")

	launch_button.pressed.connect(_on_launch_pressed)
	loadout_button.pressed.connect(_on_loadout_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _populate_roster() -> void:
	for child in char_list_container.get_children():
		child.queue_free()

	for char_id in characters_data.keys():
		var data: Dictionary = characters_data[char_id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(280, 54)
		btn.text = "%s  —  %s" % [data["name"], data["title"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func(): _select_character(char_id))
		char_list_container.add_child(btn)

func _select_character(char_id: StringName) -> void:
	current_character_id = char_id
	var data: Dictionary = characters_data[char_id]

	name_label.text = data["name"]
	name_label.modulate = data["color"]
	title_label.text = data["title"]
	desc_label.text = data["desc"]
	stats_label.text = data["stats"]

	# Carga de retrato ilustrado o fallback a silueta poligonal
	var portrait_path := "res://assets/portraits/portrait_%s.png" % str(char_id).to_lower()
	if ResourceLoader.exists(portrait_path):
		var tex := load(portrait_path) as Texture2D
		if portrait_texture and tex:
			portrait_texture.texture = tex
			portrait_texture.visible = true
			if portrait_emblem:
				portrait_emblem.visible = false
	else:
		if portrait_texture:
			portrait_texture.visible = false
		if portrait_emblem:
			portrait_emblem.polygon = data["pts"]
			portrait_emblem.color = data["color"]
			portrait_emblem.visible = true

func _on_launch_pressed() -> void:
	# Inicia la run con el personaje seleccionado
	get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")

func _on_loadout_pressed() -> void:
	# Abre la pantalla de Hangar / Banlist de items
	get_tree().change_scene_to_file("res://scenes/ui/hangar_banlist_ui.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")
