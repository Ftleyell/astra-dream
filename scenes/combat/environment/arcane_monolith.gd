class_name ArcaneMonolith
extends "res://scenes/combat/environment/destructible_space_object.gd"


## ArcaneMonolith.gd
## Monolito Arcano-Tecnológico: reliquia antigua flotante con runas pulsantes cian/magenta.
## Salud: 150 HP. Al ser destruido libera el orbe de invocación de Arcana (ArcanaOrb) y esquirlas rúnicas.

@export var pulse_speed: float = 3.5
@export var float_amplitude: float = 8.0

var _time: float = 0.0
var arcana_orb_scene: PackedScene = preload("res://scenes/combat/pickups/arcana_orb.tscn")
var biomass_orb_scene: PackedScene = preload("res://scenes/combat/pickups/biomass_orb.tscn")

@onready var visual_base: CanvasItem = get_node_or_null("VisualBase")
@onready var visual_crystal: Polygon2D = get_node_or_null("FloatingCrystal")
@onready var runes_line: Line2D = get_node_or_null("RunesLine")
@onready var aura_polygon: Polygon2D = get_node_or_null("AuraPolygon")
@onready var hit_sparks: CPUParticles2D = get_node_or_null("HitSparks")

var _last_hit_msec: int = 0
var _shake_tween: Tween = null


func _ready() -> void:
	tier = 2
	obstacle_radius = 54.0
	shard_color = Color(0.1, 0.95, 1.0, 1.0)
	add_to_group("monoliths")
	add_to_group("monolith")

	# Deriva inercial lenta y mística (sin rotación continua para permanecer erguido/vertical)
	if drift_velocity == Vector2.ZERO:
		drift_velocity = Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
	angular_velocity = 0.0
	rotation = 0.0

	if health_component:
		health_component.max_health = 650.0
		health_component.current_health = 650.0
		if not health_component.damage_taken.is_connected(_on_monolith_damage_taken):
			health_component.damage_taken.connect(_on_monolith_damage_taken)

	super._ready()


func _process(delta: float) -> void:
	if is_dying:
		return

	_time += delta * pulse_speed

	# Oscilación pendular suave (permanece erguido/parado con sutil vaivén majestuoso)
	rotation = sin(_time * 0.4) * 0.03

	# Levitación vertical suave del monolito
	if visual_base is Node2D and (_shake_tween == null or not _shake_tween.is_valid()):
		(visual_base as Node2D).position.y = sin(_time) * (float_amplitude * 0.5)

	# Pulso cromático del aura (cian <-> magenta)
	var blend := (sin(_time * 1.2) + 1.0) * 0.5
	var rune_color := Color(0.0, 0.9, 1.0).lerp(Color(1.0, 0.1, 0.65), blend)
	if aura_polygon:
		aura_polygon.color = Color(rune_color.r, rune_color.g, rune_color.b, 0.18 + sin(_time) * 0.08)


## Contrato canónico de daño con resistencia a derretimiento instantáneo por rayos continuos
func take_damage(arg: Variant) -> void:
	if is_dying or not arg:
		return

	var dmg: float = 0.0
	var is_crit: bool = false
	if arg is HitContext:
		dmg = arg.final_damage
		is_crit = arg.is_crit
	elif arg is float or arg is int:
		dmg = float(arg)
	else:
		return

	var now := Time.get_ticks_msec()
	# Si los impactos se suceden a cadencia ultra-alta (<60ms como rayos láser continuo), mitigar ráfagas
	if now - _last_hit_msec < 60:
		dmg = minf(dmg * 0.75, 45.0)
	else:
		dmg = minf(dmg, 95.0)
	_last_hit_msec = now

	if health_component:
		health_component.take_damage(dmg, is_crit)
	else:
		_die()


func _on_monolith_damage_taken(amount: float, is_crit: bool) -> void:
	if is_dying:
		return

	# 1. Sacudida estructural del pilar
	if visual_base is Node2D:
		if _shake_tween and _shake_tween.is_valid():
			_shake_tween.kill()
		_shake_tween = create_tween()
		var base_y: float = sin(_time) * (float_amplitude * 0.5)
		_shake_tween.tween_property(visual_base, "position", Vector2(randf_range(-6.0, 6.0), base_y + randf_range(-4.0, 4.0)), 0.03)
		_shake_tween.tween_property(visual_base, "position", Vector2(randf_range(-3.0, 3.0), base_y + randf_range(-2.0, 2.0)), 0.03)
		_shake_tween.tween_property(visual_base, "position", Vector2(0.0, base_y), 0.04)

	# 2. Partículas de chispas arcanas
	if hit_sparks:
		hit_sparks.restart()
		hit_sparks.emitting = true

	# 3. Popup numérico de daño arcano cian / magenta
	var parent_node := get_parent()
	if parent_node:
		var txt_col := Color(0.2, 0.95, 1.0) if not is_crit else Color(1.0, 0.35, 0.75)
		var pop_pos := global_position + Vector2(randf_range(-24.0, 24.0), randf_range(-60.0, -20.0))
		FloatingText.spawn(parent_node, pop_pos, str(int(roundf(amount))), txt_col)

	# 4. Feedback sonoro
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("impact", 1.25)


func _die() -> void:
	if is_dying:
		return

	_spawn_arcana_orb()
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("unlock_or_upgrade_trophy"):
		save_mgr.unlock_or_upgrade_trophy(&"trophy_monolith_master", 1)
	_spawn_biomass_bonus()

	# Invocación de la secuencia base de muerte (shattered signal, esquirlas cinemáticas y knockback)
	super._die()


func _spawn_arcana_orb() -> void:
	if not arcana_orb_scene or not is_inside_tree():
		return
	var orb = arcana_orb_scene.instantiate()
	if not orb:
		return
	orb.global_position = global_position
	var parent_target := get_parent() if get_parent() else get_tree().current_scene
	if parent_target:
		parent_target.add_child(orb)


func _spawn_biomass_bonus() -> void:
	if not biomass_orb_scene or not is_inside_tree():
		return
	var parent_target := get_parent() if get_parent() else get_tree().current_scene
	if not parent_target:
		return
	for i in range(2):
		var bio = biomass_orb_scene.instantiate()
		if bio:
			if bio.has_method("setup"):
				bio.setup(2, global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15)))
			parent_target.add_child(bio)
