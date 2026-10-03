class_name PetSelectionModal
extends CanvasLayer

## PetSelectionModal.gd
## Modal de selección de compañeros astrales (Mascotas/Pets) y skins CoverFlow.
## Coordina la selección activa, persistencia en SaveManager e inputs,
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
@onready var index_badge: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ModalHeader/IndexBadge

@onready var prev_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/PrevButton
@onready var next_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/NextButton

@onready var left_card: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/LeftCard
@onready var left_texture: TextureRect = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/LeftCard/VBox/LeftTexture
@onready var left_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/LeftCard/VBox/LeftLabel

@onready var artwork_frame: PanelContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame
@onready var artwork_viewport: Control = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame/ArtworkViewport
@onready var fullbody_texture: TextureRect = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame/ArtworkViewport/FullbodyTexture
@onready var locked_overlay: Control = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame/LockedOverlay
@onready var lock_desc: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/ArtworkFrame/LockedOverlay/LockCenter/LockDesc

@onready var right_card: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/RightCard
@onready var right_texture: TextureRect = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/RightCard/VBox/RightTexture
@onready var right_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/CoverFlowRow/CardsRow/RightCard/VBox/RightLabel

@onready var dots_container: HBoxContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CoverFlowSection/DotsContainer

@onready var name_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/HeaderRow/NameLabel
@onready var title_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/HeaderRow/TitleLabel
@onready var status_badge: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/HeaderRow/StatusBadge

@onready var bio_desc: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/CardsRow/BioCard/Margin/VBox/BioDesc
@onready var power_card: PanelContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/CardsRow/PowerCard
@onready var power_desc: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/CardsRow/PowerCard/Margin/VBox/PowerDesc

@onready var select_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/ActionsRow/SelectButton
@onready var close_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierPanel/Margin/DossierVBox/ActionsRow/CloseButton

var is_open: bool = false
var current_index: int = 0
var _pets: Array[PetData] = []
var _is_skin_mode: bool = false
var _pet_skins: Array[Dictionary] = []
var _skin_index: int = 0
var skins_btn: Button = null

var _nav_buttons: Array[Button]:
	get:
		return cover_flow_renderer.nav_buttons if cover_flow_renderer else []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 125
	hide()

	_init_components()

	if select_btn:
		select_btn.pressed.connect(_on_select_pressed)
		UIFocusHelper.apply_cyber_focus(select_btn)
	if close_btn:
		close_btn.pressed.connect(close_modal)
		UIFocusHelper.apply_cyber_focus(close_btn)

	# Inyectar botón de Aspectos / Skins en ActionsRow
	skins_btn = Button.new()
	skins_btn.name = "SkinsButton"
	skins_btn.text = "🎨 ASPECTOS / SKINS"
	skins_btn.custom_minimum_size = Vector2(180, 44)
	skins_btn.pressed.connect(_on_skins_toggle_pressed)
	UIFocusHelper.apply_cyber_focus(skins_btn)
	if select_btn and select_btn.get_parent():
		select_btn.get_parent().add_child(skins_btn)
		select_btn.get_parent().move_child(skins_btn, select_btn.get_index() + 1)

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
		Callable(self, "_cycle")
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
	_is_skin_mode = false
	show()
	_populate_pets()
	if select_btn and not select_btn.disabled:
		select_btn.grab_focus()
	elif next_btn:
		next_btn.grab_focus()
	elif close_btn:
		close_btn.grab_focus()


