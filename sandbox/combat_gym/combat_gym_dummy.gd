class_name CombatGymDummy
extends CharacterBody2D
## Dummy de entrenamiento inmortal para CombatGym con lectura de daño y DPS (ventana 3 s).

const MAX_HP_DEFAULT: float = 2500.0
const DPS_WINDOW_SEC: float = 3.0
const HIT_RADIUS_PX: float = 26.0

var max_health: float = MAX_HP_DEFAULT
var current_health: float = MAX_HP_DEFAULT
var total_damage_taken: float = 0.0
var reset_count: int = 0
var is_dying: bool = false
var is_invulnerable: bool = false

var _hit_flash: float = 0.0
var _sim_time: float = 0.0
var _damage_log: Array[Dictionary] = []
var _info_label: Label = null


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 0

	var col := CollisionShape2D.new()
	col.name = "HitShape"
	var shape := CircleShape2D.new()
	shape.radius = HIT_RADIUS_PX
	col.shape = shape
	add_child(col)

	_info_label = Label.new()
	_info_label.name = "DummyInfoLabel"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.position = Vector2(-75.0, -56.0)
	_info_label.custom_minimum_size = Vector2(150.0, 28.0)
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.add_theme_color_override("font_color", Color(0.85, 0.96, 1.0, 0.95))
	_info_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_info_label.add_theme_constant_override("shadow_offset_x", 1)
	_info_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_info_label)
	_refresh_label()


func _process(delta: float) -> void:
	_sim_time += delta
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta * 5.0)
	_prune_damage_log()
	_refresh_label()
	queue_redraw()


func take_damage(ctx: HitContext) -> void:
	if ctx == null:
		return
	var dmg: float = maxf(0.0, ctx.final_damage)
	current_health -= dmg
	total_damage_taken += dmg
	_hit_flash = 1.0
	_damage_log.append({"t": _sim_time, "dmg": dmg})
	if current_health <= 0.0:
		reset_count += 1
		current_health = max_health
	_refresh_label()
	queue_redraw()


func get_recent_dps() -> float:
	_prune_damage_log()
	var sum_dmg: float = 0.0
	for item: Dictionary in _damage_log:
		sum_dmg += float(item.get("dmg", 0.0))
	return sum_dmg / DPS_WINDOW_SEC


func _prune_damage_log() -> void:
	var cutoff: float = _sim_time - DPS_WINDOW_SEC
	while not _damage_log.is_empty() and float(_damage_log[0].get("t", 0.0)) < cutoff:
		_damage_log.remove_at(0)


func _refresh_label() -> void:
	if not is_instance_valid(_info_label):
		return
	_info_label.text = "DUMMY %d/%d\nDPS: %.0f | Resets: %d" % [
		int(ceilf(current_health)),
		int(max_health),
		get_recent_dps(),
		reset_count,
	]


func _draw() -> void:
	var fill_col: Color = Color(0.14, 0.22, 0.34, 0.85).lerp(Color(1.0, 0.45, 0.55, 0.95), _hit_flash)
	draw_circle(Vector2.ZERO, HIT_RADIUS_PX, fill_col)
	draw_arc(Vector2.ZERO, HIT_RADIUS_PX, 0.0, TAU, 36, Color(0.25, 0.92, 1.0, 0.92), 2.0, true)
	draw_arc(Vector2.ZERO, HIT_RADIUS_PX * 0.55, 0.0, TAU, 24, Color(1.0, 0.35, 0.55, 0.78), 1.5, true)

	var ratio: float = clampf(current_health / maxf(1.0, max_health), 0.0, 1.0)
	var start_ang: float = -PI * 0.5
	draw_arc(
		Vector2.ZERO,
		HIT_RADIUS_PX + 6.0,
		start_ang,
		start_ang + TAU * ratio,
		36,
		Color(0.28, 1.0, 0.55, 0.92),
		3.0,
		true
	)
