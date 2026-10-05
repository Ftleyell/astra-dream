class_name EnemyAssaultCone
extends EnemyBase

## Campeón de Asalto Frontal (Didáctica: Embestida / Charge de Pantalla Completa):
## Al detectar al jugador en rango de pantalla, proyecta un carril de advertencia
## ultra-largo que atraviesa la pantalla completa, y tras el telegrafiado se lanza en una
## embestida a 750 px/s de punta a punta, manteniendo el indicador visible todo el trayecto.

@export var attack_interval: float = 4.0
@export var telegraph_duration: float = 1.2
@export var charge_speed: float = 1200.0
@export var max_charge_distance: float = 2400.0

var is_preparing_charge: bool = false

var _attack_timer: float = 2.0
var _is_telegraphing: bool = false
var _is_charging: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_distance_covered: float = 0.0
var _v_danmaku_timer: float = 0.0
var _locked_relative_offset: Vector2 = Vector2.ZERO
var _bullet_server: BulletServer = null
var _telegraph_indicator: TelegraphIndicator = null

func _init() -> void:
	enemy_id = &"enemy_assault_cone"
	max_health = 110.0
	move_speed = 135.0
	contact_damage = 25.0
	exp_reward = 65.0
	credits_reward = 6
	contact_radius = 28.0

func _ready_custom() -> void:
	add_to_group("chargers")
	_attack_timer = randf_range(1.5, 2.5)
	_acquire_bullet_server()
	_setup_telegraph()
	_setup_visual()

func _setup_visual() -> void:
	var tex_path := "res://assets/sprites/enemies/enemy_shooter.png"
	if ResourceLoader.exists(tex_path) and is_instance_valid(sprite):
		var tex := load(tex_path) as Texture2D
		if tex:
			sprite.texture = tex
			sprite.scale = Vector2(0.075, 0.075)
			# Matiz ámbar-anaranjado radiactivo característico
			sprite.modulate = Color(1.35, 0.95, 0.45, 1.0)

func _setup_telegraph() -> void:
	if _telegraph_indicator == null:
		_telegraph_indicator = TelegraphIndicator.new()
		_telegraph_indicator.name = "TelegraphIndicator"
		_telegraph_indicator.indicator_scale = Vector2(1.2, 1.2)
		_telegraph_indicator.telegraph_completed.connect(_on_telegraph_completed)
		add_child(_telegraph_indicator)

func _acquire_bullet_server() -> void:
	if not is_instance_valid(_bullet_server):
		_bullet_server = get_tree().get_first_node_in_group("bullet_server") as BulletServer
		if not _bullet_server and is_instance_valid(player) and "bullet_server" in player:
			_bullet_server = player.bullet_server

func _update_behavior(delta: float) -> void:
	_acquire_bullet_server()
	if not is_instance_valid(player):
		return

	if _is_charging:
		var step: float = charge_speed * delta
		velocity = _charge_dir * charge_speed
		_charge_distance_covered += step
		move_and_slide()

		# Disparo continuo de Danmaku colosal en formación de 'V' hacia atrás
		_v_danmaku_timer -= delta
		if _v_danmaku_timer <= 0.0:
			_v_danmaku_timer = 0.08
			_fire_v_danmaku()

		if _charge_distance_covered >= max_charge_distance:
			_end_charge()
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist_to_player: float = to_player.length()
	var dir_to_player: Vector2 = to_player / dist_to_player if dist_to_player > 0.001 else Vector2.RIGHT

	if _is_telegraphing:
		# Lock-in: mantiene orientación y velocidad relativa con el jugador durante la preparación
		rotation = dir_to_player.angle()
		_charge_dir = dir_to_player
		if is_instance_valid(_telegraph_indicator):
			_telegraph_indicator._laser_direction = dir_to_player
		velocity = player.velocity
		move_and_slide()
		return

	# Orientación permanente hacia el jugador mientras no embiste
	rotation = dir_to_player.angle()
	velocity = dir_to_player * move_speed
	move_and_slide()

	# Lock-in se activa al entrar en el borde de visión (~540px)
	if dist_to_player <= 540.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_begin_charge_attack(dir_to_player)

func _begin_charge_attack(dir_to_player: Vector2) -> void:
	_is_telegraphing = true
	is_preparing_charge = true
	_charge_dir = dir_to_player
	if is_instance_valid(_telegraph_indicator):
		_telegraph_indicator.start_telegraph(TelegraphIndicator.TelegraphType.CHARGE_LANE, telegraph_duration, dir_to_player)

	# Pulso de compresión previo a la embestida (toma impulso)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.7, 2.3), telegraph_duration * 0.45)
	tw.tween_property(self, "scale", Vector2(2.35, 1.65), telegraph_duration * 0.55)

func _on_telegraph_completed() -> void:
	_is_telegraphing = false
	is_preparing_charge = false
	_is_charging = true
	_charge_distance_covered = 0.0
	_v_danmaku_timer = 0.0
	scale = Vector2(2.4, 1.7)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("dash", 0.9, 2.0)

func _fire_v_danmaku() -> void:
	if not is_instance_valid(_bullet_server):
		return
	var base_back: float = _charge_dir.angle() + PI
	var left_angle: float = base_back + deg_to_rad(35.0)
	var right_angle: float = base_back - deg_to_rad(35.0)
	var b_spd: float = 270.0
	_bullet_server.spawn_bullet(global_position.x, global_position.y, cos(left_angle) * b_spd, sin(left_angle) * b_spd, 2, 7.5)
	_bullet_server.spawn_bullet(global_position.x, global_position.y, cos(right_angle) * b_spd, sin(right_angle) * b_spd, 2, 7.5)

func _end_charge() -> void:
	_is_charging = false
	is_preparing_charge = false
	_attack_timer = attack_interval + randf_range(-0.5, 0.5)
	scale = Vector2(2.0, 2.0)

	if is_instance_valid(_telegraph_indicator):
		_telegraph_indicator.dismiss()

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.85, 2.15), 0.12)
	tw.tween_property(self, "scale", Vector2(2.0, 2.0), 0.15)
