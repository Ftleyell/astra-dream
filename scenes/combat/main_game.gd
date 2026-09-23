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
@onready var pause_menu: PauseMenu = get_node_or_null("PauseMenu") as PauseMenu
@onready var character_stats_overlay: CharacterStatsOverlay = get_node_or_null("CharacterStatsOverlay") as CharacterStatsOverlay
@onready var skip_badge_layer: CanvasLayer = get_node_or_null("SkipBadgeLayer")

const WAVE_DURATION: float = 60.0
const MAX_SATELLITES_PER_WAVE: int = 3
const BASE_SPAWN_DISTANCE: float = 600.0
const DISTANCE_INCREMENT_PER_SAT: float = 250.0
const SPAWN_AHEAD_DISTANCE: float = 1100.0

var current_satellite_idx: int = 1
var satellite_scene: PackedScene = preload("res://scenes/combat/satellite/satellite_beacon.tscn")
var current_satellite: SatelliteBeacon = null
var boss_scene: PackedScene = preload("res://scenes/combat/bosses/boss_mothership.tscn")
var current_boss: BossMothership = null
var _last_player_hp: float = 100.0

var current_wave: int = 1
var wave_timer: float = WAVE_DURATION
var wave_satellites_spawned: int = 0
var satellites_collected_total: int = 0
var last_anchor_pos: Vector2 = Vector2.ZERO

var is_briefing_active: bool = true
var is_cockpit_active: bool = false
var is_boss_transmission_active: bool = false
var prologue_bonus_chosen: bool = false
var run_time_elapsed: float = 0.0
var enemies_killed_count: int = 0
var _auto_save_timer: float = 0.0

const AUTO_SAVE_INTERVAL: float = 5.0

func _ready() -> void:
	add_to_group("main_game")
	# Conexión del HUD con el jugador
	player.exp_changed.connect(hud.update_exp)
	player.credits_changed.connect(hud.update_credits)
	if not player.biomass_changed.is_connected(hud.update_biomass):
		player.biomass_changed.connect(hud.update_biomass)
	player.level_up_requested.connect(_on_level_up_requested)
	player.bomb_used.connect(_on_player_bomb_used)
	player.health_changed.connect(_on_player_health_changed)
	player.player_died.connect(_on_player_died)
	_last_player_hp = player.current_health

	# Conexión con EventBus
	var bus := get_node_or_null("/root/EventBus")
	if bus and bus.has_signal("enemy_killed"):
		bus.enemy_killed.connect(_on_enemy_killed)

	# Conexión de la tienda
	satellite_shop.item_purchased.connect(_on_item_purchased)
	satellite_shop.shop_closed.connect(_on_satellite_shop_closed)

	# Inicializar ancla de distancia al spawn del jugador
	last_anchor_pos = player.global_position

	# Inicializar HUD
	var debug_mgr = get_node_or_null("/root/DebugManager")
	if debug_mgr and debug_mgr.has_method("is_infinite_credits_active") and debug_mgr.is_infinite_credits_active():
		player.run_credits = 999999
	hud.update_credits(player.run_credits)
	hud.update_exp(player.current_exp, player.exp_to_next, player.current_level)
	hud.update_wave_status(current_wave, wave_timer, wave_satellites_spawned, MAX_SATELLITES_PER_WAVE)

	# Asegurar que MainGame y Dialogic procesen durante la pausa
	process_mode = Node.PROCESS_MODE_ALWAYS
	Dialogic.process_mode = Node.PROCESS_MODE_ALWAYS

	# Conexión de Dialogic para briefing inicial y eventos de señal
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.timeline_ended.connect(_on_dialogic_timeline_ended)
	Dialogic.timeline_started.connect(_on_dialogic_timeline_started)

	if skip_badge_layer and skip_badge_layer.has_signal("skip_requested"):
		skip_badge_layer.skip_requested.connect(_on_dialogue_skip_requested)

	# Iniciar música de combate
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_music"):
		audio_mgr.play_music("combat")

	# Inyección dinámica de objetos espaciales y asteroides periódicos
	var asteroid_spawner := AsteroidSpawner.new()
	asteroid_spawner.name = "AsteroidSpawner"
	add_child(asteroid_spawner)

	# Inyección dinámica de macro-planetas y nidos de exploración
	var planet_spawner := PlanetSpawner.new()
	planet_spawner.name = "PlanetSpawner"
	add_child(planet_spawner)

	# Chequeo de reanudación de partida activa (Mid-Run Resume)
	if SaveManager.is_resuming_run:
		SaveManager.is_resuming_run = false
		var active_data := SaveManager.load_active_run()
		if not active_data.is_empty():
			restore_run_state(active_data)
			return

	# Si es una nueva partida, iniciar secuencia de briefing con Dialogic 2
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

