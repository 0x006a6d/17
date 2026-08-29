extends SceneTree

## プレイヤー用 Mixamo モーションのロード、GeneralSkeleton リターゲット、
## AnimationLibrary とコード生成ステートへの割り当て、実尺とロジック窓を検証する。
## 実行:
##   godot --path . --headless --script tools/verify_player_action_motions.gd

const PLAYER_SCENE_PATH: String = "res://actors/player/player.tscn"
const MOTION_DIRECTORY: String = "res://assets/motions/"
const SOURCE_ANIMATION_KEY: String = "mixamo_com"
const PLAYER_LIBRARY_PREFIX: String = "player/"
const GENERAL_SKELETON_NAME: StringName = &"GeneralSkeleton"
const RETARGET_PROBE_BONE: StringName = &"RightHand"
const FIRST_KATANA_STAGE: int = 1
const SECOND_KATANA_STAGE: int = 2
const FINAL_KATANA_STAGE: int = 3
const SECOND_KATANA_SOURCE_LENGTH: float = 2.4
const SECOND_KATANA_DURATION: float = 0.6
const SECOND_KATANA_SPEED_SCALE: float = 4.0
const PISTOL_WALK_SOURCE_LENGTH: float = 0.8
const PISTOL_WALK_TRACK_COUNT: int = 53
const GENERAL_SKELETON_BONE_COUNT: int = 65
const PISTOL_WALK_NATURAL_SPEED: float = 2.09
const PISTOL_WALK_MAX_PLAYBACK_SCALE: float = 2.2
const SWORD_IDLE_SOURCE_LENGTH: float = 1.833
const SWORD_IDLE_BLEND_OUT_SPEED: float = 0.1
const GUN_WALK_BLEND_POSITION: float = 1.0
const NATURAL_PLAYBACK_SCALE: float = 1.0
const EXPECTED_GUN_BLEND_POINT_COUNT: int = 2
const DEFAULT_LOCOMOTION_MAX_SPEED: float = 4.5
const IN_PLACE_ROOT_MOTION_EPSILON: float = 0.001
const CLIP_LENGTH_TOLERANCE: float = 0.001
const GUN_SELECT_PARAMETER: String = \
	"parameters/main/locomotion/gun_select/blend_amount"
const KATANA_SELECT_PARAMETER: String = \
	"parameters/main/locomotion/katana_select/blend_amount"
const GUN_BLEND_POSITION_PARAMETER: String = \
	"parameters/main/locomotion/gun/blend/blend_position"
const GUN_SPEED_SCALE_PARAMETER: String = \
	"parameters/main/locomotion/gun/speed/scale"

const CLIP_SPECS: Array[Dictionary] = [
	{"id": &"katana_1", "file": "mixamo_sword_slash.fbx", "library": &"katana_1",
		"state": &"katana_1"},
	{"id": &"katana_2", "file": "mixamo_melee_horizontal.fbx", "library": &"katana_2",
		"state": &"katana_2"},
	{"id": &"katana_3", "file": "mixamo_katana_360.fbx", "library": &"katana",
		"state": &"katana"},
	{"id": &"gun_idle", "file": "mixamo_pistol_fire.fbx", "library": &"gun_idle",
		"state": &"locomotion"},
	{"id": &"gun_walk", "file": "mixamo_pistol_walk.fbx", "library": &"gun_walk",
		"state": &"locomotion"},
	{"id": &"katana_idle", "file": "mixamo_sword_idle.fbx", "library": &"katana_idle",
		"state": &"locomotion"},
	{"id": &"dodge", "file": "mixamo_dodge_backflip.fbx", "library": &"dodge",
		"state": &"dodge"},
	{"id": &"special", "file": "mixamo_spin_flip_kick.fbx", "library": &"special",
		"state": &"special"},
	{"id": &"death", "file": "mixamo_death_headshot.fbx", "library": &"",
		"state": &""},
]

