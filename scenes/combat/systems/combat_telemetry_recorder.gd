class_name CombatTelemetryRecorder
extends RefCounted

## Grabador desacoplado de telemetría, recopilación de armamento y cálculo de
## puntuación final/carrera para las pantallas de Victoria y Game Over.

static func collect_weapons_summary(player: Node2D) -> Array:
	var weapons_summary: Array = []
	if not is_instance_valid(player):
		return weapons_summary
	var w_ctrl: WeaponController = player.get_node_or_null("WeaponController") as WeaponController
	if w_ctrl:
		for inst in w_ctrl.equipped_weapons:
			if inst and inst.weapon_data:
				var w_dname: String = ""
				if inst.weapon_data.has_method("get_display_name"):
					w_dname = inst.weapon_data.get_display_name()
				elif "weapon_name" in inst.weapon_data and not inst.weapon_data.weapon_name.is_empty():
					w_dname = inst.weapon_data.weapon_name
				else:
					w_dname = WeaponData.get_stylized_name_for_id(str(inst.weapon_data.weapon_id))

				weapons_summary.append({
					"name": w_dname,
					"id": str(inst.weapon_data.weapon_id),
					"level": inst.level,
					"icon": inst.weapon_data.icon if "icon" in inst.weapon_data else null
				})
	return weapons_summary

static func build_end_of_run_data(main_game: Node2D, is_victory: bool, route: String = "neutral") -> Dictionary:
	var player: Node2D = main_game.get("player")
	var run_time_elapsed: float = float(main_game.get("run_time_elapsed"))
	var enemies_killed_count: int = int(main_game.get("enemies_killed_count"))
	var current_wave: int = int(main_game.get("current_wave"))
	var bosses_defeated_count: int = int(main_game.get("bosses_defeated_count"))
	var satellites_collected_total: int = int(main_game.get("satellites_collected_total"))

	var minutes: int = int(run_time_elapsed) / 60
	var seconds: int = int(run_time_elapsed) % 60
	var time_str: String = "%02d:%02d" % [minutes, seconds]

	var pilot_id: String = "nova"
	var pilot_name: String = "Piloto Estelar"
	if is_instance_valid(player) and player.get("character_data"):
		var c_data = player.get("character_data")
		if "character_id" in c_data and c_data.character_id:
			pilot_id = String(c_data.character_id)
		if "display_name" in c_data and not c_data.display_name.is_empty():
			pilot_name = c_data.display_name

	var player_credits: int = int(player.get("run_credits")) if is_instance_valid(player) else 0
	var player_biomass: int = int(player.get("run_biomass")) if is_instance_valid(player) else 0
	var player_dark_matter: int = int(player.get("run_dark_matter")) if is_instance_valid(player) else 0

	var final_score: int = 0
	if is_victory:
		final_score = int((enemies_killed_count * 50) + (current_wave * 1500) + (bosses_defeated_count * 8000) + (player_credits * 15) + int(run_time_elapsed * 25))
	else:
		final_score = int((enemies_killed_count * 50) + (current_wave * 1000) + (bosses_defeated_count * 5000) + (player_credits * 10) + int(run_time_elapsed * 20))

	var rank: int = SaveManager.record_run_score({
		"pilot_id": pilot_id,
		"pilot_name": pilot_name,
		"wave_reached": current_wave,
		"time_survived_seconds": run_time_elapsed,
		"time_survived_formatted": time_str,
		"enemies_killed": enemies_killed_count,
		"credits_earned": player_credits,
		"victory": is_victory,
		"score": final_score
	})

	SaveManager.record_career_run_end({
		"time_survived": run_time_elapsed,
		"credits_earned": player_credits,
		"biomass_earned": player_biomass,
		"enemies_killed": enemies_killed_count,
		"satellites_collected": satellites_collected_total,
		"victory": is_victory
	})

	SaveManager.clear_active_run()

	var weapons_summary: Array = collect_weapons_summary(player)

	var ending_title: String = ""
	var epilogue: String = ""
	if is_victory:
		SaveManager.record_ending(route)
		var tokens_awarded: int = 3 if (route == "pacifist" or route == "slayer") else 1
		SaveManager.add_gacha_tokens(tokens_awarded)

		ending_title = "FINAL NEUTRAL: EQUILIBRIO FRAGMENTADO"
		epilogue = "Sobreviviste tomando decisiones pragmáticas. El orden cósmico permanece en una frágil calma."
		if route == "pacifist":
			ending_title = "FINAL PACIFISTA: FLOTA DE LA ESPERANZA"
			epilogue = "Las 5 pilotos perdonadas se unieron a tu vuelo, liberando el Núcleo Astra y salvando la galaxia."
		elif route == "slayer":
			ending_title = "FINAL EXTERMINADOR: EL LOBO SOLITARIO"
			epilogue = "Erradicaste a todas las rivales y absorbiste sus armas. Ahora reinas como el soberano absoluto del vacío."

	var res_data: Dictionary = {
		"score": final_score,
		"is_new_highscore": (rank == 1),
		"rank": rank,
		"pilot_name": pilot_name,
		"pilot_id": pilot_id,
		"waves_survived": current_wave,
		"time_survived_seconds": run_time_elapsed,
		"time_formatted": time_str,
		"bosses_defeated": bosses_defeated_count,
		"enemies_killed": enemies_killed_count,
		"biomass_collected": player_biomass,
		"dark_matter_collected": player_dark_matter,
		"credits_collected": player_credits,
		"arcanas": player.get("active_arcanas").duplicate() if (is_instance_valid(player) and "active_arcanas" in player) else [],
		"items": player.inventory.get_all_items() if (is_instance_valid(player) and "inventory" in player and player.inventory) else [],
		"weapons": weapons_summary,
		"victory": is_victory
	}

	if is_victory:
		res_data["ending_type"] = route
		res_data["ending_title"] = ending_title
		res_data["epilogue_text"] = epilogue

	return res_data
