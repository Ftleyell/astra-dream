class_name WaveSpawnConfig
extends Resource

## Configuración data-driven de spawn y composición hostil para una oleada específica.

@export var wave_number: int = 1
@export var max_enemies: int = 50
@export var base_spawn_interval: float = 1.2
@export var min_spawn_interval: float = 0.50
@export var cluster_min: int = 3
@export var cluster_max: int = 6

@export_group("Pesos de Aparición (Spawn Weights)")
@export_range(0.0, 100.0) var drone_weight: float = 75.0
@export_range(0.0, 100.0) var kamikaze_weight: float = 15.0
@export_range(0.0, 100.0) var micro_flock_weight: float = 10.0
@export_range(0.0, 100.0) var shooter_weight: float = 0.0
@export_range(0.0, 100.0) var tank_weight: float = 0.0
@export_range(0.0, 100.0) var splitter_weight: float = 0.0
@export_range(0.0, 100.0) var assault_cone_weight: float = 0.0
@export_range(0.0, 100.0) var vanguard_ring_weight: float = 0.0
@export_range(0.0, 100.0) var specter_wave_weight: float = 0.0

func pick_enemy_type() -> StringName:
	var total_weight: float = (
		drone_weight + kamikaze_weight + micro_flock_weight +
		shooter_weight + tank_weight + splitter_weight +
		assault_cone_weight + vanguard_ring_weight + specter_wave_weight
	)
	if total_weight <= 0.001:
		return &"drone"

	var roll := randf() * total_weight
	var acc: float = 0.0

	acc += drone_weight
	if roll < acc: return &"drone"

	acc += kamikaze_weight
	if roll < acc: return &"kamikaze"

	acc += micro_flock_weight
	if roll < acc: return &"micro_flock"

	acc += shooter_weight
	if roll < acc: return &"shooter"

	acc += tank_weight
	if roll < acc: return &"tank"

	acc += splitter_weight
	if roll < acc: return &"splitter"

	acc += assault_cone_weight
	if roll < acc: return &"assault_cone"

	acc += vanguard_ring_weight
	if roll < acc: return &"vanguard_ring"

	return &"specter_wave"
