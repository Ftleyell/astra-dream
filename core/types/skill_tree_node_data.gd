class_name SkillTreeNodeData
extends Resource

## Definición de datos de un nodo individual en la constelación del Árbol de Habilidades.
## Recurso serializable data-driven para balance de talentos de pilotos.

@export var id: StringName = &"core"
@export var branch: String = "NÚCLEO"
@export var title: String = "NÚCLEO DE PILOTO"
@export_multiline var description: String = ""
@export var glyph: String = "⚛"
@export var position: Vector2 = Vector2.ZERO
@export var cost: int = 25
@export var req_id: StringName = &""

func to_dict() -> Dictionary:
	return {
		"id": id,
		"branch": branch,
		"title": title,
		"desc": description,
		"glyph": glyph,
		"pos": position,
		"cost": cost,
		"req": req_id
	}

static func from_dict(d: Dictionary) -> Resource:
	var script_cls: GDScript = load("res://core/types/skill_tree_node_data.gd")
	var node = script_cls.new()
	node.id = StringName(str(d.get("id", "core")))
	node.branch = str(d.get("branch", "NÚCLEO"))
	node.title = str(d.get("title", ""))
	node.description = str(d.get("desc", ""))
	node.glyph = str(d.get("glyph", "⚛"))
	var raw_pos = d.get("pos", Vector2.ZERO)
	if raw_pos is Vector2:
		node.position = raw_pos
	node.cost = int(d.get("cost", 25))
	node.req_id = StringName(str(d.get("req", "")))
	return node
