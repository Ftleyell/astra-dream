class_name SkillTreeConfig
extends Resource

const SkillTreeNodeDataClass = preload("res://core/types/skill_tree_node_data.gd")

## Recurso de configuración de Árbol de Habilidades por personaje.
## Centraliza la definición de constelaciones, costes y dependencias de forma Data-Driven.

@export var character_id: StringName = &"default"
@export var node_cost: int = 25
@export var nodes: Array[Resource] = []

func get_node_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for n in nodes:
		if n and n.has_method("to_dict"):
			result.append(n.to_dict())
	return result

func get_node_dict_by_id(target_id: StringName) -> Dictionary:
	for n in nodes:
		if n and n.get("id") == target_id:
			if n.has_method("to_dict"):
				return n.to_dict()
	return {}

func get_node_data_by_id(target_id: StringName) -> Resource:
	for n in nodes:
		if n and n.get("id") == target_id:
			return n
	return null

static func get_config_for_character(char_id: StringName) -> Resource:
	var custom_path := "res://data/skill_trees/skill_tree_%s.tres" % String(char_id).to_lower()
	if ResourceLoader.exists(custom_path):
		var res := ResourceLoader.load(custom_path)
		if res:
			return res

	var default_path := "res://data/skill_trees/skill_tree_default.tres"
	if ResourceLoader.exists(default_path):
		var def_res := ResourceLoader.load(default_path)
		if def_res:
			return def_res

	# Generador programático de salvaguarda (Zero-Failure)
	return _build_fallback_config(char_id)

static func _build_fallback_config(char_id: StringName) -> Resource:
	var script_cls: GDScript = load("res://core/types/skill_tree_config.gd")
	var config = script_cls.new()
	config.character_id = char_id
	config.node_cost = 25

	if char_id == &"nyx":
		config.nodes = _build_nyx_nodes()
	else:
		config.nodes = _build_default_nodes()

	return config

static func _build_default_nodes() -> Array[Resource]:
	var raw_defs: Array[Dictionary] = [
		{ "id": &"core", "branch": "NÚCLEO", "title": "NÚCLEO DE PILOTO", "desc": "Matriz neural primaria del piloto. Punto de origen de todas las rutas de hiper-conducción.", "glyph": "⚛", "pos": Vector2(0, 0), "cost": 0, "req": &"" },
		{ "id": &"speed_1", "branch": "VELOCIDAD", "title": "IMPULSO VECTORIAL I", "desc": "+20% Velocidad de movimiento permanente en combate.", "glyph": "⚡", "pos": Vector2(0, -115), "cost": 25, "req": &"core" },
		{ "id": &"speed_2", "branch": "VELOCIDAD", "title": "IMPULSO VECTORIAL II", "desc": "+20% Velocidad de movimiento permanente (+40% acumulado).", "glyph": "⚡", "pos": Vector2(0, -225), "cost": 25, "req": &"speed_1" },
		{ "id": &"speed_3", "branch": "VELOCIDAD", "title": "SOBRECARGA DE POSTQUEMADOR", "desc": "+20% Velocidad de movimiento permanente (+60% acumulado).", "glyph": "⚡", "pos": Vector2(0, -335), "cost": 25, "req": &"speed_2" },
		{ "id": &"damage_1", "branch": "DAÑO", "title": "SOBREALIMENTACIÓN TÉRMICA I", "desc": "+15% Daño general infligido permanente en combate.", "glyph": "⚔", "pos": Vector2(150, 0), "cost": 25, "req": &"core" },
		{ "id": &"damage_2", "branch": "DAÑO", "title": "SOBREALIMENTACIÓN TÉRMICA II", "desc": "+15% Daño general permanente (+30% acumulado).", "glyph": "⚔", "pos": Vector2(280, 0), "cost": 25, "req": &"damage_1" },
		{ "id": &"damage_3", "branch": "DAÑO", "title": "FUSIÓN DE CAÑÓN CUÁNTICO", "desc": "+15% Daño general permanente (+45% acumulado).", "glyph": "⚔", "pos": Vector2(410, 0), "cost": 25, "req": &"damage_2" },
		{ "id": &"hp_1", "branch": "SUPERVIVENCIA", "title": "NANO-BLINDAJE REGENERATIVO I", "desc": "+25 Puntos de Salud Máxima permanente en combate.", "glyph": "🛡", "pos": Vector2(0, 115), "cost": 25, "req": &"core" },
		{ "id": &"hp_2", "branch": "SUPERVIVENCIA", "title": "NANO-BLINDAJE REGENERATIVO II", "desc": "+25 Puntos de Salud Máxima permanente (+50 HP acumulado).", "glyph": "🛡", "pos": Vector2(0, 225), "cost": 25, "req": &"hp_1" },
		{ "id": &"hp_3", "branch": "SUPERVIVENCIA", "title": "MATRIZ DE CASCO TITÁN", "desc": "+25 Puntos de Salud Máxima permanente (+75 HP acumulado).", "glyph": "🛡", "pos": Vector2(0, 335), "cost": 25, "req": &"hp_2" },
		{ "id": &"crit_1", "branch": "UTILIDAD", "title": "TELEMETRÍA DE PRECISIÓN I", "desc": "+5% Probabilidad Crítica y +5% Cadencia de ataque permanente.", "glyph": "✦", "pos": Vector2(-150, 0), "cost": 25, "req": &"core" },
		{ "id": &"crit_2", "branch": "UTILIDAD", "title": "TELEMETRÍA DE PRECISIÓN II", "desc": "+5% Probabilidad Crítica y +5% Cadencia (+10% acumulado).", "glyph": "✦", "pos": Vector2(-280, 0), "cost": 25, "req": &"crit_1" },
		{ "id": &"crit_3", "branch": "UTILIDAD", "title": "SINCRONIZADOR HIPER-ÓPTICO", "desc": "+5% Probabilidad Crítica y +5% Cadencia (+15% acumulado).", "glyph": "✦", "pos": Vector2(-410, 0), "cost": 25, "req": &"crit_2" }
	]

	var arr: Array[Resource] = []
	for d in raw_defs:
		arr.append(SkillTreeNodeDataClass.from_dict(d))
	return arr

