class_name SlotMachineMarqueeDisplay
extends Node2D

## Componente visual flotante estilo Arcade Marquee para SlotMachineBeacon.
## Administra el renderizado del marquesina con luces neón, cajas de rodillos,
## etiquetas de texto, animaciones de tirada y mensajes flotantes.

var _marquee_node: Node2D
var _reel_labels: Array[Label] = []
var _info_label: Label
var _msg_label: Label

func setup_display(parent: Node2D) -> void:
	_marquee_node = Node2D.new()
	_marquee_node.position = Vector2(0, -68)
	parent.add_child(_marquee_node)

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
	var start_x: float = -46.0
	var spacing: float = 46.0
	_reel_labels.clear()

	for i: int in range(3):
		var cell_x: float = start_x + (float(i) * spacing)
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

func update_info_display(current_spin_cost: int, remaining_uses: int) -> void:
	if _info_label:
		_info_label.text = "🪙 %d CR  |  🔥 x%d USOS" % [current_spin_cost, remaining_uses]

func show_flash_msg(msg: String, color: Color) -> void:
	if _msg_label:
		_msg_label.text = msg
		_msg_label.modulate = color

func spawn_floating_text(parent: Node2D, msg: String, color: Color) -> void:
	var float_lbl := Label.new()
	float_lbl.text = msg
	float_lbl.position = Vector2(-120, -110)
	float_lbl.custom_minimum_size = Vector2(240, 24)
	float_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	float_lbl.add_theme_font_size_override("font_size", 12)
	float_lbl.modulate = color
	parent.add_child(float_lbl)

	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(float_lbl, "position:y", float_lbl.position.y - 45.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(float_lbl, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(float_lbl.queue_free)

func animate_spin(symbols_pool: Array[String], final_symbols: Array[String], tree: SceneTree) -> void:
	var steps: int = 12
	for step: int in range(steps):
		if not is_instance_valid(_marquee_node) or not _marquee_node.is_inside_tree():
			return
		for r_idx: int in range(mini(3, _reel_labels.size())):
			if step >= 7 and r_idx == 0:
				_reel_labels[0].text = final_symbols[0]
			elif step >= 9 and r_idx == 1:
				_reel_labels[1].text = final_symbols[1]
			elif step >= 11 and r_idx == 2:
				_reel_labels[2].text = final_symbols[2]
			else:
				_reel_labels[r_idx].text = symbols_pool[randi() % symbols_pool.size()]

		if tree == null:
			return
		await tree.create_timer(0.07, false, false, true).timeout

	if not is_instance_valid(_marquee_node) or not _marquee_node.is_inside_tree():
		return

	for r_idx: int in range(mini(3, _reel_labels.size())):
		_reel_labels[r_idx].text = final_symbols[r_idx]
