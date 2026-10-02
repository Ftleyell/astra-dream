class_name SlotMachineBeacon
extends Node2D

## Máquina Tragamonedas In-Run tipo Bumper Arcade 100% In-Game.
## El jugador la choca físicamente ("bump"), rebota suavemente hacia atrás,
## descuenta los créditos y hace girar los 3 rodillos sobre la propia máquina
## en tiempo real sin abrir ventanas modales ni pausar la partida.

signal interacted(beacon: SlotMachineBeacon)
signal exploded(pos: Vector2)
signal spin_started()
signal spin_resolved(outcome: Dictionary)

const ExpBlobScript = preload("res://scenes/combat/pickups/exp_blob.gd")

@export var bumper_radius: float = 46.0

var remaining_uses: int = 3
var current_spin_cost: int = 50
const COST_INCREMENT: int = 25

var is_rolling: bool = false
var is_exploded: bool = false
var _is_tearing_down: bool = false
var _bump_cooldown: float = 0.0

const SYMBOLS: Array[String] = ["💰", "💣", "🧲", "💖", "⭐"]

# Nodos visuales in-game
var _visual_core: CanvasItem
var _radius_visual: Line2D
var _area: Area2D

# Display flotante estilo Arcade Marquee
var _marquee_node: Node2D
var _reel_labels: Array[Label] = []
var _info_label: Label
var _msg_label: Label

func _ready() -> void:
	add_to_group("slot_machine_beacon")
	scale = Vector2(2.0, 2.0)
	if remaining_uses <= 0:
		remaining_uses = randi_range(3, 5)
	_setup_visuals()
	_setup_marquee_display()
	_setup_area()

func _setup_visuals() -> void:
	# Sprite de alta resolución arcade pinball bumper
	var sprite := Sprite2D.new()
	var tex = load("res://assets/sprites/interactables/slot_machine_beacon.png") as Texture2D
	if tex:
		sprite.texture = tex
		sprite.scale = Vector2(0.24, 0.24)
	_visual_core = sprite
	add_child(_visual_core)

	# Anillo de Bumper alrededor del pedestal
	_radius_visual = Line2D.new()
	_radius_visual.width = 2.5
	_radius_visual.default_color = Color(1.0, 0.85, 0.2, 0.7)
	var points: int = 32
	for i in range(points + 1):
		var angle := float(i) * TAU / float(points)
		_radius_visual.add_point(Vector2(cos(angle), sin(angle)) * bumper_radius)
	add_child(_radius_visual)

func _setup_marquee_display() -> void:
	_marquee_node = Node2D.new()
	_marquee_node.position = Vector2(0, -68)
	add_child(_marquee_node)

	# Fondo del panel de rodillos
	var bg := Polygon2D.new()
	bg.polygon = PackedVector2Array([
		Vector2(-72, -34), Vector2(72, -34),
		Vector2(72, 30), Vector2(-72, 30)
	])
	bg.color = Color(0.04, 0.03, 0.1, 0.94)
	_marquee_node.add_child(bg)

	# Borde neón del panel
	var border := Line2D.new()
	border.width = 2.0
	border.default_color = Color(0.2, 0.95, 1.0, 0.85)
	border.points = PackedVector2Array([
		Vector2(-72, -34), Vector2(72, -34),
		Vector2(72, 30), Vector2(-72, 30), Vector2(-72, -34)
	])
	_marquee_node.add_child(border)

	# Cajas para los 3 rodillos
	var start_x := -46.0
	var spacing := 46.0
	_reel_labels.clear()

	for i in range(3):
		var cell_x := start_x + (float(i) * spacing)
		var cell_bg := Polygon2D.new()
		cell_bg.polygon = PackedVector2Array([
			Vector2(cell_x - 18, -26), Vector2(cell_x + 18, -26),
			Vector2(cell_x + 18, 10), Vector2(cell_x - 18, 10)
		])
		cell_bg.color = Color(0.12, 0.08, 0.24, 0.95)
		_marquee_node.add_child(cell_bg)

		var cell_border := Line2D.new()
		cell_border.width = 1.2
		cell_border.default_color = Color(1.0, 0.85, 0.2, 0.6)
		cell_border.points = PackedVector2Array([
			Vector2(cell_x - 18, -26), Vector2(cell_x + 18, -26),
			Vector2(cell_x + 18, 10), Vector2(cell_x - 18, 10), Vector2(cell_x - 18, -26)
		])
		_marquee_node.add_child(cell_border)

		var lbl := Label.new()
		lbl.text = "💰" if i != 1 else "⭐"
		lbl.position = Vector2(cell_x - 18, -28)
		lbl.custom_minimum_size = Vector2(36, 36)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 18)
		_marquee_node.add_child(lbl)
		_reel_labels.append(lbl)

	# Info label inferior (Coste y Usos)
	_info_label = Label.new()
	_info_label.position = Vector2(-70, 11)
	_info_label.custom_minimum_size = Vector2(140, 16)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", 10)
	_info_label.modulate = Color(0.2, 0.95, 1.0, 1.0)
	_marquee_node.add_child(_info_label)

	# Mensaje de ayuda / resultado
	_msg_label = Label.new()
	_msg_label.text = "¡BUMP PARA GIRAR!"
	_msg_label.position = Vector2(-100, -52)
	_msg_label.custom_minimum_size = Vector2(200, 16)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.add_theme_font_size_override("font_size", 10)
	_msg_label.modulate = Color(1.0, 0.9, 0.3, 0.9)
	_marquee_node.add_child(_msg_label)

	_update_info_display()

