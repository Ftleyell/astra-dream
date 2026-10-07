class_name HeroPickerModal
extends CanvasLayer

## HeroPickerModal.gd
## Modal de selección inmersiva de heroína al entrar a la pantalla de selección o al reactivar el dock.
## Exhibe a la heroína en el centro de la pantalla con shader holográfico y la barra inferior de personajes agrandada.

signal hero_confirmed(character_id: StringName)
signal hero_cancelled()

const SHOWCASE_SHADER: Shader = preload("res://shaders/pilot_showcase_hologram.gdshader")
const SCREEN_BLUR_SHADER: Shader = preload("res://shaders/screen_blur.gdshader")
const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var hero_preview_texture: TextureRect = $DimOverlay/CenterContainer/CenterVBox/PreviewHolder/HeroPreview
@onready var hero_backlight: TextureRect = $DimOverlay/CenterContainer/CenterVBox/PreviewHolder/HeroBacklight
@onready var hero_name_label: Label = $DimOverlay/CenterContainer/CenterVBox/HeroIdentity/HeroName
@onready var hero_title_label: Label = $DimOverlay/CenterContainer/CenterVBox/HeroIdentity/HeroTitle
@onready var hint_label: Label = $DimOverlay/CenterContainer/CenterVBox/HeroIdentity/HintLabel
@onready var cards_container: HBoxContainer = $DimOverlay/BottomDockAnchor/BottomDockBar/Margin/CardsContainer
@onready var bottom_dock_bar: PanelContainer = $DimOverlay/BottomDockAnchor/BottomDockBar

# Dossier de Sistemas de Combate (Izquierda)
@onready var weapon_block_icon: TextureRect = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/WeaponBlock/WeaponMargin/WeaponRow/WeaponBlockIcon
@onready var weapon_block_tag: Label = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/WeaponBlock/WeaponMargin/WeaponRow/WeaponBlockVBox/WeaponBlockTag
@onready var weapon_block_title: Label = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/WeaponBlock/WeaponMargin/WeaponRow/WeaponBlockVBox/WeaponBlockTitle
@onready var weapon_block_desc: Label = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/WeaponBlock/WeaponMargin/WeaponRow/WeaponBlockVBox/WeaponBlockDesc

@onready var tactical_block_icon: TextureRect = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/TacticalBlock/TacticalMargin/TacticalRow/TacticalBlockIcon
@onready var tactical_block_tag: Label = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/TacticalBlock/TacticalMargin/TacticalRow/TacticalBlockVBox/TacticalBlockTag
@onready var tactical_block_title: Label = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/TacticalBlock/TacticalMargin/TacticalRow/TacticalBlockVBox/TacticalBlockTitle
@onready var tactical_block_desc: Label = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/TacticalBlock/TacticalMargin/TacticalRow/TacticalBlockVBox/TacticalBlockDesc

@onready var dash_block_icon: TextureRect = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/DashBlock/DashMargin/DashRow/DashBlockIcon
@onready var dash_block_tag: Label = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/DashBlock/DashMargin/DashRow/DashBlockVBox/DashBlockTag
@onready var dash_block_title: Label = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/DashBlock/DashMargin/DashRow/DashBlockVBox/DashBlockTitle
@onready var dash_block_desc: Label = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/DashBlock/DashMargin/DashRow/DashBlockVBox/DashBlockDesc

@onready var passive_block_icon: TextureRect = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/PassiveBlock/PassiveMargin/PassiveRow/PassiveBlockIcon
@onready var passive_block_tag: Label = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/PassiveBlock/PassiveMargin/PassiveRow/PassiveBlockVBox/PassiveBlockTag
@onready var passive_block_title: Label = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/PassiveBlock/PassiveMargin/PassiveRow/PassiveBlockVBox/PassiveBlockTitle
@onready var passive_block_desc: Label = $DimOverlay/LeftDossierPanel/DossierMargin/DossierVBox/PassiveBlock/PassiveMargin/PassiveRow/PassiveBlockVBox/PassiveBlockDesc

var is_open: bool = false
var is_initial_entry: bool = true

var _roster: Array[CharacterData] = []
var _current_index: int = 0
var _card_buttons: Array[Button] = []
var _last_click_msec: int = 0
var _last_clicked_index: int = -1
var _preview_tween: Tween = null
var _is_confirming: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	hide()

	if dim_overlay:
		dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		var mat := ShaderMaterial.new()
		mat.shader = SCREEN_BLUR_SHADER
		mat.set_shader_parameter("blur_amount", 2.8)
		mat.set_shader_parameter("tint_color", Color(0.015, 0.025, 0.05, 0.84))
		dim_overlay.material = mat

	_setup_backlight()


func _setup_backlight() -> void:
	if not hero_backlight:
		return
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.8))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	grad_tex.width = 512
	grad_tex.height = 512
	hero_backlight.texture = grad_tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	hero_backlight.material = mat


