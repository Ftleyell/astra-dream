class_name CosmosDeepSpaceSector2D
extends Node2D

## Sector espacial no estelar determinista para el ~35% de parcelas sin sol (Cosmos Engine v3.2).
## Implementa 4 arquetipos diferenciados, evaluación orbital 3D zero-allocation en tiempo analítico,
## armonía cromática reactiva con el bioma y guías orbitales opcionales [O].

enum SectorArchetype {
	ROGUE_WORLD = 0,
	DERELICT_ARMADA = 1,
	WARP_RELAY = 2,
	ION_NURSERY = 3
}

const ATLAS_SIZE: Vector2 = Vector2(2048.0, 2048.0)

const CELESTIAL_BODY_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/celestial_body.gdshader")
const PLANETARY_RING_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/planetary_ring.gdshader")
const STATION_BEACON_SHADER: Shader = preload("res://scenes/combat/environment/space_station_beacon.gdshader")
const DEBRIS_CUTOUT_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/debris_cutout.gdshader")
const WARP_GATE_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/warp_gate_ring.gdshader")
const DERELICT_PLASMA_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/derelict_plasma_arcs.gdshader")
const ION_NURSERY_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/ion_storm_nursery.gdshader")

const STATION_CITADEL_TEX: Texture2D = preload("res://assets/environments/cosmos_v2/stations/station_ring_citadel.png")
const STATION_RELAY_TEX: Texture2D = preload("res://assets/environments/cosmos_v2/stations/station_spire_relay.png")
const STATION_SHIPYARD_TEX: Texture2D = preload("res://assets/environments/cosmos_v2/stations/station_shipyard_dock.png")
const DEBRIS_ROCK_TEX: Texture2D = preload("res://assets/environments/cosmos_v2/debris/debris_asteroids_v2.png")
const DEBRIS_SCRAP_TEX: Texture2D = preload("res://assets/environments/cosmos_v2/debris/debris_mecha_ruins_v2.png")


class _SectorOrbitGuidesDrawer extends Node2D:
	var _sector: CosmosDeepSpaceSector2D = null
	var _pts_40: PackedVector2Array = PackedVector2Array()
	var _cols_40: PackedColorArray = PackedColorArray()

	func _init() -> void:
		name = "SectorOrbitGuidesDrawer"
		visible = false
		z_index = 1
		_pts_40.resize(41)
		_cols_40.resize(41)

	func setup(p_sector: CosmosDeepSpaceSector2D) -> void:
		_sector = p_sector
		if visible:
			queue_redraw()

	func _draw() -> void:
		if not visible or _sector == null or not is_instance_valid(_sector):
			return
		var inv_zoom: float = 1.0
		if is_inside_tree() and get_viewport() != null:
			var cam: Camera2D = get_viewport().get_camera_2d()
			if cam != null and cam.zoom.x > 0.001:
				inv_zoom = clampf(1.0 / cam.zoom.x, 0.75, 5.5)

		var w_major: float = 1.8 * inv_zoom
		var w_minor: float = 1.45 * inv_zoom
		var w_env: float = 1.15 * inv_zoom

		if _sector.guide_outer_radius > 1.0:
			draw_arc(Vector2.ZERO, _sector.guide_outer_radius, 0.0, TAU, 64, _sector.guide_ring_color, w_major)
		if _sector.guide_core_radius > 1.0:
			draw_arc(Vector2.ZERO, _sector.guide_core_radius, 0.0, TAU, 48, Color(0.35, 0.85, 0.78, 0.34), w_env)

		for orb: CosmosOrbitalBody2D in _sector.orbiting_bodies:
			if not is_instance_valid(orb) or orb.orbit_radius <= 1.0:
				continue
			CosmosOrbitGuidesOverlay2D.draw_ellipse_3d_on(
				self,
				Vector2.ZERO,
				Vector2.ONE,
				orb.orbit_radius,
				orb.orbit_eccentricity,
				orb.orbit_periapsis_angle,
				orb.orbit_plane_tilt,
				orb.orbit_plane_squash,
				_sector.guide_orbit_front_color,
				_sector.guide_orbit_back_color,
				w_minor,
				40,
				_pts_40,
				_cols_40,
				true,
				inv_zoom
			)


static var _quad_tex: ImageTexture = null
static var _unit_quad_mesh: QuadMesh = null
static var _cached_atlas_rects: Dictionary = {}

@export var system_profile: CosmosCelestialSystemProfile
@export var living_config: CosmosLivingUniverseConfig
@export var debris_profile: CosmosDebrisLayerProfile

var archetype: int = SectorArchetype.ROGUE_WORLD
var sector_name: String = ""
var sector_seed: int = 0
var sector_cell: Vector2i = Vector2i.ZERO
var bounding_radius: float = 1600.0
var guide_outer_radius: float = 900.0
var guide_core_radius: float = 200.0
var guide_ring_color: Color = Color(0.6, 0.85, 1.0, 0.45)
var guide_orbit_front_color: Color = Color(0.24, 0.96, 1.0, 0.76)
var guide_orbit_back_color: Color = Color(0.18, 0.56, 0.82, 0.24)

var orbiting_bodies: Array[CosmosOrbitalBody2D] = []
var orbital_trails: Array[CosmosOrbitalTrail2D] = []

var _host_body: CosmosOrbitalBody2D = null
var _global_time_mats: Array[ShaderMaterial] = []
var _override_time_mats: Array[ShaderMaterial] = []
var _biome_tinted_mats: Array[ShaderMaterial] = []
var _debris_mats: Array[ShaderMaterial] = []
var _quality_mats: Array[ShaderMaterial] = []
var _rotating_nodes: Array[Node2D] = []
var _rotating_speeds: PackedFloat32Array = PackedFloat32Array()
var _rotating_phases: PackedFloat32Array = PackedFloat32Array()

var _guides_drawer: _SectorOrbitGuidesDrawer = null
var _orbit_guides_visible: bool = false
var _graphics_quality: int = 2
var _biome_primary: Color = Color(0.28, 0.06, 0.52, 1.0)
var _biome_secondary: Color = Color(0.03, 0.38, 0.62, 1.0)
var _last_global_time: float = 0.0
var _is_built: bool = false


static func _get_quad_tex() -> ImageTexture:
	if _quad_tex == null:
		var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_quad_tex = ImageTexture.create_from_image(img)
	return _quad_tex


static func _get_unit_quad_mesh() -> QuadMesh:
	if _unit_quad_mesh == null:
		_unit_quad_mesh = QuadMesh.new()
		_unit_quad_mesh.size = Vector2.ONE
	return _unit_quad_mesh


