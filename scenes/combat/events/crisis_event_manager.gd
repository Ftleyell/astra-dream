class_name CrisisEventManager
extends Node2D

## Gestor y Director de Eventos de Crisis de Oleada:
## Orquesta los 4 eventos dinámicos espaciales del juego:
## 1. Tormenta Solar (Ceguera térmica periférica + buff de +30% Attack Speed al jugador por 18s)
## 2. Ráfaga de Micro-Drones (Wedges geométricos de EnemyMicroFlock)
## 3. Invasión Mitótica (Células de división de EnemySplitter)
## 4. Arena de Contención (Anillo de 14 nodos de ResonanceContainmentNode conectados por arcos)

signal crisis_started(crisis_id: String)
signal crisis_ended(crisis_id: String)

@export var auto_crisis_enabled: bool = true
@export var min_crisis_interval: float = 45.0

const CrisisAlertBannerClass = preload("res://scenes/ui/hud/crisis_alert_banner.gd")
const EnemyMicroFlockClass = preload("res://scenes/combat/enemies/enemy_micro_flock.gd")
const EnemySplitterClass = preload("res://scenes/combat/enemies/enemy_splitter.gd")
const ResonanceContainmentNodeClass = preload("res://scenes/combat/enemies/resonance_containment_node.gd")

var player: Node2D = null
var banner: CrisisAlertBannerClass = null
var current_active_crisis: String = ""

# Referencias de escenas
var flock_scene: PackedScene = preload("res://scenes/combat/enemies/enemy_micro_flock.tscn")
var splitter_scene: PackedScene = preload("res://scenes/combat/enemies/enemy_splitter.tscn")
var containment_scene: PackedScene = preload("res://scenes/combat/enemies/resonance_containment_node.tscn")

# Tormenta Solar
var solar_storm_active: bool = false
var solar_storm_timer: float = 0.0
var solar_storm_duration: float = 18.0
var solar_shader_mat: ShaderMaterial = null
var solar_overlay: ColorRect = null
var solar_canvas_layer: CanvasLayer = null

# Temporizador para eventos automáticos
var crisis_cooldown: float = 35.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_setup_solar_storm_overlay()
	_acquire_references()

func _acquire_references() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(banner):
		banner = get_tree().root.find_child("CrisisAlertBanner", true, false) as CrisisAlertBannerClass
		if banner and not banner.alert_finished.is_connected(_on_banner_alert_finished):
			banner.alert_finished.connect(_on_banner_alert_finished)

func _setup_solar_storm_overlay() -> void:
	solar_canvas_layer = CanvasLayer.new()
	solar_canvas_layer.layer = 20 # Por debajo del HUD principal y banner
	add_child(solar_canvas_layer)

	solar_overlay = ColorRect.new()
	solar_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	solar_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	solar_overlay.visible = false

	var shader := preload("res://core/shaders/solar_storm_burn.gdshader")
	solar_shader_mat = ShaderMaterial.new()
	solar_shader_mat.shader = shader
	solar_shader_mat.set_shader_parameter("intensity", 0.0)
	solar_shader_mat.set_shader_parameter("inner_radius", 280.0)
	solar_shader_mat.set_shader_parameter("outer_radius", 620.0)
	solar_overlay.material = solar_shader_mat

	solar_canvas_layer.add_child(solar_overlay)

func _process(delta: float) -> void:
	_acquire_references()

	# Proceso de Tormenta Solar
	if solar_storm_active:
		solar_storm_timer -= delta
		if is_instance_valid(player) and solar_shader_mat:
			var canvas_pos := player.get_global_transform_with_canvas().origin
			solar_shader_mat.set_shader_parameter("player_screen_pos", canvas_pos)

		if solar_storm_timer <= 0.0:
			_end_solar_storm()

	# Cooldown de crisis automáticas
	if auto_crisis_enabled and not solar_storm_active:
		crisis_cooldown -= delta
		if crisis_cooldown <= 0.0:
			crisis_cooldown = min_crisis_interval + randf_range(5.0, 20.0)
			_trigger_random_crisis()

func _trigger_random_crisis() -> void:
	var options := ["solar_storm", "flock_rush", "mitosis_invasion", "containment_arena"]
	var choice: String = options[randi() % options.size()]
	trigger_crisis(choice)

func trigger_crisis(crisis_id: String) -> void:
	_acquire_references()
	var title := "ANOMALÍA DETECTADA"
	var subtitle := "Condiciones operacionales extremas en el sector."
	var tint := Color(1.0, 0.4, 0.1)

	match crisis_id:
		"solar_storm":
			title = "TORMENTA DE RADIACIÓN SOLAR"
			subtitle = "Ceguera térmica exterior detectada. Sensores sobrecargados (+30% Cadencia de Fuego)."
			tint = Color(1.0, 0.5, 0.1)
		"flock_rush":
			title = "ENJAMBRE DE MICRO-DRONES"
			subtitle = "Múltiples formaciones en cuña a hiper-velocidad interceptando el vector."
			tint = Color(0.2, 0.9, 1.0)
		"mitosis_invasion":
			title = "INVASIÓN DE CÉLULAS MITÓTICAS"
			subtitle = "Especímenes de fisión biológica detectados. Destruye ambas mitades antes de su fusión."
			tint = Color(0.3, 1.0, 0.5)
		"containment_arena":
			title = "CERCO DE RESONANCIA ELECTRÓNICA"
			subtitle = "Generadores de cerco electromagnético desplegados. Destruye los nodos o resiste 25s."
			tint = Color(0.9, 0.2, 0.8)

	if banner:
		banner.show_crisis_alert(crisis_id, title, subtitle, tint)
	else:
		_execute_crisis(crisis_id)

