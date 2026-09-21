class_name HitboxComponent
extends Area2D

## HitboxComponent.gd
## Componente ofensivo (Area2D) que proyecta daño e impactos a los HurtboxComponent.
##
## Diseñado para proyectiles balísticos, vigas láser continuas y ataques de contacto.
## Incluye soporte de hit_delay para coordinar invulnerabilidades por tick en penetraciones (Vector 1).

# --- SEÑALES ---
## Emitida cuando el hitbox conecta exitosamente con un HurtboxComponent.
signal hit_landed(hurtbox: HurtboxComponent)

# --- PROPIEDADES EXPORTADAS ---
## Daño base que transmite el impacto.
@export var damage: float = 10.0

## Determina si el impacto es un golpe crítico.
@export var is_critical: bool = false

## Coeficiente de proc (0.0 a 1.0) para la activación de sinergias e ítems on-hit.
@export var proc_coefficient: float = 1.0

## Fuerza de retroceso / knockback aplicada a la entidad impactada.
@export var knockback_force: float = 0.0

## Intervalo mínimo en segundos entre impactos sobre una MISMA hurtbox (Vector 1).
## Evita daño en cada frame físico en vigas continuas o proyectiles perforantes.
@export var hit_delay: float = 0.2


func _init() -> void:
	monitoring = true
	monitorable = true


## Retorna el daño determinista con redondeo y piso mínimo = 1.0.
func get_effective_damage() -> float:
	return maxf(1.0, roundf(damage))
