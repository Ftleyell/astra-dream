class_name SfxLabCatalog
extends RefCounted
## Catálogo de slots SFX de Stela Galactica y persistencia del manifiesto de curación.

const DEFAULT_MANIFEST_PATH: String = "user://sfx_lab_curation.json"
const CURATED_PRESETS_PATH: String = "res://sandbox/workbenches/sfx_lab/curated_presets.json"
const BUNDLED_PACKS_DIR: String = "res://sandbox/workbenches/sfx_lab/packs"
const DEFAULT_CUSTOM_PRESETS_PATH: String = "user://sfx_lab_custom_presets.json"
const ESSENTIAL_KEYS: Array[String] = [
	"weapon_laser", "weapon_railgun", "weapon_blade", "weapon_shotgun", "weapon_missile",
	"explosion", "bomb", "player_hit", "dash", "exp", "ui_click", "hub_footstep",
]


static func get_profile_specs() -> Array[Dictionary]:
	return [
		{"id": "hibrido_stela", "label": "Híbrido Stela Galactica (Rec.)", "desc": "Combate ágil/cristalino + UI holográfica + Ults/Bosses cinematográficos con Capa 2."},
		{"id": "anime_cristalino", "label": "Anime Sci-Fi Cristalino", "desc": "Prioriza sonidos nítidos, brillantes y rápidos con mínima fatiga."},
		{"id": "cinematografico", "label": "Cinematográfico & Pesado", "desc": "Mayor cuerpo grave, impactos densos y Capa 2 extendida."},
		{"id": "arcade_punchy", "label": "Arcade Bullet-Hell Punchy", "desc": "Transientes ultra-cortos (<250ms) para cadencias extremas."},
	]


static func is_essential_slot(slot_key: String) -> bool:
	return ESSENTIAL_KEYS.has(slot_key)


