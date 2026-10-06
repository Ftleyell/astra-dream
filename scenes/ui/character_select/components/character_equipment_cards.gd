class_name CharacterEquipmentCards
extends RefCounted

## CharacterEquipmentCards.gd
## Controlador modular de las tarjetas de equipamiento (Nave, Arma, Mascota, Navegadora)
## para CharacterSelectUI. Gestiona el feedback visual de hover, iconos, descripciones y skins cosméticas.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const PetDataScript = preload("res://data/pets/pet_data.gd")
const NavigatorDataScript = preload("res://data/navigators/navigator_data.gd")

var ship_card: PanelContainer = null
var ship_icon: TextureRect = null
var ship_name: Label = null
var ship_button: Button = null

var weapon_card: PanelContainer = null
var weapon_icon: TextureRect = null
var weapon_name: Label = null
var weapon_button: Button = null

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
		UIFocusHelper.apply_cyber_focus(ship_button)
		ship_button.pressed.connect(p_on_ship_pressed)
		setup_card_hover_feedback(ship_button, ship_card, Color(0.2, 0.95, 1.0, 1.0))

	if weapon_button:
		UIFocusHelper.apply_cyber_focus(weapon_button)
		weapon_button.pressed.connect(p_on_weapon_pressed)
		setup_card_hover_feedback(weapon_button, weapon_card, Color(1.0, 0.85, 0.35, 1.0))

	# Centrado en medio del contenedor: se ajusta dinámicamente según la textura asignada
	_apply_weapon_optical_centering()


func _apply_weapon_optical_centering() -> void:
	if not weapon_icon or not weapon_icon.texture:
		return
	
	var raw_tex: Texture2D = weapon_icon.texture
	if raw_tex is AtlasTexture:
		raw_tex = (raw_tex as AtlasTexture).atlas
	if not raw_tex:
		return

	var tw: float = float(raw_tex.get_width())
	var th: float = float(raw_tex.get_height())
	if tw <= 0.0 or th <= 0.0:
		return

	# Si es un sprite de arma orbital con margen de rotación (256x256 o 1024x1024)
	# recortamos estrictamente a la región visible con un margen equilibrado del 8%
	if tw == 256.0 or tw == 1024.0:
		var ratio: float = tw / 256.0
		# Rectángulo del contenido visible centrado:
		# En 256x256, el arma va de x: 88..248, y: 88..168 (ancho ~160, alto ~80)
		var crop_x: float = 84.0 * ratio
		var crop_y: float = 80.0 * ratio
		var crop_w: float = 168.0 * ratio
		var crop_h: float = 96.0 * ratio

		var atlas := AtlasTexture.new()
		atlas.atlas = raw_tex
		atlas.region = Rect2(crop_x, crop_y, crop_w, crop_h)
		weapon_icon.texture = atlas
		weapon_icon.position = Vector2.ZERO
		weapon_icon.scale = Vector2.ONE


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
		UIFocusHelper.apply_cyber_focus(pet_button)
		pet_button.pressed.connect(p_on_pet_pressed)
		setup_card_hover_feedback(pet_button, pet_card, Color(0.2, 0.95, 0.65, 1.0))

	if navigator_button:
		UIFocusHelper.apply_cyber_focus(navigator_button)
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


func update_equipment(data: CharacterData, char_id: StringName) -> void:
	if not data:
		return

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

