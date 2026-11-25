class_name DialogicMumbleBridge
extends Node

## Puente desacoplado entre Dialogic y MumbleSpeechController.
## Silencia DialogicNode_TypeSounds heredado, detecta al hablante activo
## mediante `about_to_show_text` y sincroniza los blips con `visible_characters`.

signal speaker_voice_changed(speaker_id: StringName, profile: Resource)
signal blip_played(pitch_scale: float, volume_db: float, is_radio: bool)

const MumbleSpeechControllerScript = preload("res://core/audio/mumble_speech_controller.gd")
const VoiceProfileRegistryScript = preload("res://data/voices/voice_profile_registry.gd")
const VoiceProfileDataScript = preload("res://data/voices/voice_profile_data.gd")

const INSTANT_SKIP_CHAR_THRESHOLD: int = 12

var _controller: MumbleSpeechControllerScript = null
var _dialog_text: RichTextLabel = null
var _connected_text_subsystem: Object = null
var _last_visible_chars: int = 0
var _current_speaker_id: StringName = &"default"
var _current_profile: VoiceProfileDataScript = null
var _preview_token: int = 0


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_controller()


func _ensure_controller() -> void:
	if is_instance_valid(_controller):
		return
	_controller = MumbleSpeechControllerScript.new()
	_controller.name = "MumbleSpeechController"
	add_child(_controller)
	_controller.blip_played.connect(func(p: float, v: float, r: bool) -> void:
		blip_played.emit(p, v, r)
	)
	if _current_profile == null:
		_apply_speaker_profile(&"default")


func attach_to_layout(layout: Node, dialogic_node: Node, p_force_radio: bool = false) -> void:
	_ensure_controller()
	_controller.force_radio = p_force_radio
	_last_visible_chars = 0

	if is_instance_valid(layout):
		_disable_legacy_type_sounds(layout)
		_dialog_text = _find_dialog_text_node(layout)
		if is_instance_valid(_dialog_text):
			var parsed: String = _dialog_text.get_parsed_text()
			if not parsed.is_empty():
				_controller.begin_utterance(parsed)
	else:
		_dialog_text = null

	if is_instance_valid(dialogic_node) and dialogic_node.has_method("get_subsystem"):
		var text_sub: Variant = dialogic_node.get_subsystem("Text")
		if text_sub is Object and text_sub.has_signal("about_to_show_text"):
			var sub_obj: Object = text_sub as Object
			if _connected_text_subsystem != sub_obj:
				if is_instance_valid(_connected_text_subsystem) and _connected_text_subsystem.has_signal("about_to_show_text"):
					if _connected_text_subsystem.is_connected("about_to_show_text", _on_about_to_show_text):
						_connected_text_subsystem.disconnect("about_to_show_text", _on_about_to_show_text)
				if not sub_obj.is_connected("about_to_show_text", _on_about_to_show_text):
					sub_obj.connect("about_to_show_text", _on_about_to_show_text)
				_connected_text_subsystem = sub_obj


func _disable_legacy_type_sounds(layout: Node) -> void:
	var ts: Node = layout.find_child("DialogicNode_TypeSounds", true, false)
	if ts == null:
		return
	if "enabled" in ts:
		ts.set("enabled", false)
	if "sounds" in ts:
		ts.set("sounds", [])


func _find_dialog_text_node(layout: Node) -> RichTextLabel:
	var dt: Node = layout.find_child("DialogicNode_DialogText", true, false)
	if dt is RichTextLabel:
		return dt as RichTextLabel
	return null


func _on_about_to_show_text(info: Dictionary) -> void:
	var speaker_id: StringName = _extract_speaker_id(info.get("character"))
	_apply_speaker_profile(speaker_id)

	var raw_text: String = str(info.get("text", ""))
	_last_visible_chars = 0
	if is_instance_valid(_controller):
		_controller.begin_utterance(_strip_bbcode_fast(raw_text))


func _extract_speaker_id(character_obj: Variant) -> StringName:
	if character_obj is Resource:
		var res: Resource = character_obj as Resource
		var rpath: String = res.resource_path
		if not rpath.is_empty():
			var base: String = rpath.get_file().get_basename().strip_edges().to_lower()
			if not base.is_empty():
				return StringName(base)
	if character_obj is Object:
		var obj: Object = character_obj as Object
		var dname: Variant = obj.get("display_name")
		if dname is String and not String(dname).strip_edges().is_empty():
			return StringName(String(dname).strip_edges().to_lower())
	return &"default"


func _apply_speaker_profile(speaker_id: StringName) -> void:
	_ensure_controller()
	var profile: VoiceProfileDataScript = VoiceProfileRegistryScript.get_profile(speaker_id)
	_current_speaker_id = speaker_id
	_current_profile = profile
	_controller.set_profile(profile)
	speaker_voice_changed.emit(speaker_id, profile)


func _process(_delta: float) -> void:
	if not is_instance_valid(_controller) or not _controller.enabled:
		return
	if not is_instance_valid(_dialog_text) or not _dialog_text.is_inside_tree():
		return

	var vis: int = _dialog_text.visible_characters
	if vis < 0:
		# -1 en RichTextLabel significa texto completo visible sin typewriter
		var full_len: int = _dialog_text.get_parsed_text().length()
		_last_visible_chars = full_len
		return

	if vis < _last_visible_chars:
		_last_visible_chars = 0
		var parsed_reset: String = _dialog_text.get_parsed_text()
		if not parsed_reset.is_empty():
			_controller.begin_utterance(parsed_reset)

	if vis <= _last_visible_chars:
		return

	var delta_chars: int = vis - _last_visible_chars
	if delta_chars > INSTANT_SKIP_CHAR_THRESHOLD:
		_last_visible_chars = vis
		return

	var parsed_text: String = _dialog_text.get_parsed_text()
	var total_len: int = parsed_text.length()
	for i: int in range(_last_visible_chars, mini(vis, total_len)):
		var ch: String = parsed_text.substr(i, 1)
		_controller.on_character_revealed(ch, i)

	_last_visible_chars = vis


func _strip_bbcode_fast(text: String) -> String:
	var rx := RegEx.new()
	rx.compile("\\[[^\\]]+\\]")
	return rx.sub(text, "", true)


func set_enabled(val: bool) -> void:
	_ensure_controller()
	_controller.enabled = val
	if not val:
		_controller.stop()


func is_enabled() -> bool:
	_ensure_controller()
	return _controller.enabled


func stop() -> void:
	_preview_token += 1
	if is_instance_valid(_controller):
		_controller.stop()


func get_current_speaker_id() -> StringName:
	return _current_speaker_id


func get_current_profile() -> VoiceProfileDataScript:
	return _current_profile


func reload_profiles() -> void:
	VoiceProfileRegistryScript.reload_all()
	_apply_speaker_profile(_current_speaker_id)


func preview_voice(speaker_id: StringName, sample_text: String = "Transmisión de prueba en canal táctico.") -> void:
	_apply_speaker_profile(speaker_id)
	_controller.begin_utterance(sample_text)
	_preview_token += 1
	var my_token: int = _preview_token
	if not is_inside_tree():
		_controller.on_character_revealed(sample_text.substr(0, 1), 0, 0)
		return
	_run_preview_burst(my_token, sample_text)


func _run_preview_burst(token: int, sample_text: String) -> void:
	var burst_chars: int = mini(sample_text.length(), 10)
	for i: int in range(burst_chars):
		if token != _preview_token or not is_inside_tree() or not is_instance_valid(_controller):
			return
		_controller.on_character_revealed(sample_text.substr(i, 1), i)
		await get_tree().create_timer(0.055, true, false, true).timeout
