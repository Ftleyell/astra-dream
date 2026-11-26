class_name SfxCueBank
extends Resource
## Banco maestro Data-Driven de cues SFX, aliases retrocompatibles y pistas de Ambience.

const SfxCueDataScript = preload("res://core/audio/sfx_cue_data.gd")
const DEFAULT_BANK_PATH: String = "res://data/audio/default_sfx_cue_bank.tres"
const SFX_DIR: String = "res://assets/audio/sfx"
const AMBIENCE_DIR: String = "res://assets/audio/ambience"

@export var cues: Array[SfxCueDataScript] = []
@export var aliases: Dictionary = {}
@export var ambience_tracks: Dictionary = {}


func build_lookup() -> Dictionary:
	var lookup: Dictionary = {}
	for cue: SfxCueDataScript in cues:
		if cue != null and cue.cue_id != &"":
			lookup[String(cue.cue_id)] = cue
	return lookup


func resolve_key(raw_key: String) -> String:
	var clean: String = raw_key.strip_edges()
	if aliases.has(clean):
		return str(aliases[clean])
	return clean


static func create_default_bank() -> Resource:
	var bank: Resource = load("res://core/audio/sfx_cue_bank.gd").new()
	bank.aliases = {
		"exp_pickup": "exp",
		"laser_fire": "laser",
		"bomb_explode": "bomb",
	}
	bank.ambience_tracks = {
		"cosmos": _resolve_ambience_path("ambience_cosmos"),
		"hub": _resolve_ambience_path("ambience_hub"),
		"title": _resolve_ambience_path("ambience_cosmos"),
	}

	var specs: Array[Dictionary] = _get_default_cue_specs()
	for spec: Dictionary in specs:
		var cue := SfxCueDataScript.new()
		var cue_id: String = str(spec["id"])
		var file_base: String = str(spec["file_base"])
		var fallback_file: String = str(spec.get("fallback_file", ""))

		cue.cue_id = StringName(cue_id)
		cue.bus_name = StringName(str(spec.get("bus", "SFX_Combat")))
		cue.priority = int(spec.get("priority", SfxCueDataScript.Priority.FEEDBACK)) as SfxCueDataScript.Priority
		cue.base_volume_db = float(spec.get("base_volume_db", 0.0))
		cue.pitch_min = float(spec.get("pitch_min", 0.94))
		cue.pitch_max = float(spec.get("pitch_max", 1.06))
		cue.vol_jitter_db = float(spec.get("vol_jitter_db", 1.0))
		cue.min_interval_ms = int(spec.get("min_interval_ms", 35))
		cue.max_polyphony = int(spec.get("max_polyphony", 4))
		cue.density_attenuation_db = float(spec.get("density_attenuation_db", 0.0))
		cue.duck_combat_db = float(spec.get("duck_combat_db", 0.0))
		cue.duck_duration_sec = float(spec.get("duck_duration_sec", 0.25))
		cue.allow_panning = bool(spec.get("allow_panning", false))
		cue.panning_strength = float(spec.get("panning_strength", 0.35))
		cue.use_exp_combo = bool(spec.get("use_exp_combo", false))
		cue.secondary_layer_delay_sec = float(spec.get("layer2_delay", 0.0))
		cue.secondary_layer_volume_db = float(spec.get("layer2_vol_db", -3.0))
		cue.secondary_layer_bus = StringName(str(spec.get("layer2_bus", "SFX_Heroic")))

		cue.streams = _discover_stream_variants(file_base, fallback_file)
		cue.secondary_layer_streams = _discover_layer2_streams(file_base)
		bank.cues.append(cue)

	return bank


static func rebuild_and_save_default_bank() -> Error:
	var dir_abs: String = ProjectSettings.globalize_path(DEFAULT_BANK_PATH.get_base_dir())
	DirAccess.make_dir_recursive_absolute(dir_abs)
	var bank: Resource = create_default_bank()
	return ResourceSaver.save(bank, DEFAULT_BANK_PATH)


