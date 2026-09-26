class_name NavigatorController
extends Node

## Controlador de combate y escaneo periódico de Navegantes.
## Gestiona la oficial táctica seleccionada, alertas por radio lateral,
## trazado de línea de guía cuántica y activación del Buff de Navegación.

signal buff_applied(nav_id: StringName, buff_name: String, duration: float)
signal buff_expired(nav_id: StringName)

const NavigatorDataScript := preload("res://data/navigators/navigator_data.gd")
const NavigatorGuideLineScript := preload("res://scenes/combat/navigators/navigator_guide_line.gd")

var main_game: Node2D = null
var player: Player = null
var hud: GameHUD = null

var navigator_data: Resource = null
var comms_widget = null
var active_guide_line = null
var current_target_node: Node2D = null

var scan_timer: float = 12.0 # Primer escaneo rápido a los 12s para enganchar al jugador
var is_first_scan: bool = true
const NORMAL_SCAN_INTERVAL: float = 38.0

var active_buff_duration: float = 0.0
var is_buff_active: bool = false
var caelia_shield_active: bool = false

func setup(p_main_game: Node2D, p_player: Player, p_hud: GameHUD) -> void:
	main_game = p_main_game
	player = p_player
	hud = p_hud

	var nav_id := SaveManager.get_selected_navigator()
	navigator_data = NavigatorDataScript.get_navigator(nav_id)
	if not navigator_data:
		navigator_data = NavigatorDataScript.get_navigator(&"lyra")

	_create_comms_widget()

func _create_comms_widget() -> void:
	var widget_scene := preload("res://scenes/ui/hud/navigator_comms_widget.tscn")
	if widget_scene:
		comms_widget = widget_scene.instantiate()
		add_child(comms_widget)

func _process(delta: float) -> void:
	if not is_instance_valid(player) or player.is_dead:
		return

	# Control del temporizador de escaneo periódico
	if not is_instance_valid(active_guide_line):
		scan_timer -= delta
		if scan_timer <= 0.0:
			trigger_scan()
			scan_timer = NORMAL_SCAN_INTERVAL

	# Control de la duración del Buff activo
	if is_buff_active:
		active_buff_duration -= delta
		if active_buff_duration <= 0.0:
			_expire_buff()

func trigger_scan() -> void:
	if not is_instance_valid(player) or not navigator_data:
		return

	var target := _find_best_target_for_navigator()
	if not is_instance_valid(target):
		target = _create_fallback_anomaly_target()

	if not is_instance_valid(target):
		return

	current_target_node = target

	# Seleccionar línea de diálogo táctico
	var callouts: Array = navigator_data.dialogue_callouts if ("dialogue_callouts" in navigator_data) else []
	var dialogue := "¡Coordenada táctica detectada! Sigue el vector marcado para sincronizar."
	if not callouts.is_empty():
		dialogue = callouts[randi() % callouts.size()]

	# Mostrar widget de comunicaciones lateral
	if comms_widget:
		var hint := _get_target_hint_text()
		comms_widget.show_transmission(navigator_data, dialogue, hint)

	# Trazar línea de guía cuántica
	_spawn_guide_line(target)

func _spawn_guide_line(target: Node2D) -> void:
	if is_instance_valid(active_guide_line):
		active_guide_line.fade_out()
		active_guide_line = null

	var line = NavigatorGuideLineScript.new()
	line.name = "NavigatorGuideLine"
	line.setup(player, target, navigator_data.theme_color, 28.0)
	line.target_reached.connect(_on_target_reached)
	main_game.add_child(line)
	active_guide_line = line

func _on_target_reached(target: Node2D) -> void:
	if not is_instance_valid(player) or not navigator_data:
		return

	# Notificar en el HUD
	if comms_widget:
		comms_widget.show_buff_activated(navigator_data)

	# Aplicar buff específico
	_apply_navigator_buff()

