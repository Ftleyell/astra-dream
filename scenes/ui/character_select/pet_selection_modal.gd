class_name PetSelectionModal
extends CanvasLayer

## PetSelectionModal.gd
## Modal de selección de compañeros astrales (Mascotas/Pets) y skins CoverFlow.
## Coordina la selección activa, persistencia en SaveManager e inputs en carrusel 2D con profundidad,
## delegando la presentación visual a PetCoverFlowRenderer y PetDossierController.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const PetDataScript = preload("res://data/pets/pet_data.gd")
const PetCoverFlowRenderer = preload("res://scenes/ui/character_select/components/pet_cover_flow_renderer.gd")
const PetDossierController = preload("res://scenes/ui/character_select/components/pet_dossier_controller.gd")

signal pet_selected(pet_id: StringName)
signal skin_equipped(slot_key: String, skin_id: String)
signal closed()

# Componentes Modulares
var cover_flow_renderer: PetCoverFlowRenderer = null
var dossier_controller: PetDossierController = null

# Nodos de la escena accesibles para suites de tests y dependencias externas
@onready var dim_overlay: ColorRect = $DimOverlay
@onready var root_hbox: HBoxContainer = $DimOverlay/CenterContainer/RootHBox
@onready var index_badge: Label = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/DossierHeader/IndexBadge

var prev_btn: Button = null
var next_btn: Button = null

@onready var carousel_panel: PanelContainer = $DimOverlay/CenterContainer/RootHBox/CarouselPanel
@onready var cards_row: HBoxContainer = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow
@onready var left_card: Button = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/LeftCard
@onready var left_texture: TextureRect = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/LeftCard/VBox/LeftTexture
@onready var left_label: Label = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/LeftCard/VBox/LeftLabel

@onready var center_column: VBoxContainer = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn
@onready var top_card: Button = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/TopCard
@onready var top_texture: TextureRect = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/TopCard/TopTexture

@onready var artwork_frame: PanelContainer = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame
@onready var artwork_viewport: Control = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/ArtworkViewport
@onready var fullbody_texture: TextureRect = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/ArtworkViewport/FullbodyTexture
@onready var locked_overlay: Control = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/LockedOverlay
@onready var lock_desc: Label = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/LockedOverlay/LockCenter/LockDesc

@onready var bottom_card: Button = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/BottomCard
@onready var bottom_texture: TextureRect = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/BottomCard/BottomTexture

@onready var right_card: Button = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/RightCard
@onready var right_texture: TextureRect = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/RightCard/VBox/RightTexture
@onready var right_label: Label = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/RightCard/VBox/RightLabel

@onready var dots_container: HBoxContainer = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/DotsContainer

@onready var name_label: Label = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/DossierHeader/HeaderRow/NameLabel
@onready var title_label: Label = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/DossierHeader/TitleLabel
@onready var status_badge: Label = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/DossierHeader/HeaderRow/StatusBadge

@onready var bio_desc: Label = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/BioCard/Margin/VBox/BioDesc
@onready var power_card: PanelContainer = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/PowerCard
@onready var power_desc: Label = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/PowerCard/Margin/VBox/PowerDesc

@onready var select_btn: Button = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/ActionsRow/SelectButton
@onready var close_btn: Button = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/ActionsRow/CloseButton

var is_open: bool = false
var current_index: int = 0
var _pets: Array[PetData] = []
var _available_skins: Array[Dictionary] = []
var _skin_index: int = 0

