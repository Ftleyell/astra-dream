class_name HubModuleUnlockRule
extends Resource

## Regla data-driven de desbloqueo progresivo para un módulo o sub-módulo del Hub 3D.

enum UnlockMetric {
	ALWAYS_ONLINE = 0,
	PLAYABLE_PILOTS_AT_LEAST = 1,
	UNLOCKED_SKINS_AT_LEAST = 2,
	BIOMASS_OR_ANTIMATTER_OR_RUNS = 3,
	UNLOCKED_COMPANIONS_AT_LEAST = 4,
	TOTAL_RUNS_PLAYED_AT_LEAST = 5,
	TOTAL_BOSSES_KILLED_AT_LEAST = 6,
	TOTAL_RUNS_CLEARED_AT_LEAST = 7,
}

@export var module_id: StringName = &""
@export var display_name: String = ""
@export var unlock_metric: UnlockMetric = UnlockMetric.ALWAYS_ONLINE
@export var threshold: int = 1
@export var locked_hint_text: String = "En Calibración"
@export var accent_override: Color = Color(0.0, 0.94, 1.0, 1.0)
