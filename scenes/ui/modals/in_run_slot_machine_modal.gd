class_name InRunSlotMachineModal
extends CanvasLayer

signal spin_completed(outcome: Dictionary)
signal modal_closed()

var current_beacon: Node2D = null
var current_player: Player = null
var is_spinning: bool = false

const SYMBOLS: Array[String] = ["💰", "💣", "🧲", "💖", "⭐"]

# UI Nodes
var _panel: PanelContainer
var _title_label: Label
var _uses_label: Label
var _credits_label: Label
var _reels_container: HBoxContainer
var _reel_labels: Array[Label] = []
var _result_label: Label
var _spin_button: Button
var _close_button: Button

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()

func _build_ui() -> void:
	# Dim background
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(580, 440)
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.16, 0.95)
	sb.border_color = Color(0.95, 0.75, 0.1, 1.0) # Gold border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "🎰 TRAGAMONEDAS ESTELAR 🎰"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	vbox.add_child(_title_label)

	# Subtitle / Uses info
	var info_box := HBoxContainer.new()
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(info_box)

	_uses_label = Label.new()
	_uses_label.text = "Usos restantes: 3"
	_uses_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2, 1.0))
	info_box.add_child(_uses_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(24, 0)
	info_box.add_child(spacer)

	_credits_label = Label.new()
	_credits_label.text = "Créditos: 0"
	_credits_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0, 1.0))
	info_box.add_child(_credits_label)

	# Reels Display
	var reels_frame := PanelContainer.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.04, 0.02, 0.08, 0.9)
	rsb.border_color = Color(0.6, 0.4, 0.9, 0.8)
	rsb.set_border_width_all(2)
	rsb.set_corner_radius_all(8)
	rsb.content_margin_left = 20
	rsb.content_margin_right = 20
	rsb.content_margin_top = 16
	rsb.content_margin_bottom = 16
	reels_frame.add_theme_stylebox_override("panel", rsb)
	vbox.add_child(reels_frame)

	_reels_container = HBoxContainer.new()
	_reels_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_reels_container.add_theme_constant_override("separation", 28)
	reels_frame.add_child(_reels_container)

	_reel_labels.clear()
	for i in range(3):
		var reel_bg := PanelContainer.new()
		var reel_sb := StyleBoxFlat.new()
		reel_sb.bg_color = Color(0.12, 0.08, 0.22, 1.0)
		reel_sb.set_corner_radius_all(6)
		reel_bg.custom_minimum_size = Vector2(90, 90)
		reel_bg.add_theme_stylebox_override("panel", reel_sb)
		
		var r_label := Label.new()
		r_label.text = "7"
		r_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r_label.add_theme_font_size_override("font_size", 44)
		reel_bg.add_child(r_label)
		
		_reels_container.add_child(reel_bg)
		_reel_labels.append(r_label)

	# Result announcement
	_result_label = Label.new()
	_result_label.text = "¡Prueba tu suerte! Gasta créditos para activar la máquina."
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 15)
	_result_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 1.0))
	vbox.add_child(_result_label)

	# Action Buttons
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 18)
	vbox.add_child(btn_box)

	_spin_button = Button.new()
	_spin_button.text = "🎰 GIRAR RODILLOS (50 Créditos)"
	_spin_button.custom_minimum_size = Vector2(280, 48)
	_spin_button.pressed.connect(_on_spin_pressed)
	btn_box.add_child(_spin_button)

	_close_button = Button.new()
	_close_button.text = "SALIR"
	_close_button.custom_minimum_size = Vector2(100, 48)
	_close_button.pressed.connect(_on_close_pressed)
	btn_box.add_child(_close_button)

func open_slot_machine(beacon: Node2D, player: Player) -> void:
	current_beacon = beacon
	current_player = player
	is_spinning = false
	_update_ui_state()
	_result_label.text = "¡Prueba tu suerte! Gasta créditos para activar la máquina."
	_reel_labels[0].text = "💰"
	_reel_labels[1].text = "⭐"
	_reel_labels[2].text = "💰"
	show()
	get_tree().paused = true
	_spin_button.grab_focus()

func _update_ui_state() -> void:
	if not current_beacon or not current_player:
		return
	_uses_label.text = "🔥 Usos antes de detonar: %d" % current_beacon.remaining_uses
	_credits_label.text = "💳 Tus Créditos: %d" % current_player.run_credits
	_spin_button.text = "🎰 GIRAR RODILLOS (%d Créditos)" % current_beacon.current_spin_cost
	_spin_button.disabled = (current_player.run_credits < current_beacon.current_spin_cost) or is_spinning

