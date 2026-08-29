extends Node

## 撃破された敵が、倒れたまま後ろへ滑っていかないことの検証。
##   godot --path . --headless res://tools/test_enemy_down_slide.tscn
##
## 経緯: 「撃破された敵が倒れたままノックバック方向へ下がっていく」という実機報告が
## あった。d9f9615 は死亡クリップのルートモーションを疑って潰したが、症状は残った。
## クリップ（見た目）ではなく本体（CharacterBody3D）の座標を直接測って切り分ける。
##
## 測り方: 実戦と同じ `Hurtbox.receive_hit()` へ 1 撃で倒す打撃を流し、ダウンが確定した
## フレームの `global_position.x` を基準に、その後 SAMPLE_FRAMES ぶんの x を毎フレーム
## 記録する。ノックバック強度は素手コンボ・刀コンボ・必殺の代表値を使う。
##
## 検証項目（強度ごと）:
##   (1) ダウン確定後、本体の x が動かない
##   (2) ノックバック減衰時間を過ぎた後も静止したままである
##       （減衰しきらずに残った速度が永久に運び続けていないか）

const STAGE := "res://levels/belt_test.tscn"
const ENEMY := "res://actors/enemy/enemy.tscn"

## 検証するノックバック強度（`Hitbox.knockback`）。素手コンボ 3.0、刀コンボ 6.0、
## 必殺・刀コンボ最終段 10.0 を代表させる。
const KNOCKBACK_CASES: Array[float] = [3.0, 6.0, 10.0]
## 1 撃で倒すためのダメージ。敵の max_hp（30000）を確実に上回らせる。
const LETHAL_DAMAGE: float = 100000.0
## ダウン確定後に x を記録するフレーム数（60Hz で 3.0 秒）。
const SAMPLE_FRAMES: int = 180
## ノックバックが減衰しきったとみなすフレーム数。敵の knockback_decay（0.25 秒）の
## 倍以上を取り、ここから先の移動は「減衰後も残っている速度」とみなす。
const SETTLE_FRAMES: int = 30
## 敵を出してから殴るまでの待ちフレーム（着地とステート確定を待つ）。
const WARMUP_FRAMES: int = 20
## 停止とみなす移動量（m）。move_and_slide の丸め誤差だけを見逃す幅。
const POSITION_TOLERANCE: float = 0.02
## 減衰後の停止とみなす移動量（m）。速度が完全に 0 なら移動は起きない。
const SETTLED_TOLERANCE: float = 0.005
## 攻撃側の立ち位置。敵より手前（-X）に置き、ノックバックを +X 方向にする。
const PLAYER_POSITION := Vector3(2.0, 0.2, 0.0)
const ENEMY_POSITION := Vector3(4.2, 0.2, 0.0)
const BELT_Z_MIN: float = -1.5
const BELT_Z_MAX: float = 1.5
const DUMMY_AWAY := Vector3(50.0, 0.2, 0.0)
const MAX_FRAMES: int = 3000

## 進行段階。0=着地待ち、1=記録中。
const STEP_WARMUP: int = 0
const STEP_SAMPLE: int = 1

var _pass: int = 0
var _fail: int = 0

var _stage: Node3D = null
var _player: Node3D = null
var _hitbox: Hitbox = null
var _enemy: Enemy = null

var _frames: int = 0
var _case_index: int = -1
var _step: int = STEP_WARMUP
var _step_frame: int = 0
var _down_x: float = 0.0
var _settled_x: float = 0.0
var _samples: Array[float] = []
var _results: Array[Dictionary] = []


func _ready() -> void:
	print("=== 撃破後に倒れた敵が滑らないかの検証開始 ===")
	RunState.reset()

	var packed := load(STAGE) as PackedScene
	if packed == null:
		_fatal("belt_test の読み込みに失敗")
		return
	_stage = packed.instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node_or_null("Player") as Node3D
	if _player == null:
		_fatal("Player が見つからない")
		return
	for dummy_name: String in ["Dummy1", "Dummy2", "Dummy3"]:
		var dummy := _stage.get_node_or_null(dummy_name) as Node3D
		if dummy != null:
			dummy.global_position = DUMMY_AWAY
	_player.global_position = PLAYER_POSITION

	# 攻撃側の判定。実戦と同じ Hurtbox.receive_hit() 経路へ流したいが、判定の重なりを
	# 待つとフレームがぶれるので、プレイヤーの子に置いた Hitbox を直接当てる。
	_hitbox = Hitbox.new()
	_hitbox.name = "TestHitbox"
	_player.add_child(_hitbox)

	_start_case(0)


