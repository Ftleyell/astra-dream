class_name CosmeticCarouselModal
extends CanvasLayer

## CosmeticCarouselModal.gd
## Modal de selección 2D minimalista para aspectos (Skins) de Pilotos, Exo-trajes y Armamento.
## - Horizontal (A / D, Flechas): Cicla las skins disponibles del personaje.
## - Vertical (W / S, Flechas): Cicla niveles de estrellas (1★, 2★, 3★).
## - Ítems bloqueados: Silueta negra con halo perimetral tenue y etiqueta [ BLOQUEADO ].
## - Pilotos HD: Usa ilustraciones de selección aplicando bottom_fade orgánico.
## - Minimalista: Clic en el blur exterior o tecla ESC confirma y cierra.

signal skin_modal_closed(category: String, target_id: StringName, equipped_skin_id: String)
signal skin_selected(slot_key: String, skin_id: String)

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const BLUR_SHADER := preload("res://shaders/screen_blur.gdshader")
const SILHOUETTE_SHADER := preload("res://shaders/silhouette_black_vfx.gdshader")
const HOLOGRAM_SHADER := preload("res://shaders/pilot_showcase_hologram.gdshader")

# Nodos UI
@onready var dim_overlay: ColorRect = $DimOverlay
@onready var root_hbox: HBoxContainer = $DimOverlay/CenterContainer/RootHBox
@onready var carousel_panel: PanelContainer = $DimOverlay/CenterContainer/RootHBox/CarouselPanel

# Carrusel
@onready var cards_row: HBoxContainer = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow
@onready var left_card: Button = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/LeftCard
@onready var left_texture: TextureRect = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/LeftCard/VBox/LeftTexture

@onready var center_column: VBoxContainer = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn
@onready var top_card: Button = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/TopCard
@onready var top_texture: TextureRect = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/TopCard/TopTexture

@onready var center_slot: Control = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot
@onready var artwork_frame: PanelContainer = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame
@onready var circular_glow: Control = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/GlowHolder/CircularGlow
@onready var artwork_viewport: Control = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/ArtworkViewport
@onready var artwork_texture: TextureRect = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/ArtworkViewport/ArtworkTexture
@onready var silhouette_overlay: TextureRect = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/ArtworkViewport/SilhouetteOverlay

@onready var locked_overlay: Control = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/LockedOverlay
@onready var lock_title: Label = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/LockedOverlay/LockCenter/LockTitle
@onready var lock_desc: Label = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/LockedOverlay/LockCenter/LockDesc

@onready var bottom_card: Button = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/BottomCard
@onready var bottom_texture: TextureRect = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/BottomCard/BottomTexture

@onready var right_card: Button = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/RightCard
@onready var right_texture: TextureRect = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/RightCard/VBox/RightTexture

@onready var dots_container: HBoxContainer = $DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/DotsContainer

# Dossier
@onready var floating_dossier: VBoxContainer = $DimOverlay/CenterContainer/RootHBox/FloatingDossier
@onready var index_badge: Label = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/DossierHeader/IndexBadge
@onready var category_label: Label = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/DossierHeader/CategoryLabel
@onready var name_label: Label = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/DossierHeader/HeaderRow/NameLabel
@onready var status_badge: Label = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/DossierHeader/HeaderRow/StatusBadge
@onready var stars_badge: Label = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/DossierHeader/StarsBadge
@onready var desc_label: Label = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/InfoCard/Margin/VBox/DescLabel
@onready var hint_footer_label: Label = $DimOverlay/CenterContainer/RootHBox/FloatingDossier/HintFooterLabel

# Estado
var is_open: bool = false
var current_category: String = "pilot" # "pilot", "ship", "weapon"
var current_target_id: StringName = &"nova"
var character_data_ref: CharacterData = null

var _available_skins: Array[Dictionary] = []
var _skin_index: int = 0
var _star_level: int = 1 # 1, 2, 3
var _max_unlocked_stars: int = 1

var _last_valid_equipped_skin: String = "base"
var _active_tween: Tween = null
var _silhouette_material: ShaderMaterial = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 125
	hide()

	_silhouette_material = ShaderMaterial.new()
	_silhouette_material.shader = SILHOUETTE_SHADER
	if silhouette_overlay:
		silhouette_overlay.material = _silhouette_material

	if dim_overlay:
		dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		dim_overlay.gui_input.connect(_on_dim_overlay_gui_input)

	if carousel_panel:
		carousel_panel.focus_mode = Control.FOCUS_ALL

	if left_card:
		left_card.focus_mode = Control.FOCUS_NONE
		left_card.pressed.connect(func() -> void: _cycle_skin(-1))
	if right_card:
		right_card.focus_mode = Control.FOCUS_NONE
		right_card.pressed.connect(func() -> void: _cycle_skin(1))
	if top_card:
		top_card.focus_mode = Control.FOCUS_NONE
		top_card.pressed.connect(func() -> void: _cycle_stars(-1))
	if bottom_card:
		bottom_card.focus_mode = Control.FOCUS_NONE
		bottom_card.pressed.connect(func() -> void: _cycle_stars(1))


