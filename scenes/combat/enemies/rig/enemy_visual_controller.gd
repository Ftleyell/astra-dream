class_name EnemyVisualController
extends Node2D

## Modular 2.5D/3D visual rig bridge for production EnemyBase archetypes.
## Mounts VoidScarabRig25D (combat_lite_mode) with archetype color palette, size
## multiplier, staggered CosmicLightingSampler illumination, and lifecycle reactions.

const VoidScarabRigScript = preload("res://scenes/combat/enemies/rig/void_scarab_rig_25d.gd")
const CatalogRes: EnemyArchetypeVisualCatalog = preload("res://data/enemies/default_enemy_visual_catalog.tres")
const DefaultScarabConfig: EnemyScarabRigConfig = preload("res://data/enemies/void_scarab/void_scarab_config.tres")
const DefaultScarabStyle: EnemyFactionStyle = preload("res://data/enemies/void_scarab/style_biomech_void.tres")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")

const COSMIC_SAMPLE_INTERVAL: float = 0.08

static var _cached_cosmos_host_ref: WeakRef = null

var _owner_enemy: Node2D = null
var _rig: VoidScarabRig25D = null
var _entry: EnemyArchetypeVisualEntry = null
var _lighting_sample: CosmicLightingSampleScript = CosmicLightingSampleScript.new()

var _light_timer: float = 0.0
var _did_initial_light: bool = false
var _prev_rot: float = 0.0
var _prev_speed: float = 0.0
var _rainbow_time: float = 0.0


func setup(p_owner: Node2D) -> void:
	_owner_enemy = p_owner
	if _owner_enemy == null:
		return

	_entry = _resolve_entry()
	_rig = VoidScarabRigScript.new()
	_rig.name = "VoidScarabRig25D"
	_rig.combat_lite_mode = true
	_rig.enable_combat_ribbons = _entry.enable_flight_ribbons
	_rig.rig_config = DefaultScarabConfig
	_rig.style_profile = DefaultScarabStyle
	add_child(_rig)

	_apply_entry_transform_and_palette()
	hide_legacy_visuals(_owner_enemy)

	_prev_rot = _owner_enemy.rotation
	_prev_speed = 0.0
	_light_timer = randf_range(0.0, COSMIC_SAMPLE_INTERVAL)
	_did_initial_light = false


func _resolve_entry() -> EnemyArchetypeVisualEntry:
	var eid: StringName = &"enemy_drone"
	if _owner_enemy != null and "enemy_id" in _owner_enemy:
		eid = _owner_enemy.get("enemy_id") as StringName
	return CatalogRes.resolve_entry(eid)


func _apply_entry_transform_and_palette() -> void:
	if _rig == null or _entry == null:
		return
	var s: float = maxf(CatalogRes.combat_base_rig_scale * _entry.size_multiplier, 0.04)
	scale = Vector2(s, s)
	_rig.set_enable_ribbons(_entry.enable_flight_ribbons)
	_rig.apply_custom_palette(
		_entry.use_variant_recolor,
		_entry.armor_tint,
		_entry.accent_tint,
		_entry.energy_tint
	)


static func hide_legacy_visuals(p_owner: Node2D) -> void:
	if p_owner == null:
		return
	for node_name: String in ["Sprite2D", "SplitterSprite", "FlockSprite", "Visual", "CoreGlow", "CellCore", "EngineParticles"]:
		var item: CanvasItem = p_owner.get_node_or_null(node_name) as CanvasItem
		if item != null:
			item.visible = false
	if "sprite" in p_owner:
		var spr: CanvasItem = p_owner.get("sprite") as CanvasItem
		if spr != null:
			spr.visible = false


func _process(delta: float) -> void:
	step_from_owner(delta)