func _setup_area() -> void:
	_area = Area2D.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = bumper_radius
	col.shape = shape
	_area.add_child(col)
	add_child(_area)

	_area.body_entered.connect(_on_body_entered)

func _exit_tree() -> void:
	_is_tearing_down = true
	if is_instance_valid(_area) and _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.disconnect(_on_body_entered)

func _process(delta: float) -> void:
	if is_exploded or _is_tearing_down:
		return

	if _bump_cooldown > 0.0:
		_bump_cooldown -= delta

	# Efecto de levitación sutil
	var bob := sin(Time.get_ticks_msec() * 0.003) * 0.35 * delta * 60.0
	position.y += bob

	# Pulsación de luces neón
	if _visual_core:
		var pulse := 0.88 + 0.12 * sin(Time.get_ticks_msec() * 0.006)
		_visual_core.modulate = Color(1.0 * pulse, 0.82 * pulse, 0.15, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if _is_tearing_down or is_exploded or not is_inside_tree() or is_queued_for_deletion():
		return
	if body != null and (not body.is_inside_tree() or body.is_queued_for_deletion()):
		return
	if body is Player or body.is_in_group("player"):
		handle_player_bump(body as Player)

## Procesa el choque físico (Bumper) del jugador contra la máquina
func handle_player_bump(player: Player) -> void:
	if _bump_cooldown > 0.0 or is_exploded:
		return
	_bump_cooldown = 0.28

	# 1. Rebote físico del jugador hacia atrás (Bumper Kickback)
	var diff: Vector2 = player.global_position - global_position
	var bump_dir: Vector2 = diff.normalized() if diff.length_squared() > 1.0 else Vector2.UP

	if "velocity" in player:
		player.velocity = bump_dir * 540.0
	player.global_position += bump_dir * 14.0

	# 2. Deformación elástica de impacto en la máquina (Squash & Stretch)
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale = Vector2(2.56, 1.52)
	tw.tween_property(self, "scale", Vector2(2.0, 2.0), 0.24)

	# 3. Sonido de impacto
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click")

	# 4. Verificar si ya está girando
	if is_rolling:
		_show_flash_msg("🎰 ¡RODILLOS GIRANDO!", Color(0.2, 0.95, 1.0))
		return

	# 5. Verificar usos restantes
	if remaining_uses <= 0:
		return

	# 6. Verificar créditos del jugador
	if player.run_credits < current_spin_cost:
		_show_flash_msg("❌ ¡FALTAN CRÉDITOS! (%d CR)" % current_spin_cost, Color(1.0, 0.35, 0.35))
		_spawn_floating_text("¡Créditos insuficientes! (%d CR)" % current_spin_cost, Color(1.0, 0.35, 0.35))
		return

	# 7. Cobrar créditos e iniciar tirada in-game
	player.run_credits -= current_spin_cost
	var main_scene := get_tree().current_scene
	if main_scene and "hud" in main_scene and main_scene.hud:
		main_scene.hud.update_credits(player.run_credits)

	interacted.emit(self)
	_start_in_game_spin(player)

func _start_in_game_spin(player: Player) -> void:
	is_rolling = true
	spin_started.emit()
	_show_flash_msg("🎰 ¡GIRANDO...!", Color(1.0, 0.85, 0.2))

	var spin_cost := current_spin_cost

	# Determinar resultado
	var roll := randf()
	var s1: String = "💰"
	var s2: String = "💰"
	var s3: String = "💰"

	if roll < 0.18:
		# Triple Jackpot / Evento especial
		var sym := SYMBOLS[randi() % SYMBOLS.size()]
		s1 = sym
		s2 = sym
		s3 = sym
	elif roll < 0.65:
		# Par coincidente (Reembolso)
		var sym := SYMBOLS[randi() % SYMBOLS.size()]
		s1 = sym
		s2 = sym
		var other := SYMBOLS[randi() % SYMBOLS.size()]
		while other == sym:
			other = SYMBOLS[randi() % SYMBOLS.size()]
		s3 = other
		if randf() > 0.5:
			var tmp := s2
			s2 = s3
			s3 = tmp
	else:
		# Tres diferentes
		s1 = SYMBOLS[0]
		s2 = SYMBOLS[1]
		s3 = SYMBOLS[2]
		var shuffled := SYMBOLS.duplicate()
		shuffled.shuffle()
		s1 = shuffled[0]
		s2 = shuffled[1]
		s3 = shuffled[2]

	var final_symbols: Array[String] = [s1, s2, s3]

	# Animación de rotación rápida de rodillos (~0.85s)
	var steps := 12
	for step in range(steps):
		if not is_inside_tree() or is_exploded or _is_tearing_down:
			return
		for r_idx in range(mini(3, _reel_labels.size())):
			# Detener progresivamente los rodillos
			if step >= 7 and r_idx == 0:
				_reel_labels[0].text = final_symbols[0]
			elif step >= 9 and r_idx == 1:
				_reel_labels[1].text = final_symbols[1]
			elif step >= 11 and r_idx == 2:
				_reel_labels[2].text = final_symbols[2]
			else:
				_reel_labels[r_idx].text = SYMBOLS[randi() % SYMBOLS.size()]
		var tree := get_tree()
		if tree == null:
			return
		await tree.create_timer(0.07, false, false, true).timeout

	if not is_inside_tree() or is_exploded or _is_tearing_down:
		return

	for r_idx in range(mini(3, _reel_labels.size())):
		_reel_labels[r_idx].text = final_symbols[r_idx]

	# Sonido de rodillos detenidos
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click")

	# Resolver pago
	var payout := evaluate_payout(final_symbols, spin_cost)
	if is_instance_valid(player):
		_apply_payout(payout, player)

	consume_spin()
	_update_info_display()
	spin_resolved.emit(payout)
	is_rolling = false

	# Detonación si no quedan usos
	if remaining_uses <= 0:
		_show_flash_msg("⚠️ ¡DETONACIÓN INMINENTE! ⚠️", Color(1.0, 0.25, 0.25))
		# Secuencia de explosión tras 0.65s
		var tree := get_tree()
		if tree != null:
			await tree.create_timer(0.65, false, false, true).timeout
		if is_inside_tree() and not is_exploded:
			trigger_explosion()

func _apply_payout(payout: Dictionary, player: Player) -> void:
	var p_type: String = str(payout.get("type", "none"))
	match p_type:
		"jackpot":
			var credits: int = int(payout.get("credits", 250))
			player.run_credits += credits
			var main_scene := get_tree().current_scene
			if main_scene and "hud" in main_scene and main_scene.hud:
				main_scene.hud.update_credits(player.run_credits)
			_spawn_floating_text("🎉 ¡JACKPOT! +%d CRÉDITOS" % credits, Color(1.0, 0.85, 0.2))
			_show_flash_msg("🎉 ¡JACKPOT! +%d CR" % credits, Color(1.0, 0.85, 0.2))
		"bomb":
			player.bomb_count = mini(5, player.bomb_count + 2)
			player.bomb_used.emit(player.bomb_count)
			_spawn_floating_text("💣 ¡+2 BOMBAS TÁCTICAS!", Color(1.0, 0.45, 0.2))
			_show_flash_msg("💣 ¡+2 BOMBAS!", Color(1.0, 0.45, 0.2))
		"magnet":
			ExpBlobScript.trigger_global_magnet(get_tree())
			_spawn_floating_text("🧲 ¡IMÁN GLOBAL ACTIVADO!", Color(0.2, 0.95, 1.0))
			_show_flash_msg("🧲 ¡IMÁN GLOBAL!", Color(0.2, 0.95, 1.0))
		"heal":
			var max_hp: float = player.stats.get_stat(&"max_health") if player.stats else 100.0
			player.heal(max_hp)
			_spawn_floating_text("💖 ¡CURACIÓN TOTAL 100%!", Color(0.2, 1.0, 0.4))
			_show_flash_msg("💖 ¡CURACIÓN 100%!", Color(0.2, 1.0, 0.4))
		"pair":
			var credits: int = int(payout.get("credits", current_spin_cost))
			player.run_credits += credits
			var main_scene := get_tree().current_scene
			if main_scene and "hud" in main_scene and main_scene.hud:
				main_scene.hud.update_credits(player.run_credits)
			_spawn_floating_text("🪙 ¡PAR! REEMBOLSO +%d CR" % credits, Color(0.9, 0.95, 0.35))
			_show_flash_msg("🪙 ¡REEMBOLSO +%d CR!" % credits, Color(0.9, 0.95, 0.35))
		_:
			_spawn_floating_text("❌ ¡SIN PREMIO!", Color(0.7, 0.7, 0.8))
			_show_flash_msg("❌ ¡SIN PREMIO!", Color(0.7, 0.7, 0.8))

func _spawn_floating_text(msg: String, color: Color) -> void:
	var float_lbl := Label.new()
	float_lbl.text = msg
	float_lbl.position = Vector2(-120, -110)
	float_lbl.custom_minimum_size = Vector2(240, 24)
	float_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	float_lbl.add_theme_font_size_override("font_size", 12)
	float_lbl.modulate = color
	add_child(float_lbl)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(float_lbl, "position:y", float_lbl.position.y - 45.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(float_lbl, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(float_lbl.queue_free)

func _show_flash_msg(msg: String, color: Color) -> void:
	if _msg_label:
		_msg_label.text = msg
		_msg_label.modulate = color

func _update_info_display() -> void:
	if _info_label:
		_info_label.text = "🪙 %d CR  |  🔥 x%d USOS" % [current_spin_cost, remaining_uses]

func get_current_cost() -> int:
	return current_spin_cost

func has_uses_remaining() -> bool:
	return remaining_uses > 0

func record_use() -> void:
	consume_spin()

func consume_spin() -> void:
	remaining_uses -= 1
	current_spin_cost += COST_INCREMENT

func trigger_explosion() -> void:
	if is_exploded:
		return
	is_exploded = true
	var exp_pos := position if position != Vector2.ZERO else global_position
	exploded.emit(exp_pos)
	queue_free()

## Método de evaluación de pagos compatible con las suites de prueba existentes
static func evaluate_payout(symbols: Array, spin_cost: int = 50) -> Dictionary:
	if symbols.size() < 3:
		return { "type": "none", "credits": 0, "bombs": 0, "magnet": false, "heal": false }
	var s1: String = str(symbols[0])
	var s2: String = str(symbols[1])
	var s3: String = str(symbols[2])
	var is_jackpot: bool = (s1 == s2 and s2 == s3)
	var is_pair: bool = (s1 == s2 or s2 == s3 or s1 == s3)

	if is_jackpot:
		if s1 == "💰" or s1 == "gold":
			return { "type": "jackpot", "credits": spin_cost * 5, "bombs": 0, "magnet": false, "heal": false }
		elif s1 == "💣" or s1 == "bomb":
			return { "type": "bomb", "credits": 0, "bombs": 2, "magnet": false, "heal": false }
		elif s1 == "🧲" or s1 == "magnet":
			return { "type": "magnet", "credits": 0, "bombs": 0, "magnet": true, "heal": false }
		elif s1 == "💖" or s1 == "heart":
			return { "type": "heal", "credits": 0, "bombs": 0, "magnet": false, "heal": true }
		else:
			return { "type": "jackpot", "credits": spin_cost * 5, "bombs": 0, "magnet": false, "heal": false }
	elif is_pair:
		return { "type": "pair", "credits": spin_cost, "bombs": 0, "magnet": false, "heal": false }
	else:
		return { "type": "none", "credits": 0, "bombs": 0, "magnet": false, "heal": false }
