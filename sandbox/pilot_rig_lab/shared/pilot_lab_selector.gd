class_name PilotLabSelector
extends RefCounted
## Selector y resolvedor multi-piloto compartido por WorkbenchHub y los 10 Pilot Rig Labs.
## Garantiza retrocompatibilidad 100%: si no hay piloto activo o falta un .tres hermano,
## cae limpiamente al perfil y config de valentina_v2.

const PILOTS_ROOT_DIR: String = "res://data/pilots"
const DEFAULT_PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const META_KEY: StringName = &"astra_active_pilot_profile_path"


static func scan_profile_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var root_dir := DirAccess.open(PILOTS_ROOT_DIR)
	if root_dir == null:
		return entries

	root_dir.list_dir_begin()
	var sub: String = root_dir.get_next()
	while not sub.is_empty():
		if root_dir.current_is_dir() and not sub.begins_with("."):
			var dir_path: String = PILOTS_ROOT_DIR.path_join(sub)
			var sub_dir := DirAccess.open(dir_path)
			if sub_dir != null:
				sub_dir.list_dir_begin()
				var fname: String = sub_dir.get_next()
				while not fname.is_empty():
					if not sub_dir.current_is_dir() and fname.ends_with(".tres"):
						var full_path: String = dir_path.path_join(fname)
						var res: Resource = ResourceLoader.load(full_path)
						if res is PilotRigProfile:
							var prof: PilotRigProfile = res as PilotRigProfile
							entries.append({
								"pilot_id": prof.pilot_id if not prof.pilot_id.is_empty() else sub,
								"display_name": prof.display_name if not prof.display_name.is_empty() else sub,
								"profile_path": full_path,
								"dir_path": dir_path,
							})
					fname = sub_dir.get_next()
				sub_dir.list_dir_end()
		sub = root_dir.get_next()
	root_dir.list_dir_end()

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var aid: String = str(a.get("pilot_id", ""))
		var bid: String = str(b.get("pilot_id", ""))
		if aid == "valentina_v2" and bid != "valentina_v2":
			return true
		if bid == "valentina_v2" and aid != "valentina_v2":
			return false
		return aid < bid
	)
	return entries


static func set_selected_profile_path(profile_path: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var cleaned: String = profile_path.strip_edges()
	if cleaned.is_empty():
		if tree.root.has_meta(META_KEY):
			tree.root.remove_meta(META_KEY)
	else:
		tree.root.set_meta(META_KEY, cleaned)


static func get_selected_profile_path(fallback: String = DEFAULT_PROFILE_PATH) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null and tree.root.has_meta(META_KEY):
		var meta_val: String = str(tree.root.get_meta(META_KEY, "")).strip_edges()
		if not meta_val.is_empty() and ResourceLoader.exists(meta_val):
			return meta_val
	return fallback


static func resolve_profile_path(override_path: String = "", fallback: String = DEFAULT_PROFILE_PATH) -> String:
	var cleaned_override: String = override_path.strip_edges()
	if not cleaned_override.is_empty() and ResourceLoader.exists(cleaned_override):
		return cleaned_override
	return get_selected_profile_path(fallback)


static func resolve_sibling_config_path(profile_path: String, suffix: String, fallback_path: String) -> String:
	var p_path: String = profile_path.strip_edges()
	if p_path.is_empty():
		return fallback_path
	var dir_path: String = p_path.get_base_dir()
	var file_name: String = p_path.get_file()
	var base_id: String = file_name.trim_suffix("_profile.tres")
	if base_id == file_name:
		base_id = dir_path.get_file()
	var clean_suffix: String = suffix.trim_prefix("_").trim_suffix(".tres")
	var candidate: String = dir_path.path_join("%s_%s.tres" % [base_id, clean_suffix])
	if ResourceLoader.exists(candidate):
		return candidate
	return fallback_path


static func resolve_active_paths(
	override_path: String = "",
	default_profile: String = DEFAULT_PROFILE_PATH,
	config_suffixes: Dictionary = {}
) -> Dictionary:
	var active_profile: String = resolve_profile_path(override_path, default_profile)
	var resolved_configs: Dictionary = {}
	for key_v: Variant in config_suffixes.keys():
		var key_str: String = str(key_v)
		var spec_v: Variant = config_suffixes[key_v]
		if spec_v is Dictionary:
			var spec: Dictionary = spec_v as Dictionary
			var suffix: String = str(spec.get("suffix", key_str))
			var fallback: String = str(spec.get("fallback", ""))
			resolved_configs[key_str] = resolve_sibling_config_path(active_profile, suffix, fallback)
		else:
			resolved_configs[key_str] = resolve_sibling_config_path(active_profile, key_str, str(spec_v))
	return {
		"profile_path": active_profile,
		"configs": resolved_configs,
	}
