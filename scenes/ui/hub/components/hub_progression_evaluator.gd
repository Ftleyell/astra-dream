class_name HubProgressionEvaluator
extends RefCounted

## Evaluador puro y data-driven de desbloqueos progresivos (CALIBRATING / NEWLY_UNLOCKED / ONLINE)
## para las estaciones y sub-módulos de la Estación Astral v2. Nunca muta SaveManager.

const ConfigScript = preload("res://scenes/ui/hub/resources/hub_progression_config.gd")
const RuleScript = preload("res://scenes/ui/hub/resources/hub_module_unlock_rule.gd")
const DEFAULT_CONFIG: ConfigScript = preload("res://data/hub/default_hub_progression_config.tres")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")
const CharacterDataScript = preload("res://data/characters/character_data.gd")
const DebugManagerScript = preload("res://core/autoloads/debug_manager.gd")

enum ModuleState {
	CALIBRATING = 0,
	NEWLY_UNLOCKED = 1,
	ONLINE = 2,
}

const TACTICAL_SUBMODULES: Array[StringName] = [
	&"tactical_banlist",
	&"tactical_tomes",
	&"tactical_speed",
	&"tactical_seed",
]

var _config: ConfigScript = DEFAULT_CONFIG
var _states: Dictionary = {}
var _acknowledged: Dictionary = {}
var _has_evaluated_once: bool = false
var _last_snapshot: Dictionary = {}


func setup(p_config: ConfigScript = null) -> void:
	_config = p_config if p_config != null else DEFAULT_CONFIG
	_states.clear()
	_acknowledged.clear()
	_has_evaluated_once = false
	_last_snapshot.clear()


func get_config() -> ConfigScript:
	return _config if _config != null else DEFAULT_CONFIG


static func build_live_snapshot(debug_force_unlock: bool = false) -> Dictionary:
	var unlocked_skins_count: int = SaveManagerScript.get_unlocked_skins().size()
	var biomass: int = SaveManagerScript.get_biomass()
	var antimatter: int = SaveManagerScript.get_antimatter()
	var unlocked_companions: int = SaveManagerScript.get_unlocked_pets().size() + SaveManagerScript.get_unlocked_navigators().size()
	var career: Dictionary = SaveManagerScript.get_career_stats()
	var runs_played: int = int(career.get("total_runs_played", 0))
	var bosses_killed: int = int(career.get("total_bosses_killed", 0))
	var runs_cleared: int = int(career.get("total_runs_cleared", 0))

	var playable_pilots: int = 0
	var roster: Array[CharacterData] = CharacterDataScript.load_roster_ordered()
	for cd: CharacterData in roster:
		if cd == null:
			continue
		if cd.is_playable_rework_ready and SaveManagerScript.is_character_unlocked(cd.character_id):
			playable_pilots += 1

	var debug_active: bool = debug_force_unlock
	if not debug_active and DebugManagerScript.is_debug_enabled():
		var loop: MainLoop = Engine.get_main_loop()
		var tree: SceneTree = loop as SceneTree
		if tree != null and tree.root != null and tree.root.has_node("DebugManager"):
			var dm: Node = tree.root.get_node("DebugManager")
			if dm != null and "is_enabled" in dm and bool(dm.get("is_enabled")):
				debug_active = true

	return {
		"playable_pilots": playable_pilots,
		"unlocked_skins": unlocked_skins_count,
		"biomass": biomass,
		"antimatter": antimatter,
		"unlocked_companions": unlocked_companions,
		"total_runs_played": runs_played,
		"total_bosses_killed": bosses_killed,
		"total_runs_cleared": runs_cleared,
		"debug_force_unlock": debug_active,
	}


static func build_preset_snapshot(preset_id: StringName) -> Dictionary:
	match preset_id:
		&"run1":
			return {
				"playable_pilots": 1,
				"unlocked_skins": 0,
				"biomass": 0,
				"antimatter": 0,
				"unlocked_companions": 0,
				"total_runs_played": 0,
				"total_bosses_killed": 0,
				"total_runs_cleared": 0,
				"debug_force_unlock": false,
			}
		&"post_run1":
			return {
				"playable_pilots": 1,
				"unlocked_skins": 1,
				"biomass": 45,
				"antimatter": 0,
				"unlocked_companions": 1,
				"total_runs_played": 1,
				"total_bosses_killed": 0,
				"total_runs_cleared": 0,
				"debug_force_unlock": false,
			}
		&"post_boss":
			return {
				"playable_pilots": 1,
				"unlocked_skins": 2,
				"biomass": 120,
				"antimatter": 15,
				"unlocked_companions": 2,
				"total_runs_played": 2,
				"total_bosses_killed": 1,
				"total_runs_cleared": 0,
				"debug_force_unlock": false,
			}
		&"all_online":
			return {
				"playable_pilots": 2,
				"unlocked_skins": 3,
				"biomass": 300,
				"antimatter": 40,
				"unlocked_companions": 3,
				"total_runs_played": 4,
				"total_bosses_killed": 2,
				"total_runs_cleared": 1,
				"debug_force_unlock": false,
			}
		&"debug_unlock":
			var snap: Dictionary = build_preset_snapshot(&"run1")
			snap["debug_force_unlock"] = true
			return snap
		_:
			return build_live_snapshot(false)


