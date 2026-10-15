class_name SatelliteSpawnRunEffect
extends RunEffect

## SatelliteSpawnRunEffect.gd
## Despliega inmediatamente una estación/baliza orbital en combate.

@export var satellite_type: StringName = &"beacon"


func apply_effect(context: CombatContext) -> void:
	if not context:
		return

	var sat_coord: Node = context.satellite_coordinator
	if not sat_coord and context.main_game and "satellite_coordinator" in context.main_game:
		sat_coord = context.main_game.satellite_coordinator

	if not sat_coord:
		return

	var p_pos: Vector2 = context.player.global_position if is_instance_valid(context.player) else Vector2.ZERO

	if sat_coord.has_method("spawn_next_satellite"):
		var spawn_pos: Vector2 = p_pos + Vector2(1200.0, 0.0)
		if "spawn_selector" in sat_coord and sat_coord.spawn_selector != null and sat_coord.spawn_selector.has_method("calculate_spawn_position"):
			var p_vel: Vector2 = context.player.velocity if is_instance_valid(context.player) else Vector2.ZERO
			spawn_pos = sat_coord.spawn_selector.calculate_spawn_position(p_pos, p_vel)
		sat_coord.spawn_next_satellite(spawn_pos, null)
	elif sat_coord.has_method("spawn_next_satellite_for_wave"):
		sat_coord.spawn_next_satellite_for_wave()
