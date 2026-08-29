extends Node

## 4面・5面のゾンビが怯まないことの検証。
##   godot --path . --headless res://tools/test_zombie_poise.tscn
##
##   (1) 通常の雑魚は poise を超える被弾でのけぞる
##   (2) 4面のゾンビはのけぞらない
##   (3) 5面の増援は、守衛はのけぞり、ニケ素体はのけぞらない
##   (4) のけぞらない敵も HP は減り、倒れる

const STAGE_PATH: String = "res://levels/belt_test.tscn"
const CASES: Array = [
	["res://actors/enemy/enemy.tscn", "通常の雑魚", true],
	["res://actors/enemy/roles/zombie.tscn", "4面のゾンビ", false],
	["res://actors/enemy/roles/zombie_c_yellow.tscn", "4面のゾンビ（色違い）", false],
	["res://actors/enemy/roles/zombie_escort.tscn", "4面ボス戦のゾンビ", false],
	["res://actors/enemy/roles/final_guard.tscn", "5面の守衛", true],
	["res://actors/enemy/roles/nike_blank.tscn", "5面のニケ素体", false],
]
const SETTLE_FRAMES: int = 6
const REACT_FRAMES: int = 6
## poise（2800）を確実に超える一撃。
const BIG_HIT: float = 12000.0

var _pass: int = 0
var _fail: int = 0
var _stage: Node3D = null


func _ready() -> void:
	print("=== ゾンビの怯み 検証開始 ===")
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

	for case: Array in CASES:
		var path: String = case[0]
		var label: String = case[1]
		var expects_stagger: bool = case[2]
		var enemy := await _spawn(path)
		var health := enemy.get_node(^"Health") as Health
		health.take_hit(BIG_HIT)
		await _wait_frames(REACT_FRAMES)
		var staggered: bool = int(enemy.call("current_state")) == Enemy.State.STAGGERED
		if expects_stagger:
			_assert("(1) %s は大きな被弾でのけぞる" % label, staggered)
		else:
			_assert("(2〜3) %s はのけぞらない" % label, not staggered)
		_assert("(4) %s は HP が減る (%.0f)" % [label, health.current_hp()],
			health.current_hp() < health.max_hp)
		if not expects_stagger:
			health.take_hit(health.current_hp(), true, true)
			await _wait_frames(REACT_FRAMES)
			_assert("(4) %s は倒れる" % label, health.is_downed())
		enemy.queue_free()
		await _wait_frames(2)

	_finish()


func _spawn(path: String) -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	_stage.add_child(node)
	node.global_position = Vector3(40.0, 0.2, 0.0)
	node.set_physics_process(false)
	await _wait_frames(SETTLE_FRAMES)
	return node


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
