class_name WeaponController
extends Node2D

@export var weapon_data: WeaponData
@export var player: Player

var active_cooldown: float = 0.0
var passive_timer: float = 0.0

func _ready() -> void:
	if not weapon_data:
		weapon_data = WeaponData.new()
	passive_timer = weapon_data.passive_interval

func _process(delta: float) -> void:
	_handle_aim()
	_handle_active_fire(delta)
	_handle_passive_fire(delta)

func _handle_aim() -> void:
	var mouse_pos := get_global_mouse_position()
	look_at(mouse_pos)

func _handle_active_fire(delta: float) -> void:
	if active_cooldown > 0.0:
		active_cooldown -= delta

	if Input.is_action_pressed("fire_active") and active_cooldown <= 0.0:
		var atk_speed: float = player.stats.get_stat(&"attack_speed") if player else 1.0
		active_cooldown = weapon_data.base_cooldown / maxf(0.1, atk_speed)
		_fire_active()

func _fire_active() -> void:
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	var base_dmg: float = weapon_data.base_damage + (player.stats.get_stat(&"base_damage") if player else 0.0)
	var crit_chance: float = player.stats.get_stat(&"crit_chance") if player else 0.05
	var is_crit := randf() <= crit_chance
	var crit_mult: float = player.stats.get_stat(&"crit_damage") if player else 1.5
	var final_dmg := base_dmg * (crit_mult if is_crit else 1.0)

	var ctx := HitContext.new()
	ctx.attacker = player
	ctx.raw_damage = base_dmg
	ctx.final_damage = final_dmg
	ctx.is_crit = is_crit
	ctx.proc_coefficient = weapon_data.proc_coefficient
	ctx.hit_position = global_position

	# Spawn projectile or hitscan logic
	# Para el prototipo: generamos ráfagas dirigidas
	# print("Disparo activo efectuado: ", final_dmg, " daño. Crítico: ", is_crit)

func _handle_passive_fire(delta: float) -> void:
	passive_timer -= delta
	if passive_timer <= 0.0:
		var atk_speed: float = player.stats.get_stat(&"attack_speed") if player else 1.0
		passive_timer = weapon_data.passive_interval / maxf(0.1, atk_speed)
		_fire_passive()

func _fire_passive() -> void:
	# Búsqueda autónoma de objetivos en radio
	# print("Disparo pasivo autónomo activado")
	pass
