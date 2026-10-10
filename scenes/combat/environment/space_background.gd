class_name SpaceBackground
extends Node2D

## space_background.gd
## Controlador de fondo espacial multicapa estilo Deep-Fold.
## Soporta auto-scroll continuo (drift cósmico) tanto en combate como en menús,
## y en combate se suma al desplazamiento por movimiento de cámara/jugador.

const SpaceEnvironmentConfigScript = preload("res://core/resources/space_environment_config.gd")
@export var env_config: Resource = preload("res://data/environment/default_space_environment_config.tres")
@export var enable_auto_drift: bool = true
@export var drift_direction: Vector2 = Vector2(-0.894427, -0.447214)
@export var base_drift_speed: float = 16.0

@onready var parallax_nebula: Parallax2D = get_node_or_null("ParallaxNebula")
@onready var parallax_deep_stars: Parallax2D = get_node_or_null("ParallaxDeepStars")
@onready var parallax_mid_stars: Parallax2D = get_node_or_null("ParallaxMidStars")
@onready var parallax_near_dust: Parallax2D = get_node_or_null("ParallaxNearDust")

var _accum_drift: Vector2 = Vector2.ZERO


func _ready() -> void:
	if is_instance_valid(env_config):
		base_drift_speed = env_config.base_drift_speed
		drift_direction = env_config.drift_direction
		if parallax_nebula:
			parallax_nebula.scroll_scale = env_config.parallax_layer0_nebula_scroll
		if parallax_deep_stars:
			parallax_deep_stars.scroll_scale = env_config.parallax_layer1_deep_scroll
		if parallax_mid_stars:
			parallax_mid_stars.scroll_scale = env_config.parallax_layer2_mid_scroll
		if parallax_near_dust:
			parallax_near_dust.scroll_scale = env_config.parallax_layer3_near_scroll


func _process(delta: float) -> void:
	if not enable_auto_drift:
		return

	_accum_drift += drift_direction * (base_drift_speed * delta)

	var d0: float = env_config.parallax_layer0_drift_factor if is_instance_valid(env_config) else 0.20
	var d1: float = env_config.parallax_layer1_drift_factor if is_instance_valid(env_config) else 0.50
	var d2: float = env_config.parallax_layer2_drift_factor if is_instance_valid(env_config) else 1.00
	var d3: float = env_config.parallax_layer3_drift_factor if is_instance_valid(env_config) else 1.60

	# Desplazamiento diferenciado por capa
	if parallax_nebula:
		parallax_nebula.scroll_offset = _accum_drift * d0
	if parallax_deep_stars:
		parallax_deep_stars.scroll_offset = _accum_drift * d1
	if parallax_mid_stars:
		parallax_mid_stars.scroll_offset = _accum_drift * d2
	if parallax_near_dust:
		parallax_near_dust.scroll_offset = _accum_drift * d3
