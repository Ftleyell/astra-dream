class_name HubTutorialDirector
extends Node

## Orquestador modular del tutorial/debrief guiado por la mascota sobre el Hub 3D
## usando la ventana nativa de Dialogic (con retrato grande de Mochi/mascota equipada)
## y voz vía DialogicMumbleBridge, sin oscurecer el Hub 3D.

signal tutorial_started()
signal step_changed(step_index: int, step: StepDataScript)
signal tutorial_finished(skipped: bool)

const SequenceConfigScript = preload("res://data/hub/hub_tutorial_sequence_config.gd")
const DEFAULT_SEQUENCE: SequenceConfigScript = preload("res://data/hub/default_hub_tutorial_sequence.tres")
const StepDataScript = preload("res://data/hub/hub_tutorial_step_data.gd")
const HighlightCtrlScript = preload("res://scenes/ui/hub/astral_station/components/hub_tutorial_highlight_controller.gd")
const SpotlightOverlayScript = preload("res://scenes/ui/hub/astral_station/components/hub_tutorial_spotlight_overlay.gd")
const DialogicMumbleBridgeScript = preload("res://core/audio/dialogic_mumble_bridge.gd")
const DialogueSkipScene: PackedScene = preload("res://scenes/ui/dialogue_skip_overlay.tscn")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")

const VALID_PET_DCH: Array[String] = ["mochi", "kuro", "luna", "pip", "cosmo"]
const STEP_SIGNAL_PREFIX: String = "hub_tutorial_step:"

@export var sequence_config: SequenceConfigScript = DEFAULT_SEQUENCE

var _hub: AstralStationHub = null
var _bridge: HubEmbeddedViewportBridge = null
var _camera: GameCamera2D = null

var _highlight_ctrl: HighlightCtrlScript = null
var _spotlight_overlay: SpotlightOverlayScript = null
var _mumble_bridge: DialogicMumbleBridgeScript = null
var _skip_overlay: DialogueSkipOverlay = null

var _is_active: bool = false
var _is_restarting_timeline: bool = false
var _restart_epoch: int = 0
var _current_index: int = -1
var _active_pet_id: String = "mochi"


func setup(
	p_hub: AstralStationHub,
	p_bridge: HubEmbeddedViewportBridge,
	p_camera: GameCamera2D,
	p_config: SequenceConfigScript = null
) -> void:
	_hub = p_hub
	_bridge = p_bridge
	_camera = p_camera
	if p_config != null:
		sequence_config = p_config
	elif sequence_config == null:
		sequence_config = DEFAULT_SEQUENCE
	_ensure_children()


func _ensure_children() -> void:
	if _highlight_ctrl == null:
		_highlight_ctrl = HighlightCtrlScript.new()
		_highlight_ctrl.name = "HubTutorialHighlightController"
		add_child(_highlight_ctrl)
	if _spotlight_overlay == null:
		_spotlight_overlay = SpotlightOverlayScript.new()
		_spotlight_overlay.name = "HubTutorialSpotlightOverlay"
		add_child(_spotlight_overlay)
	if _mumble_bridge == null:
		_mumble_bridge = DialogicMumbleBridgeScript.new()
		_mumble_bridge.name = "HubTutorialMumbleBridge"
		add_child(_mumble_bridge)
	if _skip_overlay == null and DialogueSkipScene != null:
		_skip_overlay = DialogueSkipScene.instantiate() as DialogueSkipOverlay
		if _skip_overlay != null:
			_skip_overlay.name = "HubTutorialSkipOverlay"
			_skip_overlay.layer = 48
			_skip_overlay.hide()
			_skip_overlay.skip_requested.connect(func() -> void:
				finish_tutorial(true)
			)
			add_child(_skip_overlay)


func _get_dialogic() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Dialogic")
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Dialogic") if tree and tree.root else null


func _resolve_pet_dch_id(pet_id: StringName) -> String:
	var candidate: String = String(pet_id).strip_edges().to_lower()
	if VALID_PET_DCH.has(candidate):
		return candidate
	var saved: String = String(SaveManagerScript.get_selected_pet()).strip_edges().to_lower()
	if VALID_PET_DCH.has(saved):
		return saved
	return "mochi"


func is_active() -> bool:
	return _is_active


func get_current_step_index() -> int:
	return _current_index


func get_step_count() -> int:
	if sequence_config == null:
		return 0
	return sequence_config.steps.size()


func get_highlight_controller() -> HighlightCtrlScript:
	return _highlight_ctrl


