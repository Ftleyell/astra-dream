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
	WARPING_IN,
	PEACEFUL_WARN,
	DOGFIGHT,
	WARPING_OUT,
	DYING
}

const WARNING_RADIUS: float = 650.0
const COMBAT_TRIGGER_RADIUS: float = 480.0
const PROXIMITY_SHIELD_RADIUS: float = 480.0
const ESCAPE_RADIUS: float = 1450.0
const SPARED_REQUIRED_TIME: float = 5.0
const CHALLENGE_REQUIRED_TIME: float = 2.0

@export var pilot_id: StringName = &"nova"
@export var pilot_name: String = "Nova"
@export var max_health: float = 950.0

var current_health: float = 950.0
var current_state: State = State.WARPING_IN
var character_data: CharacterData = null
var weapon_data: WeaponData = null

var player: Player = null
var bullet_server: BulletServer = null
var elapsed_time: float = 0.0
var spared_timer: float = 0.0
var challenge_timer: float = 0.0
var attack_timer: float = 0.0
var dash_timer: float = 0.0
var is_dashing: bool = false
var dash_velocity: Vector2 = Vector2.ZERO

# Componentes visuales
var ship_sprite: Sprite2D = null
var shield_sprite: Sprite2D = null
var engine_trail: Line2D = null
var warning_ring_color: Color = Color(1.0, 0.8, 0.1, 0.5)
var warning_ring_pulse: float = 0.0
var warning_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	add_to_group("rival_pilots")
	add_to_group("rival_pilot")
	add_to_group("bosses")
	scale = Vector2(1.2, 1.2)

	current_health = max_health
	_acquire_references()
	_setup_visuals()
	health_changed.emit(current_health, max_health)

	if current_state == State.WARPING_IN:
		prepare_warp_in()

const PILOT_THEME_COLORS: Dictionary = {
	&"nova": Color(0.0, 0.9, 1.0),
	&"valentina": Color(1.0, 0.84, 0.0),
	&"kira": Color(1.0, 0.55, 0.0),
	&"selene": Color(0.0, 0.9, 0.45),
	&"roxy": Color(1.0, 0.1, 0.25),
	&"echo": Color(0.5, 0.3, 1.0),
	&"nyx": Color(0.85, 0.0, 0.95),
}

const HyperspacePortalScript := preload("res://scenes/combat/bosses/hyperspace_portal.gd")

var _warp_portal: Node2D = null
var _warp_target_pos: Vector2 = Vector2.ZERO

func _exit_tree() -> void:
	if _warp_portal and is_instance_valid(_warp_portal):
		_warp_portal.queue_free()
		_warp_portal = null

func setup_pilot(p_id: StringName, p_wave: int = 1) -> void:
	pilot_id = p_id
	var roster := CharacterData.load_roster()
	if roster.has(p_id):
		character_data = roster[p_id]
		pilot_name = character_data.display_name
		weapon_data = character_data.starting_weapon

	# Color temático del anillo de advertencia según la piloto
	var theme_col: Color = PILOT_THEME_COLORS.get(p_id, Color(0.0, 0.9, 1.0))
	warning_ring_color = Color(theme_col.r, theme_col.g, theme_col.b, 0.5)

	# Escalamiento por oleada
	max_health = 750.0 + float(p_wave) * 160.0
	current_health = max_health

	if ship_sprite and character_data:
		var tex := character_data.get_ship_texture()
		if tex:
			ship_sprite.texture = tex

	_update_warning_label()
	queue_redraw()

func prepare_warp_in(target_rest_pos: Vector2 = Vector2.ZERO) -> void:
	current_state = State.WARPING_IN
	rotation = -PI / 2.0
	if target_rest_pos != Vector2.ZERO:
		_warp_target_pos = target_rest_pos
		global_position = _warp_target_pos + Vector2(90.0, 0.0)
	elif _warp_target_pos == Vector2.ZERO:
		_warp_target_pos = global_position
		global_position = _warp_target_pos + Vector2(90.0, 0.0)

	if ship_sprite:
		ship_sprite.scale = Vector2(0.01, 0.01)
		ship_sprite.modulate = Color(2.5, 2.5, 3.5, 0.0)
	if shield_sprite:
		shield_sprite.modulate.a = 0.0
	if warning_label:
		warning_label.modulate.a = 0.0
	queue_redraw()

