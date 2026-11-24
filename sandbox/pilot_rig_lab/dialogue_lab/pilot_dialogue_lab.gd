class_name PilotDialogueLab
extends Node2D
## Laboratorio interactivo 1:1 análogo al diálogo In-Game (1920x1080).
## Valentina ocupa el slot izquierdo (442, 1080) e interlocuta con una Pet real (1478, 820)
## replicando atenuación de turno, BacklightGlow, caja inferior centrada y guías portables.

const PortraitCtrlScript = preload("res://scenes/pilots/dialogue/pilot_dialogue_portrait_controller.gd")
const ConfigScript = preload("res://data/pilots/schemas/pilot_dialogue_portrait_config.gd")
const EntryScript = preload("res://data/pilots/schemas/pilot_dialogue_portrait_entry.gd")
const HUDScript = preload("res://sandbox/pilot_rig_lab/dialogue_lab/pilot_dialogue_lab_hud.gd")
const PilotLabSelectorScript = preload("res://sandbox/pilot_rig_lab/shared/pilot_lab_selector.gd")
const CosmosEnvScene: PackedScene = preload("res://scenes/combat/environment/cosmos_combat_environment.tscn")

const PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const CONFIG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_dialogue_portraits.tres"
const WORKBENCH_HUB_PATH: String = "res://sandbox/workbenches/workbench_hub.tscn"

const PET_IDS: Array[String] = ["mochi", "kuro", "luna", "pip", "cosmo"]
const PET_BASE_SCALE: float = 0.65
const PET_OFFSET_Y: float = -260.0
const PET_TINT_COLORS: Dictionary = {
	"mochi": Color(0.95, 0.65, 0.90, 1.0),
	"kuro": Color(0.95, 0.34, 0.42, 1.0),
	"luna": Color(0.55, 0.85, 1.0, 1.0),
	"pip": Color(1.0, 0.82, 0.40, 1.0),
	"cosmo": Color(0.45, 0.65, 1.0, 1.0),
}

const CONVERSATIONS: Array[Dictionary] = [
	{
		"id": "briefing",
		"title": "1. Briefing Táctico (Pose A → B)",
		"lines": [
			{"speaker": "Valentina", "pilot_focus": true, "emotion": &"neutral", "comms": false, "text": "Órbita estabilizada. Trazo de telemetría limpio y sin interferencias gravitacionales."},
			{"speaker": "Valentina", "pilot_focus": true, "emotion": &"thinking", "comms": false, "text": "Tres flancos posibles en el sector exterior... si ajustamos la parábola a 14 grados, ahorramos energía."},
			{"speaker": "Valentina", "pilot_focus": true, "emotion": &"focused", "comms": false, "text": "Blanco fijado en el cuadrante norte. Calibrando el Rail-Lance al límite crítico."},
			{"speaker": "Valentina", "pilot_focus": true, "emotion": &"warm", "comms": false, "text": "Buen trabajo en el chequeo previo. Vamos a despejar este sector sin un rasguño."},
		],
	},
	{
		"id": "mochi",
		"title": "2. Turnos con Pet (Habla vs Escucha)",
		"lines": [
			{"speaker": "Pet", "is_pet": true, "pilot_focus": false, "emotion": &"neutral", "comms": false, "text": "¡Pii-miau! Valentina, ¿segura que no quieres que sobrealimentemos los estabilizadores con polvo estelar?"},
			{"speaker": "Valentina", "pilot_focus": true, "emotion": &"thinking", "comms": false, "text": "La última vez que hiciste eso casi fundimos los disipadores antes de la primera oleada."},
			{"speaker": "Pet", "is_pet": true, "pilot_focus": false, "emotion": &"thinking", "comms": false, "text": "¡P-pero las chispas violetas se veían increíbles en el radar táctico!"},
			{"speaker": "Valentina", "pilot_focus": true, "emotion": &"warm", "comms": false, "text": "Está bien, copiloto. Guarda esas chispas para la celebración en el hangar."},
		],
	},
	{
		"id": "duel",
		"title": "3. Cara a Cara Rival (Lock-On)",
		"lines": [
			{"speaker": "Rival Nova", "pilot_focus": false, "emotion": &"focused", "comms": true, "text": "Canal abierto, Valentina. Veamos si tu mira de precisión sigue mi velocidad de crucero."},
			{"speaker": "Valentina", "pilot_focus": true, "emotion": &"focused", "comms": false, "text": "Ya calculé tus tres vectores de evasión antes de que terminaras esa frase."},
			{"speaker": "Valentina", "pilot_focus": true, "emotion": &"alert", "comms": false, "text": "¡Firma energética entrante a las doce! Interceptando trayectoria en 3... 2..."},
			{"speaker": "Valentina", "pilot_focus": true, "emotion": &"warm", "comms": false, "text": "Telemetría limpia. Cuando quieras la revancha, sabes dónde encontrarnos."},
		],
	},
	{
		"id": "boss_radio",
		"title": "4. Alerta Boss por Radio (Comms)",
		"lines": [
			{"speaker": "Valentina", "pilot_focus": true, "emotion": &"alert", "comms": true, "text": "¡Atención! Anomalía de masa extrema emergiendo frente al corredor estelar."},
			{"speaker": "Valentina", "pilot_focus": true, "emotion": &"focused", "comms": true, "text": "Enlace táctico bloqueado sobre el núcleo del coloso. Mantén el vector lateral firme."},
		],
	},
	{
		"id": "hangar",
		"title": "5. Victoria en Hangar (Distensión)",
		"lines": [
			{"speaker": "Valentina", "pilot_focus": true, "emotion": &"warm", "comms": false, "text": "Reactores en reposo. Todo el escuadrón regresó entero y con datos intactos."},
			{"speaker": "Valentina", "pilot_focus": true, "emotion": &"neutral", "comms": false, "text": "Guardando registros balísticos para la próxima incursión. Buen vuelo."},
		],
	},
]


