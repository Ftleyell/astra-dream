class_name CharacterSelectModalRouter
extends RefCounted

## Enrutador desacoplado para la apertura, consulta de estado y cierre de modales en CharacterSelect.

const CharacterFocusRouter = preload("res://scenes/ui/character_select/components/character_focus_router.gd")

var debug_menu_modal: Node = null
var pet_selection_modal: Node = null
var navigator_selection_modal: Node = null
var gacha_modal: Node = null
var tome_selection_modal: Node = null
var weapon_selection_modal: Node = null
var character_skill_tree_modal: Node = null
var cosmetic_carousel_modal: Node = null
var hero_picker_modal: Node = null
var arsenal_banlist_modal: Node = null


func setup_from_root(root: Control) -> void:
	debug_menu_modal = root.get_node_or_null("DebugMenuModal")
	pet_selection_modal = root.get_node_or_null("PetSelectionModal")
	navigator_selection_modal = root.get_node_or_null("NavigatorSelectionModal")
	gacha_modal = root.get_node_or_null("GachaModal")
	tome_selection_modal = root.get_node_or_null("TomeSelectionModal")
	weapon_selection_modal = root.get_node_or_null("WeaponSelectionModal")
	character_skill_tree_modal = root.get_node_or_null("CharacterSkillTreeModal")
	cosmetic_carousel_modal = root.get_node_or_null("CosmeticCarouselModal")
	hero_picker_modal = root.get_node_or_null("HeroPickerModal")
	arsenal_banlist_modal = root.get_node_or_null("ArsenalBanlistModal")


func connect_modal_signals(listener: Object) -> void:
	if pet_selection_modal:
		if pet_selection_modal.has_signal("pet_selected"):
			pet_selection_modal.connect("pet_selected", Callable(listener, "_on_pet_selected"))
		if pet_selection_modal.has_signal("skin_equipped"):
			pet_selection_modal.connect("skin_equipped", Callable(listener, "_on_pet_skin_equipped"))
		if pet_selection_modal.has_signal("closed"):
			pet_selection_modal.connect("closed", Callable(listener, "_on_pet_modal_closed"))

	if navigator_selection_modal:
		if navigator_selection_modal.has_signal("navigator_selected"):
			navigator_selection_modal.connect("navigator_selected", Callable(listener, "_on_navigator_selected"))
		if navigator_selection_modal.has_signal("skin_equipped"):
			navigator_selection_modal.connect("skin_equipped", Callable(listener, "_on_navigator_skin_equipped"))
		if navigator_selection_modal.has_signal("closed"):
			navigator_selection_modal.connect("closed", Callable(listener, "_on_navigator_modal_closed"))

	if debug_menu_modal and debug_menu_modal.has_signal("closed"):
		debug_menu_modal.connect("closed", Callable(listener, "_on_debug_modal_closed"))

	if cosmetic_carousel_modal:
		if cosmetic_carousel_modal.has_signal("skin_modal_closed"):
			cosmetic_carousel_modal.connect("skin_modal_closed", Callable(listener, "_on_cosmetic_carousel_closed"))
		if cosmetic_carousel_modal.has_signal("skin_selected"):
			cosmetic_carousel_modal.connect("skin_selected", Callable(listener, "_on_skin_selected"))

	if gacha_modal:
		if gacha_modal.has_signal("skin_equipped"):
			gacha_modal.connect("skin_equipped", Callable(listener, "_on_gacha_skin_equipped"))
		if gacha_modal.has_signal("modal_closed"):
			gacha_modal.connect("modal_closed", Callable(listener, "_on_gacha_modal_closed"))

	if tome_selection_modal and tome_selection_modal.has_signal("closed"):
		tome_selection_modal.connect("closed", Callable(listener, "_on_tome_modal_closed"))

	if weapon_selection_modal and weapon_selection_modal.has_signal("closed"):
		weapon_selection_modal.connect("closed", Callable(listener, "_on_weapon_modal_closed"))

	if arsenal_banlist_modal and arsenal_banlist_modal.has_signal("closed"):
		arsenal_banlist_modal.connect("closed", Callable(listener, "_on_arsenal_banlist_modal_closed"))

	if character_skill_tree_modal:
		if character_skill_tree_modal.has_signal("modal_closed"):
			character_skill_tree_modal.connect("modal_closed", Callable(listener, "_on_skill_tree_closed"))
		elif character_skill_tree_modal.has_signal("closed"):
			character_skill_tree_modal.connect("closed", Callable(listener, "_on_skill_tree_closed"))


