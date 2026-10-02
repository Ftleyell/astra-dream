class_name WaveScheduleConfig
extends Resource

## Cronograma data-driven maestro de oleadas de combate en Astra Dream.
## Almacena las configuraciones WaveSpawnConfig de cada oleada y provee fallback automático.

@export var wave_configs: Array[WaveSpawnConfig] = []
@export var fallback_config: WaveSpawnConfig = null

func get_config_for_wave(wave_num: int) -> WaveSpawnConfig:
	for cfg in wave_configs:
		if cfg and cfg.wave_number == wave_num:
			return cfg

	if fallback_config:
		return fallback_config

	# Fallback sintético seguro en caso de que no haya recurso asignado
	var def_cfg := WaveSpawnConfig.new()
	def_cfg.wave_number = wave_num
	def_cfg.max_enemies = 80
	def_cfg.base_spawn_interval = 0.70
	def_cfg.min_spawn_interval = 0.28
	def_cfg.cluster_min = 4
	def_cfg.cluster_max = 8
	def_cfg.drone_weight = 35.0
	def_cfg.kamikaze_weight = 20.0
	def_cfg.micro_flock_weight = 15.0
	def_cfg.tank_weight = 12.0
	def_cfg.shooter_weight = 10.0
	def_cfg.splitter_weight = 8.0
	return def_cfg
