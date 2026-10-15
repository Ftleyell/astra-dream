class_name HUDDragonRadarDisplay
extends Control

## HUDDragonRadarDisplay.gd
## Componente visual y desacoplado del minimapa estilo Dragon Radar:
## - Pantalla shaderizada con barrido polar rotativo y cuadrícula CRT.
## - Detección angular sincronizada con el sweep: los puntos hacen 'ping' y se desvanecen.
## - Satélites y puntos de interés adhiriéndose y rotando en el borde circular útil cuando están fuera de rango.
## - Puntos de entidades de diferentes colores y tamaños según jerarquía (Drops, Enemigos, Bosses, Satélites).

const DragonRadarBlipClass = preload("res://scenes/ui/hud/components/dragon_radar_blip.gd")

@export var radar_world_range: float = 3200.0
@export var sweep_speed: float = 2.4 # radianes por segundo
@export var blip_fade_time: float = 2.6 # Persiste durante una vuelta completa

# Colores de pings según rol
@export var enemy_color: Color = Color(1.0, 0.25, 0.25, 1.0)
@export var boss_color: Color = Color(1.0, 0.1, 0.8, 1.0)
@export var pickup_color: Color = Color(0.2, 0.85, 1.0, 0.9)
@export var satellite_color: Color = Color(1.0, 0.85, 0.15, 1.0)
@export var player_color: Color = Color(0.3, 1.0, 0.4, 1.0)

var player_ref: Node2D = null

# Estado del sweep angular
var _current_sweep_angle: float = 0.0
var _prev_sweep_angle: float = 0.0

# Almacén de blips activos (renderizados en _draw())
var _active_blips: Dictionary = {} # target_id (int) -> DragonRadarBlip

# Referencias visuales internas
var _screen_rect: ColorRect = null
var _frame_texture: TextureRect = null
var _screen_material: ShaderMaterial = null
var _blips_layer: Control = null

# Geometría calibrada con minmap.png y minmapmask.png (1024x1024)
const MASK_USEFUL_RADIUS_RATIO: float = 0.430 # ~441px en 1024px

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_visual_nodes()

func _setup_visual_nodes() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(240, 240)
		size = custom_minimum_size

	# 1. Obtener o crear ColorRect con el Shader de Pantalla
	_screen_rect = get_node_or_null("RadarScreen") as ColorRect
	if not _screen_rect:
		_screen_rect = ColorRect.new()
		_screen_rect.name = "RadarScreen"
		_screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_screen_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_screen_rect)

	if _screen_rect.material is ShaderMaterial:
		_screen_material = _screen_rect.material as ShaderMaterial
	else:
		var shader_res: Shader = load("res://scenes/ui/hud/shaders/dragon_radar_screen.gdshader") as Shader
		if shader_res:
			_screen_material = ShaderMaterial.new()
			_screen_material.shader = shader_res
			var mask_tex: Texture2D = load("res://assets/ui/minmapmask.png") as Texture2D
			if mask_tex:
				_screen_material.set_shader_parameter("mask_texture", mask_tex)
				_screen_material.set_shader_parameter("use_mask_texture", true)
			_screen_material.set_shader_parameter("border_radius", MASK_USEFUL_RADIUS_RATIO)
			_screen_rect.material = _screen_material

	# 2. Capa de dibujo de pings/blips (Entre RadarScreen y RadarFrame)
	_blips_layer = get_node_or_null("RadarBlipsLayer") as Control
	if not _blips_layer:
		_blips_layer = Control.new()
		_blips_layer.name = "RadarBlipsLayer"
		_blips_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_blips_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_blips_layer)
	
	if not _blips_layer.draw.is_connected(_on_blips_layer_draw):
		_blips_layer.draw.connect(_on_blips_layer_draw)

	# 3. Obtener o crear Marco exterior PNG (Carcasa metálica)
	_frame_texture = get_node_or_null("RadarFrame") as TextureRect
	if not _frame_texture:
		_frame_texture = TextureRect.new()
		_frame_texture.name = "RadarFrame"
		_frame_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		_frame_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_frame_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var frame_tex: Texture2D = load("res://assets/ui/minmap.png") as Texture2D
		if frame_tex:
			_frame_texture.texture = frame_tex
		add_child(_frame_texture)

func set_player(p_player: Node2D) -> void:
	player_ref = p_player

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	# 1. Avanzar ángulo de sweep
	_prev_sweep_angle = _current_sweep_angle
	_current_sweep_angle = fmod(_current_sweep_angle + sweep_speed * delta, TAU)

	# Actualizar shader
	if _screen_material:
		_screen_material.set_shader_parameter("sweep_angle", _current_sweep_angle)

	# 2. Actualizar ciclo de vida de blips existentes
	var expired_keys: Array = []
	for k: Variant in _active_blips.keys():
		var blip = _active_blips[k]
		if blip != null:
			blip.life -= delta / blip.max_life
			if blip.life <= 0.0:
				expired_keys.append(k)

	for k: Variant in expired_keys:
		_active_blips.erase(k)

	# 3. Detectar entidades alcanzadas por el haz en este frame
	_scan_world_entities()

	# 4. Redibujar capa de pings por encima del shader
	if is_instance_valid(_blips_layer):
		_blips_layer.queue_redraw()
	else:
		queue_redraw()

