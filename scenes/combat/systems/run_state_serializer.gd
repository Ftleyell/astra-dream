class_name RunStateSerializer
extends RefCounted

## Serializador y deserializador del estado completo de una Run de combate.
## Guarda armas equipadas, niveles, inventario, progreso de oleadas y rivales en SaveManager.

static func get_run_state(main_game: Node) -> Dictionary:
	var player = main_game.get("player")
	if not is_instance_valid(player) or player.current_health <= 0.0:
		return {}

	var pilot_id: String = String(player.character_data.character_id) if player.character_data and player.character_data.character_id else "nova"
	var pilot_name: String = player.character_data.display_name if player.character_data and player.character_data.display_name != "" else "Piloto Estelar"

	# Armas equipadas
	var weapons_data: Array[Dictionary] = []
	var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
	if w_ctrl:
		for inst in w_ctrl.equipped_weapons:
			if inst.weapon_data:
				weapons_data.append({
					"id": String(inst.weapon_data.weapon_id),
					"level": inst.level
				})

	# Ítems de inventario
	var items_data: Array[Dictionary] = []
	if player.inventory:
		for it_entry in player.inventory.get_all_items():
			var it_res: ItemData = it_entry.get("data")
			if it_res:
				items_data.append({
					"id": String(it_res.item_id),
					"count": int(it_entry.get("count", 1))
				})

	# Cartas de nivel (Brotato)
	var cards_data: Array[String] = []
	for card in player.chosen_stat_cards:
		cards_data.append(String(card.card_id))

	return {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"pilot_id": pilot_id,
		"pilot_name": pilot_name,
		"current_wave": main_game.get("current_wave"),
		"wave_timer": main_game.get("wave_timer"),
		"wave_satellites_spawned": main_game.get("wave_satellites_spawned"),
		"satellites_collected_total": main_game.get("satellites_collected_total"),
		"current_satellite_idx": main_game.get("current_satellite_idx"),
		"run_time_elapsed": main_game.get("run_time_elapsed"),
		"enemies_killed_count": main_game.get("enemies_killed_count"),
		"bosses_defeated_count": main_game.get("bosses_defeated_count"),
		"prologue_bonus_chosen": main_game.get("prologue_bonus_chosen"),
		"player_health": player.current_health,
		"player_level": player.current_level,
		"player_exp": player.current_exp,
		"player_exp_to_next": player.exp_to_next,
		"run_credits": player.run_credits,
		"run_biomass": player.run_biomass,
		"run_dark_matter": player.run_dark_matter if "run_dark_matter" in player else 0,
		"active_arcanas": player.get_arcana_ids() if player.has_method("get_arcana_ids") else [],
		"bomb_count": player.bomb_count,
		"equipped_weapons": weapons_data,
		"equipped_items": items_data,
		"chosen_stat_cards": cards_data,
		"rivals_spared": main_game.get("rivals_spared").duplicate() if main_game.get("rivals_spared") else [],
		"rivals_killed": main_game.get("rivals_killed").duplicate() if main_game.get("rivals_killed") else [],
		"rival_queue": main_game.get("rival_queue").duplicate() if main_game.get("rival_queue") else [],
		"_wave_encounter_checked_for_wave": main_game.get("_wave_encounter_checked_for_wave"),
		"_wave_encounter_spawned_for_wave": main_game.get("_wave_encounter_spawned_for_wave"),
		"_slot_machine_pity_chance": main_game.get("_slot_machine_pity_chance"),
		"paid_chests_count": main_game.chest_director.paid_chests_count if ("chest_director" in main_game and main_game.chest_director) else 0
	}

static func save_run_state(main_game: Node) -> void:
	var state := get_run_state(main_game)
	if not state.is_empty():
		SaveManager.save_active_run(state)

