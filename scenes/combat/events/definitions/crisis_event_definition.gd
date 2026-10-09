class_name CrisisEventDefinition
extends Resource

## CrisisEventDefinition.gd
## Recurso de datos y contrato modular para eventos de crisis de oleada.
## Permite añadir nuevas anomalías o crisis espaciales mediante recursos o mods (Open/Closed Principle).

@export var id: String = ""
@export var title: String = "ANOMALÍA DETECTADA"
@export var subtitle: String = "Condiciones operacionales extremas en el sector."
@export var tint: Color = Color(1.0, 0.4, 0.1)
@export var duration: float = 0.0

## Callback opcional de ejecución si la crisis tiene lógica de spawn personalizada
## signature: (manager: Node2D, player: Node2D, parent_node: Node) -> void
var on_execute: Callable = Callable()

## Callback opcional de fin de crisis
var on_end: Callable = Callable()

## Callback de actualización continua por frame si es requerida (ej. shaders)
## signature: (delta: float, manager: Node2D, player: Node2D) -> void
var on_process: Callable = Callable()
