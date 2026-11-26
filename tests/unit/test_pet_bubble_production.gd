extends BaseTestSuite

## Suite unitaria de producción para 3D Bubble Pets:
## - Single Source of Truth (data/pets/bubble_v2/*.tres y assets/pets/bubble_v2/*)
## - Skins 100% por shader (1★–3★) vía PetBubbleRegistry + PetBubbleRig25D
## - CompanionPet híbrido (órbita 3D con z_index ↔ seguidor elástico al dashear) + modo Hub pacífico
## - PetSelectionModal (3 burbujas vivas horizontales), GachaWardrobeController y GachaRevealTheater

const PET_IDS: Array[StringName] = [&"mochi", &"kuro", &"luna", &"pip", &"cosmo"]
const CompanionPetScene: PackedScene = preload("res://scenes/combat/pets/companion_pet.tscn")
const PetModalScene: PackedScene = preload("res://scenes/ui/character_select/pet_selection_modal.tscn")
const GachaWardrobeScript = preload("res://scenes/ui/gacha/components/gacha_wardrobe_controller.gd")
const GachaTheaterScript = preload("res://scenes/ui/gacha/components/gacha_reveal_theater.gd")
const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const PetDataScript = preload("res://data/pets/pet_data.gd")


func _ready() -> void:
	timeout_seconds = 16.0
	super._ready()
	await _run_tests()


func _run_tests() -> void:
	_test_prod_configs_and_textures()
	_test_shader_skin_style_resolution()
	await _test_companion_pet_hybrid_and_hub_mode()
	await _test_pet_selection_modal_live_bubbles()
	await _test_gacha_wardrobe_and_reveal_pet_preview()
	pass_suite("Produccion 3D Bubble Pets verificada: configs .tres, skins shader, CompanionPet hibrido/Hub, CoverFlow y Gacha.")


func _test_prod_configs_and_textures() -> void:
	for pid: StringName in PET_IDS:
		var pid_str: String = String(pid)
		var cfg: PetBubbleVisualConfig = PetBubbleRegistry.get_config(pid)
		assert_true(cfg != null and cfg.pet_id == pid, "PetBubbleRegistry debe cargar %s.tres" % pid_str)
		assert_true(is_equal_approx(cfg.combat_diameter_px, 64.0), "Diametro combate por defecto 64 px en %s" % pid_str)
		assert_true(is_equal_approx(cfg.hub_diameter_px, 54.0), "Diametro hub por defecto 54 px en %s" % pid_str)
		for suffix: String in ["albedo", "normal", "bubble_tex"]:
			var p: String = "res://assets/pets/bubble_v2/%s/pet_%s_%s.png" % [pid_str, pid_str, suffix]
			var tex: Texture2D = PetBubbleRig25D._load_tex_safe(null, p)
			assert_true(tex != null and tex.get_width() == 512 and tex.get_height() == 512, "Textura 512x512 valida: %s" % p)


func _test_shader_skin_style_resolution() -> void:
	var base_style: Dictionary = PetBubbleRegistry.resolve_skin_style("", 1)
	assert_true(not bool(base_style.get("active", true)), "Skin base no debe activar tintado")

	var s1: Dictionary = PetBubbleRegistry.resolve_skin_style("pet_mochi_cyber_neon", 1)
	var s3: Dictionary = PetBubbleRegistry.resolve_skin_style("pet_mochi_cyber_neon", 3)
	assert_true(bool(s1.get("active", false)), "Skin pet_mochi_cyber_neon debe resolver estilo shader activo")
	assert_true(float(s3.get("star_boost", 0.0)) > float(s1.get("star_boost", 0.0)), "3★ debe aumentar star_boost frente a 1★")


