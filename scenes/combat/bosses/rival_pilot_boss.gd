class_name RivalPilotBoss
extends CharacterBody2D

## Jefe y Encuentro Rival: Piloto de la Flota Astra
## Aparece en oleadas impares (1, 3, 5, 7, 9) proyectando un perímetro de advertencia.
## Si el jugador se aleja pacíficamente por >4 segundos (>1400 px), salta al hiperespacio (Perdonada / Spared).
## Si el jugador cruza el perímetro (<720 px) o ataca, comienza un intenso dogfight 1v1.
## Al ser derrotada, suelta su arma básica insignia en una cápsula recolectable.

signal rival_spared(pilot_id: StringName)
signal rival_engaged(pilot_id: StringName)
signal rival_defeated(pilot_id: StringName, weapon: WeaponData)
signal health_changed(current: float, max_val: float)

enum State {
	PEACEFUL_WARN,
	DOGFIGHT,
	WARPING_OUT,
	DYING
}

const WARNING_RADIUS: float = 720.0
const ESCAPE_RADIUS: float = 1400.0
const SPARED_REQUIRED_TIME: float = 4.0

@export var pilot_id: StringName = &"nova"
@export var pilot_name: String = "Nova"
@export var max_health: float = 950.0

var current_health: float = 950.0
var current_state: State = State.PEACEFUL_WARN
var character_data: CharacterData = null
var weapon_data: WeaponData = null

var player: Player = null
var bullet_server: BulletServer = null
var elapsed_time: float = 0.0
var spared_timer: float = 0.0
var attack_timer: float = 0.0
var dash_timer: float = 0.0
var is_dashing: bool = false
var dash_velocity: Vector2 = Vector2.ZERO

# Componentes visuales
var ship_sprite: Sprite2D = null
var engine_trail: Line2D = null
var warning_ring_color: Color = Color(1.0, 0.8, 0.1, 0.5)
var warning_ring_pulse: float = 0.0
var warning_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	add_to_group("rival_pilots")

	current_health = max_health
	_acquire_references()
	_setup_visuals()
	health_changed.emit(current_health, max_health)

func setup_pilot(p_id: StringName, p_wave: int = 1) -> void:
	pilot_id = p_id
	var roster := CharacterData.load_roster()
	if roster.has(p_id):
		character_data = roster[p_id]
		pilot_name = character_data.display_name
		weapon_data = character_data.starting_weapon

	# Escalamiento por oleada
	max_health = 750.0 + float(p_wave) * 160.0
	current_health = max_health

	if ship_sprite and character_data:
		var tex := character_data.get_ship_texture()
		if tex:
			ship_sprite.texture = tex

	_update_warning_label()
	queue_redraw()

func _acquire_references() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(bullet_server):
		bullet_server = get_node_or_null("/root/BulletServer") as BulletServer
		if not bullet_server and get_parent():
			bullet_server = get_parent().get_node_or_null("BulletServer") as BulletServer

func _setup_visuals() -> void:
	ship_sprite = Sprite2D.new()
	ship_sprite.name = "ShipSprite"
	add_child(ship_sprite)

	if character_data:
		var tex := character_data.get_ship_texture()
		if tex:
			ship_sprite.texture = tex
	else:
		# Textura de fallback
		var fb_path := "res://assets/characters/ships/ship_nova.png"
		if ResourceLoader.exists(fb_path):
			ship_sprite.texture = load(fb_path) as Texture2D

	# Colisión básica para recibir impactos
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	col.shape = circle
	add_child(col)

	# Label de advertencia
	warning_label = Label.new()
	warning_label.name = "WarningLabel"
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.position = Vector2(-200, -65)
	warning_label.size = Vector2(400, 30)
	warning_label.add_theme_font_size_override("font_size", 13)
	add_child(warning_label)
	_update_warning_label()

