class_name VoiceProfileData
extends Resource

## Perfil de voz data-driven para mumble speech (enfoque híbrido).
## Si `samples` está vacío, MumbleSpeechController sintetiza micro-sílabas
## procedurales en memoria usando `formant_hz` y `syllable_duration_sec`.

@export var profile_id: StringName = &"default"
@export var display_name: String = "Piloto"

@export_group("Audio & Timbre")
## Pool opcional de 3-6 micro-samples (40-90 ms). Si está vacío usa síntesis de formantes.
@export var samples: Array[AudioStream] = []
@export_range(0.5, 2.2, 0.01) var base_pitch: float = 1.0
@export_range(0.0, 0.35, 0.005) var pitch_variance: float = 0.08
@export_range(160.0, 1200.0, 5.0) var formant_hz: float = 420.0
@export_range(0.03, 0.14, 0.005) var syllable_duration_sec: float = 0.065
@export_range(-24.0, 6.0, 0.5) var volume_db: float = -4.0
@export_range(0.0, 4.0, 0.1) var volume_jitter_db: float = 1.0

@export_group("Cadencia & Entonación")
@export_range(1, 5, 1) var chars_per_blip: int = 2
@export_range(20, 150, 5) var min_interval_ms: int = 50
@export_range(0.0, 0.45, 0.01) var question_pitch_boost: float = 0.18
@export_range(0.0, 6.0, 0.25) var exclamation_vol_db: float = 2.0

@export_group("Efectos")
@export var radio_filter_enabled: bool = false