var _failures: int = 0
var _checks: int = 0
var _passes: int = 0
var _source_lengths: Dictionary[StringName, float] = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== player action motion source verification ===")
	for spec: Dictionary in CLIP_SPECS:
		_verify_source_clip(spec)

	var packed := load(PLAYER_SCENE_PATH) as PackedScene
	_check("player scene loads", packed != null)
	if packed == null:
		_finish()
		return
	var player := packed.instantiate() as CharacterBody3D
	_check("player scene instantiates", player != null)
	if player == null:
		_finish()
		return
	get_root().add_child(player)
	await process_frame
	await process_frame

	var melee: Node = player.get_node_or_null(^"PlayerMelee")
	var tree: AnimationTree = null
	if melee != null:
		tree = melee.get_node_or_null(^"AnimationTree") as AnimationTree
	_check("PlayerMelee generated AnimationTree", tree != null)
	if tree == null:
		player.queue_free()
		_finish()
		return

	var animation_player := _find_animation_player(player.get_node(^"Model"))
	_check("player AnimationPlayer exists", animation_player != null)
	var root_blend := tree.tree_root as AnimationNodeBlendTree
	_check("AnimationTree root is BlendTree", root_blend != null)
	var state_machine: AnimationNodeStateMachine = null
	if root_blend != null:
		state_machine = root_blend.get_node(&"main") as AnimationNodeStateMachine
	_check("AnimationTree main is StateMachine", state_machine != null)
	if animation_player != null and state_machine != null:
		_verify_assignments(animation_player, state_machine)
		_check("katana_1 transitions to katana_2",
			state_machine.has_transition(&"katana_1", &"katana_2"))
		_check("katana_2 transitions to katana finisher",
			state_machine.has_transition(&"katana_2", &"katana"))
		_verify_legacy_states(root_blend, state_machine)
		var playback := tree.get("parameters/main/playback") as AnimationNodeStateMachinePlayback
		var weapon: Node = player.get_node(^"PlayerWeapon")
		# プレイヤーは素手で始まる（PlayerWeapon._ready が unequip する）。
		# 銃の locomotion を見る前に装備させる。
		weapon.call("equip_gun")
		await process_frame
		_check("gun equip selects gun motion inside locomotion", playback != null
			and playback.get_current_node() == &"locomotion"
			and is_equal_approx(float(tree.get(GUN_SELECT_PARAMETER)), 1.0)
			and is_zero_approx(float(tree.get(KATANA_SELECT_PARAMETER))))
		weapon.call("equip_katana")
		await process_frame
		_check("katana equip selects sword idle inside locomotion", playback != null
			and playback.get_current_node() == &"locomotion"
			and is_zero_approx(float(tree.get(GUN_SELECT_PARAMETER)))
			and is_equal_approx(float(tree.get(KATANA_SELECT_PARAMETER)), 1.0))
		melee.call("set_locomotion", SWORD_IDLE_BLEND_OUT_SPEED)
		_check("katana movement returns to default locomotion",
			is_zero_approx(float(tree.get(KATANA_SELECT_PARAMETER))))
		melee.call("set_locomotion", 0.0)
		_check("katana stop returns to sword idle",
			is_equal_approx(float(tree.get(KATANA_SELECT_PARAMETER)), 1.0))
		weapon.call("unequip")
		await process_frame
		_check("unequip returns to default locomotion", playback != null
			and playback.get_current_node() == &"locomotion"
			and is_zero_approx(float(tree.get(GUN_SELECT_PARAMETER)))
			and is_zero_approx(float(tree.get(KATANA_SELECT_PARAMETER))))
		weapon.call("equip_gun")
		await process_frame
		_check("re-equip selects gun motion inside locomotion", playback != null
			and playback.get_current_node() == &"locomotion"
			and is_equal_approx(float(tree.get(GUN_SELECT_PARAMETER)), 1.0)
			and is_zero_approx(float(tree.get(KATANA_SELECT_PARAMETER))))
		_print_timing(player, tree)

	player.queue_free()
	await process_frame
	_finish()


