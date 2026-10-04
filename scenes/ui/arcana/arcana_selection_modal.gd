class_name ArcanaSelectionModal
extends CanvasLayer

## ArcanaSelectionModal.gd
## Modal de selección táctica de Arcanas (Pactos de Alto Riesgo / Recompensa).
## Se activa al recolectar un ArcanaOrb liberado por el Monolito Arcano.
## Pausa la partida, ofrece 3 cartas estilizadas Psycho-Pop, visualiza las alteraciones
## exactas en las estadísticas en tiempo real y aplica las modificaciones al jugador.

signal arcana_chosen(arcana: ArcanaData)
signal modal_closed()

const ArcanaCardBuilder = preload("res://scenes/ui/arcana/components/arcana_card_builder.gd")
const ArcanaStatsInspector = preload("res://scenes/ui/arcana/components/arcana_stats_inspector.gd")

const COLOR_HOT_PINK := Color("#FF1493")
const COLOR_DEEP_BLACK := Color("#0A0A0E")
const COLOR_NEON_CYAN := Color("#00F0FF")

@export var player: Player = null

@onready var backdrop: ColorRect = $Backdrop
@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var cards_container: HBoxContainer = find_child("CardsContainer", true, false) as HBoxContainer
@onready var header_title: Label = find_child("HeaderTitle", true, false) as Label
@onready var header_subtitle: Label = find_child("HeaderSubtitle", true, false) as Label
@onready var stats_side_panel: PanelContainer = find_child("StatsSidePanel", true, false) as PanelContainer
@onready var stats_list_container: VBoxContainer = find_child("StatsList", true, false) as VBoxContainer
@onready var stats_header_label: Label = find_child("StatsHeader", true, false) as Label
@onready var pilot_info_label: Label = find_child("PilotInfo", true, false) as Label
@onready var controls_hint_label: Label = find_child("ControlsHint", true, false) as Label

var offered_arcanas: Array[ArcanaData] = []
var card_panels: Array[PanelContainer] = []
var card_buttons: Array[Button] = []
var current_selected_idx: int = 0
var is_active: bool = false
var pending_arcanas_queue: int = 0
var _mouse_lockout_active: bool = false

var stats_inspector: ArcanaStatsInspector = null

