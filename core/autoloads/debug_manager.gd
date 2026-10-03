extends Node

## Singleton de Depuración y Trampas para Testeo de Desarrollo
## Permite activar God Mode, Economía Infinita, Consumibles Ilimitados y Modificadores de Stats.
## Puede desactivarse completamente para builds de producción cambiando FORCE_DISABLE_DEBUG a true.

const FORCE_DISABLE_DEBUG: bool = false
const FORCE_ENABLE_DEBUG: bool = true

static func is_debug_enabled() -> bool:
	if FORCE_DISABLE_DEBUG:
		return false
	if FORCE_ENABLE_DEBUG:
		return true
	return OS.is_debug_build()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not is_debug_enabled():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		var tree := get_tree()
		if not tree:
			return
		var current_scene := tree.current_scene
		if current_scene and current_scene.has_method("_toggle_ingame_debug"):
			get_viewport().set_input_as_handled()
			current_scene._toggle_ingame_debug()

# Señales para coordinación reactiva in-game con MainGame y sus coordinadores
signal spawn_monolith_requested(position: Vector2)
signal spawn_boss_requested(boss_id: String, play_intro: bool)
signal spawn_rival_requested(play_intro: bool)
signal spawn_slot_machine_requested(position: Vector2)
signal kill_all_enemies_requested()
signal clear_all_bullets_requested()
signal jump_wave_requested(target_wave: int)
signal trigger_crisis_requested(crisis_id: String)
signal add_credits_requested(amount: int)
signal add_bombs_requested(amount: int)
signal restore_health_requested()
signal set_speed_mult_requested(mult: float)
signal give_weapon_requested(weapon_id: StringName)
signal upgrade_weapons_requested()
signal give_arcana_pact_requested(pact_id: StringName)

var is_enabled: bool = false

# Flags de Trampas
var infinite_hp: bool = false
var infinite_credits: bool = false
var infinite_consumables: bool = false
var pending_debug_route: String = ""

# Modificadores de estadísticas numéricas específicas
var stat_overrides: Dictionary[StringName, float] = {}

# Definición de rangos y valores por defecto de todas las estadísticas de CharacterStats
const STAT_CONFIGS: Dictionary = {
	&"max_health": { "name": "Vida Máxima", "min": 10.0, "max": 2000.0, "step": 10.0, "default": 100.0, "format": "%.0f" },
	&"health_regen": { "name": "Regen. Vida (/s)", "min": 0.0, "max": 50.0, "step": 0.5, "default": 0.0, "format": "%.1f" },
	&"move_speed": { "name": "Velocidad Movimiento", "min": 100.0, "max": 1200.0, "step": 25.0, "default": 300.0, "format": "%.0f" },
	&"armor": { "name": "Armadura Blindaje", "min": -50.0, "max": 150.0, "step": 1.0, "default": 0.0, "format": "%.0f" },
	&"base_damage": { "name": "Daño Base Armas", "min": 1.0, "max": 250.0, "step": 1.0, "default": 15.0, "format": "%.0f" },
	&"attack_speed": { "name": "Velocidad de Ataque", "min": 0.2, "max": 5.0, "step": 0.1, "default": 1.0, "format": "%.2f" },
	&"crit_chance": { "name": "Probabilidad Crítico", "min": 0.0, "max": 1.0, "step": 0.01, "default": 0.05, "format": "%.2f" },
	&"crit_damage": { "name": "Multiplicador Crítico", "min": 1.0, "max": 6.0, "step": 0.1, "default": 1.5, "format": "%.2f" },
	&"luck": { "name": "Suerte / Rerolls", "min": 0.1, "max": 10.0, "step": 0.1, "default": 1.0, "format": "%.1f" },
	&"pickup_radius": { "name": "Radio de Recogida", "min": 30.0, "max": 800.0, "step": 10.0, "default": 100.0, "format": "%.0f" },
	&"projectile_count": { "name": "Cant. Proyectiles", "min": 1.0, "max": 12.0, "step": 1.0, "default": 1.0, "format": "%.0f" },
	&"projectile_speed": { "name": "Vel. Proyectil Mult.", "min": 0.2, "max": 4.0, "step": 0.1, "default": 1.0, "format": "%.2f" },
	&"weapon_size": { "name": "Tamaño del Arma Mult.", "min": 0.3, "max": 4.0, "step": 0.1, "default": 1.0, "format": "%.2f" },
	&"cooldown_reduction": { "name": "Reducción Enfriamiento", "min": 0.0, "max": 0.85, "step": 0.05, "default": 0.0, "format": "%.2f" },
	&"exp_multiplier": { "name": "Multiplicador EXP", "min": 0.5, "max": 8.0, "step": 0.2, "default": 1.0, "format": "%.1f" }
}

