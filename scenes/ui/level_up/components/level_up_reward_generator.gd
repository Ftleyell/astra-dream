class_name LevelUpRewardGenerator
extends RefCounted

## LevelUpRewardGenerator.gd
## Generador data-driven de opciones para la subida de nivel:
## - Ofrece exclusivamente Armas (nuevas o mejoras) y Tomos de Atributos (nuevos o mejoras).
## - Si el jugador ya tiene 4 armas y 4 tomos equipados, el 100% de las opciones
##   son mejoras de nivel de las armas y tomos en curso.

const TomeCatalog = preload("res://data/tomes/tome_catalog.gd")
const TomeDataScript = preload("res://data/tomes/tome_data.gd")
const LevelUpRewardOption = preload("res://scenes/ui/level_up/components/level_up_reward_option.gd")
const WeaponCatalog = preload("res://data/weapons/weapon_catalog.gd")

static func generate_reward_options(
	player: CharacterBody2D,
	active_tome_ids: Array[StringName],
	count: int = 3,
	active_weapon_ids: Array[StringName] = []
) -> Array[LevelUpRewardOption]:
	var options: Array[LevelUpRewardOption] = []
	if not player or not is_instance_valid(player):
		return options

	var w_ctrl = player.get("weapon_controller")
	var t_ctrl = player.get("tome_controller")

	var equipped_weapons: Array = w_ctrl.equipped_weapons if w_ctrl else []
	var equipped_tomes: Array = t_ctrl.equipped_tomes if t_ctrl else []

	var num_weapons: int = equipped_weapons.size()
	var num_tomes: int = equipped_tomes.size()

	var candidates: Array[LevelUpRewardOption] = []

	var player_luck: float = 0.0
	if player.get("stats") and player.stats.has_method("get_stat"):
		player_luck = player.stats.get_stat(&"luck")

	# 1. Mejoras de Armas Equipadas (Infinitas con rareza escalada por Suerte)
	for inst in equipped_weapons:
		if not inst or not inst.weapon_data:
			continue
		var opt := LevelUpRewardOption.new()
		opt.type = LevelUpRewardOption.OptionType.WEAPON_UPGRADE
		opt.weapon_data = inst.weapon_data
		opt.current_level = inst.level
		opt.next_level = inst.level + 1
		opt.title = inst.weapon_data.weapon_name
		opt.icon = inst.weapon_data.icon
		opt.description = inst.weapon_data.description

		# Tirada de Rareza ponderada por suerte
		opt.tier = _roll_weapon_upgrade_tier(player_luck)
		match opt.tier:
			Enums.Tier.TIER_1:
				opt.subtitle = "• MEJORA ESTÁNDAR (Nvl. %d ➔ %d)" % [opt.current_level, opt.next_level]
				opt.badge_text = "+1 Proy. Extra | Potencia Calibrada (85% daño)"
			Enums.Tier.TIER_2:
				opt.subtitle = "• MEJORA MEJORADA (Nvl. %d ➔ %d)" % [opt.current_level, opt.next_level]
				opt.badge_text = "+1 Proy. Extra | Potencia Nominal (100% daño)"
			Enums.Tier.TIER_3:
				opt.subtitle = "• MEJORA AVANZADA (Nvl. %d ➔ %d)" % [opt.current_level, opt.next_level]
				opt.badge_text = "+1 Proy. Extra | Sobrecarga de Plasma (120% daño)"
			Enums.Tier.TIER_4:
				opt.subtitle = "• MEJORA LEGENDARIA (Nvl. %d ➔ %d)" % [opt.current_level, opt.next_level]
				opt.badge_text = "+1 Proy. Extra | Reactor Hipercrítico (145% daño)"
			_:
				opt.subtitle = "• MEJORA DE ARMA (Nvl. %d ➔ %d)" % [opt.current_level, opt.next_level]
				opt.badge_text = "+1 Proyectil Extra y +Daño escalado"
		candidates.append(opt)

	# 2. Nuevas Armas (si hay ranuras disponibles < 4)
	if num_weapons < 4:
		var all_weapons: Array[WeaponData] = WeaponCatalog.get_pool_weapons()
		var equipped_ids: Array[StringName] = []
		for inst in equipped_weapons:
			if inst and inst.weapon_data:
				equipped_ids.append(inst.weapon_data.weapon_id)

		for w in all_weapons:
			if not equipped_ids.has(w.weapon_id):
				if not active_weapon_ids.is_empty() and not active_weapon_ids.has(w.weapon_id):
					continue
				var opt := LevelUpRewardOption.new()
				opt.type = LevelUpRewardOption.OptionType.WEAPON_NEW
				opt.weapon_data = w
				opt.current_level = 0
				opt.next_level = 1
				opt.title = w.weapon_name
				opt.subtitle = "• NUEVA ARMA (Nivel 1)"
				opt.badge_text = "+Despliega una nueva salva en tu nave"
				opt.description = w.description
				opt.icon = w.icon
				opt.tier = Enums.Tier.TIER_1
				candidates.append(opt)

	# 3. Mejoras de Tomos Equipados
	if t_ctrl:
		for tome in equipped_tomes:
			if not tome:
				continue
			var cur_lvl: int = t_ctrl.get_tome_level(tome.tome_id)
			if tome.max_level <= 0 or cur_lvl < tome.max_level:
				var opt := LevelUpRewardOption.new()
				opt.type = LevelUpRewardOption.OptionType.TOME_UPGRADE
				opt.tome_data = tome
				opt.current_level = cur_lvl
				opt.next_level = cur_lvl + 1
				var stat_display: String = LevelUpStatsInspector.get_stat_display_name(tome.stat_name)
				opt.title = tome.display_name
				opt.subtitle = "• MEJORA DE TOMO (Nvl. %d ➔ %d)" % [opt.current_level, opt.next_level]
				opt.badge_text = "+%s %s (Efecto total)" % [stat_display, tome.get_bonus_description(opt.next_level)]
				opt.description = tome.description
				opt.icon = tome.icon
				opt.target_stat = tome.stat_name
				opt.tier = Enums.Tier.TIER_2
				candidates.append(opt)

	# 4. Nuevos Tomos (si hay ranuras disponibles < 4)
	if num_tomes < 4:
		var active_ids: Array[StringName] = active_tome_ids
		if active_ids.is_empty():
			active_ids = TomeCatalog.ALL_TOME_IDS
		var equipped_tome_ids: Array[StringName] = []
		if t_ctrl:
			for tome in equipped_tomes:
				if tome:
					equipped_tome_ids.append(tome.tome_id)

		for id in active_ids:
			if not equipped_tome_ids.has(id):
				var tome := TomeCatalog.load_tome(id)
				if tome:
					var opt := LevelUpRewardOption.new()
					opt.type = LevelUpRewardOption.OptionType.TOME_NEW
					opt.tome_data = tome
					opt.current_level = 0
					opt.next_level = 1
					var stat_display: String = LevelUpStatsInspector.get_stat_display_name(tome.stat_name)
					opt.title = tome.display_name
					opt.subtitle = "• NUEVO TOMO (Nivel 1)"
					opt.badge_text = "+%s %s por nivel" % [stat_display, tome.get_bonus_description(1)]
					opt.description = tome.description
					opt.icon = tome.icon
					opt.target_stat = tome.stat_name
					opt.tier = Enums.Tier.TIER_1
					candidates.append(opt)

	# Si candidates tiene opciones, barajar y extraer hasta `count`
	if not candidates.is_empty():
		candidates.shuffle()
		var picked_count: int = mini(count, candidates.size())
		for i in range(picked_count):
			options.append(candidates[i])

	return options


static func _roll_weapon_upgrade_tier(luck: float) -> Enums.Tier:
	# Probabilidades base: Tier 1 (Común 45%), Tier 2 (Poco común 35%), Tier 3 (Raro 15%), Tier 4 (Legendario 5%)
	# La suerte traslada peso de los tiers bajos a los tiers altos
	var roll: float = randf() * 100.0
	var luck_bonus: float = clampf(luck * 0.4, 0.0, 40.0)

	var leg_threshold: float = 5.0 + (luck_bonus * 0.35)
	var rare_threshold: float = leg_threshold + 15.0 + (luck_bonus * 0.40)
	var uncom_threshold: float = rare_threshold + 35.0

	if roll < leg_threshold:
		return Enums.Tier.TIER_4
	elif roll < rare_threshold:
		return Enums.Tier.TIER_3
	elif roll < uncom_threshold:
		return Enums.Tier.TIER_2
	else:
		return Enums.Tier.TIER_1