func _update_warning_label() -> void:
	if not warning_label:
		return
	if current_state == State.PEACEFUL_WARN:
		warning_label.text = "⚠️ %s: ¡ALÉJATE DEL SECTOR!\n(Retrocede para evitar el combate)" % pilot_name.to_upper()
		warning_label.modulate = Color(1.0, 0.85, 0.2, 0.95)
	elif current_state == State.DOGFIGHT:
		warning_label.text = "⚔️ EN DUELO: PILOTO %s" % pilot_name.to_upper()
		warning_label.modulate = Color(1.0, 0.2, 0.2, 0.95)
	else:
		warning_label.text = ""

func _process(delta: float) -> void:
	elapsed_time += delta
	warning_ring_pulse += delta * 3.5
	queue_redraw()

func _draw() -> void:
	if current_state == State.PEACEFUL_WARN:
		var alpha := 0.35 + sin(warning_ring_pulse) * 0.15
		var col := Color(1.0, 0.8, 0.15, alpha)
		draw_arc(Vector2.ZERO, WARNING_RADIUS, 0, TAU, 64, col, 3.0, true)
		# Anillo de peligro interno
		draw_arc(Vector2.ZERO, WARNING_RADIUS * 0.5, 0, TAU, 48, Color(1.0, 0.4, 0.1, alpha * 0.6), 1.5, true)
	elif current_state == State.DOGFIGHT:
		var alpha := 0.5 + sin(warning_ring_pulse * 1.5) * 0.25
		draw_arc(Vector2.ZERO, 380.0, 0, TAU, 48, Color(1.0, 0.15, 0.2, alpha), 2.5, true)

func _physics_process(delta: float) -> void:
	if current_state == State.DYING or current_state == State.WARPING_OUT:
		return

	if not is_instance_valid(player):
		_acquire_references()
		if not is_instance_valid(player):
			return

	var dist_to_player := global_position.distance_to(player.global_position)

	match current_state:
		State.PEACEFUL_WARN:
			_process_peaceful_warn(delta, dist_to_player)
		State.DOGFIGHT:
			_process_dogfight(delta, dist_to_player)

func _process_peaceful_warn(delta: float, dist: float) -> void:
	# Rotar mirando al jugador con cautela
	var dir := (player.global_position - global_position).normalized()
	rotation = lerp_angle(rotation, dir.angle() + PI / 2.0, 5.0 * delta)

	# Suave flotación orbital
	velocity = Vector2(-dir.y, dir.x) * sin(elapsed_time * 1.5) * 45.0
	move_and_slide()

	# Condición de combate: el jugador cruza el perímetro
	if dist <= WARNING_RADIUS:
		engage_combat()
		return

	# Condición de perdón: el jugador se aleja (> 1400 px) o permanece fuera respetando la distancia
	if dist >= ESCAPE_RADIUS or dist >= (WARNING_RADIUS + 250.0):
		spared_timer += delta
		if spared_timer >= SPARED_REQUIRED_TIME:
			_warp_out_peacefully()
	else:
		spared_timer = maxf(0.0, spared_timer - delta * 0.5)

func engage_combat() -> void:
	if current_state == State.DOGFIGHT:
		return
	current_state = State.DOGFIGHT
	_update_warning_label()

	# Alarma sonora y feedback
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("warning", 1.0, 1.0)

	rival_engaged.emit(pilot_id)

func _warp_out_peacefully() -> void:
	current_state = State.WARPING_OUT
	if warning_label:
		warning_label.text = "✓ %s: HIPERSALTO INICIADO. CONTACTO PACÍFICO." % pilot_name.to_upper()
		warning_label.modulate = Color(0.2, 1.0, 0.6, 1.0)

	rival_spared.emit(pilot_id)

	# Animación de hipersalto hacia adelante
	var forward := Vector2.UP.rotated(rotation)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", global_position + forward * 900.0, 0.8).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(0.1, 2.5), 0.8)
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(queue_free)