static func get_slot_specs() -> Array[Dictionary]:
	return [
		# --- Activos actualmente en AudioManager (11) ---
		{
			"key": "laser",
			"target_filename": "laser_fire.wav",
			"category": "Combat",
			"in_audio_manager": true,
			"burst_hz": 7.0,
			"default_mono": true,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Sci-Fi Weapons) / lentikula",
			"description": "Disparo principal rápido de armas láser / pulso.",
			"keywords": ["laser", "beam", "plasma", "shoot", "blaster"],
		},
		{
			"key": "missile",
			"target_filename": "missile_fire.wav",
			"category": "Combat",
			"in_audio_manager": true,
			"burst_hz": 4.0,
			"default_mono": true,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Sci-Fi Weapons) / Sonniss",
			"description": "Lanzamiento de misiles, cohetes y enjambres teledirigidos.",
			"keywords": ["missile", "rocket", "launch", "whoosh"],
		},
		{
			"key": "explosion",
			"target_filename": "explosion.wav",
			"category": "Combat",
			"in_audio_manager": true,
			"burst_hz": 3.0,
			"default_mono": true,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Hit & Punch) / Sonniss",
			"description": "Muerte de enemigos y explosiones medias frecuentes.",
			"keywords": ["explosion", "boom", "blast", "destroy"],
		},
		{
			"key": "bomb",
			"target_filename": "bomb.wav",
			"category": "Combat",
			"in_audio_manager": true,
			"burst_hz": 1.2,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Arcane) / Sonniss",
			"description": "Detonación masiva, Ultimate [Q] y revelación épica Gacha.",
			"keywords": ["bomb", "nuke", "ult", "bass", "shockwave", "arcane"],
		},
		{
			"key": "player_hit",
			"target_filename": "player_hit.wav",
			"category": "Combat",
			"in_audio_manager": true,
			"burst_hz": 2.5,
			"default_mono": true,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Hit & Punch) / Kenney Impact",
			"description": "Daño recibido por el piloto (golpe seco + acento escudo).",
			"keywords": ["hit", "damage", "shield", "hurt", "punch"],
		},
		{
			"key": "dash",
			"target_filename": "dash.wav",
			"category": "Combat",
			"in_audio_manager": true,
			"burst_hz": 2.5,
			"default_mono": true,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Arcane / Future UI)",
			"description": "Propulsión táctica / blink Sandevistan del jugador.",
			"keywords": ["dash", "whoosh", "boost", "warp", "blink"],
		},
		{
			"key": "exp",
			"target_filename": "exp_pickup.wav",
			"category": "Pickups",
			"in_audio_manager": true,
			"burst_hz": 10.0,
			"default_mono": true,
			"use_combo": true,
			"recommended_pack": "Kenney Interface / Hove Audio UI",
			"description": "Orbe de EXP (usa escala pentatónica ascendente en AudioManager).",
			"keywords": ["coin", "gem", "pickup", "chime", "blip", "crystal"],
		},
		{
			"key": "heal",
			"target_filename": "heal.wav",
			"category": "Pickups",
			"in_audio_manager": true,
			"burst_hz": 1.5,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Arcane Activations)",
			"description": "Curación y restauración de escudo.",
			"keywords": ["heal", "powerup", "magic", "shimmer", "restore"],
		},
		{
			"key": "magnet",
			"target_filename": "magnet.wav",
			"category": "Pickups",
			"in_audio_manager": true,
			"burst_hz": 1.5,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Arcane / Future UI)",
			"description": "Activación de imán de experiencia en campo.",
			"keywords": ["magnet", "charge", "warp", "suction", "arcane"],
		},
		{
			"key": "ui_click",
			"target_filename": "ui_click.wav",
			"category": "UI",
			"in_audio_manager": true,
			"burst_hz": 4.0,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Hove Audio / JDSherbert Sci-Fi UI / Kenney",
			"description": "Confirmación y pulsación estándar de botones UI.",
			"keywords": ["click", "select", "confirm", "button", "ui"],
		},
		{
			"key": "hub_footstep",
			"target_filename": "hub_footstep.wav",
			"category": "Hub",
			"in_audio_manager": true,
			"burst_hz": 2.8,
			"default_mono": true,
			"use_combo": false,
			"recommended_pack": "Kenney Impact (metal tap / footstep)",
			"description": "Pasos Astral Glide-Hop sobre cubierta metálica del Hub 3D.",
			"keywords": ["footstep", "step", "metal", "tap", "walk"],
		},
		# --- Invocados en código pero pendientes de mapear (12) ---
		{
			"key": "ui_hover",
			"target_filename": "ui_hover.wav",
			"category": "UI",
			"in_audio_manager": false,
			"burst_hz": 5.0,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Hove Audio / JDSherbert Sci-Fi UI",
			"description": "Micro-tick sutil al pasar cursor o foco en tarjetas.",
			"keywords": ["hover", "tick", "rollover", "ui", "soft"],
		},
		{
			"key": "ui_error",
			"target_filename": "ui_error.wav",
			"category": "UI",
			"in_audio_manager": false,
			"burst_hz": 2.0,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Hove Audio / Kenney Interface",
			"description": "Acción denegada, recursos insuficientes o bloqueo.",
			"keywords": ["error", "deny", "cancel", "buzz", "negative"],
		},
		{
			"key": "menu_open",
			"target_filename": "menu_open.wav",
			"category": "UI",
			"in_audio_manager": false,
			"burst_hz": 1.5,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Future UI) / Hove Audio",
			"description": "Apertura de modales, Game Over y pantallas de hangar.",
			"keywords": ["open", "menu", "swoosh", "panel", "ui"],
		},
		{
			"key": "level_up",
			"target_filename": "level_up.wav",
			"category": "Pickups",
			"in_audio_manager": false,
			"burst_hz": 1.2,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Arcane) / JDSherbert",
			"description": "Subida de nivel y recolección de orbes Arcana / Dark Matter.",
			"keywords": ["level", "fanfare", "upgrade", "chime", "powerup"],
		},
		{
			"key": "upgrade_obtained",
			"target_filename": "upgrade_obtained.wav",
			"category": "Pickups",
			"in_audio_manager": false,
			"burst_hz": 1.2,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Future UI / Arcane)",
			"description": "Recompensa de tragamonedas / mejora adquirida.",
			"keywords": ["upgrade", "reward", "unlock", "victory", "gacha"],
		},
		{
			"key": "item_pickup",
			"target_filename": "item_pickup.wav",
			"category": "Pickups",
			"in_audio_manager": false,
			"burst_hz": 3.0,
			"default_mono": true,
			"use_combo": false,
			"recommended_pack": "Kenney Interface / Sci-Fi",
			"description": "Recolección general de ítems y loot en arena.",
			"keywords": ["pickup", "item", "collect", "loot"],
		},
		{
			"key": "warning",
			"target_filename": "warning.wav",
			"category": "Combat",
			"in_audio_manager": false,
			"burst_hz": 1.5,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Hove Audio / Kenney Sci-Fi",
			"description": "Alerta de entrada de Boss / Rival / evento crítico.",
			"keywords": ["warning", "alarm", "alert", "siren", "boss"],
		},
		{
			"key": "laser_heavy",
			"target_filename": "laser_heavy.wav",
			"category": "Combat",
			"in_audio_manager": false,
			"burst_hz": 1.5,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Sci-Fi Weapons)",
			"description": "Disparo pesado de Railgun / Desgarro Cósmico.",
			"keywords": ["heavy", "cannon", "railgun", "beam", "charge"],
		},
		{
			"key": "impact",
			"target_filename": "impact.wav",
			"category": "Combat",
			"in_audio_manager": false,
			"burst_hz": 4.0,
			"default_mono": true,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Hit & Punch) / Kenney Impact",
			"description": "Impacto físico pesado en monolitos y colisiones.",
			"keywords": ["impact", "hit", "thud", "crash", "slam"],
		},
		{
			"key": "hit_bullet",
			"target_filename": "hit_bullet.wav",
			"category": "Combat",
			"in_audio_manager": false,
			"burst_hz": 6.0,
			"default_mono": true,
			"use_combo": false,
			"recommended_pack": "Kenney Impact / Shapeforms",
			"description": "Impacto metálico / rebote rápido de proyectiles.",
			"keywords": ["hit", "ricochet", "spark", "metal", "impact"],
		},
		{
			"key": "satellite_plant",
			"target_filename": "satellite_plant.wav",
			"category": "Hub",
			"in_audio_manager": false,
			"burst_hz": 1.5,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Kenney Sci-Fi / Shapeforms",
			"description": "Despliegue / anclaje de satélite o geoda astral.",
			"keywords": ["deploy", "plant", "lock", "mech", "activate"],
		},
		{
			"key": "satellite_activate",
			"target_filename": "satellite_activate.wav",
			"category": "Hub",
			"in_audio_manager": false,
			"burst_hz": 1.5,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Arcane / Future UI)",
			"description": "Activación de baliza orbital / Gacha modal.",
			"keywords": ["activate", "beacon", "portal", "power", "gacha"],
		},
		# --- 7 Familias Sonoras de Armas (WeaponData) ---
		{
			"key": "weapon_laser",
			"target_filename": "weapon_laser.wav",
			"category": "Weapons",
			"in_audio_manager": true,
			"burst_hz": 7.5,
			"default_mono": true,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Sci-Fi Weapons) / lentikula",
			"description": "Familia Láser Cristalino (Scatter Laser, Tachyon Beam, Solar Beam).",
			"keywords": ["laser", "pulse", "scifi", "blaster", "beam"],
		},
		{
			"key": "weapon_railgun",
			"target_filename": "weapon_railgun.wav",
			"category": "Weapons",
			"in_audio_manager": true,
			"burst_hz": 2.4,
			"default_mono": true,
			"use_combo": false,
			"supports_layer2": true,
			"recommended_pack": "Shapeforms (Sci-Fi Weapons)",
			"description": "Familia Railgun / Francotirador (Rail Launcher, Sniper Rifle).",
			"keywords": ["railgun", "sniper", "cannon", "gauss", "heavy"],
		},
		{
			"key": "weapon_shotgun",
			"target_filename": "weapon_shotgun.wav",
			"category": "Weapons",
			"in_audio_manager": true,
			"burst_hz": 3.0,
			"default_mono": true,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Sci-Fi Weapons / Hit & Punch)",
			"description": "Familia Escopeta / Flak (Titan Shotgun, Plasma Flak, Nova Flak).",
			"keywords": ["shotgun", "flak", "blast", "scatter", "heavy"],
		},
		{
			"key": "weapon_missile",
			"target_filename": "weapon_missile.wav",
			"category": "Weapons",
			"in_audio_manager": true,
			"burst_hz": 4.5,
			"default_mono": true,
			"use_combo": false,
			"recommended_pack": "Shapeforms / Sonniss",
			"description": "Familia Misiles y Enjambre (Swarm Missiles, Hive Cannon, Cluster).",
			"keywords": ["missile", "rocket", "launch", "swarm", "whoosh"],
		},
		{
			"key": "weapon_blade",
			"target_filename": "weapon_blade.wav",
			"category": "Weapons",
			"in_audio_manager": true,
			"burst_hz": 4.0,
			"default_mono": true,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Arcane) / Leohpaz",
			"description": "Familia Espada Energética Anime (Crescent Blade, Dimensional Blade).",
			"keywords": ["blade", "sword", "slash", "swipe", "energy"],
		},
		{
			"key": "weapon_tesla",
			"target_filename": "weapon_tesla.wav",
			"category": "Weapons",
			"in_audio_manager": true,
			"burst_hz": 5.0,
			"default_mono": true,
			"use_combo": false,
			"recommended_pack": "Shapeforms (Sci-Fi) / Kenney",
			"description": "Familia Arco Eléctrico (Tesla Arc).",
			"keywords": ["tesla", "electric", "zap", "arc", "lightning"],
		},
		{
			"key": "weapon_void",
			"target_filename": "weapon_void.wav",
			"category": "Weapons",
			"in_audio_manager": true,
			"burst_hz": 2.0,
			"default_mono": false,
			"use_combo": false,
			"supports_layer2": true,
			"recommended_pack": "Shapeforms (Arcane) / Sonniss",
			"description": "Familia Vacío / Gravitatoria (Singularity Cannon/Pulsar, Void Siphon, Solar Flare).",
			"keywords": ["void", "singularity", "gravity", "deep", "arcane"],
		},
		# --- 2 Camas Atmosféricas (Ambience Bed) ---
		{
			"key": "ambience_cosmos",
			"target_filename": "ambience_cosmos.wav",
			"category": "Ambience",
			"in_audio_manager": true,
			"is_ambience": true,
			"burst_hz": 0.5,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Sonniss / Space Ambience Loops",
			"description": "Loop espacial etéreo de fondo para Cosmos y Title.",
			"keywords": ["space", "cosmos", "ambience", "drone", "nebula"],
		},
		{
			"key": "ambience_hub",
			"target_filename": "ambience_hub.wav",
			"category": "Ambience",
			"in_audio_manager": true,
			"is_ambience": true,
			"burst_hz": 0.5,
			"default_mono": false,
			"use_combo": false,
			"recommended_pack": "Sonniss / Sci-Fi Room Tone",
			"description": "Zumbido limpio de estación orbital / hangar para Hub 3D.",
			"keywords": ["station", "hub", "ship", "bridge", "hum", "ambience"],
		},
	]


