class_name SceneTransitionClass
extends CanvasLayer

## SceneTransition.gd
## Autoload global para transiciones de pantalla usando la cinemática de Singularidad
## (Big Crunch -> Punto Blanco Vivo + carga threaded -> Big Bang) vía SingularityTransitionPresenter.

signal transition_started
signal screen_covered
signal transition_finished

const SingularityPresenterScript = preload("res://core/systems/singularity_transition_presenter.gd")
const SingularityConfigScript = preload("res://data/ui/singularity_transition_config.gd")
const DEFAULT_CONFIG: SingularityConfigScript = preload("res://data/ui/default_singularity_transition_config.tres")

var is_transitioning: bool = false
var _presenter: SingularityPresenterScript = null


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_presenter()


func _ensure_presenter() -> void:
	if _presenter != null and is_instance_valid(_presenter):
		return
	_presenter = SingularityPresenterScript.new() as SingularityPresenterScript
	_presenter.name = "SingularityTransitionPresenter"
	_presenter.layer = 150
	_presenter.apply_config(DEFAULT_CONFIG)
	add_child(_presenter)
	if not _presenter.crunch_completed.is_connected(_on_presenter_crunch_completed):
		_presenter.crunch_completed.connect(_on_presenter_crunch_completed)


func _on_presenter_crunch_completed() -> void:
	screen_covered.emit()


func get_presenter() -> SingularityPresenterScript:
	_ensure_presenter()
	return _presenter


func get_config() -> SingularityConfigScript:
	_ensure_presenter()
	return _presenter.config if _presenter != null else DEFAULT_CONFIG


## Cambia de escena de forma asíncrona (ResourceLoader.load_threaded_request) dentro de la Singularidad.
func change_scene_to_file(target_scene_path: String) -> void:
	if is_transitioning or target_scene_path.is_empty():
		return
	_ensure_presenter()
	is_transitioning = true
	transition_started.emit()
	await _presenter.change_scene_threaded(target_scene_path)
	is_transitioning = false
	transition_finished.emit()


## Ejecuta la transición de Singularidad y llama a on_covered_callback al colapsar al punto blanco.
func play_wipe(on_covered_callback: Callable = Callable(), min_hold_override: float = -1.0) -> void:
	if is_transitioning:
		return
	_ensure_presenter()
	is_transitioning = true
	transition_started.emit()
	await _presenter.play_custom_transition(on_covered_callback, min_hold_override)
	is_transitioning = false
	transition_finished.emit()
