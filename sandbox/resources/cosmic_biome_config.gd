class_name CosmicBiomeConfig
extends Resource

## Configuración data-driven para biomas espaciales del Cosmos Engine.

@export_group("Identificación")
@export var biome_id: StringName = &"void_default"
@export var display_name: String = "Vacío Interestelar"

@export_group("Paleta de Color")
@export var color_deep_space: Color = Color(0.01, 0.01, 0.03, 1.0)
@export var color_gas_primary: Color = Color(0.18, 0.04, 0.28, 0.8)
@export var color_gas_secondary: Color = Color(0.02, 0.22, 0.38, 0.6)
@export var color_star_tint: Color = Color(0.85, 0.92, 1.0, 1.0)

@export_group("Parámetros de Ruido FBM")
@export_range(0.00001, 0.005, 0.00001) var noise_frequency: float = 0.0008
@export_range(1, 6, 1) var noise_octaves: int = 4
@export_range(0.1, 3.0, 0.05) var gas_density: float = 2.0
@export_range(0.5, 4.0, 0.1) var gas_contrast: float = 1.8

@export_group("Óptica")
@export_range(0.0, 0.02, 0.0005) var chromatic_aberration_strength: float = 0.003
@export_range(0.0, 2.0, 0.05) var starfield_energy: float = 1.0
