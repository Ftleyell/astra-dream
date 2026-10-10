class_name RivalPilotBoss
extends CharacterBody2D

## Jefe y Encuentro Rival: Piloto de la Flota Astra
## Aparece en oleadas impares (1, 3, 5, 7, 9) proyectando un perímetro de advertencia.
## Si el jugador se aleja pacíficamente por >5 segundos (>1450 px), salta al hiperespacio (Perdonada / Spared).
## Si el jugador cruza el perímetro (<480 px) o ataca, comienza un intenso dogfight 1v1.
## Delega máquina de estados en RivalEngagementBehavior y cinemática en RivalFlightMotor.

signal rival_spared(pilot_id: StringName)
signal rival_engaged(pilot_id: StringName)
signal rival_defeated(pilot_id: StringName, weapon: WeaponData)
signal health_changed(current: float, max_val: float)

const RivalEngagementBehaviorScript = preload("res://scenes/combat/bosses/components/rival_engagement_behavior.gd")
const RivalFlightMotorScript = preload("res://scenes/combat/bosses/components/rival_flight_motor.gd")
const RivalWarpPresenterScript = preload("res://scenes/combat/bosses/rival_warp_presenter.gd")
const RivalCombatPatternExecutorScript = preload("res://scenes/combat/bosses/rival_combat_pattern_executor.gd")
const CinematicDeathSequenceScript = preload("res://scenes/combat/bosses/cinematic_death_sequence.gd")
const RivalVisualBuilderScript = preload("res://scenes/combat/bosses/rival_visual_builder.gd")

enum State {
	WARPING_IN,
	PEACEFUL_WARN,
	DOGFIGHT,
	WARPING_OUT,
	DYING
}

const WARNING_RADIUS: float = RivalEngagementBehaviorScript.WARNING_RADIUS
const COMBAT_TRIGGER_RADIUS: float = RivalEngagementBehaviorScript.COMBAT_TRIGGER_RADIUS
const ESCAPE_RADIUS: float = RivalEngagementBehaviorScript.ESCAPE_RADIUS
const SPARED_REQUIRED_TIME: float = RivalEngagementBehaviorScript.SPARED_REQUIRED_TIME
const CHALLENGE_REQUIRED_TIME: float = RivalEngagementBehaviorScript.CHALLENGE_REQUIRED_TIME

const PILOT_THEME_COLORS: Dictionary = {
	&"nova": Color(0.0, 0.9, 1.0),
	&"valentina": Color(1.0, 0.84, 0.0),
	&"kira": Color(1.0, 0.55, 0.0),
	&"selene": Color(0.0, 0.9, 0.45),
	&"roxy": Color(1.0, 0.1, 0.25),
	&"echo": Color(0.5, 0.3, 1.0),
	&"nyx": Color(0.85, 0.0, 0.95),
}

@export var pilot_id: StringName = &"nova"
@export var pilot_name: String = "Nova"
@export var max_health: float = 1600.0

var current_health: float = 1600.0
var character_data: CharacterData = null
var weapon_data: WeaponData = null

var player: Player = null
var bullet_server: BulletServer = null
var elapsed_time: float = 0.0
var attack_timer: float = 0.0

# Subcomponentes desacoplados
var behavior: RivalEngagementBehaviorScript = RivalEngagementBehaviorScript.new()
var flight_motor: RivalFlightMotorScript = RivalFlightMotorScript.new()

var current_state: State:
	get: return behavior.current_state as State
	set(val): behavior.current_state = val as RivalEngagementBehaviorScript.State

var spared_timer: float:
	get: return behavior.spared_timer
	set(val): behavior.spared_timer = val

var challenge_timer: float:
	get: return behavior.challenge_timer
	set(val): behavior.challenge_timer = val

# Componentes visuales
var ship_sprite: Sprite2D = null
var combat_danger_ring: Sprite2D = null
var warning_ring_color: Color = Color(1.0, 0.8, 0.1, 0.5)
var warning_ring_pulse: float = 0.0
var warning_label: Label = null
var _warp_portal: Node2D = null
var _warp_target_pos: Vector2 = Vector2.ZERO

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
	_bind_behavior()
	health_changed.emit(current_health, max_health)

	if current_state == State.WARPING_IN:
		prepare_warp_in()

func _bind_behavior() -> void:
	behavior.setup(pilot_id, pilot_name)
	behavior.combat_engaged.connect(_on_behavior_combat_engaged)
	behavior.warped_out_peacefully.connect(_on_behavior_warped_out_peacefully)

