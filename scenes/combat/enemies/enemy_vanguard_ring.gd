class_name EnemyVanguardRing
extends EnemyBase

## Campeón de Vanguardia Pesada (Didáctica: Anillos Radiales / Círculos):
## Avanza de frente implacablemente como un ariete blindado. Cada ciclo proyecta
## un anillo de advertencia en el suelo y libera un pulso radial de 12 esferas de cobalto
## que enseñan al jugador a colarse por los huecos entre proyectiles.

@export var attack_interval: float = 4.8
@export var telegraph_duration: float = 0.65

var _attack_timer: float = 2.5
var _is_telegraphing: bool = false
var _bullet_server: BulletServer = null
var _telegraph_indicator: TelegraphIndicator = null

func _init() -> void:
	enemy_id = &"enemy_vanguard_ring"
	max_health = 190.0
	move_speed = 90.0
	contact_damage = 22.0
	exp_reward = 80.0
	credits_reward = 8
	contact_radius = 32.0

func _ready_custom() -> void:
	_attack_timer = randf_range(2.0, 3.5)
	_acquire_bullet_server()
	_setup_telegraph()
	_setup_visual()

func _setup_visual() -> void:
	var tex_path := "res://assets/sprites/enemies/enemy_tank.png"
	if ResourceLoader.exists(tex_path) and is_instance_valid(sprite):
		var tex := load(tex_path) as Texture2D
		if tex:
			sprite.texture = tex
			sprite.scale = Vector2(0.085, 0.085)
			# Matiz azul cobalto con brillo eléctrico
			sprite.modulate = Color(0.65, 1.15, 1.6, 1.0)

func _setup_telegraph() -> void:
	if _telegraph_indicator == null:
		_telegraph_indicator = TelegraphIndicator.new()
		_telegraph_indicator.name = "TelegraphIndicator"
		_telegraph_indicator.indicator_scale = Vector2(1.3, 1.3)
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

	# Giro suave y avance frontal sin retroceso
	var current_dir := Vector2.RIGHT.rotated(rotation)
	var new_dir := current_dir.lerp(dir_to_player, delta * 2.5).normalized()
	rotation = new_dir.angle()

	var current_spd: float = move_speed * (0.7 if _is_telegraphing else 1.0)
	velocity = new_dir * current_spd
	move_and_slide()

	if not _is_telegraphing:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_begin_ring_attack()

func _begin_ring_attack() -> void:
	_is_telegraphing = true
	if is_instance_valid(_telegraph_indicator):
		_telegraph_indicator.start_telegraph(TelegraphIndicator.TelegraphType.RING, telegraph_duration, Vector2.ZERO)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(2.2, 2.2), telegraph_duration * 0.5)
	tw.tween_property(self, "scale", Vector2(1.9, 1.9), telegraph_duration * 0.5)

func _on_telegraph_completed() -> void:
	_is_telegraphing = false
	_attack_timer = attack_interval + randf_range(-0.4, 0.5)
	scale = Vector2(2.0, 2.0)

	if not is_instance_valid(_bullet_server):
		return

	# Emisión de anillo radial de 12 proyectiles
	_bullet_server.fire_alien_ring_burst(global_position, 12, 175.0, rotation)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("explosion", 0.9, -6.0)

	# Sacudida reactiva cinematográfica leve
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.18)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(2.3, 2.3), 0.08)
	tw.tween_property(self, "scale", Vector2(2.0, 2.0), 0.15)
