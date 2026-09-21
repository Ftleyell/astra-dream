class_name FieldConsumable
extends Area2D

## Consumible táctico de campo (Heal, Imán, Bomba) que cae de enemigos al morir.
## Permanece estático en el suelo durante 45s (con parpadeo en los últimos 8s)
## requiriendo que el jugador navegue activamente hasta él para recogerlo.

enum ConsumableType {
	HEAL,
	MAGNET,
	BOMB
}

@export var type: ConsumableType = ConsumableType.HEAL

const MAX_LIFETIME: float = 45.0
const BLINK_START: float = 37.0
const PICKUP_RADIUS_SQ: float = 28.0 * 28.0

var current_lifetime: float = 0.0
var is_collected: bool = false
var player_ref: Player = null

@onready var visual_root: Node2D = $VisualRoot
@onready var aura_ring: Node2D = $VisualRoot/AuraRing
@onready var icon_sprite: Sprite2D = $VisualRoot/IconSprite
@onready var glow_polygon: Polygon2D = $VisualRoot/GlowPolygon

func _ready() -> void:
	add_to_group("field_consumables")
	_find_player()
	_apply_visuals()

func setup(p_type: ConsumableType, spawn_pos: Vector2) -> void:
	type = p_type
	global_position = spawn_pos
	_apply_visuals()

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_ref = players[0] as Player

func _apply_visuals() -> void:
	if not is_inside_tree() or not icon_sprite:
		return

	match type:
		ConsumableType.HEAL:
			glow_polygon.color = Color(0.12, 0.95, 0.5, 0.35)
			icon_sprite.texture = load("res://assets/icons/items/icon_heart.svg")
			icon_sprite.modulate = Color(0.2, 1.0, 0.6)
			icon_sprite.scale = Vector2(0.6, 0.6)
		ConsumableType.MAGNET:
			glow_polygon.color = Color(0.05, 0.8, 1.0, 0.35)
			icon_sprite.texture = load("res://assets/icons/items/icon_magnet.svg")
			icon_sprite.modulate = Color(0.2, 0.9, 1.0)
			icon_sprite.scale = Vector2(0.6, 0.6)
		ConsumableType.BOMB:
			glow_polygon.color = Color(1.0, 0.35, 0.1, 0.35)
			icon_sprite.texture = load("res://assets/icons/icon_bomb.png")
			icon_sprite.modulate = Color(1.0, 0.55, 0.2)
			icon_sprite.scale = Vector2(0.5, 0.5)

func _physics_process(delta: float) -> void:
	if is_collected:
		return

	current_lifetime += delta

	# Animación de flotación suave (bobbing vertical)
	if visual_root:
		visual_root.position.y = sin(current_lifetime * 3.8) * 3.5
	if aura_ring:
		aura_ring.rotation += delta * 1.8

	# Parpadeo de advertencia en los últimos 8 segundos
	if current_lifetime >= BLINK_START:
		var blink_factor := (current_lifetime - BLINK_START) / (MAX_LIFETIME - BLINK_START)
		var freq := 8.0 + blink_factor * 16.0
		modulate.a = 0.25 + 0.75 * abs(sin(current_lifetime * freq))

	# Despawn al agotar el tiempo
	if current_lifetime >= MAX_LIFETIME:
		queue_free()
		return

	# Chequeo de colisión con jugador
	if not is_instance_valid(player_ref):
		_find_player()
	if is_instance_valid(player_ref):
		var dist_sq := global_position.distance_squared_to(player_ref.global_position)
		if dist_sq <= PICKUP_RADIUS_SQ:
			collect(player_ref)

func collect(player: Player) -> void:
	if is_collected or not is_instance_valid(player):
		return
	is_collected = true

	var parent_node := get_parent()
	if not parent_node:
		parent_node = get_tree().current_scene

	var audio_mgr := get_node_or_null("/root/AudioManager")
	var floating_text_script = preload("res://scenes/ui/floating_text.gd")

	match type:
		ConsumableType.HEAL:
			player.heal(25.0)
			if audio_mgr and audio_mgr.has_method("play_sfx"):
				audio_mgr.play_sfx("heal")
			floating_text_script.spawn(parent_node, global_position, "+25 HP", Color(0.2, 1.0, 0.5))

		ConsumableType.MAGNET:
			ExpBlob.trigger_global_magnet(get_tree())
			if audio_mgr and audio_mgr.has_method("play_sfx"):
				audio_mgr.play_sfx("magnet")
			floating_text_script.spawn(parent_node, global_position, "¡IMÁN GLOBAL!", Color(0.1, 0.9, 1.0))

		ConsumableType.BOMB:
			var stored := player.add_bombs(1)
			if stored:
				if audio_mgr and audio_mgr.has_method("play_sfx"):
					audio_mgr.play_sfx("bomb", 1.35)
				floating_text_script.spawn(parent_node, global_position, "+1 BOMBA", Color(1.0, 0.65, 0.15))
			else:
				# Ya estaba en 5: detonación inmediata de pantalla
				var camera := get_viewport().get_camera_2d()
				if camera and camera.has_method("add_trauma"):
					camera.add_trauma(0.6)
				floating_text_script.spawn(parent_node, global_position, "¡PANTALLA LIMPIA!", Color(1.0, 0.3, 0.2))

	# Animación de absorción rápida
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.12).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)
