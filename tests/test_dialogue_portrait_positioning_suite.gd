extends Node

func _ready() -> void:
	# Watchdog timeout
	get_tree().create_timer(15.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout in dialogue portrait positioning test.")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Testing VN Dialogue Portrait Positions Across Resolutions...")
	print("==========================================")

	# 1. Start dialogue with prologue_briefing (joins nova left and echo right)
	var layout = Dialogic.start("res://narrative/timelines/prologue_briefing.dtl")
	assert(layout != null, "Dialogic layout must not be null")
	# Wait for both join animations to complete (0.5s + 0.5s = 1.0s)
	await get_tree().create_timer(1.2).timeout

	var portraits_layer = layout.find_child("VN_PortraitLayer", true, false)
	assert(portraits_layer != null, "VN_PortraitLayer must exist in Dialogic layout")

	var portraits: Control = portraits_layer.get_node("%Portraits")
	assert(portraits != null, "%Portraits node must exist")

	var resolutions := [
		Vector2(1920, 1080), # 16:9 Full HD
		Vector2(2560, 1080), # 21:9 Ultrawide
		Vector2(3440, 1440), # 21:9 Ultrawide QHD
		Vector2(3840, 1080), # 32:9 Super Ultrawide
		Vector2(1920, 1200), # 16:10 Steam Deck/WUXGA
	]

	print("\n[PHASE 1] Dynamic Viewport Resize Testing...")
	for res in resolutions:
		portraits.size = res
		portraits.resized.emit()
		await get_tree().process_frame
		await get_tree().process_frame

		var left_node: DialogicNode_PortraitContainer = portraits.get_node_or_null("left")
		var right_node: DialogicNode_PortraitContainer = portraits.get_node_or_null("right")
		var center_node: DialogicNode_PortraitContainer = portraits.get_node_or_null("center")
		var nova_container: DialogicNode_PortraitContainer = portraits.get_node_or_null("Portrait_nova")
		var echo_container: DialogicNode_PortraitContainer = portraits.get_node_or_null("Portrait_echo")

		var expected_half_width: float = res.y * 0.5
		var expected_left_center: float = expected_half_width
		var expected_right_center: float = res.x - expected_half_width
		var expected_center_x: float = res.x * 0.5

		print("  Res %dx%d -> Left: %.1f (exp %.1f), Right: %.1f (exp %.1f)" % [
			int(res.x), int(res.y),
			left_node.container_position.as_pixels().x, expected_left_center,
			right_node.container_position.as_pixels().x, expected_right_center
		])

		assert(absf(left_node.container_position.as_pixels().x - expected_left_center) < 1.0, "left node position must match edge docking")
		assert(absf(right_node.container_position.as_pixels().x - expected_right_center) < 1.0, "right node position must match edge docking")
		assert(absf(center_node.container_position.as_pixels().x - expected_center_x) < 1.0, "center node must be at 50% width")

		if nova_container:
			var nova_char = nova_container.get_node_or_null("nova")
			var nova_global_x: float = nova_char.global_position.x if nova_char else -1.0
			assert(absf(nova_global_x - expected_left_center) < 1.0, "Nova global x must dock to left edge")

		if echo_container:
			var echo_char = echo_container.get_node_or_null("echo")
			var echo_global_x: float = echo_char.global_position.x if echo_char else -1.0
			assert(absf(echo_global_x - expected_right_center) < 1.0, "Echo global x must dock to right edge")

	Dialogic.end_timeline()
	await get_tree().process_frame

	print("\n==========================================")
	print("[PASS] ALL ULTRAWIDE DIALOGUE PORTRAIT POSITION TESTS PASSED (100%)!")
	print("==========================================")
	get_tree().quit(0)
