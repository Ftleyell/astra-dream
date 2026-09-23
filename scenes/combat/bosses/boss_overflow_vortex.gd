class_name BossOverflowVortex
extends CharacterBody2D

## Jefe de Oleada 8: "Vórtice del Desborde"
## Representa el Dominio del Agobio / Caos Sensorial (Saturación y sobrecarga).
## Mecánicas: Espirales de Fermat de alta densidad pero lectura limpia,
## erupciones fractales telegiadas con contracción intensa, y clímax de singularidad en Fase 2.

signal health_changed(current: float, max_val: float)
signal phase_changed(new_phase: int)
signal boss_defeated(boss_id: String)

@export var boss_id: String = "boss_overflow_vortex"
@export var boss_name: String = "VÓRTICE DEL DESBORDE"
@export var max_health: float = 4500.0

var current_health: float = 4500.0
var current_phase: int = 1
var is_dying: bool = false
var elapsed_combat_time: float = 0.0

var player: Player = null
var bullet_server: BulletServer = null

# Timers
var spiral_timer: float = 0.0
var spiral_tick: int = 0
var nova_timer: float = 0.0
var aimed_timer: float = 0.0
var is_telegraphing: bool = false

# Visuales
var vortex_hull: Sprite2D = null
var inner_core: Polygon2D = null
var outer_ring: Node2D = null
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
	telegraph_material.set_shader_parameter("domain_tint", Color(1.0, 0.15, 0.45, 1.0)) # Tinte Carmesí Neón / Sobrecarga
	telegraph_material.set_shader_parameter("chromatic_aberration", 0.0)
	telegraph_material.set_shader_parameter("flash_intensity", 0.0)
	telegraph_material.set_shader_parameter("glitch_jitter", 0.02)

	# 1. Anillo exterior de resonadores caóticos
	outer_ring = Node2D.new()
	outer_ring.name = "ResonatorRing"
	add_child(outer_ring)

	for i in range(8):
		var angle := (TAU / 8.0) * float(i)
		var res_poly := Polygon2D.new()
		res_poly.polygon = PackedVector2Array([
			Vector2(-10, -6), Vector2(10, -6), Vector2(14, 6), Vector2(-14, 6)
		])
		res_poly.color = Color(1.0, 0.25, 0.35, 0.85)
		res_poly.position = Vector2(cos(angle), sin(angle)) * 74.0
		res_poly.rotation = angle + PI / 2.0
		outer_ring.add_child(res_poly)

	# 2. Casco principal
	var tex_path := "res://assets/enemies/enemy_tank.png"
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex:
			vortex_hull = Sprite2D.new()
			vortex_hull.texture = tex
			vortex_hull.scale = Vector2(1.7, 1.7)
			vortex_hull.material = telegraph_material
			add_child(vortex_hull)

	# 3. Núcleo de sobrecarga caótica
	inner_core = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a := (TAU / 16.0) * float(i)
		pts.append(Vector2(cos(a), sin(a)) * 24.0)
	inner_core.polygon = pts
	inner_core.color = Color(1.0, 0.9, 0.2, 0.95)
	add_child(inner_core)

func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_acquire_references()
	if not is_instance_valid(player):
		return

	elapsed_combat_time += delta

	# Regla Anti-Stall: Transición a Fase 2 al 50% HP o 80s
	if current_phase == 1 and (current_health <= max_health * 0.5 or elapsed_combat_time >= 80.0):
		_transition_to_phase_2()

	# Movimiento de aproximación e interceptación agresiva
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var desired_dist := 290.0

	var move_dir := Vector2.ZERO
	if dist > desired_dist + 40.0:
		move_dir = to_player.normalized()
	elif dist < desired_dist - 40.0:
		move_dir = -to_player.normalized() * 0.8
	else:
		move_dir = to_player.normalized().orthogonal() * 0.5

	var spd := 115.0 if current_phase == 1 else 160.0
	velocity = velocity.lerp(move_dir * spd, delta * 3.0)
	move_and_slide()

	# Rotaciones visuales dinámicas
	rotation += delta * (0.6 if current_phase == 1 else 1.2)
	if outer_ring:
		outer_ring.rotation -= delta * (1.1 if current_phase == 1 else 2.2)

	# Pulso del núcleo
	if inner_core:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.01) * 0.18
		inner_core.scale = Vector2(pulse, pulse)

	# Procesamiento Danmaku
	if not is_telegraphing:
		if current_phase == 1:
			_process_phase_1(delta)
		else:
			_process_phase_2(delta)

