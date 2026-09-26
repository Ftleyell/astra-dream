class_name ResonanceContainmentNode
extends CharacterBody2D

## Nodo de Contención de Resonancia:
## Estructura estática de alta durabilidad (150 HP) que forma un cerco o arena temporal.
## Emite daño por choque eléctrico por contacto y se conecta visualmente con sus nodos adyacentes.
## Dura 25 segundos antes de colapsar automáticamente si no es destruido antes.

signal node_destroyed(node: ResonanceContainmentNode)

@export var max_health: float = 150.0
@export var contact_damage: float = 18.0
@export var contact_radius: float = 24.0
@export var lifetime: float = 25.0
@export var exp_reward: float = 40.0

var current_health: float = 150.0
var is_dying: bool = false
var neighbor_node: ResonanceContainmentNode = null
var tether_line: Line2D = null
var player: Player = null
var contact_cooldown: float = 0.0

@onready var damage_accumulator: Node2D = get_node_or_null("DamageAccumulator")
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_core: Polygon2D = get_node_or_null("VisualCore")

var exp_blob_scene: PackedScene = preload("res://scenes/combat/pickups/exp_blob.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	current_health = max_health
	_acquire_player()
	
	tether_line = Line2D.new()
	tether_line.width = 3.0
	tether_line.default_color = Color(0.1, 0.8, 1.0, 0.6)
	tether_line.top_level = true
	add_child(tether_line)

func _acquire_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player

func set_neighbor(other: ResonanceContainmentNode) -> void:
	neighbor_node = other

func _physics_process(delta: float) -> void:
	if is_dying:
		return

	lifetime -= delta
	if lifetime <= 0.0:
		_expire()
		return

	if contact_cooldown > 0.0:
		contact_cooldown -= delta

	_acquire_player()
	if is_instance_valid(player) and contact_cooldown <= 0.0:
		if global_position.distance_squared_to(player.global_position) <= contact_radius * contact_radius:
			contact_cooldown = 0.5
			if player.has_method("take_damage"):
				player.take_damage(contact_damage)

	_update_tether()
	_update_pulsing(delta)

func _update_tether() -> void:
	if not tether_line:
		return
	if is_instance_valid(neighbor_node) and not neighbor_node.is_dying:
		tether_line.visible = true
		tether_line.clear_points()
		tether_line.add_point(global_position)
		tether_line.add_point(neighbor_node.global_position)
		var alpha: float = 0.4 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
		tether_line.default_color = Color(0.2, 0.9, 1.0, alpha)
	else:
		tether_line.visible = false

func _update_pulsing(_delta: float) -> void:
	if visual_core:
		var s := 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.01)
		visual_core.scale = Vector2(s, s)

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

	current_health -= dmg

	if damage_accumulator and damage_accumulator.has_method("register_hit"):
		damage_accumulator.register_hit(dmg, is_crit)

	# Hit flash
	modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.08)

	if current_health <= 0.0:
		_die(true)

func _expire() -> void:
	_die(false)

func _die(drop_rewards: bool = true) -> void:
	if is_dying:
		return
	is_dying = true

	if damage_accumulator and damage_accumulator.has_method("clear_on_death"):
		damage_accumulator.clear_on_death()

	node_destroyed.emit(self)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("explosion", 1.2)

	if tether_line:
		tether_line.visible = false

	if drop_rewards and exp_blob_scene:
		var blob := exp_blob_scene.instantiate() as Node2D
		if blob.has_method("setup"):
			blob.setup(exp_reward, global_position)
		var parent_node := get_parent() if is_inside_tree() else null
		if parent_node:
			parent_node.add_child(blob)

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.12)
	tween.parallel().tween_property(self, "modulate", Color(0.1, 0.8, 1.0, 0.0), 0.15)
	tween.tween_callback(queue_free)
