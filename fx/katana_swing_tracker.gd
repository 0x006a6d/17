extends RefCounted

## 刀身方向の角速度から、斬撃円弧を置く3D回転面を求める。

const MIN_BLADE_LENGTH: float = 0.20
const MIN_ANGULAR_STEP: float = 0.003
const PLANE_SMOOTHING: float = 0.35

var _holder: WeaponHolder = null
var _weapon: Node3D = null
var _blade_tip_local: Vector3 = Vector3.ZERO
var _last_direction: Vector3 = Vector3.ZERO
var _plane_normal: Vector3 = Vector3.ZERO
var _swing_transform: Transform3D = Transform3D.IDENTITY
var _blade_radius: float = 0.0
var _valid: bool = false
var _locked: bool = false


func configure(holder: WeaponHolder) -> void:
	_holder = holder


func begin_stage() -> void:
	_weapon = _holder.current_weapon() if _holder != null else null
	_last_direction = Vector3.ZERO
	_plane_normal = Vector3.ZERO
	_swing_transform = Transform3D.IDENTITY
	_blade_radius = 0.0
	_valid = false
	_locked = false
	_resolve_blade_tip()


func sample(lock_at_current_pose: bool) -> bool:
	if _locked:
		return _valid
	if not is_instance_valid(_weapon):
		_weapon = _holder.current_weapon() if _holder != null else null
		_resolve_blade_tip()
	if _weapon == null:
		return false
	var center: Vector3 = _weapon.global_position
	var tip: Vector3 = _weapon.to_global(_blade_tip_local)
	var radius_vector: Vector3 = tip - center
	_blade_radius = radius_vector.length()
	if _blade_radius < MIN_BLADE_LENGTH:
		return false
	var blade_direction: Vector3 = radius_vector / _blade_radius
	if not _last_direction.is_zero_approx():
		var angular_normal: Vector3 = _last_direction.cross(blade_direction)
		if angular_normal.length() >= MIN_ANGULAR_STEP:
			angular_normal = angular_normal.normalized()
			if not _plane_normal.is_zero_approx():
				if angular_normal.dot(_plane_normal) < 0.0:
					angular_normal = -angular_normal
				_plane_normal = _plane_normal.slerp(
					angular_normal, PLANE_SMOOTHING).normalized()
			else:
				_plane_normal = angular_normal
	_last_direction = blade_direction
	if _plane_normal.is_zero_approx():
		return false
	# 正の角度が刀の進行方向。弧は負角側から現在の刀身方向へ伸ばす。
	var tangent: Vector3 = _plane_normal.cross(blade_direction).normalized()
	_swing_transform = Transform3D(
		Basis(blade_direction, tangent, _plane_normal).orthonormalized(), center)
	_valid = true
	if lock_at_current_pose:
		_locked = true
	return true


func swing_transform() -> Transform3D:
	return _swing_transform


func blade_radius() -> float:
	return _blade_radius


func blade_direction() -> Vector3:
	return _last_direction


func plane_normal() -> Vector3:
	return _plane_normal


func _resolve_blade_tip() -> void:
	if _weapon == null:
		return
	var bounds := AABB()
	var found_bounds: bool = false
	for mesh_instance: MeshInstance3D in _mesh_descendants(_weapon):
		if mesh_instance.mesh == null:
			continue
		var local_transform: Transform3D = _weapon.global_transform.affine_inverse() \
			* mesh_instance.global_transform
		var local_bounds: AABB = local_transform * mesh_instance.get_aabb()
		bounds = bounds.merge(local_bounds) if found_bounds else local_bounds
		found_bounds = true
	if not found_bounds:
		_weapon = null
		return
	var axis: int = _longest_axis(bounds.size)
	var minimum: float = bounds.position[axis]
	var maximum: float = minimum + bounds.size[axis]
	var tip_scalar: float = maximum if absf(maximum) >= absf(minimum) else minimum
	_blade_tip_local = bounds.get_center()
	_blade_tip_local[axis] = tip_scalar


func _mesh_descendants(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		found.append(root as MeshInstance3D)
	for child: Node in root.get_children():
		found.append_array(_mesh_descendants(child))
	return found


func _longest_axis(size: Vector3) -> int:
	if size.x >= size.y and size.x >= size.z:
		return Vector3.AXIS_X
	if size.y >= size.z:
		return Vector3.AXIS_Y
	return Vector3.AXIS_Z
