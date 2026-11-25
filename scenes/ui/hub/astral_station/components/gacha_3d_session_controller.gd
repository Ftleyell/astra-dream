class_name Gacha3DSessionController
extends RefCounted

## Controlador de sesión simulada y aislada para el Lab Invocador Gacha 3D (Fase 2).
## Reutiliza al 100% GachaBannerEngine y CosmeticsManager sin leer ni mutar SaveManager real.

const GachaBannerEngineScript = preload("res://scenes/ui/gacha/components/gacha_banner_engine.gd")
const CosmeticsManagerScript = preload("res://core/systems/cosmetics_manager.gd")
const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_gacha_3d_config.gd")

enum PullOverride {
	NATURAL = 0,
	FORCE_COMMON = 1,
	FORCE_EPIC = 2,
	FORCE_PITY = 3,
	FORCE_FAKEOUT = 4,
}

const MAX_SKIN_STARS: int = 3

var _config: ConfigScript = null
var _tokens: int = 30
var _active_banner_id: String = "general"
var _pity_by_banner: Dictionary = {
	"general": 0,
	"ships": 0,
	"pilots": 0,
}
var _owned_stars: Dictionary = {}
var _equipped_by_slot: Dictionary = {}


func setup(p_config: ConfigScript) -> void:
	_config = p_config
	reset_session()


func reset_session() -> void:
	_tokens = _config.sandbox_initial_tokens if _config != null else 30
	_active_banner_id = "general"
	_pity_by_banner = {
		"general": 0,
		"ships": 0,
		"pilots": 0,
	}
	_owned_stars.clear()
	_equipped_by_slot.clear()


func get_tokens() -> int:
	return _tokens


func add_tokens(amount: int) -> int:
	_tokens = maxi(0, _tokens + amount)
	return _tokens


func can_afford(count: int) -> bool:
	return count > 0 and _tokens >= count


func get_active_banner_id() -> String:
	return _active_banner_id


func set_active_banner_id(banner_id: String) -> void:
	if GachaBannerEngineScript.BANNERS_CONFIG.has(banner_id):
		_active_banner_id = banner_id
	else:
		_active_banner_id = "general"


func get_banner_config(banner_id: String = "") -> Dictionary:
	var target_id: String = banner_id if not banner_id.is_empty() else _active_banner_id
	return GachaBannerEngineScript.get_banner_config(target_id)


func get_pity(banner_id: String = "") -> int:
	var target_id: String = banner_id if not banner_id.is_empty() else _active_banner_id
	return int(_pity_by_banner.get(target_id, 0))


func set_pity(banner_id: String, value: int) -> void:
	var target_id: String = banner_id if not banner_id.is_empty() else _active_banner_id
	_pity_by_banner[target_id] = clampi(value, 0, GachaBannerEngineScript.PITY_THRESHOLD - 1)


func get_pool_for_banner(banner_id: String) -> Array[Dictionary]:
	var all_skins: Dictionary = CosmeticsManagerScript.get_all_skins()
	return GachaBannerEngineScript.filter_skins_for_banner(all_skins, banner_id)


