class_name CompanionPet
extends Node2D

## companion_pet.gd
## Mascota acompañante espacial que asiste al jugador en combate sin hitbox.
## Flota y orbita alegremente alrededor de la nave espacial ejecutando habilidades
## únicas según el arquetipo de mascota seleccionado.

enum State {
	ORBITING,
	FETCHING,
	ATTACKING
}

@export var pet_data: PetData

var player: Player = null
var current_state: State = State.ORBITING
var _orbit_angle: float = 0.0
var _orbit_radius: float = 75.0
var _orbit_speed: float = 1.8
var _float_time: float = 0.0

# Targets y temporizadores
var _target_exp_blob: WeakRef = null
var _target_enemy: WeakRef = null
var _attack_cooldown_timer: float = 0.0
var _support_pulse_timer: float = 15.0
var _pip_steal_timer: float = 5.0
var _cosmo_laser_timer: float = 0.8
var _is_doing_flip: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var aura_particles: CPUParticles2D = get_node_or_null("AuraParticles")
@onready var laser_beam: Line2D = get_node_or_null("LaserBeam")

func _ready() -> void:
	z_index = 25
	if not pet_data:
		var pid := SaveManager.get_selected_pet()
		const PetDataScript := preload("res://data/pets/pet_data.gd")
		pet_data = PetDataScript.get_pet(pid)

	_apply_pet_visuals()
	_acquire_player()
	_apply_passive_buffs()

func setup(p_data: PetData, p_player: Player) -> void:
	pet_data = p_data
	player = p_player
	_apply_pet_visuals()
	_apply_passive_buffs()

func _acquire_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if is_instance_valid(player):
		global_position = player.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * _orbit_radius

func _apply_pet_visuals() -> void:
	if not pet_data:
		return
	if sprite and pet_data.icon:
		sprite.texture = pet_data.icon
		sprite.scale = Vector2(0.55, 0.55)
	if aura_particles:
		aura_particles.color = pet_data.theme_color
		aura_particles.emitting = true

func _apply_passive_buffs() -> void:
	if not is_instance_valid(player) or not player.stats or not pet_data:
		return
	# Pip: Bono pasivo constante de +15% cadencia y +8% crítico
	if pet_data.pet_id == &"pip":
		player.stats.add_modifier(&"attack_speed", CharacterStats.StatModifier.new(&"pet_pip_atk_spd", 0.15, true, self))
		player.stats.add_modifier(&"crit_chance", CharacterStats.StatModifier.new(&"pet_pip_crit", 0.08, false, self))

func _exit_tree() -> void:
	if is_instance_valid(player) and player.stats:
		player.stats.remove_modifier(&"attack_speed", &"pet_pip_atk_spd")
		player.stats.remove_modifier(&"crit_chance", &"pet_pip_crit")

func _process(delta: float) -> void:
	_float_time += delta
	if sprite and not _is_doing_flip:
		sprite.position.y = sin(_float_time * 4.5) * 4.0
		sprite.rotation = sin(_float_time * 2.2) * 0.12

	if not is_instance_valid(player):
		_acquire_player()
		if not is_instance_valid(player):
			return

	var pid := pet_data.pet_id if pet_data else &"mochi"

	# Lógica por tipo de mascota
	match pid:
		&"mochi":
			_process_mochi(delta)
		&"kuro":
			_process_kuro(delta)
		&"luna":
			_process_luna(delta)
		&"pip":
			_process_pip(delta)
		&"cosmo":
			_process_cosmo(delta)

	# Movimiento según estado
	match current_state:
		State.ORBITING:
			_process_orbiting(delta)
		State.FETCHING:
			_process_fetching(delta)
		State.ATTACKING:
			_process_attacking(delta)

func _process_orbiting(delta: float) -> void:
	_orbit_angle += _orbit_speed * delta
	if _orbit_angle > TAU:
		_orbit_angle -= TAU
	var target_pos := player.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * _orbit_radius
	global_position = global_position.lerp(target_pos, delta * 7.5)

	# Voltear sprite según dirección
	if sprite:
		var dir_x := target_pos.x - global_position.x
		if absf(dir_x) > 1.0:
			sprite.flip_h = (dir_x < 0.0)

# ── 1. MOCHI: IMÁN DE EXP DINÁMICO ──────────────────────────────────────────
func _process_mochi(delta: float) -> void:
	if current_state == State.ORBITING:
		var p_radius: float = player.stats.get_stat(&"pickup_radius") if player.stats else 100.0
		var max_search_dist := p_radius * 3.5 + 280.0
		var best_blob: ExpBlob = null
		var best_dist := 999999.0

		for node in get_tree().get_nodes_in_group("exp_blobs"):
			if is_instance_valid(node) and node is ExpBlob:
				var blob := node as ExpBlob
				if blob.is_collected or blob.is_being_absorbed:
					continue
				var d := global_position.distance_to(blob.global_position)
				var d_player := player.global_position.distance_to(blob.global_position)
				# Buscar blobs que estén fuera del alcance inmediato del jugador
				if d_player > p_radius * 1.3 and d < max_search_dist and d < best_dist:
					best_dist = d
					best_blob = blob

		if best_blob:
			_target_exp_blob = weakref(best_blob)
			current_state = State.FETCHING

func _process_fetching(delta: float) -> void:
	var blob = _target_exp_blob.get_ref() if _target_exp_blob else null
	if not blob or not is_instance_valid(blob) or blob.is_collected or blob.is_being_absorbed:
		current_state = State.ORBITING
		return

	var p_radius: float = player.stats.get_stat(&"pickup_radius") if (player and player.stats) else 100.0
	var fetch_speed := 440.0 + (p_radius * 1.6)
	var dir: Vector2 = (blob.global_position - global_position).normalized()
	global_position += dir * fetch_speed * delta

	if sprite:
		sprite.flip_h = (dir.x < 0.0)

	if global_position.distance_to(blob.global_position) < 32.0:
		# Recolectar gema y darle la EXP al jugador
		blob._collect()
		_play_happy_flip()
		current_state = State.ORBITING

