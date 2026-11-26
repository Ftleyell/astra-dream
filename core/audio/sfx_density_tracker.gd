class_name SfxDensityTracker
extends RefCounted
## Controla la atenuación progresiva por densidad de disparo en ventana deslizante
## para evitar saturación auditiva cuando la cadencia de combate escala.

const WINDOW_MSEC: int = 600
const MAX_TIMESTAMPS_PER_CUE: int = 16

var _history: Dictionary = {} # String -> Array[int]


func record_and_get_attenuation_db(cue_id: String, now_msec: int, max_attenuation_db: float) -> float:
	if max_attenuation_db <= 0.0:
		return 0.0

	var list: Array[int] = []
	if _history.has(cue_id):
		list = _history[cue_id] as Array[int]
	else:
		_history[cue_id] = list

	# Purgar marcas fuera de ventana
	var cutoff: int = now_msec - WINDOW_MSEC
	while not list.is_empty() and list[0] < cutoff:
		list.pop_front()

	list.append(now_msec)
	if list.size() > MAX_TIMESTAMPS_PER_CUE:
		list.pop_front()

	var count: int = list.size()
	if count <= 2:
		return 0.0

	var t: float = clampf(float(count - 2) / 8.0, 0.0, 1.0)
	return -max_attenuation_db * t


func clear() -> void:
	_history.clear()