static func create_default_slot_state(spec: Dictionary) -> Dictionary:
	var is_amb: bool = bool(spec.get("is_ambience", false))
	return {
		"candidates": [] as Array[String],
		"layer2_candidate": "",
		"gain_db": 0.0,
		"pitch_base": 1.0,
		"pitch_jitter": 0.08,
		"trim_silence": not is_amb,
		"mono": bool(spec.get("default_mono", true)),
	}


static func create_empty_manifest() -> Dictionary:
	var slots: Dictionary = {}
	for spec: Dictionary in get_slot_specs():
		var key: String = str(spec.get("key", ""))
		slots[key] = create_default_slot_state(spec)
	return {
		"version": 2,
		"pack_root_dir": "",
		"pack_dirs": [] as Array[String],
		"active_profile_id": "hibrido_stela",
		"favorites": [] as Array[String],
		"slots": slots,
	}


static func save_manifest(data: Dictionary, path: String = DEFAULT_MANIFEST_PATH) -> Error:
	var dir_path: String = path.get_base_dir()
	if not dir_path.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK


static func load_manifest(path: String = DEFAULT_MANIFEST_PATH) -> Dictionary:
	var base: Dictionary = create_empty_manifest()
	if not FileAccess.file_exists(path):
		return base
	var raw_text: String = FileAccess.get_file_as_string(path)
	if raw_text.is_empty():
		return base
	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		return base
	var loaded: Dictionary = parsed as Dictionary
	var root_dir: String = str(loaded.get("pack_root_dir", ""))
	base["pack_root_dir"] = root_dir
	base["active_profile_id"] = str(loaded.get("active_profile_id", "hibrido_stela"))

	var p_dirs: Array[String] = []
	var raw_dirs: Variant = loaded.get("pack_dirs", [])
	if raw_dirs is Array:
		for d_v: Variant in (raw_dirs as Array):
			var d_str: String = str(d_v).strip_edges()
			if not d_str.is_empty() and not p_dirs.has(d_str):
				p_dirs.append(d_str)
	if p_dirs.is_empty() and not root_dir.is_empty():
		p_dirs.append(root_dir)
	base["pack_dirs"] = p_dirs

	var favs: Array[String] = []
	var raw_favs: Variant = loaded.get("favorites", [])
	if raw_favs is Array:
		for item: Variant in (raw_favs as Array):
			var p: String = str(item)
			if not p.is_empty() and not favs.has(p):
				favs.append(p)
	base["favorites"] = favs

	var base_slots: Dictionary = base["slots"] as Dictionary
	var raw_slots: Variant = loaded.get("slots", {})
	if raw_slots is Dictionary:
		var loaded_slots: Dictionary = raw_slots as Dictionary
		for key_v: Variant in base_slots.keys():
			var key: String = str(key_v)
			if not loaded_slots.has(key) or not (loaded_slots[key] is Dictionary):
				continue
			var src: Dictionary = loaded_slots[key] as Dictionary
			var dst: Dictionary = base_slots[key] as Dictionary
			var cands: Array[String] = []
			var raw_cands: Variant = src.get("candidates", [])
			if raw_cands is Array:
				for c_v: Variant in (raw_cands as Array):
					var c_path: String = str(c_v)
					if not c_path.is_empty():
						cands.append(c_path)
			dst["candidates"] = cands
			dst["layer2_candidate"] = str(src.get("layer2_candidate", dst.get("layer2_candidate", "")))
			dst["gain_db"] = float(src.get("gain_db", dst.get("gain_db", 0.0)))
			dst["pitch_base"] = float(src.get("pitch_base", dst.get("pitch_base", 1.0)))
			dst["pitch_jitter"] = float(src.get("pitch_jitter", dst.get("pitch_jitter", 0.08)))
			dst["trim_silence"] = bool(src.get("trim_silence", dst.get("trim_silence", true)))
			dst["mono"] = bool(src.get("mono", dst.get("mono", true)))
	return base


