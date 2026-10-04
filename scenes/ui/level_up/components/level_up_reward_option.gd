class_name LevelUpRewardOption
extends RefCounted

enum OptionType {
	WEAPON_NEW,
	WEAPON_UPGRADE,
	TOME_NEW,
	TOME_UPGRADE
}

var type: OptionType
var weapon_data: WeaponData = null
var tome_data: Resource = null
var current_level: int = 1
var next_level: int = 2
var title: String = ""
var subtitle: String = ""
var description: String = ""
var badge_text: String = ""
var icon: Texture2D = null
var tier: Enums.Tier = Enums.Tier.TIER_1
var target_stat: StringName = &""
