extends RefCounted
class_name PlayerWeaponGripSolver

## SkeletonModifier3D から使う、握り軸の円柱表面に関節を接地させる有界角度ソルバー。

const MIN_AXIS_LENGTH_SQUARED: float = 0.00000001
const MIN_SCAN_STEPS: int = 2

var _skeleton: Skeleton3D = null
var _axis_start_world: Vector3 = Vector3.ZERO
var _axis_end_world: Vector3 = Vector3.ZERO
var _grip_radius: float = 0.0
var _surface_tolerance: float = 0.0
var _scan_steps: int = MIN_SCAN_STEPS
var _refinement_iterations: int = 0


func configure_frame(skeleton: Skeleton3D, axis_start_world: Vector3,
		axis_end_world: Vector3, grip_radius: float, surface_tolerance: float,
		scan_steps: int, refinement_iterations: int) -> void:
	_skeleton = skeleton
	_axis_start_world = axis_start_world
	_axis_end_world = axis_end_world
	_grip_radius = maxf(grip_radius, 0.0)
	_surface_tolerance = maxf(surface_tolerance, 0.0)
	_scan_steps = maxi(scan_steps, MIN_SCAN_STEPS)
	_refinement_iterations = maxi(refinement_iterations, 0)


## 可動域の小さい側から曲げ軸方向へ走査し、最初の表面交差を二分探索する。
## 交差が無い場合は、域内で誤差が最小の角度を局所的に絞り込む。
func solve_joint(joint_index: int, target_index: int,
		target_local_offset: Vector3, axis: Vector3, min_angle: float,
		max_angle: float, preferred_angle: float) -> Vector2:
	var lower_angle: float = minf(min_angle, max_angle)
	var upper_angle: float = maxf(min_angle, max_angle)
	var preferred: float = clampf(preferred_angle, lower_angle, upper_angle)
	var best_angle: float = lower_angle
	var best_error: float = _evaluate_angle(joint_index, target_index,
		target_local_offset, axis, lower_angle)
	var previous_angle: float = lower_angle
	var previous_error: float = best_error
	var bracket_found: bool = false
	var bracket_low_angle: float = lower_angle
	var bracket_high_angle: float = lower_angle
	var bracket_low_error: float = best_error

	if absf(best_error) > _surface_tolerance:
		for sample_index: int in range(1, _scan_steps + 1):
			var sample_ratio: float = float(sample_index) / float(_scan_steps)
			var sample_angle: float = lerpf(lower_angle, upper_angle, sample_ratio)
			var sample_error: float = _evaluate_angle(joint_index, target_index,
				target_local_offset, axis, sample_angle)
			if _is_better_solution(sample_error, sample_angle, best_error,
					best_angle, preferred):
				best_angle = sample_angle
				best_error = sample_error
			if _crosses_surface(previous_error, sample_error):
				bracket_found = true
				bracket_low_angle = previous_angle
				bracket_high_angle = sample_angle
				bracket_low_error = previous_error
				break
			previous_angle = sample_angle
			previous_error = sample_error

	if bracket_found:
		for _iteration: int in range(_refinement_iterations):
			var middle_angle: float = (bracket_low_angle + bracket_high_angle) * 0.5
			var middle_error: float = _evaluate_angle(joint_index, target_index,
				target_local_offset, axis, middle_angle)
			if _is_better_solution(middle_error, middle_angle, best_error,
					best_angle, preferred):
				best_angle = middle_angle
				best_error = middle_error
			if absf(middle_error) <= _surface_tolerance:
				break
			if _crosses_surface(bracket_low_error, middle_error):
				bracket_high_angle = middle_angle
			else:
				bracket_low_angle = middle_angle
				bracket_low_error = middle_error
	else:
		var refine_step: float = (upper_angle - lower_angle) / float(_scan_steps)
		for _iteration: int in range(_refinement_iterations):
			if absf(best_error) <= _surface_tolerance:
				break
			refine_step *= 0.5
			var center_angle: float = best_angle
			var left_angle: float = clampf(center_angle - refine_step,
				lower_angle, upper_angle)
			var left_error: float = _evaluate_angle(joint_index, target_index,
				target_local_offset, axis, left_angle)
			if _is_better_solution(left_error, left_angle, best_error,
					best_angle, preferred):
				best_angle = left_angle
				best_error = left_error
			var right_angle: float = clampf(center_angle + refine_step,
				lower_angle, upper_angle)
			var right_error: float = _evaluate_angle(joint_index, target_index,
				target_local_offset, axis, right_angle)
			if _is_better_solution(right_error, right_angle, best_error,
					best_angle, preferred):
				best_angle = right_angle
				best_error = right_error

	_apply_bone_rotation(joint_index, axis, best_angle)
	_skeleton.force_update_bone_child_transform(joint_index)
	return Vector2(best_angle, best_error)


