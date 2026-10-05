class_name EnemyBase
extends CharacterBody2D

## Clase base para todos los enemigos comunes del juego.
## Provee soporte común de salud, mitigación, registro de daño acumulado,
## drops de EXP y consumibles de campo, colisión con el jugador y ciclo de vida.

signal enemy_died(enemy: CharacterBody2D)

@export var enemy_id: StringName = &"enemy_base"
@export var max_health: float = 30.0
@export var move_speed: float = 160.0
@export var contact_damage: float = 10.0
@export var exp_reward: float = 15.0
@export var credits_reward: int = 1
@export var contact_radius: float = 24.0
@export var contact_interval: float = 0.6

var current_health: float = 30.0
var player: Player = null
var is_dying: bool = false
var contact_cooldown: float = 0.0
var pool_source: Node = null

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var damage_accumulator: Node2D = get_node_or_null("DamageAccumulator")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

var exp_blob_scene: PackedScene = preload("res://scenes/combat/pickups/exp_blob.tscn")

static var _cached_outline_material: ShaderMaterial = null

static func _get_shared_outline_material() -> ShaderMaterial:
	if not _cached_outline_material:
		var shader := load("res://shaders/enemy_silhouette_outline.gdshader") as Shader
		if shader:
			_cached_outline_material = ShaderMaterial.new()
			_cached_outline_material.shader = shader
	return _cached_outline_material

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	scale = Vector2(2.0, 2.0)
	contact_radius *= 2.0
	current_health = max_health
	_acquire_player()
	_ready_custom()
	_apply_silhouette_outline()

func _ready_custom() -> void:
	pass

func reset_from_pool(pos: Vector2) -> void:
	global_position = pos
	current_health = max_health
	is_dying = false
	contact_cooldown = 0.0
	visible = true
	scale = Vector2(2.0, 2.0)
	modulate = Color.WHITE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if not is_in_group("enemies"):
		add_to_group("enemies")
	if "is_diving" in self:
		set("is_diving", false)
	_ready_custom()

func _apply_silhouette_outline() -> void:
	if not is_instance_valid(sprite):
		for child in get_children():
			if child is Sprite2D:
				sprite = child
				break
	if not is_instance_valid(sprite):
		return

	if sprite.material == null:
		var outline_mat: ShaderMaterial = _get_shared_outline_material()
		if outline_mat:
			sprite.material = outline_mat

func _acquire_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player

func _physics_process(delta: float) -> void:
	if is_dying or (get_tree() and get_tree().paused):
		return

	if contact_cooldown > 0.0:
		contact_cooldown -= delta

	_acquire_player()
	if not is_instance_valid(player):
		return

	_update_behavior(delta)
	_handle_player_contact()

## Método virtual para lógica de movimiento y ataque específica de cada arquetipo
func _update_behavior(delta: float) -> void:
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * move_speed
	rotation = dir.angle()
	move_and_slide()

func _handle_player_contact() -> void:
	if contact_cooldown <= 0.0 and is_instance_valid(player):
		if global_position.distance_squared_to(player.global_position) <= contact_radius * contact_radius:
			contact_cooldown = contact_interval
			_on_contact_with_player()

func _on_contact_with_player() -> void:
	if player.has_method("take_damage"):
		player.take_damage(contact_damage)

func take_damage(arg) -> void:
	if is_dying or (get_tree() and get_tree().paused):
		return

	var dmg: float = 0.0
	var is_crit: bool = false
	if arg is HitContext:
		dmg = arg.final_damage
		is_crit = arg.is_crit
	elif arg is float or arg is int:
		dmg = float(arg)

	current_health -= dmg

	if damage_accumulator and damage_accumulator.has_method("register_hit"):
		damage_accumulator.register_hit(dmg, is_crit)

	# Hit flash blanco
	modulate = Color(3.0, 3.0, 3.0, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.08)

	if current_health <= 0.0:
		_die()

func _die() -> void:
	if is_dying:
		return
	is_dying = true

	if damage_accumulator and damage_accumulator.has_method("clear_on_death"):
		damage_accumulator.clear_on_death()
	enemy_died.emit(self)
	var bus := get_node_or_null("/root/EventBus")
	if bus and bus.has_signal("enemy_killed"):
		bus.enemy_killed.emit(String(enemy_id))

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("explosion", randf_range(0.92, 1.08))

	if is_instance_valid(player):
		if player.inventory:
			player.inventory.process_kill_procs(self)
		var drop_creds: int = 0
		if is_in_group("elites") or is_in_group("bosses") or credits_reward >= 15:
			# Élites y jefes otorgan botín sustancial garantizado
			drop_creds = credits_reward
		elif credits_reward >= 3:
			# Mobs medianos: drop rate moderado (15%) de 1 crédito
			drop_creds = 1 if randf() < 0.15 else 0
		else:
			# Mobs comunes y enjambre: drop rate bajo (7%) para erradicar hiperinflación pasiva
			drop_creds = 1 if randf() < 0.07 else 0

		if drop_creds > 0:
			player.add_credits(drop_creds)

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

	# Posibilidad de soltar consumible de campo (Heal, Imán, Bomba)
	_roll_consumable_drop()

	_on_die_extra()

	# Efecto visual de desintegración
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
	tween.parallel().tween_property(self, "modulate", Color(1.0, 0.4, 0.1, 0.0), 0.15)
	if pool_source and is_instance_valid(pool_source) and pool_source.has_method("recycle_enemy"):
		tween.tween_callback(func(): pool_source.call("recycle_enemy", self))
	else:
		tween.tween_callback(queue_free)

func _on_die_extra() -> void:
	pass

func _roll_consumable_drop() -> void:
	var luck_val: float = 0.0
	if is_instance_valid(player) and player.stats:
		luck_val = player.stats.get_stat(&"luck")

	# Base 3.5% + 0.1% por cada punto de Suerte (luck)
	var drop_chance: float = clampf(0.035 + (luck_val * 0.001), 0.01, 0.40)
	if randf() > drop_chance:
		return

	var consumable_scene := preload("res://scenes/combat/pickups/field_consumable.tscn")
	var consumable := consumable_scene.instantiate() as Area2D
	if not consumable:
		return

	var consumable_script = preload("res://scenes/combat/pickups/field_consumable.gd")
	var roll := randf()
	var chosen_type: int = consumable_script.ConsumableType.HEAL
	if roll < 0.50:
		chosen_type = consumable_script.ConsumableType.HEAL
	elif roll < 0.75:
		chosen_type = consumable_script.ConsumableType.MAGNET
	elif roll < 0.90:
		chosen_type = consumable_script.ConsumableType.BOMB
	else:
		chosen_type = consumable_script.ConsumableType.QUANTUM_KEY

	var parent_node := get_parent() if is_inside_tree() else null
	if not parent_node and is_inside_tree():
		parent_node = get_tree().current_scene
	if parent_node:
		parent_node.add_child(consumable)
		consumable.setup(chosen_type, global_position)
