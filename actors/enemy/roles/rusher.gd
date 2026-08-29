extends Enemy
class_name Rusher

## 突進型（旧 erratic の組み替え。客を撃つ処理は無い）。
## 段が揃っていて距離があるとき、予備動作のあと一直線に突っ込む。突進中は判定を開き、
## 終わったあとは長めに硬直する。それ以外は共通の接近・近接・ガードに任せる。

## Enemy.State の最大値 DOWNED の直後を使う。
const RUSH: int = State.DOWNED + 1

@export_group("Rush")
## 突進を始める X 距離の下限・上限（m）。近すぎれば通常の近接、遠すぎれば歩いて詰める。
@export var rush_min_distance: float = 2.5
@export var rush_max_distance: float = 6.0
## 条件を満たしているとき、1 秒あたりに突進へ入る確率。
@export_range(0.0, 1.0) var rush_chance_per_second: float = 0.9
## 予備動作（秒）。構えて止まる。
@export var rush_telegraph: float = 0.5
## 突進の速度（m/s）と継続秒数。
@export var rush_speed: float = 7.0
@export var rush_duration: float = 0.55
## 突進後の硬直（秒）。
@export var rush_recovery: float = 0.9
## 突進の与ダメージとノックバック。
@export var rush_damage: float = 1400.0
@export var rush_knockback: float = 5.0
## 突進後、次の突進までの間隔（秒）。
@export var rush_cooldown: float = 3.0
@export_group("")

var _rush_cooldown_left: float = 0.0
var _rush_dir: float = 1.0


func _ready() -> void:
	super._ready()
	if _sm != null:
		_sm.add_state(RUSH, &"rush", _enter_rush, _physics_rush, _exit_rush)


func display_name() -> String:
	return "突進型"


func _physics_process(delta: float) -> void:
	if _rush_cooldown_left > 0.0:
		_rush_cooldown_left = maxf(_rush_cooldown_left - delta, 0.0)
	super._physics_process(delta)


func _uses_role_locomotion(state: int) -> bool:
	return state == RUSH


## 接近中、条件が揃えば突進へ。
func _role_approach_override(delta: float) -> bool:
	if _target == null or _rush_cooldown_left > 0.0:
		return false
	var dx := _target.global_position.x - global_position.x
	var dz := _target.global_position.z - global_position.z
	if absf(dz) > attack_depth_tolerance:
		return false
	if absf(dx) < rush_min_distance or absf(dx) > rush_max_distance:
		return false
	if randf() >= rush_chance_per_second * delta:
		return false
	_rush_dir = signf(dx)
	_sm.transition_to(RUSH)
	return true


func _enter_rush() -> void:
	_set_color(color_telegraph)
	_hitbox_open = false
	_stop_horizontal_immediate()


func _physics_rush(delta: float) -> void:
	var t := _sm.time_in_state()
	if t < rush_telegraph:
		_stop_horizontal(delta)
		_face_direction_at_speed(Vector3(_rush_dir, 0.0, 0.0), delta, rotation_speed)
		return
	if t < rush_telegraph + rush_duration:
		if not _hitbox_open and _hitbox != null:
			_hitbox_open = true
			_hitbox.configure(rush_damage, rush_knockback, false)
			_hitbox.activate()
		velocity.x = _rush_dir * rush_speed
		velocity.z = 0.0
		return
	if _hitbox_open:
		_close_hitbox()
	if t < rush_telegraph + rush_duration + rush_recovery:
		_stop_horizontal(delta)
		return
	_rush_cooldown_left = rush_cooldown
	_cooldown_left = attack_cooldown
	_sm.transition_to(State.APPROACH)


func _exit_rush() -> void:
	_close_hitbox()
