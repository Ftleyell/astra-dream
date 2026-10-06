class_name TestDialoguePilotPolishSuite
extends BaseTestSuite

const SHOWCASE_SHADER := preload("res://shaders/pilot_showcase_hologram.gdshader")

func _ready() -> void:
	timeout_seconds = 12.0
	super._ready()
	_run_test()

func _run_test() -> void:
	print("\n=======================================================")
	print("🧪 VERIFICACIÓN: PULIDO VISUAL DE PILOTOS EN DIÁLOGOS")
	print("=======================================================")

	# 1. Instanciar DialogueBackdropLayer en el SceneTree
	var backdrop_scene := preload("res://scenes/ui/dialogue/dialogue_backdrop_layer.tscn")
	var backdrop: Node = backdrop_scene.instantiate()
	add_child(backdrop)

	# 2. Iniciar diálogo con Nova y Echo
	var tl_text := """
join nova left
join echo right
nova: Iniciando sincronización de telemetría.
echo: Canales cuánticos estabilizados.
leave --All--
"""
	var tl := DialogicTimeline.new()
	tl.from_text(tl_text)

	var layout = Dialogic.start(tl)
	assert_true(layout != null, "Dialogic layout debe inicializarse correctamente")

	var echo_res = DialogicResourceUtil.get_character_resource("echo")
	print("  [DEBUG ECHO RESOURCE] ", echo_res)

	# Esperar a que se procese el inicio de la línea de tiempo y las animaciones de join (0.5s x 2)
	await get_tree().create_timer(1.2, true, false, true).timeout

	# 3. Localizar los retratos de Dialogic
	var portraits_layer = layout.find_child("VN_PortraitLayer", true, false)
	assert_true(portraits_layer != null, "VN_PortraitLayer debe existir")
	var portraits: Control = portraits_layer.get_node("%Portraits")
	assert_true(portraits != null, "%Portraits debe existir")

	var portraits_sub: Variant = Dialogic.call("get_subsystem", "Portraits")
	print("  [DEBUG CHAR NODES KEYS] ", portraits_sub.character_nodes.keys())
	var nova_char: Node = null
	var echo_char: Node = null
	for k in portraits_sub.character_nodes.keys():
		var node: Node = portraits_sub.character_nodes[k] as Node
		var id_str: String = ""
		if k is String or k is StringName:
			id_str = String(k).to_lower()
		elif "display_name" in k:
			id_str = String(k.display_name).to_lower()
		if id_str.contains("nova"):
			nova_char = node
		elif id_str.contains("echo"):
			echo_char = node

	assert_true(nova_char != null, "Nodo nova debe existir en character_nodes")
	assert_true(echo_char != null, "Nodo echo debe existir en character_nodes")

	# 4. Validar que los retratos tienen el ShaderMaterial holográfico y el BacklightGlow
	var nova_sprite: Sprite2D = nova_char.find_child("Portrait", true, false) as Sprite2D
	var echo_sprite: Sprite2D = echo_char.find_child("Portrait", true, false) as Sprite2D
	assert_true(nova_sprite != null, "Sprite2D Portrait de Nova debe existir")
	assert_true(echo_sprite != null, "Sprite2D Portrait de Echo debe existir")

	# Verificar shader holográfico en Nova
	assert_true(nova_sprite.material is ShaderMaterial, "Nova Portrait debe tener ShaderMaterial asignado")
	var nova_mat := nova_sprite.material as ShaderMaterial
	assert_true(nova_mat.shader == SHOWCASE_SHADER, "Nova Portrait debe usar SHOWCASE_SHADER")
	var nova_rim_color: Color = nova_mat.get_shader_parameter("rim_color")
	assert_true(nova_rim_color.is_equal_approx(Color(1.00, 0.40, 0.05)), "Color de rim de Nova debe ser su color característico")
	var nova_cutoff: float = float(nova_mat.get_shader_parameter("alpha_cutoff"))
	assert_true(is_equal_approx(nova_cutoff, 0.04), "alpha_cutoff debe ser 0.04 para descartar residuos")

	# Verificar BacklightGlow en Nova
	var nova_glow: Sprite2D = nova_sprite.get_parent().get_node_or_null("BacklightGlow") as Sprite2D
	assert_true(nova_glow != null, "BacklightGlow debe existir detrás del retrato de Nova")
	assert_true(nova_glow.z_index == -1, "BacklightGlow debe tener z_index = -1")
	assert_true(nova_glow.material is CanvasItemMaterial, "BacklightGlow debe tener material aditivo")
	assert_true((nova_glow.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "Glow debe usar BLEND_MODE_ADD")

	# Verificar shader y glow en Echo
	assert_true(echo_sprite.material is ShaderMaterial, "Echo Portrait debe tener ShaderMaterial asignado")
	var echo_mat := echo_sprite.material as ShaderMaterial
	assert_true(echo_mat.shader == SHOWCASE_SHADER, "Echo Portrait debe usar SHOWCASE_SHADER")
	var echo_rim_color: Color = echo_mat.get_shader_parameter("rim_color")
	assert_true(echo_rim_color.is_equal_approx(Color(0.12, 0.85, 0.95)), "Color de rim de Echo debe ser su color característico")

	var echo_glow: Sprite2D = echo_sprite.get_parent().get_node_or_null("BacklightGlow") as Sprite2D
	assert_true(echo_glow != null, "BacklightGlow debe existir detrás del retrato de Echo")

	# 5. Validar orador activo (Nova está hablando)
	print("  ✓ Nova activa: rim_intensity = %.2f, glow.modulate.a = %.2f" % [
		float(nova_mat.get_shader_parameter("rim_intensity")),
		nova_glow.modulate.a
	])
	assert_true(float(nova_mat.get_shader_parameter("rim_intensity")) >= 1.25, "Nova activa debe tener rim_intensity alto (~1.30)")

	print("  ✓ Retratos de diálogo pulidos con shader de defringing y contraluz dinámico verificados exitosamente.")

	Dialogic.end_timeline(true)
	await get_tree().process_frame

	pass_suite("Pulido visual de retratos de diálogo en DialogueBackdropLayer verificado al 100%")
