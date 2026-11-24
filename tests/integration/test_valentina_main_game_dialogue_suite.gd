class_name TestValentinaMainGameDialogueSuite
extends BaseTestSuite
## Verifica la integración real de Valentina v2 Living Dialogue Portraits en
## DialogueBackdropLayer + Dialogic 2 y durante el prólogo de MainGame.

const BackdropScene: PackedScene = preload("res://scenes/ui/dialogue/dialogue_backdrop_layer.tscn")
const MainGameScene: PackedScene = preload("res://scenes/combat/main_game.tscn")
const PortraitCtrlScript = preload("res://scenes/pilots/dialogue/pilot_dialogue_portrait_controller.gd")


func _ready() -> void:
	timeout_seconds = 14.0
	super._ready()
	await _run_tests()


func _run_tests() -> void:
	await _test_dialogic_backdrop_bridge()
	await _test_main_game_prologue_with_valentina()
	pass_suite("Integración de Valentina v2 Living Dialogue Portrait en Dialogic y MainGame verificada al 100%")


func _test_dialogic_backdrop_bridge() -> void:
	var backdrop: CanvasLayer = BackdropScene.instantiate() as CanvasLayer
	assert_true(backdrop != null, "Debe instanciar DialogueBackdropLayer")
	add_child(backdrop)

	# 1. Flipped (neutral base) + Mochi en Dialogic real
	var res_a: Dictionary = await _run_valentina_timeline(
		"join valentina (Flipped) left\njoin mochi (Flipped) right\nvalentina: Órbita estabilizada.\nleave --All--\n"
	)
	var val_char_a: Node = res_a.get("char_node", null) as Node
	var val_sprite_a: Sprite2D = res_a.get("sprite", null) as Sprite2D
	var ctrl_a: PortraitCtrlScript = res_a.get("ctrl", null) as PortraitCtrlScript
	assert_true(ctrl_a != null, "Debe montarse LivingDialoguePortraitController bajo Valentina")
	assert_true(ctrl_a.process_mode == Node.PROCESS_MODE_ALWAYS, "Controlador debe usar PROCESS_MODE_ALWAYS")
	assert_true(is_equal_approx(val_sprite_a.self_modulate.a, 0.0), "Sprite estático de Dialogic debe quedar oculto (alpha 0.0)")
	if "scale" in val_char_a:
		assert_true((val_char_a.get("scale") as Vector2).is_equal_approx(Vector2.ONE), "Contenedor padre no debe escalarse doble")
	if "modulate" in val_char_a:
		assert_true((val_char_a.get("modulate") as Color).is_equal_approx(Color.WHITE), "Contenedor padre no debe atenuarse doble")
	assert_true(ctrl_a.get_current_emotion() == &"neutral", "Flipped debe sincronizar emoción neutral")
	assert_true(not ctrl_a.is_mirrored(), "Slot izquierdo no debe reflejar espejado")

	Dialogic.end_timeline(true)
	for _i: int in range(4):
		await get_tree().process_frame

	# 2. Focused
	var res_f: Dictionary = await _run_valentina_timeline(
		"join valentina (Focused) left\nvalentina (Focused): Blanco fijado.\nleave --All--\n"
	)
	var ctrl_f: PortraitCtrlScript = res_f.get("ctrl", null) as PortraitCtrlScript
	assert_true(ctrl_f != null and ctrl_f.get_current_emotion() == &"focused", "Debe sincronizar emoción focused en Dialogic")
	Dialogic.end_timeline(true)
	for _j: int in range(3):
		await get_tree().process_frame

	# 3. Warm
	var res_w: Dictionary = await _run_valentina_timeline(
		"join valentina (Warm) left\nvalentina (Warm): Excelente vuelo.\nleave --All--\n"
	)
	var ctrl_w: PortraitCtrlScript = res_w.get("ctrl", null) as PortraitCtrlScript
	assert_true(ctrl_w != null and ctrl_w.get_current_emotion() == &"warm", "Debe sincronizar emoción warm en Dialogic")
	Dialogic.end_timeline(true)
	for _k: int in range(3):
		await get_tree().process_frame

	backdrop.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _test_main_game_prologue_with_valentina() -> void:
	var prev_char: StringName = SaveManager.get_selected_character()
	SaveManager.set_selected_character(&"valentina")

	var main_game: MainGame = MainGameScene.instantiate() as MainGame
	assert_true(main_game != null, "Debe instanciar MainGame")
	add_child(main_game)

	var found: Dictionary = await _poll_for_valentina_ctrl(36)
	var ctrl: PortraitCtrlScript = found.get("ctrl", null) as PortraitCtrlScript
	var sprite: Sprite2D = found.get("sprite", null) as Sprite2D
	assert_true(main_game.is_briefing_active, "MainGame debe arrancar el prólogo con briefing activo")
	assert_true(ctrl != null, "MainGame debe montar LivingDialoguePortraitController para Valentina en diálogo")
	assert_true(is_instance_valid(sprite) and is_equal_approx(sprite.self_modulate.a, 0.0), "Sprite estático de MainGame debe ocultarse")

	if is_instance_valid(main_game.skip_badge_layer) and main_game.skip_badge_layer.has_method("_execute_skip"):
		main_game.skip_badge_layer.call("_execute_skip")
	else:
		Dialogic.end_timeline(true)

	for _i: int in range(4):
		await get_tree().process_frame

	if Dialogic.current_timeline != null:
		Dialogic.end_timeline(true)
		await get_tree().process_frame

	main_game.queue_free()
	for _j: int in range(3):
		await get_tree().process_frame

	SaveManager.set_selected_character(prev_char)


func _run_valentina_timeline(tl_text: String) -> Dictionary:
	var tl := DialogicTimeline.new()
	tl.from_text(tl_text)
	var layout: Variant = Dialogic.start(tl)
	assert_true(layout != null, "Dialogic timeline debe iniciar")
	return await _poll_for_valentina_ctrl(32)


func _poll_for_valentina_ctrl(max_steps: int) -> Dictionary:
	var portraits_sub: Variant = Dialogic.call("get_subsystem", "Portraits")
	for _step: int in range(max_steps):
		await get_tree().create_timer(0.05, true, false, true).timeout
		if portraits_sub == null or not ("character_nodes" in portraits_sub):
			continue
		var char_nodes: Dictionary = portraits_sub.character_nodes
		for k: Variant in char_nodes.keys():
			var id_str: String = _resolve_key_id(k)
			if not id_str.contains("valentina"):
				continue
			var raw_node: Variant = char_nodes[k]
			if not is_instance_valid(raw_node):
				continue
			var char_node: Node = raw_node as Node
			var sprite: Sprite2D = char_node.find_child("Portrait", true, false) as Sprite2D
			if is_instance_valid(sprite) and is_instance_valid(sprite.get_parent()):
				var ctrl: PortraitCtrlScript = sprite.get_parent().get_node_or_null("LivingDialoguePortraitController") as PortraitCtrlScript
				if is_instance_valid(ctrl):
					return {"char_node": char_node, "sprite": sprite, "ctrl": ctrl}
	return {}


func _resolve_key_id(k: Variant) -> String:
	if k is String or k is StringName:
		return String(k).to_lower()
	if k is Object and is_instance_valid(k):
		var obj := k as Object
		if obj.has_method("get_identifier"):
			return String(obj.call("get_identifier")).to_lower()
		if "display_name" in obj:
			return String(obj.get("display_name")).to_lower()
	return ""
