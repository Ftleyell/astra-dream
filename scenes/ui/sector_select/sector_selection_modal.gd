class_name SectorSelectionModal
extends CanvasLayer

## sector_selection_modal.gd
## Starchart Modal interactivo para selección de sectores estelares, modificadores y rivales.
## Estética Psycho-Pop de alto contraste: Hot Pink, Cyan, Deep Black y transiciones elásticas.

signal sector_selected(sector_id: StringName)
signal closed()
const SectorDossierPresenter = preload("res://scenes/ui/sector_select/sector_dossier_presenter.gd")

const COLOR_DEEP_BLACK := Color("#0A0A0E")
const COLOR_HOT_PINK := Color("#FF1493")
const COLOR_CYAN := Color("#00F0FF")
const COLOR_PURE_WHITE := Color("#FFFFFF")
const COLOR_EMERALD := Color("#00FF9D")
const COLOR_DARK_MATTER := Color("#BF00FF")
const COLOR_AMBER := Color("#FFB700")

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var main_panel: PanelContainer = $DimOverlay/CenterContainer/MainPanel
@onready var index_badge: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ModalHeader/IndexBadge
@onready var close_header_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/ModalHeader/CloseHeaderBtn

# Carousel Controls
@onready var prev_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CarouselSection/CarouselRow/PrevButton
@onready var next_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CarouselSection/CarouselRow/NextButton
@onready var left_card: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CarouselSection/CarouselRow/LeftSectorCard
@onready var left_thumbnail: TextureRect = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CarouselSection/CarouselRow/LeftSectorCard/VBox/LeftThumbnail
@onready var left_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CarouselSection/CarouselRow/LeftSectorCard/VBox/LeftLabel

@onready var center_frame: PanelContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CarouselSection/CarouselRow/CenterSectorFrame
@onready var center_nebula_texture: TextureRect = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CarouselSection/CarouselRow/CenterSectorFrame/ViewportContainer/NebulaTexture
@onready var center_threat_badge: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CarouselSection/CarouselRow/CenterSectorFrame/ViewportContainer/ThreatBadge
@onready var locked_overlay: Control = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CarouselSection/CarouselRow/CenterSectorFrame/LockedOverlay
@onready var lock_desc: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CarouselSection/CarouselRow/CenterSectorFrame/LockedOverlay/LockCenter/LockDesc

@onready var right_card: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CarouselSection/CarouselRow/RightSectorCard
@onready var right_thumbnail: TextureRect = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CarouselSection/CarouselRow/RightSectorCard/VBox/RightThumbnail
@onready var right_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CarouselSection/CarouselRow/RightSectorCard/VBox/RightLabel
@onready var dots_container: HBoxContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/CarouselSection/DotsContainer

# Dossier
@onready var sector_name_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/LeftCol/DossierHeader/NameRow/SectorNameLabel
@onready var status_badge: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/LeftCol/DossierHeader/NameRow/StatusBadge
@onready var title_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/LeftCol/DossierHeader/TitleLabel
@onready var desc_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/LeftCol/DescCard/Margin/DescLabel

# Modifiers
@onready var modifiers_card: PanelContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/CenterCol/ModifiersCard
@onready var density_val: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/CenterCol/ModifiersCard/Margin/VBox/ModifiersGrid/DensityRow/Val
@onready var biomass_val: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/CenterCol/ModifiersCard/Margin/VBox/ModifiersGrid/BiomassRow/Val
@onready var dark_matter_val: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/CenterCol/ModifiersCard/Margin/VBox/ModifiersGrid/DarkMatterRow/Val
@onready var credits_val: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/CenterCol/ModifiersCard/Margin/VBox/ModifiersGrid/CreditsRow/Val
@onready var arcana_val: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/CenterCol/ModifiersCard/Margin/VBox/ModifiersGrid/ArcanaRow/Val
@onready var hazard_val: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/CenterCol/ModifiersCard/Margin/VBox/ModifiersGrid/HazardRow/Val
@onready var hazard_warning: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/CenterCol/ModifiersCard/Margin/VBox/HazardWarningLabel