func step_from_owner(delta: float) -> void:
	if _owner_enemy == null or not is_instance_valid(_owner_enemy) or _rig == null:
		return

	var dt: float = maxf(delta, 0.0001)
	var cur_rot: float = _owner_enemy.rotation
	var ang_vel: float = wrapf(cur_rot - _prev_rot, -PI, PI) / dt
	_prev_rot = cur_rot

	var vel: Vector2 = Vector2.ZERO
	if _owner_enemy is CharacterBody2D:
		vel = (_owner_enemy as CharacterBody2D).velocity
	var spd: float = vel.length()
	var fwd_norm: float = clampf(spd / 260.0, 0.0, 1.35)
	var accel_norm: float = clampf(((spd - _prev_speed) / dt) / 600.0, -1.0, 1.0)
	_prev_speed = spd

	var dying: bool = _get_owner_flag(&"is_dying")
	var desired_state: int = VoidScarabRigScript.AnimState.IDLE_HOVER
	if dying:
		desired_state = VoidScarabRigScript.AnimState.DEATH_SHATTER
	elif _get_owner_flag(&"is_diving") or _get_owner_flag(&"_is_charging"):
		desired_state = VoidScarabRigScript.AnimState.ATTACK_LUNGE
	elif _get_owner_flag(&"is_charging_shot") or _get_owner_flag(&"_is_telegraphing") or _get_owner_flag(&"is_preparing_charge"):
		desired_state = VoidScarabRigScript.AnimState.CHARGE_TELEGRAPH
	elif spd > 28.0:
		desired_state = VoidScarabRigScript.AnimState.CRUISE_BANK

	if _rig.get_anim_state() != desired_state and not (dying and _rig.get_anim_state() == VoidScarabRigScript.AnimState.DEATH_SHATTER):
		_rig.set_anim_state(desired_state)

	if _entry != null and _entry.enable_rainbow_cycle and not dying:
		_rainbow_time += delta
		var h: float = fmod(_rainbow_time * 0.42, 1.0)
		var arm_c: Color = Color.from_hsv(h, 0.58, 0.44, 1.0)
		var acc_c: Color = Color.from_hsv(fmod(h + 0.12, 1.0), 0.85, 1.0, 1.0)
		var eng_c: Color = Color.from_hsv(fmod(h + 0.24, 1.0), 0.90, 1.0, 1.0)
		_rig.apply_custom_palette(true, arm_c, acc_c, eng_c)

	_light_timer -= delta
	if not _did_initial_light or _light_timer <= 0.0:
		_did_initial_light = true
		_light_timer = COSMIC_SAMPLE_INTERVAL
		var cosmos_host: CosmosHostController = _resolve_cosmos_host()
		if cosmos_host != null:
			cosmos_host.sample_lighting_at(_owner_enemy.global_position, _lighting_sample)
			_rig.apply_cosmic_lighting(_lighting_sample)

	_rig.step(delta, ang_vel, fwd_norm, accel_norm)


func _resolve_cosmos_host() -> CosmosHostController:
	if _cached_cosmos_host_ref != null:
		var cached: Object = _cached_cosmos_host_ref.get_ref()
		if cached != null and is_instance_valid(cached) and cached is CosmosHostController:
			return cached as CosmosHostController

	var found: CosmosHostController = null
	if _owner_enemy != null and _owner_enemy.is_inside_tree():
		var p: Node = _owner_enemy.get_parent()
		if p != null:
			var env_host: Variant = p.get("environment_host")
			if env_host is Object and (env_host as Object).has_method("get_cosmos_controller"):
				found = (env_host as Object).call("get_cosmos_controller") as CosmosHostController
			if found == null:
				var bg: Node = p.get_node_or_null("SpaceBackground")
				if bg != null and bg.has_method("get_host_controller"):
					found = bg.call("get_host_controller") as CosmosHostController
		if found == null and _owner_enemy.get_tree().current_scene != null:
			var scene_bg: Node = _owner_enemy.get_tree().current_scene.get_node_or_null("SpaceBackground")
			if scene_bg != null and scene_bg.has_method("get_host_controller"):
				found = scene_bg.call("get_host_controller") as CosmosHostController
		if found == null:
			var cosmos_root: Node = _owner_enemy.get_tree().get_first_node_in_group(&"cosmos_root")
			if cosmos_root != null and cosmos_root.get_parent() != null:
				var cp: Node = cosmos_root.get_parent()
				if cp.has_method("get_host_controller"):
					found = cp.call("get_host_controller") as CosmosHostController

	if found != null:
		_cached_cosmos_host_ref = weakref(found)
	return found


func on_hit() -> void:
	if _rig != null:
		_rig.trigger_hit_flash()


func on_contact_bite() -> void:
	if _rig != null:
		_rig.trigger_bite_snap()


func on_die() -> void:
	if _rig != null:
		_rig.set_anim_state(VoidScarabRigScript.AnimState.DEATH_SHATTER)


func reset_for_pool() -> void:
	_entry = _resolve_entry()
	_apply_entry_transform_and_palette()
	hide_legacy_visuals(_owner_enemy)
	_prev_rot = _owner_enemy.rotation if _owner_enemy != null else 0.0
	_prev_speed = 0.0
	_did_initial_light = false
	if _rig != null:
		_rig.respawn()


func get_rig() -> VoidScarabRig25D:
	return _rig


func get_visual_entry() -> EnemyArchetypeVisualEntry:
	return _entry


func _get_owner_flag(prop: StringName) -> bool:
	if _owner_enemy == null:
		return false
	var val: Variant = _owner_enemy.get(prop)
	return val is bool and (val as bool)
