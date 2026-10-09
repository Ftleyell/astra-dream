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


@onready var station_0: Sprite2D = get_node_or_null("ParallaxStations/Station0")
@onready var station_1: Sprite2D = get_node_or_null("ParallaxStations/Station1")
@onready var station_2: Sprite2D = get_node_or_null("ParallaxStations/Station2")

var _station_nodes: Array[Sprite2D] = []
var _station_base_rotations: PackedFloat32Array = PackedFloat32Array([-0.28, 0.31, -0.16])
var _station_wobble_speeds: PackedFloat32Array = PackedFloat32Array([0.22, 0.18, 0.25])
var _station_wobble_phases: PackedFloat32Array = PackedFloat32Array([0.0, 1.8, 3.5])
var _time_accumulator: float = 0.0

var _rotating_debris: Array[Sprite2D] = []
var _debris_spin_speeds: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	if is_instance_valid(station_0):
		_station_nodes.append(station_0)
	if is_instance_valid(station_1):
		_station_nodes.append(station_1)
	if is_instance_valid(station_2):
		_station_nodes.append(station_2)

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

	if is_instance_valid(parallax_debris_deep):
		parallax_debris_deep.modulate = Color(0.9, 0.9, 1.0, 0.14)
	if is_instance_valid(parallax_debris_mid):
		parallax_debris_mid.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _process(delta: float) -> void:
	_time_accumulator += delta

	# 1. Micro-oscilación orgánica de alabeo en estaciones espaciales (±1.5° en ciclos lentos de ~25s)
	var station_count: int = _station_nodes.size()
	for i: int in range(station_count):
		var st := _station_nodes[i]
		if is_instance_valid(st):
			var base_rot: float = _station_base_rotations[i]
			var w_spd: float = _station_wobble_speeds[i]
			var w_phase: float = _station_wobble_phases[i]
			st.rotation = base_rot + sin(_time_accumulator * w_spd + w_phase) * 0.026

	# 2. Rotación continua de fragmentos de asteroides y chatarra fina
	var total_debris: int = _rotating_debris.size()
	for i: int in range(total_debris):
		_rotating_debris[i].rotation += _debris_spin_speeds[i] * delta

	# 3. Sincronización de perspectiva aérea cósmica y velo intermedio con el bioma activo
	if is_instance_valid(sector_manager):
		var neb_color: Color = sector_manager.get_current_nebula_primary()

		var veil_node: Parallax2D = get_node_or_null("ParallaxCosmicVeil") as Parallax2D
		if is_instance_valid(veil_node):
			var v_sprite: Sprite2D = veil_node.get_node_or_null("VeilSprite") as Sprite2D
			if is_instance_valid(v_sprite):
				v_sprite.modulate = Color(neb_color.r, neb_color.g, neb_color.b, 0.22)

		for st: Sprite2D in _station_nodes:
			if is_instance_valid(st) and st.material is ShaderMaterial:
				(st.material as ShaderMaterial).set_shader_parameter("ambient_haze_color", neb_color)

		# 4. Modulación reactiva de densidad y tono de chatarra según proximidad al Cementerio Mecánico
		var gy_influence: float = sector_manager.get_graveyard_influence()
		var target_deep_alpha: float = lerpf(0.14, 0.88, gy_influence)
		var target_mid_alpha: float = lerpf(0.00, 0.92, gy_influence)
		var industrial_tint: Color = Color(0.85, 0.95, 0.92, 1.0).lerp(Color(0.60, 1.0, 0.85, 1.0), gy_influence * 0.35)

		if is_instance_valid(parallax_debris_deep):
			var cur_deep_a: float = parallax_debris_deep.modulate.a
			parallax_debris_deep.modulate = Color(
				industrial_tint.r,
				industrial_tint.g,
				industrial_tint.b,
				lerpf(cur_deep_a, target_deep_alpha, delta * 3.5)
			)
		if is_instance_valid(parallax_debris_mid):
			var cur_mid_a: float = parallax_debris_mid.modulate.a
			parallax_debris_mid.modulate = Color(
				industrial_tint.r,
				industrial_tint.g,
				industrial_tint.b,
				lerpf(cur_mid_a, target_mid_alpha, delta * 3.5)
			)


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

	# 1. Capa Densa de Fondo Profundo (scroll 0.08, movimiento lento, siluetas diminutas y difusas)
	if is_instance_valid(parallax_debris_deep):
		var area_deep: Vector2 = parallax_debris_deep.repeat_size
		if area_deep == Vector2.ZERO:
			area_deep = Vector2(6144.0, 6144.0)

		var count_deep: int = 68
		for i: int in range(count_deep):
			var tex_path: String = debris_paths[rng.randi_range(0, debris_paths.size() - 1)]
			var tex: Resource = load(tex_path)
			if not tex:
				continue

			var sprite := Sprite2D.new()
			sprite.texture = tex as Texture2D
			sprite.position = Vector2(rng.randf_range(0.0, area_deep.x), rng.randf_range(0.0, area_deep.y))
			sprite.rotation = rng.randf_range(0.0, TAU)

			# Escala diminuta (0.12 - 0.24) para situarla en el fondo remoto
			var s: float = rng.randf_range(0.12, 0.24)
			sprite.scale = Vector2(s, s)
			# Opacidad reducida de fondo (0.25 - 0.48) para no competir con el gameplay
			sprite.modulate = Color(0.85, 0.90, 1.0, rng.randf_range(0.25, 0.48))
			parallax_debris_deep.add_child(sprite)

			var spin_speed: float = rng.randf_range(-0.25, 0.25)
			_rotating_debris.append(sprite)
			_debris_spin_speeds.append(spin_speed)

	# 2. Capa Sutil y Esporádica de Distancia Media (scroll 0.24, solo 18 fragmentos dispersos)
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

			var s: float = rng.randf_range(0.20, 0.36)
			sprite.scale = Vector2(s, s)
			sprite.modulate = Color(0.92, 0.95, 1.0, rng.randf_range(0.38, 0.62))
			parallax_debris_mid.add_child(sprite)

			var spin_speed: float = rng.randf_range(-0.35, 0.35)
			_rotating_debris.append(sprite)
			_debris_spin_speeds.append(spin_speed)

