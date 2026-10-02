class_name EnemySpecterWave
extends EnemyBase

## Campeón Espectro Astral (Didáctica: Ondas Sinusoidales Entrelazadas):
## Crucero ágil que persigue al jugador con movimientos serpenteantes.
## Proyecta un carril de advertencia ondulante y desata ráfagas de proyectiles púrpura
## que viajan en ondas sinusoidales opuestas (crestas y valles entrelazados).

@export var attack_interval: float = 4.4
@export var telegraph_duration: float = 0.60

var _attack_timer: float = 1.8
var _is_telegraphing: bool = false
var _bullet_server: BulletServer = null
var _telegraph_indicator: TelegraphIndicator = null
var _orbit_timer: float = 0.0

func _init() -> void:
	enemy_id = &"enemy_specter_wave"
	max_health = 75.0
	move_speed = 135.0
	contact_damage = 14.0
	exp_reward = 60.0
	credits_reward = 6
	contact_radius = 24.0

func _ready_custom() -> void:
	_attack_timer = randf_range(1.5, 2.8)
	_acquire_bullet_server()
	_setup_telegraph()
	_setup_visual()

func _setup_visual() -> void:
	var tex_path := "res://assets/sprites/enemies/enemy_splitter.png"
	if ResourceLoader.exists(tex_path) and is_instance_valid(sprite):
		var tex := load(tex_path) as Texture2D
		if tex:
			sprite.texture = tex
			sprite.scale = Vector2(0.065, 0.065)
			# Matiz púrpura abisal místico
			sprite.modulate = Color(1.35, 0.7, 1.8, 1.0)

func _setup_telegraph() -> void:
	if _telegraph_indicator == null:
		_telegraph_indicator = TelegraphIndicator.new()
		_telegraph_indicator.name = "TelegraphIndicator"
		_telegraph_indicator.indicator_scale = Vector2(1.1, 1.4)
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

	_orbit_timer += delta * 2.5
	var to_player: Vector2 = player.global_position - global_position
	var dir_to_player: Vector2 = to_player.normalized() if to_player.length_squared() > 1.0 else Vector2.RIGHT

	# Desplazamiento ondulante lateral mientras acorta distancia constantemente
	var lateral: Vector2 = dir_to_player.orthogonal() * sin(_orbit_timer) * 0.35
	var move_dir: Vector2 = (dir_to_player + lateral).normalized()

	rotation = dir_to_player.angle()

	var current_spd: float = move_speed * (0.6 if _is_telegraphing else 1.0)
	velocity = move_dir * current_spd
	move_and_slide()

	if not _is_telegraphing:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_begin_wave_attack(dir_to_player)

func _begin_wave_attack(dir_to_player: Vector2) -> void:
	_is_telegraphing = true
	if is_instance_valid(_telegraph_indicator):
		_telegraph_indicator.start_telegraph(TelegraphIndicator.TelegraphType.WAVE, telegraph_duration, dir_to_player)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.8, 2.2), telegraph_duration * 0.5)
	tw.tween_property(self, "scale", Vector2(2.1, 1.9), telegraph_duration * 0.5)

func _on_telegraph_completed() -> void:
	_is_telegraphing = false
	_attack_timer = attack_interval + randf_range(-0.3, 0.4)
	scale = Vector2(2.0, 2.0)

	if not is_instance_valid(player) or not is_instance_valid(_bullet_server):
		return

	# Disparo de 2 pares entrelazados (4 balas en total formando crestas y valles)
	_bullet_server.fire_alien_wave_lane(global_position, player.global_position, 2, 210.0, 65.0, 5.0)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("laser", 0.75, -1.0)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(2.2, 1.8), 0.07)
	tw.tween_property(self, "scale", Vector2(2.0, 2.0), 0.12)
