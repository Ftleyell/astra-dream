class_name Planet
extends Node2D

## Planet.gd
## Macro-entidad planetaria colosal rediseñada (diámetro 600 px).
## 
## Arquitectura Visual y Mecánica:
## 1. Núcleo central (PlanetCore, radio 55 px) accionable con [E] para obtener BioMasa.
## 2. Manto Interior (Sprite2D con textura generada de interior rocoso/magma/hielo según planeta).
## 3. Corteza Exterior (Sprite2D con shader de erosión y fractura dinámica en 8 sectores).
## 4. Colisión y Daño limpios: 8 sectores angulares (PlanetSector) que deshabilitan su sólido
##    abriendo paso a la nave hacia el interior conforme son destruidos.
## 5. Halo atmosférico suave alrededor del cuerpo celeste.

@export var planet_data: PlanetData
@export var core_radius: float = 55.0
@export var mantle_radius: float = 190.0
@export var crust_radius: float = 300.0
@export var sector_count: int = 8

@export var defender_spawn_interval: float = 6.0
@export var max_defenders: int = 4
@export var nest_trigger_radius: float = 950.0
@export var disable_defenders: bool = false

const PlanetSectorScript := preload("res://scenes/combat/environment/planet_sector.gd")
var sector_scene: PackedScene = preload("res://scenes/combat/environment/planet_sector.tscn")
var drone_scene: PackedScene = preload("res://scenes/combat/enemies/enemy_drone.tscn")

var player: Player = null
var defender_timer: float = 2.0
var active_defenders: Array[Node2D] = []
var atmosphere_color: Color = Color(0.3, 0.7, 1.0, 0.15)

# Array de daño por sector [0.0 = intacto, 1.0 = destruido]
var crust_damage: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var mantle_damage: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

@onready var atmosphere_aura: Node2D = get_node_or_null("AtmosphereAura")
@onready var planet_core: Node2D = get_node_or_null("PlanetCore")
@onready var mantle_sprite: Sprite2D = get_node_or_null("MantleSprite")
@onready var crust_sprite: Sprite2D = get_node_or_null("CrustSprite")
@onready var crust_sectors_container: Node2D = get_node_or_null("CrustSectors")
@onready var mantle_sectors_container: Node2D = get_node_or_null("MantleSectors")


func _ready() -> void:
	add_to_group("planets")
	if not planet_data:
		_pick_random_planet_data()

	_initialize_planet()


func _draw() -> void:
	# Dibujar halo atmosférico celestial etéreo rodeando el planeta
	var atmo_radius: float = crust_radius + 14.0
	draw_arc(Vector2.ZERO, atmo_radius, 0.0, TAU, 64, atmosphere_color, 16.0, true)
	draw_arc(Vector2.ZERO, atmo_radius + 12.0, 0.0, TAU, 64, Color(atmosphere_color.r, atmosphere_color.g, atmosphere_color.b, atmosphere_color.a * 0.4), 8.0, true)


func _pick_random_planet_data() -> void:
	var presets := [
		"res://data/planets/verdant_planet.tres",
		"res://data/planets/volcanic_planet.tres",
		"res://data/planets/cryo_planet.tres"
	]
	var chosen_path: String = presets[randi() % presets.size()]
	if ResourceLoader.exists(chosen_path):
		planet_data = load(chosen_path) as PlanetData


func _initialize_planet() -> void:
	if not planet_data:
		return

	atmosphere_color = Color(planet_data.crust_border_color.r, planet_data.crust_border_color.g, planet_data.crust_border_color.b, 0.22)
	queue_redraw()

	# 1. Configurar Núcleo central
	if planet_core:
		planet_core.setup_core(core_radius, planet_data.core_color, planet_data.core_type, planet_data.core_biomass_reward)

	# 2. Configurar Sprite del Manto / Fondo Interior
	if mantle_sprite:
		if planet_data.interior_texture:
			mantle_sprite.texture = planet_data.interior_texture
		elif planet_data.texture_overlay:
			mantle_sprite.texture = planet_data.texture_overlay
			mantle_sprite.modulate = Color(0.4, 0.35, 0.35, 1.0)
		# Escala para cubrir diámetro 600 px (textura 512x512 -> scale ~1.17)
		mantle_sprite.scale = Vector2((crust_radius * 2.0) / 512.0, (crust_radius * 2.0) / 512.0)
		mantle_sprite.material = null # Fondo celestial que se mantiene intacto sin modificarse

	# 3. Configurar Sprite de la Corteza Exterior con Shader de Fractura
	if crust_sprite:
		crust_sprite.texture = planet_data.texture_overlay
		crust_sprite.scale = Vector2((crust_radius * 2.0) / 512.0, (crust_radius * 2.0) / 512.0)
		_setup_crust_shader()

	# 4. Construir sectores invisibles de colisión y daño
	_build_sectors()


