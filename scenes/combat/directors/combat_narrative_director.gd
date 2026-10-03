class_name CombatNarrativeDirector
extends Node

## Director modular de secuencias narrativas, diálogos (Dialogic) y cinemáticas de combate.
## Gestiona el prólogo táctico, advertencias de mascotas/navegadoras, duelos de rivales y victorias.

signal briefing_completed(bonus_awarded: bool)
signal dialogue_started()
signal dialogue_ended()
signal rival_duel_engaged(rival: Node2D)
signal victory_screen_requested(victory_data: Dictionary)

var main_game: Node = null
var player: CharacterBody2D = null
var hud: Node = null
var skip_badge_layer: CanvasLayer = null
var active_navigator_controller: Node = null
var audio_duck_manager: Node = null

var is_briefing_active: bool = false
var is_cockpit_active: bool = false
var is_boss_transmission_active: bool = false
var is_rival_cinematic_active: bool = false
var is_victory_dialogue_active: bool = false
var prologue_bonus_chosen: bool = false

var pending_victory_data: Dictionary = {}
var on_dialogue_finished_callback: Callable = Callable()

func setup(p_main_game: Node, p_player: CharacterBody2D, p_hud: Node, p_skip_badge: CanvasLayer, p_audio_duck: Node) -> void:
	main_game = p_main_game
	player = p_player
	hud = p_hud
	skip_badge_layer = p_skip_badge
	audio_duck_manager = p_audio_duck

func get_dialogic() -> Node:
	if not is_inside_tree():
		var tree := Engine.get_main_loop() as SceneTree
		return tree.root.get_node_or_null("Dialogic") if tree and tree.root else null
	return get_node_or_null("/root/Dialogic")

func is_dialogue_active() -> bool:
	if is_rival_cinematic_active or is_briefing_active or is_cockpit_active or is_boss_transmission_active or is_victory_dialogue_active:
		return true
	var dialogic := get_dialogic()
	if dialogic and "current_timeline" in dialogic and dialogic.current_timeline != null:
		if dialogic.has_method("get_subsystem"):
			var styles = dialogic.get_subsystem("Styles")
			if styles and styles.has_method("has_active_layout_node") and styles.has_active_layout_node():
				var l_node = styles.get_layout_node()
				if is_instance_valid(l_node) and l_node.is_inside_tree():
					if "visible" in l_node:
						return bool(l_node.visible)
					elif l_node.has_method("is_visible_in_tree"):
						return l_node.is_visible_in_tree()
					return true
				return false
		return false
	return false

func start_prologue_briefing() -> void:
	is_briefing_active = true
	get_tree().paused = true
	if skip_badge_layer:
		skip_badge_layer.show()

	# Bonificación inicial silenciosa e inmediata (+50 Créditos)
	if not prologue_bonus_chosen:
		prologue_bonus_chosen = true
		if is_instance_valid(player):
			player.run_credits += 50
			if hud and hud.has_method("update_credits"):
				hud.update_credits(player.run_credits)

	var dialogic_node := get_dialogic()
	if dialogic_node and dialogic_node.has_method("start"):
		var p_id: String = String(player.character_data.character_id).to_lower() if (player and player.character_data and player.character_data.character_id != &"") else "nova"
		if not ["nova", "valentina", "kira", "selene", "roxy", "echo", "nyx"].has(p_id):
			p_id = "nova"
		var pet_id: String = String(SaveManager.get_selected_pet()).to_lower()
		if not ["mochi", "kuro", "luna", "pip", "cosmo"].has(pet_id):
			pet_id = "mochi"

		var pilot_label: String = p_id
		var pet_label: String = pet_id

		var dtl_text := """
join %s (Flipped) left
join %s (Flipped) right
%s: Reactores presurizados y toberas calibradas al 100%%. ¿Telemetría lista, %s?
%s: [wave amp=14.0 freq=3.0]¡Todo verificado! Transfiriendo enlace al canal táctico...[/wave]
leave --All--
""" % [pilot_label, pet_label, pilot_label, pet_label.capitalize(), pet_label]

		var backdrop := main_game.get_node_or_null("DialogueBackdropLayer") if main_game else null
		if backdrop and "hold_dimmer" in backdrop:
			backdrop.hold_dimmer = true
		if hud:
			if hud.has_method("set_hud_visible"):
				hud.set_hud_visible(false)
			else:
				hud.visible = false

		if backdrop and backdrop.has_method("fade_in"):
			backdrop.fade_in(0.2)
			await get_tree().create_timer(0.2, true, false, true).timeout

		var tl := DialogicTimeline.new()
		tl.from_text(dtl_text)
		var layout = dialogic_node.start(tl)
		if layout:
			layout.process_mode = Node.PROCESS_MODE_ALWAYS
			if layout is CanvasLayer:
				layout.layer = 50
			if "canvas_layer" in layout:
				layout.canvas_layer = 50
		_setup_dialogic_audio(layout)
	else:
		is_briefing_active = false
		get_tree().paused = false

