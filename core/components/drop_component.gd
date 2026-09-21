class_name DropComponent
extends Node

## DropComponent.gd
## Componente para la generación desacoplada de experiencia y botín al morir una entidad.
##
## Conectado reactivamente a la señal 'health_depleted' del HealthComponent.
## Instancia gemas de experiencia (ExpBlob) o consulta tablas de botín (drop_table).

# --- SEÑALES ---
## Emitida cuando se spawnean las recompensas de la entidad.
signal drops_spawned(spawn_position: Vector2, xp: int)

# --- PROPIEDADES EXPORTADAS ---
## Cantidad de experiencia (XP) que otorgará la entidad al morir.
@export var xp_amount: int = 15

## Recurso opcional que define probabilidades y tipos de botines adicionales.
@export var drop_table: Resource = null

## Referencia al HealthComponent a monitorear. Si es null, se busca automáticamente entre hermanos.
@export var health_component: HealthComponent:
	set(val):
		if health_component and health_component.health_depleted.is_connected(_on_health_depleted):
			health_component.health_depleted.disconnect(_on_health_depleted)
		health_component = val
		if health_component and not health_component.health_depleted.is_connected(_on_health_depleted):
			health_component.health_depleted.connect(_on_health_depleted)

## Escena del orbe de experiencia a instanciar en el mapa.
@export var exp_blob_scene: PackedScene = preload("res://scenes/combat/pickups/exp_blob.tscn")

## Probabilidad de que se efectúe la tirada de drops [0.0, 1.0].
@export_range(0.0, 1.0) var drop_chance: float = 1.0


func _ready() -> void:
	if not health_component:
		health_component = _find_sibling_health_component()
	elif not health_component.health_depleted.is_connected(_on_health_depleted):
		health_component.health_depleted.connect(_on_health_depleted)


## Disparador reactivo invocado al vaciarse la salud de la entidad.
func _on_health_depleted() -> void:
	spawn_drops()


## Realiza la instanciación de gemas de XP y botín en la posición global actual.
func spawn_drops() -> void:
	if randf() > drop_chance:
		return

	var spawn_pos: Vector2 = _get_spawn_position()
	var container: Node = _get_drop_container()

	# 1. Instanciación de gema/blob de experiencia
	if xp_amount > 0 and exp_blob_scene and container:
		var blob := exp_blob_scene.instantiate() as Node2D
		if blob:
			if blob.has_method("setup"):
				blob.setup(float(xp_amount), spawn_pos)
			else:
				blob.global_position = spawn_pos
			container.add_child(blob)

	# 2. Soporte para DropTable personalizada si el recurso implementa roll o spawn
	if drop_table and container:
		if drop_table.has_method("spawn_drops"):
			drop_table.spawn_drops(spawn_pos, container)
		elif drop_table.has_method("roll_drop"):
			var custom_drop = drop_table.roll_drop()
			if custom_drop is PackedScene:
				var drop_node := custom_drop.instantiate() as Node2D
				if drop_node:
					drop_node.global_position = spawn_pos
					container.add_child(drop_node)

	drops_spawned.emit(spawn_pos, xp_amount)


func _get_spawn_position() -> Vector2:
	var parent_node: Node = get_parent()
	if parent_node is Node2D:
		return (parent_node as Node2D).global_position
	return Vector2.ZERO


func _get_drop_container() -> Node:
	var entity: Node = get_parent()
	if entity and entity.is_inside_tree():
		var entity_parent: Node = entity.get_parent()
		if entity_parent:
			return entity_parent
	if is_inside_tree():
		if get_tree().current_scene:
			return get_tree().current_scene
		if get_tree().root:
			return get_tree().root
	return null


func _find_sibling_health_component() -> HealthComponent:
	var parent_node: Node = get_parent()
	if not parent_node:
		return null
	for child in parent_node.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null