func open_warp_portal(on_shockwave_ready: Callable = Callable()) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rotation = -PI / 2.0

	if _warp_target_pos == Vector2.ZERO:
		_warp_target_pos = global_position
	var portal_pos: Vector2 = _warp_target_pos + Vector2(90.0, 0.0)
	var theme_col: Color = PILOT_THEME_COLORS.get(pilot_id, Color(0.0, 0.9, 1.0))

	# Instanciar el vórtice hiperespacial temático
	var portal = HyperspacePortalScript.new()
	portal.setup(portal_pos, theme_col, 68.0, 680.0)
	portal.auto_collapse = false
	portal.process_mode = Node.PROCESS_MODE_ALWAYS
	_warp_portal = portal
	var parent_node := get_parent()
	if parent_node:
		parent_node.add_child(portal)
	else:
		add_child(portal)

	# La nave permanece dentro del portal totalmente oculta
	global_position = portal_pos
	if ship_sprite:
		ship_sprite.scale = Vector2(0.01, 0.01)
		ship_sprite.modulate = Color(2.5, 2.5, 3.5, 0.0)
	if shield_sprite:
		shield_sprite.modulate.a = 0.0
	if warning_label:
		warning_label.modulate.a = 0.0

	if on_shockwave_ready.is_valid():
		portal.shockwave_completed.connect(on_shockwave_ready, CONNECT_ONE_SHOT)

func emerge_from_portal(callback: Callable = Callable()) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ship_sprite:
		if callback.is_valid():
			callback.call()
		return

	_play_sfx("dash", 0.65)
	var tw := create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tw.tween_property(self, "global_position", _warp_target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var t_anim := tw.tween_property(ship_sprite, "scale", Vector2(0.42, 0.42), 0.5)
	t_anim.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ship_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)

	if shield_sprite:
		tw.tween_property(shield_sprite, "modulate:a", 0.85, 0.5)

	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(_warp_portal):
			_warp_portal.start_collapse()
		if callback.is_valid():
			callback.call()
	)

func start_encounter() -> void:
	current_state = State.PEACEFUL_WARN
	process_mode = Node.PROCESS_MODE_PAUSABLE
	spared_timer = 0.0
	challenge_timer = 0.0
	if warning_label:
		warning_label.modulate.a = 1.0
	_update_warning_label()
	queue_redraw()

func play_warp_in_cinematic(callback: Callable = Callable()) -> void:
	open_warp_portal(func() -> void:
		emerge_from_portal(func() -> void:
			start_encounter()
			if callback.is_valid():
				callback.call()
		)
	)

func _acquire_references() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(bullet_server):
		bullet_server = get_node_or_null("/root/BulletServer") as BulletServer
		if not bullet_server and get_parent():
			bullet_server = get_parent().get_node_or_null("BulletServer") as BulletServer

func _setup_visuals() -> void:
	if not ship_sprite:
		ship_sprite = Sprite2D.new()
		ship_sprite.name = "ShipSprite"
		ship_sprite.scale = Vector2(0.42, 0.42)
		ship_sprite.z_index = 2
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

	# Colisión de la nave entera (escala 0.42 de nave ~36px -> radio 18.0)
	var existing_col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if existing_col and existing_col.shape is CircleShape2D:
		(existing_col.shape as CircleShape2D).radius = 18.0
	elif not existing_col:
		var col := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 18.0
		col.shape = circle
		add_child(col)

	# Label de advertencia
	warning_label = Label.new()
	warning_label.name = "WarningLabel"
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.position = Vector2(-200, -85)
	warning_label.size = Vector2(400, 30)
	warning_label.z_index = 3
	warning_label.add_theme_font_size_override("font_size", 13)
	add_child(warning_label)

	# Escudo de proximidad pacífico (~480px de radio = 960px diámetro)
	if not shield_sprite:
		shield_sprite = Sprite2D.new()
		shield_sprite.name = "ProximityShieldSprite"
		var shield_tex_path := "res://assets/sprites/effects/energy_dome_shield.png"
		var shield_tex: Texture2D = null
		if ResourceLoader.exists(shield_tex_path):
			var res = load(shield_tex_path)
			if res is Texture2D:
				shield_tex = res
		if not shield_tex:
			var global_path := ProjectSettings.globalize_path(shield_tex_path)
			if FileAccess.file_exists(global_path):
				var img := Image.new()
				if img.load(global_path) == OK:
					shield_tex = ImageTexture.create_from_image(img)
		shield_sprite.texture = shield_tex

		# Material con mezcla aditiva para resplandor holográfico vibrante
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		shield_sprite.material = mat

		# El sprite original es 1024x1024. Para abarcar 480px de radio (960px diámetro):
		var target_scale: float = (PROXIMITY_SHIELD_RADIUS * 2.0) / (1024.0 * scale.x)
		shield_sprite.scale = Vector2(target_scale, target_scale)
		shield_sprite.modulate = Color(0.3, 0.85, 1.0, 0.85)
		shield_sprite.z_index = 1
		add_child(shield_sprite)

	_update_warning_label()

