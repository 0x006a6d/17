extends "res://actors/player/player.gd"
class_name NikeBoss

## 5面の最終ボス ニケ（technical-spec §10）。
## プレイヤーと同じ本体スクリプト・AnimationTree・コンボツリー・Hitbox/Hurtbox を持ち、
## 入力の読み取りだけを AI に差し替える。見た目は NikeSkin（ヘアピン無し・赤シャツ）。
##
## AI:
##   - Z をプレイヤーに合わせ、engage_range まで X を詰める
##   - 射程内ならコンボツリーの系統を 1 つ選び、stage_started に合わせて次のボタンを押す
##   - 短時間に guard_trigger_hits 回被弾すると guard_chance でガード（正面からの近接を弾く）
##   - プレイヤーが踊っている間はクールダウンを待たずに詰める
##   - HP が adds_hp_ratios の各割合を切るたびに増援を要請して距離を取る
##   - 倒れたら立ち上がらず defeated を送る

signal defeated(enemy: Node3D)
signal adds_requested(count: int)

## コンボの系統（コンボツリーの入力列。技の実体は combo_tree.gd が持つ）。
const COMBOS: Array = [
	["attack", "attack", "attack"],
	["kick", "kick", "kick"],
	["attack", "kick", "attack", "attack"],
	["attack", "kick", "kick", "attack"],
	["attack", "attack", "kick", "attack", "kick"],
]

@export_group("Boss AI")
## 攻撃に入る X 距離（m）。
@export var engage_range: float = 1.35
## これより近いと半歩下がる（m）。
@export var too_close_range: float = 0.55
## 攻撃に入るための奥行き差の上限（m）。
@export var ai_depth_tolerance: float = 0.42
## 段を合わせ始める奥行き差（m）。
@export var depth_align_threshold: float = 0.25
## 次のボタンを押す間隔（秒）。受付窓に入るまで同じボタンを押し続ける。
@export var press_interval: float = 0.1
## コンボ後のクールダウン（秒）の下限・上限。
@export var cooldown_min: float = 0.5
@export var cooldown_max: float = 1.3
@export_group("Boss Guard")
## この秒数以内に guard_trigger_hits 回被弾すると、guard_chance でガードに入る。
@export var guard_window: float = 0.7
@export var guard_trigger_hits: int = 2
@export_range(0.0, 1.0) var guard_chance: float = 0.5
## ガードの継続秒数と再使用待ち。
@export var guard_duration: float = 0.9
@export var guard_cooldown: float = 2.0
@export_group("Boss Phase")
## HP がこれらの割合を切るたびに増援を呼ぶ。それぞれ1回だけ発火する。
@export var adds_hp_ratios: Array[float] = [0.5, 0.3, 0.15]
@export var adds_count: int = 2
## 増援を呼んだあと距離を取る秒数。
@export var retreat_time: float = 1.6
## ボスバーに出す名前。
@export var boss_name: String = "ニケ"
## 撃破後、倒れ込みを見せてから消えるまでの秒数。
@export var despawn_delay: float = 4.0
@export_group("")

var _target: Node3D = null
var _queue: Array = []
var _press_left: float = 0.0
var _current_button: String = ""
var _cooldown_left: float = 0.0
var _guarding: bool = false
var _guard_left: float = 0.0
var _guard_cooldown_left: float = 0.0
var _recent_hits: Array[float] = []
var _time: float = 0.0
## 発火済みの増援閾値（adds_hp_ratios の添字）。
var _adds_fired: Array[int] = []
var _retreat_left: float = 0.0
var _defeated_emitted: bool = false


func _ready() -> void:
	super._ready()
	add_to_group(&"enemy")
	if _melee != null and _melee.has_signal("stage_started"):
		_melee.connect("stage_started", _on_boss_stage_started)
	if _health != null:
		_health.hp_changed.connect(_on_boss_hp_changed)


func display_name() -> String:
	return boss_name


func is_boss() -> bool:
	return true


func is_guarding() -> bool:
	return _guarding


func set_belt_bounds_from_stage(z_min: float, z_max: float) -> void:
	set_belt_bounds(z_min, z_max)


# --- 入力の差し替え ---------------------------------------------------------

func _accepts_player_input() -> bool:
	return false


func _interact_held() -> bool:
	return false


func _read_move_input() -> Vector2:
	if _downed or _guarding:
		return Vector2.ZERO
	_resolve_target()
	if _target == null:
		return Vector2.ZERO
	var dx := _target.global_position.x - global_position.x
	var dz := _target.global_position.z - global_position.z
	if absf(dx) > 0.05:
		_facing = 1 if dx > 0.0 else -1
	var attacking: bool = _melee != null and bool(_melee.call("is_attacking"))
	if attacking:
		return Vector2.ZERO
	var move := Vector2.ZERO
	if _retreat_left > 0.0:
		move.x = -signf(dx)
		return move
	if absf(dz) > depth_align_threshold:
		move.y = signf(dz)
	if absf(dx) > engage_range:
		move.x = signf(dx)
	elif absf(dx) < too_close_range:
		move.x = -signf(dx)
	return move.limit_length(1.0)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_time += delta
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _guard_cooldown_left > 0.0:
		_guard_cooldown_left = maxf(_guard_cooldown_left - delta, 0.0)
	if _retreat_left > 0.0:
		_retreat_left = maxf(_retreat_left - delta, 0.0)
	if _guarding:
		_guard_left -= delta
		if _guard_left <= 0.0:
			_guarding = false
			_guard_cooldown_left = guard_cooldown
		return
	if _downed or _target == null:
		return
	_drive_combo(delta)


