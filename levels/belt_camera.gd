extends Camera3D
class_name BeltCamera

## ベルトスクロールの側面固定カメラ（technical-spec §6.1）。
## 対象（プレイヤー）の X にだけ追従し、Y / Z / 向きは固定。俯角・FOV・距離は @export。
## 画面ロック中は lock_at(x) で X を固定し、unlock() で追従へ戻す。
## プレイヤー側の X clamp のために、ベルト面（z=0）上で画面に映る左右端を公開する。
## 誰からも直接参照されないよう、グループ belt_camera に登録して検索させる。

## 追従する対象（面側で Player を指定する）。
@export var target_path: NodePath
## X 追従の補間速度。
@export var follow_speed: float = 8.0
## 俯角（度、正で見下ろし）。
@export var pitch_deg: float = 12.0
## 垂直 FOV（度）。小さいほど望遠で奥行きが潰れ、ベルトスクロールの絵に近づく。
@export var fov_deg: float = 35.0
## 注視点（ベルト中央 z=0・高さ look_height）までの距離（m）。
@export var distance: float = 8.5
## 注視点の高さ（m）。身長 160cm のキャラが画面中央より少し下に収まる値。
@export var look_height: float = 1.0
## カメラ中心 X の可動範囲。面側（BeltStage）が set_x_limits() で上書きする。
@export var x_min: float = -1.0e9
@export var x_max: float = 1.0e9
## 対象の初期位置へ即座に合わせる（true なら起動時の追従遅れを出さない）。
@export var snap_on_ready: bool = true

var _target: Node3D = null
var _locked: bool = false
var _lock_x: float = 0.0


func _ready() -> void:
	add_to_group(&"belt_camera")
	_target = get_node_or_null(target_path) as Node3D
	fov = fov_deg
	var pitch := deg_to_rad(pitch_deg)
	rotation = Vector3(-pitch, 0.0, 0.0)
	position.y = look_height + distance * sin(pitch)
	position.z = distance * cos(pitch)
	if snap_on_ready and _target != null:
		position.x = clampf(_target.global_position.x, x_min, x_max)


func _physics_process(delta: float) -> void:
	var desired := position.x
	if _locked:
		desired = _lock_x
	elif _target != null and is_instance_valid(_target):
		desired = clampf(_target.global_position.x, x_min, x_max)
	position.x = lerpf(position.x, desired, 1.0 - exp(-follow_speed * delta))


func set_target(target: Node3D) -> void:
	_target = target


func set_x_limits(new_min: float, new_max: float) -> void:
	x_min = new_min
	x_max = new_max


## 画面ロック。カメラ中心 X を x に固定する。
func lock_at(x: float) -> void:
	_locked = true
	_lock_x = clampf(x, x_min, x_max)


func unlock() -> void:
	_locked = false


func is_locked() -> bool:
	return _locked


## ベルト面（z=0、高さ look_height）で画面に映る半幅（m）。
func half_width_at_belt() -> float:
	var viewport := get_viewport()
	var aspect := 16.0 / 9.0
	if viewport != null:
		var size := viewport.get_visible_rect().size
		if size.y > 0.0:
			aspect = size.x / size.y
	return distance * tan(deg_to_rad(fov) * 0.5) * aspect


## プレイヤーが出てはいけない左右端（ワールド X）。
func left_limit() -> float:
	return position.x - half_width_at_belt()


func right_limit() -> float:
	return position.x + half_width_at_belt()
