class_name EnemySplitter
extends "res://scenes/combat/enemies/enemy_base.gd"

## Célula cibernética mitótica (Enemigo Fisión):
## Al ser destruida, se divide en 2 versiones menores ("micro-clones") que se dispersan.
## Cada mitad tiene un temporizador de 5 segundos con un enlace de resonancia visible.
## Si ambas mitades sobreviven los 5 segundos, intentan fusionarse de vuelta en un Splitter.

const DEFAULT_SPLITTER_DATA: EnemyData = preload("res://data/enemies/enemy_splitter.tres")
const DEFAULT_SPLITTER_MICRO_DATA: EnemyData = preload("res://data/enemies/enemy_splitter_micro.tres")

@export var is_micro_clone: bool = false:
	set(value):
		is_micro_clone = value
		enemy_data = DEFAULT_SPLITTER_MICRO_DATA if is_micro_clone else DEFAULT_SPLITTER_DATA
		_apply_enemy_data()
@export var fusion_countdown: float = 5.0
@export var split_count: int = 2

var twin_half: EnemySplitter = null
var tether_line: Line2D = null
var is_recombining: bool = false

func _init() -> void:
	enemy_data = DEFAULT_SPLITTER_MICRO_DATA if is_micro_clone else DEFAULT_SPLITTER_DATA
	_apply_enemy_data()

func _apply_enemy_data() -> void:
	enemy_data = DEFAULT_SPLITTER_MICRO_DATA if is_micro_clone else DEFAULT_SPLITTER_DATA
	super._apply_enemy_data()
	if enemy_data != null:
		fusion_countdown = enemy_data.fusion_countdown
		split_count = enemy_data.split_count

func _apply_stats() -> void:
	_apply_enemy_data()

func _ready_custom() -> void:
	var visual: CanvasItem = get_node_or_null("Visual") as CanvasItem
	var cell_core: CanvasItem = get_node_or_null("CellCore") as CanvasItem
	var existing_spr: Sprite2D = get_node_or_null("SplitterSprite") as Sprite2D
	if existing_spr == null:
		var tex_path: String = "res://assets/sprites/enemies/enemy_splitter.png"
		if ResourceLoader.exists(tex_path):
			var tex: Texture2D = load(tex_path) as Texture2D
			if tex:
				var spr: Sprite2D = Sprite2D.new()
				spr.name = "SplitterSprite"
				spr.texture = tex
				spr.scale = Vector2(0.06, 0.06)
				add_child(spr)
				move_child(spr, 0)
				sprite = spr
				if visual:
					visual.visible = false
				if cell_core:
					cell_core.visible = false
	else:
		sprite = existing_spr
	if tether_line == null:
		tether_line = Line2D.new()
		tether_line.name = "TetherLine"
		tether_line.width = 2.0
		tether_line.default_color = Color(0.2, 1.0, 0.5, 0.7)
		tether_line.top_level = true
		tether_line.visible = false
		add_child(tether_line)
	_reset_pool_state()

func _reset_pool_state() -> void:
	_apply_enemy_data()
	contact_radius = (enemy_data.contact_radius if enemy_data != null else contact_radius) * 2.0
	current_health = max_health
	is_recombining = false
	if is_micro_clone:
		scale = Vector2(1.3, 1.3)
	else:
		twin_half = null
		scale = Vector2(2.0, 2.0)
	if is_instance_valid(tether_line):
		tether_line.clear_points()
		tether_line.visible = is_micro_clone and is_instance_valid(twin_half)

func _update_behavior(delta: float) -> void:
	if is_micro_clone and is_instance_valid(twin_half) and not twin_half.is_dying:
		fusion_countdown -= delta
		_update_tether_visual()

		if fusion_countdown <= 0.0:
			# Intentar reunificación: avanzar hacia la otra mitad
			is_recombining = true
			var to_twin := (twin_half.global_position - global_position)
			var dist := to_twin.length()
			if dist < 30.0:
				_fuse_with_twin()
				return
			velocity = to_twin.normalized() * (move_speed * 1.5)
			rotation = to_twin.angle()
			move_and_slide()
			return

	# Comportamiento normal hacia el jugador
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * move_speed
	rotation = dir.angle()
	move_and_slide()

func _update_tether_visual() -> void:
	if not tether_line:
		return
	if is_instance_valid(twin_half) and not twin_half.is_dying:
		tether_line.visible = true
		tether_line.clear_points()
		tether_line.add_point(global_position)
		tether_line.add_point(twin_half.global_position)
		# Parpadeo conforme se acerca la fusión
		var pulse := sin(fusion_countdown * 8.0) * 0.3 + 0.7
		tether_line.default_color = Color(1.0, 0.4, 0.2, pulse) if fusion_countdown < 2.0 else Color(0.2, 1.0, 0.5, pulse * 0.7)
	else:
		tether_line.visible = false

func _fuse_with_twin() -> void:
	if is_dying:
		return
	# Solo uno de los dos orquesta la re-fusión
	if get_instance_id() < twin_half.get_instance_id():
		return

	var spawn_pos := (global_position + twin_half.global_position) * 0.5
	var parent_node := get_parent()
	if parent_node:
		var reformed: EnemySplitter = (load("res://scenes/combat/enemies/enemy_splitter.tscn") as PackedScene).instantiate() as EnemySplitter
		reformed.is_micro_clone = false
		reformed.global_position = spawn_pos
		parent_node.add_child(reformed)
		reformed.current_health = reformed.max_health * 0.5 # Reconstituido con 50% HP

	if is_instance_valid(twin_half):
		twin_half.queue_free()
	queue_free()

func _die() -> void:
	if not is_micro_clone and not is_dying:
		_spawn_mitosis_halves()

	if tether_line:
		tether_line.visible = false

	super._die()

func _spawn_mitosis_halves() -> void:
	var scene := load("res://scenes/combat/enemies/enemy_splitter.tscn") as PackedScene
	if not scene:
		return
	var parent_node := get_parent()
	if not parent_node:
		return

	var half_a := scene.instantiate() as EnemySplitter
	var half_b := scene.instantiate() as EnemySplitter
	half_a.is_micro_clone = true
	half_b.is_micro_clone = true

	var forward := Vector2.RIGHT.rotated(rotation)
	var offset_a := forward.rotated(0.7) * 25.0
	var offset_b := forward.rotated(-0.7) * 25.0

	half_a.global_position = global_position + offset_a
	half_b.global_position = global_position + offset_b

	half_a.twin_half = half_b
	half_b.twin_half = half_a

	parent_node.add_child(half_a)
	parent_node.add_child(half_b)