func _update_warning_label() -> void:
	if not warning_label:
		return
	if current_state == State.PEACEFUL_WARN:
		if challenge_timer > 0.0:
			var remaining := maxf(0.0, CHALLENGE_REQUIRED_TIME - challenge_timer)
			warning_label.text = "⚠️ RETANDO A %s (%.1fs)...\n[ Permanece cerca para iniciar combate ]" % [pilot_name.to_upper(), remaining]
			warning_label.modulate = Color(1.0, 0.45, 0.2, 0.95)
		elif spared_timer > 0.0:
			var remaining := maxf(0.0, SPARED_REQUIRED_TIME - spared_timer)
			warning_label.text = "⚠️ %s: RETIRÁNDOSE (%.1fs)...\n(Mantén distancia para perdonar)" % [pilot_name.to_upper(), remaining]
			warning_label.modulate = Color(0.3, 1.0, 0.5, 0.95)
		else:
			warning_label.text = "🛡️ ESCUDO IMPENETRABLE — %s\n[ Aléjate para perdonar | Permanece cerca para retar ]" % pilot_name.to_upper()
			warning_label.modulate = Color(0.2, 0.85, 1.0, 0.95)
	elif current_state == State.DOGFIGHT:
		warning_label.text = "⚔️ EN DUELO: PILOTO %s" % pilot_name.to_upper()
		warning_label.modulate = Color(1.0, 0.2, 0.2, 0.95)
	else:
		warning_label.text = ""

func _process(delta: float) -> void:
	elapsed_time += delta
	warning_ring_pulse += delta * 3.5
	if shield_sprite and is_instance_valid(shield_sprite):
		if current_state == State.PEACEFUL_WARN:
			var base_scale: float = (PROXIMITY_SHIELD_RADIUS * 2.0) / (1024.0 * scale.x)
			var pulse := 1.0 + sin(elapsed_time * 3.0) * 0.03
			shield_sprite.scale = Vector2(base_scale * pulse, base_scale * pulse)
			shield_sprite.modulate.a = 0.8 + sin(elapsed_time * 4.0) * 0.15
			shield_sprite.rotation += delta * 0.3
		elif shield_sprite.visible:
			shield_sprite.visible = false
	queue_redraw()

func _draw() -> void:
	var sx: float = scale.x if scale.x > 0.0 else 1.0
	if current_state == State.PEACEFUL_WARN:
		var alpha := 0.35 + sin(warning_ring_pulse) * 0.15
		var col := Color(1.0, 0.8, 0.15, alpha)
		# Anillo de advertencia exterior
		draw_arc(Vector2.ZERO, WARNING_RADIUS / sx, 0, TAU, 64, col, 2.5, true)
		# Anillo de peligro / detonador de combate interior
		var combat_col := Color(1.0, 0.25, 0.15, alpha * 0.9)
		draw_arc(Vector2.ZERO, COMBAT_TRIGGER_RADIUS / sx, 0, TAU, 48, combat_col, 2.5, true)
	elif current_state == State.DOGFIGHT:
		var alpha := 0.5 + sin(warning_ring_pulse * 1.5) * 0.25
		draw_arc(Vector2.ZERO, COMBAT_TRIGGER_RADIUS / sx, 0, TAU, 48, Color(1.0, 0.15, 0.2, alpha), 2.5, true)