class _GuidesOverlay extends Control:
	var owner_lab: PilotDialogueLab = null

	func _draw() -> void:
		if owner_lab == null:
			return
		var font: Font = ThemeDB.fallback_font
		var cfg: ConfigScript = owner_lab.get_config()
		var left_pos: Vector2 = cfg.left_slot_pos if cfg != null else Vector2(442.0, 1080.0)
		var right_pos: Vector2 = cfg.right_slot_pos if cfg != null else Vector2(1478.0, 1080.0)
		var base_h: float = cfg.base_display_height_px if cfg != null else 860.0
		var fade_y_norm: float = cfg.bottom_fade_start if cfg != null else 0.86

		var mirrored: bool = owner_lab.is_mirrored()
		var pilot_anchor: Vector2 = right_pos if mirrored else left_pos
		var pet_anchor_bottom: Vector2 = left_pos if mirrored else right_pos
		var pet_center: Vector2 = Vector2(pet_anchor_bottom.x, pet_anchor_bottom.y + PET_OFFSET_Y)

		# 1. Marco 1920x1080 y barra superior de métricas
		draw_rect(Rect2(2.0, 2.0, 1916.0, 1076.0), Color(0.40, 0.72, 1.0, 0.38), false, 2.0)
		if font != null:
			draw_string(font, Vector2(680.0, 32.0), "STAGE IN-GAME ANALOG: 1920x1080 (canvas_items)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.70, 0.90, 1.0, 0.95))

		# 2. Slot Retrato Valentina
		var p_half_w: float = base_h * 0.44
		var p_rect := Rect2(pilot_anchor.x - p_half_w, pilot_anchor.y - base_h, p_half_w * 2.0, base_h)
		draw_rect(p_rect, Color(0.32, 0.86, 1.0, 0.10), true)
		draw_rect(p_rect, Color(0.32, 0.86, 1.0, 0.82), false, 2.0)
		var fade_y: float = (pilot_anchor.y - base_h) + base_h * fade_y_norm
		draw_dashed_line(Vector2(p_rect.position.x, fade_y), Vector2(p_rect.end.x, fade_y), Color(1.0, 0.80, 0.35, 0.90), 2.0, 8.0)
		_draw_crosshair(pilot_anchor, Color(0.32, 0.86, 1.0, 1.0))
		if font != null:
			draw_string(font, Vector2(p_rect.position.x + 6.0, maxf(p_rect.position.y - 8.0, 20.0)), "PILOT SLOT · Pos(%d, %d) · H=%dpx · Fade=%.2f" % [int(pilot_anchor.x), int(pilot_anchor.y), int(base_h), fade_y_norm], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.92, 1.0, 1.0))

		# 3. Slot Pet Interlocutor
		var pet_sz: float = 512.0 * PET_BASE_SCALE
		var pet_rect := Rect2(pet_center.x - pet_sz * 0.5, pet_center.y - pet_sz * 0.5, pet_sz, pet_sz)
		draw_rect(pet_rect, Color(0.95, 0.58, 0.90, 0.08), true)
		draw_rect(pet_rect, Color(0.95, 0.58, 0.90, 0.82), false, 2.0)
		_draw_crosshair(pet_center, Color(0.95, 0.58, 0.90, 1.0))
		if font != null:
			draw_string(font, Vector2(pet_rect.position.x, pet_rect.position.y - 10.0), "PET (%s) · Pos(%d, %d) · S=%.2f" % [owner_lab.get_pet_id().to_upper(), int(pet_center.x), int(pet_center.y), PET_BASE_SCALE], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.72, 0.95, 1.0))

		# 4. Textbox In-Game
		var tb_rect := Rect2(200.0, 842.0, 1520.0, 210.0)
		draw_rect(tb_rect, Color(0.45, 0.95, 0.65, 0.82), false, 2.0)
		if font != null:
			draw_string(font, Vector2(tb_rect.end.x - 455.0, tb_rect.position.y - 8.0), "TEXTBOX IN-GAME · 1520x210 · X[200..1720] Y[842..1052]", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.98, 0.72, 1.0))

	func _draw_crosshair(pt: Vector2, col: Color) -> void:
		draw_line(pt + Vector2(-12.0, 0.0), pt + Vector2(12.0, 0.0), col, 2.0)
		draw_line(pt + Vector2(0.0, -12.0), pt + Vector2(0.0, 12.0), col, 2.0)
		draw_circle(pt, 4.0, col)