func _on_banner_alert_finished(crisis_id: String) -> void:
	_execute_crisis(crisis_id)

func _execute_crisis(crisis_id: String) -> void:
	current_active_crisis = crisis_id
	match crisis_id:
		"solar_storm":
			_start_solar_storm()
		"flock_rush":
			_spawn_flock_rush()
		"mitosis_invasion":
			_spawn_mitosis_invasion()
		"containment_arena":
			_spawn_containment_arena()
	crisis_started.emit(crisis_id)

# 1. Tormenta Solar
func _start_solar_storm() -> void:
	solar_storm_active = true
	solar_storm_timer = solar_storm_duration
	if solar_overlay:
		solar_overlay.visible = true

	# Transición suave de intensidad del shader
	var tw := create_tween()
	tw.tween_method(func(v: float):
		if solar_shader_mat:
			solar_shader_mat.set_shader_parameter("intensity", v)
	, 0.0, 1.0, 1.5)

	# Buff al jugador: +30% attack_speed
	if is_instance_valid(player) and player.stats:
		player.stats.add_modifier(&"attack_speed", CharacterStats.StatModifier.new(&"solar_storm_frenzy", 0.30, true, self))

func _end_solar_storm() -> void:
	solar_storm_active = false
	current_active_crisis = ""

	if is_instance_valid(player) and player.stats:
		player.stats.remove_modifier(&"attack_speed", &"solar_storm_frenzy")

	var tw := create_tween()
	tw.tween_method(func(v: float):
		if solar_shader_mat:
			solar_shader_mat.set_shader_parameter("intensity", v)
	, 1.0, 0.0, 1.5)
	tw.tween_callback(func():
		if solar_overlay:
			solar_overlay.visible = false
	)
	crisis_ended.emit("solar_storm")

# 2. Enjambre de Micro-Drones
func _spawn_flock_rush() -> void:
	if not is_instance_valid(player):
		return
	var parent_node := get_parent()
	if not parent_node:
		return

	# Generar 3 cuñas de 5 drones cada una (15 en total)
	for w in range(3):
		var base_angle := randf_range(-PI, PI)
		var spawn_origin := player.global_position + Vector2(cos(base_angle), sin(base_angle)) * 620.0
		var approach_dir := (player.global_position - spawn_origin).normalized()

		for i in range(5):
			var drone: EnemyMicroFlockClass = flock_scene.instantiate() as EnemyMicroFlockClass
			# Formación de cuña (V-shape)
			var row := absi(i - 2)
			var lateral := (i - 2) * 32.0
			var forward_off := float(row) * -28.0
			var local_off := approach_dir.orthogonal() * lateral + approach_dir * forward_off
			drone.global_position = spawn_origin + local_off
			parent_node.add_child(drone)

# 3. Invasión Mitótica
func _spawn_mitosis_invasion() -> void:
	if not is_instance_valid(player):
		return
	var parent_node := get_parent()
	if not parent_node:
		return

	# Generar 4 células dividibles en las 4 direcciones
	for i in range(4):
		var angle := (TAU / 4.0) * float(i) + randf_range(-0.2, 0.2)
		var spawn_pos := player.global_position + Vector2(cos(angle), sin(angle)) * 520.0
		var splitter: EnemySplitterClass = splitter_scene.instantiate() as EnemySplitterClass
		splitter.global_position = spawn_pos
		parent_node.add_child(splitter)

# 4. Cerco de Resonancia
func _spawn_containment_arena() -> void:
	if not is_instance_valid(player):
		return
	var parent_node := get_parent()
	if not parent_node:
		return

	var center := player.global_position
	var ring_radius := 560.0
	var count := 14
	var nodes: Array[ResonanceContainmentNodeClass] = []

	for i in range(count):
		var angle := (TAU / float(count)) * float(i)
		var pos := center + Vector2(cos(angle), sin(angle)) * ring_radius
		var node_inst: ResonanceContainmentNodeClass = containment_scene.instantiate() as ResonanceContainmentNodeClass
		node_inst.global_position = pos
		parent_node.add_child(node_inst)
		nodes.append(node_inst)

	# Conectar vecinos para dibujar el perímetro eléctrico
	for i in range(count):
		var next_idx := (i + 1) % count
		nodes[i].set_neighbor(nodes[next_idx])