static func _get_atlas_entries(meta_path: String) -> Dictionary:
	if _cached_atlas_rects.has(meta_path):
		return _cached_atlas_rects[meta_path] as Dictionary

	var rocks: Array[Dictionary] = []
	var scrap: Array[Dictionary] = []
	if FileAccess.file_exists(meta_path):
		var file: FileAccess = FileAccess.open(meta_path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Array:
				for entry_var: Variant in parsed:
					if entry_var is Dictionary:
						var d: Dictionary = entry_var as Dictionary
						var rect_arr: Array = d.get("rect", [])
						if rect_arr.size() >= 4:
							var rx: float = float(rect_arr[0])
							var ry: float = float(rect_arr[1])
							var rw: float = float(rect_arr[2])
							var rh: float = float(rect_arr[3])
							var item: Dictionary = {
								"uv_rect": Rect2(rx / ATLAS_SIZE.x, ry / ATLAS_SIZE.y, rw / ATLAS_SIZE.x, rh / ATLAS_SIZE.y),
								"pixel_size": Vector2(rw, rh),
							}
							if str(d.get("prefix", "")) == "debris_0":
								rocks.append(item)
							else:
								scrap.append(item)

	var fallback: Dictionary = {"uv_rect": Rect2(0.0, 0.0, 0.25, 0.25), "pixel_size": Vector2(180.0, 180.0)}
	if rocks.is_empty():
		rocks.append(fallback)
	if scrap.is_empty():
		scrap.append(fallback)

	var bundle: Dictionary = {"rock": rocks, "scrap": scrap}
	_cached_atlas_rects[meta_path] = bundle
	return bundle


func _clear_sector() -> void:
	for child: Node in get_children():
		if child == _guides_drawer:
			continue
		remove_child(child)
		child.queue_free()

	orbiting_bodies.clear()
	orbital_trails.clear()
	_host_body = null
	_global_time_mats.clear()
	_override_time_mats.clear()
	_biome_tinted_mats.clear()
	_debris_mats.clear()
	_quality_mats.clear()
	_rotating_nodes.clear()
	_rotating_speeds.clear()
	_rotating_phases.clear()
	_is_built = false


## Construye deterministamente uno de los 4 arquetipos de sector no estelar para (p_seed, p_cell).
func build_sector(
	p_seed: int,
	p_cell: Vector2i,
	p_archetype_override: int = -1,
	p_neighbor_solar_angles: PackedFloat32Array = PackedFloat32Array()
) -> void:
	_clear_sector()
	sector_seed = p_seed
	sector_cell = p_cell

	var cfg: CosmosLivingUniverseConfig = living_config if living_config != null else CosmosLivingUniverseConfig.new()
	if p_archetype_override >= 0 and p_archetype_override <= 3:
		archetype = p_archetype_override
	else:
		archetype = cfg.pick_sector_archetype(p_seed)

	var id_num: int = absi(p_seed) % 900 + 100
	match archetype:
		SectorArchetype.ROGUE_WORLD:
			sector_name = "ERRANTE_%d" % id_num
			_build_rogue_world(cfg)
		SectorArchetype.DERELICT_ARMADA:
			sector_name = "PECIO_%d" % id_num
			_build_derelict_armada(cfg)
		SectorArchetype.WARP_RELAY:
			sector_name = "RELE_%d" % id_num
			_build_warp_relay(cfg, p_neighbor_solar_angles)
		_:
			sector_name = "VIVERO_ION_%d" % id_num
			_build_ion_nursery(cfg)

	if _guides_drawer == null:
		_guides_drawer = _SectorOrbitGuidesDrawer.new()
		add_child(_guides_drawer)
	_guides_drawer.setup(self)
	_guides_drawer.visible = _orbit_guides_visible

	_is_built = true
	apply_biome_harmony(_biome_primary, _biome_secondary)
	apply_graphics_quality(_graphics_quality)
	update_sector_state(_last_global_time)


func get_archetype_label() -> String:
	match archetype:
		SectorArchetype.ROGUE_WORLD:
			return "Planeta Errante"
		SectorArchetype.DERELICT_ARMADA:
			return "Cementerio de Flotas"
		SectorArchetype.WARP_RELAY:
			return "Puerta de Salto"
		SectorArchetype.ION_NURSERY:
			return "Tormenta Iónica"
	return "Sector Profundo"


func _pick_rogue_planet_archetype(p_cfg: CosmosPlanetarySystemConfig) -> CosmosPlanetArchetype:
	var candidates: Array[CosmosPlanetArchetype] = []
	for arch: CosmosPlanetArchetype in p_cfg.planet_archetypes:
		if arch == null:
			continue
		var aid: String = String(arch.archetype_id).to_lower()
		if aid.contains("shattered") or aid.contains("cryo") or aid.contains("relic") or aid.contains("dyson") or aid.contains("cyber") or aid.contains("volcanic"):
			candidates.append(arch)
	if candidates.is_empty():
		candidates = p_cfg.planet_archetypes
	if candidates.is_empty():
		return null
	var idx: int = int(CosmosHasher.hash_2d_float(sector_seed, 3201, 13) * float(candidates.size()))
	idx = clampi(idx, 0, candidates.size() - 1)
	return candidates[idx]


func _build_rogue_world(cfg: CosmosLivingUniverseConfig) -> void:
	guide_ring_color = Color(0.56, 0.68, 1.0, 0.42)
	guide_orbit_front_color = Color(0.84, 0.66, 1.0, 0.78)
	guide_orbit_back_color = Color(0.54, 0.38, 0.85, 0.24)

	var p_cfg: CosmosPlanetarySystemConfig = system_profile.get_effective_planetary_config() if system_profile != null else null
	var host := CosmosOrbitalBody2D.new()
	host.name = "RoguePlanetHost"
	host.body_name = StringName(sector_name)
	host.show_orbit_lines = false
	host.z_index = 0
	add_child(host)
	_host_body = host

	var planet_radius: float = 165.0
	var ring_outer: float = 0.0
	var biome_tint: Color = _biome_primary.lerp(_biome_secondary, 0.45)

	if p_cfg != null and not p_cfg.planet_archetypes.is_empty():
		var arch: CosmosPlanetArchetype = _pick_rogue_planet_archetype(p_cfg)
		if arch != null:
			var light_ang: float = CosmosHasher.hash_2d_float(sector_seed, 3211, 21) * TAU
			var lighting_ctx: Dictionary = {
				"night_ambient": cfg.rogue_night_ambient,
				"day_exposure": cfg.rogue_day_exposure,
				"star_color": Color(0.56, 0.74, 1.0, 1.0),
				"day_tint_strength": 0.28,
				"atmo_tint_strength": 0.36,
				"dist_tint_attenuation": 0.75,
				"biome_tint_color": biome_tint,
				"biome_tint_intensity": cfg.rogue_biome_tint_intensity,
			}
			var vis_info: Dictionary = CosmosPlanetVisualBuilder.configure_planet_visual(
				host,
				arch,
				sector_seed ^ 0x19B1,
				p_cfg.planet_size_multiplier * cfg.rogue_diameter_multiplier,
				_get_quad_tex(),
				CELESTIAL_BODY_SHADER,
				PLANETARY_RING_SHADER,
				lighting_ctx
			)
			planet_radius = float(vis_info.get("visual_radius", 165.0))
			ring_outer = float(vis_info.get("ring_outer_radius_px", 0.0))

			var p_spr: Sprite2D = host.get_sprite()
			if p_spr != null and p_spr.material is ShaderMaterial:
				var p_mat: ShaderMaterial = p_spr.material as ShaderMaterial
				p_mat.set_shader_parameter("light_direction", Vector2(cos(light_ang), sin(light_ang)))
				p_mat.set_shader_parameter("light_depth", 0.46)
				p_mat.set_shader_parameter("night_emissive_strength", maxf(arch.night_emissive_strength, 0.42) * cfg.rogue_emissive_boost)
				p_mat.set_shader_parameter("atmosphere_intensity", maxf(arch.atmosphere_intensity, 0.35) * 1.25)
				_override_time_mats.append(p_mat)
				_biome_tinted_mats.append(p_mat)
			if host.has_meta(&"ring_materials"):
				var ring_mats_var: Variant = host.get_meta(&"ring_materials")
				if ring_mats_var is Array:
					for rm_v: Variant in ring_mats_var as Array:
						if rm_v is ShaderMaterial:
							var rm: ShaderMaterial = rm_v as ShaderMaterial
							rm.set_shader_parameter("light_direction", Vector2(cos(light_ang), sin(light_ang)))
							rm.set_shader_parameter("light_depth", 0.46)
							_biome_tinted_mats.append(rm)

	guide_core_radius = maxf(planet_radius, ring_outer)
	var min_moons: int = mini(cfg.rogue_moon_count_range.x, cfg.rogue_moon_count_range.y)
	var max_moons: int = maxi(cfg.rogue_moon_count_range.x, cfg.rogue_moon_count_range.y)
	var moon_span: int = max_moons - min_moons + 1
	var moon_count: int = min_moons + (int(CosmosHasher.hash_2d_float(sector_seed, 3232, 31) * float(moon_span)) % maxi(moon_span, 1))

	var base_sat_r: float = maxf(planet_radius * 2.1, ring_outer + 95.0)
	var base_vel: float = system_profile.base_angular_velocity if system_profile != null else 0.02
	var max_orbit: float = base_sat_r

	for m_idx: int in range(moon_count):
		var m_seed: int = sector_seed + 4100 + m_idx * 97
		var orbit_r: float = base_sat_r + float(m_idx) * 145.0 + CosmosHasher.hash_2d_float(m_seed, 11, 7) * 55.0
		max_orbit = maxf(max_orbit, orbit_r)
		var dir_sign: float = 1.0 if CosmosHasher.hash_2d_float(m_seed, 13, 9) > 0.4 else -1.0
		var ang_vel: float = (base_vel * (3.2 - float(m_idx) * 0.65)) * dir_sign
		var init_theta: float = CosmosHasher.hash_2d_float(m_seed, 17, 5) * TAU
		var ecc: float = lerpf(0.05, 0.16, CosmosHasher.hash_2d_float(m_seed, 19, 3))
		var peri: float = CosmosHasher.hash_2d_float(m_seed, 23, 2) * TAU
		var tilt: float = deg_to_rad(lerpf(-65.0, 65.0, CosmosHasher.hash_2d_float(m_seed, 29, 8)))
		var squash: float = lerpf(0.28, 0.56, CosmosHasher.hash_2d_float(m_seed, 31, 4))

		var moon := CosmosOrbitalBody2D.new()
		moon.name = "RogueMoon_%d" % (m_idx + 1)
		moon.orbit_radius = orbit_r
		moon.angular_velocity = ang_vel
		moon.initial_theta = init_theta
		moon.orbit_eccentricity = ecc
		moon.orbit_periapsis_angle = peri
		moon.orbit_plane_tilt = tilt
		moon.orbit_plane_squash = squash
		moon.depth_scale_amplitude = 0.18
		moon.enable_depth_z_swap = true
		moon.show_orbit_lines = false
		host.add_child(moon)

		if p_cfg != null and not p_cfg.moon_archetypes.is_empty():
			var m_arch: CosmosPlanetArchetype = p_cfg.moon_archetypes[(m_idx + int(CosmosHasher.hash_2d_float(m_seed, 41, 6) * 3.0)) % p_cfg.moon_archetypes.size()]
			var m_diam: float = (planet_radius * 2.0) * cfg.rogue_moon_size_ratio * lerpf(0.85, 1.15, CosmosHasher.hash_2d_float(m_seed, 43, 9))
			var moon_ctx: Dictionary = {
				"night_ambient": maxf(cfg.rogue_night_ambient, 0.24),
				"day_exposure": maxf(cfg.rogue_day_exposure, 0.82),
				"star_color": Color(0.62, 0.82, 1.0, 1.0),
				"day_tint_strength": 0.34,
				"biome_tint_color": biome_tint,
				"biome_tint_intensity": cfg.rogue_biome_tint_intensity * 1.15,
			}
			CosmosPlanetVisualBuilder.configure_moon_visual(moon, m_arch, m_seed, m_diam, _get_quad_tex(), CELESTIAL_BODY_SHADER, moon_ctx)
			var m_spr: Sprite2D = moon.get_sprite()
			if m_spr != null and m_spr.material is ShaderMaterial:
				var m_mat: ShaderMaterial = m_spr.material as ShaderMaterial
				m_mat.set_shader_parameter("light_direction", Vector2(0.7, -0.7).normalized())
				_override_time_mats.append(m_mat)
				_biome_tinted_mats.append(m_mat)

		orbiting_bodies.append(moon)
		_attach_trail_to_body(moon, 1.45, 3.2, Color(0.74, 0.72, 1.0, 0.54), Color(0.36, 0.48, 0.94, 0.0))

	# Periferia exterior de fragmentos helados/rocosos para lectura temprana a vista 1x
	var r_meta_path: String = debris_profile.metadata_json_path if debris_profile != null and not debris_profile.metadata_json_path.is_empty() else "res://assets/environments/cosmos_v2/debris/debris_metadata_v2.json"
	var r_entries: Dictionary = _get_atlas_entries(r_meta_path)
	var r_rocks: Array = r_entries.get("rock", []) as Array
	if not r_rocks.is_empty():
		var mm_rogue := _create_sector_multimesh(
			"RogueOuterFragments",
			-1,
			DEBRIS_ROCK_TEX,
			r_rocks,
			26,
			Vector2(1200.0, 2750.0),
			Vector2(0.22, 0.44),
			0.52,
			Color(0.76, 0.84, 0.96, 0.78),
			false
		)
		var r_mat: ShaderMaterial = mm_rogue.material as ShaderMaterial
		if r_mat != null:
			r_mat.set_shader_parameter("star_light_color", Color(0.55, 0.78, 1.0, 1.0))
			r_mat.set_shader_parameter("star_influence", 0.25)
		add_child(mm_rogue)
		_register_rotating_node(mm_rogue, 0.008, CosmosHasher.hash_2d_float(sector_seed, 3251, 91) * TAU)

	guide_outer_radius = maxf(max_orbit * 1.12, 2400.0)
	bounding_radius = maxf(max_orbit + 320.0, 2900.0)


func _build_derelict_armada(cfg: CosmosLivingUniverseConfig) -> void:
	guide_ring_color = Color(1.0, 0.36, 0.28, 0.48)
	guide_orbit_front_color = Color(1.0, 0.46, 0.34, 0.78)
	guide_orbit_back_color = Color(0.72, 0.24, 0.28, 0.24)

	var phase_val: float = CosmosHasher.hash_2d_float(sector_seed, 3301, 51) * TAU

	# 1. Aura de plasma fugado y destellos SOS (z = -2)
	var aura_spr := Sprite2D.new()
	aura_spr.name = "DerelictPlasmaAura"
	aura_spr.centered = true
	aura_spr.texture = _get_quad_tex()
	aura_spr.scale = Vector2.ONE * cfg.derelict_plasma_arc_radius
	aura_spr.z_index = -2
	var aura_mat := ShaderMaterial.new()
	aura_mat.shader = DERELICT_PLASMA_SHADER
	aura_mat.set_shader_parameter("seed_phase", phase_val)
	aura_mat.set_shader_parameter("plasma_color", cfg.derelict_plasma_color)
	aura_mat.set_shader_parameter("distress_color", cfg.derelict_distress_color)
	aura_mat.set_shader_parameter("overall_intensity", 1.18)
	aura_spr.material = aura_mat
	add_child(aura_spr)
	_global_time_mats.append(aura_mat)
	_biome_tinted_mats.append(aura_mat)
	_quality_mats.append(aura_mat)

	# 2. Vórtice de restos mecha (MultiMeshInstance2D, z = -1)
	var meta_path: String = debris_profile.metadata_json_path if debris_profile != null and not debris_profile.metadata_json_path.is_empty() else "res://assets/environments/cosmos_v2/debris/debris_metadata_v2.json"
	var entries: Dictionary = _get_atlas_entries(meta_path)
	var scrap_pool: Array = entries.get("scrap", []) as Array
	if not scrap_pool.is_empty() and cfg.derelict_scrap_count > 0:
		var mm_inst := _create_sector_multimesh(
			"DerelictScrapVortex",
			-1,
			DEBRIS_SCRAP_TEX,
			scrap_pool,
			cfg.derelict_scrap_count,
			cfg.derelict_vortex_radius_range,
			Vector2(0.30, 0.68),
			0.82,
			Color(0.90, 0.92, 0.98, 0.92),
			true
		)
		var v_mat: ShaderMaterial = mm_inst.material as ShaderMaterial
		if v_mat != null:
			v_mat.set_shader_parameter("star_light_color", Color(1.0, 0.52, 0.30, 1.0))
			v_mat.set_shader_parameter("star_influence", 0.48)
			v_mat.set_shader_parameter("rim_strength", 0.58)
			v_mat.set_shader_parameter("rim_tint", Color(1.0, 0.62, 0.42, 1.0))
		add_child(mm_inst)
		_register_rotating_node(mm_inst, cfg.derelict_vortex_angular_speed, phase_val * 0.25)

	# 3. Pecio principal + cascos fracturados opuestos para silueta clara de armada destruida (z = 0)
	var main_wreck := Sprite2D.new()
	main_wreck.name = "DerelictCoreWreck"
	main_wreck.centered = true
	main_wreck.texture = STATION_CITADEL_TEX
	var core_w: float = float(STATION_CITADEL_TEX.get_width()) if STATION_CITADEL_TEX != null else 512.0
	main_wreck.scale = Vector2.ONE * (cfg.derelict_core_diameter / maxf(core_w, 1.0))
	main_wreck.z_index = 0
	var wreck_mat := _build_station_shader_mat(cfg.derelict_distress_color, Color(1.0, 0.58, 0.22, 1.0), 3.4, 0.26, 0.24, 0.14)
	wreck_mat.set_shader_parameter("star_light_color", Color(1.0, 0.56, 0.28, 1.0))
	main_wreck.material = wreck_mat
	add_child(main_wreck)
	_biome_tinted_mats.append(wreck_mat)
	_register_rotating_node(main_wreck, 0.011, deg_to_rad(-28.0) + phase_val * 0.2)

	var sub_wreck := Sprite2D.new()
	sub_wreck.name = "DerelictFractureHull"
	sub_wreck.centered = true
	sub_wreck.texture = STATION_RELAY_TEX
	var sub_w: float = float(STATION_RELAY_TEX.get_width()) if STATION_RELAY_TEX != null else 512.0
	sub_wreck.scale = Vector2.ONE * ((cfg.derelict_core_diameter * 0.56) / maxf(sub_w, 1.0))
	sub_wreck.position = Vector2(245.0, -160.0).rotated(phase_val)
	sub_wreck.z_index = 0
	var sub_mat := _build_station_shader_mat(cfg.derelict_distress_color, cfg.derelict_plasma_color, 3.0, 0.30, 0.26, 0.14)
	sub_wreck.material = sub_mat
	add_child(sub_wreck)
	_biome_tinted_mats.append(sub_mat)
	_register_rotating_node(sub_wreck, -0.016, phase_val + 1.1)

	var sub_wreck_b := Sprite2D.new()
	sub_wreck_b.name = "DerelictFractureHullB"
	sub_wreck_b.centered = true
	sub_wreck_b.texture = STATION_CITADEL_TEX
	sub_wreck_b.scale = Vector2.ONE * ((cfg.derelict_core_diameter * 0.48) / maxf(core_w, 1.0))
	sub_wreck_b.position = Vector2(-240.0, 175.0).rotated(phase_val)
	sub_wreck_b.z_index = 0
	var sub_mat_b := _build_station_shader_mat(cfg.derelict_plasma_color, cfg.derelict_distress_color, 2.8, 0.28, 0.25, 0.14)
	sub_wreck_b.material = sub_mat_b
	add_child(sub_wreck_b)
	_biome_tinted_mats.append(sub_mat_b)
	_register_rotating_node(sub_wreck_b, 0.014, phase_val - 0.85)

	guide_core_radius = cfg.derelict_core_diameter * 0.55

	# 4. Drones / balizas de auxilio en órbitas 3D inclinadas
	var min_d: int = mini(cfg.derelict_beacon_drone_count.x, cfg.derelict_beacon_drone_count.y)
	var max_d: int = maxi(cfg.derelict_beacon_drone_count.x, cfg.derelict_beacon_drone_count.y)
	var span_d: int = max_d - min_d + 1
	var drone_count: int = min_d + (int(CosmosHasher.hash_2d_float(sector_seed, 3333, 41) * float(span_d)) % maxi(span_d, 1))
	var max_orb: float = cfg.derelict_vortex_radius_range.y

	for idx: int in range(drone_count):
		var d_seed: int = sector_seed + 5200 + idx * 103
		var orbit_r: float = lerpf(340.0, 580.0, CosmosHasher.hash_2d_float(d_seed, 11, 22)) + float(idx) * 95.0
		max_orb = maxf(max_orb, orbit_r)
		var drone := _create_orbital_craft(
			"DistressBeaconDrone_%d" % (idx + 1),
			d_seed,
			orbit_r,
			0.068 * (1.0 if idx % 2 == 0 else -1.0),
			lerpf(0.28, 0.54, CosmosHasher.hash_2d_float(d_seed, 33, 44)),
			lerpf(0.03, 0.14, CosmosHasher.hash_2d_float(d_seed, 55, 66)),
			58.0,
			cfg.derelict_distress_color,
			Color(1.0, 0.62, 0.25, 1.0),
			3.4
		)
		add_child(drone)
		orbiting_bodies.append(drone)
		_attach_trail_to_body(drone, 1.25, 2.8, Color(1.0, 0.36, 0.26, 0.54), Color(1.0, 0.18, 0.14, 0.0))

	# 5. Anillo periférico de balizas y restos a la deriva (lectura temprana a zoom 1x)
	var perim_ring := Node2D.new()
	perim_ring.name = "DerelictPerimeterRing"
	perim_ring.z_index = 0
	var relay_w: float = float(STATION_RELAY_TEX.get_width()) if STATION_RELAY_TEX != null else 512.0
	for p_i: int in range(3):
		var ps: int = sector_seed + 8100 + p_i * 67
		var p_ang: float = (float(p_i) * (TAU / 3.0)) + CosmosHasher.hash_2d_float(ps, 11, 22) * 0.75
		var p_rad: float = lerpf(1650.0, 2650.0, CosmosHasher.hash_2d_float(ps, 33, 44))
		var buoy := Sprite2D.new()
		buoy.name = "DerelictPerimeterBuoy_%d" % (p_i + 1)
		buoy.centered = true
		buoy.texture = STATION_RELAY_TEX
		buoy.scale = Vector2.ONE * (46.0 / maxf(relay_w, 1.0))
		buoy.position = Vector2(cos(p_ang), sin(p_ang)) * p_rad
		buoy.rotation = p_ang + 0.6
		var b_mat := _build_station_shader_mat(cfg.derelict_distress_color, Color(1.0, 0.58, 0.22, 1.0), 3.0, 0.32, 0.28, 0.14)
		buoy.material = b_mat
		_biome_tinted_mats.append(b_mat)
		perim_ring.add_child(buoy)
	add_child(perim_ring)
	_register_rotating_node(perim_ring, -0.011, phase_val * 0.35)

	guide_outer_radius = maxf(max_orb * 0.96, 2650.0)
	bounding_radius = maxf(max_orb + 260.0, 2900.0)


func _build_warp_relay(cfg: CosmosLivingUniverseConfig, p_neighbor_solar_angles: PackedFloat32Array) -> void:
	guide_ring_color = Color(0.22, 0.88, 1.0, 0.50)
	guide_orbit_front_color = Color(0.24, 0.96, 1.0, 0.80)
	guide_orbit_back_color = Color(0.22, 0.58, 0.86, 0.26)

	var phase_val: float = CosmosHasher.hash_2d_float(sector_seed, 3401, 61) * TAU

	# 1. Anillo rúnico hiperespacial + haces direccionales hacia estrellas cercanas (z = -2)
	var gate_spr := Sprite2D.new()
	gate_spr.name = "WarpGateAura"
	gate_spr.centered = true
	gate_spr.texture = _get_quad_tex()
	gate_spr.scale = Vector2.ONE * cfg.relay_gate_aura_radius
	gate_spr.z_index = -2
	var gate_mat := ShaderMaterial.new()
	gate_mat.shader = WARP_GATE_SHADER
	gate_mat.set_shader_parameter("seed_phase", phase_val)
	gate_mat.set_shader_parameter("primary_color", cfg.relay_primary_color)
	gate_mat.set_shader_parameter("accent_color", cfg.relay_accent_color)
	gate_mat.set_shader_parameter("overall_intensity", 1.15)
	if p_neighbor_solar_angles.size() >= 1:
		gate_mat.set_shader_parameter("guide_angle_a", p_neighbor_solar_angles[0])
		gate_mat.set_shader_parameter("guide_strength_a", 0.95)
	else:
		gate_mat.set_shader_parameter("guide_angle_a", phase_val)
		gate_mat.set_shader_parameter("guide_strength_a", 0.45)
	if p_neighbor_solar_angles.size() >= 2:
		gate_mat.set_shader_parameter("guide_angle_b", p_neighbor_solar_angles[1])
		gate_mat.set_shader_parameter("guide_strength_b", 0.85)
	else:
		gate_mat.set_shader_parameter("guide_strength_b", 0.0)

	gate_spr.material = gate_mat
	add_child(gate_spr)
	_global_time_mats.append(gate_mat)
	_biome_tinted_mats.append(gate_mat)
	_quality_mats.append(gate_mat)

	# 2. Megaestructura Relé central (z = 0)
	var citadel := Sprite2D.new()
	citadel.name = "WarpRelayCitadel"
	citadel.centered = true
	var cit_tex: Texture2D = STATION_CITADEL_TEX if CosmosHasher.hash_2d_float(sector_seed, 3417, 29) > 0.35 else STATION_RELAY_TEX
	citadel.texture = cit_tex
	var cit_w: float = float(cit_tex.get_width()) if cit_tex != null else 512.0
	citadel.scale = Vector2.ONE * (cfg.relay_core_diameter / maxf(cit_w, 1.0))
	citadel.z_index = 0
	var cit_mat := _build_station_shader_mat(cfg.relay_primary_color, cfg.relay_accent_color, 3.2, 0.0, 0.04, 0.08)
	cit_mat.set_shader_parameter("star_light_color", Color(0.68, 0.96, 1.0, 1.0))
	citadel.material = cit_mat
	add_child(citadel)
	_biome_tinted_mats.append(cit_mat)
	_register_rotating_node(citadel, 0.045, phase_val)

	guide_core_radius = cfg.relay_core_diameter * 0.52

	# 3. Satélites escolta en órbitas 3D cruzadas con estela energética
	var min_e: int = mini(cfg.relay_escort_count.x, cfg.relay_escort_count.y)
	var max_e: int = maxi(cfg.relay_escort_count.x, cfg.relay_escort_count.y)
	var span_e: int = max_e - min_e + 1
	var escort_count: int = min_e + (int(CosmosHasher.hash_2d_float(sector_seed, 3433, 71) * float(span_e)) % maxi(span_e, 1))
	var max_orb: float = cfg.relay_gate_aura_radius

	for idx: int in range(escort_count):
		var e_seed: int = sector_seed + 6300 + idx * 111
		var t_r: float = float(idx) / maxf(float(escort_count - 1), 1.0)
		var orbit_r: float = lerpf(cfg.relay_escort_orbit_range.x, cfg.relay_escort_orbit_range.y, t_r)
		max_orb = maxf(max_orb, orbit_r)
		var escort := _create_orbital_craft(
			"RelayEscort_%d" % (idx + 1),
			e_seed,
			orbit_r,
			0.095 * (1.0 if idx % 2 == 0 else -1.0),
			lerpf(0.24, 0.52, CosmosHasher.hash_2d_float(e_seed, 21, 32)),
			lerpf(0.02, 0.09, CosmosHasher.hash_2d_float(e_seed, 43, 54)),
			58.0,
			cfg.relay_primary_color,
			cfg.relay_accent_color,
			3.0
		)
		add_child(escort)
		orbiting_bodies.append(escort)
		_attach_trail_to_body(escort, 1.30, 2.8, Color(cfg.relay_primary_color.r, cfg.relay_primary_color.g, cfg.relay_primary_color.b, 0.52), Color(cfg.relay_accent_color.r, cfg.relay_accent_color.g, cfg.relay_accent_color.b, 0.0))

	# 4. Boyas de aproximación exterior alineadas hacia accesos del sector (r = 1350..2450)
	var approach_angles: PackedFloat32Array = PackedFloat32Array()
	if p_neighbor_solar_angles.size() >= 2:
		approach_angles.append(p_neighbor_solar_angles[0])
		approach_angles.append(p_neighbor_solar_angles[1])
		approach_angles.append(p_neighbor_solar_angles[0] + 0.42)
		approach_angles.append(p_neighbor_solar_angles[1] - 0.42)
	elif p_neighbor_solar_angles.size() == 1:
		var a0: float = p_neighbor_solar_angles[0]
		approach_angles.append(a0)
		approach_angles.append(a0 + 0.45)
		approach_angles.append(a0 + PI * 0.85)
		approach_angles.append(a0 - PI * 0.85)
	else:
		for k: int in range(4):
			approach_angles.append(phase_val + float(k) * (PI * 0.5))

	var b_tex_w: float = float(STATION_RELAY_TEX.get_width()) if STATION_RELAY_TEX != null else 512.0
	for b_i: int in range(4):
		var bs: int = sector_seed + 8300 + b_i * 73
		var b_ang: float = approach_angles[b_i]
		var b_rad: float = lerpf(1350.0, 2450.0, float(b_i) * 0.25 + CosmosHasher.hash_2d_float(bs, 17, 29) * 0.25)
		var buoy := Sprite2D.new()
		buoy.name = "RelayApproachBuoy_%d" % (b_i + 1)
		buoy.centered = true
		buoy.texture = STATION_RELAY_TEX
		buoy.scale = Vector2.ONE * (48.0 / maxf(b_tex_w, 1.0))
		buoy.position = Vector2(cos(b_ang), sin(b_ang)) * b_rad
		buoy.rotation = b_ang
		buoy.z_index = 0
		var b_mat := _build_station_shader_mat(cfg.relay_primary_color, cfg.relay_accent_color, 3.1, 0.04, 0.08, 0.10)
		b_mat.set_shader_parameter("beacon_1_phase_offset", float(b_i) * 0.35)
		buoy.material = b_mat
		_biome_tinted_mats.append(b_mat)
		add_child(buoy)

	guide_outer_radius = maxf(max_orb, 2450.0)
	bounding_radius = maxf(max_orb + 260.0, 2700.0)


func _build_ion_nursery(cfg: CosmosLivingUniverseConfig) -> void:
	guide_ring_color = Color(0.42, 0.84, 1.0, 0.45)
	guide_orbit_front_color = Color(1.0, 0.80, 0.44, 0.76)
	guide_orbit_back_color = Color(0.45, 0.62, 0.92, 0.24)

	var phase_val: float = CosmosHasher.hash_2d_float(sector_seed, 3501, 83) * TAU

	# 1. Bolsa nebular iónica FBM con 2-3 protoestrellas + relámpagos cósmicos (z = -2)
	var cloud_spr := Sprite2D.new()
	cloud_spr.name = "IonStormNurseryCloud"
	cloud_spr.centered = true
	cloud_spr.texture = _get_quad_tex()
	cloud_spr.scale = Vector2.ONE * cfg.nursery_cloud_radius
	cloud_spr.z_index = -2

	var min_p: int = mini(cfg.nursery_protostar_count.x, cfg.nursery_protostar_count.y)
	var max_p: int = maxi(cfg.nursery_protostar_count.x, cfg.nursery_protostar_count.y)
	var span_p: int = max_p - min_p + 1
	var proto_count: int = clampi(min_p + (int(CosmosHasher.hash_2d_float(sector_seed, 3511, 17) * float(span_p)) % maxi(span_p, 1)), 1, 3)

	var cloud_mat := ShaderMaterial.new()
	cloud_mat.shader = ION_NURSERY_SHADER
	cloud_mat.set_shader_parameter("seed_phase", phase_val)
	cloud_mat.set_shader_parameter("primary_color", cfg.nursery_primary_color)
	cloud_mat.set_shader_parameter("protostar_color", cfg.nursery_protostar_color)
	cloud_mat.set_shader_parameter("arc_color", cfg.nursery_arc_color)
	cloud_mat.set_shader_parameter("protostar_count", proto_count)
	cloud_mat.set_shader_parameter("lightning_intensity", cfg.nursery_lightning_intensity)

	for p_i: int in range(3):
		var a_p: float = phase_val + float(p_i) * (TAU / float(proto_count))
		var r_p: float = lerpf(0.055, 0.145, CosmosHasher.hash_2d_float(sector_seed + p_i * 71, 44, 55))
		cloud_mat.set_shader_parameter("protostar_pos_%d" % p_i, Vector2(cos(a_p), sin(a_p)) * r_p)

	cloud_spr.material = cloud_mat
	add_child(cloud_spr)
	_global_time_mats.append(cloud_mat)
	_biome_tinted_mats.append(cloud_mat)
	_quality_mats.append(cloud_mat)

	# 2. Cúmulo de cristales / proto-planetas rocosos iluminados por las protoestrellas (MultiMesh, z = -1)
	var meta_path: String = debris_profile.metadata_json_path if debris_profile != null and not debris_profile.metadata_json_path.is_empty() else "res://assets/environments/cosmos_v2/debris/debris_metadata_v2.json"
	var entries: Dictionary = _get_atlas_entries(meta_path)
	var rock_pool: Array = entries.get("rock", []) as Array
	if not rock_pool.is_empty() and cfg.nursery_crystal_count > 0:
		var mm_crystals := _create_sector_multimesh(
			"IonNurseryCrystals",
			-1,
			DEBRIS_ROCK_TEX,
			rock_pool,
			cfg.nursery_crystal_count,
			cfg.nursery_crystal_radius_range,
			Vector2(0.28, 0.58),
			0.88,
			Color(0.92, 0.96, 1.0, 0.92),
			false
		)
		var c_mat: ShaderMaterial = mm_crystals.material as ShaderMaterial
		if c_mat != null:
			c_mat.set_shader_parameter("star_light_color", cfg.nursery_protostar_color)
			c_mat.set_shader_parameter("star_influence", 0.78)
			c_mat.set_shader_parameter("rim_strength", 0.62)
			c_mat.set_shader_parameter("rim_tint", Color(0.55, 0.92, 1.0, 1.0))
		add_child(mm_crystals)
		_register_rotating_node(mm_crystals, 0.012, phase_val * 0.5)

	guide_core_radius = cfg.nursery_crystal_radius_range.x

	# 3. Fragmentos / embriones planetarios orbitando el vivero (permite validar órbitas 3D y [O])
	var p_cfg: CosmosPlanetarySystemConfig = system_profile.get_effective_planetary_config() if system_profile != null else null
	var embryo_count: int = 2
	var max_orb: float = cfg.nursery_crystal_radius_range.y
	for idx: int in range(embryo_count):
		var o_seed: int = sector_seed + 7400 + idx * 127
		var orbit_r: float = lerpf(420.0, 820.0, float(idx) * 0.65 + CosmosHasher.hash_2d_float(o_seed, 19, 29) * 0.35)
		max_orb = maxf(max_orb, orbit_r)
		var embryo := CosmosOrbitalBody2D.new()
		embryo.name = "IonEmbryo_%d" % (idx + 1)
		embryo.orbit_radius = orbit_r
		embryo.angular_velocity = 0.052 * (1.0 if idx % 2 == 0 else -1.0)
		embryo.initial_theta = CosmosHasher.hash_2d_float(o_seed, 13, 27) * TAU
		embryo.orbit_eccentricity = 0.10
		embryo.orbit_periapsis_angle = CosmosHasher.hash_2d_float(o_seed, 31, 41) * TAU
		embryo.orbit_plane_tilt = deg_to_rad(lerpf(-55.0, 55.0, CosmosHasher.hash_2d_float(o_seed, 53, 63)))
		embryo.orbit_plane_squash = lerpf(0.32, 0.58, CosmosHasher.hash_2d_float(o_seed, 71, 81))
		embryo.depth_scale_amplitude = 0.16
		embryo.enable_depth_z_swap = true
		embryo.show_orbit_lines = false
		add_child(embryo)

		if p_cfg != null and not p_cfg.moon_archetypes.is_empty():
			var m_arch: CosmosPlanetArchetype = p_cfg.moon_archetypes[(idx + 1) % p_cfg.moon_archetypes.size()]
			var m_ctx: Dictionary = {
				"night_ambient": 0.22,
				"day_exposure": 1.25,
				"star_color": cfg.nursery_protostar_color,
				"day_tint_strength": 0.55,
				"biome_tint_color": cfg.nursery_primary_color,
				"biome_tint_intensity": 0.25,
			}
			CosmosPlanetVisualBuilder.configure_moon_visual(embryo, m_arch, o_seed, 58.0 + float(idx) * 14.0, _get_quad_tex(), CELESTIAL_BODY_SHADER, m_ctx)
			var e_spr: Sprite2D = embryo.get_sprite()
			if e_spr != null and e_spr.material is ShaderMaterial:
				var e_mat: ShaderMaterial = e_spr.material as ShaderMaterial
				e_mat.set_shader_parameter("light_direction", Vector2(-cos(embryo.initial_theta), -sin(embryo.initial_theta)))
				_override_time_mats.append(e_mat)
				_biome_tinted_mats.append(e_mat)

		orbiting_bodies.append(embryo)
		_attach_trail_to_body(embryo, 1.25, 2.4, Color(cfg.nursery_arc_color.r, cfg.nursery_arc_color.g, cfg.nursery_arc_color.b, 0.45), Color(cfg.nursery_primary_color.r, cfg.nursery_primary_color.g, cfg.nursery_primary_color.b, 0.0))

	guide_outer_radius = maxf(cfg.nursery_cloud_radius * 0.72, max_orb)
	bounding_radius = maxf(cfg.nursery_cloud_radius, max_orb) + 250.0


func _create_sector_multimesh(
	node_name: String,
	p_z_index: int,
	atlas_tex: Texture2D,
	item_pool: Array,
	count: int,
	radius_range: Vector2,
	scale_range: Vector2,
	max_luma: float,
	tint: Color,
	spiral_vortex: bool
) -> MultiMeshInstance2D:
	var mm_inst := MultiMeshInstance2D.new()
	mm_inst.name = node_name
	mm_inst.z_index = p_z_index

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _get_unit_quad_mesh()
	mm.instance_count = count
	mm.visible_instance_count = count
	mm_inst.multimesh = mm

	for i: int in range(count):
		var s: int = sector_seed + 9000 + i * 37
		var pick_t: float = CosmosHasher.hash_2d_float(s, 11, 22)
		var entry: Dictionary = item_pool[clampi(int(pick_t * float(item_pool.size())), 0, item_pool.size() - 1)] as Dictionary
		var uv_r: Rect2 = entry.get("uv_rect", Rect2(0, 0, 0.25, 0.25)) as Rect2
		var pix_sz: Vector2 = entry.get("pixel_size", Vector2(180.0, 180.0)) as Vector2

		var r_t: float = CosmosHasher.hash_2d_float(s, 33, 44)
		var dist: float = lerpf(radius_range.x, radius_range.y, pow(r_t, 0.85))
		var base_ang: float = CosmosHasher.hash_2d_float(s, 55, 66) * TAU
		if spiral_vortex:
			base_ang = float(i % 2) * PI + r_t * 3.8 + (CosmosHasher.hash_2d_float(s, 77, 88) - 0.5) * 0.9
		var pos := Vector2(cos(base_ang), sin(base_ang)) * dist
		var rot: float = CosmosHasher.hash_2d_float(s, 91, 93) * TAU
		var sc_mult: float = lerpf(scale_range.x, scale_range.y, CosmosHasher.hash_2d_float(s, 95, 97))
		var final_sz: Vector2 = pix_sz * sc_mult

		var col_x: Vector2 = Vector2(cos(rot), sin(rot)) * final_sz.x
		var col_y: Vector2 = Vector2(-sin(rot), cos(rot)) * final_sz.y
		mm.set_instance_transform_2d(i, Transform2D(col_x, col_y, pos))
		var fade: float = lerpf(0.70, 1.0, 1.0 - r_t * 0.45)
		mm.set_instance_color(i, Color(tint.r, tint.g, tint.b, tint.a * fade))
		mm.set_instance_custom_data(i, Color(uv_r.position.x, uv_r.position.y, uv_r.size.x, uv_r.size.y))

	if DEBRIS_CUTOUT_SHADER != null:
		var mat := ShaderMaterial.new()
		mat.shader = DEBRIS_CUTOUT_SHADER
		mat.set_shader_parameter("atlas_texture", atlas_tex)
		mat.set_shader_parameter("cell_radius", maxf(radius_range.y + 520.0, 2400.0))
		mat.set_shader_parameter("edge_fade_margin", 480.0)
		mat.set_shader_parameter("desaturation_amount", 0.48)
		mat.set_shader_parameter("biome_grade_mix", 0.42)
		mat.set_shader_parameter("max_debris_luma", max_luma)
		mat.set_shader_parameter("depth_haze_strength", 0.28)
		mat.set_shader_parameter("star_influence", 0.0)
		mat.set_shader_parameter("spin_speed_mult", 0.35)
		mat.set_shader_parameter("drift_speed", 8.0)
		mm_inst.material = mat
		_global_time_mats.append(mat)
		_debris_mats.append(mat)

	return mm_inst


func _build_station_shader_mat(
	col_a: Color,
	col_b: Color,
	p_beacon_intensity: float,
	p_eclipse: float,
	p_desat: float,
	p_haze_intensity: float = 0.20
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = STATION_BEACON_SHADER
	mat.set_shader_parameter("beacon_1_color", col_a)
	mat.set_shader_parameter("beacon_2_color", Color(1.0, 0.98, 0.94, 1.0))
	mat.set_shader_parameter("beacon_3_color", col_b)
	mat.set_shader_parameter("beacon_4_color", col_a)
	mat.set_shader_parameter("beacon_intensity", p_beacon_intensity)
	mat.set_shader_parameter("eclipse_shadow", p_eclipse)
	mat.set_shader_parameter("distance_desaturation", p_desat)
	mat.set_shader_parameter("ambient_haze_intensity", p_haze_intensity)
	mat.set_shader_parameter("star_light_color", col_a)
	mat.set_shader_parameter("light_direction", Vector2(0.75, -0.66))
	return mat


func _create_orbital_craft(
	p_name: String,
	p_seed: int,
	p_orbit_r: float,
	p_ang_vel: float,
	p_squash: float,
	p_ecc: float,
	p_diameter: float,
	col_a: Color,
	col_b: Color,
	p_beacon_intensity: float
) -> CosmosOrbitalBody2D:
	var craft := CosmosOrbitalBody2D.new()
	craft.name = p_name
	craft.orbit_radius = p_orbit_r
	craft.angular_velocity = p_ang_vel
	craft.initial_theta = CosmosHasher.hash_2d_float(p_seed, 101, 202) * TAU
	craft.orbit_eccentricity = p_ecc
	craft.orbit_periapsis_angle = CosmosHasher.hash_2d_float(p_seed, 303, 404) * TAU
	craft.orbit_plane_tilt = deg_to_rad(lerpf(-68.0, 68.0, CosmosHasher.hash_2d_float(p_seed, 505, 606)))
	craft.orbit_plane_squash = p_squash
	craft.depth_scale_amplitude = 0.18
	craft.enable_depth_z_swap = true
	craft.tangent_align = true
	craft.show_orbit_lines = false

	var spr := Sprite2D.new()
	spr.name = "CraftVisual"
	spr.centered = true
	spr.texture = STATION_RELAY_TEX
	var tex_w: float = float(STATION_RELAY_TEX.get_width()) if STATION_RELAY_TEX != null else 512.0
	spr.scale = Vector2.ONE * (p_diameter / maxf(tex_w, 1.0))
	spr.material = _build_station_shader_mat(col_a, col_b, p_beacon_intensity, 0.22, 0.15)
	craft.add_child(spr)
	craft.set_sprite_reference(spr)
	craft.set_meta(&"visual_radius", p_diameter * 0.5)
	_biome_tinted_mats.append(spr.material as ShaderMaterial)
	return craft


func _attach_trail_to_body(
	body: CosmosOrbitalBody2D,
	arc_radians: float,
	head_width: float,
	head_col: Color,
	tail_col: Color
) -> void:
	var trail := CosmosOrbitalTrail2D.new()
	trail.name = body.name + "_Trail"
	trail.configure_from_body(body, arc_radians, head_width, head_col, tail_col, 16, true)
	add_child(trail)
	orbital_trails.append(trail)


func _register_rotating_node(node: Node2D, angular_speed: float, initial_phase: float) -> void:
	_rotating_nodes.append(node)
	_rotating_speeds.append(angular_speed)
	_rotating_phases.append(initial_phase)
	node.rotation = initial_phase


## Evalúa cinemática 3D, estelas, rotación y tiempo de shaders en t_global sin asignar memoria.
func update_sector_state(global_time: float) -> void:
	_last_global_time = global_time
	if not _is_built:
		return

	if _host_body != null and is_instance_valid(_host_body):
		_host_body.evaluate_orbital_position(global_time)

	for body: CosmosOrbitalBody2D in orbiting_bodies:
		if is_instance_valid(body):
			body.evaluate_orbital_position(global_time)

	for trail: CosmosOrbitalTrail2D in orbital_trails:
		if is_instance_valid(trail):
			trail.update_trail(global_time)

	for i: int in range(_rotating_nodes.size()):
		var node: Node2D = _rotating_nodes[i]
		if is_instance_valid(node):
			node.rotation = _rotating_phases[i] + (_rotating_speeds[i] * global_time)

	for mat: ShaderMaterial in _global_time_mats:
		mat.set_shader_parameter("global_time", global_time)
	for mat: ShaderMaterial in _override_time_mats:
		mat.set_shader_parameter("global_time_override", global_time)


func apply_biome_harmony(b_primary: Color, b_secondary: Color) -> void:
	_biome_primary = b_primary
	_biome_secondary = b_secondary
	var blend_tint: Color = b_primary.lerp(b_secondary, 0.45)
	var haze_col: Color = blend_tint.lerp(Color(0.05, 0.08, 0.20, 1.0), 0.36)

	for mat: ShaderMaterial in _biome_tinted_mats:
		mat.set_shader_parameter("biome_tint_color", blend_tint)
	for mat: ShaderMaterial in _debris_mats:
		mat.set_shader_parameter("biome_haze_color", haze_col)


func apply_graphics_quality(quality_level: int) -> void:
	_graphics_quality = clampi(quality_level, 0, 2)
	for mat: ShaderMaterial in _quality_mats:
		mat.set_shader_parameter("quality_level", _graphics_quality)
	var show_trails: bool = (_graphics_quality >= 1)
	for trail: CosmosOrbitalTrail2D in orbital_trails:
		if is_instance_valid(trail):
			trail.visible = show_trails


func set_orbit_guides_visible(p_visible: bool) -> void:
	_orbit_guides_visible = p_visible
	if _guides_drawer != null and is_instance_valid(_guides_drawer):
		_guides_drawer.visible = p_visible
		if p_visible:
			_guides_drawer.queue_redraw()
