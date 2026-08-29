extends Node
class_name PlayerKatanaCombo
## 刀専用の3段コンボ。PlayerWeapon から fire 押下を受け、段ごとのタイマーで
## 判定・先行入力・踏み込みを進める。AnimationTree は PlayerMelee 経由で一方向に駆動する。

const PLAYER_ACTION_ANIM := preload("res://actors/player/player_action_anim.gd")
const NO_STAGE: int = 0
const FIRST_STAGE: int = 1
const SECOND_STAGE: int = 2
const FINAL_STAGE: int = 3
const MIN_HITBOX_RADIUS: float = 0.01
const INITIAL_PRESS_FRAME: int = -1000
@export_group("Stages: slash / attack / 360")
## 配列は順に初段・二段・三段。初段は従来値、後段ほど威力・押し出し・リーチを上げる。
@export var stage_damages: Array[float] = [4000.0, 5000.0, 7000.0]
@export var stage_knockbacks: Array[float] = [6.0, 7.5, 10.0]
## 本体原点から判定球の前方端までの距離（m）。初段1.4mは従来形状を維持する。
@export var stage_reaches: Array[float] = [1.4, 1.65, 1.9]
@export var stage_windups: Array[float] = [0.12, 0.18, 0.20]
@export var stage_actives: Array[float] = [0.16, 0.20, 0.22]
@export var stage_recoveries: Array[float] = [0.22, 0.22, 0.33]
## FBX右腕系ボーンの角速度最大点。実測順に40%・33.3%・40%。
@export var stage_contact_ratios: Array[float] = [0.40, 0.333, 0.40]
@export var stage_lunge_speeds: Array[float] = [2.5, 2.8, 3.2]
## 初段・二段の再押下受付終端。三段目はフィニッシュなので入力を受けない。
@export var stage_chain_close_ratios: Array[float] = [0.85, 0.90, 0.0]
@export_group("Combo")
## 素手コンボと同じ物理フレーム基準の押下デバウンス。
@export var press_debounce_frames: int = 4
## コンボ終了後に武器入力を抑止する秒数。従来値を維持する。
@export var post_cooldown: float = 0.1
## リーチを変える際も本体側へ広がりすぎないよう固定する前方端の反対側（m）。
@export var hitbox_near_edge: float = 0.1
@export_group("Nodes")
@export var body_path: NodePath = ^".."
@export var animation_driver_path: NodePath = ^"../PlayerMelee"
@export var hitbox_path: NodePath = ^"../Model/KatanaHitbox"
@export var hitbox_shape_path: NodePath = ^"CollisionShape3D"
@export_group("")

signal combo_started()
signal stage_started(stage: int)
signal combo_finished(completed: bool)
var _body: Node3D = null
var _animation_driver: Node = null
var _hitbox: Hitbox = null
var _hitbox_shape: SphereShape3D = null
var _stage: int = NO_STAGE
var _stage_elapsed: float = 0.0
var _next_stage_queued: bool = false
var _queue_closed: bool = false
var _hit_open: bool = false
var _combo_motion_available: bool = false
var _active_action: StringName = &""
var _cooldown_left: float = 0.0
var _last_press_frame: int = INITIAL_PRESS_FRAME
func _ready() -> void:
	_body = get_node_or_null(body_path) as Node3D
	_animation_driver = get_node_or_null(animation_driver_path)
	_hitbox = get_node_or_null(hitbox_path) as Hitbox
	if _hitbox != null:
		var shape_node := _hitbox.get_node_or_null(hitbox_shape_path) as CollisionShape3D
		if shape_node != null and shape_node.shape is SphereShape3D:
			_hitbox_shape = shape_node.shape.duplicate() as SphereShape3D
			shape_node.shape = _hitbox_shape

func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _stage == NO_STAGE:
		return
	if _is_downed():
		cancel()
		return
	_stage_elapsed += delta
	_update_hit_window()
	if _combo_motion_available and _stage < FINAL_STAGE \
			and _stage_elapsed >= _chain_close_time(_stage):
		_queue_closed = true
	if _stage_elapsed < stage_duration(_stage):
		return
	if _combo_motion_available and _stage < FINAL_STAGE and _next_stage_queued:
		_start_stage(_stage + 1, true)
		return
	_finish_combo(_stage == FINAL_STAGE)

## PlayerWeapon が刀装備中の fire 押下だけを渡す。
func press() -> void:
	var frame: int = Engine.get_physics_frames()
	if frame - _last_press_frame < press_debounce_frames:
		return
	_last_press_frame = frame
	if _stage == NO_STAGE:
		if _cooldown_left > 0.0 or _hitbox == null or _is_downed() \
				or _animation_is_busy():
			return
		_start_combo()
		return
	if not _combo_motion_available or _stage >= FINAL_STAGE or _next_stage_queued \
			or _queue_closed:
		return
	if _stage_elapsed >= _chain_close_time(_stage):
		_queue_closed = true
		return
	_next_stage_queued = true


func cancel() -> void:
	var was_active: bool = _stage != NO_STAGE
	_close_hitbox()
	_finish_requested_action()
	_stage = NO_STAGE
	_stage_elapsed = 0.0
	_next_stage_queued = false
	_queue_closed = false
	_combo_motion_available = false
	if was_active:
		combo_finished.emit(false)


func is_active() -> bool:
	return _stage != NO_STAGE


func is_cooling_down() -> bool:
	return _cooldown_left > 0.0


func current_stage() -> int:
	return _stage

func stage_progress() -> float:
	var duration: float = stage_duration(_stage)
	return clampf(_stage_elapsed / duration, 0.0, 1.0) if duration > 0.0 else 0.0

func stage_duration(stage: int) -> float:
	return stage_windup(stage) + stage_active(stage) + stage_recovery(stage)