func is_peaceful() -> bool:
	return behavior.is_peaceful()

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

	behavior.setup(pilot_id, pilot_name)
	var theme_col: Color = PILOT_THEME_COLORS.get(p_id, Color(0.0, 0.9, 1.0))
	warning_ring_color = Color(theme_col.r, theme_col.g, theme_col.b, 0.5)
	max_health = 1600.0 + float(p_wave) * 280.0
	current_health = max_health

	if ship_sprite and character_data:
		var tex := character_data.get_ship_texture()
		if tex:
			ship_sprite.texture = tex

	_update_warning_label()
	queue_redraw()

func prepare_warp_in(target_rest_pos: Vector2 = Vector2.ZERO) -> void:
	current_state = State.WARPING_IN
	_warp_target_pos = RivalWarpPresenterScript.prepare_warp_in(self, target_rest_pos)

func open_warp_portal(on_shockwave_ready: Callable = Callable()) -> void:
	var theme_col: Color = PILOT_THEME_COLORS.get(pilot_id, Color(0.0, 0.9, 1.0))
	_warp_portal = RivalWarpPresenterScript.open_warp_portal(self, _warp_target_pos, theme_col, on_shockwave_ready)

func emerge_from_portal(callback: Callable = Callable()) -> void:
	var portal_ref: Variant = _warp_portal if is_instance_valid(_warp_portal) else null
	RivalWarpPresenterScript.emerge_from_portal(self, portal_ref, _warp_target_pos, callback)

func start_encounter() -> void:
	if is_instance_valid(_warp_portal):
		_warp_portal.start_collapse()
	if _warp_target_pos != Vector2.ZERO:
		global_position = _warp_target_pos
	behavior.start_encounter()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if ship_sprite:
		ship_sprite.scale = Vector2(0.42, 0.42)
		ship_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if combat_danger_ring:
		combat_danger_ring.modulate.a = 0.65
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
	ship_sprite = RivalVisualBuilderScript.setup_ship_sprite(self, character_data, pilot_id, PILOT_THEME_COLORS)
	RivalVisualBuilderScript.setup_collision_shape(self)
	warning_label = RivalVisualBuilderScript.setup_warning_label(self)
	combat_danger_ring = RivalVisualBuilderScript.setup_danger_ring(self, COMBAT_TRIGGER_RADIUS)
	_update_warning_label()

func _update_warning_label() -> void:
	if not warning_label:
		return
	warning_label.text = behavior.get_warning_text()
	warning_label.modulate = behavior.get_warning_color()

func _process(delta: float) -> void:
	if get_tree() and get_tree().paused:
		return
	elapsed_time += delta
	warning_ring_pulse += delta * 3.5
	if combat_danger_ring and is_instance_valid(combat_danger_ring):
		if current_state == State.PEACEFUL_WARN:
			combat_danger_ring.visible = true
			var base_scale: float = (COMBAT_TRIGGER_RADIUS * 2.0) / (906.0 * scale.x)
			var pulse: float = 1.0 + sin(elapsed_time * 2.2) * 0.015
			combat_danger_ring.scale = Vector2(base_scale * pulse, base_scale * pulse)
			combat_danger_ring.rotation += delta * 0.12

			var osc: float = sin(elapsed_time * 3.8) * 0.5 + 0.5
			var micro_flicker: float = sin(elapsed_time * 18.0) * 0.08
			var intensity: float = clampf(osc + micro_flicker, 0.0, 1.0)
			var col_base := Color(1.0, 0.25, 0.3, 0.65)
			var col_bright := Color(1.85, 0.65, 0.7, 0.98)
			var active_color: Color = col_base.lerp(col_bright, intensity)

			if challenge_timer > 0.0:
				var c_ratio: float = clampf(challenge_timer / CHALLENGE_REQUIRED_TIME, 0.0, 1.0)
				var fast_flicker: float = sin(elapsed_time * (18.0 + c_ratio * 16.0)) * 0.15
				var intense_intensity: float = clampf(intensity + c_ratio * 0.45 + fast_flicker, 0.0, 1.0)
				active_color = col_base.lerp(Color(2.5, 0.9, 0.9, 1.0), intense_intensity)
			elif spared_timer > 0.0:
				var s_ratio: float = clampf(spared_timer / SPARED_REQUIRED_TIME, 0.0, 1.0)
				active_color.a *= maxf(0.15, 1.0 - s_ratio * 0.7)
			combat_danger_ring.modulate = active_color
		elif combat_danger_ring.visible:
			combat_danger_ring.visible = false
	queue_redraw()