var _nav_buttons: Array[Button]:
	get:
		return cover_flow_renderer.nav_buttons if cover_flow_renderer else []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 125
	hide()

	_init_components()

	if dim_overlay:
		dim_overlay.gui_input.connect(_on_dim_overlay_gui_input)

	if artwork_frame:
		artwork_frame.gui_input.connect(_on_artwork_frame_gui_input)

	if select_btn:
		select_btn.pressed.connect(_on_select_pressed)
		select_btn.focus_mode = Control.FOCUS_NONE
	if close_btn:
		close_btn.pressed.connect(close_modal)
		close_btn.focus_mode = Control.FOCUS_NONE

	if carousel_panel:
		carousel_panel.focus_mode = Control.FOCUS_ALL
		carousel_panel.focus_neighbor_left = carousel_panel.get_path()
		carousel_panel.focus_neighbor_right = carousel_panel.get_path()
		carousel_panel.focus_neighbor_top = carousel_panel.get_path()
		carousel_panel.focus_neighbor_bottom = carousel_panel.get_path()
		carousel_panel.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	_setup_focus_neighbors()


func _init_components() -> void:
	cover_flow_renderer = PetCoverFlowRenderer.new()
	cover_flow_renderer.setup(
		prev_btn,
		next_btn,
		left_card,
		left_texture,
		left_label,
		artwork_frame,
		artwork_viewport,
		fullbody_texture,
		locked_overlay,
		lock_desc,
		right_card,
		right_texture,
		right_label,
		dots_container,
		Callable(self, "_cycle_horizontal"),
		cards_row
	)
	cover_flow_renderer.setup_vertical(
		top_card,
		top_texture,
		bottom_card,
		bottom_texture,
		Callable(self, "_cycle_vertical")
	)

	dossier_controller = PetDossierController.new()
	dossier_controller.setup(
		index_badge,
		name_label,
		title_label,
		status_badge,
		bio_desc,
		power_card,
		power_desc,
		select_btn
	)


func open_modal() -> void:
	is_open = true
	show()
	if carousel_panel:
		carousel_panel.call_deferred("grab_focus")
	_populate_pets()


