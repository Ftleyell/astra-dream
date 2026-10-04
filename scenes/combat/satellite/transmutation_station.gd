class_name TransmutationStation
extends Node2D

## TransmutationStation.gd
## Baliza satelital de Forja Cuántica (Microondas espacial).
## Permite al jugador clonar un ítem de su inventario sacrificando
## otro ítem aleatorio de la misma rareza (hasta 3 usos por estación).

signal station_activated(station: TransmutationStation)
signal station_depleted()

const TEXTURE_BEACON := "res://assets/sprites/interactables/transmutation_beacon.png"

@export var max_uses: int = 3
@export var activation_radius: float = 180.0
@export var rotation_speed: float = 0.35

var uses_remaining: int = 3
var is_active: bool = false
var player_inside: bool = false
var is_depleted: bool = false

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/Sprite2D
@onready var area: Area2D = $PerimeterArea
@onready var radius_visual: Line2D = $RadiusVisual
@onready var status_label: Label = $StatusLabel

func _ready() -> void:
	add_to_group("transmutation_stations")
	check_quantum_recompiler()
	_apply_visual_skin()
	_draw_radius_circle()

	if is_instance_valid(area):
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

func check_quantum_recompiler(player_override: Node = null) -> void:
	var target_player: Node = player_override if player_override else (get_tree().get_first_node_in_group("player") if get_tree() else null)
	if target_player and "inventory" in target_player and target_player.inventory:
		if target_player.inventory.has_method("get_item_count") and target_player.inventory.get_item_count(&"quantum_recompiler") > 0:
			max_uses = 4
			uses_remaining = 4
			_update_label()
		else:
			max_uses = 3
			uses_remaining = 3
			_update_label()

func _process(delta: float) -> void:
	if visual_root and not is_depleted:
		visual_root.rotation += rotation_speed * delta

func _apply_visual_skin() -> void:
	if sprite and ResourceLoader.exists(TEXTURE_BEACON):
		sprite.texture = load(TEXTURE_BEACON) as Texture2D
		sprite.scale = Vector2(0.22, 0.22) # Escala óptima para 1024x1024 a ~220px de satélite

func _draw_radius_circle() -> void:
	if not radius_visual:
		return
	radius_visual.clear_points()
	var points: int = 36
	for i in range(points + 1):
		var angle := float(i) * TAU / float(points)
		radius_visual.add_point(Vector2(cos(angle), sin(angle)) * activation_radius)
	radius_visual.default_color = Color(0.8, 0.3, 1.0, 0.45) # Violeta cuántico

func _on_body_entered(body: Node2D) -> void:
	if is_depleted:
		return
	if body is Player:
		player_inside = true
		check_quantum_recompiler(body)
		station_activated.emit(self)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_inside = false

func consume_use() -> bool:
	if uses_remaining <= 0 or is_depleted:
		return false
	uses_remaining -= 1
	_update_label()
	if uses_remaining <= 0:
		deplete_station()
	return true

func _update_label() -> void:
	if status_label:
		status_label.text = "FORJA: %d/%d" % [uses_remaining, max_uses]

func deplete_station() -> void:
	is_depleted = true
	station_depleted.emit()
	if radius_visual:
		radius_visual.default_color = Color(0.4, 0.4, 0.4, 0.2)
	if status_label:
		status_label.text = "AGOTADA"
		status_label.modulate = Color(0.5, 0.5, 0.5, 0.8)

	var tw := create_tween()
	tw.tween_property(visual_root, "modulate", Color(0.5, 0.5, 0.6, 0.4), 0.8)
