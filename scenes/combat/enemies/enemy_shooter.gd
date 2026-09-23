class_name EnemyShooter
extends "res://scenes/combat/enemies/enemy_base.gd"

## Artillero Danmaku: nave de apoyo que frena a distancia media (~450px)
## y dispara periódicamente ráfagas de 3 proyectiles dirigidos hacia el jugador.

const PREFERRED_DISTANCE: float = 450.0
const DISTANCE_TOLERANCE: float = 50.0

@export var shoot_interval: float = 3.6
var shoot_timer: float = 2.0
var is_charging_shot: bool = false
var charge_timer: float = 0.0
const CHARGE_DURATION: float = 0.35
var bullet_server: BulletServer = null

func _init() -> void:
	enemy_id = &"enemy_shooter"
	max_health = 45.0
	move_speed = 120.0
	contact_damage = 10.0
	exp_reward = 35.0
	credits_reward = 4
	contact_radius = 24.0

func _ready_custom() -> void:
	shoot_timer = randf_range(1.5, shoot_interval)
	_acquire_bullet_server()
	var tex_path := "res://assets/enemies/enemy_shooter.png"
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex and sprite:
			sprite.texture = tex
			sprite.scale = Vector2(0.45, 0.45)

func _acquire_bullet_server() -> void:
	if not is_instance_valid(bullet_server):
		bullet_server = get_tree().get_first_node_in_group("bullet_server") as BulletServer
		if not bullet_server and get_parent():
			bullet_server = get_parent().get_node_or_null("BulletServer") as BulletServer
		if not bullet_server and is_instance_valid(player) and "bullet_server" in player:
			bullet_server = player.bullet_server
		if not bullet_server and is_inside_tree() and get_tree().current_scene:
			bullet_server = get_tree().current_scene.get_node_or_null("BulletServer") as BulletServer

func _update_behavior(delta: float) -> void:
	_acquire_bullet_server()
	if not is_instance_valid(player):
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var dir_to_player := to_player.normalized()

	# Apuntar visualmente hacia el jugador
	rotation = dir_to_player.angle()

	# Si está cargando el disparo telegrafiado: frenar en seco y parpadear
	if is_charging_shot:
		velocity = Vector2.ZERO
		move_and_slide()
		charge_timer -= delta
		if charge_timer <= 0.0:
			is_charging_shot = false
			_fire_telegraphed_shot()
		return

	# Control de posicionamiento táctico (mantener distancia de ~450px)
	var move_dir := Vector2.ZERO
	if dist > PREFERRED_DISTANCE + DISTANCE_TOLERANCE:
		move_dir = dir_to_player
	elif dist < PREFERRED_DISTANCE - DISTANCE_TOLERANCE:
		move_dir = -dir_to_player * 0.7
	else:
		move_dir = dir_to_player.orthogonal() * 0.5

	velocity = move_dir * move_speed
	move_and_slide()

	# Temporizador de disparo: solo comenzar carga si la cuota global no está saturada
	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_interval + randf_range(-0.4, 0.6)
		if is_instance_valid(bullet_server) and bullet_server.can_common_enemy_shoot():
			_begin_charge_up()

func _begin_charge_up() -> void:
	is_charging_shot = true
	charge_timer = CHARGE_DURATION
	# Telegrafiado visual: contracción y destello de advertencia
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.85, 0.85), CHARGE_DURATION * 0.8)
	tw.parallel().tween_property(self, "modulate", Color(2.0, 1.4, 1.4, 1.0), CHARGE_DURATION * 0.8)

func _fire_telegraphed_shot() -> void:
	# Restaurar modulación
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	scale = Vector2(1.0, 1.0)

	if not is_instance_valid(player) or not is_instance_valid(bullet_server):
		return

	# Disparo único balístico de plasma (evita alfombras danmaku a velocidad x4)
	var fired := bullet_server.fire_common_aimed_bullet(global_position, player.global_position, 190.0, 1)
	if fired:
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("laser", 0.75, -4.0)

		# Rebote elástico de retroceso
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.15, 0.85), 0.06)
		tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)