func open_modal(p_category: String, p_target_id: StringName, p_char_data: CharacterData) -> void:
	current_category = p_category
	current_target_id = p_target_id
	character_data_ref = p_char_data
	is_open = true
	show()

	_setup_frame_dimensions()
	_load_available_skins()

	var loadout: Dictionary = SaveManager.get_character_loadout(current_target_id)
	var equipped: String = ""
	match current_category:
		"pilot":
			equipped = str(loadout.get("pilot_skin", ""))
		"ship":
			equipped = str(loadout.get("ship_skin", ""))
		"weapon":
			equipped = str(loadout.get("weapon_skin", ""))

	var slot_key: String = "%s:%s" % [current_category, String(current_target_id).to_lower()]
	if equipped.is_empty():
		equipped = SaveManager.get_equipped_skin(slot_key)
	if equipped.is_empty():
		equipped = "base"
	_last_valid_equipped_skin = equipped

	# Encontrar índice de la skin actualmente equipada
	_skin_index = 0
	for i in range(_available_skins.size()):
		if _available_skins[i].get("id", "") == equipped:
			_skin_index = i
			break

	var cur_skin: Dictionary = _available_skins[_skin_index] if not _available_skins.is_empty() else {}
	_max_unlocked_stars = cur_skin.get("unlocked_stars", 1)
	_star_level = cur_skin.get("stars", 1)

	_refresh_display()
	_build_dots()
	_animate_open()

	if carousel_panel:
		carousel_panel.call_deferred("grab_focus")


func close_modal() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	var slot_key: String = "%s:%s" % [current_category, String(current_target_id).to_lower()]
	var final_equipped: String = SaveManager.get_equipped_skin(slot_key)
	skin_modal_closed.emit(current_category, current_target_id, final_equipped)


func _on_dim_overlay_gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx(&"ui_click", 0.0, 1.0)
		close_modal()


func _input(event: InputEvent) -> void:
	if not is_open: return
	if event.is_action("ui_focus_next") or event.is_action("ui_focus_prev"):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled(); close_modal(); return

	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_A, KEY_LEFT]):
		get_viewport().set_input_as_handled(); _cycle_skin(-1); return
	if event.is_action_pressed("move_right") or event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_D, KEY_RIGHT]):
		get_viewport().set_input_as_handled(); _cycle_skin(1); return
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_W, KEY_UP]):
		get_viewport().set_input_as_handled(); _cycle_stars(-1); return
	if event.is_action_pressed("move_down") or event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_S, KEY_DOWN]):
		get_viewport().set_input_as_handled(); _cycle_stars(1); return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER]):
		get_viewport().set_input_as_handled(); _confirm_equip(); return


const CosmeticCarouselLayoutBuilderScript = preload("res://scenes/ui/cosmetics/cosmetic_carousel_layout_builder.gd")
var layout_builder: RefCounted = CosmeticCarouselLayoutBuilderScript.new()


func _setup_frame_dimensions() -> void:
	if layout_builder:
		layout_builder.setup_frame_dimensions(
			current_category, carousel_panel, center_slot, artwork_frame,
			category_label, hint_footer_label, artwork_texture, silhouette_overlay
		)


func _apply_artwork_transform(offset_pos: Vector2, target_scale: Vector2) -> void:
	if layout_builder:
		layout_builder.apply_artwork_transform(artwork_texture, silhouette_overlay, offset_pos, target_scale)


func _load_available_skins() -> void:
	if layout_builder:
		_available_skins = layout_builder.load_available_skins(current_category, current_target_id, character_data_ref)


func _cycle_skin(dir: int) -> void:
	if _available_skins.size() <= 1:
		return
	_skin_index = (_skin_index + dir + _available_skins.size()) % _available_skins.size()
	var skin: Dictionary = _available_skins[_skin_index]
	_max_unlocked_stars = skin.get("unlocked_stars", 1)
	_star_level = clampi(skin.get("stars", 1), 1, 3)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_hover", 0.0, 1.1)

	_refresh_display()
	_build_dots()
	_animate_skin_transition(dir)
	_auto_equip_if_unlocked()