func _drive_combo(delta: float) -> void:
	var attacking: bool = _melee != null and bool(_melee.call("is_attacking"))
	if not _queue.is_empty() or _current_button != "":
		if not attacking and _current_button != "" and _press_left <= 0.0 and _queue.is_empty():
			# コンボが途切れた（受付窓に入らなかった、または終わった）。
			_end_combo()
			return
		_press_left -= delta
		if _press_left <= 0.0 and _current_button != "":
			_press_left = press_interval
			_melee.call(_current_button)
		return
	if attacking or _cooldown_left > 0.0 and not _player_is_dancing():
		return
	var dx := _target.global_position.x - global_position.x
	var dz := _target.global_position.z - global_position.z
	if absf(dx) > engage_range or absf(dz) > ai_depth_tolerance:
		return
	var combo: Array = COMBOS[randi_range(0, COMBOS.size() - 1)]
	_queue = combo.duplicate()
	_current_button = String(_queue.pop_front())
	_press_left = 0.0


## 段が進んだ: 次のボタンへ。最後なら、クリップが終わるのを待って _end_combo。
func _on_boss_stage_started(_technique: StringName, _stage: int) -> void:
	if _queue.is_empty():
		_current_button = ""
		_press_left = 0.0
		return
	_current_button = String(_queue.pop_front())
	_press_left = press_interval * 2.0


func _end_combo() -> void:
	_queue.clear()
	_current_button = ""
	_cooldown_left = randf_range(cooldown_min, cooldown_max)


func _player_is_dancing() -> bool:
	return _target != null and _target.has_method("is_dancing") and bool(_target.call("is_dancing"))


func _resolve_target() -> void:
	if _target != null and is_instance_valid(_target):
		return
	_target = get_tree().get_first_node_in_group(&"player") as Node3D


# --- ガード -----------------------------------------------------------------

## Hitbox の汎用方向防御フック。ガード中、向いている側からの近接を弾く。
func blocks_hit_from(attacker_position: Vector3) -> bool:
	if not _guarding or _downed:
		return false
	var dx := attacker_position.x - global_position.x
	return signf(dx) == float(_facing)


func receive_knockback(direction: Vector3, strength: float) -> void:
	_recent_hits.append(_time)
	while not _recent_hits.is_empty() and _time - _recent_hits[0] > guard_window:
		_recent_hits.remove_at(0)
	if not _guarding and not _downed and _guard_cooldown_left <= 0.0 \
			and _recent_hits.size() >= guard_trigger_hits and randf() < guard_chance:
		_guarding = true
		_guard_left = guard_duration
		_recent_hits.clear()
		_end_combo()
		# 構えはプレイヤーの方（＝攻撃が来る側）へ向ける。移動しないと _facing が更新
		# されないため、ここで明示的に合わせる。
		_resolve_target()
		if _target != null:
			var dx := _target.global_position.x - global_position.x
			if absf(dx) > 0.01:
				_facing = 1 if dx > 0.0 else -1
	super.receive_knockback(direction, strength)


## 被弾の提示はプレイヤー側のヒットストップ・シェイクが担う。ボス側では揺らさない。
func flash_hit() -> void:
	_stop_dance()


# --- フェーズ・ダウン --------------------------------------------------------

func _on_boss_hp_changed(current: float, maximum: float) -> void:
	if maximum <= 0.0 or _downed:
		return
	for i in range(adds_hp_ratios.size()):
		if _adds_fired.has(i):
			continue
		if current <= maximum * adds_hp_ratios[i]:
			_adds_fired.append(i)
			_retreat_left = retreat_time
			_end_combo()
			adds_requested.emit(adds_count)


## 倒れたら立ち上がらない。
func _on_health_downed(_lethal: bool) -> void:
	if _downed:
		return
	_stop_dance()
	_downed = true
	_out_of_lives = true
	_hurt_timer = 0.0
	_queue.clear()
	_current_button = ""
	_guarding = false
	if _hitbox != null:
		_hitbox.deactivate_deferred()
	if _melee != null and _melee.has_method("start_down"):
		_melee.call("start_down", down_fall_time)
	if despawn_delay > 0.0:
		if _recovery_blink != null:
			_recovery_blink.begin(despawn_delay)
		get_tree().create_timer(despawn_delay).timeout.connect(_despawn)
	set_deferred("collision_layer", 0)
	if not _defeated_emitted:
		_defeated_emitted = true
		RunState.enemies_downed += 1
		RunState.add_defeat_score()
		defeated.emit(self)


func _despawn() -> void:
	if is_inside_tree():
		queue_free()
