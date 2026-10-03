class_name StatDeckManager
extends Node

signal cards_offered(cards: Array[StatCardData], reroll_cost: int)
signal card_applied(card: StatCardData)

@export var all_stat_cards: Array[StatCardData] = []
@export var base_reroll_cost: int = 5
@export var reroll_cost_increment: int = 3

var _current_level: int = 1
var _rerolls_this_session: int = 0

const BASE_TIER_PROBS = {
	1: [0.90, 0.10, 0.00, 0.00],
	5: [0.70, 0.25, 0.05, 0.00],
	10: [0.45, 0.35, 0.15, 0.05],
	20: [0.20, 0.40, 0.25, 0.15]
}

func _ready() -> void:
	if all_stat_cards.is_empty():
		_generate_default_cards()

func _generate_default_cards() -> void:
	var stats_to_create = [
		{"id": &"card_dmg_1", "title": "+12% Daño Base", "stat": &"base_damage", "val": 0.12, "pct": true, "mod_type": Enums.ModifierType.ADDITIVE_PERCENT, "tier": Enums.Tier.TIER_1},
		{"id": &"card_dmg_2", "title": "+24% Daño Base", "stat": &"base_damage", "val": 0.24, "pct": true, "mod_type": Enums.ModifierType.ADDITIVE_PERCENT, "tier": Enums.Tier.TIER_2},
		{"id": &"card_atk_spd", "title": "+10% Cadencia de Fuego", "stat": &"attack_speed", "val": 0.10, "pct": true, "mod_type": Enums.ModifierType.ADDITIVE_PERCENT, "tier": Enums.Tier.TIER_1},
		{"id": &"card_crit_chance", "title": "+6% Prob. Crítica", "stat": &"crit_chance", "val": 0.06, "pct": false, "mod_type": Enums.ModifierType.FLAT, "tier": Enums.Tier.TIER_1},
		{"id": &"card_crit_dmg", "title": "+30% Daño Crítico", "stat": &"crit_damage", "val": 0.30, "pct": true, "mod_type": Enums.ModifierType.ADDITIVE_PERCENT, "tier": Enums.Tier.TIER_2},
		{"id": &"card_hp_up", "title": "+25 Vida Máxima", "stat": &"max_health", "val": 25.0, "pct": false, "mod_type": Enums.ModifierType.FLAT, "tier": Enums.Tier.TIER_1},
		{"id": &"card_speed_up", "title": "+10% Velocidad de Movimiento", "stat": &"move_speed", "val": 0.10, "pct": true, "mod_type": Enums.ModifierType.ADDITIVE_PERCENT, "tier": Enums.Tier.TIER_1},
		{"id": &"card_luck_up", "title": "+20% Suerte (Mejores Tiers)", "stat": &"luck", "val": 0.20, "pct": true, "mod_type": Enums.ModifierType.ADDITIVE_PERCENT, "tier": Enums.Tier.TIER_2},
		{"id": &"card_armor_1", "title": "+3 Armadura", "stat": &"armor", "val": 3.0, "pct": false, "mod_type": Enums.ModifierType.FLAT, "tier": Enums.Tier.TIER_1},
		{"id": &"card_armor_2", "title": "+6 Armadura", "stat": &"armor", "val": 6.0, "pct": false, "mod_type": Enums.ModifierType.FLAT, "tier": Enums.Tier.TIER_2},
		{"id": &"card_regen_1", "title": "+0.8 Regen/s", "stat": &"health_regen", "val": 0.8, "pct": false, "mod_type": Enums.ModifierType.FLAT, "tier": Enums.Tier.TIER_1},
		{"id": &"card_regen_2", "title": "+1.8 Regen/s", "stat": &"health_regen", "val": 1.8, "pct": false, "mod_type": Enums.ModifierType.FLAT, "tier": Enums.Tier.TIER_2},
		{"id": &"card_magnet_1", "title": "+35 px Imán", "stat": &"pickup_radius", "val": 35.0, "pct": false, "mod_type": Enums.ModifierType.FLAT, "tier": Enums.Tier.TIER_1},
		{"id": &"card_magnet_2", "title": "+70 px Imán", "stat": &"pickup_radius", "val": 70.0, "pct": false, "mod_type": Enums.ModifierType.FLAT, "tier": Enums.Tier.TIER_2},
		{"id": &"card_exp_1", "title": "+12% EXP Ganada", "stat": &"exp_multiplier", "val": 0.12, "pct": true, "mod_type": Enums.ModifierType.ADDITIVE_PERCENT, "tier": Enums.Tier.TIER_1},
		{"id": &"card_exp_2", "title": "+25% EXP Ganada", "stat": &"exp_multiplier", "val": 0.25, "pct": true, "mod_type": Enums.ModifierType.ADDITIVE_PERCENT, "tier": Enums.Tier.TIER_2}
	]
	var stat_icon_map := {
		&"base_damage": "res://assets/icons/items/icon_sword.svg",
		&"attack_speed": "res://assets/icons/items/icon_gauntlet.svg",
		&"crit_chance": "res://assets/icons/items/icon_glasses.svg",
		&"crit_damage": "res://assets/icons/items/icon_lens.svg",
		&"max_health": "res://assets/icons/items/icon_heart.svg",
		&"move_speed": "res://assets/icons/items/icon_boots.svg",
		&"luck": "res://assets/icons/items/icon_clover.svg",
		&"projectile_count": "res://assets/icons/items/icon_quiver.svg",
		&"armor": "res://assets/icons/items/icon_shield.svg",
		&"health_regen": "res://assets/icons/items/icon_apple.svg",
		&"pickup_radius": "res://assets/icons/items/icon_magnet.svg",
		&"exp_multiplier": "res://assets/icons/items/icon_lens.svg",
	}

	for def in stats_to_create:
		var c := StatCardData.new()
		c.card_id = def["id"]
		c.title = def["title"]
		c.target_stat = def["stat"]
		c.modifier_value = def["val"]
		c.is_percentage = def["pct"]
		c.modifier_type = def.get("mod_type", Enums.ModifierType.ADDITIVE_PERCENT if c.is_percentage else Enums.ModifierType.FLAT)
		c.tier = def["tier"]
		c.base_weight = 100.0
		var stat_key: StringName = def["stat"]
		if stat_icon_map.has(stat_key) and ResourceLoader.exists(stat_icon_map[stat_key]):
			c.icon = load(stat_icon_map[stat_key]) as Texture2D
		all_stat_cards.append(c)