func close_modal() -> void:
	if not is_open:
		return
	if _is_skin_mode:
		_is_skin_mode = false
		_populate_pets()
		return
	is_open = false
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_modal()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A or event.keycode == KEY_LEFT or event.keycode == KEY_W or event.keycode == KEY_UP:
			get_viewport().set_input_as_handled()
			_cycle(-1)
			return
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT or event.keycode == KEY_S or event.keycode == KEY_DOWN:
			get_viewport().set_input_as_handled()
			_cycle(1)
			return
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if select_btn and not select_btn.disabled:
				get_viewport().set_input_as_handled()
				_on_select_pressed()
				return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			get_viewport().set_input_as_handled()
			_cycle(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()
			_cycle(1)


func _populate_pets() -> void:
	_pets = PetDataScript.load_roster_ordered()

	var selected_pid := SaveManager.get_selected_pet()
	var initial_index: int = 0
	for i in range(_pets.size()):
		if _pets[i].pet_id == selected_pid:
			initial_index = i
			break
	current_index = initial_index

	if skins_btn:
		skins_btn.text = "🎨 ASPECTOS / SKINS"
		skins_btn.modulate = Color(1.0, 0.85, 0.2, 1.0)

	_build_dots(_pets.size(), current_index)
	_display_current_pet(false, 0)


func _populate_pet_skins() -> void:
	if _pets.is_empty():
		return
	var cur_pet := _pets[current_index]
	var pid_str := String(cur_pet.pet_id).to_lower()
	_pet_skins = CosmeticsManager.get_skins_for_target("pet", pid_str)

	var slot_key := "pet:" + pid_str
	var equipped_sid := SaveManager.get_equipped_skin(slot_key)
	_skin_index = 0
	for i in range(_pet_skins.size()):
		if _pet_skins[i].get("id", "") == equipped_sid:
			_skin_index = i
			break

	if skins_btn:
		skins_btn.text = "↺ VOLVER A MASCOTAS"
		skins_btn.modulate = Color(0.2, 0.9, 1.0, 1.0)

	_build_dots(_pet_skins.size(), _skin_index)
	_display_current_skin(false, 0)


func _build_dots(count: int, active_idx: int) -> void:
	if cover_flow_renderer:
		cover_flow_renderer.build_dots(count, active_idx, Callable(self, "_on_dot_selected"))


func _on_dot_selected(target_idx: int) -> void:
	var cur := _skin_index if _is_skin_mode else current_index
	if cur != target_idx:
		var dir: int = 1 if target_idx > cur else -1
		_set_index(target_idx, dir)


func _cycle(direction: int) -> void:
	if _is_skin_mode:
		if _pet_skins.is_empty():
			return
		var count := _pet_skins.size()
		var next_idx := (_skin_index + direction) % count
		if next_idx < 0:
			next_idx += count
		_set_index(next_idx, direction)
	else:
		if _pets.is_empty():
			return
		var count := _pets.size()
		var next_idx := (current_index + direction) % count
		if next_idx < 0:
			next_idx += count
		_set_index(next_idx, direction)


func _set_index(new_idx: int, slide_direction: int = 0) -> void:
	if _is_skin_mode:
		if new_idx == _skin_index:
			return
		_skin_index = new_idx
		_display_current_skin(true, slide_direction)
	else:
		if new_idx == current_index:
			return
		current_index = new_idx
		_display_current_pet(true, slide_direction)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_hover", 0.0, 1.1)


func _display_current_pet(animate: bool = true, slide_direction: int = 0) -> void:
	if _pets.is_empty() or current_index < 0 or current_index >= _pets.size():
		return

	var count := _pets.size()
	var pet_data: PetData = _pets[current_index]
	var pid: StringName = pet_data.pet_id
	var is_unlocked: bool = SaveManager.is_pet_unlocked(pid)
	var is_selected: bool = (pid == SaveManager.get_selected_pet())

	var left_idx := (current_index - 1 + count) % count
	var right_idx := (current_index + 1) % count
	var left_data: PetData = _pets[left_idx]
	var right_data: PetData = _pets[right_idx]

	var slot_key := "pet:" + String(pid).to_lower()
	var equipped_skin := SaveManager.get_equipped_skin(slot_key)
	var skin_stars: int = 0
	if equipped_skin != "" and SaveManager.is_skin_unlocked(equipped_skin):
		skin_stars = SaveManager.get_skin_stars(equipped_skin)
	else:
		equipped_skin = ""

	cover_flow_renderer.render_pet_cards(pet_data, left_data, right_data, is_unlocked, equipped_skin, skin_stars)
	cover_flow_renderer.update_dots(pet_data.theme_color, current_index)
	cover_flow_renderer.animate_center_card(animate, slide_direction, is_unlocked)

	dossier_controller.display_pet(pet_data, is_unlocked, is_selected, current_index, count)


func _display_current_skin(animate: bool = true, slide_direction: int = 0) -> void:
	if _pet_skins.is_empty():
		return

	var count := _pet_skins.size()
	var cur_skin: Dictionary = _pet_skins[_skin_index]
	var sid: String = cur_skin.get("id", "")
	var is_unlocked: bool = bool(SaveManager.is_skin_unlocked(sid))
	var stars: int = SaveManager.get_skin_stars(sid) if is_unlocked else 1

	var slot_key := "pet:" + String(_pets[current_index].pet_id).to_lower()
	var currently_equipped := SaveManager.get_equipped_skin(slot_key)
	var is_equipped: bool = (currently_equipped == sid)

	var left_idx := (_skin_index - 1 + count) % count
	var right_idx := (_skin_index + 1) % count
	var left_skin: Dictionary = _pet_skins[left_idx]
	var right_skin: Dictionary = _pet_skins[right_idx]

	cover_flow_renderer.render_skin_cards(cur_skin, left_skin, right_skin, is_unlocked, stars)
	cover_flow_renderer.update_dots(Color(1.0, 0.85, 0.2), _skin_index)
	cover_flow_renderer.animate_center_card(animate, slide_direction, is_unlocked)

	dossier_controller.display_skin(cur_skin, is_unlocked, is_equipped, stars, _skin_index, count)


# Delegados auxiliares para retrocompatibilidad con tests existentes
func _update_dots(active_color: Color, active_idx: int) -> void:
	if cover_flow_renderer:
		cover_flow_renderer.update_dots(active_color, active_idx)


func _animate_center_card(animate: bool, slide_direction: int, p_is_unlocked: bool) -> void:
	if cover_flow_renderer:
		cover_flow_renderer.animate_center_card(animate, slide_direction, p_is_unlocked)


func _on_skins_toggle_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.2)

	if _is_skin_mode:
		_is_skin_mode = false
		_populate_pets()
	else:
		_is_skin_mode = true
		_populate_pet_skins()


