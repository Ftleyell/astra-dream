class_name PlanetSpawnerHelper
extends RefCounted

## Helper desacoplado para generación de planetas y biomas de prueba en combate.

static func spawn_debug_planets(parent: Node2D, player: Node2D) -> void:
	if not is_instance_valid(player) or not is_instance_valid(parent):
		return

	var planet_scene := load("res://scenes/combat/environment/planet.tscn") as PackedScene
	if not planet_scene:
		return

	var configs: Array[Dictionary] = [
		{
			"res": "res://data/planets/verdant_planet.tres",
			"offset": Vector2(650.0, -250.0)
		},
		{
			"res": "res://data/planets/volcanic_planet.tres",
			"offset": Vector2(-750.0, 300.0)
		},
		{
			"res": "res://data/planets/cryo_planet.tres",
			"offset": Vector2(850.0, 600.0)
		}
	]

	for cfg in configs:
		var p_res := load(cfg["res"]) as PlanetData
		if not p_res:
			continue
		var planet := planet_scene.instantiate() as Planet
		if not planet:
			continue
		planet.planet_data = p_res
		planet.disable_defenders = true
		planet.global_position = player.global_position + cfg["offset"]
		parent.add_child(planet)