func _draw() -> void:
	var sx: float = scale.x if scale.x > 0.0 else 1.0
	if current_state == State.PEACEFUL_WARN:
		var alpha: float = 0.35 + sin(warning_ring_pulse) * 0.15
		draw_arc(Vector2.ZERO, WARNING_RADIUS / sx, 0, TAU, 64, Color(1.0, 0.8, 0.15, alpha), 2.5, true)
	elif current_state == State.DOGFIGHT:
		var alpha: float = 0.5 + sin(warning_ring_pulse * 1.5) * 0.25
		draw_arc(Vector2.ZERO, COMBAT_TRIGGER_RADIUS / sx, 0, TAU, 48, Color(1.0, 0.15, 0.2, alpha), 2.5, true)

func _physics_process(delta: float) -> void:
	if current_state == State.DYING or current_state == State.WARPING_OUT or current_state == State.WARPING_IN or (get_tree() and get_tree().paused):
		return

	if not is_instance_valid(player):
		_acquire_references()
		if not is_instance_valid(player):
			return

	var dist_to_player: float = global_position.distance_to(player.global_position)
	match current_state:
		State.PEACEFUL_WARN:
			_process_peaceful_warn(delta, dist_to_player)
		State.DOGFIGHT:
			_process_dogfight(delta, dist_to_player)

	flight_motor.update_flight_shader(self, ship_sprite, current_state == State.DOGFIGHT, delta, elapsed_time)

func _process_peaceful_warn(delta: float, dist: float) -> void:
	flight_motor.process_peaceful_flight(self, player, delta, elapsed_time)
	behavior.process_peaceful_warn(delta, dist)
	_update_warning_label()

func engage_combat() -> void:
	behavior.engage_combat()

func _on_behavior_combat_engaged(p_id: StringName) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_update_warning_label()
	if combat_danger_ring and is_instance_valid(combat_danger_ring):
		var tw_ring := create_tween()
		tw_ring.tween_property(combat_danger_ring, "modulate:a", 0.0, 0.3)
		tw_ring.chain().tween_callback(combat_danger_ring.queue_free)
		combat_danger_ring = null

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("warning", 1.0, 1.0)
	rival_engaged.emit(p_id)

func _on_behavior_warped_out_peacefully(p_id: StringName, p_name: String) -> void:
	RivalWarpPresenterScript.warp_out_peacefully(self, p_id, p_name)

func _process_dogfight(delta: float, dist: float) -> void:
	flight_motor.process_dogfight_flight(self, player, delta, dist)
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = randf_range(1.4, 2.2)
		_execute_signature_attack()

func _execute_signature_attack() -> void:
	if not is_instance_valid(player) or not is_instance_valid(bullet_server):
		return
	RivalCombatPatternExecutorScript.execute_signature_attack(bullet_server, pilot_id, global_position, player.global_position, rotation, Callable(self, "_play_sfx"))

func take_damage(arg: Variant) -> void:
	if current_state == State.DYING or current_state == State.WARPING_OUT or current_state == State.WARPING_IN or current_state == State.PEACEFUL_WARN:
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

	if ship_sprite:
		var orig_mod := ship_sprite.modulate
		ship_sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
		create_tween().tween_property(ship_sprite, "modulate", orig_mod, 0.08)
		if ship_sprite.material is ShaderMaterial:
			var mat := ship_sprite.material as ShaderMaterial
			mat.set_shader_parameter("hit_flash", 1.0)
			create_tween().tween_method(func(val: float) -> void: mat.set_shader_parameter("hit_flash", val), 1.0, 0.0, 0.12)

	if current_health <= 0.0:
		_die()

func _die() -> void:
	if current_state == State.DYING:
		return
	current_state = State.DYING
	set_physics_process(false)
	set_process(false)
	if warning_label and is_instance_valid(warning_label):
		warning_label.visible = false
	if combat_danger_ring and is_instance_valid(combat_danger_ring):
		combat_danger_ring.visible = false
	queue_redraw()
	CinematicDeathSequenceScript.play_for_boss(self, _finish_death)

func _finish_death() -> void:
	rival_defeated.emit(pilot_id, weapon_data)
	if weapon_data:
		RivalCombatPatternExecutorScript.drop_weapon_pickup(get_tree(), get_parent(), global_position, weapon_data, pilot_name)
	queue_free()

func _play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name, 1.0, pitch)
