extends Node

## 入力マップの検証。キーボードとパッド (PS5 DualSense / PS4 DualShock 4) の
## 両方が各アクションに登録されていることをヘッドレスで確認する。
## (実機のパッド動作確認は人間に委ねる。ここでは登録の有無のみ)
##
## 実行: godot --path . --headless res://tools/test_input_map.tscn

var _pass: int = 0
var _fail: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== 入力マップ 検証開始 ===")
	InputMap.load_from_project_settings()

	# [action, 期待キー physical_keycode 群, 期待 joypad button 群, 期待 joypad axis (axis, sign) 群]
	_check("move_forward", [KEY_W], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1]])
	_check("move_back", [KEY_S], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1]])
	_check("move_left", [KEY_A], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1]])
	_check("move_right", [KEY_D], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1]])
	_check("attack", [KEY_J], [JOY_BUTTON_X], [])              # □
	_check("kick", [KEY_K], [JOY_BUTTON_A], [])                # ×
	_check("interact", [KEY_E], [JOY_BUTTON_B], [])            # ○
	_check("fire", [KEY_U], [], [[JOY_AXIS_TRIGGER_RIGHT, 1]])
	_check("reload", [KEY_R], [], [[JOY_AXIS_TRIGGER_LEFT, 1]])
	_check("dodge", [KEY_SPACE], [JOY_BUTTON_RIGHT_SHOULDER], [])  # R1
	_check("special", [KEY_O], [JOY_BUTTON_Y], [])                 # △
	_check("switch_weapon", [KEY_TAB], [JOY_BUTTON_LEFT_SHOULDER], [])  # L1
	_check("ui_accept", [KEY_ENTER, KEY_SPACE], [JOY_BUTTON_B, JOY_BUTTON_START], [])  # ○ / Options
	# ベルトスクロール化・手榴弾廃止・つかみ削除で消したアクションが無いこと。
	for removed: String in ["throw", "switch_mode", "lock_on", "camera_left", "camera_right", "grab"]:
		_assert_absent(removed)

	# マウスイベントが残っていないこと (キーボード/パッド完結)。
	var mouse_found := false
	for action in InputMap.get_actions():
		if str(action).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventMouseButton or ev is InputEventMouseMotion:
				mouse_found = true
				print("  [warn] mouse event in ", action)
	_assert("マウスイベントが登録されていない", not mouse_found)

	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)


func _check(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if not InputMap.has_action(action):
		_assert("%s: アクションが存在する" % action, false)
		return
	var events := InputMap.action_get_events(action)
	for want_key in keys:
		var found := false
		for ev in events:
			var k := ev as InputEventKey
			if k != null and k.physical_keycode == want_key:
				found = true
		_assert("%s: キー %s" % [action, OS.get_keycode_string(want_key)], found)
	for want_btn in buttons:
		var found := false
		for ev in events:
			var b := ev as InputEventJoypadButton
			if b != null and b.button_index == want_btn:
				found = true
		_assert("%s: パッドボタン %d" % [action, want_btn], found)
	for want_axis in axes:
		var found := false
		for ev in events:
			var m := ev as InputEventJoypadMotion
			if m != null and m.axis == int(want_axis[0]) and signf(m.axis_value) == signf(float(want_axis[1])):
				found = true
		_assert("%s: パッド軸 %d (%+d)" % [action, int(want_axis[0]), int(want_axis[1])], found)


func _assert(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("[PASS] %s" % label)
	else:
		_fail += 1
		print("[FAIL] %s" % label)


func _assert_absent(action: String) -> void:
	if InputMap.has_action(action):
		_fail += 1
		print("[FAIL] 廃止済みアクション %s が残っている" % action)
	else:
		_pass += 1
		print("[PASS] 廃止済みアクション %s は無い" % action)
