class_name DialogueWorkbench
extends Node2D
## Workbench sobre producción real para probar Dialogic, retratos .dch y secuencias narrativas.

const CombatNarrativeDirectorScript = preload("res://scenes/combat/directors/combat_narrative_director.gd")
const DialogueBackdropScene: PackedScene = preload("res://scenes/ui/dialogue/dialogue_backdrop_layer.tscn")
const DialogueSkipScene: PackedScene = preload("res://scenes/ui/dialogue_skip_overlay.tscn")
const NavControllerScript = preload("res://scenes/combat/navigators/navigator_controller.gd")
const NavigatorDataScript = preload("res://data/navigators/navigator_data.gd")
const CosmosEnvScene: PackedScene = preload("res://scenes/combat/environment/cosmos_combat_environment.tscn")
const DialoguePanelScript = preload("res://sandbox/workbenches/dialogue_workbench/dialogue_workbench_panel.gd")
const AlignmentOverlayScript = preload("res://sandbox/workbenches/shared/workbench_alignment_overlay.gd")
const SaveSandboxScript = preload("res://sandbox/workbenches/shared/workbench_save_sandbox.gd")
const WORKBENCH_HUB_PATH: String = "res://sandbox/workbenches/workbench_hub.tscn"


class MockDialoguePlayer extends CharacterBody2D:
	var character_data: CharacterData = null
	var run_credits: int = 100
	var stats: CharacterStats = CharacterStats.new()
	var is_invulnerable: bool = false
	var is_movement_suppressed: bool = false
	var is_dead: bool = false

	func resume_movement_control() -> void:
		is_invulnerable = false
		is_movement_suppressed = false


class MockDialogueRival extends Node2D:
	var pilot_id: StringName = &"nova"


var narrative_director: CombatNarrativeDirector = null
var backdrop_layer: DialogueBackdropLayer = null
var skip_badge_layer: DialogueSkipOverlay = null
var navigator_controller: NavigatorController = null
var alignment_overlay: AlignmentOverlayScript = null

var _save_sandbox: SaveSandboxScript = SaveSandboxScript.new()
var _camera: Camera2D = null
var _cosmos_env: CosmosCombatEnvironment = null
var _backdrop_bg_layer: CanvasLayer = null
var _panel_refs: Dictionary = {}

var _mock_player: MockDialoguePlayer = null
var _mock_rival: MockDialogueRival = null
var _roster: Dictionary[StringName, CharacterData] = {}

var selected_pilot_id: String = "valentina"
var selected_pet_id: String = "mochi"
var selected_rival_id: String = "nova"
var selected_navigator_id: String = "lyra"
var selected_portrait_name: String = "Normal"
var _cached_portraits: Dictionary = {}

# Propiedades leídas por CombatNarrativeDirector / CombatRadioFeedController vía main_game
var is_boss_transmission_active: bool = false
var is_cockpit_active: bool = false
var is_rival_cinematic_active: bool = false
var current_boss: Node2D = null
var current_rival: Node2D = null
var rivals_spared: Array[StringName] = [&"nova", &"kira", &"selene", &"roxy", &"echo"]


func _enter_tree() -> void:
	_save_sandbox.backup()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_roster = CharacterData.load_roster()
	_build_stage()
	_mount_narrative_stack()
	alignment_overlay = AlignmentOverlayScript.attach_to(self, 75) as AlignmentOverlayScript
	_panel_refs = DialoguePanelScript.build(self, self)
	_sync_participants_to_mocks()
	_refresh_portrait_inspector()


func _exit_tree() -> void:
	stop_active_dialogue()
	_disconnect_dialogic_signals()
	PauseArbitrator.release_pause(&"dialogue")
	PauseArbitrator.release_pause(&"briefing")
	_save_sandbox.restore()


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


func _build_stage() -> void:
	_backdrop_bg_layer = CanvasLayer.new()
	_backdrop_bg_layer.name = "StageBgLayer"
	_backdrop_bg_layer.layer = -120
	add_child(_backdrop_bg_layer)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.09, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_bg_layer.add_child(bg)

	_camera = Camera2D.new()
	_camera.name = "DialogueCamera"
	_camera.position = Vector2(960.0, 540.0)
	_camera.enabled = true
	add_child(_camera)

	_mock_player = MockDialoguePlayer.new()
	_mock_player.name = "MockDialoguePlayer"
	_mock_player.position = Vector2(960.0, 540.0)
	add_child(_mock_player)

	_mock_rival = MockDialogueRival.new()
	_mock_rival.name = "MockDialogueRival"
	_mock_rival.position = Vector2(1180.0, 420.0)
	add_child(_mock_rival)
	current_rival = _mock_rival