static func load_curated_presets(path: String = CURATED_PRESETS_PATH) -> Dictionary:
	return _load_presets_dict(path)


static func load_custom_presets(path: String = DEFAULT_CUSTOM_PRESETS_PATH) -> Dictionary:
	return _load_presets_dict(path)


static func _load_presets_dict(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var raw_text: String = FileAccess.get_file_as_string(path)
	if raw_text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		return {}
	var root: Dictionary = parsed as Dictionary
	var raw_presets: Variant = root.get("presets", {})
	if raw_presets is Dictionary:
		return raw_presets as Dictionary
	return {}


static func save_custom_preset(
	preset_id: String,
	label: String,
	desc: String,
	manifest_slots: Dictionary,
	path: String = DEFAULT_CUSTOM_PRESETS_PATH
) -> Error:
	var existing: Dictionary = load_custom_presets(path)
	var clean_slots: Dictionary = {}
	for key_v: Variant in manifest_slots.keys():
		var key: String = str(key_v)
		var st_v: Variant = manifest_slots[key_v]
		if st_v is Dictionary:
			clean_slots[key] = (st_v as Dictionary).duplicate(true)
	existing[preset_id] = {
		"id": preset_id,
		"label": label,
		"desc": desc,
		"slots": clean_slots,
	}
	var dir_path: String = path.get_base_dir()
	if not dir_path.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"version": 1, "presets": existing}, "\t"))
	f.close()
	return OK


