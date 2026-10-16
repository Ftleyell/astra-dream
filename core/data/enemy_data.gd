class_name EnemyData
extends Resource

## Recurso Data-Driven (Read-Only en runtime) para estadísticas base y parámetros
## específicos de cada arquetipo de enemigo en Astra Dream.
## Prohibido mutar este recurso en caliente; EnemyBase y subclases copian sus valores
## al inicializar y al reciclarse en el pool (_reset_pool_state).

@export_group("Identity & Base Stats")
@export var enemy_id: StringName = &"enemy_base"
@export var max_health: float = 30.0
@export var move_speed: float = 160.0
@export var contact_damage: float = 10.0
@export var exp_reward: float = 15.0
@export var credits_reward: int = 1
@export var contact_radius: float = 24.0
@export var contact_interval: float = 0.6
@export var lifetime: float = 25.0

@export_group("Shooter & Ranged Parameters")
@export var shoot_interval: float = 3.6
@export var charge_duration: float = 0.35
@export var preferred_distance: float = 450.0
@export var distance_tolerance: float = 50.0

@export_group("Kamikaze & Dive Parameters")
@export var dive_distance: float = 260.0
@export var dive_speed: float = 360.0

@export_group("Champion & Telegraph Parameters")
@export var attack_interval: float = 4.0
@export var telegraph_duration: float = 1.2
@export var charge_speed: float = 1200.0
@export var max_charge_distance: float = 2400.0

@export_group("Splitter & Mitosis Parameters")
@export var fusion_countdown: float = 5.0
@export var split_count: int = 2

@export_group("Anomaly / Loot Goblin Parameters")
@export var escape_duration: float = 45.0
@export var panic_boost: float = 60.0
