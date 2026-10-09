class_name SpaceBiomeSandbox
extends Node2D

## space_biome_sandbox.gd
## Orquestador del sandbox de pruebas de fondos y biomas cósmicos continuos.
## Registra los sectores espaciales con interpolación quíntica C2 y vincula la nave de prueba.

@onready var sector_manager: SectorManager = $SectorManager
@onready var cosmic_quad: ColorRect = $CanvasLayer/CosmicBackgroundQuad
@onready var ship: SandboxShip = $SandboxShip
@onready var parallax_debris_deep: Parallax2D = get_node_or_null("ParallaxDebrisDeep")
@onready var parallax_debris_mid: Parallax2D = get_node_or_null("ParallaxDebrisMid")

const BIOME_NEUTRAL = preload("res://assets/environments/parallax_space/biomes/neutral_space.tres")
const BIOME_IONIZED = preload("res://assets/environments/parallax_space/biomes/ionized_nebula.tres")
const BIOME_GRAVEYARD = preload("res://assets/environments/parallax_space/biomes/mechanical_graveyard.tres")
const BIOME_QUANTUM = preload("res://assets/environments/parallax_space/biomes/quantum_abyss.tres")
const BIOME_SOLAR = preload("res://assets/environments/parallax_space/biomes/solar_corona.tres")
const BIOME_VIOLET = preload("res://assets/environments/parallax_space/biomes/mystic_violet.tres")
const BIOME_AURORA = preload("res://assets/environments/parallax_space/biomes/cosmic_aurora.tres")



@onready var cosmic_pool: CosmicObjectPool = get_node_or_null("CosmicObjectPool") as CosmicObjectPool
@onready var cosmic_director: Node2D = get_node_or_null("CosmicSocketDirector") as Node2D
@onready var cosmic_virtualizer: Node2D = get_node_or_null("CosmicSocketDirector") as Node2D



const SpaceEnvironmentConfigScript = preload("res://core/resources/space_environment_config.gd")
@export var env_config: Resource = preload("res://data/environment/default_space_environment_config.tres")

var _time_accumulator: float = 0.0
var _accum_drift: Vector2 = Vector2.ZERO

var _rotating_debris: Array[Sprite2D] = []
var _debris_spin_speeds: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:


	if not sector_manager:
		return

	sector_manager.neutral_biome = BIOME_NEUTRAL
	sector_manager.cosmic_quad = cosmic_quad
	sector_manager.ship_reference = ship

	# Distribución pentagonal de sectores cósmicos (~10-12s de vuelo a 750 px/s)
	# 1. Nebulosa Ionizada (Noreste: carmesí / filamentos dorados)
	sector_manager.register_sector(Vector2(6500.0, -3200.0), 4800.0, 2200.0, BIOME_IONIZED)

	# 2. Corona Solar (Noroeste: oro brillante / energía solar)
	sector_manager.register_sector(Vector2(-6500.0, -3200.0), 4800.0, 2200.0, BIOME_SOLAR)

	# 3. Cementerio Mecánico (Suroeste: turquesa / verde esmeralda industrial)
	sector_manager.register_sector(Vector2(-6500.0, 4200.0), 4800.0, 2200.0, BIOME_GRAVEYARD)

	# 4. Abismo Cuántico (Sureste: violeta / magenta eléctrico / aberración cromática)
	sector_manager.register_sector(Vector2(6500.0, 4200.0), 4800.0, 2200.0, BIOME_QUANTUM)

	_populate_debris_field()

	if is_instance_valid(env_config):
		if is_instance_valid(parallax_debris_deep):
			parallax_debris_deep.scroll_scale = env_config.parallax_layer1_deep_scroll
		if is_instance_valid(parallax_debris_mid):
			parallax_debris_mid.scroll_scale = env_config.parallax_layer2_mid_scroll
		var init_veil: Parallax2D = get_node_or_null("ParallaxCosmicVeil") as Parallax2D
		if is_instance_valid(init_veil):
			init_veil.scroll_scale = env_config.parallax_layer3_near_scroll
		if is_instance_valid(cosmic_quad) and cosmic_quad.material is ShaderMaterial:
			(cosmic_quad.material as ShaderMaterial).set_shader_parameter("nebula_scroll_scale", env_config.parallax_layer0_nebula_scroll.x)

	if is_instance_valid(parallax_debris_deep):
		parallax_debris_deep.modulate = Color(0.9, 0.9, 1.0, 0.14)
	if is_instance_valid(parallax_debris_mid):
		parallax_debris_mid.modulate = Color(1.0, 1.0, 1.0, 0.0)

	_setup_debug_hud()



