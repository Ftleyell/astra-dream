class_name EnemyDrone
extends CharacterBody2D

@export var max_health: float = 60.0
@export var move_speed: float = 150.0
@export var contact_damage: float = 12.0
@export var exp_reward: float = 15.0
@export var credits_reward: int = 5

var current_health: float = 60.0
var player: Player = null
var is_dying: bool = false

@onready var visual: Polygon2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var damage_accumulator: Node2D = get_node_or_null("DamageAccumulator")

signal enemy_died(enemy: EnemyDrone)

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	if not player:
		player = get_tree().get_first_node_in_group("player") as Player

	# Carga de sprite de dron con fallback
	var drone_tex_path := "res://assets/enemies/enemy_drone.png"
	if ResourceLoader.exists(drone_tex_path):
		var tex := load(drone_tex_path) as Texture2D
		if tex:
			var spr := Sprite2D.new()
			spr.name = "DroneSprite"
			spr.texture = tex
			spr.scale = Vector2(0.4, 0.4)
			add_child(spr)
			move_child(spr, 0)
			if visual:
				visual.visible = false

var contact_cooldown: float = 0.0

func _physics_process(delta: float) -> void:
	if is_dying:
		return

	if contact_cooldown > 0.0:
		contact_cooldown -= delta

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if not player:
			return

	# Persecución continua hacia el jugador
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * move_speed
	rotation = dir.angle()
	move_and_slide()

	# Daño por contacto con el jugador
	if contact_cooldown <= 0.0 and global_position.distance_squared_to(player.global_position) <= 24.0 * 24.0:
		contact_cooldown = 0.6
		if player.has_method("take_damage"):
			player.take_damage(contact_damage)

func take_damage(ctx: HitContext) -> void:
	if is_dying:
		return

	current_health -= ctx.final_damage

	if damage_accumulator and damage_accumulator.has_method("register_hit"):
		damage_accumulator.register_hit(ctx.final_damage, ctx.is_crit)

	# Hit flash blanco
	modulate = Color(3.0, 3.0, 3.0, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.08)

	if current_health <= 0.0:
		_die()

var exp_blob_scene: PackedScene = preload("res://scenes/combat/pickups/exp_blob.tscn")

func _die() -> void:
	is_dying = true
	if damage_accumulator and damage_accumulator.has_method("clear_on_death"):
		damage_accumulator.clear_on_death()
	enemy_died.emit(self)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("explosion", randf_range(0.92, 1.08))

	if is_instance_valid(player):
		player.add_credits(credits_reward)

	# Soltar gema/blob de EXP en el campo
	if exp_blob_scene:
		var blob := exp_blob_scene.instantiate() as Node2D
		if blob.has_method("setup"):
			blob.setup(exp_reward, global_position)
		var parent_node := get_parent() if is_inside_tree() else null
		if not parent_node and is_inside_tree():
			parent_node = get_tree().current_scene
		if parent_node:
			parent_node.add_child(blob)

	# Efecto visual de desintegración/explosión
	collision_shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.15)
	tween.parallel().tween_property(self, "modulate", Color(1.0, 0.4, 0.1, 0.0), 0.15)
	tween.tween_callback(queue_free)
