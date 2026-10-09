class_name CombatContext
extends RefCounted

## CombatContext.gd
## Contexto compartido e inyectable de combate para Astra Dream.
## Provee acceso fuertemente tipado a los actores centrales del mundo, HUD,
## servidores y estado de la partida, eliminando la necesidad de pasar 'self' (MainGame).

signal wave_started(wave_idx: int)
signal wave_completed(wave_idx: int)
signal combat_ended(reason: StringName)

# Actores centrales de la simulación
var player: CharacterBody2D = null
var camera: Camera2D = null
var hud: CanvasLayer = null
var bullet_server: Node = null
var enemy_spawner: Node = null
var space_object_spawner: Node = null
var chest_director: Node = null
var satellite_shop: Node = null
var main_game: Node = null

# Estado global de la run
var current_wave: int = 1
var wave_duration: float = 30.0
var wave_timer: float = 30.0
var enemies_killed_count: int = 0
var bosses_defeated_count: int = 0

var is_endless_mode: bool = false
var is_exiting_run: bool = false


func initialize(
	p_player: CharacterBody2D,
	p_camera: Camera2D,
	p_hud: CanvasLayer,
	p_bullet_server: Node,
	p_enemy_spawner: Node,
	p_space_object_spawner: Node = null,
	p_chest_director: Node = null,
	p_satellite_shop: Node = null,
	p_main_game: Node = null
) -> void:
	player = p_player
	camera = p_camera
	hud = p_hud
	bullet_server = p_bullet_server
	enemy_spawner = p_enemy_spawner
	space_object_spawner = p_space_object_spawner
	chest_director = p_chest_director
	satellite_shop = p_satellite_shop
	main_game = p_main_game


func notify_wave_started(wave_idx: int) -> void:
	current_wave = wave_idx
	wave_started.emit(wave_idx)


func notify_wave_completed(wave_idx: int) -> void:
	wave_completed.emit(wave_idx)


func notify_combat_ended(reason: StringName) -> void:
	is_exiting_run = true
	combat_ended.emit(reason)
