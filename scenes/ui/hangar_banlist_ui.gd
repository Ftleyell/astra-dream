class_name HangarBanlistUI
extends Control

signal launch_run_requested(character_id: StringName, banned_items: Array[StringName])

const MAX_BANS: int = 5

var current_character_id: StringName = &"nova"
var profile_data: Dictionary = {}
var item_pool_manager: ItemPoolManager = ItemPoolManager.new()

@onready var char_buttons_container: HBoxContainer = $VBoxContainer/CharSelectRow
@onready var char_desc_label: Label = $VBoxContainer/CharInfoPanel/CharDesc
@onready var ban_counter_label: Label = $VBoxContainer/BanlistHeader/BanCounterLabel
@onready var items_grid: GridContainer = $VBoxContainer/ItemsScroll/ItemsGrid
@onready var launch_button: Button = $VBoxContainer/BottomBar/LaunchButton

var character_roster = {
	&"nova": {"name": "Nova", "title": "Piloto de Vanguardia", "desc": "Alta movilidad y daño ígneo a media distancia. Capa activa de plasma."},
	&"valentina": {"name": "Valentina", "title": "Francotiradora Táctica", "desc": "Daño crítico perforante a larga distancia. Mono-láseres de telemetría."},
	&"kira": {"name": "Kira", "title": "Ingeniera de Drones", "desc": "Control de área con munición de racimo y nano-drones automáticos."},
	&"selene": {"name": "Selene", "title": "Ocultista del Vacío", "desc": "Singularidades gravitatorias que ralentizan balas enemigas y atraen EXP."},
	&"roxy": {"name": "Roxanne", "title": "Especialista Pesada", "desc": "Escopeta sísmica de alta metralla con escudo cinético frontal."},
	&"echo": {"name": "Echo", "title": "Androide de Ciber-Guerra", "desc": "Transmisión de virus de latencia que salta entre enemigos."}
}

func _ready() -> void:
	add_child(item_pool_manager)
	profile_data = SaveManager.load_profile()
	_setup_character_buttons()
	_select_character(&"nova")
	launch_button.pressed.connect(_on_launch_pressed)

func _setup_character_buttons() -> void:
	for child in char_buttons_container.get_children():
		child.queue_free()

	for char_id in character_roster.keys():
		var info: Dictionary = character_roster[char_id]
		var btn := Button.new()
		btn.text = "%s\n(%s)" % [info["name"], info["title"]]
		btn.custom_minimum_size = Vector2(140, 50)
		btn.pressed.connect(func(): _select_character(char_id))
		char_buttons_container.add_child(btn)

func _select_character(char_id: StringName) -> void:
	current_character_id = char_id
	var info: Dictionary = character_roster[char_id]
	char_desc_label.text = "%s: %s" % [info["name"], info["desc"]]
	_refresh_banlist_ui()

func _get_current_character_bans() -> Array[StringName]:
	var bans_dict: Dictionary = profile_data.get("character_banlists", {})
	if bans_dict.has(current_character_id):
		return bans_dict[current_character_id]
	return []

func _refresh_banlist_ui() -> void:
	for child in items_grid.get_children():
		child.queue_free()

	var active_bans: Array[StringName] = _get_current_character_bans()
	ban_counter_label.text = "Baneos Activos: %d / %d" % [active_bans.size(), MAX_BANS]

	for item: ItemData in item_pool_manager.master_catalog:
		var is_banned: bool = active_bans.has(item.item_id)
		var card := _create_item_ban_card(item, is_banned, active_bans)
		items_grid.add_child(card)

func _create_item_ban_card(item: ItemData, is_banned: bool, active_bans: Array[StringName]) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 120)

	var vbox := VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 6)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_size_override("font_size", 14)

	var desc_lbl := Label.new()
	desc_lbl.text = item.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 12)

	var toggle_btn := Button.new()
	if is_banned:
		toggle_btn.text = "BANEADO [✗] (Excluido de la Run)"
		toggle_btn.modulate = Color(1.0, 0.3, 0.3)
	else:
		toggle_btn.text = "ACTIVO [✓] (Disponible)"
		toggle_btn.modulate = Color(0.3, 1.0, 0.4)

	toggle_btn.pressed.connect(func():
		var bans: Array[StringName] = _get_current_character_bans()
		if bans.has(item.item_id):
			bans.erase(item.item_id)
		else:
			if bans.size() < MAX_BANS:
				bans.append(item.item_id)
			else:
				# Límite alcanzado
				return

		if not profile_data.has("character_banlists"):
			profile_data["character_banlists"] = {}
		profile_data["character_banlists"][current_character_id] = bans

		SaveManager.save_profile(
			profile_data["unlocked_items"],
			profile_data["character_banlists"],
			profile_data["unlocked_characters"]
		)
		_refresh_banlist_ui()
	)

	vbox.add_child(name_lbl)
	vbox.add_child(desc_lbl)
	vbox.add_child(toggle_btn)
	panel.add_child(vbox)
	return panel

func _on_launch_pressed() -> void:
	var bans: Array[StringName] = _get_current_character_bans()
	launch_run_requested.emit(current_character_id, bans)
	# Cargar escena principal de combate
	get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")
