extends Node

## Singleton de Depuración y Trampas para Testeo de Desarrollo
## Permite activar God Mode, Economía Infinita, Consumibles Ilimitados y Modificadores de Stats.
## Puede desactivarse completamente para builds de producción cambiando is_enabled a false.

var is_enabled: bool = false

# Flags de Trampas
var infinite_hp: bool = false
var infinite_credits: bool = false
var infinite_consumables: bool = false

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

func reset_all() -> void:
	infinite_hp = false
	infinite_credits = false
	infinite_consumables = false
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