func _verify_source_clip(spec: Dictionary) -> void:
	var clip_id := StringName(spec["id"])
	var file_name: String = String(spec["file"])
	var scene_path: String = MOTION_DIRECTORY + file_name
	var packed := load(scene_path) as PackedScene
	_check("%s loads" % file_name, packed != null)
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	var skeleton: Skeleton3D = _find_skeleton(instance)
	var animation_player: AnimationPlayer = _find_animation_player(instance)
	var animation: Animation = _find_exact_animation(animation_player, SOURCE_ANIMATION_KEY)
	var skeleton_ok: bool = skeleton != null and skeleton.name == GENERAL_SKELETON_NAME
	var bone_ok: bool = skeleton != null and skeleton.find_bone(RETARGET_PROBE_BONE) >= 0
	var track_ok: bool = animation != null and _has_profile_bone_track(animation,
		RETARGET_PROBE_BONE)
	_check("%s uses GeneralSkeleton" % file_name, skeleton_ok)
	_check("%s has RightHand profile bone" % file_name, bone_ok)
	_check("%s animation '%s' exists" % [file_name, SOURCE_ANIMATION_KEY], animation != null)
	_check("%s tracks target profile bones" % file_name, track_ok)
	if animation != null:
		_source_lengths[clip_id] = animation.length
		if clip_id == &"katana_2":
			_check("katana_2 source length is 2.400s",
				is_equal_approx(animation.length, SECOND_KATANA_SOURCE_LENGTH))
		if clip_id == &"gun_walk":
			_check("gun_walk source length is 0.800s",
				is_equal_approx(animation.length, PISTOL_WALK_SOURCE_LENGTH))
			_check("gun_walk has 53 animation tracks",
				animation.get_track_count() == PISTOL_WALK_TRACK_COUNT)
			_check("gun_walk skeleton has 65 bones", skeleton != null \
				and skeleton.get_bone_count() == GENERAL_SKELETON_BONE_COUNT)
			var horizontal_travel: float = RootMotion.horizontal_travel(animation)
			_check("gun_walk source is In Place",
				horizontal_travel <= IN_PLACE_ROOT_MOTION_EPSILON)
			print("[root_motion] id=gun_walk horizontal_travel=%.3fm in_place=%s" % [
				horizontal_travel,
				str(horizontal_travel <= IN_PLACE_ROOT_MOTION_EPSILON)])
		if clip_id == &"katana_idle":
			_check("katana_idle source length is 1.833s",
				absf(animation.length - SWORD_IDLE_SOURCE_LENGTH) <= CLIP_LENGTH_TOLERANCE)
			var sword_horizontal_travel: float = RootMotion.horizontal_travel(animation)
			_check("katana_idle source is In Place",
				sword_horizontal_travel <= IN_PLACE_ROOT_MOTION_EPSILON)
			print("[root_motion] id=katana_idle horizontal_travel=%.3fm in_place=%s" % [
				sword_horizontal_travel,
				str(sword_horizontal_travel <= IN_PLACE_ROOT_MOTION_EPSILON)])
		print("[clip] id=%s file=%s animation=%s length=%.3fs tracks=%d skeleton=%s retarget=%s" % [
			String(clip_id), file_name, SOURCE_ANIMATION_KEY, animation.length,
			animation.get_track_count(), String(skeleton.name) if skeleton != null else "(none)",
			str(skeleton_ok and bone_ok and track_ok)])
	instance.free()


func _verify_assignments(animation_player: AnimationPlayer,
		state_machine: AnimationNodeStateMachine) -> void:
	print("=== AnimationLibrary / StateMachine assignment verification ===")
	for spec: Dictionary in CLIP_SPECS:
		var clip_id := StringName(spec["id"])
		var library_name := StringName(spec["library"])
		var state_name := StringName(spec["state"])
		if clip_id == &"death":
			var death_library_absent: bool = not animation_player.has_animation(
				StringName(PLAYER_LIBRARY_PREFIX + "death"))
			var death_state_absent: bool = not state_machine.has_node(&"death")
			_check("death clip is not assigned over recoverable down", death_library_absent
				and death_state_absent)
			print("[state] id=death assigned=false reason=no_separate_player_death_state")
			continue
		var full_animation_name := StringName(PLAYER_LIBRARY_PREFIX + String(library_name))
		var library_ok: bool = animation_player.has_animation(full_animation_name)
		var state_ok: bool = state_machine.has_node(state_name)
		var node_ok: bool = false
		if state_ok and (clip_id == &"gun_idle" or clip_id == &"gun_walk"):
			node_ok = _gun_locomotion_has_animation(state_machine, full_animation_name)
		elif state_ok and clip_id == &"katana_idle":
			node_ok = _katana_locomotion_has_animation(state_machine, full_animation_name)
		elif state_ok:
			node_ok = _action_state_has_animation(state_machine, state_name,
				full_animation_name)
		_check("%s is in player AnimationLibrary" % String(clip_id), library_ok)
		_check("%s state exists" % String(clip_id), state_ok)
		_check("%s state references %s" % [String(clip_id), String(full_animation_name)], node_ok)
		if library_ok and clip_id == &"gun_walk":
			var assigned_animation: Animation = animation_player.get_animation(full_animation_name)
			_check("gun_walk assigned clip loops",
				assigned_animation.loop_mode == Animation.LOOP_LINEAR)
			_check("gun_walk assigned clip remains In Place",
				RootMotion.horizontal_travel(assigned_animation) <= IN_PLACE_ROOT_MOTION_EPSILON)
		if clip_id == &"gun_walk":
			_check("gun_walk is the 1.000 blend point", is_equal_approx(
				_gun_locomotion_animation_position(state_machine, full_animation_name),
				GUN_WALK_BLEND_POSITION))
		if library_ok and clip_id == &"katana_idle":
			var assigned_sword_idle: Animation = animation_player.get_animation(full_animation_name)
			_check("katana_idle assigned clip loops",
				assigned_sword_idle.loop_mode == Animation.LOOP_LINEAR)
			_check("katana_idle assigned clip remains In Place",
				RootMotion.horizontal_travel(assigned_sword_idle) <= IN_PLACE_ROOT_MOTION_EPSILON)
		print("[state] id=%s library=%s state=%s assigned=%s" % [String(clip_id),
			String(full_animation_name), String(state_name), str(library_ok and state_ok and node_ok)])