func _mount_narrative_stack() -> void:
	skip_badge_layer = DialogueSkipScene.instantiate() as DialogueSkipOverlay
	skip_badge_layer.name = "SkipBadgeLayer"
	add_child(skip_badge_layer)

	backdrop_layer = DialogueBackdropScene.instantiate() as DialogueBackdropLayer
	backdrop_layer.name = "DialogueBackdropLayer"
	add_child(backdrop_layer)

	navigator_controller = NavControllerScript.new()
	navigator_controller.name = "NavigatorController"
	add_child(navigator_controller)
	navigator_controller.setup(self, null, null)
	navigator_controller.set_process(false)

	narrative_director = CombatNarrativeDirectorScript.new()
	narrative_director.name = "CombatNarrativeDirector"
	add_child(narrative_director)
	narrative_director.setup(self, _mock_player, null, skip_badge_layer, null)
	narrative_director.active_navigator_controller = navigator_controller
	narrative_director.victory_screen_requested.connect(_on_victory_screen_requested)

	if skip_badge_layer.has_signal("skip_requested"):
		skip_badge_layer.skip_requested.connect(stop_active_dialogue)

	_connect_dialogic_signals()


func _connect_dialogic_signals() -> void:
	var dialogic_node: Node = narrative_director.get_dialogic() if narrative_director != null else null
	if dialogic_node == null:
		return
	dialogic_node.process_mode = Node.PROCESS_MODE_ALWAYS
	if dialogic_node.has_signal("timeline_started") and not dialogic_node.timeline_started.is_connected(_on_dialogic_timeline_started):
		dialogic_node.timeline_started.connect(_on_dialogic_timeline_started)
	if dialogic_node.has_signal("timeline_ended") and not dialogic_node.timeline_ended.is_connected(_on_dialogic_timeline_ended):
		dialogic_node.timeline_ended.connect(_on_dialogic_timeline_ended)
	if dialogic_node.has_signal("signal_event") and not dialogic_node.signal_event.is_connected(_on_dialogic_signal_event):
		dialogic_node.signal_event.connect(_on_dialogic_signal_event)


func _disconnect_dialogic_signals() -> void:
	var dialogic_node: Node = narrative_director.get_dialogic() if is_instance_valid(narrative_director) else get_node_or_null("/root/Dialogic")
	if dialogic_node == null:
		return
	if dialogic_node.has_signal("timeline_started") and dialogic_node.timeline_started.is_connected(_on_dialogic_timeline_started):
		dialogic_node.timeline_started.disconnect(_on_dialogic_timeline_started)
	if dialogic_node.has_signal("timeline_ended") and dialogic_node.timeline_ended.is_connected(_on_dialogic_timeline_ended):
		dialogic_node.timeline_ended.disconnect(_on_dialogic_timeline_ended)
	if dialogic_node.has_signal("signal_event") and dialogic_node.signal_event.is_connected(_on_dialogic_signal_event):
		dialogic_node.signal_event.disconnect(_on_dialogic_signal_event)


func _on_dialogic_timeline_started() -> void:
	if is_instance_valid(narrative_director):
		narrative_director.on_timeline_started()


func _on_dialogic_timeline_ended() -> void:
	if is_instance_valid(narrative_director):
		narrative_director.on_timeline_ended()
	_set_status("Diálogo finalizado")


func _on_dialogic_signal_event(arg: Variant) -> void:
	if is_instance_valid(narrative_director):
		narrative_director.on_dialogic_signal(arg)


func _on_victory_screen_requested(v_data: Dictionary) -> void:
	_set_status("Victory callback recibido (route=%s)" % str(v_data.get("route", "unknown")))


func _sync_participants_to_mocks() -> void:
	var pid := StringName(selected_pilot_id)
	if _roster.has(pid):
		_mock_player.character_data = _roster[pid]
		_mock_player.stats.initialize(_mock_player.character_data)
	elif not _roster.is_empty():
		_mock_player.character_data = _roster.values()[0]
		_mock_player.stats.initialize(_mock_player.character_data)

	_mock_rival.pilot_id = StringName(selected_rival_id)
	SaveManager.set_selected_pet(StringName(selected_pet_id))
	SaveManager.set_selected_navigator(StringName(selected_navigator_id))
	if is_instance_valid(navigator_controller):
		navigator_controller.navigator_data = NavigatorDataScript.get_navigator(StringName(selected_navigator_id))


