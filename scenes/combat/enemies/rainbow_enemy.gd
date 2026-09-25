class_name RainbowEnemy
extends EnemyBase

## Enemigo estilo Loot Goblin espacial (Nave Botín Arcoíris).
## Cruza transversalmente el campo de visión del jugador en trayectoria en arco.
## Al ser golpeado, realiza impulsos de pánico con estelas de chispas doradas.
## Al ser destruido, genera una explosión sci-fi completa con restos de nave, onda expansiva,
## sacudida de pantalla, jackpot de créditos y un nivel completo instantáneo.

var escape_timer: float = 16.0
var panic_timer: float = 0.0
const PANIC_BOOST: float = 60.0
var _current_flight_dir: Vector2 = Vector2.RIGHT
var is_escaping: bool = false
var _flight_wobble_time: float = 0.0

@onready var engine_particles: CPUParticles2D = get_node_or_null("EngineParticles")

func _ready_custom() -> void:
	enemy_id = &"enemy_rainbow"
	max_health = 350.0
	current_health = max_health
	move_speed = 240.0
	contact_damage = 0.0
	credits_reward = 250
	exp_reward = 100.0

	_acquire_player()
	if _current_flight_dir == Vector2.RIGHT and is_instance_valid(player):
		var to_self := (global_position - player.global_position).normalized()
		var tangent := Vector2(-to_self.y, to_self.x)
		_current_flight_dir = (tangent * 0.75 + to_self * 0.25).normalized()

	rotation = _current_flight_dir.angle() + PI * 0.5

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.7)

func setup_transverse_flight(center: Vector2, spawn_angle: float) -> void:
	# Trayectoria transversal en arco a través del campo visual del jugador
	var radial_dir := Vector2.from_angle(spawn_angle)
	var sign_tangent := 1.0 if randf() > 0.5 else -1.0
	var tangent_dir := Vector2(-radial_dir.y * sign_tangent, radial_dir.x * sign_tangent)
	# 75% tangencial (cruzando pantalla), 25% radial leve hacia afuera
	_current_flight_dir = (tangent_dir * 0.75 + radial_dir * 0.25).normalized()
	rotation = _current_flight_dir.angle() + PI * 0.5

func take_damage(arg) -> void:
	super.take_damage(arg)
	if is_dying:
		return
	panic_timer = 0.45
	_spawn_panic_sparks()

func _update_behavior(delta: float) -> void:
	if is_dying or is_escaping:
		return

	escape_timer -= delta
	if escape_timer <= 0.0:
		_warp_escape()
		return

	_flight_wobble_time += delta

	# Maniobras de evasión: si el jugador está muy cerca, huir prioritariamente
	if is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist < 230.0:
			var flee_dir := (global_position - player.global_position).normalized()
			_current_flight_dir = _current_flight_dir.lerp(flee_dir, delta * 3.5).normalized()
		else:
			# Curvatura suave y oscilación de vuelo evasivo
			var wobble := sin(_flight_wobble_time * 2.8) * 0.25
			var swayed_dir := _current_flight_dir.rotated(wobble * delta * 1.5).normalized()
			_current_flight_dir = _current_flight_dir.lerp(swayed_dir, delta * 2.0).normalized()

	if panic_timer > 0.0:
		panic_timer -= delta

	var cur_speed := move_speed + (PANIC_BOOST if panic_timer > 0.0 else 0.0)
	velocity = _current_flight_dir * cur_speed

	# Orientación suave y precisa del morro de la nave en dirección al vector de vuelo
	var target_rot := _current_flight_dir.angle() + PI * 0.5
	rotation = rotate_toward(rotation, target_rot, delta * 12.0)
	move_and_slide()

func _spawn_panic_sparks() -> void:
	var p: Node = get_parent() if is_inside_tree() else null
	if not p:
		return
	for i in range(3):
		var spark := Node2D.new()
		spark.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		p.add_child(spark)

		var spr := Sprite2D.new()
		var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.85, 0.2, 0.9))
		spr.texture = ImageTexture.create_from_image(img)
		spark.add_child(spr)

		var move_offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
		var tw := spark.create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "position", spark.position + move_offset, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(spark.queue_free)

func _warp_escape() -> void:
	if is_escaping or is_dying:
		return
	is_escaping = true
	if engine_particles:
		engine_particles.emitting = false

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.01, 2.8), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)

func _on_die_extra() -> void:
	# 1. Ocultar inmediatamente el sprite y motores para evitar nave estática congelada
	if sprite:
		sprite.visible = false
	if engine_particles:
		engine_particles.emitting = false

	# 2. Sacudida de impacto/destrucción en cámara
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.40)

	var p_parent: Node = get_parent() if is_inside_tree() else null
	if not p_parent and is_inside_tree():
		p_parent = get_tree().current_scene

	# 3. Explosión sci-fi completa de nave con restos de casco y shockwaves
	var explosion_scene: PackedScene = preload("res://scenes/combat/player/player_explosion_vfx.tscn")
	if explosion_scene and p_parent:
		var vfx = explosion_scene.instantiate()
		p_parent.add_child(vfx)
		if vfx.has_method("setup"):
			vfx.setup(global_position, Color(1.0, 0.85, 0.25, 1.0))

	# 4. Fuente de chispas y monedas doradas (Jackpot)
	if p_parent:
		_spawn_jackpot_fountain(p_parent)
		FloatingText.spawn(p_parent, global_position + Vector2(0, -35), "💰 +250 CRÉDITOS // ¡NIVEL OBTENIDO!", Color(1.0, 0.88, 0.25))

	# 5. Otorga 1 nivel completo instantáneo al jugador
	if is_instance_valid(player) and player.has_method("add_exp"):
		var exp_needed: float = maxf(1.0, player.exp_to_next - player.current_exp)
		player.add_exp(exp_needed)

	# 6. Audio cinematográfico de detonación de reactor botín
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("explosion", 0.85)
		audio_mgr.play_sfx("ui_click", 0.0, 1.8)

func _spawn_jackpot_fountain(p_node: Node) -> void:
	for i in range(12):
		var drop := Node2D.new()
		drop.global_position = global_position
		p_node.add_child(drop)

		var spr := Sprite2D.new()
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.88, 0.2, 1.0))
		spr.texture = ImageTexture.create_from_image(img)
		drop.add_child(spr)

		var angle := randf() * TAU
		var dist := randf_range(40.0, 110.0)
		var target_pos := global_position + Vector2(cos(angle), sin(angle)) * dist

		var tw := drop.create_tween()
		tw.set_parallel(true)
		tw.tween_property(drop, "position", target_pos, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(drop, "scale", Vector2(0.2, 0.2), 0.55)
		tw.tween_property(drop, "modulate:a", 0.0, 0.55).set_delay(0.25)
		tw.chain().tween_callback(drop.queue_free)
