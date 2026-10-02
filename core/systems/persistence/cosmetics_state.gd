class_name CosmeticsState
extends RefCounted

## Gestor de persistencia y estado para cosméticos, skins desbloqueadas, equipadas y contadores de pity de Gacha.

static func get_gacha_tokens(profile: Dictionary) -> int:
	return int(profile.get("gacha_tokens", 0))

static func add_gacha_tokens(profile: Dictionary, amount: int) -> int:
	var cur := get_gacha_tokens(profile)
	var nw: int = maxi(0, cur + amount)
	profile["gacha_tokens"] = nw
	return nw

static func spend_gacha_tokens(profile: Dictionary, amount: int) -> bool:
	var cur := get_gacha_tokens(profile)
	if cur >= amount:
		profile["gacha_tokens"] = cur - amount
		return true
	return false

static func set_gacha_tokens(profile: Dictionary, amount: int) -> void:
	profile["gacha_tokens"] = maxi(0, amount)

static func get_unlocked_skins(profile: Dictionary) -> Dictionary:
	return profile.get("unlocked_skins", {})

static func is_skin_unlocked(profile: Dictionary, skin_id: String) -> bool:
	var skins: Dictionary = get_unlocked_skins(profile)
	return skins.has(skin_id)

static func get_skin_stars(profile: Dictionary, skin_id: String) -> int:
	var skins: Dictionary = get_unlocked_skins(profile)
	return int(skins.get(skin_id, 0))

static func unlock_or_upgrade_skin(profile: Dictionary, skin_id: String) -> Dictionary:
	var skins: Dictionary = profile.get("unlocked_skins", {})
	var prev_stars: int = int(skins.get(skin_id, 0))
	var is_first: bool = (prev_stars == 0)
	var new_stars: int = mini(prev_stars + 1, 3)
	skins[skin_id] = new_stars
	profile["unlocked_skins"] = skins
	return {
		"is_new": is_first,
		"stars": new_stars,
		"skin_id": skin_id
	}

static func equip_skin(profile: Dictionary, slot_key: String, skin_id: String) -> bool:
	if skin_id != "" and not is_skin_unlocked(profile, skin_id):
		return false
	var equipped: Dictionary = profile.get("equipped_skins", {})
	equipped[slot_key] = skin_id
	profile["equipped_skins"] = equipped
	return true

static func unequip_skin(profile: Dictionary, slot_key: String) -> void:
	var equipped: Dictionary = profile.get("equipped_skins", {})
	if equipped.has(slot_key):
		equipped.erase(slot_key)
		profile["equipped_skins"] = equipped

static func get_equipped_skin(profile: Dictionary, slot_key: String) -> String:
	var equipped: Dictionary = profile.get("equipped_skins", {})
	return str(equipped.get(slot_key, ""))

static func get_equipped_skins(profile: Dictionary) -> Dictionary:
	return profile.get("equipped_skins", {})

static func get_banner_pity(profile: Dictionary, banner_id: String) -> int:
	var pity_dict: Dictionary = profile.get("gacha_pity", {})
	return int(pity_dict.get(banner_id, 0))

static func increment_banner_pity(profile: Dictionary, banner_id: String, amount: int = 1) -> void:
	var pity_dict: Dictionary = profile.get("gacha_pity", {})
	var cur := int(pity_dict.get(banner_id, 0))
	pity_dict[banner_id] = cur + amount
	profile["gacha_pity"] = pity_dict

static func reset_banner_pity(profile: Dictionary, banner_id: String) -> void:
	var pity_dict: Dictionary = profile.get("gacha_pity", {})
	pity_dict[banner_id] = 0
	profile["gacha_pity"] = pity_dict
