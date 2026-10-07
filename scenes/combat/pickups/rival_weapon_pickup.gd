class_name RivalWeaponPickup
extends Node2D

const WeaponSwapModalClass = preload("res://scenes/ui/modals/weapon_swap_modal.gd")

## Cofre de Armamento de Piloto Rival
## Aparece cuando una piloto rival es derrotada en combate dogfight.
## Se presenta como un cofre dorado interactivo idéntico al de la máquina tragamonedas.
## Al ser recolectado, entrega y desbloquea el arma insignia de la piloto rival.

signal collected(weapon: WeaponData)

@export var pulse_speed: float = 4.0
@export var pickup_radius: float = 240.0
@export var collect_radius: float = 45.0

var weapon_data: WeaponData = null
var pilot_name: String = ""
var player: Player = null
var is_collected: bool = false
var velocity: Vector2 = Vector2.ZERO
var magnet_speed: float = 0.0

var chest_sprite: Sprite2D = null

@onready var visual_aura: Polygon2D = get_node_or_null("VisualAura")
@onready var visual_ring: Line2D = get_node_or_null("VisualRing")
@onready var visual_core: Polygon2D = get_node_or_null("VisualCore")
@onready var weapon_icon: Sprite2D = get_node_or_null("WeaponIcon")
@onready var label_name: Label = get_node_or_null("LabelName")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("pickups")
	add_to_group("rival_weapon_pickups")
	scale = Vector2(1.2, 1.2)

	_setup_chest_visual()

	# Impulso inicial suave
	var angle := randf_range(-PI, PI)
	velocity = Vector2(cos(angle), sin(angle)) * randf_range(50.0, 100.0)

	_update_appearance()

func _setup_chest_visual() -> void:
	if not chest_sprite:
		chest_sprite = Sprite2D.new()
		chest_sprite.name = "ChestSprite"
		var tex := load("res://assets/sprites/interactables/slot_machine_chest.png") as Texture2D
		if tex:
			chest_sprite.texture = tex
		chest_sprite.scale = Vector2(0.18, 0.18)
		add_child(chest_sprite)
		move_child(chest_sprite, 0)

	if visual_core:
		visual_core.visible = false
	if visual_aura:
		visual_aura.color = Color(1.0, 0.84, 0.0, 0.3)
	if visual_ring:
		visual_ring.default_color = Color(1.0, 0.85, 0.2, 0.7)

func setup(p_pos: Vector2, p_weapon: WeaponData, p_pilot_name: String = "") -> void:
	global_position = p_pos
	weapon_data = p_weapon
	pilot_name = p_pilot_name
	_update_appearance()

func _update_appearance() -> void:
	if not is_inside_tree() or weapon_data == null:
		return

	if label_name:
		var p_title: String = pilot_name.to_upper() if not pilot_name.is_empty() else "RIVAL"
		label_name.text = "🎁 COFRE DE %s" % p_title
		label_name.modulate = Color(1.0, 0.9, 0.3, 1.0)
		label_name.position = Vector2(-120, -44)
		label_name.custom_minimum_size = Vector2(240, 20)

	if weapon_icon:
		weapon_icon.visible = false

func _process(delta: float) -> void:
	if is_collected:
		return

	var t := Time.get_ticks_msec() * 0.001 * pulse_speed
	var pulse := (0.95 + 0.05 * sin(t * 1.5)) * 0.18
	if chest_sprite:
		chest_sprite.scale = Vector2(pulse, pulse)

	if visual_ring:
		visual_ring.rotation += delta * 2.0
	if visual_aura:
		visual_aura.rotation -= delta * 1.2

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

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player

	var reward_modal: SlotMachineRewardModal = null
	var tree := get_tree()
	if tree:
		reward_modal = tree.get_first_node_in_group("slot_machine_reward_modal") as SlotMachineRewardModal
		if not reward_modal and tree.current_scene and "slot_machine_reward_modal" in tree.current_scene:
			reward_modal = tree.current_scene.slot_machine_reward_modal as SlotMachineRewardModal

	if reward_modal and is_instance_valid(player) and weapon_data:
		reward_modal.show_weapon_reward(self, player, weapon_data, pilot_name)
		collected.emit(weapon_data)
	else:
		if is_instance_valid(player) and weapon_data:
			var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
			if w_ctrl:
				if w_ctrl.has_method("is_full") and w_ctrl.is_full() and not w_ctrl.get_weapon_instance(weapon_data.weapon_id):
					var swap_modal := WeaponSwapModalClass.new()
					get_tree().root.add_child(swap_modal)
					swap_modal.prompt_swap(player, weapon_data,
						func(_idx, _new_w):
							collected.emit(weapon_data)
							open_and_destroy()
							swap_modal.queue_free(),
						func(_discarded_w):
							open_and_destroy()
							swap_modal.queue_free()
					)
					return
				w_ctrl.add_weapon(weapon_data)

			# Sonido de recolección
			var audio_mgr := get_node_or_null("/root/AudioManager")
			if audio_mgr and audio_mgr.has_method("play_sfx"):
				audio_mgr.play_sfx("menu_open", 1.2, 1.1)

			# Feedback flotante
			_spawn_pickup_floater()

		collected.emit(weapon_data)
		open_and_destroy()

func open_and_destroy() -> void:
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