func _cycle_stars(dir: int) -> void:
	_star_level = clampi(_star_level + dir, 1, 3)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.2)

	_refresh_display()
	_animate_stars_transition(dir)
	_auto_equip_if_unlocked()


func _confirm_equip() -> void:
	_auto_equip_if_unlocked()
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.0)
	close_modal()


func _auto_equip_if_unlocked() -> void:
	if _available_skins.is_empty():
		return
	var cur: Dictionary = _available_skins[_skin_index]
	var sid: String = cur.get("id", "base")
	var is_unl: bool = cur.get("is_unlocked", false)
	var unl_stars: int = cur.get("unlocked_stars", 1)

	var slot_key: String = "%s:%s" % [current_category, String(current_target_id).to_lower()]
	if is_unl and _star_level <= unl_stars:
		SaveManager.equip_skin(slot_key, sid)
		if not cur.get("is_base", false):
			SaveManager.set_skin_stars(sid, _star_level)
		_last_valid_equipped_skin = sid

		var loadout: Dictionary = SaveManager.get_character_loadout(current_target_id)
		match current_category:
			"pilot":
				loadout["pilot_skin"] = sid
				loadout["equipped_pilot_skin"] = sid
			"ship":
				loadout["ship_skin"] = sid
				loadout["equipped_ship_skin"] = sid
			"weapon":
				loadout["weapon_skin"] = sid
				loadout["equipped_weapon_skin"] = sid
		SaveManager.set_character_loadout(current_target_id, loadout)

		skin_selected.emit(slot_key, sid)


func _refresh_display() -> void:
	if layout_builder:
		layout_builder.refresh_display(
			self, _available_skins, _skin_index, _star_level,
			current_category, current_target_id, _silhouette_material
		)


func _build_dots() -> void:
	if layout_builder:
		layout_builder.build_dots(dots_container, _available_skins, _skin_index)


func _animate_open() -> void:
	root_hbox.scale = Vector2(0.94, 0.94)
	root_hbox.modulate.a = 0.0
	root_hbox.pivot_offset = root_hbox.size * 0.5

	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(root_hbox, "scale", Vector2.ONE, 0.22)
	tw.tween_property(root_hbox, "modulate:a", 1.0, 0.18)


func _animate_skin_transition(dir: int) -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	artwork_viewport.position.x = 40.0 * float(dir)
	artwork_viewport.modulate.a = 0.4

	_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(artwork_viewport, "position:x", 0.0, 0.16)
	_active_tween.tween_property(artwork_viewport, "modulate:a", 1.0, 0.16)


func _animate_stars_transition(dir: int) -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	artwork_viewport.position.y = 30.0 * float(dir)
	artwork_viewport.modulate.a = 0.5

	_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(artwork_viewport, "position:y", 0.0, 0.14)
	_active_tween.tween_property(artwork_viewport, "modulate:a", 1.0, 0.14)


func get_available_skins_count() -> int: return _available_skins.size()
func get_current_skin_index() -> int: return _skin_index
func get_current_stars() -> int: return _star_level
func cycle_skins_for_test(dir: int) -> void: _cycle_skin(dir)
func cycle_stars_for_test(dir: int) -> void: _cycle_stars(dir)
func equip_current_for_test() -> void: _confirm_equip()

func set_stars_for_test(stars: int) -> void:
	_star_level = clampi(stars, 1, 3)
	_refresh_display()

func select_skin_by_id_for_test(skin_id: String) -> bool:
	for i in range(_available_skins.size()):
		if _available_skins[i].get("id", "") == skin_id:
			_skin_index = i
			var cur: Dictionary = _available_skins[i]
			_max_unlocked_stars = cur.get("unlocked_stars", 1)
			_star_level = clampi(cur.get("stars", 1), 1, 3)
			_refresh_display()
			_build_dots()
			return true
	return false

func unequip_to_default_for_test() -> void:
	var slot_key: String = "%s:%s" % [current_category, String(current_target_id).to_lower()]
	SaveManager.unequip_skin(slot_key)
	var loadout: Dictionary = SaveManager.get_character_loadout(current_target_id)
	match current_category:
		"pilot": loadout["pilot_skin"] = ""; loadout["equipped_pilot_skin"] = ""
		"ship": loadout["ship_skin"] = ""; loadout["equipped_ship_skin"] = ""
		"weapon": loadout["weapon_skin"] = ""; loadout["equipped_weapon_skin"] = ""
	SaveManager.set_character_loadout(current_target_id, loadout)
	_last_valid_equipped_skin = ""
	skin_selected.emit(slot_key, "")
	_refresh_display()

