extends PlayerWeaponGripModifier
class_name EnemyLeftGripModifier

## 左手の指を武器へ巻き付ける SkeletonModifier。
##
## 元の `PlayerWeaponGripModifier` はボーン名の定数が全部 `Right*` で、右手しか曲げない。
## 両手で構える長物では左手が添えるだけの形のまま残るため、左手用をここに分ける。
## プレイヤー側の部品には手を入れない。
##
## 解く仕組み（`player_weapon_grip_solver.gd`）と、関節を1本ずつ接地させる
## `_solve_chain()` はそのまま使う。差し替えるのはボーン名だけ。
##
## 武器そのものは右手に付いているので、武器のワールド変換を右手から求める
## `_resolve_world_axis()` は上書きしない。左右で違うのは指の出どころだけ。

const LEFT_HAND: StringName = &"LeftHand"
const LEFT_THUMB_METACARPAL: StringName = &"LeftThumbMetacarpal"
const LEFT_THUMB_PROXIMAL: StringName = &"LeftThumbProximal"
const LEFT_THUMB_DISTAL: StringName = &"LeftThumbDistal"
const LEFT_INDEX_PROXIMAL: StringName = &"LeftIndexProximal"
const LEFT_INDEX_INTERMEDIATE: StringName = &"LeftIndexIntermediate"
const LEFT_INDEX_DISTAL: StringName = &"LeftIndexDistal"
const LEFT_MIDDLE_PROXIMAL: StringName = &"LeftMiddleProximal"
const LEFT_MIDDLE_INTERMEDIATE: StringName = &"LeftMiddleIntermediate"
const LEFT_MIDDLE_DISTAL: StringName = &"LeftMiddleDistal"
const LEFT_RING_PROXIMAL: StringName = &"LeftRingProximal"
const LEFT_RING_INTERMEDIATE: StringName = &"LeftRingIntermediate"
const LEFT_RING_DISTAL: StringName = &"LeftRingDistal"
const LEFT_LITTLE_PROXIMAL: StringName = &"LeftLittleProximal"
const LEFT_LITTLE_INTERMEDIATE: StringName = &"LeftLittleIntermediate"
const LEFT_LITTLE_DISTAL: StringName = &"LeftLittleDistal"


## 左手の指で解く。親の実装と手順は同じで、ボーン名だけ左手に差し替える。
func _apply_grip_pose() -> void:
	if not _resolve_skeleton() or not _resolve_world_axis():
		return
	_solver.configure_frame(_skeleton, _axis_start_world, _axis_end_world,
		_grip_radius, _surface_tolerance, _solver_scan_steps,
		_solver_refinement_iterations)
	_surface_errors.clear()
	_limited_joints.clear()
	_solve_chain(LEFT_INDEX_PROXIMAL, LEFT_INDEX_INTERMEDIATE, LEFT_INDEX_DISTAL,
		_finger_curl_axis, _finger_min_angles, _finger_max_angles)
	_solve_chain(LEFT_MIDDLE_PROXIMAL, LEFT_MIDDLE_INTERMEDIATE, LEFT_MIDDLE_DISTAL,
		_finger_curl_axis, _finger_min_angles, _finger_max_angles)
	_solve_chain(LEFT_RING_PROXIMAL, LEFT_RING_INTERMEDIATE, LEFT_RING_DISTAL,
		_finger_curl_axis, _finger_min_angles, _finger_max_angles)
	_solve_chain(LEFT_LITTLE_PROXIMAL, LEFT_LITTLE_INTERMEDIATE, LEFT_LITTLE_DISTAL,
		_finger_curl_axis, _finger_min_angles, _finger_max_angles)
	# 親指は4本指と逆軸で、木部の反対側から接地させる。
	_solve_chain(LEFT_THUMB_METACARPAL, LEFT_THUMB_PROXIMAL, LEFT_THUMB_DISTAL,
		_thumb_curl_axis, _thumb_min_angles, _thumb_max_angles)


## 右手（武器の付け根）と左手の指を両方引く。武器のワールド変換は右手から求めるので、
## `RightHand` も要る。
func _cache_bone_indices() -> void:
	var required_bones: Array[StringName] = [
		RIGHT_HAND, LEFT_HAND,
		LEFT_THUMB_METACARPAL, LEFT_THUMB_PROXIMAL, LEFT_THUMB_DISTAL,
		LEFT_INDEX_PROXIMAL, LEFT_INDEX_INTERMEDIATE, LEFT_INDEX_DISTAL,
		LEFT_MIDDLE_PROXIMAL, LEFT_MIDDLE_INTERMEDIATE, LEFT_MIDDLE_DISTAL,
		LEFT_RING_PROXIMAL, LEFT_RING_INTERMEDIATE, LEFT_RING_DISTAL,
		LEFT_LITTLE_PROXIMAL, LEFT_LITTLE_INTERMEDIATE, LEFT_LITTLE_DISTAL,
	]
	for bone_name: StringName in required_bones:
		var bone_index: int = _skeleton.find_bone(bone_name)
		_bone_indices[bone_name] = bone_index
		if bone_index < 0:
			push_warning("enemy_left_grip_modifier: ボーン %s が無い" % bone_name)
	_bones_cached = true