func stage_contact_ratio(stage: int) -> float:
	return _stage_value(stage_contact_ratios, stage)
func stage_damage(stage: int) -> float:
	return _stage_value(stage_damages, stage)
func stage_knockback(stage: int) -> float:
	return _stage_value(stage_knockbacks, stage)

func stage_reach(stage: int) -> float:
	return _stage_value(stage_reaches, stage)

func stage_windup(stage: int) -> float:
	return _stage_value(stage_windups, stage)

func stage_active(stage: int) -> float:
	return _stage_value(stage_actives, stage)

func stage_recovery(stage: int) -> float:
	return _stage_value(stage_recoveries, stage)


func _start_combo() -> void:
	_combo_motion_available = _has_action_motion(PLAYER_ACTION_ANIM.ACTION_KATANA_1) \
		and _has_action_motion(PLAYER_ACTION_ANIM.ACTION_KATANA_2) \
		and _has_action_motion(PLAYER_ACTION_ANIM.ACTION_KATANA)
	var first_action: StringName = PLAYER_ACTION_ANIM.ACTION_KATANA_1 \
		if _combo_motion_available else PLAYER_ACTION_ANIM.ACTION_KATANA
	if not _request_action(first_action, stage_duration(FIRST_STAGE)):
		return
	_stage = FIRST_STAGE
	_active_action = first_action
	_begin_stage()
	combo_started.emit()


func _start_stage(stage: int, chained: bool) -> void:
	var action: StringName = _action_for_stage(stage)
	var accepted: bool = _continue_action(action, stage_duration(stage)) if chained \
		else _request_action(action, stage_duration(stage))
	if not accepted:
		_finish_combo(false)
		return
	_stage = stage
	_active_action = action
	_begin_stage()


func _begin_stage() -> void:
	_close_hitbox()
	_stage_elapsed = 0.0
	_next_stage_queued = false
	_queue_closed = false
	_configure_reach(stage_reach(_stage))
	_apply_lunge(_stage_value(stage_lunge_speeds, _stage))
	stage_started.emit(_stage)


func _update_hit_window() -> void:
	var active_start: float = stage_windup(_stage)
	var active_end: float = active_start + stage_active(_stage)
	if not _hit_open and _stage_elapsed >= active_start and _stage_elapsed < active_end:
		_hit_open = true
		_hitbox.configure(stage_damage(_stage), stage_knockback(_stage), true)
		_hitbox.activate()
	elif _hit_open and _stage_elapsed >= active_end:
		_close_hitbox()


func _finish_combo(completed: bool) -> void:
	_close_hitbox()
	_finish_requested_action()
	_stage = NO_STAGE
	_stage_elapsed = 0.0
	_next_stage_queued = false
	_queue_closed = false
	_combo_motion_available = false
	_cooldown_left = post_cooldown
	combo_finished.emit(completed)


func _close_hitbox() -> void:
	if _hit_open and _hitbox != null:
		_hitbox.deactivate_deferred()
	_hit_open = false


func _configure_reach(reach: float) -> void:
	if _hitbox == null or _hitbox_shape == null:
		return
	var safe_reach: float = maxf(reach, hitbox_near_edge + MIN_HITBOX_RADIUS * 2.0)
	_hitbox_shape.radius = maxf((safe_reach - hitbox_near_edge) * 0.5,
		MIN_HITBOX_RADIUS)
	_hitbox.position.z = (safe_reach + hitbox_near_edge) * 0.5


func _apply_lunge(speed: float) -> void:
	if not _body is CharacterBody3D or not _body.has_method("facing"):
		return
	var facing: int = int(_body.call("facing"))
	(_body as CharacterBody3D).velocity.x = float(facing) * speed


func _request_action(action: StringName, duration: float) -> bool:
	if _animation_driver == null:
		return true
	if _animation_driver.has_method("request_combo_action"):
		return bool(_animation_driver.call("request_combo_action", action, duration))
	if not _animation_driver.has_method("request_action"):
		return true
	return bool(_animation_driver.call("request_action", action, duration))


func _continue_action(action: StringName, duration: float) -> bool:
	if _animation_driver == null or not _animation_driver.has_method("continue_action"):
		return true
	return bool(_animation_driver.call("continue_action", action, duration))


func _finish_requested_action() -> void:
	if _active_action != &"" and _animation_driver != null \
			and _animation_driver.has_method("finish_action"):
		_animation_driver.call("finish_action", _active_action)
	_active_action = &""


func _has_action_motion(action: StringName) -> bool:
	return _animation_driver != null and _animation_driver.has_method("has_action_motion") \
		and bool(_animation_driver.call("has_action_motion", action))

func _animation_is_busy() -> bool:
	if _animation_driver == null:
		return false
	if _animation_driver.has_method("is_attacking") \
			and bool(_animation_driver.call("is_attacking")):
		return true
	return _animation_driver.has_method("is_dancing") \
		and bool(_animation_driver.call("is_dancing"))

func _is_downed() -> bool:
	return _body != null and _body.has_method("is_downed") and bool(_body.call("is_downed"))


func _action_for_stage(stage: int) -> StringName:
	match stage:
		FIRST_STAGE:
			return PLAYER_ACTION_ANIM.ACTION_KATANA_1
		SECOND_STAGE:
			return PLAYER_ACTION_ANIM.ACTION_KATANA_2
		FINAL_STAGE:
			return PLAYER_ACTION_ANIM.ACTION_KATANA
	return &""


func _chain_close_time(stage: int) -> float:
	return stage_duration(stage) * _stage_value(stage_chain_close_ratios, stage)


func _stage_value(values: Array[float], stage: int) -> float:
	var index: int = stage - FIRST_STAGE
	if index < 0 or index >= values.size():
		return 0.0
	return values[index]
