class_name TomeController
extends Node

## TomeController.gd
## Componente desacoplado que gestiona los hasta 4 tomos de atributos (estilo Megabonk)
## equipados durante una run por el jugador.

const TomeDataScript = preload("res://data/tomes/tome_data.gd")
const TomeCatalog = preload("res://data/tomes/tome_catalog.gd")

signal tome_equipped(tome: TomeDataScript, level: int)
signal tome_leveled_up(tome: TomeDataScript, new_level: int)
signal tomes_updated(equipped_tomes: Array[TomeDataScript], tome_levels: Dictionary)

const MAX_TOME_SLOTS: int = 4

var player: Player = null
var equipped_tomes: Array[TomeDataScript] = []
var tome_levels: Dictionary[StringName, int] = {}

func setup(p_player: Player) -> void:
	player = p_player
	apply_all_modifiers()

func can_equip_or_upgrade(tome: TomeDataScript) -> bool:
	if not tome:
		return false
	if is_tome_equipped(tome.tome_id):
		var cur_lvl: int = get_tome_level(tome.tome_id)
		if tome.max_level > 0 and cur_lvl >= tome.max_level:
			return false
		return true
	return equipped_tomes.size() < MAX_TOME_SLOTS

func is_tome_equipped(tome_id: StringName) -> bool:
	return tome_levels.has(tome_id)

func get_tome_level(tome_id: StringName) -> int:
	return tome_levels.get(tome_id, 0)

func get_tome_count() -> int:
	return equipped_tomes.size()

func is_full() -> bool:
	return equipped_tomes.size() >= MAX_TOME_SLOTS

func equip_or_upgrade_tome(tome: TomeDataScript) -> bool:
	if not tome:
		return false

	var id: StringName = tome.tome_id
	if is_tome_equipped(id):
		var cur_lvl: int = tome_levels[id]
		if tome.max_level > 0 and cur_lvl >= tome.max_level:
			return false
		var new_lvl: int = cur_lvl + 1
		tome_levels[id] = new_lvl
		_apply_tome_modifier(tome, new_lvl)
		tome_leveled_up.emit(tome, new_lvl)
		tomes_updated.emit(equipped_tomes, tome_levels)
		_play_upgrade_sfx()
		return true

	if equipped_tomes.size() >= MAX_TOME_SLOTS:
		return false

	equipped_tomes.append(tome)
	tome_levels[id] = 1
	_apply_tome_modifier(tome, 1)
	tome_equipped.emit(tome, 1)
	tomes_updated.emit(equipped_tomes, tome_levels)
	_play_upgrade_sfx()
	return true

func _apply_tome_modifier(tome: TomeDataScript, level: int) -> void:
	if not player or not is_instance_valid(player) or not player.stats:
		return

	var mod_id: StringName = StringName("tome_" + str(tome.tome_id))
	var total_val: float = tome.stat_value_per_level * float(level)
	var mod := CharacterStats.StatModifier.new(
		mod_id,
		total_val,
		tome.get_effective_modifier_type(),
		self
	)
	player.stats.set_or_replace_modifier(tome.stat_name, mod)

func apply_all_modifiers() -> void:
	if not player or not is_instance_valid(player) or not player.stats:
		return
	for tome: TomeDataScript in equipped_tomes:
		var lvl: int = get_tome_level(tome.tome_id)
		if lvl > 0:
			_apply_tome_modifier(tome, lvl)

func _play_upgrade_sfx() -> void:
	if not is_inside_tree():
		return
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 1.8, 3.5)

func serialize() -> Dictionary:
	var list: Array[Dictionary] = []
	for tome: TomeDataScript in equipped_tomes:
		list.append({
			"id": str(tome.tome_id),
			"level": get_tome_level(tome.tome_id)
		})
	return { "equipped_tomes": list }

func deserialize(data: Dictionary) -> void:
	equipped_tomes.clear()
	tome_levels.clear()
	if not data.has("equipped_tomes"):
		return
	var list: Array = data["equipped_tomes"]
	for entry in list:
		var id := StringName(entry.get("id", ""))
		var lvl := int(entry.get("level", 1))
		var tome := TomeCatalog.load_tome(id)
		if tome:
			equipped_tomes.append(tome)
			tome_levels[id] = lvl
	apply_all_modifiers()
	tomes_updated.emit(equipped_tomes, tome_levels)
