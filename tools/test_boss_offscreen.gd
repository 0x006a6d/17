extends Node

## 距離を取る敵が画面外へ逃げないことの検証（technical-spec §8.2.1）。
##   godot --path . --headless res://tools/test_boss_offscreen.tscn
##
## 面と同じ手順で、3面ボスを画面外（右端の外側 spawn_margin）から出し、プレイヤーが
## 詰め続けて後退させる。ボスは gun_preferred_distance 4.5m を保つので、余白の内側まで
## 入って来ないことがある。「画面に入った」を余白の内側で判定していると、この個体は
## 判定が立たないまま後退し続けられる（修正前の実測: 2.56m はみ出したまま戻らない）。
##
##   (1) ボスが画面内に入る
##   (2) 詰め続けても画面（可視範囲）の外へ出ない
##   (3) 最後は余白の内側（右端から screen_margin）まで収まる

const STAGE: String = "res://levels/belt_test.tscn"
const BOSS: String = "res://actors/enemy/bosses/stage_3_boss.tscn"
## BeltStage._spawn_enemy と同じ、画面端から外側への出現距離（m）。
const SPAWN_MARGIN: float = 1.5
const FRAMES: int = 420
## プレイヤーを1フレームに詰める量（m）。
const PUSH_STEP: float = 0.04
## 判定の許容（m）。物理1フレームぶんの行き過ぎを見込む。
const TOLERANCE: float = 0.05

var _pass: int = 0
var _fail: int = 0


func _ready() -> void:
	print("=== 画面外へ逃げないか 検証開始 ===")
	RunState.reset()
	_run()


func _run() -> void:
	var stage := (load(STAGE) as PackedScene).instantiate() as Node3D
	add_child(stage)
	for dummy_name: String in ["Dummy1", "Dummy2", "Dummy3"]:
		var dummy := stage.get_node_or_null(NodePath(dummy_name)) as Node3D
		if dummy != null:
			dummy.global_position = Vector3(80.0, 0.2, 0.0)
	var player := stage.get_node(^"Player") as Node3D
	var camera: Node3D = stage.get_node_or_null(^"BeltCamera")
	if camera == null:
		camera = get_tree().get_first_node_in_group(&"belt_camera") as Node3D
	player.global_position = Vector3(10.0, 0.2, 0.0)
	await _wait(10)
	# ボス戦と同じくカメラを固定する。
	camera.call("lock_at", camera.position.x)
	var boss := (load(BOSS) as PackedScene).instantiate() as Node3D
	stage.add_child(boss)
	boss.global_position = Vector3(
		float(camera.call("right_limit")) + SPAWN_MARGIN, 0.2, 0.0)
	boss.call("set_belt_bounds", -1.5, 1.5)

	var entered: bool = false
	var worst_visible: float = 0.0
	var last_over_margin: float = 0.0
	for _frame: int in range(FRAMES):
		if is_instance_valid(boss):
			var to_boss: float = boss.global_position.x - player.global_position.x
			if absf(to_boss) > 1.2:
				player.global_position.x += signf(to_boss) * PUSH_STEP
		await get_tree().process_frame
		if not is_instance_valid(boss):
			break
		var right: float = float(camera.call("right_limit"))
		var margin: float = float(boss.get("screen_margin"))
		if boss.global_position.x < right:
			entered = true
		if entered:
			worst_visible = maxf(worst_visible, boss.global_position.x - right)
		last_over_margin = boss.global_position.x - (right - margin)

	_assert("(1) ボスが画面内に入った", entered)
	_assert("(2) 詰め続けても可視範囲の外へ出ない（最大はみ出し %.3f m）" % worst_visible,
		worst_visible <= TOLERANCE)
	_assert("(3) 余白の内側まで収まる（右端の内側から %+.3f m）" % last_over_margin,
		last_over_margin <= TOLERANCE)
	_finish()


func _wait(count: int) -> void:
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
