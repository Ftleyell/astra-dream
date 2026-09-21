class_name EnemyKamikaze
extends "res://scenes/combat/enemies/enemy_base.gd"

## Kamikaze de asalto: nave ágil que entra en sobrecarga y embiste a gran velocidad
## cuando se acerca al jugador, generando una micro-explosión al detonar.

const DIVE_DISTANCE: float = 260.0
const DIVE_SPEED: float = 360.0

var is_diving: bool = false
var dive_dir: Vector2 = Vector2.ZERO

func _init() -> void:
	enemy_id = &"enemy_kamikaze"
	max_health = 20.0
	move_speed = 220.0
	contact_damage = 18.0
	exp_reward = 20.0
	credits_reward = 2
	contact_radius = 22.0

func _ready_custom() -> void:
	var tex_path := "res://assets/enemies/enemy_kamikaze.png"
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex:
			var spr := Sprite2D.new()
			spr.name = "KamikazeSprite"
			spr.texture = tex
			spr.scale = Vector2(0.45, 0.45)
			add_child(spr)
			move_child(spr, 0)
			var visual := get_node_or_null("Visual")
			if visual:
				visual.visible = false

func _update_behavior(delta: float) -> void:
	var dist_to_player := global_position.distance_to(player.global_position)

	# Transición a modo embestida / turbo
	if not is_diving and dist_to_player <= DIVE_DISTANCE:
		is_diving = true
		dive_dir = (player.global_position - global_position).normalized()
		# Feedback visual de sobrecarga
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(1.8, 0.4, 0.2, 1.0), 0.1)

	if is_diving:
		# Embestida a alta velocidad con leve ajuste direccional
		var target_dir := (player.global_position - global_position).normalized()
		dive_dir = dive_dir.lerp(target_dir, delta * 3.5).normalized()
		velocity = dive_dir * DIVE_SPEED
		rotation = dive_dir.angle()
	else:
		# Persecución veloz estándar
		var dir := (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		rotation = dir.angle()

	move_and_slide()

func _on_contact_with_player() -> void:
	super._on_contact_with_player()
	# Al impactar al jugador se auto-destruye detonando su reactor
	_die()

func _on_die_extra() -> void:
	# Micro-explosión y sacudida si estaba en rango de detonación
	if is_diving or (is_instance_valid(player) and global_position.distance_to(player.global_position) < 80.0):
		var cam := get_viewport().get_camera_2d()
		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(0.25)
