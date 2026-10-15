class_name CombatForkDirector
extends CombatSubsystem

## CombatForkDirector.gd
## Orquestador del ciclo de drenado de oleada (Wave Drain) y selección de bifurcaciones (Fork Decisions).
## Controla el frenado cinemático, anclaje de posición P0, proyección de tarjetas en HUD y confirmación táctica.

enum State {
	IDLE,
	DRAINING_WAVE,
	CINEMATIC_BRAKE,
	SELECTING_FORK,
	CONFIRMING,
}

signal wave_drain_started()
signal fork_selection_started()
signal fork_selection_completed(chosen_option: RunForkOptionData)

const RunForkOverlayClass = preload("res://scenes/combat/ui/run_fork_overlay.gd")

const STARTER_FORK_PATHS: Array[String] = [
	"res://resources/run_forks/starter/fork_hostile_storm.tres",
	"res://resources/run_forks/starter/fork_sector_jump.tres",
	"res://resources/run_forks/starter/fork_hyper_propulsion.tres",
	"res://resources/run_forks/starter/fork_orbital_beacon.tres",
]

var current_state: State = State.IDLE
var anchor_position: Vector2 = Vector2.ZERO
var available_forks: Array[RunForkOptionData] = []
var current_choices: Array[RunForkOptionData] = []
var overlay: RunForkOverlayClass = null
var transition_timer: float = 0.0
var drain_timer: float = 0.0
var drain_timeout: float = 12.0
var decision_time: float = 0.8
var selected_index: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"fork_director")
	if available_forks.is_empty():
		_load_default_fork_pool()


func setup_director(p_context: CombatContextScript, p_overlay: RunForkOverlayClass = null, p_fork_pool: Array[RunForkOptionData] = []) -> void:
	setup_subsystem(p_context)
	if p_overlay:
		overlay = p_overlay
	if not p_fork_pool.is_empty():
		available_forks = p_fork_pool
	elif available_forks.is_empty():
		_load_default_fork_pool()
	if context:
		context.fork_director = self


func is_blocking_combat() -> bool:
	return current_state != State.IDLE


func is_active() -> bool:
	return current_state != State.IDLE


func start_wave_drain() -> void:
	if current_state != State.IDLE:
		return

	current_state = State.DRAINING_WAVE
	drain_timer = 0.0
	wave_drain_started.emit()

	# 1. Detener spawn de nuevos enemigos
	if context and context.enemy_spawner:
		if "is_spawning_enabled" in context.enemy_spawner:
			context.enemy_spawner.is_spawning_enabled = false
		elif context.enemy_spawner.has_method("set_spawning_paused"):
			context.enemy_spawner.set_spawning_paused(true)

	# 2. Culling off-screen inmediato de enemigos y balas
	var cam_rect: Rect2 = _get_camera_viewport_rect()
	if context and context.enemy_spawner and context.enemy_spawner.has_method("despawn_offscreen_enemies"):
		context.enemy_spawner.despawn_offscreen_enemies(cam_rect)
	if context and context.bullet_server and context.bullet_server.has_method("despawn_offscreen_bullets"):
		context.bullet_server.despawn_offscreen_bullets(cam_rect)


func _process(delta: float) -> void:
	match current_state:
		State.DRAINING_WAVE:
			_process_draining_wave(delta)
		State.CINEMATIC_BRAKE:
			_process_cinematic_brake(delta)
		State.SELECTING_FORK:
			_process_selecting_fork(delta)
		State.CONFIRMING:
			_process_confirming(delta)
		State.IDLE:
			pass


func _process_draining_wave(delta: float) -> void:
	drain_timer += delta
	var cam_rect: Rect2 = _get_camera_viewport_rect()

	# Culling continuo de cualquier enemigo o proyectil que cruce fuera de pantalla
	if context and context.enemy_spawner and context.enemy_spawner.has_method("despawn_offscreen_enemies"):
		context.enemy_spawner.despawn_offscreen_enemies(cam_rect)
	if context and context.bullet_server and context.bullet_server.has_method("despawn_offscreen_bullets"):
		context.bullet_server.despawn_offscreen_bullets(cam_rect)

	var remaining_count: int = 0
	if context and context.enemy_spawner and context.enemy_spawner.has_method("get_onscreen_enemy_count"):
		remaining_count = context.enemy_spawner.get_onscreen_enemy_count(cam_rect)
	elif is_inside_tree():
		remaining_count = get_tree().get_nodes_in_group(&"enemies").size()

	# Al limpiar la pantalla (o por timeout de seguridad), entramos en frenado cinemático
	if remaining_count == 0 or drain_timer >= drain_timeout:
		_enter_cinematic_brake()


func force_fork_selection() -> void:
	current_state = State.DRAINING_WAVE
	_enter_cinematic_brake()


func _enter_cinematic_brake() -> void:
	current_state = State.CINEMATIC_BRAKE
	transition_timer = 0.4

	# Frenado en seco
	if context and is_instance_valid(context.player):
		context.player.velocity = Vector2.ZERO
		anchor_position = context.player.global_position
	elif is_inside_tree():
		var p := get_tree().get_first_node_in_group(&"player") as Node2D
		if p:
			p.set("velocity", Vector2.ZERO)
			anchor_position = p.global_position

	# Limpieza de balas enemigas residuales para blindar al jugador durante la seleccion
	if context and context.bullet_server and context.bullet_server.has_method("clear_all_bullets"):
		context.bullet_server.clear_all_bullets()

	var cur_wave: int = context.current_wave if context else 1
	current_choices = draw_fork_choices(4, cur_wave)

	if overlay:
		overlay.present_choices(current_choices)

	fork_selection_started.emit()


