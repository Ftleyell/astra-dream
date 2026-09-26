class_name EliteHeraldBoss
extends CharacterBody2D

## Mini-Jefe Tutorial / Heraldo de Dominio (Oleadas 3, 5, 7):
## Anticipa los patrones trigonométricos de los Jefes de Dominio en una escala contenida:
## - Oleada 3: Heraldo del Tiempo (Péndulo oscilante senoidal de manecillas)
## - Oleada 5: Heraldo del Espejo (Tijeras trenzadas de Lissajous con desfase)
## - Oleada 7: Heraldo del Vórtice (Espirales de Fermat pulsantes con respiración)

signal health_changed(current: float, max_val: float)
signal boss_defeated(boss_id: String)

enum HeraldType {
	TIME = 3,
	MIRROR = 5,
	VORTEX = 7
}

@export var herald_type: HeraldType = HeraldType.TIME
@export var boss_id: String = "elite_herald"
@export var boss_name: String = "HERALDO DEL TIEMPO"
@export var max_health: float = 600.0

var current_health: float = 600.0
var is_dying: bool = false
var elapsed_time: float = 0.0
var fire_timer: float = 0.0
var pattern_angle: float = 0.0

var player: Node2D = null
var bullet_server: BulletServer = null

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var damage_accumulator: Node2D = get_node_or_null("DamageAccumulator")
@onready var visual_core: Polygon2D = get_node_or_null("VisualCore")
@onready var visual_frame: Polygon2D = get_node_or_null("VisualFrame")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	add_to_group("bosses")

	_configure_by_wave()
	current_health = max_health

	_acquire_references()
	health_changed.emit(current_health, max_health)

func setup_type(wave: int) -> void:
	herald_type = wave as HeraldType
	_configure_by_wave()

func _configure_by_wave() -> void:
	match herald_type:
		HeraldType.TIME:
			boss_id = "herald_time"
			boss_name = "HERALDO DEL TIEMPO"
			max_health = 550.0
			if visual_core:
				visual_core.color = Color(1.0, 0.8, 0.2, 1.0)
			if visual_frame:
				visual_frame.color = Color(0.85, 0.6, 0.1, 1.0)
		HeraldType.MIRROR:
			boss_id = "herald_mirror"
			boss_name = "HERALDO DEL ESPEJO"
			max_health = 750.0
			if visual_core:
				visual_core.color = Color(0.2, 0.9, 1.0, 1.0)
			if visual_frame:
				visual_frame.color = Color(0.1, 0.5, 0.9, 1.0)
		HeraldType.VORTEX:
			boss_id = "herald_vortex"
			boss_name = "HERALDO DEL VÓRTICE"
			max_health = 950.0
			if visual_core:
				visual_core.color = Color(0.8, 0.2, 1.0, 1.0)
			if visual_frame:
				visual_frame.color = Color(0.4, 0.1, 0.7, 1.0)
		_:
			boss_id = "herald_time"
			boss_name = "HERALDO DEL DOMINIO"
			max_health = 600.0

	current_health = max_health

func _acquire_references() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(bullet_server):
		bullet_server = get_node_or_null("/root/BulletServer") as BulletServer
		if not bullet_server and get_parent():
			bullet_server = get_parent().get_node_or_null("BulletServer") as BulletServer

func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_acquire_references()
	if not is_instance_valid(player):
		return

	elapsed_time += delta
	fire_timer += delta

	# Movimiento en órbita / rodeo elíptico
	var to_player := (player.global_position - global_position)
	var dist := to_player.length()
	var desired_dist := 320.0
	var tangent := to_player.normalized().orthogonal()
	var move_dir := tangent * 0.7
	if dist > desired_dist + 50.0:
		move_dir += to_player.normalized() * 0.4
	elif dist < desired_dist - 50.0:
		move_dir -= to_player.normalized() * 0.4

	velocity = velocity.lerp(move_dir * 130.0, delta * 4.0)
	move_and_slide()

	# Rotación visual
	rotation += delta * 1.5

	# Ataques específicos según heraldo
	match herald_type:
		HeraldType.TIME:
			_process_time_herald(delta)
		HeraldType.MIRROR:
			_process_mirror_herald(delta)
		HeraldType.VORTEX:
			_process_vortex_herald(delta)