func setup_modals(
	p_debug: Node,
	p_pet: Node,
	p_nav: Node,
	p_gacha: Node,
	p_tome: Node,
	p_weapon: Node,
	p_skill_tree: Node,
	p_carousel: Node,
	p_hero_picker: Node,
	p_arsenal_banlist: Node
) -> void:
	debug_menu_modal = p_debug
	pet_selection_modal = p_pet
	navigator_selection_modal = p_nav
	gacha_modal = p_gacha
	tome_selection_modal = p_tome
	weapon_selection_modal = p_weapon
	character_skill_tree_modal = p_skill_tree
	cosmetic_carousel_modal = p_carousel
	hero_picker_modal = p_hero_picker
	arsenal_banlist_modal = p_arsenal_banlist


func has_any_modal_open() -> bool:
	if cosmetic_carousel_modal and cosmetic_carousel_modal.get("is_open"):
		return true
	if hero_picker_modal and hero_picker_modal.get("is_open"):
		return true
	if debug_menu_modal and debug_menu_modal.get("is_open"):
		return true
	if pet_selection_modal and pet_selection_modal.get("is_open"):
		return true
	if navigator_selection_modal and navigator_selection_modal.get("is_open"):
		return true
	if gacha_modal and gacha_modal.visible:
		return true
	if tome_selection_modal and tome_selection_modal.get("is_open"):
		return true
	if weapon_selection_modal and weapon_selection_modal.get("is_open"):
		return true
	if arsenal_banlist_modal and arsenal_banlist_modal.get("is_open"):
		return true
	if character_skill_tree_modal and character_skill_tree_modal.visible:
		return true
	return false


func open_talents(char_id: StringName, viewport: Viewport, focus_router: CharacterFocusRouter) -> void:
	if character_skill_tree_modal and character_skill_tree_modal.has_method("open_for_character"):
		if focus_router and viewport:
			focus_router.save_focus(viewport)
		character_skill_tree_modal.call("open_for_character", char_id)


func open_arsenal_banlist(char_id: StringName, default_tab: int, viewport: Viewport, focus_router: CharacterFocusRouter) -> void:
	if focus_router and viewport:
		focus_router.save_focus(viewport)

	if arsenal_banlist_modal and arsenal_banlist_modal.has_method("open_modal"):
		arsenal_banlist_modal.call("open_modal", char_id, default_tab)
	elif default_tab == 1 and tome_selection_modal and tome_selection_modal.has_method("open_modal"):
		tome_selection_modal.call("open_modal", char_id)
	elif weapon_selection_modal and weapon_selection_modal.has_method("open_modal"):
		weapon_selection_modal.call("open_modal", char_id)


func open_tomes_pool(char_id: StringName, viewport: Viewport, focus_router: CharacterFocusRouter) -> void:
	if focus_router and viewport:
		focus_router.save_focus(viewport)

	if arsenal_banlist_modal and arsenal_banlist_modal.has_method("open_modal"):
		arsenal_banlist_modal.call("open_modal", char_id, 1)
	elif tome_selection_modal and tome_selection_modal.has_method("open_modal"):
		tome_selection_modal.call("open_modal", char_id)


func open_loadout(char_id: StringName, viewport: Viewport, focus_router: CharacterFocusRouter) -> void:
	if focus_router and viewport:
		focus_router.save_focus(viewport)

	if arsenal_banlist_modal and arsenal_banlist_modal.has_method("open_modal"):
		arsenal_banlist_modal.call("open_modal", char_id, 0)
	if weapon_selection_modal and weapon_selection_modal.has_method("open_modal"):
		weapon_selection_modal.call("open_modal", char_id)


func open_debug(char_data: CharacterData, viewport: Viewport, focus_router: CharacterFocusRouter) -> void:
	if debug_menu_modal and debug_menu_modal.has_method("open_menu"):
		if focus_router and viewport:
			focus_router.save_focus(viewport)
		debug_menu_modal.call("open_menu", char_data)


func restore_modal_closed_focus(preferred_control: Control, focus_router: CharacterFocusRouter, fallback_terminal: Control) -> void:
	var target: Control = null
	if preferred_control and preferred_control.is_visible_in_tree():
		target = preferred_control
	elif focus_router and focus_router.has_valid_saved_focus():
		target = focus_router.get_saved_focus()
	elif fallback_terminal and fallback_terminal.is_visible_in_tree():
		target = fallback_terminal

	if target:
		target.grab_focus()