func set_selected_pilot(pilot_id: String) -> void:
	selected_pilot_id = pilot_id.to_lower()
	_sync_participants_to_mocks()
	_refresh_portrait_inspector()
	_set_status("Piloto activo: %s" % selected_pilot_id)


func set_selected_pet(pet_id: String) -> void:
	selected_pet_id = pet_id.to_lower()
	_sync_participants_to_mocks()
	_set_status("Mascota activa: %s" % selected_pet_id)


func set_selected_rival(rival_id: String) -> void:
	selected_rival_id = rival_id.to_lower()
	_sync_participants_to_mocks()
	_set_status("Rival activo: %s" % selected_rival_id)


func set_selected_navigator(nav_id: String) -> void:
	selected_navigator_id = nav_id.to_lower()
	_sync_participants_to_mocks()
	_set_status("Navegante activa: %s" % selected_navigator_id)


func set_selected_portrait(portrait_name: String) -> void:
	selected_portrait_name = portrait_name
	_update_portrait_info_label()


func get_pilot_dch_portraits(pilot_id: String) -> Dictionary:
	var dch_path: String = "res://narrative/characters/%s.dch" % pilot_id.to_lower()
	if not FileAccess.file_exists(dch_path):
		return {}
	if ResourceLoader.exists(dch_path):
		var res: Resource = ResourceLoader.load(dch_path)
		if res != null and "portraits" in res and res.get("portraits") is Dictionary:
			return (res.get("portraits") as Dictionary).duplicate(true)

	# Fallback textual para sintaxis Dialogic (.dch) en caso de entorno sin importador registrado
	var raw_text: String = FileAccess.get_file_as_string(dch_path)
	var portraits: Dictionary = {}
	var start_idx: int = raw_text.find("portraits")
	if start_idx == -1:
		return portraits
	var section_text: String = raw_text.substr(start_idx)
	var rx := RegEx.new()
	rx.compile("\"([^\"]+)\"\\s*:\\s*\\{[^\\}]*?\"image\"\\s*:\\s*\"\\\\\"([^\"]+)\\\\\"\"[^\\}]*?\"mirror\"\\s*:\\s*(true|false)")
	for m: RegExMatch in rx.search_all(section_text):
		var pname: String = m.get_string(1)
		var img_path: String = m.get_string(2)
		var is_mirror: bool = m.get_string(3) == "true"
		portraits[pname] = {
			"export_overrides": {"image": img_path},
			"mirror": is_mirror,
		}
	return portraits


func _refresh_portrait_inspector() -> void:
	_cached_portraits = get_pilot_dch_portraits(selected_pilot_id)
	var opt: OptionButton = _panel_refs.get("portrait_option") as OptionButton
	if is_instance_valid(opt):
		opt.clear()
		if _cached_portraits.is_empty():
			opt.add_item("Normal")
			selected_portrait_name = "Normal"
		else:
			for key_v: Variant in _cached_portraits.keys():
				opt.add_item(str(key_v))
			selected_portrait_name = opt.get_item_text(0)
	_update_portrait_info_label()


func _update_portrait_info_label() -> void:
	var lbl: Label = _panel_refs.get("portrait_info") as Label
	if not is_instance_valid(lbl):
		return
	var entry_v: Variant = _cached_portraits.get(selected_portrait_name, null)
	if entry_v is Dictionary:
		var entry: Dictionary = entry_v as Dictionary
		var overrides_v: Variant = entry.get("export_overrides", {})
		var img_path: String = "-"
		if overrides_v is Dictionary:
			img_path = str((overrides_v as Dictionary).get("image", "-")).replace("\"", "")
		var is_mirrored: bool = bool(entry.get("mirror", false))
		lbl.text = "Retrato: %s (mirror=%s)\n%s" % [selected_portrait_name, str(is_mirrored), img_path]
	else:
		lbl.text = "Retrato: %s (sin entrada en .dch)" % selected_portrait_name


func preview_selected_portrait(side: String = "left") -> void:
	preview_portrait(selected_portrait_name, side)


