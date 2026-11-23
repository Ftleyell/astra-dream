class_name CosmosLivingUniverseConfig
extends Resource

## Perfil data-driven para sectores espaciales no estelares del Cosmos Engine (v3.2+).
## Controla pesos de arquetipos, pooling, escalas, colores y conteos de elementos
## para las parcelas sin estrella (~35% del macro-grid).

@export_group("Streaming y Pesos del Macro-Grid")
@export_range(0.0, 1.0, 0.01) var weight_rogue_world: float = 0.30:
	set(v):
		weight_rogue_world = v
		emit_changed()

@export_range(0.0, 1.0, 0.01) var weight_derelict_armada: float = 0.25:
	set(v):
		weight_derelict_armada = v
		emit_changed()

@export_range(0.0, 1.0, 0.01) var weight_warp_relay: float = 0.25:
	set(v):
		weight_warp_relay = v
		emit_changed()

@export_range(0.0, 1.0, 0.01) var weight_ion_nursery: float = 0.20:
	set(v):
		weight_ion_nursery = v
		emit_changed()

@export_range(4, 16, 1) var sector_pool_size: int = 8:
	set(v):
		sector_pool_size = v
		emit_changed()

@export var sector_bound_radius: float = 4200.0:
	set(v):
		sector_bound_radius = v
		emit_changed()

@export var sector_jitter_margin: float = 2800.0:
	set(v):
		sector_jitter_margin = v
		emit_changed()

@export_group("1. Planeta Errante (Rogue World)")
@export_range(0.6, 2.2, 0.02) var rogue_diameter_multiplier: float = 1.18:
	set(v):
		rogue_diameter_multiplier = v
		emit_changed()

@export_range(0.05, 0.50, 0.01) var rogue_night_ambient: float = 0.14:
	set(v):
		rogue_night_ambient = v
		emit_changed()

@export_range(0.10, 1.50, 0.02) var rogue_day_exposure: float = 0.42:
	set(v):
		rogue_day_exposure = v
		emit_changed()

@export_range(0.5, 3.0, 0.05) var rogue_emissive_boost: float = 1.65:
	set(v):
		rogue_emissive_boost = v
		emit_changed()

@export_range(0.0, 0.85, 0.01) var rogue_biome_tint_intensity: float = 0.34:
	set(v):
		rogue_biome_tint_intensity = v
		emit_changed()

@export var rogue_moon_count_range: Vector2i = Vector2i(1, 2):
	set(v):
		rogue_moon_count_range = v
		emit_changed()

@export_range(0.08, 0.40, 0.01) var rogue_moon_size_ratio: float = 0.20:
	set(v):
		rogue_moon_size_ratio = v
		emit_changed()

@export_range(0.0, 1.0, 0.05) var rogue_ring_probability: float = 0.65:
	set(v):
		rogue_ring_probability = v
		emit_changed()

@export_group("2. Cementerio de Flotas (Derelict Armada)")
@export var derelict_core_diameter: float = 440.0:
	set(v):
		derelict_core_diameter = v
		emit_changed()

@export_range(8, 120, 1) var derelict_scrap_count: int = 44:
	set(v):
		derelict_scrap_count = v
		emit_changed()

@export var derelict_vortex_radius_range: Vector2 = Vector2(310.0, 1450.0):
	set(v):
		derelict_vortex_radius_range = v
		emit_changed()

@export var derelict_vortex_angular_speed: float = 0.032:
	set(v):
		derelict_vortex_angular_speed = v
		emit_changed()

@export var derelict_beacon_drone_count: Vector2i = Vector2i(2, 3):
	set(v):
		derelict_beacon_drone_count = v
		emit_changed()

@export var derelict_plasma_arc_radius: float = 740.0:
	set(v):
		derelict_plasma_arc_radius = v
		emit_changed()

@export var derelict_distress_color: Color = Color(1.0, 0.24, 0.18, 1.0):
	set(v):
		derelict_distress_color = v
		emit_changed()

@export var derelict_plasma_color: Color = Color(0.28, 0.78, 1.0, 1.0):
	set(v):
		derelict_plasma_color = v
		emit_changed()

@export_group("3. Puerta de Salto / Relé (Warp Relay)")
@export var relay_core_diameter: float = 420.0:
	set(v):
		relay_core_diameter = v
		emit_changed()

@export var relay_gate_aura_radius: float = 1150.0:
	set(v):
		relay_gate_aura_radius = v
		emit_changed()

@export var relay_escort_count: Vector2i = Vector2i(2, 3):
	set(v):
		relay_escort_count = v
		emit_changed()

@export var relay_escort_orbit_range: Vector2 = Vector2(320.0, 620.0):
	set(v):
		relay_escort_orbit_range = v
		emit_changed()