@export var pilot_profile_override: String = ""

var _active_profile_path: String = PROFILE_PATH
var _active_config_path: String = CONFIG_PATH

var _profile: PilotRigProfile = null
var _config: ConfigScript = null
var _camera: Camera2D = null
var _stage_layer: CanvasLayer = null
var _stage_dimmer: ColorRect = null
var _portrait_ctrl: PortraitCtrlScript = null

var _pet_root: Node2D = null
var _pet_backlight: Sprite2D = null
var _pet_sprite: Sprite2D = null
var _active_pet_id: String = "mochi"
var _pet_focus_t: float = 0.0
var _pet_wiggle_t: float = 0.0
var _pet_tex_cache: Dictionary = {}

var _guides_layer: CanvasLayer = null
var _guides_overlay: _GuidesOverlay = null
var _cosmos_env: CosmosCombatEnvironment = null
var _hud_refs: Dictionary = {}

var _active_conv_lines: Array = []
var _active_line_idx: int = -1
var _full_line_text: String = ""
var _reveal_chars: float = 0.0
var _is_typing: bool = false
var _pilot_is_speaking_line: bool = true
var _is_mirrored: bool = false
var _hud_panel_visible: bool = true
var _guides_visible: bool = false


func _ready() -> void:
	_load_resources()
	_build_environment()
	_build_stage()

	var skin_labels: Array[String] = []
	if _profile != null:
		for sk: PilotSkinPreset in _profile.skins:
			skin_labels.append(sk.label if sk != null else "Skin")
	if skin_labels.is_empty():
		skin_labels.append("Base Original")

	_hud_refs = HUDScript.build_hud(self, _config, skin_labels, PET_IDS, CONVERSATIONS, {
		"on_emotion_selected": Callable(self, "select_emotion"),
		"on_conversation_selected": Callable(self, "start_conversation"),
		"on_advance_dialogue": Callable(self, "advance_conversation"),
		"on_pet_selected": Callable(self, "set_pet_id"),
		"on_debug_view_selected": Callable(self, "set_debug_view_mode"),
		"on_skin_selected": Callable(self, "set_skin_index"),
		"on_hair_recolor_toggled": Callable(self, "set_hair_recolor_enabled"),
		"on_living_toggled": Callable(self, "set_living_enabled"),
		"on_comms_toggled": Callable(self, "set_comms_enabled"),
		"on_focused_toggled": Callable(self, "set_focused_enabled"),
		"on_mirror_toggled": Callable(self, "set_mirrored_enabled"),
		"on_particles_toggled": Callable(self, "set_particles_enabled"),
		"on_cosmos_toggled": Callable(self, "toggle_cosmos_background"),
		"on_speech_pulse": Callable(self, "trigger_speech_pulse"),
		"on_param_changed": Callable(self, "_on_entry_param_changed"),
		"on_config_param_changed": Callable(self, "_on_config_param_changed"),
		"on_save_config": Callable(self, "save_config"),
		"on_reload_config": Callable(self, "reload_config"),
		"on_hud_toggled": Callable(self, "set_hud_panel_visible"),
		"on_guides_toggled": Callable(self, "set_guides_visible"),
		"on_return_hub": Callable(self, "return_to_hub"),
	})

	_apply_slot_positions()
	set_pet_id("mochi")
	_sync_ui_for_current_entry()
	start_conversation("mochi")
	call_deferred("_maybe_run_gpu_audit_capture")


