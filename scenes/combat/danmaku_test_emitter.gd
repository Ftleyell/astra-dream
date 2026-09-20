class_name DanmakuTestEmitter
extends Node2D

@export var bullet_server: BulletServer
@export var player: Player

var tick: int = 0
var radial_timer: float = 0.0
var spiral_timer: float = 0.0

func _process(delta: float) -> void:
	if not bullet_server:
		return

	radial_timer += delta
	spiral_timer += delta

	# Disparo de espiral dorada continua (Fermat Spiral)
	if spiral_timer >= 0.03: # Cada 30ms (~33 balas/segundo por emisor)
		spiral_timer = 0.0
		tick += 1
		bullet_server.fire_fermat_spiral_tick(global_position, tick, 180.0, 0.0, 1)

	# Disparo de anillo radial periódico
	if radial_timer >= 1.5:
		radial_timer = 0.0
		bullet_server.fire_radial_ring(global_position, 24, 140.0, float(tick) * 0.1, 0)
		if player:
			bullet_server.fire_aimed_spread(global_position, player.global_position, 5, 45.0, 220.0, 2)
