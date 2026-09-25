class_name BossAshClock
extends CharacterBody2D

## Jefe de Oleada 4: "Reloj de Cenizas"
## Representa el Dominio del Arrepentimiento / Tiempo.
## Mecánicas: Dilatación temporal periódica, manecillas cardinales rotatorias,
## bombardeo en posiciones pasadas del jugador y aceleración cronológica en Fase 2.

signal health_changed(current: float, max_val: float)
signal phase_changed(new_phase: int)
signal boss_defeated(boss_id: String)

@export var boss_id: String = "boss_ash_clock"
@export var boss_name: String = "RELOJ DE CENIZAS"
@export var max_health: float = 2400.0

var current_health: float = 2400.0
var current_phase: int = 1
var is_dying: bool = false
var elapsed_combat_time: float = 0.0

var player: Player = null
var bullet_server: BulletServer = null

# Timers
var clock_hands_timer: float = 0.0
var echo_timer: float = 0.0
var dilation_cycle_timer: float = 0.0
var is_in_dilation: bool = false
var clock_hand_angle: float = 0.0
var is_telegraphing: bool = false

# Historial para "Eco del Arrepentimiento"
var past_player_positions: Array[Vector2] = []
var record_timer: float = 0.0

# Nodos visuales
var gear_sprite: Sprite2D = null
var dial_ring: Node2D = null
var hand_nodes: Array[Polygon2D] = []
var telegraph_material: ShaderMaterial = null
var hit_flash_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	add_to_group("bosses")

	current_health = max_health
	_acquire_references()
	_setup_visuals()

	health_changed.emit(current_health, max_health)

func _acquire_references() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(bullet_server):
		bullet_server = get_node_or_null("/root/BulletServer") as BulletServer
		if not bullet_server and get_parent():
			bullet_server = get_parent().get_node_or_null("BulletServer") as BulletServer

func _setup_visuals() -> void:
	# Material con shader de telegrafiado visual
	telegraph_material = ShaderMaterial.new()
	telegraph_material.shader = preload("res://core/shaders/boss_telegraph.gdshader")
	telegraph_material.set_shader_parameter("domain_tint", Color(1.0, 0.78, 0.25, 1.0)) # Tinte Oro Ceniza
	telegraph_material.set_shader_parameter("chromatic_aberration", 0.0)
	telegraph_material.set_shader_parameter("flash_intensity", 0.0)

	# 1. Anillo de dial cronológico (12 marcas horarias)
	dial_ring = Node2D.new()
	dial_ring.name = "ChronometerDial"
	add_child(dial_ring)

	for i in range(12):
		var angle := (TAU / 12.0) * float(i)
		var tick := Polygon2D.new()
		var is_cardinal := (i % 3 == 0)
		var t_size := Vector2(12, 4) if is_cardinal else Vector2(6, 2)
		tick.polygon = PackedVector2Array([
			Vector2(-t_size.x * 0.5, -t_size.y * 0.5),
			Vector2(t_size.x * 0.5, -t_size.y * 0.5),
			Vector2(t_size.x * 0.5, t_size.y * 0.5),
			Vector2(-t_size.x * 0.5, t_size.y * 0.5)
		])
		tick.color = Color(1.0, 0.85, 0.35, 0.95) if is_cardinal else Color(0.8, 0.65, 0.25, 0.7)
		tick.position = Vector2(cos(angle), sin(angle)) * 68.0
		tick.rotation = angle
		dial_ring.add_child(tick)

	# 2. Casco / Engranaje central
	var tex_path := "res://assets/enemies/enemy_tank.png"
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex:
			gear_sprite = Sprite2D.new()
			gear_sprite.texture = tex
			gear_sprite.scale = Vector2(1.5, 1.5)
			gear_sprite.material = telegraph_material
			add_child(gear_sprite)

	# 3. Manecillas de aguja horarias
	for i in range(4):
		var hand := Polygon2D.new()
		hand.polygon = PackedVector2Array([
			Vector2(0, -3), Vector2(48, 0), Vector2(0, 3), Vector2(-10, 0)
		])
		hand.color = Color(1.0, 0.9, 0.4, 0.85)
		hand_nodes.append(hand)
		add_child(hand)

