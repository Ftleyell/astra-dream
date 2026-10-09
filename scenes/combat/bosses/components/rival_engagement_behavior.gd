class_name RivalEngagementBehavior
extends RefCounted

## RivalEngagementBehavior.gd
## Máquina de estados desacoplada para encuentros con Pilotos Rivales.
## Gestiona umbrales de proximidad, temporizador de reto violento vs perdón pacífico.

signal state_changed(old_state: int, new_state: int)
signal combat_engaged(pilot_id: StringName)
signal warped_out_peacefully(pilot_id: StringName, pilot_name: String)

enum State {
	WARPING_IN,
	PEACEFUL_WARN,
	DOGFIGHT,
	WARPING_OUT,
	DYING
}

const WARNING_RADIUS: float = 650.0
const COMBAT_TRIGGER_RADIUS: float = 480.0
const ESCAPE_RADIUS: float = 1450.0
const SPARED_REQUIRED_TIME: float = 5.0
const CHALLENGE_REQUIRED_TIME: float = 2.0

var current_state: State = State.WARPING_IN:
	set(val):
		if current_state != val:
			var prev: State = current_state
			current_state = val
			state_changed.emit(prev, current_state)

var pilot_id: StringName = &"nova"
var pilot_name: String = "Nova"
var spared_timer: float = 0.0
var challenge_timer: float = 0.0

func setup(p_id: StringName, p_name: String) -> void:
	pilot_id = p_id
	pilot_name = p_name
	current_state = State.WARPING_IN
	spared_timer = 0.0
	challenge_timer = 0.0

func start_encounter() -> void:
	current_state = State.PEACEFUL_WARN
	spared_timer = 0.0
	challenge_timer = 0.0

func is_peaceful() -> bool:
	return current_state != State.DOGFIGHT

func process_peaceful_warn(delta: float, dist_to_player: float) -> void:
	if current_state != State.PEACEFUL_WARN:
		return

	# Condición de combate: entrar y permanecer en la zona de desafío durante CHALLENGE_REQUIRED_TIME
	if dist_to_player <= COMBAT_TRIGGER_RADIUS:
		challenge_timer += delta
		spared_timer = 0.0
		if challenge_timer >= CHALLENGE_REQUIRED_TIME:
			engage_combat()
		return
	else:
		challenge_timer = maxf(0.0, challenge_timer - delta * 1.5)

	# Condición de perdón: el jugador se aleja (> ESCAPE_RADIUS)
	if dist_to_player >= ESCAPE_RADIUS:
		spared_timer += delta
		if spared_timer >= SPARED_REQUIRED_TIME:
			_warp_out_peacefully()
	else:
		spared_timer = maxf(0.0, spared_timer - delta * 0.8)

func engage_combat() -> void:
	if current_state == State.DOGFIGHT:
		return
	current_state = State.DOGFIGHT
	combat_engaged.emit(pilot_id)

func _warp_out_peacefully() -> void:
	if current_state == State.WARPING_OUT:
		return
	current_state = State.WARPING_OUT
	warped_out_peacefully.emit(pilot_id, pilot_name)

func get_warning_text() -> String:
	if current_state == State.PEACEFUL_WARN:
		if challenge_timer > 0.0:
			var remaining: float = maxf(0.0, CHALLENGE_REQUIRED_TIME - challenge_timer)
			return "⚔️ RETANDO A %s (%.1fs)...\n[ Permanece en el anillo para iniciar combate ]" % [pilot_name.to_upper(), remaining]
		elif spared_timer > 0.0:
			var remaining: float = maxf(0.0, SPARED_REQUIRED_TIME - spared_timer)
			return "⚠️ %s: RETIRÁNDOSE (%.1fs)...\n(Mantén distancia para perdonar)" % [pilot_name.to_upper(), remaining]
		else:
			return "⚠️ PERÍMETRO DE COMBATE — %s\n[ Entra al anillo para retar | Aléjate para perdonar ]" % pilot_name.to_upper()
	elif current_state == State.DOGFIGHT:
		return "⚔️ EN DUELO: PILOTO %s" % pilot_name.to_upper()
	return ""

func get_warning_color() -> Color:
	if current_state == State.PEACEFUL_WARN:
		if challenge_timer > 0.0:
			return Color(1.0, 0.45, 0.2, 0.95)
		elif spared_timer > 0.0:
			return Color(0.3, 1.0, 0.5, 0.95)
		else:
			return Color(1.0, 0.75, 0.2, 0.95)
	elif current_state == State.DOGFIGHT:
		return Color(1.0, 0.2, 0.2, 0.95)
	return Color.WHITE