func _scan_world_entities() -> void:
	if not is_instance_valid(player_ref):
		var tree := get_tree()
		if tree:
			player_ref = tree.get_first_node_in_group("player") as Node2D
		if not is_instance_valid(player_ref):
			return

	var center: Vector2 = size * 0.5
	var useful_radius: float = minf(size.x, size.y) * MASK_USEFUL_RADIUS_RATIO
	var player_pos: Vector2 = player_ref.global_position

	# 1. Satélites y Estaciones (satellite_beacon, transmutation_stations, slot_machine_beacon)
	var sat_groups: Array[String] = ["satellite_beacon", "transmutation_stations", "slot_machine_beacon"]
	for grp in sat_groups:
		var sats: Array[Node] = get_tree().get_nodes_in_group(grp)
		for s_node: Node in sats:
			if not is_instance_valid(s_node):
				continue
			var s_2d := s_node as Node2D
			if not s_2d or not s_2d.is_inside_tree():
				continue
			_process_radar_target(
				s_2d.get_instance_id(),
				s_2d.global_position,
				player_pos,
				center,
				useful_radius,
				satellite_color,
				6.0,
				true
			)

	# 2. Satélite activo seguido por el HUD si aún no está instanciado en el mundo (proyección de odómetro)
	var hud_parent := get_parent()
	if hud_parent and "_edge_tracker_mgr" in hud_parent:
		var edge_mgr = hud_parent._edge_tracker_mgr
		if edge_mgr and "satellite_tracker" in edge_mgr and is_instance_valid(edge_mgr.satellite_tracker):
			var sat_tracker = edge_mgr.satellite_tracker
			if sat_tracker.has_satellite:
				_process_radar_target(
					999999,
					sat_tracker.active_satellite_pos,
					player_pos,
					center,
					useful_radius,
					satellite_color,
					6.0,
					true
				)

	# 3. Jefes y Colosos
	var bosses: Array[Node] = get_tree().get_nodes_in_group("bosses")
	for boss_node: Node in bosses:
		if not is_instance_valid(boss_node):
			continue
		var b_2d := boss_node as Node2D
		if not b_2d or not b_2d.is_inside_tree():
			continue
		_process_radar_target(
			b_2d.get_instance_id(),
			b_2d.global_position,
			player_pos,
			center,
			useful_radius,
			boss_color,
			5.0,
			true
		)

	# 4. Enemigos normales
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy_node: Node in enemies:
		if not is_instance_valid(enemy_node):
			continue
		var e_2d := enemy_node as Node2D
		if not e_2d or not e_2d.is_inside_tree():
			continue
		_process_radar_target(
			e_2d.get_instance_id(),
			e_2d.global_position,
			player_pos,
			center,
			useful_radius,
			enemy_color,
			3.0,
			false
		)

	# 5. Drops, orbes de EXP y cofres
	var exp_blobs: Array[Node] = get_tree().get_nodes_in_group("exp_blobs")
	for exp_node: Node in exp_blobs:
		if not is_instance_valid(exp_node):
			continue
		var exp_2d := exp_node as Node2D
		if not exp_2d or not exp_2d.is_inside_tree():
			continue
		_process_radar_target(
			exp_2d.get_instance_id(),
			exp_2d.global_position,
			player_pos,
			center,
			useful_radius,
			pickup_color,
			1.8,
			false
		)

	var consumables: Array[Node] = get_tree().get_nodes_in_group("field_consumables")
	for c_node: Node in consumables:
		if not is_instance_valid(c_node):
			continue
		var c_2d := c_node as Node2D
		if not c_2d or not c_2d.is_inside_tree():
			continue
		_process_radar_target(
			c_2d.get_instance_id(),
			c_2d.global_position,
			player_pos,
			center,
			useful_radius,
			Color(0.2, 1.0, 0.6, 1.0),
			3.5,
			false
		)

	var chests: Array[Node] = get_tree().get_nodes_in_group("spatial_chests")
	for ch_node: Node in chests:
		if not is_instance_valid(ch_node):
			continue
		var ch_2d := ch_node as Node2D
		if not ch_2d or not ch_2d.is_inside_tree():
			continue
		_process_radar_target(
			ch_2d.get_instance_id(),
			ch_2d.global_position,
			player_pos,
			center,
			useful_radius,
			Color(1.0, 0.7, 0.1, 1.0),
			4.0,
			true
		)