func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_acquire_references()
	if not is_instance_valid(player):
		return

	elapsed_combat_time += delta

	# Regla Anti-Stall: Transición automática a Fase 2 al 50% HP o 70s
	if current_phase == 1 and (current_health <= max_health * 0.5 or elapsed_combat_time >= 70.0):
		_transition_to_phase_2()

	# Registro de posiciones pasadas para "Eco del Arrepentimiento"
	record_timer += delta
	if record_timer >= 0.4:
		record_timer = 0.0
		past_player_positions.append(player.global_position)
		if past_player_positions.size() > 8:
			past_player_positions.pop_front()

	# AURA DE DOMINIO: Dilatación del Arrepentimiento (pulso cíclico cada 7.5s)
	dilation_cycle_timer += delta
	if dilation_cycle_timer >= 7.5:
		dilation_cycle_timer = 0.0
		_trigger_temporal_dilation_pulse()

	# Movimiento elíptico constante
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var desired_dist := 360.0
	var move_dir := to_player.normalized().orthogonal() * 0.6
	if dist > desired_dist + 40.0:
		move_dir += to_player.normalized() * 0.4
	elif dist < desired_dist - 40.0:
		move_dir -= to_player.normalized() * 0.4

	var move_spd := 100.0 if current_phase == 1 else 145.0
	velocity = velocity.lerp(move_dir * move_spd, delta * 3.0)
	move_and_slide()

	# Rotación de manecillas con modulación armónica senoidal (acelera y frena como reloj vacilante)
	var hand_speed := 0.75 if current_phase == 1 else -1.4
	var harmonic_mod: float = sin(elapsed_combat_time * (3.0 if current_phase == 1 else 5.2)) * (0.45 if current_phase == 1 else 0.7)
	var effective_hand_speed: float = hand_speed * (1.0 + harmonic_mod)
	clock_hand_angle += delta * effective_hand_speed
	for i in range(hand_nodes.size()):
		var base_a := clock_hand_angle + (TAU / 4.0) * float(i)
		hand_nodes[i].rotation = base_a

	if dial_ring:
		dial_ring.rotation += delta * 0.15

	# Procesamiento Danmaku
	if not is_telegraphing:
		if current_phase == 1:
			_process_phase_1(delta)
		else:
			_process_phase_2(delta)

func _process_phase_1(delta: float) -> void:
	clock_hands_timer += delta
	echo_timer += delta

	# Disparo de manecillas rotatorias con ondulación senoidal cada 0.8s
	if clock_hands_timer >= 0.8:
		clock_hands_timer = 0.0
		_fire_clock_hand_spokes(4, 160.0, 1)

	# Eco del arrepentimiento cada 3.5s
	if echo_timer >= 3.5:
		echo_timer = 0.0
		_start_telegraph(0.45, Callable(self, "_detonate_past_echoes"))

func _process_phase_2(delta: float) -> void:
	clock_hands_timer += delta
	echo_timer += delta

	# Manecillas aceleradas en cruz de 8 vías con alta frecuencia senoidal cada 0.6s
	if clock_hands_timer >= 0.6:
		clock_hands_timer = 0.0
		_fire_clock_hand_spokes(8, 185.0, 2)

	# Detonaciones de eco dobles cada 2.8s
	if echo_timer >= 2.8:
		echo_timer = 0.0
		_start_telegraph(0.4, Callable(self, "_detonate_past_echoes_phase_2"))

func _fire_clock_hand_spokes(count: int, speed: float, bullet_type: int) -> void:
	if not is_instance_valid(bullet_server):
		return
	for i in range(count):
		var a := clock_hand_angle + (TAU / float(count)) * float(i)
		var dir := Vector2(cos(a), sin(a))
		var wave_sign: float = 1.0 if (i % 2 == 0) else -1.0
		bullet_server.spawn_bullet(
			global_position.x + dir.x * 55.0,
			global_position.y + dir.y * 55.0,
			dir.x * speed,
			dir.y * speed,
			bullet_type,
			4.5,
			7.0,
			14.0 * wave_sign,
			3.8
		)
	_play_sfx("laser", 0.9)

