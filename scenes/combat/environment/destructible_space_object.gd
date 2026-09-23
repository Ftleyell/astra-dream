class_name DestructibleSpaceObject
extends CharacterBody2D

## DestructibleSpaceObject.gd
## Clase base para entidades y objetos espaciales destructibles neutros (Asteroides, chatarra, minas).
##
## Implementa flotación inercial, interfaz canónica take_damage(HitContext),
## integración reactiva con HealthComponent, HurtboxComponent, HitFlashComponent y DropComponent,
## y despawn automático para preservar rendimiento cuando se aleja del jugador.

signal destroyed(object: DestructibleSpaceObject)
signal shattered(pos: Vector2, tier: int)

# --- PROPIEDADES INERCIALES Y BALÍSTICAS ---
@export var drift_velocity: Vector2 = Vector2.ZERO
@export var angular_velocity: float = 0.0
@export var max_distance_from_player: float = 2600.0
@export var obstacle_radius: float = 35.0
@export var tier: int = 1
@export var shard_color: Color = Color(0.85, 0.9, 1.0)

var player: Node2D = null
var is_dying: bool = false
var _despawn_timer: float = 0.0
const DESPAWN_CHECK_RATE: float = 2.0

# --- REFERENCIAS A COMPONENTES ---
@onready var health_component: HealthComponent = get_node_or_null("HealthComponent")
@onready var hurtbox_component: HurtboxComponent = get_node_or_null("HurtboxComponent")
@onready var hit_flash_component: HitFlashComponent = get_node_or_null("HitFlashComponent")
@onready var drop_component: DropComponent = get_node_or_null("DropComponent")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("destructibles")
	_acquire_player()

	# Conexión con HealthComponent
	if not health_component:
		health_component = _find_child_health_component()

	if health_component and not health_component.health_depleted.is_connected(_on_health_depleted):
		health_component.health_depleted.connect(_on_health_depleted)

	# Asignar Hurtbox si existe
	if not hurtbox_component:
		for child in get_children():
			if child is HurtboxComponent:
				hurtbox_component = child
				break
	if hurtbox_component and health_component:
		hurtbox_component.health_component = health_component

	_register_with_bullet_server()


func _exit_tree() -> void:
	_unregister_from_bullet_server()


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	# Movimiento inercial constante
	velocity = drift_velocity
	move_and_slide()
	rotation += angular_velocity * delta

	# Chequeo periódico de despawn fuera de rango
	_despawn_timer += delta
	if _despawn_timer >= DESPAWN_CHECK_RATE:
		_despawn_timer = 0.0
		_check_despawn_range()


## Contrato canónico de combate de Astra Dream
func take_damage(ctx: HitContext) -> void:
	if is_dying or not ctx:
		return

	if health_component:
		health_component.take_damage(ctx.final_damage, ctx.is_crit)
	else:
		# Fallback directo si no tuviese componente
		_die()


func _on_health_depleted() -> void:
	if is_dying:
		return
	_die()


## Método virtual extensible para clases hijas
func _die() -> void:
	if is_dying:
		return
	is_dying = true
	destroyed.emit(self)
	shattered.emit(global_position, tier)

	_unregister_from_bullet_server()

	# Emitir onda de metralla cinemática con retroceso a enemigos
	var shard_script = preload("res://scenes/combat/environment/shrapnel_shard.gd")
	if shard_script:
		shard_script.spawn_shattered_burst(self, global_position, tier, -1, shard_color)

	# Desactivar colisiones inmediatamente
	_disable_collisions()

	# Si DropComponent está presente y no fue accionado automáticamente
	if drop_component and not is_queued_for_deletion():
		drop_component.spawn_drops()

	queue_free()


func _register_with_bullet_server() -> void:
	if not is_inside_tree():
		return
	var bs := get_tree().get_first_node_in_group("bullet_server") as BulletServer
	if not bs and get_tree().current_scene:
		bs = get_tree().current_scene.get_node_or_null("BulletServer") as BulletServer
	if bs and bs.has_method("register_obstacle"):
		bs.register_obstacle(self, obstacle_radius)


func _unregister_from_bullet_server() -> void:
	if not is_inside_tree():
		return
	var bs := get_tree().get_first_node_in_group("bullet_server") as BulletServer
	if not bs and get_tree().current_scene:
		bs = get_tree().current_scene.get_node_or_null("BulletServer") as BulletServer
	if bs and bs.has_method("unregister_obstacle"):
		bs.unregister_obstacle(self)


func _disable_collisions() -> void:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
		elif child is HurtboxComponent:
			child.set_deferred("monitoring", false)
			child.set_deferred("monitorable", false)


func _acquire_player() -> void:
	if not is_instance_valid(player) and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Node2D


func _check_despawn_range() -> void:
	_acquire_player()
	if is_instance_valid(player):
		if global_position.distance_squared_to(player.global_position) > max_distance_from_player * max_distance_from_player:
			queue_free()


func _find_child_health_component() -> HealthComponent:
	for child in get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null
