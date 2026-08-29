extends Node
class_name EnemyLeftGrip

## 両手で構える武器を持つ敵の、左手の指を武器へ巻き付ける部品。
##
## 右手は `PlayerWeaponGrip` が受け持つ（あちらは `Right*` のボーンしか触らない）。
## こちらはその左手版で、`EnemyLeftGripModifier` をスケルトンへ足して、支え手が
## 添える場所（ライフルなら handguard）の線分と太さを渡す。
##
## 線分と太さはメッシュの実測値で、`tools/capture_rifle_grip.gd` が出す。
## 座標はモデルのローカルで、武器の拡縮は modifier 側が掛ける。

@export_group("Nodes")
@export var model_path: NodePath = ^"../Model"
## 装備中の武器を持っている `WeaponLoadout`。
@export var loadout_path: NodePath = ^"../WeaponLoadout"

@export_group("Grip geometry")
## 支え手が添える部分の軸（モデルのローカル座標）。
@export var axis_start: Vector3 = Vector3.ZERO
@export var axis_end: Vector3 = Vector3.ZERO
## その部分の太さ（モデル座標の半径）。0 なら何もしない。
@export var model_radius: float = 0.0

@export_group("Curl axes")
## 指を曲げる軸。右手と左右が逆になるので、右手の既定と符号が反転する。
@export var finger_curl_axis: Vector3 = Vector3(0.0, 0.0, 1.0)
## 親指の軸。符号を反転しても結果は変わらなかったので、4本指と対の向きにしてある。
##
## 親指は手前の姿勢では木部へ届かず、どちらの符号でも角度 0 度で止まる
## （ソルバのログ: `LeftThumbProximal clamped angle=0.00 error=+0.03m` 前後）。
## 誤差 2〜4 cm は「木部の外側で止まっている距離」で、回しても縮まらない。
## 親指まで巻き付けたいなら、軸ではなくアニメーション側（左手の開き）を直す必要がある。
@export var thumb_curl_axis: Vector3 = Vector3(0.0, 0.0, -1.0)

@export_group("Joint limits (degrees)")
@export var finger_min_angles: Vector3 = Vector3.ZERO
@export var finger_max_angles: Vector3 = Vector3(100.0, 120.0, 80.0)
@export var thumb_min_angles: Vector3 = Vector3.ZERO
@export var thumb_max_angles: Vector3 = Vector3(90.0, 110.0, 80.0)

@export_group("Solver")
@export_range(0.0001, 0.01, 0.0001) var surface_tolerance: float = 0.002
@export_range(2, 64, 1) var solver_scan_steps: int = 16
@export_range(0, 16, 1) var solver_refinement_iterations: int = 8
@export var debug_solver_limits: bool = false
@export_group("")

var _skeleton: Skeleton3D = null
var _modifier: EnemyLeftGripModifier = null
var _loadout: WeaponLoadout = null


func _ready() -> void:
	# 敵はモデルを親の _ready() で差し込むので、その後に立ち上げ直す。
	if not setup(false):
		call_deferred("setup")


func setup(warn_on_failure: bool = true) -> bool:
	if _modifier != null and is_instance_valid(_modifier):
		_refresh()
		return true
	var model: Node = get_node_or_null(model_path)
	if model == null:
		if warn_on_failure:
			push_warning("enemy_left_grip: Model が見つからない")
		return false
	_skeleton = _find_skeleton(model)
	if _skeleton == null:
		if warn_on_failure:
			push_warning("enemy_left_grip: Skeleton3D が見つからない")
		return false
	_modifier = EnemyLeftGripModifier.new()
	_modifier.name = &"LeftHandWeaponGripModifier"
	_modifier.active = false
	_skeleton.add_child(_modifier)
	_refresh()
	return true


## 装備中の武器を見て、掴む相手を渡し直す。武器を持っていなければ止める。
func _refresh() -> void:
	if _modifier == null:
		return
	_loadout = get_node_or_null(loadout_path) as WeaponLoadout
	var weapon: Node3D = _loadout.current_weapon() if _loadout != null else null
	if weapon == null or not is_instance_valid(weapon) or model_radius <= 0.0:
		_modifier.active = false
		_modifier.clear_target()
		return
	_modifier.configure(weapon, axis_start, axis_end, model_radius,
		finger_curl_axis, thumb_curl_axis, finger_min_angles, finger_max_angles,
		thumb_min_angles, thumb_max_angles, surface_tolerance, solver_scan_steps,
		solver_refinement_iterations, debug_solver_limits, &"left_support")
	_modifier.active = true


## 武器を差し替えたときに面側から呼ぶ。
func rebind() -> void:
	_refresh()


func is_grip_active() -> bool:
	return _modifier != null and _modifier.active


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null