func _process_time_herald(_delta: float) -> void:
	# Péndulo senoidal de manecillas: dispara cada 0.9s en un arco oscilante
	if fire_timer >= 0.9:
		fire_timer = 0.0
		if not is_instance_valid(bullet_server):
			return

		var swing_offset := sin(elapsed_time * 2.8) * 0.85
		var base_angle := (player.global_position - global_position).angle() + swing_offset
		var bullet_count: int = 5
		var arc: float = 0.5

		for i in range(bullet_count):
			var a := base_angle - (arc * 0.5) + (arc / float(bullet_count - 1)) * float(i)
			var dir := Vector2(cos(a), sin(a))
			var spd := 150.0 + (float(i) * 10.0)
			bullet_server.spawn_bullet(
				global_position.x + dir.x * 30.0,
				global_position.y + dir.y * 30.0,
				dir.x * spd,
				dir.y * spd,
				1, # bullet_type = 1
				4.5,
				8.0,
				sin(float(i)) * 12.0, # Ligera ondulación
				3.5
			)

		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("laser", 0.95)

func _process_mirror_herald(_delta: float) -> void:
	# Tijeras trenzadas de Lissajous: dispara cada 1.1s dos corrientes reflejadas
	if fire_timer >= 1.1:
		fire_timer = 0.0
		if not is_instance_valid(bullet_server):
			return

		var to_player_angle := (player.global_position - global_position).angle()
		var lissajous_spread := absf(sin(elapsed_time * 2.2)) * 0.75 + 0.15

		# Dos proyectiles curvos opuestos que cruzan sus trayectorias
		for branch: float in [-1.0, 1.0]:
			var dir_angle: float = to_player_angle + (lissajous_spread * branch)
			var dir := Vector2(cos(dir_angle), sin(dir_angle))
			bullet_server.spawn_bullet(
				global_position.x + dir.x * 32.0,
				global_position.y + dir.y * 32.0,
				dir.x * 165.0,
				dir.y * 165.0,
				2, # bullet_type = 2
				4.5,
				8.0,
				-branch * 18.0, # Curvatura opuesta para cruzar (shear)
				3.8
			)

		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("laser", 1.1)

func _process_vortex_herald(_delta: float) -> void:
	# Espiral de Fermat con modulación armónica respiratoria cada 0.7s
	if fire_timer >= 0.7:
		fire_timer = 0.0
		if not is_instance_valid(bullet_server):
			return

		var breathing := 1.0 + 0.3 * sin(elapsed_time * 4.0)
		pattern_angle += 0.45 * breathing
		var arms: int = 3
		for a in range(arms):
			var ang := pattern_angle + (TAU / float(arms)) * float(a)
			var dir := Vector2(cos(ang), sin(ang))
			bullet_server.spawn_bullet(
				global_position.x + dir.x * 28.0,
				global_position.y + dir.y * 28.0,
				dir.x * (140.0 * breathing),
				dir.y * (140.0 * breathing),
				3, # bullet_type = 3
				5.0,
				7.5,
				0.0,
				4.0
			)

		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("laser", 1.25)

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

	if damage_accumulator and damage_accumulator.has_method("register_hit"):
		damage_accumulator.register_hit(dmg, is_crit)

	modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.08)

	if current_health <= 0.0:
		_die()

func _die() -> void:
	if is_dying:
		return
	is_dying = true

	if is_instance_valid(bullet_server):
		bullet_server.clear_bullets_in_radius(global_position, 400.0)

	boss_defeated.emit(boss_id)

	if is_instance_valid(player):
		player.add_credits(120)
		player.add_exp(180.0)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("explosion", 1.1)

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
