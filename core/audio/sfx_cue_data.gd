class_name SfxCueData
extends Resource
## Definición Data-Driven de un evento SFX con variantes, layering, prioridad,
## atenuación por densidad, ducking y soporte de panning estéreo.

enum Priority {
	CROWD = 0,
	FEEDBACK = 1,
	HERO = 2,
	CRITICAL = 3,
}

@export var cue_id: StringName = &""
@export var bus_name: StringName = &"SFX_Combat"
@export var priority: Priority = Priority.FEEDBACK
@export var streams: Array[AudioStream] = []

@export_group("Layering (Capa 2)")
@export var secondary_layer_streams: Array[AudioStream] = []
@export var secondary_layer_delay_sec: float = 0.0
@export var secondary_layer_volume_db: float = -3.0
@export var secondary_layer_bus: StringName = &"SFX_Heroic"

@export_group("Modulación y Anti-Fatiga")
@export var base_volume_db: float = 0.0
@export var pitch_min: float = 0.94
@export var pitch_max: float = 1.06
@export var vol_jitter_db: float = 1.0
@export var min_interval_ms: int = 35
@export var max_polyphony: int = 4
@export var density_attenuation_db: float = 0.0
@export var use_exp_combo: bool = false

@export_group("Ducking y Espacialidad")
@export var duck_combat_db: float = 0.0
@export var duck_duration_sec: float = 0.25
@export var allow_panning: bool = false
@export var panning_strength: float = 0.35
