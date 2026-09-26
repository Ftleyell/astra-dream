class_name BossAstraPrime
extends CharacterBody2D

## Jefe Final - Oleada 11: "Astra Prime: Núcleo Supremo"
## El clímax de la incursión que sella el destino de la galaxia según las decisiones del jugador.
## Modifica su comportamiento según la ruta de las 5 pilotos rivales:
## - "pacifist": Enfrenta a la Flota de la Esperanza unida (el jugador y 5 escoltas).
## - "slayer": Modo Furia y Sobrecarga Sanguinaria por la erradicación de todas las pilotos.
## - "neutral": Duelo equilibrado por la supervivencia fragmentada.

signal health_changed(current: float, max_val: float)
signal phase_changed(new_phase: int)
signal boss_defeated(boss_id: String)

@export var boss_id: String = "boss_astra_prime"
@export var boss_name: String = "ASTRA PRIME: NÚCLEO SUPREMO"
@export var max_health: float = 3800.0

var current_health: float = 3800.0
var current_phase: int = 1
var is_dying: bool = false
var route: String = "neutral"

var player: Player = null
var bullet_server: BulletServer = null
var elapsed_combat_time: float = 0.0

# Timers de patrones Danmaku
var pattern_timer: float = 0.0
var radial_timer: float = 0.0
var spiral_tick: int = 0
var movement_timer: float = 0.0

# Visuales
var hull_sprite: Sprite2D = null
var core_poly: Polygon2D = null
var crown_nodes: Node2D = null
var hit_flash_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	add_to_group("bosses")

	current_health = max_health
	_acquire_references()
	_setup_visuals()

	health_changed.emit(current_health, max_health)

func set_route(p_route: String) -> void:
	route = p_route
	if route == "slayer":
		max_health = 4600.0
		current_health = max_health
		boss_name = "ASTRA PRIME [FURIA ENCADENADA]"
		if core_poly:
			core_poly.color = Color(1.0, 0.1, 0.2, 0.95)
	elif route == "pacifist":
		boss_name = "ASTRA PRIME [NÚCLEO DEL DESTINO]"
		if core_poly:
			core_poly.color = Color(0.1, 0.9, 1.0, 0.95)
	else:
		boss_name = "ASTRA PRIME: NÚCLEO SUPREMO"
	health_changed.emit(current_health, max_health)

func _acquire_references() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(bullet_server):
		bullet_server = get_node_or_null("/root/BulletServer") as BulletServer
		if not bullet_server and get_parent():
			bullet_server = get_parent().get_node_or_null("BulletServer") as BulletServer

func _setup_visuals() -> void:
	# Corona de orbes cósmicos orbitales
	crown_nodes = Node2D.new()
	crown_nodes.name = "CrownNodes"
	add_child(crown_nodes)

	for i in range(8):
		var angle := (TAU / 8.0) * float(i)
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(0, -18), Vector2(14, 0), Vector2(0, 18), Vector2(-14, 0)
		])
		shard.color = Color(0.9, 0.8, 0.2, 0.85)
		shard.position = Vector2(cos(angle), sin(angle)) * 88.0
		shard.rotation = angle
		crown_nodes.add_child(shard)

	# Casco
	var tex_path := "res://assets/enemies/enemy_tank.png"
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex:
			hull_sprite = Sprite2D.new()
			hull_sprite.name = "HullSprite"
			hull_sprite.texture = tex
			hull_sprite.scale = Vector2(2.1, 2.1)
			add_child(hull_sprite)

	# Núcleo interior
	core_poly = Polygon2D.new()
	core_poly.name = "CorePoly"
	var pts := PackedVector2Array()
	for i in range(12):
		var a := (TAU / 12.0) * float(i)
		pts.append(Vector2(cos(a), sin(a)) * 32.0)
	core_poly.polygon = pts
	core_poly.color = Color(0.2, 0.85, 1.0, 0.95)
	add_child(core_poly)

