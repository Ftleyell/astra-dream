class_name EnemyArchetypeVisualCatalog
extends Resource

## Data-driven catalog mapping production EnemyBase archetypes to Void Scarab
## 2.5D placeholder palettes, sizes, and flight trail options.

@export_range(0.05, 0.60) var combat_base_rig_scale: float = 0.175
@export var entries: Array[EnemyArchetypeVisualEntry] = []

var _lookup_cache: Dictionary = {}


func resolve_entry(p_enemy_id: StringName) -> EnemyArchetypeVisualEntry:
	if _lookup_cache.is_empty() and not entries.is_empty():
		for item: EnemyArchetypeVisualEntry in entries:
			if item != null and item.enemy_id != &"":
				_lookup_cache[item.enemy_id] = item
	if _lookup_cache.has(p_enemy_id):
		return _lookup_cache[p_enemy_id] as EnemyArchetypeVisualEntry
	if not entries.is_empty() and entries[0] != null:
		return entries[0]
	var fallback := EnemyArchetypeVisualEntry.new()
	fallback.enemy_id = p_enemy_id
	fallback.display_label = String(p_enemy_id)
	return fallback
