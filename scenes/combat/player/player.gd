class_name Player
extends CharacterBody2D

@export var character_data: CharacterData
@export var bullet_server: BulletServer

var stats: CharacterStats = CharacterStats.new()
var inventory: InventoryComponent = InventoryComponent.new()

# Dash state
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
const DASH_DURATION: float = 0.25
const DASH_COOLDOWN: float = 1.0
var dash_direction: Vector2 = Vector2.RIGHT

# Bombs & Economy
var bomb_count: int = 2
var run_credits: int = 120

# EXP & Leveling
var current_level: int = 1
var current_exp: float = 0.0
var exp_to_next: float = 40.0

# Core Hitbox Node
@onready var hitbox_core: Node2D = $HitboxCore
@onready var weapon_controller: Node2D = $WeaponController

signal health_changed(current: float, max_val: float)
signal bomb_used(remaining: int)
signal credits_changed(amount: int)
signal exp_changed(current: float, max_val: float, level: int)
signal level_up_requested(level: int)
signal player_died()

var current_health: float = 100.0

func _ready() -> void:
	if not character_data:
		character_data = CharacterData.new()
	stats.initialize(character_data)
	current_health = stats.get_stat(&"max_health")

	inventory.character_stats = stats
	add_child(inventory)

	if bullet_server:
		bullet_server.player_hit.connect(_on_bullet_hit)
		bullet_server.player_grazed.connect(_on_bullet_grazed)

func _physics_process(delta: float) -> void:
	_handle_dash(delta)
	_handle_movement(delta)
	_handle_actions()

	if bullet_server:
		bullet_server.player_pos = global_position
		bullet_server.player_invulnerable = is_dashing

func _handle_movement(delta: float) -> void:
	if is_dashing:
		velocity = dash_direction * (stats.get_stat(&"move_speed") * 2.5)
		move_and_slide()
		return

	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	var speed: float = stats.get_stat(&"move_speed")
	velocity = velocity.move_toward(input_vector * speed, speed * 8.0 * delta)
	move_and_slide()

func _handle_dash(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false

	if Input.is_action_just_pressed("dash") and not is_dashing and dash_cooldown_timer <= 0.0:
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		dash_direction = velocity.normalized() if velocity.length_squared() > 0.1 else (get_global_mouse_position() - global_position).normalized()

func _handle_actions() -> void:
	if Input.is_action_just_pressed("bomb") and bomb_count > 0:
		bomb_count -= 1
		bomb_used.emit(bomb_count)
		if bullet_server:
			bullet_server.bomb_clear_all()

func add_credits(amount: int) -> void:
	run_credits += amount
	credits_changed.emit(run_credits)

func add_exp(amount: float) -> void:
	current_exp += amount
	if current_exp >= exp_to_next:
		current_exp -= exp_to_next
		current_level += 1
		exp_to_next *= 1.35
		level_up_requested.emit(current_level)
	exp_changed.emit(current_exp, exp_to_next, current_level)

func _on_bullet_hit() -> void:
	if is_dashing:
		return
	current_health -= 10.0
	health_changed.emit(current_health, stats.get_stat(&"max_health"))
	if current_health <= 0.0:
		player_died.emit()

func _on_bullet_grazed(bullet_pos: Vector2) -> void:
	add_exp(2.0) # Cada roce con balas suma experiencia
