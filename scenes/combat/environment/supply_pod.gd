class_name SupplyPod
extends "res://scenes/combat/environment/destructible_space_object.gd"

## SupplyPod.gd
## Cápsula de Suministros Militares: contenedor blindado de recursos tácticos.
## Salud: 220 HP, armadura plana que mitiga 3 puntos de daño por impacto.
## Al ser destruida, libera consumibles críticos de supervivencia (Heal, Escudo/Bomba, Imán).

@export var flat_armor: float = 3.0
@export var beacon_blink_speed: float = 5.0

var consumable_scene: PackedScene = preload("res://scenes/combat/pickups/field_consumable.tscn")
var _time: float = 0.0

@onready var visual_box: Polygon2D = get_node_or_null("VisualBox")
@onready var hazard_stripes: Line2D = get_node_or_null("HazardStripes")
@onready var beacon_light: Polygon2D = get_node_or_null("BeaconLight")


func _ready() -> void:
	tier = 2
	obstacle_radius = 38.0
	shard_color = Color(1.0, 0.75, 0.2, 1.0) # Metralla metálica dorada/bronce
	add_to_group("supply_pods")

	# Deriva inercial moderada
	if drift_velocity == Vector2.ZERO:
		drift_velocity = Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	angular_velocity = randf_range(-0.4, 0.4)

	if health_component:
		health_component.max_health = 220.0
		health_component.current_health = 220.0

	super._ready()


func _process(delta: float) -> void:
	if is_dying:
		return

	_time += delta * beacon_blink_speed
	if beacon_light:
		var blink := (sin(_time) + 1.0) * 0.5
		beacon_light.color = Color(1.0, 0.5, 0.0).lerp(Color(1.0, 1.0, 0.2), blink)
		beacon_light.scale = Vector2.ONE * (0.8 + blink * 0.4)


## Mitigación de armadura plana por impacto
func take_damage(arg) -> void:
	if is_dying or not arg:
		return

	var final_ctx: HitContext = null
	if arg is HitContext:
		final_ctx = arg
	elif arg is float or arg is int:
		final_ctx = HitContext.new()
		final_ctx.raw_damage = float(arg)
		final_ctx.final_damage = float(arg)
	else:
		return

	# Reducción plana de daño (mínimo 1.0 de daño absorbido)
	var original_final := final_ctx.final_damage
	final_ctx.final_damage = maxf(1.0, original_final - flat_armor)
	final_ctx.raw_damage = maxf(1.0, final_ctx.raw_damage - flat_armor)

	super.take_damage(final_ctx)

	# Restaurar contexto para evitar efectos colaterales en objetos compartidos
	final_ctx.final_damage = original_final


func _die() -> void:
	if is_dying:
		return

	_spawn_survival_consumables()
	super._die()


func _spawn_survival_consumables() -> void:
	if not consumable_scene or not is_inside_tree():
		return

	var parent_target := get_parent() if get_parent() else get_tree().current_scene
	if not parent_target:
		return

	# Garantizar entre 1 y 2 consumibles
	var num_drops := randi_range(1, 2)
	var consumable_script = preload("res://scenes/combat/pickups/field_consumable.gd")

	for i in range(num_drops):
		var item := consumable_scene.instantiate() as Area2D
		if not item:
			continue

		var roll := randf()
		var chosen_type: int = consumable_script.ConsumableType.HEAL
		if roll < 0.45:
			chosen_type = consumable_script.ConsumableType.HEAL
		elif roll < 0.75:
			chosen_type = consumable_script.ConsumableType.MAGNET
		else:
			chosen_type = consumable_script.ConsumableType.BOMB

		var offset := Vector2(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0))
		parent_target.add_child(item)
		if item.has_method("setup"):
			item.setup(chosen_type, global_position + offset)
