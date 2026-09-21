class_name BiomassOrb
extends Node2D

## BiomassOrb.gd
## Orbe orgánico flotante de BioMasa obtenido al destruir segmentos de planetas.
## Atraído magnéticamente hacia el jugador y persistente entre partidas.

@export var biomass_value: int = 1

var player: Player = null
var is_collected: bool = false
var velocity: Vector2 = Vector2.ZERO
var magnet_speed: float = 0.0

const PICKUP_RADIUS_SQ: float = 180.0 * 180.0
const COLLECT_RADIUS_SQ: float = 24.0 * 24.0

@onready var visual_core: Polygon2D = get_node_or_null("VisualCore")
@onready var visual_aura: Polygon2D = get_node_or_null("VisualAura")


func _ready() -> void:
	add_to_group("biomass_orbs")
	# Pequeño impulso inicial de eyección radial
	var angle := randf() * TAU
	velocity = Vector2(cos(angle), sin(angle)) * randf_range(40.0, 110.0)


func setup(p_amount: int, p_pos: Vector2) -> void:
	biomass_value = max(1, p_amount)
	global_position = p_pos


func _process(delta: float) -> void:
	if is_collected:
		return

	# Pulso orgánico bioluminiscente
	var t := Time.get_ticks_msec() * 0.005
	var s: float = 1.0 + sin(t) * 0.18
	if visual_core:
		visual_core.scale = Vector2(s, s)
	if visual_aura:
		visual_aura.rotation += delta * 1.8


func _physics_process(delta: float) -> void:
	if is_collected:
		return

	# Desaceleración del impulso inicial
	if velocity.length_squared() > 1.0:
		velocity = velocity.move_toward(Vector2.ZERO, 140.0 * delta)
		global_position += velocity * delta

	# Atracción magnética hacia el jugador
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if not player:
			return

	var d_sq := global_position.distance_squared_to(player.global_position)
	if d_sq <= PICKUP_RADIUS_SQ:
		magnet_speed = move_toward(magnet_speed, 720.0, 1400.0 * delta)
		var dir := (player.global_position - global_position).normalized()
		global_position += dir * magnet_speed * delta

		if d_sq <= COLLECT_RADIUS_SQ:
			_collect()


func _collect() -> void:
	if is_collected:
		return
	is_collected = true

	if is_instance_valid(player) and player.has_method("add_biomass"):
		player.add_biomass(biomass_value)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("exp_pickup")

	# Animación de absorción
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)