func _on_spin_pressed() -> void:
	if is_spinning or not current_beacon or not current_player:
		return
	if current_player.run_credits < current_beacon.current_spin_cost:
		_result_label.text = "❌ ¡Créditos insuficientes!"
		return

	# Deduct credits
	current_player.run_credits -= current_beacon.current_spin_cost
	is_spinning = true
	_spin_button.disabled = true
	_close_button.disabled = true
	_result_label.text = "⚡ ¡Girando rodillos...!"
	_update_ui_state()

	# Spin animation
	_animate_reels()

func _animate_reels() -> void:
	var final_symbols: Array[String] = [
		SYMBOLS[randi() % SYMBOLS.size()],
		SYMBOLS[randi() % SYMBOLS.size()],
		SYMBOLS[randi() % SYMBOLS.size()]
	]
	
	# Small chance of rigged win for better game feel (25% chance of 3x match)
	if randf() < 0.25:
		var lucky_symbol: String = SYMBOLS[randi() % SYMBOLS.size()]
		final_symbols = [lucky_symbol, lucky_symbol, lucky_symbol]
	elif randf() < 0.40:
		var lucky_symbol: String = SYMBOLS[randi() % SYMBOLS.size()]
		final_symbols[0] = lucky_symbol
		final_symbols[1] = lucky_symbol

	var steps := 12
	var timer := get_tree().create_timer(0.08, true, false, true)
	for s in range(steps):
		for i in range(3):
			_reel_labels[i].text = SYMBOLS[randi() % SYMBOLS.size()]
		await get_tree().create_timer(0.08, true, false, true).timeout

	# Set final results
	for i in range(3):
		_reel_labels[i].text = final_symbols[i]

func evaluate_payout(symbols: Array, spin_cost: int = 50) -> Dictionary:
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

func _resolve_payout(symbols: Array[String]) -> void:
	is_spinning = false
	_close_button.disabled = false
	
	var s1 := symbols[0]
	var s2 := symbols[1]
	var s3 := symbols[2]
	
	var is_jackpot: bool = (s1 == s2 and s2 == s3)
	var is_pair: bool = (s1 == s2 or s2 == s3 or s1 == s3)
	
	var payout_type := "none"
	var credits_won := 0

	if is_jackpot:
		match s1:
			"💰":
				credits_won = current_beacon.current_spin_cost * 4
				current_player.run_credits += credits_won
				_result_label.text = "🌟 ¡¡JACKPOT DE CRÉDITOS!! Ganaste %d Créditos." % credits_won
				payout_type = "jackpot_credits"
			"💣":
				_result_label.text = "💣 ¡TRIPLE BOMBA! ¡Recibes +2 Bombas instantáneas!"
				if "bombs_available" in current_player:
					current_player.bombs_available += 2
				payout_type = "jackpot_bombs"
			"🧲":
				_result_label.text = "🧲 ¡IMÁN CÓSMICO! Atrayendo todos los minerales del sector."
				_trigger_global_magnet()
				payout_type = "jackpot_magnet"
			"💖":
				_result_label.text = "💖 ¡REGENERACIÓN SUPREMA! Vida y escudos al 100%."
				if current_player.has_method("heal"):
					current_player.heal(9999.0)
				payout_type = "jackpot_heal"
			"⭐":
				credits_won = current_beacon.current_spin_cost * 5
				current_player.run_credits += credits_won
				_result_label.text = "⭐ ¡¡SUERTE ESTELAR MÁXIMA!! Ganaste %d Créditos." % credits_won
				payout_type = "jackpot_stars"
	elif is_pair:
		credits_won = current_beacon.current_spin_cost
		current_player.run_credits += credits_won
		_result_label.text = "✨ ¡Par Coincidente! Recuperas %d Créditos." % credits_won
		payout_type = "pair_refund"
	else:
		_result_label.text = "❌ Sin coincidencias. ¡Mejor suerte en la próxima!"

	spin_completed.emit({
		"symbols": symbols,
		"is_jackpot": is_jackpot,
		"payout_type": payout_type,
		"credits_won": credits_won
	})

	# Consume use and check explosion
	if current_beacon:
		current_beacon.consume_spin()
		if current_beacon.remaining_uses <= 0:
			_result_label.text += "\n⚠️ ¡LA MÁQUINA SE HA SOBRECALENTADO Y VA A EXPLOTAR!"
			_spin_button.disabled = true
			await get_tree().create_timer(1.2, true, false, true).timeout
			_on_close_pressed()
			if current_beacon:
				current_beacon.trigger_explosion()
			return

	_update_ui_state()

func _trigger_global_magnet() -> void:
	if not is_instance_valid(current_player):
		return
	var tree := get_tree()
	if not tree:
		return
	var exp_blobs = tree.get_nodes_in_group("exp_blob")
	for blob in exp_blobs:
		if is_instance_valid(blob) and blob.has_method("start_magnet_homing"):
			blob.start_magnet_homing(current_player)

func _on_close_pressed() -> void:
	hide()
	var tree := get_tree()
	if tree:
		tree.paused = false
	modal_closed.emit()
