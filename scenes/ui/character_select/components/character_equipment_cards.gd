class_name CharacterEquipmentCards
extends RefCounted

## CharacterEquipmentCards.gd
## Controlador modular de las tarjetas de equipamiento (Nave, Arma, Mascota, Navegadora)
## para CharacterSelectUI. Gestiona el feedback visual de hover, iconos, descripciones y skins cosméticas.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const PetDataScript = preload("res://data/pets/pet_data.gd")
const NavigatorDataScript = preload("res://data/navigators/navigator_data.gd")
const ShaderSkinLivePreviewScript = preload("res://scenes/ui/cosmetics/components/shader_skin_live_preview.gd")

var ship_card: PanelContainer = null
var ship_icon: TextureRect = null
var ship_title: Label = null
var ship_name: Label = null
var ship_button: Button = null

var weapon_card: PanelContainer = null
var weapon_icon: TextureRect = null
var weapon_title: Label = null
var weapon_name: Label = null
var weapon_button: Button = null

var wings_live_preview: ShaderSkinLivePreview = null
var weapon_live_preview: ShaderSkinLivePreview = null

var pet_card: PanelContainer = null
var pet_icon: TextureRect = null
var pet_name: Label = null
var pet_desc: Label = null
var pet_button: Button = null

var navigator_card: PanelContainer = null
var navigator_icon: TextureRect = null
var navigator_name: Label = null
var navigator_desc: Label = null
var navigator_button: Button = null


func setup_from_root(
	root: Control,
	p_on_ship_pressed: Callable,
	p_on_weapon_pressed: Callable,
	p_on_pet_pressed: Callable,
	p_on_nav_pressed: Callable
) -> void:
	var base_path: String = "MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/"
	ship_title = root.get_node_or_null(base_path + "ChassisWeaponRow/ShipCard/ShipMargin/ShipBox/ShipLabelVBox/ShipTitle") as Label
	weapon_title = root.get_node_or_null(base_path + "ChassisWeaponRow/WeaponCard/WeaponMargin/WeaponBox/WeaponLabelVBox/WeaponTitle") as Label
	setup_ship_and_weapon(
		root.get_node_or_null(base_path + "ChassisWeaponRow/ShipCard") as PanelContainer,
		root.get_node_or_null(base_path + "ChassisWeaponRow/ShipCard/ShipMargin/ShipBox/ShipIcon") as TextureRect,
		root.get_node_or_null(base_path + "ChassisWeaponRow/ShipCard/ShipMargin/ShipBox/ShipLabelVBox/ShipName") as Label,
		root.get_node_or_null(base_path + "ChassisWeaponRow/ShipCard/ShipButton") as Button,
		p_on_ship_pressed,
		root.get_node_or_null(base_path + "ChassisWeaponRow/WeaponCard") as PanelContainer,
		root.get_node_or_null(base_path + "ChassisWeaponRow/WeaponCard/WeaponMargin/WeaponBox/WeaponIcon") as TextureRect,
		root.get_node_or_null(base_path + "ChassisWeaponRow/WeaponCard/WeaponMargin/WeaponBox/WeaponLabelVBox/WeaponName") as Label,
		root.get_node_or_null(base_path + "ChassisWeaponRow/WeaponCard/WeaponButton") as Button,
		p_on_weapon_pressed
	)
	setup_companions(
		root.get_node_or_null(base_path + "PetCard") as PanelContainer,
		root.get_node_or_null(base_path + "PetCard/PetMargin/PetBox/PetIcon") as TextureRect,
		root.get_node_or_null(base_path + "PetCard/PetMargin/PetBox/PetLabelVBox/PetName") as Label,
		root.get_node_or_null(base_path + "PetCard/PetMargin/PetBox/PetLabelVBox/PetDesc") as Label,
		root.get_node_or_null(base_path + "PetCard/PetButton") as Button,
		p_on_pet_pressed,
		root.get_node_or_null(base_path + "NavigatorCard") as PanelContainer,
		root.get_node_or_null(base_path + "NavigatorCard/NavigatorMargin/NavigatorBox/NavigatorIcon") as TextureRect,
		root.get_node_or_null(base_path + "NavigatorCard/NavigatorMargin/NavigatorBox/NavigatorLabelVBox/NavigatorName") as Label,
		root.get_node_or_null(base_path + "NavigatorCard/NavigatorMargin/NavigatorBox/NavigatorLabelVBox/NavigatorDesc") as Label,
		root.get_node_or_null(base_path + "NavigatorCard/NavigatorButton") as Button,
		p_on_nav_pressed
	)


