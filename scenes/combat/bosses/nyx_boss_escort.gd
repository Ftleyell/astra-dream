class_name NyxBossEscort
extends CharacterBody2D

## Escolta Hostil de Astra Prime (Ruta Genocida / Slayer)
## Si el jugador usa una piloto base, Nyx desciende furiosa como escolta de Astra Prime.
## Si el jugador usa a Nyx, la 6ta piloto original que sobrevivió a la run desciende
## para vengar a sus 5 compañeras caídas con su propia nave y ataques insignia.

signal health_changed(current: float, max_val: float)
signal boss_defeated(boss_id: String)

@export var max_health: float = 1600.0
@export var pilot_id: StringName = &"nyx"
@export var pilot_name: String = "Nyx, Vengadora del Vacío"
@export var is_shadow: bool = false

var current_health: float = 1600.0
var is_dying: bool = false

var player: Player = null
var prime_boss: Node2D = null
var bullet_server: BulletServer = null

var orbit_angle: float = 0.0
var attack_timer: float = 1.0
var dash_timer: float = 3.5
var is_dashing: bool = false
var dash_velocity: Vector2 = Vector2.ZERO

var ship_sprite: Sprite2D = null
var aura_ring: Line2D = null
var engine_trail: Line2D = null
var hit_flash_tween: Tween = null
var base_color: Color = Color(1.0, 0.35, 0.65, 1.0)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	add_to_group("bosses")

	current_health = max_health
	_acquire_references()
	_setup_visuals()
	health_changed.emit(current_health, max_health)

func setup(p_pilot_id: StringName = &"nyx", p_prime: Node2D = null) -> void:
	pilot_id = p_pilot_id
	prime_boss = p_prime
	var roster := CharacterData.load_roster()
	if roster.has(pilot_id):
		var cd: CharacterData = roster[pilot_id]
		if pilot_id == &"nyx":
			pilot_name = "Nyx, Vengadora del Vacío"
			base_color = Color(1.0, 0.3, 0.65, 1.0)
		else:
			pilot_name = cd.display_name + ", Vengadora de la Flota"
			base_color = cd.color
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
		ship_sprite.scale = Vector2(0.42, 0.42)
		add_child(ship_sprite)

	var roster := CharacterData.load_roster()
	if roster.has(pilot_id):
		var cd: CharacterData = roster[pilot_id]
		var tex := cd.get_ship_texture()
		if tex:
			ship_sprite.texture = tex
		base_color = cd.color if pilot_id != &"nyx" else Color(1.0, 0.3, 0.65, 1.0)

	modulate = base_color

	if not aura_ring:
		aura_ring = Line2D.new()
		aura_ring.name = "VoidAura"
		aura_ring.width = 2.0
		aura_ring.default_color = Color(base_color.r, base_color.g, base_color.b, 0.8)
		var pts := PackedVector2Array()
		for i in range(17):
			var a := (TAU / 16.0) * float(i)
			pts.append(Vector2(cos(a), sin(a)) * 20.0)
		aura_ring.points = pts
		add_child(aura_ring)

	if not engine_trail:
		engine_trail = Line2D.new()
		engine_trail.name = "EngineTrail"
		engine_trail.width = 3.5
		engine_trail.default_color = Color(base_color.r, base_color.g, base_color.b, 0.6)
		add_child(engine_trail)

func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_acquire_references()
	if not is_instance_valid(player):
		return

	# Si Astra Prime fue derrotado, la nave escolta desaparece
	if prime_boss != null and not is_instance_valid(prime_boss):
		_warp_out_on_prime_death()
		return

	# Formación de combate cercana a Astra Prime (~140 px de órbita defensiva)
	orbit_angle += delta * 1.3
	var anchor_pos := player.global_position
	if is_instance_valid(prime_boss):
		anchor_pos = prime_boss.global_position

	var target_pos := anchor_pos + Vector2(cos(orbit_angle), sin(orbit_angle)) * 140.0

	dash_timer -= delta
	if dash_timer <= 0.0 and not is_dashing:
		dash_timer = randf_range(3.5, 5.0)
		_start_dash()

	if is_dashing:
		velocity = dash_velocity
	else:
		var dir := (target_pos - global_position).normalized()
		var dist := global_position.distance_to(target_pos)
		var desired_vel := dir * clampf(dist * 4.0, 100.0, 340.0)
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
		attack_timer = randf_range(1.5, 2.2)
		_execute_attack()

func _start_dash() -> void:
	is_dashing = true
	var dir := (player.global_position - global_position).normalized().rotated(randf_range(-0.4, 0.4))
	dash_velocity = dir * 600.0
	_play_sfx("dash", 1.3)

	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func(): is_dashing = false)

func _execute_attack() -> void:
	if not is_instance_valid(player) or not is_instance_valid(bullet_server):
		return

	var target_pos := player.global_position

	match pilot_id:
		&"nova":
			bullet_server.fire_aimed_spread(global_position, target_pos, 3, 15.0, 360.0, 2)
			_play_sfx("laser", 1.2)
		&"valentina":
			bullet_server.fire_common_aimed_bullet(global_position, target_pos, 460.0, 1)
			_play_sfx("laser", 0.8)
		&"kira":
			bullet_server.fire_serpentine_spread(global_position, target_pos, 5, 35.0, 220.0, 40.0, 3.5, 0)
			_play_sfx("missile", 1.0)
		&"selene":
			bullet_server.fire_radial_ring(global_position, 12, 190.0, rotation, 3)
			_play_sfx("missile", 0.9)
		&"roxy":
			bullet_server.fire_aimed_spread(global_position, target_pos, 7, 45.0, 270.0, 1)
			_play_sfx("explosion", 1.1)
		&"echo":
			bullet_server.fire_braided_lissajous(global_position, target_pos, 3, 240.0, 50.0, 4.0, 2)
			_play_sfx("laser", 1.4)
		&"nyx":
			bullet_server.fire_rhodonea_flower(global_position, 12, 210.0, 4, 0.45, rotation, 1)
			bullet_server.fire_common_aimed_bullet(global_position, target_pos, 320.0, 2)
			_play_sfx("laser", 1.25)
		_:
			bullet_server.fire_aimed_spread(global_position, target_pos, 4, 25.0, 280.0, 1)

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
	modulate = Color(2.0, 2.0, 2.0, 1.0)
	hit_flash_tween.tween_property(self, "modulate", base_color, 0.12)

func _die() -> void:
	is_dying = true
	set_physics_process(false)
	boss_defeated.emit(pilot_name)

	_play_sfx("explosion", 1.1)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(queue_free)

func _warp_out_on_prime_death() -> void:
	is_dying = true
	set_physics_process(false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.1, 2.5), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(queue_free)

func _play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name, 1.0, pitch)