func _process(delta: float) -> void:
	if _is_typing and not _full_line_text.is_empty():
		var body: RichTextLabel = _hud_refs.get("body_label", null) as RichTextLabel
		if is_instance_valid(body):
			if body.visible_characters >= 0 and body.visible_characters < _full_line_text.length():
				_reveal_chars += delta * 46.0
				var next_count: int = mini(int(_reveal_chars), _full_line_text.length())
				body.visible_characters = next_count
				if next_count >= _full_line_text.length():
					_finish_typing()
			else:
				_finish_typing()

	_update_pet_turn_state(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev := event as InputEventKey
		if kev.pressed and not kev.echo:
			match kev.keycode:
				KEY_SPACE, KEY_ENTER:
					advance_conversation()
				KEY_H:
					set_hud_panel_visible(not _hud_panel_visible)
				KEY_G:
					set_guides_visible(not _guides_visible)
				KEY_1:
					_select_emotion_by_index(0)
				KEY_2:
					_select_emotion_by_index(1)
				KEY_3:
					_select_emotion_by_index(2)
				KEY_4:
					_select_emotion_by_index(3)
				KEY_5:
					_select_emotion_by_index(4)
				KEY_TAB:
					var lchk: CheckButton = _hud_refs.get("living_check", null) as CheckButton
					if is_instance_valid(lchk):
						lchk.button_pressed = not lchk.button_pressed
				KEY_R:
					var rchk: CheckButton = _hud_refs.get("comms_check", null) as CheckButton
					if is_instance_valid(rchk):
						rchk.button_pressed = not rchk.button_pressed
				KEY_F:
					var fchk: CheckButton = _hud_refs.get("focus_check", null) as CheckButton
					if is_instance_valid(fchk):
						fchk.button_pressed = not fchk.button_pressed
				KEY_M:
					var mchk: CheckButton = _hud_refs.get("mirror_check", null) as CheckButton
					if is_instance_valid(mchk):
						mchk.button_pressed = not mchk.button_pressed
				KEY_C:
					var cchk: CheckButton = _hud_refs.get("cosmos_check", null) as CheckButton
					if is_instance_valid(cchk):
						cchk.button_pressed = not cchk.button_pressed


func get_portrait_controller() -> PortraitCtrlScript:
	return _portrait_ctrl


func get_config() -> ConfigScript:
	return _config


func get_pet_root() -> Node2D:
	return _pet_root


func get_pet_id() -> String:
	return _active_pet_id


func is_mirrored() -> bool:
	return _is_mirrored


func is_typing() -> bool:
	return _is_typing


func is_hud_panel_visible() -> bool:
	return _hud_panel_visible


func is_guides_visible() -> bool:
	return _guides_visible


func set_hud_panel_visible(vis: bool) -> void:
	_hud_panel_visible = vis
	HUDScript.set_hud_panel_visible(_hud_refs, vis)


func set_guides_visible(vis: bool) -> void:
	_guides_visible = vis
	if is_instance_valid(_guides_layer):
		_guides_layer.visible = vis
	if is_instance_valid(_guides_overlay):
		_guides_overlay.queue_redraw()
	var gbtn: Button = _hud_refs.get("guides_btn", null) as Button
	if is_instance_valid(gbtn):
		gbtn.set_pressed_no_signal(vis)


func set_pet_id(pet_id: String) -> void:
	var clean_id: String = pet_id.strip_edges().to_lower()
	if not PET_IDS.has(clean_id):
		clean_id = "mochi"
	_active_pet_id = clean_id
	if _pet_sprite != null:
		_pet_sprite.texture = _load_pet_texture(clean_id)
	var pet_opt: OptionButton = _hud_refs.get("pet_option", null) as OptionButton
	if is_instance_valid(pet_opt):
		var idx: int = PET_IDS.find(clean_id)
		if idx >= 0:
			pet_opt.select(idx)
	if is_instance_valid(_guides_overlay) and _guides_visible:
		_guides_overlay.queue_redraw()
	_refresh_active_speaker_name_if_pet()
	_set_status("Pet interlocutor: %s" % clean_id.capitalize())


func select_emotion(emotion_id: StringName) -> void:
	if _portrait_ctrl != null:
		_portrait_ctrl.set_emotion(emotion_id, false)
	_sync_ui_for_current_entry()
	_set_status("Emoción activa: %s" % String(emotion_id))


func start_conversation(conv_id: String) -> void:
	for conv: Dictionary in CONVERSATIONS:
		if str(conv.get("id", "")) == conv_id:
			_is_typing = false
			_active_conv_lines = conv.get("lines", []) as Array
			_active_line_idx = -1
			advance_conversation()
			return


func advance_conversation() -> void:
	if _active_conv_lines.is_empty():
		return
	var body: RichTextLabel = _hud_refs.get("body_label", null) as RichTextLabel
	if _is_typing and is_instance_valid(body) and body.visible_characters >= 0 and body.visible_characters < _full_line_text.length():
		body.visible_characters = _full_line_text.length()
		_finish_typing()
		return

	_active_line_idx = (_active_line_idx + 1) % _active_conv_lines.size()
	var line: Dictionary = _active_conv_lines[_active_line_idx] as Dictionary
	var is_pet_line: bool = bool(line.get("is_pet", false))
	var speaker: String = _active_pet_id.capitalize() if is_pet_line else str(line.get("speaker", "Valentina"))
	var pilot_focus: bool = bool(line.get("pilot_focus", true))
	var emotion: StringName = line.get("emotion", &"neutral") as StringName
	var comms: bool = bool(line.get("comms", false))
	var line_text: String = str(line.get("text", ""))

	_pilot_is_speaking_line = pilot_focus
	if _portrait_ctrl != null:
		_portrait_ctrl.set_emotion(emotion, false)
		_portrait_ctrl.set_comms_mode(comms)
		_portrait_ctrl.set_focused(pilot_focus)
		_portrait_ctrl.set_speaking(pilot_focus)
		_portrait_ctrl.z_index = 10 if pilot_focus else 0
	if _pet_root != null:
		_pet_root.z_index = 0 if pilot_focus else 10

	var comms_chk: CheckButton = _hud_refs.get("comms_check", null) as CheckButton
	if is_instance_valid(comms_chk):
		comms_chk.set_pressed_no_signal(comms)
	var focus_chk: CheckButton = _hud_refs.get("focus_check", null) as CheckButton
	if is_instance_valid(focus_chk):
		focus_chk.set_pressed_no_signal(pilot_focus)

	_show_theater_line(speaker, emotion, line_text, comms)
	_sync_ui_for_current_entry()


func set_debug_view_mode(idx: int) -> void:
	if _portrait_ctrl != null:
		_portrait_ctrl.set_debug_view_mode(idx)
	_set_status("Debug View Mode = %d" % idx)


func set_skin_index(idx: int) -> void:
	if _portrait_ctrl == null or _profile == null:
		return
	if idx >= 0 and idx < _profile.skins.size():
		var sk: PilotSkinPreset = _profile.skins[idx]
		_portrait_ctrl.apply_skin_preset(sk)
		_set_status("Skin: %s" % (sk.label if sk != null else "Base"))


func set_hair_recolor_enabled(enabled: bool) -> void:
	if _portrait_ctrl != null:
		_portrait_ctrl.set_hair_recolor_enabled(enabled)


func set_living_enabled(enabled: bool) -> void:
	if _portrait_ctrl != null:
		_portrait_ctrl.set_living_enabled(enabled)
	_set_status("Modo: %s" % ("LIVING 2.5D" if enabled else "ESTÁTICO PLANO (A/B)"))


func set_comms_enabled(enabled: bool) -> void:
	if _portrait_ctrl != null:
		_portrait_ctrl.set_comms_mode(enabled)


func set_focused_enabled(enabled: bool) -> void:
	_pilot_is_speaking_line = enabled
	if _portrait_ctrl != null:
		_portrait_ctrl.set_focused(enabled)
		_portrait_ctrl.set_speaking(enabled and _is_typing)
		_portrait_ctrl.z_index = 10 if enabled else 0
	if _pet_root != null:
		_pet_root.z_index = 0 if enabled else 10


func set_mirrored_enabled(enabled: bool) -> void:
	_is_mirrored = enabled
	if _portrait_ctrl != null:
		_portrait_ctrl.set_mirrored(enabled)
	_apply_slot_positions()
	if is_instance_valid(_guides_overlay) and _guides_visible:
		_guides_overlay.queue_redraw()


func set_particles_enabled(enabled: bool) -> void:
	if _portrait_ctrl != null:
		_portrait_ctrl.set_particles_enabled(enabled)


func trigger_speech_pulse() -> void:
	if _portrait_ctrl != null:
		_portrait_ctrl.notify_speech_pulse()


func toggle_cosmos_background(enable: bool = true) -> void:
	var want_on: bool = enable
	if not want_on and is_instance_valid(_cosmos_env):
		_cosmos_env.queue_free()
		_cosmos_env = null
		_set_status("Fondo: Estudio In-Game (Dimmer 0.72)")
		return
	if want_on and not is_instance_valid(_cosmos_env) and CosmosEnvScene != null:
		_cosmos_env = CosmosEnvScene.instantiate() as CosmosCombatEnvironment
		_cosmos_env.name = "CosmosDialogueBackdrop"
		_cosmos_env.z_index = -100
		add_child(_cosmos_env)
		if _camera != null:
			_cosmos_env.set_camera_reference(_camera)
		_set_status("Fondo: Cosmos Engine activo")


func save_config() -> void:
	if _config == null:
		return
	var err: Error = ResourceSaver.save(_config, _active_config_path)
	_set_status(("Guardado OK: %s" % _active_config_path.get_file()) if err == OK else ("Error guardando: %d" % err))


func reload_config() -> void:
	if not ResourceLoader.exists(_active_config_path):
		return
	var reloaded: ConfigScript = ResourceLoader.load(_active_config_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ConfigScript
	if reloaded != null:
		_config = reloaded
		_config.ensure_defaults()
		if _portrait_ctrl != null:
			_portrait_ctrl.set_config(_config)
		_apply_slot_positions()
		_sync_ui_for_current_entry()
		_set_status("Recargado desde .tres")


func return_to_hub() -> void:
	get_tree().change_scene_to_file(WORKBENCH_HUB_PATH)


func _load_resources() -> void:
	var resolved: Dictionary = PilotLabSelectorScript.resolve_active_paths(pilot_profile_override, PROFILE_PATH, {
		"dialogue_portraits": CONFIG_PATH,
	})
	_active_profile_path = str(resolved.get("profile_path", PROFILE_PATH))
	var cfgs: Dictionary = resolved.get("configs", {}) as Dictionary
	_active_config_path = str(cfgs.get("dialogue_portraits", CONFIG_PATH))

	if ResourceLoader.exists(_active_profile_path):
		_profile = ResourceLoader.load(_active_profile_path) as PilotRigProfile
	if ResourceLoader.exists(_active_config_path):
		_config = ResourceLoader.load(_active_config_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ConfigScript
	elif _profile != null and _profile.dialogue_portraits_config is ConfigScript:
		_config = _profile.dialogue_portraits_config as ConfigScript
	if _config == null:
		_config = ConfigScript.new()
	_config.ensure_defaults()


func _build_environment() -> void:
	RenderingServer.set_default_clear_color(Color(0.055, 0.075, 0.145, 1.0))
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.08
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	var we := WorldEnvironment.new()
	we.name = "DialogueLabWorldEnvironment"
	we.environment = env
	add_child(we)

	_camera = Camera2D.new()
	_camera.name = "DialogueLabCamera"
	_camera.position = Vector2(960.0, 540.0)
	_camera.enabled = true
	add_child(_camera)


func _build_stage() -> void:
	# Escenario 1920x1080 análogo al in-game
	_stage_layer = CanvasLayer.new()
	_stage_layer.name = "DialogueStageLayer"
	_stage_layer.layer = 10
	add_child(_stage_layer)

	_stage_dimmer = ColorRect.new()
	_stage_dimmer.name = "StageDimmer"
	_stage_dimmer.color = Color(0.02, 0.03, 0.06, 0.72)
	_stage_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_layer.add_child(_stage_dimmer)

	_portrait_ctrl = PortraitCtrlScript.new()
	_portrait_ctrl.name = "PilotDialoguePortraitController"
	_portrait_ctrl.set_config(_config)
	_portrait_ctrl.z_index = 10
	_stage_layer.add_child(_portrait_ctrl)

	# Slot Interlocutor Pet
	_pet_root = Node2D.new()
	_pet_root.name = "PetInterlocutorRoot"
	_pet_root.z_index = 0
	_stage_layer.add_child(_pet_root)

	_pet_backlight = Sprite2D.new()
	_pet_backlight.name = "PetBacklightGlow"
	_pet_backlight.texture = _build_pet_backlight_texture()
	_pet_backlight.centered = true
	_pet_backlight.scale = Vector2(0.82, 0.56)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_pet_backlight.material = add_mat
	_pet_root.add_child(_pet_backlight)

	_pet_sprite = Sprite2D.new()
	_pet_sprite.name = "PetSprite"
	_pet_sprite.centered = true
	_pet_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_pet_root.add_child(_pet_sprite)

	# Capa de Guías Portables 1080p (CanvasLayer 35)
	_guides_layer = CanvasLayer.new()
	_guides_layer.name = "DialogueGuidesLayer"
	_guides_layer.layer = 35
	_guides_layer.visible = false
	add_child(_guides_layer)

	_guides_overlay = _GuidesOverlay.new()
	_guides_overlay.name = "PortableGuidesOverlay"
	_guides_overlay.owner_lab = self
	_guides_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_guides_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guides_layer.add_child(_guides_overlay)


func _apply_slot_positions() -> void:
	var left_pos: Vector2 = _config.left_slot_pos if _config != null else Vector2(442.0, 1080.0)
	var right_pos: Vector2 = _config.right_slot_pos if _config != null else Vector2(1478.0, 1080.0)
	var pilot_pos: Vector2 = right_pos if _is_mirrored else left_pos
	var pet_bottom: Vector2 = left_pos if _is_mirrored else right_pos
	if _portrait_ctrl != null:
		_portrait_ctrl.position = pilot_pos
	if _pet_root != null:
		_pet_root.position = Vector2(pet_bottom.x, pet_bottom.y + PET_OFFSET_Y)
	if _pet_sprite != null:
		_pet_sprite.flip_h = not _is_mirrored


func _update_pet_turn_state(delta: float) -> void:
	if _pet_root == null or _pet_sprite == null:
		return
	var dt: float = maxf(delta, 0.0)
	var pet_speaking: bool = not _pilot_is_speaking_line
	_pet_focus_t = move_toward(_pet_focus_t, 1.0 if pet_speaking else 0.0, dt * 6.0)

	var scale_mult: float = lerpf(0.95, 1.05, _pet_focus_t) * PET_BASE_SCALE
	_pet_sprite.scale = Vector2(scale_mult, scale_mult)

	var dim_col := Color(0.55, 0.55, 0.65, 0.65)
	_pet_sprite.modulate = dim_col.lerp(Color.WHITE, _pet_focus_t)

	if pet_speaking and _is_typing:
		_pet_wiggle_t += dt
		_pet_sprite.rotation_degrees = sin(_pet_wiggle_t * 12.0) * 4.0
	else:
		_pet_wiggle_t = 0.0
		_pet_sprite.rotation_degrees = move_toward(_pet_sprite.rotation_degrees, 0.0, dt * 36.0)

	if _pet_backlight != null:
		var base_col: Color = PET_TINT_COLORS.get(_active_pet_id, Color(0.95, 0.65, 0.90, 1.0)) as Color
		var glow_a: float = lerpf(0.14, 0.44, _pet_focus_t)
		_pet_backlight.modulate = Color(base_col.r, base_col.g, base_col.b, glow_a)


func _finish_typing() -> void:
	_is_typing = false
	if _portrait_ctrl != null:
		_portrait_ctrl.set_speaking(false)


func _refresh_active_speaker_name_if_pet() -> void:
	if _active_line_idx < 0 or _active_line_idx >= _active_conv_lines.size():
		return
	var line: Dictionary = _active_conv_lines[_active_line_idx] as Dictionary
	if bool(line.get("is_pet", false)):
		var sp_lbl: Label = _hud_refs.get("speaker_label", null) as Label
		if is_instance_valid(sp_lbl):
			sp_lbl.text = _active_pet_id.to_upper()


func _select_emotion_by_index(idx: int) -> void:
	if _config == null or idx < 0 or idx >= _config.entries.size():
		return
	var entry: EntryScript = _config.entries[idx]
	if entry != null:
		select_emotion(entry.emotion_id)


func _on_entry_param_changed(param_name: String, val: float) -> void:
	if _config == null or _portrait_ctrl == null:
		return
	var entry: EntryScript = _config.get_entry(_portrait_ctrl.get_current_emotion())
	if entry == null:
		return
	match param_name:
		"rim_light_strength":
			entry.rim_light_strength = val
		"rim_light_angle_deg":
			entry.rim_light_angle_deg = val
		"cel_strength":
			entry.cel_strength = val
		"specular_strength":
			entry.specular_strength = val
		"face_shadow_protect":
			entry.face_shadow_protect = val
		"breath_amp_px":
			entry.breath_amp_px = val
		"hair_sway_amp_px":
			entry.hair_sway_amp_px = val
		"eye_shimmer_strength":
			entry.eye_shimmer_strength = val
	_portrait_ctrl.refresh_active_entry_params()


func _on_config_param_changed(param_name: String, val: float) -> void:
	if _config == null or _portrait_ctrl == null:
		return
	match param_name:
		"base_display_height_px":
			_config.base_display_height_px = val
		"bottom_fade_start":
			_config.bottom_fade_start = val
	_config.ensure_defaults()
	_portrait_ctrl.refresh_layout_metrics()
	if is_instance_valid(_guides_overlay) and _guides_visible:
		_guides_overlay.queue_redraw()


func _maybe_run_gpu_audit_capture() -> void:
	var audit_dir: String = ""
	for raw_arg: String in OS.get_cmdline_user_args():
		if raw_arg.begins_with("--capture-audit="):
			audit_dir = raw_arg.trim_prefix("--capture-audit=").strip_edges()
	if audit_dir.is_empty():
		return
	if audit_dir.begins_with("res://"):
		audit_dir = ProjectSettings.globalize_path(audit_dir)
	if not DirAccess.dir_exists_absolute(audit_dir):
		DirAccess.make_dir_recursive_absolute(audit_dir)

	var controls_layer: CanvasLayer = _hud_refs.get("controls_layer", null) as CanvasLayer
	if is_instance_valid(controls_layer):
		controls_layer.visible = false
	set_hud_panel_visible(false)
	_portrait_ctrl.set_living_enabled(true)
	_portrait_ctrl.set_particles_enabled(false)

	# 1. Valentina hablando (turno izquierdo activo, Pet atenuada a la derecha)
	set_guides_visible(false)
	start_conversation("mochi")
	advance_conversation() # finaliza typewriter linea 0 (Mochi)
	advance_conversation() # avanza a linea 1 (Valentina)
	var body: RichTextLabel = _hud_refs.get("body_label", null) as RichTextLabel
	if is_instance_valid(body):
		body.visible_characters = _full_line_text.length()
	_finish_typing()
	_portrait_ctrl.set_emotion(&"warm", true)
	_portrait_ctrl.set_focused(true, true)
	_pet_focus_t = 0.0
	_update_pet_turn_state(0.016)
	_portrait_ctrl.step(0.05)
	_sync_ui_for_current_entry()
	var badge: Label = _hud_refs.get("pose_badge_label", null) as Label
	if is_instance_valid(badge):
		badge.text = "[WARM]"
	await _capture_png(audit_dir.path_join("01_ingame_valentina_speaks.png"))

	# 2. Pet Mochi hablando (Pet iluminada derecha, Valentina atenuada izquierda)
	start_conversation("mochi")
	if is_instance_valid(body):
		body.visible_characters = _full_line_text.length()
	_is_typing = true
	_portrait_ctrl.set_focused(false, true)
	_pet_focus_t = 1.0
	_update_pet_turn_state(0.08)
	_portrait_ctrl.step(0.05)
	await _capture_png(audit_dir.path_join("02_ingame_pet_speaks.png"))

	# 3. Alert + Guías portables 1080p activadas (Valentina hablando)
	advance_conversation() # finaliza typewriter
	advance_conversation() # pasa a linea Valentina
	if is_instance_valid(body):
		body.visible_characters = _full_line_text.length()
	_finish_typing()
	_portrait_ctrl.set_emotion(&"alert", true)
	_portrait_ctrl.set_focused(true, true)
	_pet_focus_t = 0.0
	_update_pet_turn_state(0.016)
	set_guides_visible(true)
	_portrait_ctrl.step(0.05)
	_sync_ui_for_current_entry()
	var badge_alert: Label = _hud_refs.get("pose_badge_label", null) as Label
	if is_instance_valid(badge_alert):
		badge_alert.text = "[ALERT]"
	await _capture_png(audit_dir.path_join("03_ingame_alert_guides.png"))

	# 4. Verificación GPU de Motion Mask (Rayos-X modo 6, pose Thinking)
	set_guides_visible(false)
	_portrait_ctrl.set_emotion(&"thinking", true)
	_portrait_ctrl.set_debug_view_mode(6)
	_portrait_ctrl.set_focused(true, true)
	_portrait_ctrl.step(0.05)
	if is_instance_valid(badge_alert):
		badge_alert.text = "[THINKING · MOTION MASK]"
	await _capture_png(audit_dir.path_join("04_motion_mask_debug.png"))
	_portrait_ctrl.set_debug_view_mode(0)

	print("GPU_AUDIT_CAPTURED=", audit_dir)
	get_tree().quit(0)


func _capture_png(out_path: String) -> void:
	for _f: int in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		if img.get_format() == Image.FORMAT_RGBAH or img.get_format() == Image.FORMAT_RGBAF:
			img.linear_to_srgb()
			img.convert(Image.FORMAT_RGBA8)
		img.save_png(out_path)


func _show_theater_line(speaker: String, emotion: StringName, text: String, comms: bool) -> void:
	_full_line_text = text
	_reveal_chars = 0.0
	_is_typing = true

	var sp_lbl: Label = _hud_refs.get("speaker_label", null) as Label
	if is_instance_valid(sp_lbl):
		sp_lbl.text = speaker.to_upper()
		sp_lbl.add_theme_color_override("font_color", Color(0.42, 0.90, 1.0, 1.0) if comms else (Color(1.0, 0.44, 0.58, 1.0) if _pilot_is_speaking_line else Color(0.98, 0.78, 0.36, 1.0)))

	var step_lbl: Label = _hud_refs.get("conv_step_label", null) as Label
	if is_instance_valid(step_lbl):
		step_lbl.text = "Línea %d / %d" % [_active_line_idx + 1, _active_conv_lines.size()]

	var body: RichTextLabel = _hud_refs.get("body_label", null) as RichTextLabel
	if is_instance_valid(body):
		body.text = text
		body.visible_characters = 0

	var badge: Label = _hud_refs.get("pose_badge_label", null) as Label
	if is_instance_valid(badge):
		var radio_tag: String = " · RADIO" if comms else ""
		badge.text = "[%s%s]" % [String(emotion).to_upper(), radio_tag]


func _sync_ui_for_current_entry() -> void:
	if _config == null or _portrait_ctrl == null:
		return
	HUDScript.sync_config_sliders(_hud_refs, _config)
	var entry: EntryScript = _config.get_entry(_portrait_ctrl.get_current_emotion())
	if entry != null:
		HUDScript.sync_entry_sliders(_hud_refs, entry)
		var box_style: StyleBoxFlat = _hud_refs.get("dialogue_box_style", null) as StyleBoxFlat
		if box_style != null:
			box_style.border_color = Color(entry.rim_light_color.r, entry.rim_light_color.g, entry.rim_light_color.b, 0.80)
		var np_style: StyleBoxFlat = _hud_refs.get("nameplate_style", null) as StyleBoxFlat
		if np_style != null:
			np_style.border_color = Color(entry.rim_light_color.r, entry.rim_light_color.g, entry.rim_light_color.b, 0.88)


func _load_pet_texture(pet_id: String) -> Texture2D:
	if _pet_tex_cache.has(pet_id) and _pet_tex_cache[pet_id] != null:
		return _pet_tex_cache[pet_id] as Texture2D
	var res_path: String = "res://assets/pets/pet_%s.png" % pet_id
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		tex = ResourceLoader.load(res_path) as Texture2D
	if tex == null:
		var abs_path: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var img: Image = Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
	_pet_tex_cache[pet_id] = tex
	return tex


func _build_pet_backlight_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(0.45, Color(1.0, 1.0, 1.0, 0.35))
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
	var gt := GradientTexture2D.new()
	gt.width = 512
	gt.height = 768
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.gradient = grad
	return gt


func _set_status(msg: String) -> void:
	var lbl: Label = _hud_refs.get("status_label", null) as Label
	if is_instance_valid(lbl):
		lbl.text = msg
