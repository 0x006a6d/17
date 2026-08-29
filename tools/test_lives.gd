extends Node

## 残機・コンティニューの検証（時間は物理フレーム基準。ヘッドレスでは _process が物理より速く回る）。
##   godot --path . --headless res://tools/test_lives.tscn
##
##   (1) プレイヤーが倒れるたびに RunState.lives が減り、残っていれば立ち上がる
##   (2) 残機が尽きると player_out_of_lives が出て立ち上がらない
##   (3) BeltStage がコンティニューのカードを出し、ui_accept で RunState.continues が減る
##       （シーン切替はテストでは行わない）

const STAGE := "res://levels/belt_test.tscn"
const MAX_FRAMES := 3000

var _pass: int = 0
var _fail: int = 0
var _belt: BeltStage = null
var _player: Node3D = null
var _health: Health = null
var _frames: int = 0
var _phase: int = 0
var _phase_started: int = 10
var _recovered: int = 0
var _out: int = 0
var _lives_seen: Array[int] = []


func _ready() -> void:
	print("=== 残機・コンティニュー 検証開始 ===")
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.reset()
	# 有限残機のロジックを検証する（無限化 playtest 既定を切る）。
	RunState.infinite_lives = false
	RunState.lives_changed.connect(func(l: int) -> void: _lives_seen.append(l))
	var stage := (load(STAGE) as PackedScene).instantiate() as Node3D
	_belt = BeltStage.new()
	_belt.player_path = ^"Player"
	_belt.camera_path = ^"BeltCamera"
	_belt.change_scene_on_continue = false
	_belt.continue_timeout = 3.0
	for child in stage.get_children():
		stage.remove_child(child)
		_belt.add_child(child)
	stage.queue_free()
	add_child(_belt)
	_player = _belt.get_node("Player") as Node3D
	_health = _player.get_node("Health") as Health
	_player.set("down_duration", 0.2)
	_player.set("stand_up_time", 0.2)
	_player.set("down_fall_time", 0.2)
	_player.connect("player_recovered", func() -> void: _recovered += 1)
	_player.connect("player_out_of_lives", func() -> void: _out += 1)


func _accept() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > MAX_FRAMES:
		_assert("全ケースが MAX_FRAMES 内に完了した (phase=%d)" % _phase, false)
		_finish()
		return
	if _frames < 10:
		return
	var local := _frames - _phase_started
	match _phase:
		0:
			if local == 1:
				_health.take_hit(_health.max_hp)
			if local == 60:
				_assert("(1) 1 回目のダウンで残機 3→2 (%s) 立ち上がり %d 回" % [str(_lives_seen), _recovered],
					RunState.lives == 2 and _recovered == 1)
				_health.take_hit(_health.max_hp)
			if local == 120:
				_assert("(1) 2 回目のダウンで残機 2→1、立ち上がる (%d)" % RunState.lives,
					RunState.lives == 1 and _recovered == 2)
				_health.take_hit(_health.max_hp)
			if local == 180:
				_assert("(2) 3 回目で残機 0、player_out_of_lives が出る (%d)" % _out,
					RunState.lives == 0 and _out == 1)
				_assert("(2) 立ち上がらない（復帰回数は 2 のまま）", _recovered == 2
					and bool(_player.call("is_downed")))
				_advance(1)
		1:
			if local == 10:
				var card := _belt.text_card()
				_assert("(3) コンティニューのカードが開く", card != null and bool(card.call("is_open")))
				_assert("(3) 表示中はツリーが止まる", get_tree().paused)
				_accept()
			if local == 14:
				_accept()
			# 1行=1ページなので、コンティニューのカードは2枚ある（見出しと案内）。
			if local == 18:
				_accept()
			if local == 24:
				_assert("(3) ui_accept で continues 3→2 (%d) 結果=%s" %
					[RunState.continues, _belt.continue_result()],
					RunState.continues == 2 and _belt.continue_result() == "continue")
				_assert("(3) コンティニュー後に残機が初期値へ戻る (%d)" % RunState.lives,
					RunState.lives == RunState.initial_lives)
				_finish()


func _advance(phase: int) -> void:
	_phase = phase
	_phase_started = _frames


func _assert(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[PASS] " + label)
	else:
		_fail += 1
		print("[FAIL] " + label)


func _finish() -> void:
	set_physics_process(false)
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)
