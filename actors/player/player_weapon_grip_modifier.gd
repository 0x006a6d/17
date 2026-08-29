extends SkeletonModifier3D
class_name PlayerWeaponGripModifier

## AnimationTree が Skeleton3D へ書いた後、武器の握り軸と半径から
## 右手15指ボーンの接地角を解く。左手と手首以上のボーンは変更しない。

const GRIP_SOLVER_SCRIPT := preload("res://actors/player/player_weapon_grip_solver.gd")
const RIGHT_HAND: StringName = &"RightHand"
const THUMB_METACARPAL: StringName = &"RightThumbMetacarpal"
const THUMB_PROXIMAL: StringName = &"RightThumbProximal"
const THUMB_DISTAL: StringName = &"RightThumbDistal"
const INDEX_PROXIMAL: StringName = &"RightIndexProximal"
const INDEX_INTERMEDIATE: StringName = &"RightIndexIntermediate"
const INDEX_DISTAL: StringName = &"RightIndexDistal"
const MIDDLE_PROXIMAL: StringName = &"RightMiddleProximal"
const MIDDLE_INTERMEDIATE: StringName = &"RightMiddleIntermediate"
const MIDDLE_DISTAL: StringName = &"RightMiddleDistal"
const RING_PROXIMAL: StringName = &"RightRingProximal"
const RING_INTERMEDIATE: StringName = &"RightRingIntermediate"
const RING_DISTAL: StringName = &"RightRingDistal"
const LITTLE_PROXIMAL: StringName = &"RightLittleProximal"
const LITTLE_INTERMEDIATE: StringName = &"RightLittleIntermediate"
const LITTLE_DISTAL: StringName = &"RightLittleDistal"

const MIN_AXIS_LENGTH_SQUARED: float = 0.00000001
const ANGLE_LIMIT_EPSILON_DEGREES: float = 0.001
const MIN_SCAN_STEPS: int = 2

var _solver: GRIP_SOLVER_SCRIPT = GRIP_SOLVER_SCRIPT.new()
var _skeleton: Skeleton3D = null
var _bone_indices: Dictionary[StringName, int] = {}
var _bones_cached: bool = false
var _weapon: Node3D = null
var _axis_start_local: Vector3 = Vector3.ZERO
var _axis_end_local: Vector3 = Vector3.ZERO
var _axis_start_world: Vector3 = Vector3.ZERO
var _axis_end_world: Vector3 = Vector3.ZERO
var _grip_model_radius: float = 0.0
var _grip_radius: float = 0.0
var _finger_curl_axis: Vector3 = Vector3.ZERO
var _thumb_curl_axis: Vector3 = Vector3.ZERO
var _finger_min_angles: Vector3 = Vector3.ZERO
var _finger_max_angles: Vector3 = Vector3.ZERO
var _thumb_min_angles: Vector3 = Vector3.ZERO
var _thumb_max_angles: Vector3 = Vector3.ZERO
var _surface_tolerance: float = 0.0
var _solver_scan_steps: int = MIN_SCAN_STEPS
var _solver_refinement_iterations: int = 0
var _debug_solver_limits: bool = false
var _profile_label: StringName = &"none"
var _solved_angles: Dictionary[StringName, float] = {}
var _surface_errors: Dictionary[StringName, float] = {}
var _limited_joints: Dictionary[StringName, float] = {}
var _reported_failures: Dictionary[StringName, bool] = {}


func configure(weapon: Node3D, axis_start_local: Vector3, axis_end_local: Vector3,
		grip_model_radius: float, finger_axis: Vector3, thumb_axis: Vector3,
		finger_min_angles: Vector3, finger_max_angles: Vector3,
		thumb_min_angles: Vector3, thumb_max_angles: Vector3,
		surface_tolerance: float, solver_scan_steps: int,
		solver_refinement_iterations: int, debug_solver_limits: bool,
		profile_label: StringName) -> void:
	_weapon = weapon
	_axis_start_local = axis_start_local
	_axis_end_local = axis_end_local
	_grip_model_radius = maxf(grip_model_radius, 0.0)
	_finger_curl_axis = finger_axis.normalized()
	_thumb_curl_axis = thumb_axis.normalized()
	_finger_min_angles = finger_min_angles
	_finger_max_angles = finger_max_angles
	_thumb_min_angles = thumb_min_angles
	_thumb_max_angles = thumb_max_angles
	_surface_tolerance = maxf(surface_tolerance, 0.0)
	_solver_scan_steps = maxi(solver_scan_steps, MIN_SCAN_STEPS)
	_solver_refinement_iterations = maxi(solver_refinement_iterations, 0)
	_debug_solver_limits = debug_solver_limits
	_profile_label = profile_label
	_solved_angles.clear()
	_surface_errors.clear()
	_limited_joints.clear()
	_reported_failures.clear()