func set_pet_id(pet_id: StringName) -> void:
	var next_pet: String = _resolve_pet_dch_id(pet_id)
	if next_pet == _active_pet_id:
		return
	_active_pet_id = next_pet
	if _is_active:
		var resume_idx: int = maxi(_current_index, 0)
		_start_dialogic_from_step(resume_idx)


func start_tutorial(pet_id_override: StringName = &"") -> void:
	if _hub == null or _bridge == null or _camera == null:
		return
	if sequence_config == null:
		sequence_config = DEFAULT_SEQUENCE
	if sequence_config.steps.is_empty():
		return

	_ensure_children()
	_active_pet_id = _resolve_pet_dch_id(pet_id_override)
	_is_active = true
	_current_index = 0

	if _hub.hud != null:
		_hub.hud.set_clean_hud_visible(false)
	_hub.embedded_movement_lock_changed.emit(true)
	if _skip_overlay != null:
		_skip_overlay.show()

	tutorial_started.emit()
	_connect_dialogic_signals()
	_start_dialogic_from_step(0)


func go_to_step(idx: int) -> void:
	if not _is_active or sequence_config == null or sequence_config.steps.is_empty():
		return
	var total: int = sequence_config.steps.size()
	if idx < 0:
		idx = 0
	if idx >= total:
		finish_tutorial(false)
		return
	_start_dialogic_from_step(idx)


func next_step() -> void:
	if not _is_active:
		return
	if _current_index + 1 >= get_step_count():
		finish_tutorial(false)
	else:
		go_to_step(_current_index + 1)


func prev_step() -> void:
	if not _is_active:
		return
	if _current_index > 0:
		go_to_step(_current_index - 1)


func _start_dialogic_from_step(start_idx: int) -> void:
	if not _is_active or sequence_config == null or sequence_config.steps.is_empty():
		return
	var total: int = sequence_config.steps.size()
	var safe_idx: int = clampi(start_idx, 0, total - 1)
	_restart_epoch += 1
	var my_epoch: int = _restart_epoch
	_apply_step_visuals(safe_idx)

	var dialogic_node: Node = _get_dialogic()
	if dialogic_node == null or not dialogic_node.has_method("start"):
		return

	_is_restarting_timeline = true
	_disconnect_dialogic_signals()
	if "current_timeline" in dialogic_node and dialogic_node.current_timeline != null:
		if dialogic_node.has_method("end_timeline"):
			dialogic_node.end_timeline(true)
		if is_inside_tree():
			await get_tree().process_frame
		if not _is_active or my_epoch != _restart_epoch or not is_inside_tree():
			return

	var lines: PackedStringArray = PackedStringArray()
	lines.append("join %s right" % _active_pet_id)
	for i: int in range(safe_idx, total):
		var step: StepDataScript = sequence_config.steps[i]
		if step == null:
			continue
		var hex_col: String = "#" + step.highlight_color.to_html(false)
		var clean_text: String = step.dialogue_text.replace("\n", " ").strip_edges()
		lines.append("[signal arg=\"%s%d\"]" % [STEP_SIGNAL_PREFIX, i])
		lines.append("%s: [color=%s][b]%s (%d/%d)[/b][/color] — %s" % [
			_active_pet_id,
			hex_col,
			step.station_badge,
			i + 1,
			total,
			clean_text
		])
	lines.append("leave --All--")

	var tl := DialogicTimeline.new()
	tl.from_text("\n".join(lines))
	var layout: Node = dialogic_node.start(tl)
	if layout != null:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
		if layout is CanvasLayer:
			(layout as CanvasLayer).layer = 42
		if "canvas_layer" in layout:
			layout.set("canvas_layer", 42)
	if _mumble_bridge != null:
		_mumble_bridge.attach_to_layout(layout, dialogic_node, false)
	_connect_dialogic_signals()
	_is_restarting_timeline = false


func _apply_step_visuals(idx: int) -> void:
	if sequence_config == null or idx < 0 or idx >= sequence_config.steps.size():
		return
	_current_index = idx
	var step: StepDataScript = sequence_config.steps[idx]
	if step == null:
		return

	var bundle: Dictionary = _hub.get_station_materials_for_tutorial(step.target_id)
	var world_3d: Vector3 = bundle.get("world_pos_3d", Vector3.ZERO) as Vector3
	var pos_2d: Vector2 = _bridge.hub_3d_to_world_2d(world_3d)
	var zoom_v: float = maxf(step.camera_zoom, 0.5)
	var cam_off: Vector2 = step.focus_offset_2d + sequence_config.dialogic_portrait_camera_offset_px
	var focus_2d: Vector2 = pos_2d + (cam_off / zoom_v)
	_camera.set_cinematic_focus(focus_2d, step.camera_zoom)

	if step.target_id == &"overview":
		_highlight_ctrl.clear_highlight()
	else:
		_highlight_ctrl.activate_target(bundle, step.highlight_color, step.pulse_speed_hz, step.pulse_intensity)

	refresh_spotlight_style()
	if _spotlight_overlay != null:
		var lift_y: float = sequence_config.spotlight_focus_lift_y_px
		_spotlight_overlay.set_target(pos_2d + Vector2(0.0, lift_y), step.spotlight_enabled, step.spotlight_radius)

	step_changed.emit(idx, step)


