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
var telegraph_indicator: TelegraphIndicator = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	add_to_group("bosses")
	scale = Vector2(2.0, 2.0)

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

	# Indicador holográfico de advertencia
	telegraph_indicator = TelegraphIndicator.new()
	telegraph_indicator.name = "TelegraphIndicator"
	telegraph_indicator.indicator_scale = Vector2(1.6, 1.6)
	add_child(telegraph_indicator)

	# 1. Anillo exterior de resonadores caóticos (detrás del casco)
	outer_ring = Node2D.new()
	outer_ring.name = "ResonatorRing"
	outer_ring.z_index = -1
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

	# 2. Núcleo de sobrecarga caótica (DETRÁS del sprite para actuar como aura incandescente)
	inner_core = Polygon2D.new()
	inner_core.name = "InnerCore"
	var pts := PackedVector2Array()
	for i in range(16):
		var a := (TAU / 16.0) * float(i)
		pts.append(Vector2(cos(a), sin(a)) * 58.0)
	inner_core.polygon = pts
	inner_core.color = Color(1.0, 0.9, 0.2, 0.75)
	inner_core.z_index = -1
	add_child(inner_core)

	# 3. Casco principal (AL FRENTE)
	var tex_path := "res://assets/sprites/enemies/boss_overflow_vortex.png"
	if not ResourceLoader.exists(tex_path):
		tex_path = "res://assets/enemies/enemy_tank.png"
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex:
			vortex_hull = Sprite2D.new()
			vortex_hull.name = "VortexHull"
			vortex_hull.texture = tex
			vortex_hull.scale = Vector2(0.13, 0.13)
			vortex_hull.material = telegraph_material
			vortex_hull.z_index = 1
			add_child(vortex_hull)

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

	var spd: float = (115.0 if current_phase == 1 else 160.0) * (0.45 if is_telegraphing else 1.0)
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

	# Espiral de Fermat con respiración radial continua (Ondas Púrpura tipo 6)
	if spiral_timer >= 0.045:
		spiral_timer = 0.0
		spiral_tick += 1
		if is_instance_valid(bullet_server):
			bullet_server.fire_breathing_fermat_spiral_tick(global_position, spiral_tick, 175.0, rotation, 0.18, 0.35, 6)

	# Erupción de rosa polar de 6 puntas telegrafiada cada 3.2s
	if nova_timer >= 3.2:
		nova_timer = 0.0
		_start_telegraph(0.65, Callable(self, "_fire_overload_nova_ring"), TelegraphIndicator.TelegraphType.RING)

	# Ráfagas serpenteantes dirigidas de plasma cada 2.4s (Dardos Ámbar tipo 4)
	if aimed_timer >= 2.4:
		aimed_timer = 0.0
		if is_instance_valid(bullet_server):
			bullet_server.fire_serpentine_spread(global_position, player.global_position, 5, 36.0, 215.0, 22.0, 4.2, 4)

func _process_phase_2(delta: float) -> void:
	spiral_timer += delta
	nova_timer += delta
	aimed_timer += delta

	# Doble espiral de Fermat con respiración radial cruzada (Sobrecarga de singularidad: Púrpura 6 y Cobalto 5)
	if spiral_timer >= 0.038:
		spiral_timer = 0.0
		spiral_tick += 1
		if is_instance_valid(bullet_server):
			bullet_server.fire_breathing_fermat_spiral_tick(global_position, spiral_tick, 185.0, rotation, 0.20, 0.38, 6)
			bullet_server.fire_breathing_fermat_spiral_tick(global_position, -spiral_tick, 185.0, -rotation, 0.20, 0.38, 5)

	# Doble nova de 12 lóbulos armónicos telegrafiada cada 2.5s
	if nova_timer >= 2.5:
		nova_timer = 0.0
		_start_telegraph(0.60, Callable(self, "_fire_overload_double_nova"), TelegraphIndicator.TelegraphType.RING)

	if aimed_timer >= 1.8:
		aimed_timer = 0.0
		if is_instance_valid(bullet_server):
			bullet_server.fire_serpentine_spread(global_position, player.global_position, 7, 48.0, 240.0, 26.0, 5.0, 4)

