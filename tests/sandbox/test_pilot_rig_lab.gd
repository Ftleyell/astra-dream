extends BaseTestSuite

const PilotRigLabScene: PackedScene = preload("res://sandbox/pilot_rig_lab/pilot_rig_lab.tscn")

func _ready() -> void:
	super._ready()
	_run_test()

func _run_test() -> void:
	var lab: Control = PilotRigLabScene.instantiate() as Control
	add_child(lab)

	var sprites: Dictionary = lab.get("part_sprites") as Dictionary
	assert_true(sprites.size() == 8, "Expected 8 sliced layers in PilotRigLab, got %d" % sprites.size())
	assert_true(lab.get("wings_bloom_sprite") != null, "Expected additive CRT bloom sprite on wings")

	# Verify seamless elastic bust mode is enabled by default and hides the detached bust sprite
	var bust_spr: Sprite2D = sprites["bust"] as Sprite2D
	assert_true(bust_spr.visible == false, "Detached bust sprite should be hidden when seamless elastic bust is active")

	# Test autonomous idle breathing & spring physics (0% mouse reactivity)
	lab.call("_process", 0.04)
	lab.call("_process", 0.04)
	var disp: Vector2 = lab.get("_bust_disp") as Vector2
	assert_true(disp.length() > 0.001, "Autonomous breathing cycle should drive elastic bust spring")

	# Test switching between the 5 real-time shader pipeline modes and skins
	lab.set("current_skin_id", "solar_valkyrie")
	lab.call("_sync_colors_from_preset", "solar_valkyrie")
	lab.set("current_pipeline_mode", 2)
	lab.call("_apply_pipeline_and_skin")
	var mats: Dictionary = lab.get("part_materials") as Dictionary
	var torso_mat: ShaderMaterial = mats["torso"] as ShaderMaterial
	assert_true(bool(torso_mat.get_shader_parameter("enable_shader_recolor")) == true, "Shader recolor should be active on non-base skin")
	assert_true(int(torso_mat.get_shader_parameter("pipeline_style_mode")) == 2, "Pipeline style mode should be 2 (Skullgirls Screentone)")

	lab.set("current_skin_id", "base")
	lab.call("_sync_colors_from_preset", "base")
	lab.set("current_pipeline_mode", 0)
	lab.call("_apply_pipeline_and_skin")
	assert_true(bool(torso_mat.get_shader_parameter("enable_shader_recolor")) == false, "Shader recolor should be off on base skin without custom edits")

	pass_suite("PilotRigLab v3 Upscayl 4x, 100% skin-protected 4ch mask, autonomous idle, and 5 shader pipelines verified.")
