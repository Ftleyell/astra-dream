class_name HealthComponent
extends Node

## HealthComponent.gd
## Componente desacoplado para gestión de vida y daño en arquitecturas Bullet Heaven.
##
## Diseñado bajo los principios del documento 'GUIA_ARQUITECTURA_BULLET_HEAVEN_7_VECTORES':
## - Vector 1: Cero asignaciones de memoria y GC en take_damage(). Determinismo numérico
##   y piso de daño mínimo = 1.0 (evita daño cero o flotantes no deterministas).
## - Vector 7: Desacoplamiento total mediante señales (hit flash, HUD, SFX, muerte).

# --- SEÑALES (Vector 7) ---
## Emitida cuando la vida actual cambia tras daño o curación.
signal health_changed(new_health: float, max_health: float)
## Emitida exactamente una vez cuando la vida se reduce a 0.
signal health_depleted()
## Emitida al sufrir daño para activar hit flash, audio o popups numéricos.
signal damage_taken(amount: float, is_critical: bool)

# --- PROPIEDADES EXPORTADAS ---
## Salud máxima de la entidad.
@export var max_health: float = 100.0:
	set(val):
		var prev_max: float = max_health
		max_health = maxf(1.0, roundf(val))
		if is_inside_tree():
			var prev_health: float = current_health
			current_health = clampf(current_health, 0.0, max_health)
			if current_health != prev_health or max_health != prev_max:
				health_changed.emit(current_health, max_health)

## Salud actual de la entidad.
@export var current_health: float = 100.0:
	set(val):
		var target: float = clampf(roundf(val), 0.0, max_health)
		if current_health == target:
			return
		current_health = target
		if is_inside_tree() and not _modifying_internally:
			health_changed.emit(current_health, max_health)
			if current_health <= 0.0 and not is_depleted:
				is_depleted = true
				health_depleted.emit()
			elif current_health > 0.0 and is_depleted:
				is_depleted = false

## Estado interno que garantiza que health_depleted se emita una sola vez.
var is_depleted: bool = false

## Bandera interna para evitar emisiones duplicadas de señales durante take_damage y heal.
var _modifying_internally: bool = false


func _ready() -> void:
	max_health = maxf(1.0, roundf(max_health))
	current_health = clampf(roundf(current_health), 0.0, max_health)
	is_depleted = (current_health <= 0.0)


## Aplica daño entrante siguiendo los principios de optimización de Vector 1.
## Garantiza daño truncado/redondeado a enteros deterministas, piso mínimo de 1.0 y cero GC.
func take_damage(amount: float, is_critical: bool = false) -> void:
	if is_depleted or current_health <= 0.0 or amount <= 0.0:
		return

	# Vector 1: Redondeo determinista y piso de daño mínimo = 1.0
	var effective_damage: float = maxf(1.0, roundf(amount))

	_modifying_internally = true
	current_health = maxf(0.0, current_health - effective_damage)
	_modifying_internally = false

	# Vector 7: Desacoplamiento mediante emisión de señales
	damage_taken.emit(effective_damage, is_critical)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0 and not is_depleted:
		is_depleted = true
		health_depleted.emit()


## Aplica curación a la entidad sin exceder max_health ni revivir si ya falleció.
func heal(amount: float) -> void:
	if is_depleted or current_health <= 0.0 or amount <= 0.0:
		return

	var effective_heal: float = roundf(amount)
	if effective_heal <= 0.0:
		return

	var prev_health: float = current_health
	_modifying_internally = true
	current_health = minf(max_health, current_health + effective_heal)
	_modifying_internally = false

	if current_health != prev_health:
		health_changed.emit(current_health, max_health)


## Restaura la salud y resetea el estado de agotamiento si se requiere respawn.
func revive(full_health: bool = true, custom_amount: float = 0.0) -> void:
	is_depleted = false
	if full_health:
		current_health = max_health
	else:
		current_health = clampf(roundf(custom_amount), 1.0, max_health)
	health_changed.emit(current_health, max_health)


## Retorna true si la salud está totalmente agotada.
func is_dead() -> bool:
	return is_depleted or current_health <= 0.0


## Retorna el porcentaje de salud restante en el rango [0.0, 1.0].
func get_health_percent() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0