func close_modal() -> void:
	if not is_open:
		return
	is_open = false
	if get_viewport():
		get_viewport().gui_release_focus()
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	# 1. Consumir siempre navegación Tab (focus next/prev) para que nunca escape al fondo
	if event.is_action("ui_focus_next") or event.is_action("ui_focus_prev"):
		get_viewport().set_input_as_handled()
		return

	# 2. Confirmación y cierre con Escape
	if event.is_action("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo():
			_confirm_and_close()
		return

	# 3. Confirmación y selección con Espacio / Enter
	if event.is_action("ui_accept") or (event is InputEventKey and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo():
			_confirm_and_close()
		return

	# 4. Navegación horizontal (A / D / Izquierda / Derecha)
	if event.is_action("ui_left") or (event is InputEventKey and (event.keycode == KEY_A or event.keycode == KEY_LEFT)):
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo():
			_cycle_horizontal(-1)
		return
	elif event.is_action("ui_right") or (event is InputEventKey and (event.keycode == KEY_D or event.keycode == KEY_RIGHT)):
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo():
			_cycle_horizontal(1)
		return

	# 5. Navegación vertical (W / S / Arriba / Abajo)
	if event.is_action("ui_up") or (event is InputEventKey and (event.keycode == KEY_W or event.keycode == KEY_UP)):
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo():
			_cycle_vertical(-1)
		return
	elif event.is_action("ui_down") or (event is InputEventKey and (event.keycode == KEY_S or event.keycode == KEY_DOWN)):
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo():
			_cycle_vertical(1)
		return

	# 6. Rueda del ratón para navegación vertical
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			get_viewport().set_input_as_handled()
			_cycle_vertical(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()
			_cycle_vertical(1)


func _on_dim_overlay_gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if root_hbox:
			var mouse_pos := root_hbox.get_local_mouse_position()
			var bounds := Rect2(Vector2.ZERO, root_hbox.size)
			if not bounds.has_point(mouse_pos):
				get_viewport().set_input_as_handled()
				_confirm_and_close()


func _on_artwork_frame_gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_confirm_and_close()


func _confirm_and_close() -> void:
	if select_btn and not select_btn.disabled:
		_on_select_pressed()
	else:
		close_modal()


func _populate_pets() -> void:
	_pets = PetDataScript.load_roster_ordered()

	var selected_pid := SaveManager.get_selected_pet()
	var initial_index: int = 0
	for i in range(_pets.size()):
		if _pets[i].pet_id == selected_pid:
			initial_index = i
			break
	current_index = initial_index

	_load_available_skins()
	_build_dots(_pets.size(), current_index)
	_display_current_pet(false, 0, 0)


func _load_available_skins() -> void:
	_available_skins.clear()
	if _pets.is_empty() or current_index < 0 or current_index >= _pets.size():
		return
	var cur_pet := _pets[current_index]
	var pid_str: String = String(cur_pet.pet_id).to_lower()
	var slot_key: String = "pet:" + pid_str

	# Slot 0: Aspecto base/estándar
	var base_skin: Dictionary = {
		"id": "",
		"skin_name": "Aspecto Estándar",
		"texture": cur_pet.get_icon_texture(),
		"is_base": true,
		"is_unlocked": true,
		"stars": 0,
		"glow_hex": "#FF9900"
	}
	_available_skins.append(base_skin)

	# Slots 1..N: Aspectos alternativos
	var raw_skins: Array[Dictionary] = CosmeticsManager.get_skins_for_target("pet", pid_str)
	for s in raw_skins:
		var sid: String = s.get("id", "")
		var is_unlocked: bool = bool(SaveManager.is_skin_unlocked(sid))
		var stars: int = SaveManager.get_skin_stars(sid) if is_unlocked else 1
		var tex: Texture2D = CosmeticsManager.load_texture(s.get("texture_path", ""))
		if not tex:
			tex = cur_pet.get_icon_texture()
		var skin_entry: Dictionary = {
			"id": sid,
			"skin_name": s.get("name", "Aspecto"),
			"texture": tex,
			"is_base": false,
			"is_unlocked": is_unlocked,
			"stars": stars,
			"glow_hex": s.get("glow_hex", "#FF9900"),
			"desc": s.get("desc", "")
		}
		_available_skins.append(skin_entry)

	var equipped_sid: String = SaveManager.get_equipped_skin(slot_key)
	_skin_index = 0
	if not equipped_sid.is_empty():
		for i in range(1, _available_skins.size()):
			if _available_skins[i].get("id", "") == equipped_sid:
				_skin_index = i
				break


func _build_dots(count: int, active_idx: int) -> void:
	if cover_flow_renderer:
		cover_flow_renderer.build_dots(count, active_idx, Callable(self, "_on_dot_selected"))


func _on_dot_selected(target_idx: int) -> void:
	if current_index != target_idx:
		var dir: int = 1 if target_idx > current_index else -1
		_set_index(target_idx, dir)


# Método retrocompatible con test suites existentes
func _cycle(direction: int) -> void:
	_cycle_horizontal(direction)


func _cycle_horizontal(direction: int) -> void:
	if _pets.is_empty():
		return
	var count: int = _pets.size()
	var next_idx: int = (current_index + direction) % count
	if next_idx < 0:
		next_idx += count
	_set_index(next_idx, direction)


func _cycle_vertical(direction: int) -> void:
	if _available_skins.size() <= 1:
		return
	var count: int = _available_skins.size()
	var next_idx: int = (_skin_index + direction) % count
	if next_idx < 0:
		next_idx += count
	_set_skin_index(next_idx, direction)


func _set_index(new_idx: int, slide_direction: int = 0) -> void:
	if new_idx == current_index:
		return
	current_index = new_idx
	_load_available_skins()
	_display_current_pet(true, slide_direction, 0)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_hover", 0.0, 1.1)


func _set_skin_index(new_skin_idx: int, slide_v: int = 0) -> void:
	if new_skin_idx == _skin_index:
		return
	_skin_index = new_skin_idx
	_display_current_pet(true, 0, slide_v)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_hover", 0.0, 1.2)


func _display_current_pet(animate: bool = true, slide_h: int = 0, slide_v: int = 0) -> void:
	if _pets.is_empty() or current_index < 0 or current_index >= _pets.size():
		return

	var count: int = _pets.size()
	var pet_data: PetData = _pets[current_index]
	var pid: StringName = pet_data.pet_id
	var is_unlocked: bool = SaveManager.is_pet_unlocked(pid)
	var is_selected: bool = (pid == SaveManager.get_selected_pet())

	var left_idx: int = (current_index - 1 + count) % count
	var right_idx: int = (current_index + 1) % count
	var left_data: PetData = _pets[left_idx]
	var right_data: PetData = _pets[right_idx]

	cover_flow_renderer.render_2d_carousel(pet_data, left_data, right_data, _available_skins, _skin_index, is_unlocked)
	cover_flow_renderer.update_carousel_layout(false, pet_data.theme_color)
	cover_flow_renderer.update_dots(pet_data.theme_color, current_index)
	cover_flow_renderer.animate_center_card_2d(animate, slide_h, slide_v, is_unlocked)

	if _skin_index > 0 and _skin_index < _available_skins.size():
		var cur_skin: Dictionary = _available_skins[_skin_index]
		var sid: String = cur_skin.get("id", "")
		var s_unlocked: bool = bool(cur_skin.get("is_unlocked", false))
		var pid_str: String = String(pid).to_lower()
		var slot_key: String = "pet:" + pid_str
		var is_equipped: bool = (SaveManager.get_equipped_skin(slot_key) == sid)
		var stars: int = int(cur_skin.get("stars", 1))
		dossier_controller.display_skin(cur_skin, s_unlocked, is_equipped, stars, _skin_index, _available_skins.size())
		if title_label:
			title_label.text = "%s • [%s]" % [pet_data.title, cur_skin.get("skin_name", "").to_upper()]
	else:
		dossier_controller.display_pet(pet_data, is_unlocked, is_selected, current_index, count)


# Métodos delegados para retrocompatibilidad con tests existentes
func _update_dots(active_color: Color, active_idx: int) -> void:
	if cover_flow_renderer:
		cover_flow_renderer.update_dots(active_color, active_idx)


func _animate_center_card(animate: bool, slide_direction: int, p_is_unlocked: bool) -> void:
	if cover_flow_renderer:
		cover_flow_renderer.animate_center_card_2d(animate, slide_direction, 0, p_is_unlocked)


func _on_select_pressed() -> void:
	if _pets.is_empty() or current_index < 0 or current_index >= _pets.size():
		return
	var pet_data = _pets[current_index]
	var pid: StringName = pet_data.pet_id
	if not SaveManager.is_pet_unlocked(pid):
		return

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.25)

	# 1. Fijar mascota seleccionada
	SaveManager.set_selected_pet(pid)
	pet_selected.emit(pid)

	# 2. Equipar skin activa (o desequipar si es Slot 0)
	var pid_str: String = String(pid).to_lower()
	var slot_key: String = "pet:" + pid_str
	if _skin_index > 0 and _skin_index < _available_skins.size():
		var cur_skin: Dictionary = _available_skins[_skin_index]
		var sid: String = cur_skin.get("id", "")
		if SaveManager.is_skin_unlocked(sid):
			SaveManager.equip_skin(slot_key, sid)
			skin_equipped.emit(slot_key, sid)
	else:
		SaveManager.unequip_skin(slot_key)
		skin_equipped.emit(slot_key, "")

	close_modal()


func _setup_focus_neighbors() -> void:
	if left_card:
		left_card.focus_mode = Control.FOCUS_NONE
	if right_card:
		right_card.focus_mode = Control.FOCUS_NONE
	if top_card:
		top_card.focus_mode = Control.FOCUS_NONE
	if bottom_card:
		bottom_card.focus_mode = Control.FOCUS_NONE

	if select_btn:
		select_btn.focus_mode = Control.FOCUS_NONE
	if close_btn:
		close_btn.focus_mode = Control.FOCUS_NONE
