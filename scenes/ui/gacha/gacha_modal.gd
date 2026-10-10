class_name GachaModal
extends CanvasLayer

## GachaModal.gd
## Orquestador desacoplado de la Máquina de Cápsulas Gacha y Armario de Cosméticos:
## - Cúpula procedural con físicas y actuador arcade táctil (GachaDomeWidget).
## - Banners temáticos ("Estelar General", "Hangar de Naves", "Academia de Pilotos").
## - Coordinación de tiradas y pity mediante GachaPullCoordinator.
## - Revelación cinematográfica y resumen de recompensas mediante GachaRevealTheater.
## - Armario y colección de skins mediante GachaWardrobeController.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const SaveManager = preload("res://core/autoloads/save_manager.gd")
const GachaDomeWidgetClass = preload("res://scenes/ui/gacha/gacha_dome_widget.gd")
const GachaPullCoordinatorClass = preload("res://scenes/ui/gacha/components/gacha_pull_coordinator.gd")
const GachaRevealTheaterClass = preload("res://scenes/ui/gacha/components/gacha_reveal_theater.gd")
const GachaWardrobeControllerClass = preload("res://scenes/ui/gacha/components/gacha_wardrobe_controller.gd")
const GachaBannerEngineClass = preload("res://scenes/ui/gacha/components/gacha_banner_engine.gd")

signal skin_unlocked(skin_id: String, stars: int)
signal skin_equipped(slot_key: String, skin_id: String)
signal modal_closed()

var is_animating: bool = false
var _active_tab: int = 0 # 0 = Gacha, 1 = Wardrobe
var _active_banner_id: String = "general"

const BANNERS_CONFIG := GachaBannerEngineClass.BANNERS_CONFIG

# Sub-Controllers
var _pull_coordinator: RefCounted
var _reveal_theater: Control
var _wardrobe_controller: RefCounted

# UI Nodes
var _panel: PanelContainer
var _token_count_label: Label
var _biomass_count_label: Label
var _tab_gacha_btn: Button
var _tab_wardrobe_btn: Button

# Gacha Tab Elements
var _gacha_content: VBoxContainer
var _banner_buttons_box: HBoxContainer
var _banner_title_label: Label
var _banner_desc_label: Label
var _pity_count_label: Label
var _pity_progress_bar: ProgressBar
var _dome_widget: GachaDomeWidget
var _lever_btn: Button
var _pull_1_btn: Button
var _pull_5_btn: Button
var _pull_10_btn: Button

# Backwards Compatibility Facades for test suite
var _hide_locked: bool:
	get:
		return _wardrobe_controller.hide_locked if _wardrobe_controller else false
	set(val):
		if _wardrobe_controller:
			_wardrobe_controller.hide_locked = val

var _hide_locked_check: CheckBox:
	get:
		return _wardrobe_controller.hide_locked_check if _wardrobe_controller else null

var _wardrobe_grid: GridContainer:
	get:
		return _wardrobe_controller.wardrobe_grid if _wardrobe_controller else null

var _wardrobe_content: VBoxContainer:
	get:
		return _wardrobe_controller.wardrobe_content if _wardrobe_controller else null

var _active_category_filter: String:
	get:
		return _wardrobe_controller.active_category_filter if _wardrobe_controller else "all"


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pull_coordinator = GachaPullCoordinatorClass.new()
	_wardrobe_controller = GachaWardrobeControllerClass.new()
	_wardrobe_controller.skin_equipped.connect(_on_wardrobe_skin_equipped)
	_build_ui()
	hide()


const GachaModalLayoutBuilderClass = preload("res://scenes/ui/gacha/components/gacha_modal_layout_builder.gd")
var _layout_builder: RefCounted = GachaModalLayoutBuilderClass.new()


func _build_ui() -> void:
	if _layout_builder:
		_layout_builder.build_modal_ui(self)
	_refresh_banner_info()


func _select_banner(banner_id: String) -> void:
	if is_animating or (_reveal_theater and _reveal_theater.is_theater_active()):
		return
	_active_banner_id = banner_id
	_refresh_banner_info()
	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")


