class_name BulletServer
extends MultiMeshInstance2D

const MAX_BULLETS: int = 5000
const FLOATS_PER_INSTANCE: int = 12

# Dynamic Bounding limits (relative to player/camera)
var cull_distance_x: float = 3600.0
var cull_distance_y: float = 3600.0

# Structure of Arrays (Zero-Allocation Pool)
var pos_x: PackedFloat32Array
var pos_y: PackedFloat32Array
var vel_x: PackedFloat32Array
var vel_y: PackedFloat32Array
var time_alive: PackedFloat32Array
var max_life: PackedFloat32Array
var radius: PackedFloat32Array
var bullet_type: PackedFloat32Array
var wave_amp: PackedFloat32Array
var wave_freq: PackedFloat32Array
var base_angle: PackedFloat32Array
var flags: PackedInt32Array

var active_count: int = 0

# GPU Buffer & RID
var render_buffer: PackedFloat32Array
var multimesh_rid: RID

# Player Hitbox Core & Graze
var player_pos: Vector2 = Vector2.ZERO
var player_hitbox_radius: float = 5.0
var player_graze_radius: float = 24.0
var player_invulnerable: bool = false

signal player_hit()
signal player_grazed(pos: Vector2)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("bullet_server")
	top_level = true
	_init_memory_pools()
	_setup_multimesh()

func _init_memory_pools() -> void:
	pos_x.resize(MAX_BULLETS)
	pos_y.resize(MAX_BULLETS)
	vel_x.resize(MAX_BULLETS)
	vel_y.resize(MAX_BULLETS)
	time_alive.resize(MAX_BULLETS)
	max_life.resize(MAX_BULLETS)
	radius.resize(MAX_BULLETS)
	bullet_type.resize(MAX_BULLETS)
	wave_amp.resize(MAX_BULLETS)
	wave_freq.resize(MAX_BULLETS)
	base_angle.resize(MAX_BULLETS)
	flags.resize(MAX_BULLETS)

	render_buffer.resize(MAX_BULLETS * FLOATS_PER_INSTANCE)

	for i in range(MAX_BULLETS):
		var base: int = i * FLOATS_PER_INSTANCE
		render_buffer[base + 0] = 1.0
		render_buffer[base + 1] = 0.0
		render_buffer[base + 2] = 0.0
		render_buffer[base + 3] = 0.0
		render_buffer[base + 4] = 0.0
		render_buffer[base + 5] = 1.0
		render_buffer[base + 6] = 0.0
		render_buffer[base + 7] = 0.0
		render_buffer[base + 8] = 0.0
		render_buffer[base + 9] = 1.0
		render_buffer[base + 10] = 1.0
		render_buffer[base + 11] = 1.0

func _setup_multimesh() -> void:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.instance_count = MAX_BULLETS
	mm.visible_instance_count = 0
	# Definir AABB global masivo para que el motor jamás culle el MultiMesh al moverse la cámara
	mm.custom_aabb = AABB(Vector3(-100000.0, -100000.0, -100.0), Vector3(200000.0, 200000.0, 200.0))

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(24.0, 24.0)
	mm.mesh = quad

	self.multimesh = mm
	multimesh_rid = mm.get_rid()
	RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, Rect2(-100000.0, -100000.0, 200000.0, 200000.0))

	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://core/shaders/danmaku_bullet.gdshader")
	self.material = shader_material

func spawn_bullet(px: float, py: float, vx: float, vy: float, 
				  b_type: int = 0, b_radius: float = 4.0, lifetime: float = 10.0,
				  amp: float = 0.0, freq: float = 0.0) -> bool:
	if active_count >= MAX_BULLETS:
		return false

	var i: int = active_count
	pos_x[i] = px
	pos_y[i] = py
	vel_x[i] = vx
	vel_y[i] = vy
	time_alive[i] = 0.0
	max_life[i] = lifetime
	radius[i] = b_radius
	bullet_type[i] = float(b_type)
	wave_amp[i] = amp
	wave_freq[i] = freq
	base_angle[i] = atan2(vy, vx)
	flags[i] = 0

	active_count += 1
	return true

