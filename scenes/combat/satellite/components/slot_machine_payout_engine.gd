class_name SlotMachinePayoutEngine
extends RefCounted

## Motor de evaluación y aplicación de premios para SlotMachineBeacon.
## Responsabilidad única: lógica matemática de combinación de rodillos y
## ejecución de los efectos de recompensas (créditos, bombas, imán, curación).

const ExpBlobScript = preload("res://scenes/combat/pickups/exp_blob.gd")

static func roll_symbols(symbols: Array[String], jackpot_chance: float, pair_chance: float) -> Array[String]:
	var roll: float = randf()
	var s1: String = "💰"
	var s2: String = "💰"
	var s3: String = "💰"

	if roll < jackpot_chance:
		var sym: String = symbols[randi() % symbols.size()]
		s1 = sym
		s2 = sym
		s3 = sym
	elif roll < pair_chance:
		var sym: String = symbols[randi() % symbols.size()]
		s1 = sym
		s2 = sym
		var other: String = symbols[randi() % symbols.size()]
		while other == sym:
			other = symbols[randi() % symbols.size()]
		s3 = other
		if randf() > 0.5:
			var tmp: String = s2
			s2 = s3
			s3 = tmp
	else:
		var shuffled: Array[String] = symbols.duplicate()
		shuffled.shuffle()
		s1 = shuffled[0]
		s2 = shuffled[1]
		s3 = shuffled[2]

	return [s1, s2, s3]

static func evaluate_payout(symbols: Array, spin_cost: int = 50) -> Dictionary:
	if symbols.size() < 3:
		return { "type": "none", "credits": 0, "bombs": 0, "magnet": false, "heal": false }
	var s1: String = str(symbols[0])
	var s2: String = str(symbols[1])
	var s3: String = str(symbols[2])
	var is_jackpot: bool = (s1 == s2 and s2 == s3)
	var is_pair: bool = (s1 == s2 or s2 == s3 or s1 == s3)

	if is_jackpot:
		if s1 == "💰" or s1 == "gold":
			return { "type": "jackpot", "credits": spin_cost * 5, "bombs": 0, "magnet": false, "heal": false }
		elif s1 == "💣" or s1 == "bomb":
			return { "type": "bomb", "credits": 0, "bombs": 2, "magnet": false, "heal": false }
		elif s1 == "🧲" or s1 == "magnet":
			return { "type": "magnet", "credits": 0, "bombs": 0, "magnet": true, "heal": false }
		elif s1 == "💖" or s1 == "heart":
			return { "type": "heal", "credits": 0, "bombs": 0, "magnet": false, "heal": true }
		else:
			return { "type": "jackpot", "credits": spin_cost * 5, "bombs": 0, "magnet": false, "heal": false }
	elif is_pair:
		return { "type": "pair", "credits": spin_cost, "bombs": 0, "magnet": false, "heal": false }
	else:
		return { "type": "none", "credits": 0, "bombs": 0, "magnet": false, "heal": false }

static func apply_payout(
	payout: Dictionary,
	player: Player,
	tree: SceneTree,
	beacon_node: Node2D,
	marquee: Node2D,
	current_spin_cost: int
) -> void:
	var p_type: String = str(payout.get("type", "none"))
	match p_type:
		"jackpot":
			var credits: int = int(payout.get("credits", 250))
			player.run_credits += credits
			var main_scene: Node = tree.current_scene if tree else null
			if main_scene and "hud" in main_scene and main_scene.hud:
				main_scene.hud.update_credits(player.run_credits)
			marquee.spawn_floating_text(beacon_node, "🎉 ¡JACKPOT! +%d CRÉDITOS" % credits, Color(1.0, 0.85, 0.2))
			marquee.show_flash_msg("🎉 ¡JACKPOT! +%d CR" % credits, Color(1.0, 0.85, 0.2))
		"bomb":
			player.bomb_count = mini(5, player.bomb_count + 2)
			player.bomb_used.emit(player.bomb_count)
			marquee.spawn_floating_text(beacon_node, "💣 ¡+2 BOMBAS TÁCTICAS!", Color(1.0, 0.45, 0.2))
			marquee.show_flash_msg("💣 ¡+2 BOMBAS!", Color(1.0, 0.45, 0.2))
		"magnet":
			if tree:
				ExpBlobScript.trigger_global_magnet(tree)
			marquee.spawn_floating_text(beacon_node, "🧲 ¡IMÁN GLOBAL ACTIVADO!", Color(0.2, 0.95, 1.0))
			marquee.show_flash_msg("🧲 ¡IMÁN GLOBAL!", Color(0.2, 0.95, 1.0))
		"heal":
			var max_hp: float = player.stats.get_stat(&"max_health") if player.stats else 100.0
			player.heal(max_hp)
			marquee.spawn_floating_text(beacon_node, "💖 ¡CURACIÓN TOTAL 100%!", Color(0.2, 1.0, 0.4))
			marquee.show_flash_msg("💖 ¡CURACIÓN 100%!", Color(0.2, 1.0, 0.4))
		"pair":
			var credits: int = int(payout.get("credits", current_spin_cost))
			player.run_credits += credits
			var main_scene: Node = tree.current_scene if tree else null
			if main_scene and "hud" in main_scene and main_scene.hud:
				main_scene.hud.update_credits(player.run_credits)
			marquee.spawn_floating_text(beacon_node, "🪙 ¡PAR! REEMBOLSO +%d CR" % credits, Color(0.9, 0.95, 0.35))
			marquee.show_flash_msg("🪙 ¡REEMBOLSO +%d CR!" % credits, Color(0.9, 0.95, 0.35))
		_:
			marquee.spawn_floating_text(beacon_node, "❌ ¡SIN PREMIO!", Color(0.7, 0.7, 0.8))
			marquee.show_flash_msg("❌ ¡SIN PREMIO!", Color(0.7, 0.7, 0.8))