func _print_timing(player: CharacterBody3D, tree: AnimationTree) -> void:
	var action: Node = player.get_node(^"PlayerAction")
	var katana: Node = player.get_node(^"PlayerKatanaCombo")
	for stage: int in range(FIRST_KATANA_STAGE, FINAL_KATANA_STAGE + 1):
		var windup: float = float(katana.call("stage_windup", stage))
		var active: float = float(katana.call("stage_active", stage))
		var recovery: float = float(katana.call("stage_recovery", stage))
		var duration: float = float(katana.call("stage_duration", stage))
		var ratio: float = float(katana.call("stage_contact_ratio", stage))
		var contact: float = duration * ratio
		var clip_id := StringName("katana_%d" % stage)
		var clip_length: float = _length(clip_id)
		_check("katana stage %d contact marker is inside active window" % stage,
			contact >= windup and contact <= windup + active)
		if stage == SECOND_KATANA_STAGE:
			_check("katana stage 2 duration remains 0.600s",
				is_equal_approx(duration, SECOND_KATANA_DURATION))
			_check("katana stage 2 playback scale is 4.000x",
				is_equal_approx(_scale(clip_length, duration), SECOND_KATANA_SPEED_SCALE))
		print("[timing] katana_stage=%d clip=%.3fs duration=%.3fs scale=%.3fx windup=0.000-%.3fs active=%.3f-%.3fs recovery=%.3f-%.3fs contact=%.3fs(%.0f%%) damage=%.1f reach=%.2fm" % [
			stage, clip_length, duration, _scale(clip_length, duration), windup,
			windup, windup + active, windup + active, duration, contact, ratio * 100.0,
			float(katana.call("stage_damage", stage)),
			float(katana.call("stage_reach", stage))])

	var dodge_duration: float = float(player.get("dodge_duration"))
	var dodge_iframes: float = float(player.get("dodge_iframes"))
	var dodge_length: float = _length(&"dodge")
	print("[timing] dodge clip=%.3fs duration=%.3fs scale=%.3fx iframes=0.000-%.3fs" % [
		dodge_length, dodge_duration, _scale(dodge_length, dodge_duration), dodge_iframes])


	var special_duration: float = float(action.get("special_cooldown"))
	var special_ratio: float = float(action.get("special_impact_ratio"))
	var special_length: float = _length(&"special")
	var special_impact: float = special_duration * special_ratio
	var lunge_start: float = float(action.get("special_lunge_start_time"))
	var lunge_speed: float = float(action.get("special_lunge_speed"))
	var lunge_distance: float = float(action.get("special_lunge_distance"))
	var lunge_end: float = lunge_start
	if lunge_speed > 0.0:
		lunge_end += lunge_distance / lunge_speed
	var physics_frame: float = 1.0 / float(Engine.physics_ticks_per_second)
	# 走り出しは素材の先頭に来ているので lunge_start は 0.000 秒でよい（0 も許す）。
	_check("special lunge starts during run-up", lunge_start >= 0.0
		and lunge_start < special_impact)
	_check("special lunge completes within one physics frame of impact",
		lunge_end <= special_impact and special_impact - lunge_end <= physics_frame)
	print("[timing] special clip=%.3fs duration=%.3fs scale=%.3fx lunge=%.3f-%.3fs speed=%.2fm/s distance=%.2fm impact=%.3fs(%.0f%%) radius=%.2fm front=%.2fx%.2fm cooldown=%.3fs" % [
		special_length, special_duration, _scale(special_length, special_duration),
		lunge_start, lunge_end, lunge_speed, lunge_distance, special_impact,
		special_ratio * 100.0, float(action.get("special_radius")),
		float(action.get("special_front_distance")), float(action.get("special_front_width")),
		special_duration])

	var melee: Node = player.get_node(^"PlayerMelee")
	var action_anim: Node = player.get_node(^"PlayerActionAnim")
	var max_speed: float = float(melee.get("locomotion_max_speed"))
	var walk_reference: float = float(action_anim.get("pistol_walk_reference_speed"))
	var maximum_playback_scale: float = float(
		action_anim.get("pistol_walk_max_playback_scale"))
	var sword_idle_blend_out_speed: float = float(
		action_anim.get("katana_idle_blend_out_speed"))
	var max_speed_scale: float = minf(max_speed / walk_reference, maximum_playback_scale)
	_check("gun walk natural speed is 2.09m/s",
		is_equal_approx(walk_reference, PISTOL_WALK_NATURAL_SPEED))
	_check("gun walk playback limit is 2.200x",
		is_equal_approx(maximum_playback_scale, PISTOL_WALK_MAX_PLAYBACK_SCALE))
	_check("locomotion maximum speed remains 4.500m/s",
		is_equal_approx(max_speed, DEFAULT_LOCOMOTION_MAX_SPEED))
	_check("katana idle fully blends out by 0.100m/s",
		is_equal_approx(sword_idle_blend_out_speed, SWORD_IDLE_BLEND_OUT_SPEED))
	melee.call("set_locomotion", walk_reference)
	_check("gun walk point is selected at 2.090m/s",
		is_equal_approx(float(tree.get(GUN_BLEND_POSITION_PARAMETER)),
			GUN_WALK_BLEND_POSITION))
	_check("gun walk natural speed applies 1.000x playback",
		is_equal_approx(float(tree.get(GUN_SPEED_SCALE_PARAMETER)),
			NATURAL_PLAYBACK_SCALE))
	melee.call("set_locomotion", max_speed)
	_check("gun walk remains selected at 4.500m/s",
		is_equal_approx(float(tree.get(GUN_BLEND_POSITION_PARAMETER)),
			GUN_WALK_BLEND_POSITION))
	_check("gun walk applies 2.153x playback at 4.500m/s",
		is_equal_approx(float(tree.get(GUN_SPEED_SCALE_PARAMETER)), max_speed_scale))
	print("[timing] gun_idle clip=%.3fs loop=true; gun_walk clip=%.3fs loop=true in_place=true natural=%.2fm/s idle_to_walk=0.000-%.3fm/s playback_at_natural=1.000x playback_at_%.3fm/s=%.3fx limit=%.3fx" % [
		_length(&"gun_idle"), _length(&"gun_walk"), walk_reference, walk_reference,
		max_speed, max_speed_scale, maximum_playback_scale])
	print("[timing] katana_idle clip=%.3fs loop=true in_place=true sword_idle_to_default=0.000-%.3fm/s" % [
		_length(&"katana_idle"), sword_idle_blend_out_speed])
	print("[timing] death clip=%.3fs assigned=false; down/stand_up recovery preserved" %
		_length(&"death"))