func clear_target() -> void:
	_weapon = null
	_profile_label = &"none"
	_solved_angles.clear()
	_surface_errors.clear()
	_limited_joints.clear()
	_reported_failures.clear()


## Godot 4.7 以前との互換入口。修正は通知シグナルではなく modifier 処理内で行う。
func _process_modification() -> void:
	_apply_grip_pose()


## Godot 4.7 の delta 付き入口。対象寸法から求める絶対姿勢なので delta は使用しない。
func _process_modification_with_delta(_delta: float) -> void:
	_apply_grip_pose()


func _apply_grip_pose() -> void:
	if not _resolve_skeleton() or not _resolve_world_axis():
		return
	_solver.configure_frame(_skeleton, _axis_start_world, _axis_end_world,
		_grip_radius, _surface_tolerance, _solver_scan_steps,
		_solver_refinement_iterations)
	_surface_errors.clear()
	_limited_joints.clear()
	_solve_chain(INDEX_PROXIMAL, INDEX_INTERMEDIATE, INDEX_DISTAL,
		_finger_curl_axis, _finger_min_angles, _finger_max_angles)
	_solve_chain(MIDDLE_PROXIMAL, MIDDLE_INTERMEDIATE, MIDDLE_DISTAL,
		_finger_curl_axis, _finger_min_angles, _finger_max_angles)
	_solve_chain(RING_PROXIMAL, RING_INTERMEDIATE, RING_DISTAL,
		_finger_curl_axis, _finger_min_angles, _finger_max_angles)
	_solve_chain(LITTLE_PROXIMAL, LITTLE_INTERMEDIATE, LITTLE_DISTAL,
		_finger_curl_axis, _finger_min_angles, _finger_max_angles)
	# 親指は4本指と逆軸で柄の反対側から接地させる。
	_solve_chain(THUMB_METACARPAL, THUMB_PROXIMAL, THUMB_DISTAL,
		_thumb_curl_axis, _thumb_min_angles, _thumb_max_angles)


func _resolve_skeleton() -> bool:
	if _skeleton == null:
		_skeleton = get_skeleton()
	if _skeleton == null:
		return false
	if not _bones_cached:
		_cache_bone_indices()
	return true


func _resolve_world_axis() -> bool:
	if _weapon == null or not is_instance_valid(_weapon) or _grip_model_radius <= 0.0:
		return false
	var hand_index: int = _bone_indices.get(RIGHT_HAND, -1)
	if hand_index < 0:
		return false
	# BoneAttachment3D の Node 更新順に依存せず、modifier が見ている最新の手姿勢を使う。
	var hand_world: Transform3D = _skeleton.global_transform \
		* _skeleton.get_bone_global_pose(hand_index)
	var weapon_world: Transform3D = hand_world * _weapon.transform
	_axis_start_world = weapon_world * _axis_start_local
	_axis_end_world = weapon_world * _axis_end_local
	_grip_radius = _scaled_grip_radius(weapon_world.basis)
	return _axis_start_world.distance_squared_to(_axis_end_world) \
		> MIN_AXIS_LENGTH_SQUARED and _grip_radius > 0.0


## 円形のモデル半径へ、握り軸に直交する2方向の実スケール平均を適用する。
## 現行武器は直交2方向が同率なので、異方性スケール後も円形のままになる。
func _scaled_grip_radius(weapon_basis: Basis) -> float:
	var axis_direction: Vector3 = (_axis_end_local - _axis_start_local).normalized()
	if axis_direction.is_zero_approx():
		return 0.0
	var perpendicular_a: Vector3 = axis_direction.cross(Vector3.UP)
	if perpendicular_a.is_zero_approx():
		perpendicular_a = axis_direction.cross(Vector3.RIGHT)
	perpendicular_a = perpendicular_a.normalized()
	var perpendicular_b: Vector3 = axis_direction.cross(perpendicular_a).normalized()
	var scale_a: float = (weapon_basis * perpendicular_a).length()
	var scale_b: float = (weapon_basis * perpendicular_b).length()
	return _grip_model_radius * (scale_a + scale_b) * 0.5