func _setup_dialogic_audio(layout: Node) -> void:
	if not layout:
		return
	var type_sound := layout.find_child("DialogicNode_TypeSounds", true, false) as DialogicNode_TypeSounds
	if type_sound:
		type_sound.sounds = [
			preload("res://addons/dialogic/Example Assets/sound-effects/typing1.wav"),
			preload("res://addons/dialogic/Example Assets/sound-effects/typing4.wav")
		]
		type_sound.play_every_character = 1
		type_sound.pitch_variance = 0.2
		type_sound.volume_variance = 0.5

func skip_dialogue() -> void:
	if on_dialogue_finished_callback.is_valid():
		var cb := on_dialogue_finished_callback
		on_dialogue_finished_callback = Callable()
		var dialogic_node := get_dialogic()
		if dialogic_node and "current_timeline" in dialogic_node and dialogic_node.current_timeline != null:
			if dialogic_node.has_method("end_timeline"):
				dialogic_node.end_timeline(true)
		cb.call()
		return

	if is_victory_dialogue_active:
		is_victory_dialogue_active = false
		var v_data := pending_victory_data.duplicate()
		pending_victory_data.clear()
		var dialogic_node := get_dialogic()
		if dialogic_node and "current_timeline" in dialogic_node and dialogic_node.current_timeline != null:
			if dialogic_node.has_method("end_timeline"):
				dialogic_node.end_timeline(true)
		if not v_data.is_empty():
			victory_screen_requested.emit(v_data)
		return

	if is_briefing_active and not prologue_bonus_chosen:
		prologue_bonus_chosen = true
		if is_instance_valid(player):
			player.run_credits += 50
			if hud and hud.has_method("update_credits"):
				hud.update_credits(player.run_credits)

	is_briefing_active = false
	is_cockpit_active = false
	is_boss_transmission_active = false
	if is_rival_cinematic_active:
		is_rival_cinematic_active = false
		var current_rival = main_game.get("current_rival") if main_game else null
		if is_instance_valid(current_rival):
			if current_rival.has_method("start_encounter"):
				current_rival.start_encounter()
			else:
				current_rival.process_mode = Node.PROCESS_MODE_PAUSABLE
		var spawner = main_game.get("enemy_spawner") if main_game else null
		if spawner and spawner.has_method("set_spawning_paused"):
			spawner.set_spawning_paused(false)

	if main_game and main_game.has_method("notify_menu_closed"):
		main_game.notify_menu_closed(0.4)

	var dialogic_node := get_dialogic()
	if dialogic_node and "current_timeline" in dialogic_node and dialogic_node.current_timeline != null:
		if dialogic_node.has_method("end_timeline"):
			dialogic_node.end_timeline(true)

	var cam := get_tree().get_first_node_in_group("camera") as GameCamera2D
	if cam and cam.has_method("clear_cinematic_focus"):
		cam.clear_cinematic_focus()

	if is_instance_valid(player) and player.has_method("resume_movement_control"):
		player.resume_movement_control()

	var backdrop := main_game.get_node_or_null("DialogueBackdropLayer") if main_game else null
	if backdrop:
		if "hold_dimmer" in backdrop:
			backdrop.hold_dimmer = false
		if backdrop.has_method("fade_out"):
			backdrop.fade_out(0.2)

	if hud:
		hud.visible = true

	var lvl_modal = main_game.get("level_up_modal") if main_game else null
	if lvl_modal and lvl_modal.has_method("has_pending_levels") and lvl_modal.has_pending_levels():
		lvl_modal.show_next_level_up()
	elif main_game and not main_game.is_any_combat_modal_active():
		get_tree().paused = false

