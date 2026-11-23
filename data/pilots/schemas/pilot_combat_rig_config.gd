class_name PilotCombatRigConfig
extends Resource
## Configuración data-driven para el montaje de Valentina v2 en combate in-game.
## Parametriza escala compensada, referencias orbitales/VFX, sobre-enfoque y reacciones.

@export_group("Escala y Recursos Base")
@export var combat_rig_scale: float = 0.90
@export var default_style_path: String = "res://data/pilots/styles/02_valentina_razor_sharp.tres"
@export var orbital_weapon_config: PilotOrbitalWeaponConfig = null
@export var propulsion_vfx_config: PilotPropulsionVFXConfig = null
@export var ring_texture_path: String = "res://assets/pilots/valentina_v2/planar/weapons/valentina_mecha_ring_packed.png"
@export var rig_z_offset: int = 5
@export var sandevistan_abs_z_index: int = 2

@export_group("Twin-Stick, Puntería y Aura Cósmica")
@export var turbo_speed_ratio_thresh: float = 0.92
@export var aim_min_dist_sq: float = 16.0
@export var muzzle_reaim_min_dist: float = 48.0
@export var aura_radius_px: float = 225.0
@export var aura_base_energy: float = 0.96
@export var aura_overfocus_bonus: float = 0.58
@export var aura_fire_pulse_bonus: float = 0.44
@export var aura_fire_decay_rate: float = 3.8
@export var aura_offset_px: Vector2 = Vector2(0.0, -20.0)

@export_group("Sobre-Enfoque (Bullet-Time)")
@export var overfocus_impact_ms: float = 42.0
@export var overfocus_impact_shake_px: float = 5.0
@export var overfocus_eye_monocle_boost: float = 1.25
@export var overfocus_aberration_layer: int = 2

@export_group("Reacciones de Combate")
@export var hit_impact_ms: float = 48.0
@export var hit_impact_shake_px: float = 5.5
@export var osp_impact_ms: float = 78.0
@export var osp_impact_shake_px: float = 8.5
@export var bomb_impact_ms: float = 65.0
@export var bomb_impact_shake_px: float = 7.0
@export var shield_absorb_wings_sec: float = 0.45
@export var bomb_wings_bloom_sec: float = 0.70
@export var active_fire_recoil_strength: float = 0.85
@export var passive_fire_recoil_strength: float = 0.35
