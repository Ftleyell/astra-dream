class_name RivalWeaponPickup
extends Node2D

## Cápsula de Armamento de Piloto Rival
## Aparece cuando una piloto rival es derrotada en combate dogfight.
## Al ser recolectada, desbloquea o sube de nivel su arma insignia en el arsenal del jugador.

signal collected(weapon: WeaponData)

@export var pulse_speed: float = 4.5
@export var pickup_radius: float = 260.0
@export var collect_radius: float = 34.0

var weapon_data: WeaponData = null
var pilot_name: String = ""
var player: Player = null
var is_collected: bool = false
var velocity: Vector2 = Vector2.ZERO
var magnet_speed: float = 0.0

@onready var visual_aura: Polygon2D = get_node_or_null("VisualAura")
@onready var visual_ring: Line2D = get_node_or_null("VisualRing")
@onready var visual_core: Polygon2D = get_node_or_null("VisualCore")
@onready var weapon_icon: Sprite2D = get_node_or_null("WeaponIcon")
@onready var label_name: Label = get_node_or_null("LabelName")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("pickups")
	add_to_group("rival_weapon_pickups")

	# Impulso inicial suave
	var angle := randf_range(-PI, PI)
	velocity = Vector2(cos(angle), sin(angle)) * randf_range(50.0, 110.0)

	_update_appearance()

func setup(p_pos: Vector2, p_weapon: WeaponData, p_pilot_name: String = "") -> void:
	global_position = p_pos
	weapon_data = p_weapon
	pilot_name = p_pilot_name
	_update_appearance()

func _update_appearance() -> void:
	if not is_inside_tree() or weapon_data == null:
		return

	if label_name:
		var w_name: String = weapon_data.name if "name" in weapon_data and not weapon_data.name.is_empty() else str(weapon_data.weapon_id)
		label_name.text = "CÁPSULA: %s" % w_name.to_upper()
		label_name.modulate = Color(1.0, 0.85, 0.2, 0.95)

	if weapon_icon and "icon" in weapon_data and weapon_data.icon:
		weapon_icon.texture = weapon_data.icon
		weapon_icon.scale = Vector2(0.55, 0.55)

func _process(delta: float) -> void:
	if is_collected:
		return

	var t := Time.get_ticks_msec() * 0.001 * pulse_speed
	var s := 1.0 + sin(t) * 0.22

	if visual_core:
		visual_core.scale = Vector2(s, s)
	if visual_ring:
		visual_ring.rotation += delta * 2.8
	if visual_aura:
		visual_aura.rotation -= delta * 1.5
		visual_aura.scale = Vector2(1.0 + cos(t * 0.8) * 0.15, 1.0 + cos(t * 0.8) * 0.15)

func _physics_process(delta: float) -> void:
	if is_collected:
		return

	# Desaceleración del impulso
	if velocity.length_squared() > 1.0:
		velocity = velocity.move_toward(Vector2.ZERO, 90.0 * delta)
		global_position += velocity * delta

	# Magnetismo hacia el jugador
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if not player:
			return

	var effective_radius := pickup_radius
	if is_instance_valid(player) and player.stats:
		effective_radius = maxf(pickup_radius, player.stats.get_stat(&"pickup_radius"))

	var dist := global_position.distance_to(player.global_position)
	if dist <= effective_radius:
		magnet_speed = move_toward(magnet_speed, 920.0, 1800.0 * delta)
		var dir := (player.global_position - global_position).normalized()
		global_position += dir * magnet_speed * delta

		if dist <= collect_radius:
			_collect()

func _collect() -> void:
	if is_collected:
		return
	is_collected = true

	if is_instance_valid(player) and weapon_data:
		var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
		if w_ctrl:
			w_ctrl.add_weapon(weapon_data)

		# Sonido de recolección
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("menu_open", 1.2, 1.1)

		# Feedback flotante
		_spawn_pickup_floater()

	collected.emit(weapon_data)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)

func _spawn_pickup_floater() -> void:
	var label := Label.new()
	var w_name: String = weapon_data.name if "name" in weapon_data and not weapon_data.name.is_empty() else str(weapon_data.weapon_id)
	label.text = "¡ARMA DESBLOQUEADA: %s!" % w_name.to_upper()
	label.modulate = Color(0.1, 1.0, 0.6, 1.0) # Verde terminal brillante
	label.top_level = true
	label.global_position = global_position + Vector2(-90, -40)
	label.add_theme_font_size_override("font_size", 14)
	get_parent().add_child(label)

	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 65.0, 1.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.chain().tween_callback(label.queue_free)
