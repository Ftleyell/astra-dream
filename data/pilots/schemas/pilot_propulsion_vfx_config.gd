class_name PilotPropulsionVFXConfig
extends Resource
## Configuración data-driven para la propulsión Sandevistan Astral (Valentina v2).
## Fuente de verdad estética: docs/VALENTINA_PROPULSION_VFX_SPEC.md

@export_group("Nivel A — Propulsión Base (Vuelo Continuo)")
@export var base_spawn_distance_px: float = 28.0
@export var base_min_speed_px_s: float = 95.0
@export var base_max_ghosts: int = 5
@export var base_lifetime_sec: float = 0.30
@export var base_sequence_cap: float = 0.55

@export_group("Nivel B — Ráfaga Prolongada / Pico Cinético")
@export var burst_spawn_distance_px: float = 19.0
@export var burst_max_ghosts: int = 10
@export var burst_lifetime_sec: float = 0.48
@export var burst_duration_sec: float = 0.72
@export var burst_speed_mult: float = 1.75
@export var burst_world_time_scale: float = 0.22
@export var burst_hitstop_sec: float = 0.045

@export_group("Compresión en Giros y Evolución de Secuencia")
@export var turn_angle_compress_deg: float = 35.0
@export var turn_distance_compress_factor: float = 0.58
@export var color_step_per_ghost: float = 0.18
@export var sequence_charge_rate: float = 0.85
@export var sequence_burst_charge_rate: float = 2.40
@export var sequence_decay_rate: float = 1.35
@export var age_color_shift_amount: float = 0.0

@export_group("Silueta, Relleno y Outline (Calco de Animación)")
@export var outline_width_px: float = 2.6
@export var outline_min_width_px: float = 0.75
@export var outline_darken_amount: float = 0.38
@export var internal_ink_strength: float = 1.0
@export var fill_opacity_max: float = 0.62
@export var outline_opacity_max: float = 0.90
@export var rim_strength: float = 0.15
@export var rim_width_px: float = 1.8
@export var amethyst_emissive_boost: float = 1.22

@export_group("Curvas y Paleta Cromática")
@export var fill_alpha_curve: Curve = null
@export var outline_alpha_curve: Curve = null
@export var sequence_gradient: Gradient = null

@export_group("Acabado de Impacto (Aberración Cromática)")
@export var aberration_enabled: bool = true
@export var aberration_peak_px: float = 7.5
@export var aberration_decay_sec: float = 0.26


func ensure_defaults() -> void:
	if fill_alpha_curve == null:
		fill_alpha_curve = _build_default_fill_curve()
	if outline_alpha_curve == null:
		outline_alpha_curve = _build_default_outline_curve()
	if sequence_gradient == null:
		sequence_gradient = _build_default_gradient()


func sample_fill_alpha(age_t: float) -> float:
	ensure_defaults()
	var t: float = clampf(age_t, 0.0, 1.0)
	return clampf(fill_alpha_curve.sample_baked(t), 0.0, 1.0) * fill_opacity_max


func sample_outline_alpha(age_t: float) -> float:
	ensure_defaults()
	var t: float = clampf(age_t, 0.0, 1.0)
	return clampf(outline_alpha_curve.sample_baked(t), 0.0, 1.0) * outline_opacity_max


func sample_sequence_color(seq_t: float) -> Color:
	ensure_defaults()
	return sequence_gradient.sample(clampf(seq_t, 0.0, 1.0))


func compute_emissive_boost(seq_t: float) -> float:
	# Compensa menor luminancia percibida en el tramo Amatista/Magenta (0.55 - 0.88)
	var center: float = 0.72
	var half_w: float = 0.20
	var dist: float = absf(seq_t - center) / half_w
	var weight: float = clampf(1.0 - dist * dist, 0.0, 1.0)
	return lerpf(1.05, amethyst_emissive_boost, weight)


static func _build_default_fill_curve() -> Curve:
	# Relleno cae más rápido que el outline entre 30% y 70% de vida ("calco de animación")
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(0.28, 0.72))
	c.add_point(Vector2(0.62, 0.16))
	c.add_point(Vector2(1.0, 0.0))
	c.bake()
	return c


static func _build_default_outline_curve() -> Curve:
	# Outline se mantiene protagonista hasta 70% y luego se disuelve suavemente
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(0.30, 0.96))
	c.add_point(Vector2(0.70, 0.74))
	c.add_point(Vector2(1.0, 0.0))
	c.bake()
	return c


static func _build_default_gradient() -> Gradient:
	# Rampa canónica: Turquesa -> Bordó -> Amatista
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.52, 0.78, 1.0])
	g.colors = PackedColorArray([
		Color("#18E0D4"),
		Color("#24A8B8"),
		Color("#9E1F47"),
		Color("#9F3DFF"),
		Color("#C67BFF"),
	])
	return g