static func _build_nyx_nodes() -> Array[Resource]:
	var raw_defs: Array[Dictionary] = [
		{ "id": &"core", "branch": "NÚCLEO", "title": "NÚCLEO CREPUSCULAR", "desc": "Matriz dimensional de Nyx. Canaliza energía del vacío hacia la Hoja Crepuscular y el motor de fase.", "glyph": "⚛", "pos": Vector2(0, 0), "cost": 0, "req": &"" },
		{ "id": &"nyx_speed_1", "branch": "PASO UMBRÍO", "title": "PASO ENTRE FRENTES I", "desc": "+18% Velocidad de movimiento permanente en combate.", "glyph": "⚡", "pos": Vector2(0, -115), "cost": 25, "req": &"core" },
		{ "id": &"nyx_speed_2", "branch": "PASO UMBRÍO", "title": "TRASLACIÓN FLUIDA II", "desc": "+18% Velocidad de movimiento permanente (+36% acumulado).", "glyph": "⚡", "pos": Vector2(0, -225), "cost": 25, "req": &"nyx_speed_1" },
		{ "id": &"nyx_speed_3", "branch": "PASO UMBRÍO", "title": "SALTO DIMENSIONAL PERPETUO", "desc": "+18% Velocidad (+54% acum.) y recarga de Dash un 15% más rápida.", "glyph": "⚡", "pos": Vector2(0, -335), "cost": 25, "req": &"nyx_speed_2" },
		{ "id": &"nyx_dmg_1", "branch": "FILO DIMENSIONAL", "title": "FILO DEL CREPÚSCULO I", "desc": "+18% Daño cuerpo a cuerpo general permanente.", "glyph": "⚔", "pos": Vector2(150, 0), "cost": 25, "req": &"core" },
		{ "id": &"nyx_dmg_2", "branch": "FILO DIMENSIONAL", "title": "RESQUEBRAJADURA ESPACIAL II", "desc": "+18% Daño cuerpo a cuerpo permanente (+36% acumulado).", "glyph": "⚔", "pos": Vector2(280, 0), "cost": 25, "req": &"nyx_dmg_1" },
		{ "id": &"nyx_dmg_3", "branch": "FILO DIMENSIONAL", "title": "SINGULARIDAD CORTANTE", "desc": "+18% Daño cuerpo a cuerpo (+54% acum.) y +15% tamaño del arco de corte.", "glyph": "⚔", "pos": Vector2(410, 0), "cost": 25, "req": &"nyx_dmg_2" },
		{ "id": &"nyx_hp_1", "branch": "MANTO CREPUSCULAR", "title": "ESCUDO DE EVENTOS I", "desc": "+30 Puntos de Salud Máxima permanente en combate.", "glyph": "🛡", "pos": Vector2(0, 115), "cost": 25, "req": &"core" },
		{ "id": &"nyx_hp_2", "branch": "MANTO CREPUSCULAR", "title": "TEJIDO DIMENSIONAL II", "desc": "+30 Puntos de Salud Máxima permanente (+60 HP acumulado).", "glyph": "🛡", "pos": Vector2(0, 225), "cost": 25, "req": &"nyx_hp_1" },
		{ "id": &"nyx_hp_3", "branch": "MANTO CREPUSCULAR", "title": "ANCLAJE ESPACIO-TEMPORAL", "desc": "+30 HP Máxima (+90 HP acum.) y +1.0 Regeneración de HP/segundo.", "glyph": "🛡", "pos": Vector2(0, 335), "cost": 25, "req": &"nyx_hp_2" },
		{ "id": &"nyx_crit_1", "branch": "FURIA DE MEDIALUNA", "title": "COMPÁS DE MEDIA LUNA I", "desc": "+6% Probabilidad Crítica y +6% Cadencia de ataque melee permanente.", "glyph": "✦", "pos": Vector2(-150, 0), "cost": 25, "req": &"core" },
		{ "id": &"nyx_crit_2", "branch": "FURIA DE MEDIALUNA", "title": "RÁFAGA DE VACÍO II", "desc": "+6% Probabilidad Crítica y +6% Cadencia (+12% acumulado).", "glyph": "✦", "pos": Vector2(-280, 0), "cost": 25, "req": &"nyx_crit_1" },
		{ "id": &"nyx_crit_3", "branch": "FURIA DE MEDIALUNA", "title": "VERDUGO DEL ECLIPSE", "desc": "+8% Prob. Crítica y +8% Cadencia (+20% acum.) y +20% Daño Crítico.", "glyph": "✦", "pos": Vector2(-410, 0), "cost": 25, "req": &"nyx_crit_2" }
	]

	var arr: Array[Resource] = []
	for d in raw_defs:
		arr.append(SkillTreeNodeDataClass.from_dict(d))
	return arr
