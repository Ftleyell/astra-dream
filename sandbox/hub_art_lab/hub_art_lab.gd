class_name HubArtLab
extends AstralStationHub

## Wrapper sandbox del Laboratorio de Arte del Hub 3D (Estación Astral v4).
## Hereda toda la escena/arquitectura de producción (AstralStationHub) con el panel Dev [H] activo
## y salida directa al Workbench Hub de I+D.

const WORKBENCH_HUB_PATH: String = "res://sandbox/workbenches/workbench_hub.tscn"


func _init() -> void:
	is_dev_lab_mode = true


func _on_dev_back_to_workbench() -> void:
	if ResourceLoader.exists(WORKBENCH_HUB_PATH) and get_tree() != null:
		get_tree().change_scene_to_file(WORKBENCH_HUB_PATH)
