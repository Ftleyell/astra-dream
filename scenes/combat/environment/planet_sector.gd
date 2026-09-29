class_name PlanetSector
extends CharacterBody2D

## PlanetSector.gd
## Sector de colisión y recepción de daño para un planeta de 2 capas.
## Capa 0: Corteza Exterior
## Capa 1: Manto Interior
##
## NO DIBUJA polígonos grises ni líneas geométricas feas.
## El aspecto visual del planeta se proyecta 100% mediante los Sprites y Shaders del Planet padre.
## Este nodo maneja exclusivamente:
## - Hitbox (HurtboxComponent) para recibir impactos del jugador.
## - Colisión física sólida (CollisionPolygon2D) contra la nave espacial.
## - Notificación de porcentaje de daño al Planet padre para erosionar el shader.

signal sector_damaged(layer_idx: int, sector_idx: int, damage_ratio: float)
signal sector_destroyed(layer_idx: int, sector_idx: int, pos: Vector2)

@export var layer_idx: int = 0 # 0 = Corteza, 1 = Manto
@export var sector_idx: int = 0 # 0 a 7
@export var max_sector_health: float = 200.0
@export var inner_radius: float = 120.0
@export var outer_radius: float = 300.0
@export var start_angle: float = 0.0
@export var end_angle: float = 0.785398 # TAU / 8
@export var obstacle_radius: float = 60.0

var is_dead: bool = false
var is_dying: bool = false
var centroid: Vector2 = Vector2.ZERO
var biomass_orb_scene: PackedScene = preload("res://scenes/combat/pickups/biomass_orb.tscn")

@onready var collision_poly: CollisionPolygon2D = get_node_or_null("CollisionPolygon2D")
@onready var hurtbox_poly: CollisionPolygon2D = get_node_or_null("HurtboxComponent/CollisionPolygon2D")
@onready var health_component: HealthComponent = get_node_or_null("HealthComponent")
@onready var hurtbox_component: HurtboxComponent = get_node_or_null("HurtboxComponent")
@onready var hit_flash_component: HitFlashComponent = get_node_or_null("HitFlashComponent")


func _ready() -> void:
	add_to_group("destructibles")
	add_to_group("planet_sectors")
	
	# Capa física 1 (sólido contra el jugador), sin máscara para no ser empujado
	collision_layer = 1
	collision_mask = 0
	
	if health_component:
		health_component.max_health = max_sector_health
		health_component.current_health = max_sector_health
		if not health_component.health_changed.is_connected(_on_health_changed):
			health_component.health_changed.connect(_on_health_changed)
		if not health_component.health_depleted.is_connected(_on_health_depleted):
			health_component.health_depleted.connect(_on_health_depleted)
			
	if hurtbox_component and health_component:
		hurtbox_component.health_component = health_component
		
	_build_collision_shape()
	_register_with_bullet_server()


func setup_sector(p_layer: int, p_idx: int, r_in: float, r_out: float, a_start: float, a_end: float, hp: float) -> void:
	layer_idx = p_layer
	sector_idx = p_idx
	inner_radius = r_in
	outer_radius = r_out
	start_angle = a_start
	end_angle = a_end
	max_sector_health = hp
	is_dead = false
	is_dying = false
	
	var mid_a := (start_angle + end_angle) * 0.5
	var mid_r := (inner_radius + outer_radius) * 0.5
	centroid = Vector2(cos(mid_a), sin(mid_a)) * mid_r
	position = centroid
	obstacle_radius = maxf(40.0, (outer_radius - inner_radius) * 0.65)
	
	if health_component:
		health_component.max_health = max_sector_health
		health_component.current_health = max_sector_health
		if not health_component.health_changed.is_connected(_on_health_changed):
			health_component.health_changed.connect(_on_health_changed)
		if not health_component.health_depleted.is_connected(_on_health_depleted):
			health_component.health_depleted.connect(_on_health_depleted)
			
	_build_collision_shape()
	_register_with_bullet_server()