func open_picker(p_roster: Array[CharacterData], p_current_id: StringName, p_initial: bool = false) -> void:
	_roster = p_roster
	is_initial_entry = p_initial
	is_open = true
	_is_confirming = false
	show()

	_current_index = 0
	for i in range(_roster.size()):
		if _roster[i].character_id == p_current_id:
			_current_index = i
			break

	_build_dock_cards()
	_update_selected_hero()

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_hover", 0.0, 0.95)


func close_picker() -> void:
	if not is_open:
		return
	is_open = false
	_is_confirming = false
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	hide()


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		_cancel_selection()
		return

	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
		get_viewport().set_input_as_handled()
		_confirm_selection()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A, KEY_LEFT:
				_cycle_hero(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_D, KEY_RIGHT:
				_cycle_hero(1)
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_cycle_hero(-1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_cycle_hero(1)
		get_viewport().set_input_as_handled()
		return


func _cycle_hero(dir: int) -> void:
	if _roster.is_empty():
		return
	var next_idx: int = (_current_index + dir + _roster.size()) % _roster.size()
	_select_index(next_idx)

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_hover", 0.0, 1.1)


func _select_index(idx: int) -> void:
	if idx < 0 or idx >= _roster.size():
		return
	_current_index = idx
	_update_selected_hero()
	_update_card_highlights()


func _confirm_selection() -> void:
	if not is_open or _is_confirming or _roster.is_empty():
		return
	_is_confirming = true
	var char_data: CharacterData = _roster[_current_index]
	var cid: StringName = char_data.character_id

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 1.15)

	close_picker()
	hero_confirmed.emit.call_deferred(cid)


func _cancel_selection() -> void:
	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click", 0.0, 0.9)

	close_picker()
	hero_cancelled.emit.call_deferred()


func _build_dock_cards() -> void:
	if not _card_buttons.is_empty():
		_update_card_highlights()
		return

	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()
	_card_buttons.clear()

	for i in range(_roster.size()):
		var c_data: CharacterData = _roster[i]
		var cid: StringName = c_data.character_id
		var is_unlocked: bool = SaveManager.is_character_unlocked(cid)
		if not is_unlocked and cid == &"nyx":
			continue

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(104, 104)
		btn.focus_mode = Control.FOCUS_NONE
		btn.icon = c_data.get_avatar_texture()
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.tooltip_text = c_data.display_name.to_upper()
		btn.pivot_offset = Vector2(52, 52)
		btn.set_meta(&"char_data", c_data)
		btn.set_meta(&"roster_index", i)

		var card_idx: int = i
		btn.pressed.connect(func() -> void:
			if not is_open or _is_confirming:
				return
			var now_msec: int = Time.get_ticks_msec()
			if _last_clicked_index == card_idx and (now_msec - _last_click_msec) < 380:
				_confirm_selection()
			else:
				_select_index(card_idx)
			_last_clicked_index = card_idx
			_last_click_msec = now_msec
		)

		btn.mouse_entered.connect(func() -> void:
			if is_instance_valid(btn) and card_idx != _current_index:
				if btn.has_meta(&"hover_tw"):
					var tw: Tween = btn.get_meta(&"hover_tw") as Tween
					if tw and tw.is_valid():
						tw.kill()
				var tw := btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.12)
				btn.set_meta(&"hover_tw", tw)
		)
		btn.mouse_exited.connect(func() -> void:
			if is_instance_valid(btn) and card_idx != _current_index:
				if btn.has_meta(&"hover_tw"):
					var tw: Tween = btn.get_meta(&"hover_tw") as Tween
					if tw and tw.is_valid():
						tw.kill()
				var tw := btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
				btn.set_meta(&"hover_tw", tw)
		)

		cards_container.add_child(btn)
		_card_buttons.append(btn)

	_update_card_highlights()


