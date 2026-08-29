extends Node

## ボスが HP の割合で増援を呼ぶことの検証。
##   godot --path . --headless res://tools/test_boss_adds.tscn
##
##   (1) 3面ボスは増援を呼ばない（ボス戦に雑魚を出さない面）
##   (2) 4面ボスは HP30% で1回だけ4体を呼ぶ
##   (3) 5面のニケは HP50% / 30% / 15% で2体ずつ、計3回呼ぶ
##   (4) 閾値を跨いでも同じ閾値では二度呼ばない

const STAGE_PATH: String = "res://levels/belt_test.tscn"
const STAGE_3_BOSS: String = "res://actors/enemy/bosses/stage_3_boss.tscn"
const STAGE_4_BOSS: String = "res://actors/enemy/bosses/stage_4_boss.tscn"
const NIKE: String = "res://actors/boss/nike.tscn"
const SETTLE_FRAMES: int = 6

var _pass: int = 0
var _fail: int = 0
var _stage: Node3D = null


func _ready() -> void:
	print("=== ボスの増援 検証開始 ===")
	_run()


func _run() -> void:
	RunState.reset()
	_stage = (load(STAGE_PATH) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	for dummy_name: String in ["Dummy1", "Dummy2", "Dummy3"]:
		var dummy := _stage.get_node_or_null(NodePath(dummy_name)) as Node3D
		if dummy != null:
			dummy.global_position = Vector3(60.0, 0.2, 0.0)
	await _wait_frames(SETTLE_FRAMES)

	await _check_no_adds(STAGE_3_BOSS, "3面ボス")
	await _check(STAGE_4_BOSS, "4面ボス", [0.3], 4)
	await _check(NIKE, "5面のニケ", [0.5, 0.3, 0.15], 2)
	_finish()


## HP を 0 まで削っても増援が1度も要請されないことを見る。
func _check_no_adds(path: String, label: String) -> void:
	var boss := (load(path) as PackedScene).instantiate() as Node3D
	_stage.add_child(boss)
	boss.global_position = Vector3(40.0, 0.2, 0.0)
	boss.set_physics_process(false)
	await _wait_frames(SETTLE_FRAMES)
	var health := boss.get_node(^"Health") as Health
	var calls: Array[int] = []
	boss.connect("adds_requested", func(count: int) -> void: calls.append(count))
	_assert("%s の増援閾値は空" % label, Array(boss.get("adds_hp_ratios")).is_empty())
	_assert("%s の増援体数は 0" % label, int(boss.get("adds_count")) == 0)
	health.take_hit(health.current_hp())
	await _wait_frames(4)
	_assert("%s は HP0 まで削っても増援を呼ばない" % label, calls.is_empty())
	boss.queue_free()
	await _wait_frames(2)


## ratios の割合を上から順に下回らせ、そのたびに1回ずつ増援が要請されることを見る。
func _check(path: String, label: String, ratios: Array, expected_count: int) -> void:
	var boss := (load(path) as PackedScene).instantiate() as Node3D
	_stage.add_child(boss)
	boss.global_position = Vector3(40.0, 0.2, 0.0)
	boss.set_physics_process(false)
	await _wait_frames(SETTLE_FRAMES)
	var health := boss.get_node(^"Health") as Health
	var calls: Array[int] = []
	boss.connect("adds_requested", func(count: int) -> void: calls.append(count))

	_assert("%s の閾値は %s" % [label, str(ratios)],
		Array(boss.get("adds_hp_ratios")) == ratios)
	for i: int in range(ratios.size()):
		var ratio: float = ratios[i]
		# 閾値をわずかに下回るところまで削る。
		var target: float = health.max_hp * ratio - 1.0
		health.take_hit(health.current_hp() - target)
		await _wait_frames(2)
		_assert("%s は HP%d%% で %d 回目の増援を呼ぶ" % [label, int(ratio * 100.0), i + 1],
			calls.size() == i + 1)
		if not calls.is_empty():
			_assert("%s の増援は %d 体" % [label, expected_count],
				calls[calls.size() - 1] == expected_count)
		# 同じ閾値の下で削り続けても増えないこと。
		health.take_hit(1.0)
		await _wait_frames(2)
		_assert("%s は同じ閾値で二度呼ばない" % label, calls.size() == i + 1)
	boss.queue_free()
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