func _on_dialogic_timeline_started() -> void:
	if skip_badge_layer:
		skip_badge_layer.show()
	if audio_duck_manager:
		audio_duck_manager.duck_music(true)

func _on_dialogue_skip_requested() -> void:
	if is_briefing_active and not prologue_bonus_chosen:
		prologue_bonus_chosen = true
		player.run_credits += 100
		hud.update_credits(player.run_credits)

	is_cockpit_active = false
	is_boss_transmission_active = false
	notify_menu_closed(0.4)

	if Dialogic.current_timeline != null:
		Dialogic.end_timeline(true)

	if level_up_modal and level_up_modal.has_pending_levels():
		level_up_modal.show_next_level_up()
	elif not is_any_combat_modal_active():
		get_tree().paused = false

func _on_dialogic_timeline_ended() -> void:
	if skip_badge_layer:
		skip_badge_layer.hide()
	if audio_duck_manager:
		audio_duck_manager.duck_music(false)

	if is_briefing_active:
		is_briefing_active = false
		if not prologue_bonus_chosen:
			prologue_bonus_chosen = true
			player.run_credits += 100
			hud.update_credits(player.run_credits)

	if is_cockpit_active:
		is_cockpit_active = false
		notify_menu_closed(0.4)

	if is_boss_transmission_active:
		is_boss_transmission_active = false
		notify_menu_closed(0.4)

	if level_up_modal and level_up_modal.has_pending_levels():
		level_up_modal.show_next_level_up()
	elif not is_any_combat_modal_active():
		get_tree().paused = false

func _trigger_cockpit_interlude() -> void:
	is_cockpit_active = true
	get_tree().paused = true
	if skip_badge_layer:
		skip_badge_layer.show()
	var layout = Dialogic.start("res://narrative/timelines/wave_interlude_cockpit.dtl")
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_dialogic_audio(layout)


func _process(delta: float) -> void:
	if get_tree().paused or is_briefing_active or is_cockpit_active or is_boss_transmission_active:
		return

	# Cronómetro de tiempo total de la run
	run_time_elapsed += delta

	# Temporizador de auto-guardado periódico en segundo plano
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		save_current_run_state()

	# Lógica del temporizador de oleada
	wave_timer -= delta
	if wave_timer <= 0.0:
		current_wave += 1
		wave_timer = WAVE_DURATION
		wave_satellites_spawned = 0
		if enemy_spawner and enemy_spawner.has_method("set_wave"):
			enemy_spawner.set_wave(current_wave)
		_trigger_cockpit_interlude()
		_check_wave_boss_spawn()
		save_current_run_state()

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

func _check_wave_boss_spawn() -> void:
	# Aparece en oleadas pares (2, 4, 6...)
	if current_wave % 2 == 0 and current_boss == null:
		_spawn_wave_boss()

func _spawn_wave_boss() -> void:
	if current_boss != null or not is_instance_valid(player):
		return

	# Pausar la generación de drones comunes para duelo 1v1
	if enemy_spawner and enemy_spawner.has_method("set_spawning_paused"):
		enemy_spawner.set_spawning_paused(true)

	var forward := player.velocity.normalized() if player.velocity.length_squared() > 10.0 else Vector2.UP
	var boss_pos := player.global_position + forward * 650.0

	current_boss = boss_scene.instantiate() as BossMothership
	current_boss.global_position = boss_pos
	add_child(current_boss)

	# Conexiones con HUD
	hud.show_boss(current_boss.boss_name, current_boss.max_health)
	current_boss.health_changed.connect(hud.update_boss_health)
	current_boss.phase_changed.connect(hud.set_boss_phase)
	current_boss.boss_defeated.connect(_on_boss_defeated)

	# Transmisión narrativa opcional
	var bus := get_node_or_null("/root/EventBus")
	if bus and bus.has_signal("boss_spawn_requested"):
		bus.boss_spawn_requested.emit("boss_titan_alert", current_boss.boss_id, false)

func _on_boss_defeated(_boss_id: String) -> void:
	current_boss = null
	hud.hide_boss()

	# Reanudar la generación de drones comunes
	if enemy_spawner and enemy_spawner.has_method("set_spawning_paused"):
		enemy_spawner.set_spawning_paused(false)
	save_current_run_state()