func _setup_crust_shader() -> void:
	if not crust_sprite:
		return
	var shader_res := load("res://core/shaders/planet_crust_destruction.gdshader") as Shader
	if shader_res:
		var mat := ShaderMaterial.new()
		mat.shader = shader_res
		mat.set_shader_parameter("glow_color", planet_data.crust_border_color)
		mat.set_shader_parameter("inner_radius_ratio", mantle_radius / (crust_radius * 2.0))
		mat.set_shader_parameter("outer_radius_ratio", 0.50)
		for i in range(8):
			crust_damage[i] = 0.0
		mat.set_shader_parameter("sector_damage", crust_damage)
		crust_sprite.material = mat


func _build_sectors() -> void:
	if not sector_scene:
		return

	# Limpiar anteriores
	if crust_sectors_container:
		for c in crust_sectors_container.get_children():
			c.queue_free()
	if mantle_sectors_container:
		for c in mantle_sectors_container.get_children():
			c.queue_free()

	var angle_step := TAU / float(sector_count)

	for i in range(sector_count):
		var a_start := angle_step * float(i)
		var a_end := angle_step * float(i + 1)

		# Sector de Corteza (mantle_radius -> crust_radius)
		var sec_c: PlanetSector = null
		if crust_sectors_container:
			sec_c = sector_scene.instantiate() as PlanetSector
			if sec_c:
				crust_sectors_container.add_child(sec_c)
				sec_c.setup_sector(0, i, mantle_radius, crust_radius, a_start, a_end, planet_data.crust_health)
				sec_c.sector_damaged.connect(_on_sector_damaged)

		# Sector de Manto (core_radius -> mantle_radius)
		if mantle_sectors_container:
			var sec_m := sector_scene.instantiate() as PlanetSector
			if sec_m:
				mantle_sectors_container.add_child(sec_m)
				sec_m.setup_sector(1, i, core_radius, mantle_radius, a_start, a_end, planet_data.mid_mantle_health)
				sec_m.sector_damaged.connect(_on_sector_damaged)


func _on_sector_damaged(layer_i: int, sector_i: int, damage_ratio: float) -> void:
	if layer_i == 0:
		crust_damage[sector_i] = damage_ratio
		if crust_sprite and crust_sprite.material is ShaderMaterial:
			(crust_sprite.material as ShaderMaterial).set_shader_parameter("sector_damage", crust_damage)
	elif layer_i == 1:
		mantle_damage[sector_i] = damage_ratio


func disintegrate(shockwave_color: Color = Color.WHITE) -> void:
	# 1. Desactivar nido de defensores y limpiar drones activos
	disable_defenders = true
	for d in active_defenders:
		if is_instance_valid(d):
			d.queue_free()
	active_defenders.clear()

	# 2. Desactivar colisiones físicas y monitoreo de sectores
	if crust_sectors_container:
		for s in crust_sectors_container.get_children():
			if s is PlanetSector:
				s.set_deferred("collision_layer", 0)
				s.set_deferred("collision_mask", 0)
				if s.collision_poly:
					s.collision_poly.set_deferred("disabled", true)
				if s.hurtbox_poly:
					s.hurtbox_poly.set_deferred("disabled", true)
	if mantle_sectors_container:
		for s in mantle_sectors_container.get_children():
			if s is PlanetSector:
				s.set_deferred("collision_layer", 0)
				s.set_deferred("collision_mask", 0)
				if s.collision_poly:
					s.collision_poly.set_deferred("disabled", true)
				if s.hurtbox_poly:
					s.hurtbox_poly.set_deferred("disabled", true)

	remove_from_group("planets")

	# 3. Vaporización estelar con destello cromático
	var tw := create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	var flash_col := Color(
		lerpf(shockwave_color.r, 2.5, 0.7),
		lerpf(shockwave_color.g, 2.5, 0.7),
		lerpf(shockwave_color.b, 3.5, 0.7),
		0.0
	)
	tw.tween_property(self, "modulate", flash_col, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", scale * 1.15, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	# Rotación celestial sincrónica unificada (0.005 rad/s)
	var rot_step: float = delta * 0.005
	rotation += rot_step
	_handle_defender_nest(delta)


func _handle_defender_nest(delta: float) -> void:
	if disable_defenders or not drone_scene or not is_inside_tree():
		return

	for i in range(active_defenders.size() - 1, -1, -1):
		if not is_instance_valid(active_defenders[i]):
			active_defenders.remove_at(i)

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if not player:
			return

	var dist_sq := global_position.distance_squared_to(player.global_position)
	if dist_sq > nest_trigger_radius * nest_trigger_radius:
		return

	defender_timer -= delta
	if defender_timer <= 0.0:
		defender_timer = defender_spawn_interval
		if active_defenders.size() < max_defenders:
			_spawn_defender_drone()


func _spawn_defender_drone() -> void:
	var drone := drone_scene.instantiate() as Node2D
	if not drone:
		return

	var ang := randf() * TAU
	var spawn_pos := global_position + Vector2(cos(ang), sin(ang)) * (crust_radius + 60.0)
	drone.global_position = spawn_pos

	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(drone)
		active_defenders.append(drone)
