class_name DialogicLivingPortraitBridge
extends Node
## Puente modular y multi-piloto que conecta retratos Dialogic 2 in-game con
## PilotDialoguePortraitController (Living 2.5D) sin acoplar lógica al backdrop.

const PortraitCtrlScript = preload("res://scenes/pilots/dialogue/pilot_dialogue_portrait_controller.gd")
const ConfigScript = preload("res://data/pilots/schemas/pilot_dialogue_portrait_config.gd")
const CosmeticsManagerScript = preload("res://core/systems/cosmetics_manager.gd")

const ROSTER_PATH_FMT: String = "res://data/characters/roster/%s.tres"
const LIVING_CTRL_NAME: String = "LivingDialoguePortraitController"

var _config_cache: Dictionary = {}
var _last_portrait_names: Dictionary = {}
var _active_entries: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var stale_keys: Array[String] = []
	for key: Variant in _active_entries.keys():
		var char_id: String = str(key)
		var entry: Dictionary = _active_entries[key] as Dictionary
		var raw_ctrl: Variant = entry.get("ctrl", null)
		var raw_sprite: Variant = entry.get("sprite", null)
		var raw_parent: Variant = entry.get("parent", null)
		var raw_char: Variant = entry.get("char_node", null)
		if not is_instance_valid(raw_ctrl) or not is_instance_valid(raw_sprite) or not is_instance_valid(raw_parent) or not is_instance_valid(raw_char):
			stale_keys.append(char_id)
			continue
		var ctrl := raw_ctrl as PortraitCtrlScript
		var sprite := raw_sprite as Sprite2D
		var parent_node := raw_parent as Node
		var char_node := raw_char as Node
		if ctrl == null or sprite == null or parent_node == null or char_node == null:
			stale_keys.append(char_id)
			continue
		sprite.self_modulate.a = 0.0
		_sync_controller_transform(ctrl, sprite, parent_node, char_node)
	for sk: String in stale_keys:
		_active_entries.erase(sk)


func resolve_config(char_id: String) -> ConfigScript:
	var id: String = char_id.strip_edges().to_lower()
	if id.is_empty():
		return null
	if _config_cache.has(id):
		return _config_cache[id] as ConfigScript

	var cfg: ConfigScript = null
	var roster_path: String = ROSTER_PATH_FMT % id
	if ResourceLoader.exists(roster_path):
		var cd: CharacterData = ResourceLoader.load(roster_path) as CharacterData
		if cd != null and cd.pilot_rig_profile != null:
			var raw_cfg: Resource = cd.pilot_rig_profile.dialogue_portraits_config
			if raw_cfg is ConfigScript:
				cfg = raw_cfg as ConfigScript
				cfg.ensure_defaults()
	_config_cache[id] = cfg
	return cfg


func has_living_portrait(char_id: String) -> bool:
	return resolve_config(char_id) != null


func on_portrait_event(info: Dictionary) -> void:
	var char_id: String = _extract_char_id(info.get("character", null))
	if char_id.is_empty():
		return
	var portrait_name: String = str(info.get("portrait", "")).strip_edges().to_lower()
	_last_portrait_names[char_id] = portrait_name


func sync_character_portrait(
	char_id: String,
	character_node: Node,
	sprite: Sprite2D,
	is_current_speaker: bool,
	is_typing: bool = true
) -> PortraitCtrlScript:
	var id: String = char_id.strip_edges().to_lower()
	var cfg: ConfigScript = resolve_config(id)
	if cfg == null or not is_instance_valid(character_node) or not is_instance_valid(sprite) or sprite.texture == null:
		return null

	var parent_node: Node = sprite.get_parent()
	if not is_instance_valid(parent_node):
		return null

	sprite.visible = true
	sprite.self_modulate.a = 0.0

	var ctrl: PortraitCtrlScript = parent_node.get_node_or_null(LIVING_CTRL_NAME) as PortraitCtrlScript
	var is_new: bool = false
	if not is_instance_valid(ctrl):
		ctrl = PortraitCtrlScript.new()
		ctrl.name = LIVING_CTRL_NAME
		ctrl.process_mode = Node.PROCESS_MODE_ALWAYS
		ctrl.set_config(cfg)
		parent_node.add_child(ctrl)
		is_new = true
		_apply_equipped_skin(id, ctrl)

	var emotion_id: StringName = _resolve_emotion_id(id, sprite, cfg)
	ctrl.set_emotion(emotion_id, is_new)
	ctrl.set_focused(is_current_speaker, is_new)
	ctrl.set_speaking(is_current_speaker and is_typing)

	var prev_entry: Dictionary = _active_entries.get(id, {}) as Dictionary
	var raw_prev: Variant = prev_entry.get("ctrl", null)
	if is_instance_valid(raw_prev) and raw_prev != ctrl:
		var prev_node := raw_prev as Node
		if prev_node != null:
			prev_node.queue_free()

	_active_entries[id] = {
		"ctrl": ctrl,
		"sprite": sprite,
		"parent": parent_node,
		"char_node": character_node,
	}
	_sync_controller_transform(ctrl, sprite, parent_node, character_node)
	return ctrl