func _input(event: InputEvent) -> void:
	# Atajo para saltar el briefing o secuencias de diálogo cinematográfico con ESC o acción dialogue_skip
	if is_briefing_active or is_cockpit_active or is_boss_transmission_active:
		if event.is_action_pressed("dialogue_skip") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			_on_dialogue_skip_requested()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		# Tecla B para invocar o testear al jefe inmediatamente
		if event.keycode == KEY_B:
			if current_boss == null:
				_spawn_wave_boss()
		# Tecla T para testear en cualquier momento la transmisión cinemática de jefe
		elif event.keycode == KEY_T:
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
	save_current_run_state()

func trigger_boss_transmission(_speaker: String = "", _text: String = "") -> void:
	is_boss_transmission_active = true
	get_tree().paused = true
	if skip_badge_layer:
		skip_badge_layer.show()
	var layout = Dialogic.start("res://narrative/timelines/boss_titan_alert.dtl")
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_dialogic_audio(layout)

func _on_item_purchased(item_or_weapon: Resource, cost: int) -> void:
	var debug_mgr = get_node_or_null("/root/DebugManager")
	if debug_mgr and debug_mgr.has_method("is_infinite_credits_active") and debug_mgr.is_infinite_credits_active():
		player.run_credits = 999999
	else:
		player.run_credits -= cost
	if item_or_weapon is WeaponData:
		var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
		if w_ctrl:
			w_ctrl.add_weapon(item_or_weapon as WeaponData)
	elif item_or_weapon is ItemData:
		player.inventory.add_item(item_or_weapon as ItemData, 1)
	hud.update_credits(player.run_credits)
	save_current_run_state()

func _on_level_up_requested(level: int) -> void:
	if is_satellite_shop_active() or is_dialogue_active():
		level_up_modal.queue_level_up(level)
	else:
		level_up_modal.show_level_up(level)
	save_current_run_state()

func _on_satellite_shop_closed() -> void:
	if level_up_modal and level_up_modal.has_pending_levels():
		level_up_modal.show_next_level_up()

func is_pause_menu_active() -> bool:
	return pause_menu != null and pause_menu.visible

func is_satellite_shop_active() -> bool:
	return satellite_shop != null and satellite_shop.visible

func is_level_up_modal_active() -> bool:
	return level_up_modal != null and level_up_modal.visible

func is_character_stats_active() -> bool:
	return character_stats_overlay != null and (character_stats_overlay.is_open or character_stats_overlay.visible)

func is_dialogue_active() -> bool:
	if is_briefing_active or is_cockpit_active or is_boss_transmission_active:
		return true
	var dialogic = get_node_or_null("/root/Dialogic")
	if dialogic and "current_timeline" in dialogic and dialogic.current_timeline != null:
		if dialogic.has_method("get_subsystem"):
			var styles = dialogic.get_subsystem("Styles")
			if styles and styles.has_method("has_active_layout_node") and styles.has_active_layout_node():
				var l_node = styles.get_layout_node()
				if is_instance_valid(l_node) and l_node.is_inside_tree():
					if "visible" in l_node:
						return bool(l_node.visible)
					elif l_node.has_method("is_visible_in_tree"):
						return l_node.is_visible_in_tree()
					return true
				return false
		return false
	return false

func is_any_combat_modal_active() -> bool:
	if is_dialogue_active():
		return true
	if is_satellite_shop_active():
		return true
	if is_level_up_modal_active():
		return true
	if level_up_modal and level_up_modal.has_pending_levels():
		return true
	if is_pause_menu_active():
		return true
	if is_character_stats_active():
		return true
	var reset_overlay = get_node_or_null("HoldToResetOverlay") as HoldToResetOverlay
	if reset_overlay and (reset_overlay.visible or reset_overlay.current_hold > 0.0):
		return true
	var vp := get_viewport()
	if vp:
		var focused := vp.gui_get_focus_owner()
		if focused and focused.is_visible_in_tree():
			return true
	return false

func notify_menu_closed(duration: float = 0.35) -> void:
	if is_instance_valid(player) and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(duration)


func restore_combat_modal_focus() -> void:
	if is_level_up_modal_active() and level_up_modal.has_method("restore_focus"):
		level_up_modal.restore_focus()
	elif is_satellite_shop_active() and satellite_shop.has_method("restore_focus"):
		satellite_shop.restore_focus()