# Rival & Rewards
@onready var rival_card: PanelContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/RightCol/RivalCard
@onready var rival_portrait: TextureRect = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/RightCol/RivalCard/Margin/HBox/RivalPortrait
@onready var rival_name: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/RightCol/RivalCard/Margin/HBox/RivalVBox/RivalName
@onready var rival_wave_alert: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/RightCol/RivalCard/Margin/HBox/RivalVBox/WaveAlertLabel

@onready var rewards_card: PanelContainer = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/RightCol/RewardsCard
@onready var currencies_label: Label = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/RightCol/RewardsCard/Margin/HBox/CurrenciesVBox/CurrenciesLabel

@onready var select_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/RightCol/ActionsVBox/SelectButton
@onready var close_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/RootVBox/DossierSection/RightCol/ActionsVBox/CloseButton

var is_open: bool = false
var current_index: int = 0
var _sectors: Array[SectorData] = []
var _dot_buttons: Array[Button] = []
var _active_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 127
	hide()

	if prev_btn:
		prev_btn.pressed.connect(func(): _cycle(-1))
		UIFocusHelper.apply_cyber_focus(prev_btn)
	if next_btn:
		next_btn.pressed.connect(func(): _cycle(1))
		UIFocusHelper.apply_cyber_focus(next_btn)

	if left_card:
		left_card.pressed.connect(func(): _cycle(-1))
		UIFocusHelper.apply_cyber_focus(left_card)
	if right_card:
		right_card.pressed.connect(func(): _cycle(1))
		UIFocusHelper.apply_cyber_focus(right_card)

	if select_btn:
		select_btn.pressed.connect(_on_select_pressed)
		UIFocusHelper.apply_cyber_focus(select_btn)
	if close_btn:
		close_btn.pressed.connect(close_modal)
		UIFocusHelper.apply_cyber_focus(close_btn)
	if close_header_btn:
		close_header_btn.pressed.connect(close_modal)
		UIFocusHelper.apply_cyber_focus(close_header_btn)

	_setup_focus_neighbors()

func open_modal() -> void:
	is_open = true
	show()
	_populate_sectors()
	_animate_open()
	if select_btn and not select_btn.disabled:
		select_btn.grab_focus()
	elif next_btn:
		next_btn.grab_focus()
	elif close_btn:
		close_btn.grab_focus()

func close_modal() -> void:
	if not is_open:
		return
	is_open = false
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(main_panel, "scale", Vector2(0.92, 0.92), 0.12)
	tw.tween_property(dim_overlay, "modulate:a", 0.0, 0.12)
	await tw.finished
	hide()
	closed.emit()

func get_selected_sector_id() -> StringName:
	if _sectors.is_empty() or current_index < 0 or current_index >= _sectors.size():
		return SaveManager.get_selected_sector() if SaveManager.has_method("get_selected_sector") else &"sector_nebula_outskirts"
	return _sectors[current_index].sector_id

func _animate_open() -> void:
	main_panel.pivot_offset = main_panel.size * 0.5
	main_panel.scale = Vector2(0.92, 0.92)
	dim_overlay.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(main_panel, "scale", Vector2.ONE, 0.22)
	tw.tween_property(dim_overlay, "modulate:a", 1.0, 0.18)

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_modal()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_A, KEY_LEFT, KEY_W, KEY_UP]:
			get_viewport().set_input_as_handled()
			_cycle(-1)
			return
		elif event.keycode in [KEY_D, KEY_RIGHT, KEY_S, KEY_DOWN]:
			get_viewport().set_input_as_handled()
			_cycle(1)
			return
		elif event.keycode in [KEY_SPACE, KEY_ENTER]:
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

func _populate_sectors() -> void:
	const SectorDataScript := preload("res://data/sectors/sector_data.gd")
	_sectors = SectorDataScript.load_all_sectors()

	var selected_sid: StringName = SaveManager.get_selected_sector() if SaveManager.has_method("get_selected_sector") else &"sector_nebula_outskirts"
	var initial_index: int = 0
	for i in range(_sectors.size()):
		if _sectors[i].sector_id == selected_sid:
			initial_index = i
			break
	current_index = initial_index

	_build_dots()
	_display_current_sector(false, 0)

