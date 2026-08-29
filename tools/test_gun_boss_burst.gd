extends Node

## 3面ボスのバースト射撃の検証。
##   godot --path . --headless res://tools/test_gun_boss_burst.tscn
##
##   (1) 1回の射撃で burst_count 発撃つ
##   (2) 発砲の間隔は burst_interval
##   (3) 撃ち終わってから次の射撃まで gun_fire_interval 空く
##   (4) 5発ぶんの威力でプレイヤーは瀕死になるが、1回では倒れない

const STAGE: String = "res://levels/belt_test.tscn"
const BOSS: String = "res://actors/enemy/bosses/stage_3_boss.tscn"
const SETTLE_FRAMES: int = 10
## バーストが終わるのを待つフレーム数（5発 × 0.18秒 ＋ 余裕）。
const BURST_FRAMES: int = 150

var _pass: int = 0
var _fail: int = 0
var _times: Array[float] = []
var _elapsed: float = 0.0
var _counting: bool = false


func _ready() -> void:
	print("=== ボスのバースト射撃 検証開始 ===")
	RunState.reset()
	_run()


func _process(delta: float) -> void:
	if _counting:
		_elapsed += delta


func _run() -> void:
	var stage := (load(STAGE) as PackedScene).instantiate() as Node3D
	add_child(stage)
	for dummy_name: String in ["Dummy1", "Dummy2", "Dummy3"]:
		var dummy := stage.get_node_or_null(NodePath(dummy_name)) as Node3D
		if dummy != null:
			dummy.global_position = Vector3(60.0, 0.2, 0.0)
	var player := stage.get_node(^"Player") as Node3D
	var health := player.get_node(^"Health") as Health
	health.damage_variance = 0.0
	var boss := (load(BOSS) as PackedScene).instantiate() as Node3D
	stage.add_child(boss)
	player.global_position = Vector3(10.0, 0.2, 0.0)
	boss.global_position = Vector3(14.5, 0.2, 0.0)
	await _wait_frames(SETTLE_FRAMES)

	var gun := boss.get_node(^"HitscanGun") as HitscanGun
	gun.shot_fired.connect(func(_f: Vector3, _t: Vector3, _b: Node3D) -> void:
		_times.append(_elapsed))
	_counting = true
	# ボスは歩き込み・向き直り・射線の確認を済ませてから撃つ。1発目を待ってから測る。
	var waited: int = 0
	while _times.is_empty() and waited < 600:
		await get_tree().process_frame
		waited += 1
	_assert("(1) ボスが撃ち始める (%d フレーム待った)" % waited, not _times.is_empty())
	if _times.is_empty():
		# 撃たないままなら、この先は測れない（空の配列を読むと落ちて結果が出ない）。
		stage.queue_free()
		await _wait_frames(2)
		_finish()
		return
	await _wait_frames(BURST_FRAMES)
	_counting = false
	var start_hp: float = health.max_hp

	var offsets: PackedStringArray = []
	for t: float in _times:
		offsets.append("%.2f" % (t - _times[0]))
	print("[発砲] 1発目からの秒数: " + ", ".join(offsets))
	var count: int = int(boss.get("burst_count"))
	var interval: float = float(boss.get("burst_interval"))
	_assert("(1) 1回の射撃で %d 発撃つ (%d 発)" % [count, _times.size()],
		_times.size() == count)
	if _times.size() >= 2:
		var gaps: Array[float] = []
		for i: int in range(1, _times.size()):
			gaps.append(_times[i] - _times[i - 1])
		var worst: float = 0.0
		for g: float in gaps:
			worst = maxf(worst, absf(g - interval))
		_assert("(2) 発砲の間隔は %.2f秒（ずれ最大 %.3f秒）" % [interval, worst], worst <= 0.05)

	var taken: float = start_hp - health.current_hp()
	var expected: float = float(boss.get("gun_damage")) * float(count)
	_assert("(4) 5発ぶんの威力が入る (%.0f / %.0f)" % [taken, expected],
		is_equal_approx(taken, expected))
	_assert("(4) 1回のバーストでは倒れない (残り %.0f)" % health.current_hp(),
		not health.is_downed() and health.current_hp() > 0.0)
	_assert("(4) ただし瀕死になる（残りが最大の3割以下）",
		health.current_hp() <= health.max_hp * 0.3)

	var before: int = _times.size()
	await _wait_frames(int(float(boss.get("gun_fire_interval")) * 60.0) - 20)
	_assert("(3) 次の射撃まで間が空く (%d 発のまま)" % _times.size(), _times.size() == before)
	# 間が空くだけでなく、そのあとちゃんと撃ち直すこと（撃たなくなる実装でも上は通る）。
	_counting = true
	var waited_again: int = 0
	while _times.size() == before and waited_again < 240:
		await get_tree().process_frame
		waited_again += 1
	_assert("(3) 間が空いたあと撃ち直す (%d 発へ増えた)" % _times.size(),
		_times.size() > before)

	stage.queue_free()
	await _wait_frames(2)
	_finish()


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


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