func _refresh_banner_info() -> void:
	var cfg: Dictionary = BANNERS_CONFIG.get(_active_banner_id, BANNERS_CONFIG["general"])
	if _banner_title_label:
		_banner_title_label.text = cfg["title"]
		_banner_title_label.add_theme_color_override("font_color", cfg["color"])
	if _banner_desc_label:
		_banner_desc_label.text = cfg["desc"]

	var current_pity: int = SaveManager.get_banner_pity(_active_banner_id)
	if _pity_count_label:
		_pity_count_label.text = "⚡ PITY [%s]: %d / 10" % [cfg["featured_badge"], current_pity]
	if _pity_progress_bar:
		_pity_progress_bar.value = float(current_pity)

	if _banner_buttons_box:
		var b_keys: Array[String] = ["general", "ships", "pilots"]
		for i: int in range(_banner_buttons_box.get_child_count()):
			var btn: Button = _banner_buttons_box.get_child(i) as Button
			if btn and i < b_keys.size():
				if b_keys[i] == _active_banner_id:
					btn.modulate = Color(0.2, 1.0, 0.8, 1.0)
				else:
					btn.modulate = Color(0.65, 0.65, 0.65, 1.0)


func open_gacha_modal() -> void:
	_refresh_currency()
	_refresh_banner_info()
	_switch_tab(0)
	show()
	get_tree().paused = true


func _refresh_currency() -> void:
	var tokens: int = SaveManager.get_gacha_tokens()
	var bio: int = SaveManager.get_biomass()
	if _token_count_label:
		_token_count_label.text = "🎟️ Fichas: %d" % tokens
	if _biomass_count_label:
		_biomass_count_label.text = "✨ Polvo Estelar: %d" % bio


func _switch_tab(tab_idx: int) -> void:
	_active_tab = tab_idx
	if tab_idx == 0:
		_gacha_content.show()
		if _wardrobe_content:
			_wardrobe_content.hide()
		_tab_gacha_btn.modulate = Color(0.2, 1.0, 0.8, 1.0)
		_tab_wardrobe_btn.modulate = Color(0.7, 0.7, 0.7, 1.0)
		_refresh_banner_info()
	else:
		_gacha_content.hide()
		if _wardrobe_content:
			_wardrobe_content.show()
		_tab_gacha_btn.modulate = Color(0.7, 0.7, 0.7, 1.0)
		_tab_wardrobe_btn.modulate = Color(0.2, 1.0, 0.8, 1.0)
		_filter_wardrobe(_active_category_filter)


func _filter_wardrobe(category_id: String) -> void:
	if _wardrobe_controller:
		_wardrobe_controller.filter_wardrobe(category_id)


func execute_pulls(count: int) -> Array[Dictionary]:
	if not _pull_coordinator:
		return []
	var results: Array[Dictionary] = _pull_coordinator.execute_pulls(count, _active_banner_id)
	if not results.is_empty():
		_refresh_currency()
		_refresh_banner_info()
	return results


func _on_lever_pulled() -> void:
	if is_animating or (_reveal_theater and _reveal_theater.is_theater_active()):
		return
	var current_tokens: int = SaveManager.get_gacha_tokens()
	if current_tokens < 1:
		_flash_no_tokens()
		return

	if _lever_btn:
		var tw: Tween = create_tween()
		if tw:
			tw.tween_property(_lever_btn, "scale", Vector2(0.92, 0.92), 0.1)
			tw.tween_property(_lever_btn, "scale", Vector2.ONE, 0.15)

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")

	_start_gacha_sequence(1)


func _start_gacha_sequence(count: int) -> void:
	if is_animating or (_reveal_theater and _reveal_theater.is_theater_active()):
		return
	var current_tokens: int = SaveManager.get_gacha_tokens()
	if current_tokens < count:
		_flash_no_tokens()
		return

	is_animating = true
	if _dome_widget:
		_dome_widget.trigger_spin_and_shake(1.0)

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("satellite_activate")

	var results: Array[Dictionary] = execute_pulls(count)
	if results.is_empty():
		is_animating = false
		return

	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if _reveal_theater:
			_reveal_theater.start_sequence(results)
	)


func _on_reveal_theater_finished() -> void:
	is_animating = false
	_refresh_currency()
	_refresh_banner_info()


func _flash_no_tokens() -> void:
	if _token_count_label:
		_token_count_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
		var tw: Tween = create_tween()
		if tw:
			tw.tween_property(_token_count_label, "modulate", Color.WHITE, 0.6)


func _on_wardrobe_skin_equipped(slot_key: String, skin_id: String) -> void:
	skin_equipped.emit(slot_key, skin_id)


func close_modal() -> void:
	_on_close_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		if _reveal_theater and _reveal_theater.is_theater_active():
			_reveal_theater.skip_sequence()
			get_viewport().set_input_as_handled()
			return
		close_modal()
		get_viewport().set_input_as_handled()


func _on_close_pressed() -> void:
	hide()
	get_tree().paused = false
	modal_closed.emit()
