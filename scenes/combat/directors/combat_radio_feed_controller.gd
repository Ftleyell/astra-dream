class_name CombatRadioFeedController
extends RefCounted

## Controlador modular para transmisiones de radio tácticas, alertas de mascotas y diálogos de rivales/clímax.
## Desacopla la generación de scripts de Dialogic, diálogos condicionales y locuciones del director de flujo narrativo.

const CharacterDataScript = preload("res://data/characters/character_data.gd")

static func get_rival_dialogue(rival_pid: StringName, player_pid: StringName) -> Dictionary:
	var r_line: String = "¡Piloto en mi vector! Detecto armas cargadas. Si no buscas pelea, apaga los motores y déjame pasar."
	var p_line: String = "Te recibo fuerte y claro. No busco un conflicto innecesario, pero me defenderé si atacas."
	var r_close: String = "La decisión es tuya: mantén distancia y nos retiraremos... o cruza el perímetro."

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

static func trigger_pet_rival_jump_warning(director: Node, rival: Node2D, on_finished: Callable = Callable()) -> void:
	var dialogic_node: Node = director.call("get_dialogic") if director.has_method("get_dialogic") else null
	if not dialogic_node or not dialogic_node.has_method("start"):
		if on_finished.is_valid():
			on_finished.call()
		return

	director.set("is_cockpit_active", true)
	director.get_tree().paused = true
	director.set("on_dialogue_finished_callback", on_finished)
	var skip_badge = director.get("skip_badge_layer")
	if skip_badge:
		skip_badge.show()

	var pet_id: String = String(SaveManager.get_selected_pet()).to_lower()
	if not ["mochi", "kuro", "luna", "pip", "cosmo"].has(pet_id):
		pet_id = "mochi"

	var text: String = "join " + pet_id + " (Flipped) right\n"
	text += pet_id + ": [shake rate=15.0 level=4][color=#ffd700]¡DETECCIÓN DE SALTO HIPERESPACIAL EN NUESTRAS COORDENADAS![/color][/shake]\n"
	text += pet_id + ": Una nave de combate de alta potencia emerge desde el hiperespacio.\n"
	text += pet_id + ": [wave amp=12.0 freq=3.0]Si retrocedemos y mantenemos distancia, se irá pacíficamente... pero si nos acercamos o disparamos, comenzará el combate.[/wave]\n"
	text += "leave --All--\n"

	var tl := DialogicTimeline.new()
	tl.from_text(text)
	var layout: Node = dialogic_node.start(tl)
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
		if layout is CanvasLayer:
			layout.layer = 50
		if "canvas_layer" in layout:
			layout.canvas_layer = 50
		if director.has_method("_setup_dialogic_audio"):
			director.call("_setup_dialogic_audio", layout)
	else:
		if on_finished.is_valid():
			director.set("on_dialogue_finished_callback", Callable())
			on_finished.call()

static func trigger_rival_face_to_face_dialogue(director: Node, rival: Node2D) -> void:
	var dialogic_node: Node = director.call("get_dialogic") if director.has_method("get_dialogic") else null
	if not dialogic_node or not dialogic_node.has_method("start"):
		if director.has_method("on_timeline_ended"):
			director.call("on_timeline_ended")
		return

	director.set("is_cockpit_active", true)
	director.get_tree().paused = true
	director.set("on_dialogue_finished_callback", Callable())
	var skip_badge = director.get("skip_badge_layer")
	if skip_badge:
		skip_badge.show()

	var player = director.get("player")
	var r_pid: StringName = rival.pilot_id if (rival and "pilot_id" in rival) else &"nova"
	var p_pid: StringName = player.character_data.character_id if (player and player.character_data) else &"nova"
	var lines: Dictionary = get_rival_dialogue(r_pid, p_pid)

	var text: String = "join " + String(r_pid) + " right\n"
	text += "join " + String(p_pid) + " (Flipped) left\n"
	text += String(r_pid) + ": " + lines["rival_line"] + "\n"
	text += String(p_pid) + ": " + lines["player_line"] + "\n"
	text += String(r_pid) + ": " + lines["rival_closing"] + "\n"
	text += "leave --All--\n"

	var tl := DialogicTimeline.new()
	tl.from_text(text)
	var layout: Node = dialogic_node.start(tl)
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
		if layout is CanvasLayer:
			layout.layer = 50
		if "canvas_layer" in layout:
			layout.canvas_layer = 50
		if director.has_method("_setup_dialogic_audio"):
			director.call("_setup_dialogic_audio", layout)
	else:
		if director.has_method("on_timeline_ended"):
			director.call("on_timeline_ended")