func _physics_process(delta: float) -> void:
	if current_state == State.DYING or current_state == State.WARPING_OUT or current_state == State.WARPING_IN:
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
	if is_instance_valid(player):
		# Rotar mirando al jugador con cautela
		var dir := (player.global_position - global_position).normalized()
		rotation = lerp_angle(rotation, dir.angle() + PI / 2.0, 5.0 * delta)

		# Suave flotación orbital
		velocity = Vector2(-dir.y, dir.x) * sin(elapsed_time * 1.5) * 45.0
		move_and_slide()

	# Condición de combate: entrar y permanecer en la zona de desafío durante CHALLENGE_REQUIRED_TIME
	if dist <= COMBAT_TRIGGER_RADIUS:
		challenge_timer += delta
		spared_timer = 0.0
		_update_warning_label()
		if challenge_timer >= CHALLENGE_REQUIRED_TIME:
			engage_combat()
		return
	else:
		challenge_timer = maxf(0.0, challenge_timer - delta * 1.5)

	# Condición de perdón: el jugador se aleja (> ESCAPE_RADIUS)
	if dist >= ESCAPE_RADIUS:
		spared_timer += delta
		_update_warning_label()
		if spared_timer >= SPARED_REQUIRED_TIME:
			_warp_out_peacefully()
	else:
		spared_timer = maxf(0.0, spared_timer - delta * 0.8)
		_update_warning_label()

func engage_combat() -> void:
	if current_state == State.DOGFIGHT:
		return
	current_state = State.DOGFIGHT
	_update_warning_label()

	# Disipar escudo de energía con efecto de colapso
	if shield_sprite and is_instance_valid(shield_sprite):
		var tw_shield := create_tween()
		tw_shield.set_parallel(true)
		tw_shield.tween_property(shield_sprite, "scale", shield_sprite.scale * 1.35, 0.25)
		tw_shield.tween_property(shield_sprite, "modulate:a", 0.0, 0.25)
		tw_shield.chain().tween_callback(shield_sprite.queue_free)
		shield_sprite = null

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
	if not is_instance_valid(player):
		return
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
	if current_state == State.DYING or current_state == State.WARPING_OUT or current_state == State.WARPING_IN:
		return

	# Si está en fase pacífica, atacar a la rival rompe el perímetro pacífico y desata el combate:
	if current_state == State.PEACEFUL_WARN:
		engage_combat()
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

	# Flash de impacto
	if ship_sprite:
		var orig_mod := ship_sprite.modulate
		ship_sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
		create_tween().tween_property(ship_sprite, "modulate", orig_mod, 0.08)

	if current_health <= 0.0:
		_die()

const CinematicDeathSequenceScript = preload("res://scenes/combat/bosses/cinematic_death_sequence.gd")

func _die() -> void:
	if current_state == State.DYING:
		return
	current_state = State.DYING
	set_physics_process(false)
	set_process(false)

	# Limpiar indicadores y etiquetas de advertencia en pantalla
	if warning_label and is_instance_valid(warning_label):
		warning_label.visible = false
	if shield_sprite and is_instance_valid(shield_sprite):
		shield_sprite.visible = false
	queue_redraw()

	# Ejecutar secuencia cinematográfica estilizada con paleta de color propia de la piloto
	CinematicDeathSequenceScript.play_for_boss(self, _finish_death)

func _finish_death() -> void:
	# Emisión de evento y recompensas
	rival_defeated.emit(pilot_id, weapon_data)

	# Spawning de la cápsula de armamento
	if weapon_data:
		_drop_weapon_pickup()

	queue_free()

func _drop_weapon_pickup() -> void:
	var pickup_scene := load("res://scenes/combat/pickups/rival_weapon_pickup.tscn") as PackedScene
	if pickup_scene:
		var pickup = pickup_scene.instantiate()
		pickup.setup(global_position, weapon_data, pilot_name)
		var spawn_parent: Node = get_parent() if get_parent() else get_tree().current_scene
		if spawn_parent:
			spawn_parent.call_deferred("add_child", pickup)

func _play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name, 1.0, pitch)
