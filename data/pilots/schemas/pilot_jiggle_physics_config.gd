class_name PilotJigglePhysicsConfig
extends Resource
## Configuración data-driven de física secundaria sutil (busto y glúteos) para Valentina v2 (8-Dir).
## Modela dinámicas diferenciadas: busto suave en ingravidez y glúteos firmes acoplados a cadera/muslos.

const BasePoseConfigScript = preload("res://data/pilots/schemas/pilot_base_pose_config.gd")

enum PreviewMode {
	AUTO_CHOREO_CYCLE = 0,
	BRAKE_BOUNCE_PULSE = 1,
	LATERAL_TURN_WHIP = 2,
	IDLE_BREATH_ONLY = 3,
}

const FAMILY_ORDER: Array[String] = ["s", "se", "e", "ne", "n"]
const MUL_KEYS: Array[String] = ["bust_scale", "glute_scale"]

const FLOAT_DEFAULTS: Dictionary = {
	"master_intensity": 1.0,
	"normal_light_strength": 0.015,
	"preview_pulse_interval_sec": 1.15,
	"bust_idle_amp_px": 1.35,
	"bust_freq_hz": 2.15,
	"bust_damping_ratio": 0.28,
	"bust_inertia_gain": 1.35,
	"bust_lr_asymmetry": 0.24,
	"bust_max_clamp_px": 7.50,
	"glute_idle_amp_px": 0.95,
	"glute_freq_hz": 2.85,
	"glute_damping_ratio": 0.36,
	"glute_inertia_gain": 1.25,
	"glute_thigh_coupling": 0.95,
	"glute_lr_asymmetry": 0.32,
	"glute_max_clamp_px": 6.20,
}

@export var anim_id: String = "jiggle_physics_subtle_zero_g"
@export var display_name: String = "Jiggle Physics Sutil — Busto & Glúteos"

# A. Control Maestro y Luz 2.5D (jiggle_global)
@export var master_intensity: float = 1.0
@export var normal_light_strength: float = 0.015
@export var preview_pulse_interval_sec: float = 1.15

# B. Física de Busto (jiggle_bust — s, se, sw, e, w)
@export var enable_bust_jiggle: bool = true
@export var bust_idle_amp_px: float = 1.35
@export var bust_freq_hz: float = 2.15
@export var bust_damping_ratio: float = 0.28
@export var bust_inertia_gain: float = 1.35
@export var bust_lr_asymmetry: float = 0.24
@export var bust_max_clamp_px: float = 7.50

# C. Física de Glúteos (jiggle_glute — n, ne, nw, e, w)
@export var enable_glute_jiggle: bool = true
@export var glute_idle_amp_px: float = 0.95
@export var glute_freq_hz: float = 2.85
@export var glute_damping_ratio: float = 0.36
@export var glute_inertia_gain: float = 1.25
@export var glute_thigh_coupling: float = 0.95
@export var glute_lr_asymmetry: float = 0.32
@export var glute_max_clamp_px: float = 6.20

# D. Multiplicadores por Familia (jiggle_fam)
@export var family_multipliers: Dictionary = {}


func _init() -> void:
	ensure_initialized()


## Construye multiplicadores por defecto para cada familia canónica.
static func build_default_family_multipliers() -> Dictionary:
	return {
		"s": {"bust_scale": 1.0, "glute_scale": 1.0},
		"se": {"bust_scale": 1.0, "glute_scale": 1.0},
		"e": {"bust_scale": 0.95, "glute_scale": 0.95},
		"ne": {"bust_scale": 1.0, "glute_scale": 1.0},
		"n": {"bust_scale": 1.0, "glute_scale": 1.0},
	}


## Garantiza que existan todas las familias y claves en family_multipliers.
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


## Restaura todos los parámetros de física secundaria a sus valores por defecto.
func reset_to_defaults() -> void:
	enable_bust_jiggle = true
	enable_glute_jiggle = true
	for k: String in FLOAT_DEFAULTS.keys():
		set(k, float(FLOAT_DEFAULTS[k]))
	family_multipliers = build_default_family_multipliers()


## Lee un parámetro numérico global por nombre.
func get_global_param(key: String) -> float:
	if key in self:
		return float(get(key))
	return 0.0


## Actualiza un parámetro numérico global por nombre.
func set_global_param(key: String, val: float) -> void:
	if key in self:
		set(key, val)


## Obtiene un multiplicador de familia (bust_scale o glute_scale).
func get_family_mul(fam: String, key: String) -> float:
	ensure_initialized()
	var can_fam: String = BasePoseConfigScript.canonical_family_for_view(fam)
	var d: Dictionary = family_multipliers.get(can_fam, {}) as Dictionary
	return float(d.get(key, 1.0))


## Fija un multiplicador de familia (bust_scale o glute_scale).
func set_family_mul(fam: String, key: String, val: float) -> void:
	ensure_initialized()
	var can_fam: String = BasePoseConfigScript.canonical_family_for_view(fam)
	var d: Dictionary = family_multipliers.get(can_fam, {}) as Dictionary
	d[key] = val
	family_multipliers[can_fam] = d