func preview_portrait(portrait_name: String, side: String = "left") -> void:
	stop_active_dialogue()
	_sync_participants_to_mocks()
	var dialogic_node: Node = narrative_director.get_dialogic() if narrative_director != null else null
	if dialogic_node == null or not dialogic_node.has_method("start"):
		_set_status("Dialogic no disponible en runtime")
		return

	var pname: String = portrait_name if not portrait_name.is_empty() else "Normal"
	var text: String = ""
	if side == "right":
		text += "join %s (%s) right\n" % [selected_pilot_id, pname]
		text += "%s: Inspección visual de retrato '%s' en lado derecho.\n" % [selected_pilot_id, pname]
	elif side == "both":
		text += "join %s (%s) left\n" % [selected_pilot_id, pname]
		text += "join %s (Flipped) right\n" % selected_rival_id
		text += "%s: Comparativa frente a frente (%s) contra %s.\n" % [selected_pilot_id, pname, selected_rival_id.capitalize()]
		text += "%s: Encuadre y escala verificados en canal táctico.\n" % selected_rival_id
	else:
		text += "join %s (%s) left\n" % [selected_pilot_id, pname]
		text += "%s: Inspección visual de retrato '%s' en lado izquierdo.\n" % [selected_pilot_id, pname]
	text += "leave --All--\n"

	var tl := DialogicTimeline.new()
	tl.from_text(text)
	var layout: Node = dialogic_node.start(tl)
	if layout != null:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
		if layout is CanvasLayer:
			(layout as CanvasLayer).layer = 50
		if "canvas_layer" in layout:
			layout.canvas_layer = 50
	_set_status("Preview retrato %s (%s)" % [pname, side])


func trigger_scenario(scenario_id: String) -> void:
	stop_active_dialogue()
	_sync_participants_to_mocks()
	if not is_instance_valid(narrative_director):
		return

	match scenario_id:
		"prologue":
			narrative_director.prologue_bonus_chosen = false
			narrative_director.start_prologue_briefing()
		"rival_jump":
			narrative_director.trigger_pet_rival_jump_warning(_mock_rival)
		"rival_face":
			narrative_director.trigger_rival_face_to_face_dialogue(_mock_rival)
		"boss_alert":
			narrative_director.trigger_pet_boss_alert("ASTRA PRIME (MOCK)")
		"climax_pacifist":
			narrative_director.trigger_climax_dialogue("pacifist")
		"climax_slayer":
			narrative_director.trigger_climax_dialogue("slayer")
		"victory_pacifist":
			narrative_director.trigger_post_boss_victory_dialogue("pacifist", {"route": "pacifist", "score": 12000})
		"navigator_radio":
			if is_instance_valid(navigator_controller):
				navigator_controller.play_tutorial_callout()
		_:
			_set_status("Escenario desconocido: %s" % scenario_id)
			return
	_set_status("Escenario lanzado: %s" % scenario_id)


func stop_active_dialogue() -> void:
	if is_instance_valid(narrative_director) and narrative_director.is_dialogue_active():
		narrative_director.skip_dialogue()
	else:
		var dialogic_node: Node = get_node_or_null("/root/Dialogic")
		if dialogic_node != null and "current_timeline" in dialogic_node and dialogic_node.current_timeline != null:
			if dialogic_node.has_method("end_timeline"):
				dialogic_node.end_timeline(true)
	PauseArbitrator.release_pause(&"dialogue")
	PauseArbitrator.release_pause(&"briefing")
	if is_instance_valid(backdrop_layer):
		backdrop_layer.hold_dimmer = false
		backdrop_layer.fade_out(0.01)
	if is_instance_valid(skip_badge_layer):
		skip_badge_layer.hide()
	_set_status("Diálogo detenido y pausas liberadas")


func toggle_guides() -> void:
	if alignment_overlay != null:
		alignment_overlay.show_guides = not alignment_overlay.show_guides
		_set_status("Guías: %s" % ("ON" if alignment_overlay.show_guides else "OFF"))


func toggle_cosmos_background() -> void:
	if is_instance_valid(_cosmos_env):
		_cosmos_env.queue_free()
		_cosmos_env = null
		_set_status("Fondo: Oscuro plano")
		return
	if CosmosEnvScene != null:
		_cosmos_env = CosmosEnvScene.instantiate() as CosmosCombatEnvironment
		_cosmos_env.name = "CosmosPreview"
		add_child(_cosmos_env)
		_cosmos_env.set_camera_reference(_camera)
		_set_status("Fondo: Cosmos Engine activo")


func return_to_hub() -> void:
	stop_active_dialogue()
	get_tree().change_scene_to_file(WORKBENCH_HUB_PATH)


func _set_status(msg: String) -> void:
	var lbl: Label = _panel_refs.get("status_label") as Label
	if is_instance_valid(lbl):
		lbl.text = msg
