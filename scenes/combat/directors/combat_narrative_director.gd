class_name CombatNarrativeDirector
extends Node

## Director modular de secuencias narrativas, diálogos (Dialogic) y cinemáticas de combate.
## Gestiona el prólogo táctico, advertencias de mascotas/navegadoras, duelos de rivales y victorias.

const CombatRadioFeedControllerScript = preload("res://scenes/combat/directors/combat_radio_feed_controller.gd")
const BossCinematicPresenterScript = preload("res://scenes/combat/bosses/boss_cinematic_presenter.gd")

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
	if CinematicDeathSequence.is_sequence_active:
		return

	var is_in_rival_spawn: bool = is_rival_cinematic_active or (main_game != null and main_game.get("is_rival_cinematic_active") == true)
	var is_in_boss_spawn: bool = is_boss_transmission_active or (main_game != null and main_game.get("is_boss_transmission_active") == true)

	if is_in_rival_spawn or is_in_boss_spawn:
		# Salto total inmediato: descartar callbacks encadenados de fases intermedias
		on_dialogue_finished_callback = Callable()

	elif on_dialogue_finished_callback.is_valid():
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
	if main_game:
		main_game.set("is_boss_transmission_active", false)

	if is_rival_cinematic_active or (main_game != null and main_game.get("is_rival_cinematic_active") == true):
		is_rival_cinematic_active = false
		if main_game:
			main_game.set("is_rival_cinematic_active", false)
		var current_rival = main_game.get("current_rival") if main_game else null
		if is_instance_valid(current_rival):
			current_rival.process_mode = Node.PROCESS_MODE_PAUSABLE
			if current_rival.has_method("start_encounter"):
				current_rival.start_encounter()
		if main_game:
			BossCinematicPresenterScript.unfreeze_combat_environment(main_game)

	if is_in_boss_spawn and main_game:
		var current_boss = main_game.get("current_boss")
		if is_instance_valid(current_boss):
			current_boss.process_mode = Node.PROCESS_MODE_PAUSABLE
			current_boss.visible = true
		BossCinematicPresenterScript.unfreeze_combat_environment(main_game)

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

	var is_in_cinematic: bool = is_rival_cinematic_active or (main_game and main_game.get("is_rival_cinematic_active") == true)
	var is_boss_active: bool = is_boss_transmission_active or (main_game and main_game.get("current_boss") != null and main_game.get("current_boss").get_meta("_is_emerging", false))

	if not is_in_cinematic and not is_boss_active:
		var cam := get_tree().get_first_node_in_group("camera") as GameCamera2D
		if cam and cam.has_method("clear_cinematic_focus"):
			cam.clear_cinematic_focus()

		if is_instance_valid(player) and player.has_method("resume_movement_control"):
			player.resume_movement_control()

	if is_cockpit_active:
		is_cockpit_active = false
		if not is_in_cinematic and not is_boss_active and main_game and main_game.has_method("notify_menu_closed"):
			main_game.notify_menu_closed(0.4)

	if is_boss_transmission_active:
		is_boss_transmission_active = false
		if not is_boss_active and main_game and main_game.has_method("notify_menu_closed"):
			main_game.notify_menu_closed(0.4)

	if is_rival_cinematic_active:
		is_rival_cinematic_active = false
		var current_rival = main_game.get("current_rival") if main_game else null
		if is_instance_valid(current_rival):
			current_rival.process_mode = Node.PROCESS_MODE_PAUSABLE
			if current_rival.has_method("start_encounter"):
				current_rival.start_encounter()
		if main_game:
			BossCinematicPresenterScript.unfreeze_combat_environment(main_game)
		var cam := get_tree().get_first_node_in_group("camera") as GameCamera2D
		if cam and cam.has_method("clear_cinematic_focus"):
			cam.clear_cinematic_focus()
		if is_instance_valid(player) and player.has_method("resume_movement_control"):
			player.resume_movement_control()

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
	return CombatRadioFeedControllerScript.get_rival_dialogue(rival_pid, player_pid)

func trigger_pet_rival_jump_warning(rival: Node2D, on_finished: Callable = Callable()) -> void:
	CombatRadioFeedControllerScript.trigger_pet_rival_jump_warning(self, rival, on_finished)

func trigger_rival_face_to_face_dialogue(rival: Node2D) -> void:
	CombatRadioFeedControllerScript.trigger_rival_face_to_face_dialogue(self, rival)

func trigger_pet_rival_encounter(rival: Node2D) -> void:
	trigger_rival_face_to_face_dialogue(rival)

func trigger_cockpit_interlude() -> void:
	trigger_pet_rival_alert("Piloto Desconocida")

func trigger_pet_rival_alert(pilot_name: String) -> void:
	CombatRadioFeedControllerScript.trigger_pet_rival_alert(self, pilot_name)

func trigger_pet_boss_alert(boss_name: String, on_finished: Callable = Callable()) -> void:
	CombatRadioFeedControllerScript.trigger_pet_boss_alert(self, boss_name, on_finished)

func trigger_climax_dialogue(route: String, on_finished: Callable = Callable()) -> void:
	CombatRadioFeedControllerScript.trigger_climax_dialogue(self, route, on_finished)

func trigger_pet_climax_alert(route: String) -> void:
	trigger_climax_dialogue(route)

func trigger_post_boss_victory_dialogue(route: String, victory_data: Dictionary) -> void:
	CombatRadioFeedControllerScript.trigger_post_boss_victory_dialogue(self, route, victory_data)
