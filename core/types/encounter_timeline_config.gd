class_name EncounterTimelineConfig
extends Resource

## Configuración Data-Driven de la línea temporal de encuentros en Astra Dream.
## Permite calibrar duraciones, hitos de colosos, rivales y escalado de dificultad
## directamente desde el Inspector de Godot sin tocar código de lógica.

@export_group("Oleadas y Tiempos")
@export var wave_duration: float = 30.0
@export var pre_round_duration: float = 3.0
@export var total_waves: int = 16

@export_group("Hitos de Jefes y Rivales")
## Diccionario que mapea número de oleada (int) a recurso de escena de jefe (PackedScene)
@export var boss_wave_scenes: Dictionary = {}
## Oleadas donde arriba un piloto rival a través de un portal hiperespacial
@export var rival_wave_milestones: Array[int] = [4, 7, 10, 13]

@export_group("Satélites y Balizas")
@export var satellite_interval_seconds: float = 60.0
@export var max_satellites_per_wave: int = 2
@export var slot_machine_chance_per_wave: float = 0.35

@export_group("Escalado Adaptativo de Jefes")
@export var base_boss_hp_multiplier: float = 1.0
@export var wave_scaling_hp_step: float = 0.08
@export var adaptive_dps_floor: float = 0.85
@export var adaptive_dps_ceiling: float = 2.50
@export var burst_compression_threshold_pct: float = 0.12

func get_boss_scene_for_wave(wave_num: int) -> PackedScene:
	if boss_wave_scenes.has(wave_num):
		var val: Variant = boss_wave_scenes[wave_num]
		if val is PackedScene:
			return val as PackedScene
		elif val is String and ResourceLoader.exists(val):
			return load(val) as PackedScene
	return null

func is_boss_wave(wave_num: int) -> bool:
	return boss_wave_scenes.has(wave_num)

func is_rival_wave(wave_num: int) -> bool:
	return wave_num in rival_wave_milestones