func is_infinite_hp_active() -> bool:
	return is_enabled and infinite_hp

func is_infinite_credits_active() -> bool:
	return is_enabled and infinite_credits

func is_infinite_consumables_active() -> bool:
	return is_enabled and infinite_consumables

func has_stat_overrides() -> bool:
	return is_enabled and not stat_overrides.is_empty()

func get_stat_override(stat: StringName, fallback: float) -> float:
	if not is_enabled:
		return fallback
	return stat_overrides.get(stat, fallback)

func set_stat_override(stat: StringName, val: float) -> void:
	is_enabled = true
	stat_overrides[stat] = val

func clear_stat_override(stat: StringName) -> void:
	stat_overrides.erase(stat)

var pending_slot_machine_test: bool = false
var pending_planet_test: bool = false
var pending_debug_boss: String = ""
var pending_auto_trigger_death: bool = false
var pending_rival_spawn: bool = false

func set_pending_rival_spawn(val: bool = true) -> void:
	pending_rival_spawn = val
	is_enabled = true

func consume_pending_rival_spawn() -> bool:
	var res := pending_rival_spawn
	pending_rival_spawn = false
	return res

func set_pending_debug_boss(boss_id: String, auto_trigger_death: bool = false) -> void:
	pending_debug_boss = boss_id
	pending_auto_trigger_death = auto_trigger_death
	is_enabled = true

func consume_pending_debug_boss() -> String:
	var b := pending_debug_boss
	pending_debug_boss = ""
	return b

func consume_pending_auto_trigger_death() -> bool:
	var res := pending_auto_trigger_death
	pending_auto_trigger_death = false
	return res

func set_pending_debug_route(route: String) -> void:
	pending_debug_route = route
	is_enabled = true

func consume_pending_debug_route() -> String:
	var r := pending_debug_route
	pending_debug_route = ""
	return r

func set_pending_slot_machine_test(val: bool = true) -> void:
	pending_slot_machine_test = val
	is_enabled = true

func consume_pending_slot_machine_test() -> bool:
	var res := pending_slot_machine_test
	pending_slot_machine_test = false
	return res

func set_pending_planet_test(val: bool = true) -> void:
	pending_planet_test = val
	is_enabled = true

func consume_pending_planet_test() -> bool:
	var res := pending_planet_test
	pending_planet_test = false
	return res

func reset_all() -> void:
	infinite_hp = false
	infinite_credits = false
	infinite_consumables = false
	pending_debug_route = ""
	pending_debug_boss = ""
	pending_slot_machine_test = false
	pending_planet_test = false
	pending_rival_spawn = false
	stat_overrides.clear()
	is_enabled = false

func apply_to_player(player: Player) -> void:
	if not is_enabled or not is_instance_valid(player):
		return

	# 1. Aplicar overrides directos a las estadísticas del jugador
	if player.stats:
		for stat_name in stat_overrides.keys():
			var val: float = stat_overrides[stat_name]
			# Sobrescribir la base directamente en _base_stats
			player.stats._base_stats[stat_name] = val
			player.stats._is_dirty[stat_name] = true

		if stat_overrides.has(&"max_health"):
			player.current_health = player.stats.get_stat(&"max_health")
			player.health_changed.emit(player.current_health, player.stats.get_stat(&"max_health"))

	# 2. Créditos infinitos
	if infinite_credits:
		player.run_credits = 999999
		player.credits_changed.emit(player.run_credits)

	# 3. Consumibles infinitos (Bombas máximas)
	if infinite_consumables:
		player.bomb_count = 5
		player.bomb_used.emit(player.bomb_count)