func on_timeline_started() -> void:
	if skip_badge_layer:
		skip_badge_layer.show()
	if audio_duck_manager and audio_duck_manager.has_method("duck_music"):
		audio_duck_manager.duck_music(true)
	dialogue_started.emit()

func on_timeline_ended() -> void:
	if skip_badge_layer:
		skip_badge_layer.hide()
	if audio_duck_manager and audio_duck_manager.has_method("duck_music"):
		audio_duck_manager.duck_music(false)

	if on_dialogue_finished_callback.is_valid():
		var cb := on_dialogue_finished_callback
		on_dialogue_finished_callback = Callable()
		cb.call()
		return

	if is_victory_dialogue_active:
		is_victory_dialogue_active = false
		var v_data := pending_victory_data.duplicate()
		pending_victory_data.clear()
		if not v_data.is_empty():
			victory_screen_requested.emit(v_data)
		return

	if is_briefing_active:
		if not prologue_bonus_chosen:
			prologue_bonus_chosen = true
			if is_instance_valid(player):
				player.run_credits += 50
				if hud and hud.has_method("update_credits"):
					hud.update_credits(player.run_credits)

		if active_navigator_controller and active_navigator_controller.has_method("show_prologue_transmission"):
			active_navigator_controller.show_prologue_transmission(
				"Enlace táctico verificado, comandante. Estaré en este canal lateral guiándote hacia balizas y objetivos prioritarios en el sector. ¡Despegue autorizado!",
				func() -> void:
					_finish_prologue_and_start_run()
			)
			return
		else:
			_finish_prologue_and_start_run()
			return

	var cam := get_tree().get_first_node_in_group("camera") as GameCamera2D
	if cam and cam.has_method("clear_cinematic_focus"):
		cam.clear_cinematic_focus()

	if is_instance_valid(player) and player.has_method("resume_movement_control"):
		player.resume_movement_control()

	if is_cockpit_active:
		is_cockpit_active = false
		if main_game and main_game.has_method("notify_menu_closed"):
			main_game.notify_menu_closed(0.4)

	if is_boss_transmission_active:
		is_boss_transmission_active = false
		if main_game and main_game.has_method("notify_menu_closed"):
			main_game.notify_menu_closed(0.4)

	if is_rival_cinematic_active:
		is_rival_cinematic_active = false
		var current_rival = main_game.get("current_rival") if main_game else null
		if is_instance_valid(current_rival):
			if current_rival.has_method("start_encounter"):
				current_rival.start_encounter()
			else:
				current_rival.process_mode = Node.PROCESS_MODE_PAUSABLE
		var spawner = main_game.get("enemy_spawner") if main_game else null
		if spawner and spawner.has_method("set_spawning_paused"):
			spawner.set_spawning_paused(false)

	var backdrop := main_game.get_node_or_null("DialogueBackdropLayer") if main_game else null
	if backdrop and not is_briefing_active:
		if "hold_dimmer" in backdrop:
			backdrop.hold_dimmer = false
		if backdrop.has_method("fade_out"):
			backdrop.fade_out(0.2)

	if hud:
		hud.visible = true

	var lvl_modal = main_game.get("level_up_modal") if main_game else null
	if lvl_modal and lvl_modal.has_method("has_pending_levels") and lvl_modal.has_pending_levels():
		lvl_modal.show_next_level_up()
	elif main_game and not main_game.is_any_combat_modal_active():
		get_tree().paused = false

	dialogue_ended.emit()

func _finish_prologue_and_start_run() -> void:
	is_briefing_active = false
	var backdrop := main_game.get_node_or_null("DialogueBackdropLayer") if main_game else null
	if backdrop:
		backdrop.hold_dimmer = false
		if backdrop.has_method("fade_out"):
			backdrop.fade_out(0.25)

	var cam := get_tree().get_first_node_in_group("camera") as GameCamera2D
	if cam and cam.has_method("clear_cinematic_focus"):
		cam.clear_cinematic_focus()

	if hud:
		if hud.has_method("set_hud_visible"):
			hud.call("set_hud_visible", true)
		else:
			hud.visible = true

	if main_game and not main_game.is_any_combat_modal_active():
		get_tree().paused = false

	briefing_completed.emit(prologue_bonus_chosen)