func _process(delta: float) -> void:
	_time_accumulator += delta

	# 0. Deriva cósmica continua multi-capa
	if is_instance_valid(env_config):
		_accum_drift += env_config.drift_direction * (env_config.base_drift_speed * delta)
		if is_instance_valid(parallax_debris_deep):
			parallax_debris_deep.scroll_offset = _accum_drift * env_config.parallax_layer1_drift_factor
		if is_instance_valid(parallax_debris_mid):
			parallax_debris_mid.scroll_offset = _accum_drift * env_config.parallax_layer2_drift_factor
		var cur_veil: Parallax2D = get_node_or_null("ParallaxCosmicVeil") as Parallax2D
		if is_instance_valid(cur_veil):
			cur_veil.scroll_offset = _accum_drift * env_config.parallax_layer3_drift_factor

	# 1. Rotación continua de fragmentos de asteroides y chatarra fina
	var total_debris: int = _rotating_debris.size()
	for i: int in range(total_debris):
		_rotating_debris[i].rotation += _debris_spin_speeds[i] * delta

	# 2. Sincronización de perspectiva aérea cósmica y velo intermedio con el bioma activo
	if is_instance_valid(sector_manager):
		var neb_color: Color = sector_manager.get_current_nebula_primary()

		var veil_node: Parallax2D = get_node_or_null("ParallaxCosmicVeil") as Parallax2D
		if is_instance_valid(veil_node):
			var v_sprite: Sprite2D = veil_node.get_node_or_null("VeilSprite") as Sprite2D
			if is_instance_valid(v_sprite):
				v_sprite.modulate = Color(neb_color.r, neb_color.g, neb_color.b, 0.22)

		# 3. Actualización de Generación Cósmica de Zócalos Solares y Pooling
		var cam_pos: Vector2 = ship.global_position if is_instance_valid(ship) else Vector2.ZERO
		if is_instance_valid(cosmic_director):
			cosmic_director.update_camera_position(cam_pos)
		if is_instance_valid(cosmic_pool):
			cosmic_pool.update_parallax_positions(cam_pos, delta, neb_color)
		if is_instance_valid(cosmic_director):
			var vp_size: Vector2 = get_viewport_rect().size
			var cam_zoom: Vector2 = ship.camera.zoom if is_instance_valid(ship) and is_instance_valid(ship.camera) else Vector2.ONE
			cosmic_director.apply_viewport_arbitration(cam_pos, vp_size, cam_zoom)


		# 4. Modulación reactiva de densidad y tono de chatarra según proximidad al Cementerio Mecánico
		var gy_influence: float = sector_manager.get_graveyard_influence()
		var target_deep_alpha: float = lerpf(0.65, 0.95, gy_influence)
		var target_mid_alpha: float = lerpf(0.50, 0.90, gy_influence)
		var base_debris_color: Color = Color(0.92, 0.94, 0.98, 1.0)
		var industrial_tint: Color = base_debris_color.lerp(Color(0.70, 1.0, 0.88, 1.0), gy_influence * 0.45)

		if is_instance_valid(parallax_debris_deep):
			var cur_deep_a: float = parallax_debris_deep.modulate.a
			parallax_debris_deep.modulate = Color(
				industrial_tint.r,
				industrial_tint.g,
				industrial_tint.b,
				lerpf(cur_deep_a, target_deep_alpha, delta * 3.0)
			)
		if is_instance_valid(parallax_debris_mid):
			var cur_mid_a: float = parallax_debris_mid.modulate.a
			parallax_debris_mid.modulate = Color(
				industrial_tint.r,
				industrial_tint.g,
				industrial_tint.b,
				lerpf(cur_mid_a, target_mid_alpha, delta * 3.0)
			)

	_update_hud_display()