## FK で自身の回転が動かすのは子関節なので、first で second、second で
## third を接地させる。third は最終節を同じ長さだけ延長した仮想指先を接地させる。
func _solve_chain(first: StringName, second: StringName, third: StringName,
		axis: Vector3, min_angles: Vector3, max_angles: Vector3) -> void:
	var first_index: int = _bone_indices.get(first, -1)
	var second_index: int = _bone_indices.get(second, -1)
	var third_index: int = _bone_indices.get(third, -1)
	if first_index < 0 or second_index < 0 or third_index < 0 \
			or axis.is_zero_approx():
		return

	var root_error: float = _solver.surface_error(
		_solver.bone_world_position(first_index))
	_surface_errors[first] = root_error
	_report_fixed_root(first, root_error)

	var first_preferred: float = float(_solved_angles.get(first, min_angles.x))
	var first_result: Vector2 = _solver.solve_joint(first_index, second_index,
		Vector3.ZERO, axis, min_angles.x, max_angles.x, first_preferred)
	_solved_angles[first] = first_result.x
	_surface_errors[second] = first_result.y
	_report_joint_result(first, first_result, min_angles.x, max_angles.x)

	var second_preferred: float = float(_solved_angles.get(second, min_angles.y))
	var second_result: Vector2 = _solver.solve_joint(second_index, third_index,
		Vector3.ZERO, axis, min_angles.y, max_angles.y, second_preferred)
	_solved_angles[second] = second_result.x
	_surface_errors[third] = second_result.y
	_report_joint_result(second, second_result, min_angles.y, max_angles.y)

	var tip_extension: Vector3 = _solver.virtual_tip_extension(
		second_index, third_index)
	if tip_extension.is_zero_approx():
		return
	var third_preferred: float = float(_solved_angles.get(third, min_angles.z))
	var third_result: Vector2 = _solver.solve_joint(third_index, third_index,
		tip_extension, axis, min_angles.z, max_angles.z, third_preferred)
	_solved_angles[third] = third_result.x
	_report_joint_result(third, third_result, min_angles.z, max_angles.z)


func _report_fixed_root(bone_name: StringName, surface_error: float) -> void:
	if absf(surface_error) <= _surface_tolerance or not _debug_solver_limits:
		return
	var report_key: StringName = StringName("%s/%s/root" % [_profile_label, bone_name])
	if _reported_failures.has(report_key):
		return
	print("[grip_solver] profile=%s joint=%s root_unreachable error=%+.4fm" % [
		_profile_label, bone_name, surface_error])
	_reported_failures[report_key] = true


func _report_joint_result(bone_name: StringName, result: Vector2,
		min_angle: float, max_angle: float) -> void:
	if absf(result.y) <= _surface_tolerance:
		return
	var lower_angle: float = minf(min_angle, max_angle)
	var upper_angle: float = maxf(min_angle, max_angle)
	var clamped: bool = absf(result.x - lower_angle) <= ANGLE_LIMIT_EPSILON_DEGREES \
		or absf(result.x - upper_angle) <= ANGLE_LIMIT_EPSILON_DEGREES
	if clamped:
		_limited_joints[bone_name] = result.x
	if not _debug_solver_limits:
		return
	var suffix: String = "clamped" if clamped else "unresolved"
	var report_key: StringName = StringName("%s/%s/%s" % [
		_profile_label, bone_name, suffix])
	if _reported_failures.has(report_key):
		return
	print("[grip_solver] profile=%s joint=%s %s angle=%.2f error=%+.4fm" % [
		_profile_label, bone_name, suffix, result.x, result.y])
	_reported_failures[report_key] = true


func solved_angles() -> Dictionary[StringName, float]:
	return _copy_float_dictionary(_solved_angles)


func surface_errors() -> Dictionary[StringName, float]:
	return _copy_float_dictionary(_surface_errors)


func limited_joint_angles() -> Dictionary[StringName, float]:
	return _copy_float_dictionary(_limited_joints)


func _copy_float_dictionary(source: Dictionary[StringName, float]) \
		-> Dictionary[StringName, float]:
	var result: Dictionary[StringName, float] = {}
	for bone_name: StringName in source:
		result[bone_name] = source[bone_name]
	return result


func _cache_bone_indices() -> void:
	var required_bones: Array[StringName] = [
		RIGHT_HAND,
		THUMB_METACARPAL, THUMB_PROXIMAL, THUMB_DISTAL,
		INDEX_PROXIMAL, INDEX_INTERMEDIATE, INDEX_DISTAL,
		MIDDLE_PROXIMAL, MIDDLE_INTERMEDIATE, MIDDLE_DISTAL,
		RING_PROXIMAL, RING_INTERMEDIATE, RING_DISTAL,
		LITTLE_PROXIMAL, LITTLE_INTERMEDIATE, LITTLE_DISTAL,
	]
	for bone_name: StringName in required_bones:
		var bone_index: int = _skeleton.find_bone(bone_name)
		_bone_indices[bone_name] = bone_index
		if bone_index < 0:
			push_warning("player_weapon_grip_modifier: ボーン %s が無い" % bone_name)
	_bones_cached = true