func bone_world_position(bone_index: int) -> Vector3:
	return _skeleton.global_transform \
		* _skeleton.get_bone_global_pose(bone_index).origin


## 最終節に子ボーンが無いため、直前の節長と方向を最終節ローカルへ変換する。
func virtual_tip_extension(parent_index: int, distal_index: int) -> Vector3:
	var parent_pose: Transform3D = _skeleton.get_bone_global_pose(parent_index)
	var distal_pose: Transform3D = _skeleton.get_bone_global_pose(distal_index)
	var segment: Vector3 = distal_pose.origin - parent_pose.origin
	if segment.length_squared() <= MIN_AXIS_LENGTH_SQUARED:
		return Vector3.ZERO
	return distal_pose.basis.inverse() * segment


func surface_error(point_world: Vector3) -> float:
	var segment: Vector3 = _axis_end_world - _axis_start_world
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared <= MIN_AXIS_LENGTH_SQUARED:
		return point_world.distance_to(_axis_start_world) - _grip_radius
	var ratio: float = clampf(
		(point_world - _axis_start_world).dot(segment) / segment_length_squared,
		0.0, 1.0)
	var nearest: Vector3 = _axis_start_world + segment * ratio
	return point_world.distance_to(nearest) - _grip_radius


func _evaluate_angle(joint_index: int, target_index: int,
		target_local_offset: Vector3, axis: Vector3, angle_degrees: float) -> float:
	_apply_bone_rotation(joint_index, axis, angle_degrees)
	_skeleton.force_update_bone_child_transform(joint_index)
	var bone_pose: Transform3D = _skeleton.get_bone_global_pose(target_index)
	var skeleton_position: Vector3 = bone_pose * target_local_offset
	var target_world: Vector3 = _skeleton.global_transform * skeleton_position
	return surface_error(target_world)


func _apply_bone_rotation(bone_index: int, axis: Vector3,
		angle_degrees: float) -> void:
	if bone_index < 0 or axis.is_zero_approx():
		return
	_skeleton.set_bone_pose_rotation(bone_index,
		Quaternion(axis.normalized(), deg_to_rad(angle_degrees)))


func _crosses_surface(first_error: float, second_error: float) -> bool:
	return is_zero_approx(first_error) or is_zero_approx(second_error) \
		or (first_error < 0.0 and second_error > 0.0) \
		or (first_error > 0.0 and second_error < 0.0)


func _is_better_solution(candidate_error: float, candidate_angle: float,
		best_error: float, best_angle: float, preferred_angle: float) -> bool:
	var candidate_absolute: float = absf(candidate_error)
	var best_absolute: float = absf(best_error)
	if candidate_absolute < best_absolute and not is_equal_approx(
			candidate_absolute, best_absolute):
		return true
	if is_equal_approx(candidate_absolute, best_absolute):
		return absf(candidate_angle - preferred_angle) \
			< absf(best_angle - preferred_angle)
	return false
