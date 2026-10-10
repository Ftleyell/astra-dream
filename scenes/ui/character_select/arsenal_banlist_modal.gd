class_name ArsenalBanlistModal
extends CanvasLayer

## ArsenalBanlistModal.gd
## Modal unificado de gestión de Arsenal y Exclusiones (Banlist) para Astra Dream.
## Orquestador desacoplado y ligero (<200 líneas) apoyado en:
## - ArsenalBanlistDataController (reglas del 40%, conteos y persistencia)
## - ArsenalBanlistLayoutBuilder (construcción procedural del layout y paneles)
## - ArsenalCardRenderer (botones, estilos de cartas e indicadores de ban)
## - ArsenalDetailPanel (renderizado e inspección del panel lateral)

const DataControllerScript = preload("res://scenes/ui/character_select/components/arsenal_banlist_data_controller.gd")
const LayoutBuilderScript = preload("res://scenes/ui/character_select/components/arsenal_banlist_layout_builder.gd")
const CardRendererScript = preload("res://scenes/ui/character_select/components/arsenal_card_renderer.gd")
const DetailPanelScript = preload("res://scenes/ui/character_select/components/arsenal_detail_panel.gd")

enum TabCategory {
	WEAPONS,
	TOMES,
	OVERLOADS,
	REACTIVE_PROCS,
	UTILITY_CORES,
	STRATEGIC_MODULES,
	CHEST_ITEMS
}

@export_group("Dimensiones de Ventana")
@export var modal_size: Vector2 = Vector2(760, 580)
@export var side_panel_size: Vector2 = Vector2(340, 580)
@export var card_size: Vector2 = Vector2(80, 80)
@export var icon_size: Vector2 = Vector2(68, 68)
@export var grid_columns: int = 6

signal closed()
signal banlist_updated(char_id: StringName, tab_category: int)

var is_open: bool = false
var current_character_id: StringName = &"nova"
var active_tab: TabCategory = TabCategory.WEAPONS

# Submódulos desacoplados
var data_ctrl: RefCounted = null
var _card_renderer: RefCounted = null
var _detail_panel: RefCounted = null

# Nodos inyectados por LayoutBuilder
var dim_overlay: ColorRect = null
var tabs_container: HBoxContainer = null
var title_label: Label = null
var subtitle_label: Label = null
var counter_label: Label = null
var max_rule_label: Label = null
var warning_label: Label = null
var items_grid: GridContainer = null

var side_detail_panel: PanelContainer = null
var detail_icon_rect: TextureRect = null
var detail_title_label: Label = null
var detail_category_label: Label = null
var detail_rarity_label: Label = null
var detail_stats_label: Label = null
var detail_desc_label: Label = null
var detail_status_badge: Label = null
var detail_status_panel: PanelContainer = null

var tab_buttons: Dictionary[int, Button] = {}
var _warning_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 126
	data_ctrl = DataControllerScript.new(current_character_id)
	_card_renderer = CardRendererScript.new()
	_card_renderer.card_size = card_size
	_card_renderer.icon_size = icon_size
	_card_renderer.grid_columns = grid_columns
	_detail_panel = DetailPanelScript.new()

	LayoutBuilderScript.build_ui(self, modal_size, side_panel_size, grid_columns)
	_detail_panel.bind_nodes(
		detail_icon_rect,
		detail_title_label,
		detail_category_label,
		detail_rarity_label,
		detail_stats_label,
		detail_desc_label,
		detail_status_badge,
		detail_status_panel
	)
	hide()


func open_modal(character_id: StringName = &"nova", default_tab: int = 0) -> void:
	current_character_id = character_id
	if data_ctrl:
		data_ctrl.character_id = character_id
	is_open = true
	active_tab = clampi(default_tab, 0, data_ctrl.tabs_info.size() - 1) as TabCategory
	show()
	_refresh_all_tab_badges()
	_load_active_tab()
	if not _card_renderer.card_buttons.is_empty() and is_instance_valid(_card_renderer.card_buttons[0]):
		_card_renderer.card_buttons[0].grab_focus()


func close_modal() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	closed.emit()


func _on_dim_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_modal()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close_modal()
		get_viewport().set_input_as_handled()
		return

	var tabs_count: int = data_ctrl.tabs_info.size()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_on_tab_pressed((int(active_tab) - 1 + tabs_count) % tabs_count)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			_on_tab_pressed((int(active_tab) + 1) % tabs_count)
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_on_tab_pressed((int(active_tab) - 1 + tabs_count) % tabs_count)
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_on_tab_pressed((int(active_tab) + 1) % tabs_count)
			get_viewport().set_input_as_handled()


func _on_tab_pressed(tab_id: int) -> void:
	active_tab = tab_id as TabCategory
	_refresh_all_tab_badges()
	_load_active_tab()
	if not _card_renderer.card_buttons.is_empty() and is_instance_valid(_card_renderer.card_buttons[0]):
		_card_renderer.card_buttons[0].grab_focus()


func get_max_bans_for_tab(tab_id: int) -> int:
	return data_ctrl.get_max_bans_for_tab(tab_id)


func get_banned_ids_for_tab(tab_id: int) -> Array[StringName]:
	return data_ctrl.get_banned_ids_for_tab(tab_id)


func is_item_banned(tab_id: int, item_id: StringName) -> bool:
	return data_ctrl.is_item_banned(tab_id, item_id)


