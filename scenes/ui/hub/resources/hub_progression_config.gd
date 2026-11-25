class_name HubProgressionConfig
extends Resource

## Configuración maestra de progresión progresiva (CALIBRATING -> NEWLY_UNLOCKED -> ONLINE)
## y políticas de integridad para runs seeded en la Estación Astral v2.

const RuleScript = preload("res://scenes/ui/hub/resources/hub_module_unlock_rule.gd")

@export var module_rules: Array[RuleScript] = []
@export var calibrating_desaturation: float = 0.85
@export var calibrating_tint: Color = Color(0.32, 0.36, 0.48, 1.0)
@export var newly_unlocked_pulse_hz: float = 2.2
@export var debug_unlock_all_in_debug_mode: bool = true

@export_group("Seeded Run Policy")
@export var allow_highscores_on_custom_seed: bool = false
@export var allow_trophies_on_custom_seed: bool = false


func get_rule(p_module_id: StringName) -> RuleScript:
	for rule: RuleScript in module_rules:
		if rule != null and rule.module_id == p_module_id:
			return rule
	return null
