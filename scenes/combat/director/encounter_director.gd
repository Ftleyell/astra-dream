class_name EncounterDirector
extends Node2D

## Director Coordinador de Encuentros Data-Driven en Astra Dream.
## Administra la línea temporal de combate delegando en sub-directores especializados
## (WaveDirector, BossRivalDirector, SatelliteDirector) y gobernado por EncounterTimelineConfig.

signal wave_changed(wave_num: int)
signal wave_status_updated(wave_num: int, timer: float, satellites_spawned: int, max_satellites: int)
signal boss_spawn_requested(scene: PackedScene, target_pos: Vector2, adaptive_hp: float)
signal rival_spawn_requested(rival_id: StringName, spawn_pos: Vector2)
signal satellite_spawn_requested(target_pos: Vector2, sat_index: int)
signal satellite_despawn_requested(beacon: Node2D)
signal slot_machine_spawn_requested(target_pos: Vector2)

@export var config: EncounterTimelineConfig = preload("res://data/balance/default_encounter_timeline.tres")

var wave_director: WaveDirector = null
var boss_rival_director: BossRivalDirector = null
var satellite_director: SatelliteDirector = null

var _is_initialized: bool = false

func _ready() -> void:
	if not _is_initialized:
		initialize(config)

func initialize(timeline_cfg: EncounterTimelineConfig = null) -> void:
	if timeline_cfg:
		config = timeline_cfg
	elif not config:
		config = load("res://data/balance/default_encounter_timeline.tres") as EncounterTimelineConfig

	_ensure_sub_directors()

	if wave_director:
		wave_director.initialize(config)
		if not wave_director.wave_started.is_connected(_on_wave_director_wave_started):
			wave_director.wave_started.connect(_on_wave_director_wave_started)
		if not wave_director.wave_time_updated.is_connected(_on_wave_time_updated):
			wave_director.wave_time_updated.connect(_on_wave_time_updated)

	if boss_rival_director:
		boss_rival_director.initialize(config)
		if not boss_rival_director.boss_spawn_requested.is_connected(_on_boss_spawn_requested):
			boss_rival_director.boss_spawn_requested.connect(_on_boss_spawn_requested)
		if not boss_rival_director.rival_spawn_requested.is_connected(_on_rival_spawn_requested):
			boss_rival_director.rival_spawn_requested.connect(_on_rival_spawn_requested)

	if satellite_director:
		satellite_director.initialize(config)
		if not satellite_director.satellite_spawn_requested.is_connected(_on_satellite_spawn_requested):
			satellite_director.satellite_spawn_requested.connect(_on_satellite_spawn_requested)
		if not satellite_director.satellite_despawn_requested.is_connected(_on_satellite_despawn_requested):
			satellite_director.satellite_despawn_requested.connect(_on_satellite_despawn_requested)
		if not satellite_director.slot_machine_spawn_requested.is_connected(_on_slot_machine_spawn_requested):
			satellite_director.slot_machine_spawn_requested.connect(_on_slot_machine_spawn_requested)

	_is_initialized = true

func _ensure_sub_directors() -> void:
	if not wave_director:
		wave_director = get_node_or_null("WaveDirector") as WaveDirector
		if not wave_director:
			wave_director = WaveDirector.new()
			wave_director.name = "WaveDirector"
			add_child(wave_director)

	if not boss_rival_director:
		boss_rival_director = get_node_or_null("BossRivalDirector") as BossRivalDirector
		if not boss_rival_director:
			boss_rival_director = BossRivalDirector.new()
			boss_rival_director.name = "BossRivalDirector"
			add_child(boss_rival_director)

	if not satellite_director:
		satellite_director = get_node_or_null("SatelliteDirector") as SatelliteDirector
		if not satellite_director:
			satellite_director = SatelliteDirector.new()
			satellite_director.name = "SatelliteDirector"
			add_child(satellite_director)

func update_encounters(delta: float, is_combat_active: bool, player_pos: Vector2, player_vel: Vector2) -> void:
	if wave_director:
		wave_director.update_wave_timeline(delta, is_combat_active)

	if satellite_director and not is_combat_active:
		satellite_director.check_satellite_despawn(player_pos)
		if satellite_director.can_spawn_satellite_for_wave():
			var sat_pos := satellite_director.calculate_satellite_spawn_position(player_pos, player_vel)
			satellite_director.wave_satellites_spawned += 1
			satellite_director.satellite_spawn_requested.emit(sat_pos, satellite_director.current_satellite_idx)

func jump_to_wave(wave_num: int) -> void:
	if wave_director:
		wave_director.set_wave(wave_num)
	if satellite_director:
		satellite_director.reset_for_new_wave()
	if boss_rival_director:
		boss_rival_director.clear_encounters()

func _on_wave_director_wave_started(wave_num: int) -> void:
	if satellite_director:
		satellite_director.reset_for_new_wave()
	wave_changed.emit(wave_num)

func _on_wave_time_updated(time_left: float, _total_time: float) -> void:
	var w_num: int = wave_director.current_wave if wave_director else 1
	var sats_spawned: int = satellite_director.wave_satellites_spawned if satellite_director else 0
	var max_sats: int = config.max_satellites_per_wave if config else 1
	wave_status_updated.emit(w_num, time_left, sats_spawned, max_sats)

func _on_boss_spawn_requested(scene: PackedScene, target_pos: Vector2, hp: float) -> void:
	boss_spawn_requested.emit(scene, target_pos, hp)

func _on_rival_spawn_requested(rival_id: StringName, spawn_pos: Vector2) -> void:
	rival_spawn_requested.emit(rival_id, spawn_pos)

func _on_satellite_spawn_requested(target_pos: Vector2, sat_idx: int) -> void:
	satellite_spawn_requested.emit(target_pos, sat_idx)

func _on_satellite_despawn_requested(beacon: Node2D) -> void:
	satellite_despawn_requested.emit(beacon)

func _on_slot_machine_spawn_requested(target_pos: Vector2) -> void:
	slot_machine_spawn_requested.emit(target_pos)