func execute_pull_batch(
	banner_id: String,
	count: int,
	override_mode: PullOverride = PullOverride.NATURAL
) -> Dictionary:
	if not (count in [1, 5, 10]):
		return {"ok": false, "error": "invalid_count"}
	if _tokens < count:
		return {"ok": false, "error": "insufficient_tokens"}

	var target_banner: String = banner_id if GachaBannerEngineScript.BANNERS_CONFIG.has(banner_id) else "general"
	var pool: Array[Dictionary] = get_pool_for_banner(target_banner)
	if pool.is_empty():
		return {"ok": false, "error": "empty_pool"}

	_tokens -= count
	var cur_pity: int = get_pity(target_banner)
	var results: Array[Dictionary] = []
	var has_epic: bool = false
	var has_pity: bool = false
	var highest_rarity: String = "common"

	for i: int in range(count):
		var is_featured: bool = (i == count - 1)
		var forced_roll: float = -1.0

		match override_mode:
			PullOverride.FORCE_COMMON:
				if cur_pity >= GachaBannerEngineScript.PITY_THRESHOLD - 1:
					cur_pity = 0
				forced_roll = 0.85
			PullOverride.FORCE_EPIC, PullOverride.FORCE_FAKEOUT:
				if is_featured:
					forced_roll = 0.01
			PullOverride.FORCE_PITY:
				if is_featured:
					cur_pity = GachaBannerEngineScript.PITY_THRESHOLD - 1
				else:
					cur_pity = mini(cur_pity, GachaBannerEngineScript.PITY_THRESHOLD - 2)
					forced_roll = 0.85

		var pull_res: Dictionary = GachaBannerEngineScript.resolve_pull(target_banner, cur_pity, pool, forced_roll)
		if pull_res.is_empty():
			continue

		var skin_dict: Dictionary = pull_res.get("skin", {}) as Dictionary
		var sid: String = str(skin_dict.get("id", ""))
		var rarity: String = str(pull_res.get("rarity", "common"))
		var is_pity_pull: bool = bool(pull_res.get("is_pity", false))
		cur_pity = int(pull_res.get("new_pity", 0))

		var prev_stars: int = int(_owned_stars.get(sid, 0))
		var new_stars: int = prev_stars
		var status: String = "new"
		if prev_stars <= 0:
			new_stars = 1
			status = "new"
		elif prev_stars < MAX_SKIN_STARS:
			new_stars = prev_stars + 1
			status = "upgraded"
		else:
			new_stars = MAX_SKIN_STARS
			status = "max_converted"
		_owned_stars[sid] = new_stars

		if rarity == "epic" or is_pity_pull:
			has_epic = true
			highest_rarity = "epic"
		elif rarity == "rare" and highest_rarity != "epic":
			highest_rarity = "rare"

		if is_pity_pull:
			has_pity = true

		results.append({
			"skin_data": skin_dict,
			"skin_id": sid,
			"rarity": rarity,
			"is_pity": is_pity_pull,
			"new_stars": new_stars,
			"status": status,
			"is_shader_skin": CosmeticsManagerScript.is_shader_skin(skin_dict),
		})

	_pity_by_banner[target_banner] = cur_pity

	var fakeout_prob: float = _config.fakeout_probability if _config != null else 0.28
	var is_fakeout: bool = false
	if override_mode == PullOverride.FORCE_FAKEOUT:
		is_fakeout = true
	elif override_mode == PullOverride.NATURAL and has_epic:
		is_fakeout = (randf() < fakeout_prob)

	return {
		"ok": true,
		"banner_id": target_banner,
		"count": count,
		"results": results,
		"highest_rarity": highest_rarity,
		"has_epic": has_epic,
		"has_pity": has_pity,
		"is_fakeout": is_fakeout,
		"remaining_tokens": _tokens,
		"final_pity": cur_pity,
	}


func equip_pulled_skin(skin_data: Dictionary, star_level: int = 1) -> Dictionary:
	if skin_data.is_empty():
		return {"ok": false}
	var raw_cat: String = str(skin_data.get("category", "pilot"))
	var tid_str: String = str(skin_data.get("target_id", "valentina")).to_lower()
	var tid: StringName = StringName(tid_str)
	var norm_cat: String = CosmeticsManagerScript.normalize_category_for_target(raw_cat, tid)
	var slot_key: String = "%s:%s" % [norm_cat, tid_str]
	var sid: String = str(skin_data.get("id", ""))
	var clamped_stars: int = clampi(star_level, 1, MAX_SKIN_STARS)
	var is_shader: bool = CosmeticsManagerScript.is_shader_skin(skin_data)
	var preset: PilotSkinPreset = CosmeticsManagerScript.get_skin_preset(sid) if is_shader else null
	var s_name: String = str(skin_data.get("skin_name", sid))

	_equipped_by_slot[slot_key] = {
		"skin_id": sid,
		"skin_name": s_name,
		"star_level": clamped_stars,
		"category": norm_cat,
		"target_id": tid_str,
	}

	return {
		"ok": true,
		"slot_key": slot_key,
		"category": norm_cat,
		"target_id": tid_str,
		"skin_id": sid,
		"skin_name": s_name,
		"star_level": clamped_stars,
		"is_shader_skin": is_shader,
		"preset": preset,
	}


func get_equipped_summary() -> Dictionary:
	return _equipped_by_slot.duplicate(true)


func get_owned_star_level(skin_id: String) -> int:
	return int(_owned_stars.get(skin_id, 0))
