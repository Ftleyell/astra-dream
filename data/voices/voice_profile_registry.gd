class_name VoiceProfileRegistry
extends RefCounted

## Registro estático de perfiles de voz data-driven (`VoiceProfileData`).
## Resuelve `speaker_id -> res://data/voices/profiles/<id>.tres` con caché y fallback seguro.

const VoiceProfileDataScript = preload("res://data/voices/voice_profile_data.gd")

const PROFILES_DIR: String = "res://data/voices/profiles/"
const DEFAULT_PROFILE_PATH: String = "res://data/voices/profiles/default.tres"

static var _cache: Dictionary = {} # StringName -> VoiceProfileData


static func get_profile(speaker_id: StringName) -> VoiceProfileDataScript:
	var normalized: String = String(speaker_id).strip_edges().to_lower()
	var key: StringName = StringName(normalized) if not normalized.is_empty() else &"default"

	if _cache.has(key):
		var cached: Variant = _cache[key]
		if cached is VoiceProfileDataScript:
			return cached as VoiceProfileDataScript

	var path: String = "%s%s.tres" % [PROFILES_DIR, String(key)]
	if ResourceLoader.exists(path):
		var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if loaded is VoiceProfileDataScript:
			_cache[key] = loaded
			return loaded as VoiceProfileDataScript

	var fallback: VoiceProfileDataScript = _get_default_profile()
	_cache[key] = fallback
	return fallback


static func _get_default_profile() -> VoiceProfileDataScript:
	if _cache.has(&"default"):
		var cached_def: Variant = _cache[&"default"]
		if cached_def is VoiceProfileDataScript:
			return cached_def as VoiceProfileDataScript

	if ResourceLoader.exists(DEFAULT_PROFILE_PATH):
		var loaded_def: Resource = ResourceLoader.load(DEFAULT_PROFILE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
		if loaded_def is VoiceProfileDataScript:
			_cache[&"default"] = loaded_def
			return loaded_def as VoiceProfileDataScript

	var synthetic_def: VoiceProfileDataScript = VoiceProfileDataScript.new()
	synthetic_def.profile_id = &"default"
	synthetic_def.display_name = "Default"
	_cache[&"default"] = synthetic_def
	return synthetic_def


static func reload_all() -> void:
	_cache.clear()


static func get_all_profile_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	var dir: DirAccess = DirAccess.open(PROFILES_DIR)
	if dir == null:
		return ids
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while not fname.is_empty():
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			ids.append(StringName(fname.get_basename().to_lower()))
		fname = dir.get_next()
	dir.list_dir_end()
	ids.sort()
	return ids
