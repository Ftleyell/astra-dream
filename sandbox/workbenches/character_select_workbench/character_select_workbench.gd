class_name CharacterSelectWorkbench
extends Control
## Workbench sobre producción real para pulir CharacterSelectUI y HeroPickerModal sin tocar el save real.

const CharacterSelectScene: PackedScene = preload("res://scenes/ui/character_select/character_select.tscn")
const SkinCatalogPath: String = "res://data/pilots/valentina_v2/valentina_v2_skin_catalog.tres"
const CharSelectPanelScript = preload("res://sandbox/workbenches/character_select_workbench/character_select_workbench_panel.gd")
const AlignmentOverlayScript = preload("res://sandbox/workbenches/shared/workbench_alignment_overlay.gd")
const SaveSandboxScript = preload("res://sandbox/workbenches/shared/workbench_save_sandbox.gd")
const WORKBENCH_HUB_PATH: String = "res://sandbox/workbenches/workbench_hub.tscn"

var char_select: CharacterSelectUI = null
var alignment_overlay: AlignmentOverlayScript = null
var _save_sandbox: SaveSandboxScript = SaveSandboxScript.new()
var _panel_refs: Dictionary = {}

var _pilot_ids: Array[String] = ["base"]
var _pilot_labels: Array[String] = ["Base (Original)"]
var _wings_ids: Array[String] = ["follow_pilot", "base"]
var _wings_labels: Array[String] = ["Seguir Piloto", "Base (Original)"]
var _weapon_ids: Array[String] = ["follow_pilot", "base"]
var _weapon_labels: Array[String] = ["Seguir Piloto", "Base (Original)"]


func _enter_tree() -> void:
	_save_sandbox.backup()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_skin_catalog_choices()
	_mount_character_select()
	alignment_overlay = AlignmentOverlayScript.attach_to(self, 145) as AlignmentOverlayScript
	_register_alignment_targets()
	_panel_refs = CharSelectPanelScript.build(self, self)
	_refresh_metrics_label()


func _exit_tree() -> void:
	_cleanup_char_select()
	_save_sandbox.restore()


func _process(_delta: float) -> void:
	_refresh_metrics_label()


func _unhandled_input(event: InputEvent) -> void:
	var key_ev := event as InputEventKey
	if key_ev != null and key_ev.pressed and not key_ev.echo:
		if key_ev.keycode == KEY_G:
			toggle_guides()
			get_viewport().set_input_as_handled()
		elif key_ev.keycode == KEY_H:
			var panel: Control = _panel_refs.get("panel") as Control
			if is_instance_valid(panel):
				panel.visible = not panel.visible
			get_viewport().set_input_as_handled()


func _load_skin_catalog_choices() -> void:
	_pilot_ids = ["base"]
	_pilot_labels = ["Base (Original)"]
	_wings_ids = ["follow_pilot", "base"]
	_wings_labels = ["Seguir Piloto", "Base (Original)"]
	_weapon_ids = ["follow_pilot", "base"]
	_weapon_labels = ["Seguir Piloto", "Base (Original)"]

	if not ResourceLoader.exists(SkinCatalogPath):
		return
	var catalog: PilotShaderSkinCatalog = ResourceLoader.load(SkinCatalogPath) as PilotShaderSkinCatalog
	if catalog == null:
		return
	for entry: ShaderSkinEntry in catalog.entries:
		if entry == null or entry.id.is_empty():
			continue
		var label_str: String = entry.skin_name if not entry.skin_name.is_empty() else entry.id
		match entry.category:
			"pilot":
				_pilot_ids.append(entry.id)
				_pilot_labels.append(label_str)
			"wings", "ship":
				_wings_ids.append(entry.id)
				_wings_labels.append(label_str)
			"weapon":
				_weapon_ids.append(entry.id)
				_weapon_labels.append(label_str)


func get_skin_display_lists() -> Dictionary:
	return {
		"pilot_labels": _pilot_labels,
		"wings_labels": _wings_labels,
		"weapon_labels": _weapon_labels,
	}


func _mount_character_select() -> void:
	_cleanup_char_select()
	char_select = CharacterSelectScene.instantiate() as CharacterSelectUI
	char_select.name = "CharacterSelectUI"
	char_select.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(char_select)


func _cleanup_char_select() -> void:
	if is_instance_valid(char_select):
		char_select.queue_free()
		char_select = null


func _register_alignment_targets() -> void:
	if alignment_overlay == null or not is_instance_valid(char_select):
		return
	alignment_overlay.clear_targets()
	var left_panel: Control = char_select.find_child("LeftCommandPanel", true, false) as Control
	var right_area: Control = char_select.find_child("RightShowcaseArea", true, false) as Control
	var header_bar: Control = char_select.find_child("HeaderBar", true, false) as Control
	var hero_box: Control = char_select.find_child("HeroIdentityBox", true, false) as Control

	alignment_overlay.register_control("HeaderBar", header_bar)
	alignment_overlay.register_control("LeftCommandPanel", left_panel)
	alignment_overlay.register_control("RightShowcaseArea", right_area)
	alignment_overlay.register_control("HeroIdentityBox", hero_box)
	alignment_overlay.register_gap_pair("Panel↔Showcase", left_panel, right_area)


