class_name CosmeticCarouselLayoutBuilder
extends RefCounted

## CosmeticCarouselLayoutBuilder.gd
## Constructor desacoplado de vista, maquetación y estilos para CosmeticCarouselModal.
## Gestiona el renderizado de tarjetas, shaders de holograma, puntos del carrusel y estilos visuales.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")
const HOLOGRAM_SHADER := preload("res://shaders/pilot_showcase_hologram.gdshader")
const ShaderSkinSwatchScript = preload("res://scenes/ui/cosmetics/components/shader_skin_swatch.gd")


func load_available_skins(category: String, target_id: StringName, char_data: CharacterData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var tid_str: String = String(target_id).to_lower()
	var norm_cat: String = CosmeticsManager.normalize_category_for_target(category, target_id)
	var catalog: PilotShaderSkinCatalog = char_data.shader_skin_catalog if (char_data != null and char_data.shader_skin_catalog != null) else CosmeticsManager.get_shader_skin_catalog(target_id)
	var use_shader_catalog: bool = catalog != null

	if use_shader_catalog:
		if norm_cat == "wings" or norm_cat == "weapon":
			var pilot_preset: PilotSkinPreset = CosmeticsManager.resolve_pilot_skin_preset(target_id, "pilot")
			if pilot_preset == null:
				pilot_preset = catalog.base_preset
			result.append({
				"id": CosmeticsManager.FOLLOW_PILOT_SKIN_ID,
				"skin_name": "Seguir Traje del Piloto",
				"description": "Sincroniza automáticamente la paleta cromática con el exo-traje equipado del piloto.",
				"rarity": "common",
				"is_base": true,
				"is_follow_pilot": true,
				"is_shader_skin": true,
				"is_unlocked": true,
				"unlocked_stars": 3,
				"stars": 1,
				"texture": null,
				"preset": pilot_preset,
				"glow_color": pilot_preset.accent_color if pilot_preset != null else (char_data.color if char_data else Color(0.2, 0.85, 1.0)),
			})

		var base_preset: PilotSkinPreset = catalog.base_preset
		var base_label: String = base_preset.label if (base_preset != null and not base_preset.label.is_empty()) else ("%s Base" % (char_data.display_name if char_data else "Original"))
		result.append({
			"id": "base",
			"skin_name": base_label,
			"description": "Aspecto operativo estándar de despliegue estelar.",
			"rarity": "common",
			"is_base": true,
			"is_follow_pilot": false,
			"is_shader_skin": true,
			"is_unlocked": true,
			"unlocked_stars": 3,
			"stars": 1,
			"texture": null,
			"preset": base_preset,
			"glow_color": base_preset.accent_color if base_preset != null else (char_data.color if char_data else Color(0.2, 0.85, 1.0)),
		})
	else:
		# Skin Base legacy PNG
		var base_tex: Texture2D = get_base_texture(category, char_data)
		var base_skin: Dictionary = {
			"id": "base",
			"skin_name": "%s Base" % (char_data.display_name if char_data else "Original"),
			"description": "Aspecto operativo estándar de despliegue estelar.",
			"rarity": "common",
			"is_base": true,
			"is_follow_pilot": false,
			"is_shader_skin": false,
			"is_unlocked": true,
			"unlocked_stars": 3,
			"stars": 1,
			"texture": base_tex,
			"glow_color": char_data.color if char_data else Color(0.2, 0.85, 1.0)
		}
		result.append(base_skin)

	# Skins alternativas desde CosmeticsManager
	var catalog_skins: Array[Dictionary] = CosmeticsManager.get_skins_for_target(norm_cat, tid_str)
	for s in catalog_skins:
		var sid: String = s.get("id", "")
		var is_unl: bool = SaveManagerScript.is_skin_unlocked(sid)
		var stars: int = SaveManagerScript.get_skin_stars(sid) if is_unl else 1
		var is_shd: bool = bool(s.get("is_shader_skin", false))
		var preset_obj: PilotSkinPreset = CosmeticsManager.get_skin_preset(sid) if is_shd else null
		var tex: Texture2D = null if is_shd else get_skin_texture(category, s, char_data)
		var glow_hex: String = s.get("glow_hex", "#00f0ff")
		var glow_col := preset_obj.accent_color if preset_obj != null else Color(glow_hex)

		var entry: Dictionary = {
			"id": sid,
			"skin_name": s.get("skin_name", sid),
			"description": s.get("description", "Aspecto cromático del arsenal cuántico."),
			"rarity": s.get("rarity", "rare"),
			"is_base": false,
			"is_follow_pilot": false,
			"is_shader_skin": is_shd,
			"preset": preset_obj,
			"is_unlocked": is_unl,
			"unlocked_stars": stars if is_unl else 0,
			"stars": clampi(stars, 1, 3),
			"texture": tex,
			"glow_color": glow_col,
			"raw_data": s
		}
		result.append(entry)

	return result


func get_base_texture(category: String, char_data: CharacterData) -> Texture2D:
	if not char_data:
		return null
	match category:
		"pilot":
			return char_data.get_selection_texture(false)
		"ship":
			return char_data.get_ship_texture()
		"weapon":
			return char_data.get_weapon_texture()
	return null


func get_skin_texture(category: String, s_data: Dictionary, char_data: CharacterData) -> Texture2D:
	match category:
		"pilot":
			var sel_path: String = s_data.get("selection_texture_path", "")
			if not sel_path.is_empty() and ResourceLoader.exists(sel_path):
				return load(sel_path) as Texture2D
			var fb_path: String = s_data.get("texture_path", "")
			if not fb_path.is_empty() and ResourceLoader.exists(fb_path):
				return load(fb_path) as Texture2D
		"ship":
			var s_path: String = s_data.get("texture_path", "")
			if not s_path.is_empty() and ResourceLoader.exists(s_path):
				return load(s_path) as Texture2D
		"weapon":
			var w_path: String = s_data.get("texture_path", "")
			if not w_path.is_empty() and ResourceLoader.exists(w_path):
				return load(w_path) as Texture2D
	return get_base_texture(category, char_data)


func setup_frame_dimensions(
	category: String,
	carousel_panel: PanelContainer,
	center_slot: Control,
	artwork_frame: PanelContainer,
	category_label: Label,
	hint_footer_label: Label,
	artwork_texture: TextureRect,
	silhouette_overlay: TextureRect
) -> void:
	if not carousel_panel:
		return
	carousel_panel.custom_minimum_size = Vector2(580, 640)
	match category:
		"pilot":
			center_slot.custom_minimum_size = Vector2(360, 500)
			artwork_frame.custom_minimum_size = Vector2(360, 500)
			category_label.text = "HEROÍNA // EXO-TRAJE DE COMBATE"
			hint_footer_label.text = "✦ [A / D] ASPECTOS  ✦  [W / S] ESTRELLAS  ✦  [ESPACIO] EQUIPAR  ✦  [ESC] SALIR"
			apply_artwork_transform(artwork_texture, silhouette_overlay, Vector2.ZERO, Vector2.ONE)
		"wings":
			center_slot.custom_minimum_size = Vector2(360, 360)
			artwork_frame.custom_minimum_size = Vector2(360, 360)
			category_label.text = "ALAS // PROPULSIÓN PSÍQUICA"
			hint_footer_label.text = "✦ [A / D] ASPECTOS  ✦  [W / S] ESTRELLAS  ✦  [ESPACIO] EQUIPAR  ✦  [ESC] SALIR"
			apply_artwork_transform(artwork_texture, silhouette_overlay, Vector2.ZERO, Vector2.ONE)
		"ship":
			center_slot.custom_minimum_size = Vector2(320, 320)
			artwork_frame.custom_minimum_size = Vector2(320, 320)
			category_label.text = "EXO-TRAJE // AERONAVE DE COMBATE"
			hint_footer_label.text = "✦ [A / D] ASPECTOS  ✦  [W / S] ESTRELLAS  ✦  [ESPACIO] EQUIPAR  ✦  [ESC] SALIR"
			apply_artwork_transform(artwork_texture, silhouette_overlay, Vector2.ZERO, Vector2.ONE)
		"weapon":
			center_slot.custom_minimum_size = Vector2(320, 320)
			artwork_frame.custom_minimum_size = Vector2(320, 320)
			category_label.text = "ARMAMENTO // RAIL-LANCE ORBITAL"
			hint_footer_label.text = "✦ [A / D] ASPECTOS  ✦  [W / S] ESTRELLAS  ✦  [ESPACIO] EQUIPAR  ✦  [ESC] SALIR"
			apply_artwork_transform(artwork_texture, silhouette_overlay, Vector2(-38.0, 0.0), Vector2(1.15, 1.15))


func apply_artwork_transform(
	artwork_texture: TextureRect,
	silhouette_overlay: TextureRect,
	offset_pos: Vector2,
	target_scale: Vector2
) -> void:
	if artwork_texture:
		artwork_texture.pivot_offset = artwork_texture.size * 0.5
		artwork_texture.position = offset_pos
		artwork_texture.scale = target_scale
	if silhouette_overlay:
		silhouette_overlay.pivot_offset = silhouette_overlay.size * 0.5
		silhouette_overlay.position = offset_pos
		silhouette_overlay.scale = target_scale


func refresh_display(
	modal: CosmeticCarouselModal,
	available_skins: Array[Dictionary],
	skin_index: int,
	star_level: int,
	category: String,
	target_id: StringName,
	silhouette_material: ShaderMaterial
) -> void:
	if available_skins.is_empty() or not modal:
		return

	var cur: Dictionary = available_skins[skin_index]
	var total: int = available_skins.size()
	var is_unlocked: bool = cur.get("is_unlocked", false)
	var unl_stars: int = cur.get("unlocked_stars", 1)
	var is_star_unlocked: bool = is_unlocked and (star_level <= unl_stars)

	var norm_cat: String = CosmeticsManager.normalize_category_for_target(category, target_id)
	var slot_key: String = "%s:%s" % [norm_cat, String(target_id).to_lower()]
	var equipped_now: String = SaveManager.get_equipped_skin(slot_key)
	if equipped_now.is_empty() and modal.character_data_ref != null and modal.character_data_ref.has_shader_skins():
		equipped_now = CosmeticsManager.resolve_equipped_skin_id(norm_cat, target_id)
	elif equipped_now.is_empty():
		equipped_now = "base"
	var is_equipped: bool = is_star_unlocked and (equipped_now == cur.get("id", ""))
	var theme_col: Color = cur.get("glow_color", Color(0.2, 0.85, 1.0))

	# Dossier Header
	modal.index_badge.text = "[ %02d / %02d ]" % [skin_index + 1, total]

	if not is_unlocked:
		modal.name_label.text = "[ BLOQUEADO ]"
		modal.name_label.modulate = Color(0.6, 0.65, 0.75, 0.7)
		modal.status_badge.text = "[ BLOQUEADO // GACHA ]"
		modal.status_badge.modulate = Color(1.0, 0.35, 0.45)
	elif not is_star_unlocked:
		modal.name_label.text = str(cur.get("skin_name", "")).to_upper()
		modal.name_label.modulate = theme_col
		modal.status_badge.text = "[ NIVEL %d★ BLOQUEADO ]" % star_level
		modal.status_badge.modulate = Color(1.0, 0.6, 0.3)
	elif is_equipped:
		modal.name_label.text = str(cur.get("skin_name", "")).to_upper()
		modal.name_label.modulate = theme_col
		modal.status_badge.text = "[✓ EQUIPADA]"
		modal.status_badge.modulate = Color(0.2, 1.0, 0.6)
	else:
		modal.name_label.text = str(cur.get("skin_name", "")).to_upper()
		modal.name_label.modulate = theme_col
		modal.status_badge.text = "[ DISPONIBLE ]"
		modal.status_badge.modulate = Color(0.4, 0.8, 1.0)

	# Stars Badge
	match star_level:
		1: modal.stars_badge.text = "★☆☆  [NIVEL 1 - BASE]"
		2: modal.stars_badge.text = "★★☆  [NIVEL 2 - HALO DE ENERGÍA]"
		3: modal.stars_badge.text = "★★★  [NIVEL 3 - SOBRECARGA RADIANTE]"
	modal.stars_badge.modulate = Color(1.0, 0.85, 0.25) if is_star_unlocked else Color(0.5, 0.55, 0.6)

	# Lore / Info
	if not is_unlocked:
		modal.desc_label.text = "Aspecto estelar clasificado. Desbloquéalo participando en la Gacha Cuántica del Hangar."
	else:
		modal.desc_label.text = str(cur.get("description", ""))

	# Artwork Texture / Live Shader Preview
	var char_data_ref: CharacterData = modal.character_data_ref
	var use_live_preview: bool = char_data_ref != null and (char_data_ref.pilot_rig_profile != null or char_data_ref.shader_skin_catalog != null)
	var live_preview: ShaderSkinLivePreview = modal.ensure_live_preview() if use_live_preview else modal.get_live_preview()

	if use_live_preview and live_preview != null:
		modal.artwork_texture.visible = false
		modal.artwork_texture.texture = null
		modal.artwork_texture.material = null
		var vp_dim: Vector2i = Vector2i(360, 480) if norm_cat == "pilot" else Vector2i(340, 340)
		var prof: PilotRigProfile = char_data_ref.pilot_rig_profile
		if prof == null and ResourceLoader.exists("res://data/pilots/valentina_v2/valentina_v2_profile.tres"):
			prof = ResourceLoader.load("res://data/pilots/valentina_v2/valentina_v2_profile.tres") as PilotRigProfile
		live_preview.configure(norm_cat, prof, vp_dim)
		var resolved_preset: PilotSkinPreset = cur.get("preset", null) as PilotSkinPreset
		if bool(cur.get("is_follow_pilot", false)):
			resolved_preset = CosmeticsManager.resolve_pilot_skin_preset(target_id, "pilot")
		live_preview.apply_skin_preset(resolved_preset, star_level, not is_unlocked or not is_star_unlocked)
		live_preview.visible = true
		live_preview.set_preview_paused(false)
	else:
		if live_preview != null:
			live_preview.set_preview_paused(true)
			live_preview.visible = false
		modal.artwork_texture.visible = true
		var tex: Texture2D = cur.get("texture", null)
		modal.artwork_texture.texture = tex

	if not is_unlocked or not is_star_unlocked:
		if not use_live_preview:
			modal.artwork_texture.material = silhouette_material
		modal.locked_overlay.visible = true
		modal.lock_title.text = "ASPECTO BLOQUEADO" if not is_unlocked else "NIVEL %d★ BLOQUEADO" % star_level
		modal.lock_desc.text = "Obtén duplicados o cápsulas cuánticas para desbloquear este nivel de resonancia."
		if modal.circular_glow:
			modal.circular_glow.modulate = Color(0.1, 0.15, 0.25, 0.3)
	else:
		modal.locked_overlay.visible = false
		if not use_live_preview:
			if category == "pilot":
				var mat := ShaderMaterial.new()
				mat.shader = HOLOGRAM_SHADER
				mat.set_shader_parameter("rim_color", theme_col)
				var is_valentina: bool = (String(target_id).to_lower() == "valentina")
				mat.set_shader_parameter("bottom_fade_start", 0.78 if is_valentina else 0.88)
				modal.artwork_texture.material = mat
			elif cur.get("is_base", false):
				modal.artwork_texture.material = null
			else:
				CosmeticsManager.apply_skin_to_canvas_item(modal.artwork_texture, cur.get("id", ""), star_level, false)

		if modal.circular_glow:
			modal.circular_glow.modulate = Color(theme_col.r, theme_col.g, theme_col.b, 0.85)

	# Tarjetas Adyacentes (Horizontales)
	var left_idx := (skin_index - 1 + total) % total
	var right_idx := (skin_index + 1) % total
	_update_auxiliary_card_visual(modal.left_texture, available_skins[left_idx], norm_cat, int(available_skins[left_idx].get("stars", 1)), not bool(available_skins[left_idx].get("is_unlocked", false)))
	_update_auxiliary_card_visual(modal.right_texture, available_skins[right_idx], norm_cat, int(available_skins[right_idx].get("stars", 1)), not bool(available_skins[right_idx].get("is_unlocked", false)))

	# Tarjetas de Estrellas (Verticales)
	if modal.top_card and modal.bottom_card:
		_update_auxiliary_card_visual(modal.top_texture, cur, norm_cat, maxi(1, star_level - 1), not is_unlocked)
		_update_auxiliary_card_visual(modal.bottom_texture, cur, norm_cat, mini(3, star_level + 1), not is_unlocked)
		modal.top_card.modulate.a = 0.6 if star_level > 1 else 0.2
		modal.bottom_card.modulate.a = 0.6 if star_level < 3 else 0.2


func _update_auxiliary_card_visual(
	tex_rect: TextureRect,
	skin_entry: Dictionary,
	category: String,
	stars: int,
	locked: bool
) -> void:
	if tex_rect == null:
		return
	var host: Node = tex_rect.get_parent()
	var swatch: ShaderSkinSwatch = host.get_node_or_null("SideSwatch") as ShaderSkinSwatch if host != null else null
	if bool(skin_entry.get("is_shader_skin", false)):
		tex_rect.visible = false
		if swatch == null and host != null:
			swatch = ShaderSkinSwatchScript.new() as ShaderSkinSwatch
			swatch.name = "SideSwatch"
			swatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			swatch.offset_left = 8.0
			swatch.offset_top = 8.0
			swatch.offset_right = -8.0
			swatch.offset_bottom = -8.0
			host.add_child(swatch)
		if swatch != null:
			swatch.visible = true
			swatch.configure_swatch(
				skin_entry.get("preset", null) as PilotSkinPreset,
				category,
				stars,
				locked,
				bool(skin_entry.get("is_follow_pilot", false))
			)
	else:
		if swatch != null:
			swatch.visible = false
		tex_rect.visible = true
		tex_rect.texture = skin_entry.get("texture", null) as Texture2D


func build_dots(dots_container: HBoxContainer, available_skins: Array[Dictionary], current_index: int) -> void:
	if not dots_container:
		return
	for child in dots_container.get_children():
		child.queue_free()

	for i in range(available_skins.size()):
		var dot := Panel.new()
		var is_active := (i == current_index)
		dot.custom_minimum_size = Vector2(20 if is_active else 8, 8)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		if is_active:
			var cur_col: Color = available_skins[i].get("glow_color", Color(0, 0.95, 1.0))
			sb.bg_color = cur_col
			sb.shadow_color = cur_col
			sb.shadow_size = 4
		else:
			sb.bg_color = Color(0.25, 0.35, 0.45, 0.5)
		dot.add_theme_stylebox_override("panel", sb)
		dots_container.add_child(dot)
