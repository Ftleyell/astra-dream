class_name EnemyAssaultCone
extends EnemyBase

## Campeón de Asalto Frontal (Didáctica: Cono / Escopetazo):
## Avanza hacia el jugador a velocidad media, telegrafía un abanico angular ámbar
## y dispara un cono de 5 proyectiles pesados de plasma radiactivo.

@export var attack_interval: float = 4.2
@export var telegraph_duration: float = 0.55

var _attack_timer: float = 2.0
var _is_telegraphing: bool = false
var _bullet_server: BulletServer = null
var _telegraph_indicator: TelegraphIndicator = null

func _init() -> void:
	enemy_id = &"enemy_assault_cone"
	max_health = 85.0
	move_speed = 120.0
	contact_damage = 16.0
	exp_reward = 55.0
	credits_reward = 5
	contact_radius = 26.0

func _ready_custom() -> void:
	_attack_timer = randf_range(1.5, 3.0)
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
			# Matiz ámbar radiactivo característico
			sprite.modulate = Color(1.3, 1.05, 0.6, 1.0)

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

	var to_player: Vector2 = player.global_position - global_position
	var dir_to_player: Vector2 = to_player.normalized() if to_player.length_squared() > 1.0 else Vector2.RIGHT

	# Orientación permanente hacia el jugador
	rotation = dir_to_player.angle()

	# Avance continuo hacia el jugador (mantiene el ritmo para combate melee)
	var current_spd: float = move_speed * (0.65 if _is_telegraphing else 1.0)
	velocity = dir_to_player * current_spd
	move_and_slide()

	# Manejo del temporizador de ataque
	if not _is_telegraphing:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_begin_cone_attack(dir_to_player)

func _begin_cone_attack(dir_to_player: Vector2) -> void:
	_is_telegraphing = true
	if is_instance_valid(_telegraph_indicator):
		_telegraph_indicator.start_telegraph(TelegraphIndicator.TelegraphType.CONE, telegraph_duration, dir_to_player)

	# Pulso de advertencia visual en el chasis
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.85, 1.85), telegraph_duration * 0.5)
	tw.tween_property(self, "scale", Vector2(2.1, 2.1), telegraph_duration * 0.5)

func _on_telegraph_completed() -> void:
	_is_telegraphing = false
	_attack_timer = attack_interval + randf_range(-0.3, 0.4)
	scale = Vector2(2.0, 2.0)

	if not is_instance_valid(player) or not is_instance_valid(_bullet_server):
		return

	# Disparo de 5 proyectiles en cono frontal
	_bullet_server.fire_alien_cone_spread(global_position, player.global_position, 5, 38.0, 230.0)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("laser", 0.85, -2.0)

	# Rebote de retroceso
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(2.25, 1.75), 0.07)
	tw.tween_property(self, "scale", Vector2(2.0, 2.0), 0.12)
