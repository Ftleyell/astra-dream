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
	if not is_open:
		return

	if event.is_action("ui_focus_next") or event.is_action("ui_focus_prev"):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_modal()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A, KEY_LEFT:
				_cycle_skin(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_D, KEY_RIGHT:
				_cycle_skin(1)
				get_viewport().set_input_as_handled()
				return
			KEY_W, KEY_UP:
				_cycle_stars(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_S, KEY_DOWN:
				_cycle_stars(1)
				get_viewport().set_input_as_handled()
				return
			KEY_SPACE, KEY_ENTER:
				_confirm_equip()
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("ui_accept"):
		_confirm_equip()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_cycle_skin(-1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_cycle_skin(1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		_cycle_stars(-1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		_cycle_stars(1)
		get_viewport().set_input_as_handled()
		return


func _setup_frame_dimensions() -> void:
	carousel_panel.custom_minimum_size = Vector2(580, 640)
	match current_category:
		"pilot":
			center_slot.custom_minimum_size = Vector2(360, 500)
			artwork_frame.custom_minimum_size = Vector2(360, 500)
			category_label.text = "HEROÍNA // PILOTO ESTELAR"
			hint_footer_label.text = "✦ [A / D] ASPECTOS  ✦  [W / S] ESTRELLAS  ✦  [ESPACIO] EQUIPAR  ✦  [ESC] SALIR"
			_apply_artwork_transform(Vector2.ZERO, Vector2.ONE)
		"ship":
			center_slot.custom_minimum_size = Vector2(320, 320)
			artwork_frame.custom_minimum_size = Vector2(320, 320)
			category_label.text = "EXO-TRAJE // AERONAVE DE COMBATE"
			hint_footer_label.text = "✦ [A / D] ASPECTOS  ✦  [W / S] ESTRELLAS  ✦  [ESPACIO] EQUIPAR  ✦  [ESC] SALIR"
			_apply_artwork_transform(Vector2.ZERO, Vector2.ONE)
		"weapon":
			center_slot.custom_minimum_size = Vector2(320, 320)
			artwork_frame.custom_minimum_size = Vector2(320, 320)
			category_label.text = "ARMAMENTO // SISTEMA BALÍSTICO"
			hint_footer_label.text = "✦ [A / D] ASPECTOS  ✦  [W / S] ESTRELLAS  ✦  [ESPACIO] EQUIPAR  ✦  [ESC] SALIR"
			# Centrado óptico compensado: los sprites 256x256 están cargados a la derecha (X: 88..247)
			_apply_artwork_transform(Vector2(-38.0, 0.0), Vector2(1.15, 1.15))


func _apply_artwork_transform(offset_pos: Vector2, target_scale: Vector2) -> void:
	if artwork_texture:
		artwork_texture.pivot_offset = artwork_texture.size * 0.5
		artwork_texture.position = offset_pos
		artwork_texture.scale = target_scale
	if silhouette_overlay:
		silhouette_overlay.pivot_offset = silhouette_overlay.size * 0.5
		silhouette_overlay.position = offset_pos
		silhouette_overlay.scale = target_scale


func _load_available_skins() -> void:
	_available_skins.clear()
	var tid_str: String = String(current_target_id).to_lower()

	# 1. Skin Base (siempre presente y siempre desbloqueada)
	var base_tex: Texture2D = _get_base_texture()
	var base_skin: Dictionary = {
		"id": "base",
		"skin_name": "%s Base" % (character_data_ref.display_name if character_data_ref else "Original"),
		"description": "Aspecto operativo estándar de despliegue estelar.",
		"rarity": "common",
		"is_base": true,
		"is_unlocked": true,
		"unlocked_stars": 3,
		"stars": 1,
		"texture": base_tex,
		"glow_color": character_data_ref.color if character_data_ref else Color(0.2, 0.85, 1.0)
	}
	_available_skins.append(base_skin)

	# 2. Skins alternativas desde CosmeticsManager
	var catalog_skins: Array[Dictionary] = CosmeticsManager.get_skins_for_target(current_category, tid_str)
	for s in catalog_skins:
		var sid: String = s.get("id", "")
		var is_unl: bool = SaveManager.is_skin_unlocked(sid)
		var stars: int = SaveManager.get_skin_stars(sid) if is_unl else 1
		var tex: Texture2D = _get_skin_texture(s)
		var glow_hex: String = s.get("glow_hex", "#00f0ff")
		var glow_col := Color(glow_hex)

		var entry: Dictionary = {
			"id": sid,
			"skin_name": s.get("skin_name", sid),
			"description": s.get("description", "Aspecto cromático del arsenal cuántico."),
			"rarity": s.get("rarity", "rare"),
			"is_base": false,
			"is_unlocked": is_unl,
			"unlocked_stars": stars if is_unl else 0,
			"stars": clampi(stars, 1, 3),
			"texture": tex,
			"glow_color": glow_col,
			"raw_data": s
		}
		_available_skins.append(entry)


func _get_base_texture() -> Texture2D:
	if not character_data_ref:
		return null
	match current_category:
		"pilot":
			return character_data_ref.get_selection_texture(false)
		"ship":
			return character_data_ref.get_ship_texture()
		"weapon":
			return character_data_ref.get_weapon_texture()
	return null


func _get_skin_texture(s_data: Dictionary) -> Texture2D:
	match current_category:
		"pilot":
			var sel_path: String = s_data.get("selection_texture_path", "")
			if not sel_path.is_empty() and ResourceLoader.exists(sel_path):
				return load(sel_path) as Texture2D
			var fb_path: String = s_data.get("texture_path", "")
			if not fb_path.is_empty() and ResourceLoader.exists(fb_path):
				return load(fb_path) as Texture2D
		"ship":
			var s_path: String = s_data.get("texture_path", "")
			if not s_path.is_empty() and ResourceLoader.exists(s_path):
				return load(s_path) as Texture2D
		"weapon":
			var w_path: String = s_data.get("texture_path", "")
			if not w_path.is_empty() and ResourceLoader.exists(w_path):
				return load(w_path) as Texture2D
	return _get_base_texture()


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
	if _available_skins.is_empty():
		return

	var cur: Dictionary = _available_skins[_skin_index]
	var total: int = _available_skins.size()
	var is_unlocked: bool = cur.get("is_unlocked", false)
	var unl_stars: int = cur.get("unlocked_stars", 1)
	var is_star_unlocked: bool = is_unlocked and (_star_level <= unl_stars)

	var slot_key: String = "%s:%s" % [current_category, String(current_target_id).to_lower()]
	var equipped_now: String = SaveManager.get_equipped_skin(slot_key)
	var is_equipped: bool = is_star_unlocked and (equipped_now == cur.get("id", ""))

	var theme_col: Color = cur.get("glow_color", Color(0.2, 0.85, 1.0))

	# 1. Dossier Header
	index_badge.text = "[ %02d / %02d ]" % [_skin_index + 1, total]

	if not is_unlocked:
		name_label.text = "[ BLOQUEADO ]"
		name_label.modulate = Color(0.6, 0.65, 0.75, 0.7)
		status_badge.text = "[ BLOQUEADO // GACHA ]"
		status_badge.modulate = Color(1.0, 0.35, 0.45)
	elif not is_star_unlocked:
		name_label.text = str(cur.get("skin_name", "")).to_upper()
		name_label.modulate = theme_col
		status_badge.text = "[ NIVEL %d★ BLOQUEADO ]" % _star_level
		status_badge.modulate = Color(1.0, 0.6, 0.3)
	elif is_equipped:
		name_label.text = str(cur.get("skin_name", "")).to_upper()
		name_label.modulate = theme_col
		status_badge.text = "[✓ EQUIPADA]"
		status_badge.modulate = Color(0.2, 1.0, 0.6)
	else:
		name_label.text = str(cur.get("skin_name", "")).to_upper()
		name_label.modulate = theme_col
		status_badge.text = "[ DISPONIBLE ]"
		status_badge.modulate = Color(0.4, 0.8, 1.0)

	# 2. Stars Badge
	match _star_level:
		1: stars_badge.text = "★☆☆  [NIVEL 1 - BASE]"
		2: stars_badge.text = "★★☆  [NIVEL 2 - HALO DE ENERGÍA]"
		3: stars_badge.text = "★★★  [NIVEL 3 - SOBRECARGA RADIANTE]"
	stars_badge.modulate = Color(1.0, 0.85, 0.25) if is_star_unlocked else Color(0.5, 0.55, 0.6)

	# 3. Lore / Info
	if not is_unlocked:
		desc_label.text = "Aspecto estelar clasificado. Desbloquéalo participando en la Gacha Cuántica del Hangar."
	else:
		desc_label.text = str(cur.get("description", ""))

	# 4. Artwork Texture & Shader
	var tex: Texture2D = cur.get("texture", null)
	artwork_texture.texture = tex

	if not is_unlocked or not is_star_unlocked:
		# Silueta negra perimetral
		artwork_texture.material = _silhouette_material
		locked_overlay.visible = true
		lock_title.text = "ASPECTO BLOQUEADO" if not is_unlocked else "NIVEL %d★ BLOQUEADO" % _star_level
		lock_desc.text = "Obtén duplicados o cápsulas cuánticas para desbloquear este nivel de resonancia."
		if circular_glow:
			circular_glow.modulate = Color(0.1, 0.15, 0.25, 0.3)
	else:
		locked_overlay.visible = false
		if current_category == "pilot":
			var mat := ShaderMaterial.new()
			mat.shader = HOLOGRAM_SHADER
			mat.set_shader_parameter("rim_color", theme_col)
			# Ajuste especial para Valentina: corte suave de rodillas
			var is_valentina: bool = (String(current_target_id).to_lower() == "valentina")
			mat.set_shader_parameter("bottom_fade_start", 0.78 if is_valentina else 0.88)
			artwork_texture.material = mat
		elif cur.get("is_base", false):
			artwork_texture.material = null
		else:
			CosmeticsManager.apply_skin_to_canvas_item(artwork_texture, cur.get("id", ""), _star_level, false)

		if circular_glow:
			circular_glow.modulate = Color(theme_col.r, theme_col.g, theme_col.b, 0.85)

	# 5. Tarjetas Adyacentes (Horizontales)
	var left_idx := (_skin_index - 1 + total) % total
	var right_idx := (_skin_index + 1) % total
	left_texture.texture = _available_skins[left_idx].get("texture", null)
	right_texture.texture = _available_skins[right_idx].get("texture", null)

	# 6. Tarjetas de Estrellas (Verticales)
	if top_card and bottom_card:
		top_texture.texture = tex
		bottom_texture.texture = tex
		top_card.modulate.a = 0.6 if _star_level > 1 else 0.2
		bottom_card.modulate.a = 0.6 if _star_level < 3 else 0.2


func _build_dots() -> void:
	for child in dots_container.get_children():
		child.queue_free()

	for i in range(_available_skins.size()):
		var dot := Panel.new()
		var is_active := (i == _skin_index)
		dot.custom_minimum_size = Vector2(20 if is_active else 8, 8)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		if is_active:
			var cur_col: Color = _available_skins[i].get("glow_color", Color(0, 0.95, 1.0))
			sb.bg_color = cur_col
			sb.shadow_color = cur_col
			sb.shadow_size = 4
		else:
			sb.bg_color = Color(0.25, 0.35, 0.45, 0.5)
		dot.add_theme_stylebox_override("panel", sb)
		dots_container.add_child(dot)


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


func get_available_skins_count() -> int:
	return _available_skins.size()


func get_current_skin_index() -> int:
	return _skin_index


func get_current_stars() -> int:
	return _star_level


func cycle_skins_for_test(dir: int) -> void:
	_cycle_skin(dir)


func cycle_stars_for_test(dir: int) -> void:
	_cycle_stars(dir)


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


func set_stars_for_test(stars: int) -> void:
	_star_level = clampi(stars, 1, 3)
	_refresh_display()


func equip_current_for_test() -> void:
	_confirm_equip()


func unequip_to_default_for_test() -> void:
	var slot_key: String = "%s:%s" % [current_category, String(current_target_id).to_lower()]
	SaveManager.unequip_skin(slot_key)
	var loadout: Dictionary = SaveManager.get_character_loadout(current_target_id)
	match current_category:
		"pilot":
			loadout["pilot_skin"] = ""
			loadout["equipped_pilot_skin"] = ""
		"ship":
			loadout["ship_skin"] = ""
			loadout["equipped_ship_skin"] = ""
		"weapon":
			loadout["weapon_skin"] = ""
			loadout["equipped_weapon_skin"] = ""
	SaveManager.set_character_loadout(current_target_id, loadout)
	_last_valid_equipped_skin = ""
	skin_selected.emit(slot_key, "")
	_refresh_display()