static func _resolve_ambience_path(base_name: String) -> String:
	for ext: String in ["ogg", "wav"]:
		var p: String = "%s/%s.%s" % [AMBIENCE_DIR, base_name, ext]
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			return p
	return "%s/%s.ogg" % [AMBIENCE_DIR, base_name]


static func _discover_stream_variants(file_base: String, fallback_file: String) -> Array[AudioStream]:
	var list: Array[AudioStream] = []
	var primary_path: String = "%s/%s.wav" % [SFX_DIR, file_base]
	var primary_stream: AudioStream = _load_audio_if_exists(primary_path)
	if primary_stream != null:
		list.append(primary_stream)
	for v: int in range(2, 6):
		var v_path: String = "%s/%s_v%d.wav" % [SFX_DIR, file_base, v]
		var v_stream: AudioStream = _load_audio_if_exists(v_path)
		if v_stream != null:
			list.append(v_stream)

	if list.is_empty() and not fallback_file.is_empty():
		var fb_path: String = "%s/%s" % [SFX_DIR, fallback_file]
		var fb_stream: AudioStream = _load_audio_if_exists(fb_path)
		if fb_stream != null:
			list.append(fb_stream)
	return list


static func _discover_layer2_streams(file_base: String) -> Array[AudioStream]:
	var list: Array[AudioStream] = []
	var l2_path: String = "%s/%s_layer2.wav" % [SFX_DIR, file_base]
	var s: AudioStream = _load_audio_if_exists(l2_path)
	if s != null:
		list.append(s)
	return list


static func _load_audio_if_exists(res_path: String) -> AudioStream:
	if ResourceLoader.exists(res_path):
		return load(res_path) as AudioStream
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		return AudioStreamWAV.load_from_file(abs_path)
	return null


