class_name BossBrokenMirror
extends CharacterBody2D

## Jefe de Oleada 6: "Espejo Quebrado"
## Representa el Dominio de la Disociación / Vacío (Despersonalización y fragmentación).
## Mecánicas: Ilusiones especulares, barrido cónico de mirada disociativa telegrafiado,
## y fragmentación prismática en Fase 2.

signal health_changed(current: float, max_val: float)
signal phase_changed(new_phase: int)
signal boss_defeated(boss_id: String)

@export var boss_id: String = "boss_broken_mirror"
@export var boss_name: String = "ESPEJO QUEBRADO"
@export var max_health: float = 3200.0

var current_health: float = 3200.0
var current_phase: int = 1
var is_dying: bool = false
var elapsed_combat_time: float = 0.0

var player: Player = null
var bullet_server: BulletServer = null

# Timers
var gaze_sweep_timer: float = 0.0
var mirror_clone_timer: float = 0.0
var prism_fan_timer: float = 0.0
var is_telegraphing: bool = false

# Visuales
var mirror_hull: Sprite2D = null
var crystal_ring: Node2D = null
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
	telegraph_material = ShaderMaterial.new()
	telegraph_material.shader = preload("res://core/shaders/boss_telegraph.gdshader")
	telegraph_material.set_shader_parameter("domain_tint", Color(0.25, 0.9, 1.0, 1.0)) # Tinte Cian Cristalino / Espejo
	telegraph_material.set_shader_parameter("chromatic_aberration", 0.0)
	telegraph_material.set_shader_parameter("flash_intensity", 0.0)
	telegraph_material.set_shader_parameter("glitch_jitter", 0.01)

	# 1. Fragmentos de cristal rotos flotantes
	crystal_ring = Node2D.new()
	crystal_ring.name = "PrismShards"
	add_child(crystal_ring)

	for i in range(8):
		var angle := (TAU / 8.0) * float(i)
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(-8, -14), Vector2(12, -4), Vector2(6, 14), Vector2(-10, 6)
		])
		shard.color = Color(0.3, 0.85, 1.0, 0.8)
		shard.position = Vector2(cos(angle), sin(angle)) * 66.0
		shard.rotation = angle + 0.4
		crystal_ring.add_child(shard)

	# 2. Casco prismático
	var tex_path := "res://assets/enemies/enemy_tank.png"
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex:
			mirror_hull = Sprite2D.new()
			mirror_hull.texture = tex
			mirror_hull.scale = Vector2(1.55, 1.55)
			mirror_hull.material = telegraph_material
			add_child(mirror_hull)

func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_acquire_references()
	if not is_instance_valid(player):
		return

	elapsed_combat_time += delta

	# Regla Anti-Stall: Transición a Fase 2 al 50% HP o 75s
	if current_phase == 1 and (current_health <= max_health * 0.5 or elapsed_combat_time >= 75.0):
		_transition_to_phase_2()

	# Movimiento errático tipo "espejo" (refleja inversamente la trayectoria del jugador)
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var desired_dist := 320.0

	var mirror_vel := -player.velocity * 0.6
	var center_pull := Vector2.ZERO
	if dist > desired_dist + 60.0:
		center_pull = to_player.normalized() * 110.0
	elif dist < desired_dist - 60.0:
		center_pull = -to_player.normalized() * 110.0

	velocity = velocity.lerp(mirror_vel + center_pull, delta * 3.5)
	move_and_slide()

	# Rotación
	rotation = to_player.angle()
	if crystal_ring:
		crystal_ring.rotation += delta * (0.8 if current_phase == 1 else 1.8)

	# Procesamiento Danmaku
	if not is_telegraphing:
		if current_phase == 1:
			_process_phase_1(delta)
		else:
			_process_phase_2(delta)