func evaluate_snapshot(snapshot: Dictionary) -> Dictionary:
	var cfg: ConfigScript = get_config()
	_last_snapshot = snapshot.duplicate(true)
	var debug_unlock: bool = cfg.debug_unlock_all_in_debug_mode and bool(snapshot.get("debug_force_unlock", false))

	for rule: RuleScript in cfg.module_rules:
		if rule == null or rule.module_id == &"":
			continue
		var mid: StringName = rule.module_id
		var prev_state: ModuleState = _states.get(mid, ModuleState.CALIBRATING) as ModuleState
		var unlocked_now: bool = debug_unlock or _rule_matches_snapshot(rule, snapshot)

		var next_state: ModuleState = ModuleState.CALIBRATING
		if unlocked_now:
			if _has_evaluated_once and prev_state == ModuleState.CALIBRATING and not bool(_acknowledged.get(mid, false)):
				next_state = ModuleState.NEWLY_UNLOCKED
			elif prev_state == ModuleState.NEWLY_UNLOCKED and not bool(_acknowledged.get(mid, false)):
				next_state = ModuleState.NEWLY_UNLOCKED
			else:
				next_state = ModuleState.ONLINE
		else:
			_acknowledged.erase(mid)

		_states[mid] = next_state

	_has_evaluated_once = true
	return _states.duplicate(true)


func _rule_matches_snapshot(rule: RuleScript, snapshot: Dictionary) -> bool:
	var thresh: int = maxi(0, rule.threshold)
	match rule.unlock_metric:
		RuleScript.UnlockMetric.ALWAYS_ONLINE:
			return true
		RuleScript.UnlockMetric.PLAYABLE_PILOTS_AT_LEAST:
			return int(snapshot.get("playable_pilots", 0)) >= thresh
		RuleScript.UnlockMetric.UNLOCKED_SKINS_AT_LEAST:
			return int(snapshot.get("unlocked_skins", 0)) >= thresh
		RuleScript.UnlockMetric.BIOMASS_OR_ANTIMATTER_OR_RUNS:
			return (
				int(snapshot.get("biomass", 0)) >= thresh
				or int(snapshot.get("antimatter", 0)) >= thresh
				or int(snapshot.get("total_runs_played", 0)) >= thresh
			)
		RuleScript.UnlockMetric.UNLOCKED_COMPANIONS_AT_LEAST:
			return int(snapshot.get("unlocked_companions", 0)) >= thresh
		RuleScript.UnlockMetric.TOTAL_RUNS_PLAYED_AT_LEAST:
			return int(snapshot.get("total_runs_played", 0)) >= thresh
		RuleScript.UnlockMetric.TOTAL_BOSSES_KILLED_AT_LEAST:
			return int(snapshot.get("total_bosses_killed", 0)) >= thresh
		RuleScript.UnlockMetric.TOTAL_RUNS_CLEARED_AT_LEAST:
			return int(snapshot.get("total_runs_cleared", 0)) >= thresh
		_:
			return false


func get_module_state(module_id: StringName) -> ModuleState:
	return _states.get(module_id, ModuleState.CALIBRATING) as ModuleState


func is_module_unlocked(module_id: StringName) -> bool:
	return get_module_state(module_id) != ModuleState.CALIBRATING


func get_tactical_console_state() -> ModuleState:
	var any_online: bool = false
	for sub_id: StringName in TACTICAL_SUBMODULES:
		var st: ModuleState = get_module_state(sub_id)
		if st == ModuleState.NEWLY_UNLOCKED:
			return ModuleState.NEWLY_UNLOCKED
		if st == ModuleState.ONLINE:
			any_online = true
	return ModuleState.ONLINE if any_online else ModuleState.CALIBRATING


func is_tactical_console_online() -> bool:
	return get_tactical_console_state() != ModuleState.CALIBRATING


func get_locked_hint(module_id: StringName) -> String:
	var cfg: ConfigScript = get_config()
	if module_id == &"tactical_console":
		var ban_rule: RuleScript = cfg.get_rule(&"tactical_banlist")
		if ban_rule != null and not ban_rule.locked_hint_text.is_empty():
			return ban_rule.locked_hint_text
		return "Completa 1 incursión para calibrar Consola Táctica"
	var rule: RuleScript = cfg.get_rule(module_id)
	if rule != null and not rule.locked_hint_text.is_empty():
		return rule.locked_hint_text
	return "En Calibración"


func acknowledge_module(module_id: StringName) -> void:
	_acknowledged[module_id] = true
	if get_module_state(module_id) == ModuleState.NEWLY_UNLOCKED:
		_states[module_id] = ModuleState.ONLINE


func acknowledge_tactical_console() -> void:
	for sub_id: StringName in TACTICAL_SUBMODULES:
		if get_module_state(sub_id) != ModuleState.CALIBRATING:
			acknowledge_module(sub_id)


func acknowledge_all_unlocked() -> void:
	for mid_var: Variant in _states.keys():
		var mid: StringName = mid_var as StringName
		if get_module_state(mid) != ModuleState.CALIBRATING:
			acknowledge_module(mid)


func get_last_snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)
