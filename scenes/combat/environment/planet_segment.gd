class_name PlanetSegment
extends CharacterBody2D

## PlanetSegment.gd
## Segmento angular destructible con origen geométrico localizado en su propio centroide.
## Incorpora:
## 1. Colisión física sólida real contra la nave del jugador (CharacterBody2D en collision_layer 1).
## 2. Texturas procedurales diferenciadas de tierra, roca y piedra negra según profundidad geológica.
## 3. Deformación física en 3 fases geométricas discretas (Intacto -> Mellado -> Crítico fragmentado).

signal segment_destroyed(segment: PlanetSegment)

@export var inner_radius: float = 30.0
@export var outer_radius: float = 55.0
@export var start_angle: float = 0.0
@export var end_angle: float = 1.0
@export var segment_color: Color = Color(0.35, 0.45, 0.28, 1.0)
@export var border_color: Color = Color(0.55, 0.75, 0.45, 1.0)
@export var biomass_reward: int = 1
@export var max_segment_health: float = 120.0
@export var layer_type: int = 0 # 0: Corteza (Tierra), 1: Manto Medio (Roca), 2: Manto Profundo (Piedra Negra)

var is_dying: bool = false
var centroid: Vector2 = Vector2.ZERO
var current_fracture_stage: int = 0 # 0: 100-66%, 1: 66-33%, 2: <33%
var biomass_orb_scene: PackedScene = preload("res://scenes/combat/pickups/biomass_orb.tscn")

# Caché estático de texturas de tierra, roca y basalto para alto rendimiento y cero duplicación
static var _soil_texture: ImageTexture = null
static var _rock_texture: ImageTexture = null
static var _black_stone_texture: ImageTexture = null

@onready var visual_polygon: Polygon2D = get_node_or_null("VisualPolygon")
@onready var border_line: Line2D = get_node_or_null("BorderLine")
@onready var collision_poly: CollisionPolygon2D = get_node_or_null("CollisionPolygon2D")
@onready var hurtbox_poly: CollisionPolygon2D = get_node_or_null("HurtboxComponent/CollisionPolygon2D")
@onready var health_component: HealthComponent = get_node_or_null("HealthComponent")
@onready var hurtbox_component: HurtboxComponent = get_node_or_null("HurtboxComponent")
@onready var hit_flash_component: HitFlashComponent = get_node_or_null("HitFlashComponent")


func _ensure_nodes() -> void:
	if not visual_polygon:
		visual_polygon = get_node_or_null("VisualPolygon")
	if not border_line:
		border_line = get_node_or_null("BorderLine")
	if not collision_poly:
		collision_poly = get_node_or_null("CollisionPolygon2D")
	if not hurtbox_poly:
		hurtbox_poly = get_node_or_null("HurtboxComponent/CollisionPolygon2D")
	if not health_component:
		health_component = get_node_or_null("HealthComponent")
	if not hurtbox_component:
		hurtbox_component = get_node_or_null("HurtboxComponent")
	if not hit_flash_component:
		hit_flash_component = get_node_or_null("HitFlashComponent")


func _ready() -> void:
	add_to_group("destructibles")
	_ensure_nodes()

	# Capa 1: Sólido contra la nave del jugador (move_and_slide). Máscara 0 para ser inamovible.
	collision_layer = 1
	collision_mask = 0

	if health_component:
		health_component.max_health = max_segment_health
		health_component.current_health = max_segment_health
		if not health_component.health_depleted.is_connected(_on_health_depleted):
			health_component.health_depleted.connect(_on_health_depleted)
		if not health_component.health_changed.is_connected(_on_health_changed):
			health_component.health_changed.connect(_on_health_changed)

	if hurtbox_component and health_component:
		hurtbox_component.health_component = health_component

	_apply_geological_texture()
	rebuild_geometry()


