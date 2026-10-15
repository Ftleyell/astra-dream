class_name RunStateSerializer
extends RefCounted

## Serializador y deserializador del estado completo de una Run de combate.
## Guarda armas equipadas, niveles, inventario, progreso de oleadas y rivales en SaveManager.

static func get_run_state(main_game: Node) -> Dictionary:
	var player: Player = main_game.get("player") as Player
	if not is_instance_valid(player) or player.current_health <= 0.0:
		return {}

	var pilot_id: String = String(player.character_data.character_id) if player.character_data and player.character_data.character_id else "nova"
	var pilot_name: String = player.character_data.display_name if player.character_data and player.character_data.display_name != "" else "Piloto Estelar"

	# Armas equipadas
	var weapons_data: Array[Dictionary] = []
	var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
	if w_ctrl:
		for inst: WeaponInstanceData in w_ctrl.equipped_weapons:
			if inst.weapon_data:
				weapons_data.append({
					"id": String(inst.weapon_data.weapon_id),
					"level": inst.level,
					"upgrade_tier": int(inst.upgrade_tier),
					"tier_damage_multiplier": float(inst.tier_damage_multiplier)
				})

	# Ítems de inventario
	var items_data: Array[Dictionary] = []
	if player.inventory:
		for it_entry: Dictionary in player.inventory.get_all_items():
			var it_res: ItemData = it_entry.get("data") as ItemData
			if it_res:
				items_data.append({
					"id": String(it_res.item_id),
					"count": int(it_entry.get("count", 1)),
					"origin": String(it_entry.get("origin", "DESCONOCIDO"))
				})

	# Cartas de nivel (Brotato)
	var cards_data: Array[String] = []
	for card: StatCardData in player.chosen_stat_cards:
		cards_data.append(String(card.card_id))

	# Tomos de atributos equipados
	var tomes_state: Dictionary = {}
	if player.tome_controller and player.tome_controller.has_method("serialize"):
		tomes_state = player.tome_controller.serialize()

	# Modificadores activos de Run (Bifurcaciones)
	var run_modifiers: Array[Dictionary] = []
	var rmm: Node = main_game.get("run_modifier_manager") as Node
	if not rmm and "combat_context" in main_game and main_game.combat_context:
		rmm = main_game.combat_context.run_modifier_manager
	if rmm and rmm.has_method("serialize_active_modifiers"):
		run_modifiers = rmm.serialize_active_modifiers()

	var enc_ctrl: CombatEncounterController = main_game.encounter_controller if "encounter_controller" in main_game else null
	var loot_coord: CombatLootCoordinator = main_game.loot_coordinator if "loot_coordinator" in main_game else null

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
		"equipped_tomes": tomes_state.get("equipped_tomes", []),
		"tome_controller": tomes_state,
		"chosen_stat_cards": cards_data,
		"run_modifiers": run_modifiers,
		"rivals_spared": enc_ctrl.rivals_spared.duplicate() if enc_ctrl else [],
		"rivals_killed": enc_ctrl.rivals_killed.duplicate() if enc_ctrl else [],
		"rival_queue": enc_ctrl.rival_queue.duplicate() if enc_ctrl else [],
		"_wave_encounter_checked_for_wave": enc_ctrl.wave_encounter_checked_for_wave if enc_ctrl else 0,
		"_wave_encounter_spawned_for_wave": enc_ctrl.wave_encounter_spawned_for_wave if enc_ctrl else 0,
		"_slot_machine_pity_chance": float(loot_coord.pity_chance) if loot_coord else 0.25,
		"paid_chests_count": main_game.chest_director.paid_chests_count if ("chest_director" in main_game and main_game.chest_director) else 0,
		"run_seed": int(main_game.get("run_seed")) if main_game.get("run_seed") != null else 0
	}

static func save_run_state(main_game: Node) -> void:
	var state := get_run_state(main_game)
	if not state.is_empty():
		SaveManager.save_active_run(state)