static func _get_default_cue_specs() -> Array[Dictionary]:
	var P_CROWD: int = SfxCueDataScript.Priority.CROWD
	var P_FB: int = SfxCueDataScript.Priority.FEEDBACK
	var P_HERO: int = SfxCueDataScript.Priority.HERO
	var P_CRIT: int = SfxCueDataScript.Priority.CRITICAL
	return [
		# --- 11 Cues base activos ---
		{"id": "laser", "file_base": "laser_fire", "bus": "SFX_Combat", "priority": P_FB, "pitch_min": 0.90, "pitch_max": 1.12, "vol_jitter_db": 1.4, "min_interval_ms": 40, "max_polyphony": 4, "density_attenuation_db": 4.0, "allow_panning": true},
		{"id": "missile", "file_base": "missile_fire", "bus": "SFX_Combat", "priority": P_FB, "pitch_min": 0.88, "pitch_max": 1.14, "vol_jitter_db": 1.4, "min_interval_ms": 50, "max_polyphony": 4, "density_attenuation_db": 3.5, "allow_panning": true},
		{"id": "explosion", "file_base": "explosion", "bus": "SFX_Combat", "priority": P_CROWD, "pitch_min": 0.78, "pitch_max": 1.20, "vol_jitter_db": 1.8, "min_interval_ms": 45, "max_polyphony": 4, "density_attenuation_db": 4.5, "allow_panning": true},
		{"id": "bomb", "file_base": "bomb", "bus": "SFX_Heroic", "priority": P_CRIT, "pitch_min": 0.94, "pitch_max": 1.06, "vol_jitter_db": 0.5, "min_interval_ms": 100, "max_polyphony": 2, "duck_combat_db": 6.5, "duck_duration_sec": 0.35},
		{"id": "player_hit", "file_base": "player_hit", "bus": "SFX_Heroic", "priority": P_CRIT, "pitch_min": 0.92, "pitch_max": 1.08, "vol_jitter_db": 0.8, "min_interval_ms": 80, "max_polyphony": 2, "duck_combat_db": 5.5, "duck_duration_sec": 0.22},
		{"id": "dash", "file_base": "dash", "bus": "SFX_Heroic", "priority": P_HERO, "pitch_min": 0.92, "pitch_max": 1.10, "vol_jitter_db": 1.0, "min_interval_ms": 60, "max_polyphony": 3},
		{"id": "exp", "file_base": "exp_pickup", "bus": "SFX_UI", "priority": P_FB, "pitch_min": 0.98, "pitch_max": 1.02, "vol_jitter_db": 1.0, "min_interval_ms": 35, "max_polyphony": 5, "density_attenuation_db": 3.0, "use_exp_combo": true},
		{"id": "heal", "file_base": "heal", "bus": "SFX_Heroic", "priority": P_HERO, "pitch_min": 0.94, "pitch_max": 1.06, "vol_jitter_db": 0.8, "min_interval_ms": 60, "max_polyphony": 2},
		{"id": "magnet", "file_base": "magnet", "bus": "SFX_Heroic", "priority": P_HERO, "pitch_min": 0.94, "pitch_max": 1.06, "vol_jitter_db": 0.8, "min_interval_ms": 60, "max_polyphony": 2},
		{"id": "ui_click", "file_base": "ui_click", "bus": "SFX_UI", "priority": P_CRIT, "pitch_min": 0.96, "pitch_max": 1.04, "vol_jitter_db": 0.6, "min_interval_ms": 28, "max_polyphony": 3},
		{"id": "hub_footstep", "file_base": "hub_footstep", "bus": "SFX_Combat", "priority": P_FB, "pitch_min": 0.90, "pitch_max": 1.12, "vol_jitter_db": 1.5, "min_interval_ms": 140, "max_polyphony": 3, "base_volume_db": -3.0},

		# --- 12 Cues ya invocados en código (con fallback seguro si aún no tienen WAV propio) ---
		{"id": "ui_hover", "file_base": "ui_hover", "fallback_file": "ui_click.wav", "bus": "SFX_UI", "priority": P_FB, "base_volume_db": -6.0, "pitch_min": 1.15, "pitch_max": 1.25, "min_interval_ms": 35, "max_polyphony": 2},
		{"id": "ui_error", "file_base": "ui_error", "fallback_file": "ui_click.wav", "bus": "SFX_UI", "priority": P_CRIT, "base_volume_db": -2.0, "pitch_min": 0.68, "pitch_max": 0.76, "min_interval_ms": 80, "max_polyphony": 2},
		{"id": "menu_open", "file_base": "menu_open", "fallback_file": "ui_click.wav", "bus": "SFX_UI", "priority": P_HERO, "pitch_min": 0.96, "pitch_max": 1.04, "min_interval_ms": 60, "max_polyphony": 2},
		{"id": "level_up", "file_base": "level_up", "fallback_file": "heal.wav", "bus": "SFX_Heroic", "priority": P_CRIT, "pitch_min": 0.98, "pitch_max": 1.04, "min_interval_ms": 80, "max_polyphony": 2, "duck_combat_db": 5.0, "duck_duration_sec": 0.30},
		{"id": "upgrade_obtained", "file_base": "upgrade_obtained", "fallback_file": "heal.wav", "bus": "SFX_Heroic", "priority": P_CRIT, "pitch_min": 0.98, "pitch_max": 1.04, "min_interval_ms": 80, "max_polyphony": 2},
		{"id": "item_pickup", "file_base": "item_pickup", "fallback_file": "exp_pickup.wav", "bus": "SFX_UI", "priority": P_HERO, "pitch_min": 0.95, "pitch_max": 1.05, "min_interval_ms": 45, "max_polyphony": 3},
		{"id": "warning", "file_base": "warning", "fallback_file": "bomb.wav", "bus": "SFX_Heroic", "priority": P_CRIT, "pitch_min": 0.98, "pitch_max": 1.02, "min_interval_ms": 150, "max_polyphony": 2, "duck_combat_db": 6.0, "duck_duration_sec": 0.35},
		{"id": "laser_heavy", "file_base": "laser_heavy", "fallback_file": "laser_fire.wav", "bus": "SFX_Heroic", "priority": P_HERO, "pitch_min": 0.72, "pitch_max": 0.84, "min_interval_ms": 70, "max_polyphony": 3, "allow_panning": true},
		{"id": "impact", "file_base": "impact", "fallback_file": "player_hit.wav", "bus": "SFX_Combat", "priority": P_FB, "pitch_min": 0.88, "pitch_max": 1.12, "min_interval_ms": 45, "max_polyphony": 4, "allow_panning": true},
		{"id": "hit_bullet", "file_base": "hit_bullet", "fallback_file": "player_hit.wav", "bus": "SFX_Combat", "priority": P_CROWD, "base_volume_db": -4.0, "pitch_min": 1.05, "pitch_max": 1.30, "min_interval_ms": 35, "max_polyphony": 4, "density_attenuation_db": 4.0, "allow_panning": true},
		{"id": "satellite_plant", "file_base": "satellite_plant", "fallback_file": "magnet.wav", "bus": "SFX_Heroic", "priority": P_HERO, "pitch_min": 0.95, "pitch_max": 1.05, "min_interval_ms": 80, "max_polyphony": 2, "allow_panning": true},
		{"id": "satellite_activate", "file_base": "satellite_activate", "fallback_file": "heal.wav", "bus": "SFX_Heroic", "priority": P_HERO, "pitch_min": 0.96, "pitch_max": 1.04, "min_interval_ms": 80, "max_polyphony": 2, "allow_panning": true},

		# --- 7 Familias sonoras de armas ---
		{"id": "weapon_laser", "file_base": "weapon_laser", "fallback_file": "laser_fire.wav", "bus": "SFX_Combat", "priority": P_FB, "pitch_min": 0.92, "pitch_max": 1.12, "vol_jitter_db": 1.2, "min_interval_ms": 38, "max_polyphony": 4, "density_attenuation_db": 4.2},
		{"id": "weapon_railgun", "file_base": "weapon_railgun", "fallback_file": "laser_fire.wav", "bus": "SFX_Combat", "priority": P_HERO, "pitch_min": 0.82, "pitch_max": 0.96, "vol_jitter_db": 1.0, "min_interval_ms": 55, "max_polyphony": 3, "density_attenuation_db": 3.0},
		{"id": "weapon_shotgun", "file_base": "weapon_shotgun", "fallback_file": "explosion.wav", "bus": "SFX_Combat", "priority": P_FB, "pitch_min": 0.94, "pitch_max": 1.12, "vol_jitter_db": 1.2, "min_interval_ms": 55, "max_polyphony": 3, "density_attenuation_db": 3.5},
		{"id": "weapon_missile", "file_base": "weapon_missile", "fallback_file": "missile_fire.wav", "bus": "SFX_Combat", "priority": P_FB, "pitch_min": 0.88, "pitch_max": 1.14, "vol_jitter_db": 1.2, "min_interval_ms": 48, "max_polyphony": 4, "density_attenuation_db": 3.8},
		{"id": "weapon_blade", "file_base": "weapon_blade", "fallback_file": "dash.wav", "bus": "SFX_Combat", "priority": P_FB, "pitch_min": 1.02, "pitch_max": 1.22, "vol_jitter_db": 1.0, "min_interval_ms": 45, "max_polyphony": 4, "density_attenuation_db": 3.5},
		{"id": "weapon_tesla", "file_base": "weapon_tesla", "fallback_file": "dash.wav", "bus": "SFX_Combat", "priority": P_FB, "pitch_min": 1.12, "pitch_max": 1.36, "vol_jitter_db": 1.2, "min_interval_ms": 45, "max_polyphony": 4, "density_attenuation_db": 4.0},
		{"id": "weapon_void", "file_base": "weapon_void", "fallback_file": "magnet.wav", "bus": "SFX_Heroic", "priority": P_HERO, "pitch_min": 0.86, "pitch_max": 1.02, "vol_jitter_db": 0.9, "min_interval_ms": 65, "max_polyphony": 3, "density_attenuation_db": 3.0},
	]