func setup_segment(r_in: float, r_out: float, a_start: float, a_end: float, col: Color, b_col: Color, hp: float, xp_biomass: int, l_type: int = 0) -> void:
	inner_radius = r_in
	outer_radius = r_out
	start_angle = a_start
	end_angle = a_end
	segment_color = col
	border_color = b_col
	max_segment_health = hp
	biomass_reward = xp_biomass
	layer_type = l_type
	current_fracture_stage = 0

	# Calcular el centroide geométrico del sector angular
	var mid_angle := (start_angle + end_angle) * 0.5
	var mid_radius := (inner_radius + outer_radius) * 0.5
	centroid = Vector2(cos(mid_angle), sin(mid_angle)) * mid_radius

	# Posicionar el nodo en su centroide para que su global_position sea real en el espacio
	position = centroid

	_ensure_nodes()
	if health_component:
		health_component.max_health = max_segment_health
		health_component.current_health = max_segment_health
		if not health_component.health_depleted.is_connected(_on_health_depleted):
			health_component.health_depleted.connect(_on_health_depleted)
		if not health_component.health_changed.is_connected(_on_health_changed):
			health_component.health_changed.connect(_on_health_changed)
	_apply_geological_texture()
	rebuild_geometry()


## Genera o recupera texturas estáticas procedurales para tierra, roca y piedra negra
static func _get_layer_texture(p_layer: int) -> ImageTexture:
	const TEX_SIZE: int = 64
	match p_layer:
		0:
			# Textura de Tierra / Suelo orgánico: gránulos y porosidad cálida
			if not _soil_texture:
				var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
				var fn := FastNoiseLite.new()
				fn.noise_type = FastNoiseLite.TYPE_PERLIN
				fn.frequency = 0.08
				for y in range(TEX_SIZE):
					for x in range(TEX_SIZE):
						var v := (fn.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
						var c := Color(0.85 + v * 0.15, 0.75 + v * 0.25, 0.65 + v * 0.35, 1.0)
						img.set_pixel(x, y, c)
				_soil_texture = ImageTexture.create_from_image(img)
			return _soil_texture
		1:
			# Textura de Roca intermedia: estrías y asperezas minerales
			if not _rock_texture:
				var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
				var fn := FastNoiseLite.new()
				fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
				fn.frequency = 0.12
				for y in range(TEX_SIZE):
					for x in range(TEX_SIZE):
						var v := (fn.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
						var c := Color(0.7 + v * 0.3, 0.7 + v * 0.3, 0.72 + v * 0.28, 1.0)
						img.set_pixel(x, y, c)
				_rock_texture = ImageTexture.create_from_image(img)
			return _rock_texture
		2:
			# Textura de Piedra Negra profunda: celdas basálticas y obsidiana
			if not _black_stone_texture:
				var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
				var fn := FastNoiseLite.new()
				fn.noise_type = FastNoiseLite.TYPE_CELLULAR
				fn.frequency = 0.15
				for y in range(TEX_SIZE):
					for x in range(TEX_SIZE):
						var v := (fn.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
						var c := Color(0.4 + v * 0.6, 0.4 + v * 0.6, 0.45 + v * 0.55, 1.0)
						img.set_pixel(x, y, c)
				_black_stone_texture = ImageTexture.create_from_image(img)
			return _black_stone_texture
	return null


func _apply_geological_texture() -> void:
	if not visual_polygon:
		return
	var tex := _get_layer_texture(layer_type)
	if tex:
		visual_polygon.texture = tex
		visual_polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		visual_polygon.texture_scale = Vector2(0.35, 0.35)


## Monitor de salud para activar las 3 etapas de degradación geométrica
func _on_health_changed(new_hp: float, max_hp: float) -> void:
	if max_hp <= 0.0 or is_dying:
		return

	var ratio := new_hp / max_hp
	var target_stage := 0
	if ratio < 0.33:
		target_stage = 2 # Crítico fragmentado
	elif ratio < 0.66:
		target_stage = 1 # Cuarteado / Mellado

	if target_stage != current_fracture_stage:
		current_fracture_stage = target_stage
		rebuild_geometry()


## Construye el polígono en coordenadas locales respecto al centroide del gajo
## Aplica deformación física y muescas según la fase de fractura
func rebuild_geometry() -> void:
	var pts: PackedVector2Array = []
	var steps: int = 8 # Resolución del arco para mallas melladas

	var radial_depth := outer_radius - inner_radius

	# Arco exterior respecto al centroide local según la fase de degradación
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var ang := lerpf(start_angle, end_angle, t)

		var cur_outer_r: float = outer_radius

		match current_fracture_stage:
			0:
				# Fase 0 (Intacto): Arco concéntrico perfecto
				cur_outer_r = outer_radius
			1:
				# Fase 1 (Cuarteado / Mellado, 66%-33% HP):
				# Retracción del ~18% con muescas angulares en vértices impares
				var base_eroded := outer_radius - radial_depth * 0.18
				var notch := 0.0
				if i % 2 == 1:
					var p_seed := sin(float(i) * 2.7 + start_angle * 5.3)
					notch = radial_depth * 0.12 * absf(p_seed)
				cur_outer_r = maxf(inner_radius + 4.0, base_eroded - notch)
			2:
				# Fase 2 (Crítico fragmentado, <33% HP):
				# Retracción del ~42% con grietas profundas y perfil aserrado
				var base_eroded := outer_radius - radial_depth * 0.42
				var notch := 0.0
				if i % 2 == 1:
					var p_seed := sin(float(i) * 3.4 + start_angle * 8.7)
					notch = radial_depth * 0.22 * absf(p_seed)
				cur_outer_r = maxf(inner_radius + 4.0, base_eroded - notch)

		var pt_from_planet := Vector2(cos(ang), sin(ang)) * cur_outer_r
		pts.append(pt_from_planet - centroid)

	# Arco interior respecto al centroide local
	for i in range(steps, -1, -1):
		var t := float(i) / float(steps)
		var ang := lerpf(start_angle, end_angle, t)
		var pt_from_planet := Vector2(cos(ang), sin(ang)) * inner_radius
		pts.append(pt_from_planet - centroid)

	if visual_polygon:
		visual_polygon.polygon = pts
		visual_polygon.color = segment_color

	if border_line:
		border_line.clear_points()
		for p in pts:
			border_line.add_point(p)
		if pts.size() > 0:
			border_line.add_point(pts[0])

		# Ajuste visual del borde según el estado de cuarteado
		match current_fracture_stage:
			0:
				border_line.default_color = border_color
				border_line.width = 2.0
			1:
				border_line.default_color = border_color.lightened(0.25)
				border_line.width = 2.4
			2:
				border_line.default_color = Color(1.0, 0.4, 0.3, 0.95) # Borde incandescente/fracturado
				border_line.width = 2.8

	# Sincronización exacta de colisión física (bloqueo al jugador) y hurtbox (área de daño)
	if collision_poly:
		collision_poly.polygon = pts
	if hurtbox_poly:
		hurtbox_poly.polygon = pts


## Contrato canónico de combate
func take_damage(ctx: HitContext) -> void:
	if is_dying or not ctx:
		return
	if health_component:
		health_component.take_damage(ctx.final_damage, ctx.is_crit)
	else:
		_die()


func _on_health_depleted() -> void:
	_die()


func _die() -> void:
	if is_dying:
		return
	is_dying = true
	segment_destroyed.emit(self)

	# Desactivar colisiones inmediatamente
	if collision_poly:
		collision_poly.set_deferred("disabled", true)
	if hurtbox_component:
		hurtbox_component.set_deferred("monitoring", false)
		hurtbox_component.set_deferred("monitorable", false)

	# 1. Liberar orbe de BioMasa en la posición del gajo
	_spawn_biomass()

	# 2. Desprendimiento radial outward
	var outward_dir := centroid.normalized() if centroid.length_squared() > 0.01 else Vector2.RIGHT

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + outward_dir * 50.0, 0.25)
	tween.tween_property(self, "scale", scale * 1.2, 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func _spawn_biomass() -> void:
	if not biomass_orb_scene:
		return

	var orb := biomass_orb_scene.instantiate() as BiomassOrb
	if not orb:
		return

	orb.setup(biomass_reward, global_position)
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(orb)