func _process_phase_1(delta: float) -> void:
	spiral_timer += delta
	nova_timer += delta
	aimed_timer += delta

	# Espiral de Fermat armónica continua
	if spiral_timer >= 0.045:
		spiral_timer = 0.0
		spiral_tick += 1
		if is_instance_valid(bullet_server):
			bullet_server.fire_fermat_spiral_tick(global_position, spiral_tick, 175.0, rotation, 0)

	# Erupción de pulso nova telegrafiada cada 3.2s
	if nova_timer >= 3.2:
		nova_timer = 0.0
		_start_telegraph(0.48, Callable(self, "_fire_overload_nova_ring"))

	# Ráfagas dirigidas de plasma cada 2.4s
	if aimed_timer >= 2.4:
		aimed_timer = 0.0
		if is_instance_valid(bullet_server):
			bullet_server.fire_aimed_spread(global_position, player.global_position, 5, 36.0, 225.0, 1)

func _process_phase_2(delta: float) -> void:
	spiral_timer += delta
	nova_timer += delta
	aimed_timer += delta

	# Doble espiral de Fermat cruzada (Sobrecarga de singularidad)
	if spiral_timer >= 0.038:
		spiral_timer = 0.0
		spiral_tick += 1
		if is_instance_valid(bullet_server):
			bullet_server.fire_fermat_spiral_tick(global_position, spiral_tick, 185.0, rotation, 0)
			bullet_server.fire_fermat_spiral_tick(global_position, -spiral_tick, 185.0, -rotation, 2)

	# Doble anillo de erupción telegrafiado cada 2.5s
	if nova_timer >= 2.5:
		nova_timer = 0.0
		_start_telegraph(0.38, Callable(self, "_fire_overload_double_nova"))

	if aimed_timer >= 1.8:
		aimed_timer = 0.0
		if is_instance_valid(bullet_server):
			bullet_server.fire_aimed_spread(global_position, player.global_position, 7, 48.0, 250.0, 1)

func _fire_overload_nova_ring() -> void:
	if not is_instance_valid(bullet_server):
		return
	bullet_server.fire_radial_ring(global_position, 20, 160.0, rotation, 0)
	_play_sfx("laser", 1.0)

func _fire_overload_double_nova() -> void:
	if not is_instance_valid(bullet_server):
		return
	bullet_server.fire_radial_ring(global_position, 24, 175.0, rotation, 0)
	bullet_server.fire_radial_ring(global_position, 24, 140.0, rotation + (PI / 24.0), 2)
	_play_sfx("missile", 1.3)

func _start_telegraph(duration: float, callback: Callable) -> void:
	is_telegraphing = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.78, 0.78), duration * 0.7).set_trans(Tween.TRANS_BACK)
	if telegraph_material:
		tw.parallel().tween_method(func(val: float): telegraph_material.set_shader_parameter("chromatic_aberration", val), 0.0, 0.09, duration * 0.7)
		tw.parallel().tween_method(func(val: float): telegraph_material.set_shader_parameter("flash_intensity", val), 0.0, 1.0, duration * 0.7)

	tw.tween_callback(func():
		scale = Vector2(1.22, 1.22)
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
		bullet_server.clear_bullets_in_radius(global_position, 600.0)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.45, 1.45), 0.3)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2)

	if telegraph_material:
		telegraph_material.set_shader_parameter("domain_tint", Color(1.0, 0.05, 0.1, 1.0))

	_play_sfx("missile", 1.5)

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
	modulate = Color(2.8, 2.8, 2.8, 1.0)
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
		bullet_server.clear_bullets_in_radius(global_position, 800.0)

	boss_defeated.emit(boss_id)

	if is_instance_valid(player):
		player.add_credits(750)
		player.add_exp(900.0)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.6).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)

func _play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name, pitch, -2.0)