func _apply_navigator_buff() -> void:
	var nid: StringName = navigator_data.navigator_id if navigator_data else &""
	var duration: float = 10.0

	# Limpiar buff previo si seguía activo
	if is_buff_active:
		_expire_buff()

	match nid:
		&"lyra":
			# Lyra: Sobrecarga de Propulsión (+25% Vel, +100% Radio de Imán)
			duration = 10.0
			player.stats.set_or_replace_modifier(&"move_speed", CharacterStats.StatModifier.new(&"nav_lyra_speed", 0.25, true, self))
			player.stats.set_or_replace_modifier(&"pickup_radius", CharacterStats.StatModifier.new(&"nav_lyra_magnet", 1.0, true, self))
		&"vespera":
			# Vespera: Sintonía Arcana (+20% CDR, +15% Daño)
			duration = 10.0
			player.stats.set_or_replace_modifier(&"cooldown_reduction", CharacterStats.StatModifier.new(&"nav_vespera_cdr", 0.20, true, self))
			player.stats.set_or_replace_modifier(&"base_damage", CharacterStats.StatModifier.new(&"nav_vespera_dmg", 0.15, true, self))
		&"caelia":
			# Caelia: Blindaje Gravitacional (Absorbe 1 impacto gratis + 20% Armadura)
			duration = 12.0
			caelia_shield_active = true
			player.stats.set_or_replace_modifier(&"armor", CharacterStats.StatModifier.new(&"nav_caelia_armor", 0.20, true, self))
			# Conectar hook de daño para absorber el siguiente hit si no está conectado
			if not player.has_meta("caelia_shield_hook"):
				player.set_meta("caelia_shield_hook", true)
		&"zephyr":
			# Zephyr: Bolsillo Táctico (+50 Créditos inmediatos + 15% Cadencia)
			duration = 10.0
			player.run_credits += 50
			player.credits_changed.emit(player.run_credits)
			if hud:
				hud.update_credits(player.run_credits)
			player.stats.set_or_replace_modifier(&"attack_speed", CharacterStats.StatModifier.new(&"nav_zephyr_atkspd", 0.15, true, self))
		&"iris":
			# Iris: Trascendencia Cósmica (+30% Prob. Crítica, +25% Vel. Proyectil)
			duration = 12.0
			player.stats.set_or_replace_modifier(&"crit_chance", CharacterStats.StatModifier.new(&"nav_iris_crit", 0.30, false, self))
			player.stats.set_or_replace_modifier(&"projectile_speed", CharacterStats.StatModifier.new(&"nav_iris_projspd", 0.25, true, self))

	is_buff_active = true
	active_buff_duration = duration
	buff_applied.emit(nid, navigator_data.buff_name, duration)

	# Destello visual en el jugador con el color de la navegante
	_spawn_buff_visual_feedback()

func _expire_buff() -> void:
	if not is_instance_valid(player) or not is_buff_active:
		return

	is_buff_active = false
	caelia_shield_active = false
	if player.has_meta("caelia_shield_hook"):
		player.remove_meta("caelia_shield_hook")

	var nid: StringName = navigator_data.navigator_id if navigator_data else &""
	match nid:
		&"lyra":
			player.stats.remove_modifier(&"move_speed", &"nav_lyra_speed")
			player.stats.remove_modifier(&"pickup_radius", &"nav_lyra_magnet")
		&"vespera":
			player.stats.remove_modifier(&"cooldown_reduction", &"nav_vespera_cdr")
			player.stats.remove_modifier(&"base_damage", &"nav_vespera_dmg")
		&"caelia":
			player.stats.remove_modifier(&"armor", &"nav_caelia_armor")
		&"zephyr":
			player.stats.remove_modifier(&"attack_speed", &"nav_zephyr_atkspd")
		&"iris":
			player.stats.remove_modifier(&"crit_chance", &"nav_iris_crit")
			player.stats.remove_modifier(&"projectile_speed", &"nav_iris_projspd")

	buff_expired.emit(nid)