var stat_card_ui_entries: Dictionary:
	get:
		var dock := _get_hud_stats_dock()
		if dock and not dock._stat_ui_entries.is_empty():
			return dock._stat_ui_entries
		return stats_inspector.stat_card_ui_entries if stats_inspector else {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if stats_list_container:
		stats_inspector = ArcanaStatsInspector.new()
		stats_inspector.setup(stats_list_container, stats_header_label, pilot_info_label)
	_apply_modal_styles()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active or not visible:
		return

	# Si el Menú de Pausa está abierto por encima, ignorar cualquier entrada para no competir con el foco ni desviar controles
	var parent_game = get_parent()
	if parent_game and parent_game.has_method("is_pause_menu_active") and parent_game.is_pause_menu_active():
		return
	var root_pm = get_tree().root.find_child("PauseMenu", true, false)
	if root_pm and root_pm.visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_select_card_by_index(0)
				get_viewport().set_input_as_handled()
				return
			KEY_2, KEY_KP_2:
				_select_card_by_index(1)
				get_viewport().set_input_as_handled()
				return
			KEY_3, KEY_KP_3:
				_select_card_by_index(2)
				get_viewport().set_input_as_handled()
				return
			KEY_LEFT, KEY_A:
				_cycle_selection(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_RIGHT, KEY_D:
				_cycle_selection(1)
				get_viewport().set_input_as_handled()
				return
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_choose_focused_card()
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("ui_left"):
		_cycle_selection(-1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_right"):
		_cycle_selection(1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_accept"):
		_choose_focused_card()
		get_viewport().set_input_as_handled()
		return


func _cycle_selection(delta_dir: int) -> void:
	if card_buttons.is_empty():
		return
	var next_idx := (current_selected_idx + delta_dir) % card_buttons.size()
	if next_idx < 0:
		next_idx += card_buttons.size()
	_update_card_selection(next_idx)


func _select_card_by_index(idx: int) -> void:
	if idx >= 0 and idx < offered_arcanas.size():
		_on_card_chosen(offered_arcanas[idx])


func _choose_focused_card() -> void:
	if current_selected_idx >= 0 and current_selected_idx < offered_arcanas.size():
		_on_card_chosen(offered_arcanas[current_selected_idx])
	elif not offered_arcanas.is_empty():
		_on_card_chosen(offered_arcanas[0])


func open_modal(p_player: Player = null) -> void:
	show_arcana_selection(p_player)

func show_arcana_selection(p_player: Player = null) -> void:
	var parent_game = get_parent()
	var shop_active: bool = (parent_game and parent_game.has_method("is_satellite_shop_active") and parent_game.is_satellite_shop_active())
	var diag_active: bool = (parent_game and parent_game.has_method("is_dialogue_active") and parent_game.is_dialogue_active())
	var level_active: bool = (parent_game and parent_game.has_method("is_level_up_modal_active") and parent_game.is_level_up_modal_active())
	var pause_active: bool = (parent_game and parent_game.has_method("is_pause_menu_active") and parent_game.is_pause_menu_active())

	if is_active or visible or shop_active or diag_active or level_active or pause_active:
		queue_arcana()
		return

	_present_arcana(p_player)


func queue_arcana() -> void:
	pending_arcanas_queue += 1
	_update_header_title()


func has_pending_arcanas() -> bool:
	return pending_arcanas_queue > 0 or is_active


func clear_pending_arcanas() -> void:
	pending_arcanas_queue = 0
	is_active = false


func show_next_arcana() -> void:
	if is_active and visible:
		return
	if pending_arcanas_queue > 0:
		pending_arcanas_queue -= 1
		_present_arcana(player)
	elif is_instance_valid(player):
		_present_arcana(player)


func _update_header_title() -> void:
	if not header_title:
		return
	if pending_arcanas_queue > 0:
		header_title.text = "◈ INVOCACIÓN DE ARCANA ◈ (+%d PENDIENTES)" % pending_arcanas_queue
	else:
		header_title.text = "◈ INVOCACIÓN DE ARCANA ◈"


const CombatStatsDockClass = preload("res://scenes/ui/hud/components/combat_stats_dock.gd")

func _notify_hud_stats_dock(active: bool) -> void:
	var hud_node: Node = get_tree().get_first_node_in_group("hud") if get_tree() else null
	if not hud_node:
		var parent_game = get_parent()
		if parent_game and "hud" in parent_game and is_instance_valid(parent_game.hud):
			hud_node = parent_game.hud
	if hud_node and hud_node.has_method("set_stats_dock_requested"):
		hud_node.set_stats_dock_requested(&"arcana_selection", active)


func _get_hud_stats_dock() -> CombatStatsDockClass:
	var hud_node: Node = get_tree().get_first_node_in_group("hud") if get_tree() else null
	if not hud_node:
		var parent_game = get_parent()
		if parent_game and "hud" in parent_game and is_instance_valid(parent_game.hud):
			hud_node = parent_game.hud
	if hud_node and "combat_stats_dock" in hud_node and is_instance_valid(hud_node.combat_stats_dock):
		return hud_node.combat_stats_dock as CombatStatsDockClass
	return null


func _present_arcana(p_player: Player = null) -> void:
	if p_player:
		player = p_player
	elif not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player

	# Pausar la simulación de juego solo si no estaba ya activo
	if not is_active:
		PauseArbitrator.acquire_pause(&"arcana_selection")
	is_active = true
	visible = true
	_mouse_lockout_active = true

	var excluded_ids: Array = []
	if is_instance_valid(player) and player.has_method("get_arcana_ids"):
		excluded_ids = player.get_arcana_ids()

	offered_arcanas = ArcanaData.get_random_selection(3, excluded_ids)

	# Manejo seguro si el catálogo está agotado (24 arcanas adquiridas)
	if offered_arcanas.is_empty():
		var overload_arc := ArcanaData.new()
		overload_arc.id = "quantum_overload_mastery"
		overload_arc.name = "Sobrecarga del Vacío"
		overload_arc.description_boon = "Todas las 24 Arcanas asimiladas. +500 Créditos y +15 Materia Oscura inmediata."
		overload_arc.description_curse = "Sobrecarga canalizada. Sin penalizaciones adicionales."
		overload_arc.quadrant = "greed"
		overload_arc.color_accent = Color(0.85, 0.2, 1.0)
		overload_arc.stat_modifiers = {}
		offered_arcanas.append(overload_arc)

	_update_header_title()
	_notify_hud_stats_dock(true)
	_refresh_player_stats_display()
	_build_cards_ui()

	# Audio místico de apertura
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("level_up", 1.1)

	# Foco inicial en la primera carta
	call_deferred("_update_card_selection", 0)

	# Período de gracia contra clicks involuntarios por spam de disparo
	get_tree().create_timer(0.3, true, false, true).timeout.connect(func():
		_mouse_lockout_active = false
	)


func close_modal() -> void:
	is_active = false
	visible = false
	_notify_hud_stats_dock(false)
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()

	# Notificar cierre a MainGame y Player para suprimir disparador de bomba accidental
	var main_node = get_parent()
	if main_node and main_node.has_method("notify_menu_closed"):
		main_node.notify_menu_closed(0.35)
	elif is_instance_valid(player) and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(0.35)

	PauseArbitrator.release_pause(&"arcana_selection")
	if main_node and main_node.has_method("restore_combat_modal_focus") and main_node.has_method("is_any_combat_modal_active") and main_node.is_any_combat_modal_active():
		main_node.restore_combat_modal_focus()

	modal_closed.emit()


func restore_focus() -> void:
	if is_active and current_selected_idx >= 0 and current_selected_idx < card_buttons.size():
		var btn: Button = card_buttons[current_selected_idx]
		if is_instance_valid(btn):
			btn.grab_focus()
	elif is_active and not card_buttons.is_empty() and is_instance_valid(card_buttons[0]):
		card_buttons[0].grab_focus()


func _build_cards_ui() -> void:
	if not cards_container:
		return

	# Limpiar cartas anteriores
	for child in cards_container.get_children():
		child.queue_free()
	card_buttons.clear()
	card_panels.clear()

	var on_chosen := Callable(self, "_on_card_chosen")
	var on_focused := Callable(self, "_update_card_selection")
	var is_locked := Callable(self, "_is_mouse_locked")

	for i in range(offered_arcanas.size()):
		var arc: ArcanaData = offered_arcanas[i]
		var card_data: Dictionary = ArcanaCardBuilder.build_card(arc, i, on_chosen, on_focused, is_locked)
		var card_panel: PanelContainer = card_data["panel"]
		var btn: Button = card_data["button"]
		cards_container.add_child(card_panel)
		card_panels.append(card_panel)
		card_buttons.append(btn)

	# Enlace horizontal cíclico de foco para teclado / gamepad
	var n: int = card_buttons.size()
	for i in range(n):
		var prev_btn: Button = card_buttons[(i - 1 + n) % n]
		var next_btn: Button = card_buttons[(i + 1) % n]
		card_buttons[i].focus_neighbor_left = prev_btn.get_path()
		card_buttons[i].focus_neighbor_right = next_btn.get_path()


func _is_mouse_locked() -> bool:
	return _mouse_lockout_active


func _update_card_selection(idx: int) -> void:
	if idx < 0 or idx >= offered_arcanas.size():
		return
	current_selected_idx = idx

	for i in range(card_panels.size()):
		var p: PanelContainer = card_panels[i]
		var btn: Button = card_buttons[i] if i < card_buttons.size() else null
		var arc: ArcanaData = offered_arcanas[i]
		var is_selected: bool = (i == current_selected_idx)
		ArcanaCardBuilder.apply_selection_style(p, btn, arc, is_selected)
		if is_selected and is_instance_valid(btn) and not btn.has_focus():
			btn.grab_focus()

	_highlight_arcana_stats(offered_arcanas[idx])


func _refresh_player_stats_display() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(player) and get_parent():
		player = get_parent().get_node_or_null("Player") as Player

	var dock := _get_hud_stats_dock()
	if dock and is_instance_valid(player):
		dock.refresh_stats(player)
	elif stats_inspector:
		stats_inspector.refresh_player_stats(player)


func _highlight_arcana_stats(arc: ArcanaData) -> void:
	var dock := _get_hud_stats_dock()
	if dock:
		dock.preview_arcana_deltas(arc)
	elif stats_inspector:
		stats_inspector.highlight_arcana_stats(arc)


func _on_card_chosen(arc: ArcanaData) -> void:
	if arc.id == "quantum_overload_mastery":
		if is_instance_valid(player):
			player.add_credits(500)
			if player.has_method("add_dark_matter"):
				player.add_dark_matter(15)
			else:
				SaveManager.add_dark_matter(15)
	else:
		# Aplicar bonos y maldiciones al jugador
		if is_instance_valid(player) and player.has_method("apply_arcana"):
			player.apply_arcana(arc)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 1.2)

	arcana_chosen.emit(arc)

	if pending_arcanas_queue > 0:
		pending_arcanas_queue -= 1
		_present_arcana(player)
		return

	close_modal()


func _apply_modal_styles() -> void:
	if backdrop:
		backdrop.color = Color(0.02, 0.02, 0.04, 0.88)

	if main_panel:
		var sb := StyleBoxFlat.new()
		sb.bg_color = COLOR_DEEP_BLACK
		sb.border_color = COLOR_HOT_PINK
		sb.set_border_width_all(2)
		sb.border_width_top = 4
		sb.set_corner_radius_all(0)
		sb.shadow_color = Color(1.0, 0.08, 0.58, 0.25)
		sb.shadow_size = 18
		main_panel.add_theme_stylebox_override("panel", sb)

	if stats_side_panel:
		var side_sb := StyleBoxFlat.new()
		side_sb.bg_color = Color(0.03, 0.04, 0.07, 0.92)
		side_sb.set_border_width_all(1)
		side_sb.border_color = Color(0.2, 0.5, 0.8, 0.5)
		side_sb.set_corner_radius_all(6)
		stats_side_panel.add_theme_stylebox_override("panel", side_sb)

	if header_title:
		header_title.text = "◈ INVOCACIÓN DE ARCANA ◈"
		header_title.add_theme_color_override("font_color", COLOR_HOT_PINK)

	if header_subtitle:
		header_subtitle.text = "PACTOS DE ALTO RIESGO / RECOMPENSA - SELECCIONA UNA ALTERACIÓN CUÁNTICA"
		header_subtitle.add_theme_color_override("font_color", COLOR_NEON_CYAN)