static func restore_run_state(main_game: Node, run_data: Dictionary) -> void:
	# 1. Variables de oleada y progresión global
	main_game.set("current_wave", int(run_data.get("current_wave", 1)))
	main_game.set("wave_timer", float(run_data.get("wave_timer", 30.0)))
	main_game.set("wave_satellites_spawned", int(run_data.get("wave_satellites_spawned", 0)))
	main_game.set("satellites_collected_total", int(run_data.get("satellites_collected_total", 0)))
	main_game.set("current_satellite_idx", int(run_data.get("current_satellite_idx", 1)))
	main_game.set("run_time_elapsed", float(run_data.get("run_time_elapsed", 0.0)))
	main_game.set("enemies_killed_count", int(run_data.get("enemies_killed_count", 0)))
	main_game.set("bosses_defeated_count", int(run_data.get("bosses_defeated_count", 0)))
	main_game.set("prologue_bonus_chosen", bool(run_data.get("prologue_bonus_chosen", true)))
	main_game.set("_wave_encounter_checked_for_wave", int(run_data.get("_wave_encounter_checked_for_wave", main_game.get("current_wave"))))
	main_game.set("_wave_encounter_spawned_for_wave", int(run_data.get("_wave_encounter_spawned_for_wave", main_game.get("current_wave"))))
	main_game.set("_slot_machine_pity_chance", float(run_data.get("_slot_machine_pity_chance", 0.25)))
	main_game.set("_wave_encounter_pending", false)
	if "chest_director" in main_game and main_game.chest_director:
		if run_data.has("paid_chests_count"):
			main_game.chest_director.paid_chests_count = int(run_data["paid_chests_count"])
		var restored_wave: int = int(run_data.get("current_wave", 1))
		var green_cards: int = 0
		var p_node = main_game.get("player")
		if p_node and "inventory" in p_node and p_node.inventory:
			green_cards = p_node.inventory.get_item_count(&"credit_card_green")
		main_game.chest_director.on_new_wave(restored_wave, green_cards)

	if run_data.has("rivals_spared"):
		var rivals_spared: Array = main_game.get("rivals_spared")
		rivals_spared.clear()
		for s in run_data["rivals_spared"]:
			rivals_spared.append(StringName(s))
	if run_data.has("rivals_killed"):
		var rivals_killed: Array = main_game.get("rivals_killed")
		rivals_killed.clear()
		for k in run_data["rivals_killed"]:
			rivals_killed.append(StringName(k))
	if run_data.has("rival_queue"):
		var rival_queue: Array = main_game.get("rival_queue")
		rival_queue.clear()
		for q in run_data["rival_queue"]:
			rival_queue.append(StringName(q))

	var player = main_game.get("player")
	if not is_instance_valid(player):
		return

	player.current_level = int(run_data.get("player_level", 1))
	player.current_exp = float(run_data.get("player_exp", 0.0))
	player.exp_to_next = float(run_data.get("player_exp_to_next", 40.0))
	player.run_credits = int(run_data.get("run_credits", 0))
	player.run_biomass = int(run_data.get("run_biomass", 0))
	if "run_dark_matter" in player:
		player.run_dark_matter = int(run_data.get("run_dark_matter", 0))
	player.bomb_count = int(run_data.get("bomb_count", 2))

	# 2. Restaurar arcanas activas
	var saved_arcanas: Array = run_data.get("active_arcanas", [])
	for arc_id in saved_arcanas:
		var arc: ArcanaData = ArcanaData.get_arcana(String(arc_id))
		if arc:
			player.apply_arcana(arc)

	# 3. Restaurar cartas de nivel elegidas (Brotato)
	player.chosen_stat_cards.clear()
	var saved_cards: Array = run_data.get("chosen_stat_cards", [])
	var stat_deck = main_game.get("stat_deck_manager")
	if stat_deck and "all_stat_cards" in stat_deck:
		var card_map: Dictionary = {}
		for card in stat_deck.all_stat_cards:
			card_map[String(card.card_id)] = card
		for cid in saved_cards:
			var s_cid := String(cid)
			if card_map.has(s_cid):
				var card_res: StatCardData = card_map[s_cid]
				player.chosen_stat_cards.append(card_res)
				stat_deck.apply_card_to_stats(card_res, player.stats)

	# 4. Restaurar ítems adquiridos en inventario
	if player.inventory:
		player.inventory.clear_items()
		var saved_items: Array = run_data.get("equipped_items", [])
		var item_map: Dictionary = {}
		for it in ItemPoolManager.create_canonical_stat_items():
			item_map[String(it.item_id)] = it
		for it_entry in saved_items:
			var i_id: String = String(it_entry.get("id", ""))
			var i_count: int = int(it_entry.get("count", 1))
			if item_map.has(i_id):
				player.inventory.add_item(item_map[i_id], i_count)

	# 5. Restaurar armas equipadas y sus niveles
	var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
	var saved_weapons: Array = run_data.get("equipped_weapons", [])
	if w_ctrl and not saved_weapons.is_empty():
		w_ctrl.clear_equipped_weapons()
		var weapon_catalog: Dictionary = {
			"rail_launcher": "res://data/weapons/roster/rail_launcher.tres",
			"hive_cannon": "res://data/weapons/roster/hive_cannon.tres",
			"singularity_pulsar": "res://data/weapons/roster/singularity_pulsar.tres",
			"sniper_rifle": "res://data/weapons/roster/sniper_rifle.tres",
			"tesla_arc": "res://data/weapons/roster/tesla_arc.tres",
			"titan_shotgun": "res://data/weapons/roster/titan_shotgun.tres",
			"cluster_submunition": "res://data/weapons/shop/cluster_submunition.tres",
			"dimensional_blade": "res://data/weapons/shop/dimensional_blade.tres",
			"nova_flak": "res://data/weapons/shop/nova_flak.tres",
			"solar_beam": "res://data/weapons/shop/solar_beam.tres",
		}
		for w_entry in saved_weapons:
			var w_id: String = str(w_entry.get("id", ""))
			var w_lvl: int = int(w_entry.get("level", 1))
			if weapon_catalog.has(w_id) and ResourceLoader.exists(weapon_catalog[w_id]):
				var w_res = load(weapon_catalog[w_id]) as WeaponData
				if w_res:
					w_ctrl.add_weapon(w_res)
					for _l in range(2, w_lvl + 1):
						w_ctrl.upgrade_weapon(StringName(w_id))

	# 6. Restaurar salud
	player.current_health = minf(float(run_data.get("player_health", 100.0)), player.stats.get_stat(&"max_health"))
	main_game.set("_last_player_hp", player.current_health)

	# 7. Actualizar todo el HUD
	var hud = main_game.get("hud")
	if hud:
		hud.update_credits(player.run_credits)
		hud.update_exp(player.current_exp, player.exp_to_next, player.current_level)
		hud.update_wave_status(main_game.get("current_wave"), main_game.get("wave_timer"), main_game.get("wave_satellites_spawned"), 1)
		player.health_changed.emit(player.current_health, player.stats.get_stat(&"max_health"))
		player.bomb_used.emit(player.bomb_count)