func _spawn_buff_visual_feedback() -> void:
	if not is_instance_valid(player):
		return
	var col: Color = navigator_data.theme_color if navigator_data else Color.CYAN
	var tw := player.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "modulate", col.lerp(Color.WHITE, 0.4), 0.15)
	tw.tween_property(player, "modulate", Color.WHITE, 0.35)

func _find_best_target_for_navigator() -> Node2D:
	var t_type: StringName = navigator_data.target_type if navigator_data else &"planet"
	var candidate: Node2D = null

	match t_type:
		&"planet":
			candidate = _find_nearest_in_groups([&"planet_segment", &"planets", &"bio_cocoon", &"biomass_orbs"])
		&"pact":
			candidate = _find_nearest_in_groups([&"arcana_orb", &"arcana_orbs", &"astra_pacts"])
		&"monolith":
			candidate = _find_nearest_in_groups([&"monolith", &"monoliths", &"astral_geodes", &"space_objects"])
		&"satellite":
			if main_game and "current_satellite" in main_game and is_instance_valid(main_game.current_satellite):
				candidate = main_game.current_satellite
			else:
				candidate = _find_nearest_in_groups([&"satellite_beacon", &"satellite_beacons", &"satellite_shops"])
		&"anomaly":
			if main_game and "current_boss" in main_game and is_instance_valid(main_game.current_boss):
				candidate = main_game.current_boss
			elif main_game and "current_rival" in main_game and is_instance_valid(main_game.current_rival):
				candidate = main_game.current_rival
			else:
				candidate = _find_nearest_in_groups([&"bosses", &"boss", &"elites"])

	# Fallback inteligente si la categoría primaria no tiene elementos activos en ese segundo
	if not is_instance_valid(candidate):
		if main_game and "current_satellite" in main_game and is_instance_valid(main_game.current_satellite):
			candidate = main_game.current_satellite
		else:
			candidate = _find_nearest_in_groups([&"space_objects", &"destructibles", &"enemies"])

	return candidate

func _find_nearest_in_groups(group_names: Array[StringName]) -> Node2D:
	var tree := get_tree()
	if not tree or not is_instance_valid(player):
		return null

	var nearest: Node2D = null
	var min_dist: float = 999999.0
	var p_pos := player.global_position

	for gname in group_names:
		var nodes := tree.get_nodes_in_group(gname)
		for n in nodes:
			if is_instance_valid(n) and n is Node2D and n.is_inside_tree() and n.visible:
				var dist: float = p_pos.distance_to(n.global_position)
				# Ignorar nodos que estén demasiado cerca (ya encima del jugador) o a distancias descomunales
				if dist > 80.0 and dist < min_dist:
					min_dist = dist
					nearest = n

	return nearest

func _create_fallback_anomaly_target() -> Node2D:
	if not is_instance_valid(player) or not is_instance_valid(main_game):
		return null

	# Si no hay ningún objeto especial en escena, spawnear una Baliza de Anomalía Cuántica
	var anomaly := Node2D.new()
	anomaly.name = "SpatialAnomaly"
	var angle := randf() * TAU
	var spawn_dist := randf_range(500.0, 850.0)
	anomaly.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * spawn_dist
	main_game.add_child(anomaly)

	# Auto-destrucción tras 35s si no se alcanza
	var timer := get_tree().create_timer(35.0)
	timer.timeout.connect(func():
		if is_instance_valid(anomaly):
			anomaly.queue_free()
	)
	return anomaly

func _get_target_hint_text() -> String:
	match navigator_data.target_type:
		&"planet": return "Segmento Planetario / Biosfera"
		&"pact": return "Pacto Astral / Resonancia"
		&"monolith": return "Monolito de Materia Oscura"
		&"satellite": return "Baliza Satélite / Estación"
		&"anomaly": return "Anomalía Primordial / Jefe"
		_: return "Coordenada Táctica"
