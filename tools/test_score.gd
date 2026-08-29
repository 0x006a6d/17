extends Node

## 得点と結果画面の検証（8/26）。
##   godot --path . --headless res://tools/test_score.tscn
##
##   (1) 武器の順が 素手 → 日本刀 → 銃 で、開始は素手
##   (2) 同じ段なら 素手 > 日本刀 > 銃 の配点
##   (3) コンボの段が進むほど1発の加点が増える
##   (4) 撃破で加点、死亡で減点し、0 未満にはならない
##   (5) HUD の右上に得点が出る
##   (6) 結果画面の文言が「私は #AIニケちゃん で N,NNN 回ヌキました（2025年8月からの累計）」で、
##       得点は3桁区切り。投稿 URL にも載る

const STAGE_PATH: String = "res://levels/belt_test.tscn"
const RESULT_PANEL_PATH: String = "res://ui/result_panel.tscn"
const SETTLE_FRAMES: int = 6

var _pass: int = 0
var _fail: int = 0


func _ready() -> void:
	print("=== 得点と結果画面 検証開始 ===")
	_run()


func _run() -> void:
	await _check_weapon_order()
	_check_score_rules()
	await _check_hud()
	_check_result_panel()
	_finish()


func _check_weapon_order() -> void:
	var stage := (load(STAGE_PATH) as PackedScene).instantiate() as Node3D
	add_child(stage)
	var player := stage.get_node(^"Player") as Node3D
	var weapon := player.get_node(^"PlayerWeapon") as PlayerWeapon
	await _wait_frames(SETTLE_FRAMES)
	_assert("(1) 開始は素手", weapon.kind() == PlayerWeapon.WeaponKind.NONE)
	weapon.call("_switch_weapon")
	_assert("(1) 素手の次は日本刀", weapon.kind() == PlayerWeapon.WeaponKind.KATANA)
	weapon.call("_switch_weapon")
	_assert("(1) 日本刀の次は銃", weapon.kind() == PlayerWeapon.WeaponKind.GUN)
	_assert("(1) 銃はリロードできる", weapon.max_ammo() > 0)
	weapon.set("_ammo", 0)
	weapon.call("_try_reload")
	_assert("(1) reload でリロードが始まる", weapon.is_reloading())
	weapon.call("_switch_weapon")
	_assert("(1) 銃の次は素手へ戻る", weapon.kind() == PlayerWeapon.WeaponKind.NONE)
	stage.queue_free()
	await _wait_frames(2)


func _check_score_rules() -> void:
	RunState.reset()
	RunState.add_hit_score(GameTypes.ScoreWeapon.UNARMED)
	var unarmed: int = RunState.score
	RunState.reset()
	RunState.add_hit_score(GameTypes.ScoreWeapon.KATANA)
	var katana: int = RunState.score
	RunState.reset()
	RunState.add_hit_score(GameTypes.ScoreWeapon.GUN)
	var gun: int = RunState.score
	_assert("(2) 素手 %d > 日本刀 %d > 銃 %d" % [unarmed, katana, gun],
		unarmed > katana and katana > gun)

	RunState.reset()
	for stage in range(1, 6):
		RunState.add_hit_score(GameTypes.ScoreWeapon.UNARMED, stage)
	var chained: int = RunState.score
	RunState.reset()
	for _i in range(5):
		RunState.add_hit_score(GameTypes.ScoreWeapon.UNARMED, 1)
	var singles: int = RunState.score
	_assert("(3) 5段繋いだ %d が単発5回 %d より高い" % [chained, singles],
		chained > singles)

	RunState.reset()
	RunState.add_defeat_score()
	_assert("(4) 撃破で加点 (%d)" % RunState.score, RunState.score > 0)
	var before_death: int = RunState.score
	RunState.apply_death_penalty()
	_assert("(4) 死亡で減点 (%d→%d)" % [before_death, RunState.score],
		RunState.score < before_death)
	for _i in range(10):
		RunState.apply_death_penalty()
	_assert("(4) 減点しても 0 未満にならない (%d)" % RunState.score, RunState.score == 0)


func _check_hud() -> void:
	var stage := (load(STAGE_PATH) as PackedScene).instantiate() as Node3D
	add_child(stage)
	var hud := stage.get_node(^"Hud") as Hud
	await _wait_frames(SETTLE_FRAMES)
	RunState.reset()
	RunState.add_defeat_score()
	await _wait_frames(2)
	var label := hud.get_node(^"Screen/ScorePanel/Margin/Rows/ScoreLabel") as Label
	_assert("(5) HUD の得点表示が RunState と一致 (%s)" % label.text,
		label.text == str(RunState.score))
	_assert("(5) 得点欄は画面右上（右端に寄せて上端から 100px 以内）",
		label.get_global_rect().position.y < 100.0
		and label.get_global_rect().end.x > hud.get_node(^"Screen").size.x * 0.6)
	stage.queue_free()
	await _wait_frames(2)


func _check_result_panel() -> void:
	var panel := (load(RESULT_PANEL_PATH) as PackedScene).instantiate() as ResultPanel
	add_child(panel)
	panel.show_result(1234, true)
	_assert("(6) 投稿の文言が指定どおり (%s)" % panel.post_text(),
		panel.post_text() == "私は #AIニケちゃん で1,234回ヌキました（2025年8月からの累計）")
	var url: String = panel.post_url()
	_assert("(6) 投稿 URL に文言が載る", url.begins_with("https://")
		and url.contains("私は #AIニケちゃん で1,234回ヌキました（2025年8月からの累計）".uri_encode()))
	_assert("(6) 結果画面はツリーを止める", get_tree().paused)
	var closed: Array[bool] = [false]
	panel.closed.connect(func() -> void: closed[0] = true)
	# 決定入力で閉じる（ボタンのフォーカスに頼らない）。
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	panel.call("_input", event)
	_assert("(6) 決定で閉じ、closed が出て停止も解ける",
		closed[0] and not get_tree().paused and not panel.is_open())
	panel.queue_free()


func _wait_frames(count: int) -> void:
	for _i in range(count):
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