func setup_ship_and_weapon(
	p_ship_card: PanelContainer,
	p_ship_icon: TextureRect,
	p_ship_name: Label,
	p_ship_button: Button,
	p_on_ship_pressed: Callable,
	p_weapon_card: PanelContainer,
	p_weapon_icon: TextureRect,
	p_weapon_name: Label,
	p_weapon_button: Button,
	p_on_weapon_pressed: Callable
) -> void:
	ship_card = p_ship_card
	ship_icon = p_ship_icon
	ship_name = p_ship_name
	ship_button = p_ship_button

	weapon_card = p_weapon_card
	weapon_icon = p_weapon_icon
	weapon_name = p_weapon_name
	weapon_button = p_weapon_button

	if ship_button:
		var empty_focus := StyleBoxEmpty.new()
		ship_button.add_theme_stylebox_override("focus", empty_focus)
		ship_button.pressed.connect(p_on_ship_pressed)
		setup_card_hover_feedback(ship_button, ship_card, Color(0.2, 0.95, 1.0, 1.0))

	if weapon_button:
		var empty_focus := StyleBoxEmpty.new()
		weapon_button.add_theme_stylebox_override("focus", empty_focus)
		weapon_button.pressed.connect(p_on_weapon_pressed)
		setup_card_hover_feedback(weapon_button, weapon_card, Color(1.0, 0.85, 0.35, 1.0))

	# Centrado en medio del contenedor: se ajusta dinámicamente según la textura asignada
	_apply_weapon_optical_centering()


func _apply_weapon_optical_centering() -> void:
	if not weapon_icon or not weapon_icon.texture:
		return

	var raw_tex: Texture2D = weapon_icon.texture
	while raw_tex is AtlasTexture:
		raw_tex = (raw_tex as AtlasTexture).atlas
	if not raw_tex:
		return

	var tw: int = raw_tex.get_width()
	var th: int = raw_tex.get_height()
	if tw <= 0 or th <= 0:
		return

	# Obtener la imagen subyacente para calcular el bounding box de píxeles no transparentes
	var img: Image = raw_tex.get_image()
	if not img:
		return

	var used_rect: Rect2i = img.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		weapon_icon.texture = raw_tex
		return

	# Centrado simétrico estricto: encuadrar el dibujo activo en una región cuadrada perfectamente centrada
	var center_x: float = float(used_rect.position.x) + float(used_rect.size.x) * 0.5
	var center_y: float = float(used_rect.position.y) + float(used_rect.size.y) * 0.5
	var max_dim: float = maxf(float(used_rect.size.x), float(used_rect.size.y))
	var half_span: float = (max_dim * 0.5) * 1.12 # 12% margen de respiración

	var max_safe_x: float = minf(center_x, float(tw) - center_x)
	var max_safe_y: float = minf(center_y, float(th) - center_y)
	var max_safe_span: float = minf(max_safe_x, max_safe_y)
	var final_span: float = minf(half_span, max_safe_span)
	if final_span < (max_dim * 0.5):
		final_span = max_safe_span

	var crop_x: int = int(round(center_x - final_span))
	var crop_y: int = int(round(center_y - final_span))
	var crop_w: int = int(round(final_span * 2.0))

	var final_region := Rect2(crop_x, crop_y, crop_w, crop_w)
	var atlas := AtlasTexture.new()
	atlas.atlas = raw_tex
	atlas.region = final_region

	weapon_icon.texture = atlas


