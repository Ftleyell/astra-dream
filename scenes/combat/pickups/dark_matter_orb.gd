class_name DarkMatterOrb
extends Node2D

## DarkMatterOrb.gd
## Orbe de Materia Oscura liberado por Bosses y Núcleos Planetarios.
## Divisa del meta-juego para desbloquear y subir de nivel los trofeos de maestría.

signal collected(amount: int)

@export var value: int = 5
@export var pickup_radius: float = 260.0
@export var collect_radius: float = 30.0

var player: Node2D = null
var is_collected: bool = false
var velocity: Vector2 = Vector2.ZERO
var magnet_speed: float = 0.0

@onready var visual_core: Polygon2D = get_node_or_null("VisualCore")
@onready var visual_aura: Polygon2D = get_node_or_null("VisualAura")


func _ready() -> void:
	add_to_group("dark_matter_orbs")
	add_to_group("pickups")

	var angle := randf() * TAU
	velocity = Vector2(cos(angle), sin(angle)) * randf_range(50.0, 130.0)


func setup(p_amount: int, p_pos: Vector2) -> void:
	value = max(1, p_amount)
	global_position = p_pos


func _process(delta: float) -> void:
	if is_collected:
		return

	var t := Time.get_ticks_msec() * 0.004
	var s: float = 1.0 + sin(t * 1.8) * 0.22
	if visual_core:
		visual_core.scale = Vector2(s, s)
		visual_core.rotation += delta * 2.0
	if visual_aura:
		visual_aura.rotation -= delta * 1.5


func _physics_process(delta: float) -> void:
	if is_collected:
		return

	if velocity.length_squared() > 1.0:
		velocity = velocity.move_toward(Vector2.ZERO, 150.0 * delta)
		global_position += velocity * delta

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if not player:
			return

	var effective_radius := pickup_radius
	if is_instance_valid(player) and "stats" in player and player.stats:
		effective_radius = maxf(pickup_radius, player.stats.get_stat(&"pickup_radius"))

	var d_sq := global_position.distance_squared_to(player.global_position)
	if d_sq <= effective_radius * effective_radius:
		magnet_speed = move_toward(magnet_speed, 900.0, 1600.0 * delta)
		var dir := (player.global_position - global_position).normalized()
		global_position += dir * magnet_speed * delta

		if d_sq <= collect_radius * collect_radius:
			_collect()


func _collect() -> void:
	if is_collected:
		return
	is_collected = true
	collected.emit(value)

	if is_instance_valid(player) and player.has_method("add_dark_matter"):
		player.add_dark_matter(value)
	else:
		SaveManager.add_dark_matter(value)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("level_up", 1.4)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)