func _verify_legacy_states(root_blend: AnimationNodeBlendTree,
		state_machine: AnimationNodeStateMachine) -> void:
	var legacy_states: Array[StringName] = [&"locomotion", &"melee_1", &"melee_2", &"melee_3",
		&"kick_1", &"kick_2", &"kick_3", &"dance", &"down", &"stand_up"]
	for state_name: StringName in legacy_states:
		_check("legacy state remains: %s" % String(state_name), state_machine.has_node(state_name))
	var locomotion := state_machine.get_node(&"locomotion") as AnimationNodeBlendTree
	var gun_select: AnimationNodeBlend2 = null
	var gun_blend: AnimationNodeBlendSpace1D = null
	var katana_select: AnimationNodeBlend2 = null
	var katana_idle: AnimationNodeAnimation = null
	if locomotion != null:
		gun_select = locomotion.get_node(&"gun_select") as AnimationNodeBlend2
		katana_select = locomotion.get_node(&"katana_select") as AnimationNodeBlend2
		katana_idle = locomotion.get_node(&"katana_idle") as AnimationNodeAnimation
		var gun_tree := locomotion.get_node(&"gun") as AnimationNodeBlendTree
		if gun_tree != null:
			gun_blend = gun_tree.get_node(&"blend") as AnimationNodeBlendSpace1D
	_check("gun selector is nested in legacy locomotion", gun_select != null)
	_check("gun locomotion has only idle and walk blend points", gun_blend != null \
		and gun_blend.get_blend_point_count() == EXPECTED_GUN_BLEND_POINT_COUNT)
	_check("katana selector is nested in legacy locomotion", katana_select != null)
	_check("katana idle node is nested in legacy locomotion", katana_idle != null)
	_check("hurt Blend2 layer remains", root_blend.has_node(&"hurt_blend"))