func _refresh_all_tab_badges() -> void:
	for i in range(data_ctrl.tabs_info.size()):
		var info: Dictionary = data_ctrl.tabs_info[i]
		var tab_id: int = info["id"]
		var btn: Button = tab_buttons.get(tab_id)
		if not btn:
			continue

		var total_items: int = (info["item_ids"] as Array).size()
		var banned: Array[StringName] = data_ctrl.get_banned_ids_for_tab(tab_id)
		var is_active_tab: bool = (tab_id == int(active_tab))

		btn.text = "%s (%d)" % [info["name"], total_items] if banned.is_empty() else "%s (%d) [%d⊘]" % [info["name"], total_items - banned.size(), banned.size()]

		var tab_sb := StyleBoxFlat.new()
		tab_sb.corner_radius_top_left = 8
		tab_sb.corner_radius_top_right = 8
		tab_sb.content_margin_top = 7
		tab_sb.content_margin_bottom = 7
		tab_sb.content_margin_left = 4
		tab_sb.content_margin_right = 4

		if is_active_tab:
			tab_sb.bg_color = Color(0.03, 0.05, 0.09, 0.98)
			tab_sb.border_color = info["accent"]
			tab_sb.border_width_top = 2
			tab_sb.border_width_left = 2
			tab_sb.border_width_right = 2
			btn.add_theme_color_override("font_color", info["accent"])
			btn.add_theme_color_override("font_hover_color", Color.WHITE)
			btn.z_index = 2
		else:
			tab_sb.bg_color = Color(0.015, 0.025, 0.04, 0.8)
			tab_sb.border_color = Color(0.18, 0.28, 0.38, 0.6)
			tab_sb.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
			btn.add_theme_color_override("font_hover_color", Color(0.9, 0.95, 1.0))
			btn.z_index = 1

		btn.add_theme_stylebox_override("normal", tab_sb)
		btn.add_theme_stylebox_override("hover", tab_sb)
		btn.add_theme_stylebox_override("pressed", tab_sb)
		btn.add_theme_stylebox_override("focus", tab_sb)


func _load_active_tab() -> void:
	var tab_idx: int = int(active_tab)
	var info: Dictionary = data_ctrl.get_tab_info(tab_idx)
	title_label.text = info["full_title"]
	subtitle_label.text = info["subtitle"]
	title_label.add_theme_color_override("font_color", info["accent"])

	var total_items: int = (info["item_ids"] as Array).size()
	var banned_ids: Array[StringName] = data_ctrl.get_banned_ids_for_tab(tab_idx)
	var max_bans: int = data_ctrl.get_max_bans_for_tab(tab_idx)
	var active_count: int = total_items - banned_ids.size()

	counter_label.text = "ACTIVOS: %d / %d  |  BANEOS: %d / %d" % [active_count, total_items, banned_ids.size(), max_bans]
	max_rule_label.text = "(MÁXIMO 40%% BANEOS · MÍNIMO %d ACTIVOS EN COMBATE)" % (total_items - max_bans)

	_card_renderer.clear_cards(items_grid)
	for item_id in (info["item_ids"] as Array):
		var is_banned: bool = data_ctrl.is_item_banned(tab_idx, item_id)
		var is_unlocked: bool = data_ctrl.check_item_unlocked(tab_idx, item_id)
		_card_renderer.create_item_card(
			items_grid, item_id, tab_idx, is_banned, is_unlocked,
			Callable(self, "_on_card_pressed"),
			Callable(self, "_on_card_inspected")
		)
	_card_renderer.setup_card_focus_mesh()
	if not _card_renderer.card_buttons.is_empty():
		_inspect_item(_card_renderer.card_buttons[0].get_meta("item_id"), tab_idx)


func _on_card_pressed(item_id: StringName, tab_id: int) -> void:
	if not data_ctrl.toggle_item_ban(tab_id, item_id):
		_deny_ban_action(data_ctrl.get_max_bans_for_tab(tab_id))
		return

	_play_sfx("ui_click")
	_refresh_all_tab_badges()
	_card_renderer.update_card_visuals(item_id, data_ctrl.is_item_banned(tab_id, item_id), data_ctrl.check_item_unlocked(tab_id, item_id))

	var info: Dictionary = data_ctrl.get_tab_info(tab_id)
	var total_items: int = (info["item_ids"] as Array).size()
	var banned_ids: Array[StringName] = data_ctrl.get_banned_ids_for_tab(tab_id)
	counter_label.text = "ACTIVOS: %d / %d  |  BANEOS: %d / %d" % [total_items - banned_ids.size(), total_items, banned_ids.size(), data_ctrl.get_max_bans_for_tab(tab_id)]

	_inspect_item(item_id, tab_id)
	banlist_updated.emit(current_character_id, tab_id)


func _deny_ban_action(max_bans: int) -> void:
	_play_sfx("ui_error")
	warning_label.text = "⚠️ LÍMITE ALCANZADO: MÁXIMO %d EXCLUSIONES PERMITIDAS (40%% DEL POOL)" % max_bans
	if _warning_tween and _warning_tween.is_valid():
		_warning_tween.kill()

	_warning_tween = create_tween()
	_warning_tween.tween_property(warning_label, "modulate:a", 1.0, 0.1)
	_warning_tween.tween_property(warning_label, "modulate:a", 1.0, 1.8)
	_warning_tween.tween_property(warning_label, "modulate:a", 0.0, 0.4)

	var t := create_tween()
	t.tween_property(counter_label, "modulate", Color(1.0, 0.3, 0.3), 0.1)
	t.tween_property(counter_label, "modulate", Color(1.0, 1.0, 1.0), 0.3)


func _on_card_inspected(item_id: StringName, tab_id: int) -> void:
	_inspect_item(item_id, tab_id)


func _inspect_item(item_id: StringName, tab_id: int) -> void:
	_detail_panel.inspect_item(
		item_id, tab_id, data_ctrl.get_tab_info(tab_id),
		data_ctrl.is_item_banned(tab_id, item_id),
		data_ctrl.check_item_unlocked(tab_id, item_id)
	)


func _play_sfx(sfx_name: String) -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name)
