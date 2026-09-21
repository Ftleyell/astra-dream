class_name HitFlashComponent
extends Node

## HitFlashComponent.gd
## Componente visual de respuesta a impactos (Hit Flash) basado en el Vector 7.
##
## Desacopla la lógica de render/efecto visual del HealthComponent y HurtboxComponent
## escuchando la señal 'damage_taken' y aplicando un destello vía Tween sobre un CanvasItem.

# --- PROPIEDADES EXPORTADAS ---
## Referencia al HealthComponent a escuchar. Si es null, se busca entre hermanos.
@export var health_component: HealthComponent

## Nodo visual objetivo cuyo modulate será alterado (ej. Polygon2D o Sprite2D).
## Si es null, busca un CanvasItem en el nodo padre.
@export var target_visual: CanvasItem

## Color del destello de impacto (por defecto blanco de alta intensidad HDR).
@export var flash_color: Color = Color(3.0, 3.0, 3.0, 1.0)

## Duración en segundos de la recuperación visual tras el impacto.
@export var flash_duration: float = 0.08

## Color base original al que volverá el nodo.
@export var original_color: Color = Color.WHITE

var _current_tween: Tween = null


func _ready() -> void:
	if not health_component:
		health_component = _find_sibling_health_component()

	if not target_visual:
		target_visual = _find_target_visual()

	if target_visual:
		original_color = target_visual.modulate

	if health_component and not health_component.damage_taken.is_connected(_on_damage_taken):
		health_component.damage_taken.connect(_on_damage_taken)


func _on_damage_taken(_amount: float, _is_critical: bool) -> void:
	trigger_flash()


## Ejecuta el efecto visual de hit flash mediante un Tween rápido.
func trigger_flash() -> void:
	if not is_instance_valid(target_visual):
		return

	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	target_visual.modulate = flash_color
	_current_tween = create_tween()
	_current_tween.tween_property(target_visual, "modulate", original_color, flash_duration)


func _find_sibling_health_component() -> HealthComponent:
	var parent_node: Node = get_parent()
	if not parent_node:
		return null
	for child in parent_node.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null


func _find_target_visual() -> CanvasItem:
	var parent_node: Node = get_parent()
	if parent_node is CanvasItem:
		return parent_node as CanvasItem
	if parent_node:
		for child in parent_node.get_children():
			if child is CanvasItem and child != self:
				return child as CanvasItem
	return null
