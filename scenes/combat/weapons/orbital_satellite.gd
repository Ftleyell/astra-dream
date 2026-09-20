class_name OrbitalSatellite
extends Node2D

@export var orbit_radius: float = 88.0
@export var orbit_speed: float = 2.4
@export var contact_radius: float = 34.0
@export var contact_damage: float = 16.0
@export var contact_hit_cooldown: float = 0.35
@export var bullet_clear_radius: float = 30.0
@export var zap_interval: float = 1.8
@export var zap_range: float = 230.0

var player: Player = null
var bullet_server: BulletServer = null
var orbit_index: int = 0
var total_satellites: int = 2
var current_angle: float = 0.0
var base_hit_context: HitContext = null

var zap_timer: float = 0.0
var victim_cooldowns: Dictionary = {}

@onready var shield_aura: Polygon2D = get_node_or_null("ShieldAura")
@onready var satellite_body: Polygon2D = get_node_or_null("SatelliteBody")
@onready var core_light: Polygon2D = get_node_or_null("CoreLight")

func setup(p_player: Player, p_orbit_index: int, p_total_satellites: int = 2, p_ctx: HitContext = null) -> void:
	player = p_player
	orbit_index = p_orbit_index
	total_satellites = max(1, p_total_satellites)
	base_hit_context = p_ctx

	# Distribuir equitativamente en la circunferencia (180° si son 2)
	current_angle = (TAU / float(total_satellites)) * float(orbit_index)

	if is_instance_valid(player):
		global_position = player.global_position + Vector2(cos(current_angle), sin(current_angle)) * orbit_radius

func _ready() -> void:
	# Localizar bullet_server en la escena si no se inyectó
	if not bullet_server and is_inside_tree():
		var bs_node := get_tree().current_scene.get_node_or_null("BulletServer")
		if bs_node is BulletServer:
			bullet_server = bs_node
		elif is_instance_valid(player) and player.bullet_server:
			bullet_server = player.bullet_server

	zap_timer = randf_range(0.2, zap_interval)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return

	_update_orbit(delta)
	_defend_anti_projectile()
	_handle_contact_damage(delta)
	_handle_autonomous_zap(delta)

func _update_orbit(delta: float) -> void:
	current_angle += orbit_speed * delta
	var target_offset := Vector2(cos(current_angle), sin(current_angle)) * orbit_radius
	global_position = player.global_position + target_offset

	# Rotación propia del dron
	if satellite_body:
		satellite_body.rotation += 3.5 * delta

	# Pulso suave del aura protectora
	if shield_aura:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.12
		shield_aura.scale = Vector2(pulse, pulse)

func _defend_anti_projectile() -> void:
	if bullet_server:
		bullet_server.bomb_clear_shockwave(global_position, bullet_clear_radius)

func _handle_contact_damage(delta: float) -> void:
	# Actualizar cooldowns por víctima
	var keys_to_remove: Array = []
	for victim_id in victim_cooldowns.keys():
		victim_cooldowns[victim_id] -= delta
		if victim_cooldowns[victim_id] <= 0.0:
			keys_to_remove.append(victim_id)
	for k in keys_to_remove:
		victim_cooldowns.erase(k)

	var r_sq := contact_radius * contact_radius
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("enemies"))
	targets.append_array(get_tree().get_nodes_in_group("emitters"))

	for node in targets:
		if node is Node2D and is_instance_valid(node) and node != self:
			var node_id := node.get_instance_id()
			if victim_cooldowns.has(node_id):
				continue

			var d_sq := global_position.distance_squared_to(node.global_position)
			if d_sq <= r_sq:
				victim_cooldowns[node_id] = contact_hit_cooldown
				_apply_contact_hit(node)

func _apply_contact_hit(target: Node2D) -> void:
	if not target.has_method("take_damage"):
		return

	var ctx: HitContext
	if base_hit_context:
		ctx = base_hit_context.fork_child_hit(contact_damage, 0.25, &"orbital_contact")
	else:
		ctx = HitContext.new()
		ctx.attacker = player
		ctx.raw_damage = contact_damage
		ctx.final_damage = contact_damage
		ctx.proc_coefficient = 0.25
	ctx.hit_position = target.global_position

	target.take_damage(ctx)

	if is_instance_valid(player) and player.inventory:
		player.inventory.process_hit_procs(ctx, player)

	_draw_contact_arc(global_position, target.global_position)

func _handle_autonomous_zap(delta: float) -> void:
	zap_timer -= delta
	if zap_timer > 0.0:
		return

	zap_timer = zap_interval

	# Buscar enemigo más cercano dentro del radio de telemetría
	var nearest_enemy: Node2D = null
	var min_dist_sq := zap_range * zap_range

	var candidates: Array[Node] = []
	candidates.append_array(get_tree().get_nodes_in_group("enemies"))
	candidates.append_array(get_tree().get_nodes_in_group("emitters"))

	for node in candidates:
		if node is Node2D and is_instance_valid(node) and node != self:
			var d_sq := global_position.distance_squared_to(node.global_position)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				nearest_enemy = node

	if nearest_enemy and is_instance_valid(nearest_enemy):
		_discharge_zap(nearest_enemy)

func _discharge_zap(target: Node2D) -> void:
	var zap_damage: float = contact_damage * 1.5

	var ctx: HitContext
	if base_hit_context:
		ctx = base_hit_context.fork_child_hit(zap_damage, 0.35, &"orbital_zap")
	else:
		ctx = HitContext.new()
		ctx.attacker = player
		ctx.raw_damage = zap_damage
		ctx.final_damage = zap_damage
		ctx.proc_coefficient = 0.35
	ctx.hit_position = target.global_position

	if target.has_method("take_damage"):
		target.take_damage(ctx)

	if is_instance_valid(player) and player.inventory:
		player.inventory.process_hit_procs(ctx, player)

	_draw_contact_arc(global_position, target.global_position, Color(0.4, 0.9, 1.0, 0.95), 4.0)

func _draw_contact_arc(from_pos: Vector2, to_pos: Vector2, color: Color = Color(0.2, 0.8, 1.0, 0.9), width: float = 3.0) -> void:
	var arc_line := Line2D.new()
	arc_line.width = width
	arc_line.default_color = color
	arc_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc_line.end_cap_mode = Line2D.LINE_CAP_ROUND

	# Trayecto con una ligera desviación zig-zag para simular arco eléctrico
	var mid := (from_pos + to_pos) * 0.5 + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	arc_line.add_point(from_pos)
	arc_line.add_point(mid)
	arc_line.add_point(to_pos)

	var parent_node := get_parent() if is_inside_tree() else null
	if not parent_node and is_inside_tree():
		parent_node = get_tree().current_scene
	if parent_node:
		parent_node.add_child(arc_line)
		var tween := arc_line.create_tween()
		tween.tween_property(arc_line, "modulate:a", 0.0, 0.12)
		tween.tween_callback(arc_line.queue_free)
