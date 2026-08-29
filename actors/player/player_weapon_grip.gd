extends Node
class_name PlayerWeaponGrip

## 武器装備中だけ、AnimationTree の出力後に右手の指を握り軸へ接地させる。
## SkeletonModifier3D は対象 Skeleton3D の子へ実行時に追加するため、VRM 内の構造へ
## シーン側から直接依存しない。素手では modifier を無効化し、アニメーションの指へ戻す。

enum GripProfile { NONE, PISTOL, KATANA }

const PLAYER_WEAPON_GRIP_MODIFIER := preload(
	"res://actors/player/player_weapon_grip_modifier.gd")

@export_group("Target")
@export var model_path: NodePath = ^"../Model"

@export_group("Curl axes")
## GeneralSkeleton の指ローカル軸。4本指と親指は柄を反対側から挟むため逆向き。
@export var finger_curl_axis: Vector3 = Vector3(0.0, 0.0, -1.0)
@export var thumb_curl_axis: Vector3 = Vector3(0.0, 0.0, 1.0)

@export_group("Joint limits (degrees)")
## x=Proximal、y=Intermediate、z=Distal。正の角度だけを握り込み方向に探索する。
@export var finger_min_angles: Vector3 = Vector3.ZERO
@export var finger_max_angles: Vector3 = Vector3(100.0, 120.0, 80.0)
## x=Metacarpal、y=Proximal、z=Distal。
@export var thumb_min_angles: Vector3 = Vector3.ZERO
@export var thumb_max_angles: Vector3 = Vector3(90.0, 110.0, 80.0)

@export_group("Solver")
## 柄表面と関節の距離誤差の許容値（m）。
@export_range(0.0001, 0.01, 0.0001) var surface_tolerance: float = 0.002
## 各関節の可動域を分割する初期探索数。
@export_range(2, 64, 1) var solver_scan_steps: int = 16
## 最良区間を縮める追加反復の上限。
@export_range(0, 16, 1) var solver_refinement_iterations: int = 8
## 未解決または可動域端へクランプした関節を1回だけ出力する。
@export var debug_solver_limits: bool = false
@export_group("")

var _skeleton: Skeleton3D = null
var _modifier: PLAYER_WEAPON_GRIP_MODIFIER = null
var _profile: int = GripProfile.NONE
var _weapon: Node3D = null
var _axis_start_local: Vector3 = Vector3.ZERO
var _axis_end_local: Vector3 = Vector3.ZERO
var _grip_model_radius: float = 0.0


func _ready() -> void:
	if not setup(false):
		call_deferred("setup")


## 動的にモデルを差し込む敵でも使えるよう、モデル生成後に再実行できる初期化入口。
func setup(warn_on_failure: bool = true) -> bool:
	if _modifier != null and is_instance_valid(_modifier):
		return true
	var model: Node = get_node_or_null(model_path)
	if model == null:
		if warn_on_failure:
			push_warning("weapon_grip: Model が見つからない")
		return false
	_skeleton = _find_skeleton(model)
	if _skeleton == null:
		if warn_on_failure:
			push_warning("weapon_grip: Skeleton3D が見つからない")
		return false
	_modifier = PLAYER_WEAPON_GRIP_MODIFIER.new()
	_modifier.name = &"RightHandWeaponGripModifier"
	_modifier.active = false
	_skeleton.add_child(_modifier)
	_sync_modifier_profile()
	return true


func use_pistol_grip() -> void:
	_set_profile(GripProfile.PISTOL)


func use_katana_grip() -> void:
	_set_profile(GripProfile.KATANA)


## PlayerWeapon が所有するメッシュ実測値を、装備中のモデルと結び付ける。
## modifier はローカル線分をワールド線分へ変換し、モデル半径へ実スケールを適用する。
func set_grip_geometry(weapon: Node3D, axis_start_local: Vector3,
		axis_end_local: Vector3, model_radius: float) -> void:
	_weapon = weapon
	_axis_start_local = axis_start_local
	_axis_end_local = axis_end_local
	_grip_model_radius = maxf(model_radius, 0.0)
	_sync_modifier_profile()


func clear_grip() -> void:
	_set_profile(GripProfile.NONE)


func is_grip_active() -> bool:
	return _profile != GripProfile.NONE and _modifier != null and _modifier.active


func profile() -> int:
	return _profile


func _set_profile(value: int) -> void:
	_profile = value
	_sync_modifier_profile()


func _sync_modifier_profile() -> void:
	if _modifier == null:
		return
	if _profile == GripProfile.NONE or _weapon == null \
			or not is_instance_valid(_weapon) or _grip_model_radius <= 0.0:
		_modifier.active = false
		_modifier.clear_target()
		return
	var profile_label: StringName = &"pistol" if _profile == GripProfile.PISTOL \
		else &"katana"
	_modifier.configure(_weapon, _axis_start_local, _axis_end_local, _grip_model_radius,
		finger_curl_axis, thumb_curl_axis, finger_min_angles, finger_max_angles,
		thumb_min_angles, thumb_max_angles, surface_tolerance, solver_scan_steps,
		solver_refinement_iterations, debug_solver_limits, profile_label)
	_modifier.active = true


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null
