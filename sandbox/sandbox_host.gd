class_name SandboxHost
extends Node2D

## SandboxHost
## Orquestador central para la simulación del universo y parallax sandbox.
## Ensambla:
## 1. FloatingOriginTracker: Mantiene la precisión espacial 64-bit y coordina rebases.
## 2. CosmicSectorStreamer: Determina los sectores celestes activos con histéresis.
## 3. CosmicParallaxQuad: Capas procedurales de fondo profundo y nebulosa ancladas a la cámara.
## 4. CosmicDebrisInstancer: Instanciación masiva en GPU (MultiMesh) de debris espacial.
## 5. CosmicCelestialRenderer: Generación determinista kepleriana de sistemas estelares y lunas.
## 6. SandboxShip: Nave ligera del jugador con controles de vuelo libre e inercia.
## 7. SandboxTelemetryHud: Panel visual de métricas de rendimiento y coordenadas.

@export var floating_origin_threshold: float = 8192.0
@export var sector_size: float = 8000.0
@export var universe_seed: int = 133742

var _origin_tracker: FloatingOriginTracker
var _sector_streamer: CosmicSectorStreamer

@onready var ship: SandboxShip = $SandboxShip
@onready var parallax_quad: CosmicParallaxQuad = $CosmicParallaxQuad
@onready var debris_instancer: CosmicDebrisInstancer = $CosmicDebrisInstancer
@onready var celestial_renderer: CosmicCelestialRenderer = $CosmicCelestialRenderer
@onready var telemetry_hud: SandboxTelemetryHud = $SandboxTelemetryHud


func _ready() -> void:
	# 1. Inicializar sistemas centrales
	_origin_tracker = FloatingOriginTracker.new(floating_origin_threshold)
	_sector_streamer = CosmicSectorStreamer.new(sector_size, 1, 2)

	# 2. Conectar eventos de streaming con el renderizador celeste
	_sector_streamer.sector_entered.connect(_on_sector_entered)
	_sector_streamer.sector_exited.connect(_on_sector_exited)

	# 3. Conectar rebase de origen flotante
	_origin_tracker.rebased.connect(_on_origin_rebased)

	# 4. Configurar componentes de renderizado y nave
	var camera_node: Camera2D = ship.get_node_or_null("Camera2D") as Camera2D
	if is_instance_valid(parallax_quad):
		parallax_quad.configure(camera_node, _origin_tracker)

	if is_instance_valid(debris_instancer):
		debris_instancer.configure(ship, _origin_tracker)

	if is_instance_valid(celestial_renderer):
		celestial_renderer.configure(_origin_tracker, universe_seed)

	if is_instance_valid(telemetry_hud):
		telemetry_hud.setup(
			_origin_tracker,
			_sector_streamer,
			ship,
			debris_instancer,
			celestial_renderer
		)

	# 5. Primera evaluación de streaming
	_sector_streamer.update_streamer(ship.global_position)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(ship):
		return

	# Actualizar posición del actor en el tracker de origen flotante
	_origin_tracker.update_actor_position(ship.global_position)

	# Actualizar streaming de sectores con las coordenadas lógicas mundiales
	var logical_pos: Vector2 = _origin_tracker.get_logical_position()
	_sector_streamer.update_streamer(logical_pos)


func _on_sector_entered(sector: Vector2i) -> void:
	if is_instance_valid(celestial_renderer):
		celestial_renderer.on_sector_entered(sector, _sector_streamer)


func _on_sector_exited(sector: Vector2i) -> void:
	if is_instance_valid(celestial_renderer):
		celestial_renderer.on_sector_exited(sector)


func _on_origin_rebased(offset: Vector2) -> void:
	# Al ocurrir un rebase, compensar la posición local de la nave
	if is_instance_valid(ship):
		ship.global_position -= offset
