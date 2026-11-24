class_name PilotRigProfile
extends Resource
## Perfil maestro de un piloto para PlanarCombatRig y el Pilot Rig Lab.
## Centraliza rutas de assets, configuración de animación, outline y presets.

@export var pilot_id: String = "valentina_v2"
@export var display_name: String = "Valentina v2 (8-Dir)"
@export var assets_root: String = "res://assets/pilots/valentina_v2/planar"
@export var anim_config: Resource = null
@export var display_scale: float = 0.378
@export var default_accent_color: Color = Color(0.86, 0.18, 0.32, 1.0)
@export var head_outline_strength: float = 1.0
@export var head_outline_width_px: float = 4.0
@export var stepped_fps: float = 15.0

@export_group("Animaciones del Rig (.tres)")
@export var base_pose_config: Resource = null
@export var idle_anim_config: Resource = null
@export var locomotion_anim_config: Resource = null
@export var kiting_anim_config: Resource = null
@export var turn_anim_config: Resource = null
@export var jiggle_physics_config: Resource = null
@export var face_anim_config: Resource = null
@export var base_propulsion_config: Resource = null
@export var wings_assets_subdir: String = "wings"
@export var wings_3d_config: Resource = null
@export var prefer_3d_wings: bool = true
@export var combat_rig_config: Resource = null
@export var dialogue_portraits_config: Resource = null

@export_group("Presets Asociados")
@export var skins: Array[PilotSkinPreset] = []
@export var hair_presets: Array[PilotHairPreset] = []
@export var style_profiles: Array[RigStyleProfile] = []