@export var relay_primary_color: Color = Color(0.22, 0.88, 1.0, 1.0):
	set(v):
		relay_primary_color = v
		emit_changed()

@export var relay_accent_color: Color = Color(0.74, 0.42, 1.0, 1.0):
	set(v):
		relay_accent_color = v
		emit_changed()

@export_group("4. Tormenta Iónica / Vivero Protoestelar (Ion Nursery)")
@export var nursery_cloud_radius: float = 1650.0:
	set(v):
		nursery_cloud_radius = v
		emit_changed()

@export var nursery_protostar_count: Vector2i = Vector2i(2, 3):
	set(v):
		nursery_protostar_count = v
		emit_changed()

@export_range(6, 96, 1) var nursery_crystal_count: int = 34:
	set(v):
		nursery_crystal_count = v
		emit_changed()

@export var nursery_crystal_radius_range: Vector2 = Vector2(260.0, 1280.0):
	set(v):
		nursery_crystal_radius_range = v
		emit_changed()

@export_range(0.0, 2.5, 0.05) var nursery_lightning_intensity: float = 1.05:
	set(v):
		nursery_lightning_intensity = v
		emit_changed()

@export var nursery_primary_color: Color = Color(0.26, 0.72, 1.0, 1.0):
	set(v):
		nursery_primary_color = v
		emit_changed()

@export var nursery_protostar_color: Color = Color(1.0, 0.76, 0.42, 1.0):
	set(v):
		nursery_protostar_color = v
		emit_changed()

@export var nursery_arc_color: Color = Color(0.68, 0.92, 1.0, 1.0):
	set(v):
		nursery_arc_color = v
		emit_changed()

@export_group("5. Corredores Interestelares (v3.2c)")
@export var enable_interstellar_corridors: bool = true:
	set(v):
		enable_interstellar_corridors = v
		emit_changed()

@export_range(1.0, 2.5, 0.05) var corridor_max_link_distance_mult: float = 1.55:
	set(v):
		corridor_max_link_distance_mult = v
		emit_changed()

@export_range(0.0, 1.0, 0.05) var hyperspace_lane_probability: float = 0.75:
	set(v):
		hyperspace_lane_probability = v
		emit_changed()

@export_range(2, 28, 1) var hyperspace_beacons_per_lane: int = 16:
	set(v):
		hyperspace_beacons_per_lane = v
		emit_changed()

@export_range(0.0, 0.5, 0.01) var hyperspace_slipstream_alpha: float = 0.04:
	set(v):
		hyperspace_slipstream_alpha = v
		emit_changed()

@export_range(0, 12, 1) var hyperspace_convoys_per_lane: int = 4:
	set(v):
		hyperspace_convoys_per_lane = v
		emit_changed()

@export var hyperspace_convoy_speed: float = 280.0:
	set(v):
		hyperspace_convoy_speed = v
		emit_changed()

@export var hyperspace_lane_color: Color = Color(0.28, 0.86, 1.0, 1.0):
	set(v):
		hyperspace_lane_color = v
		emit_changed()

@export var hyperspace_convoy_color: Color = Color(1.0, 0.84, 0.52, 1.0):
	set(v):
		hyperspace_convoy_color = v
		emit_changed()

@export_range(0, 24, 1) var meteor_shower_count_per_cell: int = 8:
	set(v):
		meteor_shower_count_per_cell = v
		emit_changed()

@export_range(0.0, 1.0, 0.05) var interstellar_comet_probability: float = 0.65:
	set(v):
		interstellar_comet_probability = v
		emit_changed()

@export_range(0.8, 2.0, 0.05) var bow_shock_max_distance_mult: float = 1.28:
	set(v):
		bow_shock_max_distance_mult = v
		emit_changed()

@export_range(0.0, 1.5, 0.05) var bow_shock_intensity: float = 0.58:
	set(v):
		bow_shock_intensity = v
		emit_changed()

## Selecciona deterministamente uno de los 4 arquetipos no estelares (0..3) para una semilla dada.
func pick_sector_archetype(sector_seed: int) -> int:
	var w0: float = maxf(weight_rogue_world, 0.0)
	var w1: float = maxf(weight_derelict_armada, 0.0)
	var w2: float = maxf(weight_warp_relay, 0.0)
	var w3: float = maxf(weight_ion_nursery, 0.0)
	var total: float = w0 + w1 + w2 + w3
	if total <= 0.0001:
		return 0
	var roll: float = CosmosHasher.hash_2d_float(sector_seed, 3101, 47) * total
	if roll < w0:
		return 0
	roll -= w0
	if roll < w1:
		return 1
	roll -= w1
	if roll < w2:
		return 2
	return 3
