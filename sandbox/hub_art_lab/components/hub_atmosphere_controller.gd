class_name HubAtmosphereController
extends Node3D

## Controlador atmosférico AAA modular para Estación Astral v2 (Forward+):
## - 3 haces de luz volumétricos (god-rays) entrando desde el Ventanal Norte + 1 haz cenital en la Cápsula Hero.
## - 64 motas de polvo astral flotantes Zero-G (MultiMeshInstance3D sin asignaciones por frame).
## - Post-proceso fílmico sutil de unificación cromática y viñeta cósmica (CanvasLayer 4).

const LightShaftShader = preload("res://sandbox/hub_art_lab/shaders/hub_light_shaft_3d.gdshader")
const Post2DShader = preload("res://sandbox/hub_art_lab/shaders/hub_cinematic_post_2d.gdshader")
const SparkBuilder = preload("res://sandbox/hub_art_lab/meshes/hub_gacha_summoner_mesh_builder.gd")

const MOTE_COUNT: int = 64

var _shafts_root: Node3D = null
var _motes_mm: MultiMeshInstance3D = null
var _mote_base_pos: PackedVector3Array = PackedVector3Array()
var _mote_phases: PackedFloat32Array = PackedFloat32Array()
var _mote_scales: PackedFloat32Array = PackedFloat32Array()
var _post_layer: CanvasLayer = null
var _post_rect: ColorRect = null
var _post_mat: ShaderMaterial = null
var _time_acc: float = 0.0


func setup(capsule_pos: Vector3) -> void:
	_build_light_shafts(capsule_pos)
	_build_dust_motes()
	_build_cinematic_vignette()


func _build_light_shafts(capsule_pos: Vector3) -> void:
	if _shafts_root != null:
		return
	_shafts_root = Node3D.new()
	_shafts_root.name = "VolumetricLightShafts"
	add_child(_shafts_root)

	var north_specs: Array[Dictionary] = [
		{"name": "NorthShaftCenter", "pos": Vector3(0.0, 3.3, -6.2), "rot": Vector3(48.0, 0.0, 0.0), "top": 2.4, "bot": 4.2, "h": 9.8, "col": Color(1.0, 0.36, 0.56, 1.0), "int": 0.11},
		{"name": "NorthShaftWest", "pos": Vector3(-5.2, 3.2, -5.8), "rot": Vector3(48.0, -14.0, 6.0), "top": 1.6, "bot": 3.1, "h": 9.2, "col": Color(0.62, 0.44, 1.0, 1.0), "int": 0.09},
		{"name": "NorthShaftEast", "pos": Vector3(5.2, 3.2, -5.8), "rot": Vector3(48.0, 14.0, -6.0), "top": 1.6, "bot": 3.1, "h": 9.2, "col": Color(0.28, 0.86, 1.0, 1.0), "int": 0.09},
		{"name": "CapsuleHeroShaft", "pos": Vector3(capsule_pos.x, 3.1, capsule_pos.z + 0.15), "rot": Vector3(8.0, 0.0, 0.0), "top": 0.65, "bot": 2.15, "h": 5.6, "col": Color(1.0, 0.90, 0.72, 1.0), "int": 0.095},
	]

	for spec: Dictionary in north_specs:
		var cyl := CylinderMesh.new()
		cyl.top_radius = float(spec["top"])
		cyl.bottom_radius = float(spec["bot"])
		cyl.height = float(spec["h"])
		cyl.radial_segments = 24
		cyl.cap_top = false
		cyl.cap_bottom = false

		var mat := ShaderMaterial.new()
		mat.shader = LightShaftShader
		mat.set_shader_parameter("shaft_color", spec["col"] as Color)
		mat.set_shader_parameter("intensity", float(spec["int"]))
		mat.set_shader_parameter("edge_power", 2.35)

		var mi := MeshInstance3D.new()
		mi.name = str(spec["name"])
		mi.mesh = cyl
		mi.position = spec["pos"] as Vector3
		mi.rotation_degrees = spec["rot"] as Vector3
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shafts_root.add_child(mi)


func _build_dust_motes() -> void:
	if _motes_mm != null or DisplayServer.get_name() == "headless":
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = SparkBuilder.build_spark_shard_mesh()
	mm.instance_count = MOTE_COUNT

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false

	_motes_mm = MultiMeshInstance3D.new()
	_motes_mm.name = "AstralDustMotes"
	_motes_mm.multimesh = mm
	_motes_mm.material_override = mat
	_motes_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_motes_mm)

	_mote_base_pos.resize(MOTE_COUNT)
	_mote_phases.resize(MOTE_COUNT)
	_mote_scales.resize(MOTE_COUNT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90731
	for i: int in range(MOTE_COUNT):
		var px: float = rng.randf_range(-10.5, 10.5)
		var py: float = rng.randf_range(0.45, 3.85)
		var pz: float = rng.randf_range(-9.2, 8.8)
		_mote_base_pos[i] = Vector3(px, py, pz)
		_mote_phases[i] = rng.randf_range(0.0, TAU)
		_mote_scales[i] = rng.randf_range(0.14, 0.30)
		var col := Color(0.88, 0.94, 1.0, 0.38) if (i % 3 != 0) else Color(1.0, 0.68, 0.82, 0.42)
		mm.set_instance_color(i, col)
	_update_motes(0.0)


func _build_cinematic_vignette() -> void:
	if _post_layer != null:
		return
	_post_layer = CanvasLayer.new()
	_post_layer.name = "CinematicPostLayer"
	_post_layer.layer = 4
	add_child(_post_layer)

	_post_mat = ShaderMaterial.new()
	_post_mat.shader = Post2DShader
	_post_mat.set_shader_parameter("vignette_strength", 0.30)

	_post_rect = ColorRect.new()
	_post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_rect.material = _post_mat
	_post_layer.add_child(_post_rect)


func set_vignette_visible(vis: bool) -> void:
	if _post_layer != null:
		_post_layer.visible = vis


func _process(delta: float) -> void:
	if _motes_mm == null or _motes_mm.multimesh == null:
		return
	_time_acc += delta
	_update_motes(_time_acc)


func _update_motes(t: float) -> void:
	var mm: MultiMesh = _motes_mm.multimesh
	for i: int in range(MOTE_COUNT):
		var ph: float = _mote_phases[i]
		var bp: Vector3 = _mote_base_pos[i]
		var s: float = _mote_scales[i] * (0.75 + 0.25 * sin(t * 1.4 + ph))
		var pos := Vector3(
			bp.x + sin(t * 0.35 + ph) * 0.28,
			bp.y + cos(t * 0.48 + ph * 1.3) * 0.22,
			bp.z + sin(t * 0.28 - ph) * 0.24
		)
		var xf := Transform3D(Basis.from_scale(Vector3(s, s * 1.4, s)), pos)
		mm.set_instance_transform(i, xf)