func _process_cinematic_brake(delta: float) -> void:
	transition_timer -= delta
	if transition_timer <= 0.0:
		current_state = State.SELECTING_FORK


func _process_selecting_fork(_delta: float) -> void:
	var player_pos: Vector2 = anchor_position
	if context and is_instance_valid(context.player):
		player_pos = context.player.global_position
	elif is_inside_tree():
		var p := get_tree().get_first_node_in_group(&"player") as Node2D
		if p:
			player_pos = p.global_position

	var delta_vec: Vector2 = player_pos - anchor_position
	var dist: float = delta_vec.length()
	var speed: float = get_player_speed()
	var threshold: float = calculate_threshold_distance(speed)

	if overlay:
		overlay.update_displacement(delta_vec, threshold)

	if dist >= threshold and threshold > 0.0:
		var q_idx: int = RunForkOverlayClass.get_quadrant_index_for_vector(delta_vec)
		if q_idx >= 0 and q_idx < current_choices.size():
			_confirm_choice(q_idx)


func _confirm_choice(choice_idx: int) -> void:
	current_state = State.CONFIRMING
	selected_index = choice_idx
	transition_timer = 0.5

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")

	if overlay:
		overlay.play_confirm_sequence(choice_idx)


func _process_confirming(delta: float) -> void:
	transition_timer -= delta
	if transition_timer <= 0.0:
		var chosen: RunForkOptionData = current_choices[selected_index] if (selected_index >= 0 and selected_index < current_choices.size()) else null

		if chosen:
			var rmm: Node = context.run_modifier_manager if context else null
			if not rmm and context and context.main_game and "run_modifier_manager" in context.main_game:
				rmm = context.main_game.run_modifier_manager
			if not rmm and is_inside_tree():
				rmm = get_tree().get_first_node_in_group(&"run_modifier_manager")

			if rmm and rmm.has_method("register_fork_choice"):
				rmm.register_fork_choice(chosen)

		if overlay:
			overlay.hide_overlay()

		if context and context.enemy_spawner:
			if "is_spawning_enabled" in context.enemy_spawner:
				context.enemy_spawner.is_spawning_enabled = true
			elif context.enemy_spawner.has_method("set_spawning_paused"):
				context.enemy_spawner.set_spawning_paused(false)

		current_state = State.IDLE

		fork_selection_completed.emit(chosen)

		if context and context.main_game and context.main_game.has_method("save_current_run_state"):
			context.main_game.save_current_run_state()


func draw_fork_choices(count: int, wave: int) -> Array[RunForkOptionData]:
	if available_forks.is_empty():
		_load_default_fork_pool()

	var eligible: Array[RunForkOptionData] = []
	for fork: RunForkOptionData in available_forks:
		if is_instance_valid(fork) and wave >= fork.min_wave and wave <= fork.max_wave:
			eligible.append(fork)

	if eligible.is_empty():
		eligible = available_forks.duplicate()

	var drawn: Array[RunForkOptionData] = []
	var pool: Array[RunForkOptionData] = eligible.duplicate()

	while drawn.size() < count and not pool.is_empty():
		var total_weight: float = 0.0
		for opt in pool:
			total_weight += maxf(0.1, opt.weight)

		var roll: float = randf() * total_weight
		var cumulative: float = 0.0
		var selected_idx: int = 0

		for i in range(pool.size()):
			cumulative += maxf(0.1, pool[i].weight)
			if roll <= cumulative:
				selected_idx = i
				break

		drawn.append(pool[selected_idx])
		pool.remove_at(selected_idx)

	# Si el pool fue menor que count, rellenar sin duplicar el primero
	while drawn.size() < count and not eligible.is_empty():
		drawn.append(eligible[drawn.size() % eligible.size()])

	return drawn


func calculate_threshold_distance(player_speed: float) -> float:
	return decision_time * maxf(50.0, player_speed)


func get_player_speed() -> float:
	if context and is_instance_valid(context.player):
		if "stats" in context.player and context.player.stats:
			return context.player.stats.get_stat(&"move_speed")
		elif "movement_speed" in context.player:
			return float(context.player.movement_speed)
		elif "move_speed" in context.player:
			return float(context.player.move_speed)
	return 200.0


func _get_camera_viewport_rect() -> Rect2:
	if context and is_instance_valid(context.camera):
		var vp_size: Vector2 = context.camera.get_viewport_rect().size
		var zoom: Vector2 = context.camera.zoom
		var eff_size: Vector2 = vp_size / zoom if (zoom.x > 0.0 and zoom.y > 0.0) else vp_size
		return Rect2(context.camera.global_position - (eff_size * 0.5), eff_size)

	var def_size: Vector2 = Vector2(1920.0, 1080.0)
	var center: Vector2 = anchor_position
	if context and is_instance_valid(context.player):
		center = context.player.global_position
	return Rect2(center - (def_size * 0.5), def_size)


func _load_default_fork_pool() -> void:
	for path: String in STARTER_FORK_PATHS:
		if ResourceLoader.exists(path):
			var res: RunForkOptionData = load(path) as RunForkOptionData
			if res and not available_forks.has(res):
				available_forks.append(res)