func _play_happy_flip() -> void:
	if _is_doing_flip or not sprite:
		return
	_is_doing_flip = true
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "rotation", sprite.rotation + TAU, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _is_doing_flip = false)

# ── 2. KURO: ZARPAZO A ENEMIGOS 1 A 1 ───────────────────────────────────────
func _process_kuro(delta: float) -> void:
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	if current_state == State.ORBITING and _attack_cooldown_timer <= 0.0:
		var nearest_enemy: Node2D = null
		var min_dist := 380.0
		for node in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(node) and node is Node2D:
				var d := player.global_position.distance_to(node.global_position)
				if d < min_dist:
					min_dist = d
					nearest_enemy = node
		if nearest_enemy:
			_target_enemy = weakref(nearest_enemy)
			current_state = State.ATTACKING

func _process_attacking(delta: float) -> void:
	var enemy = _target_enemy.get_ref() if _target_enemy else null
	if not enemy or not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead):
		current_state = State.ORBITING
		_attack_cooldown_timer = 0.4
		return

	var attack_speed := 650.0
	var dir: Vector2 = (enemy.global_position - global_position).normalized()
	global_position += dir * attack_speed * delta

	if sprite:
		sprite.flip_h = (dir.x < 0.0)

	if global_position.distance_to(enemy.global_position) < 35.0:
		# Ejecutar Zarpazo
		if enemy.has_method("take_damage"):
			enemy.take_damage(18.0)
		_spawn_claw_scratch_vfx(enemy.global_position)
		_play_happy_flip()
		_attack_cooldown_timer = 1.2
		current_state = State.ORBITING

func _spawn_claw_scratch_vfx(pos: Vector2) -> void:
	var p: Node = get_parent() if is_inside_tree() else null
	if not p: return
	var claw := Line2D.new()
	claw.width = 4.0
	claw.default_color = Color(1.0, 0.2, 0.35, 0.95)
	claw.points = PackedVector2Array([Vector2(-14, -14), Vector2(14, 14)])
	claw.global_position = pos
	p.add_child(claw)
	var tw := claw.create_tween()
	tw.tween_property(claw, "modulate:a", 0.0, 0.22)
	tw.tween_callback(claw.queue_free)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.8)

# ── 3. LUNA: PULSO PURPURINA (SANACIÓN + RALENTIZACIÓN) ─────────────────────
func _process_luna(delta: float) -> void:
	_support_pulse_timer -= delta
	if _support_pulse_timer <= 0.0:
		_support_pulse_timer = 15.0
		_trigger_luna_pulse()

func _trigger_luna_pulse() -> void:
	if not is_instance_valid(player):
		return
	# Restaurar +8 HP al jugador
	var max_hp: float = player.stats.get_stat(&"max_health") if player.stats else 100.0
	player.current_health = minf(player.current_health + 8.0, max_hp)
	player.health_changed.emit(player.current_health, max_hp)

	var p_parent: Node = get_parent() if is_inside_tree() else null
	if p_parent:
		FloatingText.spawn(p_parent, player.global_position + Vector2(0, -38), "💖 +8 HP", Color(0.4, 1.0, 0.85))

	_play_happy_flip()

# ── 4. PIP: ROBO DE CRÉDITOS Y PASIVOS ───────────────────────────────────────
func _process_pip(delta: float) -> void:
	_pip_steal_timer -= delta
	if _pip_steal_timer <= 0.0:
		_pip_steal_timer = 5.5
		# Robar créditos si hay enemigos alrededor
		var has_nearby := false
		for node in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(node) and global_position.distance_to(node.global_position) < 320.0:
				has_nearby = true
				break
		if has_nearby and is_instance_valid(player):
			player.add_credits(3)
			var p_parent: Node = get_parent() if is_inside_tree() else null
			if p_parent:
				FloatingText.spawn(p_parent, global_position + Vector2(0, -25), "+3 💰", Color(1.0, 0.88, 0.2))

# ── 5. COSMO: HÍBRIDO ASTRAL (EXP GRAVITACIONAL + MICRO-LÁSER) ──────────────
func _process_cosmo(delta: float) -> void:
	# 1. Succión continua de EXP cercana
	for node in get_tree().get_nodes_in_group("exp_blobs"):
		if is_instance_valid(node) and node is ExpBlob:
			var blob := node as ExpBlob
			if not blob.is_collected and not blob.is_being_absorbed:
				if global_position.distance_to(blob.global_position) < 220.0:
					blob.is_force_magnetized = true
					if global_position.distance_to(blob.global_position) < 28.0:
						blob._collect()

	# 2. Micro-láser orbital que calcina enemigos cercanos
	_cosmo_laser_timer -= delta
	if _cosmo_laser_timer <= 0.0:
		_cosmo_laser_timer = 0.85
		_fire_cosmo_laser()

func _fire_cosmo_laser() -> void:
	var target: Node2D = null
	var min_d := 320.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node is Node2D:
			var d := global_position.distance_to(node.global_position)
			if d < min_d:
				min_d = d
				target = node

	if target and laser_beam:
		laser_beam.visible = true
		laser_beam.clear_points()
		laser_beam.add_point(Vector2.ZERO)
		laser_beam.add_point(to_local(target.global_position))
		if target.has_method("take_damage"):
			target.take_damage(12.0)
		var tw := laser_beam.create_tween()
		tw.tween_property(laser_beam, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func():
			laser_beam.visible = false
			laser_beam.modulate.a = 1.0
		)
