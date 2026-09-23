class_name BossHermitVoid
extends CharacterBody2D

## Jefe de Oleada 2: "Eremita del Vacío"
## Representa el Dominio del Aislamiento / Espacio (Claustrofobia cósmica).
## Mecánicas: Gravedad del aislamiento, pulsos de vacío telegrafiados con
## aberración cromática, y expansión de horizonte de eventos en Fase 2.

signal health_changed(current: float, max_val: float)
signal phase_changed(new_phase: int)
signal boss_defeated(boss_id: String)

@export var boss_id: String = "boss_hermit_void"
@export var boss_name: String = "EREMITA DEL VACÍO"
@export var max_health: float = 1600.0

var current_health: float = 1600.0
var current_phase: int = 1
var is_dying: bool = false
var elapsed_combat_time: float = 0.0

var player: Player = null
var bullet_server: BulletServer = null

# Timers de patrones Danmaku y dominio
var gravity_pulse_timer: float = 0.0
var aimed_orbs_timer: float = 0.0
var spiral_timer: float = 0.0
var spiral_tick: int = 0
var is_telegraphing: bool = false

# Componentes visuales
var hull_sprite: Sprite2D = null
var core_poly: Polygon2D = null
var shards_container: Node2D = null
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
	# Material con shader de telegrafiado visual
	telegraph_material = ShaderMaterial.new()
	telegraph_material.shader = preload("res://core/shaders/boss_telegraph.gdshader")
	telegraph_material.set_shader_parameter("domain_tint", Color(0.55, 0.15, 0.95, 1.0)) # Tinte Vacío Abisal
	telegraph_material.set_shader_parameter("chromatic_aberration", 0.0)
	telegraph_material.set_shader_parameter("flash_intensity", 0.0)

	# 1. Esquirlas orbitales de distorsión espacial
	shards_container = Node2D.new()
	shards_container.name = "VoidShards"
	add_child(shards_container)

	for i in range(6):
		var angle := (TAU / 6.0) * float(i)
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(0, -16), Vector2(10, 0), Vector2(0, 16), Vector2(-10, 0)
		])
		shard.color = Color(0.35, 0.08, 0.75, 0.9)
		shard.position = Vector2(cos(angle), sin(angle)) * 72.0
		shard.rotation = angle
		shards_container.add_child(shard)

	# 2. Casco principal
	var tex_path := "res://assets/enemies/enemy_tank.png"
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex:
			hull_sprite = Sprite2D.new()
			hull_sprite.texture = tex
			hull_sprite.scale = Vector2(1.6, 1.6)
			hull_sprite.material = telegraph_material
			add_child(hull_sprite)

	# 3. Núcleo de Horizonte de Eventos
	core_poly = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(12):
		var a := (TAU / 12.0) * float(i)
		pts.append(Vector2(cos(a), sin(a)) * 26.0)
	core_poly.polygon = pts
	core_poly.color = Color(0.1, 0.0, 0.25, 0.98) # Negro abisal con halo violeta
	add_child(core_poly)

func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_acquire_references()
	if not is_instance_valid(player):
		return

	elapsed_combat_time += delta

	# Regla Anti-Stall (Brotato): Transición automática a Fase 2 a los 65s
	if current_phase == 1 and (current_health <= max_health * 0.5 or elapsed_combat_time >= 65.0):
		_transition_to_phase_2()

	# AURA DE DOMINIO: Gravedad del Aislamiento
	# Si el jugador se aleja excesivamente (>380px), es atraído sutilmente
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if dist > 380.0:
		var pull_dir := -to_player.normalized()
		var pull_strength := 45.0 if current_phase == 1 else 80.0
		player.velocity += pull_dir * pull_strength * delta

	# Movimiento suave hacia el jugador (mantener distancia de combate)
	var desired_dist := 300.0
	var move_dir := Vector2.ZERO
	if dist > desired_dist + 50.0:
		move_dir = to_player.normalized()
	elif dist < desired_dist - 50.0:
		move_dir = -to_player.normalized()
	else:
		move_dir = to_player.normalized().orthogonal() * 0.4

	velocity = velocity.lerp(move_dir * (90.0 if current_phase == 1 else 130.0), delta * 2.5)
	move_and_slide()

	# Rotación visual
	rotation += delta * (0.35 if current_phase == 1 else 0.75)
	if shards_container:
		shards_container.rotation -= delta * 1.2

	# Procesar ataques Danmaku telegrafiados
	if not is_telegraphing:
		if current_phase == 1:
			_process_phase_1(delta)
		else:
			_process_phase_2(delta)

