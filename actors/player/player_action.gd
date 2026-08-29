extends Node
class_name PlayerAction

## プレイヤーの即時アクション（△必殺）。移動と密結合な回避は player.gd 側。
## いずれも敵グループへの範囲問い合わせ後、Hurtbox の被弾経路で処理する（technical-spec §14.5）。

const PLAYER_ACTION_ANIM := preload("res://actors/player/player_action_anim.gd")

signal special_used()

@export_group("Special")
## △必殺の範囲・ダメージ・ノックバック。全方位に吹き飛ばす。
@export var special_radius: float = 2.6
@export var special_damage: float = 5500.0
@export var special_knockback: float = 10.0
## 使うたびに消費する自 HP と、再使用待ち（秒）。
@export var special_hp_cost: float = 1500.0
@export var special_cooldown: float = 1.632
## 元クリップで回転蹴りが最大速度になる再生割合（FBX カーブ実測 64%）。
@export_range(0.0, 1.0, 0.01) var special_impact_ratio: float = 0.56
## 助走を開始する時刻（アクション開始からの秒数）と、前進速度・距離。
@export var special_lunge_start_time: float = 0.0
@export var special_lunge_speed: float = 3.84
@export var special_lunge_distance: float = 3.5
## 全方位半径に加えて、現在位置から正面へ伸ばす矩形判定の距離と全幅。
@export var special_front_distance: float = 2.8
@export var special_front_width: float = 1.4

@export var body_path: NodePath = ^".."
@export var animation_driver_path: NodePath = ^"../PlayerMelee"
@export var special_vfx_path: NodePath = ^"../DropkickVfx3D"

var _body: Node3D = null
var _health: Health = null
var _animation_driver: Node = null
var _special_vfx: Node = null
var _special_cd: float = 0.0
var _special_action_elapsed: float = -1.0
var _special_facing: int = 1
var _special_lunge_started: bool = false


func _ready() -> void:
	_body = get_node_or_null(body_path) as Node3D
	_animation_driver = get_node_or_null(animation_driver_path)
	_special_vfx = get_node_or_null(special_vfx_path)
	if _body != null:
		_health = _body.get_node_or_null(^"Health") as Health


func _physics_process(delta: float) -> void:
	if _special_cd > 0.0:
		_special_cd = maxf(_special_cd - delta, 0.0)
	_update_special_action(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _body == null or _busy():
		return
	if event.is_action_pressed("special"):
		_try_special()


func _busy() -> bool:
	if _body.has_method("is_downed") and bool(_body.call("is_downed")):
		return true
	if _body.has_method("is_dodging") and bool(_body.call("is_dodging")):
		return true
	if _animation_driver != null and _animation_driver.has_method("is_action_playing") \
			and bool(_animation_driver.call("is_action_playing")):
		return true
	return false


# --- △必殺（全方位） -----------------------------------------------------

func _try_special() -> void:
	if _special_cd > 0.0:
		return
	if _health != null and _health.current_hp() <= special_hp_cost:
		return
	var has_motion: bool = _has_action_motion(PLAYER_ACTION_ANIM.ACTION_SPECIAL)
	if has_motion and not _request_action(PLAYER_ACTION_ANIM.ACTION_SPECIAL, special_cooldown):
		return
	_special_facing = _body_facing()
	_special_lunge_started = false
	_special_cd = special_cooldown
	if _health != null:
		# 被弾ではないので spend() を使う。take_hit だと掛け声が「やられた」側で鳴る。
		_health.spend(special_hp_cost)
	special_used.emit()
	if has_motion and special_cooldown > 0.0:
		_begin_special_vfx(special_cooldown * special_impact_ratio)
		_special_action_elapsed = 0.0
		return
	_begin_special_vfx(0.0)
	_apply_special()


func _update_special_action(delta: float) -> void:
	if _special_action_elapsed < 0.0:
		return
	if _body.has_method("is_downed") and bool(_body.call("is_downed")):
		_stop_special_lunge()
		if _special_vfx != null and _special_vfx.has_method("cancel"):
			_special_vfx.call("cancel")
		_special_action_elapsed = -1.0
		return
	_special_action_elapsed += delta
	var impact_time: float = special_cooldown * special_impact_ratio
	var lunge_start_time: float = clampf(special_lunge_start_time, 0.0, impact_time)
	if not _special_lunge_started and _special_action_elapsed >= lunge_start_time:
		_special_lunge_started = true
		_start_special_lunge()
	if _special_action_elapsed < impact_time:
		return
	_stop_special_lunge()
	_special_action_elapsed = -1.0
	_apply_special()


func _apply_special() -> void:
	var center: Vector3 = _body.global_position
	if _special_vfx != null and _special_vfx.has_method("impact"):
		_special_vfx.call("impact", center, special_radius, special_front_distance,
			special_front_width, _special_facing)
	var shocked := PackedVector3Array()
	for node: Node in _body.get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var offset: Vector3 = enemy.global_position - center
		var forward_distance: float = offset.x * float(_special_facing)
		var inside_radius: bool = offset.length() <= special_radius
		var inside_front: bool = forward_distance >= 0.0 \
			and forward_distance <= special_front_distance \
			and absf(offset.z) <= special_front_width * 0.5
		if not inside_radius and not inside_front:
			continue
		if _apply_area_damage(enemy, special_damage, special_knockback, center):
			shocked.append(enemy.global_position)
	if _special_vfx != null and _special_vfx.has_method("electrocute"):
		_special_vfx.call("electrocute", shocked)


func _begin_special_vfx(impact_delay: float) -> void:
	if _special_vfx != null and _special_vfx.has_method("begin"):
		_special_vfx.call("begin", _special_facing, impact_delay)


func _start_special_lunge() -> void:
	if _body.has_method("start_action_lunge"):
		_body.call("start_action_lunge", special_lunge_speed, special_lunge_distance)


func _stop_special_lunge() -> void:
	if _body.has_method("stop_action_lunge"):
		_body.call("stop_action_lunge")


func _body_facing() -> int:
	if _body.has_method("facing"):
		return int(_body.call("facing"))
	return 1


func _request_action(action: StringName, duration: float) -> bool:
	if _animation_driver == null or not _animation_driver.has_method("request_action"):
		return true
	return bool(_animation_driver.call("request_action", action, duration))


func _has_action_motion(action: StringName) -> bool:
	return _animation_driver != null and _animation_driver.has_method("has_action_motion") \
		and bool(_animation_driver.call("has_action_motion", action))


# --- 共通: 範囲へダメージ＋ノックバック ---------------------------------

func _splash(center: Vector3, radius: float, damage: float, knockback: float,
		exclude: Array) -> void:
	for node in _body.get_tree().get_nodes_in_group(&"enemy"):
		var e := node as Node3D
		if e == null or not is_instance_valid(e) or exclude.has(e):
			continue
		if e.global_position.distance_to(center) > radius:
			continue
		_apply_area_damage(e, damage, knockback, center)


func _apply_area_damage(target: Node3D, damage: float, knockback: float,
		knockback_origin: Vector3) -> bool:
	var hurtbox := target.get_node_or_null(^"Hurtbox") as Hurtbox
	if hurtbox == null:
		return false
	var landed: bool = hurtbox.receive_area_hit(_body, damage, knockback,
		knockback_origin, true, true)
	if landed and _body.has_method("play_action_hit_feedback"):
		_body.call("play_action_hit_feedback")
	return landed