func get_rival_dialogue(rival_pid: StringName, player_pid: StringName) -> Dictionary:
	var r_line := "¡Piloto en mi vector! Detecto armas cargadas. Si no buscas pelea, apaga los motores y déjame pasar."
	var p_line := "Te recibo fuerte y claro. No busco un conflicto innecesario, pero me defenderé si atacas."
	var r_close := "La decisión es tuya: mantén distancia y nos retiraremos... o cruza el perímetro."

	match rival_pid:
		&"nova":
			r_line = "¡Piloto en mi vector! Detecto armas cargadas. Si no buscas pelea, apaga motores y déjame pasar."
		&"valentina":
			r_line = "Aquí Valentina. Mi cuadrante está bajo custodia estricta. Mantén distancia o deberé neutralizarte."
		&"kira":
			r_line = "¡Vaya, vaya! ¿Un intruso en mi sector? Mejor da media vuelta si no quieres terminar como chatarra."
		&"selene":
			r_line = "Cálculos balísticos completados. No tengo hostilidad primaria, pero cruzar activará fuego reactivo."
		&"roxy":
			r_line = "¿Te crees con suerte? Este sector es territorio de caza. Una sola provocación y te pulverizo."
		&"echo":
			r_line = "Frecuencia captada... ecos de batalla en tu estela. Retírate antes de que nuestros destinos colisionen."
		&"nyx":
			r_line = "Las sombras cósmicas no toleran intrusos. Si avanzas un metro más, el Vacío consumirá tu luz."

	match player_pid:
		&"nova":
			p_line = "Te recibo fuerte y claro. Evaluaré la situación... no desates algo de lo que te arrepientas."
		&"valentina":
			p_line = "Aquí el puesto de mando. No buscamos conflicto, pero responderemos con fuerza ante una agresión."
		&"kira":
			p_line = "Relaja los cañones. Si quieres pelea la tendrás, pero si te calmas ambos saldremos ilesos."
		&"selene":
			p_line = "Parámetros registrados. Tomaré la decisión óptima para la preservación de ambas naves."
		&"roxy":
			p_line = "Mucho hablar y poco vuelo. Veremos quién sobrevive si decides cruzar mi camino."
		&"echo":
			p_line = "Entendido... mantendré mis sensores alertas ante cualquier alteración de tu curso."
		&"nyx":
			p_line = "No me intimidan tus amenazas. Conozco la oscuridad mejor que nadie."

	return {
		"rival_line": r_line,
		"player_line": p_line,
		"rival_closing": r_close
	}

func trigger_pet_rival_jump_warning(rival: Node2D, on_finished: Callable = Callable()) -> void:
	var dialogic_node := get_dialogic()
	if not dialogic_node or not dialogic_node.has_method("start"):
		if on_finished.is_valid():
			on_finished.call()
		return

	is_cockpit_active = true
	get_tree().paused = true
	on_dialogue_finished_callback = on_finished
	if skip_badge_layer:
		skip_badge_layer.show()

	var pet_id: String = String(SaveManager.get_selected_pet()).to_lower()
	if not ["mochi", "kuro", "luna", "pip", "cosmo"].has(pet_id):
		pet_id = "mochi"

	var text := "join " + pet_id + " (Flipped) right\n"
	text += pet_id + ": [shake rate=15.0 level=4][color=#ffd700]¡DETECCIÓN DE SALTO HIPERESPACIAL EN NUESTRAS COORDENADAS![/color][/shake]\n"
	text += pet_id + ": Una nave de combate de alta potencia emerge desde el hiperespacio.\n"
	text += pet_id + ": [wave amp=12.0 freq=3.0]Si retrocedemos y mantenemos distancia, se irá pacíficamente... pero si nos acercamos o disparamos, comenzará el combate.[/wave]\n"
	text += "leave --All--\n"

	var tl := DialogicTimeline.new()
	tl.from_text(text)
	var layout = dialogic_node.start(tl)
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
		if layout is CanvasLayer:
			layout.layer = 50
		if "canvas_layer" in layout:
			layout.canvas_layer = 50
		_setup_dialogic_audio(layout)
	else:
		if on_finished.is_valid():
			on_dialogue_finished_callback = Callable()
			on_finished.call()