func _on_select_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.25)

	if _is_skin_mode:
		if _pet_skins.is_empty():
			return
		var cur_skin: Dictionary = _pet_skins[_skin_index]
		var sid: String = cur_skin.get("id", "")
		var slot_key := "pet:" + String(_pets[current_index].pet_id).to_lower()
		var currently_equipped := SaveManager.get_equipped_skin(slot_key)

		if currently_equipped == sid:
			SaveManager.unequip_skin(slot_key)
			skin_equipped.emit(slot_key, "")
		elif SaveManager.is_skin_unlocked(sid):
			SaveManager.equip_skin(slot_key, sid)
			skin_equipped.emit(slot_key, sid)

		_display_current_skin(false, 0)
	else:
		if _pets.is_empty() or current_index < 0 or current_index >= _pets.size():
			return
		var pet_data = _pets[current_index]
		var pid: StringName = pet_data.pet_id
		if not SaveManager.is_pet_unlocked(pid):
			return
		SaveManager.set_selected_pet(pid)
		pet_selected.emit(pid)
		close_modal()


func _setup_focus_neighbors() -> void:
	if left_card:
		left_card.focus_mode = Control.FOCUS_NONE
	if right_card:
		right_card.focus_mode = Control.FOCUS_NONE

	if prev_btn and next_btn and select_btn and close_btn:
		prev_btn.focus_neighbor_right = next_btn.get_path()
		prev_btn.focus_neighbor_bottom = select_btn.get_path()
		next_btn.focus_neighbor_left = prev_btn.get_path()
		next_btn.focus_neighbor_bottom = select_btn.get_path()
		select_btn.focus_neighbor_top = next_btn.get_path()
		if skins_btn:
			select_btn.focus_neighbor_right = skins_btn.get_path()
			skins_btn.focus_neighbor_left = select_btn.get_path()
			skins_btn.focus_neighbor_right = close_btn.get_path()
			close_btn.focus_neighbor_left = skins_btn.get_path()
		else:
			select_btn.focus_neighbor_right = close_btn.get_path()
			close_btn.focus_neighbor_left = select_btn.get_path()
		close_btn.focus_neighbor_top = next_btn.get_path()