var _hud_label: Label = null

func _setup_debug_hud() -> void:
	var canvas := get_node_or_null("CanvasLayer")
	if not is_instance_valid(canvas):
		return

	var panel := PanelContainer.new()
	panel.name = "BiomeDebugPanel"
	panel.anchors_preset = Control.PRESET_TOP_LEFT
	panel.position = Vector2(24, 24)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hud_label = Label.new()
	_hud_label.name = "BiomeInfoLabel"
	_hud_label.text = "Iniciando..."
	_hud_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.95))
	_hud_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_hud_label.add_theme_constant_override("shadow_offset_x", 1)
	_hud_label.add_theme_constant_override("shadow_offset_y", 1)

	panel.add_child(_hud_label)
	canvas.add_child(panel)


func _update_hud_display() -> void:
	if not is_instance_valid(_hud_label) or not is_instance_valid(sector_manager):
		return

	var active_name: String = sector_manager.get_active_biome_name()
	var pool_info: String = ""
	if is_instance_valid(cosmic_pool):
		pool_info = "Objetos Cósmicos Activos: %d / %d (Disponibles: %d)\n" % [
			cosmic_pool.get_active_count(),
			cosmic_pool.pool_capacity,
			cosmic_pool.get_available_count()
		]

	var coords_info: String = ""
	if is_instance_valid(ship) and is_instance_valid(cosmic_director):
		var ship_pos: Vector2 = ship.global_position
		var sock_c: Vector2i = cosmic_director.get_socket_coord(ship_pos)
		var active_sockets: int = cosmic_director.get_active_sockets_count()
		coords_info = "Pos: (%.0f, %.0f) | Zócalo Solar: (%d, %d) [Activos: %d]\n" % [
			ship_pos.x, ship_pos.y, sock_c.x, sock_c.y, active_sockets
		]

	var fps_info: String = "FPS: %d\n" % Engine.get_frames_per_second()

	_hud_label.text = "[FONDOS Y ZÓCALOS SOLARES CÓSMICOS]\n" + \
		fps_info + coords_info + pool_info + \
		"Bioma Activo: %s\n" % active_name + \
		"-----------------------------------------\n" + \
		"[1] Nebulosa Violeta Mística | [2] Aurora Boreal\n" + \
		"[3] Nebulosa Ionizada        | [4] Corona Solar\n" + \
		"[5] Cementerio Mecánico      | [6] Abismo Cuántico\n" + \
		"[S] Salto Sol Zócalo         | [B] Agujero Negro | [P] Púlsar | [G] Galaxia\n" + \
		"[0] Modo Libre (Mundo)\n" + \
		"-----------------------------------------\n" + \
		"WASD: Nave | Shift: Turbo (1600px/s) | Rueda: Zoom | R: Reset"


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return

	if not is_instance_valid(sector_manager):
		return

	match event.keycode:
		KEY_S:
			if is_instance_valid(ship) and is_instance_valid(cosmic_director):
				var cur_coord: Vector2i = cosmic_director.get_socket_coord(ship.global_position)
				var sun_pos: Vector2 = cosmic_director.get_socket_center_pos(cur_coord)
				ship.global_position = sun_pos
				ship.velocity = Vector2.ZERO
		KEY_G:
			if is_instance_valid(ship) and is_instance_valid(cosmic_director):
				var gal_pos: Vector2 = cosmic_director.find_nearest_phenomenon("galaxy", ship.global_position, 25)
				if gal_pos != Vector2.ZERO:
					ship.global_position = gal_pos
					ship.velocity = Vector2.ZERO
		KEY_P:
			if is_instance_valid(ship) and is_instance_valid(cosmic_director):
				var pulsar_pos: Vector2 = cosmic_director.find_nearest_phenomenon("pulsar", ship.global_position, 25)
				if pulsar_pos != Vector2.ZERO:
					ship.global_position = pulsar_pos
					ship.velocity = Vector2.ZERO
		KEY_B:
			if is_instance_valid(ship) and is_instance_valid(cosmic_director):
				var bh_pos: Vector2 = cosmic_director.find_nearest_phenomenon("black_hole", ship.global_position, 25)
				if bh_pos != Vector2.ZERO:
					ship.global_position = bh_pos
					ship.velocity = Vector2.ZERO

		KEY_1:
			sector_manager.blend_speed = 1.0 # Transición suave tipo caminata
			sector_manager.force_biome(BIOME_VIOLET)
		KEY_2:
			sector_manager.blend_speed = 1.0
			sector_manager.force_biome(BIOME_AURORA)
		KEY_3:
			sector_manager.blend_speed = 1.0
			sector_manager.force_biome(BIOME_IONIZED)
		KEY_4:
			sector_manager.blend_speed = 1.0
			sector_manager.force_biome(BIOME_SOLAR)
		KEY_5:
			sector_manager.blend_speed = 1.0
			sector_manager.force_biome(BIOME_GRAVEYARD)
		KEY_6:
			sector_manager.blend_speed = 1.0
			sector_manager.force_biome(BIOME_QUANTUM)
		KEY_0:
			sector_manager.blend_speed = 1.5
			sector_manager.clear_forced_biome()



