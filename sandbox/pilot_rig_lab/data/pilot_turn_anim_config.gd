class_name PilotTurnAnimConfig
extends Resource
## Configuración data-driven de giros snappy 8-dir (Puente 2.5D + Cascada Esquelética)
## y Whip Cervical completo para cabeza desacoplada en Valentina v2.

const BasePoseConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_base_pose_config.gd")

enum PreviewMode {
	AUTO_BODY_AND_HEAD_CYCLE = 0,
	BODY_STEP_45_CYCLE = 1,
	BODY_WHIP_90_CYCLE = 2,
	HEAD_ONLY_WHIP_CYCLE = 3,
}

const FAMILY_ORDER: Array[String] = ["s", "se", "e", "ne", "n"]
const MUL_KEYS: Array[String] = ["turn_scale"]

const FLOAT_DEFAULTS: Dictionary = {
	"master_intensity": 1.0,
	"body_turn_duration_sec": 0.135,
	"body_swap_point": 0.34,
	"head_turn_duration_sec": 0.085,
	"preview_step_interval_sec": 0.95,
	"pre_yaw_25d": 0.19,
	"post_catchup_yaw_25d": 0.22,
	"turn_torso_trap_pulse": 0.065,
	"pelvis_whip_shift_x_px": 2.8,
	"pelvis_bob_y_px": 1.35,
	"spine_overshoot_rot": 0.095,
	"limb_lag_phase": 0.28,
	"arm_whip_rot": 0.165,
	"leg_whip_rot": 0.135,
	"leg_shin_phi_pulse": 0.075,
	"body_turn_hair_whip_px": 3.4,
	"body_turn_chest_jiggle_px": 1.15,
	"head_lead_rot": 0.075,
	"head_whip_overshoot_rot": 0.085,
	"head_whip_offset_x_px": 1.45,
	"head_neck_kick_rot": 0.065,
	"head_sympathetic_chest_rot": 0.035,
	"head_whip_hair_px": 2.65,
}

@export var anim_id: String = "snappy_turn_whip_zero_g"
@export var display_name: String = "Giros Snappy 2.5D & Whip Cervical"

# A. Tiempos y Control (turn_timing)
@export var master_intensity: float = 1.0
@export var body_turn_duration_sec: float = 0.135
@export var body_swap_point: float = 0.34
@export var head_turn_duration_sec: float = 0.085
@export var preview_step_interval_sec: float = 0.95

# B. Puente 2.5D & Overshoot de Torso (turn_bridge)
@export var pre_yaw_25d: float = 0.19
@export var post_catchup_yaw_25d: float = 0.22
@export var turn_torso_trap_pulse: float = 0.065
@export var pelvis_whip_shift_x_px: float = 2.8
@export var pelvis_bob_y_px: float = 1.35
@export var spine_overshoot_rot: float = 0.095

# C. Cascada Cinemática: Extremidades y Cabello (turn_cascade)
@export var limb_lag_phase: float = 0.28
@export var arm_whip_rot: float = 0.165
@export var leg_whip_rot: float = 0.135
@export var leg_shin_phi_pulse: float = 0.075
@export var body_turn_hair_whip_px: float = 3.4
@export var body_turn_chest_jiggle_px: float = 1.15

# D. Whip Cervical de Cabeza Desacoplada (turn_head)
@export var head_lead_rot: float = 0.075
@export var head_whip_overshoot_rot: float = 0.085
@export var head_whip_offset_x_px: float = 1.45
@export var head_neck_kick_rot: float = 0.065
@export var head_sympathetic_chest_rot: float = 0.035
@export var head_whip_hair_px: float = 2.65

# E. Multiplicadores por Familia (turn_fam)
@export var family_multipliers: Dictionary = {}


func _init() -> void:
	ensure_initialized()


## Construye multiplicadores por defecto para cada familia direccional canónica.
static func build_default_family_multipliers() -> Dictionary:
	return {
		"s": {"turn_scale": 1.0},
		"se": {"turn_scale": 1.0},
		"e": {"turn_scale": 0.95},
		"ne": {"turn_scale": 0.95},
		"n": {"turn_scale": 0.90},
	}


## Garantiza que todas las familias y claves existan con tipos válidos.
func ensure_initialized() -> void:
	var defaults: Dictionary = build_default_family_multipliers()
	for fam: String in FAMILY_ORDER:
		var def_fam: Dictionary = defaults[fam] as Dictionary
		if not family_multipliers.has(fam) or not (family_multipliers[fam] is Dictionary):
			family_multipliers[fam] = def_fam.duplicate(true)
			continue
		var cur_fam: Dictionary = family_multipliers[fam] as Dictionary
		for k: String in MUL_KEYS:
			if not cur_fam.has(k):
				cur_fam[k] = float(def_fam[k])


## Restaura todos los parámetros globales y multiplicadores a sus valores por defecto.
func reset_to_defaults() -> void:
	for k: String in FLOAT_DEFAULTS.keys():
		set(k, float(FLOAT_DEFAULTS[k]))
	family_multipliers = build_default_family_multipliers()


## Lee un parámetro global exportado por nombre.
func get_global_param(param_key: String) -> float:
	if param_key in self:
		return float(get(param_key))
	return 0.0


## Modifica un parámetro global exportado por nombre.
func set_global_param(param_key: String, value: float) -> void:
	if param_key in self:
		set(param_key, value)


## Lee el multiplicador de giro para una familia canónica o vista individual.
func get_family_mul(family_key: String, mul_key: String = "turn_scale") -> float:
	ensure_initialized()
	var can_fam: String = BasePoseConfigScript.canonical_family_for_view(family_key)
	var d: Dictionary = family_multipliers.get(can_fam, {}) as Dictionary
	return float(d.get(mul_key, 1.0))


## Actualiza el multiplicador de giro para una familia canónica.
func set_family_mul(family_key: String, mul_key: String, value: float) -> void:
	ensure_initialized()
	var can_fam: String = BasePoseConfigScript.canonical_family_for_view(family_key)
	var d: Dictionary = family_multipliers.get(can_fam, {}) as Dictionary
	d[mul_key] = value
	family_multipliers[can_fam] = d
