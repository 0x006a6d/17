extends Node

## バーストの残弾が「撃ち始めの狙い点」に縛られていること、ステートを抜けると
## 打ち切られることの検証。
##   godot --path . --headless res://tools/test_gun_boss_burst_gates.tscn
##
##   (1) 1発目のあとに段を外すと、残りの4発は当たらない（1発ぶんしか減らない）
##   (2) 1発目のあとに怯ませると、残りは撃たれない

const STAGE: String = "res://levels/belt_test.tscn"
const BOSS: String = "res://actors/enemy/bosses/stage_3_boss.tscn"
const SETTLE_FRAMES: int = 10
## バーストが終わるのを待つフレーム数（残り4発 × 0.18秒 ＋ 余裕）。
const BURST_FRAMES: int = 120
## 1発目を待つ上限。
const FIRST_SHOT_FRAMES: int = 600
## 段を外す量（m）。gun_depth_tolerance 0.45 と当たり判定の半径 0.45 を越える。
const DODGE_DEPTH: float = 1.4
## 怯ませるために入れるダメージ。bruiser の poise 5600 を一撃で越える。
const STAGGER_DAMAGE: float = 6000.0

var _pass: int = 0
var _fail: int = 0


func _ready() -> void:
	print("=== バーストの狙い点と打ち切り 検証開始 ===")
	RunState.reset()
	await _case_lane_dodge()
	await _case_stagger_cancels()
	_finish()


## 撃ち始めたあとに段を外す。狙い点が固定なら、残りの4発は空を切る。
func _case_lane_dodge() -> void:
	var setup: Dictionary = await _build()
	var player: Node3D = setup["player"]
	var health: Health = setup["health"]
	var shots: Array = setup["shots"]
	if shots.is_empty():
		_assert("(1) ボスが撃ち始める", false)
		await _teardown(setup)
		return
	var hp_after_first: float = health.current_hp()
	player.global_position += Vector3(0.0, 0.0, DODGE_DEPTH)
	await _wait_frames(BURST_FRAMES)
	var taken_after_dodge: float = hp_after_first - health.current_hp()
	_assert("(1) 撃ち始めのあと段を外すと残りは当たらない (以後の被弾 %.0f)"
		% taken_after_dodge, is_zero_approx(taken_after_dodge))
	_assert("(1) 残りの弾は撃たれている (%d 発)" % shots.size(), shots.size() >= 2)
	await _teardown(setup)


## 撃ち始めたあとにボスを怯ませる。GUN_COMBAT を抜けるので残りは出ない。
func _case_stagger_cancels() -> void:
	var setup: Dictionary = await _build()
	var boss: Node3D = setup["boss"]
	var shots: Array = setup["shots"]
	if shots.is_empty():
		_assert("(2) ボスが撃ち始める", false)
		await _teardown(setup)
		return
	var boss_health := boss.get_node(^"Health") as Health
	boss_health.take_hit(STAGGER_DAMAGE)
	var shots_at_stagger: int = shots.size()
	await _wait_frames(BURST_FRAMES)
	_assert("(2) 怯ませると残りは撃たれない (%d 発のまま)" % shots.size(),
		shots.size() == shots_at_stagger)
	await _teardown(setup)


## ステージとボスを組み、1発目が出るまで待つ。
func _build() -> Dictionary:
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
	var shots: Array = []
	var gun := boss.get_node(^"HitscanGun") as HitscanGun
	gun.shot_fired.connect(func(_f: Vector3, _t: Vector3, _b: Node3D) -> void:
		shots.append(1))
	var waited: int = 0
	while shots.is_empty() and waited < FIRST_SHOT_FRAMES:
		await get_tree().process_frame
		waited += 1
	return {"stage": stage, "player": player, "health": health,
		"boss": boss, "shots": shots}


func _teardown(setup: Dictionary) -> void:
	var stage: Node3D = setup["stage"]
	stage.queue_free()
	await _wait_frames(2)


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