func notify_text_finished() -> void:
	var stale_keys: Array[String] = []
	for key: Variant in _active_entries.keys():
		var entry: Dictionary = _active_entries[key] as Dictionary
		var raw_ctrl: Variant = entry.get("ctrl", null)
		if is_instance_valid(raw_ctrl):
			var ctrl := raw_ctrl as PortraitCtrlScript
			if ctrl != null:
				ctrl.set_speaking(false)
		else:
			stale_keys.append(str(key))
	for sk: String in stale_keys:
		_active_entries.erase(sk)


func fade_out_all() -> void:
	var stale_keys: Array[String] = []
	for key: Variant in _active_entries.keys():
		var entry: Dictionary = _active_entries[key] as Dictionary
		var raw_ctrl: Variant = entry.get("ctrl", null)
		if is_instance_valid(raw_ctrl):
			var ctrl := raw_ctrl as PortraitCtrlScript
			if ctrl != null:
				ctrl.set_speaking(false)
				ctrl.set_focused(false)
		else:
			stale_keys.append(str(key))
	for sk: String in stale_keys:
		_active_entries.erase(sk)


func _apply_equipped_skin(char_id: String, ctrl: PortraitCtrlScript) -> void:
	if not is_instance_valid(ctrl):
		return
	var cid := StringName(char_id)
	var skin: PilotSkinPreset = CosmeticsManagerScript.resolve_pilot_skin_preset(cid, "pilot")
	var stars: int = CosmeticsManagerScript.resolve_equipped_skin_stars("pilot", cid)
	ctrl.apply_skin_preset(skin, stars)


func _resolve_emotion_id(char_id: String, sprite: Sprite2D, cfg: ConfigScript) -> StringName:
	var p_name: String = str(_last_portrait_names.get(char_id, "")).to_lower()
	var tex_name: String = ""
	if is_instance_valid(sprite) and sprite.texture != null:
		tex_name = sprite.texture.resource_path.get_file().to_lower()
	var combined: String = "%s %s" % [p_name, tex_name]

	if combined.contains("alert"):
		return &"alert"
	if combined.contains("thinking"):
		return &"thinking"
	if combined.contains("warm"):
		return &"warm"
	if combined.contains("focused"):
		return &"focused"
	return cfg.default_emotion if cfg != null else &"neutral"


func _sync_controller_transform(
	ctrl: PortraitCtrlScript,
	sprite: Sprite2D,
	parent_node: Node,
	character_node: Node
) -> void:
	if sprite.texture == null:
		return
	var sz: Vector2 = sprite.texture.get_size()
	var local_bottom: Vector2 = Vector2(0.0, sz.y * 0.5) if sprite.centered else Vector2(sz.x * 0.5, sz.y)
	ctrl.position = sprite.position + (local_bottom + sprite.offset) * sprite.scale

	if parent_node is CanvasItem:
		var g_scale: Vector2 = (parent_node as CanvasItem).get_global_transform().get_scale()
		ctrl.scale = Vector2(1.0 / maxf(absf(g_scale.x), 0.05), 1.0 / maxf(absf(g_scale.y), 0.05))
	else:
		ctrl.scale = Vector2.ONE

	var vp_half_w: float = 960.0
	var vp: Viewport = character_node.get_viewport()
	if vp != null:
		var vp_w: float = vp.get_visible_rect().size.x
		if vp_w > 10.0:
			vp_half_w = vp_w * 0.5

	var screen_x: float = vp_half_w - 100.0
	if character_node is Control:
		var c_node := character_node as Control
		screen_x = c_node.global_position.x + c_node.size.x * 0.5
	elif character_node is Node2D:
		screen_x = (character_node as Node2D).global_position.x
	ctrl.set_mirrored(screen_x > vp_half_w + 1.0)


func _extract_char_id(raw_char: Variant) -> String:
	if raw_char == null:
		return ""
	if raw_char is String or raw_char is StringName:
		return str(raw_char).strip_edges().to_lower()
	if raw_char is Object:
		var obj := raw_char as Object
		if obj.has_method("get_identifier"):
			return str(obj.call("get_identifier")).strip_edges().to_lower()
		if "display_name" in obj:
			return str(obj.get("display_name")).strip_edges().to_lower()
	return ""