func _action_state_has_animation(state_machine: AnimationNodeStateMachine, state_name: StringName,
		animation_name: StringName) -> bool:
	var action_tree := state_machine.get_node(state_name) as AnimationNodeBlendTree
	if action_tree == null:
		return false
	var clip_node := action_tree.get_node(&"clip") as AnimationNodeAnimation
	return clip_node != null and clip_node.animation == animation_name


func _gun_locomotion_has_animation(state_machine: AnimationNodeStateMachine,
		animation_name: StringName) -> bool:
	return _gun_locomotion_animation_position(state_machine, animation_name) >= 0.0


func _gun_locomotion_animation_position(state_machine: AnimationNodeStateMachine,
		animation_name: StringName) -> float:
	var locomotion := state_machine.get_node(&"locomotion") as AnimationNodeBlendTree
	if locomotion == null:
		return -1.0
	var gun_tree := locomotion.get_node(&"gun") as AnimationNodeBlendTree
	if gun_tree == null:
		return -1.0
	var blend := gun_tree.get_node(&"blend") as AnimationNodeBlendSpace1D
	if blend == null:
		return -1.0
	for point_index: int in range(blend.get_blend_point_count()):
		var clip_node := blend.get_blend_point_node(point_index) as AnimationNodeAnimation
		if clip_node != null and clip_node.animation == animation_name:
			return blend.get_blend_point_position(point_index)
	return -1.0


func _katana_locomotion_has_animation(state_machine: AnimationNodeStateMachine,
		animation_name: StringName) -> bool:
	var locomotion := state_machine.get_node(&"locomotion") as AnimationNodeBlendTree
	if locomotion == null:
		return false
	var idle_node := locomotion.get_node(&"katana_idle") as AnimationNodeAnimation
	return idle_node != null and idle_node.animation == animation_name


func _find_exact_animation(animation_player: AnimationPlayer, animation_key: String) -> Animation:
	if animation_player == null:
		return null
	if animation_player.has_animation(animation_key):
		return animation_player.get_animation(animation_key)
	for animation_name: String in animation_player.get_animation_list():
		if animation_name.ends_with("/" + animation_key):
			return animation_player.get_animation(animation_name)
	return null


func _has_profile_bone_track(animation: Animation, bone_name: StringName) -> bool:
	for track_index: int in range(animation.get_track_count()):
		var track_path: NodePath = animation.track_get_path(track_index)
		if String(track_path).get_slice(":", 1) == String(bone_name):
			return true
	return false


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null


func _length(clip_id: StringName) -> float:
	return float(_source_lengths.get(clip_id, 0.0))


func _scale(clip_length: float, duration: float) -> float:
	return clip_length / duration if duration > 0.0 else 1.0


func _check(label: String, condition: bool) -> void:
	_checks += 1
	if condition:
		_passes += 1
		print("[PASS] ", label)
		return
	_failures += 1
	print("[FAIL] ", label)


func _finish() -> void:
	print("=== result: PASS=%d FAIL=%d CHECKS=%d ===" % [_passes, _failures, _checks])
	quit(0 if _failures == 0 else 1)