func trigger_rival_face_to_face_dialogue(rival: Node2D) -> void:
	var dialogic_node := get_dialogic()
	if not dialogic_node or not dialogic_node.has_method("start"):
		on_timeline_ended()
		return

	is_cockpit_active = true
	get_tree().paused = true
	on_dialogue_finished_callback = Callable()
	if skip_badge_layer:
		skip_badge_layer.show()

	var r_pid: StringName = rival.pilot_id if (rival and "pilot_id" in rival) else &"nova"
	var p_pid: StringName = player.character_data.character_id if (player and player.character_data) else &"nova"
	var lines := get_rival_dialogue(r_pid, p_pid)

	var text := "join " + String(r_pid) + " right\n"
	text += "join " + String(p_pid) + " (Flipped) left\n"
	text += String(r_pid) + ": " + lines["rival_line"] + "\n"
	text += String(p_pid) + ": " + lines["player_line"] + "\n"
	text += String(r_pid) + ": " + lines["rival_closing"] + "\n"
	text += "leave --All--\n"

	var tl := DialogicTimeline.new()
	tl.from_text(text)
	var layout = dialogic_node.start(tl)
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
		if layout is CanvasLayer:
			layout.layer = 50
		if "canvas_layer" in layout:
			layout.canvas_layer = 50
		_setup_dialogic_audio(layout)
	else:
		on_timeline_ended()

func trigger_pet_rival_encounter(rival: Node2D) -> void:
	trigger_rival_face_to_face_dialogue(rival)

func trigger_cockpit_interlude() -> void:
	trigger_pet_rival_alert("Piloto Desconocida")

func trigger_pet_rival_alert(pilot_name: String) -> void:
	var current_rival = main_game.get("current_rival") if main_game else null
	if current_rival != null:
		trigger_pet_rival_encounter(current_rival)
		return
	var dialogic_node := get_dialogic()
	if not dialogic_node or not dialogic_node.has_method("start"):
		return
	is_cockpit_active = true
	get_tree().paused = true
	if skip_badge_layer:
		skip_badge_layer.show()

	var pet_id: String = String(SaveManager.get_selected_pet()).to_lower()
	if not ["mochi", "kuro", "luna", "pip", "cosmo"].has(pet_id):
		pet_id = "mochi"

	var text := """
join %s right
%s: [shake rate=15.0 level=4][color=#ffd700]¡DETECCIÓN DE SALTO HIPERESPACIAL EN NUESTRAS COORDENADAS![/color][/shake]
%s: La nave de %s ha entrado al sector proyectando un perímetro de advertencia.
%s: [wave amp=12.0 freq=3.0]Si retrocedemos y mantenemos distancia, se irá pacíficamente... pero si nos acercamos o disparamos, comenzará el combate.[/wave]
leave --All--
""" % [pet_id, pet_id, pet_id, pilot_name, pet_id]

	var tl := DialogicTimeline.new()
	tl.from_text(text)
	var layout = dialogic_node.start(tl)
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
		if layout is CanvasLayer:
			layout.layer = 50
		if "canvas_layer" in layout:
			layout.canvas_layer = 50
	_setup_dialogic_audio(layout)

