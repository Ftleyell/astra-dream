class_name BossData
extends Resource

## Recurso Data-Driven (Read-Only en runtime) para estadísticas base, umbrales de fase,
## escalado por oleada, recompensas y tiempos de ataque/cooldown de los Jefes en Astra Dream.
## Prohibido mutar este recurso en caliente; los scripts de jefe copian sus valores al inicializar.

@export_group("Identity & Health")
@export var boss_id: String = "boss_base"
@export var boss_name: String = "BOSS"
@export var max_health: float = 2400.0
@export var contact_damage: float = 25.0
@export var wave_scaling_hp_step: float = 0.0
@export var slayer_max_health: float = 4600.0
@export var herald_mirror_health: float = 1800.0
@export var herald_vortex_health: float = 2200.0
@export var herald_fallback_health: float = 1500.0

@export_group("Phase Transitions")
@export var phase_2_hp_threshold: float = 0.5
@export var phase_2_timeout_seconds: float = 70.0

@export_group("Rewards")
@export var credits_reward: int = 350
@export var exp_reward: float = 450.0
@export var dark_matter_reward: int = 0

@export_group("Locomotion & Positioning")
@export var move_speed_phase_1: float = 100.0
@export var move_speed_phase_2: float = 145.0
@export var desired_distance: float = 360.0
@export var dash_cooldown_min: float = 3.5
@export var dash_cooldown_max: float = 5.0
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.35

@export_group("Attack & Telegraph Timings")
@export var primary_attack_interval_p1: float = 3.0
@export var secondary_attack_interval_p1: float = 2.2
@export var spiral_interval_p1: float = 0.045
@export var primary_attack_interval_p2: float = 2.5
@export var secondary_attack_interval_p2: float = 2.0
@export var spiral_interval_p2: float = 0.038
@export var telegraph_duration_p1: float = 0.65
@export var telegraph_duration_p2: float = 0.60