func open_hero_picker() -> void:
	if not is_instance_valid(char_select) or char_select.hero_picker_modal == null:
		return
	if char_select.main_margin_container != null:
		char_select.main_margin_container.visible = false
	if char_select.dock_container != null:
		char_select.dock_container.visible = false
	char_select.hero_picker_modal.open_picker(char_select.roster_ordered, char_select.current_character_id, false)
	_set_status("Vista: Hero Picker abierto")


func open_loadout_view() -> void:
	if not is_instance_valid(char_select):
		return
	char_select._on_hero_confirmed(char_select.current_character_id)
	_set_status("Vista: Loadout & Showcase activos")


func switch_tab_view(tab_idx: int) -> void:
	if not is_instance_valid(char_select):
		return
	open_loadout_view()
	if char_select.tab_controller != null:
		char_select.tab_controller.switch_tab(tab_idx)
	_set_status("Tab activo: %d" % tab_idx)


func select_skin_by_index(slot_category: String, idx: int) -> void:
	match slot_category:
		"pilot":
			if idx >= 0 and idx < _pilot_ids.size():
				apply_valentina_skin("pilot:valentina", _pilot_ids[idx])
		"wings":
			if idx >= 0 and idx < _wings_ids.size():
				apply_valentina_skin("wings:valentina", _wings_ids[idx])
		"weapon":
			if idx >= 0 and idx < _weapon_ids.size():
				apply_valentina_skin("weapon:valentina", _weapon_ids[idx])


func apply_valentina_skin(slot_key: String, skin_id: String) -> void:
	if not skin_id.is_empty() and skin_id != "base" and skin_id != "follow_pilot":
		SaveManager.unlock_or_upgrade_skin(skin_id)
	SaveManager.equip_skin(slot_key, skin_id)
	if is_instance_valid(char_select) and char_select.skin_coordinator != null:
		char_select.skin_coordinator.handle_skin_selected(slot_key, skin_id, &"valentina")
	if is_instance_valid(char_select) and char_select.hero_picker_modal != null and char_select.hero_picker_modal.is_open:
		char_select.hero_picker_modal.open_picker(char_select.roster_ordered, &"valentina", char_select.hero_picker_modal.is_initial_entry)
	_set_status("Skin %s -> %s" % [slot_key, skin_id])


func apply_save_preset(preset_id: String) -> void:
	match preset_id:
		"unlock_all":
			SaveManager.unlock_all_skins(5)
			_set_status("Save sandbox: Todas las skins ★5 desbloqueadas")
		"base_only":
			SaveManager.lock_all_skins()
			apply_valentina_skin("pilot:valentina", "base")
			apply_valentina_skin("wings:valentina", "follow_pilot")
			apply_valentina_skin("weapon:valentina", "follow_pilot")
			_set_status("Save sandbox: Solo Base")
		"rich_wallet":
			SaveManager.add_biomass(9999)
			SaveManager.add_antimatter(9999)
			SaveManager.add_dark_matter(9999)
			SaveManager.set_gacha_tokens(999)
			_set_status("Save sandbox: Monedas +9999 / Tickets 999")
		"restore":
			_save_sandbox.reset_to_backup()
			reload_character_select()
			_set_status("Snapshot de save restaurado")
			return
	if is_instance_valid(char_select):
		char_select._select_character(char_select.current_character_id)


func reload_character_select() -> void:
	_mount_character_select()
	_register_alignment_targets()
	_set_status("CharacterSelectUI recargado")


func toggle_guides() -> void:
	if alignment_overlay != null:
		alignment_overlay.show_guides = not alignment_overlay.show_guides
		_set_status("Guías: %s" % ("ON" if alignment_overlay.show_guides else "OFF"))


func return_to_hub() -> void:
	get_tree().change_scene_to_file(WORKBENCH_HUB_PATH)


func _refresh_metrics_label() -> void:
	var lbl: Label = _panel_refs.get("metrics_label") as Label
	if not is_instance_valid(lbl) or not is_instance_valid(char_select):
		return
	var left_p: Control = char_select.find_child("LeftCommandPanel", true, false) as Control
	var right_a: Control = char_select.find_child("RightShowcaseArea", true, false) as Control
	var header_b: Control = char_select.find_child("HeaderBar", true, false) as Control
	var hero_b: Control = char_select.find_child("HeroIdentityBox", true, false) as Control
	if left_p == null or right_a == null or header_b == null or hero_b == null:
		return
	var lr: Rect2 = left_p.get_global_rect()
	var rr: Rect2 = right_a.get_global_rect()
	var hr: Rect2 = header_b.get_global_rect()
	var hbr: Rect2 = hero_b.get_global_rect()
	lbl.text = "Header: %dx%d\nLeftPanel: %dx%d | RightArea: %dx%d\nHeroBox: %dx%d @ (%.0f, %.0f)" % [
		int(hr.size.x), int(hr.size.y),
		int(lr.size.x), int(lr.size.y),
		int(rr.size.x), int(rr.size.y),
		int(hbr.size.x), int(hbr.size.y), hbr.position.x, hbr.position.y,
	]


func _set_status(msg: String) -> void:
	var lbl: Label = _panel_refs.get("status_label") as Label
	if is_instance_valid(lbl):
		lbl.text = msg