func _detonate_past_echoes() -> void:
	if not is_instance_valid(bullet_server) or past_player_positions.is_empty():
		return
	# Detonar un pulso de rosa polar de 4 cuadrantes en la posición del eco
	var target_echo := past_player_positions[0]
	bullet_server.fire_rhodonea_flower(target_echo, 12, 135.0, 4, 0.35, 0.0, 1)
	_play_sfx("missile", 1.1)

func _detonate_past_echoes_phase_2() -> void:
	if not is_instance_valid(bullet_server) or past_player_positions.size() < 2:
		return
	var pos1 := past_player_positions[0]
	var pos2 := past_player_positions[past_player_positions.size() / 2]
	bullet_server.fire_rhodonea_flower(pos1, 16, 145.0, 4, 0.35, 0.0, 1)
	bullet_server.fire_rhodonea_flower(pos2, 16, 145.0, 4, 0.35, PI / 8.0, 2)
	_play_sfx("missile", 1.2)

func _trigger_temporal_dilation_pulse() -> void:
	# Pulso visual de dilatación temporal (sutil distorsión cromática)
	if telegraph_material:
		var tw := create_tween()
		tw.tween_method(func(v: float): telegraph_material.set_shader_parameter("chromatic_aberration", v), 0.0, 0.05, 0.3)
		tw.tween_method(func(v: float): telegraph_material.set_shader_parameter("chromatic_aberration", v), 0.05, 0.0, 0.4)

func _start_telegraph(duration: float, callback: Callable) -> void:
	is_telegraphing = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.88, 0.88), duration * 0.7).set_trans(Tween.TRANS_BACK)
	if telegraph_material:
		tw.parallel().tween_method(func(val: float): telegraph_material.set_shader_parameter("chromatic_aberration", val), 0.0, 0.07, duration * 0.7)
		tw.parallel().tween_method(func(val: float): telegraph_material.set_shader_parameter("flash_intensity", val), 0.0, 0.95, duration * 0.7)

	tw.tween_callback(func():
		scale = Vector2(1.12, 1.12)
		if telegraph_material:
			telegraph_material.set_shader_parameter("chromatic_aberration", 0.0)
			telegraph_material.set_shader_parameter("flash_intensity", 0.0)
		callback.call()
		is_telegraphing = false
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.15)
	)

func _transition_to_phase_2() -> void:
	current_phase = 2
	phase_changed.emit(2)

	if is_instance_valid(bullet_server):
		bullet_server.clear_bullets_in_radius(global_position, 500.0)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.35, 1.35), 0.25)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2)

	# Cambiar tinte a oro ardiente
	if telegraph_material:
		telegraph_material.set_shader_parameter("domain_tint", Color(1.0, 0.4, 0.1, 1.0))

	_play_sfx("missile", 1.3)

func take_damage(arg) -> void:
	if is_dying:
		return

	var dmg: float = 0.0
	var is_crit: bool = false
	if arg is HitContext:
		dmg = arg.final_damage
		is_crit = arg.is_crit
	elif arg is float or arg is int:
		dmg = float(arg)
	else:
		return

	current_health -= dmg
	health_changed.emit(maxf(0.0, current_health), max_health)

	var dmg_acc := get_node_or_null("DamageAccumulator") as DamageAccumulator
	if dmg_acc:
		dmg_acc.register_hit(dmg, is_crit)

	if hit_flash_tween and hit_flash_tween.is_valid():
		hit_flash_tween.kill()
	modulate = Color(2.5, 2.5, 2.5, 1.0)
	hit_flash_tween = create_tween()
	hit_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.08)

	# Transición a Fase 2 al 50% de HP
	if current_phase == 1 and current_health <= max_health * 0.5:
		_transition_to_phase_2()

	if current_health <= 0.0:
		_die()

func _die() -> void:
	if is_dying:
		return
	is_dying = true

	if is_instance_valid(bullet_server):
		bullet_server.clear_bullets_in_radius(global_position, 600.0)

	boss_defeated.emit(boss_id)

	if is_instance_valid(player):
		player.add_credits(350)
		player.add_exp(450.0)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.5).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

func _play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name, pitch, -2.0)