static func trigger_pet_rival_alert(director: Node, pilot_name: String) -> void:
	var main_game = director.get("main_game")
	var current_rival = main_game.get("current_rival") if main_game else null
	if current_rival != null:
		trigger_rival_face_to_face_dialogue(director, current_rival)
		return

	var dialogic_node: Node = director.call("get_dialogic") if director.has_method("get_dialogic") else null
	if not dialogic_node or not dialogic_node.has_method("start"):
		return

	director.set("is_cockpit_active", true)
	director.get_tree().paused = true
	var skip_badge = director.get("skip_badge_layer")
	if skip_badge:
		skip_badge.show()

	var pet_id: String = String(SaveManager.get_selected_pet()).to_lower()
	if not ["mochi", "kuro", "luna", "pip", "cosmo"].has(pet_id):
		pet_id = "mochi"

	var text: String = """
join %s right
%s: [shake rate=15.0 level=4][color=#ffd700]¡DETECCIÓN DE SALTO HIPERESPACIAL EN NUESTRAS COORDENADAS![/color][/shake]
%s: La nave de %s ha entrado al sector proyectando un perímetro de advertencia.
%s: [wave amp=12.0 freq=3.0]Si retrocedemos y mantenemos distancia, se irá pacíficamente... pero si nos acercamos o disparamos, comenzará el combate.[/wave]
leave --All--
""" % [pet_id, pet_id, pet_id, pilot_name, pet_id]

	var tl := DialogicTimeline.new()
	tl.from_text(text)
	var layout: Node = dialogic_node.start(tl)
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
		if layout is CanvasLayer:
			layout.layer = 50
		if "canvas_layer" in layout:
			layout.canvas_layer = 50
		if director.has_method("_setup_dialogic_audio"):
			director.call("_setup_dialogic_audio", layout)

static func trigger_pet_boss_alert(director: Node, boss_name: String, on_finished: Callable = Callable()) -> void:
	var dialogic_node: Node = director.call("get_dialogic") if director.has_method("get_dialogic") else null
	if not dialogic_node or not dialogic_node.has_method("start"):
		if on_finished.is_valid():
			on_finished.call()
		return

	director.set("is_boss_transmission_active", true)
	director.get_tree().paused = true
	director.set("on_dialogue_finished_callback", on_finished)
	var skip_badge = director.get("skip_badge_layer")
	if skip_badge:
		skip_badge.show()

	var pet_id: String = String(SaveManager.get_selected_pet()).to_lower()
	if not ["mochi", "kuro", "luna", "pip", "cosmo"].has(pet_id):
		pet_id = "mochi"

	var text: String = """
join %s (Flipped) right
%s: [shake rate=20.0 level=6][color=#ff3333]¡ALERTA DE DISTORSIÓN CRÍTICA EN EL RADAR![/color][/shake]
%s: La firma titánica de %s se ha manifestado en el sector.
%s: [wave amp=15.0 freq=4.0]¡Detectores fijados en el coloso! ¡Prepara los propulsores para esquivar sus proyectiles![/wave]
leave --All--
""" % [pet_id, pet_id, pet_id, boss_name, pet_id]

	var tl := DialogicTimeline.new()
	tl.from_text(text)
	var layout: Node = dialogic_node.start(tl)
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
		if layout is CanvasLayer:
			layout.layer = 50
		if "canvas_layer" in layout:
			layout.canvas_layer = 50
		if director.has_method("_setup_dialogic_audio"):
			director.call("_setup_dialogic_audio", layout)

static func trigger_climax_dialogue(director: Node, route: String, on_finished: Callable = Callable()) -> void:
	var dialogic_node: Node = director.call("get_dialogic") if director.has_method("get_dialogic") else null
	if not dialogic_node or not dialogic_node.has_method("start"):
		if on_finished.is_valid():
			on_finished.call()
		return

	director.set("is_boss_transmission_active", true)
	director.get_tree().paused = true
	director.set("on_dialogue_finished_callback", on_finished)
	var skip_badge = director.get("skip_badge_layer")
	if skip_badge:
		skip_badge.show()

	var pet_id: String = String(SaveManager.get_selected_pet()).to_lower()
	if not ["mochi", "kuro", "luna", "pip", "cosmo"].has(pet_id):
		pet_id = "mochi"

	var player = director.get("player")
	var p_pid: StringName = player.character_data.character_id if (player and player.character_data) else &"nova"
	var main_game = director.get("main_game")
	var text: String = ""

	if route == "pacifist":
		var fleet_lines: Dictionary = {
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
		var is_player_nyx: bool = (p_pid == &"nyx")
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
			var escort_str: String = String(escort_pid)
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
	var layout: Node = dialogic_node.start(tl)
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
		if layout is CanvasLayer:
			layout.layer = 50
		if "canvas_layer" in layout:
			layout.canvas_layer = 50
		if director.has_method("_setup_dialogic_audio"):
			director.call("_setup_dialogic_audio", layout)

static func trigger_post_boss_victory_dialogue(director: Node, route: String, victory_data: Dictionary) -> void:
	var dialogic_node: Node = director.call("get_dialogic") if director.has_method("get_dialogic") else null
	var main_game = director.get("main_game")
	if not dialogic_node or not dialogic_node.has_method("start"):
		if main_game and main_game.has_method("_show_game_over_screen"):
			main_game.call("_show_game_over_screen", victory_data)
		return

	director.set("is_victory_dialogue_active", true)
	director.set("pending_victory_data", victory_data)
	director.get_tree().paused = true
	var skip_badge = director.get("skip_badge_layer")
	if skip_badge:
		skip_badge.show()

	var pet_id: String = String(SaveManager.get_selected_pet()).to_lower()
	if not ["mochi", "kuro", "luna", "pip", "cosmo"].has(pet_id):
		pet_id = "mochi"

	var player = director.get("player")
	var p_pid: StringName = player.character_data.character_id if (player and player.character_data) else &"nova"
	var text: String = ""

	if route == "pacifist":
		var victory_fleet_lines: Dictionary = {
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
	var layout: Node = dialogic_node.start(tl)
	if layout:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
		if director.has_method("_setup_dialogic_audio"):
			director.call("_setup_dialogic_audio", layout)