func trigger_pet_boss_alert(boss_name: String, on_finished: Callable = Callable()) -> void:
	var dialogic_node := get_dialogic()
	if not dialogic_node or not dialogic_node.has_method("start"):
		if on_finished.is_valid():
			on_finished.call()
		return
	is_boss_transmission_active = true
	get_tree().paused = true
	on_dialogue_finished_callback = on_finished
	if skip_badge_layer:
		skip_badge_layer.show()

	var pet_id: String = String(SaveManager.get_selected_pet()).to_lower()
	if not ["mochi", "kuro", "luna", "pip", "cosmo"].has(pet_id):
		pet_id = "mochi"

	var text := """
join %s (Flipped) right
%s: [shake rate=20.0 level=6][color=#ff3333]¡ALERTA DE DISTORSIÓN CRÍTICA EN EL RADAR![/color][/shake]
%s: La firma titánica de %s se ha manifestado en el sector.
%s: [wave amp=15.0 freq=4.0]¡Detectores fijados en el coloso! ¡Prepara los propulsores para esquivar sus proyectiles![/wave]
leave --All--
""" % [pet_id, pet_id, pet_id, boss_name, pet_id]

	var tl := DialogicTimeline.new()
	tl.from_text(text)
	var layout = dialogic_node.start(tl)
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
		if layout is CanvasLayer:
			layout.layer = 50
		if "canvas_layer" in layout:
			layout.canvas_layer = 50
	_setup_dialogic_audio(layout)

func trigger_climax_dialogue(route: String, on_finished: Callable = Callable()) -> void:
	var dialogic_node := get_dialogic()
	if not dialogic_node or not dialogic_node.has_method("start"):
		if on_finished.is_valid():
			on_finished.call()
		return
	is_boss_transmission_active = true
	get_tree().paused = true
	on_dialogue_finished_callback = on_finished
	if skip_badge_layer:
		skip_badge_layer.show()

	var pet_id: String = String(SaveManager.get_selected_pet()).to_lower()
	if not ["mochi", "kuro", "luna", "pip", "cosmo"].has(pet_id):
		pet_id = "mochi"

	var p_pid: StringName = player.character_data.character_id if (player and player.character_data) else &"nova"
	var text := ""

	if route == "pacifist":
		var fleet_lines := {
			&"nova": "¡Estamos contigo, comandante! La Flota de la Esperanza cubre tu retaguardia.",
			&"valentina": "Formación de combate establecida. No permitiremos que caigas ante el Núcleo.",
			&"kira": "¡Armas al máximo! ¡Vamos a romper ese coloso en mil pedazos juntas!",
			&"selene": "Vectores balísticos sincronizados. La probabilidad de victoria es del 100% con nosotras.",
			&"roxy": "Más vale que me dejes el tiro de gracia. ¡Hagamos pedazos a Astra Prime!",
			&"echo": "El destino resuena con luz... volaremos a tu lado hasta el final del cosmos.",
			&"nyx": "La oscuridad del Vacío no prevalecerá hoy. Mis guadañas te protegen."
		}

		text += "join " + pet_id + " right\n"
		text += pet_id + ": [shake rate=20.0 level=6][color=#00e5ff]¡ALERTA CÓSMICA: LLEGADA AL NÚCLEO SUPREMO ASTRA PRIME![/color][/shake]\n"
		text += pet_id + ": ¡Increíble! ¡Las señales de las 5 pilotos que perdonaste emergen del hiperespacio!\n"
		text += "leave " + pet_id + "\n"

		var spared: Array = main_game.get("rivals_spared") if main_game else []
		for pid in spared:
			var line: String = fleet_lines.get(pid, "¡A tu lado hasta la victoria estelar!")
			text += "join " + String(pid) + " right\n"
			text += String(pid) + ": " + line + "\n"
			text += "leave " + String(pid) + "\n"

		text += "join " + String(p_pid) + " (Flipped) left\n"
		text += String(p_pid) + ": ¡Flota de la Esperanza unida! ¡Iniciemos las maniobras para liberar el Núcleo Astra!\n"
		text += "join " + pet_id + " (Flipped) right\n"
		text += pet_id + ": [wave amp=16.0 freq=3.5]¡Todos los reactores al 100%! ¡Por la victoria estelar![/wave]\n"
		text += "leave --All--\n"

	elif route == "slayer":
		var is_player_nyx := (p_pid == &"nyx")
		text += "join " + pet_id + " right\n"
		text += pet_id + ": [shake rate=25.0 level=8][color=#ff0044]¡COLAPSO ESPACIO-TEMPORAL CRÍTICO![/color][/shake]\n"
		text += pet_id + ": ¡Toda la galaxia tiembla por la masacre de las 5 pilotos...! ¡Y una nave de combate apoya al Núcleo Astra Prime!\n"
		text += "leave " + pet_id + "\n"

		if not is_player_nyx:
			text += "join nyx (Flipped) right\n"
			text += "join " + String(p_pid) + " left\n"
			text += "nyx: [shake rate=18.0 level=5][color=#ff1744]¿Creíste que tu carnicería cósmica quedaría impune?[/color][/shake]\n"
			text += "nyx: Has erradicado a cada una de mis compañeras. Sentí sus almas apagarse en el tejido estelar...\n"
			text += "nyx: Astra Prime y yo seremos tus verdugos. ¡El Vacío te devorará por completo!\n"
			text += String(p_pid) + ": Eran obstáculos en mi ascenso estelar. Si te interpones, compartirás su mismo destino.\n"
			text += "nyx: ¡No saldrás con vida de este sector!\n"
			text += "leave --All--\n"
		else:
			var escort_pid: StringName = main_game.call("_get_genocide_escort_pilot_id") if (main_game and main_game.has_method("_get_genocide_escort_pilot_id")) else &"nova"
			var escort_str := String(escort_pid)
			var CharacterDataScript = preload("res://data/characters/character_data.gd")
			var roster: Dictionary = CharacterDataScript.load_roster()
			var e_name: String = roster[escort_pid].display_name if roster.has(escort_pid) else escort_str.capitalize()
			text += "join " + escort_str + " right\n"
			text += "join nyx (Flipped) left\n"
			text += escort_str + ": [shake rate=18.0 level=5][color=#ff1744]¡Nyx! ¿Cómo pudiste traicionar a la Flota?[/color][/shake]\n"
			text += escort_str + ": Asesinaste a mis 5 compañeras sin piedad... ¡escuché sus últimas transmisiones apagarse en el vacío!\n"
			text += escort_str + ": Soy la última que queda en pie. ¡Astra Prime y yo acabaremos con tu demencia aquí y ahora!\n"
			text += "nyx: Eran débiles... se interpusieron en el camino del Vacío. Tú serás la última en extinguirte.\n"
			text += escort_str + ": ¡Por la memoria de la Flota Astra, jamás te permitiré tocar el Núcleo!\n"
			text += "leave --All--\n"

	else: # neutral
		text += "join " + pet_id + " (Flipped) right\n"
		text += "join " + String(p_pid) + " (Flipped) left\n"
		text += pet_id + ": Hemos llegado al epicentro del universo... pero el costo ha sido inmenso.\n"
		text += String(p_pid) + ": Hicimos lo necesario para llegar con vida. Ni santos ni monstruos... solo supervivientes.\n"
		text += pet_id + ": El Núcleo Supremo Astra Prime inicia su escaneo estelar. ¿Cuál será su veredicto?\n"
		text += String(p_pid) + ": Solo hay un veredicto posible para nosotros: salir victoriosos cueste lo que cueste.\n"
		text += "leave --All--\n"

	var tl := DialogicTimeline.new()
	tl.from_text(text)
	var layout = dialogic_node.start(tl)
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
		if layout is CanvasLayer:
			layout.layer = 50
		if "canvas_layer" in layout:
			layout.canvas_layer = 50
	_setup_dialogic_audio(layout)

