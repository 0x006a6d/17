extends Node

## 攻撃時の擬音表示の検証。
##   godot --path . --headless res://tools/test_attack_cry.tscn
##
##   (1) 銃で「ぱん」、刀で「ぶん」、素手で「ふっ」が出る
##   (2) 位置は頭の上で、向いている方向へ寄る
##   (3) 向きを変えると出る側も変わる
##   (4) 寿命が過ぎると消える
##   (5) ドロップキック（△必殺）で「でやあ」が出て、踏み込んでも文字はその場に残る

const STAGE: String = "res://levels/belt_test.tscn"
const SETTLE_FRAMES: int = 6

var _pass: int = 0
var _fail: int = 0
var _shown: Array = []


func _ready() -> void:
	print("=== 攻撃時の擬音 検証開始 ===")
	_run()


func _run() -> void:
	RunState.reset()
	var stage := (load(STAGE) as PackedScene).instantiate() as Node3D
	add_child(stage)
	var player := stage.get_node(^"Player") as Node3D
	var cry := player.get_node(^"AttackCry3D") as AttackCry3D
	cry.cry_shown.connect(func(text: String, pos: Vector3) -> void: _shown.append([text, pos]))
	await _wait_frames(SETTLE_FRAMES)
	player.set("_facing", 1)

	var weapon := player.get_node(^"PlayerWeapon") as PlayerWeapon
	var katana := player.get_node(^"PlayerKatanaCombo")
	var melee := player.get_node(^"PlayerMelee")

	# 出した瞬間の立ち位置を基準にする（あとで測ると、その間に動いたぶんずれる）。
	var origin: Vector3 = player.global_position
	weapon.fired.emit()
	katana.emit_signal("stage_started", 1)
	melee.emit_signal("stage_started", &"jab", 1)
	await _wait_frames(2)
	var texts: Array = []
	for entry: Array in _shown:
		texts.append(entry[0])
	_assert("(1) 銃・刀・素手の3つが出る (%s)" % str(texts), texts == ["ぱん", "ぶん", "ふっ"])

	var head_top: float = float(cry.head_height)
	var pos: Vector3 = _shown[0][1]
	_assert("(2) 頭の上に出る (y=%.2f > %.2f)" % [pos.y, head_top], pos.y > head_top)
	_assert("(2) 向いている方向（+X）へ寄る (dx=%.2f)" % (pos.x - origin.x),
		pos.x - origin.x > 0.0)
	var forward: float = float(cry.head_size) * float(cry.forward_heads)
	_assert("(2) 前へ出す距離は頭ふたつぶん (%.2fm)" % forward,
		is_equal_approx(pos.x - origin.x, forward))

	_shown.clear()
	player.set("_facing", -1)
	var back_origin: Vector3 = player.global_position
	weapon.fired.emit()
	await _wait_frames(2)
	var back: Vector3 = _shown[0][1]
	_assert("(3) 逆を向くと反対側に出る (dx=%.2f)" % (back.x - back_origin.x),
		back.x - back_origin.x < 0.0)

	var before: int = cry.get_child_count()
	_assert("(4) 出している間はノードがある (%d 個)" % before, before > 0)
	await _wait_seconds(cry.lifetime + 0.2)
	_assert("(4) 寿命が過ぎると消える (%d 個)" % cry.get_child_count(), cry.get_child_count() == 0)

	_shown.clear()
	player.set("_facing", 1)
	var press_x: float = player.global_position.x
	var special := InputEventAction.new()
	special.action = "special"
	special.pressed = true
	Input.parse_input_event(special)
	await _wait_frames(4)
	var special_texts: Array = []
	for entry: Array in _shown:
		special_texts.append(entry[0])
	_assert("(5) ドロップキックで「%s」が出る (%s)" % [cry.dropkick_text, str(special_texts)],
		special_texts == [cry.dropkick_text])
	if not _shown.is_empty():
		var kick: Vector3 = _shown[0][1]
		_assert("(5) 位置は他の技と同じ（頭の上・向いている方向） (y=%.2f, dx=%.2f)"
			% [kick.y, kick.x - press_x],
			kick.y > float(cry.head_height) and kick.x - press_x > 0.0)
		# 踏み込みで本体は前へ出るが、文字は出した場所に残る（anchor が top_level）。
		# 踏み込みは _physics_process が動かすので、待つのは物理フレームで数える。
		# 描画フレームで数えると、速い環境では物理が1回も進まないまま「動いていない
		# ＝文字もずれていない」で通ってしまう。
		var anchor := cry.get_child(0) as Node3D if cry.get_child_count() > 0 else null
		if anchor == null:
			_assert("(5) 擬音のノードが残っている", false)
		else:
			var anchor_x: float = anchor.global_position.x
			await _wait_physics_frames(12)
			var moved: float = player.global_position.x - press_x
			var alive: bool = is_instance_valid(anchor)
			var drift: float = absf(anchor.global_position.x - anchor_x) if alive else INF
			_assert("(5) 踏み込んでも文字はその場に残る (体 +%.2fm / 文字 %.3fm)"
				% [moved, drift],
				alive and moved > 0.0 and is_equal_approx(drift, 0.0))

	stage.queue_free()
	await _wait_frames(2)
	_finish()


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _wait_physics_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


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