func setup_companions(
	p_pet_card: PanelContainer,
	p_pet_icon: TextureRect,
	p_pet_name: Label,
	p_pet_desc: Label,
	p_pet_button: Button,
	p_on_pet_pressed: Callable,
	p_nav_card: PanelContainer,
	p_nav_icon: TextureRect,
	p_nav_name: Label,
	p_nav_desc: Label,
	p_nav_button: Button,
	p_on_nav_pressed: Callable
) -> void:
	pet_card = p_pet_card
	pet_icon = p_pet_icon
	pet_name = p_pet_name
	pet_desc = p_pet_desc
	pet_button = p_pet_button

	navigator_card = p_nav_card
	navigator_icon = p_nav_icon
	navigator_name = p_nav_name
	navigator_desc = p_nav_desc
	navigator_button = p_nav_button

	if pet_button:
		var empty_focus := StyleBoxEmpty.new()
		pet_button.add_theme_stylebox_override("focus", empty_focus)
		pet_button.pressed.connect(p_on_pet_pressed)
		setup_card_hover_feedback(pet_button, pet_card, Color(0.2, 0.95, 0.65, 1.0))

	if navigator_button:
		var empty_focus := StyleBoxEmpty.new()
		navigator_button.add_theme_stylebox_override("focus", empty_focus)
		navigator_button.pressed.connect(p_on_nav_pressed)
		setup_card_hover_feedback(navigator_button, navigator_card, Color(0.3, 0.7, 1.0, 1.0))

	refresh_pet_display()
	refresh_navigator_display()


func setup_card_hover_feedback(btn: Button, card: PanelContainer, glow_color: Color) -> void:
	if not btn or not card:
		return
	var on_highlight := func():
		var sb := card.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var dup := sb.duplicate() as StyleBoxFlat
			dup.border_color = glow_color
			dup.shadow_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.35)
			dup.shadow_size = 8
			card.add_theme_stylebox_override("panel", dup)
	var on_unhighlight := func():
		var sb := card.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var dup := sb.duplicate() as StyleBoxFlat
			dup.border_color = Color(0.18, 0.3, 0.45, 0.6)
			dup.shadow_color = Color(0, 0, 0, 0)
			dup.shadow_size = 0
			card.add_theme_stylebox_override("panel", dup)
	btn.mouse_entered.connect(on_highlight)
	btn.focus_entered.connect(on_highlight)
	btn.mouse_exited.connect(on_unhighlight)
	btn.focus_exited.connect(on_unhighlight)


func _ensure_card_preview(icon_host: TextureRect, existing: ShaderSkinLivePreview, node_name: String) -> ShaderSkinLivePreview:
	if existing != null and is_instance_valid(existing):
		return existing
	if icon_host == null:
		return null
	var preview: ShaderSkinLivePreview = ShaderSkinLivePreviewScript.new() as ShaderSkinLivePreview
	preview.name = node_name
	preview.custom_minimum_size = Vector2(160, 160)
	preview.size = Vector2(160, 160)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1.0, 1.0, 1.0, 0.0)
	icon_host.add_child(preview)
	return preview


func _resolve_skin_badge_suffix(skin_id: String) -> String:
	if skin_id.is_empty() or skin_id == CosmeticsManager.FOLLOW_PILOT_SKIN_ID:
		return "Seguir Piloto"
	if skin_id == "base" or skin_id == "default":
		return "Base"
	var info: Dictionary = CosmeticsManager.get_skin(skin_id)
	var s_name: String = str(info.get("skin_name", ""))
	return s_name if not s_name.is_empty() else skin_id


