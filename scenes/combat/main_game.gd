class_name MainGame
extends Node2D

@onready var player: Player = $Player
@onready var bullet_server: BulletServer = $BulletServer
@onready var hud: GameHUD = $HUD
@onready var level_up_modal: LevelUpModal = $LevelUpModal
@onready var satellite_shop: SatelliteShop = $SatelliteShop
@onready var stat_deck_manager: StatDeckManager = $StatDeckManager

var current_satellite_idx: int = 1
var satellite_scene: PackedScene = preload("res://scenes/combat/satellite/satellite_beacon.tscn")
var current_satellite: SatelliteBeacon = null

func _ready() -> void:
	# Conexión del HUD con el jugador
	player.exp_changed.connect(hud.update_exp)
	player.credits_changed.connect(hud.update_credits)
	player.level_up_requested.connect(_on_level_up_requested)

	# Conexión de la tienda
	satellite_shop.item_purchased.connect(_on_item_purchased)

	# Inicializar HUD
	hud.update_credits(player.run_credits)
	hud.update_exp(player.current_exp, player.exp_to_next, player.current_level)

	# Spawnear el primer satélite
	_spawn_next_satellite(Vector2(1400, 450))

func _spawn_next_satellite(target_pos: Vector2) -> void:
	if current_satellite:
		current_satellite.queue_free()

	current_satellite = satellite_scene.instantiate() as SatelliteBeacon
	current_satellite.global_position = target_pos
	current_satellite.satellite_index = current_satellite_idx
	add_child(current_satellite)

	current_satellite.planted.connect(_on_satellite_planted)
	current_satellite.exited_perimeter.connect(_on_satellite_exited)

	hud.set_active_satellite(target_pos, current_satellite_idx)

func _on_satellite_planted(index: int, pos: Vector2) -> void:
	# Abre la tienda del satélite con los créditos actuales del jugador
	satellite_shop.open_shop(player.run_credits)

func _on_satellite_exited(index: int) -> void:
	# El jugador salió del perímetro: avanza la carrera contra el reloj
	current_satellite_idx += 1
	var next_offset := Vector2(randf_range(600, 900), randf_range(-400, 400))
	var next_pos := player.global_position + next_offset
	_spawn_next_satellite(next_pos)

	# Spawn de emisor adicional que incrementa la dificultad
	_spawn_additional_wave_emitter(next_pos + Vector2(-200, -200))

func _on_item_purchased(item: ItemData, cost: int) -> void:
	player.run_credits -= cost
	player.inventory.add_item(item, 1)
	hud.update_credits(player.run_credits)

func _on_level_up_requested(level: int) -> void:
	level_up_modal.show_level_up(level)

func _spawn_additional_wave_emitter(pos: Vector2) -> void:
	var emitter := DanmakuTestEmitter.new()
	emitter.global_position = pos
	emitter.bullet_server = bullet_server
	emitter.player = player
	add_child(emitter)