static func _resolve_file_with_ext_fallback(abs_or_res_path: String) -> String:
	if abs_or_res_path.is_empty():
		return ""
	if FileAccess.file_exists(abs_or_res_path):
		return abs_or_res_path
	var ext: String = abs_or_res_path.get_extension().to_lower()
	if ext == "wav":
		var ogg_cand: String = abs_or_res_path.get_basename() + ".ogg"
		if FileAccess.file_exists(ogg_cand):
			return ogg_cand
	elif ext == "ogg":
		var wav_cand: String = abs_or_res_path.get_basename() + ".wav"
		if FileAccess.file_exists(wav_cand):
			return wav_cand
	return ""


static func resolve_preset_path(rel_or_abs: String, pack_dirs: Array[String]) -> String:
	var clean: String = rel_or_abs.strip_edges().replace("\\", "/")
	if clean.is_empty():
		return ""
	var direct_hit: String = _resolve_file_with_ext_fallback(clean)
	if not direct_hit.is_empty():
		return direct_hit
	for d: String in pack_dirs:
		var base_dir: String = d.strip_edges().replace("\\", "/")
		var cand: String = _resolve_file_with_ext_fallback(base_dir.path_join(clean))
		if not cand.is_empty():
			return cand
		var parent_cand: String = _resolve_file_with_ext_fallback(base_dir.get_base_dir().path_join(clean))
		if not parent_cand.is_empty():
			return parent_cand
	return ""