func update_equipment(data: CharacterData, char_id: StringName) -> void:
	if not data:
		return

	if data.has_shader_skins():
		var catalog: PilotShaderSkinCatalog = data.shader_skin_catalog
		var prof: PilotRigProfile = data.pilot_rig_profile
		if prof == null and ResourceLoader.exists("res://data/pilots/valentina_v2/valentina_v2_profile.tres"):
			prof = ResourceLoader.load("res://data/pilots/valentina_v2/valentina_v2_profile.tres") as PilotRigProfile

		if ship_title:
			ship_title.text = catalog.wings_slot_title
		if weapon_title:
			weapon_title.text = catalog.weapon_slot_title

		var wings_skin_id: String = CosmeticsManager.resolve_equipped_skin_id("wings", char_id)
		var wings_preset: PilotSkinPreset = CosmeticsManager.resolve_pilot_skin_preset(char_id, "wings")
		var wings_stars: int = CosmeticsManager.resolve_equipped_skin_stars("wings", char_id)
		if ship_icon:
			wings_live_preview = _ensure_card_preview(ship_icon, wings_live_preview, "WingsCardLivePreview")
			if wings_live_preview != null:
				wings_live_preview.configure("wings", prof, Vector2i(160, 160))
				wings_live_preview.apply_skin_preset(wings_preset, wings_stars, false)
				wings_live_preview.visible = true
				wings_live_preview.set_preview_paused(false)
				var w_vp: SubViewport = wings_live_preview.get_preview_viewport()
				ship_icon.texture = w_vp.get_texture() if w_vp != null else null
			if not wings_skin_id.is_empty() and wings_skin_id != "base" and wings_skin_id != CosmeticsManager.FOLLOW_PILOT_SKIN_ID:
				CosmeticsManager.apply_skin_to_canvas_item(ship_icon, wings_skin_id, wings_stars, false)
			else:
				ship_icon.material = null
		if ship_name:
			ship_name.text = "%s · %s" % [catalog.wings_slot_display_name, _resolve_skin_badge_suffix(wings_skin_id)]

		var weapon_skin_id: String = CosmeticsManager.resolve_equipped_skin_id("weapon", char_id)
		var weapon_preset: PilotSkinPreset = CosmeticsManager.resolve_pilot_skin_preset(char_id, "weapon")
		var weapon_stars: int = CosmeticsManager.resolve_equipped_skin_stars("weapon", char_id)
		if weapon_icon:
			weapon_live_preview = _ensure_card_preview(weapon_icon, weapon_live_preview, "WeaponCardLivePreview")
			if weapon_live_preview != null:
				weapon_live_preview.configure("weapon", prof, Vector2i(160, 160))
				weapon_live_preview.apply_skin_preset(weapon_preset, weapon_stars, false)
				weapon_live_preview.visible = true
				weapon_live_preview.set_preview_paused(false)
				var g_vp: SubViewport = weapon_live_preview.get_preview_viewport()
				weapon_icon.texture = g_vp.get_texture() if g_vp != null else null
			if not weapon_skin_id.is_empty() and weapon_skin_id != "base" and weapon_skin_id != CosmeticsManager.FOLLOW_PILOT_SKIN_ID:
				CosmeticsManager.apply_skin_to_canvas_item(weapon_icon, weapon_skin_id, weapon_stars, false)
			else:
				weapon_icon.material = null
		if weapon_name:
			var base_w_name: String = data.starting_weapon.weapon_name if (data.starting_weapon != null and not data.starting_weapon.weapon_name.is_empty()) else catalog.weapon_slot_display_name
			weapon_name.text = "%s · %s" % [base_w_name, _resolve_skin_badge_suffix(weapon_skin_id)]

		refresh_pet_display(char_id)
		refresh_navigator_display(char_id)
		return

	if ship_title:
		ship_title.text = "NAVE"
	if weapon_title:
		weapon_title.text = "ARMA INICIAL"
	if wings_live_preview != null and is_instance_valid(wings_live_preview):
		wings_live_preview.set_preview_paused(true)
		wings_live_preview.visible = false
	if weapon_live_preview != null and is_instance_valid(weapon_live_preview):
		weapon_live_preview.set_preview_paused(true)
		weapon_live_preview.visible = false

	var loadout: Dictionary = SaveManager.get_character_loadout(char_id)

	# Nave Asignada
	var ship_skin_id: String = str(loadout.get("equipped_ship_skin", "base"))
	if ship_skin_id.is_empty():
		ship_skin_id = "base"
	if ship_icon:
		ship_icon.material = null
		ship_icon.texture = null
		if ship_skin_id != "base":
			var stars := SaveManager.get_skin_stars(ship_skin_id)
			CosmeticsManager.apply_skin_to_canvas_item(ship_icon, ship_skin_id, stars)
		if ship_icon.texture == null:
			ship_icon.texture = data.get_ship_texture()
	if ship_name:
		ship_name.text = "%s Mark I" % data.display_name

	# Arma Inicial Asignada
	var weapon_skin_id: String = str(loadout.get("equipped_weapon_skin", "base"))
	if weapon_skin_id.is_empty():
		weapon_skin_id = "base"
	if weapon_icon:
		weapon_icon.material = null
		weapon_icon.texture = null
		if weapon_skin_id != "base":
			var stars := SaveManager.get_skin_stars(weapon_skin_id)
			CosmeticsManager.apply_skin_to_canvas_item(weapon_icon, weapon_skin_id, stars)
		if weapon_icon.texture == null:
			weapon_icon.texture = data.get_weapon_texture()
		_apply_weapon_optical_centering()
	if weapon_name:
		if data.starting_weapon and not data.starting_weapon.weapon_name.is_empty():
			weapon_name.text = data.starting_weapon.weapon_name
		else:
			weapon_name.text = "Arma Especializada"

	refresh_pet_display(char_id)
	refresh_navigator_display(char_id)