func _process_radar_target(
	t_id: int,
	target_pos: Vector2,
	player_pos: Vector2,
	radar_center: Vector2,
	radar_radius: float,
	color: Color,
	size_px: float,
	pin_to_edge_if_outside: bool
) -> void:
	var delta_pos: Vector2 = target_pos - player_pos
	var dist_world: float = delta_pos.length()

	# Ángulo [0, TAU]
	var angle: float = delta_pos.angle()
	if angle < 0.0:
		angle += TAU

	# Verificar si el sweep ha atravesado este ángulo en el frame actual
	var swept: bool = _is_angle_swept(_prev_sweep_angle, _current_sweep_angle, angle)

	var is_outside: bool = dist_world > radar_world_range
	if is_outside and not pin_to_edge_if_outside:
		return

	var clamped_dist: float = minf(dist_world, radar_world_range)
	var scale_factor: float = (clamped_dist / radar_world_range) * radar_radius
	if is_outside:
		scale_factor = radar_radius * 0.92

	var final_pos: Vector2 = radar_center + delta_pos.normalized() * scale_factor

	var blip = _active_blips.get(t_id)
	if swept:
		if blip == null:
			blip = DragonRadarBlipClass.new(t_id, final_pos, color, size_px, blip_fade_time)
			_active_blips[t_id] = blip
		else:
			blip.radar_pos = final_pos
			blip.life = 1.0 # Refrescar ping
			blip.color = color
			blip.size = size_px

		blip.is_satellite = pin_to_edge_if_outside
		blip.is_edge_clamped = is_outside
		blip.heading_angle = angle
	elif blip != null:
		# Si el blip todavía está desvaneciéndose en pantalla, acompañar la posición actual de la entidad
		blip.radar_pos = final_pos
		blip.is_edge_clamped = is_outside
		blip.heading_angle = angle

func _is_angle_swept(from_ang: float, to_ang: float, target_ang: float) -> bool:
	if from_ang <= to_ang:
		return target_ang >= from_ang and target_ang <= to_ang
	else:
		# Cruzó el límite 0 / TAU
		return target_ang >= from_ang or target_ang <= to_ang

func _on_blips_layer_draw() -> void:
	if not is_instance_valid(_blips_layer):
		return
	var center: Vector2 = size * 0.5

	# 1. Dibujar jugador en el centro exacto (pequeño triángulo o punto verde luminoso)
	_blips_layer.draw_circle(center, 4.0, player_color)
	_blips_layer.draw_circle(center, 2.0, Color.WHITE)

	# 2. Dibujar blips y pings activos
	for k: Variant in _active_blips.keys():
		var blip = _active_blips[k]
		if blip == null or blip.life <= 0.0:
			continue

		var alpha: float = clampf(blip.life, 0.0, 1.0)
		var draw_col: Color = blip.color
		draw_col.a = clampf(alpha * 1.2, 0.0, 1.0)

		if blip.is_edge_clamped:
			# Satélite pegado al borde: Marcador triangular nítido y anillo
			_draw_satellite_edge_marker(blip.radar_pos, blip.heading_angle, draw_col, alpha)
		else:
			# Punto normal en la pantalla
			if blip.life > 0.8:
				var pulse_expand: float = (1.0 - (blip.life - 0.8) / 0.2) * (blip.size * 2.0)
				_blips_layer.draw_arc(blip.radar_pos, blip.size + pulse_expand, 0.0, TAU, 16, Color(draw_col, alpha * 0.7), 1.5)

			# Halo exterior brillante
			_blips_layer.draw_circle(blip.radar_pos, blip.size + 1.2, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.45))
			# Núcleo de color
			_blips_layer.draw_circle(blip.radar_pos, blip.size, draw_col)
			# Núcleo blanco de alta intensidad
			var core_col: Color = Color(1.0, 1.0, 1.0, alpha * 0.95)
			_blips_layer.draw_circle(blip.radar_pos, maxf(1.2, blip.size * 0.45), core_col)

func _draw() -> void:
	# Fallback si _blips_layer no estuviera presente
	if not is_instance_valid(_blips_layer):
		_on_blips_layer_draw()

func _draw_satellite_edge_marker(pos: Vector2, angle: float, col: Color, alpha: float) -> void:
	var canvas: CanvasItem = _blips_layer if is_instance_valid(_blips_layer) else self
	var dir: Vector2 = Vector2.from_angle(angle)
	var ortho: Vector2 = Vector2(-dir.y, dir.x)

	var p_tip: Vector2 = pos + dir * 7.0
	var p_left: Vector2 = pos - dir * 5.0 - ortho * 5.0
	var p_right: Vector2 = pos - dir * 5.0 + ortho * 5.0

	var tri: PackedVector2Array = PackedVector2Array([p_tip, p_left, p_right])
	canvas.draw_colored_polygon(tri, col)
	canvas.draw_arc(pos, 8.0, 0.0, TAU, 16, Color(col, alpha * 0.9), 2.0)