func offer_cards(char_stats: CharacterStats, level: int, count: int = 3) -> void:
	_current_level = level
	_rerolls_this_session = 0
	_generate_hand(char_stats, count)

func reroll(char_stats: CharacterStats, current_credits: int) -> bool:
	var cost := get_reroll_cost()
	if current_credits < cost:
		return false
	_rerolls_this_session += 1
	_generate_hand(char_stats, 3)
	return true

func get_reroll_cost() -> int:
	return base_reroll_cost + (_rerolls_this_session * reroll_cost_increment)

func _generate_hand(char_stats: CharacterStats, count: int) -> void:
	var hand: Array[StatCardData] = []
	var luck: float = char_stats.get_stat(&"luck") if char_stats else 1.0
	var temp_deck := all_stat_cards.duplicate()

	for i in range(count):
		if temp_deck.is_empty():
			break
		var rolled_tier := _roll_tier(_current_level, luck)
		var chosen_card := _sample_card_by_tier(temp_deck, rolled_tier)
		if chosen_card:
			hand.append(chosen_card)
			temp_deck.erase(chosen_card)

	cards_offered.emit(hand, get_reroll_cost())

func _roll_tier(level: int, luck: float) -> Enums.Tier:
	var key_levels := BASE_TIER_PROBS.keys()
	key_levels.sort()
	var selected_bracket: int = key_levels[0]
	for lvl in key_levels:
		if level >= lvl:
			selected_bracket = lvl

	var probs: Array = BASE_TIER_PROBS[selected_bracket].duplicate()
	var luck_factor: float = clampf((luck - 1.0) * 0.05, -0.2, 0.5)
	probs[0] = maxf(0.05, probs[0] - luck_factor)
	probs[1] = maxf(0.05, probs[1] + (luck_factor * 0.4))
	probs[2] = maxf(0.00, probs[2] + (luck_factor * 0.35))
	probs[3] = maxf(0.00, probs[3] + (luck_factor * 0.25))

	var total_p: float = float(probs[0]) + float(probs[1]) + float(probs[2]) + float(probs[3])
	var roll: float = randf() * total_p
	var cumulative: float = 0.0
	for tier_idx in range(probs.size()):
		cumulative += float(probs[tier_idx])
		if roll <= cumulative:
			return tier_idx as Enums.Tier
	return Enums.Tier.TIER_1

func _sample_card_by_tier(deck: Array[StatCardData], tier: Enums.Tier) -> StatCardData:
	var candidates: Array[StatCardData] = []
	var total_weight: float = 0.0
	for card in deck:
		if card.tier == tier:
			candidates.append(card)
			total_weight += card.base_weight

	if candidates.is_empty():
		return deck.pick_random() if not deck.is_empty() else null

	var roll := randf() * total_weight
	var cumulative := 0.0
	for card in candidates:
		cumulative += card.base_weight
		if roll <= cumulative:
			return card
	return candidates[0]

func apply_card_to_stats(card: StatCardData, char_stats: CharacterStats) -> void:
	var m_type: Enums.ModifierType = card.get_effective_modifier_type() if card.has_method(&"get_effective_modifier_type") else (card.modifier_type if "modifier_type" in card else (Enums.ModifierType.ADDITIVE_PERCENT if card.is_percentage else Enums.ModifierType.FLAT))
	var mod := CharacterStats.StatModifier.new(
		card.card_id,
		card.modifier_value,
		m_type,
		card
	)
	char_stats.add_modifier(card.target_stat, mod)
	card_applied.emit(card)