func _update_card_highlights() -> void:
	for i in range(_card_buttons.size()):
		var btn: Button = _card_buttons[i]
		if not is_instance_valid(btn):
			continue
		var c_data: CharacterData = (btn.get_meta(&"char_data") as CharacterData) if btn.has_meta(&"char_data") else null
		var roster_idx: int = (btn.get_meta(&"roster_index") as int) if btn.has_meta(&"roster_index") else i
		if not c_data and i < _roster.size():
			c_data = _roster[i]
		if not c_data:
			continue
		var is_selected: bool = (roster_idx == _current_index)
		var is_unlocked: bool = SaveManager.is_character_unlocked(c_data.character_id)

		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 6
		sb.content_margin_top = 6
		sb.content_margin_right = 6
		sb.content_margin_bottom = 6

		if btn.has_meta(&"hover_tw"):
			var hover_tw: Tween = btn.get_meta(&"hover_tw") as Tween
			if hover_tw and hover_tw.is_valid():
				hover_tw.kill()

		if is_selected:
			sb.border_width_left = 3
			sb.border_width_top = 3
			sb.border_width_right = 3
			sb.border_width_bottom = 3
			sb.border_color = c_data.color
			sb.bg_color = Color(0.04, 0.09, 0.14, 0.98)
			sb.shadow_color = c_data.color * Color(1, 1, 1, 0.5)
			sb.shadow_size = 8
			btn.scale = Vector2(1.10, 1.10)
		else:
			sb.border_width_left = 2
			sb.border_width_top = 2
			sb.border_width_right = 2
			sb.border_width_bottom = 2
			sb.border_color = (c_data.color * Color(1, 1, 1, 0.45) if is_unlocked else Color(0.25, 0.3, 0.35, 0.5))
			sb.bg_color = Color(0.025, 0.04, 0.07, 0.92)
			sb.shadow_size = 0
			btn.scale = Vector2.ONE

		btn.add_theme_stylebox_override("normal", sb)
		var hover_sb := sb.duplicate() as StyleBoxFlat
		if not is_selected and is_unlocked:
			hover_sb.border_color = c_data.color * Color(1, 1, 1, 0.85)
			hover_sb.bg_color = Color(0.035, 0.065, 0.1, 0.95)
		btn.add_theme_stylebox_override("hover", hover_sb)
		btn.add_theme_stylebox_override("pressed", sb)


func _update_selected_hero() -> void:
	if _roster.is_empty():
		return
	var c_data: CharacterData = _roster[_current_index]
	var cid: StringName = c_data.character_id
	var is_unlocked: bool = SaveManager.is_character_unlocked(cid)
	var theme_col: Color = c_data.color if c_data else Color(0.2, 0.9, 1.0)

	hero_name_label.text = c_data.display_name.to_upper()
	hero_name_label.modulate = theme_col
	hero_title_label.text = c_data.title if not c_data.title.is_empty() else "Piloto de la Flota Estelar"

	if hero_backlight:
		hero_backlight.modulate = Color(theme_col.r, theme_col.g, theme_col.b, 0.55 if is_unlocked else 0.15)

	# Artwork y shader holográfico centrado
	var tex: Texture2D = c_data.get_selection_texture(false) if c_data.has_method("get_selection_texture") else c_data.get_fullbody_texture(false)
	if not tex:
		tex = c_data.get_portrait_texture()
	hero_preview_texture.texture = tex

	var mat := ShaderMaterial.new()
	mat.shader = SHOWCASE_SHADER
	mat.set_shader_parameter("rim_color", theme_col)
	var is_valentina: bool = (cid == &"valentina")
	mat.set_shader_parameter("bottom_fade_start", 0.78 if is_valentina else 0.90)
	hero_preview_texture.material = mat
	hero_preview_texture.modulate = Color.WHITE if is_unlocked else Color(0.25, 0.25, 0.35, 0.85)

	# Animación de entrada suave
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	if hero_preview_texture.size != Vector2.ZERO:
		hero_preview_texture.pivot_offset = hero_preview_texture.size * 0.5
	hero_preview_texture.scale = Vector2(0.96, 0.96)
	hero_preview_texture.modulate.a = 0.5
	_preview_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_preview_tween.tween_property(hero_preview_texture, "scale", Vector2.ONE, 0.16)
	_preview_tween.tween_property(hero_preview_texture, "modulate:a", 1.0, 0.16)

	_update_combat_dossier(c_data)


func _update_combat_dossier(c_data: CharacterData) -> void:
	if not c_data:
		return
	var kit: Dictionary = c_data.get_kit_dossier() if c_data.has_method("get_kit_dossier") else {}
	if not kit.is_empty():
		if weapon_block_title:
			weapon_block_title.text = kit.weapon_name
		if weapon_block_desc:
			weapon_block_desc.text = kit.weapon_desc
		if tactical_block_title:
			tactical_block_title.text = kit.tactical_name
		if tactical_block_desc:
			tactical_block_desc.text = kit.tactical_desc
		if dash_block_title:
			dash_block_title.text = kit.dash_name
		if dash_block_desc:
			dash_block_desc.text = kit.dash_desc
		if passive_block_title:
			passive_block_title.text = kit.passive_name
		if passive_block_desc:
			passive_block_desc.text = kit.passive_desc

	if weapon_block_icon:
		weapon_block_icon.texture = c_data.get_weapon_skill_texture()
	if tactical_block_icon:
		tactical_block_icon.texture = c_data.get_tactical_texture()
	if dash_block_icon:
		dash_block_icon.texture = c_data.get_dash_texture()
	if passive_block_icon:
		passive_block_icon.texture = c_data.get_passive_texture()
