class_name NovaSpin360Laser
extends Node2D

## NovaSpin360Laser.gd
## Nodo temporal instanciado por el Omega Spin de Nova.
## Dispara RAY_COUNT rayos láser en ángulos equidistantes (cobertura 360°)
## con un hit_registry compartido para garantizar máx 1 hit por enemigo.
## Se auto-destruye tras el disparo.

const RAY_COUNT: int = 24
## Multiplicador de daño del Omega Spin: menor que el láser normal (2.2×)
## para compensar el gran AoE de 360°.
const DAMAGE_MULT: float = 1.2

var laser_scene: PackedScene = preload("res://scenes/combat/weapons/screen_laser_beam.tscn")

func setup(p_origin: Vector2, p_ctx: HitContext) -> void:
	global_position = p_origin
	_fire_360(p_ctx)

func _fire_360(base_ctx: HitContext) -> void:
	if not base_ctx:
		queue_free()
		return

	var spawn_parent: Node = get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
	if not spawn_parent:
		queue_free()
		return

	# Contexto derivado con multiplicador de daño reducido para el AoE 360°
	var ctx := base_ctx.fork_child_hit(
		base_ctx.final_damage * DAMAGE_MULT,
		0.35,
		&"nova_omega_spin"
	)

	# Registry compartido entre todos los rayos: garantiza máx 1 hit por enemigo
	var hit_registry: Dictionary = {}

	for i in range(RAY_COUNT):
		var angle := TAU * float(i) / float(RAY_COUNT)
		var dir := Vector2.from_angle(angle)
		var laser: ScreenLaserBeam = laser_scene.instantiate() as ScreenLaserBeam
		if not laser:
			continue
		laser.hit_registry = hit_registry
		laser.setup(global_position, dir, ctx)
		spawn_parent.add_child(laser)

	queue_free()
