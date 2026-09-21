class_name MainGame
extends Node2D

@onready var player: Player = $Player
@onready var bullet_server: BulletServer = $BulletServer
@onready var hud: GameHUD = $HUD
@onready var level_up_modal: LevelUpModal = $LevelUpModal
@onready var satellite_shop: SatelliteShop = $SatelliteShop
@onready var stat_deck_manager: StatDeckManager = $StatDeckManager
@onready var audio_duck_manager: AudioDuckManager = $AudioDuckManager
@onready var camera: GameCamera2D = $Camera2D
@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var skip_badge_layer: CanvasLayer = get_node_or_null("SkipBadgeLayer")
@onready var skip_button: Button = get_node_or_null("SkipBadgeLayer/MarginContainer/SkipButton")

const WAVE_DURATION: float = 60.0
const MAX_SATELLITES_PER_WAVE: int = 3
const BASE_SPAWN_DISTANCE: float = 600.0
const DISTANCE_INCREMENT_PER_SAT: float = 250.0
const SPAWN_AHEAD_DISTANCE: float = 1100.0

var current_satellite_idx: int = 1
var satellite_scene: PackedScene = preload("res://scenes/combat/satellite/satellite_beacon.tscn")
var current_satellite: SatelliteBeacon = null
var _last_player_hp: float = 100.0

var current_wave: int = 1
var wave_timer: float = WAVE_DURATION
var wave_satellites_spawned: int = 0
var satellites_collected_total: int = 0
var last_anchor_pos: Vector2 = Vector2.ZERO

var is_briefing_active: bool = true
var prologue_bonus_chosen: bool = false

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

	# Inicializar ancla de distancia al spawn del jugador
	last_anchor_pos = player.global_position

	# Inicializar HUD
	hud.update_credits(player.run_credits)
	hud.update_exp(player.current_exp, player.exp_to_next, player.current_level)
	hud.update_wave_status(current_wave, wave_timer, wave_satellites_spawned, MAX_SATELLITES_PER_WAVE)

	# Asegurar que MainGame y Dialogic procesen durante la pausa
	process_mode = Node.PROCESS_MODE_ALWAYS
	Dialogic.process_mode = Node.PROCESS_MODE_ALWAYS

	# Conexión de Dialogic para briefing inicial y eventos de señal
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.timeline_ended.connect(_on_dialogic_timeline_ended)

	if skip_button:
		skip_button.pressed.connect(func():
			if is_briefing_active:
				Dialogic.end_timeline()
		)

	# Iniciar música de combate
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_music"):
		audio_mgr.play_music("combat")

	# Inyección dinámica de objetos espaciales y asteroides periódicos
	var asteroid_spawner := AsteroidSpawner.new()
	asteroid_spawner.name = "AsteroidSpawner"
	add_child(asteroid_spawner)

	# Iniciar secuencia de briefing con Dialogic 2 antes de la oleada
	_start_prologue_briefing()

func _start_prologue_briefing() -> void:
	is_briefing_active = true
	get_tree().paused = true
	if skip_badge_layer:
		skip_badge_layer.show()

	var layout = Dialogic.start("res://narrative/timelines/prologue_briefing.dtl")
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_dialogic_audio(layout)

func _setup_dialogic_audio(layout: Node) -> void:
	if not layout:
		return
	var type_sound := layout.find_child("DialogicNode_TypeSounds", true, false) as DialogicNode_TypeSounds
	if type_sound:
		type_sound.sounds = [
			preload("res://addons/dialogic/Example Assets/sound-effects/typing1.wav"),
			preload("res://addons/dialogic/Example Assets/sound-effects/typing4.wav")
		]
		type_sound.play_every_character = 1
		type_sound.pitch_variance = 0.2
		type_sound.volume_variance = 0.5

func _on_dialogic_signal(arg: Variant) -> void:
	match str(arg):
		"briefing_credits":
			prologue_bonus_chosen = true
			player.run_credits += 100
			hud.update_credits(player.run_credits)
		"briefing_speed":
			prologue_bonus_chosen = true
			player.stats.add_modifier(&"move_speed", CharacterStats.StatModifier.new(&"briefing_speed", 0.15, true, self))
		"briefing_hull":
			prologue_bonus_chosen = true
			player.stats.add_modifier(&"max_health", CharacterStats.StatModifier.new(&"briefing_hull", 25.0, false, self))
			player.current_health = player.stats.get_stat(&"max_health")
			player.health_changed.emit(player.current_health, player.stats.get_stat(&"max_health"))