func _process_phase_1(delta: float) -> void:
	gravity_pulse_timer += delta
	aimed_orbs_timer += delta

	# Pulso gravitatorio telegrafiado cada 3.2s
	if gravity_pulse_timer >= 3.2:
		gravity_pulse_timer = 0.0
		_start_telegraph(0.45, Callable(self, "_fire_void_radial_ring"))

	# Ráfaga de 3 orbes dirigidos cada 2.2s
	if aimed_orbs_timer >= 2.2:
		aimed_orbs_timer = 0.0
		if is_instance_valid(player) and is_instance_valid(bullet_server):
			bullet_server.fire_aimed_spread(global_position, player.global_position, 3, 25.0, 180.0, 3)

func _process_phase_2(delta: float) -> void:
	gravity_pulse_timer += delta
	spiral_timer += delta
	aimed_orbs_timer += delta

	# Espiral de Horizonte de Eventos
	if spiral_timer >= 0.05:
		spiral_timer = 0.0
		spiral_tick += 1
		if is_instance_valid(bullet_server):
			bullet_server.fire_fermat_spiral_tick(global_position, spiral_tick, 160.0, rotation, 3)

	# Anillo doble telegrafiado cada 2.5s
	if gravity_pulse_timer >= 2.5:
		gravity_pulse_timer = 0.0
		_start_telegraph(0.38, Callable(self, "_fire_expanded_void_novas"))

	if aimed_orbs_timer >= 2.0:
		aimed_orbs_timer = 0.0
		if is_instance_valid(player) and is_instance_valid(bullet_server):
			bullet_server.fire_aimed_spread(global_position, player.global_position, 5, 36.0, 210.0, 1)

func _start_telegraph(duration: float, callback: Callable) -> void:
	is_telegraphing = true
	# Telegrafiado: aberración cromática + contracción + flash previo
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.85, 0.85), duration * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if telegraph_material:
		tw.parallel().tween_method(func(val: float): telegraph_material.set_shader_parameter("chromatic_aberration", val), 0.0, 0.06, duration * 0.7)
		tw.parallel().tween_method(func(val: float): telegraph_material.set_shader_parameter("flash_intensity", val), 0.0, 0.9, duration * 0.7)

	tw.tween_callback(func():
		scale = Vector2(1.15, 1.15)
		if telegraph_material:
			telegraph_material.set_shader_parameter("chromatic_aberration", 0.0)
			telegraph_material.set_shader_parameter("flash_intensity", 0.0)
		callback.call()
		is_telegraphing = false
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.15)
	)

func _fire_void_radial_ring() -> void:
	if not is_instance_valid(bullet_server):
		return
	bullet_server.fire_radial_ring(global_position, 14, 135.0, rotation, 3)
	_play_sfx("laser", 0.7)

func _fire_expanded_void_novas() -> void:
	if not is_instance_valid(bullet_server):
		return
	bullet_server.fire_radial_ring(global_position, 18, 155.0, rotation, 3)
	bullet_server.fire_radial_ring(global_position, 18, 120.0, rotation + (PI / 18.0), 1)
	_play_sfx("missile", 0.9)

func _transition_to_phase_2() -> void:
	current_phase = 2
	phase_changed.emit(2)

	# Telegrafiado de clímax de Dominio: Estallido cromático y limpieza de balas cercanas
	if is_instance_valid(bullet_server):
		bullet_server.clear_bullets_in_radius(global_position, 450.0)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), 0.2)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2)

	if shards_container:
		for shard in shards_container.get_children():
			if shard is Polygon2D:
				shard.color = Color(0.85, 0.2, 1.0, 1.0) # Violeta sobrecargado

	_play_sfx("missile", 1.2)

func take_damage(ctx: HitContext) -> void:
	if is_dying:
		return

	current_health -= ctx.final_damage
	health_changed.emit(maxf(0.0, current_health), max_health)

	var dmg_acc := get_node_or_null("DamageAccumulator") as DamageAccumulator
	if dmg_acc:
		dmg_acc.register_hit(ctx.final_damage, ctx.is_crit)

	# Flash de impacto
	if hit_flash_tween and hit_flash_tween.is_valid():
		hit_flash_tween.kill()
	modulate = Color(2.5, 2.5, 2.5, 1.0)
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
		bullet_server.clear_bullets_in_radius(global_position, 600.0)

	boss_defeated.emit(boss_id)

	# Recompensas
	if is_instance_valid(player):
		player.add_credits(250)
		player.add_exp(300.0)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.5).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

func _play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name, pitch, -2.0)