func _build_dots() -> void:
	if not dots_container:
		return
	for child in dots_container.get_children():
		dots_container.remove_child(child)
		child.queue_free()
	_dot_buttons.clear()

	for i in range(_sectors.size()):
		var dot_btn := Button.new()
		dot_btn.custom_minimum_size = Vector2(26, 26)
		dot_btn.flat = true
		dot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		dot_btn.text = "●" if i == current_index else "○"
		dot_btn.add_theme_font_size_override("font_size", 18)
		dot_btn.focus_mode = Control.FOCUS_NONE

		var target_idx := i
		dot_btn.pressed.connect(func():
			if current_index != target_idx:
				var dir: int = 1 if target_idx > current_index else -1
				_set_index(target_idx, dir)
		)
		dots_container.add_child(dot_btn)
		_dot_buttons.append(dot_btn)

func _cycle(direction: int) -> void:
	if _sectors.is_empty():
		return
	var count := _sectors.size()
	var next_idx := (current_index + direction) % count
	if next_idx < 0:
		next_idx += count
	_set_index(next_idx, direction)

func _set_index(new_idx: int, slide_direction: int = 0) -> void:
	if new_idx == current_index:
		return
	current_index = new_idx
	_display_current_sector(true, slide_direction)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_hover", 0.0, 1.1)

func _display_current_sector(animate: bool = true, slide_direction: int = 0) -> void:
	if _sectors.is_empty() or current_index < 0 or current_index >= _sectors.size():
		return

	var count := _sectors.size()
	var sector: SectorData = _sectors[current_index]
	var sid: StringName = sector.sector_id
	var is_unlocked: bool = SaveManager.is_sector_unlocked(sid) if SaveManager.has_method("is_sector_unlocked") else true
	var cur_sel_sid: StringName = SaveManager.get_selected_sector() if SaveManager.has_method("get_selected_sector") else &""
	var is_selected: bool = (sid == cur_sel_sid)
	var theme_col: Color = sector.theme_color

	# 1. Header Index
	if index_badge:
		index_badge.text = "[ SECTOR %02d / %02d ]" % [current_index + 1, count]

	# 2. Cover Flow Cards
	var left_idx := (current_index - 1 + count) % count
	var right_idx := (current_index + 1) % count
	var left_data: SectorData = _sectors[left_idx]
	var right_data: SectorData = _sectors[right_idx]

	if left_thumbnail and left_data:
		left_thumbnail.texture = left_data.nebula_texture if left_data.nebula_texture else preload("res://assets/environments/deep_fold_space/layer0_space_nebula.png")
		left_thumbnail.modulate = left_data.nebula_tint
	if left_label and left_data:
		left_label.text = "◀ %s" % left_data.display_name.to_upper()
		left_label.modulate = left_data.theme_color

	if right_thumbnail and right_data:
		right_thumbnail.texture = right_data.nebula_texture if right_data.nebula_texture else preload("res://assets/environments/deep_fold_space/layer0_space_nebula.png")
		right_thumbnail.modulate = right_data.nebula_tint
	if right_label and right_data:
		right_label.text = "%s ▶" % right_data.display_name.to_upper()
		right_label.modulate = right_data.theme_color

	# 3. Center Hero Frame
	if center_nebula_texture:
		center_nebula_texture.texture = sector.nebula_texture if sector.nebula_texture else preload("res://assets/environments/deep_fold_space/layer0_space_nebula.png")
		center_nebula_texture.modulate = sector.nebula_tint

	if center_threat_badge:
		center_threat_badge.text = "[ AMENAZA: %s ]" % ("ALTA" if sector.enemy_density_mult > 1.2 else "NORMAL")
		center_threat_badge.add_theme_color_override("font_color", theme_col)

	if locked_overlay:
		locked_overlay.visible = not is_unlocked

	if center_frame:
		var sb := center_frame.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var sb_dup := sb.duplicate() as StyleBoxFlat
			sb_dup.border_color = theme_col if is_unlocked else Color(0.3, 0.35, 0.45, 0.7)
			sb_dup.shadow_color = Color(theme_col.r, theme_col.g, theme_col.b, 0.35)
			center_frame.add_theme_stylebox_override("panel", sb_dup)

	# 4. Dossier Identity
	SectorDossierPresenter.update_dossier_identity(
		sector, is_unlocked, is_selected,
		sector_name_label, title_label, status_badge, desc_label, animate
	)

	# 5. Modifiers Grid
	SectorDossierPresenter.update_modifiers_grid(
		sector,
		density_val, biomass_val, dark_matter_val,
		credits_val, arcana_val, hazard_val, hazard_warning
	)

	# 6. Rival Pilot Intelligence & 7. Stellar Rewards
	SectorDossierPresenter.update_rival_and_rewards(
		sector, rival_name, rival_wave_alert, rival_portrait, currencies_label
	)

	# 8. Action Buttons
	if select_btn:
		if is_selected:
			select_btn.text = "✓ RUTA ACTIVA (SELECCIONADA)"
			select_btn.disabled = false
			select_btn.add_theme_color_override("font_color", COLOR_EMERALD)
		elif is_unlocked:
			select_btn.text = "⚡ ESTABLECER RUTA DE VUELO [ESPACIO]"
			select_btn.disabled = false
			select_btn.add_theme_color_override("font_color", COLOR_CYAN)
		else:
			select_btn.text = "🔒 SECTOR BLOQUEADO"
			select_btn.disabled = true
			select_btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))

	_update_dots(theme_col)

	# 9. Center Slide Animation
	if animate and is_instance_valid(center_nebula_texture):
		if _active_tween and _active_tween.is_valid():
			_active_tween.kill()
		_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var offset_x: float = 40.0 * (1.0 if slide_direction >= 0 else -1.0)
		center_nebula_texture.position.x = offset_x
		center_nebula_texture.modulate.a = 0.3
		_active_tween.tween_property(center_nebula_texture, "position:x", 0.0, 0.22)
		_active_tween.tween_property(center_nebula_texture, "modulate:a", 1.0, 0.22)