func trigger_pet_climax_alert(route: String) -> void:
	trigger_climax_dialogue(route)

func trigger_post_boss_victory_dialogue(route: String, victory_data: Dictionary) -> void:
	var dialogic_node := get_dialogic()
	if not dialogic_node or not dialogic_node.has_method("start"):
		if main_game and main_game.has_method("_show_game_over_screen"):
			main_game.call("_show_game_over_screen", victory_data)
		return

	is_victory_dialogue_active = true
	pending_victory_data = victory_data
	get_tree().paused = true
	if skip_badge_layer:
		skip_badge_layer.show()

	var pet_id: String = String(SaveManager.get_selected_pet()).to_lower()
	if not ["mochi", "kuro", "luna", "pip", "cosmo"].has(pet_id):
		pet_id = "mochi"

	var p_pid: StringName = player.character_data.character_id if (player and player.character_data) else &"nova"
	var text := ""

	if route == "pacifist":
		var victory_fleet_lines := {
			&"nova": "¡Lo conseguiste, comandante! El Núcleo Astra vuelve a palpitar en armonía.",
			&"valentina": "Firmas térmicas del Núcleo estabilizadas. Ha sido un honor cubrir tus flancos.",
			&"kira": "¡SIII! ¡Hicimos pedazos a esa monstruosidad! ¡El cosmos nos recordará por esto!",
			&"selene": "Cálculos post-combate finalizados: probabilidad de un nuevo amanecer al 100%. Misión perfecta.",
			&"roxy": "Admito que tienes talento de verdad. Buen vuelo, heroína espacial.",
			&"echo": "Las frecuencias de todas las almas estelares vibran en paz... La Flota de la Esperanza triunfó.",
			&"nyx": "El equilibrio entre luz y oscuridad se preserva. Demostraste el poder de la unión."
		}

		text += "join " + pet_id + " right\n"
		text += pet_id + ": [shake rate=20.0 level=5][color=#00e5ff]¡LO LOGRAMOS! ¡EL NÚCLEO ASTRA SE HA LIBERADO SIN COLAPSO![/color][/shake]\n"
		text += pet_id + ": ¡Los escudos se calman y todas las balizas orbitales resplandecen en señal de paz!\n"
		text += "leave " + pet_id + "\n"

		var spared: Array = main_game.get("rivals_spared") if main_game else []
		for pid in spared:
			var line: String = victory_fleet_lines.get(pid, "¡Misión cumplida! El orden cósmico ha sido restaurado.")
			text += "join " + String(pid) + " (Flipped) right\n"
			text += String(pid) + ": " + line + "\n"
			text += "leave " + String(pid) + "\n"

		text += "join " + String(p_pid) + " left\n"
		text += String(p_pid) + ": ¡Gracias a todas por creer en este camino! Unidas demostramos que la galaxia puede salvarse sin exterminio.\n"
		text += "leave " + String(p_pid) + "\n"

		text += "join " + pet_id + " right\n"
		text += pet_id + ": [wave amp=16.0 freq=3.5]¡Coordenadas de regreso al Hub establecidas! ¡Iniciando salto de victoria estelar![/wave]\n"
		text += "leave --All--\n"

	elif route == "slayer":
		text += "join " + pet_id + " right\n"
		text += pet_id + ": [shake rate=20.0 level=6][color=#ff0044]El Núcleo Astra Prime... ha colapsado en un silencio sepulcral.[/color][/shake]\n"
		text += pet_id + ": No detecto más señales de vida en el radar. Todas las pilotos rivales han perecido en tu cacería...\n"
		text += "leave " + pet_id + "\n"

		text += "join " + String(p_pid) + " left\n"
		if p_pid == &"nyx":
			text += "nyx: El Vacío finalmente lo ha consumido todo. No quedan rivales ni ataduras... solo mi reino en las sombras.\n"
		else:
			text += String(p_pid) + ": Nadie pudo detener mi ascenso. Absorbí cada fragmento de su poder... ahora gobierno el vacío estelar.\n"
		text += "leave " + String(p_pid) + "\n"

		text += "join " + pet_id + " right\n"
		text += pet_id + ": [color=#888888]El trono del cosmos es tuyo, soberano solitario... Iniciando retorno.[/color]\n"
		text += "leave --All--\n"

	else: # neutral
		text += "join " + pet_id + " right\n"
		text += pet_id + ": [shake rate=15.0 level=4][color=#ffd700]¡Astra Prime ha caído![/color][/shake]\n"
		text += pet_id + ": Las lecturas del sector vuelven a niveles seguros. Hemos sobrevivido al coloso.\n"
		text += "leave " + pet_id + "\n"

		text += "join " + String(p_pid) + " left\n"
		text += String(p_pid) + ": Fue una travesía brutal... Tomamos decisiones difíciles en cada sector, pero estamos con vida.\n"
		text += "leave " + String(p_pid) + "\n"

		text += "join " + pet_id + " right\n"
		text += pet_id + ": [wave amp=12.0 freq=3.0]Calculando vector de salida hacia el Hub orbital. ¡Excelente pilotaje, comandante![/wave]\n"
		text += "leave --All--\n"

	var tl := DialogicTimeline.new()
	tl.from_text(text)
	var layout = dialogic_node.start(tl)
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_dialogic_audio(layout)