static func restore_run_state(main_game: Node, run_data: Dictionary) -> void:
	# 1. Variables de oleada y progresión global
	if run_data.has("run_seed"):
		main_game.set("run_seed", int(run_data["run_seed"]))
	if "wave_pipeline" in main_game and main_game.wave_pipeline:
		main_game.wave_pipeline.is_pre_round = false
	main_game.set("is_pre_round", false)
	main_game.set("current_wave", int(run_data.get("current_wave", 1)))
	main_game.set("wave_timer", float(run_data.get("wave_timer", 30.0)))

	main_game.set("wave_satellites_spawned", int(run_data.get("wave_satellites_spawned", 0)))
	main_game.set("satellites_collected_total", int(run_data.get("satellites_collected_total", 0)))
	main_game.set("current_satellite_idx", int(run_data.get("current_satellite_idx", 1)))
	main_game.set("run_time_elapsed", float(run_data.get("run_time_elapsed", 0.0)))
	main_game.set("enemies_killed_count", int(run_data.get("enemies_killed_count", 0)))
	main_game.set("bosses_defeated_count", int(run_data.get("bosses_defeated_count", 0)))
	main_game.set("prologue_bonus_chosen", bool(run_data.get("prologue_bonus_chosen", true)))

	var enc_ctrl: CombatEncounterController = main_game.encounter_controller if "encounter_controller" in main_game else null
	if enc_ctrl:
		var def_wave: int = int(run_data.get("current_wave", 1))
		enc_ctrl.wave_encounter_checked_for_wave = int(run_data.get("_wave_encounter_checked_for_wave", def_wave))
		enc_ctrl.wave_encounter_spawned_for_wave = int(run_data.get("_wave_encounter_spawned_for_wave", def_wave))
		enc_ctrl.wave_encounter_pending = false
		if run_data.has("rivals_spared"):
			enc_ctrl.rivals_spared.clear()
			for s: Variant in run_data["rivals_spared"]:
				enc_ctrl.rivals_spared.append(StringName(str(s)))
		if run_data.has("rivals_killed"):
			enc_ctrl.rivals_killed.clear()
			for k: Variant in run_data["rivals_killed"]:
				enc_ctrl.rivals_killed.append(StringName(str(k)))
		if run_data.has("rival_queue"):
			enc_ctrl.rival_queue.clear()
			for q: Variant in run_data["rival_queue"]:
				enc_ctrl.rival_queue.append(StringName(str(q)))

	var loot_coord: CombatLootCoordinator = main_game.loot_coordinator if "loot_coordinator" in main_game else null
	if loot_coord:
		var pity_val: Variant = run_data.get("_slot_machine_pity_chance")
		loot_coord.pity_chance = float(pity_val) if pity_val != null else 0.25

	var player: Player = main_game.get("player") as Player
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
	for arc_id: Variant in saved_arcanas:
		var arc: ArcanaData = ArcanaData.get_arcana(String(arc_id))
		if arc:
			player.apply_arcana(arc)

	# 3. Restaurar cartas de nivel elegidas (Brotato)
	player.chosen_stat_cards.clear()
	var saved_cards: Array = run_data.get("chosen_stat_cards", [])
	var stat_deck: StatDeckManager = main_game.get("stat_deck_manager") as StatDeckManager
	if stat_deck and "all_stat_cards" in stat_deck:
		var card_map: Dictionary = {}
		for card: StatCardData in stat_deck.all_stat_cards:
			card_map[String(card.card_id)] = card
		for cid: Variant in saved_cards:
			var s_cid := String(cid)
			if card_map.has(s_cid):
				var card_res: StatCardData = card_map[s_cid]
				player.chosen_stat_cards.append(card_res)
				stat_deck.apply_card_to_stats(card_res, player.stats)

	# 3b. Restaurar tomos de atributos equipados
	if player.tome_controller and player.tome_controller.has_method("deserialize"):
		if run_data.has("tome_controller") and run_data["tome_controller"] is Dictionary:
			player.tome_controller.deserialize(run_data["tome_controller"] as Dictionary)
		else:
			player.tome_controller.deserialize(run_data)

	# 4. Restaurar ítems adquiridos en inventario
	if player.inventory:
		player.inventory.clear_items()
		var saved_items: Array = run_data.get("equipped_items", [])
		var item_map: Dictionary = {}
		for it: ItemData in ItemPoolManager.create_canonical_stat_items():
			item_map[String(it.item_id)] = it
		for it: ItemData in ItemPoolManager.create_satellite_shop_items():
			item_map[String(it.item_id)] = it
		for it_entry: Variant in saved_items:
			if not (it_entry is Dictionary):
				continue
			var it_dict: Dictionary = it_entry as Dictionary
			var i_id: String = String(it_dict.get("id", ""))
			var i_count: int = int(it_dict.get("count", 1))
			var i_origin: String = String(it_dict.get("origin", "DESCONOCIDO"))
			if item_map.has(i_id):
				player.inventory.add_item(item_map[i_id], i_count, i_origin)

	if "chest_director" in main_game and main_game.chest_director:
		if run_data.has("paid_chests_count"):
			main_game.chest_director.paid_chests_count = int(run_data["paid_chests_count"])
		var restored_wave: int = int(run_data.get("current_wave", 1))
		var green_cards: int = player.inventory.get_item_count(&"credit_card_green") if player.inventory else 0
		main_game.chest_director.on_new_wave(restored_wave, green_cards)

	# 5. Restaurar armas equipadas y sus niveles
	var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
	var saved_weapons: Array = run_data.get("equipped_weapons", [])
	if w_ctrl and not saved_weapons.is_empty():
		w_ctrl.clear_equipped_weapons()
		for w_entry: Variant in saved_weapons:
			if not (w_entry is Dictionary):
				continue
			var w_dict: Dictionary = w_entry as Dictionary
			var w_id: String = str(w_dict.get("id", ""))
			var w_lvl: int = maxi(1, int(w_dict.get("level", 1)))
			var w_res: WeaponData = WeaponCatalog.get_weapon_by_id(StringName(w_id))
			if w_res:
				w_ctrl.add_weapon(w_res)
				var inst: WeaponInstanceData = w_ctrl.get_weapon_instance(StringName(w_id))
				if inst:
					inst.level = w_lvl
					inst.upgrade_tier = int(w_dict.get("upgrade_tier", Enums.Tier.TIER_2)) as Enums.Tier
					inst.tier_damage_multiplier = float(w_dict.get("tier_damage_multiplier", 1.0))
		w_ctrl.weapons_updated.emit(w_ctrl.equipped_weapons)

	# 6. Restaurar salud
	player.current_health = minf(float(run_data.get("player_health", 100.0)), player.stats.get_stat(&"max_health"))
	main_game.set("_last_player_hp", player.current_health)

	# 7. Actualizar todo el HUD
	var hud: GameHUD = main_game.get("hud") as GameHUD
	if hud:
		hud.update_credits(player.run_credits)
		hud.update_exp(player.current_exp, player.exp_to_next, player.current_level)
		hud.update_wave_status(main_game.get("current_wave"), main_game.get("wave_timer"), main_game.get("wave_satellites_spawned"), 1)
		player.health_changed.emit(player.current_health, player.stats.get_stat(&"max_health"))
		player.bomb_used.emit(player.bomb_count)

	# 8. Restaurar modificadores activos de Run (Bifurcaciones)
	if run_data.has("run_modifiers"):
		var rmm: Node = main_game.get("run_modifier_manager") as Node
		if not rmm and "combat_context" in main_game and main_game.combat_context:
			rmm = main_game.combat_context.run_modifier_manager
		if rmm and rmm.has_method("restore_active_modifiers"):
			rmm.restore_active_modifiers(run_data["run_modifiers"])


