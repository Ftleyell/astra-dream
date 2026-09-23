class_name ArcanaOrb
extends Node2D

## ArcanaOrb.gd
## Orbe de invocación de Arcana liberado al destruir un Monolito Arcano.
## Pulsación místico-tecnológica (cian/magenta) y magnetismo hacia el jugador.
## Al recogerse, desencadena la invocación / selección de Arcanas (Fase 2).

signal collected(orb: ArcanaOrb)

@export var pulse_speed: float = 4.0
@export var pickup_radius: float = 240.0
@export var collect_radius: float = 28.0

var player: Node2D = null
var is_collected: bool = false
var velocity: Vector2 = Vector2.ZERO
var magnet_speed: float = 0.0

@onready var visual_core: Polygon2D = get_node_or_null("VisualCore")
@onready var visual_ring: Line2D = get_node_or_null("VisualRing")
@onready var visual_aura: Polygon2D = get_node_or_null("VisualAura")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("pickups")
	add_to_group("arcana_orbs")

	# Impulso inicial suave hacia arriba/afuera
	var angle := randf_range(-PI * 0.8, -PI * 0.2)
	velocity = Vector2(cos(angle), sin(angle)) * randf_range(60.0, 120.0)


func setup(p_pos: Vector2) -> void:
	global_position = p_pos


func _process(delta: float) -> void:
	if is_collected:
		return

	var t := Time.get_ticks_msec() * 0.001 * pulse_speed
	var s := 1.0 + sin(t) * 0.22

	if visual_core:
		visual_core.scale = Vector2(s, s)
		# Alternancia cromática cian y magenta
		var blend := (sin(t * 1.5) + 1.0) * 0.5
		visual_core.color = Color(0.0, 0.95, 1.0).lerp(Color(1.0, 0.1, 0.6), blend)

	if visual_ring:
		visual_ring.rotation += delta * 2.5
	if visual_aura:
		visual_aura.rotation -= delta * 1.8


func _physics_process(delta: float) -> void:
	if is_collected:
		return

	# Desaceleración del impulso inicial
	if velocity.length_squared() > 1.0:
		velocity = velocity.move_toward(Vector2.ZERO, 100.0 * delta)
		global_position += velocity * delta

	# Magnetismo hacia el jugador
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		if not player:
			return

	var effective_radius := pickup_radius
	if is_instance_valid(player) and "stats" in player and player.stats:
		effective_radius = maxf(pickup_radius, player.stats.get_stat(&"pickup_radius"))

	var d_sq := global_position.distance_squared_to(player.global_position)
	if d_sq <= effective_radius * effective_radius:
		magnet_speed = move_toward(magnet_speed, 850.0, 1600.0 * delta)
		var dir := (player.global_position - global_position).normalized()
		global_position += dir * magnet_speed * delta

		if d_sq <= collect_radius * collect_radius:
			_collect()


func _collect() -> void:
	if is_collected:
		return
	is_collected = true
	collected.emit(self)

	# Notificación al EventBus para el modal de selección de Arcanas (Fase 2)
	var bus := get_node_or_null("/root/EventBus")
	if bus and bus.has_signal("arcana_orb_collected"):
		bus.arcana_orb_collected.emit(self)

	# Audio
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("level_up", 1.2)

	# Animación de implosión y destello
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.2, 2.2), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)
