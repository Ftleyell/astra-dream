class_name SpaceBackground
extends Node2D

## space_background.gd
## Controlador de fondo espacial multicapa estilo Deep-Fold.
## Soporta auto-scroll continuo (drift cósmico) tanto en combate como en menús,
## y en combate se suma al desplazamiento por movimiento de cámara/jugador.

@export var enable_auto_drift: bool = true
@export var drift_direction: Vector2 = Vector2(-1.0, -0.5).normalized()
@export var base_drift_speed: float = 16.0

@onready var parallax_nebula: Parallax2D = get_node_or_null("ParallaxNebula")
@onready var parallax_deep_stars: Parallax2D = get_node_or_null("ParallaxDeepStars")
@onready var parallax_mid_stars: Parallax2D = get_node_or_null("ParallaxMidStars")
@onready var parallax_near_dust: Parallax2D = get_node_or_null("ParallaxNearDust")

var _accum_drift: Vector2 = Vector2.ZERO


func _process(delta: float) -> void:
	if not enable_auto_drift:
		return

	_accum_drift += drift_direction * (base_drift_speed * delta)

	# Desplazamiento diferenciado por capa
	if parallax_nebula:
		parallax_nebula.scroll_offset = _accum_drift * 0.25
	if parallax_deep_stars:
		parallax_deep_stars.scroll_offset = _accum_drift * 0.6
	if parallax_mid_stars:
		parallax_mid_stars.scroll_offset = _accum_drift * 1.0
	if parallax_near_dust:
		parallax_near_dust.scroll_offset = _accum_drift * 1.45