func _on_dialogic_timeline_ended() -> void:
	if is_briefing_active:
		is_briefing_active = false
		get_tree().paused = false
		if skip_badge_layer:
			skip_badge_layer.hide()

		# Si se saltó el diálogo sin haber seleccionado una opción, otorgar bono base
		if not prologue_bonus_chosen:
			prologue_bonus_chosen = true
			player.run_credits += 50
			hud.update_credits(player.run_credits)

func _trigger_cockpit_interlude() -> void:
	var layout = Dialogic.start("res://narrative/timelines/wave_interlude_cockpit.dtl")
	_setup_dialogic_audio(layout)

func _process(delta: float) -> void:
	if get_tree().paused or is_briefing_active:
		return

	# Lógica del temporizador de oleada
	wave_timer -= delta
	if wave_timer <= 0.0:
		current_wave += 1
		wave_timer = WAVE_DURATION
		wave_satellites_spawned = 0
		if enemy_spawner and enemy_spawner.has_method("set_wave"):
			enemy_spawner.set_wave(current_wave)
		_trigger_cockpit_interlude()

	# Distancia requerida que escala con cada satélite recolectado
	var req_dist: float = BASE_SPAWN_DISTANCE + (float(satellites_collected_total) * DISTANCE_INCREMENT_PER_SAT)
	var current_dist: float = player.global_position.distance_to(last_anchor_pos)

	hud.update_wave_status(current_wave, wave_timer, wave_satellites_spawned, MAX_SATELLITES_PER_WAVE)
	hud.update_satellite_travel_dist(current_dist, req_dist)

	# Chequeo para spawnear satélite en la dirección del movimiento
	if current_satellite == null and wave_satellites_spawned < MAX_SATELLITES_PER_WAVE:
		if current_dist >= req_dist:
			_spawn_satellite_in_player_direction()

func _spawn_satellite_in_player_direction() -> void:
	var move_dir := player.velocity.normalized() if player.velocity.length_squared() > 10.0 else (get_global_mouse_position() - player.global_position).normalized()
	if move_dir.length_squared() < 0.001:
		move_dir = Vector2.RIGHT

	var spawn_pos: Vector2 = player.global_position + move_dir * SPAWN_AHEAD_DISTANCE
	wave_satellites_spawned += 1
	_spawn_next_satellite(spawn_pos)

func _input(event: InputEvent) -> void:
	# Atajo para saltar el briefing cinematográfico con ESC o diálogo skip
	if is_briefing_active:
		if event.is_action_pressed("dialogue_skip") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			Dialogic.end_timeline()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		# Tecla T para testear en cualquier momento la transmisión cinemática de jefe
		if event.keycode == KEY_T:
			trigger_boss_transmission("CENTINELA TITÁN", "¡Alerta de distorsión! Tus armas no perforarán nuestro núcleo planetario. Prepárate para el impacto.")
		# Tecla C para testear en cualquier momento la secuencia de diálogo de cabina en vivo
		elif event.keycode == KEY_C:
			_trigger_cockpit_interlude()

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

func _on_satellite_planted(index: int, _pos: Vector2) -> void:
	# Abre la tienda del satélite con los créditos actuales del jugador
	satellite_shop.open_shop(player.run_credits)

	# Al activar el 2do satélite, se dispara la transmisión cinemática del primer jefe
	if index == 2:
		trigger_boss_transmission("CENTINELA TITÁN (FASE 1)", "Intruso localizado en la baliza orbital. Desplegando enjambre de proyectiles.")

func _on_satellite_exited(_index: int) -> void:
	# El jugador salió del perímetro del satélite: se contabiliza y se actualiza el ancla de distancia
	current_satellite_idx += 1
	satellites_collected_total += 1
	last_anchor_pos = player.global_position

	if current_satellite:
		current_satellite.queue_free()
		current_satellite = null

	hud.clear_satellite()

func trigger_boss_transmission(_speaker: String = "", _text: String = "") -> void:
	var layout = Dialogic.start("res://narrative/timelines/boss_titan_alert.dtl")
	_setup_dialogic_audio(layout)

func _on_item_purchased(item: ItemData, cost: int) -> void:
	player.run_credits -= cost
	player.inventory.add_item(item, 1)
	hud.update_credits(player.run_credits)

func _on_level_up_requested(level: int) -> void:
	level_up_modal.show_level_up(level)

func _on_player_bomb_used(_remaining: int) -> void:
	if camera:
		camera.add_trauma(0.6)

func _on_player_health_changed(current: float, _max_val: float) -> void:
	if current < _last_player_hp:
		if camera:
			camera.add_trauma(0.4)
	_last_player_hp = current