func refresh_pet_display(char_id: StringName = &"") -> void:
	var sel_pid: StringName = &"mochi"
	var pet_skin_id: String = ""
	if not char_id.is_empty():
		var loadout: Dictionary = SaveManager.get_character_loadout(char_id)
		if loadout.has("selected_pet") and not str(loadout["selected_pet"]).is_empty():
			sel_pid = StringName(str(loadout["selected_pet"]))
		if loadout.has("equipped_pet_skin"):
			pet_skin_id = str(loadout["equipped_pet_skin"])
	else:
		sel_pid = SaveManager.get_selected_pet()
		if sel_pid.is_empty():
			sel_pid = &"mochi"

	var pet_res = PetDataScript.get_pet(sel_pid)
	if pet_res:
		var pet_slot := "pet:" + String(sel_pid).to_lower()
		if pet_skin_id.is_empty():
			pet_skin_id = SaveManager.get_equipped_skin(pet_slot)
		if pet_icon:
			pet_icon.material = null
			pet_icon.texture = null
			if not pet_skin_id.is_empty() and pet_skin_id != "base":
				var stars := SaveManager.get_skin_stars(pet_skin_id)
				CosmeticsManager.apply_skin_to_canvas_item(pet_icon, pet_skin_id, stars)
			if pet_icon.texture == null:
				pet_icon.texture = pet_res.get_icon_texture()
		if pet_name:
			pet_name.text = "%s — %s" % [pet_res.display_name.to_upper(), pet_res.title.to_upper()]
			pet_name.modulate = pet_res.theme_color
		if pet_desc:
			pet_desc.text = pet_res.power_description


func refresh_navigator_display(char_id: StringName = &"") -> void:
	var sel_nid: StringName = &"lyra"
	var nav_skin_id: String = ""
	if not char_id.is_empty():
		var loadout: Dictionary = SaveManager.get_character_loadout(char_id)
		if loadout.has("selected_navigator") and not str(loadout["selected_navigator"]).is_empty():
			sel_nid = StringName(str(loadout["selected_navigator"]))
		if loadout.has("equipped_navigator_skin"):
			nav_skin_id = str(loadout["equipped_navigator_skin"])
	else:
		sel_nid = SaveManager.get_selected_navigator()
		if sel_nid.is_empty():
			sel_nid = &"lyra"

	var nav_res = NavigatorDataScript.get_navigator(sel_nid)
	if nav_res:
		var nav_slot := "navigator:" + String(sel_nid).to_lower()
		if nav_skin_id.is_empty():
			nav_skin_id = SaveManager.get_equipped_skin(nav_slot)
		if navigator_icon:
			navigator_icon.material = null
			navigator_icon.texture = null
			if not nav_skin_id.is_empty() and nav_skin_id != "base":
				var stars := SaveManager.get_skin_stars(nav_skin_id)
				CosmeticsManager.apply_skin_to_canvas_item(navigator_icon, nav_skin_id, stars)
			if navigator_icon.texture == null:
				navigator_icon.texture = nav_res.get_portrait_texture()
		if navigator_name:
			navigator_name.text = "%s — %s" % [nav_res.display_name.to_upper(), nav_res.title.to_upper()]
			navigator_name.modulate = nav_res.theme_color
		if navigator_desc:
			navigator_desc.text = "%s | Buff: %s (%s)" % [nav_res.specialty_desc, nav_res.buff_name, nav_res.buff_desc]