func _populate_debris_field() -> void:
	var debris_dir_path: String = "res://assets/environments/parallax_space/atlas_textures"
	var dir := DirAccess.open(debris_dir_path)
	var debris_paths: Array[String] = []
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				debris_paths.append(debris_dir_path + "/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	if debris_paths.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 1337

	_rotating_debris.clear()
	_debris_spin_speeds.clear()

	# 1. Capa Profunda (scroll 0.08, movimiento lento, fragmentos medianos)
	if is_instance_valid(parallax_debris_deep):
		var area_deep: Vector2 = parallax_debris_deep.repeat_size
		if area_deep == Vector2.ZERO:
			area_deep = Vector2(6144.0, 6144.0)

		var count_deep: int = 45
		for i: int in range(count_deep):
			var tex_path: String = debris_paths[rng.randi_range(0, debris_paths.size() - 1)]
			var tex: Resource = load(tex_path)
			if not tex:
				continue

			var sprite := Sprite2D.new()
			sprite.texture = tex as Texture2D
			sprite.position = Vector2(rng.randf_range(0.0, area_deep.x), rng.randf_range(0.0, area_deep.y))
			sprite.rotation = rng.randf_range(0.0, TAU)

			# Escala claramente visible (0.22 - 0.38)
			var s: float = rng.randf_range(0.22, 0.38)
			sprite.scale = Vector2(s, s)
			sprite.modulate = Color(0.85, 0.88, 0.95, rng.randf_range(0.65, 0.85))
			parallax_debris_deep.add_child(sprite)

			var spin_speed: float = rng.randf_range(-0.18, 0.18)
			_rotating_debris.append(sprite)
			_debris_spin_speeds.append(spin_speed)

	# 2. Capa Media (scroll 0.14, fragmentos más cercanos y definidos)
	if is_instance_valid(parallax_debris_mid):
		var area_mid: Vector2 = parallax_debris_mid.repeat_size
		if area_mid == Vector2.ZERO:
			area_mid = Vector2(6144.0, 6144.0)

		var count_mid: int = 18
		for i: int in range(count_mid):
			var tex_path: String = debris_paths[rng.randi_range(0, debris_paths.size() - 1)]
			var tex: Resource = load(tex_path)
			if not tex:
				continue

			var sprite := Sprite2D.new()
			sprite.texture = tex as Texture2D
			sprite.position = Vector2(rng.randf_range(0.0, area_mid.x), rng.randf_range(0.0, area_mid.y))
			sprite.rotation = rng.randf_range(0.0, TAU)

			# Escala nítida y presente (0.35 - 0.55)
			var s: float = rng.randf_range(0.35, 0.55)
			sprite.scale = Vector2(s, s)
			sprite.modulate = Color(0.92, 0.94, 1.0, rng.randf_range(0.70, 0.90))
			parallax_debris_mid.add_child(sprite)

			var spin_speed: float = rng.randf_range(-0.25, 0.25)
			_rotating_debris.append(sprite)
			_debris_spin_speeds.append(spin_speed)