func _update_dots(active_color: Color) -> void:
	for i in range(_dot_buttons.size()):
		var dot_btn := _dot_buttons[i]
		if i == current_index:
			dot_btn.text = "●"
			dot_btn.add_theme_color_override("font_color", active_color)
			dot_btn.modulate = Color(1.3, 1.3, 1.3, 1.0)
		else:
			dot_btn.text = "○"
			dot_btn.add_theme_color_override("font_color", Color(0.4, 0.5, 0.65, 0.7))
			dot_btn.modulate = Color(1.0, 1.0, 1.0, 0.7)

func _on_select_pressed() -> void:
	if _sectors.is_empty() or current_index < 0 or current_index >= _sectors.size():
		return
	var sector: SectorData = _sectors[current_index]
	var sid: StringName = sector.sector_id
	if SaveManager.has_method("is_sector_unlocked") and not SaveManager.is_sector_unlocked(sid):
		return

	if SaveManager.has_method("set_selected_sector"):
		SaveManager.set_selected_sector(sid)
	sector_selected.emit(sid)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.25)

	close_modal()

func _setup_focus_neighbors() -> void:
	if prev_btn and next_btn and select_btn and close_btn:
		prev_btn.focus_neighbor_right = next_btn.get_path()
		prev_btn.focus_neighbor_bottom = select_btn.get_path()
		next_btn.focus_neighbor_left = prev_btn.get_path()
		next_btn.focus_neighbor_bottom = select_btn.get_path()
		select_btn.focus_neighbor_top = next_btn.get_path()
		select_btn.focus_neighbor_bottom = close_btn.get_path()
		close_btn.focus_neighbor_top = select_btn.get_path()
