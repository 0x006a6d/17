extends Node

## 回復量を水色の数字で出すことの検証。
##   godot --path . --headless res://tools/test_heal_number.tscn
##
##   (1) 回復すると数字が1つ出る
##   (2) 間隔（heal_number_interval）ぶんの回復はまとめて1つにする
##   (3) 数字の色は水色で、被弾の色とは別
##   (4) 満タンで回復しても数字は出ない

const STAGE_PATH: String = "res://levels/belt_test.tscn"
const SETTLE_FRAMES: int = 6

var _pass: int = 0
var _fail: int = 0
var _spawned: Array[float] = []


func _ready() -> void:
	print("=== 回復の数字 検証開始 ===")
	_run()


func _run() -> void:
	RunState.reset()
	var stage := (load(STAGE_PATH) as PackedScene).instantiate() as Node3D
	add_child(stage)
	var player := stage.get_node(^"Player") as Node3D
	var health := player.get_node(^"Health") as Health
	var feedback := player.get_node(^"DamageFeedback3D") as DamageFeedback3D
	# まとめた合計を厳密に見るので、この検証では端数の揺らぎを切る。
	health.damage_variance = 0.0
	feedback.heal_spawned.connect(func(amount: float) -> void: _spawned.append(amount))
	await _wait_frames(SETTLE_FRAMES)

	_assert("(3) 回復の色が水色（青と緑が赤より大きい）",
		feedback.heal_color.b > feedback.heal_color.r
		and feedback.heal_color.g > feedback.heal_color.r)
	_assert("(3) 回復の色は被弾の色と別", feedback.heal_color != feedback.damage_color)

	health.take_hit(10000.0)
	await _wait_frames(2)
	_spawned.clear()

	# 間隔の中に3回入れる。1つにまとまるはず。
	health.heal(300.0)
	health.heal(300.0)
	health.heal(400.0)
	await _wait_seconds(feedback.heal_number_interval + 0.1)
	_assert("(1)(2) 間隔内の回復は1つの数字にまとまる (出た数=%d)" % _spawned.size(),
		_spawned.size() == 1)
	if not _spawned.is_empty():
		_assert("(2) まとめた数字は合計値 (%.0f)" % _spawned[0],
			is_equal_approx(_spawned[0], 1000.0))

	_spawned.clear()
	health.heal(500.0)
	await _wait_seconds(feedback.heal_number_interval + 0.1)
	_assert("(1) 次の回復はまた数字が出る (出た数=%d)" % _spawned.size(), _spawned.size() == 1)

	health.revive()
	_spawned.clear()
	health.heal(500.0)
	await _wait_seconds(feedback.heal_number_interval + 0.1)
	_assert("(4) 満タンでは数字が出ない (出た数=%d)" % _spawned.size(), _spawned.is_empty())

	stage.queue_free()
	await _wait_frames(2)
	_finish()


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _assert(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[PASS] " + label)
	else:
		_fail += 1
		print("[FAIL] " + label)


func _finish() -> void:
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)
