class_name PlayerArcanaInventory
extends Node

## PlayerArcanaInventory.gd
## Componente modular especializado en la gestión de Arcanas (Cartas del Destino).
## Administra la colección activa de arcanas y la inyección de modificadores de estadísticas en el jugador.
## Extraído de Player como parte de la Fase 3 del Plan de Erradicación de Monolitos.

signal arcana_applied(arcana: ArcanaData)

var active_arcanas: Array[ArcanaData] = []

func get_arcana_ids() -> Array[String]:
	var ids: Array[String] = []
	for arc in active_arcanas:
		if arc:
			ids.append(arc.id)
	return ids

func has_arcana(arcana: ArcanaData) -> bool:
	return active_arcanas.has(arcana)

func apply_arcana(arcana: ArcanaData, player: Player, stats: CharacterStats) -> void:
	if not arcana or active_arcanas.has(arcana):
		return
	active_arcanas.append(arcana)

	for key in arcana.stat_modifiers.keys():
		var val: float = float(arcana.stat_modifiers[key])
		var s_key: String = String(key)
		var stat_name: StringName = StringName(s_key.trim_suffix("_pct"))
		var is_pct: bool = s_key.ends_with("_pct")

		var mod_id: StringName = StringName("arcana_" + arcana.id + "_" + s_key)
		stats.add_modifier(stat_name, CharacterStats.StatModifier.new(mod_id, val, is_pct, arcana))

	if is_instance_valid(player):
		var max_hp: float = maxf(1.0, stats.get_stat(&"max_health"))
		player.current_health = clampf(player.current_health, 1.0, max_hp)
		player.health_changed.emit(player.current_health, max_hp)

	arcana_applied.emit(arcana)
