extends Node

## ボス戦の雑魚まわりの検証。
##   godot --path . --headless res://tools/test_boss_mobs.tscn
##
##   (1) 面に置いてあるボス（4面の盾持ち）はボス戦が始まるまで動かない
##   (2) ボス戦が始まると動き出す
##   (3) ボス戦の雑魚は同時 boss_mobs_max_alive 体まで
##   (4) 待たせた分は、出ている雑魚が倒れると出てくる

const STAGE_4 := "res://levels/stage_4.tscn"
const SETTLE_FRAMES: int = 30

var _pass: int = 0
var _fail: int = 0
var _stage: Node3D = null


func _ready() -> void:
	print("=== ボス戦の雑魚 検証開始 ===")
	# 冒頭カードがツリーを止めるので、この検証ノードだけは止めない。
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.reset()
	_run()


func _run() -> void:
	_stage = (load(STAGE_4) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	var boss := _stage.get_node(^"Shielder") as Node3D
	var trigger := _stage.get_node(^"BossTrigger") as BossTrigger
	var start_x: float = boss.global_position.x
	await _wait_frames(SETTLE_FRAMES)

	_assert("(1) ボス戦の前はボスの物理処理が止まっている", not boss.is_physics_processing())
	_assert("(1) ボス戦の前はボスがその場から動かない (dx=%.3f)" %
		absf(boss.global_position.x - start_x),
		absf(boss.global_position.x - start_x) < 0.01)

	# 上限の効き目を見るテストなので、面の供回りの数に左右されないよう1体に絞る。
	_stage.set("boss_mobs_max_alive", 1)
	trigger.reached.emit(trigger)
	await _wait_frames(SETTLE_FRAMES)
	_assert("(2) ボス戦が始まるとボスが動き出す", boss.is_physics_processing())

	var limit: int = int(_stage.get("boss_mobs_max_alive"))
	var escorts: Array = _stage.get("boss_escorts")
	_assert("(3) 供回りは上限より多い (%d体 / 上限 %d体)" % [escorts.size(), limit],
		escorts.size() > limit)
	_assert("(3) 同時に出ている雑魚は上限まで (%d体)" % _mob_count(),
		_mob_count() == limit)

	# 出ている1体を倒すと、待たせていた分が出てくる。
	var mobs: Array[Node3D] = _mobs()
	var health := mobs[0].get_node(^"Health") as Health
	health.take_hit(health.current_hp(), true, true)
	await _wait_frames(SETTLE_FRAMES)
	_assert("(4) 1体倒すと待たせていた分が出て、上限のまま (%d体)" % _mob_count(),
		_mob_count() == limit)

	_stage.queue_free()
	await _wait_frames(2)
	_finish()


## ボスを除いた、生きている敵の数。
func _mobs() -> Array[Node3D]:
	var boss := _stage.get_node_or_null(^"Shielder")
	var found: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node3D
		if enemy == null or enemy == boss or not is_instance_valid(enemy):
			continue
		var health := enemy.get_node_or_null(^"Health") as Health
		if health == null or health.is_downed():
			continue
		found.append(enemy)
	return found


func _mob_count() -> int:
	return _mobs().size()


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
