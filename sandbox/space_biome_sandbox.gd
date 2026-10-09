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



@onready var station_0: Sprite2D = get_node_or_null("ParallaxStations/Station0")
@onready var station_1: Sprite2D = get_node_or_null("ParallaxStations/Station1")
@onready var station_2: Sprite2D = get_node_or_null("ParallaxStations/Station2")

@onready var planet_0: Sprite2D = get_node_or_null("ParallaxPlanets/Planet0")
@onready var planet_1: Sprite2D = get_node_or_null("ParallaxPlanets/Planet1")
@onready var planet_2: Sprite2D = get_node_or_null("ParallaxPlanets/Planet2")
@onready var planet_3: Sprite2D = get_node_or_null("ParallaxPlanets/Planet3")
@onready var galaxy_sprite: Sprite2D = get_node_or_null("ParallaxGalaxy/GalaxySprite")

var _station_nodes: Array[Sprite2D] = []

var _planet_nodes: Array[Sprite2D] = []
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

	if is_instance_valid(planet_0):
		_planet_nodes.append(planet_0)
	if is_instance_valid(planet_1):
		_planet_nodes.append(planet_1)
	if is_instance_valid(planet_2):
		_planet_nodes.append(planet_2)
	if is_instance_valid(planet_3):
		_planet_nodes.append(planet_3)


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

	_setup_debug_hud()



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

	# 2b. Rotación suave y continua de la galaxia profunda sobre su propio eje central (~120s por vuelta)
	if is_instance_valid(galaxy_sprite):
		galaxy_sprite.rotation += 0.05 * delta


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

		for pl: Sprite2D in _planet_nodes:
			if is_instance_valid(pl) and pl.material is ShaderMaterial:
				var sm := pl.material as ShaderMaterial
				sm.set_shader_parameter("biome_tint_color", neb_color)

		if is_instance_valid(galaxy_sprite) and galaxy_sprite.material is ShaderMaterial:
			var g_mat := galaxy_sprite.material as ShaderMaterial
			var target_tint: Color = Color(0.92, 0.90, 1.0, 0.95).lerp(neb_color, 0.35)
			g_mat.set_shader_parameter("tint_color", target_tint)



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
	var mode_text: String = "TRANSICIÓN SUAVE EN CURSO"
	_hud_label.text = "[FONDOS Y BIOMAS ESPACIALES]\n" + \
		"Bioma Activo: %s\n" % active_name + \
		"-----------------------------------------\n" + \
		"[1] Nebulosa Violeta Mística (Púrpura/Azul)\n" + \
		"[2] Aurora Boreal Cósmica (Esmeralda/Cian)\n" + \
		"[3] Nebulosa Ionizada (Carmesí/Dorado)\n" + \
		"[4] Corona Solar (Ámbar/Fuego Estelar)\n" + \
		"[5] Cementerio Mecánico (Verde Industrial/Chatarra)\n" + \
		"[6] Abismo Cuántico (Magenta/Neón Profundo)\n" + \
		"[0] Modo Exploración Libre (Coordenadas Mundo)\n" + \
		"-----------------------------------------\n" + \
		"Rueda Ratón: Zoom | WASD/Flechas: Mover nave\n" + \
		"Shift: Turbo | R: Reset Posición"


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return

	if not is_instance_valid(sector_manager):
		return

	match event.keycode:
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



