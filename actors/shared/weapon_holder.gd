extends Node
class_name WeaponHolder

## 武器モデルを手ボーンに装着する（technical-spec §14.5）。プレイヤーの VRM も敵の Mixamo も
## GeneralSkeleton にリターゲット済みで手ボーン名が共通なので、同じ仕組みで両方に載る。
##
## model_path 以下の Skeleton3D を探し、bone_name（既定 RightHand）に BoneAttachment3D を作って
## 武器 glb のインスタンスを子に付ける。モデルごとに原点・スケールが違うため、握りのオフセットは
## per-weapon で与える（equip の引数）。

## 武器を付ける対象（VRM / キャラクターを含むノード）。
@export var model_path: NodePath = ^"../Model"
## 装着するボーン名。GeneralSkeleton の右手。
@export var bone_name: StringName = &"RightHand"

var _skeleton: Skeleton3D = null
var _attachment: BoneAttachment3D = null
var _current: Node3D = null


func _ready() -> void:
	_resolve_skeleton()


func _resolve_skeleton() -> void:
	var model := get_node_or_null(model_path)
	if model == null:
		return
	_skeleton = _find_skeleton(model)
	if _skeleton == null:
		return
	var idx := _skeleton.find_bone(bone_name)
	if idx < 0:
		push_warning("weapon_holder: ボーン %s が無い" % bone_name)
		return
	_attachment = BoneAttachment3D.new()
	_attachment.bone_name = String(bone_name)
	_skeleton.add_child(_attachment)


## 武器を装備する。scene が null なら外す。offset/rotation(度)/軸別scale は握りの微調整。
func equip(scene: PackedScene, grip_offset: Vector3 = Vector3.ZERO,
		grip_rotation_deg: Vector3 = Vector3.ZERO,
		grip_scale: Vector3 = Vector3.ONE) -> void:
	if _attachment == null:
		_resolve_skeleton()
		if _attachment == null:
			return
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = null
	if scene == null:
		return
	var weapon := scene.instantiate() as Node3D
	if weapon == null:
		return
	_attachment.add_child(weapon)
	weapon.position = grip_offset
	weapon.rotation = Vector3(deg_to_rad(grip_rotation_deg.x),
		deg_to_rad(grip_rotation_deg.y), deg_to_rad(grip_rotation_deg.z))
	weapon.scale = grip_scale
	_current = weapon


func current_weapon() -> Node3D:
	return _current


## 装備したままの武器の向きだけを差し替える。姿勢によって銃身の向きが変わる素材で、
## 装備側が毎フレーム角度を補正するために使う（PlayerWeapon の拳銃）。
func set_grip_rotation(grip_rotation_deg: Vector3) -> void:
	if _current == null or not is_instance_valid(_current):
		return
	_current.rotation = Vector3(deg_to_rad(grip_rotation_deg.x),
		deg_to_rad(grip_rotation_deg.y), deg_to_rad(grip_rotation_deg.z))


func has_weapon() -> bool:
	return _current != null and is_instance_valid(_current)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for c in node.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null