func _physics_process(delta: float) -> void:
	if is_dying:
		return

	elapsed_combat_time += delta
	_update_visuals(delta)

	if not is_instance_valid(player):
		_acquire_references()
		if not is_instance_valid(player):
			return

	_process_movement(delta)
	_process_patterns(delta)

func _update_visuals(delta: float) -> void:
	if crown_nodes:
		var rot_dir := -1.0 if route == "slayer" else 1.0
		crown_nodes.rotation += delta * 1.5 * rot_dir
		var s := 1.0 + sin(elapsed_combat_time * 3.0) * 0.08
		crown_nodes.scale = Vector2(s, s)

	if core_poly:
		var pulse := 1.0 + cos(elapsed_combat_time * 5.0) * 0.12
		core_poly.scale = Vector2(pulse, pulse)

func _process_movement(delta: float) -> void:
	movement_timer += delta
	var to_player := (player.global_position - global_position).normalized()
	var dist := global_position.distance_to(player.global_position)

	# Flotación oscilatoria manteniendo distancia de 450 px
	var ideal_dist := 450.0
	var speed := 90.0 if route != "slayer" else 135.0
	var vel := (to_player * (dist - ideal_dist) * 0.6) + Vector2(-to_player.y, to_player.x) * sin(movement_timer * 1.2) * speed
	velocity = velocity.move_toward(vel, 300.0 * delta)
	move_and_slide()

	rotation = lerp_angle(rotation, to_player.angle() + PI / 2.0, 4.0 * delta)

func _process_patterns(delta: float) -> void:
	pattern_timer += delta
	radial_timer += delta

	var fire_mult := 0.75 if route == "slayer" else 1.0

	# 1. Espiral de Fermat continua
	spiral_tick += 1
	if spiral_tick % 4 == 0 and is_instance_valid(bullet_server):
		var b_type := 0 if route == "slayer" else 2
		bullet_server.fire_fermat_spiral_tick(global_position, spiral_tick, 190.0, rotation, b_type)

	# 2. Flores de Rhodonea periódicas
	if pattern_timer >= (3.2 * fire_mult):
		pattern_timer = 0.0
		_fire_rhodonea_nova()

	# 3. Anillo radial / abanico telegrafiado
	if radial_timer >= (4.8 * fire_mult):
		radial_timer = 0.0
		_fire_aimed_burst()

func _fire_rhodonea_nova() -> void:
	if not is_instance_valid(bullet_server):
		return
	var petals := 6 if current_phase == 1 else 8
	var b_type := 1 if current_phase == 1 else 3
	bullet_server.fire_rhodonea_flower(global_position, 24, 160.0, petals, 0.35, rotation, b_type)
	_play_sfx("laser", 0.9)

func _fire_aimed_burst() -> void:
	if not is_instance_valid(bullet_server) or not is_instance_valid(player):
		return
	var count := 5 if current_phase == 1 else 7
	bullet_server.fire_aimed_spread(global_position, player.global_position, count, 36.0, 240.0, 2)
	_play_sfx("missile", 1.0)

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

	if current_phase == 1 and current_health <= (max_health * 0.5):
		_transition_phase_2()

	if current_health <= 0.0:
		_die()

func _transition_phase_2() -> void:
	current_phase = 2
	phase_changed.emit(2)

	if is_instance_valid(bullet_server):
		bullet_server.clear_bullets_in_radius(global_position, 500.0)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), 0.2)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2)

	if crown_nodes:
		for shard in crown_nodes.get_children():
			if shard is Polygon2D:
				shard.color = Color(1.0, 0.2, 0.4, 0.95)

	_play_sfx("explosion", 1.2)

func _die() -> void:
	is_dying = true
	set_physics_process(false)

	if is_instance_valid(bullet_server):
		bullet_server.clear_all_bullets()

	boss_defeated.emit(boss_id)

	_play_sfx("explosion", 0.7)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(2.0, 2.0), 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(queue_free)

func _play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name, 1.0, pitch)