func _process_dogfight(delta: float, dist: float) -> void:
	var to_player := (player.global_position - global_position).normalized()
	rotation = lerp_angle(rotation, to_player.angle() + PI / 2.0, 8.0 * delta)

	# IA de movimiento: maniobra en espiral / órbita táctica a ~400 px
	var ideal_dist := 400.0
	var radial_speed := (dist - ideal_dist) * 1.5
	var orbit_dir := Vector2(-to_player.y, to_player.x)
	var target_vel := (to_player * radial_speed) + (orbit_dir * 310.0)

	# Micro-dash evasivo
	dash_timer -= delta
	if dash_timer <= 0.0:
		dash_timer = randf_range(2.5, 4.0)
		is_dashing = true
		dash_velocity = orbit_dir * (randf_range(500.0, 650.0) * (1.0 if randf() > 0.5 else -1.0))
		create_tween().tween_callback(func(): is_dashing = false).set_delay(0.35)

	if is_dashing:
		velocity = dash_velocity
	else:
		velocity = velocity.move_toward(target_vel, 700.0 * delta)
	move_and_slide()

	# Ataques insignia según el piloto
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = randf_range(1.4, 2.2)
		_execute_signature_attack()

func _execute_signature_attack() -> void:
	if not is_instance_valid(player) or not is_instance_valid(bullet_server):
		return

	var target_pos := player.global_position

	match pilot_id:
		&"nova":
			# Ráfaga rápida de riel acelerada
			bullet_server.fire_aimed_spread(global_position, target_pos, 3, 14.0, 340.0, 2)
			_play_sfx("laser", 1.2)
		&"valentina":
			# Francotirador telegrafiado de altísima velocidad
			bullet_server.fire_common_aimed_bullet(global_position, target_pos, 440.0, 1)
			_play_sfx("laser", 0.8)
		&"kira":
			# Enjambre de proyectiles biomórficos en espiral
			bullet_server.fire_serpentine_spread(global_position, target_pos, 5, 35.0, 210.0, 40.0, 3.5, 0)
			_play_sfx("missile", 1.0)
		&"selene":
			# Pulso gravitatorio y abanico de estrellas
			bullet_server.fire_radial_ring(global_position, 12, 180.0, rotation, 3)
			_play_sfx("missile", 0.9)
		&"roxy":
			# Escopetazo titánico con dispersión pesada
			bullet_server.fire_aimed_spread(global_position, target_pos, 7, 45.0, 260.0, 1)
			_play_sfx("explosion", 1.1)
		&"echo":
			# Trenza eléctrica de doble lissajous
			bullet_server.fire_braided_lissajous(global_position, target_pos, 3, 240.0, 50.0, 4.0, 2)
			_play_sfx("laser", 1.4)
		&"nyx":
			# Cuchillas dimensionales en abanico
			bullet_server.fire_rhodonea_flower(global_position, 14, 220.0, 4, 0.4, rotation, 1)
			_play_sfx("laser", 1.3)
		_:
			bullet_server.fire_aimed_spread(global_position, target_pos, 4, 25.0, 260.0, 1)

func take_damage(arg: Variant) -> void:
	if current_state == State.DYING or current_state == State.WARPING_OUT:
		return

	# Si estaba en fase pacífica y es atacada, entra en combate inmediatamente
	if current_state == State.PEACEFUL_WARN:
		engage_combat()

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

	# Flash de impacto
	if ship_sprite:
		var orig_mod := ship_sprite.modulate
		ship_sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
		create_tween().tween_property(ship_sprite, "modulate", orig_mod, 0.08)

	if current_health <= 0.0:
		_die()

func _die() -> void:
	current_state = State.DYING
	set_physics_process(false)

	# Emisión de muerte
	rival_defeated.emit(pilot_id, weapon_data)

	# Spawning de la cápsula de armamento
	if weapon_data:
		_drop_weapon_pickup()

	# Secuencia de explosión dramática
	_play_sfx("explosion", 0.9)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(queue_free)

func _drop_weapon_pickup() -> void:
	var pickup_scene := load("res://scenes/combat/pickups/rival_weapon_pickup.tscn") as PackedScene
	if pickup_scene:
		var pickup = pickup_scene.instantiate()
		pickup.setup(global_position, weapon_data, pilot_name)
		get_parent().add_child.call_deferred(pickup)

func _play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name, 1.0, pitch)