func _physics_process(delta: float) -> void:
	if active_count == 0:
		RenderingServer.multimesh_set_visible_instances(multimesh_rid, 0)
		return

	var px: float = player_pos.x
	var py: float = player_pos.y
	var r_graze_sq: float = player_graze_radius * player_graze_radius

	for i in range(active_count - 1, -1, -1):
		var t: float = time_alive[i] + delta
		time_alive[i] = t

		if t >= max_life[i]:
			_swap_and_pop(i)
			continue

		var vx: float = vel_x[i]
		var vy: float = vel_y[i]
		var amp: float = wave_amp[i]

		if amp != 0.0:
			var b_ang: float = base_angle[i]
			var spd: float = sqrt(vx * vx + vy * vy)
			var w_freq: float = wave_freq[i]
			var v_lat: float = amp * w_freq * cos(w_freq * t)

			var fx: float = cos(b_ang)
			var fy: float = sin(b_ang)
			var nx: float = -fy
			var ny: float = fx

			vx = fx * spd + nx * v_lat
			vy = fy * spd + ny * v_lat

		var cur_x: float = pos_x[i] + vx * delta
		var cur_y: float = pos_y[i] + vy * delta
		pos_x[i] = cur_x
		pos_y[i] = cur_y

		var dx: float = cur_x - px
		var dy: float = cur_y - py

		if absf(dx) > cull_distance_x or absf(dy) > cull_distance_y:
			_swap_and_pop(i)
			continue
		var dist_sq: float = dx * dx + dy * dy

		if not player_invulnerable:
			var combined_r: float = player_hitbox_radius + radius[i]
			if dist_sq <= combined_r * combined_r:
				player_hit.emit()
				_swap_and_pop(i)
				continue

		if dist_sq <= r_graze_sq and (flags[i] & 1) == 0:
			flags[i] |= 1
			player_grazed.emit(Vector2(cur_x, cur_y))

		var base: int = i * FLOATS_PER_INSTANCE
		var spd_sq: float = vx * vx + vy * vy
		var c: float = 1.0
		var s: float = 0.0
		if spd_sq > 0.0001:
			var inv_spd: float = 1.0 / sqrt(spd_sq)
			c = vx * inv_spd
			s = vy * inv_spd

		render_buffer[base + 0] = c
		render_buffer[base + 1] = -s
		render_buffer[base + 2] = 0.0
		render_buffer[base + 3] = cur_x
		render_buffer[base + 4] = s
		render_buffer[base + 5] = c
		render_buffer[base + 6] = 0.0
		render_buffer[base + 7] = cur_y
		render_buffer[base + 8] = bullet_type[i]
		render_buffer[base + 9] = 1.0
		render_buffer[base + 10] = 1.0
		render_buffer[base + 11] = 1.0

	RenderingServer.multimesh_set_buffer(multimesh_rid, render_buffer)
	RenderingServer.multimesh_set_visible_instances(multimesh_rid, active_count)

func _swap_and_pop(idx: int) -> void:
	active_count -= 1
	if idx != active_count:
		_copy_bullet(active_count, idx)

func _copy_bullet(src: int, dst: int) -> void:
	pos_x[dst] = pos_x[src]
	pos_y[dst] = pos_y[src]
	vel_x[dst] = vel_x[src]
	vel_y[dst] = vel_y[src]
	time_alive[dst] = time_alive[src]
	max_life[dst] = max_life[src]
	radius[dst] = radius[src]
	bullet_type[dst] = bullet_type[src]
	wave_amp[dst] = wave_amp[src]
	wave_freq[dst] = wave_freq[src]
	base_angle[dst] = base_angle[src]
	flags[dst] = flags[src]

# SCREEN CLEAR BOMBS
func bomb_clear_all() -> void:
	active_count = 0
	RenderingServer.multimesh_set_visible_instances(multimesh_rid, 0)

func bomb_clear_shockwave(center: Vector2, shockwave_radius: float) -> void:
	var r_sq: float = shockwave_radius * shockwave_radius
	for i in range(active_count - 1, -1, -1):
		var dx: float = pos_x[i] - center.x
		var dy: float = pos_y[i] - center.y
		if dx * dx + dy * dy <= r_sq:
			_swap_and_pop(i)

func clear_bullets_in_radius(center: Vector2, radius_val: float) -> void:
	bomb_clear_shockwave(center, radius_val)

func clear_bullets_in_arc(center: Vector2, direction: Vector2, arc_degrees: float, max_dist: float) -> void:
	var r_sq: float = max_dist * max_dist
	var half_rad: float = deg_to_rad(arc_degrees * 0.5)
	var forward: Vector2 = direction.normalized()
	for i in range(active_count - 1, -1, -1):
		var diff := Vector2(pos_x[i] - center.x, pos_y[i] - center.y)
		var d_sq := diff.length_squared()
		if d_sq <= r_sq and d_sq > 0.001:
			var angle_diff := absf(forward.angle_to(diff))
			if angle_diff <= half_rad:
				_swap_and_pop(i)

func get_active_bullet_count() -> int:
	return active_count

# PROCEDURAL DANMAKU PATTERNS
func fire_radial_ring(origin: Vector2, count: int, speed: float, 
					  base_rot: float = 0.0, b_type: int = 0) -> void:
	var step: float = TAU / float(count)
	for i in range(count):
		var angle: float = base_rot + float(i) * step
		spawn_bullet(origin.x, origin.y, cos(angle) * speed, sin(angle) * speed, b_type)

func fire_fermat_spiral_tick(origin: Vector2, tick: int, speed: float, 
							 rot_offset: float = 0.0, b_type: int = 1) -> void:
	var angle: float = float(tick) * 2.399963229728653 + rot_offset
	spawn_bullet(origin.x, origin.y, cos(angle) * speed, sin(angle) * speed, b_type)

func fire_aimed_spread(origin: Vector2, target: Vector2, count: int, 
					   spread_deg: float, speed: float, b_type: int = 2) -> void:
	var target_angle: float = (target - origin).angle()
	if count <= 1:
		spawn_bullet(origin.x, origin.y, cos(target_angle) * speed, sin(target_angle) * speed, b_type)
		return

	var spread_rad: float = deg_to_rad(spread_deg)
	var start_angle: float = target_angle - spread_rad * 0.5
	var step: float = spread_rad / float(count - 1)
	for i in range(count):
		var angle: float = start_angle + float(i) * step
		spawn_bullet(origin.x, origin.y, cos(angle) * speed, sin(angle) * speed, b_type)
