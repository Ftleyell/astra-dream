class_name PlanetCore
extends Node2D

## PlanetCore.gd
## Núcleo central del planeta (radio ~30 px).
## Rodeado por las capas del manto y la corteza, preparado para la futura mecánica
## de digitalización e interacción directa del jugador.

signal core_digitalized(core_type: StringName, pos: Vector2)

@export var core_radius: float = 30.0
@export var core_color: Color = Color(0.2, 0.95, 0.6, 1.0)
@export var core_type: StringName = &"biosphere_core"

var is_digitized: bool = false
var player_in_range: bool = false

@onready var core_visual: Polygon2D = get_node_or_null("CoreVisual")
@onready var core_border: Line2D = get_node_or_null("CoreBorder")
@onready var core_aura: Polygon2D = get_node_or_null("CoreAura")
@onready var interact_area: Area2D = get_node_or_null("InteractionArea")


func _ready() -> void:
	rebuild_core_geometry()
	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)


func setup_core(r: float, col: Color, p_type: StringName) -> void:
	core_radius = r
	core_color = col
	core_type = p_type
	if is_inside_tree():
		rebuild_core_geometry()


func rebuild_core_geometry() -> void:
	var pts: PackedVector2Array = []
	var steps: int = 16
	for i in range(steps):
		var ang := (TAU / float(steps)) * float(i)
		pts.append(Vector2(cos(ang), sin(ang)) * core_radius)

	if core_visual:
		core_visual.polygon = pts
		core_visual.color = core_color

	if core_border:
		core_border.clear_points()
		for p in pts:
			core_border.add_point(p)
		if pts.size() > 0:
			core_border.add_point(pts[0])
		core_border.default_color = core_color.lightened(0.4)
		core_border.width = 2.0

	if core_aura:
		var aura_pts: PackedVector2Array = []
		for i in range(steps):
			var ang := (TAU / float(steps)) * float(i)
			aura_pts.append(Vector2(cos(ang), sin(ang)) * (core_radius * 1.25))
		core_aura.polygon = aura_pts
		core_aura.color = Color(core_color.r, core_color.g, core_color.b, 0.25)


func _process(delta: float) -> void:
	# Pulso suave de energía del núcleo
	var t := Time.get_ticks_msec() * 0.003
	var pulse: float = 1.0 + sin(t) * 0.1
	if core_aura:
		core_aura.scale = Vector2(pulse, pulse)
		core_aura.rotation += delta * 0.3


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false


## Preparado para la futura función de digitalización con tecla
func can_digitalize() -> bool:
	return player_in_range and not is_digitized


func digitalize() -> void:
	if is_digitized:
		return
	is_digitized = true
	core_digitalized.emit(core_type, global_position)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.3, 0.5)
