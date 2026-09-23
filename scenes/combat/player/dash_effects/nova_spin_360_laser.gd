class_name NovaSpin360Laser
extends Node2D

## NovaSpin360Laser.gd
## Láser giratorio del Omega Spin de Nova.
## Un ÚNICO haz que barre 360° de forma continua durante la duración del dash,
## siguiendo al jugador mientras se desplaza. El rayo avanza un ángulo por frame
## hasta completar una vuelta completa, dañando a cada enemigo máximo 1 vez.

const SPIN_DURATION: float = 0.35  # debe coincidir con dash_timer del Omega Spin
const BEAM_LENGTH: float = 2600.0
const DAMAGE_MULT: float = 1.2     # reducido respecto al láser normal (2.2x) por el AoE 360°

var hit_context: HitContext
## RID del enemigo → true. Garantiza máx 1 hit por enemigo en todo el barrido.
var hit_registry: Dictionary = {}
var current_angle: float = 0.0
var elapsed: float = 0.0
## Referencia al jugador para seguir su posición durante el dash.
var origin_node: Node2D = null

@onready var outer_line: Line2D = $OuterLine
@onready var core_line: Line2D = $CoreLine

## p_origin_node: el jugador (Node2D) cuya posición se sigue. Puede ser null en tests.
## p_ctx: HitContext con el daño base ya calculado.
## p_start_angle: ángulo inicial del rayo en radianes (recomendado: dash_direction.angle()).
func setup(p_origin_node: Node2D, p_ctx: HitContext, p_start_angle: float = 0.0) -> void:
	origin_node = p_origin_node
	current_angle = p_start_angle
	hit_context = p_ctx
	if is_instance_valid(origin_node):
		global_position = origin_node.global_position
		if origin_node.has_method("update_omega_spin_rotation"):
			origin_node.update_omega_spin_rotation(current_angle)

func _exit_tree() -> void:
	if is_instance_valid(origin_node) and "is_omega_spinning" in origin_node:
		origin_node.is_omega_spinning = false

func _ready() -> void:
	# Fallback para instancias creadas sin escena (tests headless)
	if not outer_line:
		outer_line = get_node_or_null("OuterLine") as Line2D
	if not core_line:
		core_line = get_node_or_null("CoreLine") as Line2D
	_init_lines()

func _init_lines() -> void:
	if outer_line:
		outer_line.clear_points()
		outer_line.add_point(Vector2.ZERO)
		outer_line.add_point(Vector2.RIGHT * BEAM_LENGTH)
		outer_line.width = 14.0
		outer_line.default_color = Color(0.2, 0.9, 1.0, 0.95)
	if core_line:
		core_line.clear_points()
		core_line.add_point(Vector2.ZERO)
		core_line.add_point(Vector2.RIGHT * BEAM_LENGTH)
		core_line.width = 5.0
		core_line.default_color = Color(1.0, 1.0, 1.0, 1.0)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= SPIN_DURATION:
		if is_instance_valid(origin_node) and "is_omega_spinning" in origin_node:
			origin_node.is_omega_spinning = false
		queue_free()
		return

	# Seguir al jugador mientras dura el dash
	if is_instance_valid(origin_node):
		global_position = origin_node.global_position

	# Avanzar el ángulo: una vuelta completa (TAU) en SPIN_DURATION segundos
	current_angle += TAU / SPIN_DURATION * delta

	# Sincronizar la orientación visual de la nave con el giro continuo del rayo láser
	if is_instance_valid(origin_node) and origin_node.has_method("update_omega_spin_rotation"):
		origin_node.update_omega_spin_rotation(current_angle)

	var dir := Vector2.from_angle(current_angle)
	var start_world := global_position
	var beam_reach := _get_beam_reach(dir, start_world)
	var end_local := dir * beam_reach       # coordenadas locales (origen = posición del nodo)
	var end_world := start_world + end_local

	# Actualizar visual del rayo en su posición actual del barrido
	if outer_line:
		outer_line.set_point_position(1, end_local)
	if core_line:
		core_line.set_point_position(1, end_local)

	# Dañar enemigos en la trayectoria actual del rayo este frame
	_damage_along_beam(start_world, end_world)


## Raycast físico para detectar obstáculos sólidos (planetas, paredes).
## Acorta el rayo hasta el primer impacto. Sin hit → retorna BEAM_LENGTH.
func _get_beam_reach(dir: Vector2, from_pos: Vector2) -> float:
	if not is_inside_tree():
		return BEAM_LENGTH
	var space_state := get_world_2d().direct_space_state
	if not space_state:
		return BEAM_LENGTH
	var query := PhysicsRayQueryParameters2D.create(from_pos, from_pos + dir * BEAM_LENGTH)
	query.collision_mask = 1   # Capa 1: sólidos del mundo
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if hit_context and is_instance_valid(hit_context.attacker):
		query.exclude = [hit_context.attacker.get_rid()]
	var res := space_state.intersect_ray(query)
	if res:
		return (res.position - from_pos).length()
	return BEAM_LENGTH


## Comprueba todos los enemigos en la trayectoria actual del rayo y los daña una vez.
func _damage_along_beam(start_world: Vector2, end_world: Vector2) -> void:
	if not hit_context:
		return
	var hit_radius_sq: float = 28.0 * 28.0
	var tree := get_tree()
	if not tree:
		return

	for node in tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("emitters"):
		if not (node is Node2D) or not is_instance_valid(node) or node.get("is_dying"):
			continue
		var dist_sq := _dist_to_segment_sq((node as Node2D).global_position, start_world, end_world)
		if dist_sq > hit_radius_sq:
			continue
		# Deduplicación: máx 1 impacto por enemigo durante todo el barrido
		var enemy_id: int = node.get_instance_id()
		if hit_registry.has(enemy_id):
			continue
		hit_registry[enemy_id] = true
		if node.has_method("take_damage"):
			var child_ctx := HitContext.new()
			# Copiar attacker solo si sigue siendo válido (puede ser null o liberado en tests)
			if is_instance_valid(hit_context.attacker):
				child_ctx.attacker = hit_context.attacker
			child_ctx.raw_damage = hit_context.final_damage * DAMAGE_MULT
			child_ctx.final_damage = hit_context.final_damage * DAMAGE_MULT
			child_ctx.is_crit = hit_context.is_crit
			child_ctx.proc_coefficient = 0.35
			child_ctx.depth = hit_context.depth + 1
			child_ctx.proc_chain = hit_context.proc_chain.duplicate()
			if not child_ctx.proc_chain.has(&"nova_omega_spin"):
				child_ctx.proc_chain.append(&"nova_omega_spin")
			child_ctx.hit_position = (node as Node2D).global_position
			node.take_damage(child_ctx)




func _dist_to_segment_sq(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ap := p - a
	var len_sq := ab.length_squared()
	if len_sq == 0.0:
		return ap.length_squared()
	var t := clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_squared_to(a + ab * t)