func _on_player_bomb_used(_remaining: int) -> void:
	if camera:
		camera.add_trauma(0.6)

func _on_player_health_changed(current: float, _max_val: float) -> void:
	if current < _last_player_hp:
		if camera:
			camera.add_trauma(0.4)
	_last_player_hp = current

func _on_enemy_killed(_enemy_type: String) -> void:
	enemies_killed_count += 1

func _on_player_died() -> void:
	if level_up_modal and level_up_modal.has_method("clear_pending_levels"):
		level_up_modal.clear_pending_levels()

	# 1. Eliminar partida en curso (Permadeath)
	SaveManager.clear_active_run()

	# 2. Registrar resultado en la tabla de Highscores
	var minutes := int(run_time_elapsed) / 60
	var seconds := int(run_time_elapsed) % 60
	var time_str := "%02d:%02d" % [minutes, seconds]
	var pilot_id: String = String(player.character_data.character_id) if player.character_data and player.character_data.character_id else "nova"
	var pilot_name: String = player.character_data.display_name if player.character_data and player.character_data.display_name != "" else "Piloto Estelar"

	SaveManager.record_run_score({
		"pilot_id": pilot_id,
		"pilot_name": pilot_name,
		"wave_reached": current_wave,
		"time_survived_seconds": run_time_elapsed,
		"time_survived_formatted": time_str,
		"enemies_killed": enemies_killed_count,
		"credits_earned": player.run_credits,
		"victory": false
	})

	# Volver al HUB 3D tras una breve pausa
	get_tree().create_timer(1.2).timeout.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")
	)

# ==============================================================================
# SERIALIZACIÓN Y RESTAURACIÓN DEL ESTADO DE LA RUN
# ==============================================================================

func get_current_run_state() -> Dictionary:
	if not is_instance_valid(player) or player.current_health <= 0.0:
		return {}

	var pilot_id: String = String(player.character_data.character_id) if player.character_data and player.character_data.character_id else "nova"
	var pilot_name: String = player.character_data.display_name if player.character_data and player.character_data.display_name != "" else "Piloto Estelar"

	# Armas equipadas
	var weapons_data: Array[Dictionary] = []
	var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
	if w_ctrl:
		for inst in w_ctrl.equipped_weapons:
			if inst.weapon_data:
				weapons_data.append({
					"id": String(inst.weapon_data.weapon_id),
					"level": inst.level
				})

	# Ítems de inventario
	var items_data: Array[Dictionary] = []
	if player.inventory:
		for it_entry in player.inventory.get_all_items():
			var it_res: ItemData = it_entry.get("data")
			if it_res:
				items_data.append({
					"id": String(it_res.item_id),
					"count": int(it_entry.get("count", 1))
				})

	# Cartas de nivel (Brotato)
	var cards_data: Array[String] = []
	for card in player.chosen_stat_cards:
		cards_data.append(String(card.card_id))

	return {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"pilot_id": pilot_id,
		"pilot_name": pilot_name,
		"current_wave": current_wave,
		"wave_timer": wave_timer,
		"wave_satellites_spawned": wave_satellites_spawned,
		"satellites_collected_total": satellites_collected_total,
		"current_satellite_idx": current_satellite_idx,
		"run_time_elapsed": run_time_elapsed,
		"enemies_killed_count": enemies_killed_count,
		"prologue_bonus_chosen": prologue_bonus_chosen,
		"player_health": player.current_health,
		"player_level": player.current_level,
		"player_exp": player.current_exp,
		"player_exp_to_next": player.exp_to_next,
		"run_credits": player.run_credits,
		"run_biomass": player.run_biomass,
		"bomb_count": player.bomb_count,
		"equipped_weapons": weapons_data,
		"equipped_items": items_data,
		"chosen_stat_cards": cards_data
	}

func save_current_run_state() -> void:
	if not is_instance_valid(player) or player.current_health <= 0.0:
		return
	var state := get_current_run_state()
	if not state.is_empty():
		SaveManager.save_active_run(state)