func _build_collision_shape() -> void:
	var pts: PackedVector2Array = []
	var steps: int = 12
	
	# Arco exterior
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var ang := lerpf(start_angle, end_angle, t)
		var p := Vector2(cos(ang), sin(ang)) * outer_radius
		pts.append(p - centroid)
		
	# Arco interior
	for i in range(steps, -1, -1):
		var t := float(i) / float(steps)
		var ang := lerpf(start_angle, end_angle, t)
		var p := Vector2(cos(ang), sin(ang)) * inner_radius
		pts.append(p - centroid)
		
	if collision_poly:
		collision_poly.polygon = pts
	if hurtbox_poly:
		hurtbox_poly.polygon = pts


func _on_health_changed(new_hp: float, max_hp: float) -> void:
	if max_hp <= 0.0 or is_dead or is_dying:
		return
	var damage_ratio: float = 1.0 - clampf(new_hp / max_hp, 0.0, 1.0)
	sector_damaged.emit(layer_idx, sector_idx, damage_ratio)


func _on_health_depleted() -> void:
	if is_dead or is_dying:
		return
	is_dead = true
	is_dying = true
	remove_from_group("destructibles")
	remove_from_group("planet_sectors")
	
	sector_damaged.emit(layer_idx, sector_idx, 1.0)
	sector_destroyed.emit(layer_idx, sector_idx, global_position)
	
	_unregister_from_bullet_server()
	
	# Desactivar colisiones inmediatamente para abrir la brecha a la nave y proyectiles
	collision_layer = 0
	if collision_poly:
		collision_poly.set_deferred("disabled", true)
		collision_poly.disabled = true
	if hurtbox_poly:
		hurtbox_poly.set_deferred("disabled", true)
		hurtbox_poly.disabled = true
	if hurtbox_component:
		hurtbox_component.set_deferred("monitoring", false)
		hurtbox_component.set_deferred("monitorable", false)
		
	# Spawnear orbe de biomasa
	_spawn_biomass()
	
	# Metralla cinemática en la posición del sector
	var shard_script = preload("res://scenes/combat/environment/shrapnel_shard.gd")
	if shard_script:
		var burst_col := Color(0.9, 0.5, 0.2) if layer_idx == 0 else Color(0.4, 0.7, 1.0)
		var p_root: Node = get_tree().current_scene if get_tree() else get_parent()
		shard_script.spawn_shattered_burst(p_root, global_position, layer_idx + 1, -1, burst_col)

	queue_free()


func take_damage(arg) -> void:
	if is_dead or is_dying or not arg:
		return

	var dmg: float = 0.0
	var is_crit: bool = false
	if arg is HitContext:
		dmg = arg.final_damage
		is_crit = arg.is_crit
	elif arg is float or arg is int:
		dmg = float(arg)
	else:
		return
		
	if health_component:
		health_component.take_damage(dmg, is_crit)
	else:
		_on_health_depleted()


func _spawn_biomass() -> void:
	if not biomass_orb_scene or not is_inside_tree():
		return
	var orb := biomass_orb_scene.instantiate() as BiomassOrb
	if not orb:
		return
	var reward: int = 2 if layer_idx == 0 else 4
	orb.setup(reward, global_position)
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(orb)


func _register_with_bullet_server() -> void:
	if not is_inside_tree():
		return
	var bs := get_tree().get_first_node_in_group("bullet_server") as BulletServer
	if not bs and get_tree().current_scene:
		bs = get_tree().current_scene.get_node_or_null("BulletServer") as BulletServer
	if bs and bs.has_method("register_obstacle"):
		var obs_r: float = maxf(40.0, (outer_radius - inner_radius) * 0.5)
		bs.register_obstacle(self, obs_r)


func _unregister_from_bullet_server() -> void:
	if not is_inside_tree():
		return
	var bs := get_tree().get_first_node_in_group("bullet_server") as BulletServer
	if not bs and get_tree().current_scene:
		bs = get_tree().current_scene.get_node_or_null("BulletServer") as BulletServer
	if bs and bs.has_method("unregister_obstacle"):
		bs.unregister_obstacle(self)


func _exit_tree() -> void:
	_unregister_from_bullet_server()