func _fire_overload_nova_ring() -> void:
	if not is_instance_valid(bullet_server):
		return
	# Rosa de Rhodonea de 6 puntas: V(θ) = V_0 * (1 + 0.38 * cos(6 * θ)) (Cobalto tipo 5)
	bullet_server.fire_rhodonea_flower(global_position, 24, 160.0, 6, 0.38, rotation, 5)
	_play_sfx("laser", 1.0)

func _fire_overload_double_nova() -> void:
	if not is_instance_valid(bullet_server):
		return
	# Doble rosa de 12 puntas entrelazada con modulación de alta frecuencia (Cobalto 5 y Púrpura 6)
	bullet_server.fire_rhodonea_flower(global_position, 28, 175.0, 6, 0.40, rotation, 5)
	bullet_server.fire_rhodonea_flower(global_position, 28, 140.0, 12, 0.32, rotation + (PI / 12.0), 6)
	_play_sfx("missile", 1.3)

func _start_telegraph(duration: float, callback: Callable, p_type: TelegraphIndicator.TelegraphType = TelegraphIndicator.TelegraphType.RING) -> void:
	is_telegraphing = true
	if is_instance_valid(telegraph_indicator):
		var to_p: Vector2 = player.global_position - global_position if is_instance_valid(player) else Vector2.RIGHT
		telegraph_indicator.start_telegraph(p_type, duration, to_p.normalized())

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), duration * 0.7).set_trans(Tween.TRANS_BACK)
	if telegraph_material:
		tw.parallel().tween_method(func(val: float): telegraph_material.set_shader_parameter("chromatic_aberration", val), 0.0, 0.09, duration * 0.7)
		tw.parallel().tween_method(func(val: float): telegraph_material.set_shader_parameter("flash_intensity", val), 0.0, 1.0, duration * 0.7)

	tw.tween_callback(func():
		scale = Vector2(2.2, 2.2)
		if telegraph_material:
			telegraph_material.set_shader_parameter("chromatic_aberration", 0.0)
			telegraph_material.set_shader_parameter("flash_intensity", 0.0)
		callback.call()
		is_telegraphing = false
		create_tween().tween_property(self, "scale", Vector2(2.0, 2.0), 0.15)
	)

func _transition_to_phase_2() -> void:
	current_phase = 2
	phase_changed.emit(2)

	if is_instance_valid(bullet_server):
		bullet_server.clear_bullets_in_radius(global_position, 600.0)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(2.4, 2.4), 0.3)
	tw.tween_property(self, "scale", Vector2(2.0, 2.0), 0.2)

	if telegraph_material:
		telegraph_material.set_shader_parameter("domain_tint", Color(1.0, 0.05, 0.1, 1.0))

	_play_sfx("missile", 1.5)

func take_damage(arg) -> void:
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

const CinematicDeathSequenceScript = preload("res://scenes/combat/bosses/cinematic_death_sequence.gd")

func _die() -> void:
	if is_dying:
		return
	is_dying = true
	CinematicDeathSequenceScript.play_for_boss(self, _finish_death)

func _finish_death() -> void:
	boss_defeated.emit(boss_id)

	if is_instance_valid(player):
		player.add_credits(750)
		player.add_exp(900.0)

	queue_free()

func _play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name, pitch, -2.0)

const BossEmergenceHelperScript = preload("res://scenes/combat/bosses/boss_emergence_helper.gd")

func prepare_emergence(target_pos: Vector2) -> void:
	BossEmergenceHelperScript.prepare_boss(self, target_pos)

func emerge_from_tear(callback: Callable = Callable()) -> void:
	BossEmergenceHelperScript.emerge_boss(self, null, callback)

