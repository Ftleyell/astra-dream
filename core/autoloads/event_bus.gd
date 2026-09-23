extends Node

# High-level run events
signal level_up_offered(level: int)
signal level_up_selected(stat_card: StatCardData)
signal satellite_planted(satellite_index: int, position: Vector2)
signal satellite_exited(satellite_index: int)
signal run_currency_changed(new_amount: int)
signal boss_spawn_requested(timeline_id: String, boss_id: String, is_secret: bool)
signal boss_defeated(boss_id: String)
signal player_died()
signal enemy_killed(enemy_type: String)
signal arcana_orb_collected(orb: Node2D)