func _start_case(index: int) -> void:
	_case_index = index
	_step = STEP_WARMUP
	_step_frame = 0
	_samples.clear()
	var packed := load(ENEMY) as PackedScene
	if packed == null:
		_fatal("enemy の読み込みに失敗")
		return
	_enemy = packed.instantiate() as Enemy
	_stage.add_child(_enemy)
	_enemy.global_position = ENEMY_POSITION
	_enemy.set_belt_bounds(BELT_Z_MIN, BELT_Z_MAX)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames >= MAX_FRAMES:
		print("[timeout] frames=%d case=%d" % [_frames, _case_index])
		_evaluate()
		return
	if _enemy == null or not is_instance_valid(_enemy) or not _enemy.is_inside_tree():
		return

	_step_frame += 1
	match _step:
		STEP_WARMUP:
			if _step_frame < WARMUP_FRAMES:
				return
			_down_x = _enemy.global_position.x
			_strike()
			if _enemy.current_state() != Enemy.State.DOWNED:
				_fail += 1
				print("[FAIL] knockback=%.1f: 1 撃でダウンしない（state=%d）"
					% [KNOCKBACK_CASES[_case_index], _enemy.current_state()])
			_step = STEP_SAMPLE
			_step_frame = 0
		STEP_SAMPLE:
			_samples.append(_enemy.global_position.x)
			if _step_frame == SETTLE_FRAMES:
				_settled_x = _enemy.global_position.x
			if _step_frame >= SAMPLE_FRAMES:
				_finish_case()


## 1 撃で倒す打撃を、実戦と同じ Hurtbox の入り口へ流す。
func _strike() -> void:
	var hurtbox := _enemy.get_node_or_null(^"Hurtbox") as Hurtbox
	if hurtbox == null:
		_fatal("敵の Hurtbox が見つからない")
		return
	_hitbox.configure(LETHAL_DAMAGE, KNOCKBACK_CASES[_case_index], true)
	hurtbox.receive_hit(_hitbox)


func _finish_case() -> void:
	var knockback: float = KNOCKBACK_CASES[_case_index]
	var end_x: float = _samples[_samples.size() - 1]
	var total: float = end_x - _down_x
	var tail: float = end_x - _settled_x
	var tick_rate: float = float(Engine.physics_ticks_per_second)
	var max_speed: float = 0.0
	var previous: float = _down_x
	for x: float in _samples:
		max_speed = maxf(max_speed, absf(x - previous) * tick_rate)
		previous = x
	_results.append({
		"knockback": knockback,
		"total": total,
		"tail": tail,
		"max_speed": max_speed,
	})
	print(("[case] knockback=%.1f  ダウン時 x=%.3f  %.2f秒後 x=%.3f  " \
			+ "総移動=%+.3fm  減衰後(%.2f秒以降)移動=%+.3fm  最大速度=%.3fm/s") % [
		knockback, _down_x, float(SAMPLE_FRAMES) / tick_rate, end_x,
		total, float(SETTLE_FRAMES) / tick_rate, tail, max_speed
	])
	_enemy.queue_free()
	_enemy = null
	if _case_index + 1 < KNOCKBACK_CASES.size():
		_start_case(_case_index + 1)
	else:
		_evaluate()


func _evaluate() -> void:
	for result: Dictionary in _results:
		var knockback: float = float(result["knockback"])
		var total: float = float(result["total"])
		var tail: float = float(result["tail"])
		_assert("knockback=%.1f: ダウン確定後、本体の x が動かない（|Δx|=%.3fm <= %.3fm）"
			% [knockback, absf(total), POSITION_TOLERANCE],
			absf(total) <= POSITION_TOLERANCE)
		_assert("knockback=%.1f: ノックバック減衰後も静止したまま（|Δx|=%.3fm <= %.3fm）"
			% [knockback, absf(tail), SETTLED_TOLERANCE],
			absf(tail) <= SETTLED_TOLERANCE)
	_assert("全ノックバック強度を測れた", _results.size() == KNOCKBACK_CASES.size())

	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)


func _assert(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("[PASS] %s" % label)
	else:
		_fail += 1
		print("[FAIL] %s" % label)


func _fatal(msg: String) -> void:
	print("[FATAL] %s" % msg)
	get_tree().quit(1)
