class_name PlayerProgressionApplier
extends RefCounted

## PlayerProgressionApplier.gd
## Aplicador modular de bonificaciones permanentes del Árbol de Talentos y Sala de Trofeos al jugador.
## Desacopla la inyección de modificadores de estadísticas en CharacterStats durante el arranque de la run.

const CharacterStatsClass = preload("res://core/types/character_stats.gd")


func apply_skill_tree_bonuses(
	player: CharacterBody2D,
	stats: CharacterStats,
	character_data: CharacterData
) -> void:
	if not player or not stats or not character_data or not character_data.character_id:
		return

	var unlocked_nodes := SaveManager.get_character_unlocked_nodes(character_data.character_id)

	if character_data.character_id == &"nyx":
		var nyx_speed: int = 0
		var nyx_dmg: int = 0
		var nyx_hp: int = 0
		var nyx_crit: int = 0
		var has_speed_3: bool = false
		var has_dmg_3: bool = false
		var has_hp_3: bool = false
		var has_crit_3: bool = false

		for nid in unlocked_nodes:
			var s := String(nid)
			if s.begins_with("nyx_speed_") or s.begins_with("speed_"):
				nyx_speed += 1
				if s == "nyx_speed_3": has_speed_3 = true
			elif s.begins_with("nyx_dmg_") or s.begins_with("damage_"):
				nyx_dmg += 1
				if s == "nyx_dmg_3": has_dmg_3 = true
			elif s.begins_with("nyx_hp_") or s.begins_with("hp_"):
				nyx_hp += 1
				if s == "nyx_hp_3": has_hp_3 = true
			elif s.begins_with("nyx_crit_") or s.begins_with("crit_"):
				nyx_crit += 1
				if s == "nyx_crit_3": has_crit_3 = true

		if nyx_speed > 0:
			stats.add_modifier(&"move_speed", CharacterStatsClass.StatModifier.new(&"skill_tree_speed", float(nyx_speed) * 0.18, true, player))
		if has_speed_3 and "dash_recharge_max" in player:
			player.dash_recharge_max *= 0.85
		if nyx_dmg > 0:
			stats.add_modifier(&"base_damage", CharacterStatsClass.StatModifier.new(&"skill_tree_damage", float(nyx_dmg) * 0.18, true, player))
		if has_dmg_3:
			stats.add_modifier(&"weapon_size", CharacterStatsClass.StatModifier.new(&"nyx_weapon_size", 0.15, true, player))
		if nyx_hp > 0:
			stats.add_modifier(&"max_health", CharacterStatsClass.StatModifier.new(&"skill_tree_hp", float(nyx_hp) * 30.0, false, player))
		if has_hp_3:
			stats.add_modifier(&"health_regen", CharacterStatsClass.StatModifier.new(&"nyx_regen", 1.0, false, player))
		if nyx_crit > 0:
			stats.add_modifier(&"crit_chance", CharacterStatsClass.StatModifier.new(&"skill_tree_crit", float(nyx_crit) * 0.06, false, player))
			stats.add_modifier(&"attack_speed", CharacterStatsClass.StatModifier.new(&"skill_tree_atk_speed", float(nyx_crit) * 0.06, true, player))
		if has_crit_3:
			stats.add_modifier(&"crit_damage", CharacterStatsClass.StatModifier.new(&"nyx_crit_dmg", 0.20, false, player))
	else:
		var speed_count: int = 0
		var damage_count: int = 0
		var hp_count: int = 0
		var crit_count: int = 0

		for nid in unlocked_nodes:
			var s := String(nid)
			if s.begins_with("speed_") or s in ["0", "1", "2", "3", "4"]:
				speed_count += 1
			elif s.begins_with("damage_"):
				damage_count += 1
			elif s.begins_with("hp_") or s.begins_with("hull_"):
				hp_count += 1
			elif s.begins_with("crit_") or s.begins_with("overclock_") or s.begins_with("focus_"):
				crit_count += 1

		if speed_count > 0:
			stats.add_modifier(&"move_speed", CharacterStatsClass.StatModifier.new(&"skill_tree_speed", float(speed_count) * 0.20, true, player))
		if damage_count > 0:
			stats.add_modifier(&"base_damage", CharacterStatsClass.StatModifier.new(&"skill_tree_damage", float(damage_count) * 0.15, true, player))
		if hp_count > 0:
			stats.add_modifier(&"max_health", CharacterStatsClass.StatModifier.new(&"skill_tree_hp", float(hp_count) * 25.0, false, player))
		if crit_count > 0:
			stats.add_modifier(&"crit_chance", CharacterStatsClass.StatModifier.new(&"skill_tree_crit", float(crit_count) * 0.05, false, player))
			stats.add_modifier(&"attack_speed", CharacterStatsClass.StatModifier.new(&"skill_tree_atk_speed", float(crit_count) * 0.05, true, player))


func apply_trophy_bonuses(stats: CharacterStats) -> void:
	if not stats:
		return
	var trophy_bonuses := SaveManager.get_trophy_passive_bonuses()
	if trophy_bonuses.get("base_damage_pct", 0.0) > 0.0:
		stats.add_modifier(&"base_damage", CharacterStatsClass.StatModifier.new(&"trophy_damage", trophy_bonuses["base_damage_pct"], true, "trophy"))
	if trophy_bonuses.get("max_health", 0.0) > 0.0:
		stats.add_modifier(&"max_health", CharacterStatsClass.StatModifier.new(&"trophy_hp", trophy_bonuses["max_health"], false, "trophy"))
	if trophy_bonuses.get("move_speed_pct", 0.0) > 0.0:
		stats.add_modifier(&"move_speed", CharacterStatsClass.StatModifier.new(&"trophy_speed", trophy_bonuses["move_speed_pct"], true, "trophy"))
	if trophy_bonuses.get("credits_bonus_pct", 0.0) > 0.0:
		stats.add_modifier(&"credits_multiplier", CharacterStatsClass.StatModifier.new(&"trophy_credits", trophy_bonuses["credits_bonus_pct"], true, "trophy"))
