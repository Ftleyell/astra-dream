class_name PlanetCore
extends Node2D

## PlanetCore.gd
## Núcleo central del planeta (radio 50 px).
## Rodeado por las 3 capas protectoras, accionable interactivamente con la tecla [E]
## para digitalizar y obtener 20 unidades de BioMasa persistente.

signal core_digitalized(core_type: StringName, pos: Vector2)

@export var core_radius: float = 50.0
@export var core_color: Color = Color(0.2, 0.95, 0.6, 1.0)
@export var core_type: StringName = &"biosphere_core"
@export var biomass_reward: int = 20

var is_digitized: bool = false
var player_in_range: bool = false
var player_ref: Player = null

@onready var core_visual: Polygon2D = get_node_or_null("CoreVisual")
@onready var core_border: Line2D = get_node_or_null("CoreBorder")
@onready var core_aura: Polygon2D = get_node_or_null("CoreAura")
@onready var interact_area: Area2D = get_node_or_null("InteractionArea")
@onready var prompt_label: Label = get_node_or_null("PromptLabel")


func _ready() -> void:
	rebuild_core_geometry()
	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)

	if prompt_label:
		prompt_label.visible = false
		prompt_label.text = "[E] Digitalizar Núcleo (+20 BioMasa)"


func setup_core(r: float, col: Color, p_type: StringName, reward: int = 20) -> void:
	core_radius = r
	core_color = col
	core_type = p_type
	biomass_reward = reward
	if is_inside_tree():
		rebuild_core_geometry()


func rebuild_core_geometry() -> void:
	var pts: PackedVector2Array = []
	var steps: int = 20
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
		core_border.width = 3.0

	if core_aura:
		var aura_pts: PackedVector2Array = []
		for i in range(steps):
			var ang := (TAU / float(steps)) * float(i)
			aura_pts.append(Vector2(cos(ang), sin(ang)) * (core_radius * 1.3))
		core_aura.polygon = aura_pts
		core_aura.color = Color(core_color.r, core_color.g, core_color.b, 0.3)

	if interact_area:
		var coll := interact_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if coll and coll.shape is CircleShape2D:
			(coll.shape as CircleShape2D).radius = core_radius * 1.7


func _process(delta: float) -> void:
	if is_digitized:
		return

	# Pulso visual de energía
	var t := Time.get_ticks_msec() * 0.003
	var pulse: float = 1.0 + sin(t) * 0.12
	if core_aura:
		core_aura.scale = Vector2(pulse, pulse)
		core_aura.rotation += delta * 0.4


func _unhandled_input(event: InputEvent) -> void:
	if is_digitized or not player_in_range:
		return

	# Acción de teclado [E] para digitalizar
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			digitalize()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true
		player_ref = body as Player
		if prompt_label and not is_digitized:
			prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		player_ref = null
		if prompt_label:
			prompt_label.visible = false


func digitalize() -> void:
	if is_digitized:
		return
	is_digitized = true

	if prompt_label:
		prompt_label.visible = false

	# 1. Otorgar los 20 de BioMasa persistente
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Player

	if is_instance_valid(player_ref) and player_ref.has_method("add_biomass"):
		player_ref.add_biomass(biomass_reward)
	else:
		SaveManager.add_biomass(biomass_reward)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("laser_fire")

	core_digitalized.emit(core_type, global_position)

	# 2. Secuencia cinemática de digitalización / colapso estelar
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.3)
	tween.tween_property(self, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.3)
	tween.chain().tween_property(self, "scale", Vector2(0.05, 0.05), 0.35)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)