func get_spotlight_overlay() -> SpotlightOverlayScript:
	return _spotlight_overlay


func refresh_spotlight_style() -> void:
	if _spotlight_overlay == null or sequence_config == null:
		return
	_spotlight_overlay.configure_style(
		sequence_config.spotlight_blur_strength,
		sequence_config.spotlight_dim_strength,
		sequence_config.spotlight_softness,
		sequence_config.spotlight_dim_color
	)


func _connect_dialogic_signals() -> void:
	var dialogic_node: Node = _get_dialogic()
	if dialogic_node == null:
		return
	if dialogic_node.has_signal("signal_event") and not dialogic_node.signal_event.is_connected(_on_dialogic_signal):
		dialogic_node.signal_event.connect(_on_dialogic_signal)
	if dialogic_node.has_signal("timeline_ended") and not dialogic_node.timeline_ended.is_connected(_on_dialogic_timeline_ended):
		dialogic_node.timeline_ended.connect(_on_dialogic_timeline_ended)


func _disconnect_dialogic_signals() -> void:
	var dialogic_node: Node = _get_dialogic()
	if dialogic_node == null:
		return
	if dialogic_node.has_signal("signal_event") and dialogic_node.signal_event.is_connected(_on_dialogic_signal):
		dialogic_node.signal_event.disconnect(_on_dialogic_signal)
	if dialogic_node.has_signal("timeline_ended") and dialogic_node.timeline_ended.is_connected(_on_dialogic_timeline_ended):
		dialogic_node.timeline_ended.disconnect(_on_dialogic_timeline_ended)


func _on_dialogic_signal(arg: Variant) -> void:
	if not _is_active or _is_restarting_timeline:
		return
	var s_arg: String = str(arg)
	if not s_arg.begins_with(STEP_SIGNAL_PREFIX):
		return
	var idx_str: String = s_arg.substr(STEP_SIGNAL_PREFIX.length())
	if idx_str.is_valid_int():
		var idx: int = int(idx_str)
		if idx != _current_index:
			_apply_step_visuals(idx)


func _on_dialogic_timeline_ended() -> void:
	if not _is_active or _is_restarting_timeline:
		return
	finish_tutorial(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return
	var key_ev := event as InputEventKey
	if key_ev != null and key_ev.pressed and not key_ev.echo and key_ev.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		finish_tutorial(true)


func finish_tutorial(skipped: bool = false) -> void:
	if not _is_active:
		return
	_is_active = false
	_is_restarting_timeline = false
	_current_index = -1

	_disconnect_dialogic_signals()
	if is_instance_valid(_mumble_bridge):
		_mumble_bridge.stop()
	if is_instance_valid(_skip_overlay):
		_skip_overlay.hide()

	var dialogic_node: Node = _get_dialogic()
	if dialogic_node != null and "current_timeline" in dialogic_node and dialogic_node.current_timeline != null:
		if dialogic_node.has_method("end_timeline"):
			dialogic_node.end_timeline(true)

	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null:
		var focused_ctrl: Control = tree.root.gui_get_focus_owner()
		if focused_ctrl != null:
			focused_ctrl.release_focus()

	if _highlight_ctrl != null:
		_highlight_ctrl.clear_highlight()
	if _spotlight_overlay != null:
		_spotlight_overlay.deactivate(false)
	if _camera != null and is_instance_valid(_camera):
		_camera.clear_cinematic_focus()
		_camera.target_zoom = 1.0
	if _hub != null and is_instance_valid(_hub):
		if _hub.hud != null:
			_hub.hud.set_clean_hud_visible(true)
		_hub.embedded_movement_lock_changed.emit(false)

	tutorial_finished.emit(skipped)


func _exit_tree() -> void:
	_disconnect_dialogic_signals()
	if _is_active:
		finish_tutorial(true)
	elif _highlight_ctrl != null:
		_highlight_ctrl.clear_highlight()
	if _spotlight_overlay != null:
		_spotlight_overlay.deactivate(true)