func _test_companion_pet_hybrid_and_hub_mode() -> void:
	var mock_player := Player.new()
	mock_player.z_index = 10
	mock_player.position = Vector2(200.0, 200.0)
	add_child(mock_player)

	var pet: CompanionPet = CompanionPetScene.instantiate() as CompanionPet
	assert_true(pet != null, "Debe instanciar CompanionPet de produccion")
	add_child(pet)
	var p_data: PetData = PetDataScript.get_pet(&"mochi")
	pet.setup(p_data, mock_player)
	await get_tree().process_frame

	assert_true(pet.bubble_rig != null, "CompanionPet debe montar PetBubbleRig25D")
	assert_true(pet.sprite != null and not pet.sprite.visible, "Sprite2D legacy debe permanecer oculto")

	# Aplicar skin 3★ sobre el rig 3D
	pet.bubble_rig.apply_skin_by_id("pet_mochi_solar_gold", 3, false)
	assert_true(pet.bubble_rig.get_active_skin_id() == "pet_mochi_solar_gold", "Rig debe registrar skin aplicada")

	# Verificar cruce por delante y por detrás en órbita 3D tranquila
	var saw_front: bool = false
	var saw_back: bool = false
	mock_player.velocity = Vector2.ZERO
	for _i: int in range(60):
		pet._process(0.10)
		if pet.z_index > mock_player.z_index:
			saw_front = true
		elif pet.z_index < mock_player.z_index:
			saw_back = true
	assert_true(saw_front and saw_back, "CompanionPet en combate debe orbitar delante y detras del jugador")

	# Verificar transición híbrida a seguidor elástico al acelerar / dashear
	mock_player.velocity = Vector2(650.0, 0.0)
	for _j: int in range(25):
		pet._process(0.05)
	assert_true(pet._follow_blend > 0.75, "Alta velocidad debe transicionar a modo seguidor elastico")

	# Verificar modo Hub pacífico
	pet.set_hub_mode(true)
	assert_true(pet.is_hub_mode, "CompanionPet debe entrar en modo Hub pacifico")
	assert_true(is_equal_approx(pet.bubble_rig.base_diameter_px, 54.0), "Modo Hub debe ajustar diametro a hub_diameter_px")
	pet._process(0.1)
	pet.set_hub_mode(false)
	assert_true(is_equal_approx(pet.bubble_rig.base_diameter_px, 64.0), "Salir de Hub debe restaurar diametro de combate")

	pet.queue_free()
	mock_player.queue_free()
	await get_tree().process_frame


func _test_pet_selection_modal_live_bubbles() -> void:
	var modal: PetSelectionModal = PetModalScene.instantiate() as PetSelectionModal
	add_child(modal)
	modal.open_modal()
	await get_tree().process_frame

	var previews: Array[PetBubbleUIPreview] = modal.cover_flow_renderer.get_live_previews()
	assert_true(previews.size() == 3, "PetCoverFlowRenderer debe montar 3 burbujas 3D vivas (izq/centro/der)")
	for pv: PetBubbleUIPreview in previews:
		assert_true(pv.get_rig() != null and pv.get_rig().pet_sprite.texture != null, "Cada burbuja CoverFlow debe tener rig y textura cargada")

	modal.close_modal()
	modal.queue_free()
	await get_tree().process_frame


func _test_gacha_wardrobe_and_reveal_pet_preview() -> void:
	var host := VBoxContainer.new()
	host.size = Vector2(900, 600)
	add_child(host)

	var wardrobe := GachaWardrobeScript.new()
	wardrobe.setup(host)
	wardrobe.filter_wardrobe("pet")
	await get_tree().process_frame

	var pet_insp: PetBubbleUIPreview = wardrobe.get_live_pet_inspector()
	assert_true(pet_insp != null and pet_insp.visible, "GachaWardrobeController debe mostrar PetBubbleUIPreview en filtro 'pet'")

	var theater := GachaTheaterScript.new()
	var skin_dict: Dictionary = CosmeticsManager.get_skin("pet_cosmo_royal_amethyst")
	var card: Control = theater._create_reward_card(skin_dict, {"new_stars": 2, "status": "new"}, true)
	assert_true(card != null, "GachaRevealTheater debe crear tarjeta de recompensa para skin de pet")
	var found_preview: bool = false
	for child: Node in card.get_children():
		for sub: Node in child.get_children():
			if sub is PetBubbleUIPreview:
				found_preview = true
				break
	assert_true(found_preview, "Tarjeta viva de GachaRevealTheater debe usar PetBubbleUIPreview para skins de pet")

	card.queue_free()
	host.queue_free()
	await get_tree().process_frame
