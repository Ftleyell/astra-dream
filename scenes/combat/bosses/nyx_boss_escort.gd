class_name NyxBossEscort
extends CharacterBody2D

## Escolta Hostil de Astra Prime (Ruta Genocida / Slayer)
## Nyx (o la Sombra de Nyx si el jugador eligió a Nyx) desciende furiosa
## para castigar la masacre de sus camaradas, apoyando al Núcleo Astra Prime.

signal health_changed(current: float, max_val: float)
signal boss_defeated(boss_id: String)

@export var max_health: float = 1600.0
@export var pilot_name: String = "Nyx, Vengadora del Vacío"
@export var is_shadow: bool = false

var current_health: float = 1600.0
var is_dying: bool = false

var player: Player = null
var prime_boss: Node2D = null
var bullet_server: BulletServer = null

var orbit_angle: float = 0.0
var attack_timer: float = 1.2
var dash_timer: float = 3.5
var is_dashing: bool = false
var dash_velocity: Vector2 = Vector2.ZERO

var ship_sprite: Sprite2D = null
var aura_ring: Line2D = null
var engine_trail: Line2D = null
var hit_flash_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	add_to_group("bosses")

	current_health = max_health
	_acquire_references()
	_setup_visuals()
	health_changed.emit(current_health, max_health)

func setup(p_is_shadow: bool = false, p_prime: Node2D = null) -> void:
	is_shadow = p_is_shadow
	prime_boss = p_prime
	if is_shadow:
		pilot_name = "Sombra de Nyx: Eco del Vacío"
	else:
		pilot_name = "Nyx, Vengadora del Vacío"
	_setup_visuals()

func _acquire_references() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(bullet_server):
		bullet_server = get_node_or_null("/root/BulletServer") as BulletServer
		if not bullet_server and get_parent():
			bullet_server = get_parent().get_node_or_null("BulletServer") as BulletServer

func _setup_visuals() -> void:
	if not ship_sprite:
		ship_sprite = Sprite2D.new()
		ship_sprite.name = "ShipSprite"
		add_child(ship_sprite)

	var roster := CharacterData.load_roster()
	if roster.has(&"nyx"):
		var cd: CharacterData = roster[&"nyx"]
		var tex := cd.get_ship_texture()
		if tex:
			ship_sprite.texture = tex

	if is_shadow:
		modulate = Color(0.85, 0.45, 1.0, 0.9)
	else:
		modulate = Color(1.0, 0.35, 0.65, 1.0)

	if not aura_ring:
		aura_ring = Line2D.new()
		aura_ring.name = "VoidAura"
		aura_ring.width = 2.5
		aura_ring.default_color = Color(0.8, 0.1, 0.9, 0.75) if is_shadow else Color(1.0, 0.1, 0.35, 0.8)
		var pts := PackedVector2Array()
		for i in range(17):
			var a := (TAU / 16.0) * float(i)
			pts.append(Vector2(cos(a), sin(a)) * 36.0)
		aura_ring.points = pts
		add_child(aura_ring)

	if not engine_trail:
		engine_trail = Line2D.new()
		engine_trail.name = "EngineTrail"
		engine_trail.width = 4.0
		engine_trail.default_color = Color(1.0, 0.05, 0.4, 0.65)
		add_child(engine_trail)

func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_acquire_references()
	if not is_instance_valid(player):
		return

	# Si Astra Prime fue derrotado, Nyx desaparece en desvanecimiento
	if prime_boss != null and not is_instance_valid(prime_boss):
		_warp_out_on_prime_death()
		return

	# Movimiento de órbita y acoso dinámico
	orbit_angle += delta * 1.1
	var anchor_pos := player.global_position
	if is_instance_valid(prime_boss):
		anchor_pos = (player.global_position + prime_boss.global_position) * 0.5

	var target_pos := anchor_pos + Vector2(cos(orbit_angle), sin(orbit_angle)) * 380.0

	dash_timer -= delta
	if dash_timer <= 0.0 and not is_dashing:
		dash_timer = randf_range(3.5, 5.0)
		_start_dash()

	if is_dashing:
		velocity = dash_velocity
	else:
		var dir := (target_pos - global_position).normalized()
		var dist := global_position.distance_to(target_pos)
		var desired_vel := dir * clampf(dist * 3.5, 120.0, 360.0)
		velocity = velocity.move_toward(desired_vel, 800.0 * delta)

	move_and_slide()

	# Orientación hacia el jugador
	var to_player := (player.global_position - global_position).angle()
	rotation = rotate_toward(rotation, to_player + PI * 0.5, delta * 7.0)

	# Actualización de la estela
	if engine_trail:
		engine_trail.global_position = Vector2.ZERO
		engine_trail.global_rotation = 0.0
		engine_trail.add_point(global_position)
		if engine_trail.get_point_count() > 10:
			engine_trail.remove_point(0)

	# Ataque
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = randf_range(1.6, 2.3)
		_execute_attack()

func _start_dash() -> void:
	is_dashing = true
	var dir := (player.global_position - global_position).normalized().rotated(randf_range(-0.4, 0.4))
	dash_velocity = dir * 650.0
	_play_sfx("dash", 1.3)

	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(func(): is_dashing = false)

func _execute_attack() -> void:
	if not is_instance_valid(player) or not is_instance_valid(bullet_server):
		return

	var target_pos := player.global_position
	# Cuchillas oscuras del Vacío en flor / patrón pétalos
	bullet_server.fire_rhodonea_flower(global_position, 12, 210.0, 4, 0.45, rotation, 1)
	# Proyectil veloz directo al jugador
	bullet_server.fire_common_aimed_bullet(global_position, target_pos, 320.0, 2)
	_play_sfx("laser", 1.25)

func take_damage(arg: Variant) -> void:
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

	_trigger_hit_flash()

	if current_health <= 0.0:
		_die()

func _trigger_hit_flash() -> void:
	if hit_flash_tween and hit_flash_tween.is_valid():
		hit_flash_tween.kill()
	hit_flash_tween = create_tween()
	var base_col: Color = Color(0.85, 0.45, 1.0, 0.9) if is_shadow else Color(1.0, 0.35, 0.65, 1.0)
	modulate = Color(2.0, 2.0, 2.0, 1.0)
	hit_flash_tween.tween_property(self, "modulate", base_col, 0.12)

func _die() -> void:
	is_dying = true
	set_physics_process(false)
	boss_defeated.emit(pilot_name)

	_play_sfx("explosion", 1.1)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(queue_free)

func _warp_out_on_prime_death() -> void:
	is_dying = true
	set_physics_process(false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.1, 3.0), 0.4).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(queue_free)

func _play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name, 1.0, pitch)
