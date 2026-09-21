class_name HurtboxComponent
extends Area2D

## HurtboxComponent.gd
## Componente defensivo (Area2D) receptor de daño desacoplado para entidades y jugadores.
##
## Diseñado bajo los principios del documento 'GUIA_ARQUITECTURA_BULLET_HEAVEN_7_VECTORES':
## - Vector 1: Mitigación de saturación física mediante diccionario 'HitBoxDelay' por marcas de tiempo
##   (msec) evitando daño en cada frame físico en vigas continuas y proyectiles penetrantes, con cero GC.
## - Vector 7: Desacoplamiento mediante señales reactivas (hit_received, invulnerability_started/ended).

# --- SEÑALES (Vector 7) ---
## Emitida cuando se acepta y procesa un impacto de un HitboxComponent.
signal hit_received(hitbox: HitboxComponent, damage: float, is_critical: bool)
## Emitida al comenzar un periodo de invulnerabilidad (i-frames).
signal invulnerability_started()
## Emitida al finalizar el periodo de invulnerabilidad.
signal invulnerability_ended()

# --- PROPIEDADES EXPORTADAS ---
## Referencia al HealthComponent asociado que absorberá el daño.
@export var health_component: HealthComponent

## Si es true, el hurtbox ignorará todo impacto entrante.
@export var is_invulnerable: bool = false

## Duración en segundos de invulnerabilidad global (i-frames) otorgada tras recibir daño.
@export var i_frame_time: float = 0.0

## Cooldown por defecto entre impactos de un mismo hitbox si este no define un hit_delay propio.
@export var default_hitbox_delay: float = 0.2

# --- CONTROL DE HITBOX DELAY & I-FRAMES (Vector 1) ---
## Diccionario de HitBoxDelay: { hitbox_instance_id: int -> unlock_time_msec: int }.
## Almacena marcas de tiempo en milisegundos para evitar updates costosos por frame y prevenir GC.
var _hitbox_delays: Dictionary[int, int] = {}

## Buffer estático pre-alocado para limpieza de IDs sin alocación de memoria ni GC (Vector 1).
var _cleanup_buffer: Array[int] = []

## Lista de hitboxes actualmente solapadas para mantener daño continuo en vigas láser y penetraciones.
var _overlapping_hitboxes: Array[HitboxComponent] = []

## Temporizador para la cuenta regresiva de invulnerabilidad (i-frames).
var _i_frame_timer: float = 0.0

## Rastrea si la invulnerabilidad actual fue activada por temporizador i-frame (para no borrar invulnerabilidades externas).
var _invulnerable_via_timer: bool = false


func _init() -> void:
	monitoring = true
	monitorable = true


func _ready() -> void:
	if not health_component:
		health_component = _find_sibling_health_component()

	# Conexiones para seguimiento de entrada y salida de hitboxes continuas/penetrantes
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	# 1. Proceso de temporizador de i-frames
	if _i_frame_timer > 0.0:
		_i_frame_timer -= delta
		if _i_frame_timer <= 0.0:
			_i_frame_timer = 0.0
			if _invulnerable_via_timer:
				is_invulnerable = false
				_invulnerable_via_timer = false
			invulnerability_ended.emit()

	# 2. Verificación periódica de hitboxes que permanecen dentro (láseres continuos o proyectiles perforantes lentos)
	if not _overlapping_hitboxes.is_empty():
		for i in range(_overlapping_hitboxes.size() - 1, -1, -1):
			var hb: HitboxComponent = _overlapping_hitboxes[i]
			if is_instance_valid(hb):
				receive_hit(hb)
			else:
				_overlapping_hitboxes.remove_at(i)


## Método canónico para procesar impactos entrantes de HitboxComponent.
## Retorna true si el golpe fue aceptado y aplicado, o false si fue bloqueado por invulnerabilidad o cooldown.
func receive_hit(hitbox: HitboxComponent) -> bool:
	if not is_instance_valid(hitbox):
		return false

	if is_invulnerable:
		return false

	if not is_instance_valid(health_component):
		health_component = _find_sibling_health_component()
		if not is_instance_valid(health_component):
			return false

	if health_component.is_dead():
		return false

	var now_msec: int = Time.get_ticks_msec()
	var hitbox_id: int = hitbox.get_instance_id()

	# Vector 1: Verificación de HitBoxDelay (previene daño repetido frame a frame)
	if _hitbox_delays.has(hitbox_id):
		if now_msec < _hitbox_delays[hitbox_id]:
			return false

	# Registrar el próximo momento en que este hitbox específico puede volver a causar daño
	var delay_sec: float = hitbox.hit_delay if hitbox.hit_delay > 0.0 else default_hitbox_delay
	_hitbox_delays[hitbox_id] = now_msec + int(delay_sec * 1000.0)

	# Purga esporádica de IDs expirados usando buffer pre-alocado sin GC (Vector 1)
	if _hitbox_delays.size() > 32:
		_clean_expired_delays(now_msec)

	# Aplicar el daño sobre el HealthComponent
	var effective_damage: float = hitbox.get_effective_damage()
	health_component.take_damage(effective_damage, hitbox.is_critical)

	# Iniciar i-frames globales si está configurado
	if i_frame_time > 0.0:
		start_invulnerability(i_frame_time)

	# Notificar desacopladamente mediante señales (Vector 7)
	hit_received.emit(hitbox, effective_damage, hitbox.is_critical)
	if hitbox.has_signal("hit_landed"):
		hitbox.hit_landed.emit(self)

	return true


## Inicia manualmente un intervalo de invulnerabilidad temporal.
func start_invulnerability(duration: float) -> void:
	if duration <= 0.0:
		return
	is_invulnerable = true
	_invulnerable_via_timer = true
	_i_frame_timer = duration
	invulnerability_started.emit()


## Limpia el registro de cooldowns para forzar la aceptación inmediata de nuevos impactos.
func clear_hitbox_delays() -> void:
	_hitbox_delays.clear()
	_cleanup_buffer.clear()
	_overlapping_hitboxes.clear()


func _on_area_entered(area: Area2D) -> void:
	if area is HitboxComponent:
		var hb := area as HitboxComponent
		if not _overlapping_hitboxes.has(hb):
			_overlapping_hitboxes.append(hb)
		receive_hit(hb)


func _on_area_exited(area: Area2D) -> void:
	if area is HitboxComponent:
		_overlapping_hitboxes.erase(area as HitboxComponent)


func _clean_expired_delays(now_msec: int) -> void:
	_cleanup_buffer.clear()
	for id: int in _hitbox_delays:
		if now_msec >= _hitbox_delays[id]:
			_cleanup_buffer.append(id)
	for id: int in _cleanup_buffer:
		_hitbox_delays.erase(id)
	_cleanup_buffer.clear()


func _find_sibling_health_component() -> HealthComponent:
	var parent_node: Node = get_parent()
	if not parent_node:
		return null
	for child in parent_node.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null