func _process_phase_1(delta: float) -> void:
	gaze_sweep_timer += delta
	prism_fan_timer += delta

	# Mirada disociativa telegrafiada cada 3.0s (esquirlas serpenteantes de alta vibración)
	if gaze_sweep_timer >= 3.0:
		gaze_sweep_timer = 0.0
		_start_telegraph(0.42, Callable(self, "_fire_dissociative_gaze_sweep"))

	# Trenza de Lissajous / ADN reflectante cada 1.8s
	if prism_fan_timer >= 1.8:
		prism_fan_timer = 0.0
		if is_instance_valid(bullet_server):
			# Dispara 3 pares entrelazados en contrafase (+cos y -cos)
			bullet_server.fire_braided_lissajous(global_position, player.global_position, 3, 210.0, 22.0, 5.0, 2)
			_play_sfx("laser", 1.1)

func _process_phase_2(delta: float) -> void:
	gaze_sweep_timer += delta
	prism_fan_timer += delta

	# Mirada disociativa ampliada cada 2.2s
	if gaze_sweep_timer >= 2.2:
		gaze_sweep_timer = 0.0
		_start_telegraph(0.35, Callable(self, "_fire_expanded_gaze_sweep"))

	# Anillos en flor de diamante de 4 ejes en contrarrotación cada 1.6s
	if prism_fan_timer >= 1.6:
		prism_fan_timer = 0.0
		if is_instance_valid(bullet_server):
			bullet_server.fire_rhodonea_flower(global_position, 24, 160.0, 4, 0.38, rotation, 2)
			bullet_server.fire_rhodonea_flower(global_position, 24, 130.0, 4, 0.38, -rotation, 3)
			_play_sfx("missile", 1.2)

func _fire_dissociative_gaze_sweep() -> void:
	if not is_instance_valid(bullet_server) or not is_instance_valid(player):
		return
	# Salva de 7 esquirlas con serpenteo senoidal de alta frecuencia
	bullet_server.fire_serpentine_spread(global_position, player.global_position, 7, 45.0, 220.0, 16.0, 5.5, 2)
	_play_sfx("laser", 1.2)

func _fire_expanded_gaze_sweep() -> void:
	if not is_instance_valid(bullet_server) or not is_instance_valid(player):
		return
	bullet_server.fire_serpentine_spread(global_position, player.global_position, 9, 60.0, 240.0, 20.0, 6.0, 2)
	_play_sfx("laser", 1.3)

func _start_telegraph(duration: float, callback: Callable) -> void:
	is_telegraphing = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.82, 0.82), duration * 0.7).set_trans(Tween.TRANS_BACK)
	if telegraph_material:
		tw.parallel().tween_method(func(val: float): telegraph_material.set_shader_parameter("chromatic_aberration", val), 0.0, 0.08, duration * 0.7)
		tw.parallel().tween_method(func(val: float): telegraph_material.set_shader_parameter("flash_intensity", val), 0.0, 1.0, duration * 0.7)

	tw.tween_callback(func():
		scale = Vector2(1.18, 1.18)
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
		bullet_server.clear_bullets_in_radius(global_position, 550.0)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.25)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2)

	# Cambiar tinte a cian sobrecargado
	if telegraph_material:
		telegraph_material.set_shader_parameter("domain_tint", Color(0.7, 0.2, 1.0, 1.0))

	_play_sfx("missile", 1.4)

func take_damage(ctx: HitContext) -> void:
	if is_dying:
		return

	current_health -= ctx.final_damage
	health_changed.emit(maxf(0.0, current_health), max_health)

	var dmg_acc := get_node_or_null("DamageAccumulator") as DamageAccumulator
	if dmg_acc:
		dmg_acc.register_hit(ctx.final_damage, ctx.is_crit)

	if hit_flash_tween and hit_flash_tween.is_valid():
		hit_flash_tween.kill()
	modulate = Color(2.6, 2.6, 2.6, 1.0)
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
		bullet_server.clear_bullets_in_radius(global_position, 650.0)

	boss_defeated.emit(boss_id)

	if is_instance_valid(player):
		player.add_credits(500)
		player.add_exp(600.0)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.5).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

func _play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name, pitch, -2.0)