func restore_run_state(run_data: Dictionary) -> void:
	# 1. Variables de oleada y progresión global
	current_wave = int(run_data.get("current_wave", 1))
	wave_timer = float(run_data.get("wave_timer", WAVE_DURATION))
	wave_satellites_spawned = int(run_data.get("wave_satellites_spawned", 0))
	satellites_collected_total = int(run_data.get("satellites_collected_total", 0))
	current_satellite_idx = int(run_data.get("current_satellite_idx", 1))
	run_time_elapsed = float(run_data.get("run_time_elapsed", 0.0))
	enemies_killed_count = int(run_data.get("enemies_killed_count", 0))
	prologue_bonus_chosen = bool(run_data.get("prologue_bonus_chosen", true))

	is_briefing_active = false
	get_tree().paused = false
	if skip_badge_layer:
		skip_badge_layer.hide()

	if enemy_spawner and enemy_spawner.has_method("set_wave"):
		enemy_spawner.set_wave(current_wave)

	# 2. Restaurar estadísticas básicas del jugador
	player.current_level = int(run_data.get("player_level", 1))
	player.current_exp = float(run_data.get("player_exp", 0.0))
	player.exp_to_next = float(run_data.get("player_exp_to_next", 40.0))
	player.run_credits = int(run_data.get("run_credits", 0))
	player.run_biomass = int(run_data.get("run_biomass", 0))
	player.bomb_count = int(run_data.get("bomb_count", 2))

	# 3. Restaurar cartas de nivel elegidas (Brotato)
	player.chosen_stat_cards.clear()
	var saved_cards: Array = run_data.get("chosen_stat_cards", [])
	var card_map: Dictionary = {}
	for card in stat_deck_manager.all_stat_cards:
		card_map[String(card.card_id)] = card

	for cid in saved_cards:
		var s_cid := String(cid)
		if card_map.has(s_cid):
			var card_res: StatCardData = card_map[s_cid]
			player.chosen_stat_cards.append(card_res)
			stat_deck_manager.apply_card_to_stats(card_res, player.stats)

	# 4. Restaurar ítems adquiridos en inventario
	if player.inventory:
		player.inventory.clear_items()
		var saved_items: Array = run_data.get("equipped_items", [])
		var item_map: Dictionary = {}
		for it in ItemPoolManager.create_canonical_stat_items():
			item_map[String(it.item_id)] = it

		for it_entry in saved_items:
			var i_id: String = String(it_entry.get("id", ""))
			var i_count: int = int(it_entry.get("count", 1))
			if item_map.has(i_id):
				player.inventory.add_item(item_map[i_id], i_count)

	# 5. Restaurar armas equipadas y sus niveles
	var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
	var saved_weapons: Array = run_data.get("equipped_weapons", [])
	if w_ctrl and not saved_weapons.is_empty():
		w_ctrl.clear_equipped_weapons()
		var weapon_catalog: Dictionary = {
			"rail_launcher": "res://data/weapons/roster/rail_launcher.tres",
			"hive_cannon": "res://data/weapons/roster/hive_cannon.tres",
			"singularity_pulsar": "res://data/weapons/roster/singularity_pulsar.tres",
			"sniper_rifle": "res://data/weapons/roster/sniper_rifle.tres",
			"tesla_arc": "res://data/weapons/roster/tesla_arc.tres",
			"titan_shotgun": "res://data/weapons/roster/titan_shotgun.tres",
			"cluster_submunition": "res://data/weapons/shop/cluster_submunition.tres",
			"dimensional_blade": "res://data/weapons/shop/dimensional_blade.tres",
			"nova_flak": "res://data/weapons/shop/nova_flak.tres",
			"solar_beam": "res://data/weapons/shop/solar_beam.tres",
		}
		for w_entry in saved_weapons:
			var w_id: String = str(w_entry.get("id", ""))
			var w_lvl: int = int(w_entry.get("level", 1))
			if weapon_catalog.has(w_id) and ResourceLoader.exists(weapon_catalog[w_id]):
				var w_res = load(weapon_catalog[w_id]) as WeaponData
				if w_res:
					w_ctrl.add_weapon(w_res)
					for _l in range(2, w_lvl + 1):
						w_ctrl.upgrade_weapon(StringName(w_id))

	# 6. Restaurar salud
	player.current_health = minf(float(run_data.get("player_health", 100.0)), player.stats.get_stat(&"max_health"))
	_last_player_hp = player.current_health

	# 7. Actualizar todo el HUD
	hud.update_credits(player.run_credits)
	hud.update_exp(player.current_exp, player.exp_to_next, player.current_level)
	hud.update_wave_status(current_wave, wave_timer, wave_satellites_spawned, MAX_SATELLITES_PER_WAVE)
	player.health_changed.emit(player.current_health, player.stats.get_stat(&"max_health"))
	player.bomb_used.emit(player.bomb_count)
