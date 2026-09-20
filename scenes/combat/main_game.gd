class_name MainGame
extends Node2D

@onready var player: Player = $Player
@onready var bullet_server: BulletServer = $BulletServer
@onready var hud: GameHUD = $HUD
@onready var level_up_modal: LevelUpModal = $LevelUpModal
@onready var satellite_shop: SatelliteShop = $SatelliteShop
@onready var stat_deck_manager: StatDeckManager = $StatDeckManager
@onready var combat_dialogue: CombatDialogueBox = $CombatDialogueBox
@onready var audio_duck_manager: AudioDuckManager = $AudioDuckManager
@onready var camera: GameCamera2D = $Camera2D

var current_satellite_idx: int = 1
var satellite_scene: PackedScene = preload("res://scenes/combat/satellite/satellite_beacon.tscn")
var current_satellite: SatelliteBeacon = null
var _last_player_hp: float = 100.0

func _ready() -> void:
	# Conexión del HUD con el jugador
	player.exp_changed.connect(hud.update_exp)
	player.credits_changed.connect(hud.update_credits)
	player.level_up_requested.connect(_on_level_up_requested)
	player.bomb_used.connect(_on_player_bomb_used)
	player.health_changed.connect(_on_player_health_changed)
	_last_player_hp = player.current_health

	# Conexión de la tienda
	satellite_shop.item_purchased.connect(_on_item_purchased)

	# Conexión de audio con el diálogo cinemático
	combat_dialogue.audio_duck_manager = audio_duck_manager

	# Inicializar HUD
	hud.update_credits(player.run_credits)
	hud.update_exp(player.current_exp, player.exp_to_next, player.current_level)

	# Iniciar música de combate
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_music"):
		audio_mgr.play_music("combat")

	# Spawnear el primer satélite
	_spawn_next_satellite(Vector2(1400, 450))

func _input(event: InputEvent) -> void:
	# Tecla T para testear en cualquier momento la transmisión cinemática de jefe
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			trigger_boss_transmission("CENTINELA TITÁN", "¡Alerta de distorsión! Tus armas no perforarán nuestro núcleo planetario. Prepárate para el impacto.")

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

	# Al activar el 2do satélite, se dispara la transmisión cinemática del primer jefe
	if index == 2:
		trigger_boss_transmission("CENTINELA TITÁN (FASE 1)", "Intruso localizado en la baliza orbital. Desplegando enjambre de proyectiles.")

func _on_satellite_exited(index: int) -> void:
	# El jugador salió del perímetro: avanza la carrera contra el reloj
	current_satellite_idx += 1
	var next_offset := Vector2(randf_range(600, 900), randf_range(-400, 400))
	var next_pos := player.global_position + next_offset
	_spawn_next_satellite(next_pos)

	# Spawn de emisor adicional que incrementa la dificultad
	_spawn_additional_wave_emitter(next_pos + Vector2(-200, -200))

func trigger_boss_transmission(speaker: String, text: String) -> void:
	combat_dialogue.trigger_dialogue(speaker, text, Color(1.0, 0.35, 0.35))

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

func _on_player_bomb_used(_remaining: int) -> void:
	if camera:
		camera.add_trauma(0.6)

func _on_player_health_changed(current: float, _max_val: float) -> void:
	if current < _last_player_hp:
		if camera:
			camera.add_trauma(0.4)
	_last_player_hp = current
